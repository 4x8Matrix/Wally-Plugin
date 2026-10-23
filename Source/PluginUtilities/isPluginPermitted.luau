local LOCKED_CAPABILITIES = {
	Enum.SecurityCapability.InternalTest,
	Enum.SecurityCapability.LocalUser,
	Enum.SecurityCapability.RobloxEngine,
	Enum.SecurityCapability.RobloxScript,
	Enum.SecurityCapability.Unassigned,
	Enum.SecurityCapability.WritePlayer,
}

--[[
	Whether a plugin holds what a ReflectionService permit asks for. A plugin lacks every capability in
		LOCKED_CAPABILITIES (each measured in Studio on 2026-10-23: creating or setting something that needs it
		fails), so a class or property whose permit names one is out of reach, and so is one with no permit.
]]
return function(permit: SecurityCapabilities?): boolean
	if not permit then
		return false
	end

	for _, capability in LOCKED_CAPABILITIES do
		if permit:Contains(capability) then
			return false
		end
	end

	return true
end
