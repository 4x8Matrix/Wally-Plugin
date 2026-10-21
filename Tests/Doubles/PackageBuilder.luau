local ReplicatedStorage = game:GetService("ReplicatedStorage")

local parsePackageId = require(ReplicatedStorage.WallyPlugin.PluginUtilities.parsePackageId)
local parsePackageReq = require(ReplicatedStorage.WallyPlugin.PluginUtilities.parsePackageReq)

local PackageBuilder = { }

PackageBuilder.Interface = { }
PackageBuilder.Prototype = { }

--[[
	Sets the package's realm; packages start shared, as in Wally's PackageBuilder.
]]
function PackageBuilder.Prototype.WithRealm(self: PackageBuilder, realm: string): PackageBuilder
	self.Built.package.realm = realm

	return self
end

--[[
	Adds a shared dependency under an alias.
]]
function PackageBuilder.Prototype.WithDependency(
	self: PackageBuilder,
	alias: string,
	requirement: string
): PackageBuilder
	self.Built.dependencies[alias] = assert(parsePackageReq(requirement).value, `invalid requirement {requirement}`)

	return self
end

--[[
	Adds a server dependency under an alias.
]]
function PackageBuilder.Prototype.WithServerDependency(
	self: PackageBuilder,
	alias: string,
	requirement: string
): PackageBuilder
	self.Built.serverDependencies[alias] =
		assert(parsePackageReq(requirement).value, `invalid requirement {requirement}`)

	return self
end

--[[
	Returns the manifest built so far.
]]
function PackageBuilder.Prototype.Manifest(self: PackageBuilder)
	return self.Built
end

--[[
	Starts a package from its id, `scope/name@version`.
]]
function PackageBuilder.Interface.new(identity: string): PackageBuilder
	local id = assert(parsePackageId(identity).value, `invalid id {identity}`)

	return setmetatable({
		Built = {
			package = { name = id.name, version = id.version, realm = "shared", registry = "" },
			dependencies = { },
			serverDependencies = { },
			devDependencies = { }
		}
	}, {
		__index = PackageBuilder.Prototype
	})
end

export type PackageBuilder = typeof(PackageBuilder.Prototype)

return PackageBuilder.Interface
