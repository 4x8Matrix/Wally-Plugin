--[[
	Prints a cargo-semver VersionReq the way Wally's semver 0.11 prints one: each comparator expanded into explicit
		bounds, joined with ", ". Wally's messages show requirements in this form, and the registry stores dependency
		requirements in it.
]]
return function(versionReq: any): string
	local parts = { }

	for _, comparator in versionReq.comparators do
		local op = comparator.op
		local major = comparator.major
		local minor = comparator.minor
		local patch = comparator.patch
		local pre = if comparator.pre:is_empty() then "" else `-{tostring(comparator.pre)}`
		local lower = `{major}.{minor or 0}.{patch or 0}{pre}`

		if op == "=" and patch then
			table.insert(parts, `={lower}`)
		elseif (op == "=" or op == "~") and minor then
			table.insert(parts, `>={lower}`)
			table.insert(parts, `<{major}.{minor + 1}.0`)
		elseif op == "=" or (op == "~" and not minor) or (op == "^" and major > 0) then
			table.insert(parts, `>={lower}`)
			table.insert(parts, `<{major + 1}.0.0`)
		elseif op == ">" or op == ">=" or op == "<" then
			table.insert(parts, `{op}{lower}`)
		elseif op == "<=" and patch then
			table.insert(parts, `<={lower}`)
		elseif op == "<=" and minor then
			table.insert(parts, `<{major}.{minor + 1}.0`)
		elseif op == "<=" then
			table.insert(parts, `<{major + 1}.0.0`)
		elseif op == "^" and not minor then
			table.insert(parts, `>={lower}`)
			table.insert(parts, "<1.0.0")
		elseif op == "^" and (minor > 0 or not patch) then
			table.insert(parts, `>={lower}`)
			table.insert(parts, `<0.{minor + 1}.0`)
		elseif op == "^" then
			table.insert(parts, `>={lower}`)
			table.insert(parts, `<0.0.{patch + 1}`)
		elseif op == "*" and minor then
			table.insert(parts, `>={major}.{minor}.0`)
			table.insert(parts, `<{major}.{minor + 1}.0`)
		else
			table.insert(parts, `>={major}.0.0`)
			table.insert(parts, `<{major + 1}.0.0`)
		end
	end

	if #parts == 0 then
		return ">=0.0.0"
	end

	return table.concat(parts, ", ")
end
