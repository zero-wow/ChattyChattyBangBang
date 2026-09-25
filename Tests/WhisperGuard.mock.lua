-- Run from the Retail addon root with: lua Tests/WhisperGuard.mock.lua
unpack = unpack or table.unpack
local now = 100
local printed, popups, filters = {}, {}, {}
local settings = {
	historyCapacity = 150, persistHistory = false, learnedSources = {},
	customViewRevision = 0, channelTargets = {},
}
ChattyChattyBangBang = {
	GetSmartSettings = function() return settings end,
	GetSmartViews = function() return {} end,
	Print = function(_, message) printed[#printed + 1] = message end,
}
GetRealmName = function() return "Home Realm" end
GetTime = function() return now end
time = function() return 1700000000 + math.floor(now) end
date = function() return "12:00" end
C_FriendList = {
	IsFriend = function(guid) return guid == "Friend-GUID" end,
	GetNumFriends = function() return 1 end,
	GetFriendInfoByIndex = function() return { name = "Friend" } end,
}
IsInGuild = function() return true end
GetNumGuildMembers = function() return 1 end
GetGuildRosterInfo = function() return "Guildie" end
CreateFrame = function()
	return {
		SetScript = function(self, name, callback) self[name] = callback end,
		RegisterEvent = function() return true end,
		UnregisterAllEvents = function() return true end,
	}
end
ChatFrame_AddMessageEventFilter = function(event, filter)
	filters[event] = filter
	return true
end
ChatFrame_RemoveMessageEventFilter = function(event, filter)
	if filters[event] == filter then filters[event] = nil end
end
StaticPopupDialogs = {}
StaticPopup_Show = function(which, text)
	popups[#popups + 1] = { which = which, text = text }
end

dofile("Core/WhisperGuard.lua")
dofile("Core/MessageEngine.lua")
local guard = ChattyChattyBangBang.WhisperGuard
local engine = ChattyChattyBangBang.MessageEngine
guard:Initialize()
engine:Initialize()
engine:SetEnabled(true)
assert(filters.CHAT_MSG_WHISPER and guard:GetStatus().filterActive,
	"native whisper filter was not registered with active Smart Chat")
assert(settings.whisperGuard.enabled == true, "first-contact quarantine did not default on")

local function incoming(sender, message, lineId)
	local args = { message, sender, nil, nil, nil, nil, nil, nil, nil, nil, lineId }
	local nativeHidden = filters.CHAT_MSG_WHISPER(nil, "CHAT_MSG_WHISPER", unpack(args, 1, 11))
	engine:Capture("CHAT_MSG_WHISPER", unpack(args, 1, 11))
	return nativeHidden
end

assert(filters.CHAT_MSG_WHISPER(nil, "CHAT_MSG_WHISPER", "abusive private text", "Stranger") == true
	and #guard:GetSummaries() == 0,
	"native ChatFrame filter wrote quarantine data during fanout")
assert(incoming("Stranger", "abusive private text", 1) == true,
	"native filter did not hide a readable stranger whisper")
assert(#engine:GetMessages() == 0 and #guard:GetSummaries() == 1
	and guard:GetSummaries()[1].count == 1,
	"stranger whisper entered normal history or was archived more than once")
local entry = guard:GetEntry(1)
assert(entry and entry.text == "abusive private text" and entry.sender == "Stranger",
	"private review record lost the held text")

printed = {}
guard:HandleCommand("list")
local listText = table.concat(printed, "\n")
assert(string.find(listText, "Stranger", 1, true)
	and not string.find(listText, "abusive private text", 1, true),
	"quarantine list exposed private text in chat")
guard:HandleCommand("show 1")
assert(popups[1] and string.find(popups[1].text, "abusive private text", 1, true),
	"explicit SHOW did not open private review")

assert(incoming("Friend", "friend hello", 2) == false, "friend was quarantined")
assert(incoming("Guildie", "guild hello", 3) == false, "guild member was quarantined")
assert(#engine:GetMessages() == 2, "trusted social whispers did not reach normal history")

engine:Capture("CHAT_MSG_WHISPER_INFORM", "my inquiry", "Customer")
assert(incoming("Customer", "answer", 4) == false,
	"reply to an outgoing correspondent was quarantined")
local beforeApproval = #engine:GetMessages()
local approved, released = guard:ApproveSender("Stranger")
assert(approved and released == 1 and #guard:GetSummaries() == 0
	and #engine:GetMessages() == beforeApproval + 1,
	"approval did not release the held first whisper exactly once")
assert(incoming("Stranger", "approved reply", 5) == false
	and #engine:GetMessages() == beforeApproval + 2,
	"explicit approval did not release future whispers")
assert(guard:BlockSender("Friend") and incoming("Friend", "blocked despite friendship", 6) == true,
	"local block did not override friend trust")
assert(#guard:GetSummaries() == 0, "locally blocked friend entered private review trail")
assert(guard:UnblockSender("Friend") and incoming("Friend", "unblocked", 7) == false,
	"unblock did not restore friend trust")

local secret = {}
canaccessvalue = function(value) return value ~= secret end
local before = #engine:GetMessages()
assert(filters.CHAT_MSG_WHISPER(nil, "CHAT_MSG_WHISPER", secret, "Unknown") == false,
	"secret native payload was silently hidden")
engine:Capture("CHAT_MSG_WHISPER", secret, "Unknown")
assert(#engine:GetMessages() == before and guard:GetStatus().unreadable == 1,
	"secret Retail payload was not marked as degraded")
canaccessvalue = nil

guard:SetProtectionEnabled(false)
assert(incoming("Another", "protection explicitly off", 8) == false,
	"disabled protection still hid a stranger")
guard:SetProtectionEnabled(true)
assert(incoming("NewStranger", "new held contact", 9) == true,
	"new stranger was not held after re-enabling protection")
assert(guard:ClearQuarantine() == 1 and #guard:GetSummaries() == 0,
	"explicit clear did not erase held plaintext")
engine:SetEnabled(false)
assert(filters.CHAT_MSG_WHISPER == nil and not guard:GetStatus().filterActive,
	"native filter remained active without Smart Chat review capture")

print("Whisper guard mock tests passed")
