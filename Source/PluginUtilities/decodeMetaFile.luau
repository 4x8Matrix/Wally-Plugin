local Types = require(script.Parent.Types)

local decodeJsonc = require(script.Parent.decodeJsonc)
local expectKind = require(script.Parent.expectKind)
local kindOfDataValue = require(script.Parent.kindOfDataValue)
local readStruct = require(script.Parent.readStruct)

local ADJACENT_METADATA = {
	name = "AdjacentMetadata",
	fields = {
		{ name = "$schema", presence = "optional" },
		{ name = "id", presence = "optional" },
		{ name = "ignoreUnknownInstances", presence = "optional" },
		{ name = "properties", presence = "defaulted" },
		{ name = "attributes", presence = "defaulted" },
	},
	denyUnknownFields = false,
}
local DIRECTORY_METADATA = {
	name = "DirectoryMetadata",
	fields = {
		{ name = "$schema", presence = "optional" },
		{ name = "id", presence = "optional" },
		{ name = "ignoreUnknownInstances", presence = "optional" },
		{ name = "properties", presence = "defaulted" },
		{ name = "attributes", presence = "defaulted" },
		{ name = "className", presence = "optional" },
	},
	denyUnknownFields = false,
}
local FIELD_TYPES = {
	["$schema"] = { kind = "string", expected = "a string" },
	id = { kind = "string", expected = "a string" },
	ignoreUnknownInstances = { kind = "boolean", expected = "a boolean" },
	properties = { kind = "map", expected = "a map" },
	attributes = { kind = "map", expected = "a map" },
	className = { kind = "string", expected = "a &str" },
}

--[[
	Checks one field's value against its type in Rojo's metadata structs: absent as absent, null as absent for a
		field without a default, and the wrong kind refused in serde's words.
]]
local function readField(field: Types.StructField, value: Types.DataValue?): Types.BuildResult<any>
	local fieldType = FIELD_TYPES[field.name]
	local kind = kindOfDataValue(value)

	if kind == "nil" or (kind == "null" and field.presence ~= "defaulted") then
		return { ok = true }
	end

	return expectKind(value, fieldType.kind, fieldType.expected)
end

--[[
	Decodes a meta file as Rojo 7.7.1 reads one (R1.12): JSONC holding Rojo's AdjacentMetadata, or for an
		`init.meta.json` its DirectoryMetadata, which adds `className`, read by readStruct as an object or an array.
		Unknown keys are ignored, null reads as absent for `$schema`, `id`, `ignoreUnknownInstances` and
		`className`, and a wrong type fails in serde's words, the first in the order serde reads the fields: an
		object's by key, as Rojo's decoded objects come sorted, and an array's by position. Property and attribute
		values are left decoded for the caller to resolve against the instance. The error names no path; the
		caller adds the file it read.
]]
return function(text: string, isDirectory: boolean): Types.BuildResult<Types.MetaFile>
	local decoded = decodeJsonc(text)
	local shape = if isDirectory then DIRECTORY_METADATA else ADJACENT_METADATA
	local struct = if decoded.ok then readStruct(decoded.value, shape) else decoded
	local fields = table.clone(shape.fields)
	local read = {}

	if not struct.ok then
		return struct
	end

	if kindOfDataValue(decoded.value) == "map" then
		table.sort(fields, function(left: Types.StructField, right: Types.StructField): boolean
			return left.name < right.name
		end)
	end

	for _, field in fields do
		local checked = readField(field, struct.value[field.name])

		if not checked.ok then
			return checked
		end

		read[field.name] = checked.value
	end

	return {
		ok = true,
		value = {
			schema = read["$schema"],
			id = read.id,
			className = read.className,
			properties = read.properties or { kind = "map", entries = {} },
			attributes = read.attributes or { kind = "map", entries = {} },
		},
	}
end
