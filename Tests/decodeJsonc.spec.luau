local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local decodeJsonc = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeJsonc)

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

describe("decodeJsonc", function()
	it("decodes an object, its nesting and its scalars", function()
		local decoded = decodeJsonc('{"name": "pkg", "count": 3, "nested": {"ok": true, "list": [1, "two", false]}}')

		expect(decoded.ok).toBe(true)
		expect(decoded.value).toEqual(map({
			entry("count", 3),
			entry("name", "pkg"),
			entry("nested", map({ entry("list", array({ 1, "two", false })), entry("ok", true) })),
		}))
	end)

	it("decodes a scalar, an array and a null at the top level", function()
		expect(decodeJsonc('"text"').value).toBe("text")
		expect(decodeJsonc("12.5").value).toBe(12.5)
		expect(decodeJsonc("null").value).toEqual(NULL)
		expect(decodeJsonc("[]").value).toEqual(array({}))
		expect(decodeJsonc("{}").value).toEqual(map({}))
	end)

	it("keeps a null inside an array", function()
		expect(decodeJsonc("[null, 1, null]").value).toEqual(array({ NULL, 1, NULL }))
	end)

	it("returns map entries in key-byte order with the last duplicate winning", function()
		expect(decodeJsonc('{"b": 1, "a": 2, "B": 3, "_": 4}').value).toEqual(map({
			entry("B", 3),
			entry("_", 4),
			entry("a", 2),
			entry("b", 1),
		}))
		expect(decodeJsonc('{"a": 1, "b": 2, "a": 3}').value).toEqual(map({ entry("a", 3), entry("b", 2) }))
	end)

	it("accepts comments, trailing commas and missing commas", function()
		local commented = decodeJsonc('// leading\n{\n\t/* block\n\t   over lines */ "a": 1, // after\n\t"b": 2\n}')

		expect(commented.value).toEqual(map({ entry("a", 1), entry("b", 2) }))
		expect(decodeJsonc('{"a": [1, 2, ], "b": [1 2 3], "c": 3,}').value).toEqual(map({
			entry("a", array({ 1, 2 })),
			entry("b", array({ 1, 2, 3 })),
			entry("c", 3),
		}))
	end)

	it("accepts unquoted keys as written and single-quoted strings", function()
		local words = decodeJsonc("{abc-def_1: 1, _x: 2, 1: 3, -3: 4, 0x10: 5, 1.5: 6}")

		expect(words.value).toEqual(map({
			entry("-3", 4),
			entry("0x10", 5),
			entry("1", 3),
			entry("1.5", 6),
			entry("_x", 2),
			entry("abc-def_1", 1),
		}))
		expect(decodeJsonc("{'a': 'it\\'s'}").value).toEqual(map({ entry("a", "it's") }))
	end)

	it("accepts hexadecimal numbers and a leading plus", function()
		expect(decodeJsonc("[0x1F, -0x1F, +1, 0X10, +0x2]").value).toEqual(array({ 31, -31, 1, 16, 2 }))
	end)

	it("keeps the text of a number no JSON number can hold", function()
		expect(decodeJsonc("[1e400, -1e400, 0x8000000000000000, 0x7FFFFFFFFFFFFFFF]").value).toEqual(array({
			"1e400",
			"-1e400",
			"0x8000000000000000",
			9223372036854776000,
		}))
	end)

	it("accepts a unicode letter or digit in an unquoted key", function()
		expect(decodeJsonc("{\u{E9}t\u{E9}: 1, \u{65E5}\u{672C}: 2, x\u{661}: 3, \u{BD}: 4}").value).toEqual(map({
			entry("x\u{661}", 3),
			entry("\u{BD}", 4),
			entry("\u{E9}t\u{E9}", 1),
			entry("\u{65E5}\u{672C}", 2),
		}))
	end)

	it("accepts unicode whitespace between tokens", function()
		expect(decodeJsonc('{\u{A0}"a"\u{3000}:\u{2028}1\u{2029}}').value).toEqual(map({ entry("a", 1) }))
	end)

	it("accepts a character of any kind inside a string or a comment", function()
		local decoded = decodeJsonc('{"\u{2192}": "\u{2192} \u{A0}", // \u{2192} comment\n/* \u{2192} */ k: 1}')

		expect(decoded.value).toEqual(map({ entry("k", 1), entry("\u{2192}", "\u{2192} \u{A0}") }))
	end)

	it("refuses a character Rojo does not allow in an unquoted key", function()
		expect(decodeJsonc("{a\u{2192}b: 1}")).toEqual({
			ok = false,
			error = { path = "", message = "Unexpected token around 3" },
		})
		expect(decodeJsonc("{\u{2192}: 1}").ok).toBe(false)
		expect(decodeJsonc("{true\u{2192}: 1}").ok).toBe(false)
		expect(decodeJsonc("[\u{2192}]").ok).toBe(false)
		expect(decodeJsonc("\u{FEFF}{}").ok).toBe(false)
	end)

	it("refuses text with no value and text with several", function()
		expect(decodeJsonc("")).toEqual({
			ok = false,
			error = { path = "", message = "File contains no JSON value" },
		})
		expect(decodeJsonc(" \n\t ").error.message).toBe("File contains no JSON value")
		expect(decodeJsonc("// nothing\n/* here */").error.message).toBe("File contains no JSON value")
		expect(decodeJsonc("{} []").error.message).toBe("Text cannot contain more than one JSON value around 4")
		expect(decodeJsonc("1 2").error.message).toBe("Text cannot contain more than one JSON value around 3")
	end)

	it("refuses text that is not valid UTF-8, whatever else is wrong with it", function()
		local message = "File is not valid UTF-8"

		expect(decodeJsonc('{"a": "\xC0\x80"}').error.message).toBe(message)
		expect(decodeJsonc("[1] \x80").error.message).toBe(message)
		expect(decodeJsonc("// \xED\xA0\x80\n1").error.message).toBe(message)
		expect(decodeJsonc('"\xE2\x82"').error.message).toBe(message)
		expect(decodeJsonc('"\xF4\x90\x80\x80"').error.message).toBe(message)
	end)

	it("refuses a keyword as a key", function()
		expect(decodeJsonc("{true: 1}").ok).toBe(false)
		expect(decodeJsonc("{null: 1}").ok).toBe(false)
	end)

	it("says what is wrong with malformed text", function()
		expect(decodeJsonc('{"a" 1}').error.message).toBe(
			"Expected colon after the string or word in object property around 6"
		)
		expect(decodeJsonc('{"a": }').error.message).toBe("Unexpected close brace around 7")
		expect(decodeJsonc("[1,,2]").error.message).toBe("Unexpected comma around 4")
		expect(decodeJsonc("[,1]").error.message).toBe("Unexpected comma around 2")
		expect(decodeJsonc('{"a": "b}').error.message).toBe("Unterminated string literal around 7")
		expect(decodeJsonc('{"a": 1').error.message).toBe("Unterminated object around 8")
		expect(decodeJsonc("[1, 2").error.message).toBe("Unterminated array around 6")
		expect(decodeJsonc("[1] /* open").error.message).toBe("Unterminated comment block around 5")
		expect(decodeJsonc("[abc]").error.message).toBe("Unexpected token around 2")
		expect(decodeJsonc("['\\\"']").error.message).toBe("Invalid escape in single quote string around 3")
		expect(decodeJsonc('["\\\'"]').error.message).toBe("Invalid escape in double quote string around 3")
	end)

	it("reads a unicode escape and refuses an unpaired surrogate", function()
		expect(decodeJsonc('["\\ud83d\\ude00"]').value).toEqual(array({ "\u{1F600}" }))
		expect(decodeJsonc('["\\ud800"]').error.message).toBe(
			"Invalid unicode escape sequence (unpaired high surrogate) around 3"
		)
	end)
end)
