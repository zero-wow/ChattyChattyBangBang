-- Battle.net Messenger contract. Run from the addon root with:
-- lua Tests/ConversationBNet.mock.lua
dofile("Tests/ConversationWindowsLayout.mock.lua")

local addon = ChattyChattyBangBang
local manager = addon.ConversationWindows
local engine = addon.MessageEngine
local settings = addon:GetSmartSettings()
local function expect(value, message)
	if not value then error(message, 2) end
end

manager:ResetForProfile()
manager:SetEnabled(true)
settings.conversations.autoOpenWhispers = false
settings.conversations.deferInCombat = false
engine.messages = {}

local nativeOutgoing = {
	id = 1000, event = "CHAT_MSG_BN_WHISPER_INFORM", isBNet = true,
	sender = "NativeFriend", bnetAccountId = "991", direction = "outgoing",
	text = "sent from Friends UI",
}
engine.messages[1] = nativeOutgoing
manager:OnMessage(nativeOutgoing)
local nativeSession = manager.sessionsByKey["bnet:991"]
expect(nativeSession and nativeSession.unread == 0 and not manager:GetShell().frame:IsShown(),
	"native Battle.net outgoing inform failed to create a quiet account tab")
manager:SelectSession("bnet:991")
expect(manager:GetShell().display:GetNumMessages() == 1,
	"native Battle.net outgoing inform did not appear in its account history")
manager:Close("bnet:991")
engine.messages = {}

-- Retail arg13 is bnSenderID; arg14 isMobile may have been copied into the
-- record's extended ID field by the shared, legacy-compatible normalizer.
local incoming = {
	id = 1001, event = "CHAT_MSG_BN_WHISPER", isBNet = true,
	sender = "SameName", presenceId = 517, bnetAccountId = "false",
	direction = "incoming", text = "BNet hello",
}
engine.messages[1] = incoming
manager:OnMessage(incoming)
local bnetSession = manager.sessionsByKey["bnet:517"]
expect(bnetSession and bnetSession.bnetAccountID == 517
	and bnetSession.playerName == "SameName" and bnetSession.unread == 1,
	"incoming Battle.net whisper did not create an ID-keyed tab")
expect(not manager.sessionsByKey.samename, "Battle.net account was keyed by display name")
local shell = manager:GetShell()
expect(not shell.frame:IsShown(), "popup-disabled Battle.net tab opened the shell")

local invalid = {
	id = 1002, event = "CHAT_MSG_BN_WHISPER", isBNet = true,
	sender = "Unknown", presenceId = 0, bnetAccountId = "true",
	direction = "incoming", text = "missing identity",
}
manager:OnMessage(invalid)
expect(not manager.sessionsByKey.unknown and not manager.sessionsByKey["bnet:0"],
	"missing Battle.net ID opened an unsafe name-keyed session")
expect(manager:OpenForRecord(invalid, true) == nil,
	"explicit Battle.net open accepted a missing account ID")

local wow = {
	id = 1003, event = "CHAT_MSG_WHISPER", isBNet = false,
	sender = "SameName", direction = "incoming", text = "WoW hello",
}
engine.messages[2] = wow
manager:OnMessage(wow)
expect(manager.sessionsByKey.samename and manager.sessionsByKey.samename ~= bnetSession,
	"same-name WoW and Battle.net contacts merged into one tab")
manager:SelectSession("bnet:517")
shell:Show()
expect(shell:GetActiveSession() == bnetSession and shell.subtitle:GetText() == "BATTLE.NET"
	and shell.route:GetText() == "BN SameName" and shell.display:GetNumMessages() == 1,
	"Battle.net tab did not show its distinct route and isolated history")

local outgoing = {
	id = 1004, event = "CHAT_MSG_BN_WHISPER_INFORM", isBNet = true,
	sender = "SameName", presenceId = 517, bnetAccountId = "true",
	direction = "outgoing", text = "sent earlier",
}
engine.messages[3] = outgoing
manager:OnMessage(outgoing)
expect(shell.display:GetNumMessages() == 2,
	"outgoing Battle.net inform did not join its account's session")

