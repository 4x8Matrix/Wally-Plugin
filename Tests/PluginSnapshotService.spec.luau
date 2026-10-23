local EncodingService = game:GetService("EncodingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local PluginModelService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginModelService)
local PluginPropertyService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginPropertyService)
local PluginSnapshotService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginSnapshotService)
local VirtualFileSystem = require(ReplicatedStorage.WallyPlugin.PluginClasses.VirtualFileSystem)

local compileGlob = require(ReplicatedStorage.WallyPlugin.PluginUtilities.compileGlob)
local fixture = require(ReplicatedStorage.Tests.Fixtures.modelFiles)
local serialiserFiles = require(ReplicatedStorage.Tests.Fixtures.serialiserFiles)

local RBXM = buffer.tostring(EncodingService:Base64Decode(buffer.fromstring(fixture.rbxm)))
local RBXMX = buffer.tostring(EncodingService:Base64Decode(buffer.fromstring(fixture.rbxmx)))
local FOLDER_RBXM = buffer.tostring(EncodingService:Base64Decode(buffer.fromstring(serialiserFiles.folderModel)))
local CSV = "Key,Source,es\nHi,Hello,Hola\n"
local CONTENTS = '[{"key":"Hi","source":"Hello","values":{"es":"Hola"}}]'
local META = '{"attributes": {"M": true}}'
local FOLDER_ONLY =
	"className in init.meta.json can only be specified if the affected directory would turn into a Folder instance."
local LEGACY = Enum.RunContext.Legacy
local SERVER = Enum.RunContext.Server
local CLIENT = Enum.RunContext.Client
local PLUGIN = Enum.RunContext.Plugin
local INVALID_UTF8 = {
	{ "a script", "src/x.lua", "File was not valid UTF-8" },
	{ "a text file", "src/x.txt", "File was not valid UTF-8" },
	{ "a JSON module", "src/x.json", "File contains malformed JSON: File is not valid UTF-8" },
	{ "a TOML module", "src/x.toml", "File contains malformed TOML: source is not valid UTF-8 around 1" },
	{ "a YAML module", "src/x.yaml", "File was not valid UTF-8" },
	{ "a CSV file", "src/x.csv", "File was not a valid LocalizationTable CSV file: invalid UTF-8" },
	{ "an adjacent meta file", "src/x.meta.json", "File contained malformed .meta.json data: File is not valid UTF-8" },
	{
		"a directory meta file",
		"src/d/init.meta.json",
		"File contained malformed init.meta.json data: File is not valid UTF-8",
	},
	{ "an init script", "src/d/init.server.lua", "File was not valid UTF-8" },
}
local SCRIPT_RULES = {
	{ "**/*.lsv", "legacyServerScript" },
	{ "**/*.lcl", "legacyClientScript" },
	{ "**/*.rsv", "runContextServerScript" },
	{ "**/*.rcl", "runContextClientScript" },
	{ "**/*.srv", "serverScript" },
	{ "**/*.cli", "clientScript" },
	{ "**/*.mod", "moduleScript" },
	{ "**/*.plg", "pluginScript" },
}
local SCRIPT_FILES = {
	["src/a.server.lua"] = "a",
	["src/c.client.lua"] = "c",
	["src/e.plugin.lua"] = "e",
	["src/g.lua"] = "g",
	["src/sv/init.server.lua"] = "sv",
	["src/cl/init.client.luau"] = "cl",
	["src/pl/init.plugin.luau"] = "pl",
	["src/ls.lsv"] = "src/ls.lsv",
	["src/lc.lcl"] = "src/lc.lcl",
	["src/rs.rsv"] = "src/rs.rsv",
	["src/rc.rcl"] = "src/rc.rcl",
	["src/sv2.srv"] = "src/sv2.srv",
	["src/cl2.cli"] = "src/cl2.cli",
	["src/md.mod"] = "src/md.mod",
	["src/pl2.plg"] = "src/pl2.plg",
}

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local propertyReporter = PluginPropertyService.Reporter
local modelReporter = PluginModelService.Reporter
local snapshotBinaryModel = PluginModelService.SnapshotBinaryModel
local snapshotProject = PluginSnapshotService.SnapshotProject
local warnings = {}
local loaded = {}
local projects = {}

local function context(fields: { [string]: any }?): any
	local given = fields or {}

	return {
		syncRules = given.syncRules or {},
		ignoreRules = given.ignoreRules or {},
		emitLegacyScripts = if given.emitLegacyScripts == false then false else true,
	}
end

local function syncRule(pattern: string, use: string, options: { [string]: string }?): any
	local given = options or {}

	return {
		matches = compileGlob(pattern).value,
		excludes = if given.exclude then compileGlob(given.exclude).value else nil,
		use = use,
		suffix = given.suffix,
	}
end

local function ignoreRule(pattern: string): any
	local negated = string.sub(pattern, 1, 1) == "!"
	local body = if negated then string.sub(pattern, 2) else pattern

	return { folder = "", matches = compileGlob(body).value, negated = negated }
end

local function view(snapshot: any): { [string]: any }
	local node = {
		name = snapshot.name,
		class = snapshot.className,
		id = snapshot.id,
		model = if snapshot.model then snapshot.model.ClassName else nil,
	}
	local children = {}

	for key, value in snapshot.properties do
		node[key] = value
	end

	for _, child in snapshot.children do
		table.insert(children, view(child))
	end

	if #children > 0 then
		node.children = children
	end

	return node
end

local function holdModels(snapshot: any)
	if snapshot.model then
		table.insert(loaded, snapshot.model)
	end

	for _, child in snapshot.children do
		holdModels(child)
	end
