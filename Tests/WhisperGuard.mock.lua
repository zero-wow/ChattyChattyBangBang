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
local guildRosterRequests, legacyRosterReads, legacyRosterRequests = 0, 0, 0
local guildRosterReady = false
GetGuildRosterInfo = function()
	legacyRosterReads = legacyRosterReads + 1
	return "LegacyGuildie"
end
C_GuildInfo = {
	GuildRoster = function() guildRosterRequests = guildRosterRequests + 1 end,
	MemberExistsByName = function(name)
		return name == "Guildie" or (guildRosterReady and name == "LoadingGuildie")
	end,
}
GuildRoster = function() legacyRosterRequests = legacyRosterRequests + 1 end
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
assert(guildRosterRequests == 1, "Retail guild roster was not requested at startup")
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
assert(#engine:GetMessages() == 2 and legacyRosterReads == 0,
	"trusted social whispers did not use Retail guild membership")
assert(filters.CHAT_MSG_WHISPER(nil, "CHAT_MSG_WHISPER", "hello", "LoadingGuildie") == true,
	"guild sender was trusted before the Retail roster was ready")
guildRosterReady = true
assert(filters.CHAT_MSG_WHISPER(nil, "CHAT_MSG_WHISPER", "hello", "LoadingGuildie") == false,
	"guild sender was not trusted after the Retail roster became ready")
assert(guildRosterRequests == 1, "guild roster request was not throttled")
assert(filters.CHAT_MSG_WHISPER(nil, "CHAT_MSG_WHISPER", "hello", "LegacyGuildie") == true
	and legacyRosterReads == 0,
	"a negative Retail membership result was overridden by stale legacy roster data")
local retailGuildInfo = C_GuildInfo
local retailMemberExists = C_GuildInfo.MemberExistsByName
C_GuildInfo.MemberExistsByName = function() error("roster unavailable") end
assert(filters.CHAT_MSG_WHISPER(nil, "CHAT_MSG_WHISPER", "hello", "LegacyGuildie") == true,
	"a failing Retail membership lookup falsely trusted a sender")
C_GuildInfo.MemberExistsByName = retailMemberExists
C_GuildInfo = nil
now = 111
assert(filters.CHAT_MSG_WHISPER(nil, "CHAT_MSG_WHISPER", "hello", "LegacyGuildie") == false
	and legacyRosterReads == 1 and legacyRosterRequests == 1,
	"legacy guild roster fallback did not trust an exact roster member")
GetNumGuildMembers = nil
assert(filters.CHAT_MSG_WHISPER(nil, "CHAT_MSG_WHISPER", "hello", "UnknownGuildie") == true,
	"unavailable legacy guild roster falsely trusted a sender")
GetNumGuildMembers = function() return 1 end
C_GuildInfo = retailGuildInfo

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
assert(incoming("HeldForRetry", "keep until delivered", 10) == true,
	"retry test whisper was not quarantined")
local beforeRetry = #engine:GetMessages()
local originalCaptureAccessible = engine.CaptureAccessible
engine.CaptureAccessible = function() return nil end
local retryApproved, retryReleased = guard:ApproveSender("HeldForRetry")
assert(retryApproved and retryReleased == 0 and #guard:GetSummaries() == 1
	and #engine:GetMessages() == beforeRetry,
	"a non-delivering capture discarded the held whisper")
engine.CaptureAccessible = function() return false end
assert(guard:ReleaseApproved() == 0 and #guard:GetSummaries() == 1,
	"an explicit false capture result discarded the held whisper")
engine.CaptureAccessible = function() error("capture failed") end
assert(guard:ReleaseApproved() == 0 and #guard:GetSummaries() == 1,
	"a capture error discarded the held whisper")
engine.CaptureAccessible = originalCaptureAccessible
assert(guard:ReleaseApproved() == 1 and #guard:GetSummaries() == 0
	and #engine:GetMessages() == beforeRetry + 1,
	"a successful retry did not release the held whisper exactly once")
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
assert(filters.CHAT_MSG_BN_WHISPER and guard:GetStatus().bnetFilterActive,
	"native Battle.net whisper filter was not registered")
local function bnetArgs(message, sender, accountId, lineId)
	local args = { message, sender }
	args[11], args[13] = lineId, accountId
	return args
end
local function nativeBnet(args)
	return filters.CHAT_MSG_BN_WHISPER(nil, "CHAT_MSG_BN_WHISPER", unpack(args, 1, 14))
