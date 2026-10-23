local Types = require(script.Parent.Types)

local buildError = require(script.Parent.buildError)

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

--[[
	Decodes base64 as the base64 0.13 crate does for Rojo's BinaryString, SharedString and NetAssetRef: the
		standard alphabet, padding optional but never more than the last group needs, and no stray bits in the
		last symbol. The error names no path; the caller adds the file.
]]
return function(text: string): Types.BuildResult<string>
	local symbols, padding = string.match(text, "^([%w+/]*)(=*)$")
	local bytes = {}
	local bits = 0
	local held = 0

	if not symbols or #symbols % 4 == 1 or #padding > (4 - #symbols % 4) % 4 then
		return buildError("", `"{text}" is not valid base64`)
	end

	for index = 1, #symbols do
		bits = bits * 64 + string.find(ALPHABET, string.sub(symbols, index, index), 1, true) - 1
		held += 6

		if held >= 8 then
			held -= 8
			table.insert(bytes, string.char(bits // 2 ^ held))
			bits %= 2 ^ held
		end
	end

	if bits ~= 0 then
		return buildError("", `"{text}" is not valid base64: its last symbol has stray bits`)
	end

	return { ok = true, value = table.concat(bytes) }
end
