-- Messenger must not evict unsent, unread, or pending sessions at its tab cap.
-- Run from the addon root: lua Tests/ConversationTabEviction.mock.lua
dofile("Tests/ConversationWindowsLayout.mock.lua")

local addon = ChattyChattyBangBang
local manager = addon.ConversationWindows
local engine = addon.MessageEngine
local settings = addon:GetSmartSettings()
local function expect(value, message)
	if not value then error(message, 2) end
end
local notices = {}
function addon:Print(message) notices[#notices + 1] = tostring(message or "") end

manager:ResetForProfile()
manager:SetEnabled(true)
settings.conversations.autoOpenWhispers = false
settings.conversations.deferInCombat = false
engine.messages = {}
local sessions = {}
for index = 1, 12 do
	if index == 2 then
		sessions[index] = manager:AcquireSession("SharedName", 517)
	elseif index == 4 then
		sessions[index] = manager:AcquireSession("SharedName")
	else
		sessions[index] = manager:AcquireSession("Tab" .. index)
	end
	expect(sessions[index], "could not establish twelve Messenger sessions")
	sessions[index].lastUsed = index
end
local shell = manager:SelectSession(sessions[12].playerKey)
shell:Show()
sessions[1].draft = "   " -- whitespace is still an unsent draft
sessions[2].unread = 2
sessions[2].unreadIds[200] = true
sessions[3].pendingVisible = 1
sessions[3].pendingIds[300] = true
local newcomer = manager:AcquireSession("Newcomer")
expect(newcomer and #manager.tabOrder == 12 and not manager.sessionsByKey.sharedname
	and manager.sessionsByKey["bnet:517"] == sessions[2]
	and manager.sessionsByKey[sessions[1].playerKey] == sessions[1]
	and manager.sessionsByKey[sessions[3].playerKey] == sessions[3]
	and manager.sessionsByKey[sessions[12].playerKey] == sessions[12],
	"oldest disposable WoW tab was not evicted ahead of protected drafts, unread, NEW, and active/BNet tabs")
expect(#notices == 0, "disposing of a safe read tab incorrectly reported a full protected cap")

-- With no disposable candidate, the tab cap is firm and the refusal visible.
manager:ResetForProfile()
manager:SetEnabled(true)
engine.messages = {}
notices = {}
sessions = {}
for index = 1, 12 do
	sessions[index] = manager:AcquireSession("Locked" .. index)
	sessions[index].draft = "unsent " .. index
end
sessions[2].draft = ""
sessions[2].unread = 1
sessions[3].draft = ""
sessions[3].pendingVisible = 1
sessions[4].draft = ""
sessions[4].sendState = "pending"
manager:SelectSession(sessions[12].playerKey)
local blocked, reason = manager:AcquireSession("Overflow")
expect(blocked == nil and reason == "protected-cap" and #manager.tabOrder == 12
	and not manager.sessionsByKey.overflow and #notices == 1
	and string.find(notices[1], "Close a tab", 1, true),
	"all-protected cap silently evicted a session or failed to explain the refusal")
local incoming = { id = 9000, event = "CHAT_MSG_WHISPER", sender = "Overflow",
	direction = "incoming", text = "still in history" }
engine.messages[1] = incoming
manager:OnMessage(incoming)
local opened, openReason = manager:OpenForRecord(incoming, true)
expect(opened == nil and openReason == "protected-cap"
	and not manager.sessionsByKey.overflow and #manager.tabOrder == 12
	and #notices == 1 and engine.messages[1] == incoming,
	"repeated cap attempts lost a protected tab, spammed notices, or dropped engine history")
for index = 1, 12 do
	expect(manager.sessionsByKey[sessions[index].playerKey] == sessions[index],
		"full cap discarded a protected session")
end

manager:RemoveSession(sessions[1].playerKey, true)
local admitted = manager:AcquireSession("Overflow")
expect(admitted and #manager.tabOrder == 12 and manager.sessionsByKey.overflow == admitted
	and manager.sessionsByKey[sessions[2].playerKey] == sessions[2],
	"explicitly freeing a slot did not admit the waiting sender safely")

print("ConversationTabEviction.mock.lua: PASS")