end
local bnetFriends = { [505] = true }
local lastBnetLookup
C_BattleNet = {
	GetAccountInfoByID = function(accountId)
		lastBnetLookup = accountId
		return { bnetAccountID = accountId, isFriend = bnetFriends[accountId] == true }
	end,
}
local friendBnet = bnetArgs("known friend", "SharedName", 505, 300)
assert(nativeBnet(friendBnet) == false and lastBnetLookup == 505
	and guard:ShouldBlockEngineEvent("CHAT_MSG_BN_WHISPER", unpack(friendBnet, 1, 13)) == false
	and #guard:GetSummaries() == 0,
	"known Battle.net friend was quarantined or checked by display name")
local function assertUnknownHeld(accountId, lineId, label)
	local args = bnetArgs(label, "SharedName", accountId, lineId)
	assert(nativeBnet(args) == true and #guard:GetSummaries() == 1
		and guard:GetSummaries()[1].senderKey == "bn:" .. accountId
		and guard:ClearQuarantine() == 1, label .. " was not quarantined")
end
local originalBnetLookup = C_BattleNet.GetAccountInfoByID
C_BattleNet.GetAccountInfoByID = function() return nil end
assertUnknownHeld(506, 307, "roster not ready")
C_BattleNet.GetAccountInfoByID = function() error("secret roster") end
assertUnknownHeld(507, 308, "lookup rejected")
local secretFriendFlag = {}
canaccessvalue = function(value) return value ~= secretFriendFlag end
C_BattleNet.GetAccountInfoByID = function(accountId)
	return { bnetAccountID = accountId, isFriend = secretFriendFlag }
end
assertUnknownHeld(508, 309, "secret friend status")
canaccessvalue = nil
C_BattleNet.GetAccountInfoByID = function(accountId)
	return { bnetAccountID = accountId + 1, isFriend = false }
end
assertUnknownHeld(509, 310, "mismatched identity")
C_BattleNet.GetAccountInfoByID = originalBnetLookup
local originalBattleNet = C_BattleNet
C_BattleNet = nil
BNGetFriendInfoByID = function(accountId)
	return unpack({ [1] = accountId, [13] = true }, 1, 13)
end
assert(nativeBnet(bnetArgs("verified legacy friend", "SharedName", 510, 311)) == false,
	"verified legacy Battle.net friend was quarantined")
BNGetFriendInfoByID = function(accountId)
	return unpack({ [1] = accountId, [13] = false }, 1, 13)
end
assertUnknownHeld(513, 314, "verified legacy stranger")
BNGetFriendInfoByID = function(accountId)
	return unpack({ [1] = accountId + 1, [13] = false }, 1, 13)
end
assertUnknownHeld(511, 312, "wrong legacy identity")
BNGetFriendInfoByID = nil
assertUnknownHeld(512, 313, "no friend API")
C_BattleNet = originalBattleNet
local bnetBefore = #engine:GetMessages()
local firstBnet = bnetArgs("private Battle.net text", "SharedName", 101, 301)
assert(nativeBnet(firstBnet) == true and #guard:GetSummaries() == 1,
	"readable first-contact Battle.net whisper was not retained before native hide")
engine:Capture("CHAT_MSG_BN_WHISPER", unpack(firstBnet, 1, 18))
assert(#guard:GetSummaries() == 1 and guard:GetSummaries()[1].count == 1
	and guard:GetSummaries()[1].senderKey == "bn:101"
	and #engine:GetMessages() == bnetBefore,
	"Battle.net filter fanout or engine capture duplicated or exposed held text")
local secondBnet = bnetArgs("different account", "SharedName", 202, 302)
assert(nativeBnet(secondBnet) == true and #guard:GetSummaries() == 2,
	"identical Battle.net display names were treated as one account")
local displayApproved, displayReleased = guard:ApproveSender("SharedName")
assert(displayApproved and displayReleased == 0 and #guard:GetSummaries() == 2,
	"Battle.net messages were approved by display name alone")
