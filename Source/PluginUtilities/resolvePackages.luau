local CargoSemver = require(script.Parent.Parent.Packages.CargoSemver)

local Types = require(script.Parent.Types)

local formatPackageId = require(script.Parent.formatPackageId)
local formatPackageName = require(script.Parent.formatPackageName)
local formatPackageReq = require(script.Parent.formatPackageReq)

local REALM_TITLES = { shared = "Shared", server = "Server", dev = "Dev" }

local function isGreater(left: any, right: any): boolean
	return left:cmp_precedence(right) == CargoSemver.Ordering.Greater
end

local function isCompatible(left: any, right: any): boolean
	if left:cmp_precedence(right) == CargoSemver.Ordering.Equal then
		return true
	end

	if left.major == 0 and right.major == 0 then
		return left.minor == right.minor
	end

	return left.major == right.major
end

--[[
	Port of Wally 0.3.2's `resolution.rs` `resolve`: settles every request of the root manifest, and every dependency
		of every chosen package, into one graph before anything is downloaded. The first failure stops it, as in Wally.
]]
return function(
	root: Types.Manifest,
	tryToUse: { [string]: true },
	source: Types.PackageSource
): Types.Result<Types.Resolve>
	local rootId = formatPackageId(root.package)
	local resolve = {
		activated = { [rootId] = { name = root.package.name, version = root.package.version } },
		metadata = { [rootId] = { realm = root.package.realm, originRealm = root.package.realm } },
		sharedDependencies = { },
		serverDependencies = { },
		devDependencies = { }
	}
	local dependenciesByRealm =
		{ shared = resolve.sharedDependencies, server = resolve.serverDependencies, dev = resolve.devDependencies }
	local queue = { }

	local function enqueue(
		sourceId: string,
		requestRealm: Types.Realm,
		originRealm: Types.Realm,
		dependencies: { [string]: Types.PackageReq }
	)
		local aliases = { }

		for alias in dependencies do
			table.insert(aliases, alias)
		end

		table.sort(aliases)

		for _, alias in aliases do
			table.insert(queue, {
				sourceId = sourceId,
				requestRealm = requestRealm,
				originRealm = originRealm,
				alias = alias,
				request = dependencies[alias]
			})
		end
	end

	local function activate(sourceId: string, alias: string, realm: Types.Realm, packageId: Types.PackageId)
		local id = formatPackageId(packageId)
		local dependencies = dependenciesByRealm[realm]

		resolve.activated[id] = packageId
		dependencies[sourceId] = dependencies[sourceId] or { }
		dependencies[sourceId][alias] = id
	end

	enqueue(rootId, "shared", "shared", root.dependencies)
	enqueue(rootId, "server", "server", root.serverDependencies)
	enqueue(rootId, "dev", "dev", root.devDependencies)

	while #queue > 0 do
		local request = table.remove(queue, 1)
		local requestName = formatPackageName(request.request.name)
		local requestText = formatPackageReq(request.request)
		local realmTitle = REALM_TITLES[request.requestRealm]
		local matching = { }
		local reused

		for _, packageId in resolve.activated do
			if formatPackageName(packageId.name) == requestName then
				table.insert(matching, packageId)
			end
		end

		table.sort(matching, function(left, right)
			return isGreater(left.version, right.version)
		end)

		for _, packageId in matching do
			if request.request.versionReq:matches(packageId.version) then
				reused = packageId

				break
			end
		end

		if reused then
			local metadata = resolve.metadata[formatPackageId(reused)]

			if metadata.originRealm == "shared" or request.originRealm == "shared" then
				metadata.originRealm = "shared"
			elseif metadata.originRealm == "server" or request.originRealm == "server" then
				metadata.originRealm = "server"
			end

			activate(request.sourceId, request.alias, metadata.originRealm, reused)

			continue
		end

		local queried = source.query(request.request)

		if not queried.ok and queried.error.kind == "PackageNotFound" then
			return {
				ok = false,
				error = {
					kind = "PackageNotFound",
					message = `Failed to find a source for {requestText}`,
					package = requestText
				}
			}
		end

		if not queried.ok then
			return queried
		end

		local candidates = table.clone(queried.value)
		local conflicting = { }
		local chosen

		table.sort(candidates, function(left, right)
			local leftUsed = tryToUse[formatPackageId(left.package)] == true
			local rightUsed = tryToUse[formatPackageId(right.package)] == true

			if leftUsed ~= rightUsed then
				return leftUsed
			end

			return isGreater(left.package.version, right.package.version)
		end)

		for _, candidate in candidates do
			local valid = request.requestRealm ~= "shared" or candidate.package.realm == "shared"
			local conflicts = false

			if not valid then
				continue
			end

			for _, activated in matching do
				conflicts = conflicts or isCompatible(candidate.package.version, activated.version)
			end

			if conflicts then
				table.insert(conflicting, formatPackageId(candidate.package))

				continue
			end

			chosen = candidate

			break
		end

		if not chosen and #conflicting == 0 then
			return {
				ok = false,
				error = {
					kind = "NoMatchingVersion",
					message = `No packages were found that matched ({realmTitle}) {requestText}.\nAre you sure this is a {realmTitle} dependency?`,
					package = requestText
				}
			}
		end

		if not chosen then
			local previouslySelected = table.concat(conflicting, ", ")

			return {
				ok = false,
				error = {
					kind = "Conflict",
					message = `All possible candidates for package {requestText} ({realmTitle}) conflicted with other packages that were already installed. These packages were previously selected: {previouslySelected}`,
					package = requestText
				}
			}
		end

		local chosenId = { name = chosen.package.name, version = chosen.package.version }
		local chosenKey = formatPackageId(chosenId)

		activate(request.sourceId, request.alias, request.originRealm, chosenId)

		resolve.metadata[chosenKey] = { realm = chosen.package.realm, originRealm = request.originRealm }

		enqueue(chosenKey, "shared", request.originRealm, chosen.dependencies)
		enqueue(chosenKey, "server", request.originRealm, chosen.serverDependencies)
	end

	return { ok = true, value = resolve }
end
