local Types = require(script.Parent.Types)

local buildError = require(script.Parent.buildError)
local describeUnexpected = require(script.Parent.describeUnexpected)
local kindOfDataValue = require(script.Parent.kindOfDataValue)

--[[
	Passes a decoded value of the `kind` kindOfDataValue names and refuses any other in serde's words,
		`invalid type: <what it is>, expected <expected>`. The error names no path; the caller adds the file.
]]
return function(value: Types.DataValue?, kind: string, expected: string): Types.BuildResult<Types.DataValue>
	if kindOfDataValue(value) ~= kind then
		return buildError("", `invalid type: {describeUnexpected(value)}, expected {expected}`)
	end

	return { ok = true, value = value }
end
