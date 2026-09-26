-- Run from the Retail addon root: lua Tests/GuildReadability.mock.lua

local now = 1
local roster = {
	{ name = "Mira-Azshara", class = "MAGE" },
	{ name = "Tayto", class = "DRUID" },
}

GetTime = function() return now end
GetNumGuildMembers = function() return #roster end
GetGuildRosterInfo = function(index)
	local member = roster[index]
	return member.name, nil, nil, nil, nil, nil, nil, nil, nil, nil, member.class
end
RAID_CLASS_COLORS = {
	MAGE = { r = 0, g = 0.5, b = 1 },
	DRUID = { r = 1, g = 0.5, b = 0 },
}
local smartSettings = { keywordColorGroups = {}, keywordColors = {}, dock = { classColorNames = true } }

ChattyChattyBangBang = {
	GetSmartSettings = function()
		return smartSettings
	end,
	Theme = {
		GetPalette = function()
			return { text = { 1, 1, 1 }, textMuted = { 0.6, 0.6, 0.6 },
				success = { 0.2, 0.8, 0.4 }, borderMuted = { 0.5, 0.5, 0.5 } }
		end,
		GetColor = function(self, key)
			local color = self:GetPalette()[key] or self:GetPalette().text
			return color[1], color[2], color[3]
		end,
	},
}

dofile("Core/Presentation.lua")
local presentation = ChattyChattyBangBang.Presentation

local ordinary = {
	id = 1, event = "CHAT_MSG_GUILD", view = "guild", sender = "Mira-Azshara",
	text = "Ready for the run?", timestamp = "12:00",
}
local leader, body = presentation:FormatParts(ordinary)
assert(leader:find("|cff007fffMira-Azshara|r", 1, true),
	"exact guild roster sender was not class-colored when the event GUID lacked a class")
assert(body == ordinary.text, "ordinary guild message body was recolored or rewritten")
assert(ordinary.class == nil and ordinary.text == "Ready for the run?",
	"guild presentation changed the captured record")
assert(presentation:GetColoredName({ event = "CHAT_MSG_GUILD", sender = "Tayto", class = "MAGE" })
	== "|cff007fffTayto|r", "event GUID class did not take priority over roster class")
assert(presentation:GetColoredName({ event = "CHAT_MSG_GUILD", sender = "Mira-Other" })
	== "|cff33cc66Mira-Other|r", "same-name sender from another realm inherited a guildmate's class")
assert(presentation:GetColoredName({ event = "CHAT_MSG_GUILD", sender = "Unknown" })
	== "|cff33cc66Unknown|r", "unknown guild sender was not visually distinct from plain message text")
assert(presentation:GetColoredName({ event = "CHAT_MSG_SAY", sender = "Unknown" })
	== "|cffffffffUnknown|r", "guild-only fallback changed other chat views")
smartSettings.dock.classColorNames = false
assert(presentation:GetColoredName({ event = "CHAT_MSG_GUILD", sender = "Mira-Azshara", class = "MAGE" })
	== "|cff33cc66Mira-Azshara|r", "class-color off did not retain distinct guild sender fallback")
assert(presentation:GetColoredName({ event = "CHAT_MSG_SAY", sender = "Mira-Azshara", class = "MAGE" })
	== "|cffffffffMira-Azshara|r", "class-color off still colored non-guild sender by class")
smartSettings.dock.classColorNames = true

local achievement = {
	id = 2, event = "CHAT_MSG_GUILD_ACHIEVEMENT", view = "guild",
	sender = "Mira-Azshara", timestamp = "12:01",
	text = "%s has earned the achievement |cffffff00|Hachievement:1|h[Sky]|h|r!",
}
local original = achievement.text
local achievementLeader, announcement = presentation:FormatParts(achievement)
assert(not achievementLeader:find("Mira-Azshara", 1, true),
	"guild achievement repeated its embedded sender in a separate sender lane")
assert(announcement:find("|cff007fffMira-Azshara|r", 1, true)
	and announcement:find("|cff999999 has earned the achievement |r", 1, true),
	"guild achievement did not distinguish player name from muted announcement text")
assert(announcement:find("|cffffff00|Hachievement:1|h[Sky]|h|r", 1, true),
	"guild achievement recolored or damaged the native achievement link")
assert(achievement.text == original and achievement.class == nil,
	"guild achievement presentation changed its historical raw record")
local _, localizedAnnouncement = presentation:FormatParts({
	id = 4, event = "CHAT_MSG_GUILD_ACHIEVEMENT", view = "guild",
	sender = "Mira-Azshara", text = "Achievement earned by %s: |Hachievement:2|h[Peak]|h",
})
assert(localizedAnnouncement:find("|cff999999Achievement earned by |r|cff007fffMira-Azshara|r", 1, true)
	and localizedAnnouncement:find("|Hachievement:2|h[Peak]|h", 1, true),
	"non-leading localized guild achievement sender or native link lost its styling")
local ordinaryAchievementLeader = presentation:FormatParts({
	id = 3, event = "CHAT_MSG_ACHIEVEMENT", view = "general", sender = "Mira-Azshara",
	text = "%s has earned an achievement", timestamp = "12:02",
})
assert(not ordinaryAchievementLeader:find("Mira-Azshara", 1, true),
	"ordinary achievement repeated its embedded sender in a separate sender lane")

roster = {
	{ name = "Shared-Realm", class = "MAGE" },
	{ name = "Shared-Realm", class = "DRUID" },
}
now = 32
assert(presentation:GetColoredName({ event = "CHAT_MSG_GUILD", sender = "Shared-Realm" })
	== "|cff33cc66Shared-Realm|r", "conflicting roster entries produced a guessed class")

local secretMarker = {}
canaccessvalue = function(value) return value ~= secretMarker end
roster = { { name = secretMarker, class = "MAGE" } }
now = 63
assert(presentation:GetColoredName({ event = "CHAT_MSG_GUILD", sender = "Hidden" })
	== "|cff33cc66Hidden|r", "restricted roster name was inspected or used")
assert(presentation:GetColoredName({ event = "CHAT_MSG_GUILD", sender = "Hidden", class = secretMarker })
	== "|cff33cc66Hidden|r", "restricted GUID class was inspected or used")
canaccessvalue = nil

print("Guild readability tests passed")
