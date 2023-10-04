local Promise = require(script.Parent.Parent.Packages.Promise)

local PluginWallyApiService = require(script.Parent.Parent.PluginServices.PluginWallyApiService)
local PluginSerialiserService = require(script.Parent.Parent.PluginServices.PluginSerialiserService)

local VirtualPackage = { }

VirtualPackage.Interface = { }
VirtualPackage.Prototype = { }
VirtualPackage.Packages = { }

function VirtualPackage.Prototype.FetchDependenciesAsync(self: VirtualPackage)
	return Promise.new(function(resolve)
		if self.DependenciesFetched then
			resolve(self.DependencyList)
		end

		local packageMetaData = PluginWallyApiService:QueryPackageVersionMetadataAsync(
			self.Scope,
			self.Name,
			self.Version
		):expect()

		for dependencyName, fullDependencyName in packageMetaData.dependencies do
			local depdendencyInformation = VirtualPackage.Interface.parse(fullDependencyName)
			local dependency = VirtualPackage.Interface.from(
				depdendencyInformation.Scope,
				depdendencyInformation.Name,
				depdendencyInformation.Version
			)

			self.DependencyList[dependencyName] = dependency
		end

		self.DependenciesFetched = true

		resolve(self.DependencyList)
	end)
end

function VirtualPackage.Prototype.DownloadDependenciesAsync(self: VirtualPackage)
	local downloadPromise = { }
	
	for _, dependencyPackage in self.DependencyList do
		table.insert(downloadPromise, dependencyPackage:DownloadAsync())
	end

	return Promise.all(downloadPromise)
end

function VirtualPackage.Prototype.DownloadAsync(self: VirtualPackage)
	return Promise.new(function(resolve)
		if self.ModuleScript then
			resolve(self.ModuleScript)
		end

		local rawZipBuffer = PluginWallyApiService:DownloadPackageZipAsync(
			self.Scope,
			self.Name,
			self.Version
		):expect()

		self.ModuleScript = PluginSerialiserService:SerialiseZipIntoRobloxInstances(rawZipBuffer)
	
		resolve(self.ModuleScript)
	end)
end

function VirtualPackage.Prototype.CreateStubModule(self: VirtualPackage)
	if not self.ModuleScript then
		return warn(`Failed to create stub module for: '{self.Scope}/{self.Name}@{self.Version}'`)
	end

	local stubModule = Instance.new("ModuleScript")
	local moduleFullNameSplit = string.split(self.ModuleScript:GetFullName(), ".")
	local moduleSafeName = ""

	local serviceName = table.remove(moduleFullNameSplit, 1)
	local service = game:FindFirstChild(serviceName)

	for _, path in moduleFullNameSplit do
		moduleSafeName ..= `["{path}"]`
	end

	stubModule.Source = `return require(game:GetService("{service.ClassName}"){moduleSafeName})`

	return stubModule
end

--[[
	Package constructor, used to create new virtial packages. A virtual package represents a handle on a Package that may or may not have
	been downloaded.
]]
function VirtualPackage.Interface.new(packageScope: string, packageName: string, packageVersion: string): VirtualPackage
	local self = setmetatable({
		Scope = packageScope,
		Name = packageName,
		Version = packageVersion,

		ModuleScript = nil,

		DependencyList = { },

		DependenciesFetched = false,
	}, {
		__index = VirtualPackage.Prototype
	})

	VirtualPackage.Packages[VirtualPackage.Interface.into({
		Scope = packageScope,
		Name = packageName,
		Version = packageVersion
	})] = self

	return self
end

--[[
	Retrieve a package if it already exists, if a package doesn't already exist, then create one.
]]
function VirtualPackage.Interface.from(packageScope: string, packageName: string, packageVersion: string)
	local packageObject = VirtualPackage.Packages[VirtualPackage.Interface.into({
		Scope = packageScope,
		Name = packageName,
		Version = packageVersion
	})]
	
	if packageObject then
		return packageObject
	else
		return VirtualPackage.Interface.new(packageScope, packageName, packageVersion)
	end
end

--[[
	QoL function used for parsing full package names.

	Parses either:
		- "sleitnick/knit@1.5.3"
		- "evaera/promise@>=4.0.0, <5.0.0"
	
	Returns a table containing:
		- Scope, ex: "sleitnick"
		- Name, ex: "knit"

		- Patch, ex: 3
		- Minor, ex: 5
		- Major, ex: 1

		- Version, ex: 1.5.3
]]
function VirtualPackage.Interface.parse(fullPackageName: string)
	local packageInformation = { string.match(fullPackageName, "(.+)/(.+)@(%d+).(%d+).(%d+)") }

	if not packageInformation[1] then
		packageInformation = { string.match(fullPackageName, "(.+)/(.+)@>=(%d+).(%d+).(%d+)") }
	end

	if not packageInformation[1] then
		error(`Failed to parse: '{fullPackageName}'`)
	end

	return {
		Scope = packageInformation[1],
		Name = packageInformation[2],

		Patch = packageInformation[3],
		Minor = packageInformation[4],
		Major = packageInformation[5],

		Version = `{packageInformation[3]}.{packageInformation[4]}.{packageInformation[5]}`
	}
end

--[[
	QoL function used for parsing the result of `VirtualPackage.parse` back into a full package name
]]
function VirtualPackage.Interface.into(packageDetails: VirtualPackageInformation)
	return `{packageDetails.Scope}/{packageDetails.Name}@{packageDetails.Version}`
end

export type VirtualPackage = typeof(VirtualPackage.Prototype)
export type VirtualPackageInformation = {
	Scope: string,
	Name: string,

	Patch: string,
	Minor: string,
	Major: string,

	Version: string,
}

return VirtualPackage.Interface