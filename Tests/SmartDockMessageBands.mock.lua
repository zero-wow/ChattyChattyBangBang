-- Focused no-client contract for logical-message alternating background bands.
-- Run from the addon root with: lua Tests/SmartDockMessageBands.mock.lua

local bandSettings = {
	enabled = true,
	extent = "afterPlayer",
	extendUnderScrollbar = false,
	color = { theme = "surfaceRaised" },
	alpha = 0.22,
}

ChattyChattyBangBang = {
	Theme = {
		GetColor = function(_, name)
			assert(name == "surfaceRaised", "message band requested the wrong theme color")
			return 0.1, 0.2, 0.3, 1
		end,
	},
	Presentation = {
		FormatParts = function(_, record)
			if record.sender then return "PLAYERPREFIX", record.text end
			return "CHANNEL", record.text
		end,
	},
}

function ChattyChattyBangBang:GetSmartChatMessageBandSettings()
	return bandSettings
end

dofile("Core/SmartDock.lua")

local dock = ChattyChattyBangBang.SmartDock
local display = {
	width = 300,
	height = 50,
	visibleLines = 5,
	scroll = 0,
	spacing = 0,
	GetWidth = function(self) return self.width end,
	GetHeight = function(self) return self.height end,
	GetFont = function() return "Fonts\\FRIZQT__.TTF", 10 end,
	GetSpacing = function(self) return self.spacing end,
	GetNumLinesDisplayed = function(self) return self.visibleLines end,
	GetCurrentScroll = function(self) return self.scroll end,
}
local measure = {
	SetWidth = function(self, width) self.width = width end,
	SetText = function(self, text) self.text = text end,
	GetStringWidth = function(self) return #(self.text or "") * 5 end,
}
local textures = {}
local host = {
	CreateTexture = function(_, _, layer)
		assert(layer == "ARTWORK", "message band was not placed behind the child chat frame")
		local texture = {
			points = {},
			SetTexture = function(self, path) self.path = path end,
			SetVertexColor = function(self, ...) self.color = { ... } end,
			ClearAllPoints = function(self) self.points = {} end,
			SetPoint = function(self, ...) table.insert(self.points, { ... }) end,
			Show = function(self) self.shown = true end,
			Hide = function(self) self.shown = false end,
		}
		table.insert(textures, texture)
		return texture
	end,
}

dock.display = display
dock.messageMeasure = measure
dock.messageBandHost = host
dock.messageBandPool = {}
dock.transientMessageRightInset = 16
dock.displayMeasurementWidth = 300 -- The test supplies exact logical line counts.
dock.displayRecords = {
	{ record = { timestamp = "12:34", sender = "One", text = "one" }, lines = 1, bandAlternate = false },
	{ record = { timestamp = "12:34", sender = "Two", text = "two wraps" }, lines = 2, bandAlternate = true },
	{ record = { timestamp = "12:34", sender = "Three", text = "three" }, lines = 1, bandAlternate = false },
	{ record = { timestamp = "12:34", sender = "Four", text = "four wraps" }, lines = 2, bandAlternate = true },
}

assert(dock:RefreshMessageBands(), "enabled message bands did not render")
assert(#textures == 2 and dock.messageBandVisibleCount == 2,
	"wrapped logical records did not produce exactly one band apiece")
assert(textures[1].points[1][4] == 60,
	"AFTER PLAYER did not begin at the measured player/message boundary")
assert(textures[1].points[1][5] == 0 and textures[1].points[2][5] == -20,
	"the wrapped entry lost its continuous band at the top clip")
assert(textures[2].points[1][5] == -30 and textures[2].points[2][5] == -50,
	"the bottom-clipped wrapped entry escaped its own rows or the viewport")
assert(textures[1].color[1] == 0.1 and textures[1].color[2] == 0.2
	and textures[1].color[3] == 0.3 and textures[1].color[4] == 0.22,
	"message band color or independent alpha was lost")

-- Wrath reports displayed logical messages here (3), not their five visible
-- wrapped rows. It must never be treated as a visual-line count or the bands
-- shift down onto unrelated chat entries.
display.visibleLines = 3
assert(dock:RefreshMessageBands(), "logical-message count disabled row bands")
assert(textures[1].points[1][5] == 0 and textures[1].points[2][5] == -20,
	"displayed message count was mistaken for visual rows and shifted the zebra bands")
display.visibleLines = 5

-- Scrolling clips one logical band and moves the surviving entry as a unit.
display.scroll = 2
assert(dock:RefreshMessageBands(), "scrolled history did not repaint message bands")
assert(dock.messageBandVisibleCount == 1 and textures[1].shown and textures[2].shown == false,
	"offscreen alternating records were not released from the bounded pool")
