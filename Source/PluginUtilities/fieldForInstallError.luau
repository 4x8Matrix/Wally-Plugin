local Types = require(script.Parent.Types)

local NAME_CLASHES = { "already exists and was not written by the Wally plugin", "is already installed in the" }

--[[
	Names the install form field an install error belongs under: the name in Packages, the version, or the form as a
		whole.
]]
return function(problem: Types.InstallError): Types.FormField
	if problem.kind == "NoMatchingVersion" then
		return "version"
	end

	if problem.kind == "InvalidRequest" and string.find(problem.message, "version requirement", 1, true) then
		return "version"
	end

	if problem.kind == "NameClash" then
		for _, phrase in NAME_CLASHES do
			if string.find(problem.message, phrase, 1, true) then
				return "name"
			end
		end
	end

	return "general"
end
