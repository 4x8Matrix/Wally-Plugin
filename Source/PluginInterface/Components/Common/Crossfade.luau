local Flipper = require(script.Parent.Parent.Parent.Parent.Packages.Flipper)
local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)
local RoactFlipper = require(script.Parent.Parent.Parent.Parent.Packages.RoactFlipper)
local Sift = require(script.Parent.Parent.Parent.Parent.Packages.Sift)

local Motion = require(script.Parent.Parent.Parent.Motion)

local withPalette = require(script.Parent.Parent.Parent.withPalette)

local Crossfade = Roact.Component:extend("Crossfade")

Crossfade.defaultProps = { Key = "" }

function Crossfade:init()
	self.fadeMotor = Flipper.SingleMotor.new(1)
	self.fade = RoactFlipper.getBinding(self.fadeMotor)
end

--[[
	Fades the content in again whenever `Key` changes.
]]
function Crossfade:didUpdate(previous)
	if previous.Key ~= self.props.Key then
		Motion:Snap(self.fadeMotor, 0)
		self.fadeMotor:setGoal(Motion:Goal(1, "selection"))
	end
end

function Crossfade:willUnmount()
	self.fadeMotor:destroy()
end

--[[
	A frame filling its parent whose children fade in when `Key` changes, such as a panel showing another package.
		A cover in the surface colour fades away over them rather than a CanvasGroup fading them, because a CanvasGroup
		draws its children into a texture that blurs at Studio's quality levels.
]]
function Crossfade:render()
	return withPalette(function(palette)
		return Roact.createElement(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
			Sift.Dictionary.merge(self.props[Roact.Children] or {}, {
				Cover = Roact.createElement("Frame", {
					BackgroundColor3 = palette.surface,
					BackgroundTransparency = self.fade,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					Visible = self.fade:map(function(value)
						return value < 0.99
					end),
					ZIndex = 20,
				}),
			})
		)
	end)
end

return Crossfade
