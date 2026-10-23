local EncodingService = game:GetService("EncodingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local VirtualFileSystem = require(ReplicatedStorage.WallyPlugin.PluginClasses.VirtualFileSystem)

local fixture = require(ReplicatedStorage.Tests.Fixtures.virtualFileSystemZip)

local SOURCE_LISTING = { "B.luau", "_private.luau", "a.luau", "empty", "init.luau" }

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function decode(base64: string): string
	return buffer.tostring(EncodingService:Base64Decode(buffer.fromstring(base64)))
end

local function numberedLines(count: number): string
	local lines = {}

	for index = 1, count do
		table.insert(lines, `line {index}\n`)
	end

	return table.concat(lines)
end

local function openFixture(): VirtualFileSystem.VirtualFileSystem
	local opened = VirtualFileSystem.fromZip(decode(fixture.zip))

	expect(opened.ok).toBe(true)

	return opened.value
end

describe("VirtualFileSystem", function()
	it("lists each directory's entries sorted by bytes, as Rojo orders children", function()
		local fileSystem = openFixture()

		expect(fileSystem:ListDirectory("")).toEqual({ "README.md", "lib", "src", "wally.toml" })
		expect(fileSystem:ListDirectory("src")).toEqual(SOURCE_LISTING)
	end)

	it("keeps a directory entry with nothing under it as an empty directory", function()
		local fileSystem = openFixture()

		expect(fileSystem:IsDirectory("src/empty")).toBe(true)
		expect(fileSystem:ListDirectory("src/empty")).toEqual({})
	end)

	it("implies the directories above a member that have no entries of their own", function()
		local fileSystem = openFixture()

		expect(fileSystem:IsDirectory("lib")).toBe(true)
		expect(fileSystem:IsDirectory("lib/nested")).toBe(true)
		expect(fileSystem:ListDirectory("lib")).toEqual({ "nested" })
		expect(fileSystem:ListDirectory("lib/nested")).toEqual({ "deep.txt" })
	end)

	it("treats an empty path as the root directory", function()
		local fileSystem = openFixture()

		expect(fileSystem:IsDirectory("")).toBe(true)
		expect(fileSystem:IsFile("")).toBe(false)
	end)

	it("tells files from directories and from paths that hold nothing", function()
		local fileSystem = openFixture()

		expect(fileSystem:IsFile("src/init.luau")).toBe(true)
		expect(fileSystem:IsDirectory("src/init.luau")).toBe(false)
		expect(fileSystem:IsFile("src")).toBe(false)
		expect(fileSystem:IsFile("src/missing.luau")).toBe(false)
		expect(fileSystem:IsDirectory("missing")).toBe(false)
		expect(fileSystem:ListDirectory("src/init.luau")).toEqual({})
		expect(fileSystem:ListDirectory("missing")).toEqual({})
	end)

	it("reads deflated and stored members", function()
		local fileSystem = openFixture()

		expect(fileSystem:ReadFile("src/init.luau")).toEqual({ ok = true, value = "return require(script.a)\n" })
		expect(fileSystem:ReadFile("src/_private.luau")).toEqual({ ok = true, value = 'return "_"\n' })
		expect(fileSystem:ReadFile("README.md")).toEqual({ ok = true, value = "# fixture\n" })
		expect(fileSystem:ReadFile("lib/nested/deep.txt")).toEqual({ ok = true, value = numberedLines(40) })
	end)

	it("resolves `..`, `.` and repeated or trailing slashes inside the zip as the filesystem does", function()
		local fileSystem = openFixture()

		expect(fileSystem:IsFile("lib/../src/init.luau")).toBe(true)
		expect(fileSystem:ReadFile("lib/nested/../../src/a.luau")).toEqual({ ok = true, value = 'return "a"\n' })
		expect(fileSystem:IsDirectory("lib/../lib/../src")).toBe(true)
		expect(fileSystem:IsDirectory("./src")).toBe(true)
		expect(fileSystem:IsDirectory("src/")).toBe(true)
		expect(fileSystem:IsDirectory("src/.")).toBe(true)
		expect(fileSystem:IsDirectory("lib//../src")).toBe(true)
		expect(fileSystem:IsFile("src//a.luau")).toBe(true)
		expect(fileSystem:IsFile("src/./a.luau")).toBe(true)
		expect(fileSystem:ListDirectory("lib/nested/..")).toEqual({ "nested" })
	end)

	it("finds nothing at a path that leaves the root", function()
		local fileSystem = openFixture()

		expect(fileSystem:IsDirectory("..")).toBe(false)
		expect(fileSystem:IsFile("../src/init.luau")).toBe(false)
		expect(fileSystem:IsFile("src/../../src/init.luau")).toBe(false)
		expect(fileSystem:IsDirectory("/src")).toBe(false)
		expect(fileSystem:IsFile("/src/init.luau")).toBe(false)
		expect(fileSystem:ListDirectory("..")).toEqual({})
		expect(fileSystem:ReadFile("../src/init.luau")).toEqual({
			ok = false,
			error = { path = "../src/init.luau", message = "no such file" },
		})
	end)

	it("finds nothing through a directory that does not exist or through a file", function()
		local fileSystem = openFixture()

		expect(fileSystem:IsDirectory("missing/../src")).toBe(false)
		expect(fileSystem:IsFile("src/a.luau/")).toBe(false)
		expect(fileSystem:IsDirectory("src/a.luau/../empty")).toBe(false)
	end)

	it("tells a path that runs through a file, which Rojo refuses, from one that is only missing", function()
		local fileSystem = openFixture()

		expect(fileSystem:RunsThroughFile("src/a.luau/")).toBe(true)
		expect(fileSystem:RunsThroughFile("src/a.luau/b")).toBe(true)
		expect(fileSystem:RunsThroughFile("src/a.luau/.")).toBe(true)
		expect(fileSystem:RunsThroughFile("src/a.luau/../empty")).toBe(true)
		expect(fileSystem:RunsThroughFile("src/a.luau")).toBe(false)
		expect(fileSystem:RunsThroughFile("src/empty/../a.luau")).toBe(false)
		expect(fileSystem:RunsThroughFile("missing/a.luau/b")).toBe(false)
		expect(fileSystem:RunsThroughFile("../src/a.luau/b")).toBe(false)
		expect(fileSystem:RunsThroughFile("/src/a.luau/b")).toBe(false)
	end)

	it("fails to read a missing file or a directory, naming the path", function()
		local fileSystem = openFixture()

		expect(fileSystem:ReadFile("src/missing.luau")).toEqual({
			ok = false,
			error = { path = "src/missing.luau", message = "no such file" },
		})
		expect(fileSystem:ReadFile("src")).toEqual({
			ok = false,
			error = { path = "src", message = "is a directory" },
		})
	end)

	it("fails on a corrupt zip instead of throwing", function()
		local truncated = string.sub(decode(fixture.zip), 1, 600)

		for _, zip in { "", "not a zip archive, only text long enough to hold an end record", truncated } do
			local opened = VirtualFileSystem.fromZip(zip)

			expect(opened.ok).toBe(false)
			expect(opened.error.path).toBe("")
			expect(string.sub(opened.error.message, 1, 27)).toBe("the zip could not be read: ")
		end

		expect(VirtualFileSystem.fromZip(truncated)).toEqual({
			ok = false,
			error = { path = "", message = "the zip could not be read: .ZIP file comments not supported" },
		})
	end)

	it("fails to read a corrupt member instead of throwing, and still reads the others", function()
		local opened = VirtualFileSystem.fromZip(decode(fixture.corruptMember))

		expect(opened.ok).toBe(true)
		expect(opened.value:ReadFile("src/a.luau")).toEqual({
			ok = false,
			error = { path = "src/a.luau", message = "could not be decompressed: unsupported block type" },
		})
		expect(opened.value:ReadFile("src/B.luau")).toEqual({ ok = true, value = 'return "B"\n' })
	end)

	it("builds the same tree from in-memory files, a trailing `/` marking an empty directory", function()
		local fileSystem = VirtualFileSystem.fromFiles({
			["src/init.luau"] = "return {}",
			["src/a.luau"] = "",
			["src/_private.luau"] = "",
			["src/B.luau"] = "",
			["src/empty/"] = "",
			["default.project.json"] = "{}",
		})

		expect(fileSystem:ListDirectory("")).toEqual({ "default.project.json", "src" })
		expect(fileSystem:ListDirectory("src")).toEqual(SOURCE_LISTING)
		expect(fileSystem:IsDirectory("src/empty")).toBe(true)
		expect(fileSystem:IsFile("src/empty")).toBe(false)
		expect(fileSystem:ListDirectory("src/empty")).toEqual({})
		expect(fileSystem:ReadFile("src/init.luau")).toEqual({ ok = true, value = "return {}" })
		expect(fileSystem:ReadFile("src/a.luau")).toEqual({ ok = true, value = "" })
		expect(fileSystem:ReadFile("src/../default.project.json")).toEqual({ ok = true, value = "{}" })
	end)
end)
