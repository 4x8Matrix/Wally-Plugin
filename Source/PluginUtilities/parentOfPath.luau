local function trimNameless(components: { string })
	while components[#components] == "" or components[#components] == "." do
		table.remove(components)
	end
end

--[[
	The folder a `/`-joined path sits in, as Rust's `parent` gives it: the last component dropped, with the empty and
		`.` components left at the end trimmed, `""` being the root.
]]
return function(path: string): string
	local components = string.split(path, "/")

	trimNameless(components)
	table.remove(components)
	trimNameless(components)

	return table.concat(components, "/")
end
