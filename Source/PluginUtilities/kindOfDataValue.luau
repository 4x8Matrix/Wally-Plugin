local Types = require(script.Parent.Types)

local PRIMITIVE_KINDS = { boolean = "boolean", ["nil"] = "nil", number = "number", string = "string" }

--[[
	Names what a decoded value is: `boolean`, `number`, `string`, `null`, `array` or `map`, or `nil` for a field
		that is missing.
]]
return function(value: Types.DataValue?): string
	return PRIMITIVE_KINDS[type(value)] or value.kind
end
