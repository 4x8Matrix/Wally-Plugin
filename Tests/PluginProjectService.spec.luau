local EncodingService = game:GetService("EncodingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local PluginModelService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginModelService)
local PluginProjectService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginProjectService)
local PluginPropertyService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginPropertyService)
local PluginSnapshotService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginSnapshotService)
local VirtualFileSystem = require(ReplicatedStorage.WallyPlugin.PluginClasses.VirtualFileSystem)

local fixture = require(ReplicatedStorage.Tests.Fixtures.modelFiles)

local RBXM = buffer.tostring(EncodingService:Base64Decode(buffer.fromstring(fixture.rbxm)))
local PROJECT = "default.project.json"
local FOLDER = '{"$className": "Folder"}'
local LEGACY = Enum.RunContext.Legacy
local SERVER = Enum.RunContext.Server
local CLIENT = Enum.RunContext.Client
local NOT_A_DIRECTORY = "Not a directory (os error 20)"
local CYCLE = "the project reaches its own file through $path, which overflows Rojo 7.7.1's stack"
local DROPPED = '%s: the DataModel "%s" is left out, as Studio\'s loader drops a DataModel below other instances'
	.. " with everything under it"
local NO_DIRECTORY_NAME = "Could not extract directory name (Rojo 7.7.1 crashes on a $path ending in `..`)"
local RESERVED = "Keys starting with '$' are reserved by Rojo to ensure forward compatibility. "
	.. "This project uses the key '%s', which should be renamed."
local MISSING_INFORMATION = 'Instance "%s" is missing some required information. One of the following must be true: '
	.. "$className must be set to the name of a Roblox class; $path must be set to a path of an instance; "
	.. "the instance must be a known service, like ReplicatedStorage"
local TARGET_FILES = {
	["a.server.lua"] = "s",
	["a.meta.json"] = '{"properties": {"Disabled": true}}',
	["t.txt"] = "t",
	["j.json"] = "[1]",
	["m.model.json"] = '{"className": "Configuration", "children": [{"className": "Folder"}]}',
	["l.csv"] = "Key,Source\nk,v\n",
	["x.toml"] = "a = 1",
	["y.yaml"] = "a: 1",
	["README.md"] = "#",
	["a.skip"] = "x",
	["e.model.json"] = "  ",
	["init/init.lua"] = "i",
	["plain/a.lua"] = "a",
	["plain/init.meta.json"] = '{"attributes": {"D": true}}',
	["initdir/init.server.lua"] = "i",
	["initdir/b.lua"] = "b",
	["initdir/initdir.meta.json"] = '{"attributes": {"S": true}}',
	["initdir/init.meta.json"] = '{"properties": {"Disabled": true}}',
	["projdir/default.project.json"] = '{"name": "Named", "tree": {"$className": "Model", "kid": {"$path": "k.lua"}}}',
	["projdir/k.lua"] = "k",
	["projdir/other.lua"] = "o",
	["p.project.json"] = '{"name": "Named", "tree": {"$className": "Configuration"}}',
	["q.project.json"] = '{"tree": {"$path": {"optional": "nope"}}}',
}
local MADE_NOTHING = {
	{ "a missing path", "nope" },
	{ "an unrecognised file", "README.md" },
	{ "an init file reached straight", "init/init.lua" },
	{ "a file a sync rule ignores", "a.skip" },
	{ "an empty model file", "e.model.json" },
	{ "a nested project whose optional tree is missing", "q.project.json" },
}
local MADE_INSTANCE = {
	{
		"a script with its meta",
		"a.server.lua",
		{ class = "Script", Source = "s", RunContext = LEGACY, Disabled = true },
	},
	{ "a text file", "t.txt", { class = "StringValue", Value = "t" } },
	{ "a JSON module", "j.json", { class = "ModuleScript", Source = "return {1}" } },
	{
		"a JSON model",
		"m.model.json",
		{ class = "Configuration", children = { { name = "Folder", class = "Folder" } } },
	},
	{
		"a CSV file",
		"l.csv",
		{ class = "LocalizationTable", Contents = '[{"key":"k","source":"v","values":{}}]' },
	},
	{ "a TOML module", "x.toml", { class = "ModuleScript", Source = "return {\n\ta = 1,\n}" } },
	{ "a YAML module", "y.yaml", { class = "ModuleScript", Source = "return {\n\ta = 1,\n}" } },
	{
		"an init directory",
		"initdir",
		{
			class = "Script",
			Source = "i",
			RunContext = LEGACY,
			Disabled = true,
			Attributes = { S = true },
			children = { { name = "b", class = "ModuleScript", Source = "b" } },
		},
	},
	{
		"a directory holding a project",
		"projdir",
		{ class = "Model", children = { { name = "kid", class = "ModuleScript", Source = "k" } } },
	},
	{ "a project file", "p.project.json", { class = "Configuration" } },
}

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local modelReporter = PluginModelService.Reporter
local projectReporter = PluginProjectService.Reporter
local propertyReporter = PluginPropertyService.Reporter
local snapshotBinaryModel = PluginModelService.SnapshotBinaryModel
local warnings = {}
local loaded = {}

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

local function snapshotPackage(files: { [string]: string }): any
	local result = PluginSnapshotService:SnapshotPackage(VirtualFileSystem.fromFiles(files), "pkg")

	if result.ok then
		holdModels(result.value)
	end

	return result
end

local function build(files: { [string]: string }): any
	local result = snapshotPackage(files)

	expect(result.error).toBe(nil)

	return view(result.value)
end

local function refusal(files: { [string]: string }): any
	local result = snapshotPackage(files)

	expect(result.ok).toBe(false)

	return result.error
end

local function projectTree(files: { [string]: string }): any
	local fileSystem = VirtualFileSystem.fromFiles(files)
	local context = PluginSnapshotService:DefaultContext()
	local result = PluginProjectService:SnapshotProject(fileSystem, PROJECT, context, "pkg", function(...)
		return PluginSnapshotService:SnapshotPath(...)
	end)

	expect(result.error).toBe(nil)
	holdModels(result.value)

	return view(result.value)
end

local function project(tree: string, fields: string?, files: { [string]: string }?): { [string]: string }
	local projectFiles = table.clone(files or {})

	projectFiles[PROJECT] = `\{"tree": {tree}{if fields then ", " .. fields else ""}}`

	return projectFiles
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

local function uncreatable(className: string): any
	return { path = PROJECT, message = `Class {className} cannot be created by a plugin` }
