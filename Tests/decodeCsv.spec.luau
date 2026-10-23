local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local decodeCsv = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeCsv)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function lines(...: string): string
	return table.concat({ ... }, "\n")
end

local function contents(text: string): string
	local decoded = decodeCsv(text)

	if not decoded.ok then
		return `refused: {decoded.error.message}`
	end

	return decoded.value
end

describe("decodeCsv", function()
	it("builds Rojo's own CSV test cases", function()
		expect(contents("Key,Source,Context,Example,es\nCount,3,,A number demonstrating issue 145,7")).toBe(
			'[{"key":"Count","example":"A number demonstrating issue 145","source":"3","values":{"es":"7"}}]'
		)
		expect(
			contents(
				lines(
					",Key,Source,Context,Example",
					",,,,",
					"Metadata,Language.Name,English,,",
					",Language.Region,United States,,",
					",,,,",
					"Options,Label.Thickness,Thickness,,",
					",Label.Opacity,Opacity,,",
					",,,,",
					"Toolbar,Toolbar.Undo,Undo,,",
					",Toolbar.Redo,Redo,,",
					",,,,",
					",Toolbar.Camera,Top-down camera,,",
					",Toolbar.Saves,Saved drawings,,",
					",Toolbar.Preferences,Settings,,",
					",,,,",
					",Toolbar.Mode.Vector,Vector mode,,",
					",Toolbar.Mode.Pixel,Pixel mode,,"
				)
			)
		).toBe(
			'[{"key":"Language.Name","source":"English","values":{}},{"key":"Language.Region","source":"United States","values":{}},{"key":"Label.Thickness","source":"Thickness","values":{}},{"key":"Label.Opacity","source":"Opacity","values":{}},{"key":"Toolbar.Undo","source":"Undo","values":{}},{"key":"Toolbar.Redo","source":"Redo","values":{}},{"key":"Toolbar.Camera","source":"Top-down camera","values":{}},{"key":"Toolbar.Saves","source":"Saved drawings","values":{}},{"key":"Toolbar.Preferences","source":"Settings","values":{}},{"key":"Toolbar.Mode.Vector","source":"Vector mode","values":{}},{"key":"Toolbar.Mode.Pixel","source":"Pixel mode","values":{}}]'
		)
		expect(contents("Key,Source,Context,Example,es\nAck,Ack!,,An exclamation of despair,\u{A1}Ay!")).toBe(
			'[{"key":"Ack","example":"An exclamation of despair","source":"Ack!","values":{"es":"\u{A1}Ay!"}}]'
		)
	end)

	it("writes [] for a file with no records", function()
		expect(contents("")).toBe("[]")
		expect(contents("\u{FEFF}")).toBe("[]")
		expect(contents("Key,Source,es\n")).toBe("[]")
		expect(contents("Key,Source,es")).toBe("[]")
		expect(contents(lines("", ",", "a,b", ""))).toBe("[]")
	end)

	it("reads the first record as headers and pairs each later record with them", function()
		expect(contents(lines("Key,Source,Context,Example,es,fr", "hello,Hello,greeting,Hi there,Hola,Bonjour", ""))).toBe(
			'[{"key":"hello","context":"greeting","example":"Hi there","source":"Hello","values":{"es":"Hola","fr":"Bonjour"}}]'
		)
		expect(contents(lines("Key,Source,de", "k0,s0,d0", "k1,s1,d1", "k2,s2,d2", "k3,s3,d3", "k4,s4,d4", ""))).toBe(
			'[{"key":"k0","source":"s0","values":{"de":"d0"}},{"key":"k1","source":"s1","values":{"de":"d1"}},{"key":"k2","source":"s2","values":{"de":"d2"}},{"key":"k3","source":"s3","values":{"de":"d3"}},{"key":"k4","source":"s4","values":{"de":"d4"}}]'
		)
		expect(contents(lines("Example,Context,Source,Key,es", "e,c,s,k,v", ""))).toBe(
			'[{"key":"k","context":"c","example":"e","source":"s","values":{"es":"v"}}]'
		)
		expect(contents("Key,Source\na,A")).toBe('[{"key":"a","source":"A","values":{}}]')
		expect(contents(lines("Key,Source", "\u{540D}\u{524D},\u{5024}", ""))).toBe(
			'[{"key":"\u{540D}\u{524D}","source":"\u{5024}","values":{}}]'
		)
	end)

	it("ends records at CRLF, LF and CR and skips empty lines", function()
		expect(contents(lines("Key,Source,es\r", "a,A,x\r", "b,B,y\r", ""))).toBe(
			'[{"key":"a","source":"A","values":{"es":"x"}},{"key":"b","source":"B","values":{"es":"y"}}]'
		)
		expect(contents("Key,Source,es\ra,A,x\rb,B,y\r")).toBe(
			'[{"key":"a","source":"A","values":{"es":"x"}},{"key":"b","source":"B","values":{"es":"y"}}]'
		)
		expect(contents(lines("Key,Source\r", "a,A", "b,B\rc,C"))).toBe(
			'[{"key":"a","source":"A","values":{}},{"key":"b","source":"B","values":{}},{"key":"c","source":"C","values":{}}]'
		)
		expect(contents(lines("", "", "Key,Source", "", "a,A", "", "\r", "\rb,B", "", ""))).toBe(
			'[{"key":"a","source":"A","values":{}},{"key":"b","source":"B","values":{}}]'
		)
		expect(contents(lines("Key", "a", "", ""))).toBe('[{"key":"a","values":{}}]')
		expect(
			contents(
				lines(
					"\u{FEFF}Key,Source,es\r",
					'"multi',
					'line","say ""hi""",uno\r',
					"plain,value,dos\rlast,row,tres",
					""
				)
			)
		).toBe(
			'[{"key":"multi\\nline","source":"say \\"hi\\"","values":{"es":"uno"}},{"key":"plain","source":"value","values":{"es":"dos"}},{"key":"last","source":"row","values":{"es":"tres"}}]'
		)
	end)

	it("strips a leading byte order mark", function()
		expect(contents(lines("\u{FEFF}Key,Source", "a,A", ""))).toBe('[{"key":"a","source":"A","values":{}}]')
		expect(contents(lines('\u{FEFF}"Key",Source', "a,A", ""))).toBe('[{"key":"a","source":"A","values":{}}]')
	end)

	it("reads quoted fields as the csv crate does", function()
		expect(contents(lines("Key,Source,es", '"multi', 'line","say ""hi""","a, b"', ""))).toBe(
			'[{"key":"multi\\nline","source":"say \\"hi\\"","values":{"es":"a, b"}}]'
		)
		expect(contents(lines("Key,Source", 'a,"x\r', 'y"', ""))).toBe('[{"key":"a","source":"x\\r\\ny","values":{}}]')
		expect(contents(lines("Key,Source", 'a,"x\ry"', ""))).toBe('[{"key":"a","source":"x\\ry","values":{}}]')
		expect(contents(lines("Key,Source", 'a"b,c"d', ""))).toBe('[{"key":"a\\"b","source":"c\\"d","values":{}}]')
		expect(contents(lines("Key,Source", '"ab"cd,"x" y', ""))).toBe('[{"key":"abcd","source":"x y","values":{}}]')
		expect(contents(lines("Key,Source", 'a,"open', ""))).toBe('[{"key":"a","source":"open\\n","values":{}}]')
		expect(contents(lines("Key,Source", 'a, "x"', ""))).toBe('[{"key":"a","source":" \\"x\\"","values":{}}]')
		expect(contents(lines('"Ke,y",Source', "a,A", ""))).toBe('[{"source":"A","values":{"Ke,y":"a"}}]')
		expect(contents(lines("Key", '""', "x", ""))).toBe('[{"key":"x","values":{}}]')
		expect(contents(lines("Key", "  ", "x", ""))).toBe('[{"key":"  ","values":{}},{"key":"x","values":{}}]')
	end)

	it("matches Key, Source, Context and Example by exact case and treats other headers as locales", function()
		expect(contents(lines("key,source,context,example", "a,A,c,e", ""))).toBe("[]")
		expect(contents(lines("Key,source,EXAMPLE", "a,A,e", ""))).toBe(
			'[{"key":"a","values":{"EXAMPLE":"e","source":"A"}}]'
		)
		expect(contents(lines("Key,Source,Examples", "a,A,e", ""))).toBe(
			'[{"key":"a","source":"A","values":{"Examples":"e"}}]'
		)
		expect(contents(lines(" Key,Source ", "a,A", ""))).toBe("[]")
	end)

	it("skips an empty header or field and drops a record with neither Key nor Source", function()
		expect(contents(lines("Key,Source,es", "a,,x", ",B,", ""))).toBe(
			'[{"key":"a","values":{"es":"x"}},{"source":"B","values":{}}]'
		)
		expect(contents(lines("Key,Source", ",hello", ""))).toBe('[{"source":"hello","values":{}}]')
		expect(contents(lines("Key,Source,Context,Example,es", ",,ctx,ex,val", ""))).toBe("[]")
		expect(contents(lines("Key,Source", ",", ""))).toBe("[]")
		expect(contents(lines("Key,Source,", "a,A,x", ""))).toBe('[{"key":"a","source":"A","values":{}}]')
		expect(contents(lines(",Key,Source", "meta,a,A", ""))).toBe('[{"key":"a","source":"A","values":{}}]')
	end)

	it("lets a repeated header overwrite the one before it", function()
		expect(contents(lines("Key,Source,es,es", "a,A,first,second", ""))).toBe(
			'[{"key":"a","source":"A","values":{"es":"second"}}]'
		)
		expect(contents(lines("Key,Key,Source", "first,second,A", ""))).toBe(
			'[{"key":"second","source":"A","values":{}}]'
		)
		expect(contents(lines("Key,Source,es,es", "a,A,first,", ""))).toBe(
			'[{"key":"a","source":"A","values":{"es":"first"}}]'
		)
	end)

	it("sorts locales by bytes and escapes as serde_json does", function()
		expect(contents(lines("Key,zh,en,_x,En,\u{E9},Source,10", "a,1,2,3,4,5,S,6", ""))).toBe(
			'[{"key":"a","source":"S","values":{"10":"6","En":"4","_x":"3","en":"2","zh":"1","\u{E9}":"5"}}]'
		)
		expect(
			contents(
				lines(
					"Key,Source,es",
					'a,"q""uote \\ back / slash","tab\there"',
					'b,"line',
					'break","cr\rret"',
					"c,\1\31\127,caf\u{E9} \u{1F600} \u{2028}",
					""
				)
			)
		).toBe(
			'[{"key":"a","source":"q\\"uote \\\\ back / slash","values":{"es":"tab\\there"}},{"key":"b","source":"line\\nbreak","values":{"es":"cr\\rret"}},{"key":"c","source":"\\u0001\\u001f\127","values":{"es":"caf\u{E9} \u{1F600} \u{2028}"}}]'
		)
		expect(contents(lines("Key,Source", "a,\"<b>&amp;</b> 'x'\"", ""))).toBe(
			'[{"key":"a","source":"<b>&amp;</b> \'x\'","values":{}}]'
		)
	end)

	it("refuses a record whose length differs from the headers'", function()
		expect(contents(lines("Key,Source", "a,A,extra", ""))).toMatch(
			"found record with 3 fields, but the previous record has 2 fields"
		)
		expect(contents(lines("Key,Source,es", "a,A", ""))).toMatch(
			"found record with 2 fields, but the previous record has 3 fields"
		)
		expect(contents(lines("Key,Source", '""', "a,A", ""))).toMatch(
			"found record with 1 fields, but the previous record has 2 fields"
		)
	end)

	it("refuses text that is not valid UTF-8", function()
		expect(decodeCsv(lines("Key,Source", "a,\xFF\xFE", "")).ok).toBe(false)
	end)
	it("names the record and the field counts in a refusal and names no path", function()
		local refused = decodeCsv("Key,Source\na,A\nb,B,extra\n")

		expect(refused.ok).toBe(false)
		expect(refused.error.path).toBe("")
		expect(refused.error.message).toBe(
			"File was not a valid LocalizationTable CSV file: CSV error: record 2: found record with 3 fields, but the previous record has 2 fields"
		)
	end)
end)
