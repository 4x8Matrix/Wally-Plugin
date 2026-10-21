local Types = require(script.Parent.Types)

local SECTIONS = { Dependencies = true, ServerDependencies = true }

local function unreadable(reason: string): Types.Result<Types.PlaceManifest>
	return { ok = false, error = { kind = "ManifestUnreadable", message = reason } }
end

local function readQuoted(line: string, start: number): (string?, number)
	if string.sub(line, start, start) ~= '"' then
		return nil, start
	end

	local characters = { }
	local position = start + 1

	while position <= #line do
		local character = string.sub(line, position, position)

		if character == '"' then
			return table.concat(characters), position + 1
		end

		if character == "\\" then
			position += 1
			character = string.sub(line, position, position)

			if character ~= '"' and character ~= "\\" then
				return nil, position
			end
		end

		table.insert(characters, character)

		position += 1
	end

	return nil, position
end

local function readEntry(line: string): (string?, string?, boolean?)
	if string.sub(line, 1, 3) ~= "\t\t[" then
		return
	end

	local alias, afterAlias = readQuoted(line, 4)

	if not alias or string.sub(line, afterAlias, afterAlias + 3) ~= "] = " then
		return
	end

	local requirement, afterRequirement = readQuoted(line, afterAlias + 4)
	local rest = string.sub(line, afterRequirement)

	if not requirement or (rest ~= "" and rest ~= ",") then
		return
	end

	return alias, requirement, rest == ","
end

--[[
	Reads `Manifest_DO_NOT_MODIFY` as data, so no code in the place is ever run: a comment line, then the table shape
		`writeManifestSource` writes, with its sections and entries in any order. Strings may hold `\"` and `\\`
		escapes only; anything else is refused.
]]
return function(source: string): Types.Result<Types.PlaceManifest>
	local lines = string.split(source, "\n")
	local lastLine = table.remove(lines)
	local version, versionComma = string.match(lines[3] or "", "^\tFormatVersion = (%d+)(,?)$")
	local manifest = { FormatVersion = tonumber(version) }
	local position = 4
	local hasMore = versionComma == ","

	if lastLine ~= "" then
		return unreadable("the text does not end with a newline")
	end

	if not string.match(lines[1] or "", "^%-%-") or lines[2] ~= "return {" then
		return unreadable("the text is not a manifest table")
	end

	if not version then
		return unreadable("FormatVersion is missing")
	end

	while hasMore do
		local key = string.match(lines[position] or "", "^\t(%a+) = {$")

		if not key or not SECTIONS[key] or manifest[key] then
			return unreadable(`line {position} is not a known, unrepeated section`)
		end

		local entries = { }

		manifest[key] = entries
		position += 1

		repeat
			local alias, requirement, hasComma = readEntry(lines[position] or "")

			if not alias or entries[alias] then
				return unreadable(`line {position} is not a new entry`)
			end

			entries[alias] = requirement
			position += 1
		until not hasComma

		local closer = lines[position]

		if closer ~= "\t}" and closer ~= "\t}," then
			return unreadable(`line {position} does not close the section`)
		end

		hasMore = closer == "\t},"
		position += 1
	end

	if lines[position] ~= "}" or position ~= #lines then
		return unreadable("the text does not end with the closing brace")
	end

	return { ok = true, value = manifest }
end
