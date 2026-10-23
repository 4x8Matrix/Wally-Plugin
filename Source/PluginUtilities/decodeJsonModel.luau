local Types = require(script.Parent.Types)

local buildError = require(script.Parent.buildError)
local decodeJsonc = require(script.Parent.decodeJsonc)
local describeUnexpected = require(script.Parent.describeUnexpected)
local expectKind = require(script.Parent.expectKind)
local kindOfDataValue = require(script.Parent.kindOfDataValue)

local WHITE_SPACE = {
	[0x09] = true,
	[0x0A] = true,
	[0x0B] = true,
	[0x0C] = true,
	[0x0D] = true,
	[0x20] = true,
	[0x85] = true,
	[0xA0] = true,
	[0x1680] = true,
	[0x2028] = true,
	[0x2029] = true,
	[0x202F] = true,
	[0x205F] = true,
	[0x3000] = true,
}
local FIELD_ORDER = { "$schema", "name", "className", "id", "children", "properties", "attributes" }
local FIELD_NAMES = {
	["$schema"] = "$schema",
	name = "name",
	Name = "name",
	className = "className",
	ClassName = "className",
	id = "id",
	children = "children",
	Children = "children",
	properties = "properties",
	Properties = "properties",
	attributes = "attributes",
}
local FIELD_TYPES = {
	["$schema"] = { kind = "string", expected = "a string", optional = true },
	name = { kind = "string", expected = "a string", optional = true },
	className = { kind = "string", expected = "a &str", optional = false },
	id = { kind = "string", expected = "a string", optional = true },
	children = { kind = "array", expected = "a sequence", optional = false },
	properties = { kind = "map", expected = "a map", optional = false },
	attributes = { kind = "map", expected = "a map", optional = false },
}
local REQUIRED_POSITIONS = 4

local readModel: (value: Types.DataValue) -> Types.BuildResult<Types.JsonModel>

--[[
	Whether `text` holds nothing but what Rust's `str::trim` strips, the Unicode White_Space characters.
]]
local function isBlank(text: string): boolean
	for _, codepoint in utf8.codes(text) do
		if not WHITE_SPACE[codepoint] and (codepoint < 0x2000 or codepoint > 0x200A) then
			return false
		end
	end

	return true
end

--[[
	Pairs an array's items with the fields in declaration order, as serde reads a struct written as a sequence.
]]
local function positionalEntries(items: { Types.DataValue }): { { key: string, value: Types.DataValue } }
	local entries = {}

	for index, field in FIELD_ORDER do
		if index > #items then
			break
		end

		table.insert(entries, { key = field, value = items[index] })
	end

	return entries
end

--[[
	Reads each item of a `children` array as a model, in written order.
]]
local function readChildren(items: { Types.DataValue }): Types.BuildResult<{ Types.JsonModel }>
	local children = {}

	for _, item in items do
		local child = readModel(item)

		if not child.ok then
			return child
		end

		table.insert(children, child.value)
	end

	return { ok = true, value = children }
end

--[[
	Checks one field's value against its type in Rojo's JsonModel, reading a null optional field as absent and
		`children` as models.
]]
local function readField(field: string, value: Types.DataValue): Types.BuildResult<any>
	local fieldType = FIELD_TYPES[field]
	local kind = kindOfDataValue(value)

	if kind == "null" and fieldType.optional then
		return { ok = true }
	end

	local checked = expectKind(value, fieldType.kind, fieldType.expected)

	if not checked.ok then
		return checked
	end

	return if field == "children" then readChildren(value.items) else checked
end

--[[
	Reads one model object as serde reads Rojo's JsonModel from a decoded value: an object field by field in key
		order, its aliases (`Name`, `ClassName`, `Properties`, `Children`) standing for the field and unknown keys
		ignored, or an array of four to seven items in declaration order. A field given twice, a missing
		`className` and a value of the wrong type fail in serde's words.
]]
function readModel(value: Types.DataValue): Types.BuildResult<Types.JsonModel>
	local kind = kindOfDataValue(value)

	if kind ~= "map" and kind ~= "array" then
		return buildError("", `invalid type: {describeUnexpected(value)}, expected struct JsonModel`)
	end

	local entries = if kind == "map" then value.entries else positionalEntries(value.items)
	local fields = {}
	local seen = {}

	for _, entry in entries do
		local field = FIELD_NAMES[entry.key]

		if not field then
			continue
		end

		if seen[field] then
			return buildError("", `duplicate field \`{field}\``)
		end

		local read = readField(field, entry.value)

		if not read.ok then
			return read
		end

		seen[field] = true
		fields[field] = read.value
	end

	if kind == "array" and #value.items < REQUIRED_POSITIONS then
		return buildError("", `invalid length {#value.items}, expected struct JsonModel with {#FIELD_ORDER} elements`)
	end

	if kind == "array" and #value.items > #FIELD_ORDER then
		return buildError("", `invalid length {#value.items}, expected fewer elements in array`)
	end

	if not fields.className then
		return buildError("", "missing field `className`")
	end

	return {
		ok = true,
		value = {
			name = fields.name,
			className = fields.className,
			id = fields.id,
			properties = fields.properties or { kind = "map", entries = {} },
			attributes = fields.attributes or { kind = "map", entries = {} },
			children = fields.children or {},
		},
	}
end

--[[
	Decodes a `.model.json` or `.model.jsonc` file as Rojo 7.7.1 reads one (R1.10): text that is not UTF-8 fails,
		a blank file holds no model, and anything else is JSONC holding Rojo's JsonModel schema. Property and
		attribute values are left decoded for the caller to resolve against each object's class. The error names
		no path; the caller adds the file it read.
]]
return function(text: string): Types.BuildResult<Types.JsonModel?>
	if not utf8.len(text) then
		return buildError("", "File was not valid UTF-8")
	end

	if isBlank(text) then
		return { ok = true }
	end

	local decoded = decodeJsonc(text)

	if not decoded.ok then
		return decoded
	end

	return readModel(decoded.value)
end
