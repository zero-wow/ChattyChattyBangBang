-- Run from the Retail addon root: lua Tests/PresentationEventTemplates.mock.lua

ChattyChattyBangBang = {}
local addon = ChattyChattyBangBang
addon.Theme = {
	GetPalette = function()
		return { text = { 1, 1, 1 }, textMuted = { 1, 1, 1 }, borderMuted = { 1, 1, 1 } }
	end,
	GetColor = function()
		return 1, 1, 1
	end,
}
addon.GetSmartSettings = function()
	return { keywordColorGroups = {}, keywordColors = {}, dock = {} }
end

dofile("Core/Presentation.lua")
local presentation = addon.Presentation

local savedGuildAchievement = {
	id = 1,
	event = "CHAT_MSG_GUILD_ACHIEVEMENT",
	sender = "Cindry-Hyjal",
	text = "%s has earned the achievement |cffffff00|Hachievement:10826|h[Mythic: Cenarius]|h|r!",
}
local original = savedGuildAchievement.text
assert(presentation:FormatEventText(savedGuildAchievement) ==
	"Cindry-Hyjal has earned the achievement |cffffff00|Hachievement:10826|h[Mythic: Cenarius]|h|r!",
	"saved guild-achievement template was not formatted using its event sender")
local _, rendered = presentation:FormatParts(savedGuildAchievement)
assert(string.find(rendered, "Cindry-Hyjal has earned", 1, true),
	"historical achievement still showed a raw %s in the visible chat row")
assert(savedGuildAchievement.text == original, "presentation modified the historical raw record")

assert(presentation:FormatEventText({
	event = "CHAT_MSG_ACHIEVEMENT", sender = "Mira", text = "%1$s earned it (100%% complete)",
}) == "Mira earned it (100% complete)", "positional or escaped percent format failed")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_GUILD_ACHIEVEMENT", text = "%2$s earned %1$s at level %3$d",
	formatArgs = { "Hero", "Mira", 80 },
}) == "Mira earned Hero at level 80", "multiple typed positional arguments failed")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_ACHIEVEMENT", text = "%s reached %03d", formatArgs = { "Mira", 7 },
}) == "Mira reached 007", "sequential typed arguments failed")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_ACHIEVEMENT", text = "%2$s reached %s", formatArgs = { "Mira" },
}) == "%2$s reached Mira", "missing positional argument was guessed")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_ACHIEVEMENT", sender = "Mira", text = "%s has %t and 100% progress",
}) == "Mira has %t and 100% progress", "native substitution or literal percent was corrupted")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_GUILD_ITEM_LOOTED", sender = "Mira", text = "$s looted an item",
}) == "Mira looted an item", "guild-item event's native $s replacement failed")

for _, event in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_GUILD", "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT" }) do
	assert(presentation:FormatEventText({ event = event, sender = "Mira", text = "%s says 100%%" })
		== "%s says 100%%", event .. " was incorrectly treated as a printf template")
end

local oldCanAccess = _G.canaccessvalue
_G.canaccessvalue = function(value) return value ~= "secret" end
assert(presentation:FormatEventText({
	event = "CHAT_MSG_ACHIEVEMENT", sender = "secret", text = "%s has earned it",
}) == "%s has earned it", "inaccessible Retail payload was formatted")
_G.canaccessvalue = oldCanAccess

print("Presentation event-template tests passed")
