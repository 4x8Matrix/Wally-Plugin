local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local compileGlob = require(ReplicatedStorage.WallyPlugin.PluginUtilities.compileGlob)
local isPathIgnored = require(ReplicatedStorage.WallyPlugin.PluginUtilities.isPathIgnored)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function rule(folder: string, pattern: string, negated: boolean?)
	return { folder = folder, matches = compileGlob(pattern).value, negated = negated or false }
end

describe("isPathIgnored", function()
	it("keeps a path no rule matches", function()
		expect(isPathIgnored({}, "src/a.lua")).toBe(false)
		expect(isPathIgnored({ rule("", "**/*.txt") }, "src/a.lua")).toBe(false)
	end)

	it("ignores a path a rule matches, and keeps a folder whose contents only are matched", function()
		local rules = { rule("", "src/sub/**") }

		expect(isPathIgnored(rules, "src/sub/a.lua")).toBe(true)
		expect(isPathIgnored(rules, "src/sub/inner")).toBe(true)
		expect(isPathIgnored(rules, "src/sub")).toBe(false)
	end)

	it("lets the last matching rule decide, a negated one keeping the path", function()
		local negatedLast = { rule("", "**/*.txt"), rule("", "**/keep.txt", true) }
		local negatedFirst = { rule("", "**/a.txt", true), rule("", "**/*.txt") }

		expect(isPathIgnored(negatedLast, "src/drop.txt")).toBe(true)
		expect(isPathIgnored(negatedLast, "src/n/keep.txt")).toBe(false)
		expect(isPathIgnored(negatedFirst, "src/a.txt")).toBe(true)
	end)

	it("matches a path relative to the rule's folder and never one outside it", function()
		local rules = { rule("packages/inner", "src/*.txt") }

		expect(isPathIgnored(rules, "packages/inner/src/a.txt")).toBe(true)
		expect(isPathIgnored(rules, "packages/innerish/src/a.txt")).toBe(false)
		expect(isPathIgnored(rules, "src/a.txt")).toBe(false)
	end)

	it("takes the relative path as Rojo's strip_prefix does, ignoring `./` and `/` at its start only", function()
		local rules = { rule("", "src/a.lua"), rule("sub", "../src/x.lua") }

		expect(isPathIgnored(rules, "./src/a.lua")).toBe(true)
		expect(isPathIgnored(rules, "src/./a.lua")).toBe(false)
		expect(isPathIgnored(rules, "sub/./../src/x.lua")).toBe(true)
	end)
end)
