local Types = require(script.Parent.Types)

local buildError = require(script.Parent.buildError)

local MATCH_NODE = { kind = "match" }
local SLASH_BYTE = string.byte("/")

local function bump(parser: Parser): string?
	parser.previous = parser.current
	parser.cursor += 1
	parser.current = parser.characters[parser.cursor]

	return parser.current
end

local function peek(parser: Parser): string?
	return parser.characters[parser.cursor + 1]
end

local function pushToken(parser: Parser, token: Token)
	table.insert(parser.branches[#parser.branches], token)
end

local function pushTwoStars(branch: { Token })
	table.insert(branch, { kind = "zeroOrMore" })
	table.insert(branch, { kind = "zeroOrMore" })
end

--[[
	Reads the `*` just bumped as globset's `parse_star` does: a lone `*`, a `**` that fills a whole component
		(leading, trailing or between separators, also at the edge of an alternative) as one recursive token, and
		any other `**` as two stars.
]]
local function parseStar(parser: Parser)
	local previous = parser.previous
	local branch = parser.branches[#parser.branches]
	local insideAlternates = #parser.branches > 1

	if peek(parser) ~= "*" then
		table.insert(branch, { kind = "zeroOrMore" })

		return
	end

	bump(parser)

	if #branch == 0 then
		local following = peek(parser)

		if following and following ~= "/" then
			pushTwoStars(branch)
		else
			table.insert(branch, { kind = "recursivePrefix" })
			bump(parser)
		end

		return
	end

	if previous ~= "/" and not (insideAlternates and (previous == "," or previous == "{")) then
		pushTwoStars(branch)

		return
	end

	local following = peek(parser)
	local isSuffix = not following or (insideAlternates and (following == "," or following == "}"))

	if not isSuffix and following ~= "/" then
		pushTwoStars(branch)

		return
	end

	if following == "/" then
		bump(parser)
	end

	local popped = table.remove(branch)
	local keepsPopped = popped.kind == "recursivePrefix" or popped.kind == "recursiveSuffix"
	local replacement = if isSuffix then "recursiveSuffix" else "recursiveZeroOrMore"

	table.insert(branch, if keepsPopped then popped else { kind = replacement })
end

--[[
	Reads the class opened by the `[` just bumped as globset's `parse_class` does: `!` or `^` first negates, a `]`
		or `-` first is literal, a `-` last is literal, and a range whose end is below its start is refused.
		Returns the reason when the class is refused.
]]
local function parseClass(parser: Parser): string?
	local following = peek(parser)
	local negated = following == "!" or following == "^"
	local ranges = {}
	local first = true
	local inRange = false

	if negated then
		bump(parser)
	end

	while true do
		local character = bump(parser)
		local codepoint = parser.codepoints[parser.cursor]
		local lastRange = ranges[#ranges]

		if not character then
			return "unclosed character class; missing ']'"
		end

		if character == "]" and not first then
			break
		end

		if character == "-" and not first and not inRange then
			inRange = true
		elseif inRange then
			if codepoint < lastRange.low then
				return `invalid range; '{utf8.char(lastRange.low)}' > '{character}'`
			end

			lastRange.high = codepoint
			inRange = false
		else
			table.insert(ranges, { low = codepoint, high = codepoint })
		end

		first = false
	end

	if inRange then
		table.insert(ranges, { low = string.byte("-"), high = string.byte("-") })
	end

	pushToken(parser, { kind = "class", negated = negated, ranges = ranges })

	return
end

--[[
	Closes the innermost alternate group, gathering every branch opened since its `{` into one token. Returns the
		reason when no group is open.
]]
local function popAlternate(parser: Parser): string?
	local start = table.remove(parser.alternates)
	local branches = {}

	if not start then
		return "unopened alternate group; missing '{' (maybe escape '}' with '[}]'?)"
	end

	while parser.branches[start] do
		table.insert(branches, 1, table.remove(parser.branches))
	end

	pushToken(parser, { kind = "alternates", branches = branches })

	return
end

local function parseCharacter(parser: Parser, character: string): string?
	if character == "?" then
		pushToken(parser, { kind = "any" })
	elseif character == "*" then
		parseStar(parser)
	elseif character == "[" then
		return parseClass(parser)
	elseif character == "{" then
		table.insert(parser.alternates, #parser.branches + 1)
		table.insert(parser.branches, {})
	elseif character == "}" then
		return popAlternate(parser)
	elseif character == "," and #parser.alternates > 0 then
		table.insert(parser.branches, {})
	elseif character == "\\" then
		local escaped = bump(parser)

		if not escaped then
			return "dangling '\\'"
		end

		pushToken(parser, { kind = "literal", text = escaped })
	else
		pushToken(parser, { kind = "literal", text = character })
	end

	return
end

local function parse(parser: Parser): string?
	while bump(parser) do
		local problem = parseCharacter(parser, parser.current)

		if problem then
			return problem
		end
	end

	if #parser.branches > 1 then
		return "unclosed alternate group; missing '}' (maybe escape '{' with '[{]'?)"
	end

	return
end

--[[
	Says whether `tokens` would write an empty regex in globset, which holds only for alternate groups whose every
		branch is empty, so a branch like that is dropped instead of matching nothing.
]]
local function emitsNothing(tokens: { Token }): boolean
	for _, token in tokens do
		if token.kind ~= "alternates" then
			return false
		end

		for _, branch in token.branches do
			if not emitsNothing(branch) then
				return false
			end
		end
	end

	return true
end

--[[
	Lists the bytes a class matches. globset writes each end of a range as the escaped bytes of its UTF-8 form into
		a byte regex, so a character above ASCII spreads over several one-byte members and only the bytes that meet
		at the `-` form a range.
]]
local function classMembers(ranges: { ClassRange }): { [number]: boolean }
	local members = {}

	for _, range in ranges do
		local low = utf8.char(range.low)
		local high = utf8.char(range.high)

		if range.low == range.high then
			for position = 1, #low do
				members[string.byte(low, position)] = true
			end

			continue
		end

		for position = 1, #low - 1 do
			members[string.byte(low, position)] = true
		end

		for byte = string.byte(low, #low), string.byte(high, 1) do
			members[byte] = true
		end

		for position = 2, #high do
			members[string.byte(high, position)] = true
		end
	end

	return members
end

local function byteNode(value: number, following: Node): Node
	return { kind = "byte", value = value, next = following }
end

local function bytesFrom(text: string, position: number, following: Node): Node
	if position > #text then
		return following
	end

	return byteNode(string.byte(text, position), bytesFrom(text, position + 1, following))
end

local function zeroOrMore(following: Node): Node
	local loop = { kind = "split", options = {} }

	table.insert(loop.options, { kind = "any", next = loop })
	table.insert(loop.options, following)

	return loop
end

--[[
	Builds the nodes for one token that holds no other tokens, ahead of `following`, each as the regex globset
		writes for it: `**/` as `(?:/?|.*/)`, `/**` as `/.*` and `/**/` as `(?:/|/.*/)`.
]]
local function compileToken(token: Token, following: Node): Node
	if token.kind == "literal" then
		return bytesFrom(token.text, 1, following)
	elseif token.kind == "any" then
		return { kind = "any", next = following }
	elseif token.kind == "zeroOrMore" then
		return zeroOrMore(following)
	elseif token.kind == "recursivePrefix" then
		return {
			kind = "split",
			options = { byteNode(SLASH_BYTE, following), following, zeroOrMore(byteNode(SLASH_BYTE, following)) },
		}
	elseif token.kind == "recursiveSuffix" then
		return byteNode(SLASH_BYTE, zeroOrMore(following))
	elseif token.kind == "recursiveZeroOrMore" then
		return {
			kind = "split",
			options = {
				byteNode(SLASH_BYTE, following),
				byteNode(SLASH_BYTE, zeroOrMore(byteNode(SLASH_BYTE, following))),
			},
		}
	end

	return { kind = "class", members = classMembers(token.ranges), negated = token.negated, next = following }
end

local function compileSequence(tokens: { Token }, index: number, following: Node): Node
	local token = tokens[index]

	if not token then
		return following
	end

	local rest = compileSequence(tokens, index + 1, following)

	if token.kind ~= "alternates" then
		return compileToken(token, rest)
	end

	local options = {}

	for _, branch in token.branches do
		if not emitsNothing(branch) then
			table.insert(options, compileSequence(branch, 1, rest))
		end
	end

	return if #options == 0 then rest else { kind = "split", options = options }
end

local function addState(states: { Node }, seen: { [Node]: boolean }, node: Node)
	if seen[node] then
		return
	end

	seen[node] = true

	if node.kind ~= "split" then
		table.insert(states, node)

		return
	end

	for _, option in node.options do
		addState(states, seen, option)
	end
end

local function accepts(node: Node, byte: number): boolean
	if node.kind == "byte" then
		return node.value == byte
	elseif node.kind == "class" then
		return (node.members[byte] == true) ~= node.negated
	end

	return node.kind == "any"
end

local function matches(entry: Node, path: string): boolean
	local states = {}

	addState(states, {}, entry)

	for position = 1, #path do
		local byte = string.byte(path, position)
		local advanced = {}
		local seen = {}

		for _, node in states do
			if accepts(node, byte) then
				addState(advanced, seen, node.next)
			end
		end

		states = advanced
	end

	return if table.find(states, MATCH_NODE) then true else false
end

type Parser = {
	characters: { string },
	codepoints: { number },
	cursor: number,
	previous: string?,
	current: string?,
	branches: { { Token } },
	alternates: { number },
}
type ClassRange = { low: number, high: number }
type Token = {
	kind: "literal"
		| "any"
		| "zeroOrMore"
		| "recursivePrefix"
		| "recursiveSuffix"
		| "recursiveZeroOrMore"
		| "class"
		| "alternates",
	text: string?,
	negated: boolean?,
	ranges: { ClassRange }?,
	branches: { { Token } }?,
}
type Node = {
	kind: "byte" | "any" | "class" | "split" | "match",
	value: number?,
	members: { [number]: boolean }?,
	negated: boolean?,
	options: { Node }?,
	next: Node?,
}

--[[
	Compiles `pattern` as globset 0.4.18 does with its default options, which Rojo 7.7.1 uses for its default rules,
		`syncRules` and `globIgnorePaths`, into a function telling whether a `/`-joined path matches the whole
		pattern. Matching is by bytes and case-sensitive; `*` and `?` cross `/`; `**` is recursive only as a whole
		component and two stars anywhere else; classes, nested alternates and backslash escapes follow globset, and
		a leading `!` is a literal, so an ignore rule strips it before compiling. A pattern globset refuses fails in
		its words; the error names no path, the caller adds the file the pattern came from.
]]
return function(pattern: string): Types.BuildResult<(path: string) -> boolean>
	if not utf8.len(pattern) then
		return buildError("", "Glob is not valid UTF-8")
	end

	local parser: Parser = {
		characters = {},
		codepoints = {},
		cursor = 0,
		branches = { {} },
		alternates = {},
	}

	for _, codepoint in utf8.codes(pattern) do
		table.insert(parser.characters, utf8.char(codepoint))
		table.insert(parser.codepoints, codepoint)
	end

	local problem = parse(parser)
	local tokens = parser.branches[1]
	local wholeRecursive = #tokens == 1 and tokens[1].kind == "recursivePrefix"

	if problem then
		return buildError("", `error parsing glob '{pattern}': {problem}`)
	end

	local entry = if wholeRecursive then zeroOrMore(MATCH_NODE) else compileSequence(tokens, 1, MATCH_NODE)

	return {
		ok = true,
		value = function(path: string): boolean
			return matches(entry, path)
		end,
	}
end
