local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)
local RoactRodux = require(script.Parent.Parent.Parent.Parent.Packages.RoactRodux)

local Presence = Roact.Component:extend("Presence")

Presence.defaultProps = { Name = "Content" }

local function ignore() end

--[[
	A store that only ever answers with `state`, so what is animating out keeps the content it had when it left.
]]
function Presence.frozen(state: { [string]: any })
	return {
		getState = function()
			return state
		end,
		dispatch = ignore,
		changed = {
			connect = function()
				return { disconnect = ignore }
			end,
		},
	}
end

--[[
	For a list that opens one thing in place at a time: the state changes when what is open moves from the key in
		`state.open` to `key`. The thing that was open becomes `leaving`, with a frozen store to close from.
]]
function Presence.follow(state, key: string?, storeState): { [string]: any }
	if key == state.open then
		return if key then { openState = storeState } else {}
	end

	return {
		open = key or Roact.None,
		openState = if key then storeState else Roact.None,
		leaving = if state.open then { key = state.open, store = Presence.frozen(state.openState) } else Roact.None,
	}
end

--[[
	Drops the closing copy from `updates` when its row is no longer among `present`, so it cannot come back with an
		old state when the row does.
]]
function Presence.forget(updates, state, present: { [string]: boolean })
	local leaving = updates.leaving or state.leaving

	if leaving and leaving ~= Roact.None and not present[leaving.key] then
		updates.leaving = Roact.None
	end

	return updates
end

--[[
	What a list puts under a row when something opens in place: `render(closing, closed, order)`, rendered from the
		frozen store when `leaving` is given. It is the list item itself, with no frame around it, so the rows below
		follow its height as it opens and closes.
]]
function Presence.slot(render, order: number, leaving, closed)
	if leaving then
		return Roact.createElement(RoactRodux.StoreProvider, { store = leaving.store }, {
			Content = render(true, closed, order),
		})
	end

	return render(false, ignore, order)
end

--[[
	Remembers the latest state while present, and on leaving keeps it as the frozen store the closing copy renders
		from.
]]
function Presence.getDerivedStateFromProps(props, state)
	if props.Present then
		return { last = props.State, leaving = Roact.None }
	end

	if state.last then
		return { last = Roact.None, leaving = Presence.frozen(state.last) }
	end

	return
end

--[[
	Keeps an element on screen after the store says it has gone, so it can animate out: while `Present`, it renders
		`render(false)` as `Name`; once it goes, it renders `render(true, closed)` from the state it last had, as
		`Name closing`, until the closing copy calls `closed`. Coming back before then drops the closing copy.
]]
function Presence:render()
	local props = self.props
	local leaving = self.state.leaving

	-- seam: a closing copy is a new mount, so local state such as an open version list or a scrolled form starts over as it leaves, and a surface closed while still opening starts its close from fully open; keep that state in the store, or hand the live motor's value to the copy, if either ever reads as a jump
	return Roact.createFragment({
		[props.Name] = if props.Present then props.render(false, ignore) else nil,
		[`{props.Name} closing`] = if leaving
			then Roact.createElement(RoactRodux.StoreProvider, { store = leaving }, {
				Content = props.render(true, function()
					self:setState({ leaving = Roact.None })
				end),
			})
			else nil,
	})
end

return Presence
