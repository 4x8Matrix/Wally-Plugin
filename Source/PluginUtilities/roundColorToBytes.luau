--[[
	Rounds a Color3 to the bytes Rojo writes it as for a property written as Color3uint8 (BasePart.Color): each
		channel clamped to 0 and 1, times 255, rounded half away from zero. Studio's own assignment rounds halves
		down, so the bytes are worked out here.
]]
return function(color: Color3): Color3
	return Color3.fromRGB(
		math.floor(math.clamp(color.R, 0, 1) * 255 + 0.5),
		math.floor(math.clamp(color.G, 0, 1) * 255 + 0.5),
		math.floor(math.clamp(color.B, 0, 1) * 255 + 0.5)
	)
end
