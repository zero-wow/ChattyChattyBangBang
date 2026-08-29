-- Focused no-client contract for logical-message alternating background bands.
-- Run from the addon root with: lua Tests/SmartDockMessageBands.mock.lua

local bandSettings = {
	enabled = true,
	extent = "afterPlayer",
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
	GetWidth = function(self) return self.width end,
	GetHeight = function(self) return self.height end,
	GetFont = function() return "Fonts\\FRIZQT__.TTF", 10 end,
	GetSpacing = function() return 0 end,
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
	"one wrapped entry did not retain one continuous two-line band")
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
	"scrolled wrapped entry was not mapped to its exact visible logical span")

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
assert(textures[1].points[1][4] == 0, "FULL LINE did not begin at the chat edge")

bandSettings.enabled = false
assert(dock:RefreshMessageBands() == false and textures[1].shown == false,
	"disabling alternating entries left a stale background visible")

print("SmartDock logical-message band mock passed")
