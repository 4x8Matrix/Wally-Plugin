--[[
	The enum called `enumName`, or nil when there is none. Searching `Enum:GetEnums()` keeps names such as
		`GetEnums`, which index Enum's own methods, from passing as enums.
]]
return function(enumName: string): Enum?
	for _, enum in Enum:GetEnums() do
		if tostring(enum) == enumName then
			return enum
		end
	end

	return
end
