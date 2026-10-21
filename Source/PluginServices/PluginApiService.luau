--# selene: allow(global_usage)

local Console = require(script.Parent.Parent.Packages.Console)
local Trove = require(script.Parent.Parent.Packages.Trove)

local PluginPackageService = require(script.Parent.PluginPackageService)

local PluginApiService = { }

PluginApiService.Trove = Trove.new()
PluginApiService.Reporter = Console.new(`🔎 {script.Name}`)

function PluginApiService.OnStart(self: PluginApiService)
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

	--[[
		Install and remove packages from Studio's command bar and from the Studio tools, as the context menus do.
	]]

	function _G.WallyPlugin.InstallAsync(packageName: string, realm: string, requirement: string?, alias: string?)
		return PluginPackageService:InstallAsync(packageName, realm, requirement, alias)
	end

	function _G.WallyPlugin.RemoveAsync(alias: string, realm: string)
		return PluginPackageService:RemoveAsync(alias, realm)
	end

	self.Trove:Add(function()
		_G.WallyPlugin = nil
	end)
end

function PluginApiService.OnStop(self: PluginApiService)
	self.Trove:Destroy()
end

export type PluginApiService = typeof(PluginApiService)

return PluginApiService
