-- Focused no-client proof for finite ScrollingMessageFrame history pages.
-- Run from the addon root with: lua Tests/SmartDockHistoryPaging.mock.lua

ChattyChattyBangBang = {
	Theme = {},
	Presentation = { GetSource = function() return "" end },
}
dofile("Core/SmartDock.lua")

local dock = ChattyChattyBangBang.SmartDock
local display = {
	entries = {}, maxLines = 500, scroll = 0,
	AddMessage = function(self, text)
		table.insert(self.entries, text)
		while #self.entries > self.maxLines do table.remove(self.entries, 1) end
	end,
	Clear = function(self) self.entries = {}; self.scroll = 0 end,
	GetNumMessages = function(self) return #self.entries end,
	GetCurrentScroll = function(self) return self.scroll end,
	SetScrollOffset = function(self, value) self.scroll = value end,
	ScrollToBottom = function(self) self.scroll = 0 end,
	AtBottom = function(self) return self.scroll == 0 end,
	GetWidth = function() return 200 end,
	GetHeight = function() return 50 end,
	GetLeft = function() return 0 end,
	GetRight = function() return 200 end,
	GetTop = function() return 50 end,
	GetBottom = function() return 0 end,
}
dock.display = display
dock.displayRecords = {}
dock.FormatDisplayRecord = function(_, record) return record.text end
dock.MeasureDisplayRecordLines = function(_, renderedText)
	return renderedText == "wrapped" and 2 or 1
end
dock.GetDisplayRecordGapRows = function(_, index) return index > 1 and 1 or 0 end
dock.GetDisplayLineHeight = function() return 10 end
dock.RefreshMessageBands = function() end
dock.RefreshMessageScrollbar = function() end
dock.HideMessageActionHighlight = function() end
dock.HideMessageBands = function() end
UIParent = { GetEffectiveScale = function() return 1 end }
local cursorY = 35
GetCursorPosition = function() return 20, cursorY end

