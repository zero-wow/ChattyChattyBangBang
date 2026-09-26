-- Run from the addon root: lua Tests/ChatHistorySearch.mock.lua
-- Reuse the history contract harness, then build a fresh, isolated transcript.
dofile("Tests/ChatHistory.mock.lua")

local addon = ChattyChattyBangBang
local engine = addon.MessageEngine
local settings = addon:GetSmartSettings()
settings.persistHistory = true
settings.historyCapacity = 100
addon.BlockControl = nil
engine:ClearHistory()
date = function(format, epoch)
	return os.date(format, epoch)
end

local function expect(condition, message)
	if not condition then error(message, 2) end
end

local firstDate = os.time({ year = 2025, month = 9, day = 24, hour = 12 })
local secondDate = os.time({ year = 2025, month = 9, day = 25, hour = 12 })
local function add(text, sender, sourceId, sourceLabel, epoch, view)
	local id = engine.nextId
	engine.nextId = id + 1
	local record = {
		id = id, event = "CHAT_MSG_CHANNEL", text = text,
		sender = sender, channel = sourceLabel, channelName = sourceLabel,
		sourceId = sourceId, sourceLabel = sourceLabel, sourceGroup = "channels",
		epoch = epoch, view = view, views = { [view] = true },
	}
	engine:Store(record)
	return record
end

local old = add("WTS [Sword] 500g", "Seller-A", "channel:trade", "Trade", firstDate, "trade")
local general = add("Where is the sword trainer?", "Helper", "channel:general", "General", secondDate, "general")
local new = add("wts [SWORD] 450g", "Seller-B", "channel:trade", "Trade", secondDate, "trade")

local search = engine:SearchHistory({ text = "[sword]" })
expect(#search.records == 2 and search.records[1] == new and search.records[2] == old,
	"text search was not plain, case-insensitive, and newest-first")
expect(not search.hasMore and search.nextCursor == nil,
	"fully scanned search incorrectly offered another page")
expect(engine:SearchHistory({ sender = "seller-a" }).records[1] == old,
	"sender filtering ignored case")
expect(#engine:SearchHistory({ source = "channel:TRADE" }).records == 2
	and #engine:SearchHistory({ source = "general" }).records == 1,
	"source ID and label filtering diverged")
expect(engine:SearchHistory({ date = "2025-09-24" }).records[1] == old
	and #engine:SearchHistory({ date = "2025-09-24" }).records == 1,
	"local-calendar date filtering failed")
expect(#engine:SearchHistory({ fromEpoch = secondDate, toEpoch = secondDate }).records == 2,
	"inclusive epoch range failed")
expect(#engine:SearchHistory({ viewId = "trade" }).records == 2
	and engine:SearchHistory({ viewId = "general" }).records[1] == general,
	"view filtering failed or duplicated cross-view records")
expect(engine:SearchHistory({ date = "bad-date" }).error == "invalid-date"
	and engine:SearchHistory({ fromEpoch = secondDate, toEpoch = firstDate }).error == "invalid-epoch-range",
	"invalid date/range was silently treated as an unrestricted query")

-- Scan and result caps both produce stable cursors. Empty filtered pages must
-- advance too, so a rare match can be found beyond thousands of other lines.
search = engine:SearchHistory({ sender = "Seller-A", scanLimit = 1 })
expect(#search.records == 0 and search.scanned == 1 and search.hasMore
	and search.nextCursor.sequence == general.historySequence,
	"empty search page did not advance to the previous sequence")
search = engine:SearchHistory({ sender = "Seller-A", scanLimit = 1,
	cursor = search.nextCursor })
expect(#search.records == 0 and search.hasMore
	and search.nextCursor.sequence == old.historySequence,
	"second empty search page did not advance")
search = engine:SearchHistory({ sender = "Seller-A", scanLimit = 1,
	cursor = search.nextCursor })
expect(#search.records == 1 and search.records[1] == old and not search.hasMore,
	"deep sender match was not reached through the cursor")
search = engine:SearchHistory({ source = "Trade", limit = 1 })
expect(#search.records == 1 and search.records[1] == new and search.hasMore,
	"result cap did not return only the newest match")
local tradeCursor = search.nextCursor
local arrival = add("fresh arrival", "Seller-C", "channel:trade", "Trade", secondDate, "trade")
search = engine:SearchHistory({ source = "Trade", limit = 1,
	cursor = tradeCursor })
expect(#search.records == 1 and search.records[1] == old and not search.hasMore,
	"new arrivals shifted a bounded cursor or older match was omitted")
expect(engine:SearchHistory({ source = "Trade", limit = 1 }).records[1] == arrival,
	"new arrivals were not searchable from a fresh cursor")

-- A manual block removes old copies from both normal runtime search and the
-- persisted ring; unblocking later must not resurrect them after restore.
addon.BlockControl = {
	ShouldBlock = function(_, record)
		return record.sender == "Seller-A", "rule", { id = "seller" }
	end,
	ArchiveRecord = function(self, record)
		self.archived = self.archived or {}
		self.archived[#self.archived + 1] = record.text
	end,
}
expect(engine:ReapplyBlockRules() == 1,
	"manual block did not purge retained normal history")
expect(#engine:SearchHistory({ text = "500g" }).records == 0
	and #engine:SearchHistory({ sender = "Seller-A", exactSender = true }).records == 0
	and #addon.BlockControl.archived == 1,
	"blocked text or sender history was searchable in normal history or not archived")
addon.BlockControl.ShouldBlock = function() return false end
engine:ResetForProfile()
expect(#engine:SearchHistory({ text = "500g" }).records == 0
	and #engine:SearchHistory({ text = "450g" }).records == 1,
	"blocked text reappeared after persisted-history restore")

-- Ring eviction must also remove old search hits; an empty result here is not
-- evidence of another archived/private corpus being queried.
local staleCursor = engine:SearchHistory({ limit = 1 }).nextCursor
engine:ClearHistory()
expect(engine:SearchHistory({ cursor = staleCursor }).error == "stale-cursor",
	"CLEAR reused a stale search cursor against a new transcript")
add("evicted-needle", "A", "channel:trade", "Trade", firstDate, "trade")
for index = 1, 100 do
	add("later " .. index, "B", "channel:trade", "Trade", secondDate, "trade")
end
expect(#engine:SearchHistory({ text = "evicted-needle" }).records == 0,
	"source-cap eviction left a stale searchable record")
engine:ClearHistory()
expect(#engine:SearchHistory({ text = "later" }).records == 0,
	"cleared history remained searchable")

-- Player-name HISTORY uses an exact sender boundary. A substring search must
-- remain available in ordinary FIND, but Ada must not include Adaline.
local ada = add("first message", "Ada", "channel:general", "General", secondDate, "general")
add("similarly named", "Adaline", "channel:general", "General", secondDate, "general")
local adaAgain = add("second message", "ada", "channel:trade", "Trade", secondDate, "trade")
search = engine:SearchHistory({ sender = "ADA", exactSender = true })
expect(#search.records == 2 and search.records[1] == adaAgain and search.records[2] == ada,
	"exact sender history mixed another player's retained messages or lost case-insensitive matching")
expect(#engine:SearchHistory({ sender = "ADA" }).records == 3
	and #engine:SearchHistory({ sender = "", exactSender = true }).records == 0,
	"ordinary sender substring search changed or empty exact sender exposed the full transcript")

print("Chat history search mock tests passed")
