local CargoSemver = require(script.Parent.Parent.Packages.CargoSemver)

local Types = require(script.Parent.Types)

--[[
	The version the registry website offers by default (wally-registry-frontend, package page, `page.tsx:321-333`):
		the newest version without a prerelease, else the newest prerelease. Versions that do not parse are skipped.
]]
return function(versions: { string }): Types.Result<string>
	local stable
	local prerelease

	for _, text in versions do
		local readable, version = pcall(CargoSemver.Version.parse, text)
		local isStable = readable and version.pre:is_empty()
		local best = if isStable then stable else prerelease

		if not readable or (best and version:cmp_precedence(best) ~= CargoSemver.Ordering.Greater) then
			continue
		end

		if isStable then
			stable = version
		else
			prerelease = version
		end
	end

	local chosen = stable or prerelease

	if not chosen then
		return {
			ok = false,
			error = { kind = "NoMatchingVersion", message = "the package has no published versions to choose from" }
		}
	end

	return { ok = true, value = tostring(chosen) }
end
