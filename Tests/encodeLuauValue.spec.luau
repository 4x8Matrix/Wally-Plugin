local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local encodeLuauValue = require(ReplicatedStorage.WallyPlugin.PluginUtilities.encodeLuauValue)

local NULL = { kind = "null" }

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function array(items: { any })
	return { kind = "array", items = items }
end

local function map(entries: { { key: any, value: any } })
	return { kind = "map", entries = entries }
end

local function entry(key: any, value: any)
	return { key = key, value = value }
end

local function lines(...: string): string
	return table.concat({ ... }, "\n")
end

describe("encodeLuauValue", function()
	it("returns a scalar with no trailing newline", function()
		expect(encodeLuauValue(true)).toBe("return true")
		expect(encodeLuauValue(false)).toBe("return false")
		expect(encodeLuauValue(NULL)).toBe("return nil")
		expect(encodeLuauValue("text")).toBe('return "text"')
		expect(encodeLuauValue(12.5)).toBe("return 12.5")
	end)

	it("prints a number as Rust prints it, never with an exponent", function()
		expect(encodeLuauValue(array({ 1, 1.5, -0, 0.1, 123456789.123, 100 }))).toBe(
			"return {1, 1.5, -0, 0.1, 123456789.123, 100}"
		)
		expect(encodeLuauValue(array({ 1e20, 1e-7, 1e-5, 2.5e-10 }))).toBe(
			"return {100000000000000000000, 0.0000001, 0.00001, 0.00000000025}"
		)
		expect(encodeLuauValue(array({ 1e21, 0.3, 0.30000000000000004, 9007199254740992 }))).toBe(
			"return {1000000000000000000000, 0.3, 0.30000000000000004, 9007199254740992}"
		)
	end)

	it("prints a number with no finite form by name", function()
		expect(encodeLuauValue(map({
			entry("a", 0 / 0),
			entry("b", math.huge),
			entry("c", -math.huge),
			entry("f", -0),
			entry("g", 1e20),
			entry("h", 3),
		}))).toBe(
			lines(
				"return {",
				"\ta = 0/0,",
				"\tb = math.huge,",
				"\tc = -math.huge,",
				"\tf = -0,",
				"\tg = 100000000000000000000,",
				"\th = 3,",
				"}"
			)
		)
	end)

	it("escapes only a quote, a return, a newline, a tab and a backslash", function()
		expect(encodeLuauValue(array({ 'quote " backslash \\ cr \r lf \n tab \t', "" }))).toBe(
			'return {"quote \\" backslash \\\\ cr \\r lf \\n tab \\t", ""}'
		)
		expect(encodeLuauValue(array({ "bell \7 bs \8 ff \12 one \1 del \127 slash / e \u{E9} ls \u{2028}" }))).toBe(
			'return {"bell \7 bs \8 ff \12 one \1 del \127 slash / e \u{E9} ls \u{2028}"}'
		)
	end)

	it("writes an array on one line and an empty map over two", function()
		expect(encodeLuauValue(array({ 1, 2, 3 }))).toBe("return {1, 2, 3}")
		expect(encodeLuauValue(array({}))).toBe("return {}")
		expect(encodeLuauValue(map({}))).toBe(lines("return {", "}"))
		expect(encodeLuauValue(array({ array({ 1, 2, 3 }), array({}), array({ array({}) }), array({ map({}) }) }))).toBe(
			lines("return {{1, 2, 3}, {}, {{}}, {{", "}}}")
		)
		expect(encodeLuauValue(array({ map({ entry("a", 1) }), 2 }))).toBe(lines("return {{", "\ta = 1,", "}, 2}"))
	end)

	it("indents a nested map by a tab for each map it sits in", function()
		local value = map({
			entry(
				"a",
				map({
					entry("b", map({ entry("c", array({ 1, map({ entry("d", map({})) }) })) })),
					entry("e", map({})),
				})
			),
			entry("f", array({ map({ entry("g", array({ map({ entry("h", 1) }) })) }) })),
		})

		expect(encodeLuauValue(value)).toBe(
			lines(
				"return {",
				"\ta = {",
				"\t\tb = {",
				"\t\t\tc = {1, {",
				"\t\t\t\td = {",
				"\t\t\t\t},",
				"\t\t\t}},",
				"\t\t},",
				"\t\te = {",
				"\t\t},",
				"\t},",
				"\tf = {{",
				"\t\tg = {{",
				"\t\t\th = 1,",
				"\t\t}},",
				"\t}},",
				"}"
			)
		)
	end)

	it("writes an identifier key bare and brackets every other key", function()
		expect(encodeLuauValue(map({
			entry("", 13),
			entry("1a", 11),
			entry("A", 3),
			entry("_", 2),
			entry("a b", 14),
			entry('a"b\n\\', 16),
			entry("a-b", 12),
			entry("abc_1", 1),
			entry("and", 5),
			entry("continue", 8),
			entry("end", 4),
			entry("export", 10),
			entry("goto", 7),
			entry("nil", 6),
			entry("type", 9),
			entry("until", 17),
			entry("\u{E9}", 15),
		}))).toBe(
			lines(
				"return {",
				'\t[""] = 13,',
				'\t["1a"] = 11,',
				"\tA = 3,",
				"\t_ = 2,",
				'\t["a b"] = 14,',
				'\t["a\\"b\\n\\\\"] = 16,',
				'\t["a-b"] = 12,',
				"\tabc_1 = 1,",
				'\t["and"] = 5,',
				"\tcontinue = 8,",
				'\t["end"] = 4,',
				"\texport = 10,",
				"\tgoto = 7,",
				'\t["nil"] = 6,',
				"\ttype = 9,",
				'\t["until"] = 17,',
				'\t["\u{E9}"] = 15,',
				"}"
			)
		)
	end)

	it("brackets every Lua 5.1 keyword used as a key", function()
		local keywords = {
			"and",
			"break",
			"do",
			"else",
			"elseif",
			"end",
			"false",
			"for",
			"function",
			"if",
			"in",
			"local",
			"nil",
			"not",
			"or",
			"repeat",
			"return",
			"then",
			"true",
			"until",
			"while",
		}

		for _, keyword in keywords do
			expect(encodeLuauValue(map({ entry(keyword, 1) }))).toBe(lines("return {", `\t["{keyword}"] = 1,`, "}"))
		end
	end)

	it("writes a key that is not a string as an expression", function()
		expect(encodeLuauValue(map({
			entry(1, "a"),
			entry(true, "b"),
			entry(1.5, "c"),
			entry("name", "d"),
			entry(-2, "e"),
			entry(false, "f"),
			entry(16, "g"),
			entry(math.huge, "h"),
		}))).toBe(
			lines(
				"return {",
				'\t[1] = "a",',
				'\t[true] = "b",',
				'\t[1.5] = "c",',
				'\tname = "d",',
				'\t[-2] = "e",',
				'\t[false] = "f",',
				'\t[16] = "g",',
				'\t[math.huge] = "h",',
				"}"
			)
		)
		expect(encodeLuauValue(map({
			entry("outer", map({ entry(3, "x"), entry("list", array({ map({ entry(1, "y"), entry("z", 2) }) })) })),
		}))).toBe(
			lines(
				"return {",
				"\touter = {",
				'\t\t[3] = "x",',
				"\t\tlist = {{",
				'\t\t\t[1] = "y",',
				"\t\t\tz = 2,",
				"\t\t}},",
				"\t},",
				"}"
			)
		)
	end)

	it("writes the module Rojo writes for its own json_as_lua test", function()
		local value = map({
			entry("1invalidident", "nice"),
			entry("array", array({ 1, 2, 3 })),
			entry("false", false),
			entry("float", 1234.5452),
			entry("int", 1234),
			entry("null", NULL),
			entry("object", map({ entry("hello", "world") })),
			entry("true", true),
		})

		expect(encodeLuauValue(value)).toBe(
			lines(
				"return {",
				'\t["1invalidident"] = "nice",',
				"\tarray = {1, 2, 3},",
				'\t["false"] = false,',
				"\tfloat = 1234.5452,",
				"\tint = 1234,",
				"\tnull = nil,",
				"\tobject = {",
				'\t\thello = "world",',
				"\t},",
				'\t["true"] = true,',
				"}"
			)
		)
	end)

	it("loads back as a table with the values it was given", function()
		local value = map({
			entry("array", array({ 1, 2, 3 })),
			entry("nested", map({ entry("ok", true), entry("missing", NULL) })),
			entry("text", 'say "hi"\n'),
		})

		expect(loadstring(encodeLuauValue(value))()).toEqual({
			array = { 1, 2, 3 },
			nested = { ok = true },
			text = 'say "hi"\n',
		})
	end)
end)
