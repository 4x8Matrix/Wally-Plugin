local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local findInstalled = require(ReplicatedStorage.WallyPlugin.PluginUtilities.findInstalled)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local installed = {
	{ alias = "Trove", realm = "shared", scope = "sleitnick", name = "trove", version = "1.8.0" },
	{ alias = "Trove", realm = "server", scope = "sleitnick", name = "trove", version = "1.6.0" },
}

describe("findInstalled", function()
	it("finds the installed package by its alias and realm", function()
		expect(findInstalled(installed, { kind = "installed", alias = "Trove", realm = "server" })).toBe(installed[2])
	end)

	it("finds nothing for a registry result, no selection or a package that is gone", function()
		expect(findInstalled(installed, { kind = "result", scope = "sleitnick", name = "trove" })).toBe(nil)
		expect(findInstalled(installed, nil)).toBe(nil)
		expect(findInstalled(installed, { kind = "installed", alias = "Signal", realm = "shared" })).toBe(nil)
	end)
end)
