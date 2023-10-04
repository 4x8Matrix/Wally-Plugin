local Console = require(script.Parent.Parent.Packages.Console)

local PluginStyleguideService = { }

PluginStyleguideService.Reporter = Console.new(`🍃 {script.Name}`)

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