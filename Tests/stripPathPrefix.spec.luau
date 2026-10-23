local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local stripPathPrefix = require(ReplicatedStorage.WallyPlugin.PluginUtilities.stripPathPrefix)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("stripPathPrefix", function()
	it("returns the rest of a path below its prefix, and nothing for a path outside it", function()
		expect(stripPathPrefix("sub/src/a.lua", "sub")).toBe("src/a.lua")
		expect(stripPathPrefix("sub", "sub")).toBe("")
		expect(stripPathPrefix("subway/a.lua", "sub")).toBe(nil)
		expect(stripPathPrefix("src/a.lua", "sub")).toBe(nil)
		expect(stripPathPrefix("src/a.lua", "")).toBe("src/a.lua")
	end)

	it("compares by component, as Rust's strip_prefix skips empty and `.` components", function()
		expect(stripPathPrefix("sub/./src/a.lua", "sub/src")).toBe("a.lua")
		expect(stripPathPrefix("sub//a.lua", "sub")).toBe("a.lua")
		expect(stripPathPrefix("sub/a.lua", "sub/.")).toBe("a.lua")
		expect(stripPathPrefix("sub/../src/x.lua", "sub")).toBe("../src/x.lua")
	end)

	it("trims empty and `.` components only from the ends of the rest, as as_path does", function()
		expect(stripPathPrefix("./src/a.lua", "")).toBe("src/a.lua")
		expect(stripPathPrefix(".//src/a.lua", "")).toBe("src/a.lua")
		expect(stripPathPrefix("src/./a.lua", "")).toBe("src/./a.lua")
		expect(stripPathPrefix("src//a.lua", "")).toBe("src//a.lua")
		expect(stripPathPrefix("src/lib/.", "")).toBe("src/lib")
	end)
end)
