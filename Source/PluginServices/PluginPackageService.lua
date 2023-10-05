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

--[[
	Main function for adding a package to either ServerPackageIndex or SharedPackageIndex, this function reads the "realm"
		metadata to know where to place the package.

	This function also downloads the relevant dependencies, and creates the stub modules required for the package to function.
]]
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

--[[
	Adds a package stub module to the ServerPackages folder.
	
	If the package's realm is set to "server", the package will be downloaded to the server, and the stub module will be parented
		to the SharedPackages folder.

	If the package's realm is set to "shared", the package will be downloaded to the shared packages, but the stub module will
		be parented to the SharedPackages folder.
]]
function PluginPackageService.AddPackageToSharedPackages(self: PluginPackageService, package: VirtualPackage.VirtualPackage)
	local stubModule = package:CreateStubModule()

	stubModule.Name = PluginStyleguideService:ToPascalCase(package.Name)
	stubModule.Parent = self.SharedPackages
end

--[[
	Adds a package stub module to the ServerPackages folder.
	
	If the package's realm is set to "server", the package will be downloaded to the server, and the stub module will be parented
		to the ServerPackages folder.

	If the package's realm is set to "shared", the package will be downloaded to the shared packages, but the stub module will
		be parented to the SeverPackages folder.
]]
function PluginPackageService.AddPackageToServerPackages(self: PluginPackageService, package: VirtualPackage.VirtualPackage)
	local stubModule = package:CreateStubModule()

	stubModule.Name = PluginStyleguideService:ToPascalCase(package.Name)
	stubModule.Parent = self.ServerPackages
end

--[[
	Set the selected package, called from the `PluginInterfaceService` module when a developer clicks on a package entry
]]
function PluginPackageService.SetSelectedPackage(self: PluginPackageService, package: VirtualPackage.VirtualPackage)
	self.SelectedPackage = package
end

--[[
	Return the selected package, selected packages are set when the player interacts with a package on the package list.
]]
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