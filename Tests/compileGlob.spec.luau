local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local compileGlob = require(ReplicatedStorage.WallyPlugin.PluginUtilities.compileGlob)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function expectMatches(pattern: string, matched: { string }, unmatched: { string })
	local compiled = compileGlob(pattern)
	local expected = {}
	local actual = {}

	expect(compiled.ok).toBe(true)

	for _, path in matched do
		expected[path] = true
	end

	for _, path in unmatched do
		expected[path] = false
	end

	for path in expected do
		actual[path] = compiled.value(path)
	end

	expect({ pattern = pattern, matches = actual }).toEqual({ pattern = pattern, matches = expected })
end

local function expectRefusal(pattern: string, reason: string)
	expect(compileGlob(pattern)).toEqual({
		ok = false,
		error = { path = "", message = `error parsing glob '{pattern}': {reason}` },
	})
end

describe("compileGlob", function()
	it("matches a literal pattern against the whole path, case-sensitively", function()
		expectMatches("src/a.dat", { "src/a.dat" }, { "src/a.datx", "src/b.dat", "src/x/a.dat" })
		expectMatches("src/Name.dat", { "src/Name.dat" }, { "src/NAME.dat", "src/name.dat" })
		expectMatches("src/a,b.dat", { "src/a,b.dat" }, { "src/a.dat" })
	end)

	it("lets `*` and `?` cross `/`", function()
		expectMatches("src/*.dat", { "src/.dat", "src/a.dat", "src/x/y/a.dat" }, { "src/a.dax" })
		expectMatches("*.dat", { "src/a.dat", "src/x/b.dat" }, { "src/c.dax" })
		expectMatches("src/a*b.dat", { "src/a/x/b.dat", "src/ab.dat" }, { "src/ba.dat" })
		expectMatches("src/?.dat", { "src/a.dat" }, { "src/.dat", "src/ab.dat" })
		expectMatches("src?a.dat", { "src/a.dat" }, {})
	end)

	it("matches `?` and a class against one byte, not one character", function()
		expectMatches("src/?.dat", {}, { "src/\u{E9}.dat" })
		expectMatches("src/??.dat", { "src/ab.dat", "src/\u{E9}.dat" }, { "src/a.dat" })
		expectMatches("src/[!a].dat", {}, { "src/\u{E9}.dat" })
		expectMatches("src/[\u{E9}].dat", {}, { "src/\u{E9}.dat" })
		expectMatches("src/[\u{E9}][\u{E9}].dat", { "src/\u{E9}.dat" }, {})
		expectMatches("src/[\u{E0}-\u{FC}][\u{E0}-\u{FC}].dat", { "src/\u{E9}.dat" }, { "src/ab.dat" })
	end)

	it("reads `**` as a whole component at the start, at the end and between separators", function()
		expectMatches("**/a.dat", { "src/a.dat", "src/x/y/a.dat" }, { "src/ba.dat", "src/x/ba.dat" })
		expectMatches("**/x/a.dat", { "src/q/x/a.dat", "src/x/a.dat" }, { "src/yx/a.dat" })
		expectMatches("src/x/**", { "src/x/a.dat", "src/x/y/z.dat" }, { "src/x.dat", "src/xa.dat" })
		expectMatches("src/sub/**", { "src/sub/a.txt", "src/sub/deep" }, { "src/sub", "src/c.txt" })
		expectMatches("src/**/b.dat", { "src/b.dat", "src/x/b.dat", "src/x/y/b.dat" }, { "src/x/ab.dat", "src/xb.dat" })
		expectMatches("**", { "", "src/a.dat", "src/x/b.dat" }, {})
	end)

	it("reads `**` anywhere else as two stars instead of refusing it", function()
		expectMatches("src/a**.dat", { "src/a.dat", "src/ab/c.dat" }, { "src/b.dat" })
		expectMatches("src/**a.dat", { "src/a.dat", "src/x/ya.dat" }, { "src/b.dat" })
		expectMatches("**a.dat", { "src/a.dat", "src/x/ba.dat" }, { "src/b.dat" })
	end)

	it("matches a class of characters, ranges, `!` and `^` negation, a leading `]` and an outer `-`", function()
		expectMatches("src/[abc].dat", { "src/a.dat", "src/c.dat" }, { "src/ab.dat", "src/d.dat" })
		expectMatches("src/[!a].dat", { "src/b.dat" }, { "src/a.dat" })
		expectMatches("src/[^a].dat", { "src/b.dat" }, { "src/a.dat", "src/\u{E9}.dat" })
		expectMatches("src/[a-c].dat", { "src/a.dat", "src/b.dat", "src/c.dat" }, { "src/B.dat", "src/d.dat" })
		expectMatches("src/[!0-9].dat", { "src/x.dat" }, { "src/5.dat" })
		expectMatches("src/[a-cx-z].dat", { "src/b.dat", "src/y.dat" }, { "src/m.dat" })
		expectMatches("src/[]].dat", { "src/].dat" }, { "src/a.dat" })
		expectMatches("src/[-a].dat", { "src/-.dat", "src/a.dat" }, { "src/b.dat" })
		expectMatches("src/[a-].dat", { "src/-.dat", "src/a.dat" }, { "src/b.dat" })
		expectMatches("src[/]a.dat", { "src/a.dat" }, {})
		expectMatches("src[!x]a.dat", { "src/a.dat" }, {})
		expectMatches("src/[*].dat", { "src/*.dat" }, { "src/a.dat" })
		expectMatches("src/[\\]].dat", { "src/\\].dat" }, { "src/].dat" })
	end)

	it("matches alternates, nested ones included, dropping an empty option", function()
		expectMatches("src/{a,b}.dat", { "src/a.dat", "src/b.dat" }, { "src/ab.dat", "src/c.dat" })
		expectMatches("src/{*.foo,x/**}", { "src/a.foo", "src/x/y.dat" }, { "src/b.dat" })
		expectMatches("src/{a,{b,c}}.dat", { "src/a.dat", "src/b.dat", "src/c.dat" }, { "src/d.dat" })
		expectMatches("src/{a,b{c,d}}.dat", { "src/a.dat", "src/bc.dat", "src/bd.dat" }, { "src/b.dat" })
		expectMatches("src/x{,y}.dat", { "src/xy.dat" }, { "src/x.dat" })
		expectMatches("src/{}x.dat", { "src/x.dat" }, {})
		expectMatches("{}", { "" }, { "a" })
		expectMatches("{,}", { "" }, { "a" })
	end)

	it("reads a backslash as an escape", function()
		expectMatches("src/\\*.dat", { "src/*.dat" }, { "src/a.dat" })
		expectMatches("src/\\a.dat", { "src/a.dat" }, {})
		expectMatches("src/\\[a].dat", { "src/[a].dat" }, { "src/a.dat" })
		expectMatches("src/\\{a,b\\}.dat", { "src/{a,b}.dat" }, { "src/a.dat" })
		expectMatches("src/\\!b.txt", { "src/!b.txt" }, { "src/b.txt" })
		expectMatches("src/{a\\,**}", { "src/a/x.dat" }, { "src/a,x.dat" })
	end)

	it("reads a leading `!` as a literal, leaving negation to the ignore rule", function()
		expectMatches("!src/a.dat", { "!src/a.dat" }, { "src/a.dat" })
		expectMatches("\\!src/a.dat", { "!src/a.dat" }, { "src/a.dat" })
	end)

	it("matches Rojo's default rules against the whole path, so at any depth (R1.1)", function()
		expectMatches(
			"*.server.lua",
			{ "src/a/b/c.server.lua" },
			{ "src/d.server.lua.bak", "src/e.SERVER.lua", "src/f.server.luau" }
		)
		expectMatches("*.server.luau", { "src/f.server.luau" }, { "src/a/b/c.server.lua" })
		expectMatches("*.{lua,luau}", { "src/e.SERVER.lua" }, { "src/d.server.lua.bak" })
	end)

	it("refuses what globset refuses, in its words", function()
		expectRefusal("src/[a.dat", "unclosed character class; missing ']'")
		expectRefusal("src/[].dat", "unclosed character class; missing ']'")
		expectRefusal("src/[!].dat", "unclosed character class; missing ']'")
		expectRefusal("src/[z-a].dat", "invalid range; 'z' > 'a'")
		expectRefusal("src/{a,b.dat", "unclosed alternate group; missing '}' (maybe escape '{' with '[{]'?)")
		expectRefusal("src/{a,{b,c}.dat", "unclosed alternate group; missing '}' (maybe escape '{' with '[{]'?)")
		expectRefusal("src/a}.dat", "unopened alternate group; missing '{' (maybe escape '}' with '[}]'?)")
		expectRefusal("src/a.dat\\", "dangling '\\'")
	end)

	it("refuses a pattern that is not valid UTF-8 instead of throwing", function()
		expect(compileGlob("src/\xFF.dat")).toEqual({
			ok = false,
			error = { path = "", message = "Glob is not valid UTF-8" },
		})
	end)
end)
