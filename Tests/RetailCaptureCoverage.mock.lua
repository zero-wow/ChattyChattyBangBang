-- Focused no-client coverage for additional native chat event families.
-- Run from the addon root with: lua Tests/RetailCaptureCoverage.mock.lua

local settings = {
	enabled = true, historyCapacity = 100, persistHistory = false,
	learnedSources = {}, customViews = {}, customViewRevision = 0,
	channelTargets = {},
}
local registered = {}
ChattyChattyBangBang = {
	GetSmartSettings = function() return settings end,
	GetSmartViews = function() return {} end,
	IsRecordAllowedInView = function() return true end,
	Print = function() end,
}
GetTime = function() return 1 end
time = function() return 1700000000 end
date = function() return "12:00" end
CreateFrame = function()
	return {
		SetScript = function() end,
		RegisterEvent = function(_, event) registered[event] = true; return true end,
		UnregisterAllEvents = function() end,
	}
end

dofile("Core/MessageEngine.lua")
local engine = ChattyChattyBangBang.MessageEngine
engine:Initialize()
engine:SetEnabled(true)

local cases = {
	{ "CHAT_MSG_MONSTER_SAY", "system", "system:npc-dialogue" },
	{ "CHAT_MSG_RAID_BOSS_EMOTE", "system", "system:boss" },
	{ "CHAT_MSG_IGNORED", "system", "system:chat-status" },
	{ "CHAT_MSG_COMBAT_XP_GAIN", "system", "system:progress" },
	{ "CHAT_MSG_CURRENCY", "loot", "loot:currency" },
	{ "CHAT_MSG_TRADESKILLS", "loot", "loot:crafting" },
	{ "CHAT_MSG_OPENING", "loot", "loot:crafting" },
	{ "CHAT_MSG_PET_INFO", "system", "system:pet-info" },
	{ "CHAT_MSG_COMBAT_MISC_INFO", "system", "system:combat-misc" },
	{ "CHAT_MSG_TARGETICONS", "system", "system:target-icons" },
	{ "CHAT_MSG_BN_INLINE_TOAST_ALERT", "system", "system:bnet-alert" },
	{ "CHAT_MSG_PET_BATTLE_INFO", "system", "system:pet-battle" },
	{ "CHAT_MSG_PING", "system", "system:ping" },
	{ "CHAT_MSG_VOICE_TEXT", "system", "system:voice-text" },
	{ "CHAT_MSG_GUILD_DISCORD", "guild", "guild:discord" },
}
for _, case in ipairs(cases) do
	local event, view, sourceId = case[1], case[2], case[3]
	assert(registered[event], event .. " was not registered for capture")
	local record = assert(engine:Normalize(event, "Sample " .. event, "NPC"))
	assert(record.view == view and record.sourceId == sourceId,
		event .. " did not retain its factual source and expected view")
end

local bnet = assert(engine:Normalize("CHAT_MSG_BN_WHISPER", "hello", "BNetFriend",
	nil, nil, nil, nil, nil, nil, nil, nil, 77, nil, 501, true))
assert(bnet.bnetAccountId == "501" and bnet.isBNet,
	"Retail mobile-status boolean displaced the Battle.net account identity: " .. tostring(bnet.bnetAccountId))

print("Retail capture coverage mock tests passed")
