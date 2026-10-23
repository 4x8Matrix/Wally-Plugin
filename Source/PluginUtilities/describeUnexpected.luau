local Types = require(script.Parent.Types)

local kindOfDataValue = require(script.Parent.kindOfDataValue)

local UNEXPECTED_KINDS = { null = "null", array = "sequence", map = "map" }
local DEBUG_ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

--[[
	Names a decoded value as serde's `Unexpected` does in a type error. A decoded number does not keep how it was
		written, so a whole number written as a fraction (`1.0`) is named an integer where serde names it a
		floating point.
]]
return function(value: Types.DataValue): string
	local kind = kindOfDataValue(value)

	if kind == "boolean" then
		return `boolean \`{value}\``
	elseif kind == "number" and value == math.floor(value) and math.abs(value) < 2 ^ 63 then
		return string.format("integer `%d`", value)
	elseif kind == "number" then
		return `floating point \`{value}\``
	elseif kind == "string" then
		return `string "{string.gsub(value, '[\\"\n\r\t]', DEBUG_ESCAPES)}"`
	end

	return UNEXPECTED_KINDS[kind]
end
