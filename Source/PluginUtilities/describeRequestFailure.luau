--[[
	The text for a failed registry request: `<statusCode> <statusMessage>` for a request record, `tostring` for
		anything else.
]]
return function(failure: any): string
	if failure.statusCode then
		return `{failure.statusCode} {failure.statusMessage}`
	end

	return tostring(failure)
end
