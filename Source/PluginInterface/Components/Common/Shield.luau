local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)

local Shield = Roact.Component:extend("Shield")

Shield.defaultProps = { ZIndex = 10 }

--[[
	A clear button over a closing copy that takes its clicks, so nothing in what is animating away can still be used.
		It has to be a button: frames let clicks through whatever their Active, and Interactable only reaches one
		button, not what lies under it.
]]
function Shield:render()
	return Roact.createElement("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Selectable = false,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = self.props.ZIndex,
	})
end

return Shield
