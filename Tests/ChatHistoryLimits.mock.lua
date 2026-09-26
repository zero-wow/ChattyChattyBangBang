-- Opt-in total cap and per-source overrides must not silently rewrite old
-- profiles. Run from addon root: lua Tests/ChatHistoryLimits.mock.lua

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
local settings = addon:GetSmartSettings()
local engine = addon.MessageEngine
engine:Initialize()
assert(settings.historyCapacity == 100 and settings.historyTotalCapacity == nil,
	"old profile received an implicit total cap")
assert(not addon:SetChatHistoryAggregateCapacity(0 / 0)
	and not addon:SetChatHistoryAggregateCapacity(math.huge)
	and not addon:SetChatHistorySourceLimit("channel:general", math.huge)
	and not addon:SetChatHistorySourceLimit("channel:general\nunsafe", 200)
	and not addon:SetChatHistorySourceLimit("channel:" .. string.rep("x", 100), 200)
	and settings.historyTotalCapacity == nil,
	"invalid numeric values or malformed source IDs reached SavedVariables")

local function deliver(channel, number, text)
	now = now + 1
	local record = assert(engine:Normalize("CHAT_MSG_CHANNEL", text,
		"Tester", nil, channel, nil, nil, nil, number, channel))
	return engine:Deliver(record)
end
local function countSource(sourceId)
	local source = engine.sourceHistories[sourceId]
	return source and source.count or 0
end
local function persistedCount()
	local count = 0
	for _, ring in pairs(settings.history.sources or {}) do count = count + ring.count end
	return count
end

-- The old promise remains true until the player opts into a total cap.
assert(addon:SetChatHistorySourceLimit("channel:general", 200))
for index = 1, 150 do
	deliver("General", 1, "general-" .. index)
	deliver("Trade", 2, "trade-" .. index)
end
assert(countSource("channel:general") == 150
	and countSource("channel:trade") == 100 and engine.count == 250,
	"one busy source evicted another before an aggregate cap was enabled")
assert(settings.historyTotalCapacity == nil and persistedCount() == 250,
	"default-unlimited history was silently capped in SavedVariables")

-- Explicit total cap evicts oldest physical lines globally, including across
-- different source rings; every survivor must be the same in runtime and disk.
assert(addon:SetChatHistoryAggregateCapacity(180))
local records = engine:GetMessages()
assert(#records == 180 and records[1].text == "general-61"
	and records[2].text == "trade-61"
	and countSource("channel:general") == 90
	and countSource("channel:trade") == 90,
	"opt-in aggregate cap did not evict the oldest cross-source records")
assert(persistedCount() == 180,
	"aggregate eviction left stale lines in source-owned SavedVariables rings")

for index = 151, 160 do
	deliver("General", 1, "general-" .. index)
	deliver("Trade", 2, "trade-" .. index)
end
records = engine:GetMessages()
local firstSurvivor = records[1].text
assert(#records == 180 and persistedCount() == 180,
	"live aggregate cap drifted after incremental appends")
engine:ResetForProfile()
records = engine:GetMessages()
assert(#records == 180 and records[1].text == firstSurvivor
	and persistedCount() == 180,
	"reload restored aggregate-evicted lines or changed chronology")

-- Disabling the optional total cap never prunes. Resetting an overridden
-- source to its inherited 100-line limit affects only that source.
assert(addon:SetChatHistoryAggregateCapacity(nil))
for index = 161, 200 do deliver("General", 1, "general-" .. index) end
local tradeBefore = countSource("channel:trade")
local generalBefore = countSource("channel:general")
assert(generalBefore > 100, "fixture did not exceed inherited source limit")
local dock = {
	activeView = "general", unread = { general = generalBefore, trade = tradeBefore },
	pendingVisible = generalBefore,
	IsLocallyIgnored = function() return false end,
	RefreshRailState = function() end,
	RefreshNewMessageIndicator = function() end,
	RebuildActiveView = function() end,
}
addon.SmartDock = dock
local sourceOldest = engine.sourceHistories["channel:general"].head
assert(engine:ToggleBookmark(sourceOldest) == true)
local sourceBookmark = sourceOldest.historySequence
assert(addon:SetChatHistorySourceLimit("channel:general", nil))
assert(countSource("channel:general") == 100
	and countSource("channel:trade") == tradeBefore,
	"resetting one source limit pruned an unrelated source")
assert(dock.unread.general == 100 and dock.unread.trade == tradeBefore
	and dock.pendingVisible == 100 and engine.bookmarks[sourceBookmark] == nil
	and settings.history.bookmarks[sourceBookmark] == nil,
	"explicit source-limit lowering left stale unread or bookmark state")
assert(persistedCount() == engine.count,
	"per-source pruning did not update SavedVariables")

local globalOldest = engine.historyHead
assert(engine:ToggleBookmark(globalOldest) == true)
local globalBookmark = globalOldest.historySequence
assert(addon:SetChatHistoryAggregateCapacity(100))
assert(engine.count == 100 and persistedCount() == 100
	and dock.unread.general == countSource("channel:general")
	and dock.unread.trade == countSource("channel:trade")
	and dock.pendingVisible == countSource("channel:general")
	and engine.bookmarks[globalBookmark] == nil
	and settings.history.bookmarks[globalBookmark] == nil,
	"explicit total-cap lowering left stale unread, bookmarks, or saved lines")
assert(addon:SetChatHistoryAggregateCapacity(nil))

-- Existing schema-2 SavedVariables stay intact when only the new optional
-- settings are absent; a profile/load is not user consent to shrink history.
local retained = engine.count
local previousHistory = settings.history
settings.historyTotalCapacity = nil
settings.historySourceLimits = nil
assert(addon:GetSmartSettings().history == previousHistory
	and addon:GetSmartSettings().historyTotalCapacity == nil,
	"ordinary settings migration replaced or capped existing history")
engine:ResetForProfile()
assert(engine.count == retained and persistedCount() == retained,
	"old schema-2 history lost lines without an explicit lower limit")

settings.historySourceLimits = {}
for index = 1, 128 do
	settings.historySourceLimits[string.format("channel:synthetic%03d", index)] = 100
end
assert(not addon:SetChatHistorySourceLimit("channel:synthetic129", 100)
	and settings.historySourceLimits["channel:synthetic129"] == nil,
	"per-source override map grew beyond its SavedVariables bound")

print("Chat history source/aggregate limits mock passed")
