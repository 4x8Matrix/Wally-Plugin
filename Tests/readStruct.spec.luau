local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local decodeJsonc = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeJsonc)
local readStruct = require(ReplicatedStorage.WallyPlugin.PluginUtilities.readStruct)

local SHAPE = {
	name = "Rule",
	fields = {
		{ name = "pattern", presence = "required" },
		{ name = "exclude", presence = "optional" },
		{ name = "globs", presence = "defaulted" },
	},
	denyUnknownFields = false,
}
local STRICT = { name = "Strict", fields = SHAPE.fields, denyUnknownFields = true }

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function read(text: string, shape: any): any
	return readStruct(decodeJsonc(text).value, shape or SHAPE)
end

describe("readStruct", function()
	it("pairs an object's known keys with their fields, null values kept for the field to read", function()
		expect(read('{"pattern": "a", "exclude": null, "other": 1}')).toEqual({
			ok = true,
			value = { pattern = "a", exclude = { kind = "null" } },
		})
	end)

	it("leaves out an absent optional or defaulted field and refuses an absent required one", function()
		expect(read('{"pattern": "a"}')).toEqual({ ok = true, value = { pattern = "a" } })
		expect(read('{"exclude": "b"}')).toEqual({
			ok = false,
			error = { path = "", message = "missing field `pattern`" },
		})
	end)

	it("refuses an unknown key when the struct denies them, naming the fields it expects", function()
		expect(read('{"pattern": "a", "other": 1}', STRICT)).toEqual({
			ok = false,
			error = { path = "", message = "unknown field `other`, expected one of `pattern`, `exclude`, `globs`" },
		})
	end)

	it("reads an array positionally, stopping early only before defaulted fields, as serde reads a sequence", function()
		expect(read('["a", null, ["x"]]')).toEqual({
			ok = true,
			value = { pattern = "a", exclude = { kind = "null" }, globs = { kind = "array", items = { "x" } } },
		})
		expect(read('["a", "b"]')).toEqual({ ok = true, value = { pattern = "a", exclude = "b" } })
		expect(read('["a"]')).toEqual({
			ok = false,
			error = { path = "", message = "invalid length 1, expected struct Rule with 3 elements" },
		})
		expect(read("[]")).toEqual({
			ok = false,
			error = { path = "", message = "invalid length 0, expected struct Rule with 3 elements" },
		})
		expect(read('["a", null, [], 1]')).toEqual({
			ok = false,
			error = { path = "", message = "invalid length 4, expected fewer elements in array" },
		})
	end)

	it("refuses anything but an object or an array in serde's words", function()
		expect(read('"a"')).toEqual({
			ok = false,
			error = { path = "", message = 'invalid type: string "a", expected struct Rule' },
		})
		expect(read("null")).toEqual({
			ok = false,
			error = { path = "", message = "invalid type: null, expected struct Rule" },
		})
	end)
end)
