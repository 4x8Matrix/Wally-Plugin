local Console = require(script.Parent.Parent.Packages.Console)
local Trove = require(script.Parent.Parent.Packages.Trove)

local PluginContext = require(script.Parent.Parent.PluginContext)

local PluginWidgetService = require(script.Parent.PluginWidgetService)

local PluginToolbarService = { }

PluginToolbarService.Trove = Trove.new()
PluginToolbarService.Reporter = Console.new(`🎨 {script.Name}`)
PluginToolbarService.ToolbarButtons = { } :: { [string]: PluginToolbarButton }
PluginToolbarService.ToolbarObject = PluginContext.Plugin:CreateToolbar(
	PluginContext.PluginSettings.Toolbar.Name
)

function PluginToolbarService.SetToolbarButtonCallback(self: PluginToolbarService, buttonName: string, buttonCallback: () -> ())
	return self.ToolbarButtons[buttonName].Click:Connect(buttonCallback)
end

--[[
	Update toolbar buttons icons, used when the user switches the studio theme
]]
function PluginToolbarService.UpdateToolbarButtonIcons(self: PluginToolbarService)
	local themeName = tostring(PluginContext.StudioSettings.Theme)
	
	for buttonName, buttonObject in self.ToolbarButtons do
		buttonObject.Icon = PluginContext.PluginSettings.Toolbar.Buttons[buttonName].Icons[themeName]
	end
end

--[[
	Runs through the `PluginSettings.Toolbar.Buttons` table under `PluginContext` and generates
		several buttons that will be displayed on the toolbar
]]
function PluginToolbarService.CreateToolbarButtons(self: PluginToolbarService)
	local themeName = tostring(PluginContext.StudioSettings.Theme)
	
	for	buttonName: string, buttonDetails: { [any]: any } in PluginContext.PluginSettings.Toolbar.Buttons do
		self.ToolbarButtons[buttonName] = self.ToolbarObject:CreateButton(
			buttonDetails.Id,
			buttonDetails.IconAltText,
			buttonDetails.Icons[themeName],
			buttonDetails.Text
		)

		self.ToolbarButtons[buttonName].ClickableWhenViewportHidden = true
		self.ToolbarButtons[buttonName].Name = `PluginButton<"{buttonName}">`
		self.ToolbarButtons[buttonName].Parent = self.ToolbarObject
	end
end

function PluginToolbarService.OnStart(self: PluginToolbarService)
	self.ToolbarObject.Name = `PluginToolbar<"{PluginContext.PluginSettings.Toolbar.Name}">`
	self.ToolbarObject.Parent = PluginContext.Plugin

	self:CreateToolbarButtons()
	
	--[[
		Since we dynamically generate buttons based off of what we have in the `PluginContext` file,
			this is a dynamic way for us to "bind" callbacks to these dynamic buttons.
	]]
	self.Trove:Add(self:SetToolbarButtonCallback("ToggleInterface", function()
		PluginWidgetService:SetVisible(not PluginWidgetService:IsVisible())
	end))

	self.Trove:Add(PluginContext.StudioSettings.ThemeChanged:Connect(function()
		self:UpdateToolbarButtonIcons()
	end))
end

function PluginToolbarService.OnStop(self: PluginToolbarService)
	self.ToolbarObject:Destroy()

	for _, buttonObject in self.ToolbarButtons do
		buttonObject:Destroy()
	end

	self.Trove:Destroy()
end

export type PluginToolbarService = typeof(PluginToolbarService)

return PluginToolbarService