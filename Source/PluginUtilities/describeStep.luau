--[[
	What a running operation is doing, from the backend's progress: `done` counts finished downloads, so the one under
		way is the next.
]]
return function(operation: { [string]: any }): string
	if operation.step == "downloading" then
		return `Downloading {math.min(operation.done + 1, operation.total)} of {operation.total}`
	end

	return if operation.step == "writing" then "Writing to the place" else "Resolving"
end
