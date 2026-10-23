local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local buildProjectContext = require(ReplicatedStorage.WallyPlugin.PluginUtilities.buildProjectContext)
local compileGlob = require(ReplicatedStorage.WallyPlugin.PluginUtilities.compileGlob)
local isPathIgnored = require(ReplicatedStorage.WallyPlugin.PluginUtilities.isPathIgnored)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function glob(pattern: string): (path: string) -> boolean
	return compileGlob(pattern).value
end

local function project(fields: { [string]: any }): any
	return {
		tree = {},
		emitLegacyScripts = fields.emitLegacyScripts,
		globIgnorePaths = fields.globIgnorePaths or {},
		syncRules = fields.syncRules or {},
	}
end

local function parentContext(): any
	return {
		syncRules = { { matches = glob("**/*.rojo"), use = "text" } },
		ignoreRules = { { folder = "", matches = glob("**/*.spec.lua"), negated = false } },
		emitLegacyScripts = false,
	}
end

describe("buildProjectContext", function()
	it("replaces the parent's sync rules with the project's, matched relative to the project's folder", function()
		local context = buildProjectContext(
			project({
				syncRules = {
					{ matches = glob("lib/*.dat"), excludes = glob("lib/b.*"), use = "text", suffix = ".dat" },
				},
			}),
			"src/sub",
			parentContext()
		)
		local rule = context.syncRules[1]

		expect(#context.syncRules).toBe(1)
		expect(rule.use).toBe("text")
		expect(rule.suffix).toBe(".dat")
		expect(rule.matches("src/sub/lib/a.dat")).toBe(true)
		expect(rule.matches("lib/a.dat")).toBe(false)
		expect(rule.matches("src/subway/lib/a.dat")).toBe(false)
		expect(rule.excludes("src/sub/lib/b.dat")).toBe(true)
		expect(rule.excludes("lib/b.dat")).toBe(false)
	end)

	it("matches a rule against `..` paths left raw, as Rojo strips the folder without normalising", function()
		local rule = buildProjectContext(
			project({ syncRules = { { matches = glob("../src/*.lua"), use = "text" } } }),
			"sub",
			parentContext()
		).syncRules[1]

		expect(rule.matches("sub/../src/b.lua")).toBe(true)
		expect(rule.excludes).toBe(nil)
	end)

	it("keeps the parent's ignore rules and appends the project's, relative to its folder", function()
		local context = buildProjectContext(
			project({ globIgnorePaths = { { matches = glob("src/inner.lua"), negated = false } } }),
			"subproject",
			parentContext()
		)

		expect(#context.ignoreRules).toBe(2)
		expect(context.ignoreRules[2].folder).toBe("subproject")
		expect(isPathIgnored(context.ignoreRules, "subproject/src/exclude.spec.lua")).toBe(true)
		expect(isPathIgnored(context.ignoreRules, "subproject/src/inner.lua")).toBe(true)
		expect(isPathIgnored(context.ignoreRules, "src/inner.lua")).toBe(false)
	end)

	it("leaves the parent context unchanged", function()
		local parent = parentContext()

		buildProjectContext(project({ globIgnorePaths = { { matches = glob("x"), negated = true } } }), "", parent)

		expect(#parent.ignoreRules).toBe(1)
		expect(#parent.syncRules).toBe(1)
	end)

	it("takes the project's emitLegacyScripts, and true when it gives none, never the parent's", function()
		expect(buildProjectContext(project({}), "", parentContext()).emitLegacyScripts).toBe(true)
		expect(buildProjectContext(project({ emitLegacyScripts = false }), "", parentContext()).emitLegacyScripts).toBe(
			false
		)
		expect(buildProjectContext(project({ emitLegacyScripts = true }), "", parentContext()).emitLegacyScripts).toBe(
			true
		)
	end)
end)
