local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local listEnumItems = require(ReplicatedStorage.WallyPlugin.PluginUtilities.listEnumItems)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("listEnumItems", function()
	it("lists nine sorted items and counts the rest, as Rojo 7.7.1 lists Material", function()
		expect(listEnumItems(Enum.Material)).toBe(
			"Air, Asphalt, Basalt, Brick, Cardboard, Carpet, CeramicTiles, ClayRoofTiles, Cobblestone, or 36 more"
		)
	end)

	it("lists every item of a short enum, the last after `or`, as Rojo 7.7.1 lists PartType", function()
		expect(listEnumItems(Enum.PartType)).toBe("Ball, Block, CornerWedge, Cylinder, or Wedge")
	end)
end)
