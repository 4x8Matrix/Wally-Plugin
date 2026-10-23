local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local fileNameOfPath = require(ReplicatedStorage.WallyPlugin.PluginUtilities.fileNameOfPath)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("fileNameOfPath", function()
	it("names the last component, past trailing separators and `.` components, as Rust's file_name does", function()
		expect(fileNameOfPath("src/a.lua")).toBe("a.lua")
		expect(fileNameOfPath("src/")).toBe("src")
		expect(fileNameOfPath("src/.")).toBe("src")
		expect(fileNameOfPath("./src//")).toBe("src")
		expect(fileNameOfPath("src/../lib")).toBe("lib")
	end)

	it('names the zip root `""`, as the package folder Rojo sees above it has a name a zip does not hold', function()
		expect(fileNameOfPath("")).toBe("")
		expect(fileNameOfPath(".")).toBe("")
		expect(fileNameOfPath("./")).toBe("")
	end)

	it("names nothing for a path ending in `..`, as Rust's file_name does", function()
		expect(fileNameOfPath("src/..")).toBe(nil)
		expect(fileNameOfPath("..")).toBe(nil)
		expect(fileNameOfPath("src/../.")).toBe(nil)
		expect(fileNameOfPath("src/../")).toBe(nil)
	end)
end)
