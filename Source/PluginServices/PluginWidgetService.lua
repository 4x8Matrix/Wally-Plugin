local Console = require(script.Parent.Parent.Packages.Console)
local Trove = require(script.Parent.Parent.Packages.Trove)

local PluginContext = require(script.Parent.Parent.PluginContext)

local PluginInterfaceService = require(script.Parent.PluginInterfaceService)
local PluginActionService = require(script.Parent.PluginActionService)

local PlginWidgetService = { }

PlginWidgetService.Trove = Trove.new()
PlginWidgetService.Reporter = Console.new(`🍃 {script.Name}`)

PlginWidgetService.WidgetInfo = DockWidgetPluginGuiInfo.new(
	PluginContext.PluginSettings.Widget.InitialDockState,
	PluginContext.PluginSettings.Widget.InitiallyEnabled,
	PluginContext.PluginSettings.Widget.OverridePreviousEnabled,
	PluginContext.PluginSettings.Widget.Size.X,
	PluginContext.PluginSettings.Widget.Size.Y,
	PluginContext.PluginSettings.Widget.Size.X,
	PluginContext.PluginSettings.Widget.Size.Y
)

PlginWidgetService.WidgetObject = PluginContext.Plugin:CreateDockWidgetPluginGui(
	PluginContext.PluginSettings.Widget.Id,
	PlginWidgetService.WidgetInfo
)

function PlginWidgetService.SetVisible(self: PlginWidgetService, isVisible: boolean)
	self.WidgetObject.Enabled = isVisible
	
	if isVisible then
		task.delay(0.5, function()
			PluginActionService:EndAction("WidgetClosed")
		end)
	else
		PluginActionService:StartAction("WidgetClosed")
	end
end

function PlginWidgetService.IsVisible(self: PlginWidgetService)
	return self.WidgetObject.Enabled
end

function PlginWidgetService.OnStart(self: PlginWidgetService)
	self.WidgetObject.Name = `PluginWidget<"{PluginContext.PluginSettings.Widget.Title}">`
	self.WidgetObject.Title = PluginContext.PluginSettings.Widget.Title
	self.WidgetObject.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	PluginInterfaceService:MountInterfaceOnto(self.WidgetObject)

	self.WidgetObject:BindToClose(function()
		self:SetVisible(false)
	end)
end

function PlginWidgetService.OnStop(self: PlginWidgetService)
	self.WidgetObject:Destroy()

	PluginInterfaceService:UnmountInterface()

	self.Trove:Destroy()
end

export type PlginWidgetService = typeof(PlginWidgetService)

return PlginWidgetService