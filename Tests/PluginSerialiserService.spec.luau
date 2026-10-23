local EncodingService = game:GetService("EncodingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local PluginApplyService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginApplyService)
local PluginModelService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginModelService)
local PluginPropertyService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginPropertyService)
local PluginRefService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginRefService)
local PluginSerialiserService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginSerialiserService)
local PluginSnapshotService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginSnapshotService)
local VirtualFileSystem = require(ReplicatedStorage.WallyPlugin.PluginClasses.VirtualFileSystem)

local serialiserFiles = require(ReplicatedStorage.Tests.Fixtures.serialiserFiles)
local virtualFileSystemZip = require(ReplicatedStorage.Tests.Fixtures.virtualFileSystemZip)

local UNEXPECTED = "the build stopped on an unexpected error: "
local UNCREATABLE = "Class NotAClass cannot be created by a plugin"
local MODEL_PATH = "src/thing.rbxm"

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local apply = PluginApplyService.Apply
local loadInstances = PluginModelService.LoadInstances
local snapshotPackage = PluginSnapshotService.SnapshotPackage
local applyReporter = PluginApplyService.Reporter
local propertyReporter = PluginPropertyService.Reporter
local refReporter = PluginRefService.Reporter
local warnings = {}
local touched = {}
local loaded = {}
local built = {}

local function decode(base64: string): string
	return buffer.tostring(EncodingService:Base64Decode(buffer.fromstring(base64)))
end

local function project(tree: string): string
	return `\{"name": "pkg", "tree": {tree}}`
end

local function serialise(files: { [string]: string }, name: string?)
	local result = PluginSerialiserService:SerialiseFileSystem(VirtualFileSystem.fromFiles(files), name or "pkg")

	if result.ok then
		table.insert(built, result.value)
	end

	return result
end

local function buildTree(files: { [string]: string }): Instance
	local result = serialise(files)

	assert(result.ok, if result.ok then "" else `{result.error.path}: {result.error.message}`)

	return result.value
end

local function describeText(text: string): string
	return if #text > 40 then `<{#text} bytes>` else text
end

