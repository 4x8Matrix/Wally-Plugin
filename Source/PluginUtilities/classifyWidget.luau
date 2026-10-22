local Types = require(script.Parent.Types)

--[[
	Rows by width: under 260 px is xs, under 420 s, under 680 m, else l.
]]
local function rowsFor(width: number): "xs" | "s" | "m" | "l"
	return if width < 260 then "xs" elseif width < 420 then "s" elseif width < 680 then "m" else "l"
end

--[[
	Picks the row style and the install surface for a widget size: rows by width, and where the install options open
		by width and height together. A side or strip panel takes `panelWidth`, and the rows beside it are styled by the
		room it leaves them (`rowClass`).
]]
return function(width: number, height: number): Types.WidgetLayout
	local widthClass = rowsFor(width)
	local surface = if widthClass == "l"
		then (if height < 180 then "stripLine" elseif height < 300 then "strip" else "side")
		elseif widthClass == "xs" or height < 360 then "full"
		elseif height >= 900 then "inline"
		else "sheet"
	local panelWidth = if surface == "side"
		then math.round(math.clamp(width * 0.34, 300, 380))
		elseif surface == "strip" then math.round(math.clamp(width * 0.45, 520, 640))
		elseif surface == "stripLine" then math.min(760, math.round(width * 0.55))
		else 0

	return {
		widthClass = widthClass,
		surface = surface,
		strip = surface == "strip" or surface == "stripLine",
		stackedTabs = surface == "inline",
		panelWidth = panelWidth,
		rowClass = rowsFor(width - panelWidth),
	}
end
