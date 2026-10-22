--[[
	Finds the installed package an installed selection is open on, by its alias and realm. A registry result, no
		selection, or a package that has since gone finds nothing.
]]
return function(installed: { { [string]: any } }, selection: { [string]: any }?): { [string]: any }?
	if not selection or selection.kind ~= "installed" then
		return
	end

	for _, package in installed do
		if package.alias == selection.alias and package.realm == selection.realm then
			return package
		end
	end

	return
end
