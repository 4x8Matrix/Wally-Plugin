local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)
local StudioComponents = require(script.Parent.Parent.Parent.Parent.Packages.StudioComponents)

local StudioRow = Roact.Component:extend("StudioRow")

StudioRow.defaultProps = {
	LayoutOrder = 0,

	valueElement = nil,
	keyElement = nil
}

function StudioRow:render()
	return StudioComponents.withTheme(function(theme)
		return Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
			BorderSizePixel = 1,
			LayoutOrder = self.props.LayoutOrder,
		}, {
			PropertyNameFrame = Roact.createElement("Frame", {
				Size = UDim2.fromScale(0.5, 1),
				BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
				BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
				BorderSizePixel = 1,
			}, {
				UIPadding = Roact.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 25)
				}),

				ElementKey = self.props.keyElement
			}),

			PropertyValueFrame = Roact.createElement("Frame", {
				Size = UDim2.fromScale(0.5, 1),
				Position = UDim2.fromScale(0.5, 0),
				BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
				BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border), 
				BorderSizePixel = 1,
			}, {
				UIPadding = Roact.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 5)
				}),

				UIListLayout = Roact.createElement("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center
				}),

				ElementValue = self.props.valueElement
			})
		})
	end)
end

return StudioRow
