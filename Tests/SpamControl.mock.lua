-- Focused no-client harness for the two SpamControl contracts that are easy
-- to regress on private servers: reused chat line IDs, and duplicate-to-mute
-- escalation.  Run from the addon root with: lua Tests/SpamControl.mock.lua

local now = 100
local filters = {}
local primaryFrame = {}
local secondaryFrame = {}
local engine = {}
local settings = {
	spam = {
		enabled = true,
		exemptSelf = true,
		duplicate = {
			enabled = true,
			window = 12,
			allowedCopies = 1,
			minimumLength = 4,
			caseInsensitive = true,
			collapseWhitespace = true,
			stripFormatting = true,
			ignorePunctuation = false,
			crossChannels = true,
		},
		burst = {
			enabled = false,
			window = 6,
			limit = 99,
			muteDuration = 15,
		},
		escalation = {
			enabled = true,
			mutesBeforeBan = 2,
			strikeWindow = 1800,
			offenders = {},
			bans = {},
			nextBanSequence = 0,
		},
		scopes = {
			channel = true,
			["local"] = true,
			guild = false,
			group = false,
			whisper = false,
			bnet = false,
		},
	},
}

ChattyChattyBangBang = {
	GetSmartSettings = function()
		return settings
	end,
	MessageEngine = engine,
}

GetTime = function()
	return now
end
time = function()
	return 1700000000 + math.floor(now)
end
UnitName = function()
	return "Tester", "Realm"
end
UnitGUID = function()
	return "Player-1-TESTER"
end
GetRealmName = function()
	return "Realm"
end

ChatFrame_AddMessageEventFilter = function(event, callback)
	filters[event] = callback
	return true
end
ChatFrame_RemoveMessageEventFilter = function(event)
	filters[event] = nil
	return true
end
DEFAULT_CHAT_FRAME = primaryFrame

dofile("Core/SpamControl.lua")

local control = ChattyChattyBangBang.SpamControl
assert(control:Initialize(), "SpamControl did not register its chat filters")

local function filterWithIdentity(frame, message, sender, guid)
	-- Keep lineId deliberately constant.  That is the Ascension condition this
	-- harness protects; every physical delivery below has all the same args.
	return select(1, control:OnChatFilter(
		frame,
		"CHAT_MSG_CHANNEL",
		message or "[Keystone: Dire Maul East (11)] LFM",
		sender or "Shrerra",
		nil,
		"Trade",
		nil,
		nil,
		nil,
		2,
		"Trade",
		nil,
		42,
		guid
	))
end

local function filter(frame, message)
	return filterWithIdentity(frame, message, "Shrerra", "Player-1-SHRERRA")
end

local function filterInChannel(frame, message, channelNumber, channelName)
	return select(1, control:OnChatFilter(
		frame,
		"CHAT_MSG_CHANNEL",
		message,
		"ChannelHopper",
		nil,
		channelName,
		nil,
		nil,
		nil,
		channelNumber,
		channelName,
		nil,
		42,
		"Player-1-CHANNELHOPPER"
	))
end

local function engineReplay(message)
	return control:ShouldBlockEngineEvent(
		"CHAT_MSG_CHANNEL",
		message or "[Keystone: Dire Maul East (11)] LFM",
		"Shrerra",
		nil,
		"Trade",
		nil,
		nil,
		nil,
		2,
		"Trade",
		nil,
		42,
		"Player-1-SHRERRA"
	)
end

local function deliver(message)
	local first = filter(primaryFrame, message)
	local other = filter(secondaryFrame, message)
	local replay = engineReplay(message)
	assert(other == first, "second ChatFrame did not reuse the same decision")
	assert(replay == first, "MessageEngine-style primary-frame replay was double-counted")
	return first
end

local function deliverEngineFirst(message)
	local replay = engineReplay(message)
	local first = filter(primaryFrame, message)
	local other = filter(secondaryFrame, message)
	assert(first == replay, "native primary did not reuse an engine-first decision")
	assert(other == replay, "secondary frame did not reuse an engine-first decision")
	return replay
end

-- The second physical line uses the same lineId in the same GetTime tick. It
-- must be a duplicate, while the two fanout calls of each physical line do not
-- advance the counters.
assert(deliver() == false, "first line should pass")
assert(deliver() == true, "reused lineId bypassed duplicate suppression")
local stats = control:GetStats()
assert(stats.processed == 2 and stats.duplicateBlocked == 1,
	"fanout/reused-lineId accounting is wrong")

-- If SmartChat capture is disabled, there is no MessageEngine replay at all.
-- Two native calls to the same ChatFrame must still be two physical messages,
-- rather than pairing them through a value-only cache.
control:RefreshSettings()
control:ResetStats()
assert(filter(primaryFrame) == false, "first native-only line should pass")
assert(filter(primaryFrame) == true, "native-only recycled lineId bypassed duplicate suppression")
stats = control:GetStats()
assert(stats.processed == 2 and stats.duplicateBlocked == 1,
	"native-only same-frame delivery was mistaken for fanout")

