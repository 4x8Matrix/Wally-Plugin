local Types = require(script.Parent.Types)

local buildError = require(script.Parent.buildError)
local compileIgnoreGlob = require(script.Parent.compileIgnoreGlob)
local decodeJsonc = require(script.Parent.decodeJsonc)
local decodeProjectNode = require(script.Parent.decodeProjectNode)
local decodeSyncRule = require(script.Parent.decodeSyncRule)
local describeUnexpected = require(script.Parent.describeUnexpected)
local expectKind = require(script.Parent.expectKind)
local isIpAddress = require(script.Parent.isIpAddress)
local kindOfDataValue = require(script.Parent.kindOfDataValue)
local readStruct = require(script.Parent.readStruct)

local PROJECT = {
	name = "Project",
	fields = {
		{ name = "$schema", presence = "optional" },
		{ name = "name", presence = "optional" },
		{ name = "tree", presence = "required" },
		{ name = "servePort", presence = "optional" },
		{ name = "servePlaceIds", presence = "optional" },
		{ name = "blockedPlaceIds", presence = "optional" },
		{ name = "placeId", presence = "optional" },
		{ name = "gameId", presence = "optional" },
		{ name = "serveAddress", presence = "optional" },
		{ name = "serveAllowedHosts", presence = "defaulted" },
		{ name = "emitLegacyScripts", presence = "optional" },
		{ name = "globIgnorePaths", presence = "defaulted" },
		{ name = "syncbackRules", presence = "optional" },
		{ name = "syncRules", presence = "defaulted" },
	},
	denyUnknownFields = true,
}
local SYNCBACK_RULES = {
	name = "SyncbackRules",
	fields = {
		{ name = "ignoreTrees", presence = "defaulted" },
		{ name = "ignorePaths", presence = "defaulted" },
		{ name = "ignoreProperties", presence = "defaulted" },
		{ name = "syncCurrentCamera", presence = "optional" },
		{ name = "syncUnscriptable", presence = "optional" },
		{ name = "ignoreReferents", presence = "optional" },
		{ name = "createIgnoreDirPaths", presence = "optional" },
	},
	denyUnknownFields = true,
}
local FIELD_TYPES = {
	["$schema"] = "string",
	name = "string",
	tree = "node",
	servePort = "u16",
	servePlaceIds = "u64s",
	blockedPlaceIds = "u64s",
	placeId = "u64",
	gameId = "u64",
	serveAddress = "address",
	serveAllowedHosts = "strings",
	emitLegacyScripts = "boolean",
	globIgnorePaths = "globs",
	syncbackRules = "syncbackRules",
	syncRules = "syncRules",
	ignoreTrees = "strings",
	ignorePaths = "strings",
	ignoreProperties = "propertyLists",
	syncCurrentCamera = "boolean",
	syncUnscriptable = "boolean",
	ignoreReferents = "boolean",
	createIgnoreDirPaths = "boolean",
}

local SEQUENCE_ITEMS = { u64s = "u64", strings = "string", globs = "glob", syncRules = "syncRule" }

local readFields: (value: Types.DataValue, shape: Types.StructShape) -> Types.BuildResult<{ [string]: any }>
local readValue: (fieldType: string, value: Types.DataValue) -> Types.BuildResult<any>

-- seam: a whole number written as a fraction (`1.0`) reads as an integer; upgrade trigger: a package doing it
-- seam: an integer past 2^53 loses digits, so u64 2^64-1 refuses; upgrade trigger: a package needing one
--[[
	Reads an unsigned integer up to `limit`, named `typeName` in serde's words when it is not one.
]]
local function readUnsigned(value: Types.DataValue, limit: number, typeName: string): Types.BuildResult<number>
	local isWhole = kindOfDataValue(value) == "number" and value == math.floor(value) and value < 2 ^ 64

	if not isWhole then
		return buildError("", `invalid type: {describeUnexpected(value)}, expected {typeName}`)
	end

	if value < 0 or value > limit then
		return buildError("", `invalid value: {describeUnexpected(value)}, expected {typeName}`)
	end

	return { ok = true, value = value }
end

--[[
	Reads `serveAddress`: a string that parses as an IP address.
]]
local function readAddress(value: Types.DataValue): Types.BuildResult<string>
	local checked = expectKind(value, "string", "IP address")

	if not checked.ok then
		return checked
	end

	if not isIpAddress(value) then
		return buildError("", "invalid IP address syntax")
	end

	return checked
