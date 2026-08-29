-- Focused no-client contract for received-chat history settings. Run from the
-- addon root with: lua Tests/ChatHistorySettings.mock.lua

ChattyChattyBangBang = {
	db = {
		profile = {
			smartChat = {},
		},
	},
}

dofile("Core/Settings.lua")
local addon = ChattyChattyBangBang
local settings = addon:GetSmartSettings()
local exported = addon:GetChatHistorySettings()
assert(exported.enabled == true and exported.linesPerSource == 1000,
	"received history should start enabled at 1,000 lines per source")
assert(exported.minimumLinesPerSource == 100 and exported.maximumLinesPerSource == 10000,
	"history settings did not disclose their supported bounds")
exported.enabled = false
assert(settings.persistHistory == true, "history getter leaked its SavedVariables table")

local rebuilt, clearedPersistent, resized, cleared = 0, 0, 0, 0
addon.MessageEngine = {
	RebuildPersistence = function() rebuilt = rebuilt + 1 end,
	ClearPersistentHistory = function()
		clearedPersistent = clearedPersistent + 1
		settings.history = nil
	end,
	SetHistoryLinesPerSource = function(_, value)
		resized = resized + 1
		return value
	end,
	ClearHistory = function()
		cleared = cleared + 1
		return true
	end,
}

assert(not addon:SetChatHistoryLinesPerSource("not-a-number"),
	"invalid history capacity was accepted")
local ok, value = addon:SetChatHistoryLinesPerSource(50000)
assert(ok and value == 10000 and settings.historyCapacity == 10000 and resized == 1,
	"history did not support and clamp to 10,000 lines per source")
ok, value = addon:SetChatHistoryLinesPerSource(1)
assert(ok and value == 100 and settings.historyCapacity == 100 and resized == 2,
	"history did not clamp to its safe 100-line minimum")

settings.history = { secret = "plaintext transcript" }
assert(addon:SetChatHistoryPersistenceEnabled(false))
assert(settings.persistHistory == false and settings.history == nil and clearedPersistent == 1,
	"disabling persistence did not erase saved plaintext immediately")
assert(addon:SetChatHistoryPersistenceEnabled(true))
assert(settings.persistHistory == true and rebuilt == 1,
	"enabling persistence did not save the current bounded session history")

settings.history = { secret = "clear me" }
assert(addon:ClearChatHistory())
assert(settings.history == nil and cleared == 1,
	"clear history did not hand live and saved removal to MessageEngine")

-- The old prototype had no user-facing control and defaulted off. Promote that
-- hidden value exactly once; a schema-1 false is then a real privacy choice and
-- must stay off forever after.
addon.MessageEngine = nil
addon.db.profile.smartChat = {
	persistHistory = false,
	historyCapacity = 1500,
}
settings = addon:GetSmartSettings()
assert(settings.persistHistory == true and settings.historyCapacity == 1000
	and settings.historySettingsSchema == 1,
	"legacy hidden prototype was not promoted to the new 1,000-line feature")
settings.persistHistory = false
settings.historyCapacity = 777
settings = addon:GetSmartSettings()
assert(settings.persistHistory == false and settings.historyCapacity == 777,
	"an explicit post-migration history preference was overwritten")

print("Chat history settings mock tests passed")
