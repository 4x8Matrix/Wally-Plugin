local function isNameless(component: string?): boolean
	return component == "" or component == "."
end

--[[
	The rest of a `/`-joined path below `prefix`, as Rojo 7.7.1 hands a path to a sync rule or ignore glob: Rust's
		`strip_prefix`, which compares components and skips empty and `.` ones, then `as_path`, which trims empty and
		`.` components from the ends of the rest but keeps them in its middle. Nothing for a path outside `prefix`;
		`""` is the root, a prefix of every path.
]]
return function(path: string, prefix: string): string?
	local components = string.split(path, "/")
	local first = 1
	local last = #components

	for _, expected in string.split(prefix, "/") do
		if isNameless(expected) then
			continue
		end

		while isNameless(components[first]) do
			first += 1
		end

		if components[first] ~= expected then
			return
		end

		first += 1
	end

	while first <= last and isNameless(components[first]) do
		first += 1
	end

	while last >= first and isNameless(components[last]) do
		last -= 1
	end

	return table.concat(components, "/", first, last)
end
