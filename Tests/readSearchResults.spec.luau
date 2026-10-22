local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local readSearchResults = require(ReplicatedStorage.WallyPlugin.PluginUtilities.readSearchResults)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("readSearchResults", function()
	it("reads each package with the version the registry website offers", function()
		local results = readSearchResults({
			{ description = "Signal", name = "signal", scope = "ptekspy", versions = { "1.1.1" } },
			{
				description = "Fast signals",
				name = "signal",
				scope = "red-blox",
				versions = { "2.0.2", "2.1.0-rc.1", "1.0.0" },
			},
		})

		expect(results).toEqual({
			{ scope = "ptekspy", name = "signal", description = "Signal", version = "1.1.1" },
			{ scope = "red-blox", name = "signal", description = "Fast signals", version = "2.0.2" },
		})
	end)

	it("puts a description written over several lines on one line", function()
		local results = readSearchResults({
			{
				description = "Zaphy is a easy-to-use game framework.\n\nFull documentation at:\nhttps://froststarinteractive.github.io/zaphy/\n",
				name = "zaphy",
				scope = "ivadsiuls",
				versions = { "2.1.6" },
			},
		})

		expect(results[1].description).toBe(
			"Zaphy is a easy-to-use game framework. Full documentation at: https://froststarinteractive.github.io/zaphy/"
		)
	end)

	it("keeps a package with no description", function()
		local results = readSearchResults({ { name = "trove", scope = "sleitnick", versions = { "1.8.0" } } })

		expect(results[1].description).toBe("")
	end)

	it("drops a package with no version it can offer", function()
		local results = readSearchResults({
			{ description = "", name = "broken", scope = "biff", versions = { "junk" } },
			{ description = "", name = "empty", scope = "biff", versions = {} },
			{ description = "", name = "nothing", scope = "biff" },
		})

		expect(results).toEqual({})
	end)
end)
