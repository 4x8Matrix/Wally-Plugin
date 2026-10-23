local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local buildError = require(ReplicatedStorage.WallyPlugin.PluginUtilities.buildError)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("buildError", function()
	it("fails naming the file and the message", function()
		expect(buildError("src/a.meta.json", "missing field `className`")).toEqual({
			ok = false,
			error = { path = "src/a.meta.json", message = "missing field `className`" },
		})
	end)

	it("leaves the path empty for the caller to add the file", function()
		expect(buildError("", "File was not valid UTF-8")).toEqual({
			ok = false,
			error = { path = "", message = "File was not valid UTF-8" },
		})
	end)
end)
