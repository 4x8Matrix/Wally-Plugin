local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local findEnum = require(ReplicatedStorage.WallyPlugin.PluginUtilities.findEnum)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("findEnum", function()
	it("finds an enum by its exact name", function()
		expect(findEnum("Material")).toBe(Enum.Material)
		expect(findEnum("PartType")).toBe(Enum.PartType)
	end)

	it("finds nothing for an unknown name, a near miss or one of Enum's own methods", function()
		expect(findEnum("NotAnEnum")).toBe(nil)
		expect(findEnum("material")).toBe(nil)
		expect(findEnum("GetEnums")).toBe(nil)
	end)
end)