end

local function snapshotPath(files: { [string]: string }, path: string, fields: { [string]: any }?): any
	local fileSystem = VirtualFileSystem.fromFiles(files)
	local result = PluginSnapshotService:SnapshotPath(fileSystem, path, context(fields))

	if result.ok and result.value then
		holdModels(result.value)
	end

	return result
end

local function build(files: { [string]: string }, fields: { [string]: any }?): any
	local result = snapshotPath(files, "src", fields)

	expect(result.ok).toBe(true)

	return view(result.value)
end

local function children(files: { [string]: string }, fields: { [string]: any }?): any
	return build(files, fields).children or {}
end

local function refusal(files: { [string]: string }, fields: { [string]: any }?): any
	local result = snapshotPath(files, "src", fields)

	expect(result.ok).toBe(false)

	return result.error
end

local function stubProjects(name: string?, className: string?)
	PluginSnapshotService.SnapshotProject = function(_, _fileSystem, path: string, _context, projectName: string)
		table.insert(projects, { path = path, name = projectName })

		return {
			ok = true,
			value = {
				name = name or projectName,
				className = className or "Project",
				properties = {},
				children = {},
				path = path,
			},
		}
	end
end

local function holdLoadedModels()
	PluginModelService.SnapshotBinaryModel = function(self, fileSystem, path: string, name: string)
		local result = snapshotBinaryModel(self, fileSystem, path, name)

		if result.ok then
			table.insert(loaded, result.value.model)
		end

		return result
	end
end

local function isDestroyed(instance: Instance): boolean
	local probe = Instance.new("Folder")
	local moved = pcall(function()
		instance.Parent = probe
	end)

	probe:Destroy()

	return not moved
end

