local Types = require(script.Parent.Types)

local buildError = require(script.Parent.buildError)

local MISSING_INFORMATION = 'Instance "%s" is missing some required information. One of the following must be true: '
	.. "$className must be set to the name of a Roblox class; $path must be set to a path of an instance; "
	.. "the instance must be a known service, like ReplicatedStorage"

--[[
	Chooses a project node's class as Rojo 7.7.1's `snapshot_project_node` does (R2.3), from its `$className`, the
		class of what its `$path` made and the class inferred from its parent, in the order of Rojo's match arms:
		`$className` when the path gave none; the path's class, or the inferred one over a Folder; the inferred one
		alone; `$className` over a Folder path, any other path class refused; then, with no class at all, nothing
		for an optional path and a refusal otherwise. The error names no path; the caller adds the project file.
]]
return function(
	name: string,
	className: string?,
	pathClass: string?,
	inferred: string?,
	path: Types.ProjectPath?
): Types.BuildResult<string?>
	if className and not pathClass then
		return { ok = true, value = className }
	end

	if pathClass and not className then
		return { ok = true, value = if inferred and pathClass == "Folder" then inferred else pathClass }
	end

	if inferred and not className then
		return { ok = true, value = inferred }
	end

	if className and pathClass == "Folder" then
		return { ok = true, value = className }
	end

	if className and path then
		return buildError(
			"",
			`ClassName for Instance "{name}" was specified in both the project file (as "{className}") and from the `
				.. `filesystem (as "{pathClass}"). If $className and $path are both set, $path must refer to a Folder. `
				.. `Filesystem path: {path.path}`
		)
	end

	if path and path.optional then
		return { ok = true }
	end

	if path then
		return buildError("", `$path "{path.path}" could not be turned into an instance`)
	end

	return buildError("", string.format(MISSING_INFORMATION, name))
end
