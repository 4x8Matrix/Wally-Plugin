local Roact = require(script.Parent.Parent.Packages.Roact)

local PaletteContext = require(script.Parent.PaletteContext)

--[[
	Renders `render` with the palette the nearest `PaletteProvider` supplies.
]]
return function(render: (palette: { [string]: any }) -> any)
	return Roact.createElement(PaletteContext.Consumer, { render = render })
end
