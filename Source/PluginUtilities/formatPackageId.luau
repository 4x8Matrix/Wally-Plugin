local Types = require(script.Parent.Types)

--[[
	Prints a package id as Wally does: `scope/name@version`, the version with its prerelease and build metadata.
]]
return function(id: { name: Types.PackageName, version: any }): string
	return `{id.name.scope}/{id.name.name}@{tostring(id.version)}`
end
