local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local decodeJsonc = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeJsonc)
local parseDataValue = require(ReplicatedStorage.WallyPlugin.PluginUtilities.parseDataValue)

local UNTAGGED =
	{ ok = false, error = { path = "", message = "data did not match any variant of untagged enum UnresolvedValue" } }

local MALFORMED_EXPLICIT = {
	{ "BinaryString outside the base64 alphabet", '{"BinaryString": "a!b="}' },
	{ "BinaryString with stray bits", '{"BinaryString": "YR=="}' },
	{ "BrickColor that is not a palette number", '{"BrickColor": 4}' },
	{ "Color3uint8 above 255", '{"Color3uint8": [256, 0, 0]}' },
	{ "Color3uint8 with a fraction", '{"Color3uint8": [1.5, 0, 0]}' },
	{ "Content as a bare URI", '{"Content": "rbxassetid://1"}' },
	{ "Content naming an object that is not hexadecimal", '{"Content": {"Object": "zz"}}' },
	{ "Enum above 32 bits", '{"Enum": 4294967296}' },
	{ "Font without a weight", '{"Font": {"family": "x", "style": "Italic"}}' },
	{ "Font with an unknown weight", '{"Font": {"family": "x", "weight": "Black", "style": "Normal"}}' },
	{ "Int32 with a fraction", '{"Int32": 1.5}' },
	{ "Int32 out of range", '{"Int32": 3000000000}' },
	{
		"PhysicalProperties without acousticAbsorption",
		'{"PhysicalProperties": {"density": 1, "friction": 0.5, "elasticity": 0.25, "frictionWeight": 1, "elasticityWeight": 2}}',
	},
	{ "Ref that is not hexadecimal", '{"Ref": "zz"}' },
	{ "UDim with a fractional offset", '{"UDim": [0.5, 4.5]}' },
	{ "UniqueId of the wrong length", '{"UniqueId": "xyz"}' },
	{ "Axes naming an unknown axis", '{"Axes": ["W"]}' },
	{ "Vector3 of two numbers", '{"Vector3": [1, 2]}' },
	{ "Vector3 of four numbers", '{"Vector3": [1, 2, 3, 4]}' },
	{ "an explicit value with a second key", '{"Vector3": [1, 2, 3], "Bool": true}' },
	{ "Bool that is not a bool", '{"Bool": "yes"}' },
}

local UNPARSABLE =
	{ "null", "[[1]]", '[1, "a"]', "[1, 2, 3, 4, 5]", '{"Grass": [256, 2, 3]}', '{"Plastic": [1, 2, 3]}' }

local IMPLICIT_FORMS = {
	{ "true", "Bool", true },
	{ '"a"', "String", "a" },
	{ "[]", "StringArray", {} },
	{ '["a", "b"]', "StringArray", { "a", "b" } },
	{ "1.5", "Number", 1.5 },
	{ "[1, 2]", "Array2", { 1, 2 } },
	{ "[1, 2, 3]", "Array3", { 1, 2, 3 } },
	{ "[1, 2, 3, 4]", "Array4", { 1, 2, 3, 4 } },
	{ "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]", "Array12", { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 } },
	{ '{"Grass": [1, 2, 3]}', "MaterialColors", { Grass = { 1, 2, 3 } } },
}

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function parse(text: string)
	local decoded = decodeJsonc(text)

	assert(decoded.ok, text)

	return parseDataValue(decoded.value)
end

describe("parseDataValue", function()
	it("reads an explicit value as its variant, keeping what it was written as", function()
		local parsed = parse('{"Vector3": [1.5, 2, 3]}')

		expect(parsed.ok).toBe(true)
		expect(parsed.value.explicit).toBe(true)
		expect(parsed.value.variant).toBe("Vector3")
		expect(parsed.value.value).toEqual(Vector3.new(1.5, 2, 3))
		expect(parsed.value.holdsNil).toBe(false)
		expect(parsed.value.source).toEqual({ kind = "array", items = { 1.5, 2, 3 } })
	end)

	it("reads an explicit false Bool", function()
		expect(parse('{"Bool": false}').value).toEqual({
			explicit = true,
			variant = "Bool",
			value = false,
			holdsNil = false,
			source = false,
		})
	end)

	it("marks the explicit values Studio holds as nil", function()
		for _, text in
			{
				'{"Ref": "00000000000000000000000000000000"}',
				'{"PhysicalProperties": "Default"}',
				'{"OptionalCFrame": null}',
			}
		do
			local parsed = parse(text)

			expect(parsed.value.holdsNil).toBe(true)
			expect(parsed.value.value).toBe(nil)
		end
	end)

	it("keeps an enum value, a range and an EnumItem as their parts", function()
		expect(parse('{"Enum": 512}').value.value).toBe(512)
		expect(parse('{"NumberRange": [3, 1]}').value.value).toEqual({ 3, 1 })
		expect(parse('{"EnumItem": {"type": "Material", "value": 256}}').value.value).toEqual({
			enumType = "Material",
			value = 256,
		})
	end)

	it("builds sequences, falling back to the defaults Studio loads for one it would not build", function()
		expect(parse('{"NumberSequence": {"keypoints": [{"time": 1, "value": 1, "envelope": 0}]}}').value.value).toEqual(
			NumberSequence.new(0)
		)
		expect(
			parse('{"ColorSequence": [[{"time": 0, "color": [1, 0, 0]}, {"time": 1, "color": [0, 0, 1]}]]}').value.value
		).toEqual(ColorSequence.new(Color3.new(1, 0, 0), Color3.new(0, 0, 1)))
	end)

	for _, form in IMPLICIT_FORMS do
		it(`reads {form[1]} as the implicit form {form[2]}`, function()
			local parsed = parse(form[1])

			expect(parsed.value.explicit).toBe(false)
			expect(parsed.value.variant).toBe(form[2])
			expect(parsed.value.value).toEqual(form[3])
		end)
	end

	it("reads an object of explicit values as attributes, and a Font object as a Font", function()
		local attributes = parse('{"A": {"Bool": true}}').value
		local font =
			parse('{"family": "rbxasset://fonts/families/Arial.json", "weight": "Bold", "style": "Normal"}').value

		expect(attributes.variant).toBe("Attributes")
		expect(attributes.value[1].name).toBe("A")
		expect(attributes.value[1].parsed.value).toBe(true)
		expect(parse("{}").value.variant).toBe("Attributes")
		expect(font.variant).toBe("Font")
		expect(font.value).toEqual(Font.new("rbxasset://fonts/families/Arial.json", Enum.FontWeight.Bold))
	end)

	for _, form in MALFORMED_EXPLICIT do
		it(`refuses {form[1]} as Rojo cannot parse it`, function()
			expect(parse(form[2])).toEqual(UNTAGGED)
		end)
	end

	for _, text in UNPARSABLE do
		it(`refuses {text}, which matches no form`, function()
			expect(parse(text)).toEqual(UNTAGGED)
		end)
	end
end)
