local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local isNewerVersion = require(ReplicatedStorage.WallyPlugin.PluginUtilities.isNewerVersion)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("isNewerVersion", function()
	it("compares by semver precedence", function()
		expect(isNewerVersion("2.0.3", "1.5.0")).toBe(true)
		expect(isNewerVersion("1.10.0", "1.9.0")).toBe(true)
		expect(isNewerVersion("1.0.0", "1.0.0-rc.1")).toBe(true)
		expect(isNewerVersion("1.4.2", "1.5.0")).toBe(false)
		expect(isNewerVersion("1.5.0", "1.5.0")).toBe(false)
	end)

	it("calls nothing newer when either version cannot be read", function()
		expect(isNewerVersion("junk", "1.0.0")).toBe(false)
		expect(isNewerVersion("1.0.0", "junk")).toBe(false)
	end)
end)
