--[[
	The package id an `_Plugin_Index` folder name stands for, `scope_name@version` back to `scope/name@version`, or
		nil for any other name. The inverse of `packageFolderName`.
]]
return function(folderName: string): string?
	local scope, rest = string.match(folderName, "^([^_]+)_(.+)$")

	if not scope then
		return
	end

	return `{scope}/{rest}`
end
