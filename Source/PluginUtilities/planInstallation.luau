local Types = require(script.Parent.Types)

local packageFolderName = require(script.Parent.packageFolderName)

local INDEX_NAME = "_Plugin_Index"
local LINK_ORDER = { "shared", "server", "dev" }
local PACKAGES_PATHS = { shared = "game.ReplicatedStorage.Packages", server = "game.ServerStorage.Packages" }

local function linkSource(resolve: Types.Resolve, fromRealm: Types.Realm, isRoot: boolean, id: string): string?
	local packageId = resolve.activated[id]
	local folder = packageFolderName(packageId)
	local name = packageId.name.name
	local realm = resolve.metadata[id].originRealm

	if realm == fromRealm and isRoot then
		return `return require(script.Parent.{INDEX_NAME}["{folder}"]["{name}"])\n`
	end

	if realm == fromRealm then
		return `return require(script.Parent.Parent["{folder}"]["{name}"])\n`
	end

	if realm == "dev" then
		return
	end

	return `return require({PACKAGES_PATHS[realm]}.{INDEX_NAME}["{folder}"]["{name}"])\n`
end

--[[
	Port of Wally 0.3.2's `installation.rs` as data: for each realm, the package folders `_Plugin_Index` must hold, the
		root links its `Packages` must hold, and the links inside each package folder.
]]
return function(resolve: Types.Resolve, rootId: string): Types.Result<Types.InstallPlan>
	local plan = {
		shared = { packages = { }, rootLinks = { }, packageLinks = { } },
		server = { packages = { }, rootLinks = { }, packageLinks = { } },
		dev = { packages = { }, rootLinks = { }, packageLinks = { } }
	}
	local dependenciesByRealm =
		{ shared = resolve.sharedDependencies, server = resolve.serverDependencies, dev = resolve.devDependencies }

	for id, packageId in resolve.activated do
		local isRoot = id == rootId
		local realm = resolve.metadata[id].originRealm
		local folder = packageFolderName(packageId)

		if not isRoot then
			plan[realm].packages[folder] = id
			plan[realm].packageLinks[folder] = { }
		end

		for _, tableRealm in LINK_ORDER do
			for alias, dependencyId in dependenciesByRealm[tableRealm][id] or { } do
				local fromRealm = if isRoot then tableRealm else realm
				local source = linkSource(resolve, fromRealm, isRoot, dependencyId)

				if not source then
					return {
						ok = false,
						error = {
							kind = "Conflict",
							message = "A dev dependency cannot be depended upon by a non-dev dependency",
							package = dependencyId
						}
					}
				end

				if isRoot then
					plan[tableRealm].rootLinks[alias] = source
				else
					plan[realm].packageLinks[folder][alias] = source
				end
			end
		end
	end

	return { ok = true, value = plan }
end
