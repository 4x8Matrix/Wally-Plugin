local Types = require(script.Parent.Types)

--[[
	Prints a package name as Wally does: `scope/name`.
]]
return function(name: Types.PackageName): string
	return `{name.scope}/{name.name}`
end
