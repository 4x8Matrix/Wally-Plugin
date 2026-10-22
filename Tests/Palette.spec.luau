local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local Palette = require(ReplicatedStorage.WallyPlugin.PluginInterface.Palette)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local themes = settings().Studio:GetAvailableThemes()

local function themeOver(background: Color3, name: string?)
	return {
		Name = name or "Custom",
		GetColor = function(_, color: Enum.StudioStyleGuideColor, modifier: Enum.StudioStyleGuideModifier?)
			if color == Enum.StudioStyleGuideColor.MainBackground then
				return background
			end

			return settings().Studio.Theme:GetColor(color, modifier or Enum.StudioStyleGuideModifier.Default)
		end,
	}
end

describe("Palette", function()
	it("gives every role a colour in every Studio theme", function()
		for _, theme in themes do
			local palette = Palette.from(theme)

			for _, role in Palette.Roles do
				expect(typeof(palette[role])).toBe("Color3")
			end
		end
	end)

	it("takes the neutrals from Studio's own theme", function()
		for _, theme in themes do
			local palette = Palette.from(theme)

			expect(palette.background).toEqual(theme:GetColor(Enum.StudioStyleGuideColor.MainBackground))
			expect(palette.text).toEqual(theme:GetColor(Enum.StudioStyleGuideColor.MainText))
			expect(palette.rowHover).toEqual(
				theme:GetColor(Enum.StudioStyleGuideColor.Item, Enum.StudioStyleGuideModifier.Hover)
			)
			expect(palette.error).toEqual(theme:GetColor(Enum.StudioStyleGuideColor.ErrorText))
		end
	end)

	it("uses the Wally red that suits a dark or a light background as the accent", function()
		expect(Palette.from(themeOver(Color3.fromHex("191A1F"), "Dark")).accent:ToHex()).toBe("f0564b")
		expect(Palette.from(themeOver(Color3.fromHex("FFFFFF"), "Light")).accent:ToHex()).toBe("d63a2f")
	end)

	it("goes by the background, not the theme's name, which a custom theme can contradict", function()
		expect(Palette.from(themeOver(Color3.fromHex("181825"), "Light")).accent:ToHex()).toBe("f0564b")
		expect(Palette.from(themeOver(Color3.fromHex("EFF1F5"), "Dark")).accent:ToHex()).toBe("d63a2f")
	end)

	it("judges any theme dark or light by the luminance of its background", function()
		expect(Palette.from(themeOver(Color3.fromRGB(0, 0, 255))).accent:ToHex()).toBe("f0564b")
		expect(Palette.from(themeOver(Color3.fromRGB(230, 230, 120))).accent:ToHex()).toBe("d63a2f")
	end)
end)
