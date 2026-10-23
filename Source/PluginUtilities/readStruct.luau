local Types = require(script.Parent.Types)

local buildError = require(script.Parent.buildError)
local describeUnexpected = require(script.Parent.describeUnexpected)
local kindOfDataValue = require(script.Parent.kindOfDataValue)

--[[
	Lists a struct's fields as serde names them in an unknown-field error.
]]
local function listFields(shape: Types.StructShape): string
	local names = {}

	for _, field in shape.fields do
		table.insert(names, `\`{field.name}\``)
	end

	return table.concat(names, ", ")
end

--[[
	Pairs a decoded value with a struct's fields as serde's derived Deserialize reads one from serde_json: an object
		by its keys, unknown ones ignored or refused as the struct says, a required field missing refused; or an
		array by position, which may stop early only where every field left has a default and may not run long.
		Null values are kept for the caller, which reads them as its field's type does. The error names no path.
]]
return function(value: Types.DataValue, shape: Types.StructShape): Types.BuildResult<{ [string]: Types.DataValue }>
	local kind = kindOfDataValue(value)
	local fields = {}
	local known = {}
	local present = {}

	for _, field in shape.fields do
		known[field.name] = true
	end

	if kind == "map" then
		for _, entry in value.entries do
			if known[entry.key] then
				fields[entry.key] = entry.value
				present[entry.key] = true
			elseif shape.denyUnknownFields then
				return buildError("", `unknown field \`{entry.key}\`, expected one of {listFields(shape)}`)
			end
		end

		for _, field in shape.fields do
			if field.presence == "required" and not present[field.name] then
				return buildError("", `missing field \`{field.name}\``)
			end
		end

		return { ok = true, value = fields }
	end

	if kind ~= "array" then
		return buildError("", `invalid type: {describeUnexpected(value)}, expected struct {shape.name}`)
	end

	for index, field in shape.fields do
		if index > #value.items and field.presence ~= "defaulted" then
			return buildError(
				"",
				`invalid length {index - 1}, expected struct {shape.name} with {#shape.fields} elements`
			)
		end

		fields[field.name] = value.items[index]
	end

	if #value.items > #shape.fields then
		return buildError("", `invalid length {#value.items}, expected fewer elements in array`)
	end

	return { ok = true, value = fields }
end
