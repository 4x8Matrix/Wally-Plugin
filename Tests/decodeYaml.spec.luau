local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local decodeYaml = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeYaml)
local encodeLuauValue = require(ReplicatedStorage.WallyPlugin.PluginUtilities.encodeLuauValue)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function lines(...: string): string
	return table.concat({ ... }, "\n")
end

local function generate(text: string): string
	local decoded = decodeYaml(text)

	if not decoded.ok then
		return `refused: {decoded.error.message}`
	end

	return encodeLuauValue(decoded.value)
end

describe("decodeYaml", function()
	it("keeps mappings in written order with keys of any scalar type", function()
		expect(generate(lines("zeta: 1", "alpha:", "  beta: two", "  gamma: [x, y]", "mid:", "  - 3", "  - four", ""))).toBe(
			lines(
				"return {",
				"\tzeta = 1,",
				"\talpha = {",
				'\t\tbeta = "two",',
				'\t\tgamma = {"x", "y"},',
				"\t},",
				'\tmid = {3, "four"},',
				"}"
			)
		)
		expect(generate(lines("zeta: 1", "alpha: 2", "mid: 3", ""))).toBe(
			lines("return {", "\tzeta = 1,", "\talpha = 2,", "\tmid = 3,", "}")
		)
		expect(generate(lines("1: a", "true: b", "1.5: c", '"2": d', "0x10: e", ""))).toBe(
			lines(
				"return {",
				'\t[1] = "a",',
				'\t[true] = "b",',
				'\t[1.5] = "c",',
				'\t["2"] = "d",',
				'\t[16] = "e",',
				"}"
			)
		)
		expect(generate(lines("1: a", "true: b", "1.5: c", '"2": d', "'x y': e", "0x10: f", ""))).toBe(
			lines(
				"return {",
				'\t[1] = "a",',
				'\t[true] = "b",',
				'\t[1.5] = "c",',
				'\t["2"] = "d",',
				'\t["x y"] = "e",',
				'\t[16] = "f",',
				"}"
			)
		)
		expect(generate("key with spaces: 1\n")).toBe(lines("return {", '\t["key with spaces"] = 1,', "}"))
		expect(generate(lines("end: 1", "nil: 2", ""))).toBe(lines("return {", '\t["end"] = 1,', '\t["nil"] = 2,', "}"))
		expect(generate(lines("1.0: a", "1.00: b", ""))).toBe(lines("return {", '\t[1] = "a",', '\t[1] = "b",', "}"))
		expect(generate("a:b: 1\n")).toBe(lines("return {", '\t["a:b"] = 1,', "}"))
		expect(generate("http://x: 1\n")).toBe(lines("return {", '\t["http://x"] = 1,', "}"))
		expect(generate(lines("a  : 1", "b\t: 2", ""))).toBe(lines("return {", "\ta = 1,", "\tb = 2,", "}"))
		expect(generate(lines("-0: a", "0.0: b", "-0.0: c", "'0': d", ""))).toBe(
			lines("return {", '\t[0] = "a",', '\t[0] = "b",', '\t[-0] = "c",', '\t["0"] = "d",', "}")
		)
		expect(generate(".nan: a\n")).toBe(lines("return {", '\t[0/0] = "a",', "}"))
		expect(generate(lines("\u{540D}\u{524D}: \u{5024}", 'emoji: "\\u263A"', ""))).toBe(
			lines("return {", '\t["\u{540D}\u{524D}"] = "\u{5024}",', '\temoji = "\u{263A}",', "}")
		)
		expect(generate(lines("'a b': 1", '"c\\td": 2', ""))).toBe(
			lines("return {", '\t["a b"] = 1,', '\t["c\\td"] = 2,', "}")
		)
		expect(generate('"a: b": 1\n')).toBe(lines("return {", '\t["a: b"] = 1,', "}"))
		expect(generate('"a" : 1\n')).toBe(lines("return {", "\ta = 1,", "}"))
		expect(generate(string.rep("x", 1024) .. ": 1\n")).toBe(
			lines("return {", `\t{string.rep("x", 1024)} = 1,`, "}")
		)
		expect(generate(string.rep("\u{E9}", 600) .. ": 1\n")).toBe(
			lines("return {", `\t["{string.rep("\u{E9}", 600)}"] = 1,`, "}")
		)
		expect(generate(lines("a:", "b: 1", ""))).toBe(lines("return {", "\ta = nil,", "\tb = 1,", "}"))
	end)

	it("resolves only yaml-rust2's booleans and nulls", function()
		expect(generate(lines("a: yes", "b: true", "c: False", "d: no", "e: on", "f: TRUE", ""))).toBe(
			lines(
				"return {",
				'\ta = "yes",',
				"\tb = true,",
				"\tc = false,",
				'\td = "no",',
				'\te = "on",',
				"\tf = true,",
				"}"
			)
		)
		expect(
			generate(
				lines(
					"a: true",
					"b: True",
					"c: TRUE",
					"d: false",
					"e: False",
					"f: FALSE",
					"g: yes",
					"h: no",
					"i: on",
					"j: off",
					"k: tRUE",
					"l: y",
					""
				)
			)
		).toBe(
			lines(
				"return {",
				"\ta = true,",
				"\tb = true,",
				"\tc = true,",
				"\td = false,",
				"\te = false,",
				"\tf = false,",
				'\tg = "yes",',
				'\th = "no",',
				'\ti = "on",',
				'\tj = "off",',
				'\tk = "tRUE",',
				'\tl = "y",',
				"}"
			)
		)
		expect(generate(lines("a: ~", "b: null", "c:", "d: Null", "e: NULL", ""))).toBe(
			lines("return {", "\ta = nil,", "\tb = nil,", "\tc = nil,", '\td = "Null",', '\te = "NULL",', "}")
		)
		expect(generate(lines("a: ~", "b: null", "c: Null", "d: NULL", "e:", "f: ''", ""))).toBe(
			lines(
				"return {",
				"\ta = nil,",
				"\tb = nil,",
				'\tc = "Null",',
				'\td = "NULL",',
				"\te = nil,",
				'\tf = "",',
				"}"
			)
		)
	end)

	it("resolves integers as yaml-rust2 does and refuses one above 2^53 as Rojo does", function()
		expect(
			generate(
				lines(
					"a: 42",
					"b: -7",
					"c: +12",
					"d: 007",
					"e: 0x1F",
					"f: 0o17",
					"g: 1_000",
					"h: 0X1F",
					"i: 9007199254740992",
					"j: -9007199254740999",
					"k: 99999999999999999999",
					""
				)
			)
		).toBe(
			lines(
				"return {",
				"\ta = 42,",
				"\tb = -7,",
				"\tc = 12,",
				"\td = 7,",
				"\te = 31,",
				"\tf = 15,",
				'\tg = "1_000",',
				'\th = "0X1F",',
				"\ti = 9007199254740992,",
				"\tj = -9007199254741000,",
				"\tk = 100000000000000000000,",
				"}"
			)
		)
		expect(
			generate(
				lines(
					"a: 42",
					"b: -7",
					"c: +12",
					"d: 007",
					"e: 0x1F",
					"f: 0o17",
					"g: 0b101",
					"h: 1_000",
					"i: 0x-1",
					"j: +-12",
					"k: -0x1F",
					"l: 0X1F",
					"m: 0",
					"n: -0",
					""
				)
			)
		).toBe(
			lines(
				"return {",
				"\ta = 42,",
				"\tb = -7,",
				"\tc = 12,",
				"\td = 7,",
				"\te = 31,",
				"\tf = 15,",
				'\tg = "0b101",',
				'\th = "1_000",',
				"\ti = -1,",
				"\tj = -12,",
				'\tk = "-0x1F",',
				'\tl = "0X1F",',
				"\tm = 0,",
				"\tn = 0,",
				"}"
			)
		)
		expect(generate("a: 9007199254740992\n")).toBe(lines("return {", "\ta = 9007199254740992,", "}"))
		expect(generate("a: -9007199254740999\n")).toBe(lines("return {", "\ta = -9007199254741000,", "}"))
		expect(generate("a: 99999999999999999999\n")).toBe(lines("return {", "\ta = 100000000000000000000,", "}"))
		expect(generate(lines("a: 0x-1F", "b: 0x+1F", ""))).toBe(lines("return {", "\ta = -31,", "\tb = 31,", "}"))
		expect(generate(lines("a: 0o8", "b: 0o", ""))).toBe(lines("return {", '\ta = "0o8",', '\tb = "0o",', "}"))
		expect(generate(lines("a: -9223372036854775808", "b: -9223372036854775809", ""))).toBe(
			lines("return {", "\ta = -9223372036854776000,", "\tb = -9223372036854776000,", "}")
		)

		expect(
			generate(
				lines(
					"a: 0x_1",
					"b: 1__0",
					"c: 0x8000000000000000",
					"d: -0x1",
					"e: 0o-7",
					"f: +0o7",
					"g: 0x7FFFFFFFFFFFFFFF",
					"h: 00",
					"i: +0",
					"j: -9223372036854775809",
					""
				)
			)
		).toBe("refused: the integer '9223372036854775807' cannot be losslessly converted into a Luau number")
		expect(generate("a: 9007199254740993\n")).toBe(
			"refused: the integer '9007199254740993' cannot be losslessly converted into a Luau number"
		)
		expect(generate("a: 0x20000000000001\n")).toBe(
			"refused: the integer '9007199254740993' cannot be losslessly converted into a Luau number"
		)
		expect(generate("a: 9223372036854775807\n")).toBe(
			"refused: the integer '9223372036854775807' cannot be losslessly converted into a Luau number"
		)
		expect(generate("a: !!int 9007199254740993\n")).toBe(
			"refused: the integer '9007199254740993' cannot be losslessly converted into a Luau number"
		)
	end)

	it("resolves floats, infinities and NaN as yaml-rust2 does", function()
		expect(
			generate(lines("a: 1.5", "b: 1e3", "c: .5", "d: -.inf", "e: .nan", "f: inf", "g: 6.02e+23", "h: 1.", ""))
		).toBe(
			lines(
				"return {",
				"\ta = 1.5,",
				"\tb = 1000,",
				"\tc = 0.5,",
				"\td = -math.huge,",
				"\te = 0/0,",
				'\tf = "inf",',
				"\tg = 602000000000000000000000,",
				"\th = 1,",
				"}"
			)
		)
		expect(
			generate(
				lines(
					"a: 1.5",
					"b: -2.25",
					"c: 1e3",
					"d: 1.",
					"e: .5",
					"f: +1.5",
					"g: 1E-2",
					"h: .inf",
					"i: -.Inf",
					"j: +.INF",
					"k: .nan",
					"l: .NaN",
					"m: inf",
					"n: nan",
					"o: infinity",
					"p: 1e400",
					"q: 6.02e+23",
					"r: 0.1",
					"s: 123456789.5",
					"t: -0.0",
					""
				)
			)
		).toBe(
			lines(
				"return {",
				"\ta = 1.5,",
				"\tb = -2.25,",
				"\tc = 1000,",
				"\td = 1,",
				"\te = 0.5,",
				"\tf = 1.5,",
				"\tg = 0.01,",
				"\th = math.huge,",
				"\ti = -math.huge,",
				"\tj = math.huge,",
				"\tk = 0/0,",
				"\tl = 0/0,",
				'\tm = "inf",',
				'\tn = "nan",',
				'\to = "infinity",',
				"\tp = math.huge,",
				"\tq = 602000000000000000000000,",
				"\tr = 0.1,",
				"\ts = 123456789.5,",
				"\tt = -0,",
				"}"
			)
		)
		expect(generate(lines("a: 1.e5", "b: .5E-3", "c: 1e", "d: e5", "e: 1e5.5", ""))).toBe(
			lines("return {", "\ta = 100000,", "\tb = 0.0005,", '\tc = "1e",', '\td = "e5",', '\te = "1e5.5",', "}")
		)
		expect(generate(lines("a: -0.0", "b: -0", ""))).toBe(lines("return {", "\ta = -0,", "\tb = 0,", "}"))
		expect(
			generate(
				lines(
					"a: 1e-400",
					"b: -1e400",
					"c: .1e1",
					"d: 1.5E+3",
					"e: +1.5e-3",
					"f: 1e+",
					"g: 0.0000001",
					"h: 1_0.5",
					"i: 5e-324",
					"j: 1.7976931348623157e308",
					"k: 123456789012345678901234567890",
					"l: 0.1e-5",
					""
				)
			)
		).toBe(
			lines(
				"return {",
				"\ta = 0,",
				"\tb = -math.huge,",
				"\tc = 1,",
				"\td = 1500,",
				"\te = 0.0015,",
				'\tf = "1e+",',
				"\tg = 0.0000001,",
				'\th = "1_0.5",',
				"\ti = 0.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005,",
				"\tj = 179769313486231570000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000,",
				"\tk = 123456789012345680000000000000,",
				"\tl = 0.000001,",
				"}"
			)
		)
	end)

	it("keeps quoted scalars and timestamps as strings", function()
		expect(generate(lines('a: "1"', "b: '2.5'", 'c: "true"', "d: '~'", ""))).toBe(
			lines("return {", '\ta = "1",', '\tb = "2.5",', '\tc = "true",', '\td = "~",', "}")
		)
		expect(generate(lines("a: 2001-12-14t21:59:43.10-05:00", "b: 2002-12-14", ""))).toBe(
			lines("return {", '\ta = "2001-12-14t21:59:43.10-05:00",', '\tb = "2002-12-14",', "}")
		)
		expect(generate(lines("a: 2001-12-14t21:59:43.10-05:00", "b: 2002-12-14", "c: 2001-12-14 21:59:43.10 -5", ""))).toBe(
			lines(
				"return {",
				'\ta = "2001-12-14t21:59:43.10-05:00",',
				'\tb = "2002-12-14",',
				'\tc = "2001-12-14 21:59:43.10 -5",',
				"}"
			)
		)
		expect(generate("a: 'it''s'\n")).toBe(lines("return {", '\ta = "it\'s",', "}"))
		expect(generate('a: "tab\\there \\"q\\" back\\\\slash"\n')).toBe(
			lines("return {", '\ta = "tab\\there \\"q\\" back\\\\slash",', "}")
		)
		expect(generate(lines('a: "\\\\"', "b: 'single \\ back'", 'c: "tab\\there"', ""))).toBe(
			lines("return {", '\ta = "\\\\",', '\tb = "single \\\\ back",', '\tc = "tab\\there",', "}")
		)
		expect(generate('a: "x\\x00y"\n')).toBe(lines("return {", '\ta = "x\0y",', "}"))

		expect(generate(lines("a: it's", 'b: say "hi"', "c: 'a' b", ""))).toBe(
			"refused: invalid trailing content after double-quoted scalar"
		)
	end)

	it("reads every double-quoted escape and refuses unknown ones", function()
		expect(generate('a: "\\x41"\n')).toBe(lines("return {", '\ta = "A",', "}"))
		expect(generate('a: "caf\\u00e9"\n')).toBe(lines("return {", '\ta = "caf\u{E9}",', "}"))
		expect(generate('a: "\\0\\a\\b\\t\\n\\v\\f\\r\\e\\ \\/\\N\\_\\L\\P\\U0001F600"\n')).toBe(
			lines("return {", '\ta = "\0\7\8\\t\\n\11\12\\r\27 /\u{85}\u{A0}\u{2028}\u{2029}\u{1F600}",', "}")
		)

		expect(generate('a: "\\q"\n')).toBe("refused: while parsing a quoted scalar, found unknown escape character")
		expect(generate('a: "\\ud800"\n')).toBe(
			"refused: while parsing a quoted scalar, found invalid Unicode character escape code"
		)
	end)

	it("folds multi-line plain and quoted scalars", function()
		expect(generate(lines("a: one", "  two", ""))).toBe(lines("return {", '\ta = "one two",', "}"))
		expect(generate(lines('a: "one', '  two"', ""))).toBe(lines("return {", '\ta = "one two",', "}"))
		expect(generate(lines("hello", "world", ""))).toBe('return "hello world"')
		expect(generate(lines("a: one", "  two", "", "  three", "", "", "  four", "b: x", ""))).toBe(
			lines("return {", '\ta = "one two\\nthree\\n\\nfour",', '\tb = "x",', "}")
		)
		expect(generate(lines("- one", "  two", "- three", ""))).toBe('return {"one two", "three"}')
		expect(generate(lines("a: one", "  two # c", "b: 1", ""))).toBe(
			lines("return {", '\ta = "one two",', "\tb = 1,", "}")
		)
		expect(generate(lines("a:", "  one", "  two", "b: 1", ""))).toBe(
			lines("return {", '\ta = "one two",', "\tb = 1,", "}")
		)
		expect(generate(lines("a: one", "  #two", "b: 1", ""))).toBe(lines("return {", '\ta = "one",', "\tb = 1,", "}"))
		expect(generate(lines("a:", "  b: one", "   two", "  c: 3", ""))).toBe(
			lines("return {", "\ta = {", '\t\tb = "one two",', "\t\tc = 3,", "\t},", "}")
		)
		expect(generate(lines('a: "one\\', '  two"', ""))).toBe(lines("return {", '\ta = "onetwo",', "}"))
		expect(generate(lines('a: "one', "", '  two"', ""))).toBe(lines("return {", '\ta = "one\\ntwo",', "}"))
		expect(generate(lines("a: 'one", "  two'", ""))).toBe(lines("return {", '\ta = "one two",', "}"))
		expect(generate(lines('a: ["one', "  two\", 'three", "", "  four']", ""))).toBe(
			lines("return {", '\ta = {"one two", "three\\nfour"},', "}")
		)
		expect(generate(lines("- a", "  - b", ""))).toBe('return {"a - b"}')
		expect(generate(lines('"a', 'b"', ""))).toBe('return "a b"')
		expect(generate(lines("hello", "%world", ""))).toBe('return "hello %world"')

		expect(generate(lines("a: one", "  two: 2", ""))).toBe(
			"refused: mapping values are not allowed in this context"
		)
		expect(generate(lines("a:", "  value", "  b: 2", ""))).toBe(
			"refused: mapping values are not allowed in this context"
		)
		expect(generate(lines("a:", "  b: one", " two", ""))).toBe(
			"refused: while parsing a block mapping, did not find expected key"
		)
		expect(generate(lines('a: "one', 'two"', ""))).toBe("refused: invalid indentation in quoted scalar")
		expect(generate("a: 'x\n")).toBe("refused: while scanning a quoted scalar, found unexpected end of stream")
		expect(generate(lines("-", '  "a', 'b"', ""))).toBe("refused: invalid indentation in quoted scalar")
	end)

	it("reads literal and folded block scalars as yaml-rust2 does", function()
		expect(
			generate(
				lines(
					"literal: |",
					"  line one",
					"  line two",
					"folded: >",
					"  folded one",
					"  folded two",
					"stripped: |-",
					"  x",
					"  y",
					"after: end",
					""
				)
			)
		).toBe(
			lines(
				"return {",
				'\tliteral = "line one\\nline two\\n",',
				'\tfolded = "folded one folded two\\n",',
				'\tstripped = "x\\ny",',
				'\tafter = "end",',
				"}"
			)
		)
		expect(generate(lines("text: |", "  line one", "  line two", "next: 1", ""))).toBe(
			lines("return {", '\ttext = "line one\\nline two\\n",', "\tnext = 1,", "}")
		)
		expect(generate(lines("text: >", "  folded one", "  folded two", "next: 1", ""))).toBe(
			lines("return {", '\ttext = "folded one folded two\\n",', "\tnext = 1,", "}")
		)
		expect(generate(lines("a: |-", "  x", "  y", "b: |+", "  z", "", "c: 1", ""))).toBe(
			lines("return {", '\ta = "x\\ny",', '\tb = "z\\n\\n",', "\tc = 1,", "}")
		)
		expect(generate(lines("a: |", "  x", "", "  y", ""))).toBe(lines("return {", '\ta = "x\\n\\ny\\n",', "}"))
		expect(generate(lines("a: >", "  x", "", "  y", ""))).toBe(lines("return {", '\ta = "x\\ny\\n",', "}"))
		expect(generate(lines("a: |", "  x", "  # not a comment", ""))).toBe(
			lines("return {", '\ta = "x\\n# not a comment\\n",', "}")
		)
		expect(generate(lines("a: | # comment", "  x", ""))).toBe(lines("return {", '\ta = "x\\n",', "}"))
		expect(generate(lines("- |", "  text", ""))).toBe('return {"text\\n"}')
		expect(generate(lines("a: |2", "   x", "  y", ""))).toBe(lines("return {", '\ta = " x\\ny\\n",', "}"))
		expect(generate(lines("a: |-2", "   x", "  y", "b: >+1", "  z", "", "c: 1", ""))).toBe(
			lines("return {", '\ta = " x\\ny",', '\tb = " z\\n\\n",', "\tc = 1,", "}")
		)
		expect(generate(lines("a: >", "  one", "  two", "    indented", "  three", "", "  four", ""))).toBe(
			lines("return {", '\ta = "one two\\n  indented\\nthree\\nfour\\n",', "}")
		)
		expect(generate(lines("a: |", "", "", "  x", ""))).toBe(lines("return {", '\ta = "\\n\\nx\\n",', "}"))
		expect(generate(lines("a: >", "", "  x", "  y", ""))).toBe(lines("return {", '\ta = "\\nx y\\n",', "}"))
		expect(generate(lines("a: |", "  x  ", "  y\t", ""))).toBe(lines("return {", '\ta = "x  \\ny\\t\\n",', "}"))
		expect(generate(lines("a: |", "  x", "# c", "b: 1", ""))).toBe(
			lines("return {", '\ta = "x\\n",', "\tb = 1,", "}")
		)
		expect(generate(lines("- >", "  a", "  b", "- c", ""))).toBe('return {"a b\\n", "c"}')
		expect(generate(lines("a: |", "  x", "    ", "  y", ""))).toBe(lines("return {", '\ta = "x\\n  \\ny\\n",', "}"))
		expect(generate(lines("a: >", "  x", "   ", "  y", ""))).toBe(lines("return {", '\ta = "x\\n \\ny\\n",', "}"))
		expect(generate(lines("a: |", "  \tx", ""))).toBe(lines("return {", '\ta = "\\tx\\n",', "}"))
		expect(generate(lines("a: |\r", "  x\r", "  y\r", "b: >\r", "  p\r", "  q\r", ""))).toBe(
			lines("return {", '\ta = "x\\ny\\n",', '\tb = "p q\\n",', "}")
		)
		expect(generate(lines("a: >-", "  one", "", "    two", "    three", "", "  four", "  five", ""))).toBe(
			lines("return {", '\ta = "one\\n\\n  two\\n  three\\n\\nfour five",', "}")
		)
		expect(generate(lines("a: |1", "  x", " y", ""))).toBe(lines("return {", '\ta = " x\\ny\\n",', "}"))
		expect(generate(lines("a:", "  b: |", "    x", "    y", "  c: 2", ""))).toBe(
			lines("return {", "\ta = {", '\t\tb = "x\\ny\\n",', "\t\tc = 2,", "\t},", "}")
		)
		expect(generate(lines("- |", "  a", "- |-", "  b", "- >+", "  c", "", "- d", ""))).toBe(
			'return {"a\\n", "b", "c\\n\\n", "d"}'
		)
		expect(generate(lines("--- |", "  x", "  y", ""))).toBe('return "x\\ny\\n"')
		expect(generate(lines("--- >", "foo", "bar", ""))).toBe('return "foo bar\\n"')
		expect(generate(lines("|+", "  x", "", ""))).toBe('return "x\\n\\n"')
		expect(generate(lines("|", "foo", "  bar", ""))).toBe('return "foo\\n  bar\\n"')

		expect(generate(lines("a: |", "     ", "  x", ""))).toBe("refused: wrongly indented line in block scalar")
		expect(generate(lines("a: |", "\tx", ""))).toBe("refused: a block scalar content cannot start with a tab")
		expect(generate(lines("a: |#c", "  x", ""))).toBe(
			"refused: comments must be separated from other tokens by whitespace"
		)
		expect(generate(lines("a: | x", "  y", ""))).toBe(
			"refused: while scanning a block scalar, did not find expected comment or line break"
		)
		expect(generate(lines("a: |0", "  x", ""))).toBe(
			"refused: while scanning a block scalar, found an indentation indicator equal to 0"
		)
		expect(generate(lines("a: |", "  x", " # c", "  y", ""))).toBe(
			"refused: while parsing a block mapping, did not find expected key"
		)
	end)

	it("reads an empty block scalar and the end of the stream as yaml-rust2 does", function()
		expect(generate("a: |\n  x")).toBe(lines("return {", '\ta = "x\\n",', "}"))
		expect(generate(lines("a: |+", "  x", "", "", ""))).toBe(lines("return {", '\ta = "x\\n\\n\\n",', "}"))
		expect(generate("a: |\n")).toBe(lines("return {", '\ta = "\\n",', "}"))
		expect(generate(lines("a: |", "b: 1", ""))).toBe(lines("return {", '\ta = "",', "\tb = 1,", "}"))
		expect(generate("a: |+\n")).toBe(lines("return {", '\ta = "\\n",', "}"))
		expect(generate(lines("a: |+", "", "", "b: 1", ""))).toBe(lines("return {", '\ta = "\\n\\n",', "\tb = 1,", "}"))
		expect(generate("a: |-\n")).toBe(lines("return {", '\ta = "",', "}"))
		expect(generate("a: |")).toBe(lines("return {", '\ta = "",', "}"))
		expect(generate(lines("a: |+", "  x", "", "...", ""))).toBe(lines("return {", '\ta = "x\\n\\n",', "}"))
		expect(generate(lines("a: |", "...", ""))).toBe(lines("return {", '\ta = "",', "}"))
		expect(generate(lines("--- |", "foo", "...", ""))).toBe('return "foo\\n"')
	end)

	it("reads flow collections across lines, with comments and trailing commas", function()
		expect(generate(lines("list: [1, \"2\", true, null, 1.5, abc, 'q', [], {}]", "map: {b: 1, a: 2, 3: c}", ""))).toBe(
			lines(
				"return {",
				'\tlist = {1, "2", true, nil, 1.5, "abc", "q", {}, {',
				"\t}},",
				"\tmap = {",
				"\t\tb = 1,",
				"\t\ta = 2,",
				'\t\t[3] = "c",',
				"\t},",
				"}"
			)
		)
		expect(generate("x: [1, \"2\", true, null, 1.5, abc, 'q', [], {}]\n")).toBe(
			lines("return {", '\tx = {1, "2", true, nil, 1.5, "abc", "q", {}, {', "\t}},", "}")
		)
		expect(generate("x: {b: 1, a: 2, 3: c}\n")).toBe(
			lines("return {", "\tx = {", "\t\tb = 1,", "\t\ta = 2,", '\t\t[3] = "c",', "\t},", "}")
		)
		expect(generate(lines("a: [1,", "  2,", "  3]", ""))).toBe(lines("return {", "\ta = {1, 2, 3},", "}"))
		expect(generate("a: {b: [1, {c: d}], e: 'f'}\n")).toBe(
			lines("return {", "\ta = {", "\t\tb = {1, {", '\t\t\tc = "d",', "\t\t}},", '\t\te = "f",', "\t},", "}")
		)
		expect(generate("[]\n")).toBe("return {}")
		expect(generate(lines("a: [1, 2,]", "b: {x: 1,}", ""))).toBe(
			lines("return {", "\ta = {1, 2},", "\tb = {", "\t\tx = 1,", "\t},", "}")
		)
		expect(generate(lines("a: [1, # one", "  2, # two", "  3]", ""))).toBe(
			lines("return {", "\ta = {1, 2, 3},", "}")
		)
		expect(generate('a: {"b":1, "c": [2,3]}\n')).toBe(
			lines("return {", "\ta = {", "\t\tb = 1,", "\t\tc = {2, 3},", "\t},", "}")
		)
		expect(generate("a: {b:1}\n")).toBe(lines("return {", "\ta = {", '\t\t["b:1"] = nil,', "\t},", "}"))
		expect(generate(lines("a: {", "  b: 1,", "  c: 2", "}", ""))).toBe(
			lines("return {", "\ta = {", "\t\tb = 1,", "\t\tc = 2,", "\t},", "}")
		)
		expect(generate(lines("{", '  "a": 1,', '  "b": [true, null]', "}", ""))).toBe(
			lines("return {", "\ta = 1,", "\tb = {true, nil},", "}")
		)
		expect(generate("a: [\"x, y\", 'z]']\n")).toBe(lines("return {", '\ta = {"x, y", "z]"},', "}"))
		expect(generate("a: [hello world, a b c]\n")).toBe(lines("return {", '\ta = {"hello world", "a b c"},', "}"))
		expect(generate(lines("a: [one", "  two, three]", ""))).toBe(
			lines("return {", '\ta = {"one two", "three"},', "}")
		)
		expect(generate("a: [http://x.com, {u: http://y}]\n")).toBe(
			lines("return {", '\ta = {"http://x.com", {', '\t\tu = "http://y",', "\t}},", "}")
		)
		expect(generate(lines("- [a,", "   b]", "- {c: 1,", "   d: 2}", ""))).toBe(
			lines('return {{"a", "b"}, {', "\tc = 1,", "\td = 2,", "}}")
		)
		expect(generate("a: {b: {c: [1, [2, [3]]]}}\n")).toBe(
			lines("return {", "\ta = {", "\t\tb = {", "\t\t\tc = {1, {2, {3}}},", "\t\t},", "\t},", "}")
		)
		expect(generate(lines("a: {b: , c: }", "d: {e:}", ""))).toBe(
			lines("return {", "\ta = {", "\t\tb = nil,", "\t\tc = nil,", "\t},", "\td = {", "\t\te = nil,", "\t},", "}")
		)
		expect(generate("a: [\"k\": v, 'k2':v2]\n")).toBe(
			lines("return {", "\ta = {{", '\t\tk = "v",', "\t}, {", '\t\tk2 = "v2",', "\t}},", "}")
		)
		expect(generate("a: [?x, ?]\n")).toBe(lines("return {", '\ta = {"?x", "?"},', "}"))
		expect(generate(lines("a: [b#c, d #e", "  ]", ""))).toBe(lines("return {", '\ta = {"b#c", "d"},', "}"))
		expect(generate("a: [1,\t2]\n")).toBe(lines("return {", "\ta = {1, 2},", "}"))
		expect(generate(lines("key: [", "  a,", "]", ""))).toBe(lines("return {", '\tkey = {"a"},', "}"))
		expect(generate("{a: 1} # c\n")).toBe(lines("return {", "\ta = 1,", "}"))

		expect(decodeYaml("a: [x: y: z]\n").ok).toBe(false)
		expect(generate("a: [1,,2]\n")).toBe("refused: while parsing a node, did not find expected node content")
		expect(generate("a: [,1]\n")).toBe("refused: while parsing a node, did not find expected node content")
		expect(generate("a: [1, 2\n")).toBe("refused: while parsing a flow sequence, expected ',' or ']'")
		expect(decodeYaml("a: [1] x\n").ok).toBe(false)
		expect(generate("a: [-1, -x, - ]\n")).toBe('refused: "-" is only valid inside a block')
		expect(generate(lines("a:", "  b: [1,", "2]", ""))).toBe("refused: invalid indentation")
		expect(generate(lines("key: [", "]", ""))).toBe("refused: invalid indentation")
		expect(generate(lines("[a", ": 1]", ""))).toBe("refused: illegal placement of ':' indicator")
	end)

	it("reads keys with no value, explicit keys and collection keys", function()
		expect(generate(lines("set:", "  ? a", "  ? b", ""))).toBe(
			lines("return {", "\tset = {", "\t\ta = nil,", "\t\tb = nil,", "\t},", "}")
		)
		expect(generate(lines("set: {a, b}", "pairs: [a: 1, b]", ""))).toBe(
			lines(
				"return {",
				"\tset = {",
				"\t\ta = nil,",
				"\t\tb = nil,",
				"\t},",
				"\tpairs = {{",
				"\t\ta = 1,",
				'\t}, "b"},',
				"}"
			)
		)
		expect(generate(lines("? a", "? b", ""))).toBe(lines("return {", "\ta = nil,", "\tb = nil,", "}"))
		expect(generate("x: {a, b}\n")).toBe(lines("return {", "\tx = {", "\t\ta = nil,", "\t\tb = nil,", "\t},", "}"))
		expect(generate("x: [a: 1, b]\n")).toBe(lines("return {", "\tx = {{", "\t\ta = 1,", '\t}, "b"},', "}"))
		expect(generate(lines("? a", ": 1", "? b", "? c", ": 3", ""))).toBe(
			lines("return {", "\ta = 1,", "\tb = nil,", "\tc = 3,", "}")
		)
		expect(generate(lines("? |", "  k", ": v", ""))).toBe(lines("return {", '\t["k\\n"] = "v",', "}"))
		expect(generate(lines("? a", ":", "- 1", "- 2", ""))).toBe(lines("return {", "\ta = {1, 2},", "}"))
		expect(generate("[a, b]: c\n")).toBe(lines("return {", '\t[{"a", "b"}] = "c",', "}"))
		expect(generate("{a: 1}: c\n")).toBe(lines("return {", "\t[{", "\t\ta = 1,", '\t}] = "c",', "}"))
		expect(generate(lines("? [a, b]", ": c", ""))).toBe(lines("return {", '\t[{"a", "b"}] = "c",', "}"))
		expect(generate(lines("? a: 1", ": b", ""))).toBe(lines("return {", "\t[{", "\t\ta = 1,", '\t}] = "b",', "}"))
		expect(generate(lines("? - a", "  - b", ": c", ""))).toBe(lines("return {", '\t[{"a", "b"}] = "c",', "}"))
		expect(generate("a: {? b : 1, ? c}\n")).toBe(
			lines("return {", "\ta = {", "\t\tb = 1,", "\t\tc = nil,", "\t},", "}")
		)
		expect(generate("a: [? b : 1]\n")).toBe(lines("return {", "\ta = {{", "\t\tb = 1,", "\t}},", "}"))

		expect(generate(lines("? a", ': "x', 'y"', ""))).toBe("refused: invalid indentation in quoted scalar")
	end)

	it("reads block sequences, compact entries and a sequence at its mapping's indentation", function()
		expect(generate(lines("- 1", "- two", "- ~", ""))).toBe('return {1, "two", nil}')
		expect(generate(lines("- name: a", "  value: 1", "- name: b", "  value: 2", ""))).toBe(
			lines("return {{", '\tname = "a",', "\tvalue = 1,", "}, {", '\tname = "b",', "\tvalue = 2,", "}}")
		)
		expect(generate(lines("a:", "- 1", "- 2", "b: 3", ""))).toBe(
			lines("return {", "\ta = {1, 2},", "\tb = 3,", "}")
		)
		expect(generate("- http://example.com\n")).toBe('return {"http://example.com"}')
		expect(generate("- 12:30\n")).toBe('return {"12:30"}')
		expect(generate('- "key": v\n')).toBe(lines("return {{", '\tkey = "v",', "}}"))
		expect(generate(lines("a:", "- 1", "- 2", "b:", "- c: 1", "  d: 2", "- e", ""))).toBe(
			lines("return {", "\ta = {1, 2},", "\tb = {{", "\t\tc = 1,", "\t\td = 2,", '\t}, "e"},', "}")
		)
		expect(
			generate(
				lines("on:", "  push:", "    branches:", "    - main", "    - dev", "  pull_request:", "jobs: x", "")
			)
		).toBe(
			lines(
				"return {",
				"\ton = {",
				"\t\tpush = {",
				'\t\t\tbranches = {"main", "dev"},',
				"\t\t},",
				"\t\tpull_request = nil,",
				"\t},",
				'\tjobs = "x",',
				"}"
			)
		)
		expect(generate(lines("- - a", "  - b", "- - c", ""))).toBe('return {{"a", "b"}, {"c"}}')
		expect(generate(lines("-   a: 1", "    b: 2", "-   c", ""))).toBe(
			lines("return {{", "\ta = 1,", "\tb = 2,", '}, "c"}')
		)
		expect(generate(lines("-", "- ", "-   # c", "- x", ""))).toBe('return {nil, nil, nil, "x"}')
		expect(generate(lines("-", "  a: 1", "-", "  - b", ""))).toBe(lines("return {{", "\ta = 1,", '}, {"b"}}'))
		expect(generate(lines("- a: 1", "  b:", "    - x", "    - y", "  c: {d: 2}", "- - 1", "  - 2", "- ~", ""))).toBe(
			lines("return {{", "\ta = 1,", '\tb = {"x", "y"},', "\tc = {", "\t\td = 2,", "\t},", "}, {1, 2}, nil}")
		)
		expect(generate(lines("a:", "- 1", "b:", "- 2", "- 3", "c: 4", ""))).toBe(
			lines("return {", "\ta = {1},", "\tb = {2, 3},", "\tc = 4,", "}")
		)
		expect(generate(lines("a:", " - 1", " - 2", ""))).toBe(lines("return {", "\ta = {1, 2},", "}"))
		expect(generate(lines("a:", " b:", "  c: 1", " d: 2", ""))).toBe(
			lines("return {", "\ta = {", "\t\tb = {", "\t\t\tc = 1,", "\t\t},", "\t\td = 2,", "\t},", "}")
		)
		expect(generate(lines("a:", "  b:", "    c:", "      d:", "        e: 1", "      f: 2", "  g: 3", "h: 4", ""))).toBe(
			lines(
				"return {",
				"\ta = {",
				"\t\tb = {",
				"\t\t\tc = {",
				"\t\t\t\td = {",
				"\t\t\t\t\te = 1,",
				"\t\t\t\t},",
				"\t\t\t\tf = 2,",
				"\t\t\t},",
				"\t\t},",
				"\t\tg = 3,",
				"\t},",
				"\th = 4,",
				"}"
			)
		)
		expect(
			generate(
				lines(
					"name: CI",
					"on:",
					"  push:",
					"    branches: [ main ]",
					"  pull_request:",
					"    branches: [ main ]",
					"jobs:",
					"  build:",
					"    runs-on: ubuntu-latest",
					"    steps:",
					"      - uses: actions/checkout@v2",
					"      - name: Run",
					"        run: |",
					'          echo "${{ github.ref }}" # not a comment',
					"          if [ -f x ]; then echo a: b; fi",
					"",
					"          done",
					"      - name: Two",
					"        with:",
					"          key: ${{ secrets.KEY }}",
					""
				)
			)
		).toBe(
			lines(
				"return {",
				'\tname = "CI",',
				"\ton = {",
				"\t\tpush = {",
				'\t\t\tbranches = {"main"},',
				"\t\t},",
				"\t\tpull_request = {",
				'\t\t\tbranches = {"main"},',
				"\t\t},",
				"\t},",
				"\tjobs = {",
				"\t\tbuild = {",
				'\t\t\t["runs-on"] = "ubuntu-latest",',
				"\t\t\tsteps = {{",
				'\t\t\t\tuses = "actions/checkout@v2",',
				"\t\t\t}, {",
				'\t\t\t\tname = "Run",',
				'\t\t\t\trun = "echo \\"${{ github.ref }}\\" # not a comment\\nif [ -f x ]; then echo a: b; fi\\n\\ndone\\n",',
				"\t\t\t}, {",
				'\t\t\t\tname = "Two",',
				"\t\t\t\twith = {",
				'\t\t\t\t\tkey = "${{ secrets.KEY }}",',
				"\t\t\t\t},",
				"\t\t\t}},",
				"\t\t},",
				"\t},",
				"}"
			)
		)
		expect(
			generate(
				lines(
					"lockfileVersion: '6.0'",
					"",
					"settings:",
					"  autoInstallPeers: true",
					"",
					"packages:",
					"",
					"  /@types/node@20.0.0:",
					"    resolution: {integrity: sha512-abc==}",
					"    dev: true",
					"",
					"  /x@1.0.0:",
					"    resolution: {integrity: sha1-x}",
					"    engines: {node: '>=0.10.0'}",
					""
				)
			)
		).toBe(
			lines(
				"return {",
				'\tlockfileVersion = "6.0",',
				"\tsettings = {",
				"\t\tautoInstallPeers = true,",
				"\t},",
				"\tpackages = {",
				'\t\t["/@types/node@20.0.0"] = {',
				"\t\t\tresolution = {",
				'\t\t\t\tintegrity = "sha512-abc==",',
				"\t\t\t},",
				"\t\t\tdev = true,",
				"\t\t},",
				'\t\t["/x@1.0.0"] = {',
				"\t\t\tresolution = {",
				'\t\t\t\tintegrity = "sha1-x",',
				"\t\t\t},",
				"\t\t\tengines = {",
				'\t\t\t\tnode = ">=0.10.0",',
				"\t\t\t},",
				"\t\t},",
				"\t},",
				"}"
			)
		)
		expect(generate("-")).toBe("return {nil}")

		expect(generate("a: - b\n")).toBe("refused: block sequence entries are not allowed in this context")
		expect(generate(lines("- a", "- - b", " -c", ""))).toBe(
			"refused: while parsing a block collection, did not find expected '-' indicator"
		)
		expect(generate(lines("a:", "- 1", "  b: 2", ""))).toBe(
			"refused: mapping values are not allowed in this context"
		)
		expect(decodeYaml(lines("- a", "b: 1", "")).ok).toBe(false)
		expect(generate(lines("-\tx", "-\t- y", ""))).toBe("refused: '-' must be followed by a valid YAML whitespace")
	end)

	it("copies the anchored node for each alias to it and refuses an unknown anchor", function()
		expect(
			generate(
				lines(
					"base: &b",
					"  k: v",
					"copy: *b",
					"scalar: &s 5",
					"list:",
					"  - *s",
					"  - &t [1, 2]",
					"  - *t",
					""
				)
			)
		).toBe(
			lines(
				"return {",
				"\tbase = {",
				'\t\tk = "v",',
				"\t},",
				"\tcopy = {",
				'\t\tk = "v",',
				"\t},",
				"\tscalar = 5,",
				"\tlist = {5, {1, 2}, {1, 2}},",
				"}"
			)
		)
		expect(generate(lines("&k key: v", "other: *k", ""))).toBe(
			lines("return {", '\tkey = "v",', '\tother = "key",', "}")
		)
		expect(generate(lines("- &a key: v", "- *a", ""))).toBe(lines("return {{", '\tkey = "v",', '}, "key"}'))
		expect(generate("a: [&x [1], *x]\n")).toBe(lines("return {", "\ta = {{1}, {1}},", "}"))
		expect(generate(lines("a: &x 1", "b: *x", ""))).toBe(lines("return {", "\ta = 1,", "\tb = 1,", "}"))
		expect(generate(lines("base: &b", "  k: v", "other: *b", ""))).toBe(
			lines("return {", "\tbase = {", '\t\tk = "v",', "\t},", "\tother = {", '\t\tk = "v",', "\t},", "}")
		)
		expect(generate(lines("- &m", "  a: 1", "- *m", ""))).toBe(
			lines("return {{", "\ta = 1,", "}, {", "\ta = 1,", "}}")
		)
		expect(generate(lines("base: &b {x: 1}", "derived:", "  <<: *b", "  y: 2", ""))).toBe(
			lines(
				"return {",
				"\tbase = {",
				"\t\tx = 1,",
				"\t},",
				"\tderived = {",
				'\t\t["<<"] = {',
				"\t\t\tx = 1,",
				"\t\t},",
				"\t\ty = 2,",
				"\t},",
				"}"
			)
		)
		expect(generate(lines("a: &x 1", "b: &x 2", "c: *x", ""))).toBe(
			lines("return {", "\ta = 1,", "\tb = 2,", "\tc = 2,", "}")
		)
		expect(generate("a: {b: &x {c: 1}, d: *x}\n")).toBe(
			lines(
				"return {",
				"\ta = {",
				"\t\tb = {",
				"\t\t\tc = 1,",
				"\t\t},",
				"\t\td = {",
				"\t\t\tc = 1,",
				"\t\t},",
				"\t},",
				"}"
			)
		)
		expect(generate("a: [&x 1, *x]\n")).toBe(lines("return {", "\ta = {1, 1},", "}"))
		expect(generate(lines("a: &s", "  - 1", "b: *s", ""))).toBe(lines("return {", "\ta = {1},", "\tb = {1},", "}"))
		expect(generate("--- &a 5\n")).toBe("return 5")
		expect(generate(lines("a: &x", "  b: 1", "c: *x", ""))).toBe(
			lines("return {", "\ta = {", "\t\tb = 1,", "\t},", "\tc = {", "\t\tb = 1,", "\t},", "}")
		)
		expect(generate(lines("a: &x", "b: *x", ""))).toBe(lines("return {", "\ta = nil,", "\tb = nil,", "}"))
		expect(generate(lines("a: &x [&x 1, *x]", "b: *x", ""))).toBe(
			lines("return {", "\ta = {1, 1},", "\tb = 1,", "}")
		)
		expect(generate("a: {&k b: 1, c: *k}\n")).toBe(
			lines("return {", "\ta = {", "\t\tb = 1,", '\t\tc = "b",', "\t},", "}")
		)
		expect(generate(lines("a: &k x", "*k : 1", ""))).toBe(lines("return {", '\ta = "x",', "\tx = 1,", "}"))
		expect(generate(lines("a: &x.y-z 1", "b: *x.y-z", ""))).toBe(lines("return {", "\ta = 1,", "\tb = 1,", "}"))
		expect(generate(lines("a: &s", "- 1", "b: *s", ""))).toBe(lines("return {", "\ta = {1},", "\tb = {1},", "}"))
		expect(generate(lines("a: &x", "  - 1", "  - 2", "b: *x", ""))).toBe(
			lines("return {", "\ta = {1, 2},", "\tb = {1, 2},", "}")
		)
		expect(generate(lines("- &x", "  - 1", "- *x", ""))).toBe("return {{1}, {1}}")
		expect(generate(lines("a: &k x", "b: {*k : 1}", ""))).toBe(
			lines("return {", '\ta = "x",', "\tb = {", "\t\tx = 1,", "\t},", "}")
		)
		expect(generate(lines("base: &base", "  x: 1", "child:", "  <<: *base", "  y: 2", ""))).toBe(
			lines(
				"return {",
				"\tbase = {",
				"\t\tx = 1,",
				"\t},",
				"\tchild = {",
				'\t\t["<<"] = {',
				"\t\t\tx = 1,",
				"\t\t},",
				"\t\ty = 2,",
				"\t},",
				"}"
			)
		)
		expect(generate("a: [&x 1, *x, &y {b: 2}, *y]\n")).toBe(
			lines("return {", "\ta = {1, 1, {", "\t\tb = 2,", "\t}, {", "\t\tb = 2,", "\t}},", "}")
		)
		expect(generate("a: &x\u{FEFF} 1\n")).toBe(lines("return {", '\ta = "\u{FEFF} 1",', "}"))

		expect(decodeYaml("a: *nothere\n").ok).toBe(false)
		expect(generate("a: &x [1, *x]\n")).toBe("refused: Rojo cannot convert YAML to Luau because of a parsing error")
		expect(decodeYaml(lines("a: &k x", "b: *k:", "")).ok).toBe(false)
		expect(decodeYaml("a: &x &y 1\n").ok).toBe(false)
		expect(generate("&a - x\n")).toBe("refused: block sequence entries are not allowed in this context")
		expect(decodeYaml("*a\n").ok).toBe(false)
	end)

	it("reads tags as yaml-rust2's loader does", function()
		expect(generate("a: !!str 123\n")).toBe(lines("return {", '\ta = "123",', "}"))
		expect(
			generate(
				lines(
					"a: !!int 5",
					'b: !!int "5"',
					"c: !!float 1",
					"d: !!float 2.5",
					"e: !!bool true",
					"f: !!null ~",
					"g: !!str true",
					""
				)
			)
		).toBe(
			lines(
				"return {",
				"\ta = 5,",
				'\tb = "5",',
				"\tc = 1,",
				"\td = 2.5,",
				"\te = true,",
				"\tf = nil,",
				'\tg = "true",',
				"}"
			)
		)
		expect(
			generate(
				lines(
					"a: !foo 5",
					"b: ! 5",
					"c: !<tag:yaml.org,2002:int> 5",
					"d: !!python/name:foo.bar",
					"e: !!binary aGk=",
					""
				)
			)
		).toBe(lines("return {", '\ta = "5",', '\tb = "5",', '\tc = "5",', '\td = "",', '\te = "aGk=",', "}"))
		expect(generate(lines("a: !!map", "  b: 1", "c: !!seq [1]", ""))).toBe(
			lines("return {", "\ta = {", "\t\tb = 1,", "\t},", "\tc = {1},", "}")
		)
		expect(generate(lines("%TAG !e! tag:yaml.org,2002:", "---", "a: !e!int 5", ""))).toBe(
			lines("return {", "\ta = 5,", "}")
		)
		expect(generate(lines("a: !!str &x 5", "b: &y !!str 6", "c: *x", "d: *y", ""))).toBe(
			lines("return {", '\ta = "5",', '\tb = "6",', '\tc = "5",', '\td = "6",', "}")
		)
		expect(generate("a: [!!str 1, !!int 2, ! 3]\n")).toBe(lines("return {", '\ta = {"1", 2, "3"},', "}"))
		expect(generate(lines("- !!python/name:a.b", "- x", ""))).toBe('return {"", "x"}')
		expect(generate(lines("%TAG ! tag:x,2000:", "---", "a: 1", ""))).toBe(lines("return {", "\ta = 1,", "}"))
		expect(generate("!!int x: 1\n")).toBe("return {\n}")
		expect(generate("a: [!!str , !!null ~]\n")).toBe(lines("return {", '\ta = {"", nil},', "}"))
		expect(generate("!!str\n")).toBe('return ""')
		expect(generate(lines("- !!map", "  a: 1", ""))).toBe(lines("return {{", "\ta = 1,", "}}"))

		expect(generate("a: !!bool yes\n")).toBe("refused: Rojo cannot convert YAML to Luau because of a parsing error")
		expect(generate("a: !!int 0x10\n")).toBe("refused: Rojo cannot convert YAML to Luau because of a parsing error")
		expect(generate("a: !!null\n")).toBe("refused: Rojo cannot convert YAML to Luau because of a parsing error")
		expect(generate("a: !e!int 5\n")).toBe("refused: the handle wasn't declared")
		expect(
			generate(
				lines(
					"%TAG !e! tag:yaml.org,2002:",
					"%TAG !f! tag:yaml.org,2002:",
					"---",
					"a: !f!int 5",
					"b: !e!int 6",
					""
				)
			)
		).toBe("refused: the handle wasn't declared")
		expect(generate("a: !<x 1\n")).toBe("refused: while scanning a verbatim tag, did not find the expected '>'")
	end)

	it("reads comments, blanks, tabs and every line end, and ends the stream at NUL", function()
		expect(generate(lines("a: 1#x", "b: value # comment", ""))).toBe(
			lines("return {", '\ta = "1#x",', '\tb = "value",', "}")
		)
		expect(generate(lines("# head", "a: 1 # tail", "# mid", "b: 2", ""))).toBe(
			lines("return {", "\ta = 1,", "\tb = 2,", "}")
		)
		expect(generate("a: 1\rb: 2\r")).toBe(lines("return {", "\ta = 1,", "\tb = 2,", "}"))
		expect(generate("a: b#c\n")).toBe(lines("return {", '\ta = "b#c",', "}"))
		expect(generate(lines("a:", "  # c", "  b: 1", ""))).toBe(
			lines("return {", "\ta = {", "\t\tb = 1,", "\t},", "}")
		)
		expect(generate(lines("a: 1", "\t", "b: 2", ""))).toBe(lines("return {", "\ta = 1,", "\tb = 2,", "}"))
		expect(generate(lines("a: 1\r", "b:\r", "  - x\r", ""))).toBe(
			lines("return {", "\ta = 1,", '\tb = {"x"},', "}")
		)
		expect(generate("a: x\ty\n")).toBe(lines("return {", '\ta = "x\\ty",', "}"))
		expect(generate(lines("a: 'x' # c", 'b: "y"\t# d', ""))).toBe(
			lines("return {", '\ta = "x",', '\tb = "y",', "}")
		)
		expect(generate(lines("a: value\t# comment", "b: x\t", ""))).toBe(
			lines("return {", '\ta = "value",', '\tb = "x",', "}")
		)
		expect(generate(lines('a:\t"v"', "b:\t[1]", ""))).toBe(lines("return {", '\ta = "v",', "\tb = {1},", "}"))
		expect(generate(lines("a: 1   ", "b:   ", "  c: 2  ", ""))).toBe(
			lines("return {", "\ta = 1,", "\tb = {", "\t\tc = 2,", "\t},", "}")
		)
		expect(generate(lines("a: 1\r", "\r", "b: 2", "\rc: 3", ""))).toBe(
			lines("return {", "\ta = 1,", "\tb = 2,", "\tc = 3,", "}")
		)
		expect(generate("\u{FEFF}a: 1\n")).toBe(lines("return {", '\t["\u{FEFF}a"] = 1,', "}"))
		expect(generate("\u{FEFF}")).toBe('return "\u{FEFF}"')
		expect(generate("a\t: 1\n")).toBe(lines("return {", "\ta = 1,", "}"))
		expect(generate("\ta: 1\n")).toBe(lines("return {", "\ta = 1,", "}"))
		expect(generate("a: 1\0b: 2\n")).toBe(lines("return {", "\ta = 1,", "}"))

		expect(generate('a: "x"#c\n')).toBe("refused: comments must be separated from other tokens by whitespace")
		expect(generate("a:\tb\n")).toBe("refused: ':' must be followed by a valid YAML whitespace")
		expect(generate(lines("a:    1", "b:\t2", ""))).toBe("refused: ':' must be followed by a valid YAML whitespace")
		expect(generate(lines("a:", "\tb: 1", ""))).toBe(
			"refused: tabs disallowed within this context (block indentation)"
		)
		expect(generate("a: [1]#c\n")).toBe("refused: comments must be separated from other tokens by whitespace")
	end)

	it("reads plain scalars holding indicators and refuses a value where a key cannot be", function()
		expect(generate("a: b:c\n")).toBe(lines("return {", '\ta = "b:c",', "}"))
		expect(generate("a: http://x.com:80/p?q=1#f\n")).toBe(
			lines("return {", '\ta = "http://x.com:80/p?q=1#f",', "}")
		)
		expect(generate("a: b, c [d] {e}\n")).toBe(lines("return {", '\ta = "b, c [d] {e}",', "}"))
		expect(generate(lines("a: x & y", "b: x * y", "c: x ! y", ""))).toBe(
			lines("return {", '\ta = "x & y",', '\tb = "x * y",', '\tc = "x ! y",', "}")
		)
		expect(generate(lines("a: x | y", "b: x > y", ""))).toBe(
			lines("return {", '\ta = "x | y",', '\tb = "x > y",', "}")
		)
		expect(generate("a: '%'\n")).toBe(lines("return {", '\ta = "%",', "}"))
		expect(generate(lines("a: x [y]", "b: x {y}", ""))).toBe(
			lines("return {", '\ta = "x [y]",', '\tb = "x {y}",', "}")
		)
		expect(generate(lines("a: 50%", "b: '%x'", ""))).toBe(lines("return {", '\ta = "50%",', '\tb = "%x",', "}"))
		expect(generate("a: " .. string.rep("x", 1500) .. "\n")).toBe(
			lines("return {", `\ta = "{string.rep("x", 1500)}",`, "}")
		)
		expect(generate("a: " .. string.rep("y", 3000) .. "\n")).toBe(
			lines("return {", `\ta = "{string.rep("y", 3000)}",`, "}")
		)

		expect(generate("a: b: c\n")).toBe("refused: mapping values are not allowed in this context")
		expect(generate(lines("a: -", "b: --", "c: -x", ""))).toBe(
			"refused: block sequence entries are not allowed in this context"
		)
		expect(generate(lines("a: ?", "b: ?x", ""))).toBe("refused: mapping keys are not allowed in this context")
		expect(generate("a: @x\n")).toBe("refused: unexpected character: `@'")
		expect(generate("a: `x`\n")).toBe("refused: unexpected character: ``'")
		expect(generate("a: %x\n")).toBe("refused: unexpected character: `%'")
		expect(generate(string.rep("x", 1100) .. ": 1\n")).toBe(
			"refused: mapping values are not allowed in this context"
		)
		expect(generate(string.rep("x", 1025) .. ": 1\n")).toBe(
			"refused: mapping values are not allowed in this context"
		)
		expect(decodeYaml(lines("a#b: 1", "c #d: 2", "")).ok).toBe(false)
		expect(decodeYaml(lines("a: 1", "b", "")).ok).toBe(false)
		expect(generate(lines("a: 1", "  b: 2", ""))).toBe("refused: mapping values are not allowed in this context")
		expect(generate('a: "x" y\n')).toBe("refused: invalid trailing content after double-quoted scalar")
		expect(decodeYaml('"a":1\n').ok).toBe(false)
	end)

	it("requires exactly one document", function()
		expect(generate(lines("---", "a: 1", ""))).toBe(lines("return {", "\ta = 1,", "}"))
		expect(generate("---\n")).toBe("return nil")
		expect(generate(lines("a: 1", "...", ""))).toBe(lines("return {", "\ta = 1,", "}"))
		expect(generate(lines("%YAML 1.2", "---", "a: 1", ""))).toBe(lines("return {", "\ta = 1,", "}"))
		expect(generate("--- 5\n")).toBe("return 5")
		expect(generate("hello\n")).toBe('return "hello"')
		expect(generate("[1, 2]\n")).toBe("return {1, 2}")
		expect(generate("{a: 1}\n")).toBe(lines("return {", "\ta = 1,", "}"))
		expect(generate(lines("a: 1", "...", "...", ""))).toBe(lines("return {", "\ta = 1,", "}"))
		expect(generate(lines("--- # c", "a: 1", ""))).toBe(lines("return {", "\ta = 1,", "}"))
		expect(generate("--- [1, 2]\n")).toBe("return {1, 2}")
		expect(generate('--- "x"\n')).toBe('return "x"')
		expect(generate(lines("%FOO bar baz", "---", "a: 1", ""))).toBe(lines("return {", "\ta = 1,", "}"))
		expect(generate(lines("a: 1", "... # c", ""))).toBe(lines("return {", "\ta = 1,", "}"))
		expect(generate("---x\n")).toBe('return "---x"')
		expect(generate(lines("---", "# comment", ""))).toBe("return nil")
		expect(generate(lines("# c", "", "---", "a: 1", ""))).toBe(lines("return {", "\ta = 1,", "}"))
		expect(generate(lines("---   ", "a: 1", ""))).toBe(lines("return {", "\ta = 1,", "}"))
		expect(generate(lines("  a: 1", "  b: 2", ""))).toBe(lines("return {", "\ta = 1,", "\tb = 2,", "}"))
		expect(generate("&a\n")).toBe("return nil")
		expect(generate("\u{FEFF}---\n")).toBe('return "\u{FEFF}---"')

		expect(generate("")).toBe("refused: all YAML documents must contain a document")
		expect(generate("# nothing\n")).toBe("refused: all YAML documents must contain a document")
		expect(generate("# only a comment\n")).toBe("refused: all YAML documents must contain a document")
		expect(generate("...\n")).toBe("refused: all YAML documents must contain a document")
		expect(generate(lines("   ", "\t", ""))).toBe("refused: all YAML documents must contain a document")
		expect(generate(lines("%YAML 1.2", "...", ""))).toBe("refused: did not find expected <document start>")
		expect(generate(lines("---", "---", ""))).toBe(
			"refused: Rojo does not currently support multiple documents in a YAML file"
		)
		expect(generate(lines("a: 1", "---", "b: 2", ""))).toBe(
			"refused: Rojo does not currently support multiple documents in a YAML file"
		)
		expect(generate(lines("a: 1", "...", "b: 2", ""))).toBe(
			"refused: Rojo does not currently support multiple documents in a YAML file"
		)
		expect(generate(lines("a: 1", "...", "---", "b: 2", ""))).toBe(
			"refused: Rojo does not currently support multiple documents in a YAML file"
		)
		expect(generate("--- a: 1\n")).toBe("refused: mapping values are not allowed in this context")
		expect(generate("--- - a\n")).toBe("refused: block sequence entries are not allowed in this context")
		expect(decodeYaml(lines("a: 1", "%YAML 1.2", "---", "b: 2", "")).ok).toBe(false)
		expect(generate(lines("%YAML 1.2", "a: 1", ""))).toBe("refused: did not find expected <document start>")
		expect(generate(lines("%YAML 1.2", "%YAML 1.2", "---", "a: 1", ""))).toBe(
			"refused: duplicate version directive"
		)
		expect(generate(lines("a: 1", "... x", ""))).toBe("refused: invalid content after document end marker")
		expect(generate("---\ta: 1\n")).toBe("refused: mapping values are not allowed in this context")
		expect(generate(lines("[1]", "[2]", ""))).toBe("refused: did not find expected <document start>")
		expect(generate(lines("\u{FEFF}---", "a: 1", ""))).toBe(
			"refused: mapping values are not allowed in this context"
		)
		expect(generate(lines("  a: 1", "b: 2", ""))).toBe("refused: did not find expected <document start>")
		expect(generate(lines("a", "b: c", ""))).toBe("refused: mapping values are not allowed in this context")
		expect(generate(lines("%YAML x", "---", "a: 1", ""))).toBe(
			"refused: while scanning a YAML directive, did not find expected version number"
		)
		expect(decodeYaml(lines("%TAG x y", "---", "a: 1", "")).ok).toBe(false)
	end)

	it("refuses a key its mapping already holds", function()
		expect(generate(lines("a: 1", "b: 2", "a: 3", ""))).toBe('refused: String("a"): duplicated key in mapping')
		expect(generate(lines("1: a", "01: b", ""))).toBe("refused: Integer(1): duplicated key in mapping")
		expect(generate(lines("a: &k x", "x: 1", "*k : 2", ""))).toBe('refused: String("x"): duplicated key in mapping')
		expect(generate(lines("true: a", "True: b", ""))).toBe("refused: Boolean(true): duplicated key in mapping")
		expect(generate(lines("1.0: a", "1.0: b", ""))).toBe('refused: Real("1.0"): duplicated key in mapping')
		expect(generate(lines("0: a", "-0: b", ""))).toBe("refused: Integer(0): duplicated key in mapping")
		expect(generate(lines('"a": 1', "a: 2", ""))).toBe('refused: String("a"): duplicated key in mapping')
	end)

	it("refuses a null mapping key, which Rojo crashes on", function()
		expect(decodeYaml("~: a\n").ok).toBe(false)
		expect(decodeYaml(": a\n").ok).toBe(false)
		expect(decodeYaml(lines("-1: a", ".inf: b", "~x: c", "null: d", "")).ok).toBe(false)
		expect(decodeYaml("a: {~: 1}\n").ok).toBe(false)
	end)

	it("refuses text that is not valid UTF-8", function()
		expect(decodeYaml("a: \xFF\xFE\n").ok).toBe(false)
	end)

	it("keeps maps, arrays and nulls apart and names no path", function()
		local decoded = decodeYaml("a: [1, {}, ~]\nb: {}\n")
		local refused = decodeYaml("a: b: c\n")

		expect(decoded).toEqual({
			ok = true,
			value = {
				kind = "map",
				entries = {
					{
						key = "a",
						value = { kind = "array", items = { 1, { kind = "map", entries = {} }, { kind = "null" } } },
					},
					{ key = "b", value = { kind = "map", entries = {} } },
				},
			},
		})
		expect(refused.ok).toBe(false)
		expect(refused.error.path).toBe("")
	end)

	it("says a null key is refused because Rojo cannot build it", function()
		expect(generate("~: a\n")).toBe(
			"refused: Rojo cannot build a mapping with a null key (it crashes: nil cannot be a table key)"
		)
	end)
end)
