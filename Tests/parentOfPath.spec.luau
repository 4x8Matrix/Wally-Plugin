local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local parentOfPath = require(ReplicatedStorage.WallyPlugin.PluginUtilities.parentOfPath)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("parentOfPath", function()
	it('drops the last component, as Rust\'s parent does, `""` being the root', function()
		expect(parentOfPath("sub/x.project.json")).toBe("sub")
		expect(parentOfPath("a/b/default.project.json")).toBe("a/b")
		expect(parentOfPath("default.project.json")).toBe("")
	end)

	it("trims the empty and `.` components left at the end", function()
		expect(parentOfPath("sub/./x.project.json")).toBe("sub")
		expect(parentOfPath("./x.project.json")).toBe("")
		expect(parentOfPath("sub//x.project.json")).toBe("sub")
		expect(parentOfPath("sub/../x.project.json")).toBe("sub/..")
	end)
end)
