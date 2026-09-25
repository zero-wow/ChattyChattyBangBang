-- Run from the Retail addon root with: lua Tests/SpamBlockedArchive.mock.lua
unpack = unpack or table.unpack
local now = 100
local filters = {}
local frameA, frameB = {}, {}
local settings = {
	historyCapacity = 100, persistHistory = false, learnedSources = {},
	customViewRevision = 0, channelTargets = {},
	spam = {
		enabled = true, exemptSelf = true,
		duplicate = { enabled = true, window = 12, allowedCopies = 1,
			muteAfter = 0, minimumLength = 4, caseInsensitive = true,
			collapseWhitespace = true, stripFormatting = true },
		burst = { enabled = false, window = 6, limit = 99, muteDuration = 15 },
		repeatAds = { enabled = false },
		escalation = { enabled = false, offenders = {}, bans = {} },
		scopes = { channel = true, ["local"] = false, guild = false,
			group = false, whisper = false, bnet = false },
	},
	blocks = { enabled = true, rules = {}, uiFeedback = { coalesce = true, window = 1.5 } },
}
ChattyChattyBangBang = {
	GetSmartSettings = function() return settings end,
	GetSmartViews = function() return {} end,
	IsRecordAllowedInView = function() return true end,
	Print = function() end,
}
GetTime = function() return now end
time = function() return 1700000000 + math.floor(now) end
date = function() return "12:00" end
GetRealmName = function() return "Realm" end
UnitName = function() return "Tester", "Realm" end
UnitGUID = function() return "Player-1-TESTER" end
CreateFrame = function()
	return {
		SetScript = function(self, name, callback) self[name] = callback end,
		RegisterEvent = function() return true end,
		UnregisterAllEvents = function() return true end,
	}
end
ChatFrame_AddMessageEventFilter = function(event, callback) filters[event] = callback; return true end
ChatFrame_RemoveMessageEventFilter = function(event) filters[event] = nil; return true end
DEFAULT_CHAT_FRAME = frameA

dofile("Core/SpamControl.lua")
dofile("Core/BlockControl.lua")
dofile("Core/MessageEngine.lua")
local addon = ChattyChattyBangBang
local spam, blocks, engine = addon.SpamControl, addon.BlockControl, addon.MessageEngine
assert(spam:Initialize())
blocks:Initialize()
engine:Initialize()
engine:SetEnabled(true)

local function args(text, sender, lineId, guid)
	return { n = 14, text, sender, nil, "2. Trade", nil, nil, nil,
		2, "Trade", nil, lineId, guid, nil, nil }
end
local function native(frame, text, sender, lineId, guid)
	local values = args(text, sender, lineId, guid)
	return select(1, spam:OnChatFilter(frame, "CHAT_MSG_CHANNEL", unpack(values, 1, values.n)))
end
local function capture(text, sender, lineId, guid)
	local values = args(text, sender, lineId, guid)
	engine:Capture("CHAT_MSG_CHANNEL", unpack(values, 1, values.n))
end

local text = "Repeated ordinary public line"
local sender, guid = "Seller", "Player-1-SELLER"
assert(native(frameA, text, sender, 42, guid) == false)
assert(native(frameB, text, sender, 42, guid) == false)
capture(text, sender, 42, guid)
assert(#engine:GetMessages() == 1 and #blocks:GetArchive() == 0,
	"first allowed physical line was archived or lost")

now = now + 1
assert(native(frameA, text, sender, 42, guid) == true)
assert(native(frameB, text, sender, 42, guid) == true)
capture(text, sender, 42, guid)
local archived = blocks:GetArchive()
assert(#engine:GetMessages() == 1 and #archived == 1 and archived[1].occurrences == 1,
	"blocked line leaked to normal history or fanout counted twice")
assert(archived[1].reason == "spam" and archived[1].ruleId == "spam-duplicate"
	and archived[1].text == text and archived[1].sender == sender
	and archived[1].sourceId == "channel:trade"
	and archived[1].firstEpoch > 0 and archived[1].firstTimestamp == "12:00",
	"spam archive lost reason, source, sender, text, or timestamp")

now = now + 1
assert(native(frameA, text, sender, 42, guid) == true,
	"reused line ID bypassed duplicate filter")
assert(native(frameB, text, sender, 42, guid) == true)
capture(text, sender, 42, guid)
archived = blocks:GetArchive()
assert(#archived == 1 and archived[1].occurrences == 2
	and archived[1].lastEpoch > archived[1].firstEpoch,
	"new physical line was lost or replay/fanout counted as separate entries")

-- The engine can receive the event before the native frame. The first fresh
-- decision still archives once, and the later native frame reuses it.
now = now + 1
capture("Engine-first repeat", "Other", 55, "Player-1-OTHER")
assert(native(frameA, "Engine-first repeat", "Other", 55, "Player-1-OTHER") == false)
now = now + 1
capture("Engine-first repeat", "Other", 55, "Player-1-OTHER")
assert(native(frameA, "Engine-first repeat", "Other", 55, "Player-1-OTHER") == true)
archived = blocks:GetArchive()
assert(#archived == 2 and archived[1].ruleId == "spam-duplicate"
	and archived[1].occurrences == 1,
	"engine-first blocked decision was not archived exactly once")

-- A local ban applies even when the source's analysis scope is otherwise off.
assert(spam:BanSender("Banned", { guid = "Player-1-BANNED" }))
now = now + 1
assert(native(frameA, "Ban-bound line", "Banned", 99, "Player-1-BANNED") == true)
capture("Ban-bound line", "Banned", 99, "Player-1-BANNED")
archived = blocks:GetArchive()
assert(#archived == 3 and archived[1].ruleId == "spam-localBan"
	and archived[1].reason == "spam" and #engine:GetMessages() == 2,
	"local-ban drop lacked review evidence or entered normal history")

-- Day-scale advert suppression uses the same review trail, even though it
-- never creates a timed mute or ban strike.
settings.spam.duplicate.enabled = false
settings.spam.repeatAds.enabled = true
spam:RefreshSettings()
local advert = "WTS legendary rare mount for 500g"
now = now + 1
assert(native(frameA, advert, "Advertiser", 200, "Player-1-ADVERTISER") == false)
capture(advert, "Advertiser", 200, "Player-1-ADVERTISER")
now = now + 600
assert(native(frameA, advert, "Advertiser", 201, "Player-1-ADVERTISER") == true)
capture(advert, "Advertiser", 201, "Player-1-ADVERTISER")
archived = blocks:GetArchive()
assert(#archived == 4 and archived[1].ruleId == "spam-repeatAd"
	and archived[1].reason == "spam" and archived[1].occurrences == 1
	and #engine:GetMessages() == 3,
	"day-scale repeated advert was not archived once outside normal history")

-- Secret Retail payloads must not be inspected or persisted by this bridge.
local secret = {}
canaccessvalue = function(value) return value ~= secret end
local before = #blocks:GetArchive()
assert(spam:OnChatFilter(frameA, "CHAT_MSG_CHANNEL", secret, "Hidden") == false)
capture(secret, "Hidden", 100, "Player-1-HIDDEN")
assert(#blocks:GetArchive() == before, "secret payload entered blocked archive")
canaccessvalue = nil

settings.blocks.archive.enabled = false
now = now + 1
native(frameA, text, sender, 101, guid)
assert(#blocks:GetArchive() == before,
	"user-disabled blocked archive still retained automatic spam text")

print("Spam blocked archive mock tests passed")
