local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)
local RoactRodux = require(script.Parent.Parent.Parent.Parent.Packages.RoactRodux)

local BusyOverlay = require(script.Parent.Parent.Common.BusyOverlay)
local Crossfade = require(script.Parent.Parent.Common.Crossfade)
local FloatingLayer = require(script.Parent.Parent.Common.FloatingLayer)
local InstallAction = require(script.Parent.Parent.InstallAction)
local InstallForm = require(script.Parent.Parent.InstallForm)
local InstallProblems = require(script.Parent.Parent.InstallProblems)
local PackageTitles = require(script.Parent.Parent.PackageTitles)
local Text = require(script.Parent.Parent.Common.Text)

local selectionKey = require(script.Parent.Parent.Parent.Parent.PluginUtilities.selectionKey)
local withPalette = require(script.Parent.Parent.Parent.withPalette)

local StripPanel = Roact.Component:extend("StripPanel")

StripPanel.defaultProps = { Width = 576, Line = false, LayoutOrder = 0 }

--[[
	The action at a fixed width, beside the fields rather than under them.
]]
local function fixedAction(width: number, order: number)
	return Roact.createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.fromOffset(width, 0),
	}, {
		Action = Roact.createElement(InstallAction, { Height = 30 }),
	})
end

--[[
	The rows under a strip's top row, scrolling in the height the strip leaves them, with `overlay` over them when
		given.
]]
local function scrolling(children, order: number, palette, overlay)
	children.Layout =
		Roact.createElement("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })

	return Roact.createElement("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
	}, {
		Flex = Roact.createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
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
			}, children),
		}),
		Overlay = overlay,
	})
end

function StripPanel:init()
	self.formHeight, self.setFormHeight = Roact.createBinding(0)
end

--[[
	The install options for a wide, short widget docked like Output, `Width` wide: titles and the action on one row with
		the fields under them, or everything on one line when the strip is thinner still. What sits under the top row
		scrolls, and problems that stop an install open it, so they are in view the moment the strip shows them; on one
		line the row scrolls with its problems, since the strip has no height to spare for both. Choosing another
		package crossfades the content. The strip has no height to open the version list in, so it floats over the
		strip.
]]
function StripPanel:render()
	local props = self.props
	local store = props.store
	local problems = #((store.form.errors or {}).general or {}) > 0

	return withPalette(function(palette)
		local content

		if not store.selection then
			content = {
				Empty = Roact.createElement(Text, {
					Text = "Pick a package to see its versions and install it",
					Role = "sub",
					Size = 12,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
				}),
			}
		elseif props.Line then
			local row = Roact.createElement("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0),
			}, {
				Layout = Roact.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				Titles = Roact.createElement("Frame", {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Size = UDim2.fromOffset(140, 0),
				}, {
					Titles = Roact.createElement(PackageTitles, { Size = 14, Description = false }),
				}),
				Form = Roact.createElement("Frame", {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.new(),
				}, {
					Flex = Roact.createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
					Fields = Roact.createElement("Frame", {
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 0),
						[Roact.Change.AbsoluteSize] = function(frame)
							self.setFormHeight(frame.AbsoluteSize.Y)
						end,
					}, {
						Form = Roact.createElement(InstallForm, { Layout = "line" }),
					}),
					Overlay = Roact.createElement(BusyOverlay, { Compact = true, Height = self.formHeight }),
				}),
				Action = fixedAction(150, 3),
			})

			content = {
				Layout = Roact.createElement("UIListLayout", {
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				Row = if problems then nil else row,
				Below = if problems
					then scrolling({
						Row = row,
						Problems = Roact.createElement(InstallProblems, { LayoutOrder = 2 }),
					}, 1, palette)
					else nil,
			}
		else
			content = {
				Layout = Roact.createElement(
					"UIListLayout",
					{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }
				),
				Head = Roact.createElement("Frame", {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Size = UDim2.fromScale(1, 0),
				}, {
					Layout = Roact.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 10),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					Titles = Roact.createElement(
						PackageTitles,
						{ Size = 15, Description = false, Flex = true, LayoutOrder = 1 }
					),
					Action = fixedAction(170, 2),
				}),
				Below = scrolling({
					Problems = Roact.createElement(InstallProblems, { LayoutOrder = 1 }),
					Form = Roact.createElement(InstallForm, { Layout = "strip", LayoutOrder = 2 }),
				}, 2, palette, Roact.createElement(BusyOverlay)),
			}
		end

		content.Padding = Roact.createElement("UIPadding", {
			PaddingBottom = UDim.new(0, if props.Line then 6 else 10),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, if props.Line then 6 else 10),
		})

		return Roact.createElement("Frame", {
			BackgroundColor3 = palette.surface,
			BorderSizePixel = 0,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.new(0, props.Width, 1, 0),
		}, {
			Edge = Roact.createElement("Frame", {
				BackgroundColor3 = palette.divider,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 1, 1, 0),
				ZIndex = 2,
			}),
			Floating = Roact.createElement(FloatingLayer, { ZIndex = 3 }, {
				Content = Roact.createElement(Crossfade, { Key = selectionKey(store.selection) or "" }, {
					Content = Roact.createElement(
						"Frame",
						{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
						content
					),
				}),
			}),
		})
	end)
end

return RoactRodux.connect(function(state)
	return { store = state }
end)(StripPanel)
