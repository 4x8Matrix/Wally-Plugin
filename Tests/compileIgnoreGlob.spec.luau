local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local compileIgnoreGlob = require(ReplicatedStorage.WallyPlugin.PluginUtilities.compileIgnoreGlob)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("compileIgnoreGlob", function()
	it("compiles a plain pattern as a rule that ignores what it matches", function()
		local glob = compileIgnoreGlob("src/*.lua").value

		expect(glob.negated).toBe(false)
		expect(glob.matches("src/a.lua")).toBe(true)
		expect(glob.matches("src/a.txt")).toBe(false)
	end)

	it("strips one leading `!` into a negation, so `!!` matches a literal `!`", function()
		local negated = compileIgnoreGlob("!src/keep.lua").value
		local twice = compileIgnoreGlob("!!a/y.lua").value

		expect(negated.negated).toBe(true)
		expect(negated.matches("src/keep.lua")).toBe(true)
		expect(twice.negated).toBe(true)
		expect(twice.matches("!a/y.lua")).toBe(true)
	end)

	it("reads a leading `\\!` as a literal `!`, not a negation", function()
		local glob = compileIgnoreGlob("\\!a/x.lua").value

		expect(glob.negated).toBe(false)
		expect(glob.matches("!a/x.lua")).toBe(true)
	end)

	it("refuses a pattern globset refuses, after the negation is stripped", function()
		expect(compileIgnoreGlob("!src/[a")).toEqual({
			ok = false,
			error = { path = "", message = "error parsing glob 'src/[a': unclosed character class; missing ']'" },
		})
	end)
end)
