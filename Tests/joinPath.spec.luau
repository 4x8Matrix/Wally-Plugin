local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local joinPath = require(ReplicatedStorage.WallyPlugin.PluginUtilities.joinPath)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("joinPath", function()
	it("names an entry of the root by its name alone", function()
		expect(joinPath("", "init.lua")).toBe("init.lua")
	end)

	it("joins an entry onto its directory with a slash", function()
		expect(joinPath("src", "init.lua")).toBe("src/init.lua")
		expect(joinPath("src/Shared", ".github")).toBe("src/Shared/.github")
	end)
end)
