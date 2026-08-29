-- Focused no-client contract for viewport-scoped column alignment.
-- Run from the addon root with: lua Tests/SmartDockVisibleAlignment.mock.lua

local settings = {
	dock = {
		columnAlignmentSpacing = -3,
		senderColumnAlignmentSpacing = -2,
		senderColumnMaxLength = 7,
		alignmentVisibleOnly = true,
	},
}

ChattyChattyBangBang = {
	Theme = {},
	Presentation = {
		GetSource = function(_, record) return record.source or "" end,
	},
	MessageEngine = {},
	GetSmartSettings = function() return settings end,
	GetViewSourceColumnAlignment = function() return true end,
	GetViewSenderColumnAlignment = function() return true end,
	GetColumnAlignmentSpacing = function() return settings.dock.columnAlignmentSpacing end,
	GetSenderColumnAlignmentSpacing = function() return settings.dock.senderColumnAlignmentSpacing end,
	GetSenderColumnMaxLength = function() return settings.dock.senderColumnMaxLength end,
	GetAlignmentVisibleOnly = function() return settings.dock.alignmentVisibleOnly end,
}

dofile("Core/SmartDock.lua")

local dock = ChattyChattyBangBang.SmartDock
local display = {
	width = 300,
	height = 40,
	visibleLines = 4,
	scroll = 1,
	GetWidth = function(self) return self.width end,
	GetHeight = function(self) return self.height end,
	GetFont = function() return "Fonts\\FRIZQT__.TTF", 10 end,
	GetSpacing = function() return 0 end,
	GetNumLinesDisplayed = function(self) return self.visibleLines end,
	GetCurrentScroll = function(self) return self.scroll end,
	AtBottom = function(self) return self.scroll == 0 end,
	ScrollUp = function(self) self.scroll = self.scroll + 1 end,
	ScrollToBottom = function(self) self.scroll = 0 end,
}

dock.display = display
dock.displayMeasurementWidth = 300 -- Exact logical spans are supplied below.
dock.displayRecords = {
	{ record = { id = 1, source = "OFFSCREEN", sender = "OffscreenName" }, lines = 2 },
	{ record = { id = 2, source = "TRADE", sender = "Ari" }, lines = 3 },
	{ record = { id = 3, source = "GUILD", sender = "Bea" }, lines = 1 },
	{ record = { id = 4, source = "SYSTEM", sender = "Cy" }, lines = 2 },
}

local visible, geometry = dock:GetVisibleDisplayRecordEntries()
assert(#visible == 3 and visible[1].record.id == 2 and visible[3].record.id == 4,
	"viewport scope included an offscreen newest/history record or missed a clipped visible record")
assert(visible[1].visibleFirstLine == 4 and visible[1].visibleLastLine == 5
	and visible[3].visibleFirstLine == 7 and visible[3].visibleLastLine == 7,
	"visible logical entries were not derived from their clipped wrapped-line spans")
assert(geometry.firstVisibleLine == 4 and geometry.lastVisibleLine == 7,
	"viewport line bounds did not follow ScrollingMessageFrame scroll state")

-- Signed gaps compact lane content but never produce a negative physical lane.
assert(dock:CalculateSourceColumnWidth({ { source = "SYSTEM" } }) == 3,
	"negative CHANNEL GAP did not compact the six-cell source by three cells")
assert(dock:CalculateSenderColumnWidth({ { sender = "Alexandra" }, { sender = "Bo" } }) == 9,
	"NAME MAX did not cap the visible-only sender lane at seven name cells plus brackets")
assert(dock:GetEffectiveSenderColumnWidth(9, -2) == 7
	and dock:GetEffectiveSenderColumnWidth(3, -8) == 3,
	"negative [NAME] GAP overlapped/removed the bracketed lane instead of clamping safely")

local rebuiltScopes = {}
dock.active = true
dock.activeView = "general"
dock.pendingVisible = 3
dock.activeAlignmentScopeSignature = dock:GetAlignmentScopeSignature({
	dock.displayRecords[1].record,
	dock.displayRecords[2].record,
	dock.displayRecords[3].record,
	dock.displayRecords[4].record,
})
dock.RefreshMessageBands = function() return true end
dock.UpdateSourceColumnAlignmentControl = function() end
dock.RefreshNewMessageIndicator = function() end
dock.RebuildActiveView = function(self, scope, skipVisibleRefresh)
	assert(skipVisibleRefresh == true, "visible alignment recursively scheduled another visible refresh")
	local ids = {}
	for index, record in ipairs(scope) do ids[index] = record.id end
	table.insert(rebuiltScopes, table.concat(ids, ","))
	self.activeAlignmentScopeSignature = self:GetAlignmentScopeSignature(scope)
	-- A real rebuild starts at bottom; RefreshVisibleAlignment must restore the
	-- reader's prior line distance before evaluating the settled viewport again.
	display.scroll = 0
end

assert(dock:RefreshVisibleAlignment(), "visible-only alignment did not recompute after viewport change")
assert(#rebuiltScopes == 1 and rebuiltScopes[1] == "2,3,4",
	"alignment was not rebuilt exclusively from currently visible logical records")
assert(display.scroll == 1 and dock.pendingVisible == 3,
	"visible-only alignment rebuild lost scroll position or pending-new-message state")
assert(not dock:RefreshVisibleAlignment() and #rebuiltScopes == 1,
	"an unchanged visible logical scope caused a redundant rebuild")

-- Height changes and subsequent scrolling must derive a fresh logical scope;
-- neither path may reuse the newest-history window broadly.
display.height = 20
display.visibleLines = 2
assert(dock:RefreshVisibleAlignment() and rebuiltScopes[2] == "3,4",
	"height resize did not rescope alignment to the newly visible line spans")
display.scroll = 3
assert(dock:HandleDisplayViewportChanged() and rebuiltScopes[3] == "2",
	"scroll refresh did not release records that left the viewport")
assert(display.scroll == 3,
	"scroll-triggered visible alignment did not restore the reader's position")

print("SmartDock visible-only alignment mock passed")
