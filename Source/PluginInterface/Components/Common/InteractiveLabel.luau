local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)
local StudioComponents = require(script.Parent.Parent.Parent.Parent.Packages.StudioComponents)
local Sift = require(script.Parent.Parent.Parent.Parent.Packages.Sift)

local InteractiveLabel = Roact.Component:extend("InteractiveLabel")

InteractiveLabel.defaultProps = {
	LayoutOrder = 0,
	ZIndex = 0,
	Disabled = false,
	Position = UDim2.fromScale(0, 0),
	AnchorPoint = Vector2.new(0, 0),
	Size = UDim2.fromScale(1, 1),
	Text = "Label.defaultProps.Text",
	Font = Enum.Font.SourceSans,
	TextSize = 14,
	TextColorStyle = Enum.StudioStyleGuideColor.MainText,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	BorderMode = Enum.BorderMode.Inset,
}

function InteractiveLabel:render()
	return StudioComponents.withTheme(function(theme)
		local props = Sift.Dictionary.copy(self.props)
		local modifier = Enum.StudioStyleGuideModifier.Default

		if props.Disabled then
			modifier = Enum.StudioStyleGuideModifier.Disabled
		end

		props.TextColor3 = theme:GetColor(props.TextColorStyle, modifier)

		props.Disabled = nil
		props.TextColorStyle = nil
		props.OnRightClicked = nil

		return Roact.createElement("TextLabel", Sift.Dictionary.merge({
			[Roact.Event.InputEnded] = function(_, inputObject)
				if inputObject.UserInputType ~= Enum.UserInputType.MouseButton2 then
					return
				end

				if self.props.OnRightClicked then
					self.props.OnRightClicked()
				end
			end
		}, props))
	end)
end

return InteractiveLabel
