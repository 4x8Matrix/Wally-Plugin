local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local decodeToml = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeToml)
local encodeLuauValue = require(ReplicatedStorage.WallyPlugin.PluginUtilities.encodeLuauValue)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function lines(...: string): string
	return table.concat({ ... }, "\n")
end

local function generate(text: string): string
	local decoded = decodeToml(text)

	if not decoded.ok then
		return `refused: {decoded.error.message}`
	end

	return encodeLuauValue(decoded.value)
end

describe("decodeToml", function()
	it("sorts keys by bytes and brackets each key that is not an identifier", function()
		expect(
			generate(
				lines(
					"zeta = 1",
					"Alpha = 2",
					"_under = 3",
					'beta = "b"',
					'"with space" = 4',
					'"1invalidident" = "nice"',
					"true = true",
					"end = 5",
					"[object]",
					'hello = "world"',
					"B = 1",
					"a = 2",
					""
				)
			)
		).toBe(
			lines(
				"return {",
				'\t["1invalidident"] = "nice",',
				"\tAlpha = 2,",
				"\t_under = 3,",
				'\tbeta = "b",',
				'\t["end"] = 5,',
				"\tobject = {",
				"\t\tB = 1,",
				"\t\ta = 2,",
				'\t\thello = "world",',
				"\t},",
				'\t["true"] = true,',
				'\t["with space"] = 4,',
				"\tzeta = 1,",
				"}"
			)
		)
		expect(generate(lines('"\u{E9}" = 1', "z = 2", "Z = 3", '"\u{65E5}\u{672C}" = 4', "_ = 5", ""))).toBe(
			lines(
				"return {",
				"\tZ = 3,",
				"\t_ = 5,",
				"\tz = 2,",
				'\t["\u{E9}"] = 1,',
				'\t["\u{65E5}\u{672C}"] = 4,',
				"}"
			)
		)
		expect(generate(lines("and = 1", "nil = 2", "function = 3", "local = 4", "continue = 5", "type = 6", ""))).toBe(
			lines(
				"return {",
				'\t["and"] = 1,',
				"\tcontinue = 5,",
				'\t["function"] = 3,',
				'\t["local"] = 4,',
				'\t["nil"] = 2,',
				"\ttype = 6,",
				"}"
			)
		)
		expect(generate(lines('a."b.c" = 1', "a.'d' = 2", '"x y".z = 3', ""))).toBe(
			lines(
				"return {",
				"\ta = {",
				'\t\t["b.c"] = 1,',
				"\t\td = 2,",
				"\t},",
				'\t["x y"] = {',
				"\t\tz = 3,",
				"\t},",
				"}"
			)
		)
		expect(generate('"" = 1\n')).toBe(lines("return {", '\t[""] = 1,', "}"))
		expect(generate(lines('[""]', "x = 1", ""))).toBe(lines("return {", '\t[""] = {', "\t\tx = 1,", "\t},", "}"))
		expect(generate(lines("1 = 1", "2.5 = 2", "-3 = 3", ""))).toBe(
			lines("return {", '\t["-3"] = 3,', '\t["1"] = 1,', '\t["2"] = {', '\t\t["5"] = 2,', "\t},", "}")
		)
		expect(generate(lines('[ a . "b" ]', "c = 1", "[[ d . e ]] # comment", "f = 2", ""))).toBe(
			lines(
				"return {",
				"\ta = {",
				"\t\tb = {",
				"\t\t\tc = 1,",
				"\t\t},",
				"\t},",
				"\td = {",
				"\t\te = {{",
				"\t\t\tf = 2,",
				"\t\t}},",
				"\t},",
				"}"
			)
		)
		expect(generate(lines("a . b = 1", " a .c= 2", ""))).toBe(
			lines("return {", "\ta = {", "\t\tb = 1,", "\t\tc = 2,", "\t},", "}")
		)
		expect(generate("a_very-long_key-name_0123456789 = 1\n")).toBe(
			lines("return {", '\t["a_very-long_key-name_0123456789"] = 1,', "}")
		)
	end)

	it("prints every integer and float as Rojo prints a float", function()
		expect(
			generate(
				lines(
					"int = 1234",
					"float = 1234.5452",
					"neg = -17",
					"big = 9007199254740993",
					"exp = 5e+22",
					"flt = 6.626e-34",
					"zero = 0.0",
					"negzero = -0.0",
					"intnegzero = -0",
					"intpluszero = +0",
					"plus = +99",
					"hex = 0xDEADBEEF",
					"oct = 0o755",
					"bin = 0b1101",
					"under = 1_000_000",
					"frac = 3.14_15",
					"expzero = 1e05",
					"bigexp = 1E3",
					""
				)
			)
		).toBe(
			lines(
				"return {",
				"\tbig = 9007199254740992,",
				"\tbigexp = 1000,",
				"\tbin = 13,",
				"\texp = 50000000000000000000000,",
				"\texpzero = 100000,",
				"\tfloat = 1234.5452,",
				"\tflt = 0.0000000000000000000000000000000006626,",
				"\tfrac = 3.1415,",
				"\thex = 3735928559,",
				"\tint = 1234,",
				"\tintnegzero = 0,",
				"\tintpluszero = 0,",
				"\tneg = -17,",
				"\tnegzero = -0,",
				"\toct = 493,",
				"\tplus = 99,",
				"\tunder = 1000000,",
				"\tzero = 0,",
				"}"
			)
		)
		expect(
			generate(
				lines("a = 0e0", "b = -0e0", "c = 1.0e-3", "d = 3e-0", "e = 1_0.0_1e1_0", "f = +1.5", "g = -0.0e0", "")
			)
		).toBe(
			lines(
				"return {",
				"\ta = 0,",
				"\tb = -0,",
				"\tc = 0.001,",
				"\td = 3,",
				"\te = 100100000000,",
				"\tf = 1.5,",
				"\tg = -0,",
				"}"
			)
		)
		expect(generate(lines("a = 0x0001", "b = 0o0007", "c = 0b0001", "d = 0xdead_beef", ""))).toBe(
			lines("return {", "\ta = 1,", "\tb = 7,", "\tc = 1,", "\td = 3735928559,", "}")
		)
	end)

	it("prints infinities and NaN by name", function()
		expect(
			generate(lines("inf = inf", "pinf = +inf", "ninf = -inf", "nan = nan", "pnan = +nan", "nnan = -nan", ""))
		).toBe(
			lines(
				"return {",
				"\tinf = math.huge,",
				"\tnan = 0/0,",
				"\tninf = -math.huge,",
				"\tnnan = 0/0,",
				"\tpinf = math.huge,",
				"\tpnan = 0/0,",
				"}"
			)
		)
	end)

	it("rounds an integer beyond 2^53 as Rojo does", function()
		expect(
			generate(
				lines(
					"a = 9223372036854775807",
					"b = -9223372036854775808",
					"c = 0x7FFFFFFFFFFFFFFF",
					"d = 0o777777777777777777777",
					"e = 0b111111111111111111111111111111111111111111111111111111111111111",
					""
				)
			)
		).toBe(
			lines(
				"return {",
				"\ta = 9223372036854776000,",
				"\tb = -9223372036854776000,",
				"\tc = 9223372036854776000,",
				"\td = 9223372036854776000,",
				"\te = 9223372036854776000,",
				"}"
			)
		)
		expect(
			generate(
				lines(
					"a = 0x7FFFFFFFFFFFFDFF",
					"b = 9223372036854775295",
					"c = 0x7FFFFFFFFFFFFE00",
					"d = 0x20000000000001",
					"e = 0x20000000000003",
					""
				)
			)
		).toBe(
			lines(
				"return {",
				"\ta = 9223372036854775000,",
				"\tb = 9223372036854775000,",
				"\tc = 9223372036854776000,",
				"\td = 9007199254740992,",
				"\te = 9007199254740996,",
				"}"
			)
		)
		expect(
			generate(
				lines(
					"a = 0b1100001001001101110101010111001001001010100110001111011",
					"b = 0b10110100011101100001110010110011111100101011011100000110",
					""
				)
			)
		).toBe(lines("return {", "\ta = 27345862311365756,", "\tb = 50795361458108170,", "}"))
	end)

	it("refuses an integer outside 64 bits and a float that overflows", function()
		expect(generate(lines("a = 1e-400", "b = -1e-400", ""))).toBe(lines("return {", "\ta = 0,", "\tb = -0,", "}"))

		expect(decodeToml("a = 9223372036854775808\n").ok).toBe(false)
		expect(decodeToml("a = -9223372036854775809\n").ok).toBe(false)
		expect(decodeToml("a = 0x8000000000000000\n").ok).toBe(false)
		expect(decodeToml("a = 0o1000000000000000000000\n").ok).toBe(false)
		expect(decodeToml("a = 0b1000000000000000000000000000000000000000000000000000000000000000\n").ok).toBe(false)
		expect(decodeToml("a = 1e400\n").ok).toBe(false)
		expect(decodeToml("a = -1e400\n").ok).toBe(false)
	end)

	it("reads a plus sign before a prefixed or a negative number", function()
		expect(generate("a = +0x10\n")).toBe(lines("return {", "\ta = 16,", "}"))
		expect(generate("a = +0o10\n")).toBe(lines("return {", "\ta = 8,", "}"))
		expect(generate("a = +0b10\n")).toBe(lines("return {", "\ta = 2,", "}"))
		expect(generate(lines("a = +-1.5", "b = +-inf", "c = +-nan", "d = +-1e+5", "e = +-1_000", ""))).toBe(
			lines("return {", "\ta = -1.5,", "\tb = -math.huge,", "\tc = 0/0,", "\td = -100000,", "\te = -1000,", "}")
		)
		expect(generate("a = +-1\n")).toBe(lines("return {", "\ta = -1,", "}"))

		expect(decodeToml("a = +-0x10\n").ok).toBe(false)
		expect(decodeToml("a = ++1\n").ok).toBe(false)
	end)

	it("writes an offset datetime with its fraction trimmed and its offset as +HH:MM", function()
		expect(
			generate(
				lines(
					"a = 1979-05-27T07:32:00Z",
					"b = 1979-05-27T00:32:00.999999-07:00",
					"c = 1979-05-27 07:32:00Z",
					"d = 1979-05-27t07:32:00z",
					"e = 1979-05-27T07:32:00.5+05:30",
					"f = 1979-05-27T07:32:00.000-00:00",
					"g = 1979-05-27T07:32:00.120Z",
					"h = 1979-05-27T07:32:00.1234567891Z",
					"i = 1979-05-27T07:32:00.0000000001Z",
					"j = 1979-05-27T07:32:00-00:30",
					"k = 1979-05-27T07:32:00+00:00",
					""
				)
			)
		).toBe(
			lines(
				"return {",
				'\ta = "1979-05-27T07:32:00Z",',
				'\tb = "1979-05-27T00:32:00.999999-07:00",',
				'\tc = "1979-05-27T07:32:00Z",',
				'\td = "1979-05-27T07:32:00Z",',
				'\te = "1979-05-27T07:32:00.5+05:30",',
				'\tf = "1979-05-27T07:32:00+00:00",',
				'\tg = "1979-05-27T07:32:00.12Z",',
				'\th = "1979-05-27T07:32:00.123456789Z",',
				'\ti = "1979-05-27T07:32:00Z",',
				'\tj = "1979-05-27T07:32:00+00:30",',
				'\tk = "1979-05-27T07:32:00+00:00",',
				"}"
			)
		)
		expect(generate(lines("a = 1979-05-27 00:32:00.999999-07:00", "b = 1979-05-27t07:32:00+07:00", ""))).toBe(
			lines("return {", '\ta = "1979-05-27T00:32:00.999999-07:00",', '\tb = "1979-05-27T07:32:00+07:00",', "}")
		)
	end)

	it("writes a local datetime, a local date and a local time", function()
		expect(
			generate(lines("a = 1979-05-27T07:32:00", "b = 1979-05-27T00:32:00.999999", "c = 1979-05-27 07:32:00", ""))
		).toBe(
			lines(
				"return {",
				'\ta = "1979-05-27T07:32:00",',
				'\tb = "1979-05-27T00:32:00.999999",',
				'\tc = "1979-05-27T07:32:00",',
				"}"
			)
		)
		expect(generate(lines("a = 1979-05-27", "b = 0000-01-01", ""))).toBe(
			lines("return {", '\ta = "1979-05-27",', '\tb = "0000-01-01",', "}")
		)
		expect(generate(lines("a = 07:32:00", "b = 00:32:00.999999", "c = 00:32:00.500", "d = 23:59:59.000000001", ""))).toBe(
			lines(
				"return {",
				'\ta = "07:32:00",',
				'\tb = "00:32:00.999999",',
				'\tc = "00:32:00.5",',
				'\td = "23:59:59.000000001",',
				"}"
			)
		)
		expect(generate(lines("a = 07:32:00.0", "b = 1979-05-27T07:32:00.000000000Z", ""))).toBe(
			lines("return {", '\ta = "07:32:00",', '\tb = "1979-05-27T07:32:00Z",', "}")
		)
		expect(generate("a = 1979-05-27 # c\n")).toBe(lines("return {", '\ta = "1979-05-27",', "}"))
	end)

	it("refuses a time without seconds", function()
		expect(decodeToml("t = 07:32\n").ok).toBe(false)
		expect(decodeToml("t = 1979-05-27T07:32Z\n").ok).toBe(false)
		expect(decodeToml("t = 1979-05-27T07:32\n").ok).toBe(false)
	end)

	it("accepts the day, hour and offset fields Rojo accepts and refuses the rest", function()
		expect(generate("a = 1979-02-30\n")).toBe(lines("return {", '\ta = "1979-02-30",', "}"))
		expect(generate("a = 1979-04-31T07:32:00\n")).toBe(lines("return {", '\ta = "1979-04-31T07:32:00",', "}"))
		expect(generate("a = 1979-02-29\n")).toBe(lines("return {", '\ta = "1979-02-29",', "}"))
		expect(generate(lines("a = 24:00:00", "b = 1979-05-27T24:30:00Z", ""))).toBe(
			lines("return {", '\ta = "24:00:00",', '\tb = "1979-05-27T24:30:00Z",', "}")
		)
		expect(generate("a = 1979-05-27T07:32:00+24:00\n")).toBe(
			lines("return {", '\ta = "1979-05-27T07:32:00+24:00",', "}")
		)
		expect(generate(lines("a = 1979-05-27T07:32:00+99:99", "b = 1979-05-27T07:32:00-99:99", ""))).toBe(
			lines("return {", '\ta = "1979-05-27T07:32:00+99:99",', '\tb = "1979-05-27T07:32:00-99:99",', "}")
		)

		expect(decodeToml("a = 1979-13-01\n").ok).toBe(false)
		expect(decodeToml("a = 1979-00-01\n").ok).toBe(false)
		expect(decodeToml("a = 1979-01-32\n").ok).toBe(false)
		expect(decodeToml("a = 1979-01-00\n").ok).toBe(false)
		expect(decodeToml("a = 25:00:00\n").ok).toBe(false)
		expect(decodeToml("a = 07:60:00\n").ok).toBe(false)
		expect(decodeToml("a = 07:00:60\n").ok).toBe(false)
		expect(decodeToml("a = 1979-05-27  07:32:00\n").ok).toBe(false)
		expect(decodeToml("a = 1979-05-27T07:32:00.Z\n").ok).toBe(false)
		expect(decodeToml("a = 07:32:00Z\n").ok).toBe(false)
		expect(decodeToml("a = 1979-05-27T07:32:00+0700\n").ok).toBe(false)
		expect(decodeToml("a = 1979-05-27 07\n").ok).toBe(false)
		expect(decodeToml("a = 1979-05-27T\n").ok).toBe(false)
		expect(decodeToml("a = 1979-5-27\n").ok).toBe(false)
		expect(decodeToml("a = 79-05-27\n").ok).toBe(false)
		expect(decodeToml("a = 1979-05-27T7:32:00\n").ok).toBe(false)
		expect(decodeToml("a = 07:32:0\n").ok).toBe(false)
		expect(decodeToml("a = 07:32:00.\n").ok).toBe(false)
		expect(decodeToml("a = 1979-05-27T07:32:00 Z\n").ok).toBe(false)
		expect(decodeToml("a = 1979-05-27T07:32:00+07\n").ok).toBe(false)
		expect(decodeToml("a = 1979-05-27_\n").ok).toBe(false)
		expect(decodeToml("a = -1979-05-27\n").ok).toBe(false)
		expect(decodeToml("a = +1979-05-27\n").ok).toBe(false)
		expect(decodeToml("a = 1979-05-27T07:32:00.5abc\n").ok).toBe(false)
	end)

	it("reads inline tables written on one line", function()
		expect(
			generate(
				lines(
					"point = { x = 1, y = 2 }",
					"nested = { b = { c = 1 }, d.e = 2, d.f = 3 }",
					"empty = {}",
					"spaced = { }",
					"witharray = { list = [",
					"1,",
					"2,",
					"] }",
					""
				)
			)
		).toBe(
			lines(
				"return {",
				"\tempty = {",
				"\t},",
				"\tnested = {",
				"\t\tb = {",
				"\t\t\tc = 1,",
				"\t\t},",
				"\t\td = {",
				"\t\t\te = 2,",
				"\t\t\tf = 3,",
				"\t\t},",
				"\t},",
				"\tpoint = {",
				"\t\tx = 1,",
				"\t\ty = 2,",
				"\t},",
				"\tspaced = {",
				"\t},",
				"\twitharray = {",
				"\t\tlist = {1, 2},",
				"\t},",
				"}"
			)
		)
		expect(generate("a = {b.c = 1, b.d = 2}\n")).toBe(
			lines("return {", "\ta = {", "\t\tb = {", "\t\t\tc = 1,", "\t\t\td = 2,", "\t\t},", "\t},", "}")
		)
		expect(generate("a = { b = { c = { d = { e = [ { f = 1 } ] } } } }\n")).toBe(
			lines(
				"return {",
				"\ta = {",
				"\t\tb = {",
				"\t\t\tc = {",
				"\t\t\t\td = {",
				"\t\t\t\t\te = {{",
				"\t\t\t\t\t\tf = 1,",
				"\t\t\t\t\t}},",
				"\t\t\t\t},",
				"\t\t\t},",
				"\t\t},",
				"\t},",
				"}"
			)
		)
	end)

	it("refuses an inline table that breaks a line, holds a comment or ends in a comma", function()
		expect(decodeToml(lines("a = {", "b = 1 }", "")).ok).toBe(false)
		expect(decodeToml(lines("a = { b = 1", "}", "")).ok).toBe(false)
		expect(decodeToml("a = { b = 1, }\n").ok).toBe(false)
		expect(decodeToml(lines("a = { b = 1 # c", "}", "")).ok).toBe(false)
		expect(decodeToml(lines("a = { b =", "1 }", "")).ok).toBe(false)
		expect(decodeToml("a = { , }\n").ok).toBe(false)
	end)

	it("reads arrays of tables and the tables under them", function()
		expect(
			generate(
				lines(
					"[[products]]",
					'name = "Hammer"',
					"sku = 738594937",
					"",
					"[[products]]",
					"",
					"[[products]]",
					'name = "Nail"',
					'color = "gray"',
					"",
					"[[fruit]]",
					'name = "apple"',
					"[fruit.physical]",
					'color = "red"',
					"[[fruit.variety]]",
					'name = "red delicious"',
					"[[fruit.variety]]",
					'name = "granny smith"',
					"[[fruit]]",
					'name = "banana"',
					"[[fruit.variety]]",
					'name = "plantain"',
					""
				)
			)
		).toBe(
			lines(
				"return {",
				"\tfruit = {{",
				'\t\tname = "apple",',
				"\t\tphysical = {",
				'\t\t\tcolor = "red",',
				"\t\t},",
				"\t\tvariety = {{",
				'\t\t\tname = "red delicious",',
				"\t\t}, {",
				'\t\t\tname = "granny smith",',
				"\t\t}},",
				"\t}, {",
				'\t\tname = "banana",',
				"\t\tvariety = {{",
				'\t\t\tname = "plantain",',
				"\t\t}},",
				"\t}},",
				"\tproducts = {{",
				'\t\tname = "Hammer",',
				"\t\tsku = 738594937,",
				"\t}, {",
				"\t}, {",
				'\t\tcolor = "gray",',
				'\t\tname = "Nail",',
				"\t}},",
				"}"
			)
		)
		expect(generate(lines("[[a]]", "[[a.b]]", "c = 1", "[a.b.d]", "e = 2", "[[a.b]]", ""))).toBe(
			lines(
				"return {",
				"\ta = {{",
				"\t\tb = {{",
				"\t\t\tc = 1,",
				"\t\t\td = {",
				"\t\t\t\te = 2,",
				"\t\t\t},",
				"\t\t}, {",
				"\t\t}},",
				"\t}},",
				"}"
			)
		)
		expect(generate(lines("[[a]]", "x = 1", "[[a]]", "y = 2", "[a.z]", "w = 3", ""))).toBe(
			lines(
				"return {",
				"\ta = {{",
				"\t\tx = 1,",
				"\t}, {",
				"\t\ty = 2,",
				"\t\tz = {",
				"\t\t\tw = 3,",
				"\t\t},",
				"\t}},",
				"}"
			)
		)
		expect(generate(lines("[a]", "x = 1", "[[a.b]]", "y = 2", ""))).toBe(
			lines("return {", "\ta = {", "\t\tb = {{", "\t\t\ty = 2,", "\t\t}},", "\t\tx = 1,", "\t},", "}")
		)
		expect(generate(lines("[[a]]", "x = 1", "[a.b]", "y = 2", ""))).toBe(
			lines("return {", "\ta = {{", "\t\tb = {", "\t\t\ty = 2,", "\t\t},", "\t\tx = 1,", "\t}},", "}")
		)
	end)

	it("keeps an empty array apart from an empty table", function()
		expect(generate(lines("a = []", "b = {}", "c = [[], [[]], {}]", "[d]", ""))).toBe(
			lines("return {", "\ta = {},", "\tb = {", "\t},", "\tc = {{}, {{}}, {", "\t}},", "\td = {", "\t},", "}")
		)
		expect(generate("")).toBe("return {\n}")
		expect(generate(lines("# just a comment", "", "   ", ""))).toBe("return {\n}")
		expect(generate(lines(" \t", "\t a = 1 \t", " \t", ""))).toBe(lines("return {", "\ta = 1,", "}"))
	end)

	it("keeps arrays of mixed types", function()
		expect(generate('a = [1, "two", 3.0, true, [4], {five = 5}, 1979-05-27, []]\n')).toBe(
			lines("return {", '\ta = {1, "two", 3, true, {4}, {', "\t\tfive = 5,", '\t}, "1979-05-27", {}},', "}")
		)
		expect(generate(lines("points = [ { x = 1 }, { x = 2, y = { z = 3 } } ]", "nest = [[{b = 1}], []]", ""))).toBe(
			lines(
				"return {",
				"\tnest = {{{",
				"\t\tb = 1,",
				"\t}}, {}},",
				"\tpoints = {{",
				"\t\tx = 1,",
				"\t}, {",
				"\t\tx = 2,",
				"\t\ty = {",
				"\t\t\tz = 3,",
				"\t\t},",
				"\t}},",
				"}"
			)
		)
		expect(generate(lines("a = [ 1, 2, ]", "b = [", "  1, # one", "  2", "]", 'c = [ [ 1, 2 ], ["a", "b"] ]', ""))).toBe(
			lines("return {", "\ta = {1, 2},", "\tb = {1, 2},", '\tc = {{1, 2}, {"a", "b"}},', "}")
		)
		expect(generate(lines("a = [true, false]", "b = [\"a\", 'b', \"\"\"c\"\"\", '''d''']", ""))).toBe(
			lines("return {", "\ta = {true, false},", '\tb = {"a", "b", "c", "d"},', "}")
		)
	end)

	it("reads escapes and multi-line strings, folding CRLF to LF", function()
		expect(generate(lines('a = "b\\bf\\fn\\nr\\rt\\tq\\"s\\\\u\\u00E9U\\U0001F600"', 'b = "\\u0000"', ""))).toBe(
			lines("return {", '\ta = "b\8f\12n\\nr\\rt\\tq\\"s\\\\u\u{E9}U\u{1F600}",', '\tb = "\0",', "}")
		)
		expect(
			generate(
				lines(
					'a = """',
					"line1",
					'line2"""',
					'b = """one \\',
					"    two \\",
					"",
					'  three"""',
					"c = '''",
					"raw \\n text'''",
					'd = """quote "" inside"""',
					'e = """five"""""',
					"f = '''four''''",
					""
				)
			)
		).toBe(
			lines(
				"return {",
				'\ta = "line1\\nline2",',
				'\tb = "one two three",',
				'\tc = "raw \\\\n text",',
				'\td = "quote \\"\\" inside",',
				'\te = "five\\"\\"",',
				'\tf = "four\'",',
				"}"
			)
		)
		expect(generate(lines("a = 1\r", 'b = """x\r', 'y"""\r', "# c\r", ""))).toBe(
			lines("return {", "\ta = 1,", '\tb = "x\\ny",', "}")
		)
		expect(generate(lines('a = """one \\\r', '   two"""\r', ""))).toBe(lines("return {", '\ta = "one two",', "}"))
		expect(generate(lines('a = """\\', '   """', 'b = """"""', "c = ''''''", ""))).toBe(
			lines("return {", '\ta = "",', '\tb = "",', '\tc = "",', "}")
		)
		expect(generate(lines('a = "h\u{E9}llo \u{1F600}"', "b = '\u{E9}'", ""))).toBe(
			lines("return {", '\ta = "h\u{E9}llo \u{1F600}",', '\tb = "\u{E9}",', "}")
		)
		expect(generate(lines('a = "x\ty"', "b = 'x\ty'", ""))).toBe(
			lines("return {", '\ta = "x\\ty",', '\tb = "x\\ty",', "}")
		)
		expect(generate("a = 'C:\\path\\n'\n")).toBe(lines("return {", '\ta = "C:\\\\path\\\\n",', "}"))
	end)

	it("refuses the escapes and characters Rojo refuses", function()
		expect(decodeToml('a = "\\e"\n').ok).toBe(false)
		expect(decodeToml('a = "\\x41"\n').ok).toBe(false)
		expect(decodeToml('a = "\\u00"\n').ok).toBe(false)
		expect(decodeToml('a = "\\uD800"\n').ok).toBe(false)
		expect(decodeToml('a = "\\U00110000"\n').ok).toBe(false)
		expect(decodeToml('a = "\\q"\n').ok).toBe(false)
		expect(decodeToml('a = "\\ "\n').ok).toBe(false)
		expect(decodeToml('a = "\\\n').ok).toBe(false)
		expect(decodeToml('a = "\1"\n').ok).toBe(false)
		expect(decodeToml('a = "\127"\n').ok).toBe(false)
		expect(decodeToml("a = 1\rb = 2\n").ok).toBe(false)
		expect(decodeToml(lines("#\0", "a = 1", "")).ok).toBe(false)
	end)

	it("skips a leading byte order mark and allows DEL in a comment", function()
		expect(generate("\u{FEFF}a = 1\n")).toBe(lines("return {", "\ta = 1,", "}"))
		expect(generate(lines("# del \127 here", "a = 1", ""))).toBe(lines("return {", "\ta = 1,", "}"))
		expect(generate(lines("# tab\there \u{E9}", "a = 1 # trailing \u{E9}", ""))).toBe(
			lines("return {", "\ta = 1,", "}")
		)
	end)

	it("refuses a header into a table dotted keys made, and dotted keys into a table a header made", function()
		expect(generate(lines("[a]", "b.c = 1", "[a.x]", "y = 2", ""))).toBe(
			lines(
				"return {",
				"\ta = {",
				"\t\tb = {",
				"\t\t\tc = 1,",
				"\t\t},",
				"\t\tx = {",
				"\t\t\ty = 2,",
				"\t\t},",
				"\t},",
				"}"
			)
		)
		expect(generate(lines("[a.b.d]", "[a.b]", "x = 1", ""))).toBe(
			lines("return {", "\ta = {", "\t\tb = {", "\t\t\td = {", "\t\t\t},", "\t\t\tx = 1,", "\t\t},", "\t},", "}")
		)
		expect(generate(lines("[a.b]", "[a]", "x = 1", ""))).toBe(
			lines("return {", "\ta = {", "\t\tb = {", "\t\t},", "\t\tx = 1,", "\t},", "}")
		)
		expect(generate(lines("a.b = 1", "a.c = 2", "[x]", "y.z = 1", "y.w = 2", ""))).toBe(
			lines(
				"return {",
				"\ta = {",
				"\t\tb = 1,",
				"\t\tc = 2,",
				"\t},",
				"\tx = {",
				"\t\ty = {",
				"\t\t\tw = 2,",
				"\t\t\tz = 1,",
				"\t\t},",
				"\t},",
				"}"
			)
		)
		expect(generate(lines("[[a]]", "b.c = 1", "[[a]]", "[a.b.d]", ""))).toBe(
			lines(
				"return {",
				"\ta = {{",
				"\t\tb = {",
				"\t\t\tc = 1,",
				"\t\t},",
				"\t}, {",
				"\t\tb = {",
				"\t\t\td = {",
				"\t\t\t},",
				"\t\t},",
				"\t}},",
				"}"
			)
		)
		expect(generate(lines("[a.b]", "[a.b.c]", "[a]", ""))).toBe(
			lines("return {", "\ta = {", "\t\tb = {", "\t\t\tc = {", "\t\t\t},", "\t\t},", "\t},", "}")
		)
		expect(generate(lines("[a]", "b = 1", "[a.c]", "d = 2", ""))).toBe(
			lines("return {", "\ta = {", "\t\tb = 1,", "\t\tc = {", "\t\t\td = 2,", "\t\t},", "\t},", "}")
		)

		expect(decodeToml(lines("[a]", "b.c = 1", "[a.b.d]", "")).ok).toBe(false)
		expect(decodeToml(lines("a.b = 1", "[a.c]", "")).ok).toBe(false)
		expect(decodeToml(lines("a.b = 1", "[[a.c]]", "")).ok).toBe(false)
		expect(decodeToml(lines("[x]", "a.b = 1", "[y]", "[x.a]", "")).ok).toBe(false)
		expect(decodeToml(lines("[[a]]", "b.c = 1", "[a.b.d]", "")).ok).toBe(false)
		expect(decodeToml(lines("[a.b.d]", "[a]", "b.c = 1", "")).ok).toBe(false)
		expect(decodeToml(lines("[a.b.c]", "z = 9", "[a]", "b.d = 1", "")).ok).toBe(false)
	end)

	it("refuses a key or a table defined twice", function()
		expect(decodeToml(lines("a = 1", "a = 2", "")).ok).toBe(false)
		expect(decodeToml(lines("[a]", "x = 1", "[a]", "y = 2", "")).ok).toBe(false)
		expect(decodeToml(lines("[a.b]", "[[a]]", "")).ok).toBe(false)
		expect(decodeToml(lines("a = []", "[[a]]", "")).ok).toBe(false)
		expect(decodeToml(lines("a = {b = 1}", "[a.c]", "")).ok).toBe(false)
		expect(decodeToml(lines("a = {b = 1}", "a.c = 2", "")).ok).toBe(false)
		expect(decodeToml(lines("[a]", "[b]", "[a]", "")).ok).toBe(false)
		expect(decodeToml(lines('1 = "one"', '1.2 = "dotted"', "")).ok).toBe(false)
		expect(decodeToml("a = {b.c = 1, b.c = 2}\n").ok).toBe(false)
	end)

	it("refuses a malformed value or line", function()
		expect(decodeToml("a = 1.\n").ok).toBe(false)
		expect(decodeToml("a = .5\n").ok).toBe(false)
		expect(decodeToml("a = 1.e5\n").ok).toBe(false)
		expect(decodeToml("a = 01.5\n").ok).toBe(false)
		expect(decodeToml("a = 1e\n").ok).toBe(false)
		expect(decodeToml("a = 1e+\n").ok).toBe(false)
		expect(decodeToml("a = 1_.5\n").ok).toBe(false)
		expect(decodeToml("a = -01\n").ok).toBe(false)
		expect(decodeToml("a = 0_1\n").ok).toBe(false)
		expect(decodeToml("a = 1__0\n").ok).toBe(false)
		expect(decodeToml("a = _1\n").ok).toBe(false)
		expect(decodeToml("a = 1_\n").ok).toBe(false)
		expect(decodeToml("a = 0x\n").ok).toBe(false)
		expect(decodeToml("a = 0X10\n").ok).toBe(false)
		expect(decodeToml("a = -0x10\n").ok).toBe(false)
		expect(decodeToml("a = 0b12\n").ok).toBe(false)
		expect(decodeToml("a = + 1\n").ok).toBe(false)
		expect(decodeToml("a = --1\n").ok).toBe(false)
		expect(decodeToml("a = 1e1.5\n").ok).toBe(false)
		expect(decodeToml("a = 0x_1\n").ok).toBe(false)
		expect(decodeToml("a = 1.5_\n").ok).toBe(false)
		expect(decodeToml("a = true_\n").ok).toBe(false)
		expect(decodeToml("a = TRUE\n").ok).toBe(false)
		expect(decodeToml("a = infinity\n").ok).toBe(false)
		expect(decodeToml("a = nan_\n").ok).toBe(false)
		expect(decodeToml("a = inff\n").ok).toBe(false)
		expect(decodeToml("a = True\n").ok).toBe(false)
		expect(decodeToml("a = yes\n").ok).toBe(false)
		expect(decodeToml("a = null\n").ok).toBe(false)
		expect(decodeToml("a = \n").ok).toBe(false)
		expect(decodeToml("= 1\n").ok).toBe(false)
		expect(decodeToml('a = "x\n').ok).toBe(false)
		expect(decodeToml("a =").ok).toBe(false)
		expect(decodeToml("[a] b = 1\n").ok).toBe(false)
	end)

	it("refuses text that is not valid UTF-8", function()
		expect(decodeToml('a = "\xFF"\n').ok).toBe(false)
		expect(decodeToml('a = "\xED\xA0\x80"\n').ok).toBe(false)
		expect(decodeToml(lines("# \xC0\x80", "a = 1", "")).ok).toBe(false)
	end)

	it("says what is wrong with malformed text and leaves the path to the caller", function()
		expect(decodeToml("a = 1\na = 2\n")).toEqual({
			ok = false,
			error = { path = "", message = "File contains malformed TOML: duplicate key 'a' around 12" },
		})
		expect(decodeToml("a = \n").error.message).toBe(
			"File contains malformed TOML: expected value on same line after '=' around 5"
		)
	end)
end)
