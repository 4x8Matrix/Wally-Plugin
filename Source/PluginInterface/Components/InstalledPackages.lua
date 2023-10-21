local Roact = require(script.Parent.Parent.Parent.Packages.Roact)
local RoactRodux = require(script.Parent.Parent.Parent.Packages.RoactRodux)
local StudioComponents = require(script.Parent.Parent.Parent.Packages.StudioComponents)

local InteractiveLabel = require(script.Parent.Common.InteractiveLabel)

local InstalledPackages = Roact.Component:extend("InstalledPackages")

InstalledPackages.defaultProps = {
	HeaderText = "DEFAULT_PLUGIN_HEADER",
	LayoutOrder = -1
}

function InstalledPackages:generateInstalledPackageList()
	local elements = {}

	for index, packageFullName in self.props.store.installedPackagesArray do
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
					self.props.store.onInstallLabelRightClicked(packageFullName)
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
	
						Image = "rbxassetid://14806673358",

						[Roact.Event.Activated] = function()
							self.props.store.onDeleteButtonClicked(packageFullName)
						end
					})
				}),
			})
		}))
	end

	if #self.props.store.installedPackagesArray == 0 then
		table.insert(elements, Roact.createElement(StudioComponents.Label, {
			Size = UDim2.new(1, 0, 0, 24),
			Text = "There are currently no Wally packages installed!"
		}))
	end

	return elements
end

function InstalledPackages:init()
	self:setState({
		sectionCollapsed = false
	})
end

function InstalledPackages:render()
	return StudioComponents.withTheme(function(theme)
		local installedPackageList = self:generateInstalledPackageList(theme)

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
			PackageList = Roact.createFragment(installedPackageList)
		})
	end)
end

return RoactRodux.connect(function(state)
	return {
		store = state,
	}
end)(InstalledPackages)
