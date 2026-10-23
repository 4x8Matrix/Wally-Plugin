local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local PluginMetaService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginMetaService)
local PluginPropertyService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginPropertyService)
local VirtualFileSystem = require(ReplicatedStorage.WallyPlugin.PluginClasses.VirtualFileSystem)

local FOLDER_ONLY =
	"className in init.meta.json can only be specified if the affected directory would turn into a Folder instance."
local ID_TWICE = "cannot specify an ID (instance has an ID from somewhere else)"
local SCHEMA_TWICE = "cannot specify a schema (instance has a schema from somewhere else)"

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local reporter = PluginPropertyService.Reporter
local warnings = {}

local function instance(path: string, name: string, className: string, properties: { [string]: any }?): any
	return { name = name, className = className, properties = properties or {}, children = {}, path = path }
end

local function applyAdjacent(files: { [string]: string }, snapshot: any): any
	local fileSystem = VirtualFileSystem.fromFiles(files)

	return PluginMetaService:ApplyAdjacentMeta(fileSystem, snapshot.path, snapshot.name, snapshot)
end

local function applyDirectory(files: { [string]: string }, snapshot: any): any
	return PluginMetaService:ApplyDirectoryMeta(VirtualFileSystem.fromFiles(files), snapshot.path, snapshot)
end

local function adjacent(path: string, className: string, properties: { [string]: any }, files: { [string]: any }): any
	local name = string.match(path, "([^/.]+)[^/]*$")
	local snapshot = instance(path, name, className, properties)
	local result = applyAdjacent(files, snapshot)

	expect(result).toEqual({ ok = true })

	return { className = snapshot.className, properties = snapshot.properties, id = snapshot.id }
end

local function folder(path: string, files: { [string]: string }): any
	local snapshot = instance(path, string.match(path, "[^/]*$"), "Folder")
	local result = applyDirectory(files, snapshot)

	expect(result).toEqual({ ok = true })

	return { className = snapshot.className, properties = snapshot.properties, id = snapshot.id }
end

local function refused(path: string, message: string): any
	return { ok = false, error = { path = path, message = message } }
end

