local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local roundColorToBytes = require(ReplicatedStorage.WallyPlugin.PluginUtilities.roundColorToBytes)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("roundColorToBytes", function()
	it("rounds halves up, as Studio holds Rojo's BasePart.Color", function()
		expect(roundColorToBytes(Color3.new(1, 0.5, 0))).toEqual(Color3.fromRGB(255, 128, 0))
	end)

	it("clamps each channel to 0 and 1 first", function()
		expect(roundColorToBytes(Color3.fromRGB(510, -255, 0.51))).toEqual(Color3.fromRGB(255, 0, 1))
	end)
end)
