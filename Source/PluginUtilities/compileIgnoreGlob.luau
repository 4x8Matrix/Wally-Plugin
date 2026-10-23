local Types = require(script.Parent.Types)

local compileGlob = require(script.Parent.compileGlob)

--[[
	Compiles a `globIgnorePaths` pattern as Rojo 7.7.1's IgnorableGlob does: one leading `!` is stripped and marks a
		negation, a leading `\!` loses its backslash and matches a literal `!`, and the rest compiles as a globset
		glob, which reads any other `!` literally. A pattern globset refuses fails in its words; the error names no
		path.
]]
return function(pattern: string): Types.BuildResult<Types.IgnoreGlob>
	local negated = string.sub(pattern, 1, 1) == "!"
	local escaped = string.sub(pattern, 1, 2) == "\\!"
	local body = if negated or escaped then string.sub(pattern, 2) else pattern
	local compiled = compileGlob(body)

	if not compiled.ok then
		return compiled
	end

	return { ok = true, value = { matches = compiled.value, negated = negated } }
end
