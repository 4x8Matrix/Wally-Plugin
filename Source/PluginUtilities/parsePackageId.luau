local CargoSemver = require(script.Parent.Parent.Packages.CargoSemver)

local Types = require(script.Parent.Types)

local parsePackageName = require(script.Parent.parsePackageName)

local BAD_FORMAT_MESSAGE = "a package ID is of the form SCOPE/NAME@VERSION"

--[[
	Port of Wally's `package_id.rs`: parses `scope/name@version`, where the version is a full SemVer version.
]]
return function(text: string): Types.Result<Types.PackageId>
	local scope, rest = string.match(text, "^([^/]*)/(.*)$")
	local name, versionText = string.match(rest or "", "^([^@]*)@(.*)$")

	if not name then
		return { ok = false, error = { kind = "InvalidRequest", message = BAD_FORMAT_MESSAGE } }
	end

	local parsed, version = pcall(CargoSemver.Version.parse, versionText)

	if not parsed then
		return { ok = false, error = { kind = "InvalidRequest", message = `could not parse version: {version}` } }
	end

	local packageName = parsePackageName(`{scope}/{name}`)

	if not packageName.ok then
		return {
			ok = false,
			error = { kind = "InvalidRequest", message = `{BAD_FORMAT_MESSAGE}: {packageName.error.message}` }
		}
	end

	return { ok = true, value = { name = packageName.value, version = version } }
end