local bnetApproved, bnetReleased = guard:ApproveSender("bn:101")
local bnetMessages = engine:GetMessages()
local releasedBnet = bnetMessages[#bnetMessages]
assert(bnetApproved and bnetReleased == 1 and #guard:GetSummaries() == 1
	and #bnetMessages == bnetBefore + 1 and releasedBnet.event == "CHAT_MSG_BN_WHISPER"
	and tonumber(releasedBnet.bnetAccountId) == 101,
	"Battle.net approval did not replay exactly one held account-identified message")
assert(nativeBnet(firstBnet) == false and nativeBnet(secondBnet) == true,
	"Battle.net approval leaked to another account with the same display name")
assert(guard:BlockSender("bn:202") and nativeBnet(secondBnet) == true
	and #guard:GetSummaries() == 1,
	"Battle.net block did not remain account-scoped")
local unidentifiedBnet = bnetArgs("unidentified text", "SharedName", nil, 303)
assert(nativeBnet(unidentifiedBnet) == false,
	"Battle.net whisper without stable account ID was hidden")
engine:Capture("CHAT_MSG_BN_WHISPER", unpack(unidentifiedBnet, 1, 18))
assert(#engine:GetMessages() == bnetBefore + 2 and #guard:GetSummaries() == 1,
	"unidentified Battle.net whisper did not fail open")
local unidentifiableLine = bnetArgs("missing line ID", "SharedName", 303, nil)
assert(nativeBnet(unidentifiableLine) == false and #guard:GetSummaries() == 1,
	"Battle.net whisper without a stable line ID was hidden")
local overlongBnet = bnetArgs(string.rep("x", 513), "SharedName", 303, 306)
assert(nativeBnet(overlongBnet) == false and #guard:GetSummaries() == 1,
	"Battle.net whisper too long to retain exactly was hidden or truncated")
local secretLaterArgument = {}
canaccessvalue = function(value) return value ~= secretLaterArgument end
local partlyReadableBnet = bnetArgs("retain sole readable copy", "AnotherName", 303, 304)
partlyReadableBnet[18] = secretLaterArgument
assert(nativeBnet(partlyReadableBnet) == true,
	"native filter did not retain readable text before hiding")
engine:Capture("CHAT_MSG_BN_WHISPER", unpack(partlyReadableBnet, 1, 18))
canaccessvalue = nil
assert(#engine:GetMessages() == bnetBefore + 2 and #guard:GetSummaries() == 2,
	"secret later event argument caused loss of the only readable Battle.net copy")
assert(guard:ClearQuarantine() == 2 and #guard:GetSummaries() == 0,
	"Battle.net quarantine clear did not remove held messages")
assert(guard:SetEnabled(false) and not guard.enabled,
	"guard did not leave active state before registration failure tests")
local originalAddFilter = ChatFrame_AddMessageEventFilter
ChatFrame_AddMessageEventFilter = nil
assert(guard:SetEnabled(true) == false and not guard.enabled
	and not guard:GetStatus().filterActive
	and guard:ShouldBlockEngineEvent("CHAT_MSG_WHISPER", "native fallback", "Untrusted") == false,
	"missing native filter left the guard enabled")
ChatFrame_AddMessageEventFilter = function(event, filter)
	filters[event] = filter
	return false
end
assert(guard:SetEnabled(true) == false and not guard.enabled
	and not guard:GetStatus().filterActive and filters.CHAT_MSG_WHISPER == nil,
	"rejected native filter left the guard enabled or installed")
ChatFrame_AddMessageEventFilter = function() error("registration failed") end
assert(guard:SetEnabled(true) == false and not guard.enabled
	and not guard:GetStatus().filterActive,
	"native filter registration error left the guard enabled")
ChatFrame_AddMessageEventFilter = originalAddFilter
assert(guard:SetEnabled(true) and guard.enabled and guard:GetStatus().filterActive,
	"guard could not retry native filter registration")
guard:SetEnabled(false)
ChatFrame_AddMessageEventFilter = function(event, filter)
	filters[event] = filter
	return event ~= "CHAT_MSG_BN_WHISPER"
end
assert(guard:SetEnabled(true) and guard:GetStatus().filterActive
	and not guard:GetStatus().bnetFilterActive and filters.CHAT_MSG_WHISPER
	and filters.CHAT_MSG_BN_WHISPER == nil,
	"failed Battle.net registration disabled in-game protection or left a hiding filter")
local bnetFallback = bnetArgs("native fallback", "UntrustedBnet", 404, 305)
assert(guard:ShouldBlockEngineEvent("CHAT_MSG_BN_WHISPER", unpack(bnetFallback, 1, 13)) == false,
	"Smart Chat held Battle.net whisper without a native filter")
guard:SetEnabled(false)
ChatFrame_AddMessageEventFilter = nil
ChatFrameUtil = {
	AddMessageEventFilter = function(event, filter) filters[event] = filter end,
	RemoveMessageEventFilter = function(event, filter)
		if filters[event] == filter then filters[event] = nil end
	end,
}
assert(guard:SetEnabled(true) and guard:GetStatus().filterActive
	and guard:GetStatus().bnetFilterActive and filters.CHAT_MSG_BN_WHISPER,
	"Retail ChatFrameUtil filter API was not used when legacy global was absent")
engine:SetEnabled(false)
assert(filters.CHAT_MSG_WHISPER == nil and filters.CHAT_MSG_BN_WHISPER == nil
	and not guard:GetStatus().filterActive and not guard:GetStatus().bnetFilterActive,
	"native filters remained active without Smart Chat review capture")
ChatFrameUtil = nil
ChatFrame_AddMessageEventFilter = originalAddFilter

print("Whisper guard mock tests passed")
