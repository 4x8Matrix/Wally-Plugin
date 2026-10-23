local Types = require(script.Parent.Types)

local stripPathPrefix = require(script.Parent.stripPathPrefix)

--[[
	Wraps a glob written relative to `folder` so it takes a path from the zip root, as Rojo's SyncRule matches the
		path stripped of its base path, and never matches a path outside the folder.
]]
local function relativeTo(folder: string, matches: (path: string) -> boolean): (path: string) -> boolean
	return function(path: string): boolean
		local relative = stripPathPrefix(path, folder)

		return if relative then matches(relative) else false
	end
end

--[[
	The context a project's tree is built in, as Rojo 7.7.1's `snapshot_project` makes it from the one it was reached
		in (R2.7): the parent's sync rules dropped for the project's own, matched relative to its folder; the
		parent's ignore rules kept and the project's appended, relative to its folder; and the project's
		emitLegacyScripts, true when it gives none. The parent context is left as it was.
]]
return function(project: Types.ProjectFile, folder: string, context: Types.SnapshotContext): Types.SnapshotContext
	local syncRules = {}
	local ignoreRules = table.clone(context.ignoreRules)

	for _, rule in project.syncRules do
		table.insert(syncRules, {
			matches = relativeTo(folder, rule.matches),
			excludes = if rule.excludes then relativeTo(folder, rule.excludes) else nil,
			use = rule.use,
			suffix = rule.suffix,
		})
	end

	for _, glob in project.globIgnorePaths do
		table.insert(ignoreRules, { folder = folder, matches = glob.matches, negated = glob.negated })
	end

	return { syncRules = syncRules, ignoreRules = ignoreRules, emitLegacyScripts = project.emitLegacyScripts ~= false }
end