local function listTree(root: Instance): { string }
	local lines = {}

	local function visit(instance: Instance)
		local parts = { instance:GetFullName(), instance.ClassName }
		local marks = {}
		local isPointer = instance:IsA("ObjectValue")
		local target = if isPointer then (instance :: ObjectValue).Value else nil
		local primaryPart = if instance:IsA("Model") then instance.PrimaryPart else nil

		if target then
			table.insert(parts, `Value={target:GetFullName()}`)
		elseif instance:IsA("ValueBase") and not isPointer then
			table.insert(parts, `Value={describeText(tostring((instance :: any).Value))}`)
		end

		if primaryPart then
			table.insert(parts, `PrimaryPart={primaryPart:GetFullName()}`)
		end

		if instance:IsA("LuaSourceContainer") then
			table.insert(parts, `Source={describeText((instance :: any).Source)}`)
		end

		for name, attribute in instance:GetAttributes() do
			table.insert(marks, `@{name}={describeText(tostring(attribute))}`)
		end

		for _, tag in instance:GetTags() do
			table.insert(marks, `#{tag}`)
		end

		table.sort(marks)
		table.move(marks, 1, #marks, #parts + 1, parts)
		table.insert(lines, table.concat(parts, " "))

		for _, child in instance:GetChildren() do
			visit(child)
		end
	end

	visit(root)

	return lines
end

local function isDestroyed(instance: Instance): boolean
	local probe = Instance.new("Folder")
	local moved = pcall(function()
		instance.Parent = probe
	end)

	probe:Destroy()

	return not moved
end

local function loadModel(base64: string, name: string): any
	local fileSystem = VirtualFileSystem.fromFiles({ [MODEL_PATH] = decode(base64) })
	local result = PluginModelService:SnapshotBinaryModel(fileSystem, MODEL_PATH, name)

	assert(result.ok, "the fixture model loads")

	return result.value
end

local function node(name: string, className: string, children: { any }?): any
	return { name = name, className = className, properties = {}, children = children or {}, path = `src/{name}` }
end

describe("PluginSerialiserService", function()
	beforeEach(function()
		local reporter = {
			Warn = function(_, message: string)
				table.insert(warnings, message)
			end,
		}

		warnings = {}
		touched = {}
		loaded = {}
		built = {}
		PluginApplyService.Reporter = reporter
		PluginPropertyService.Reporter = reporter
		PluginRefService.Reporter = reporter
		PluginApplyService.Apply = function(self, instance: Instance, properties: { [string]: any })
			table.insert(touched, instance)

			return apply(self, instance, properties)
		end
		PluginModelService.LoadInstances = function(self, path: string, contents: string)
			local result = loadInstances(self, path, contents)

			if result.ok then
				table.move(result.value, 1, #result.value, #loaded + 1, loaded)
			end

			return result
		end
	end)

	afterEach(function()
		PluginApplyService.Reporter = applyReporter
		PluginPropertyService.Reporter = propertyReporter
		PluginRefService.Reporter = refReporter
		PluginApplyService.Apply = apply
		PluginModelService.LoadInstances = loadInstances
		PluginSnapshotService.SnapshotPackage = snapshotPackage

		for _, instances in { built, touched, loaded } do
			for _, instance in instances do
				instance:Destroy()
			end
		end
	end)

	it("is named after its file", function()
		local source = ReplicatedStorage.WallyPlugin.PluginServices.PluginSerialiserService.Source

		expect(source).toContain("\nlocal PluginSerialiserService = {}\n")
		expect(source).toContain("\nreturn PluginSerialiserService\n")
	end)

	it("builds a package zip as Rojo builds its folder, named after the package", function()
		local result =
			PluginSerialiserService:SerialiseZipIntoRobloxInstances(decode(virtualFileSystemZip.zip), "fixture")

		expect(result.ok).toBe(true)
		table.insert(built, result.value)
		expect(listTree(result.value)).toEqual({
			"fixture Folder",
			"fixture.lib Folder",
			"fixture.lib.nested Folder",
			"fixture.lib.nested.deep StringValue Value=<311 bytes>",
			"fixture.src ModuleScript Source=return require(script.a)\n",
			'fixture.src.B ModuleScript Source=return "B"\n',
			'fixture.src._private ModuleScript Source=return "_"\n',
			'fixture.src.a ModuleScript Source=return "a"\n',
			"fixture.src.empty Folder",
			"fixture.wally ModuleScript Source=<93 bytes>",
		})
		expect(result.value.wally.Source).toBe(
			'return {\n\tpackage = {\n\t\tname = "biff/fixture",\n\t\trealm = "shared",\n\t\tversion = "1.0.0",\n\t},\n}'
		)
	end)

	it("refuses a zip it cannot read, and a package Rojo refuses, naming the file", function()
		local unreadable = PluginSerialiserService:SerialiseZipIntoRobloxInstances("not a zip", "pkg")
		local refused =
			PluginSerialiserService:SerialiseZipIntoRobloxInstances(decode(serialiserFiles.refusedZip), "broken")

		expect(unreadable.ok).toBe(false)
		expect(unreadable.error.path).toBe("")
		expect(string.sub(unreadable.error.message, 1, 25)).toBe("the zip could not be read")
		expect(refused).toEqual({
			ok = false,
			error = { path = "default.project.json", message = '$path "src" could not be turned into an instance' },
		})
	end)

	it("creates instances depth first in snapshot order: entries by bytes, then project children by key", function()
		local folder = buildTree({
			["b.lua"] = "return 'b'",
			["a.lua"] = "return 'a'",
			["B.lua"] = "return 'B'",
			["_.lua"] = "return '_'",
			["a.txt"] = "text",
			["dir/x.lua"] = "return 'x'",
		})
		local projected = buildTree({
			["default.project.json"] = project(
				'{"$className": "Folder", "zeta": {"$className": "Folder"}, "Alpha": {"$className": "Folder"}, '
					.. '"beta": {"$path": "src", "extra": {"$className": "Folder"}}}'
			),
			["src/b.lua"] = "return 'b'",
			["src/a.lua"] = "return 'a'",
		})

		expect(listTree(folder)).toEqual({
			"pkg Folder",
			"pkg.B ModuleScript Source=return 'B'",
			"pkg._ ModuleScript Source=return '_'",
			"pkg.a ModuleScript Source=return 'a'",
			"pkg.a StringValue Value=text",
			"pkg.b ModuleScript Source=return 'b'",
			"pkg.dir Folder",
			"pkg.dir.x ModuleScript Source=return 'x'",
		})
		expect(listTree(projected)).toEqual({
			"pkg Folder",
			"pkg.Alpha Folder",
			"pkg.beta Folder",
			"pkg.beta.a ModuleScript Source=return 'a'",
			"pkg.beta.b ModuleScript Source=return 'b'",
			"pkg.beta.extra Folder",
			"pkg.zeta Folder",
		})
	end)

	describe("model files", function()
		it(
			"keeps a loaded model's instance, with the snapshot's properties applied and its children appended",
			function()
				local snapshot = loadModel(serialiserFiles.modelModel, "Thing")
				local model = snapshot.model

				snapshot.properties = { Attributes = { Added = true }, Tags = { "FromProject" } }
				table.insert(snapshot.children, node("Extra", "Folder"))

				local result = PluginSerialiserService:Instantiate(snapshot)

				expect(result).toEqual({ ok = true, value = model })
				expect(listTree(model)).toEqual({
					"Thing Model #FromProject @Added=true",
					"Thing.Base Part @Rojo_Id=loaded-part",
					"Thing.Pointer ObjectValue @Rojo_Target_Value=outside",
					"Thing.Extra Folder",
				})
			end
		)

		it("builds a project node over a model file as Rojo does, linking Refs into and out of the model", function()
			local root = buildTree({
				["default.project.json"] = project(
					'{"$path": "thing.rbxm", "$properties": {"Tags": ["FromProject"]}, "$attributes": {"Added": true}, '
						.. '"Extra": {"$className": "Folder"}, "Outside": {"$className": "Folder", "$id": "outside"}, '
						.. '"Seeker": {"$className": "ObjectValue", "$attributes": {"Rojo_Target_Value": "loaded-part"}}}'
				),
				["thing.rbxm"] = decode(serialiserFiles.modelModel),
			})

			expect(listTree(root)).toEqual({
				"pkg Model #FromProject @Added=true",
				"pkg.Base Part @Rojo_Id=loaded-part",
				"pkg.Pointer ObjectValue Value=pkg.Outside @Rojo_Target_Value=outside",
				"pkg.Extra Folder",
				"pkg.Outside Folder",
				"pkg.Seeker ObjectValue Value=pkg.Base @Rojo_Target_Value=loaded-part",
			})
		end)

		it(
			"gives a Folder model the node's class, moving its attributes, tags and children, and destroys it",
			function()
				local root = buildTree({
					["default.project.json"] = project(
						'{"$className": "Model", "$path": "thing.rbxm", "Extra": {"$className": "Folder"}, '
							.. '"Seeker": {"$className": "ObjectValue", "$attributes": {"Rojo_Target_Value": "loaded-folder"}}}'
					),
					["thing.rbxm"] = decode(serialiserFiles.folderModel),
				})
				local retagged = buildTree({
					["default.project.json"] = project(
						'{"$className": "Configuration", "$path": "thing.rbxm", "$properties": {"Tags": ["Mine"]}}'
					),
					["thing.rbxm"] = decode(serialiserFiles.folderModel),
				})

				expect(listTree(root)).toEqual({
					"pkg Model #Loaded @Colour=red @Rojo_Id=loaded-folder",
					"pkg.Inner BoolValue Value=true",
					"pkg.Second Folder",
					"pkg.Extra Folder",
					"pkg.Seeker ObjectValue Value=pkg @Rojo_Target_Value=loaded-folder",
				})
				expect(listTree(retagged)).toEqual({
					"pkg Configuration #Mine @Colour=red @Rojo_Id=loaded-folder",
					"pkg.Inner BoolValue Value=true",
					"pkg.Second Folder",
				})
				expect(#loaded).toBe(2)
				expect(isDestroyed(loaded[1])).toBe(true)
				expect(isDestroyed(loaded[2])).toBe(true)
				expect(isDestroyed(root)).toBe(false)
			end
		)
	end)

	describe("Refs", function()
		local files = {
			["default.project.json"] = project([[{"$className": "Folder",
				"A": {"$className": "ObjectValue", "$attributes": {"Rojo_Target_Value": "zed"}},
				"C": {"$className": "Model", "$attributes": {"Rojo_Target_PrimaryPart": "part"},
					"P": {"$className": "Part", "$id": "part"}},
				"D": {"$className": "ObjectValue", "$attributes": {"Rojo_Target_Value": "nope"}},
				"E": {"$className": "ObjectValue", "$attributes": {"Rojo_Target_Value": "same"}},
				"F1": {"$className": "Folder", "$id": "same"},
				"F2": {"$className": "Folder", "$id": "same"},
				"G": {"$className": "ObjectValue", "$attributes": {"Rojo_Target_Value": 5}},
				"H": {"$className": "Folder", "$id": "replaced", "$attributes": {"Rojo_Id": "rojo-id"}},
				"I": {"$className": "ObjectValue", "$attributes": {"Rojo_Target_Value": "replaced"}},
				"J": {"$className": "ObjectValue", "$attributes": {"Rojo_Target_Value": "rojo-id"}},
				"K": {"$path": "src"},
				"L": {"$className": "ObjectValue", "$attributes": {"Rojo_Target_Value": "dir"}},
				"N": {"$className": "Folder", "$attributes": {"Rojo_Target_Bogus": "zed"}},
				"Z": {"$className": "Folder", "$id": "zed"}}]]),
			["src/init.meta.json"] = '{"id": "dir"}',
			["src/module.lua"] = "return 1",
			["src/module.meta.json"] = '{"id": "meta-module"}',
			["src/pointer.model.json"] = '{"className": "ObjectValue", "id": "model-top", '
				.. '"attributes": {"Rojo_Target_Value": "meta-module"}, '
				.. '"children": [{"name": "Kid", "className": "Folder", "id": "model-child"}]}',
			["src/back.model.json"] = '{"className": "ObjectValue", "attributes": {"Rojo_Target_Value": "model-top"}}',
			["src/child.model.json"] = '{"className": "ObjectValue", "attributes": {"Rojo_Target_Value": "model-child"}}',
		}

		it(
			"links through $id, meta id, model id and Rojo_Id once the tree exists, keeping the Rojo_ attributes",
			function()
				expect(listTree(buildTree(files))).toEqual({
					"pkg Folder",
					"pkg.A ObjectValue Value=pkg.Z @Rojo_Target_Value=zed",
					"pkg.C Model PrimaryPart=pkg.C.P @Rojo_Target_PrimaryPart=part",
					"pkg.C.P Part",
					"pkg.D ObjectValue @Rojo_Target_Value=nope",
					"pkg.E ObjectValue @Rojo_Target_Value=same",
					"pkg.F1 Folder",
					"pkg.F2 Folder",
					"pkg.G ObjectValue @Rojo_Target_Value=5",
					"pkg.H Folder @Rojo_Id=rojo-id",
					"pkg.I ObjectValue @Rojo_Target_Value=replaced",
					"pkg.J ObjectValue Value=pkg.H @Rojo_Target_Value=rojo-id",
					"pkg.K Folder",
					"pkg.K.back ObjectValue Value=pkg.K.pointer @Rojo_Target_Value=model-top",
					"pkg.K.child ObjectValue @Rojo_Target_Value=model-child",
					"pkg.K.module ModuleScript Source=return 1",
					"pkg.K.pointer ObjectValue Value=pkg.K.module @Rojo_Target_Value=meta-module",
					"pkg.K.pointer.Kid Folder",
					"pkg.L ObjectValue Value=pkg.K @Rojo_Target_Value=dir",
					"pkg.N Folder @Rojo_Target_Bogus=zed",
					"pkg.Z Folder",
				})
			end
		)

		it(
			"leaves a property unset with a warning for an unknown or shared id, or a target that is not a string",
			function()
				buildTree(files)
				table.sort(warnings)

				expect(warnings).toEqual({
					"Attribute Rojo_Target_Value is of type Float64 when it was expected to be a String (pkg.G)",
					"Folder.Bogus was left out: Studio does not know the property, so it drops the Ref Rojo writes for it (pkg.N)",
					"No instance has the id 'model-child', so ObjectValue.Value is left unset (pkg.K.child)",
					"No instance has the id 'nope', so ObjectValue.Value is left unset (pkg.D)",
					"No instance has the id 'replaced', so ObjectValue.Value is left unset (pkg.I)",
					"The id 'same' is shared by 2 instances, so ObjectValue.Value is left unset (pkg.E)",
				})
			end
		)

		it("ignores a target naming Name or Parent with a warning, as Rojo's writer does", function()
			local root = buildTree({
				["default.project.json"] = project(
					'{"$className": "Folder", "M": {"$className": "Folder", "$attributes": {"Rojo_Target_Name": "zed", '
						.. '"Rojo_Target_Parent": "zed"}}, "Z": {"$className": "Folder", "$id": "zed"}}'
				),
			})

			expect(listTree(root)).toEqual({
				"pkg Folder",
				"pkg.M Folder @Rojo_Target_Name=zed @Rojo_Target_Parent=zed",
				"pkg.Z Folder",
			})
			expect(#warnings).toBe(2)
		end)

		it(
			"refuses a target on a property that is not a Ref, as Rojo's writer does, destroying what it built",
			function()
				local result = serialise({
					["default.project.json"] = project(
						'{"$className": "Folder", "M": {"$className": "StringValue", "$attributes": {"Rojo_Target_Value": "zed"}}, '
							.. '"Z": {"$className": "Folder", "$id": "zed"}}'
					),
				})

				expect(result).toEqual({
					ok = false,
					error = {
						path = "default.project.json",
						message = "Property type mismatch: Expected StringValue.Value to be of type String, ContentId, "
							.. "Tags, Attributes, MaterialColors, or BinaryString, but it was of type Ref on instance pkg.M",
					},
				})
				expect(#touched).toBe(3)

				for _, instance in touched do
					expect(isDestroyed(instance)).toBe(true)
				end
			end
		)
	end)

	describe("refusals", function()
		it("refuses a property Studio will not set, destroying everything built and loaded", function()
			local first = loadModel(serialiserFiles.modelModel, "First")
			local last = loadModel(serialiserFiles.folderModel, "Last")
			local kept = loadModel(serialiserFiles.modelModel, "Kept")
			local bad = {
				name = "Bad",
				className = "Folder",
				properties = { NotAProperty = true },
				children = {},
				path = "src/Bad",
			}
			local snapshot = node("pkg", "Folder", { node("Built", "Folder", { first }), bad, last })
			local result = PluginSerialiserService:Instantiate(snapshot)
			local control = PluginSerialiserService:Instantiate(node("pkg", "Folder", { kept }))

			expect(result.ok).toBe(false)
			expect(result.error.path).toBe("src/Bad")
			expect(result.error.message).toContain("Folder.NotAProperty could not be set: ")
			expect(#touched).toBe(6)

			for _, instance in { touched[1], touched[2], touched[4], first.model, last.model } do
				expect(isDestroyed(instance)).toBe(true)
			end

			expect(control.ok).toBe(true)
			expect(isDestroyed(kept.model)).toBe(false)
		end)

		it("refuses a class a plugin cannot create taking over a Folder model, destroying the model", function()
			local result = serialise({
				["default.project.json"] = project('{"$className": "NotAClass", "$path": "thing.rbxm"}'),
				["thing.rbxm"] = decode(serialiserFiles.folderModel),
			})

			expect(result).toEqual({ ok = false, error = { path = "default.project.json", message = UNCREATABLE } })
			expect(#loaded).toBe(1)
			expect(isDestroyed(loaded[1])).toBe(true)
		end)

		it("refuses a DataModel-rooted project, which Studio cannot create", function()
			local result = serialise({
				["default.project.json"] = project('{"$className": "DataModel", "ReplicatedStorage": {}}'),
			})

			expect(result.ok).toBe(false)
			expect(result.error.path).toBe("default.project.json")
			expect(result.error.message).toContain("cannot be created by a plugin")
		end)

		it("turns an unexpected error while snapshotting into a refusal", function()
			PluginSnapshotService.SnapshotPackage = function()
				error("the snapshot broke", 0)
			end

			expect(serialise({ ["a.lua"] = "return 1" })).toEqual({
				ok = false,
				error = { path = "", message = `{UNEXPECTED}the snapshot broke` },
			})
		end)

		it("turns an unexpected error while instantiating into a refusal, destroying what it built", function()
			local snapshot =
				node("pkg", "Folder", { loadModel(serialiserFiles.modelModel, "Thing"), node("Explodes", "Folder") })

			PluginApplyService.Apply = function(self, instance: Instance, properties: { [string]: any })
				table.insert(touched, instance)

				if instance.Name == "Explodes" then
					error("the property broke", 0)
				end

				return apply(self, instance, properties)
			end

			expect(PluginSerialiserService:Instantiate(snapshot)).toEqual({
				ok = false,
				error = { path = "", message = `{UNEXPECTED}the property broke` },
			})
			expect(#touched).toBe(3)

			for _, instance in touched do
				expect(isDestroyed(instance)).toBe(true)
			end
		end)
	end)

	describe("values Studio guards", function()
		it("builds a script and a generated module of 200000 bytes or more", function()
			local numbers = {}

			for number = 0, 39999 do
				table.insert(numbers, number)
			end

			local root = buildTree({
				["big.lua"] = 'return "' .. string.rep("ab", 125000) .. '"',
				["data.json"] = `[{table.concat(numbers, ", ")}]`,
				["small.lua"] = "return 1",
			})

			expect(listTree(root)).toEqual({
				"pkg Folder",
				"pkg.big ModuleScript Source=<250009 bytes>",
				"pkg.data ModuleScript Source=<268897 bytes>",
				"pkg.small ModuleScript Source=return 1",
			})
			expect(root.big.Source).toBe('return "' .. string.rep("ab", 125000) .. '"')
			expect(root.data.Source).toBe(`return \{{table.concat(numbers, ", ")}}`)
		end)

		it("builds a CSV and a meta file's Contents over one as Studio loads Rojo's builds of them", function()
			local root = buildTree({
				["strings.csv"] = "Key,Source,Context,Example,en,fr\n"
					.. "greeting,Hello,Menu,Hello there,Hello,Bonjour\n"
					.. ",Bye,,,Goodbye,Au revoir\n",
				["replaced.csv"] = "Key,Source,en\ngreeting,Hello,Hello\n",
				["replaced.meta.json"] = '{"properties": {"Contents": "[]"}}',
				["broken.csv"] = "Key,Source,en\ngreeting,Hello,Hello\n",
				["broken.meta.json"] = '{"properties": {"Contents": "not json"}}',
			})

			expect(root.strings:GetContents()).toBe(
				'[{"key":"greeting","context":"Menu","examples":"Hello there","source":"Hello",'
					.. '"values":{"en":"Hello","fr":"Bonjour"}},{"source":"Bye","values":{"en":"Goodbye","fr":"Au revoir"}}]'
			)
			expect(root.replaced:GetContents()).toBe("[]")
			expect(root.broken:GetContents()).toBe("[]")
			expect(#warnings).toBe(1)
		end)
	end)
end)
