--[[
	Lists an enum's item names as Rojo's invalid-enum refusal does (`nonexhaustive_list`): sorted, the first nine
		at most followed by a comma, then `or` and the last one or the count of the rest.
]]
return function(enum: Enum): string
	local names = {}

	for _, item in enum:GetEnumItems() do
		table.insert(names, item.Name)
	end

	table.sort(names)

	local shown = math.min(#names - 1, 9)
	local rest = if #names > 8 then `or {#names - shown} more` else `or {names[#names]}`

	return if shown > 0 then `{table.concat(names, ", ", 1, shown)}, {rest}` else rest
end