end

local function missingInformation(name: string): any
	return { path = PROJECT, message = string.format(MISSING_INFORMATION, name) }
end

describe("PluginProjectService", function()
	beforeEach(function()
		local reporter = {
			Warn = function(_, message: string)
				table.insert(warnings, message)
			end,
		}

		table.clear(warnings)

		PluginModelService.Reporter = reporter
		PluginProjectService.Reporter = reporter
		PluginPropertyService.Reporter = reporter
	end)

	afterEach(function()
		PluginModelService.Reporter = modelReporter
		PluginProjectService.Reporter = projectReporter
		PluginPropertyService.Reporter = propertyReporter
		PluginModelService.SnapshotBinaryModel = snapshotBinaryModel

		for _, model in loaded do
			model:Destroy()
		end

		table.clear(loaded)
	end)

	describe("project files (R1.13, R2.1)", function()
		it("builds the package's own project, named after the package", function()
			expect(build(project('{"$className": "Model"}', '"name": "Other"'))).toEqual({
				name = "pkg",
				class = "Model",
			})
		end)

		it("refuses a project file that does not read, naming the file, nested ones included", function()
			local invalid = refusal({ [PROJECT] = "{" })
			local unknownField = refusal(project(FOLDER, '"foo": 1'))
			local nested = refusal(project('{"$className": "Folder", "k": {"$path": "x.project.json"}}', nil, {
				["x.project.json"] = '{"tree": {"$className": "Folder"}, "servePort": -1}',
			}))

			expect(invalid.path).toBe(PROJECT)
			expect(invalid.message).toMatch("^File was not a valid Rojo project: ")
			expect(unknownField).toEqual({
				path = PROJECT,
				message = "File was not a valid Rojo project: unknown field `foo`, expected one of `$schema`, `name`, "
					.. "`tree`, `servePort`, `servePlaceIds`, `blockedPlaceIds`, `placeId`, `gameId`, `serveAddress`, "
					.. "`serveAllowedHosts`, `emitLegacyScripts`, `globIgnorePaths`, `syncbackRules`, `syncRules`",
			})
			expect(nested).toEqual({
				path = "x.project.json",
				message = "File was not a valid Rojo project: invalid value: integer `-1`, expected u16",
			})
		end)

		it("refuses a project path that is a directory", function()
			expect(refusal({ ["default.project.json/x.lua"] = "x" })).toEqual({
				path = PROJECT,
				message = "File was not a valid Rojo project: is a directory",
			})
		end)

		it("builds a `$` key at any depth as a child, warning for it (dollar-child, n-child-nested-dollar)", function()
			local tree =
				'{"$className": "Folder", "$description": {"$className": "Folder", "$x": {"$className": "Folder"}}}'

			expect(build(project(tree))).toEqual({
				name = "pkg",
				class = "Folder",
				children = {
					{ name = "$description", class = "Folder", children = { { name = "$x", class = "Folder" } } },
				},
			})
			expect(warnings).toEqual({ string.format(RESERVED, "$description"), string.format(RESERVED, "$x") })
		end)

		it("warns for `$` keys in nodes it never builds, as Rojo checks names when it loads the file", function()
			local tree = '{"$className": "Folder", "$a": {"$className": "Folder"}, '
				.. '"gone": {"$path": {"optional": "nope"}, "$b": {"$className": "Folder"}}}'

			expect(build(project(tree))).toEqual({
				name = "pkg",
				class = "Folder",
				children = { { name = "$a", class = "Folder" } },
			})
			expect(warnings).toEqual({ string.format(RESERVED, "$a"), string.format(RESERVED, "$b") })
		end)
	end)

	describe("class choice (R2.3)", function()
		it("takes $className, and the class of what $path made (c1-class, c2-path)", function()
			expect(build(project('{"$className": "Model"}'))).toEqual({ name = "pkg", class = "Model" })
			expect(build(project('{"$path": "a.lua"}', nil, { ["a.lua"] = "a" }))).toEqual({
				name = "pkg",
				class = "ModuleScript",
				Source = "a",
			})
		end)

		it(
			"takes $className over a Folder path and refuses any other, even the same class (c6-folder, c6-same)",
			function()
				expect(build(project('{"$className": "Model", "$path": "dir"}', nil, { ["dir/a.lua"] = "a" }))).toEqual({
					name = "pkg",
					class = "Model",
					children = { { name = "a", class = "ModuleScript", Source = "a" } },
				})
				expect(refusal(project('{"$className": "ModuleScript", "$path": "a.lua"}', nil, { ["a.lua"] = "a" }))).toEqual({
					path = PROJECT,
					message = 'ClassName for Instance "pkg" was specified in both the project file (as "ModuleScript") and '
						.. 'from the filesystem (as "ModuleScript"). If $className and $path are both set, $path must refer '
						.. "to a Folder. Filesystem path: a.lua",
				})
			end
		)

		it(
			"omits a node whose optional path is missing, children and all, unless a class is set (c7-optional)",
			function()
				local tree = '{"$className": "Folder", "gone": {"$path": {"optional": "nope"}, "kid": {"$className": "Folder"}}, '
					.. '"kept": {"$className": "Model", "$path": {"optional": "nope"}}}'

				expect(build(project(tree))).toEqual({
					name = "pkg",
					class = "Folder",
					children = { { name = "kept", class = "Model" } },
				})
			end
		)

		it("refuses a node with no class from anything (c8-required, c9-absent, c-root-noinfer)", function()
			expect(refusal(project('{"$className": "Folder", "k": {"$path": "nope"}}'))).toEqual({
				path = PROJECT,
				message = '$path "nope" could not be turned into an instance',
			})
			expect(refusal(project('{"$className": "Folder", "k": {}}'))).toEqual(missingInformation("k"))
			expect(refusal(project("{}"))).toEqual(missingInformation("pkg"))
		end)

		it("infers StarterPlayer's two script containers, and nothing else under it (c3-infer, c3-noinfer)", function()
			local tree = '{"$className": "StarterPlayer", "StarterPlayerScripts": {}, "StarterCharacterScripts": {}}'

			expect(projectTree(project(tree))).toEqual({
				name = "pkg",
				class = "StarterPlayer",
				children = {
					{ name = "StarterCharacterScripts", class = "StarterCharacterScripts" },
					{ name = "StarterPlayerScripts", class = "StarterPlayerScripts" },
				},
			})
			expect(refusal(project(tree))).toEqual(uncreatable("StarterPlayer"))
			expect(refusal(project('{"$className": "StarterPlayer", "Other": {}}'))).toEqual(
				missingInformation("Other")
			)
		end)

		it("prefers $className and a non-Folder path class to an inferred one (c4, c5, c6-infer)", function()
			local function child(node: string): string
				return `\{"$className": "StarterPlayer", "StarterPlayerScripts": {node}}`
			end

			local function under(container: { [string]: any }): any
				return { name = "pkg", class = "StarterPlayer", children = { container } }
			end

			local files = { ["dir/a.lua"] = "a", ["a.lua"] = "a" }
			local moduleA = { name = "a", class = "ModuleScript", Source = "a" }

			expect(projectTree(project(child(FOLDER), nil, files))).toEqual(
				under({ name = "StarterPlayerScripts", class = "Folder" })
			)
			expect(projectTree(project(child('{"$path": "dir"}'), nil, files))).toEqual(
				under({ name = "StarterPlayerScripts", class = "StarterPlayerScripts", children = { moduleA } })
			)
			expect(projectTree(project(child('{"$path": "a.lua"}'), nil, files))).toEqual(
				under({ name = "StarterPlayerScripts", class = "ModuleScript", Source = "a" })
			)
			expect(projectTree(project(child('{"$className": "Model", "$path": "dir"}'), nil, files))).toEqual(
				under({ name = "StarterPlayerScripts", class = "Model", children = { moduleA } })
			)
			expect(refusal(project(child(FOLDER), nil, files))).toEqual(uncreatable("StarterPlayer"))
		end)

		it("infers services under a DataModel, and refuses a package rooted in one (c-dm, g-root)", function()
			local tree = '{"$className": "DataModel", "ReplicatedStorage": {"Main": {"$path": "a.lua"}}, '
				.. '"HttpService": {}, "Workspace": {"Terrain": {}}, "StarterPlayer": {"StarterPlayerScripts": {}}}'
			local files = project(tree, nil, { ["a.lua"] = "a" })

			expect(projectTree(files)).toEqual({
				name = "pkg",
				class = "DataModel",
				children = {
					{ name = "HttpService", class = "HttpService" },
					{
						name = "ReplicatedStorage",
						class = "ReplicatedStorage",
						children = { { name = "Main", class = "ModuleScript", Source = "a" } },
					},
					{
						name = "StarterPlayer",
						class = "StarterPlayer",
						children = { { name = "StarterPlayerScripts", class = "StarterPlayerScripts" } },
					},
					{ name = "Workspace", class = "Workspace", children = { { name = "Terrain", class = "Terrain" } } },
				},
			})
			expect(refusal(files)).toEqual(uncreatable("DataModel"))
			expect(refusal(project('{"$className": "DataModel", "NotAService": {}}'))).toEqual(
				missingInformation("NotAService")
			)
			expect(projectTree(project('{"$className": "DataModel", "ReplicatedStorage": {"$path": "a.lua"}}', nil, {
				["a.lua"] = "a",
			}))).toEqual({
				name = "pkg",
				class = "DataModel",
				children = { { name = "ReplicatedStorage", class = "ModuleScript", Source = "a" } },
			})
		end)

		it("infers Terrain under Workspace only, and nothing under other classes (c-ws-*, c-folder-noinfer)", function()
			local terrain = '{"$className": "Workspace", "Other": {"$className": "Folder"}, "Terrain": {}}'

			expect(projectTree(project(terrain))).toEqual({
				name = "pkg",
				class = "Workspace",
				children = { { name = "Other", class = "Folder" }, { name = "Terrain", class = "Terrain" } },
			})
			expect(refusal(project(terrain))).toEqual(uncreatable("Workspace"))
			expect(refusal(project('{"$className": "Workspace", "Camera": {}}'))).toEqual(missingInformation("Camera"))
			expect(refusal(project('{"$className": "Folder", "ReplicatedStorage": {}}'))).toEqual(
				missingInformation("ReplicatedStorage")
			)
		end)

		it("infers by the parent's final class, as Rojo's infer_class_name does", function()
			expect(PluginProjectService:InferClassName("ReplicatedStorage", "DataModel")).toBe("ReplicatedStorage")
			expect(PluginProjectService:InferClassName("Workspace", "DataModel")).toBe("Workspace")
			expect(PluginProjectService:InferClassName("Folder", "DataModel")).toBe(nil)
			expect(PluginProjectService:InferClassName("StarterPlayerScripts", "StarterPlayer")).toBe(
				"StarterPlayerScripts"
			)
			expect(PluginProjectService:InferClassName("StarterCharacterScripts", "StarterPlayer")).toBe(
				"StarterCharacterScripts"
			)
			expect(PluginProjectService:InferClassName("Terrain", "Workspace")).toBe("Terrain")
			expect(PluginProjectService:InferClassName("Terrain", "Model")).toBe(nil)
			expect(PluginProjectService:InferClassName("ReplicatedStorage", nil)).toBe(nil)
		end)
	end)

	describe("$path targets (R2.4)", function()
		local function target(path: string, node: string?): { [string]: string }
			local tree = `\{"$className": "Folder", "Node": {node or `\{"$path": "{path}"}`}}`

			return project(tree, '"syncRules": [{"pattern": "*.skip", "use": "ignore"}]', TARGET_FILES)
		end

		for _, case in MADE_NOTHING do
			it(`makes nothing from {case[1]}, which a class or an optional path settles (t-*)`, function()
				local path = case[2]

				expect(refusal(target(path))).toEqual({
					path = PROJECT,
					message = `$path "{path}" could not be turned into an instance`,
				})
				expect(build(target(path, `\{"$path": \{"optional": "{path}"}}`))).toEqual({
					name = "pkg",
					class = "Folder",
				})
				expect(build(target(path, `\{"$className": "Folder", "$path": "{path}"}`))).toEqual({
					name = "pkg",
					class = "Folder",
					children = { { name = "Node", class = "Folder" } },
				})
			end)
		end

		for _, case in MADE_INSTANCE do
			it(`makes {case[2]}'s instance, named by the key, and refuses it under $className (t-*)`, function()
				local expected = table.clone(case[3])

				expected.name = "Node"

				expect(build(target(case[2]))).toEqual({ name = "pkg", class = "Folder", children = { expected } })
				expect(build(target(case[2], `\{"$path": \{"optional": "{case[2]}"}}`))).toEqual({
					name = "pkg",
					class = "Folder",
					children = { expected },
				})
				expect(refusal(target(case[2], `\{"$className": "Folder", "$path": "{case[2]}"}`)).message).toMatch(
					`^ClassName for Instance "Node" was specified in both the project file %(as "Folder"%) and from `
						.. `the filesystem %(as "{case[3].class}"%)`
				)
			end)
		end

		it("makes a plain directory a Folder with its directory meta, under $className too (t-plaindir)", function()
			local expected = {
				name = "Node",
				class = "Folder",
				Attributes = { D = true },
				children = { { name = "a", class = "ModuleScript", Source = "a" } },
			}

			expect(build(target("plain")).children).toEqual({ expected })
			expect(build(target("plain", '{"$className": "Folder", "$path": "plain"}')).children).toEqual({ expected })
		end)

		it("keeps the model a binary model file loaded (t-rbxm)", function()
			expect(build(project('{"$className": "Folder", "Node": {"$path": "m.rbxm"}}', nil, { ["m.rbxm"] = RBXM }))).toEqual({
				name = "pkg",
				class = "Folder",
				children = { { name = "Node", class = "Model", model = "Model" } },
			})
		end)

		it("finds nothing outside the zip and never applies ignore rules to the target itself", function()
			local outside = '{"$className": "Folder", "Node": {"$className": "Folder", "$path": "../outside"}, '
				.. '"Gone": {"$path": {"optional": "../outside"}}}'
			local ignored = project(
				'{"$className": "Folder", "Node": {"$path": "a.lua"}, "Dir": {"$path": "src"}}',
				'"globIgnorePaths": ["a.lua", "src/b.lua"]',
				{ ["a.lua"] = "a", ["src/b.lua"] = "b", ["src/c.lua"] = "c" }
			)

			expect(build(project(outside))).toEqual({
				name = "pkg",
				class = "Folder",
				children = { { name = "Node", class = "Folder" } },
			})
			expect(build(ignored).children).toEqual({
				{ name = "Dir", class = "Folder", children = { { name = "c", class = "ModuleScript", Source = "c" } } },
				{ name = "Node", class = "ModuleScript", Source = "a" },
			})
		end)

		it(
			"refuses a $path running through a file, optional or not, where a missing step only finds nothing",
			function()
				local files = { ["a.lua"] = "a", ["b.lua"] = "b" }

				for _, path in { "a.lua/b", "a.lua/", "a.lua/../b.lua" } do
					expect(refusal(project(`\{"$className": "Folder", "k": \{"$path": "{path}"}}`, nil, files))).toEqual({
						path = PROJECT,
						message = `failed to query metadata of file \`{path}\`: {NOT_A_DIRECTORY}`,
					})
				end

				expect(
					refusal(project('{"$className": "Folder", "k": {"$path": {"optional": "a.lua/x"}}}', nil, files))
				).toEqual({
					path = PROJECT,
					message = `failed to query metadata of file \`a.lua/x\`: {NOT_A_DIRECTORY}`,
				})
				expect(
					build(
						project(
							'{"$className": "Folder", "k": {"$className": "Folder", "$path": "nope/../a.lua"}}',
							nil,
							files
						)
					)
				).toEqual({
					name = "pkg",
					class = "Folder",
					children = { { name = "k", class = "Folder" } },
				})
			end
		)

		it(
			"follows `..` inside the zip, reading the meta beside the file it reaches (dotdot-in, dotdot-file)",
			function()
				expect(build(project('{"$path": "src/../lib"}', nil, { ["src/x.lua"] = "x", ["lib/y.lua"] = "y" }))).toEqual({
					name = "pkg",
					class = "Folder",
					children = { { name = "y", class = "ModuleScript", Source = "y" } },
				})
				expect(build(project('{"$className": "Folder", "k": {"$path": "src/../a.server.lua"}}', nil, {
					["src/x.lua"] = "x",
					["a.server.lua"] = "s",
					["a.meta.json"] = '{"properties": {"Disabled": true}}',
				})).children).toEqual({
					{ name = "k", class = "Script", Source = "s", RunContext = LEGACY, Disabled = true },
				})
			end
		)

		it("names a directory target as Rust does, past `.` and a trailing `/` (dot-init, slash-init)", function()
			local files =
				{ ["src/init.lua"] = "i", ["src/src.meta.json"] = '{"attributes": {"S": true}}', ["src/b.lua"] = "b" }
			local expected = {
				name = "pkg",
				class = "ModuleScript",
				Source = "i",
				Attributes = { S = true },
				children = { { name = "b", class = "ModuleScript", Source = "b" } },
			}

			expect(build(project('{"$path": "src/."}', nil, files))).toEqual(expected)
			expect(build(project('{"$path": "src/"}', nil, files))).toEqual(expected)
		end)

		it("refuses a $path ending in `..`, which crashes Rojo (nested-dotdot, path-mid)", function()
			expect(refusal(project('{"$path": "./src/./lib/.."}', nil, { ["src/lib/a.lua"] = "a" }))).toEqual({
				path = PROJECT,
				message = NO_DIRECTORY_NAME,
			})
			expect(refusal(project('{"$path": "src"}', nil, {
				["src/x.project.json"] = '{"tree": {"$path": ".."}}',
				["src/a.lua"] = "a",
			}))).toEqual({ path = "src/x.project.json", message = NO_DIRECTORY_NAME })
		end)

		it("keeps the path as written for rules, as Rojo's strip_prefix trims only its ends (path-*)", function()
			local files = { ["src/a.lua"] = "a", ["src/b.txt"] = "b", ["src/lib/c.lua"] = "c", ["src/lib/d.txt"] = "d" }
			local fields = '"syncRules": [{"pattern": "src/*.txt", "use": "moduleScript"}, '
				.. '{"pattern": "src/lib/d.txt", "use": "moduleScript"}], "globIgnorePaths": ["src/a.lua", "src/lib/c.lua"]'
			local applied = {
				{ name = "b", class = "ModuleScript", Source = "b" },
				{ name = "lib", class = "Folder", children = { { name = "d", class = "ModuleScript", Source = "d" } } },
			}
			local unapplied = {
				{ name = "a", class = "ModuleScript", Source = "a" },
				{ name = "b", class = "ModuleScript", Source = "b" },
				{
					name = "lib",
					class = "Folder",
					children = {
						{ name = "c", class = "ModuleScript", Source = "c" },
						{ name = "d", class = "ModuleScript", Source = "d" },
					},
				},
			}

			for _, path in { "src", "./src", "src/", ".//src" } do
				expect({ path, build(project(`\{"$path": "{path}"}`, fields, files)).children }).toEqual({
					path,
					applied,
				})
			end

			for _, path in { "src/.", "src//" } do
				expect({ path, build(project(`\{"$path": "{path}"}`, fields, files)).children }).toEqual({
					path,
					unapplied,
				})
			end
		end)
	end)

	describe("merging (R2.5)", function()
		it(
			"names the instance by its key and lets $properties overwrite the file's, with Name dropped (m-merge)",
			function()
				local tree =
					'{"$className": "Folder", "Main": {"$path": "t.txt", "$properties": {"Value": "node", "Name": "X"}}}'

				expect(build(project(tree, nil, { ["t.txt"] = "file" })).children).toEqual({
					{ name = "Main", class = "StringValue", Value = "node" },
				})
				expect(warnings).toEqual({ "Property 'Name' cannot be set manually, ignoring (StringValue.Name)" })
			end
		)

		it("lets a non-empty $attributes replace every attribute, from meta or $properties alike (m-attrs)", function()
			local tree = '{"$className": "Folder", "A": {"$path": "t.txt", "$attributes": {"N": 1}}, "B": {"$path": "t.txt"}, '
				.. '"C": {"$className": "Folder", "$properties": {"Attributes": {"P": {"Float64": 1}}}, "$attributes": {"N": 2}}, '
				.. '"D": {"$className": "Folder", "$properties": {"Attributes": {"P": {"Float64": 1}}}, "$attributes": {}}}'
			local files = { ["t.txt"] = "file", ["t.meta.json"] = '{"attributes": {"M": true}}' }

			expect(build(project(tree, nil, files)).children).toEqual({
				{ name = "A", class = "StringValue", Value = "file", Attributes = { N = 1 } },
				{ name = "B", class = "StringValue", Value = "file", Attributes = { M = true } },
				{ name = "C", class = "Folder", Attributes = { N = 2 } },
				{ name = "D", class = "Folder", Attributes = { P = 1 } },
			})
		end)

		it("puts the file's children first and the node's after, by key, never merging names (m-children)", function()
			local tree = '{"$path": "src", "c": {"$className": "Folder"}, "a": {"$className": "Folder"}, '
				.. '"b.lua": {"$className": "Folder"}}'

			expect(build(project(tree, nil, { ["src/b.lua"] = "b", ["src/d.lua"] = "d" })).children).toEqual({
				{ name = "b", class = "ModuleScript", Source = "b" },
				{ name = "d", class = "ModuleScript", Source = "d" },
				{ name = "a", class = "Folder" },
				{ name = "b.lua", class = "Folder" },
				{ name = "c", class = "Folder" },
			})
		end)

		it("keeps the file's id unless $id replaces it (m-ids)", function()
			local tree = '{"$className": "Folder", "WithMeta": {"$path": "t.txt"}, '
				.. '"Override": {"$path": "u.txt", "$id": "nodeid"}, "Plain": {"$className": "Folder", "$id": "plainid"}}'
			local files = {
				["t.txt"] = "t",
				["t.meta.json"] = '{"id": "metaid"}',
				["u.txt"] = "u",
				["u.meta.json"] = '{"id": "uid"}',
			}

			expect(build(project(tree, nil, files)).children).toEqual({
				{ name = "Override", class = "StringValue", Value = "u", id = "nodeid" },
				{ name = "Plain", class = "Folder", id = "plainid" },
				{ name = "WithMeta", class = "StringValue", Value = "t", id = "metaid" },
			})
		end)

		it(
			"resolves explicit and implicit values and tags against the node's class (props-explicit, prop-tags)",
			function()
				local tree = '{"$className": "Folder", "$properties": {"Tags": ["a", "b"]}, '
					.. '"v": {"$className": "IntValue", "$properties": {"Value": {"Int64": 5}}}, '
					.. '"b": {"$className": "BoolValue", "$properties": {"Value": true}}, "": {"$className": "Folder"}}'

				expect(build(project(tree))).toEqual({
					name = "pkg",
					class = "Folder",
					Tags = { "a", "b" },
					children = {
						{ name = "", class = "Folder" },
						{ name = "b", class = "BoolValue", Value = true },
						{ name = "v", class = "IntValue", Value = 5 },
					},
				})
			end
		)

		it(
			"refuses a value that does not resolve, after the node's children (m-props-order, m-child-then-prop)",
			function()
				expect(refusal(project('{"$className": "StringValue", "$properties": {"Value": "v", "Nope": 1}}'))).toEqual({
					path = PROJECT,
					message = "Unresolvable property in project: Unknown property StringValue.Nope",
				})
				expect(refusal(project('{"$className": "StringValue", "$properties": {"Nope": 1}, "kid": {}}'))).toEqual(
					missingInformation("kid")
				)
				expect(refusal(project('{"$className": "Folder", "$attributes": {"A": [1, 2]}}'))).toEqual({
					path = PROJECT,
					message = "Unresolvable attribute in project: Cannot unambiguously resolve the value Array2([1.0, 2.0])",
				})
			end
		)

		it("resolves Name and Parent before dropping them, so a bad one refuses (m-parent)", function()
			expect(refusal(project('{"$className": "StringValue", "$properties": {"Parent": "x"}}')).message).toMatch(
				"^Unresolvable property in project: Cannot resolve Ref properties as a String"
			)
		end)
	end)

	describe("nested projects (R2.7)", function()
		it("drops the parent's sync rules inside a nested project and uses its own (x-nested-rules)", function()
			local files =
				project('{"$path": "nested.project.json"}', '"syncRules": [{"pattern": "*.rojo", "use": "text"}]', {
					["nested.project.json"] = '{"name": "nested", "tree": {"$path": "src"}, "syncRules": [{"pattern": "*.txt", "use": "ignore"}]}',
					["src/ignored.rojo"] = "x",
					["src/ignored.txt"] = "y",
					["src/kept.lua"] = "k",
				})

			expect(build(files)).toEqual({
				name = "pkg",
				class = "Folder",
				children = { { name = "kept", class = "ModuleScript", Source = "k" } },
			})
		end)

		it("keeps the parent's ignore rules inside and its own relative to its folder (x-ignore-nested)", function()
			local files = project('{"$path": "subproject"}', '"globIgnorePaths": ["**/*.spec.lua"]', {
				["subproject/default.project.json"] = '{"tree": {"$path": "src"}, "globIgnorePaths": ["src/inner.lua"]}',
				["subproject/src/include.lua"] = "i",
				["subproject/src/exclude.spec.lua"] = "e",
				["subproject/src/inner.lua"] = "n",
			})

			expect(build(files).children).toEqual({ { name = "include", class = "ModuleScript", Source = "i" } })
		end)

		it("never lets a nested project's ignore rules reach back up (x-ignore-back, x-ignore-sibling)", function()
			local function files(subTree: string): any
				return project('{"$className": "Folder", "Sub": {"$path": "sub"}, "Src": {"$path": "src"}}', nil, {
					["sub/default.project.json"] = `\{"tree": {subTree}, "globIgnorePaths": ["../src/x.lua"]}`,
					["src/x.lua"] = "x",
					["src/y.lua"] = "y",
				})
			end

			local moduleX = { name = "x", class = "ModuleScript", Source = "x" }
			local moduleY = { name = "y", class = "ModuleScript", Source = "y" }

			expect(build(files(FOLDER)).children).toEqual({
				{ name = "Src", class = "Folder", children = { moduleX, moduleY } },
				{ name = "Sub", class = "Folder" },
			})
			expect(build(files('{"$path": "../src"}')).children).toEqual({
				{ name = "Src", class = "Folder", children = { moduleX, moduleY } },
				{ name = "Sub", class = "Folder", children = { moduleY } },
			})
		end)

		it("takes emitLegacyScripts from each project, true when it gives none (x-emit, x-emit-absent)", function()
			local function files(nested: string): any
				return project(
					'{"$className": "Folder", "f1": {"$path": "folder1"}, "f2": {"$path": "folder2"}}',
					'"emitLegacyScripts": false',
					{
						["folder1/test.server.luau"] = "",
						["folder2/default.project.json"] = `\{"tree": \{"$path": "folder3"}{nested}}`,
						["folder2/folder3/test.server.luau"] = "",
					}
				)
			end

			local expected = {
				{
					name = "f1",
					class = "Folder",
					children = { { name = "test", class = "Script", Source = "", RunContext = SERVER } },
				},
				{
					name = "f2",
					class = "Folder",
					children = { { name = "test", class = "Script", Source = "", RunContext = LEGACY } },
				},
			}

			expect(build(files(', "emitLegacyScripts": true')).children).toEqual(expected)
			expect(build(files("")).children).toEqual(expected)
		end)

		it("lets a nested project turn legacy scripts off inside it only (x-emit-nested-false)", function()
			local files =
				project('{"$className": "Folder", "f2": {"$path": "folder2"}, "s": {"$path": "s.client.lua"}}', nil, {
					["s.client.lua"] = "",
					["folder2/default.project.json"] = '{"tree": {"$path": "folder3"}, "emitLegacyScripts": false}',
					["folder2/folder3/test.client.luau"] = "",
				})

			expect(build(files).children).toEqual({
				{
					name = "f2",
					class = "Folder",
					children = { { name = "test", class = "Script", Source = "", RunContext = CLIENT } },
				},
				{ name = "s", class = "LocalScript", Source = "" },
			})
		end)
	end)

	describe("sync rules (R2.8)", function()
		it("matches a project's rules relative to its folder, outer rules never inside (x-rules-relative)", function()
			local files = project(
				'{"$path": "src"}',
				'"syncRules": [{"pattern": "src/*.dat", "use": "moduleScript", "suffix": ".dat"}, '
					.. '{"pattern": "**/*.dat", "use": "serverScript"}]',
				{
					["src/a.dat"] = "a",
					["src/sub/lib/b.dat"] = "b",
					["src/sub/default.project.json"] = '{"tree": {"$path": "lib"}, "syncRules": [{"pattern": "lib/*.dat", "use": "text"}]}',
				}
			)

			expect(build(files).children).toEqual({
				{ name = "a", class = "ModuleScript", Source = "a" },
				{ name = "sub", class = "Folder", children = { { name = "b", class = "StringValue", Value = "b" } } },
			})
		end)

		it("matches paths outside the project's folder through `..`, as Rojo does (x-rules-outside)", function()
			local files = project('{"$className": "Folder", "Sub": {"$path": "sub"}}', nil, {
				["sub/default.project.json"] = '{"tree": {"$path": "../src"}, "syncRules": [{"pattern": "**/*.dat", "use": "text"}, '
					.. '{"pattern": "../src/*.lua", "use": "text"}]}',
				["src/a.dat"] = "a",
				["src/b.lua"] = "b",
			})

			expect(build(files).children).toEqual({
				{
					name = "Sub",
					class = "Folder",
					children = {
						{ name = "a", class = "StringValue", Value = "a" },
						{ name = "b", class = "StringValue", Value = "b" },
					},
				},
			})
		end)

		it(
			"vetoes a rule by `exclude`, strips `suffix`, and lets the first match win (x-rules-exclude, x-rules-first)",
			function()
				local excluded = project(
					'{"$path": "src"}',
					'"syncRules": [{"pattern": "src/*.dat", "exclude": "src/b.*", "use": "text"}, '
						.. '{"pattern": "**/*.x", "use": "text", "suffix": ".dat.x"}]',
					{ ["src/a.dat"] = "a", ["src/b.dat"] = "b", ["src/c.dat.x"] = "c" }
				)
				local first = project(
					'{"$path": "src"}',
					'"syncRules": [{"pattern": "**/*.lua", "use": "text"}, '
						.. '{"pattern": "**/*.lua", "use": "moduleScript"}, {"pattern": "**", "use": "serverScript"}]',
					{
						["src/a.lua"] = "a",
						["src/b.txt"] = "b",
					}
				)

				expect(build(excluded).children).toEqual({
					{ name = "a", class = "StringValue", Value = "a" },
					{ name = "c", class = "StringValue", Value = "c" },
				})
				expect(build(first).children).toEqual({
					{ name = "a", class = "StringValue", Value = "a" },
					{ name = "b", class = "Script", Source = "b", RunContext = LEGACY },
				})
			end
		)

		it("never matches a directory, and builds project files a rule names (x-rules-dir, rule-project)", function()
			local directory = project(
				'{"$path": "src"}',
				'"syncRules": [{"pattern": "**/*.dat", "use": "text"}]',
				{ ["src/d.dat/a.lua"] = "a" }
			)
			local projects = project(
				'{"$path": "src"}',
				'"syncRules": [{"pattern": "**/*.proj", "use": "project", "suffix": ".proj"}]',
				{
					["src/x.proj"] = '{"name": "Named", "tree": {"$className": "Model"}}',
					["src/y.proj"] = '{"tree": {"$className": "Model"}}',
				}
			)

			expect(build(directory).children).toEqual({
				{
					name = "d.dat",
					class = "Folder",
					children = { { name = "a", class = "ModuleScript", Source = "a" } },
				},
			})
			expect(build(projects).children).toEqual({
				{ name = "Named", class = "Model" },
				{ name = "y", class = "Model" },
			})
		end)

		it("reads `use` written as a unit variant object (use-obj)", function()
			local files = project(
				'{"$path": "src"}',
				'"syncRules": [{"pattern": "*.x", "use": {"text": null}}]',
				{ ["src/a.x"] = "a" }
			)

			expect(build(files).children).toEqual({ { name = "a", class = "StringValue", Value = "a" } })
		end)

		it("negates an ignore glob by one leading `!`, and reads `\\!` as a literal (s-ignore-neg)", function()
			local files = project(
				'{"$className": "Folder", "A": {"$path": "!a"}, "Src": {"$path": "src"}}',
				'"globIgnorePaths": ' .. '["src/*.lua", "!src/keep.lua", "\\\\!a/x.lua", "**/y.lua", "!!a/y.lua"]',
				{
					["src/a.lua"] = "a",
					["src/keep.lua"] = "k",
					["!a/x.lua"] = "x",
					["!a/y.lua"] = "y",
					["!a/z.lua"] = "z",
				}
			)

			expect(build(files).children).toEqual({
				{
					name = "A",
					class = "Folder",
					children = {
						{ name = "y", class = "ModuleScript", Source = "y" },
						{ name = "z", class = "ModuleScript", Source = "z" },
					},
				},
				{
					name = "Src",
					class = "Folder",
					children = { { name = "keep", class = "ModuleScript", Source = "k" } },
				},
			})
		end)

		it("refuses a rule Rojo cannot read, naming the project (rule-baduse)", function()
			expect(refusal(project(FOLDER, '"syncRules": [{"pattern": "*.x", "use": "dir"}]')).message).toMatch(
				"^File was not a valid Rojo project: unknown variant `dir`"
			)
		end)
	end)

	describe("naming (R1.13)", function()
		it("names a project entry by its `name`, else by its file or folder (nm-entries, jsonc-dir)", function()
			local files = {
				["a.project.json"] = `\{"tree": {FOLDER}}`,
				["b.project.json"] = `\{"tree": {FOLDER}, "name": "Bee"}`,
				["c/default.project.json"] = `\{"tree": {FOLDER}}`,
				["d/default.project.json"] = `\{"tree": {FOLDER}, "name": "Dee"}`,
				["e.project.jsonc"] = `\{"tree": {FOLDER}}`,
				["j/default.project.jsonc"] = `// c\n\{"tree": {FOLDER}, "name": "J"}`,
			}

			expect(build(files).children).toEqual({
				{ name = "a", class = "Folder" },
				{ name = "Bee", class = "Folder" },
				{ name = "c", class = "Folder" },
				{ name = "Dee", class = "Folder" },
				{ name = "e", class = "Folder" },
				{ name = "J", class = "Folder" },
			})
		end)

		it("names a project a $path reaches by the referring key, whatever its `name` (nm-path)", function()
			local files =
				project('{"$className": "Folder", "K1": {"$path": "x.project.json"}, "K2": {"$path": "d"}}', nil, {
					["x.project.json"] = `\{"tree": {FOLDER}, "name": "Named"}`,
					["d/default.project.json"] = `\{"tree": {FOLDER}, "name": "Dee"}`,
				})

			expect(build(files).children).toEqual({
				{ name = "K1", class = "Folder" },
				{ name = "K2", class = "Folder" },
			})
		end)

		it("applies no meta file to a project's root (meta-beside-project)", function()
			local files = {
				["x.project.json"] = `\{"tree": {FOLDER}}`,
				["x.meta.json"] = '{"attributes": {"M": true}}',
				["d/default.project.json"] = `\{"tree": {FOLDER}}`,
				["d/init.meta.json"] = '{"attributes": {"I": true}}',
			}

			expect(build(files).children).toEqual({ { name = "d", class = "Folder" }, { name = "x", class = "Folder" } })
		end)

		it(
			"makes nothing of a project whose tree is a missing optional path (nm-entry-optional, nm-root-optional)",
			function()
				expect(
					build({ ["x.project.json"] = '{"tree": {"$path": {"optional": "nope"}}}', ["y.lua"] = "y" }).children
				).toEqual({
					{ name = "y", class = "ModuleScript", Source = "y" },
				})
				expect(refusal(project('{"$path": {"optional": "nope"}}'))).toEqual({
					path = "",
					message = "the package builds no instance",
				})
			end
		)
	end)

	describe("DataModel nodes (Studio's loader)", function()
		it(
			"leaves out a project entry rooted in a DataModel and keeps the package's other files (g-plain-project)",
			function()
				local files = {
					["test.project.json"] = '{"tree": {"$className": "DataModel", "ReplicatedStorage": {"package": '
						.. '{"$className": "Folder", "src": {"$path": "src"}}}}}',
					["src/init.luau"] = "i",
					["src/util.luau"] = "u",
					["a.lua"] = "a",
				}

				expect(build(files)).toEqual({
					name = "pkg",
					class = "Folder",
					children = {
						{ name = "a", class = "ModuleScript", Source = "a" },
						{
							name = "src",
							class = "ModuleScript",
							Source = "i",
							children = { { name = "util", class = "ModuleScript", Source = "u" } },
						},
					},
				})
				expect(warnings).toEqual({ string.format(DROPPED, "test.project.json", "test") })
			end
		)

		it("builds a DataModel node as Rojo does, then leaves it out and keeps its siblings (g-child)", function()
			local tree = '{"$className": "Folder", "A": {"$className": "Folder"}, '
				.. '"DM": {"$className": "DataModel", "Kid": {"$className": "Folder"}}, "Z": {"$className": "Folder"}}'

			expect(build(project(tree))).toEqual({
				name = "pkg",
				class = "Folder",
				children = { { name = "A", class = "Folder" }, { name = "Z", class = "Folder" } },
			})
			expect(warnings).toEqual({ string.format(DROPPED, PROJECT, "DM") })
		end)

		it("leaves out a node whose $path reaches a DataModel project, warning once (g-path)", function()
			local tree = '{"$className": "Folder", "A": {"$className": "Folder"}, "Test": {"$path": "test.project.json"}, '
				.. '"Z": {"$className": "Folder"}}'
			local files = project(tree, nil, {
				["test.project.json"] = '{"tree": {"$className": "DataModel", "ReplicatedStorage": {"$path": "src"}}}',
				["src/init.luau"] = "i",
			})

			expect(build(files).children).toEqual({ { name = "A", class = "Folder" }, { name = "Z", class = "Folder" } })
			expect(warnings).toEqual({ string.format(DROPPED, PROJECT, "Test") })
		end)

		it("leaves out a DataModel over a Folder path, destroying what the path loaded (g-dm-path-folder)", function()
			local files = project(
				'{"$className": "Folder", "DM": {"$className": "DataModel", "$path": "dir"}, "Z": '
					.. '{"$className": "Folder"}}',
				nil,
				{ ["dir/m.model.json"] = '{"className": "Folder"}', ["dir/r.rbxm"] = RBXM }
			)

			holdLoadedModels()

			expect(build(files).children).toEqual({ { name = "Z", class = "Folder" } })
			expect(#loaded).toBe(1)
			expect(isDestroyed(loaded[1])).toBe(true)
		end)

		it("raises Rojo's refusals inside a DataModel it leaves out (g-dm-error, g-dm-badprop)", function()
			local function files(tree: string): any
				return { ["test.project.json"] = `\{"tree": {tree}}`, ["a.lua"] = "a" }
			end

			expect(refusal(files('{"$className": "DataModel", "ReplicatedStorage": {"Main": {"$path": "nope"}}}'))).toEqual({
				path = "test.project.json",
				message = '$path "nope" could not be turned into an instance',
			})
			expect(refusal(files('{"$className": "DataModel", "Workspace": {"$properties": {"Nope": 1}}}'))).toEqual({
				path = "test.project.json",
				message = "Unresolvable property in project: Unknown property Workspace.Nope",
			})
		end)

		it(
			"lets any class stand inside a DataModel it leaves out, model files included (g-dm-model-service)",
			function()
				local files = project(
					'{"$className": "Folder", "A": {"$className": "Folder"}, "Test": {"$path": "test.project.json"}}',
					nil,
					{
						["test.project.json"] = '{"tree": {"$className": "DataModel", "Lighting": {"$path": "l.model.json"}}}',
						["l.model.json"] = '{"className": "Lighting"}',
					}
				)

				expect(build(files).children).toEqual({ { name = "A", class = "Folder" } })
				expect(warnings).toEqual({ string.format(DROPPED, PROJECT, "Test") })
			end
		)

		it(
			"lets Rojo's refusal win over a class a plugin cannot create elsewhere in the package (g-precedence)",
			function()
				expect(refusal(project('{"$className": "Folder", "A": {"$className": "NotAClass"}, "B": {}}'))).toEqual(
					missingInformation("B")
				)
				expect(refusal(project('{"$className": "Folder", "A": {"$className": "NotAClass"}}'))).toEqual(
					uncreatable("NotAClass")
				)
			end
		)

		it("still refuses a service directly under anything but a DataModel (g-service-outside)", function()
			expect(refusal(project('{"$className": "Folder", "RS": {"$className": "ReplicatedStorage"}}'))).toEqual(
				uncreatable("ReplicatedStorage")
			)
		end)
	end)

	describe("recursion (R7)", function()
		it("refuses a project that reaches its own file, where Rojo overflows its stack (dot, dotclass)", function()
			expect(refusal(project('{"$path": "."}', nil, { ["a.lua"] = "a" }))).toEqual({
				path = PROJECT,
				message = CYCLE,
			})
			expect(refusal(project('{"$className": "Folder", "x": {"$path": "."}}'))).toEqual({
				path = PROJECT,
				message = CYCLE,
			})
			expect(refusal(project('{"$path": ""}'))).toEqual({ path = PROJECT, message = CYCLE })
		end)

		it("refuses a nested project that reaches back into its own folder (nested-dotdot-src)", function()
			local files = project('{"$path": "src"}', nil, {
				["src/x.project.json"] = '{"tree": {"$path": "../src"}}',
				["src/a.lua"] = "a",
			})

			expect(refusal(files)).toEqual({ path = "src/x.project.json", message = CYCLE })
		end)

		it("builds the same project file twice when it is reached twice without a cycle", function()
			local files = project(
				'{"$className": "Folder", "A": {"$path": "x.project.json"}, "B": {"$path": "x.project.json"}}',
				nil,
				{
					["x.project.json"] = `\{"tree": {FOLDER}}`,
				}
			)

			expect(build(files).children).toEqual({ { name = "A", class = "Folder" }, { name = "B", class = "Folder" } })
		end)
	end)

	describe("loaded models", function()
		it(
			"destroys every model the project loaded when a later node refuses, and keeps them when it builds",
			function()
				local failing =
					project('{"$className": "Folder", "A": {"$path": "m.rbxm"}, "B": {"$path": "nope"}}', nil, {
						["m.rbxm"] = RBXM,
					})
				local nested = project('{"$className": "Folder", "A": {"$path": "sub"}, "B": {}}', nil, {
					["sub/default.project.json"] = '{"tree": {"$className": "Folder", "M": {"$path": "m.rbxm"}}}',
					["sub/m.rbxm"] = RBXM,
				})

				holdLoadedModels()

				refusal(failing)
				refusal(nested)
				build(project('{"$className": "Folder", "A": {"$path": "m.rbxm"}}', nil, { ["m.rbxm"] = RBXM }))

				expect(#loaded).toBe(4)
				expect(isDestroyed(loaded[1])).toBe(true)
				expect(isDestroyed(loaded[2])).toBe(true)
				expect(isDestroyed(loaded[3])).toBe(false)
			end
		)

		it("destroys the model a $path loaded when the node's class choice refuses it (s-model-class)", function()
			local files = { ["m.rbxm"] = RBXM }

			holdLoadedModels()

			expect(
				refusal(
					project('{"$className": "Folder", "Node": {"$className": "Folder", "$path": "m.rbxm"}}', nil, files)
				).message
			).toMatch(
				'^ClassName for Instance "Node" was specified in both the project file %(as "Folder"%) and from the '
					.. 'filesystem %(as "Model"%)'
			)
			build(project('{"$className": "Folder", "Node": {"$path": "m.rbxm"}}', nil, files))

			expect(#loaded).toBe(3)
			expect(isDestroyed(loaded[1])).toBe(true)
			expect(isDestroyed(loaded[2])).toBe(false)
		end)
	end)
end)
