local Types = require(script.Parent.Types)

local WRONG_NUMBER_MESSAGE = "a package name is of the form SCOPE/NAME"

--[[
	Port of Wally's `package_name.rs`: parses `scope/name`, where each half holds only lowercase letters, digits and
		`-`, with 1 to 64 characters, and fails with Wally's own messages.
]]
return function(text: string): Types.Result<Types.PackageName>
	local scope, name = string.match(text, "^([^/]*)/(.*)$")

	if not scope then
		return { ok = false, error = { kind = "InvalidRequest", message = WRONG_NUMBER_MESSAGE } }
	end

	for _, part in { { kind = "scope", value = scope }, { kind = "name", value = name } } do
		local problem

		if not string.match(part.value, "^[a-z0-9%-]*$") then
			problem =
				`package {part.kind} '{part.value}' is invalid ({part.kind}s can only contain lowercase characters, digits and '-')`
		elseif #part.value == 0 then
			problem = `package {part.kind}s cannot be empty`
		elseif #part.value > 64 then
			problem = `package {part.kind}s cannot exceed 64 characters in length`
		end

		if problem then
			return { ok = false, error = { kind = "InvalidRequest", message = problem } }
		end
	end

	return { ok = true, value = { scope = scope, name = name } }
end
