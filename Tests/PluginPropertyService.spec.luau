local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local PluginApplyService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginApplyService)
local PluginPropertyService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginPropertyService)

local decodeJsonc = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeJsonc)

local UNTAGGED = "data did not match any variant of untagged enum UnresolvedValue"
local MATERIAL_MEMBERS =
	"Air, Asphalt, Basalt, Brick, Cardboard, Carpet, CeramicTiles, ClayRoofTiles, Cobblestone, or 36 more"
local STRING_TYPES = "String, ContentId, Tags, Attributes, MaterialColors, or BinaryString"
local GOTHAM = "rbxasset://fonts/families/GothamSSm.json"
local CFRAME_JSON = '{"position": [1, 2, 3], "orientation": [[0, -1, 0], [1, 0, 0], [0, 0, 1]]}'
local ROTATED = CFrame.new(1, 2, 3, 0, -1, 0, 1, 0, 0, 0, 0, 1)
local NUMBER_SEQUENCE_JSON =
	'{"keypoints": [{"time": 0, "value": 1, "envelope": 0}, {"time": 1, "value": 2, "envelope": 0.5}]}'
local COLOR_SEQUENCE_JSON = '{"keypoints": [{"time": 0, "color": [1, 0, 0]}, {"time": 1, "color": [0, 0, 1]}]}'
local PHYSICAL = { 1, 0.5, 0.25, 1, 2, 0.75 }
local PHYSICAL_JSON =
	'{"density": 1, "friction": 0.5, "elasticity": 0.25, "frictionWeight": 1, "elasticityWeight": 2, "acousticAbsorption": 0.75}'

