--[[
	A simple module to handle state for various actions, for example this module will inform other services
		about a download that may be happening
]]

local Console = require(script.Parent.Parent.Packages.Console)
local Trove = require(script.Parent.Parent.Packages.Trove)
local Signal = require(script.Parent.Parent.Packages.Signal)

local PluginActionService = { }

PluginActionService.Trove = Trove.new()
PluginActionService.Reporter = Console.new(`🔎 {script.Name}`)

PluginActionService.ActionStarted = Signal.new()
PluginActionService.ActionEnded = Signal.new()

PluginActionService.ActiveActions = { }
PluginActionService.TransitionActions = {
	["DownloadingPackage"] = true,
	["WidgetClosed"] = true
}

function PluginActionService.IsActionActive(self: PluginActionService, actionName: string)
	return self.ActiveActions[actionName] or false
end

function PluginActionService.IsTransitionableAction(self: PluginActionService, actionName: string)
	return self.TransitionActions[actionName] or false
end

function PluginActionService.IsTransitionableActionActive(self: PluginActionService)
	for actionName in self.ActiveActions do
		if self.TransitionActions[actionName] then
			return true
		end
	end

	return false
end

function PluginActionService.StartAction(self: PluginActionService, actionName: string)
	self.ActiveActions[actionName] = true

	self.ActionStarted:Fire(actionName)
end

function PluginActionService.EndAction(self: PluginActionService, actionName: string)
	self.ActiveActions[actionName] = nil

	self.ActionEnded:Fire(actionName)
end

export type PluginActionService = typeof(PluginActionService)

return PluginActionService