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

function PluginContextService.ShowDownloadContextMenuAsync(self: PluginContextService)
	return Promise.new(function(resolve)
		resolve(self.DownloadContextMenu:ShowAsync())
	end)
end

function PluginContextService.OnStart(self: PluginContextService)
	self.DownloadContextMenu.Name = `PluginContext<"{PluginContext.PluginSettings.DownloadContextMenu.Title}">`
	self.DownloadContextMenu.Parent = PluginContext.Plugin

	self.Trove:Add(self.DownloadAsServerDependency.Triggered:Connect(function()
		local selectedPackageObject = PluginPackageService:GetSelectedPackage()

		PluginPackageService:AddPackageToIndex(selectedPackageObject)
		PluginPackageService:AddPackageToServerPackages(selectedPackageObject)
	end))

	self.Trove:Add(self.DownloadAsSharedDependency.Triggered:Connect(function()
		local selectedPackageObject = PluginPackageService:GetSelectedPackage()

		PluginPackageService:AddPackageToIndex(selectedPackageObject)
		PluginPackageService:AddPackageToSharedPackages(selectedPackageObject)
	end))

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