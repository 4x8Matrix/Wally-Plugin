local Selection = game:GetService("Selection")

local Console = require(script.Parent.Parent.Packages.Console)
local Promise = require(script.Parent.Parent.Packages.Promise)
local Trove = require(script.Parent.Parent.Packages.Trove)

local PluginContext = require(script.Parent.Parent.PluginContext)

local PluginPackageService = require(script.Parent.PluginPackageService)
local PluginStyleguideService = require(script.Parent.PluginStyleguideService)

local PluginContextService = { }

PluginContextService.Trove = Trove.new()
PluginContextService.Reporter = Console.new(`🔎 {script.Name}`)

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

function PluginContextService.OnStart(self: PluginContextService)
	self.DownloadContextMenu.Name = `PluginContext<"{PluginContext.PluginSettings.DownloadContextMenu.Title}">`
	self.DownloadContextMenu.Parent = PluginContext.Plugin

	-- Download a package into the _Index folder, create a stub module in the Server Packages folder
	self.Trove:Add(self.DownloadAsServerDependency.Triggered:Connect(function()
		local selectedPackageObject = PluginPackageService:GetSelectedPackage()

		PluginPackageService:AddPackageToIndex(selectedPackageObject)
		PluginPackageService:AddPackageToServerPackages(selectedPackageObject)
	end))

	-- Download a package into the _Index folder, create a stub module in the Shared Packages folder
	self.Trove:Add(self.DownloadAsSharedDependency.Triggered:Connect(function()
		local selectedPackageObject = PluginPackageService:GetSelectedPackage()

		PluginPackageService:AddPackageToIndex(selectedPackageObject)
		PluginPackageService:AddPackageToSharedPackages(selectedPackageObject)
	end))

	--[[
		Download a package into the _Index folder, create a stub module in the workspace and selecting it.
		
		The goal behind this is to allow players to parent modules to whereever they want too, then those modules will
			refer to the module in _Index.
	]]
	self.Trove:Add(self.DownloadAsModule.Triggered:Connect(function()
		local selectedPackageObject = PluginPackageService:GetSelectedPackage()

		PluginPackageService:AddPackageToIndex(selectedPackageObject)

		local packageStub = selectedPackageObject:CreateStubModule()

		packageStub.Name = PluginStyleguideService:ToPascalCase(selectedPackageObject.Name)
		packageStub.Parent = workspace
		
		Selection:Set({ packageStub })
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