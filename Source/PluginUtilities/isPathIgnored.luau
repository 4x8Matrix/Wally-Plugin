local Types = require(script.Parent.Types)

local stripPathPrefix = require(script.Parent.stripPathPrefix)

--[[
	Whether Rojo 7.7.1 leaves a directory entry out (R4.4): the last ignore rule whose glob matches the path,
		taken relative to the rule's folder as Rojo's `strip_prefix` takes it, decides, and a negated one keeps it.
		A path outside a rule's folder never matches the rule, and a path no rule matches is kept.
]]
return function(rules: { Types.IgnoreRule }, path: string): boolean
	local ignored = false

	for _, rule in rules do
		local relative = stripPathPrefix(path, rule.folder)

		if relative and rule.matches(relative) then
			ignored = not rule.negated
		end
	end

	return ignored
end
