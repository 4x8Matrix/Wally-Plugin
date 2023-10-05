--# selene: allow(global_usage)

local Console = require(script.Parent.Parent.Packages.Console)
local Trove = require(script.Parent.Parent.Packages.Trove)

local PluginContextService = { }

PluginContextService.Trove = Trove.new()
PluginContextService.Reporter = Console.new(`🔎 {script.Name}`)

function PluginContextService.OnStart(self: PluginContextService)
	_G.WallyPlugin = { }

	--[[
		On production builds, having an Api like this could come in handy for debugging!
	]]

	function _G.WallyPlugin.EnableVerboseLogging()
		Console.setGlobalLogLevel(Console.LogLevel.Debug)
	end

	function _G.WallyPlugin.DisableVerboseLogging()
		Console.setGlobalLogLevel(Console.LogLevel.Warn)
	end

	self.Trove:Add(function()
		_G.WallyPlugin = nil
	end)
end

function PluginContextService.OnStop(self: PluginContextService)
	self.Trove:Destroy()
end

export type PluginContextService = typeof(PluginContextService)

return PluginContextService