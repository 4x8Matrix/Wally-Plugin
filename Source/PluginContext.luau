local HttpService = game:GetService("HttpService")
local StudioService = game:GetService("StudioService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local VERSION = "0.2.0"

local StudioSettings = settings().Studio

local PluginContext = {}

PluginContext.Plugin = plugin :: Plugin
PluginContext.UserId = StudioService:GetUserId() :: number
PluginContext.StudioSettings = StudioSettings :: Studio
PluginContext.UserGameSettings = UserGameSettings :: UserGameSettings

PluginContext.PluginSettings = {
	Version = VERSION,
	Widget = {
		Title = `Wally {VERSION}`,
		Id = HttpService:GenerateGUID(false),
		Size = Vector2.new(320, 560),
		MinimumSize = Vector2.new(200, 160),
		InitialDockState = Enum.InitialDockState.Left,
		OverridePreviousEnabled = true,
		InitiallyEnabled = false,
	},
	Palette = {
		Accent = { Dark = Color3.fromHex("F0564B"), Light = Color3.fromHex("D63A2F") },
		Success = { Dark = Color3.fromHex("5DC48A"), Light = Color3.fromHex("1E7A47") },
	},
	Fonts = {
		Sans = "rbxasset://fonts/families/BuilderSans.json",
		Mono = "rbxasset://fonts/families/BuilderMono.json",
	},
	Icons = {
		Search = "rbxasset://textures/StudioSharedUI/search.png",
		Close = "rbxasset://textures/StudioSharedUI/close.png",
		ChevronDown = "rbxasset://textures/ui/MenuBar/arrow_down.png",
		ChevronUp = "rbxasset://textures/ui/MenuBar/arrow_up.png",
		ChevronLeft = "rbxasset://textures/ui/MenuBar/arrow_left.png",
		Spinner = "rbxasset://textures/DarkThemeLoadingCircle.png",
		Warning = "rbxasset://textures/StudioSharedUI/statusWarning.png",
		Success = "rbxasset://textures/StudioSharedUI/statusSuccess.png",
		Error = "rbxasset://textures/StudioSharedUI/alert_error.png",
	},
	Toolbar = {
		Name = `Wally {VERSION}`,
		Buttons = {
			ToggleInterface = {
				Icons = {
					Light = "http://www.roblox.com/asset/?id=15129182671",
					Dark = "http://www.roblox.com/asset/?id=15129182671",
				},
				Text = "Wally",
				IconAltText = "",
				Id = HttpService:GenerateGUID(false),
			},
		},
	},
}

return PluginContext
