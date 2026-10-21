local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local toPascalCase = require(ReplicatedStorage.WallyPlugin.PluginUtilities.toPascalCase)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("toPascalCase", function()
	it("names root links as the plugin always has", function()
		expect(toPascalCase("roact-rodux")).toBe("RoactRodux")
		expect(toPascalCase("trove")).toBe("Trove")
		expect(toPascalCase("luau-polyfill")).toBe("LuauPolyfill")
		expect(toPascalCase("")).toBe("")
	end)
end)
