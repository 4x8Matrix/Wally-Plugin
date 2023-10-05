local Console = require(script.Parent.Parent.Packages.Console)

local PluginStyleguideService = { }

PluginStyleguideService.Reporter = Console.new(`🍃 {script.Name}`)

-- ToDo: support camelCase naming conventions + allow developers to switch between the two in settings!

--[[
	Serialise a wally package name into PascalCase so that modules can be required using their names.

	For ex:
		rbx-redux -> RbxRedux
		red -> Red
		roblox-shared -> RobloxShared
]]
function PluginStyleguideService.ToPascalCase(_: PluginStyleguideService, sourceText: string)
	local underscoreSplitString = string.split(sourceText, "-")
	local source = ""

	for _, object in underscoreSplitString do
		source ..= string.upper(string.sub(object, 1, 1)) .. string.sub(object, 2, #object)
	end

	return source
end

export type PluginStyleguideService = typeof(PluginStyleguideService)

return PluginStyleguideService