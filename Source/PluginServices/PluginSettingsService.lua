local HttpService = game:GetService("HttpService")

local Console = require(script.Parent.Parent.Packages.Console)
local Sift = require(script.Parent.Parent.Packages.Sift)

local PluginContext = require(script.Parent.Parent.PluginContext)

-- the ".blob" has no significance here, it just looks cool 😅
local PLUGIN_SETTINGS_BLOB_NAME = "wally-plugin.blob"

local PluginSettingsService = { }

PluginSettingsService.Reporter = Console.new(`🍃 {script.Name}`)
PluginSettingsService.SettingsTable = { }
PluginSettingsService.Schema = { }

--[[
	A dynamic way to get a setting on the developers device, can be set through `PluginSettingsService.Set` and is persistant through
		studio shutdowns, restarts and so on.
]]
function PluginSettingsService.Get(self: PluginSettingsService, settingsPath: string)
	local base = self.SettingsTable
	local split = string.split(settingsPath, ".")

	for _, index_name in split do
		base = base[index_name]
	end

	return base
end

--[[
	A dynamic way to set a setting on the developers device, can be fetched through `PluginSettingsService.Get` and is persistant through
		studio shutdowns, restarts and so on.
]]
function PluginSettingsService.Set(self: PluginSettingsService, settingsPath: string, value: any)
	local base = self.SettingsTable
	local split = string.split(settingsPath, ".")

	for index, index_name in split do
		if index == #split then
			continue
		end

		base = base[index_name]
	end

	base[split[#split]] = value
end

function PluginSettingsService.OnInit(self: PluginSettingsService)
	self.SettingsJsonBlob = PluginContext.Plugin:GetSetting(PLUGIN_SETTINGS_BLOB_NAME)

	if self.SettingsJsonBlob then
		self.SettingsTable = Sift.Dictionary.mergeDeep(self.Schema, HttpService:JSONDecode(self.SettingsJsonBlob))
	else
		self.SettingsTable = Sift.Dictionary.copyDeep(self.Schema)
	end
end

function PluginSettingsService.OnStop(self: PluginSettingsService)
	self.SettingsJsonBlob = HttpService:JSONEncode(self.SettingsTable)

	PluginContext.Plugin:SetSetting(PLUGIN_SETTINGS_BLOB_NAME, self.SettingsJsonBlob)
end

export type PluginSettingsService = typeof(PluginSettingsService)

return PluginSettingsService