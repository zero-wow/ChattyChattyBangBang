-- Bookmarks are bounded references to retained normal records, not body copies.
-- Run from the Retail addon root: lua Tests/ChatHistoryBookmarks.mock.lua
dofile("Tests/ChatHistory.mock.lua")

local addon = ChattyChattyBangBang
local engine = addon.MessageEngine
local settings = addon:GetSmartSettings()
settings.persistHistory = true
settings.historyCapacity = 100
addon.BlockControl = nil
engine:ClearHistory()

local function add(index, channel)
	channel = channel or "General"
	local record = assert(engine:Normalize("CHAT_MSG_CHANNEL", "bookmark " .. index,
		"Poster", nil, channel, nil, nil, nil, channel == "Trade" and 2 or 1,
		channel, nil, 900 + index, "Player-1-BOOKMARK"))
	return assert(engine:Deliver(record))
end

local first = add(1)
assert(engine:ToggleBookmark(first) == true and engine:IsBookmarked(first),
	"retained message could not be saved")
assert(engine:GetBookmarkCount() == 1 and settings.history.bookmarks[first.historySequence] == true,
	"SavedVariables did not retain only the bookmark sequence")
for sequence, value in pairs(settings.history.bookmarks) do
	assert(type(sequence) == "number" and value == true,
		"bookmark storage copied message content or an invalid identifier")
end
assert(engine:SearchHistory({ bookmarked = true }).records[1] == first,
	"saved-only search did not find a retained bookmark")
assert(engine:ToggleBookmark(first) == false and not engine:IsBookmarked(first),
	"bookmark could not be removed")
assert(#engine:SearchHistory({ bookmarked = true }).records == 0,
	"removed bookmark remained in saved-only search")
assert(engine:ToggleBookmark(first) == true)
local sequence = first.historySequence
engine:ResetForProfile()
local restored = engine:GetMessages()[1]
assert(restored and restored.historySequence == sequence and engine:IsBookmarked(restored),
	"bookmark did not survive SavedVariables restore with a new runtime ID")
assert(engine:ToggleBookmark(first) == nil,
	"stale pre-reload record was allowed to change the live bookmark set")

addon.BlockControl = {
	ShouldBlock = function(_, record)
		return record.text == "bookmark 1", "rule", { id = "bookmark-test" }
	end,
	ArchiveRecord = function() end,
}
assert(engine:ReapplyBlockRules() == 1 and engine:GetBookmarkCount() == 0
	and settings.history.bookmarks[sequence] == nil
	and #engine:SearchHistory({ bookmarked = true }).records == 0,
	"blocking a retained line failed to purge its bookmark from live and saved history")
addon.BlockControl = nil

engine:ClearHistory()
local records = {}
for index = 1, 101 do
	records[index] = add(index, index % 2 == 0 and "Trade" or "General")
	assert(engine:ToggleBookmark(records[index]) == true)
end
assert(engine:GetBookmarkCount() == 100 and not engine:IsBookmarked(records[1])
	and engine:IsBookmarked(records[101]),
	"bookmark cap did not evict the oldest saved reference")
assert(#engine:SearchHistory({ bookmarked = true, limit = 200 }).records == 100,
	"saved-only search ignored the 100-reference cap")
engine:ResetForProfile()
assert(engine:GetBookmarkCount() == 100
	and #engine:SearchHistory({ bookmarked = true, limit = 200 }).records == 100,
	"bounded bookmarks did not survive reload")
settings.history.bookmarks[records[1].historySequence] = true
settings.history.bookmarks[999999] = true
engine:ResetForProfile()
assert(engine:GetBookmarkCount() == 100
	and settings.history.bookmarks[records[1].historySequence] == nil
	and settings.history.bookmarks[999999] == nil,
	"malformed or over-limit SavedVariables bookmarks were not pruned to retained lines")

engine:ClearHistory()
local evicted = add(1000)
local evictedSequence = evicted.historySequence
assert(engine:ToggleBookmark(evicted) == true)
for index = 1001, 1100 do add(index) end
assert(engine:GetBookmarkCount() == 0 and settings.history.bookmarks[evictedSequence] == nil,
	"per-source history eviction left a dangling saved bookmark")
assert(engine:ToggleBookmark(evicted) == nil,
	"evicted record could be bookmarked after removal")

print("Chat history bookmarks mock passed")
