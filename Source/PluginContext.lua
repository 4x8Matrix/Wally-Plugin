local HttpService = game:GetService("HttpService")
local StudioService = game:GetService("StudioService")

local UserSettingsService = UserSettings()
local SettingsService = settings()

local UserGameSettings = UserSettingsService:GetService("UserGameSettings")
local StudioSettings = SettingsService.Studio

local PluginContext = { }

PluginContext.Plugin = (plugin :: Plugin)
PluginContext.UserId = (StudioService:GetUserId() :: number)
PluginContext.StudioSettings = (StudioSettings :: Studio)
PluginContext.UserGameSettings = (UserGameSettings :: UserGameSettings)

PluginContext.PluginSettings = { }

PluginContext.PluginSettings.Version = "1.0.0-rc.0"

PluginContext.PluginSettings.Widget = { }

PluginContext.PluginSettings.Widget.Title = `Wally {PluginContext.PluginSettings.Version}`
PluginContext.PluginSettings.Widget.Id = HttpService:GenerateGUID(false)
PluginContext.PluginSettings.Widget.Size = Vector2.new(300, 200)
PluginContext.PluginSettings.Widget.InitialDockState = Enum.InitialDockState.Left
PluginContext.PluginSettings.Widget.OverridePreviousEnabled = true
PluginContext.PluginSettings.Widget.InitiallyEnabled = false

PluginContext.PluginSettings.Toolbar = { }

PluginContext.PluginSettings.Toolbar.Name = `Wally {PluginContext.PluginSettings.Version}`

PluginContext.PluginSettings.Toolbar.Buttons = { }

PluginContext.PluginSettings.Toolbar.Buttons.ToggleInterface = { }

PluginContext.PluginSettings.Toolbar.Buttons.ToggleInterface.Icons = { }
PluginContext.PluginSettings.Toolbar.Buttons.ToggleInterface.Icons.Light = "rbxassetid://6835618318"
PluginContext.PluginSettings.Toolbar.Buttons.ToggleInterface.Icons.Dark = "rbxassetid://6835618318"

PluginContext.PluginSettings.Toolbar.Buttons.ToggleInterface.Text = "Wally"
PluginContext.PluginSettings.Toolbar.Buttons.ToggleInterface.IconAltText = ""
PluginContext.PluginSettings.Toolbar.Buttons.ToggleInterface.Id = HttpService:GenerateGUID(false)

PluginContext.PluginSettings.DownloadContextMenu = { }

PluginContext.PluginSettings.DownloadContextMenu.Id = HttpService:GenerateGUID(false)
PluginContext.PluginSettings.DownloadContextMenu.Icon = "rbxassetid://14806672610"
PluginContext.PluginSettings.DownloadContextMenu.Title = "Download Package"

PluginContext.PluginSettings.DownloadAsServerDependency = { }

PluginContext.PluginSettings.DownloadAsServerDependency.Id = HttpService:GenerateGUID(false)
PluginContext.PluginSettings.DownloadAsServerDependency.Text = "Download Package as Server Dependency"
PluginContext.PluginSettings.DownloadAsServerDependency.Icon = "http://www.roblox.com/asset/?id=14824729032"

PluginContext.PluginSettings.DownloadAsSharedDependency = { }

PluginContext.PluginSettings.DownloadAsSharedDependency.Id = HttpService:GenerateGUID(false)
PluginContext.PluginSettings.DownloadAsSharedDependency.Text = "Download Package as Shared Dependency"
PluginContext.PluginSettings.DownloadAsSharedDependency.Icon = "http://www.roblox.com/asset/?id=14824729781"

PluginContext.PluginSettings.DownloadAsModule = { }

PluginContext.PluginSettings.DownloadAsModule.Id = HttpService:GenerateGUID(false)
PluginContext.PluginSettings.DownloadAsModule.Text = "Download Package as Module"
PluginContext.PluginSettings.DownloadAsModule.Icon = "http://www.roblox.com/asset/?id=14825069009"

return PluginContext