local EXPLICIT_FORMS = {
	{ "Axes", "ArcHandles", "Axes", '{"Axes": ["X", "Z", "X"]}', Axes.new(Enum.Axis.X, Enum.Axis.Z) },
	{ "BinaryString", "StringValue", "Value", '{"BinaryString": "aGk="}', "hi" },
	{ "BinaryString without padding", "StringValue", "Value", '{"BinaryString": "aGk"}', "hi" },
	{ "Bool", "BoolValue", "Value", '{"Bool": true}', true },
	{ "BrickColor", "BrickColorValue", "Value", '{"BrickColor": 21}', BrickColor.new(21) },
	{ "BrickColor on BasePart.BrickColor", "Part", "BrickColor", '{"BrickColor": 21}', BrickColor.new(21) },
	{ "CFrame", "CFrameValue", "Value", `\{"CFrame": {CFRAME_JSON}}`, ROTATED },
	{
		"CFrame as an array",
		"CFrameValue",
		"Value",
		'{"CFrame": [[1, 2, 3], [[0, -1, 0], [1, 0, 0], [0, 0, 1]]]}',
		ROTATED,
	},
	{
		"CFrame keeping a matrix that is not a rotation",
		"CFrameValue",
		"Value",
		'{"CFrame": {"position": [0, 0, 0], "orientation": [[2, 0, 0], [0, 1, 0.5], [0, 0, 1]]}}',
		CFrame.new(0, 0, 0, 2, 0, 0, 0, 1, 0.5, 0, 0, 1),
	},
	{
		"CFrame ignoring an unknown field",
		"CFrameValue",
		"Value",
		'{"CFrame": {"position": [1, 2, 3], "orientation": [[1, 0, 0], [0, 1, 0], [0, 0, 1]], "extra": 1}}',
		CFrame.new(1, 2, 3),
	},
	{ "Color3", "Color3Value", "Value", '{"Color3": [0.25, 0.5, 0.75]}', Color3.new(0.25, 0.5, 0.75) },
	{ "Color3uint8", "Part", "Color", '{"Color3uint8": [255, 128, 0]}', Color3.fromRGB(255, 128, 0) },
	{
		"Color3 on BasePart.Color, as the bytes Rojo writes",
		"Part",
		"Color",
		'{"Color3": [1, 0.5, 0]}',
		Color3.fromRGB(255, 128, 0),
	},
	{
		"ColorSequence",
		"Beam",
		"Color",
		`\{"ColorSequence": {COLOR_SEQUENCE_JSON}}`,
		ColorSequence.new(Color3.new(1, 0, 0), Color3.new(0, 0, 1)),
	},
	{
		"ColorSequence Studio would not build, as the white sequence it loads",
		"Beam",
		"Color",
		'{"ColorSequence": {"keypoints": [{"time": 0.5, "color": [1, 0, 0]}]}}',
		ColorSequence.new(Color3.new(1, 1, 1)),
	},
	{
		"Content from a URI",
		"ImageLabel",
		"ImageContent",
		'{"Content": {"Uri": "rbxassetid://123"}}',
		Content.fromUri("rbxassetid://123"),
	},
	{ "Content None", "ImageLabel", "ImageContent", '{"Content": "None"}', Content.none },
	{
		"Content naming an object, as None",
		"ImageLabel",
		"ImageContent",
		'{"Content": {"Object": "0123456789abcdef0123456789abcdef"}}',
		Content.none,
	},
	{ "ContentId", "Decal", "Texture", '{"ContentId": "rbxassetid://456"}', "rbxassetid://456" },
	{
		"ContentId on a String property",
		"StringValue",
		"Value",
		'{"ContentId": "rbxassetid://457"}',
		"rbxassetid://457",
	},
	{ "Enum", "Part", "Material", '{"Enum": 512}', Enum.Material.Wood },
	{ "Enum on a property Rojo migrates", "TextLabel", "Font", '{"Enum": 18}', Enum.Font.GothamMedium },
	{ "EnumItem", "Part", "Material", '{"EnumItem": {"type": "Material", "value": 800}}', Enum.Material.Slate },
	{
		"EnumItem by the property's enum, whatever its type",
		"Part",
		"Material",
		'{"EnumItem": {"type": "PartType", "value": 816}}',
		Enum.Material.Concrete,
	},
	{
		"Faces",
		"Handles",
		"Faces",
		'{"Faces": ["Right", "Top", "Front"]}',
		Faces.new(Enum.NormalId.Right, Enum.NormalId.Top, Enum.NormalId.Front),
	},
	{ "Float32, rounded to single precision", "Part", "Transparency", '{"Float32": 0.1}', 0.10000000149011612 },
	{ "Float64", "NumberValue", "Value", '{"Float64": 0.1}', 0.1 },
	{ "Float32 on a Float64 property", "NumberValue", "Value", '{"Float32": 0.1}', 0.10000000149011612 },
	{
		"Font",
		"TextLabel",
		"FontFace",
		`\{"Font": \{"family": "{GOTHAM}", "weight": "Bold", "style": "Italic"}}`,
		Font.new(GOTHAM, Enum.FontWeight.Bold, Enum.FontStyle.Italic),
	},
	{
		"Font with a cached face",
		"TextLabel",
		"FontFace",
		`\{"Font": \{"family": "{GOTHAM}", "weight": "Bold", "style": "Italic", "cachedFaceId": "rbxasset://fonts/GothamSSm-Bold.otf"}}`,
		Font.new(GOTHAM, Enum.FontWeight.Bold, Enum.FontStyle.Italic),
	},
	{ "Int32", "Frame", "LayoutOrder", '{"Int32": 5}', 5 },
	{ "Int32 on an Int64 property", "IntValue", "Value", '{"Int32": 7}', 7 },
	{ "Int32 on a BrickColor property", "BrickColorValue", "Value", '{"Int32": 21}', BrickColor.new(21) },
	{ "Int64", "IntValue", "Value", '{"Int64": 123456789012}', 123456789012 },
	{ "NumberRange", "ParticleEmitter", "Lifetime", '{"NumberRange": [1, 2.5]}', NumberRange.new(1, 2.5) },
	{
		"NumberSequence",
		"ParticleEmitter",
		"Size",
		`\{"NumberSequence": {NUMBER_SEQUENCE_JSON}}`,
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1, 0), NumberSequenceKeypoint.new(1, 2, 0.5) }),
	},
	{
		"NumberSequence Studio would not build, as the zero sequence it loads",
		"ParticleEmitter",
		"Size",
		'{"NumberSequence": {"keypoints": [{"time": 1, "value": 1, "envelope": 0}, {"time": 0, "value": 2, "envelope": 0}]}}',
		NumberSequence.new(0),
	},
	{
		"PhysicalProperties",
		"Part",
		"CustomPhysicalProperties",
		`\{"PhysicalProperties": {PHYSICAL_JSON}}`,
		PhysicalProperties.new(table.unpack(PHYSICAL)),
	},
	{
		"Ray",
		"RayValue",
		"Value",
		'{"Ray": {"origin": [1, 2, 3], "direction": [0, 0, -1]}}',
		Ray.new(Vector3.new(1, 2, 3), Vector3.new(0, 0, -1)),
	},
	{
		"Ray as an array",
		"RayValue",
		"Value",
		'{"Ray": [[1, 2, 3], [0, 0, -1]]}',
		Ray.new(Vector3.new(1, 2, 3), Vector3.new(0, 0, -1)),
	},
	{ "Rect", "ImageLabel", "SliceCenter", '{"Rect": [[1, 2], [3, 4]]}', Rect.new(1, 2, 3, 4) },
	{ "String", "StringValue", "Value", '{"String": "hello"}', "hello" },
	{ "UDim", "UIPadding", "PaddingTop", '{"UDim": [0.5, 4]}', UDim.new(0.5, 4) },
	{ "UDim on a property Rojo migrates", "UICorner", "CornerRadius", '{"UDim": [0.25, 3]}', UDim.new(0.25, 3) },
	{ "UDim2", "Frame", "Size", '{"UDim2": [[0.5, 10], [1, -20]]}', UDim2.new(0.5, 10, 1, -20) },
	{ "Vector2", "UIGradient", "Offset", '{"Vector2": [0.5, 0.25]}', Vector2.new(0.5, 0.25) },
	{ "Vector3", "Vector3Value", "Value", '{"Vector3": [1.5, 2, 3]}', Vector3.new(1.5, 2, 3) },
	{ "Bool on a property Rojo migrates", "ScreenGui", "IgnoreGuiInset", '{"Bool": true}', true },
}

