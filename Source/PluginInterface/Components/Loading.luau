local Flipper = require(script.Parent.Parent.Parent.Packages.Flipper)
local RoactFlipper = require(script.Parent.Parent.Parent.Packages.RoactFlipper)
local Roact = require(script.Parent.Parent.Parent.Packages.Roact)
local RoactRodux = require(script.Parent.Parent.Parent.Packages.RoactRodux)
local StudioComponents = require(script.Parent.Parent.Parent.Packages.StudioComponents)

local Loading = Roact.Component:extend("Loading")

Loading.defaultProps = {
	LayoutOrder = 0,
}

function Loading:lerp(startValue, endValue, ratio)
	return startValue + (endValue - startValue) * ratio
end

function Loading:init()
	self.transparencyMotor = Flipper.SingleMotor.new(1)
	self.transparencyBinding = RoactFlipper.getBinding(self.transparencyMotor)

	self.animationMotor = Flipper.SingleMotor.new(1)
	self.animationBinding = RoactFlipper.getBinding(self.animationMotor)
end

function Loading:didMount()
	if self.props.store.isLoading then
		self.transparencyMotor:setGoal(Flipper.Spring.new(0, {
			frequency = 2,
			dampingRatio = 1,
		}))

		self.animationMotor:setGoal(Flipper.Linear.new(1, {
			velocity = 2
		}))

		self.animationMotorCompletedConnection = self.animationMotor:onComplete(function()
			local newValue = self.animationBinding:getValue() == 1 and 0 or 1
	
			self.animationMotor:setGoal(Flipper.Spring.new(newValue, {
				frequency = 2,
				dampingRatio = 1,
			}))
		end)
	end
end

function Loading:didUpdate()
	if self.props.store.isLoading then
		self.transparencyMotor:setGoal(Flipper.Spring.new(0, {
			frequency = 2,
			dampingRatio = 1,
		}))

		self.animationMotor:setGoal(Flipper.Linear.new(1, {
			velocity = 2
		}))

		self.animationMotorCompletedConnection = self.animationMotor:onComplete(function()
			local newValue = self.animationBinding:getValue() == 1 and 0 or 1
	
			self.animationMotor:setGoal(Flipper.Spring.new(newValue, {
				frequency = 2,
				dampingRatio = 1,
			}))
		end)
	else
		self.transparencyMotor:setGoal(Flipper.Spring.new(1, {
			frequency = 4,
			dampingRatio = 1,
		}))

		task.delay(1, function()
			if self.animationMotorCompletedConnection then
				self.animationMotorCompletedConnection:disconnect()
			end

			self.animationMotor:setGoal(Flipper.Instant.new(0))
		end)
	end
end

function Loading:render()
	return StudioComponents.withTheme(function(theme)
		return Roact.createElement("Frame", {
			Active = self.props.store.isLoading,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
			BorderSizePixel = 1,
			LayoutOrder = self.props.LayoutOrder,
			ZIndex = 5,
			BackgroundTransparency = self.transparencyBinding:map(function(value)
				return value
			end)
		}, {
			ForegroundFrame = Roact.createElement("Frame", {
				BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
				Size = UDim2.fromScale(0.075, 0.075),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),

				BackgroundTransparency = self.transparencyBinding:map(function(value)
					return value
				end),

				ZIndex = 2,
			}, {
				UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint"),

				UICorner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(1, 0)
				}),
			}),

			BackgroundFrame = Roact.createElement("Frame", {
				BackgroundColor3 = Color3.fromHex("2893e5"),
				Size = UDim2.fromScale(0.1, 0.1),
				AnchorPoint = Vector2.new(0.5, 0.5),

				Position = UDim2.fromScale(0.5, 0.5),

				Rotation = self.animationBinding:map(function(value)
					return 360 * value
				end),

				BackgroundTransparency = self.transparencyBinding:map(function(value)
					return math.min(value * 2, 1)
				end)
			}, {
				UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint"),

				UICorner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(1, 0)
				}),

				UIGradient = Roact.createElement("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
						ColorSequenceKeypoint.new(0.499, Color3.fromRGB(255, 255, 255)),
						ColorSequenceKeypoint.new(0.5, Color3.fromRGB(132, 132, 132)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(132, 132, 132)),
					  }),
				})
			})
		})
	end)
end

return RoactRodux.connect(function(state)
	return {
		store = state,
	}
end)(Loading)
