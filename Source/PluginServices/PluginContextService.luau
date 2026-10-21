local Selection = game:GetService("Selection")

local Console = require(script.Parent.Parent.Packages.Console)
local Promise = require(script.Parent.Parent.Packages.Promise)
local Trove = require(script.Parent.Parent.Packages.Trove)

local PluginContext = require(script.Parent.Parent.PluginContext)

local PluginPackageService = require(script.Parent.PluginPackageService)

local PluginContextService = { }

PluginContextService.Trove = Trove.new()
PluginContextService.Reporter = Console.new(`🔎 {script.Name}`)

PluginContextService.InstalledContextMenu = PluginContext.Plugin:CreatePluginMenu(
	PluginContext.PluginSettings.InstalledContextMenu.Id,
	PluginContext.PluginSettings.InstalledContextMenu.Title,
	PluginContext.PluginSettings.InstalledContextMenu.Icon
)

PluginContextService.DestroyPackage = PluginContextService.InstalledContextMenu:AddNewAction(
	PluginContext.PluginSettings.DestroyPackage.Id,
	PluginContext.PluginSettings.DestroyPackage.Text,
	PluginContext.PluginSettings.DestroyPackage.Icon
)

PluginContextService.DownloadContextMenu = PluginContext.Plugin:CreatePluginMenu(
	PluginContext.PluginSettings.DownloadContextMenu.Id,
	PluginContext.PluginSettings.DownloadContextMenu.Title,
	PluginContext.PluginSettings.DownloadContextMenu.Icon
)

PluginContextService.DownloadAsServerDependency = PluginContextService.DownloadContextMenu:AddNewAction(
	PluginContext.PluginSettings.DownloadAsServerDependency.Id,
	PluginContext.PluginSettings.DownloadAsServerDependency.Text,
	PluginContext.PluginSettings.DownloadAsServerDependency.Icon
)

PluginContextService.DownloadAsSharedDependency = PluginContextService.DownloadContextMenu:AddNewAction(
	PluginContext.PluginSettings.DownloadAsSharedDependency.Id,
	PluginContext.PluginSettings.DownloadAsSharedDependency.Text,
	PluginContext.PluginSettings.DownloadAsSharedDependency.Icon
)

PluginContextService.DownloadContextMenu:AddSeparator()

PluginContextService.DownloadAsModule = PluginContextService.DownloadContextMenu:AddNewAction(
	PluginContext.PluginSettings.DownloadAsModule.Id,
	PluginContext.PluginSettings.DownloadAsModule.Text,
	PluginContext.PluginSettings.DownloadAsModule.Icon
)

--[[
	Show the Roblox context menu for downloading and installing packages.
]]
function PluginContextService.ShowDownloadContextMenuAsync(self: PluginContextService)
	return Promise.new(function(resolve)
		resolve(self.DownloadContextMenu:ShowAsync())
	end)
end

--[[
	Show the Roblox context menu for removing packages.
]]
function PluginContextService.ShowInstalledContextMenuAsync(self: PluginContextService)
	return Promise.new(function(resolve)
		resolve(self.InstalledContextMenu:ShowAsync())
	end)
end

function PluginContextService.OnStart(self: PluginContextService)
	self.DownloadContextMenu.Name = `PluginContext<"{PluginContext.PluginSettings.DownloadContextMenu.Title}">`
	self.DownloadContextMenu.Parent = PluginContext.Plugin

	--[[
		Install a package as a server dependency of the place.
	]]
	self.Trove:Add(self.DownloadAsServerDependency.Triggered:Connect(function()
		PluginPackageService:InstallAsync(PluginPackageService:GetSelectedPackage().Name, "server"):await()
	end))

	--[[
		Install a package as a shared dependency of the place.
	]]
	self.Trove:Add(self.DownloadAsSharedDependency.Triggered:Connect(function()
		PluginPackageService:InstallAsync(PluginPackageService:GetSelectedPackage().Name, "shared"):await()
	end))

	--[[
		Install a package as a shared dependency, then select its root link so it can be found in the Explorer and
			required from `ReplicatedStorage.Packages` like any other package.
	]]
	self.Trove:Add(self.DownloadAsModule.Triggered:Connect(function()
		local installed, summary =
			PluginPackageService:InstallAsync(PluginPackageService:GetSelectedPackage().Name, "shared"):await()

		if installed then
			Selection:Set({ summary.rootLink })
		end
	end))

	--[[
		Remove a package from the place, pruning the packages nothing else needs.
	]]
	self.Trove:Add(self.DestroyPackage.Triggered:Connect(function()
		local selection = PluginPackageService:GetSelectedPackage()

		PluginPackageService:RemoveAsync(selection.Alias, selection.Realm):await()
	end))
end

function PluginContextService.OnStop(self: PluginContextService)
	self.DownloadContextMenu:Destroy()

	self.DownloadAsServerDependency:Destroy()
	self.DownloadAsSharedDependency:Destroy()

	self.Trove:Destroy()
end

export type PluginContextService = typeof(PluginContextService)

return PluginContextService