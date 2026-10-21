local ReplicatedStorage = game:GetService("ReplicatedStorage")

local formatPackageName = require(ReplicatedStorage.WallyPlugin.PluginUtilities.formatPackageName)

local InMemoryRegistry = { }

InMemoryRegistry.Interface = { }
InMemoryRegistry.Prototype = { }

--[[
	Publishes a package; publishing the same name again adds a version.
]]
function InMemoryRegistry.Prototype.Publish(self: InMemoryRegistry, builder: any)
	local manifest = builder:Manifest()
	local key = formatPackageName(manifest.package.name)

	self.Entries[key] = self.Entries[key] or { }

	table.insert(self.Entries[key], manifest)
end

--[[
	Returns every published version of a package.
]]
function InMemoryRegistry.Prototype.Manifests(self: InMemoryRegistry, scope: string, name: string)
	return self.Entries[`{scope}/{name}`] or { }
end

--[[
	Returns a PackageSource whose query lists the published versions matching a request, and an empty list for a
		package nobody published, as Wally's InMemoryRegistrySource does.
]]
function InMemoryRegistry.Prototype.Source(self: InMemoryRegistry)
	return {
		query = function(request)
			local matching = { }

			for _, manifest in self.Entries[formatPackageName(request.name)] or { } do
				if request.versionReq:matches(manifest.package.version) then
					table.insert(matching, manifest)
				end
			end

			return { ok = true, value = matching }
		end
	}
end

--[[
	Creates an empty registry.
]]
function InMemoryRegistry.Interface.new(): InMemoryRegistry
	return setmetatable({ Entries = { } }, {
		__index = InMemoryRegistry.Prototype
	})
end

export type InMemoryRegistry = typeof(InMemoryRegistry.Prototype)

return InMemoryRegistry.Interface
