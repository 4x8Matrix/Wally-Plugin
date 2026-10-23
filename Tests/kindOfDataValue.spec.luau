local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local kindOfDataValue = require(ReplicatedStorage.WallyPlugin.PluginUtilities.kindOfDataValue)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("kindOfDataValue", function()
	it("names every kind of decoded value, and a missing one", function()
		expect(kindOfDataValue(true)).toBe("boolean")
		expect(kindOfDataValue(false)).toBe("boolean")
		expect(kindOfDataValue(0)).toBe("number")
		expect(kindOfDataValue("")).toBe("string")
		expect(kindOfDataValue({ kind = "null" })).toBe("null")
		expect(kindOfDataValue({ kind = "array", items = {} })).toBe("array")
		expect(kindOfDataValue({ kind = "map", entries = {} })).toBe("map")
		expect(kindOfDataValue(nil)).toBe("nil")
	end)
end)
