local Types = require(script.Parent.Types)

local pickDefaultVersion = require(script.Parent.pickDefaultVersion)

--[[
	Reads the registry's `package-search` answer into result rows, each with the version the registry website offers
		by default and its description on one line, since rows show it on one. A package with no version to offer is
		left out.
]]
return function(packages: { any }): { Types.SearchResult }
	local results = {}

	for _, package in packages do
		local default = pickDefaultVersion(package.versions or {})
		local spaced = string.gsub(package.description or "", "%s+", " ")

		if default.ok then
			table.insert(results, {
				scope = package.scope,
				name = package.name,
				description = string.match(spaced, "^ ?(.-) ?$"),
				version = default.value,
			})
		end
	end

	return results
end
