local EncodingService = game:GetService("EncodingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local PluginModelService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginModelService)
local VirtualFileSystem = require(ReplicatedStorage.WallyPlugin.PluginClasses.VirtualFileSystem)

local fixture = require(ReplicatedStorage.Tests.Fixtures.modelFiles)

local JSON_PATH = "src/Thing.model.json"
local ONE_INSTANCE = "Rojo currently only supports model files with one top-level instance"
local JSON_REFUSALS = {
	{ "an unknown property", '{"className": "Folder", "properties": {"Bogus": 1}}', "Unknown property Folder.Bogus" },
	{
		"an unknown property on a child",
		'{"className": "Folder", "children": [{"className": "Folder", "properties": {"Bogus": 1}}]}',
		"Unknown property Folder.Bogus",
	},
	{
		"a child's property before its parent's, as Rojo snapshots children first",
		'{"className": "Folder", "properties": {"Zzz": 1}, "children": [{"className": "Folder", "properties": {"Aaa": 1}}]}',
		"Unknown property Folder.Aaa",
	},
	{
		"a property before an attribute",
		'{"className": "Folder", "properties": {"Bogus": 1}, "attributes": {"A": [1, 2]}}',
		"Unknown property Folder.Bogus",
	},
	{
		"a property value that does not parse",
		'{"className": "Folder", "properties": {"Bogus": null}}',
		"data did not match any variant of untagged enum UnresolvedValue",
	},
	{
		"an attribute that does not resolve",
		'{"className": "Folder", "attributes": {"A": [1, 2]}}',
		"Cannot unambiguously resolve the value Array2([1.0, 2.0])",
	},
	{ "a missing className", '{"name": "x"}', "missing field `className`" },
	{ "both spellings of a field", '{"className": "Folder", "ClassName": "Model"}', "duplicate field `className`" },
	{ "a file holding only a comment", "// nothing here", "File contains no JSON value" },
}
local UNCREATABLE_CLASSES = {
	{ "an unknown class", '{"className": "NotAClass"}', "NotAClass" },
	{
		"an unknown class on a child",
		'{"className": "Folder", "children": [{"className": "NotAClass"}]}',
		"NotAClass",
	},
	{ "a class a plugin cannot create", '{"className": "Player"}', "Player" },
}
local BINARY_FORMATS = {
	{ format = "rbxm", path = "src/Thing.rbxm", model = fixture.rbxm, other = fixture.rbxmx },
	{ format = "rbxmx", path = "src/Thing.rbxmx", model = fixture.rbxmx, other = fixture.rbxm },
}
local LOADED_CHILDREN = {
	{ "Base", "Part" },
	{ "Module", "ModuleScript" },
	{ "Pointer", "ObjectValue" },
	{ "Settings", "Configuration" },
}

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local reporter = PluginModelService.Reporter
local loadInstances = PluginModelService.LoadInstances
local warnings = {}
local loaded = {}
local held = {}

local function decode(base64: string): string
	return buffer.tostring(EncodingService:Base64Decode(buffer.fromstring(base64)))
end

local function holdLoadedInstances()
	PluginModelService.LoadInstances = function(self, path: string, contents: string)
		local result = loadInstances(self, path, contents)

		if result.ok then
			for _, instance in result.value do
				table.insert(held, instance)
			end
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

local function snapshotJson(text: string, files: { [string]: string }?)
	local fileSystem = VirtualFileSystem.fromFiles(files or { [JSON_PATH] = text })

	return PluginModelService:SnapshotJsonModel(fileSystem, JSON_PATH, "Thing")
end

local function snapshotBinary(path: string, contents: string, files: { [string]: string }?)
	local fileSystem = VirtualFileSystem.fromFiles(files or { [path] = contents })
	local result = PluginModelService:SnapshotBinaryModel(fileSystem, path, "Thing")

	if result.ok then
		table.insert(loaded, result.value.model)
	end

	return result
end

local function snapshot(fields: { [string]: any }): any
	return {
		name = fields.name,
		className = fields.className,
		properties = fields.properties or {},
		children = fields.children or {},
		id = fields.id,
		path = JSON_PATH,
	}
end

local function built(fields: { [string]: any }): any
	return { ok = true, value = snapshot(fields) }
end

local function refused(path: string, message: string): any
	return { ok = false, error = { path = path, message = message } }
end

describe("PluginModelService", function()
	beforeEach(function()
		table.clear(warnings)

		PluginModelService.Reporter = {
			Warn = function(_, message: string)
				table.insert(warnings, message)
			end,
		}
	end)

	afterEach(function()
		PluginModelService.Reporter = reporter
		PluginModelService.LoadInstances = loadInstances

		for _, model in loaded do
			model:Destroy()
		end

		for _, instance in held do
			instance:Destroy()
		end

		table.clear(loaded)
		table.clear(held)
	end)

	describe("SnapshotJsonModel (R1.10)", function()
		it("names the model after the file and each child after its name, else its class", function()
			local text =
				'{"className": "Folder", "children": [{"className": "Part"}, {"className": "Part", "name": "Named"}, {"className": "Folder", "name": "Part"}, {"className": "StringValue", "name": "a"}]}'

			expect(snapshotJson(text)).toEqual(built({
				name = "Thing",
				className = "Folder",
				children = {
					snapshot({ name = "Part", className = "Part" }),
					snapshot({ name = "Named", className = "Part" }),
					snapshot({ name = "Part", className = "Folder" }),
					snapshot({ name = "a", className = "StringValue" }),
				},
			}))
			expect(warnings).toEqual({})
		end)

		it("names a child whose name is null after its class", function()
			local text = '{"className": "Folder", "children": [{"className": "Folder", "name": null}]}'

			expect(snapshotJson(text)).toEqual(built({
				name = "Thing",
				className = "Folder",
				children = { snapshot({ name = "Folder", className = "Folder" }) },
			}))
		end)

		for _, field in { "name", "Name" } do
			it(`ignores a top-level {field} with Rojo's warning`, function()
				local text = `\{"{field}": "Other", "className": "Folder"}`

				expect(snapshotJson(text)).toEqual(built({ name = "Thing", className = "Folder" }))
				expect(warnings).toEqual({
					"Model at path src/Thing.model.json had a top-level Name field. This field has been ignored since Rojo 6.0. Consider removing this field and renaming the file to Other.model.json.",
				})
			end)
		end

		it("does not warn for a top-level name of null", function()
			expect(snapshotJson('{"name": null, "className": "Folder"}')).toEqual(
				built({ name = "Thing", className = "Folder" })
			)
			expect(warnings).toEqual({})
		end)

		it("reads the aliases", function()
			local text =
				'{"ClassName": "Model", "Properties": {"Tags": ["a"]}, "Children": [{"ClassName": "Part", "Name": "P", "Properties": {"Anchored": true}}]}'

			expect(snapshotJson(text)).toEqual(built({
				name = "Thing",
				className = "Model",
				properties = { Tags = { "a" } },
				children = { snapshot({ name = "P", className = "Part", properties = { Anchored = true } }) },
			}))
		end)

		it("resolves each object's properties against its own class", function()
			local text =
				'{"className": "StringValue", "properties": {"Value": "hi"}, "children": [{"className": "Part", "properties": {"Anchored": true, "Transparency": 0.5, "Material": "Wood"}}]}'

			expect(snapshotJson(text)).toEqual(built({
				name = "Thing",
				className = "StringValue",
				properties = { Value = "hi" },
				children = {
					snapshot({
						name = "Part",
						className = "Part",
						properties = { Anchored = true, Transparency = 0.5, Material = Enum.Material.Wood },
					}),
				},
			}))
		end)

		it("keeps Tags from properties as a string array", function()
			expect(snapshotJson('{"className": "Folder", "properties": {"Tags": ["x", "y"]}}')).toEqual(
				built({ name = "Thing", className = "Folder", properties = { Tags = { "x", "y" } } })
			)
		end)

		it("leaves out a Name property, which no build sets", function()
			expect(snapshotJson('{"className": "StringValue", "properties": {"Name": "x", "Value": "v"}}')).toEqual(
				built({ name = "Thing", className = "StringValue", properties = { Value = "v" } })
			)
		end)

		it("resolves attributes as Rojo's attribute rules do", function()
			local text =
				'{"className": "Folder", "attributes": {"N": 2, "S": "s", "B": true, "V": {"Vector3": [1, 2, 3]}}}'

			expect(snapshotJson(text)).toEqual(built({
				name = "Thing",
				className = "Folder",
				properties = { Attributes = { N = 2, S = "s", B = true, V = Vector3.new(1, 2, 3) } },
			}))
		end)

		it("replaces an Attributes property with attributes", function()
			local text =
				'{"className": "Folder", "properties": {"Attributes": {"A": {"Float64": 1}}}, "attributes": {"B": "x"}}'

			expect(snapshotJson(text)).toEqual(
				built({ name = "Thing", className = "Folder", properties = { Attributes = { B = "x" } } })
			)
		end)

		it("keeps an Attributes property when attributes is empty", function()
			local text =
				'{"className": "Folder", "properties": {"Attributes": {"A": {"Float64": 1}}}, "attributes": {}}'

			expect(snapshotJson(text)).toEqual(
				built({ name = "Thing", className = "Folder", properties = { Attributes = { A = 1 } } })
			)
		end)

		it("resolves a child's attributes", function()
			local text = '{"className": "Folder", "children": [{"className": "Folder", "attributes": {"C": 3}}]}'

			expect(snapshotJson(text)).toEqual(built({
				name = "Thing",
				className = "Folder",
				children = {
					snapshot({ name = "Folder", className = "Folder", properties = { Attributes = { C = 3 } } }),
				},
			}))
		end)

		it("keeps the top-level id as the Ref id and drops a child's", function()
			local text =
				'{"className": "Folder", "id": "top", "children": [{"className": "Folder", "name": "Child", "id": "child"}]}'

			expect(snapshotJson(text)).toEqual(built({
				name = "Thing",
				className = "Folder",
				id = "top",
				children = { snapshot({ name = "Child", className = "Folder" }) },
			}))
		end)

		for _, text in { "", " \n\t \r\n ", "\u{A0}\u{3000}" } do
			it(`gives no snapshot for the blank file {string.format("%q", text)}`, function()
				expect(snapshotJson(text)).toEqual({ ok = true })
			end)
		end

		it("reads no adjacent meta file", function()
			local files = {
				[JSON_PATH] = '{"className": "StringValue"}',
				["src/Thing.meta.json"] = '{"properties": {"Value": "from meta"}, "attributes": {"M": 1}}',
			}

			expect(snapshotJson("", files)).toEqual(built({ name = "Thing", className = "StringValue" }))
		end)

		for _, refusal in JSON_REFUSALS do
			it(`refuses {refusal[1]}, naming the file`, function()
				expect(snapshotJson(refusal[2])).toEqual(refused(JSON_PATH, refusal[3]))
			end)
		end

		for _, case in UNCREATABLE_CLASSES do
			it(`keeps {case[1]} as Rojo writes it, for the package's class check`, function()
				local result = snapshotJson(case[2])
				local model = result.value

				expect(result.ok).toBe(true)
				expect(if model.className == case[3] then model.className else model.children[1].className).toBe(
					case[3]
				)
			end)
		end

		it(
			"builds a DataModel model as Rojo does, for its parent to leave out (g-model-top, g-model-dm-badprop)",
			function()
				expect(snapshotJson('{"className": "DataModel", "children": [{"className": "NotAClass"}]}')).toEqual(
					built({
						name = "Thing",
						className = "DataModel",
						children = { snapshot({ name = "NotAClass", className = "NotAClass" }) },
					})
				)
				expect(
					snapshotJson(
						'{"className": "DataModel", "children": [{"className": "Folder", "properties": {"Nope": 1}}]}'
					)
				).toEqual(refused(JSON_PATH, "Unknown property Folder.Nope"))
			end
		)

		it("leaves out a DataModel child with a warning, as Studio's loader drops it (g-model-nested)", function()
			local text = '{"className": "Configuration", "children": [{"className": "Folder", "name": "A"}, '
				.. '{"className": "DataModel", "name": "DM", "children": [{"className": "Folder"}]}, '
				.. '{"className": "Folder", "name": "Z"}]}'

			expect(snapshotJson(text)).toEqual(built({
				name = "Thing",
				className = "Configuration",
				children = {
					snapshot({ name = "A", className = "Folder" }),
					snapshot({ name = "Z", className = "Folder" }),
				},
			}))
			expect(warnings).toEqual({
				`{JSON_PATH}: the DataModel "DM" is left out, as Studio's loader drops a DataModel below other instances`
					.. " with everything under it",
			})
		end)

		it("refuses a file that is not UTF-8", function()
			expect(snapshotJson('{"className": "Folder\255"}')).toEqual(refused(JSON_PATH, "File was not valid UTF-8"))
		end)

		it("passes on the error for a missing file", function()
			local fileSystem = VirtualFileSystem.fromFiles({})

			expect(PluginModelService:SnapshotJsonModel(fileSystem, JSON_PATH, "Thing")).toEqual(
				refused(JSON_PATH, "no such file")
			)
		end)
	end)

	describe("SnapshotBinaryModel (R1.11)", function()
		for _, case in BINARY_FORMATS do
			it(`loads a .{case.format} built by Rojo into a detached model named after the file`, function()
				local result = snapshotBinary(case.path, decode(case.model))
				local model = if result.ok then result.value.model else nil

				expect(result).toEqual({
					ok = true,
					value = {
						name = "Thing",
						className = "Model",
						properties = {},
						children = {},
						model = model,
						path = case.path,
					},
				})
				expect(model.Name).toBe("Thing")
				expect(model.ClassName).toBe("Model")
				expect(model.Parent).toBeNil()
			end)

			it(`keeps a .{case.format}'s properties, attributes, tags, descendants and Refs as decoded`, function()
				local model = snapshotBinary(case.path, decode(case.model)).value.model
				local children = model:GetChildren()

				expect(model:GetAttributes()).toEqual({ Label = "fast", Speed = 5 })
				expect(model:GetTags()).toEqual({ "Loaded", "Model" })
				expect(#children).toBe(#LOADED_CHILDREN)

				for index, child in children do
					expect({ child.Name, child.ClassName }).toEqual(LOADED_CHILDREN[index])
				end

				expect(model.Base.Anchored).toBe(true)
				expect(model.Base.Color).toEqual(Color3.fromRGB(255, 0, 0))
				expect(model.Base.Size).toEqual(Vector3.new(4, 1, 2))
				expect(model.Module.Source).toBe("return 1\n")
				expect(model.Pointer.Value).toBe(model.Base)
				expect(model.Pointer:GetAttribute("Rojo_Target_Value")).toBe("base")
				expect(model.Settings.Enabled.ClassName).toBe("BoolValue")
				expect(model.Settings.Enabled.Value).toBe(true)
			end)

			it(`reads no meta file beside a .{case.format}`, function()
				local files = {
					[case.path] = decode(case.model),
					["src/Thing.meta.json"] = '{"properties": {"Name": "Meta"}, "attributes": {"FromMeta": true}}',
				}
				local result = snapshotBinary(case.path, "", files)

				expect(result.value.name).toBe("Thing")
				expect(result.value.properties).toEqual({})
				expect(result.value.model.Name).toBe("Thing")
				expect(result.value.model:GetAttribute("FromMeta")).toBeNil()
			end)

			it(`keeps the model a .{case.format} loaded, which the destroyed check tells apart`, function()
				holdLoadedInstances()

				local model = snapshotBinary(case.path, decode(case.model)).value.model

				expect(held).toEqual({ model })
				expect(isDestroyed(model)).toBe(false)
			end)

			it(`refuses a .{case.format} with no top-level instance`, function()
				local contents = decode(if case.format == "rbxm" then fixture.rbxmEmpty else fixture.rbxmxEmpty)

				holdLoadedInstances()

				expect(snapshotBinary(case.path, contents)).toEqual(refused(case.path, ONE_INSTANCE))
				expect(held).toEqual({})
			end)

			it(`refuses a .{case.format} with two top-level instances and destroys both`, function()
				local contents = decode(if case.format == "rbxm" then fixture.rbxmPair else fixture.rbxmxPair)

				holdLoadedInstances()

				expect(snapshotBinary(case.path, contents)).toEqual(refused(case.path, ONE_INSTANCE))
				expect(#held).toBe(2)

				for _, instance in held do
					expect(isDestroyed(instance)).toBe(true)
				end
			end)

			for _, contents in { "not a model", "" } do
				it(`refuses a .{case.format} holding {string.format("%q", contents)} as malformed`, function()
					local result = snapshotBinary(case.path, contents)

					expect(result.ok).toBe(false)
					expect(result.error.path).toBe(case.path)
					expect(string.split(result.error.message, ": ")[1]).toBe(`Malformed {case.format} file`)
				end)
			end

			it(`refuses a .{case.format} holding the other format, as Rojo reads each with one decoder`, function()
				local result = snapshotBinary(case.path, decode(case.other))

				expect(result.ok).toBe(false)
				expect(result.error.path).toBe(case.path)
				expect(string.split(result.error.message, ": ")[1]).toBe(`Malformed {case.format} file`)
			end)

			it(`passes on the error for a missing .{case.format}`, function()
				expect(snapshotBinary(case.path, "", {})).toEqual(refused(case.path, "no such file"))
			end)
		end

		it("refuses a .rbxm that does not start with the binary header in rbx_binary's words", function()
			expect(snapshotBinary("src/Thing.rbxm", "not a model")).toEqual(
				refused("src/Thing.rbxm", "Malformed rbxm file: Invalid file header")
			)
		end)
	end)

	describe("KeepsChild", function()
		it("keeps a child of any class but DataModel", function()
			expect(PluginModelService:KeepsChild(snapshot({ name = "a", className = "Folder" }))).toBe(true)
			expect(PluginModelService:KeepsChild(snapshot({ name = "b", className = "Model" }))).toBe(true)
			expect(warnings).toEqual({})
		end)

		it("leaves out a DataModel with a warning naming its file, destroying any model under it", function()
			local model = Instance.new("Folder")
			local inner =
				{ name = "m", className = "Folder", properties = {}, children = {}, model = model, path = "x" }

			expect(
				PluginModelService:KeepsChild(snapshot({ name = "DM", className = "DataModel", children = { inner } }))
			).toBe(false)
			expect(isDestroyed(model)).toBe(true)
			expect(warnings).toEqual({
				`{JSON_PATH}: the DataModel "DM" is left out, as Studio's loader drops a DataModel below other instances`
					.. " with everything under it",
			})
		end)
	end)

	describe("DestroyModels", function()
		it("destroys the model of every snapshot in the list and below it, and nothing else", function()
			local top = Instance.new("Folder")
			local nested = Instance.new("Folder")
			local kept = Instance.new("Folder")
			local inner =
				{ name = "b", className = "Folder", properties = {}, children = {}, model = nested, path = "b" }
			local snapshots = {
				{ name = "a", className = "Folder", properties = {}, children = { inner }, model = top, path = "a" },
				{ name = "c", className = "Folder", properties = {}, children = {}, path = "c" },
			}

			table.insert(held, kept)

			PluginModelService:DestroyModels(snapshots)

			expect(isDestroyed(top)).toBe(true)
			expect(isDestroyed(nested)).toBe(true)
			expect(isDestroyed(kept)).toBe(false)
		end)
	end)
end)
