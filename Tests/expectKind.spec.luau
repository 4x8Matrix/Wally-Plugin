local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local expectKind = require(ReplicatedStorage.WallyPlugin.PluginUtilities.expectKind)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("expectKind", function()
	it("passes a value of the kind asked for, false and empty values included", function()
		local map = { kind = "map", entries = {} }

		expect(expectKind("a", "string", "a string")).toEqual({ ok = true, value = "a" })
		expect(expectKind(false, "boolean", "a boolean")).toEqual({ ok = true, value = false })
		expect(expectKind(map, "map", "a map")).toEqual({ ok = true, value = map })
	end)

	it("refuses any other kind in serde's words, naming what it is and what was expected", function()
		expect(expectKind(1, "string", "a string")).toEqual({
			ok = false,
			error = { path = "", message = "invalid type: integer `1`, expected a string" },
		})
		expect(expectKind({ kind = "null" }, "map", "struct ProjectNode")).toEqual({
			ok = false,
			error = { path = "", message = "invalid type: null, expected struct ProjectNode" },
		})
		expect(expectKind({ kind = "array", items = {} }, "map", "a map")).toEqual({
			ok = false,
			error = { path = "", message = "invalid type: sequence, expected a map" },
		})
	end)
end)
