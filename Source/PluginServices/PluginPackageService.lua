local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Console = require(script.Parent.Parent.Packages.Console)

local VirtualPackage = require(script.Parent.Parent.PluginClasses.VirtualPackage)

local PluginStyleguideService = require(script.Parent.Parent.PluginServices.PluginStyleguideService)

local PluginPackageService = { }

PluginPackageService.Reporter = Console.new(`🍃 {script.Name}`)

PluginPackageService.SelectedPackage = { } :: VirtualPackage.VirtualPackage

PluginPackageService.SharedPackages = (newproxy()) :: Folder
PluginPackageService.PackageIndex = (newproxy()) :: Folder

function PluginPackageService.AddPackageToIndex(self: PluginPackageService, package: VirtualPackage.VirtualPackage)
	local fullPackageName = VirtualPackage.into({
		Scope = package.Scope,
		Name = package.Name,
		Version = package.Version
	})

	-- VirtualPackage.CreateStubModule can create invalid paths if `.` is found within the package name.
	fullPackageName = string.gsub(fullPackageName, "%.", "-")

	if self.PackageIndex:FindFirstChild(fullPackageName) then
		return
	end

	package:DownloadAsync():andThen(function(module: ModuleScript)
		local packageFolder = Instance.new("Folder")

		packageFolder.Name = fullPackageName
		packageFolder.Parent = self.PackageIndex

		module.Name = package.Name
		module.Parent = packageFolder

		package:FetchDependenciesAsync():andThen(function(dependencyList: { VirtualPackage.VirtualPackage })
			for dependencyName, dependencyPackage in dependencyList do
				self:AddPackageToIndex(dependencyPackage)

				local stubModule = dependencyPackage:CreateStubModule()

				stubModule.Name = dependencyName
				stubModule.Parent = packageFolder
			end
		end):catch(warn):await()
	end):catch(warn):await()
end

function PluginPackageService.AddPackageToShared(self: PluginPackageService, package: VirtualPackage.VirtualPackage)
	local stubModule = package:CreateStubModule()

	stubModule.Name = PluginStyleguideService:ToPascalCase(package.Name)
	stubModule.Parent = self.SharedPackages
end

function PluginPackageService.SetSelectedPackage(self: PluginPackageService, package: VirtualPackage.VirtualPackage)
	self.SelectedPackage = package
end

function PluginPackageService.GetSelectedPackage(self: PluginPackageService)
	return self.SelectedPackage
end

function PluginPackageService.OnStart(self: PluginPackageService)
	self.SharedPackages = CollectionService:GetTagged("WallySharedPackages")[1]
	self.PackageIndex = self.SharedPackages and self.SharedPackages:FindFirstChild("_Index")

	if not self.SharedPackages then
		self.SharedPackages = Instance.new("Folder")

		self.SharedPackages.Name = "Packages"
		self.SharedPackages.Parent = ReplicatedStorage

		CollectionService:AddTag(self.SharedPackages, "Packages")
	end

	if not self.PackageIndex then
		self.PackageIndex = Instance.new("Folder")

		self.PackageIndex.Name = "_Index"
		self.PackageIndex.Parent = self.SharedPackages
	end
end

export type PluginPackageService = typeof(PluginPackageService)

return PluginPackageService