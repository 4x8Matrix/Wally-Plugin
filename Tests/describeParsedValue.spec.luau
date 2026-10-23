local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local decodeJsonc = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeJsonc)
local describeParsedValue = require(ReplicatedStorage.WallyPlugin.PluginUtilities.describeParsedValue)
local parseDataValue = require(ReplicatedStorage.WallyPlugin.PluginUtilities.parseDataValue)

local DESCRIPTIONS = {
	{ "[1, 2, 3]", "Array3([1.0, 2.0, 3.0])" },
	{ '["a"]', 'StringArray(["a"])' },
	{ "[0.1, 1e16, 1.5e-5, -0.0]", "Array4([0.1, 1e16, 1.5e-5, -0.0])" },
	{
		"[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 123456789.5]",
		"Array12([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 123456789.5])",
	},
	{ '["a\\"b", "c\\nd", "\\u00e9", "\\u0001"]', 'StringArray(["a\\"b", "c\\nd", "é", "\\u{1}"])' },
	{ "{}", "Attributes(Attributes { data: {} })" },
	{ '{"B": {"Bool": true}}', 'Attributes(Attributes { data: {"B": Bool(true)} })' },
	{
		'{"family": "x\\"y", "weight": "Bold", "style": "Normal"}',
		'Font(Font { family: "x\\"y", weight: Bold, style: Normal, cached_face_id: None })',
	},
	{
		'{"family": "x", "weight": "Bold", "style": "Normal", "cachedFaceId": "c"}',
		'Font(Font { family: "x", weight: Bold, style: Normal, cached_face_id: Some("c") })',
	},
	{ '{"Grass": [1, 2, 3]}', "MaterialColors(MaterialColors { inner: {Grass: Color3uint8 { r: 1, g: 2, b: 3 }} })" },
	{
		'{"F32": {"Float32": 0.1}, "F64": {"Float64": 1}, "I32": {"Int32": -3}, "I64": {"Int64": 4}, "S": {"String": "q\\""}, "V": {"Vector3": [1, 2, 3]}}',
		'Attributes(Attributes { data: {"F32": Float32(0.1), "F64": Float64(1.0), "I32": Int32(-3), "I64": Int64(4), "S": String("q\\""), "V": Vector3(Vector3 { x: 1.0, y: 2.0, z: 3.0 })} })',
	},
}

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("describeParsedValue", function()
	for _, description in DESCRIPTIONS do
		it(`prints {description[1]} as Rojo 7.7.1's refusal does`, function()
			local parsed = parseDataValue(decodeJsonc(description[1]).value)

			expect(parsed.ok).toBe(true)
			expect(describeParsedValue(parsed.value)).toBe(description[2])
		end)
	end
end)
