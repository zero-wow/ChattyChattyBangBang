-- Focused no-client contract for Smart Dock's logical ENTRY GAP rows.
-- Run from the addon root with: lua Tests/SmartDockEntryGap.mock.lua

local cursorX, cursorY = 20, 95

UIParent = {
	GetEffectiveScale = function() return 1 end,
}

GetCursorPosition = function()
	return cursorX, cursorY
end

ChattyChattyBangBang = {
	Theme = {},
	Presentation = {
		Format = function(_, record) return record.text end,
	},
	GetSmartChatTextAppearance = function()
		return { size = 0, outline = "INHERIT", spacing = 0, entryGapRows = 1 }
	end,
}

dofile("Core/SmartDock.lua")

local dock = ChattyChattyBangBang.SmartDock
local display = {
	messages = {},
	width = 300,
	height = 40,
	top = 100,
	bottom = 60,
	scroll = 0,
	GetWidth = function(self) return self.width end,
	GetHeight = function(self) return self.height end,
	GetTop = function(self) return self.top end,
	GetBottom = function(self) return self.bottom end,
	GetLeft = function() return 0 end,
	GetRight = function() return 300 end,
	GetFont = function() return "Fonts\\FRIZQT__.TTF", 10 end,
	GetSpacing = function() return 0 end,
	GetCurrentScroll = function(self) return self.scroll end,
	GetNumMessages = function(self) return #self.messages end,
	AddMessage = function(self, text)
		table.insert(self.messages, text)
	end,
}
local measure = {
	SetWidth = function(self, width) self.width = width end,
	SetText = function(self, text) self.text = text end,
	GetStringHeight = function(self)
		local _, lineBreaks = string.gsub(self.text or "", "\n", "")
		return (lineBreaks + 1) * 10
	end,
}

dock.display = display
dock.messageMeasure = measure
dock.rebuildingDisplay = true
dock:AppendDisplayRecord({ id = 1, text = "first" })
dock:AppendDisplayRecord({ id = 2, text = "second" })

assert(#display.messages == 2,
	"ENTRY GAP must retain one ScrollingMessageFrame AddMessage call per logical record")
assert(display.messages[1] == "first", "the first record must not gain a leading gap")
assert(display.messages[2] == "|c00FFFFFF |r\nsecond",
	"later records must use the nonempty transparent in-message spacer row")
assert(dock.displayRecords[2].gapRows == 1 and dock.displayRecords[2].contentLines == 1
	and dock.displayRecords[2].lines == 2,
	"entry cache did not preserve separate gap and content line spans")

-- ScrollingMessageFrame evicts whole AddMessage payloads. The new oldest
-- payload still contains the spacer it originally received, so a later resize
-- must measure that encoded row instead of treating its new cache index as an
-- unprefixed first message.
display.messages = { display.messages[2] }
dock:TrimDisplayRecordCache()
dock.displayMeasurementWidth = nil
dock:RefreshDisplayRecordMeasurements()
assert(#dock.displayRecords == 1 and dock.displayRecords[1].gapRows == 1
	and dock.displayRecords[1].lines == 2,
	"resize-time measurement lost the encoded spacer after oldest-message eviction")

-- The second record consumes one blank gap row plus two content rows. This
-- verifies visible alignment, hit-testing, and band geometry all distinguish
-- that gap from actual message content.
dock.displayRecords = {
	{ record = { id = 1, text = "first" }, gapRows = 0, contentLines = 1, lines = 1, bandAlternate = false },
	{ record = { id = 2, text = "second" }, gapRows = 1, contentLines = 2, lines = 3, bandAlternate = true },
}
dock.displayMeasurementWidth = display.width
local entries, geometry = dock:GetVisibleDisplayRecordEntries()
assert(geometry.totalLines == 4 and #entries == 2,
	"entry gap rows were not included in the physical display geometry")
assert(entries[2].contentFirstLine == 3 and entries[2].contentLastLine == 4
	and entries[2].hasVisibleContent,
	"entry content span did not begin after the logical gap row")

cursorY = 85 -- physical line 2: the transparent ENTRY GAP row
assert(dock:GetDisplayRecordAtCursor() == nil,
	"Shift actions or analysis must not target a message from its blank entry gap")
cursorY = 75 -- physical line 3: second record content
assert(dock:GetDisplayRecordAtCursor().id == 2,
	"hit testing did not resume at the first real content row")

local band = {
	points = {},
	ClearAllPoints = function(self) self.points = {} end,
	SetPoint = function(self, ...) table.insert(self.points, { ... }) end,
	SetVertexColor = function() end,
	Show = function(self) self.shown = true end,
	Hide = function(self) self.shown = false end,
}
dock.GetMessageBandAppearance = function()
	return { enabled = true, alpha = 0.5, extent = "full", r = 1, g = 1, b = 1 }
end
dock.MeasureMessageBandPrefix = function() return 0 end
dock.AcquireMessageBand = function() return band end
dock.messageBandPool = { band }
assert(dock:RefreshMessageBands(), "message bands did not refresh with entry-gap geometry")
assert(band.points[1][5] == -20 and band.points[2][5] == -40,
	"alternating band covered the transparent entry gap instead of only content rows")

display.height = 10
display.bottom = 90
display.scroll = 2 -- only physical line 2 (the second record's gap) is visible
entries = dock:GetVisibleDisplayRecordEntries()
assert(#entries == 1 and not entries[1].hasVisibleContent,
	"gap-only viewport was incorrectly reported as message content")
local visibleRecords = dock:GetVisibleAlignmentRecords()
assert(#visibleRecords == 0,
	"visible-only alignment must not let a blank entry gap influence column widths")

print("Smart Dock entry-gap mock: PASS")
