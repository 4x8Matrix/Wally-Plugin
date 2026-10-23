--[[
	Joins a directory's path and the name of one of its entries into the entry's path, `""` being the root.
]]
return function(directory: string, name: string): string
	return if directory == "" then name else `{directory}/{name}`
end
