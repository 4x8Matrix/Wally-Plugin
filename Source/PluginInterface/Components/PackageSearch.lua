local Roact = require(script.Parent.Parent.Parent.Packages.Roact)
local RoactRodux = require(script.Parent.Parent.Parent.Packages.RoactRodux)
local StudioComponents = require(script.Parent.Parent.Parent.Packages.StudioComponents)

local InteractiveLabel = require(script.Parent.Common.InteractiveLabel)

local PluginSearch = Roact.Component:extend("PluginSearch")

PluginSearch.defaultProps = {
	HeaderText = "DEFAULT_PLUGIN_HEADER",
	LayoutOrder = -1
}

function PluginSearch:generateSearchPackageList()
	local elements = {}

	for index, packageFullName in self.props.store.searchedPackagesArray do
		table.insert(elements, Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,

			LayoutOrder = index + 1,
		}, {
			UIPadding = Roact.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 5),
				PaddingRight = UDim.new(0, 5),
				PaddingTop = UDim.new(0, 2),
				PaddingBottom = UDim.new(0, 2),
			}),

			UIListLayout = Roact.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,

				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),

			InteractiveLabel = Roact.createElement(InteractiveLabel, {
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,

				Size = UDim2.fromScale(0.8, 1),
				Text = packageFullName,

				LayoutOrder = 1,
				OnRightClicked = function()
					self.props.store.onSuggestedLabelRightClicked(packageFullName)
				end
			}),

			ButtonFrame = Roact.createElement("Frame", {
				Size = UDim2.fromScale(0.2, 1),
				BackgroundTransparency = 1,
				LayoutOrder = 2
			}, {
				UIListLayout = Roact.createElement("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Horizontal,
	
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
				}),

				UIPadding = Roact.createElement("UIPadding", {
					PaddingTop = UDim.new(0, 2),
					PaddingBottom = UDim.new(0, 2),
				}),

				ButtonFrame = Roact.createElement("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					LayoutOrder = 2
				}, {
					UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint"),

					DownloadButton = Roact.createElement("ImageButton", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
	
						Image = "rbxassetid://14806672610",

						[Roact.Event.Activated] = function()
							self.props.store.onDownloadButtonClicked(packageFullName)
						end
					})
				}),
			})
		}))
	end

	return elements
end

function PluginSearch:init()
	self:setState({
		sectionCollapsed = false
	})
end

function PluginSearch:render()
	return StudioComponents.withTheme(function(theme)
		local searchPackageList = self:generateSearchPackageList(theme)

		return Roact.createElement(StudioComponents.VerticalCollapsibleSection, {
			HeaderText = self.props.HeaderText,
			LayoutOrder = self.props.LayoutOrder,

			Collapsed = self.state.sectionCollapsed,

			OnToggled = function()
				self:setState({
					sectionCollapsed = not self.state.sectionCollapsed
				})
			end,
		}, {
			SearchPackageFrame = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 25),
				BackgroundTransparency = 1,
				LayoutOrder = 2,
			}, {
				Roact.createElement(StudioComponents.TextInput, {
					PlaceholderText = "roblox/roact",
					ClearTextOnFocus = false,
					OnChanged = function(...)
						self.props.store.onSearchTextUpdated(...)
					end
				})
			}),

			PackageList = Roact.createFragment(searchPackageList)
		})
	end)
end

return RoactRodux.connect(function(state)
	return {
		store = state,
	}
end)(PluginSearch)
