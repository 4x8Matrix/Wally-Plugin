local Types = require(script.Parent.Types)

local buildError = require(script.Parent.buildError)
local toml = require(script.Parent.Parent.Vendor.eryx.toml)
local tomlShared = require(script.Parent.Parent.Vendor.eryx.toml.shared)

local Converters = {}

local function toDataValue(value: any): Types.DataValue
	local convert = Converters[typeof(value)]

	return if convert then convert(value) else value
end

function Converters.table(value: { [any]: any }): Types.DataValue
	if tomlShared.tableIsArray(value) then
		local items = {}

		for _, item in value do
			table.insert(items, toDataValue(item))
		end

		return { kind = "array", items = items }
	end

	local keys = {}
	local entries = {}

	for key in value do
		table.insert(keys, key)
	end

	table.sort(keys)

	for _, key in keys do
		table.insert(entries, { key = key, value = toDataValue(value[key]) })
	end

	return { kind = "map", entries = entries }
end

-- seam: a table first keyed `$__toml_private_datetime` is not read as a datetime; upgrade trigger: a package using it
--[[
	Decodes `text` as Rojo 7.7.1 reads a `.toml` file, through the toml 0.5.11 crate: a map's entries come back
		sorted by key bytes, arrays and arrays of tables as arrays, every number as a float, and each datetime as
		the string toml 0.5.11 prints. The vendored eryx parser carries the changes that make it read TOML 1.0 as
		that crate does, listed in its NOTICE. Malformed text fails in Rojo's words followed by the parser's, which
		give a byte offset where Rojo gives a line and a column. The error names no path; the caller adds the file
		it read.
]]
return function(text: string): Types.BuildResult<Types.DataValue>
	local decoded, result = pcall(toml.decode, text)

	if not decoded then
		local position, reason = string.match(result, "TOML parse error at (%d+): (.*)$")
		local detail = if reason then `{reason} around {position}` else result

		return buildError("", `File contains malformed TOML: {detail}`)
	end

	return { ok = true, value = toDataValue(result) }
end
