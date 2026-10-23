local Types = require(script.Parent.Types)

local buildError = require(script.Parent.buildError)
local compileGlob = require(script.Parent.compileGlob)
local describeUnexpected = require(script.Parent.describeUnexpected)
local expectKind = require(script.Parent.expectKind)
local kindOfDataValue = require(script.Parent.kindOfDataValue)
local readStruct = require(script.Parent.readStruct)

local SYNC_RULE = {
	name = "SyncRule",
	fields = {
		{ name = "pattern", presence = "required" },
		{ name = "exclude", presence = "optional" },
		{ name = "use", presence = "required" },
		{ name = "suffix", presence = "optional" },
	},
	denyUnknownFields = false,
}
local MIDDLEWARES = {
	"csv",
	"jsonModel",
	"json",
	"serverScript",
	"clientScript",
	"moduleScript",
	"pluginScript",
	"legacyClientScript",
	"legacyServerScript",
	"runContextServerScript",
	"runContextClientScript",
	"project",
	"rbxm",
	"rbxmx",
	"toml",
	"text",
	"yaml",
	"ignore",
}

--[[
	Reads an optional string field: null as absent, anything but a string refused in serde's words.
]]
local function readString(value: Types.DataValue?, optional: boolean): Types.BuildResult<string?>
	local kind = kindOfDataValue(value)

	if kind == "nil" or (kind == "null" and optional) then
		return { ok = true }
	end

	return expectKind(value, "string", "a string")
end

--[[
	Reads a glob field into a matcher, compiled as globset does.
]]
local function readGlob(value: Types.DataValue?, optional: boolean): Types.BuildResult<((string) -> boolean)?>
	local read = readString(value, optional)

	if not read.ok or not read.value then
		return read
	end

	return compileGlob(read.value)
end

--[[
	Reads `use` as serde reads Rojo's Middleware enum from serde_json: a variant name, or an object holding one
		variant name with a null value, which serde reads as that unit variant. Directory middlewares are not
		deserializable, so they are unknown variants.
]]
local function readMiddleware(value: Types.DataValue): Types.BuildResult<string>
	local kind = kindOfDataValue(value)
	local entry = if kind == "map" and #value.entries == 1 then value.entries[1] else nil
	local name = if kind == "string" then value elseif entry then entry.key else nil

	if entry and kindOfDataValue(entry.value) ~= "null" then
		return buildError("", `invalid type: {describeUnexpected(entry.value)}, expected unit variant`)
	end

	if not name then
		return buildError("", `invalid type: {describeUnexpected(value)}, expected variant identifier`)
	end

	if not table.find(MIDDLEWARES, name) then
		return buildError("", `unknown variant \`{name}\`, expected one of \`{table.concat(MIDDLEWARES, "`, `")}\``)
	end

	return { ok = true, value = name }
end

--[[
	Decodes one `syncRules` entry as Rojo 7.7.1's SyncRule (R2.8): `pattern` and `use` required, `exclude` and
		`suffix` optional, unknown keys ignored, as an object or an array of the four fields. The globs compile as
		globset's and match a path relative to the declaring project's folder, which the caller strips. A wrong
		field fails in serde's words; the error names no path.
]]
return function(value: Types.DataValue): Types.BuildResult<Types.SyncRule>
	local fields = readStruct(value, SYNC_RULE)

	if not fields.ok then
		return fields
	end

	local pattern = readGlob(fields.value.pattern, false)
	local exclude = if pattern.ok then readGlob(fields.value.exclude, true) else pattern
	local use = if exclude.ok then readMiddleware(fields.value.use) else exclude
	local suffix = if use.ok then readString(fields.value.suffix, true) else use

	if not suffix.ok then
		return suffix
	end

	return {
		ok = true,
		value = { matches = pattern.value, excludes = exclude.value, use = use.value, suffix = suffix.value },
	}
end
