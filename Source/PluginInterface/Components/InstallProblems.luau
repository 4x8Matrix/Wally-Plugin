local Roact = require(script.Parent.Parent.Parent.Packages.Roact)
local RoactRodux = require(script.Parent.Parent.Parent.Packages.RoactRodux)

local ErrorBlock = require(script.Parent.Common.ErrorBlock)

local InstallProblems = Roact.Component:extend("InstallProblems")

InstallProblems.defaultProps = { Settled = false, LayoutOrder = 0 }

--[[
	The problems that stopped an operation and belong to no one field, one block each, listed above the action.
		Nothing shows while there are none.
]]
function InstallProblems:render()
	local props = self.props
	local general = (props.store.form.errors or {}).general or {}
	local problems = {
		Layout = Roact.createElement(
			"UIListLayout",
			{ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }
		),
	}

	if #general == 0 then
		return
	end

	for index, problem in general do
		problems[`Problem {index}`] =
			Roact.createElement(ErrorBlock, { Text = problem, Settled = props.Settled, LayoutOrder = index })
	end

	return Roact.createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(1, 0),
	}, problems)
end

return RoactRodux.connect(function(state)
	return { store = state }
end)(InstallProblems)
