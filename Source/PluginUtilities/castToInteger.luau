--[[
	Converts a number to an integer as Rust's `as` does: toward zero, saturating at `minimum` and `maximum`.
		Studio's own assignment wraps or floors instead, so values are cast here first.
]]
return function(number: number, minimum: number, maximum: number): number
	return math.clamp(if number < 0 then math.ceil(number) else math.floor(number), minimum, maximum)
end