assert(textures[1].points[1][5] == -20 and textures[1].points[2][5] == -40,
	"scrolled wrapped entry spilled onto adjacent no-gap rows")

-- Every configured start boundary is measured from the same formatted leader
-- used by the visible ScrollingMessageFrame.
display.scroll = 0
bandSettings.extent = "afterTimestamp"
dock:RefreshMessageBands()
assert(textures[1].points[1][4] == 40, "AFTER TIMESTAMP used the wrong pixel boundary")
bandSettings.extent = "afterChannel"
dock:RefreshMessageBands()
assert(textures[1].points[1][4] == 35, "AFTER CHANNEL used the wrong formatted boundary")
bandSettings.extent = "full"
dock:RefreshMessageBands()
assert(textures[1].points[1][4] == -3,
	"FULL ROW did not reach the content panel's one-pixel inner left edge")
assert(textures[1].points[2][4] == 0,
	"ordinary message shade no longer stopped at the readable text viewport")

-- Full bleed changes only the decorative right endpoint: the chat viewport,
-- every configured left boundary, and the scrollbar hit lane remain separate.
bandSettings.extendUnderScrollbar = true
dock:RefreshMessageBands()
assert(textures[1].points[1][4] == -3 and textures[1].points[2][4] == 15,
	"full-bleed shade did not reach both one-pixel inner panel edges")
dock.transientMessageLeftInset = 20
dock:RefreshMessageBands()
assert(textures[1].points[1][4] == -19 and textures[1].points[2][4] == 15,
	"message-dot text gutter stopped a FULL ROW background before the panel edge")
dock.transientMessageLeftInset = nil
bandSettings.extent = "afterPlayer"
dock:RefreshMessageBands()
assert(textures[1].points[1][4] == 60 and textures[1].points[2][4] == 15,
	"full-bleed shade changed the configured metadata boundary instead of only its right edge")

-- Before the first live layout pass, derive the same lane from the persisted
-- scrollbar preference. Hidden scrollbar chrome still keeps a stable text
-- inset while decorative paint reaches the same one-pixel panel edge.
dock.transientMessageRightInset = nil
function ChattyChattyBangBang:GetSmartSettings()
	return { dock = { showScrollButtons = false } }
end
dock:RefreshMessageBands()
assert(textures[1].points[2][4] == 3,
	"pre-layout full bleed did not derive the hidden-scrollbar viewport inset")

-- With no entry gap, a shade owns exactly its physical row. Native line
-- spacing provides glyph padding; the band never leaks over adjacent text.
bandSettings.extendUnderScrollbar = false
bandSettings.extent = "full"
dock.displayRecords = {
	{ record = { text = "one" }, lines = 1, bandAlternate = false },
	{ record = { sender = "Two", text = "two" }, lines = 1, bandAlternate = true },
	{ record = { text = "three" }, lines = 1, bandAlternate = false },
}
assert(dock:RefreshMessageBands() and dock.messageBandVisibleCount == 1,
	"single-line alternating entry did not paint")
assert(textures[1].points[1][4] == -3
	and textures[1].points[1][5] == -30 and textures[1].points[2][5] == -40
	and textures[1].points[2][4] == 0,
	"single-line band did not stay within its own balanced row")

-- A narrow display cannot host an AFTER PLAYER stripe whose prefix is wider
-- than the text area. Retire the prior texture rather than spilling outward.
bandSettings.extent = "afterPlayer"
display.width = 59
dock.displayMeasurementWidth = display.width
assert(dock:RefreshMessageBands() and dock.messageBandVisibleCount == 0
	and textures[1].shown == false,
	"narrow text viewport left a band outside the readable width")
display.width = 300
dock.displayMeasurementWidth = display.width
bandSettings.extent = "full"

-- Partially visible one-line records clip overhang at each viewport edge.
display.height = 20
display.scroll = 1
dock.displayRecords[1].bandAlternate = true
dock.displayRecords[2].bandAlternate = false
assert(dock:RefreshMessageBands() and textures[1].points[1][5] == 0
	and textures[1].points[2][5] == -10,
	"top-clipped shade escaped the viewport or its own row")
display.scroll = 0
dock.displayRecords[1].bandAlternate = false
dock.displayRecords[3].bandAlternate = true
assert(dock:RefreshMessageBands() and textures[1].points[1][5] == -10
	and textures[1].points[2][5] == -20,
	"bottom-clipped shade escaped the viewport or its own row")

