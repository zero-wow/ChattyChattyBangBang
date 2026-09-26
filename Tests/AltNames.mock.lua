-- Run from the Retail addon root: lua Tests/AltNames.mock.lua
local settings = {}
ChattyChattyBangBang = { GetSmartSettings = function() return settings end }
dofile("Core/AltNames.lua")
local aliases = ChattyChattyBangBang.AltNames

assert(aliases:GetHistorySenderNames("Mira")[1] == "Mira")
assert(aliases:Link("Mira-Area52", "Neri-Area52"))
assert(aliases:Link("Mira-Area52", "Sora-Area52"))
local names = aliases:GetHistorySenderNames("meri-Area52")
assert(#names == 1 and names[1] == "meri-Area52", "similar names must not match")
names = aliases:GetHistorySenderNames("mira-area52")
assert(#names == 3 and names[2] == "Neri-Area52", "exact linked history names missing")
assert(#aliases:GetHistorySenderNames("Mira-OtherRealm") == 1,
	"realm-qualified names were conflated")
assert(not aliases:Link("Mira-Area52", "Mira-Area52"))
assert(not aliases:Link("Mira-Area52", "BattleTag#1234"))
assert(not aliases:Link("Mira-Area52", "|cffff0000Injected"))
assert(not aliases:Link("Mira-Area52", string.char(0xC0, 0xAF) .. "bad"),
	"invalid UTF-8 was accepted")
assert(aliases:Link("Mira-Twisting Nether", "Neri-Twisting Nether"),
	"exact realm names with spaces were rejected")
assert(#aliases:GetHistorySenderNames("Mira-Twisting Nether") == 2)

local snapshot = aliases:GetGroups()
snapshot[1].names[1] = "Changed"
assert(aliases:GetGroups()[1].names[1] == "Mira-Area52", "getter exposed live settings")
assert(aliases:Unlink("Neri-Area52"))
assert(#aliases:GetHistorySenderNames("Mira-Area52") == 2)
assert(aliases:Unlink("Sora-Area52"))
assert(#aliases:GetGroups() == 1 and #aliases:GetHistorySenderNames("Mira-Area52") == 1,
	"last association did not dissolve")

assert(aliases:Link("Ada", "Bea"))
assert(aliases:Link("Cia", "Dia"))
assert(not aliases:Link("Ada", "Cia"), "separate groups merged without review")
assert(aliases:RemoveGroup(aliases:GetGroups()[1].id))
assert(#aliases:GetGroups() == 2)

settings.altNameGroups = { groups = { { id = 1, names = { "Legit", "Other", "|Hitem:1|hbad|h" } } } }
local clean = aliases:GetGroups()
assert(#clean == 1 and #clean[1].names == 2 and clean[1].names[1] == "Legit",
	"stored malformed names were not bounded and sanitized")
assert(aliases:GetHistorySenderNames("|Hitem:1|hbad|h") == nil)
settings.altNameGroups = { nextId = math.huge, groups = {
	{ id = 1, names = { "Legit", "Other" } },
	{ id = 1, names = { "Duplicate", "Group" } },
} }
assert(#aliases:GetGroups() == 1 and aliases:Link("Next", "Pair"),
	"malformed stored IDs or nextId prevented safe additions")

settings.altNameGroups = nil
for index = 1, 32 do
	local suffix = string.char(65 + math.floor((index - 1) / 26))
		.. string.char(65 + (index - 1) % 26)
	assert(aliases:Link("A" .. suffix, "B" .. suffix))
end
assert(not aliases:Link("Extra", "Other"), "group count cap failed")
for index = 1, 6 do assert(aliases:Link("AAA", "Extra" .. string.char(64 + index))) end
assert(not aliases:Link("AAA", "Overflow"), "group member cap failed")
print("Alt-name history association mock passed")
