-- Private SavedVariables retention must not change live Messenger history.
-- Run from addon root: lua Tests/ChatPrivateHistory.mock.lua

local now = 100
ChattyChattyBangBang = {
	db = { profile = { smartChat = {
		historySettingsSchema = 1, historyCapacity = 100,
		persistHistory = true, learnedSources = {},
	} } },
	Print = function() end,
}
GetTime = function() return now end
time = function() return 1700000000 + now end
date = function() return "12:00" end
CreateFrame = function()
	return {
		SetScript = function(self, name, callback) self[name] = callback end,
		RegisterEvent = function() return true end,
		UnregisterAllEvents = function() return true end,
	}
end

dofile("Core/Settings.lua")
dofile("Core/MessageEngine.lua")
local addon = ChattyChattyBangBang
local engine = addon.MessageEngine
local settings = addon:GetSmartSettings()
engine:Initialize()

local nextId = 0
local function add(event, text, sender, sourceId)
	now = now + 1
	nextId = nextId + 1
	return engine:Deliver({ id = nextId, event = event, text = text, sender = sender,
		sourceId = sourceId, sourceLabel = sourceId, epoch = time(),
		view = event == "CHAT_MSG_CHANNEL" and "general" or "conversations",
		views = { [event == "CHAT_MSG_CHANNEL" and "general" or "conversations"] = true },
	})
end
local function savedTexts()
	local texts = {}
	for _, ring in pairs(settings.history and settings.history.sources or {}) do
		for _, record in pairs(ring.records or {}) do
			texts[record.text] = true
		end
	end
	return texts
end
local function visibleTexts()
	local texts = {}
	for _, record in ipairs(engine:GetMessages()) do texts[record.text] = true end
	return texts
end

assert(addon:GetChatHistoryPrivacySettings().saveWhispers
	and addon:GetChatHistoryPrivacySettings().saveBattleNet,
	"old profiles must keep private persistence enabled by default")
assert(not addon:SetChatHistoryPrivateSaveEnabled("whispers", nil)
	and addon:GetChatHistoryPrivacySettings().saveWhispers,
	"invalid private-save input silently changed the opt-out")
add("CHAT_MSG_WHISPER", "old whisper", "A", "conversation:incoming")
add("CHAT_MSG_BN_WHISPER", "old bnet", "B", "conversation:bnet")
add("CHAT_MSG_CHANNEL", "public", "C", "channel:general")
assert(savedTexts()["old whisper"] and savedTexts()["old bnet"] and savedTexts()["public"],
	"default save policy failed")

assert(addon:SetChatHistoryPrivateSaveEnabled("whispers", false))
assert(addon:SetChatHistoryPrivateSaveEnabled("battleNet", false))
add("CHAT_MSG_WHISPER_INFORM", "new whisper", "A", "conversation:outgoing")
add("CHAT_MSG_BN_WHISPER_INFORM", "new bnet", "B", "conversation:bnet-outgoing")
add("CHAT_MSG_BN_CONVERSATION", "new bnet room", "B", "conversation:bnet-room")
local saved = savedTexts()
assert(saved["old whisper"] and saved["old bnet"] and saved["public"]
	and not saved["new whisper"] and not saved["new bnet"]
	and not saved["new bnet room"],
	"turning off future private saves either purged old records or saved new ones")
assert(visibleTexts()["new whisper"] and visibleTexts()["new bnet"],
	"private opt-out hid current-session Messenger lines")
engine:RebuildPersistence()
saved = savedTexts()
assert(saved["old whisper"] and saved["old bnet"]
	and not saved["new whisper"] and not saved["new bnet"],
	"persistence rebuild leaked unsaved private text or pruned old saved text")
engine:ResetForProfile()
saved = savedTexts()
assert(saved["old whisper"] and saved["old bnet"]
	and visibleTexts()["old whisper"] and visibleTexts()["old bnet"]
	and not visibleTexts()["new whisper"] and not visibleTexts()["new bnet"],
	"reload with future private saving off lost old saved copies or restored opted-out lines")
add("CHAT_MSG_WHISPER_INFORM", "new whisper", "A", "conversation:outgoing")
add("CHAT_MSG_BN_WHISPER_INFORM", "new bnet", "B", "conversation:bnet-outgoing")
add("CHAT_MSG_BN_CONVERSATION", "new bnet room", "B", "conversation:bnet-room")

local ok, cleared = addon:ClearSavedPrivateChatHistory("whispers")
assert(ok and cleared == 1, "scoped whisper clear count was wrong")
saved = savedTexts()
assert(not saved["old whisper"] and saved["old bnet"] and saved["public"]
	and not saved["new whisper"],
	"whisper clear touched Battle.net/public history or failed to remove saved whisper")
assert(visibleTexts()["old whisper"] and visibleTexts()["new whisper"],
	"saved-only whisper clear removed current-session history")
engine:RebuildPersistence()
assert(not savedTexts()["old whisper"], "cleared whisper resurrected during rebuild")

ok, cleared = addon:ClearSavedPrivateChatHistory("battleNet")
assert(ok and cleared == 1, "scoped Battle.net clear count was wrong")
assert(not savedTexts()["old bnet"] and savedTexts()["public"]
	and visibleTexts()["old bnet"] and visibleTexts()["new bnet room"],
	"Battle.net saved-only clear failed or hid live Messenger messages")
engine:RebuildPersistence()
assert(not savedTexts()["old bnet"], "cleared Battle.net record resurrected during rebuild")
engine:ResetForProfile()
assert(visibleTexts()["public"] and not visibleTexts()["old whisper"]
	and not visibleTexts()["new whisper"] and not visibleTexts()["old bnet"]
	and not visibleTexts()["new bnet"],
	"reload restored explicitly cleared or unsaved private records")

-- Master history-off erases SavedVariables immediately. As before, turning it
-- back on can save still-visible current-session lines. A confirmed private
-- clear above is different: its excluded lines never return during rebuild.
assert(addon:SetChatHistoryPrivateSaveEnabled("whispers", true))
add("CHAT_MSG_WHISPER", "later whisper", "A", "conversation:incoming")
assert(savedTexts()["later whisper"], "private saving could not be re-enabled")
addon:SetChatHistoryPersistenceEnabled(false)
assert(settings.history == nil, "master history-off did not erase SavedVariables")
addon:SetChatHistoryPersistenceEnabled(true)
assert(savedTexts()["later whisper"],
	"master history re-enable stopped saving still-visible session messages")
assert(not savedTexts()["old whisper"] and not savedTexts()["old bnet"],
	"master history re-enable resurrected explicitly cleared private messages")

print("Private chat history mock passed")
