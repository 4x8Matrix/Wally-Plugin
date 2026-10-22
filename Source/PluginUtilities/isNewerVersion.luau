local CargoSemver = require(script.Parent.Parent.Packages.CargoSemver)

--[[
	Whether `version` comes after `than` by semver precedence. A version semver cannot read is never newer, nor older.
]]
return function(version: string, than: string): boolean
	local readable, left = pcall(CargoSemver.Version.parse, version)
	local comparable, right = pcall(CargoSemver.Version.parse, than)

	return readable and comparable and left:cmp_precedence(right) == CargoSemver.Ordering.Greater
end
