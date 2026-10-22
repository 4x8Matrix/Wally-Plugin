local Rodux = require(script.Parent.Parent.Packages.Rodux)

local Reducer = require(script.Parent.Reducer)

return Rodux.Store.new(Reducer)