end

--[[
	Reads a `globIgnorePaths` entry: a string compiled as an ignore glob.
]]
local function readGlob(value: Types.DataValue): Types.BuildResult<Types.IgnoreGlob>
	local checked = expectKind(value, "string", "a string")

	if not checked.ok then
		return checked
	end

	return compileIgnoreGlob(value)
end

--[[
	Reads a sequence, each item as `itemType`, into a list of what each item reads as.
]]
local function readSequence(itemType: string, value: Types.DataValue): Types.BuildResult<{ any }>
	local checked = expectKind(value, "array", "a sequence")
	local items = {}

	if not checked.ok then
		return checked
	end

	for _, item in value.items do
		local read = readValue(itemType, item)

		if not read.ok then
			return read
		end

		table.insert(items, read.value)
	end

	return { ok = true, value = items }
end

--[[
	Reads syncback's `ignoreProperties`: a map of class names to sequences of property names.
]]
local function readPropertyLists(value: Types.DataValue): Types.BuildResult<Types.DataMap>
	local checked = expectKind(value, "map", "a map")

	if not checked.ok then
		return checked
	end

	for _, entry in value.entries do
		local properties = readSequence("string", entry.value)

		if not properties.ok then
			return properties
		end
	end

	return checked
end

--[[
	Reads a value as the Rust type a field declares: strings, booleans, u16 and u64 numbers, an IP address, an ignore
		glob, the tree's node, a sync rule, the syncback rules struct and its map of class to property names, and
		sequences of each kind of item.
]]
function readValue(fieldType: string, value: Types.DataValue): Types.BuildResult<any>
	local itemType = SEQUENCE_ITEMS[fieldType]

	if itemType then
		return readSequence(itemType, value)
	elseif fieldType == "string" or fieldType == "boolean" then
		return expectKind(value, fieldType, `a {fieldType}`)
	elseif fieldType == "u16" then
		return readUnsigned(value, 65535, "u16")
	elseif fieldType == "u64" then
		return readUnsigned(value, 2 ^ 64, "u64")
	elseif fieldType == "address" then
		return readAddress(value)
	elseif fieldType == "glob" then
		return readGlob(value)
	elseif fieldType == "node" then
		return decodeProjectNode(value)
	elseif fieldType == "syncRule" then
		return decodeSyncRule(value)
	elseif fieldType == "syncbackRules" then
		return readFields(value, SYNCBACK_RULES)
	elseif fieldType == "propertyLists" then
		return readPropertyLists(value)
	end
end

--[[
	Reads a struct's fields by their types: an absent field as absent, null as absent for an optional one and as a
		value of its type for a defaulted one, which refuses it.
]]
function readFields(value: Types.DataValue, shape: Types.StructShape): Types.BuildResult<{ [string]: any }>
	local paired = readStruct(value, shape)
	local fields = {}

	if not paired.ok then
		return paired
	end

	for _, field in shape.fields do
		local given = paired.value[field.name]
		local kind = kindOfDataValue(given)
		local absent = kind == "nil" or (field.presence == "optional" and kind == "null")
		local read = if absent then { ok = true } else readValue(FIELD_TYPES[field.name], given)

		if not read.ok then
			return read
		end

		fields[field.name] = read.value
	end

	return { ok = true, value = fields }
end

--[[
	Decodes a project file as Rojo 7.7.1 loads one (R2.1): JSONC holding Rojo's Project, which denies unknown fields,
		requires `tree` and reads every field on a build, serve-only and syncback ones included, so a malformed one
		refuses. Fields with a default (`serveAllowedHosts`, `globIgnorePaths`, `syncRules`) refuse null; the others
		read it as absent. Ignore globs and sync rules come back compiled, relative to the project's folder. A wrong
		field fails in serde's words; the error names no path, the caller adds the project file.
]]
return function(text: string): Types.BuildResult<Types.ProjectFile>
	local decoded = decodeJsonc(text)
	local fields = if decoded.ok then readFields(decoded.value, PROJECT) else decoded

	if not fields.ok then
		return fields
	end

	return {
		ok = true,
		value = {
			name = fields.value.name,
			tree = fields.value.tree,
			emitLegacyScripts = fields.value.emitLegacyScripts,
			globIgnorePaths = fields.value.globIgnorePaths or {},
			syncRules = fields.value.syncRules or {},
		},
	}
end