-- Ascension's frame dispatch order can place MessageEngine before a native
-- ChatFrame.  Its replay must not reserve DEFAULT_CHAT_FRAME in the native
-- fanout ledger, otherwise that native call would be double-counted.
control:RefreshSettings()
control:ResetStats()
assert(deliverEngineFirst() == false, "engine-first first line should pass")
assert(deliverEngineFirst() == true, "engine-first recycled lineId bypassed duplicate suppression")
stats = control:GetStats()
assert(stats.processed == 2 and stats.duplicateBlocked == 1,
	"engine-first/native fanout accounting is wrong")

-- The user-facing contract is a sliding 12 second window: a remote sender's
-- first copy passes, a copy ten seconds later is hidden, and another copy two
-- seconds after that remains hidden.  This guards the exact timing reported
-- by the player instead of only same-tick repeats.
control:RefreshSettings()
control:ResetStats()
now = 500
assert(deliver() == false, "first timed duplicate line should pass")
now = now + 10
assert(deliver() == true, "remote repeat inside the 12 second window was allowed")
now = now + 2
assert(deliver() == true, "sliding duplicate window did not retain the second repeat")

-- The firewall's duplicate identity is sender + normalized message, not a
-- channel.  Changing between public channels must not provide an extra copy
-- or avoid the timed mute/escalation path.
control:RefreshSettings()
control:ResetStats()
now = 550
assert(filterInChannel(primaryFrame, "cross channel duplicate advert", 1, "General") == false,
	"first cross-channel copy should pass")
assert(filterInChannel(primaryFrame, "cross channel duplicate advert", 2, "Trade") == true,
	"same sender/message in Trade escaped the General duplicate history")
assert(filterInChannel(primaryFrame, "cross channel duplicate advert", 3, "LocalDefense") == true,
	"third cross-channel duplicate should be suppressed")
assert(filterInChannel(primaryFrame, "cross channel duplicate advert", 4, "World") == true,
	"cross-channel duplicate threshold should start one sender mute")
assert(filterInChannel(primaryFrame, "a different advert while muted", 5, "LookingForGroup") == true,
	"duplicate mute did not follow the sender to another channel")

-- Burst protection is sender-wide too, including when the flood lines differ.
settings.spam.duplicate.enabled = false
settings.spam.burst.enabled = true
settings.spam.burst.limit = 2
control:RefreshSettings()
control:ResetStats()
now = 575
assert(filterInChannel(primaryFrame, "burst one", 1, "General") == false)
assert(filterInChannel(primaryFrame, "burst two", 2, "Trade") == false)
assert(filterInChannel(primaryFrame, "burst three", 3, "LocalDefense") == true,
	"cross-channel burst did not mute the sender")
assert(filterInChannel(primaryFrame, "burst follow-up", 4, "World") == true,
	"burst mute did not follow the sender to another channel")
settings.spam.duplicate.enabled = true
settings.spam.burst.enabled = false
settings.spam.burst.limit = 99

-- Ascension occasionally omits a GUID on one event delivery.  The same named
-- sender must not evade the duplicate gate merely because the next line does
-- include its GUID.
control:RefreshSettings()
control:ResetStats()
now = 600
assert(filterWithIdentity(primaryFrame, "identity metadata repeat", "IdentityFlip", nil) == false,
	"first GUID-less line should pass")
now = now + 10
assert(filterWithIdentity(primaryFrame, "identity metadata repeat", "IdentityFlip", "Player-1-IDENTITY") == true,
	"GUID metadata change let a repeat evade duplicate suppression")

-- ALWAYS ALLOW SELF is deliberately a complete bypass.  Turning it off is
-- sufficient for a player to test the exact same duplicate behavior with
-- their own character or a macro.
settings.spam.exemptSelf = true
control:RefreshSettings()
control:ResetStats()
now = 700
assert(filterWithIdentity(primaryFrame, "self repeat contract", "Tester", "Player-1-TESTER") == false)
now = now + 2
assert(filterWithIdentity(primaryFrame, "self repeat contract", "Tester", "Player-1-TESTER") == false,
	"self exemption did not bypass the spam gate")
settings.spam.exemptSelf = false
control:RefreshSettings()
control:ResetStats()
now = 710
assert(filterWithIdentity(primaryFrame, "self repeat contract", "Tester", "Player-1-TESTER") == false)
now = now + 2
assert(filterWithIdentity(primaryFrame, "self repeat contract", "Tester", "Player-1-TESTER") == true,
	"disabling self exemption did not enable duplicate testing")
settings.spam.exemptSelf = true

-- Duplicate mute works even when burst rate limiting is disabled.  With no
-- SavedVariables field, the core default is three suppressed copies: one
-- accidental resend remains hide-only, while a real repeat flood starts one
-- sender+scope mute and exactly one strike.
control:RefreshSettings()
control:ResetStats()
assert(deliver() == false, "first duplicate episode line should pass")
assert(deliver() == true, "first suppressed duplicate should block")
assert(deliver() == true, "second suppressed duplicate should block")
assert(deliver() == true, "duplicate threshold should start a mute")
stats = control:GetStats()
assert(stats.newMutes == 1 and stats.strikes == 1 and stats.duplicateMutes == 1,
	"duplicate mute did not create exactly one strike")
