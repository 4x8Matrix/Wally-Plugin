local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local castToInteger = require(ReplicatedStorage.WallyPlugin.PluginUtilities.castToInteger)

local INT32_MINIMUM = -2 ^ 31
local INT32_MAXIMUM = 2 ^ 31 - 1

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("castToInteger", function()
	it("truncates toward zero, as Studio holds Rojo's implicit integers", function()
		expect(castToInteger(1.9, INT32_MINIMUM, INT32_MAXIMUM)).toBe(1)
		expect(castToInteger(-1.9, INT32_MINIMUM, INT32_MAXIMUM)).toBe(-1)
		expect(castToInteger(-2.5, -2 ^ 63, 2 ^ 63 - 1)).toBe(-2)
		expect(castToInteger(123456789012, -2 ^ 63, 2 ^ 63 - 1)).toBe(123456789012)
	end)

	it("saturates at the bounds", function()
		expect(castToInteger(3000000000, INT32_MINIMUM, INT32_MAXIMUM)).toBe(2147483647)
		expect(castToInteger(-3000000000, INT32_MINIMUM, INT32_MAXIMUM)).toBe(-2147483648)
	end)
end)