-- Four independently wrapped logical entries fit a five-row viewport without
-- requiring a separate FontString/button per message. A page replacement clears
-- both native text and the parallel record map together.
local older = { id = 1, text = "older" }
local wrapped = { id = 2, text = "wrapped" }
dock:AppendDisplayRecord(older)
dock:AppendDisplayRecord(wrapped)
assert(display:GetNumMessages() == 2 and #dock.displayRecords == 2)
assert(dock.displayRecords[2].gapRows == 1 and dock.displayRecords[2].lines == 3)
local record = dock:GetDisplayRecordAtCursor()
assert(record == older, "first page lost the first record's hit target")
cursorY = 15
record = dock:GetDisplayRecordAtCursor()
assert(record == wrapped, "wrapped page entry mapped to the wrong record")

display:Clear()
dock:ClearDisplayRecordCache()
local newer = { id = 3, text = "newer" }
dock:AppendDisplayRecord(newer)
cursorY = 5
record = dock:GetDisplayRecordAtCursor()
assert(record == newer and #dock.displayRecords == display:GetNumMessages(),
	"page replacement left a stale native/cache mapping")

-- Exercise actual page slicing rather than only the renderer/cache proof.
local settings = { safety = { localIgnores = {} }, dock = {}, views = { general = true } }
function ChattyChattyBangBang:GetSmartSettings() return settings end
function ChattyChattyBangBang:IsRecordAllowedInView(_, record)
	return record.id ~= 500
end
local messages = {}
for id = 1, 901 do
	messages[id] = { id = id, text = id == 501 and "wrapped" or "line " .. id, view = "general" }
end
ChattyChattyBangBang.MessageEngine = {
	GetMessages = function() return messages end,
}
local function fakeButton()
	return {
		Show = function(self) self.shown = true end,
		Hide = function(self) self.shown = false end,
		IsShown = function(self) return self.shown == true end,
	}
end
dock.historyPager = fakeButton()
dock.historyOlderButton = fakeButton()
dock.historyNewerButton = fakeButton()
dock.historyLatestButton = fakeButton()
dock.RefreshTransientMessageLayout = function() end
dock.IsAlignmentVisibleOnly = function() return false end
dock.GetRoundedDisplayPixelWidth = function() return 200 end
dock.HideMessageBlockControls = function() end
dock.ResetActiveSourceColumnMetrics = function() end
dock.CalculateSenderColumnWidth = function() return 0 end
dock.CalculateSenderColumnLongest = function() return 0 end
dock.GetColumnAlignmentSpacing = function() return 0 end
dock.GetSenderColumnAlignmentSpacing = function() return 0 end
dock.ResetActiveMetadataMetrics = function() end
dock.ResolveActiveResponsiveMetadata = function() return false end
dock.RefreshHangingMessageWrapMode = function() end
dock.UpdateEmptyState = function() end
dock.emptyState = { Hide = function() end }
dock.ScheduleMessageBlockActionRefresh = function() end
dock.RefreshRailState = function() end
dock.active = true
dock.activeView = "general"
dock.railButtons = {}
dock:RebuildActiveView()
assert(#dock.displayRecords == 400 and #display.entries == 400,
	"latest page did not stay below the native 500-entry limit")
assert(dock.displayRecords[1].record.id == 502 and dock.displayRecords[400].record.id == 901,
	"latest page selected the wrong eligible records")
assert(dock.historyPager.shown and dock.historyOlderButton.shown
	and not dock.historyNewerButton.shown,
	"retained older history has no visible entry point")

assert(dock:StepHistoryPage(1), "older page did not open")
assert(dock.historyPageOffset == 400 and dock.displayRecords[1].record.id == 101
	and dock.displayRecords[400].record.id == 501,
	"older page skipped, duplicated, or misordered records")
assert(#display.entries == #dock.displayRecords and #display.entries == 400,
	"older page's native buffer and hit-target cache diverged")
cursorY = 5
record = dock:GetDisplayRecordAtCursor()
assert(record and record.id == 501,
	"wrapped entry at the page boundary mapped to the wrong record")

table.insert(messages, { id = 902, text = "new arrival", view = "general" })
dock:OnMessage(messages[#messages])
assert(dock.historyPageOffset == 401 and dock.displayRecords[400].record.id == 501
	and #display.entries == 400 and dock.pendingVisible == 1,
	"live chat was appended out of order or displaced an older page")
-- On Retail the native visual-row range is authoritative; returning from an
-- older page should land at that real top offset, not a cached-row estimate.
display.GetMaxScrollRange = function() return 123 end
assert(dock:StepHistoryPage(-1), "newer page did not open")
assert(dock.historyPageOffset == 1 and dock.displayRecords[1].record.id == 502
	and dock.pendingVisible == 1 and display.scroll == 123,
	"newer page lost continuity or its new-message marker")
assert(dock:ScrollMessageDisplayToBottom(), "go-to-bottom failed")
assert(dock.historyPageOffset == 0 and dock.displayRecords[400].record.id == 902
	and dock.pendingVisible == 0 and display:AtBottom(),
	"go-to-bottom did not restore the newest page")

-- The native frame may grow from a 400-entry rebuild to its 500-entry cap
-- during live chat. Paging must start immediately before its true oldest
-- retained entry, without a 100-message overlap or hidden gap.
for id = 903, 1002 do
	local incoming = { id = id, text = "live " .. id, view = "general" }
	table.insert(messages, incoming)
	dock:OnMessage(incoming)
end
assert(#display.entries == 500 and dock.displayRecords[1].record.id == 503,
	"latest native buffer did not retain its expected 500 entries")
assert(dock:StepHistoryPage(1) and dock.historyPageOffset == 500
	and dock.displayRecords[400].record.id == 502,
	"older page did not begin immediately before the live native buffer")

print("SmartDock finite history paging passed")
