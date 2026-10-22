local RunService = game:GetService("RunService")

local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)

local Palette = require(script.Parent.Parent.Parent.Palette)
local PluginContext = require(script.Parent.Parent.Parent.Parent.PluginContext)

local withPalette = require(script.Parent.Parent.Parent.withPalette)

local Spinner = Roact.Component:extend("Spinner")

Spinner.defaultProps = { Size = 14, Role = "accent", Transparency = 0, LayoutOrder = 0 }

function Spinner:init()
	self.rotation, self.setRotation = Roact.createBinding(0)
end

--[[
	Turns once a second for as long as it is mounted.
]]
function Spinner:didMount()
	self.connection = RunService.Heartbeat:Connect(function()
		self.setRotation((os.clock() * 360) % 360)
	end)
end

function Spinner:willUnmount()
	self.connection:Disconnect()
end

--[[
	The turning image inside a fixed frame. A UIListLayout or UIGridLayout draws what it places unrotated whatever its
		Rotation, and every spinner sits in one, so the layout places the frame and the image turns inside it.
]]
function Spinner:render()
	local props = self.props

	return withPalette(function(palette)
		return Roact.createElement("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.fromOffset(props.Size, props.Size),
		}, {
			Image = Roact.createElement("ImageLabel", {
				BackgroundTransparency = 1,
				Image = PluginContext.PluginSettings.Icons.Spinner,
				ImageColor3 = palette[Palette.TextRoles[props.Role]],
				ImageTransparency = props.Transparency,
				Rotation = self.rotation,
				Size = UDim2.fromScale(1, 1),
			}),
		})
	end)
end

return Spinner
