local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local isIpAddress = require(ReplicatedStorage.WallyPlugin.PluginUtilities.isIpAddress)

local ACCEPTED = {
	"0.0.0.0",
	"255.255.255.255",
	"1:2:3:4:5:6:7:8",
	"1::",
	"::",
	"1:2:3:4:5:6:7::",
	"::1:2:3:4:5:6:7",
	"1:2:3:4:5:6:1.2.3.4",
	"::1.2.3.4",
	"00::",
	"0000:0::",
	"1::1.2.3.4",
	"1:2:3:4:5::6:7",
	"ABCD::ef",
	"1::2:3.4.5.6",
	"::ffff:1.2.3.4",
}
local REFUSED = {
	"",
	"localhost",
	" 1.2.3.4",
	"1.2.3",
	"1.2.3.4.5",
	"256.1.1.1",
	"01.2.3.4",
	"1.2.3.04",
	"1:2:3:4:5:6:7:8:9",
	"1.2.3.4::",
	"12345::",
	"g::",
	":1::",
	"1:::2",
	"1::2::3",
	"1:2:3:4:5:6:7:1.2.3.4",
	"::ffff:01.2.3.4",
	"1:2:3:4:5:6:7:8::",
	"::1:2:3:4:5:6:7:8",
	"1:2:3:4:5:6::1.2.3.4",
	"1:2:3:4:5:6:7::1.2.3.4",
	"fe80::1%eth0",
	"[::1]",
}

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("isIpAddress", function()
	it("accepts what Rust's IpAddr parser accepts, as Rojo 7.7.1 reads serveAddress", function()
		for _, address in ACCEPTED do
			expect({ address, isIpAddress(address) }).toEqual({ address, true })
		end
	end)

	it("refuses what it refuses: names, short or long forms, leading zeros, zones and brackets", function()
		for _, address in REFUSED do
			expect({ address, isIpAddress(address) }).toEqual({ address, false })
		end
	end)
end)
