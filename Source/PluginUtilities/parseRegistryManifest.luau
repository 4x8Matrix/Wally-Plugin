local CargoSemver = require(script.Parent.Parent.Packages.CargoSemver)

local Types = require(script.Parent.Types)

local parsePackageName = require(script.Parent.parsePackageName)
local parsePackageReq = require(script.Parent.parsePackageReq)

local REALMS = { shared = true, server = true, dev = true }
local TABLES = {
	dependencies = "dependencies",
	["server-dependencies"] = "serverDependencies",
	["dev-dependencies"] = "devDependencies"
}

local function readEntry(entry: { [string]: any }): Types.Manifest
	local package = entry.package
	local name = parsePackageName(package.name)
	local manifest = {
		package = {
			name = name.value,
			version = CargoSemver.Version.parse(package.version),
			realm = package.realm,
			registry = package.registry or ""
		},
		dependencies = { },
		serverDependencies = { },
		devDependencies = { }
	}

	assert(name.ok, `the package name '{package.name}' is not one Wally accepts`)
	assert(REALMS[package.realm], `the realm '{package.realm}' is not shared, server or dev`)

	for field, key in TABLES do
		for alias, text in entry[field] or { } do
			local request = parsePackageReq(text)

			assert(request.ok, `the dependency '{alias}' is not a package requirement`)

			manifest[key][alias] = request.value
		end
	end

	return manifest
end

--[[
	Turns one entry of `package-metadata/<scope>/<name>` into a Manifest. An entry of any other shape is refused as
		`RegistryUnavailable`, so a malformed registry answer never reaches the resolver.
]]
return function(entry: { [string]: any }): Types.Result<Types.Manifest>
	local read, manifest = pcall(readEntry, entry)

	if not read then
		return {
			ok = false,
			error = {
				kind = "RegistryUnavailable",
				message = `the registry returned a package entry the plugin cannot read: {manifest}`
			}
		}
	end

	return { ok = true, value = manifest }
end
