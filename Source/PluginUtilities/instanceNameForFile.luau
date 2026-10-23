--[[
	Names the instance a file becomes under a sync rule, as Rojo 7.7.1's `file_name_for_path` does: the file name
		without `suffix` when it ends with it, the whole file name when it does not, and without a suffix the stem
		Rust's `Path::file_stem` gives, everything before the last `.` unless nothing but the leading `.` comes
		before it.
]]
return function(fileName: string, suffix: string?): string
	local stem = string.match(fileName, "^(.*)%.[^.]*$")

	if suffix then
		return if string.sub(fileName, -#suffix) == suffix
			then string.sub(fileName, 1, #fileName - #suffix)
			else fileName
	end

	return if stem and stem ~= "" then stem else fileName
end
