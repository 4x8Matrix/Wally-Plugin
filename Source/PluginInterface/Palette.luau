local PluginContext = require(script.Parent.Parent.PluginContext)

local WHITE = Color3.new(1, 1, 1)

local Palette = {}

Palette.Sources = {
	background = { Enum.StudioStyleGuideColor.MainBackground },
	surface = { Enum.StudioStyleGuideColor.Tab },
	field = { Enum.StudioStyleGuideColor.InputFieldBackground },
	fieldHover = { Enum.StudioStyleGuideColor.InputFieldBackground, Enum.StudioStyleGuideModifier.Hover },
	fieldBorder = { Enum.StudioStyleGuideColor.InputFieldBorder },
	rowHover = { Enum.StudioStyleGuideColor.Item, Enum.StudioStyleGuideModifier.Hover },
	divider = { Enum.StudioStyleGuideColor.Border },
	track = { Enum.StudioStyleGuideColor.Mid },
	strongText = { Enum.StudioStyleGuideColor.BrightText },
	text = { Enum.StudioStyleGuideColor.MainText },
	subText = { Enum.StudioStyleGuideColor.SubText },
	dimText = { Enum.StudioStyleGuideColor.DimmedText },
	error = { Enum.StudioStyleGuideColor.ErrorText },
	warning = { Enum.StudioStyleGuideColor.WarningText },
	scrim = { Enum.StudioStyleGuideColor.DropShadow },
}
Palette.Roles = { "accent", "accentText", "success" }
Palette.TextRoles = {
	strong = "strongText",
	text = "text",
	sub = "subText",
	dim = "dimText",
	accent = "accent",
	onAccent = "accentText",
	error = "error",
	warning = "warning",
	success = "success",
}
Palette.WashTransparency = 0.86

for role in Palette.Sources do
	table.insert(Palette.Roles, role)
end

--[[
	Builds the colours the interface paints with from a Studio theme: every neutral is the theme's own, and only the
		accent and the success colour are the plugin's, picked for a dark or a light background. The background decides,
		by its luma (Rec. 709 weights on the stored colour) against one half, never the theme's name, because a custom
		Studio theme can be named Light and be dark.
]]
function Palette.from(theme: StudioTheme)
	local background = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
	local luminance = 0.2126 * background.R + 0.7152 * background.G + 0.0722 * background.B
	local isDark = luminance < 0.5
	local tone = if isDark then "Dark" else "Light"
	local palette = {
		isDark = isDark,
		accent = PluginContext.PluginSettings.Palette.Accent[tone],
		accentText = WHITE,
		success = PluginContext.PluginSettings.Palette.Success[tone],
	}

	for role, source in Palette.Sources do
		palette[role] = theme:GetColor(source[1], source[2] or Enum.StudioStyleGuideModifier.Default)
	end

	return palette
end

return Palette