describe("PluginSnapshotService", function()
	beforeEach(function()
		local reporter = {
			Warn = function(_, message: string)
				table.insert(warnings, message)
			end,
		}

		table.clear(warnings)
		table.clear(projects)

		PluginPropertyService.Reporter = reporter
		PluginModelService.Reporter = reporter
	end)

	afterEach(function()
		PluginPropertyService.Reporter = propertyReporter
		PluginModelService.Reporter = modelReporter
		PluginModelService.SnapshotBinaryModel = snapshotBinaryModel
		PluginSnapshotService.SnapshotProject = snapshotProject

		for _, model in loaded do
			model:Destroy()
		end

		table.clear(loaded)
	end)

	describe("DefaultContext", function()
		it("holds no sync or ignore rules and emits legacy scripts, as a build without a project", function()
			expect(PluginSnapshotService:DefaultContext()).toEqual({
				syncRules = {},
				ignoreRules = {},
				emitLegacyScripts = true,
			})
		end)
	end)

	describe("default rules (R1.2)", function()
		it("turns a file of every rule into its instance, named by the rule", function()
			stubProjects()

			expect(children({
				["src/a.server.lua"] = "a",
				["src/b.server.luau"] = "b",
				["src/c.client.lua"] = "c",
				["src/d.client.luau"] = "d",
				["src/e.plugin.lua"] = "e",
				["src/f.plugin.luau"] = "f",
				["src/g.lua"] = "g",
				["src/h.luau"] = "h",
				["src/g.spec.lua"] = "gs",
				["src/j.model.json"] = '{"className": "Configuration"}',
				["src/k.model.jsonc"] = '{"className": "Model"}',
				["src/l.json"] = '{"b": 1, "a": [true, null]}',
				["src/z.meta.json"] = "{}",
				["src/m.jsonc"] = "[1, 2]",
				["src/y.meta.jsonc"] = "{}",
				["src/n.toml"] = "x = 1",
				["src/a.b.toml"] = "",
				["src/o.csv"] = CSV,
				["src/p.txt"] = "text",
				["src/q.rbxmx"] = RBXMX,
				["src/r.rbxm"] = RBXM,
				["src/s.yml"] = "a: 1",
				["src/t.yaml"] = "- 1",
				["src/.lua"] = "dot",
				["src/.foo.lua"] = "dotfoo",
				["src/.server.lua"] = "dotserver",
				["src/u.project.json"] = '{"tree": {"$className": "Folder"}}',
				["src/v.project.jsonc"] = '{"name": "Named", "tree": {"$className": "Folder"}}',
			})).toEqual({
				{ name = ".foo", class = "ModuleScript", Source = "dotfoo" },
				{ name = ".lua", class = "ModuleScript", Source = "dot" },
				{ name = "", class = "Script", Source = "dotserver", RunContext = LEGACY },
				{ name = "a.b", class = "ModuleScript", Source = "return {\n}" },
				{ name = "a", class = "Script", Source = "a", RunContext = LEGACY },
				{ name = "b", class = "Script", Source = "b", RunContext = LEGACY },
				{ name = "c", class = "LocalScript", Source = "c" },
				{ name = "d", class = "LocalScript", Source = "d" },
				{ name = "e", class = "Script", Source = "e", RunContext = PLUGIN },
				{ name = "f", class = "Script", Source = "f", RunContext = PLUGIN },
				{ name = "g", class = "ModuleScript", Source = "g" },
				{ name = "g.spec", class = "ModuleScript", Source = "gs" },
				{ name = "h", class = "ModuleScript", Source = "h" },
				{ name = "j", class = "Configuration" },
				{ name = "k", class = "Model" },
				{ name = "l", class = "ModuleScript", Source = "return {\n\ta = {true, nil},\n\tb = 1,\n}" },
				{ name = "m", class = "ModuleScript", Source = "return {1, 2}" },
				{ name = "n", class = "ModuleScript", Source = "return {\n\tx = 1,\n}" },
				{ name = "o", class = "LocalizationTable", Contents = CONTENTS },
				{ name = "p", class = "StringValue", Value = "text" },
				{ name = "q", class = "Model", model = "Model" },
				{ name = "r", class = "Model", model = "Model" },
				{ name = "s", class = "ModuleScript", Source = "return {\n\ta = 1,\n}" },
				{ name = "t", class = "ModuleScript", Source = "return {1}" },
				{ name = "u", class = "Project" },
				{ name = "v", class = "Project" },
			})
			expect(projects).toEqual({
				{ path = "src/u.project.json", name = "u" },
				{ path = "src/v.project.jsonc", name = "v" },
			})
		end)

		it(
			"hands project files to PluginProjectService, which builds their $path targets through SnapshotPath",
			function()
				expect(children({
					["src/u.project.json"] = '{"tree": {"$className": "Model", "Kid": {"$path": "a.server.lua"}}}',
					["src/a.server.lua"] = "a",
				})).toEqual({
					{ name = "a", class = "Script", Source = "a", RunContext = LEGACY },
					{
						name = "u",
						class = "Model",
						children = { { name = "Kid", class = "Script", Source = "a", RunContext = LEGACY } },
					},
				})
			end
		)

		it(
			"leaves out a DataModel entry, from a model file or a directory meta, with a warning (g-model-top, g-meta-dm)",
			function()
				local dropped = '%s: the DataModel "%s" is left out, as Studio\'s loader drops a DataModel below other instances'
					.. " with everything under it"

				expect(children({
					["src/dm.model.json"] = '{"className": "DataModel", "children": [{"className": "Folder"}]}',
					["src/d/init.meta.json"] = '{"className": "DataModel"}',
					["src/d/x.lua"] = "x",
					["src/a.lua"] = "a",
				})).toEqual({ { name = "a", class = "ModuleScript", Source = "a" } })
				expect(warnings).toEqual({
					string.format(dropped, "src/d", "d"),
					string.format(dropped, "src/dm.model.json", "dm"),
				})
			end
		)

		it("skips unrecognised files and extensions in the wrong case (R1.15)", function()
			expect(children({
				["src/README.md"] = "#",
				["src/.gitkeep"] = "",
				["src/LICENSE"] = "MIT",
				["src/Foo.LUA"] = "x",
				["src/x.Json"] = "1",
				["src/y.TXT"] = "y",
				["src/orphan.meta.json"] = META,
			})).toEqual({})
		end)

		it("makes modules of every recognised file, hidden folders and wally.toml included (R4.3)", function()
			expect(children({
				["src/.github/workflows/ci.yml"] = "on: push",
				["src/.vscode/settings.json"] = "{}",
				["src/wally.toml"] = '[package]\nname = "a/b"',
			})).toEqual({
				{
					name = ".github",
					class = "Folder",
					children = {
						{
							name = "workflows",
							class = "Folder",
							children = {
								{ name = "ci", class = "ModuleScript", Source = 'return {\n\ton = "push",\n}' },
							},
						},
					},
				},
				{
					name = ".vscode",
					class = "Folder",
					children = { { name = "settings", class = "ModuleScript", Source = "return {\n}" } },
				},
				{
					name = "wally",
					class = "ModuleScript",
					Source = 'return {\n\tpackage = {\n\t\tname = "a/b",\n\t},\n}',
				},
			})
		end)

		it("builds empty files as Rojo does", function()
			expect(children({
				["src/e.lua"] = "",
				["src/e.txt"] = "",
				["src/e.csv"] = "",
				["src/e.toml"] = "",
			})).toEqual({
				{ name = "e", class = "LocalizationTable", Contents = "[]" },
				{ name = "e", class = "ModuleScript", Source = "" },
				{ name = "e", class = "ModuleScript", Source = "return {\n}" },
				{ name = "e", class = "StringValue", Value = "" },
			})
		end)

		it("gives no instance for a missing path or an init file reached directly (R1.1)", function()
			expect(snapshotPath({ ["src/init.lua"] = "x" }, "src/init.lua")).toEqual({ ok = true })
			expect(snapshotPath({ ["src/init.csv"] = CSV }, "src/init.csv")).toEqual({ ok = true })
			expect(snapshotPath({}, "src/missing.lua")).toEqual({ ok = true })
		end)
	end)

	describe("scripts (R1.3)", function()
		local rules = {}

		for _, rule in SCRIPT_RULES do
			table.insert(rules, syncRule(rule[1], rule[2]))
		end

		it("picks classes and RunContext for emitLegacyScripts true", function()
			expect(children(SCRIPT_FILES, { syncRules = rules })).toEqual({
				{ name = "a", class = "Script", Source = "a", RunContext = LEGACY },
				{ name = "c", class = "LocalScript", Source = "c" },
				{ name = "cl", class = "LocalScript", Source = "cl" },
				{ name = "cl2", class = "LocalScript", Source = "src/cl2.cli" },
				{ name = "e", class = "Script", Source = "e", RunContext = PLUGIN },
				{ name = "g", class = "ModuleScript", Source = "g" },
				{ name = "lc", class = "LocalScript", Source = "src/lc.lcl" },
				{ name = "ls", class = "Script", Source = "src/ls.lsv", RunContext = LEGACY },
				{ name = "md", class = "ModuleScript", Source = "src/md.mod" },
				{ name = "pl", class = "Script", Source = "pl", RunContext = PLUGIN },
				{ name = "pl2", class = "Script", Source = "src/pl2.plg", RunContext = PLUGIN },
				{ name = "rc", class = "Script", Source = "src/rc.rcl", RunContext = CLIENT },
				{ name = "rs", class = "Script", Source = "src/rs.rsv", RunContext = SERVER },
				{ name = "sv", class = "Script", Source = "sv", RunContext = LEGACY },
				{ name = "sv2", class = "Script", Source = "src/sv2.srv", RunContext = LEGACY },
			})
		end)

		it("picks classes and RunContext for emitLegacyScripts false", function()
			expect(children(SCRIPT_FILES, { syncRules = rules, emitLegacyScripts = false })).toEqual({
				{ name = "a", class = "Script", Source = "a", RunContext = SERVER },
				{ name = "c", class = "Script", Source = "c", RunContext = CLIENT },
				{ name = "cl", class = "Script", Source = "cl", RunContext = CLIENT },
				{ name = "cl2", class = "Script", Source = "src/cl2.cli", RunContext = CLIENT },
				{ name = "e", class = "Script", Source = "e", RunContext = PLUGIN },
				{ name = "g", class = "ModuleScript", Source = "g" },
				{ name = "lc", class = "LocalScript", Source = "src/lc.lcl" },
				{ name = "ls", class = "Script", Source = "src/ls.lsv", RunContext = LEGACY },
				{ name = "md", class = "ModuleScript", Source = "src/md.mod" },
				{ name = "pl", class = "Script", Source = "pl", RunContext = PLUGIN },
				{ name = "pl2", class = "Script", Source = "src/pl2.plg", RunContext = PLUGIN },
				{ name = "rc", class = "Script", Source = "src/rc.rcl", RunContext = CLIENT },
				{ name = "rs", class = "Script", Source = "src/rs.rsv", RunContext = SERVER },
				{ name = "sv", class = "Script", Source = "sv", RunContext = SERVER },
				{ name = "sv2", class = "Script", Source = "src/sv2.srv", RunContext = SERVER },
			})
		end)

		it("turns CRLF into LF in scripts only, keeping a lone CR and a byte order mark", function()
			expect(children({
				["src/crlf.lua"] = "a\r\nb\rc\r\n",
				["src/crlf.server.lua"] = "x\r\ny",
				["src/crlf.txt"] = "a\r\nb\r",
				["src/bom.lua"] = "\u{FEFF}return 1",
				["src/crlf.json"] = '{"a":\r\n"b\\r\\n"}',
			})).toEqual({
				{ name = "bom", class = "ModuleScript", Source = "\u{FEFF}return 1" },
				{ name = "crlf", class = "ModuleScript", Source = 'return {\n\ta = "b\\r\\n",\n}' },
				{ name = "crlf", class = "ModuleScript", Source = "a\nb\rc\n" },
				{ name = "crlf", class = "Script", Source = "x\ny", RunContext = LEGACY },
				{ name = "crlf", class = "StringValue", Value = "a\r\nb\r" },
			})
		end)
	end)

	describe("refusals", function()
		for _, case in INVALID_UTF8 do
			local name, path, message = table.unpack(case)

			it(`refuses {name} that is not valid UTF-8`, function()
				local files = { [path] = "a\255", ["src/x.lua"] = if path == "src/x.lua" then "a\255" else "x" }

				expect(refusal(files)).toEqual({ path = path, message = message })
			end)
		end

		it("refuses an empty JSON module", function()
			expect(refusal({ ["src/x.json"] = "" })).toEqual({
				path = "src/x.json",
				message = "File contains malformed JSON: File contains no JSON value",
			})
		end)

		it("refuses an init file that is a directory", function()
			expect(refusal({ ["src/d/init.lua/inner.txt"] = "i", ["src/d/a.lua"] = "a" })).toEqual({
				path = "src/d/init.lua",
				message = "is a directory",
			})
		end)

		it("destroys every model loaded before a refusal, nested and under an init file", function()
			holdLoadedModels()

			local cases = {
				{ ["src/a.rbxm"] = RBXM, ["src/b.txt"] = "\255" },
				{ ["src/d/a.rbxmx"] = RBXMX, ["src/e.txt"] = "\255" },
				{ ["src/i/a.rbxm"] = RBXM, ["src/i/init.lua"] = "\255" },
				{ ["src/f/a.rbxm"] = RBXM, ["src/f/init.meta.json"] = "{" },
				{ ["src/s/a.rbxm"] = RBXM, ["src/s/init.server.lua"] = "s", ["src/s/init.meta.json"] = "{" },
			}

			for _, files in cases do
				expect(snapshotPath(files, "src").ok).toBe(false)
			end

			expect(#loaded).toBe(#cases)

			for _, model in loaded do
				expect(isDestroyed(model)).toBe(true)
			end

			local kept = snapshotPath({ ["src/a.rbxm"] = RBXM, ["src/b.txt"] = "b" }, "src")

			expect(kept.ok).toBe(true)
			expect(isDestroyed(kept.value.children[1].model)).toBe(false)
		end)
	end)

	describe("init files (R1.4)", function()
		it("picks the directory's instance by precedence and drops the other init files", function()
			stubProjects()

			expect(children({
				["src/p1/init.luau"] = "p1 luau",
				["src/p1/init.lua"] = "p1 lua",
				["src/p1/init.server.lua"] = "p1 server",
				["src/p1/child.lua"] = "c",
				["src/p2/init.lua"] = "p2 lua",
				["src/p2/init.server.luau"] = "p2 server",
				["src/p3/init.server.luau"] = "p3 server luau",
				["src/p3/init.server.lua"] = "p3 server lua",
				["src/p3/init.client.lua"] = "p3 client",
				["src/p4/init.server.lua"] = "p4 server lua",
				["src/p4/init.client.luau"] = "p4 client",
				["src/p5/init.client.luau"] = "p5 client luau",
				["src/p5/init.client.lua"] = "p5 client lua",
				["src/p5/init.plugin.lua"] = "p5 plugin",
				["src/p6/init.client.lua"] = "p6 client lua",
				["src/p6/init.plugin.lua"] = "p6 plugin",
				["src/p7/init.plugin.lua"] = "p7 plugin lua",
				["src/p7/init.plugin.luau"] = "p7 plugin luau",
				["src/p7/init.csv"] = CSV,
				["src/p8/init.plugin.luau"] = "p8 plugin luau",
				["src/p8/init.csv"] = CSV,
				["src/p9/init.csv"] = CSV,
				["src/p9/init.txt"] = "p9 text",
			})).toEqual({
				{
					name = "p1",
					class = "ModuleScript",
					Source = "p1 luau",
					children = { { name = "child", class = "ModuleScript", Source = "c" } },
				},
				{ name = "p2", class = "ModuleScript", Source = "p2 lua" },
				{ name = "p3", class = "Script", Source = "p3 server luau", RunContext = LEGACY },
				{ name = "p4", class = "Script", Source = "p4 server lua", RunContext = LEGACY },
				{ name = "p5", class = "LocalScript", Source = "p5 client luau" },
				{ name = "p6", class = "LocalScript", Source = "p6 client lua" },
				{ name = "p7", class = "Script", Source = "p7 plugin lua", RunContext = PLUGIN },
				{ name = "p8", class = "Script", Source = "p8 plugin luau", RunContext = PLUGIN },
				{
					name = "p9",
					class = "LocalizationTable",
					Contents = CONTENTS,
					children = { { name = "init", class = "StringValue", Value = "p9 text" } },
				},
			})
			expect(projects).toEqual({})
		end)

		it("takes a directory's project file before its init files, reading no directory meta (R1.4, R1.12)", function()
			expect(children({
				["src/pj/default.project.json"] = '{"tree": {"$className": "Configuration", "Kid": {"$path": "child.lua"}}}',
				["src/pj/default.project.jsonc"] = '{"tree": {"$className": "Model"}}',
				["src/pj/init.lua"] = "init",
				["src/pj/init.meta.json"] = '{"attributes": {"Dir": true}}',
				["src/pj/child.lua"] = "child",
				["src/pj/other.lua"] = "other",
				["src/pc/default.project.jsonc"] = '{"tree": {"$className": "Model"}}',
			})).toEqual({
				{ name = "pc", class = "Model" },
				{
					name = "pj",
					class = "Configuration",
					children = { { name = "Kid", class = "ModuleScript", Source = "child" } },
				},
			})
		end)

		it("keeps other files named init as children, each reading init.meta.json as its adjacent meta", function()
			local dir = { Dir = true }

			stubProjects()

			expect(children({
				["src/p10/init.txt"] = "t",
				["src/p10/init.json"] = "[1]",
				["src/p10/init.model.json"] = '{"className": "Configuration"}',
				["src/p10/init.toml"] = "a = 1",
				["src/p10/init.yaml"] = "a: 1",
				["src/p10/init.jsonc"] = "[2]",
				["src/p10/init.yml"] = "- 1",
				["src/p10/init.project.json"] = '{"tree": {"$className": "Configuration"}}',
				["src/p10/init.meta.json"] = '{"attributes": {"Dir": true}}',
				["src/p10/init.rbxm"] = RBXM,
				["src/p10/init.rbxmx"] = RBXMX,
			})).toEqual({
				{
					name = "p10",
					class = "Folder",
					Attributes = dir,
					children = {
						{ name = "init", class = "ModuleScript", Source = "return {1}", Attributes = dir },
						{ name = "init", class = "ModuleScript", Source = "return {2}", Attributes = dir },
						{ name = "init", class = "Configuration" },
						{ name = "init", class = "Project" },
						{ name = "init", class = "Model", model = "Model" },
						{ name = "init", class = "Model", model = "Model" },
						{ name = "init", class = "ModuleScript", Source = "return {\n\ta = 1,\n}", Attributes = dir },
						{ name = "init", class = "StringValue", Value = "t", Attributes = dir },
						{ name = "init", class = "ModuleScript", Source = "return {\n\ta = 1,\n}", Attributes = dir },
						{ name = "init", class = "ModuleScript", Source = "return {1}", Attributes = dir },
					},
				},
			})
			expect(projects).toEqual({ { path = "src/p10/init.project.json", name = "init" } })
		end)

		it("reads <dir>/<dirName>.meta.json inside the directory, drops its id, then applies init.meta.json", function()
			expect(children({
				["src/ia/init.server.lua"] = "ia",
				["src/ia/ia.meta.json"] = '{"id": "ia", "properties": {"Source": "from adjacent", "Disabled": true}, "attributes": {"A": 1}}',
				["src/ia/init.meta.json"] = '{"properties": {"Tags": ["t"]}}',
				["src/ib/init.lua"] = "ib",
				["src/ib/init.meta.json"] = '{"id": "ib", "attributes": {"B": 2}}',
				["src/ib/ib.meta.json"] = '{"attributes": {"A": 1}}',
				["src/ic/init.csv"] = CSV,
				["src/ic/ic.meta.json"] = '{"attributes": {"C": "adjacent"}}',
				["src/ic/init.meta.jsonc"] = '{"properties": {"Tags": ["c"]}}',
				["src/ia.meta.json"] = '{"attributes": {"Outside": true}}',
				["src/ie/init.lua"] = "ie",
				["src/ie/ie.meta.json"] = '{"id": "e1"}',
				["src/ie/init.meta.json"] = '{"id": "e2"}',
			})).toEqual({
				{
					name = "ia",
					class = "Script",
					Source = "from adjacent",
					RunContext = LEGACY,
					Disabled = true,
					Attributes = { A = 1 },
					Tags = { "t" },
				},
				{ name = "ib", class = "ModuleScript", Source = "ib", Attributes = { B = 2 }, id = "ib" },
				{
					name = "ic",
					class = "LocalizationTable",
					Contents = CONTENTS,
					Attributes = { C = "adjacent" },
					Tags = { "c" },
				},
				{ name = "ie", class = "ModuleScript", Source = "ie", id = "e2" },
			})
		end)

		it("refuses className in the directory meta of an init script or an init.csv", function()
			expect(refusal({
				["src/cs/init.server.lua"] = "x",
				["src/cs/init.meta.json"] = '{"className": "Folder"}',
			})).toEqual({ path = "src/cs/init.meta.json", message = FOLDER_ONLY })
			expect(refusal({ ["src/cs/init.csv"] = CSV, ["src/cs/init.meta.json"] = '{"className": "Folder"}' })).toEqual({
				path = "src/cs/init.meta.json",
				message = FOLDER_ONLY,
			})
		end)

		it("still finds init and meta files that ignore rules match (R4.2)", function()
			expect(children({
				["src/m/init.lua"] = "m",
				["src/m/child.lua"] = "c",
				["src/m.meta.json"] = META,
				["src/n.lua"] = "n",
				["src/n.meta.json"] = META,
				["src/m/m.meta.json"] = META,
				["src/f/init.meta.json"] = '{"className": "Model"}',
			}, { ignoreRules = { ignoreRule("**/init.lua"), ignoreRule("**/*.meta.json") } })).toEqual({
				{ name = "f", class = "Model" },
				{
					name = "m",
					class = "ModuleScript",
					Source = "m",
					Attributes = { M = true },
					children = { { name = "child", class = "ModuleScript", Source = "c" } },
				},
				{ name = "n", class = "ModuleScript", Source = "n", Attributes = { M = true } },
			})
		end)
	end)

	describe("meta files (R1.12)", function()
		it("reads adjacent meta for scripts, data modules, text and CSV, never models, projects or folders", function()
			local shared = { Shared = true }
			local meta = { M = true }

			stubProjects()

			expect(children({
				["src/sc.lua"] = "sc",
				["src/sc.meta.json"] = META,
				["src/js.json"] = "1",
				["src/js.meta.json"] = META,
				["src/jc.jsonc"] = "2",
				["src/jc.meta.jsonc"] = META,
				["src/tm.toml"] = "a = 1",
				["src/tm.meta.json"] = META,
				["src/ym.yaml"] = "a: 1",
				["src/ym.meta.json"] = META,
				["src/tx.txt"] = "t",
				["src/tx.meta.json"] = META,
				["src/cv.csv"] = CSV,
				["src/cv.meta.json"] = META,
				["src/md.model.json"] = '{"className": "Folder"}',
				["src/md.meta.json"] = META,
				["src/rm.rbxm"] = RBXM,
				["src/rm.meta.json"] = META,
				["src/rx.rbxmx"] = RBXMX,
				["src/rx.meta.json"] = META,
				["src/pj.project.json"] = '{"tree": {"$className": "Folder"}}',
				["src/pj.meta.json"] = META,
				["src/dr/a.lua"] = "a",
				["src/dr.meta.json"] = META,
				["src/foo.lua"] = "foo",
				["src/foo.server.lua"] = "foo server",
				["src/foo.txt"] = "foo text",
				["src/foo.model.json"] = '{"className": "Folder"}',
				["src/foo/x.lua"] = "x",
				["src/foo.meta.json"] = '{"attributes": {"Shared": true}}',
			})).toEqual({
				{ name = "cv", class = "LocalizationTable", Contents = CONTENTS, Attributes = meta },
				{ name = "dr", class = "Folder", children = { { name = "a", class = "ModuleScript", Source = "a" } } },
				{ name = "foo", class = "Folder", children = { { name = "x", class = "ModuleScript", Source = "x" } } },
				{ name = "foo", class = "ModuleScript", Source = "foo", Attributes = shared },
				{ name = "foo", class = "Folder" },
				{ name = "foo", class = "Script", Source = "foo server", RunContext = LEGACY, Attributes = shared },
				{ name = "foo", class = "StringValue", Value = "foo text", Attributes = shared },
				{ name = "jc", class = "ModuleScript", Source = "return 2", Attributes = meta },
				{ name = "js", class = "ModuleScript", Source = "return 1", Attributes = meta },
				{ name = "md", class = "Folder" },
				{ name = "pj", class = "Project" },
				{ name = "rm", class = "Model", model = "Model" },
				{ name = "rx", class = "Model", model = "Model" },
				{ name = "sc", class = "ModuleScript", Source = "sc", Attributes = meta },
				{ name = "tm", class = "ModuleScript", Source = "return {\n\ta = 1,\n}", Attributes = meta },
				{ name = "tx", class = "StringValue", Value = "t", Attributes = meta },
				{ name = "ym", class = "ModuleScript", Source = "return {\n\ta = 1,\n}", Attributes = meta },
			})
		end)
	end)

	describe("directories (R4)", function()
		it("lists children sorted by bytes and keeps duplicate names", function()
			expect(build({
				["src/B.lua"] = "B",
				["src/_.lua"] = "_",
				["src/a.lua"] = "a",
				["src/Ab.lua"] = "Ab",
				["src/ab.lua"] = "ab",
				["src/a-b.lua"] = "a-b",
				["src/a b.lua"] = "a b",
				["src/aaa.txt"] = "",
				["src/dup.lua"] = "dup module",
				["src/dup.server.lua"] = "dup server",
				["src/dupdir/x.lua"] = "x",
				["src/dupdir.lua"] = "dupdir",
				["src/empty/"] = "",
			})).toEqual({
				name = "src",
				class = "Folder",
				children = {
					{ name = "Ab", class = "ModuleScript", Source = "Ab" },
					{ name = "B", class = "ModuleScript", Source = "B" },
					{ name = "_", class = "ModuleScript", Source = "_" },
					{ name = "a b", class = "ModuleScript", Source = "a b" },
					{ name = "a-b", class = "ModuleScript", Source = "a-b" },
					{ name = "a", class = "ModuleScript", Source = "a" },
					{ name = "aaa", class = "StringValue", Value = "" },
					{ name = "ab", class = "ModuleScript", Source = "ab" },
					{ name = "dup", class = "ModuleScript", Source = "dup module" },
					{ name = "dup", class = "Script", Source = "dup server", RunContext = LEGACY },
					{
						name = "dupdir",
						class = "Folder",
						children = { { name = "x", class = "ModuleScript", Source = "x" } },
					},
					{ name = "dupdir", class = "ModuleScript", Source = "dupdir" },
					{ name = "empty", class = "Folder" },
				},
			})
		end)
	end)

	describe("sync rules (R2.8)", function()
		it("lets the first matching user rule decide over every default rule, with every use value", function()
			stubProjects()

			expect(children({
				["src/cs.loc"] = CSV,
				["src/jm.jmod"] = '{"className": "Configuration"}',
				["src/js.dat"] = '{"k": "v"}',
				["src/tm.cfg"] = "k = 'v'",
				["src/tx.note"] = "note",
				["src/ym.conf"] = "k: v",
				["src/ig.lua"] = "ignored",
				["src/pj.proj"] = '{"tree": {"$className": "Folder"}}',
				["src/rx.xmodel"] = RBXMX,
				["src/rb.bmodel"] = RBXM,
				["src/cfg.data.txt"] = '{"a": 1}',
				["src/w.weird"] = "weird",
				["src/keep.lua"] = "keep",
				["src/other.lua"] = "other",
				["src/first.thing"] = "first",
				["src/folder.lua/x.txt"] = "x",
				["src/dir/a.lua"] = "a",
				["src/tx.meta.json"] = '{"attributes": {"M": true}}',
				["src/idir/init.lua"] = "init",
				["src/idir/child.lua"] = "child",
			}, {
				syncRules = {
					syncRule("**/*.loc", "csv"),
					syncRule("**/*.jmod", "jsonModel"),
					syncRule("**/*.dat", "json"),
					syncRule("**/*.cfg", "toml"),
					syncRule("**/*.note", "text"),
					syncRule("**/*.conf", "yaml"),
					syncRule("**/*.proj", "project"),
					syncRule("src/ig.lua", "ignore"),
					syncRule("**/*.xmodel", "rbxmx"),
					syncRule("**/*.bmodel", "rbxm"),
					syncRule("**/*.data.txt", "json", { suffix = ".data.txt" }),
					syncRule("**/*.weird", "text", { suffix = ".nope" }),
					syncRule("**/*.lua", "text", { exclude = "**/keep.lua" }),
					syncRule("**/*.thing", "text"),
					syncRule("**/first.thing", "json"),
					syncRule("src/folder.lua", "text"),
					syncRule("src/dir", "ignore"),
				},
			})).toEqual({
				{ name = "cfg", class = "ModuleScript", Source = "return {\n\ta = 1,\n}" },
				{ name = "cs", class = "LocalizationTable", Contents = CONTENTS },
				{ name = "dir", class = "Folder", children = { { name = "a", class = "StringValue", Value = "a" } } },
				{ name = "first", class = "StringValue", Value = "first" },
				{
					name = "folder.lua",
					class = "Folder",
					children = { { name = "x", class = "StringValue", Value = "x" } },
				},
				{
					name = "idir",
					class = "ModuleScript",
					Source = "init",
					children = { { name = "child", class = "StringValue", Value = "child" } },
				},
				{ name = "jm", class = "Configuration" },
				{ name = "js", class = "ModuleScript", Source = 'return {\n\tk = "v",\n}' },
				{ name = "keep", class = "ModuleScript", Source = "keep" },
				{ name = "other", class = "StringValue", Value = "other" },
				{ name = "pj", class = "Project" },
				{ name = "rb", class = "Model", model = "Model" },
				{ name = "rx", class = "Model", model = "Model" },
				{ name = "tm", class = "ModuleScript", Source = 'return {\n\tk = "v",\n}' },
				{ name = "tx", class = "StringValue", Value = "note", Attributes = { M = true } },
				{ name = "w.weird", class = "StringValue", Value = "weird" },
				{ name = "ym", class = "ModuleScript", Source = 'return {\n\tk = "v",\n}' },
			})
			expect(projects).toEqual({ { path = "src/pj.proj", name = "pj" } })
		end)

		it("never reads an init file through a sync rule, nor makes it a child", function()
			expect(build({
				["src/idir/init.lua"] = "init",
				["src/idir/child.lua"] = "child",
				["src/init.lua"] = "loose",
			}, { syncRules = { syncRule("**/init.lua", "text") } })).toEqual({
				name = "src",
				class = "ModuleScript",
				Source = "loose",
				children = {
					{
						name = "idir",
						class = "ModuleScript",
						Source = "init",
						children = { { name = "child", class = "ModuleScript", Source = "child" } },
					},
				},
			})
		end)
	end)

	describe("ignore rules (R4.4)", function()
		it("leaves the contents of a folder out and keeps the folder", function()
			expect(children({
				["src/sub/a.lua"] = "a",
				["src/sub/inner/b.lua"] = "b",
				["src/top.lua"] = "t",
			}, { ignoreRules = { ignoreRule("src/sub/**") } })).toEqual({
				{ name = "sub", class = "Folder" },
				{ name = "top", class = "ModuleScript", Source = "t" },
			})
		end)

		it("never lists an ignored folder, so a negation cannot bring anything below it back", function()
			expect(children({
				["src/ignored/keep.lua"] = "k",
				["src/ignored/x.lua"] = "x",
				["src/top.lua"] = "t",
			}, { ignoreRules = { ignoreRule("src/ignored"), ignoreRule("!src/ignored/keep.lua") } })).toEqual({
				{ name = "top", class = "ModuleScript", Source = "t" },
			})
		end)

		it("keeps what a later negated rule matches", function()
			expect(children({
				["src/drop.txt"] = "d",
				["src/keep.txt"] = "k",
				["src/n/keep.txt"] = "k2",
			}, { ignoreRules = { ignoreRule("**/*.txt"), ignoreRule("!**/keep.txt") } })).toEqual({
				{ name = "keep", class = "StringValue", Value = "k" },
				{ name = "n", class = "Folder", children = { { name = "keep", class = "StringValue", Value = "k2" } } },
			})
		end)

		it("lets the last matching rule decide", function()
			expect(children({
				["src/a.txt"] = "a",
				["src/b.txt"] = "b",
			}, { ignoreRules = { ignoreRule("!**/a.txt"), ignoreRule("**/*.txt") } })).toEqual({})
		end)
	end)

	describe("SnapshotPackage", function()
		it("names a plain package folder after the package", function()
			local result = PluginSnapshotService:SnapshotPackage(VirtualFileSystem.fromFiles({ ["x.lua"] = "x" }), "b")

			expect(view(result.value)).toEqual({
				name = "b",
				class = "Folder",
				children = { { name = "x", class = "ModuleScript", Source = "x" } },
			})
		end)

		it("names an init package folder after the package", function()
			local fileSystem = VirtualFileSystem.fromFiles({ ["init.lua"] = "c", ["y.lua"] = "y" })
			local result = PluginSnapshotService:SnapshotPackage(fileSystem, "c")

			expect(view(result.value)).toEqual({
				name = "c",
				class = "ModuleScript",
				Source = "c",
				children = { { name = "y", class = "ModuleScript", Source = "y" } },
			})
		end)

		it("names a project package after the package, whatever the project names it", function()
			local fileSystem = VirtualFileSystem.fromFiles({ ["default.project.json"] = "{}", ["x.lua"] = "x" })

			stubProjects("Other", "Model")

			expect(view(PluginSnapshotService:SnapshotPackage(fileSystem, "pkg").value)).toEqual({
				name = "pkg",
				class = "Model",
			})
			expect(projects).toEqual({ { path = "default.project.json", name = "pkg" } })
		end)

		it("refuses a package whose root is a DataModel, which Studio's loader drops whole", function()
			local fileSystem =
				VirtualFileSystem.fromFiles({ ["init.meta.json"] = '{"className": "DataModel"}', ["x.lua"] = "x" })

			expect(PluginSnapshotService:SnapshotPackage(fileSystem, "pkg")).toEqual({
				ok = false,
				error = { path = "", message = "Class DataModel cannot be created by a plugin" },
			})
		end)

		it("refuses the first class a plugin cannot create, outside any DataModel it leaves out", function()
			local outside =
				VirtualFileSystem.fromFiles({ ["p.model.json"] = '{"className": "NotAClass"}', ["x.lua"] = "x" })
			local inside = VirtualFileSystem.fromFiles({
				["d/init.meta.json"] = '{"className": "DataModel"}',
				["d/p.model.json"] = '{"className": "NotAClass"}',
				["x.lua"] = "x",
			})

			expect(PluginSnapshotService:SnapshotPackage(outside, "pkg")).toEqual({
				ok = false,
				error = { path = "p.model.json", message = "Class NotAClass cannot be created by a plugin" },
			})
			expect(view(PluginSnapshotService:SnapshotPackage(inside, "pkg").value)).toEqual({
				name = "pkg",
				class = "Folder",
				children = { { name = "x", class = "ModuleScript", Source = "x" } },
			})
		end)

		it("refuses a class a plugin cannot create that takes over a loaded model, destroying the model", function()
			holdLoadedModels()

			local fileSystem = VirtualFileSystem.fromFiles({
				["default.project.json"] = '{"tree": {"$className": "NotAClass", "$path": "m.rbxm"}}',
				["m.rbxm"] = FOLDER_RBXM,
			})

			expect(PluginSnapshotService:SnapshotPackage(fileSystem, "pkg")).toEqual({
				ok = false,
				error = { path = "default.project.json", message = "Class NotAClass cannot be created by a plugin" },
			})
			expect(#loaded).toBe(1)
			expect(isDestroyed(loaded[1])).toBe(true)
		end)

		it("refuses a package that builds no instance", function()
			local fileSystem = VirtualFileSystem.fromFiles({ ["default.project.json"] = "{}" })

			PluginSnapshotService.SnapshotProject = function()
				return { ok = true }
			end

			expect(PluginSnapshotService:SnapshotPackage(fileSystem, "pkg")).toEqual({
				ok = false,
				error = { path = "", message = "the package builds no instance" },
			})
		end)
	end)
end)
