local Types = require(script.Parent.Types)

--[[
	The index folder name Wally gives a package (`installation.rs` `package_id_file_name`): `scope_name@version`.
]]
return function(id: Types.PackageId): string
	return `{id.name.scope}_{id.name.name}@{tostring(id.version)}`
end