assert(deliver() == true, "active duplicate mute should block every sender line in its scope")
stats = control:GetStats()
assert(stats.newMutes == 1 and stats.strikes == 1,
	"active mute created an extra strike")

-- A separate duplicate episode after the timed mute expires produces the
-- second strike and therefore the configured automatic local ban.
now = now + 16
assert(deliver() == false, "first line after a completed mute should reset the duplicate window")
assert(deliver() == true, "second episode first repeat should block")
assert(deliver() == true, "second episode second repeat should block")
assert(deliver() == true, "second episode should trigger its timed mute")
stats = control:GetStats()
assert(stats.newMutes == 2 and stats.strikes == 2 and stats.automaticBans == 1,
	"duplicate escalation did not create the expected automatic ban")
local automaticBan
for _, ban in ipairs(control:GetBans()) do
	if ban.source == "automatic" then
		automaticBan = ban
		break
	end
end
assert(automaticBan and automaticBan.reason == "duplicate" and automaticBan.lastReason == "duplicate"
	and automaticBan.lastScope == "channel" and automaticBan.lastChannel == "Trade",
	"automatic ban did not retain its duplicate-firewall explanation")
local automaticReport = control:GetBanReport(automaticBan.id)
assert(automaticReport and #automaticReport.evidence == 2
	and automaticReport.evidence[1].message == "[Keystone: Dire Maul East (11)] LFM"
	and automaticReport.evidence[2].reason == "duplicate",
	"automatic ban report did not retain the triggering strike messages")
automaticReport.evidence[1].message = "mutated copy"
assert(control:GetBanReport(automaticBan.id).evidence[1].message == "[Keystone: Dire Maul East (11)] LFM",
	"ban report returned live SavedVariables evidence")
assert(filter(primaryFrame, "a completely different line") == true,
	"automatic local ban did not cover subsequent messages from the sender")

-- Zero is an explicit hide-only mode: duplicate suppression stays active, but
-- it must never create a timed mute, strike, or automatic ban.
control:ClearBans()
control:ClearOffenders()
settings.spam.duplicate.muteAfter = 0
settings.spam.burst.enabled = false
control:RefreshSettings()
control:ResetStats()
assert(deliver() == false)
assert(deliver() == true)
assert(deliver() == true)
assert(deliver() == true)
stats = control:GetStats()
assert(stats.newMutes == 0 and stats.strikes == 0 and stats.automaticBans == 0,
	"duplicate muteAfter = 0 did not remain hide-only")

-- When both detectors would qualify on the same line, the shared sender mute
-- state permits only one escalation incident.
control:ClearBans()
control:ClearOffenders()
settings.spam.duplicate.muteAfter = nil
control:RefreshSettings()
control:ResetStats()
settings.spam.burst.enabled = true
settings.spam.burst.limit = 2
control:RefreshSettings()
assert(deliver() == false)
assert(deliver() == true)
assert(deliver() == true)
stats = control:GetStats()
assert(stats.newMutes == 1 and stats.strikes == 1,
	"duplicate and burst detectors issued duplicate strikes for one flood")

-- Ascension fills the Battle.net argument slots with zero on ordinary channel
-- messages. A legacy automatic ban carrying that placeholder is corrupted
-- state, not a valid player ban: it must be purged and cannot hide unrelated
-- normal chat. A positive ID remains valid for actual BN events.
control:ClearBans()
control:ClearOffenders()
settings.spam.duplicate.enabled = false
settings.spam.burst.enabled = false
settings.spam.escalation.bans["guid:legacy-placeholder"] = {
	id = "guid:legacy-placeholder",
	name = "Legacy",
	guid = "Player-1-LEGACY",
	bnetAccountId = "0",
	source = "automatic",
	bannedAt = 1,
}
settings.spam.escalation.offenders["guid:legacy-placeholder"] = {
	id = "guid:legacy-placeholder",
	name = "Legacy",
	guid = "Player-1-LEGACY",
	bnetAccountId = "0",
	lastStrike = 1,
}
control:RefreshSettings()
assert(next(settings.spam.escalation.bans) == nil and next(settings.spam.escalation.offenders) == nil,
	"legacy bnet:0 automatic state was not purged")
assert(select(1, control:OnChatFilter(
	primaryFrame, "CHAT_MSG_CHANNEL", "ordinary channel line", "AnotherPlayer", nil,
	"Trade", nil, nil, nil, 2, "Trade", nil, 77, "Player-1-ANOTHER", 0, 0
)) == false, "non-BN placeholder zero became a shared ban identity")
assert(control:BanSender("BNetFriend", { bnetAccountId = 55 }) == true,
	"positive Battle.net identity could not be manually banned")
assert(select(1, control:OnChatFilter(
	primaryFrame, "CHAT_MSG_BN_WHISPER", "hello", "BNetFriend", nil,
	nil, nil, nil, nil, nil, nil, nil, nil, 55
)) == true, "positive Battle.net identity did not remain a valid local ban")

print("SpamControl mock tests passed")
