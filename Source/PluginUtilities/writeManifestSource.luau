local Types = require(script.Parent.Types)

local HEADER = "-- Written by the Wally plugin from the installed requests; rewritten on every install and removal."
local SECTIONS = { "Dependencies", "ServerDependencies" }

--[[
	Writes the source of `Manifest_DO_NOT_MODIFY`: a table literal with sorted keys, so the same requests always give
		the same text and Studio shows no change when nothing changed.
]]
return function(manifest: Types.PlaceManifest): string
	local lines = { HEADER, "return {", `\tFormatVersion = {manifest.FormatVersion}` }

	for _, section in SECTIONS do
		local entries = manifest[section] or { }
		local aliases = { }

		for alias in entries do
			table.insert(aliases, alias)
		end

		table.sort(aliases)

		if #aliases == 0 then
			continue
		end

		lines[#lines] ..= ","

		table.insert(lines, "\t" .. section .. " = {")

		for index, alias in aliases do
			local line = `\t\t[{string.format("%q", alias)}] = {string.format("%q", entries[alias])}`

			table.insert(lines, if index < #aliases then line .. "," else line)
		end

		table.insert(lines, "\t}")
	end

	table.insert(lines, "}")

	return table.concat(lines, "\n") .. "\n"
end
