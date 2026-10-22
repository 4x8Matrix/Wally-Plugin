local CargoSemver = require(script.Parent.Parent.Packages.CargoSemver)

--[[
	The requirement that installs `version` and no other, given every version the registry has: `^version` when that
		already resolves to `version`, so the place keeps taking compatible fixes later, and `=version` when a newer
		compatible release would win, as it would for an older version chosen on purpose.
]]
return function(version: string, versions: { string }): string
	local readable, caret = pcall(CargoSemver.VersionReq.parse, `^{version}`)
	local parsed, chosen = pcall(CargoSemver.Version.parse, version)

	if not readable or not parsed then
		return `={version}`
	end

	for _, text in versions do
		local known, candidate = pcall(CargoSemver.Version.parse, text)

		if known and caret:matches(candidate) and candidate:cmp_precedence(chosen) == CargoSemver.Ordering.Greater then
			return `={version}`
		end
	end

	return `^{version}`
end
