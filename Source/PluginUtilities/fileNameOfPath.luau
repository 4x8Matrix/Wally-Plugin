--[[
	Names what a `/`-joined path inside a package points at as Rust's `file_name` names `<package>/<path>`, the path
		Rojo 7.7.1 sees: the last component, past empty and `.` ones, and nothing when that is `..`. A path naming
		the package folder itself gets `""`, the folder's name being outside the zip.
]]
return function(path: string): string?
	local name = ""

	for _, component in string.split(path, "/") do
		if component ~= "" and component ~= "." then
			name = component
		end
	end

	return if name ~= ".." then name else nil
end