-- Optional blank rows are partitioned at their midpoint. Each neighbor gets
-- equal visible breathing room, even with odd native line height, and a
-- wrapped message remains one continuous band through all content lines.
display.height = 132
display.spacing = 1
display.scroll = 0
dock.displayRecords = {
	{ record = { text = "one" }, gapRows = 0, lines = 1, bandAlternate = false },
	{ record = { sender = "Two", text = "two wraps" }, gapRows = 1, lines = 3, bandAlternate = true },
	{ record = { text = "three" }, gapRows = 1, lines = 2, bandAlternate = false },
	{ record = { sender = "Four", text = "four" }, gapRows = 2, lines = 3, bandAlternate = true },
	{ record = { text = "five" }, gapRows = 2, lines = 3, bandAlternate = false },
}
assert(dock:RefreshMessageBands() and dock.messageBandVisibleCount == 2,
	"entry gaps broke alternating logical-message count")
assert(textures[1].points[1][5] == -17 and textures[1].points[2][5] == -50,
	"one-row gap did not split at the same boundary around a wrapped band")
assert(textures[2].points[1][5] == -77 and textures[2].points[2][5] == -110,
	"two-row gap did not split evenly around the later band")
assert(textures[1].points[2][4] == 0 and textures[2].points[2][4] == 0,
	"entry spacing altered the text viewport or scrollbar lane")

-- A clipped multi-row gap must not paint beyond the viewport. The following
-- band owns only its half of that gap, rather than coloring the whole spacer.
display.height = 33
display.scroll = 1
assert(dock:RefreshMessageBands() and dock.messageBandVisibleCount == 1,
	"clipped gap lost the final alternating message")
assert(textures[1].points[1][5] == 0 and textures[1].points[2][5] == -22,
	"clipped gap band escaped the viewport or claimed both halves")

-- A real font may advance farther than its nominal GetFont() size, and Retail
-- can report one partly clipped row beyond floor(frame height / advance).
-- The old estimate shifted the shade one line below the first wrapped row.
display.height = 54
display.spacing = 1
display.scroll = 0
display.GetNumVisibleLines = function() return 4 end
measure.GetLineHeight = function() return 14 end
measure.GetStringHeight = function(self)
	return self.text == "Hg\nHg" and 27 or 13
end
measure.GetNumLines = function(self)
	return self.text == "wrapped body" and 2 or 1
end
dock.displayLineMetrics = nil
assert(dock:GetDisplayLineHeight() == 15,
	"band stride used nominal font size instead of the mirrored font's line height")
assert(dock:MeasureDisplayRecordLines("wrapped body") == 2,
	"wrapped entry count ignored Retail's measured visible rows")
dock.displayMeasurementWidth = display.width
dock.displayRecords = {
	{ record = { text = "one" }, lines = 1, bandAlternate = false },
	{ record = { text = "two" }, lines = 2, bandAlternate = true },
	{ record = { text = "three" }, lines = 1, bandAlternate = false },
	{ record = { text = "four" }, lines = 1, bandAlternate = true },
}
local _, measuredGeometry = dock:GetVisibleDisplayRecordEntries()
assert(measuredGeometry.capacity == 4 and measuredGeometry.topInset == -6,
	"native partly clipped top row was lost to floor-based viewport geometry")
assert(dock:RefreshMessageBands() and dock.messageBandVisibleCount == 2,
	"calibrated visible rows lost alternating entries")
assert(textures[1].points[1][5] == 0 and textures[1].points[2][5] == -24,
	"wrapped band's first row was left unshaded or painted outside the viewport")
assert(textures[2].points[1][5] == -39 and textures[2].points[2][5] == -54,
	"calibrated row advance displaced the next logical entry")

-- When only a few messages exist, the same native viewport bottom-aligns
-- their rows rather than painting an empty strip above them.
dock.displayRecords = {
	{ record = { text = "one" }, lines = 1, bandAlternate = false },
	{ record = { text = "two" }, lines = 1, bandAlternate = true },
}
local _, underfilled = dock:GetVisibleDisplayRecordEntries()
assert(underfilled.topInset == 24,
	"underfilled native viewport did not preserve bottom alignment")
assert(dock:RefreshMessageBands() and textures[1].points[1][5] == -39
	and textures[1].points[2][5] == -54,
	"underfilled band did not stay behind its own message")

bandSettings.enabled = false
assert(dock:RefreshMessageBands() == false and textures[1].shown == false,
	"disabling alternating entries left a stale background visible")

print("SmartDock logical-message band mock passed")
