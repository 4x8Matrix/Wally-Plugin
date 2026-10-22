local CargoSemver = require(script.Parent.Parent.Packages.CargoSemver)

--[[
	Returns the versions newest first by semver precedence, as the version picker lists them. A version semver cannot
		read is left out.
]]
return function(versions: { string }): { string }
	local parsed = {}
	local sorted = {}

	for _, text in versions do
		local readable, version = pcall(CargoSemver.Version.parse, text)

		if readable then
			table.insert(parsed, { text = text, version = version })
		end
	end

	table.sort(parsed, function(left, right)
		return left.version:cmp_precedence(right.version) == CargoSemver.Ordering.Greater
	end)

	for _, entry in parsed do
		table.insert(sorted, entry.text)
	end

	return sorted
end
