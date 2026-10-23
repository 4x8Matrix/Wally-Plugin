local Types = require(script.Parent.Types)

--[[
	The failed BuildResult for a refusal: `message`, raised by the file at `path`, or `""` for a caller that adds the
		file it read.
]]
return function(path: string, message: string): Types.BuildResult<any>
	return { ok = false, error = { path = path, message = message } }
end
