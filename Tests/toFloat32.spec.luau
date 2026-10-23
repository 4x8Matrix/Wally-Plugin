local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local toFloat32 = require(ReplicatedStorage.WallyPlugin.PluginUtilities.toFloat32)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("toFloat32", function()
	it("rounds to the single-precision value Studio holds for Rojo's Float32", function()
		expect(toFloat32(0.1)).toBe(0.10000000149011612)
		expect(toFloat32(1)).toBe(1)
		expect(toFloat32(-2.5)).toBe(-2.5)
	end)
end)
