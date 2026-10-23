local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local describeUnexpected = require(ReplicatedStorage.WallyPlugin.PluginUtilities.describeUnexpected)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("describeUnexpected", function()
	it("names each kind of value as serde's Unexpected does", function()
		expect(describeUnexpected(true)).toBe("boolean `true`")
		expect(describeUnexpected(5)).toBe("integer `5`")
		expect(describeUnexpected(-2)).toBe("integer `-2`")
		expect(describeUnexpected(1.5)).toBe("floating point `1.5`")
		expect(describeUnexpected("s")).toBe('string "s"')
		expect(describeUnexpected({ kind = "null" })).toBe("null")
		expect(describeUnexpected({ kind = "array", items = {} })).toBe("sequence")
		expect(describeUnexpected({ kind = "map", entries = {} })).toBe("map")
	end)

	it("escapes a string as Rust's Debug does", function()
		expect(describeUnexpected('a"b\\c\nd\re\tf')).toBe('string "a\\"b\\\\c\\nd\\re\\tf"')
	end)
end)
