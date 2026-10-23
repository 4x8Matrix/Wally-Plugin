--[[
	Rounds a number to the nearest single-precision float, as Rust's `as f32` does.
]]
return function(number: number): number
	local rounded = string.unpack("<f", string.pack("<f", number))

	return rounded
end