local NIL_FORMS = {
	{ "PhysicalProperties Default", "Part", "CustomPhysicalProperties", '{"PhysicalProperties": "Default"}' },
	{ "a nil Ref", "ObjectValue", "Value", '{"Ref": "00000000000000000000000000000000"}' },
	{
		"a raw Ref, which points at nothing in Rojo's build",
		"ObjectValue",
		"Value",
		'{"Ref": "0123456789abcdef0123456789abcdef"}',
	},
	{ "a raw Ref of one digit", "ObjectValue", "Value", '{"Ref": "1"}' },
}

local SKIPPED_FORMS = {
	{ "an Enum value with no item, which Studio loads as the default", "Part", "Material", '{"Enum": 7}' },
	{ "UniqueId, which a plugin cannot set", "Folder", "UniqueId", '{"UniqueId": "0123456789abcdef0123456789abcdef"}' },
	{ "OptionalCFrame, which a plugin cannot set", "Model", "WorldPivotData", `\{"OptionalCFrame": {CFRAME_JSON}}` },
	{ "a null OptionalCFrame", "Model", "WorldPivotData", '{"OptionalCFrame": null}' },
	{
		"SecurityCapabilities, whose bits Studio reads differently",
		"Folder",
		"Capabilities",
		'{"SecurityCapabilities": 3}',
	},
	{ "Vector3int16, which a plugin cannot set", "TerrainRegion", "ExtentsMax", '{"Vector3int16": [1, -2, 3]}' },
	{
		"a reversed NumberRange, which a plugin cannot construct",
		"ParticleEmitter",
		"Lifetime",
		'{"NumberRange": [3, 1]}',
	},
	{ "an explicit value for a property Studio does not know", "Folder", "Bogus", '{"Float64": 1}' },
	{
		"MaterialColors for a property Studio does not know",
		"Folder",
		"Bogus",
		'{"MaterialColors": {"Grass": [1, 2, 3]}}',
	},
	{ "an implicit value for an alias a plugin cannot set", "Part", "size", "[1, 2, 3]" },
	{ "SharedString, which a plugin cannot set", "Model", "ModelMeshData", '{"SharedString": "aGk="}' },
	{ "NetAssetRef, which a plugin cannot set", "MeshPart", "SolidMeshHolder", '{"NetAssetRef": "aGk="}' },
	{ "NetAssetRef on a SharedString property", "Model", "ModelMeshData", '{"NetAssetRef": "aGk="}' },
}

local MISMATCHES = {
	{ "EqualizerSoundEffect", "HighGain", '{"Float64": 1}', "Float32", "Float64" },
	{ "Part", "Transparency", '{"Float64": 0.5}', "Float32", "Float64" },
	{ "Frame", "LayoutOrder", '{"Int64": 7}', "Int32", "Int64" },
	{ "Color3Value", "Value", '{"Color3uint8": [1, 2, 3]}', "Color3", "Color3uint8" },
	{ "Part", "Color", '{"Vector3": [1, 0, 0]}', "Color3uint8 or Color3", "Vector3" },
	{ "StringValue", "Value", '{"Bool": true}', STRING_TYPES, "Bool" },
	{ "StringValue", "Value", '{"SharedString": "aGk="}', STRING_TYPES, "SharedString" },
	{ "StringValue", "Value", '{"Enum": 1}', STRING_TYPES, "Enum" },
	{ "Part", "Material", '{"Int32": 256}', "Enum or EnumItem", "Int32" },
	{ "CFrameValue", "Value", '{"Vector3": [1, 2, 3]}', "CFrame", "Vector3" },
	{ "Folder", "Tags", '{"String": "a"}', "Tags", "String" },
}

