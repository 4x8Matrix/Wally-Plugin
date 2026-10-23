local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local json = require(ReplicatedStorage.WallyPlugin.Vendor.lute.json)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local jsoncOptions = { jsonc = true, ordered = true }

describe("lute json", function()
	it("decodes a strict object as upstream does", function()
		local decoded =
			json.deserialize('{"name": "pkg", "count": 3, "tags": ["a", "b"], "nested": {"ok": true}, "nothing": null}')

		expect(json.asObject(decoded)).never.toBeNil()
		expect(json.asArray(decoded.tags)).never.toBeNil()
		expect(decoded.name).toBe("pkg")
		expect(decoded.count).toBe(3)
		expect(decoded.tags).toEqual({ "a", "b" })
		expect(decoded.nested.ok).toBe(true)
		expect(decoded.nothing).toBe(json.null)
	end)

	it("refuses comments and trailing commas without the jsonc option", function()
		expect(function()
			json.deserialize('{"a": 1 // comment\n}')
		end).toThrow()
		expect(function()
			json.deserialize("[1,]")
		end).toThrow()
	end)

	it("decodes Rojo's JSONC dialect", function()
		local decoded = json.deserialize(
			table.concat({
				"{",
				"\t// line comment",
				'\t"b": 1, /* block */',
				"\tunquoted: 'single',",
				"\thex: 0x1F,",
				"\tplus: +1,",
				"\tlist: [1, 2,],",
				"}",
			}, "\n"),
			jsoncOptions
		)

		expect(decoded).toEqual({
			kind = "map",
			entries = {
				{ key = "b", value = 1 },
				{ key = "hex", value = 31 },
				{ key = "list", value = { kind = "array", items = { 1, 2 } } },
				{ key = "plus", value = 1 },
				{ key = "unquoted", value = "single" },
			},
		})
	end)

	it("follows jsonc-parser where it is looser than JSON5", function()
		expect(json.deserialize('[1 2 "x" true]', jsoncOptions)).toEqual({ kind = "array", items = { 1, 2, "x", true } })
		expect(
			json.deserialize("{1: 2, -3: 4, 0x10: 5, k: [1e400, +1e400, 0x8000000000000000, -0x1F, 01]}", jsoncOptions)
		).toEqual({
			kind = "map",
			entries = {
				{ key = "-3", value = 4 },
				{ key = "0x10", value = 5 },
				{ key = "1", value = 2 },
				{
					key = "k",
					value = { kind = "array", items = { "1e400", "+1e400", "0x8000000000000000", -31, 0, 1 } },
				},
			},
		})
	end)

	it("refuses JSONC with no value or with several", function()
		expect(function()
			json.deserialize("", jsoncOptions)
		end).toThrow("no JSON value")
		expect(function()
			json.deserialize("// only a comment\n", jsoncOptions)
		end).toThrow("no JSON value")
		expect(function()
			json.deserialize("[1][2]", jsoncOptions)
		end).toThrow("more than one JSON value")
	end)

	it("keeps object keys in key-byte order with the last duplicate winning", function()
		local text = '{"b": 1, "a": 2, "b": 3, "B": 4, "_": 5, "\u{E9}": 6}'
		local expected = {
			kind = "map",
			entries = {
				{ key = "B", value = 4 },
				{ key = "_", value = 5 },
				{ key = "a", value = 2 },
				{ key = "b", value = 3 },
				{ key = "\u{E9}", value = 6 },
			},
		}

		expect(json.deserialize(text, { ordered = true })).toEqual(expected)
		expect(json.deserialize(text, jsoncOptions)).toEqual(expected)
	end)

	it("keeps null and the array and map split in the order-keeping mode", function()
		expect(json.deserialize('[null, {}, [], {"x": null}]', { ordered = true })).toEqual({
			kind = "array",
			items = {
				{ kind = "null" },
				{ kind = "map", entries = {} },
				{ kind = "array", items = {} },
				{ kind = "map", entries = { { key = "x", value = { kind = "null" } } } },
			},
		})
	end)
end)
