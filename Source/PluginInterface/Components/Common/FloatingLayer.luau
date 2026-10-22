local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)

local OverlayContext = require(script.Parent.Parent.Parent.OverlayContext)

local FloatingLayer = Roact.Component:extend("FloatingLayer")

FloatingLayer.defaultProps = { ZIndex = 5 }

function FloatingLayer:init()
	self.layerRef = Roact.createRef()
end

--[[
	Offers the layer to what it wraps once the layer exists.
]]
function FloatingLayer:didMount()
	self:setState({ layer = self.layerRef:getValue() })
end

--[[
	A clear layer over a short surface, clipped to it, that pickers inside the surface float in instead of opening in
		place, offered to the children through `OverlayContext`.
]]
function FloatingLayer:render()
	return Roact.createFragment({
		Content = Roact.createElement(
			OverlayContext.Provider,
			{ value = self.state.layer },
			self.props[Roact.Children]
		),
		["Floating layer"] = Roact.createElement("Frame", {
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Size = UDim2.fromScale(1, 1),
			ZIndex = self.props.ZIndex,
			[Roact.Ref] = self.layerRef,
		}),
	})
end

return FloatingLayer