local sends = {}
C_BattleNet = {
	SendWhisper = function(id, message)
		sends[#sends + 1] = { id, message }
		return true
	end,
}
local wowSends = 0
C_ChatInfo = { SendChatMessage = function() wowSends = wowSends + 1 end }
shell.editBox:SetText("BNet reply")
shell.editBox.scripts.OnTextChanged(shell.editBox)
shell.editBox.scripts.OnEnterPressed(shell.editBox)
expect(#sends == 1 and sends[1][1] == 517 and sends[1][2] == "BNet reply"
	and wowSends == 0 and shell.editBox:GetText() == "" and bnetSession.draft == "",
	"Battle.net reply used a character whisper or failed to clear a successful draft")
expect(bnetSession.sendState == "pending" and bnetSession.pendingSendText == "BNet reply"
	and shell.subtitle:GetText() == "PENDING",
	"successful local Battle.net call was falsely labeled delivered")
manager:OnMessage({ event = "CHAT_MSG_BN_WHISPER_INFORM", isBNet = true,
	sender = "Other", bnetAccountId = "518", text = "BNet reply" })
manager:OnMessage({ event = "CHAT_MSG_BN_WHISPER_INFORM", isBNet = true,
	sender = "SameName", bnetAccountId = "517", text = "different line" })
expect(bnetSession.sendState == "pending", "unrelated outgoing echo acknowledged the pending send")
manager:OnMessage({ event = "CHAT_MSG_BN_WHISPER_INFORM", isBNet = true,
	sender = "SameName", bnetAccountId = "517", text = "BNet reply" })
expect(bnetSession.sendState == "echoed" and shell.subtitle:GetText() == "ECHOED"
	and bnetSession.pendingSendText == nil,
	"matching Battle.net chat echo did not resolve pending status")

C_BattleNet.SendWhisper = function() return false end
shell.editBox:SetText("retry false")
shell.editBox.scripts.OnTextChanged(shell.editBox)
shell:Send()
expect(shell.editBox:GetText() == "retry false" and bnetSession.draft == "retry false",
	"failed Battle.net send discarded the draft")
expect(bnetSession.sendState == "failed" and shell.subtitle:GetText() == "FAILED",
	"Battle.net API rejection did not show failure in Messenger")
C_BattleNet.SendWhisper = function() return nil end
shell:Send()
expect(shell.editBox:GetText() == "retry false" and bnetSession.draft == "retry false",
	"Retail Battle.net send without a success result discarded the draft")
C_BattleNet.SendWhisper = function() error("mock failure") end
shell:Send()
expect(shell.editBox:GetText() == "retry false" and bnetSession.draft == "retry false",
	"Battle.net send exception discarded the draft")
C_BattleNet = nil
BNSendWhisper = nil
shell:Send()
expect(shell.editBox:GetText() == "retry false" and bnetSession.draft == "retry false",
	"unavailable Battle.net send discarded the draft")
BNSendWhisper = function(id, message)
	sends[#sends + 1] = { id, message }
end
shell:Send()
expect(#sends == 2 and sends[2][1] == 517 and sends[2][2] == "retry false"
	and shell.editBox:GetText() == "", "legacy Battle.net send fallback failed")
expect(bnetSession.sendState == "pending" and shell.subtitle:GetText() == "PENDING",
	"legacy Battle.net dispatch was mistaken for delivery")
local originalGetTime = GetTime
GetTime = function() return 116 end
shell.frame.scripts.OnUpdate(shell.frame, 0.1)
expect(bnetSession.sendState == "unconfirmed" and shell.subtitle:GetText() == "NO ECHO"
	and bnetSession.pendingSendText == "retry false",
	"missing chat echo was incorrectly reported as successful or a proven failure")
GetTime = originalGetTime
manager:OnMessage({ event = "CHAT_MSG_BN_WHISPER_INFORM", isBNet = true,
	sender = "SameName", bnetAccountId = "517", text = "retry false" })
expect(bnetSession.sendState == "echoed", "late Battle.net chat echo was not recognized")
BNSendWhisper = nil

-- Character actions must not silently target an unrelated in-game character
-- whose name happens to match this Battle.net display name.
local wrongTargetActions = 0
addon.Compatibility.InvitePlayer = function() wrongTargetActions = wrongTargetActions + 1 end
addon.Compatibility.AddFriend = function() wrongTargetActions = wrongTargetActions + 1 end
addon.Compatibility.AddServerIgnore = function() wrongTargetActions = wrongTargetActions + 1 end
shell.actionButtons[2].scripts.OnClick()
shell.actionButtons[3].scripts.OnClick()
expect(shell:ApplyLocalIgnore() == false and shell:ApplyServerIgnore() == false
	and shell:ShowServerIgnoreConfirmation() == false and wrongTargetActions == 0,
	"Battle.net tab dispatched a character-name social action")

local renamed = {
	id = 1005, event = "CHAT_MSG_BN_WHISPER", isBNet = true,
	sender = "Renamed", bnetAccountId = "517", direction = "incoming", text = "new name",
}
engine.messages[4] = renamed
manager:OnMessage(renamed)
expect(manager.sessionsByKey["bnet:517"] == bnetSession and bnetSession.playerName == "Renamed"
	and shell.playerName == "Renamed" and shell.display:GetNumMessages() == 3,
	"account-name change split the Battle.net conversation or left its header stale")

manager:SelectSession("samename")
local wowSession = shell:GetActiveSession()
C_ChatInfo.SendChatMessage = function() end -- Retail documents no success return.
shell.editBox:SetText("WoW pending")
shell.editBox.scripts.OnTextChanged(shell.editBox)
shell:Send()
expect(wowSession.sendState == "pending" and shell.subtitle:GetText() == "PENDING"
	and wowSession.pendingSendText == "WoW pending" and shell.editBox:GetText() == "",
	"character send without a return value was treated as delivered or failed")
manager:OnMessage({ event = "CHAT_MSG_WHISPER_INFORM", isBNet = false,
	sender = "SameName", text = "WoW pending" })
expect(wowSession.sendState == "echoed" and shell.subtitle:GetText() == "ECHOED",
	"character chat echo did not resolve its own pending status")
C_ChatInfo.SendChatMessage = function() error("character send failed") end
shell.editBox:SetText("WoW retry")
shell.editBox.scripts.OnTextChanged(shell.editBox)
shell:Send()
expect(wowSession.sendState == "failed" and shell.subtitle:GetText() == "FAILED"
	and wowSession.draft == "WoW retry" and shell.editBox:GetText() == "WoW retry",
	"character API failure did not show FAILED while preserving the draft")
manager:SelectSession("bnet:517")
expect(shell.subtitle:GetText() == "ECHOED", "character send status leaked into Battle.net tab")
manager:SelectSession("samename")
expect(shell.subtitle:GetText() == "FAILED" and shell.editBox:GetText() == "WoW retry",
	"failed character send lost its status or draft after a tab switch")

print("ConversationBNet.mock.lua: PASS")
