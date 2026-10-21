local Types = require(script.Parent.Types)

local formatVersionReq = require(script.Parent.formatVersionReq)

--[[
	Prints a package requirement as Wally does: `scope/name@` and the requirement in semver 0.11's printed form.
]]
return function(request: Types.PackageReq): string
	return `{request.name.scope}/{request.name.name}@{formatVersionReq(request.versionReq)}`
end
