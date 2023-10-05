local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Console = require(script.Parent.Parent.Packages.Console)

local VirtualPackage = require(script.Parent.Parent.PluginClasses.VirtualPackage)

local PluginStyleguideService = require(script.Parent.Parent.PluginServices.PluginStyleguideService)

local PluginPackageService = { }

PluginPackageService.Reporter = Console.new(`🍃 {script.Name}`)

PluginPackageService.SelectedPackage = { } :: VirtualPackage.VirtualPackage

PluginPackageService.SharedPackages = (newproxy()) :: Folder
PluginPackageService.SharedPackageIndex = (newproxy()) :: Folder

PluginPackageService.ServerPackages = (newproxy()) :: Folder
PluginPackageService.ServerPackageIndex = (newproxy()) :: Folder

function PluginPackageService.AddPackageToIndex(self: PluginPackageService, package: VirtualPackage.VirtualPackage)
	local packageRealm = package:FetchRealmAsync():expect()
	local contextPackageIndex = packageRealm == "server" and self.ServerPackageIndex
		or self.SharedPackageIndex

	local fullPackageName = VirtualPackage.into({
		Scope = package.Scope,
		Name = package.Name,
		Version = package.Version
	})

	-- VirtualPackage.CreateStubModule can create invalid paths if `.` is found within the package name.
	fullPackageName = string.gsub(fullPackageName, "%.", "-")

	if contextPackageIndex:FindFirstChild(fullPackageName) then
		return
	end

	package:DownloadAsync():andThen(function(module: ModuleScript)
		local packageFolder = Instance.new("Folder")

		packageFolder.Name = fullPackageName
		packageFolder.Parent = contextPackageIndex

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

function PluginPackageService.AddPackageToSharedPackages(self: PluginPackageService, package: VirtualPackage.VirtualPackage)
	local stubModule = package:CreateStubModule()

	stubModule.Name = PluginStyleguideService:ToPascalCase(package.Name)
	stubModule.Parent = self.SharedPackages
end

function PluginPackageService.AddPackageToServerPackages(self: PluginPackageService, package: VirtualPackage.VirtualPackage)
	local stubModule = package:CreateStubModule()

	stubModule.Name = PluginStyleguideService:ToPascalCase(package.Name)
	stubModule.Parent = self.ServerPackages
end

function PluginPackageService.SetSelectedPackage(self: PluginPackageService, package: VirtualPackage.VirtualPackage)
	self.SelectedPackage = package
end

function PluginPackageService.GetSelectedPackage(self: PluginPackageService)
	return self.SelectedPackage
end

function PluginPackageService.OnStart(self: PluginPackageService)
	self.SharedPackages = CollectionService:GetTagged("WallySharedPackages")[1]
	self.SharedPackageIndex = self.SharedPackages and self.SharedPackages:FindFirstChild("_Index")

	self.ServerPackages = CollectionService:GetTagged("WallyServerPackages")[1]
	self.ServerPackageIndex = self.ServerPackages and self.ServerPackages:FindFirstChild("_Index")

	if not self.SharedPackages then
		self.SharedPackages = Instance.new("Folder")

		self.SharedPackages.Name = "Packages"
		self.SharedPackages.Parent = ReplicatedStorage

		CollectionService:AddTag(self.SharedPackages, "WallySharedPackages")
	end

	if not self.SharedPackageIndex then
		self.SharedPackageIndex = Instance.new("Folder")

		self.SharedPackageIndex.Name = "_Index"
		self.SharedPackageIndex.Parent = self.SharedPackages
	end

	if not self.ServerPackages then
		self.ServerPackages = Instance.new("Folder")

		self.ServerPackages.Name = "Packages"
		self.ServerPackages.Parent = ServerStorage

		CollectionService:AddTag(self.ServerPackages, "WallyServerPackages")
	end

	if not self.ServerPackageIndex then
		self.ServerPackageIndex = Instance.new("Folder")

		self.ServerPackageIndex.Name = "_Index"
		self.ServerPackageIndex.Parent = self.ServerPackages
	end
end

export type PluginPackageService = typeof(PluginPackageService)

return PluginPackageService