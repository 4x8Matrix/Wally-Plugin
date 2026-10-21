--[[
	Serialise a wally package name into PascalCase so that modules can be required using their names.

	For ex:
		rbx-redux -> RbxRedux
		red -> Red
		roblox-shared -> RobloxShared
]]
return function(sourceText: string): string
	local underscoreSplitString = string.split(sourceText, "-")
	local source = ""

	for _, object in underscoreSplitString do
		source ..= string.upper(string.sub(object, 1, 1)) .. string.sub(object, 2, #object)
	end

	return source
end