describe("PluginMetaService", function()
	beforeEach(function()
		table.clear(warnings)

		PluginPropertyService.Reporter = {
			Warn = function(_, message: string)
				table.insert(warnings, message)
			end,
		}
	end)

	afterEach(function()
		PluginPropertyService.Reporter = reporter
	end)

	describe("ApplyAdjacentMeta", function()
		it("reads <name>.meta.json beside the file, the name being the instance's", function()
			expect(adjacent("src/foo.server.lua", "Script", { Source = "foo" }, {
				["src/foo.server.lua"] = "foo",
				["src/foo.meta.json"] = '{"attributes": {"Shared": true}}',
				["src/foo.server.meta.json"] = '{"attributes": {"Wrong": true}}',
			})).toEqual({ className = "Script", properties = { Source = "foo", Attributes = { Shared = true } } })
		end)

		it("leaves an instance without meta files as it was", function()
			expect(adjacent("x.lua", "ModuleScript", { Source = "x" }, { ["x.lua"] = "x" })).toEqual({
				className = "ModuleScript",
				properties = { Source = "x" },
			})
		end)

		it("lets meta properties override the file's own Source and Value", function()
			expect(adjacent("src/ov.lua", "ModuleScript", { Source = "ov" }, {
				["src/ov.meta.json"] = '{"properties": {"Source": "over"}}',
			}).properties).toEqual({ Source = "over" })
			expect(adjacent("src/ov3.json", "ModuleScript", { Source = "return {1}" }, {
				["src/ov3.meta.json"] = '{"properties": {"Source": "return 2"}}',
			}).properties).toEqual({ Source = "return 2" })
			expect(adjacent("src/rc.server.lua", "Script", { Source = "rc", RunContext = Enum.RunContext.Legacy }, {
				["src/rc.meta.json"] = '{"properties": {"RunContext": "Client"}}',
			}).properties).toEqual({ Source = "rc", RunContext = Enum.RunContext.Client })
		end)

		it(
			"clears a property that a left-out value overrides, as Studio loads Rojo's build with the default",
			function()
				local server = Enum.RunContext.Server

				expect(adjacent("src/a.server.lua", "Script", { Source = "a", RunContext = server }, {
					["src/a.meta.json"] = '{"properties": {"RunContext": {"Enum": 99}}}',
				}).properties).toEqual({ Source = "a" })
				expect(adjacent("src/b.server.lua", "Script", { Source = "b", RunContext = server }, {
					["src/b.meta.json"] = '{"properties": {"RunContext": "Client"}}',
					["src/b.meta.jsonc"] = '{"properties": {"RunContext": {"Enum": 99}}}',
				}).properties).toEqual({ Source = "b" })
			end
		)

		it("applies .meta.json then .meta.jsonc, the later property winning", function()
			expect(adjacent("src/pr.txt", "StringValue", { Value = "pr" }, {
				["src/pr.meta.json"] = '{"properties": {"Value": "one", "Tags": ["x"]}}',
				["src/pr.meta.jsonc"] = '{"properties": {"Value": "two"}}',
			}).properties).toEqual({ Value = "two", Tags = { "x" } })
		end)

		it("replaces Attributes whole with a non-empty attributes field", function()
			expect(adjacent("src/at.lua", "ModuleScript", { Source = "at" }, {
				["src/at.meta.json"] = '{"properties": {"Attributes": {"A": {"Float64": 1}}}, "attributes": {"B": true}}',
			}).properties).toEqual({ Source = "at", Attributes = { B = true } })
			expect(adjacent("src/at2.txt", "StringValue", { Value = "at2" }, {
				["src/at2.meta.json"] = '{"attributes": {"A": 1}}',
				["src/at2.meta.jsonc"] = '{"attributes": {"B": 2}}',
			}).properties).toEqual({ Value = "at2", Attributes = { B = 2 } })
			expect(adjacent("src/at3.lua", "ModuleScript", { Source = "at3" }, {
				["src/at3.meta.json"] = '{"attributes": {"A": 1}}',
				["src/at3.meta.jsonc"] = '{"attributes": {}}',
			}).properties).toEqual({ Source = "at3", Attributes = { A = 1 } })
			expect(adjacent("src/at4.lua", "ModuleScript", { Source = "at4" }, {
				["src/at4.meta.json"] = '{"properties": {"Attributes": {"A": {"Float64": 1}}}}',
			}).properties).toEqual({ Source = "at4", Attributes = { A = 1 } })
		end)

		it("reads a meta file written as an array by position and ignores unknown fields", function()
			expect(adjacent("src/x.lua", "ModuleScript", { Source = "x" }, {
				["src/x.meta.json"] = '[null, "aid", false, {"Tags": ["t"]}, {"A": 1}]',
			})).toEqual({
				className = "ModuleScript",
				properties = { Source = "x", Tags = { "t" }, Attributes = { A = 1 } },
				id = "aid",
			})
			expect(adjacent("src/y.lua", "ModuleScript", { Source = "y" }, {
				["src/y.meta.json"] = '{"unknown": 1, "className": 5, "Properties": {"Bogus": 1}}',
			})).toEqual({ className = "ModuleScript", properties = { Source = "y" } })
		end)

		it("ignores className in an adjacent meta file", function()
			expect(adjacent("src/ac.lua", "ModuleScript", { Source = "ac" }, {
				["src/ac.meta.json"] = '{"className": "Folder"}',
			}).className).toBe("ModuleScript")
		end)

		it("drops a Name property with PluginPropertyService's warning", function()
			expect(adjacent("src/x.lua", "ModuleScript", { Source = "x" }, {
				["src/x.meta.json"] = '{"properties": {"Name": "renamed", "Tags": ["n"]}}',
			}).properties).toEqual({ Source = "x", Tags = { "n" } })
			expect(warnings).toEqual({ "Property 'Name' cannot be set manually, ignoring (ModuleScript.Name)" })
		end)

		it("takes id from the last meta file, clearing it when that file has none", function()
			expect(adjacent("src/x.lua", "ModuleScript", {}, { ["src/x.meta.json"] = '{"id": "x"}' }).id).toBe("x")
			expect(adjacent("src/w.lua", "ModuleScript", {}, {
				["src/w.meta.json"] = '{"id": "w"}',
				["src/w.meta.jsonc"] = "{}",
			}).id).toBeNil()
			expect(adjacent("src/v.lua", "ModuleScript", {}, {
				["src/v.meta.jsonc"] = '{"id": "v", "$schema": "s"}',
			}).id).toBe("v")
			expect(adjacent("src/sc.lua", "ModuleScript", {}, {
				["src/sc.meta.json"] = '{"$schema": "a"}',
				["src/sc.meta.jsonc"] = '{"id": "sc"}',
			}).id).toBe("sc")
		end)

		it("refuses an id or a $schema that both meta files give", function()
			local snapshot = instance("src/y.lua", "y", "ModuleScript")

			expect(applyAdjacent({
				["src/y.meta.json"] = '{"id": "y1"}',
				["src/y.meta.jsonc"] = '{"id": "y2"}',
			}, snapshot)).toEqual(refused("src/y.meta.jsonc", ID_TWICE))
			expect(applyAdjacent({
				["src/y.meta.json"] = '{"$schema": "a"}',
				["src/y.meta.jsonc"] = '{"$schema": "b"}',
			}, instance("src/y.lua", "y", "ModuleScript"))).toEqual(refused("src/y.meta.jsonc", SCHEMA_TWICE))
			expect(applyAdjacent({
				["src/e/e.meta.json"] = '{"id": "a"}',
				["src/e/e.meta.jsonc"] = '{"id": "b"}',
			}, instance("src/e/init.lua", "e", "ModuleScript"))).toEqual(refused("src/e/e.meta.jsonc", ID_TWICE))
		end)

		it("refuses properties and attributes that do not resolve, naming the meta file", function()
			local function refusal(text: string): any
				return applyAdjacent({ ["src/x.meta.json"] = text }, instance("src/x.lua", "x", "ModuleScript"))
			end

			expect(refusal('{"properties": {"Bogus": 1}}')).toEqual(
				refused("src/x.meta.json", "Unknown property ModuleScript.Bogus")
			)
			expect(refusal('{"attributes": {"A": [1, 2]}}')).toEqual(
				refused("src/x.meta.json", "Cannot unambiguously resolve the value Array2([1.0, 2.0])")
			)
			expect(refusal('{"properties": {"Source": null}}')).toEqual(
				refused("src/x.meta.json", "data did not match any variant of untagged enum UnresolvedValue")
			)
			expect(refusal('{"properties": {"Attributes": {"A": 1}}}')).toEqual(
				refused("src/x.meta.json", "data did not match any variant of untagged enum UnresolvedValue")
			)
		end)

		it("refuses a meta file that does not decode or is a directory", function()
			local snapshot = instance("src/x.lua", "x", "ModuleScript")

			expect(applyAdjacent({ ["src/x.meta.json"] = "" }, snapshot)).toEqual(
				refused("src/x.meta.json", "File contained malformed .meta.json data: File contains no JSON value")
			)
			expect(applyAdjacent({ ["src/x.meta.json"] = "5" }, snapshot)).toEqual(
				refused(
					"src/x.meta.json",
					"File contained malformed .meta.json data: invalid type: integer `5`, expected struct AdjacentMetadata"
				)
			)
			expect(applyAdjacent({ ["src/x.meta.json/inner.txt"] = "i" }, snapshot)).toEqual(
				refused("src/x.meta.json", "is a directory")
			)
		end)
	end)

	describe("ApplyDirectoryMeta", function()
		it("applies init.meta.json then init.meta.jsonc to a plain directory's Folder", function()
			expect(folder("src/pl", {
				["src/pl/init.meta.json"] = '{"properties": {"Tags": ["plain"]}, "attributes": {"P": 1}}',
				["src/pl/init.meta.jsonc"] = '{"properties": {"Tags": ["later"]}, "id": "pl"}',
			})).toEqual({
				className = "Folder",
				properties = { Tags = { "later" }, Attributes = { P = 1 } },
				id = "pl",
			})
		end)

		it("changes a Folder's class, resolving the properties against the new class", function()
			expect(folder("src/cf", {
				["src/cf/init.meta.json"] = '{"className": "StringValue", "properties": {"Value": "hi"}}',
			})).toEqual({ className = "StringValue", properties = { Value = "hi" } })
			expect(folder("src/ck", {
				["src/ck/init.meta.json"] = '{"className": "Folder"}',
				["src/ck/init.meta.jsonc"] = '{"className": "Model"}',
			}).className).toBe("Model")
			expect(folder("src/d6", {
				["src/d6/init.meta.json"] = '[null, null, null, {}, {}, "Model"]',
			}).className).toBe("Model")
		end)

		it("makes a Folder a DataModel, for its parent to leave out as Studio's loader does (g-meta-dm)", function()
			expect(folder("src/d", { ["src/d/init.meta.json"] = '{"className": "DataModel"}' })).toEqual({
				className = "DataModel",
				properties = {},
			})
		end)

		it("refuses className once the instance is not a Folder", function()
			expect(applyDirectory({
				["src/cs/init.meta.json"] = '{"className": "Folder"}',
			}, instance("src/cs", "cs", "Script"))).toEqual(refused("src/cs/init.meta.json", FOLDER_ONLY))
			expect(applyDirectory({
				["src/cs/init.meta.json"] = '{"className": "Folder"}',
			}, instance("src/cs", "cs", "LocalizationTable"))).toEqual(refused("src/cs/init.meta.json", FOLDER_ONLY))
			expect(applyDirectory({
				["src/cj/init.meta.json"] = '{"className": "Model"}',
				["src/cj/init.meta.jsonc"] = '{"className": "Configuration"}',
			}, instance("src/cj", "cj", "Folder"))).toEqual(refused("src/cj/init.meta.jsonc", FOLDER_ONLY))
		end)

		it(
			"applies a class a plugin cannot create, for the package's check, and refuses properties it lacks",
			function()
				expect(folder("src/cu", { ["src/cu/init.meta.json"] = '{"className": "NotAClass"}' })).toEqual({
					className = "NotAClass",
					properties = {},
				})
				expect(applyDirectory({
					["src/cb/init.meta.json"] = '{"className": "Model", "properties": {"Bogus": 1}}',
				}, instance("src/cb", "cb", "Folder"))).toEqual(
					refused("src/cb/init.meta.json", "Unknown property Model.Bogus")
				)
			end
		)

		it("refuses an id or a $schema that both directory meta files give", function()
			expect(applyDirectory({
				["src/d/init.meta.json"] = '{"id": "a"}',
				["src/d/init.meta.jsonc"] = '{"id": "b"}',
			}, instance("src/d", "d", "Folder"))).toEqual(refused("src/d/init.meta.jsonc", ID_TWICE))
			expect(applyDirectory({
				["src/d/init.meta.json"] = '{"$schema": "a"}',
				["src/d/init.meta.jsonc"] = '{"$schema": "b"}',
			}, instance("src/d", "d", "Folder"))).toEqual(refused("src/d/init.meta.jsonc", SCHEMA_TWICE))
		end)

		it("refuses a directory meta file that does not decode, in its own words", function()
			expect(applyDirectory({
				["src/d/init.meta.json"] = '{"className": 5}',
			}, instance("src/d", "d", "Folder"))).toEqual(
				refused(
					"src/d/init.meta.json",
					"File contained malformed init.meta.json data: invalid type: integer `5`, expected a &str"
				)
			)
		end)
	end)
end)