local SHARED_STRING_PROPERTIES = {
	{ "FeatureMatchingTable", "Data", "SharedString" },
	{ "MeshPart", "SolidMeshHolder", "NetAssetRef" },
	{ "Model", "ModelMeshData", "SharedString" },
	{ "Model", "SlimHash", "SharedString" },
	{ "PartOperation", "ChildData2", "SharedString" },
	{ "PartOperation", "ManifoldMesh_DEPRECATED", "SharedString" },
	{ "PartOperation", "MeshData2", "SharedString" },
	{ "PartOperation", "SolidMeshHolder", "NetAssetRef" },
}

local UNSUPPORTED = {
	{ "Region3", '{"Region3": [[0, 0, 0], [1, 1, 1]]}' },
	{ "Region3int16", '{"Region3int16": [[0, 0, 0], [1, 1, 1]]}' },
	{ "Vector2int16", '{"Vector2int16": [1, 2]}' },
	{ "EnumItem", '{"EnumItem": {"type": "Material", "value": 256}}' },
	{ "Attributes", '{"Attributes": {}}' },
}

local IMPLICIT_FORMS = {
	{ "an enum item by name", "Part", "Material", '"Wood"', Enum.Material.Wood },
	{ "a PartType item by name", "Part", "Shape", '"Ball"', Enum.PartType.Ball },
	{ "Bool", "Part", "Anchored", "true", true },
	{ "Float32, rounded to single precision", "Part", "Transparency", "0.1", 0.10000000149011612 },
	{ "Float64", "NumberValue", "Value", "0.1", 0.1 },
	{ "Int32, truncated", "Frame", "LayoutOrder", "1.9", 1 },
	{ "Int32, truncated toward zero", "Frame", "LayoutOrder", "-1.9", -1 },
	{ "Int32, saturated", "Frame", "LayoutOrder", "3000000000", 2147483647 },
	{ "Int64, truncated toward zero", "IntValue", "Value", "-2.5", -2 },
	{ "Int64", "IntValue", "Value", "123456789012", 123456789012 },
	{ "String", "StringValue", "Value", '"hello"', "hello" },
	{ "ProtectedString", "ModuleScript", "Source", '"return 1"', "return 1" },
	{ "Content from a string", "ImageLabel", "ImageContent", '"rbxassetid://1"', Content.fromUri("rbxassetid://1") },
	{ "Content from an empty string, as None", "ImageLabel", "ImageContent", '""', Content.none },
	{ "ContentId", "Decal", "Texture", '"rbxassetid://2"', "rbxassetid://2" },
	{ "ContentId on a property Rojo migrates", "ImageLabel", "Image", '"rbxassetid://3"', "rbxassetid://3" },
	{ "Vector2", "UIGradient", "Offset", "[1, 2]", Vector2.new(1, 2) },
	{ "Vector3", "Vector3Value", "Value", "[1, 2, 3]", Vector3.new(1, 2, 3) },
	{ "Color3", "Color3Value", "Value", "[1, 0.5, 0]", Color3.new(1, 0.5, 0) },
	{
		"Color3 on BasePart.Color, as the bytes Rojo writes",
		"Part",
		"Color",
		"[1, 0.5, 0]",
		Color3.fromRGB(255, 128, 0),
	},
	{ "Color3 on BasePart.Color, clamped", "Part", "Color", "[2, -1, 0.002]", Color3.fromRGB(255, 0, 1) },
	{ "CFrame from twelve numbers", "CFrameValue", "Value", "[1, 2, 3, 0, -1, 0, 1, 0, 0, 0, 0, 1]", ROTATED },
	{
		"Font",
		"TextLabel",
		"FontFace",
		'{"family": "rbxasset://fonts/families/Arial.json", "weight": "Bold", "style": "Normal"}',
		Font.new("rbxasset://fonts/families/Arial.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
	},
}

local IMPLICIT_REFUSALS = {
	{
		"Part",
		"Material",
		'"Woood"',
		`Invalid value for property Part.Material. Got Woood but expected a member of the Material enum such as {MATERIAL_MEMBERS}`,
	},
	{
		"Part",
		"Material",
		"512",
		`Invalid value for property Part.Material. Got a number but expected a member of the Material enum such as {MATERIAL_MEMBERS}`,
	},
	{
		"Part",
		"Material",
		"true",
		`Invalid value for property Part.Material. Got a bool but expected a member of the Material enum such as {MATERIAL_MEMBERS}`,
	},
	{
		"Part",
		"Shape",
		'"Bal"',
		"Invalid value for property Part.Shape. Got Bal but expected a member of the PartType enum such as Ball, Block, CornerWedge, Cylinder, or Wedge",
	},
	{
		"Part",
		"Shape",
		"[1, 2]",
		"Invalid value for property Part.Shape. Got an array of two numbers but expected a member of the PartType enum such as Ball, Block, CornerWedge, Cylinder, or Wedge",
	},
	{
		"ObjectValue",
		"Value",
		'"x"',
		"Cannot resolve Ref properties as a String.Use an attribute named `Rojo_Target_Value",
	},
	{
		"Frame",
		"Size",
		"[1, 2, 3, 4]",
		"Wrong type of value for property Frame.Size. Expected UDim2, got an array of four numbers",
	},
	{
		"UIPadding",
		"PaddingTop",
		"[1, 2]",
		"Wrong type of value for property UIPadding.PaddingTop. Expected UDim, got an array of two numbers",
	},
	{ "Part", "Anchored", '"yes"', "Wrong type of value for property Part.Anchored. Expected Bool, got a string" },
	{
		"Part",
		"Anchored",
		'["a"]',
		"Wrong type of value for property Part.Anchored. Expected Bool, got an array of strings",
	},
	{
		"Part",
		"Anchored",
		'{"Grass": [1, 2, 3]}',
		"Wrong type of value for property Part.Anchored. Expected Bool, got an object describing MaterialColors",
	},
	{
		"Part",
		"Anchored",
		'{"family": "x", "weight": "Bold", "style": "Normal"}',
		"Wrong type of value for property Part.Anchored. Expected Bool, got an object describing a Font",
	},
	{
		"StringValue",
		"Value",
		"[1, 2, 3]",
		"Wrong type of value for property StringValue.Value. Expected String, got an array of three numbers",
	},
	{
		"Vector3Value",
		"Value",
		"[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]",
		"Wrong type of value for property Vector3Value.Value. Expected Vector3, got an array of twelve numbers",
	},
	{
		"TextLabel",
		"FontFace",
		"{}",
		"Wrong type of value for property TextLabel.FontFace. Expected Font, got an object containing attributes",
	},
	{
		"Part",
		"Color3uint8",
		"[1, 0.5, 0]",
		"Wrong type of value for property Part.Color3uint8. Expected Color3uint8, got an array of three numbers",
	},
	{ "Part", "Bogus", "1", "Unknown property Part.Bogus" },
	{ "NotAClass", "Value", "1", "Unknown property NotAClass.Value" },
}

local AMBIGUOUS_ATTRIBUTES = {
	{ "[1, 2, 3]", "Array3([1.0, 2.0, 3.0])" },
	{ '["a"]', 'StringArray(["a"])' },
}

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local applyReporter = PluginApplyService.Reporter
local reporter = PluginPropertyService.Reporter
local warnings = {}

local function decode(text: string): any
	local decoded = decodeJsonc(text)

	assert(decoded.ok, text)

	return decoded.value
end

local function resolve(className: string, propertyName: string, text: string)
	return PluginPropertyService:ResolveProperty(className, propertyName, decode(text))
end

local function attributes(text: string)
	return PluginPropertyService:ResolveAttributes(decode(text))
end

local function object(entries: { string }): string
	return `\{{table.concat(entries, ", ")}}`
end

local function held(className: string, propertyName: string, value: any): any
	local instance = Instance.new(className)
	local applied = PluginApplyService:Apply(instance, { [propertyName] = value })
	local result = instance[propertyName]

	instance:Destroy()
	expect(applied).toEqual({ ok = true })

	return result
end

local function refusal(message: string)
	return { ok = false, error = { path = "", message = message } }
end

describe("PluginPropertyService", function()
	beforeEach(function()
		table.clear(warnings)

		PluginPropertyService.Reporter = {
			Warn = function(_, message: string)
				table.insert(warnings, message)
			end,
		}
		PluginApplyService.Reporter = PluginPropertyService.Reporter
	end)

	afterEach(function()
		PluginPropertyService.Reporter = reporter
		PluginApplyService.Reporter = applyReporter
	end)

	describe("explicit values (R3.3)", function()
		for _, form in EXPLICIT_FORMS do
			it(`resolves {form[1]} to the value Studio holds for Rojo's build`, function()
				local resolved = resolve(form[2], form[3], form[4])

				expect(resolved).toEqual({ ok = true, value = form[5] })
				expect(held(form[2], form[3], resolved.value)).toEqual(form[5])
				expect(warnings).toEqual({})
			end)
		end

		it(
			"resolves Tags on a String property as Rojo writes them, which a plugin's assignment cuts at the NUL",
			function()
				local resolved = resolve("StringValue", "Value", '{"Tags": ["a", "b"]}')

				expect(resolved).toEqual({ ok = true, value = "a\0b" })
				expect(held("StringValue", "Value", resolved.value)).toBe("a")
			end
		)

		for _, form in NIL_FORMS do
			it(`resolves {form[1]} to nil`, function()
				local resolved = resolve(form[2], form[3], form[4])

				expect(resolved).toEqual({ ok = true, value = PluginPropertyService.Nil })
				expect(held(form[2], form[3], resolved.value)).toBe(nil)
			end)
		end

		for _, form in SKIPPED_FORMS do
			it(`leaves out {form[1]} with a warning`, function()
				expect(resolve(form[2], form[3], form[4])).toEqual({ ok = true })
				expect(#warnings).toBe(1)
			end)
		end

		it("refuses a value Rojo cannot parse in serde's words, before it looks at the property", function()
			expect(resolve("BrickColorValue", "Value", '{"BrickColor": 4}')).toEqual(refusal(UNTAGGED))
			expect(resolve("Part", "Anchored", "null")).toEqual(refusal(UNTAGGED))
			expect(resolve("NotAClass", "Bogus", "[[1]]")).toEqual(refusal(UNTAGGED))
		end)

		for _, mismatch in MISMATCHES do
			it(`refuses {mismatch[5]} on {mismatch[1]}.{mismatch[2]} as Rojo's writer does`, function()
				expect(resolve(mismatch[1], mismatch[2], mismatch[3])).toEqual(
					refusal(
						`Property type mismatch: Expected {mismatch[1]}.{mismatch[2]} to be of type {mismatch[4]}, but it was of type {mismatch[5]}`
					)
				)
			end)
		end

		it(
			"has no positive SharedString or NetAssetRef case, as no property of either is writable from a plugin",
			function()
				for _, property in SHARED_STRING_PROPERTIES do
					local variant = if property[3] == "NetAssetRef" then "NetAssetRef" else "SharedString"

					expect(resolve(property[1], property[2], `\{"{variant}": "aGk="}`)).toEqual({ ok = true })
				end

				expect(#warnings).toBe(#SHARED_STRING_PROPERTIES)
			end
		)

		for _, unsupported in UNSUPPORTED do
			it(
				`refuses {unsupported[1]} for a property Studio does not know, which Rojo's writer has no type for`,
				function()
					expect(resolve("Folder", "Bogus", unsupported[2])).toEqual(
						refusal(`Unsupported property type: Folder.Bogus is of type {unsupported[1]}`)
					)
				end
			)
		end
	end)

	describe("implicit values (R3.4)", function()
		for _, form in IMPLICIT_FORMS do
			it(`resolves {form[1]} to the value Studio holds for Rojo's build`, function()
				local resolved = resolve(form[2], form[3], form[4])

				expect(resolved).toEqual({ ok = true, value = form[5] })
				expect(held(form[2], form[3], resolved.value)).toEqual(form[5])
			end)
		end

		for _, refused in IMPLICIT_REFUSALS do
			it(`refuses {refused[3]} for {refused[1]}.{refused[2]} in Rojo's words`, function()
				expect(resolve(refused[1], refused[2], refused[3])).toEqual(refusal(refused[4]))
			end)
		end

		it(
			"resolves MaterialColors and refuses an unknown material, then leaves Terrain's out as a plugin cannot set it",
			function()
				expect(resolve("Terrain", "MaterialColors", '{"Grass": [1, 2, 3], "Rock": [4, 5, 6]}')).toEqual({
					ok = true,
				})
				expect(resolve("Terrain", "MaterialColors", '{"MaterialColors": {"Grass": [1, 2, 3]}}')).toEqual({
					ok = true,
				})
				expect(#warnings).toBe(2)
				expect(resolve("Terrain", "MaterialColors", '{"Plastic": [1, 2, 3]}')).toEqual(refusal(UNTAGGED))
				expect(resolve("Terrain", "MaterialColors", '{"Grass": [256, 2, 3]}')).toEqual(refusal(UNTAGGED))
			end
		)
	end)

	describe("attributes (R3.5)", function()
		it("resolves an implicit bool, number and string", function()
			expect(attributes('{"A": true, "B": 5.5, "C": "s"}')).toEqual({
				ok = true,
				value = { A = true, B = 5.5, C = "s" },
			})
		end)

		it("resolves every explicit type the attribute writer supports to what Studio loads", function()
			local resolved = attributes(object({
				'"B": {"Bool": true}',
				'"BC": {"BrickColor": 21}',
				'"BS": {"BinaryString": "aGk="}',
				'"C3": {"Color3": [0.25, 0.5, 1]}',
				`"CF": \{"CFrame": {CFRAME_JSON}}`,
				`"CS": \{"ColorSequence": {COLOR_SEQUENCE_JSON}}`,
				'"EI": {"EnumItem": {"type": "Material", "value": 256}}',
				'"F32": {"Float32": 0.1}',
				'"F64": {"Float64": 0.1}',
				`"Fo": \{"Font": \{"family": "{GOTHAM}", "weight": "Bold", "style": "Italic"}}`,
				'"NR": {"NumberRange": [1, 2.5]}',
				`"NS": \{"NumberSequence": {NUMBER_SEQUENCE_JSON}}`,
				'"R": {"Rect": [[1, 2], [3, 4]]}',
				'"S": {"String": "t"}',
				'"U": {"UDim": [0.5, 4]}',
				'"U2": {"UDim2": [[0.5, 10], [1, -20]]}',
				'"V2": {"Vector2": [0.5, 0.25]}',
				'"V3": {"Vector3": [1, 2, 3]}',
			}))

			expect(resolved).toEqual({
				ok = true,
				value = {
					B = true,
					BC = BrickColor.new(21),
					BS = "hi",
					C3 = Color3.new(0.25, 0.5, 1),
					CF = ROTATED,
					CS = ColorSequence.new(Color3.new(1, 0, 0), Color3.new(0, 0, 1)),
					EI = Enum.Material.Plastic,
					F32 = 0.10000000149011612,
					F64 = 0.1,
					Fo = Font.new(GOTHAM, Enum.FontWeight.Bold, Enum.FontStyle.Italic),
					NR = NumberRange.new(1, 2.5),
					NS = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1, 0),
						NumberSequenceKeypoint.new(1, 2, 0.5),
					}),
					R = Rect.new(1, 2, 3, 4),
					S = "t",
					U = UDim.new(0.5, 4),
					U2 = UDim2.new(0.5, 10, 1, -20),
					V2 = Vector2.new(0.5, 0.25),
					V3 = Vector3.new(1, 2, 3),
				},
			})
		end)

		it("gives sequences Studio would not build the defaults it loads", function()
			expect(attributes(object({
				'"C": {"ColorSequence": {"keypoints": [{"time": 0.5, "color": [1, 0, 0]}]}}',
				'"N": {"NumberSequence": {"keypoints": []}}',
			}))).toEqual({
				ok = true,
				value = { C = ColorSequence.new(Color3.new(1, 1, 1)), N = NumberSequence.new(0) },
			})
		end)

		it("leaves out with a warning the attributes Studio drops when it loads Rojo's build", function()
			expect(attributes(object({
				'"Int": {"Int32": 3}',
				'"Kept": true',
				'"NoEnum": {"EnumItem": {"type": "NotAnEnum", "value": 1}}',
				'"NoItem": {"EnumItem": {"type": "Material", "value": 7}}',
				'"Reversed": {"NumberRange": [3, 1]}',
			}))).toEqual({ ok = true, value = { Kept = true } })
			expect(#warnings).toBe(4)
		end)

		for _, ambiguous in AMBIGUOUS_ATTRIBUTES do
			it(`refuses {ambiguous[1]}, which no single type fits, in Rojo's words`, function()
				expect(attributes(`\{"A": {ambiguous[1]}}`)).toEqual(
					refusal(`Cannot unambiguously resolve the value {ambiguous[2]}`)
				)
			end)
		end

		it("refuses types the attribute writer does not support, and values that do not parse", function()
			expect(attributes('{"A": {"Int64": 5}}')).toEqual(refusal("Int64 values are not supported in attributes"))
			expect(attributes('{"A": {"Content": {"Uri": "x"}}}')).toEqual(
				refusal("Content values are not supported in attributes")
			)
			expect(attributes('{"A": {"Faces": ["Top"]}}')).toEqual(
				refusal("Faces values are not supported in attributes")
			)
			expect(attributes('{"A": null}')).toEqual(refusal(UNTAGGED))
		end)

		it("resolves the Attributes property from explicit values only, implicit or explicit", function()
			expect(resolve("Folder", "Attributes", '{"A": {"Bool": true}, "B": {"Vector3": [1, 2, 3]}}')).toEqual({
				ok = true,
				value = { A = true, B = Vector3.new(1, 2, 3) },
			})
			expect(
				resolve(
					"Folder",
					"Attributes",
					'{"Attributes": {"Health": {"Float64": 100}, "Label": {"String": "x"}}}'
				)
			).toEqual({
				ok = true,
				value = { Health = 100, Label = "x" },
			})
			expect(resolve("Folder", "Attributes", "{}")).toEqual({ ok = true, value = {} })
			expect(resolve("Folder", "Attributes", '{"A": true}')).toEqual(refusal(UNTAGGED))
			expect(resolve("Folder", "Attributes", '{"A": {"Int64": 1}}')).toEqual(
				refusal("Int64 values are not supported in attributes")
			)
		end)
	end)

	describe("tags (R3.6)", function()
		it("resolves Tags from an array of strings, implicit or explicit, keeping repeats", function()
			expect(resolve("Folder", "Tags", '["a", "b", "a"]')).toEqual({ ok = true, value = { "a", "b", "a" } })
			expect(resolve("Folder", "Tags", '{"Tags": ["a", "b", "a"]}')).toEqual({
				ok = true,
				value = { "a", "b", "a" },
			})
			expect(resolve("Folder", "Tags", "[]")).toEqual({ ok = true, value = {} })
			expect(resolve("Folder", "Tags", "[1]")).toEqual(refusal(UNTAGGED))
			expect(resolve("Folder", "Tags", '["a", 1]')).toEqual(refusal(UNTAGGED))
		end)
	end)

	describe("Name and Parent", function()
		it("resolves them as Rojo does, then leaves them out with a warning", function()
			expect(resolve("Folder", "Name", '"Other"')).toEqual({ ok = true })
			expect(resolve("Folder", "Parent", '{"Ref": "00000000000000000000000000000000"}')).toEqual({ ok = true })
			expect(#warnings).toBe(2)
			expect(resolve("Folder", "Parent", '"x"')).toEqual(
				refusal("Cannot resolve Ref properties as a String.Use an attribute named `Rojo_Target_Parent")
			)
		end)
	end)

	describe("LocalizationTable", function()
		it("resolves Contents, which PluginApplyService sets with SetContents as assigning it fails", function()
			expect(resolve("LocalizationTable", "Contents", '"[]"')).toEqual({ ok = true, value = "[]" })
			expect(resolve("LocalizationTable", "Contents", '{"String": "[]"}')).toEqual({ ok = true, value = "[]" })
		end)
	end)

	describe("ResolveProperties", function()
		it("resolves properties in key order, then a non-empty attribute map as Attributes", function()
			local properties = decode('{"Value": "v", "Name": "n", "Bogus": {"Bool": true}}')

			expect(PluginPropertyService:ResolveProperties("StringValue", properties, decode('{"A": 1}'))).toEqual({
				ok = true,
				value = {
					{ name = "Bogus" },
					{ name = "Name" },
					{ name = "Value", value = "v" },
					{ name = "Attributes", value = { A = 1 } },
				},
			})
			expect(#warnings).toBe(2)
		end)

		it("leaves out an empty attribute map", function()
			expect(PluginPropertyService:ResolveProperties("Folder", decode("{}"), decode("{}"))).toEqual({
				ok = true,
				value = {},
			})
		end)

		it("refuses in Rojo's words, naming the project a refusal came from when given one", function()
			local bogus = decode('{"Bogus": 1}')
			local int64 = decode('{"A": {"Int64": 5}}')

			expect(PluginPropertyService:ResolveProperties("Part", bogus, int64)).toEqual(
				refusal("Unknown property Part.Bogus")
			)
			expect(PluginPropertyService:ResolveProperties("Part", bogus, int64, "project")).toEqual(
				refusal("Unresolvable property in project: Unknown property Part.Bogus")
			)
			expect(PluginPropertyService:ResolveProperties("Part", decode("{}"), int64)).toEqual(
				refusal("Int64 values are not supported in attributes")
			)
			expect(PluginPropertyService:ResolveProperties("Part", decode("{}"), int64, "project")).toEqual(
				refusal("Unresolvable attribute in project: Int64 values are not supported in attributes")
			)
		end)
	end)
end)
