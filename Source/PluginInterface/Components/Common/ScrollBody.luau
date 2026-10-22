local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)

local withPalette = require(script.Parent.Parent.Parent.withPalette)

local ScrollBody = Roact.Component:extend("ScrollBody")

ScrollBody.defaultProps = {
	Gap = 12,
	Gutter = 16,
	PaddingTop = 16,
	PaddingBottom = 12,
	MaxHeight = 0,
	Flex = false,
	LayoutOrder = 0,
}

function ScrollBody:init()
	self:setState({ available = 0, content = 0, footer = 0 })
end

--[[
	Keeps one measured height, re-rendering only when it changed.
]]
function ScrollBody:measure(part: string, height: number)
	if self.state[part] ~= height then
		self:setState({ [part] = height })
	end
end

--[[
	A scrolling column of the children with `Action` in a footer under it. While everything fits, the column is as tall
		as its content and the action follows the last item; once it does not, the column takes what the footer leaves
		and the action stays pinned at the bottom behind a divider. Nothing moves between the two, so the measurements
		cannot feed back into each other. It fills its parent, takes the room a vertical list leaves with `Flex`, or with
		`MaxHeight` hugs its content up to that height. `Overlay` lies over the scrolling part only, never the action.
]]
function ScrollBody:render()
	local props = self.props
	local state = self.state
	local hugging = props.MaxHeight > 0
	local available = if hugging then props.MaxHeight else state.available
	local fits = available == 0 or state.content + state.footer <= available
	local scrollHeight = if fits then state.content else math.max(available - state.footer, 0)
	local items = table.clone(props[Roact.Children] or {})
	local size = if hugging
		then UDim2.new(1, 0, 0, math.min(state.content + state.footer, props.MaxHeight))
		elseif props.Flex then UDim2.fromScale(1, 0)
		else UDim2.fromScale(1, 1)

	items.Padding = Roact.createElement("UIPadding", {
		PaddingBottom = UDim.new(0, props.Gap / 2),
		PaddingLeft = UDim.new(0, props.Gutter),
		PaddingRight = UDim.new(0, props.Gutter),
		PaddingTop = UDim.new(0, props.PaddingTop),
	})
	items.Layout = Roact.createElement(
		"UIListLayout",
		{ Padding = UDim.new(0, props.Gap), SortOrder = Enum.SortOrder.LayoutOrder }
	)

	return withPalette(function(palette)
		return Roact.createElement("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder,
			Size = size,
			[Roact.Change.AbsoluteSize] = function(frame)
				self:measure("available", frame.AbsoluteSize.Y)
			end,
		}, {
			Flex = if props.Flex then Roact.createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) else nil,
			Layout = Roact.createElement("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
			Fields = Roact.createElement("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, scrollHeight),
			}, {
				Scroll = Roact.createElement("ScrollingFrame", {
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					CanvasSize = UDim2.new(),
					ScrollBarImageColor3 = palette.dimText,
					ScrollBarThickness = 3,
					Size = UDim2.fromScale(1, 1),
				}, {
					Content = Roact.createElement("Frame", {
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 0),
						[Roact.Change.AbsoluteSize] = function(frame)
							self:measure("content", frame.AbsoluteSize.Y)
						end,
					}, items),
				}),
				Overlay = props.Overlay,
			}),
			Footer = Roact.createElement("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				[Roact.Change.AbsoluteSize] = function(frame)
					self:measure("footer", frame.AbsoluteSize.Y)
				end,
			}, {
				Layout = Roact.createElement("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
				Line = Roact.createElement("Frame", {
					BackgroundColor3 = palette.divider,
					BackgroundTransparency = if fits then 1 else 0,
					BorderSizePixel = 0,
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 1),
				}),
				Action = Roact.createElement("Frame", {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(1, 0),
				}, {
					Padding = Roact.createElement("UIPadding", {
						PaddingBottom = UDim.new(0, props.PaddingBottom),
						PaddingLeft = UDim.new(0, props.Gutter),
						PaddingRight = UDim.new(0, props.Gutter),
						PaddingTop = UDim.new(0, props.Gap / 2),
					}),
					Action = props.Action,
				}),
			}),
		})
	end)
end

return ScrollBody
