-- Run from the Retail addon root: lua Tests/RepeatAdRetroPurge.mock.lua
unpack = unpack or table.unpack
local now = 100
local settings = {
	historyCapacity = 100, persistHistory = true, learnedSources = {},
	customViewRevision = 0, channelTargets = {}, views = { trade = true, general = true },
	spam = {
		enabled = true, exemptSelf = true,
		duplicate = { enabled = false },
		burst = { enabled = false },
		repeatAds = { enabled = true, window = 86400, maxCopies = 2,
			minimumGap = 3600, minimumLength = 18 },
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
ChatFrame_AddMessageEventFilter = function() return true end
ChatFrame_RemoveMessageEventFilter = function() return true end
local frameA, frameB = {}, {}
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

local dock = {
	active = true, activeView = "trade", unread = {}, pendingVisible = 0,
	rebuilds = 0, railRefreshes = 0,
	IsLocallyIgnored = function() return false end,
	RebuildActiveViewPreservingScroll = function(self) self.rebuilds = self.rebuilds + 1 end,
	RebuildActiveView = function(self) self.rebuilds = self.rebuilds + 1 end,
	RefreshRailState = function(self) self.railRefreshes = self.railRefreshes + 1 end,
}
addon.SmartDock = dock

local function args(text, seller, lineId, source)
	local trade = source == "Trade"
	return { n = 14, text, seller, nil, trade and "2. Trade" or "1. General",
		nil, nil, nil, trade and 2 or 1, source, nil, lineId,
		"Player-1-" .. seller, nil, nil }
end
local function receive(text, seller, lineId, source)
	local values = args(text, seller, lineId, source)
	local native = spam:OnChatFilter(frameA, "CHAT_MSG_CHANNEL", unpack(values, 1, values.n))
	engine:Capture("CHAT_MSG_CHANNEL", unpack(values, 1, values.n))
	assert(spam:OnChatFilter(frameB, "CHAT_MSG_CHANNEL", unpack(values, 1, values.n)) == native,
		"native frame fanout changed one physical decision")
	return native
end
local function archiveFor(seller)
	for _, entry in ipairs(blocks:GetArchive()) do
		if entry.sender == seller and entry.ruleId == "spam-repeatAd" then return entry end
	end
end
local function persistedCount()
	local count = 0
	for _, ring in pairs(settings.history.sources) do count = count + ring.count end
	return count
end

local advert = "WTS legendary rare mount for 500g"
assert(receive(advert, "SellerA", 1, "General") == false)
now = now + 600
assert(receive(advert, "SellerA", 2, "General") == true)
assert(#engine:GetMessages() == 1 and persistedCount() == 1,
	"minimum-gap block purged an earlier visible copy")
assert(archiveFor("SellerA").occurrences == 1,
	"minimum-gap attempt was not archived exactly once")
now = now + 3601
assert(receive("WTS: legendary rare mount for 500g!", "SellerA", 3, "Trade") == false)
assert(#engine:GetMessages() == 2 and persistedCount() == 2,
	"two day-allowed copies were not visible before the cap")
assert(#engine:GetMessages("trade") == 2, "semantic Trade view did not contain both seller ads")
local otherAdvert = "WTS entirely different rare pet for 25g"
assert(receive(otherAdvert, "SellerA", 30, "Trade") == false)
dock.unread.trade, dock.pendingVisible = 3, 3
local rebuilds = 0
local originalRebuild = engine.RebuildPersistence
engine.RebuildPersistence = function(self, ...)
	rebuilds = rebuilds + 1
	return originalRebuild(self, ...)
end
now = now + 3601
assert(receive(advert, "SellerA", 4, "General") == true)
assert(#engine:GetMessages() == 1 and engine:GetMessages()[1].text == otherAdvert
	and persistedCount() == 1,
	"copy-cap purge removed the wrong advert or left matching copies in history")
assert(rebuilds == 1, "copy-cap purge did not rebuild SavedVariables exactly once")
assert(dock.unread.trade == 1 and dock.pendingVisible == 1
	and dock.rebuilds == 1 and dock.railRefreshes == 1,
	"copy-cap purge did not refresh visible and unread state")
local archived = archiveFor("SellerA")
assert(archived and archived.occurrences == 4 and archived.sourceLabel == "Multiple public channels",
	"gap attempt, two purged copies, and cap attempt did not coalesce in review")
engine.RebuildPersistence = originalRebuild

-- The same threshold must purge records restored from SavedVariables, not only
-- records received in this session. Unrelated senders must survive both passes.
now = now + 3601
assert(receive(advert, "SellerB", 10, "General") == false)
assert(receive("Hello guildmates", "Other", 11, "General") == false)
now = now + 3601
assert(receive(advert, "SellerB", 12, "Trade") == false)
assert(#engine:GetMessages() == 4 and persistedCount() == 4)
engine:ResetForProfile()
assert(#engine:GetMessages() == 4, "saved seller copies were not restored for reload test")
now = now + 3601
assert(receive(advert, "SellerB", 13, "General") == true)
assert(#engine:GetMessages() == 2 and engine:GetMessages()[1].text == otherAdvert
	and engine:GetMessages()[2].sender == "Other" and persistedCount() == 2,
	"reload-restored ads were not purged selectively")
archived = archiveFor("SellerB")
assert(archived and archived.occurrences == 3,
	"restored copies and blocked cap attempt were not archived once each")
engine:ResetForProfile()
assert(#engine:GetMessages() == 2 and engine:GetMessages()[2].sender == "Other",
	"a second reload resurrected purged advertisements")

print("Repeat-ad retroactive purge mock tests passed")
