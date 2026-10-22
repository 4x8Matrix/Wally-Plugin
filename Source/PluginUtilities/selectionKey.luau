--[[
	Names what is selected in one string, so an operation can say which selection it belongs to: a registry result by
		its package name, an installed package by its alias and realm.
]]
return function(selection: { [string]: any }?): string?
	if not selection then
		return
	end

	if selection.kind == "result" then
		return `result:{selection.scope}/{selection.name}`
	end

	return `installed:{selection.alias}:{selection.realm}`
end
