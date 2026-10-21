local CargoSemver = require(script.Parent.Parent.Packages.CargoSemver)

local Types = require(script.Parent.Types)

local parsePackageName = require(script.Parent.parsePackageName)

local BAD_FORMAT_MESSAGE = "a package requirement is of the form SCOPE/NAME@VERSION_REQ"

--[[
	Port of Wally's `package_req.rs`: parses `scope/name@requirement`. A bare version means `^version`, as in Cargo.
		An empty or all-space requirement is refused, because semver would read it as a wildcard.
]]
return function(text: string): Types.Result<Types.PackageReq>
	local scope, rest = string.match(text, "^([^/]*)/(.*)$")
	local name, requirementText = string.match(rest or "", "^([^@]*)@(.*)$")

	if not name or string.match(requirementText, "^%s*$") then
		return { ok = false, error = { kind = "InvalidRequest", message = BAD_FORMAT_MESSAGE } }
	end

	local parsed, versionReq = pcall(CargoSemver.VersionReq.parse, requirementText)

	if not parsed then
		return {
			ok = false,
			error = { kind = "InvalidRequest", message = `could not parse version requirement: {versionReq}` }
		}
	end

	local packageName = parsePackageName(`{scope}/{name}`)

	if not packageName.ok then
		return {
			ok = false,
			error = { kind = "InvalidRequest", message = `{BAD_FORMAT_MESSAGE}: {packageName.error.message}` }
		}
	end

	return { ok = true, value = { name = packageName.value, versionReq = versionReq } }
end
