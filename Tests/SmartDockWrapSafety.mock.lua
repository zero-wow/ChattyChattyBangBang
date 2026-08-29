-- Focused no-client contract for conservative, pixel-validated hanging wrap.
-- Run from the addon root with: lua Tests/SmartDockWrapSafety.mock.lua

local settings = {
	keywordColors = {},
	keywordColorGroups = {},
	dock = {
		columnAlignmentSpacing = 0,
		senderColumnAlignmentSpacing = 0,
		responsiveMetadata = false,
	},
}

ChattyChattyBangBang = {
	GetSmartSettings = function() return settings end,
	GetViewSourceColumnAlignment = function() return true end,
	GetViewSenderColumnAlignment = function() return false end,
	GetColumnAlignmentSpacing = function() return 0 end,
	GetSenderColumnAlignmentSpacing = function() return 0 end,
}

local addon = ChattyChattyBangBang
addon.Theme = {
	GetPalette = function()
		return {
			text = { 0.91, 0.91, 0.86, 1 },
			textMuted = { 0.56, 0.63, 0.71, 1 },
			borderMuted = { 0.23, 0.34, 0.49, 1 },
			warning = { 1, 0.66, 0.25, 1 },
		}
	end,
	GetColor = function(self, name)
		local color = self:GetPalette()[name] or self:GetPalette().text
		return color[1], color[2], color[3], color[4]
	end,
}

dofile("Core/Presentation.lua")
dofile("Core/SmartDock.lua")

local function utf8Size(text, position)
	local first = string.byte(text, position) or 0
	if first >= 240 then return 4 end
	if first >= 224 then return 3 end
	if first >= 192 then return 2 end
	return 1
end

local function visibleMarkup(text)
	text = tostring(text or "")
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	text = string.gsub(text, "|r", "")
	text = string.gsub(text, "|H.-|h(.-)|h", "%1")
	text = string.gsub(text, "|T.-|t", "X")
	text = string.gsub(text, "|A.-|a", "X")
	return text
end

-- Simulate a fixed ASCII face whose Cyrillic fallback glyphs are 20% wider.
-- This is the mismatch that a nominal character-cell budget alone cannot see.
local function measuredPixels(text)
	text = visibleMarkup(text)
	local width, cursor = 0, 1
	while cursor <= #text do
		local size = utf8Size(text, cursor)
		width = width + (size > 1 and 12 or 10)
		cursor = cursor + size
	end
	return width
end

local display = {
	width = 401,
	GetWidth = function(self) return self.width end,
}
local measure = {
	SetWidth = function(self, width) self.width = width end,
	SetText = function(self, text) self.text = text end,
	GetStringWidth = function(self) return measuredPixels(self.text) end,
}

local dock = addon.SmartDock
dock.display = display
dock.messageMeasure = measure
dock.activeView = "general"
dock.activeColumnLayoutResolved = true
dock.activeSourceColumnWidth = 5
dock.activeSenderColumnWidth = nil
dock.activeSenderColumnAlignmentSpacing = 0
dock.activeResponsiveMetadataEnabled = false

assert(dock:GetDisplayColumnCapacity() == 38,
	"manual wrap did not reserve the required two-cell ScrollingMessageFrame safety margin")

local url = "https://example.com/оченьдлинныйпуть,"
local record = {
	id = 1,
	timestamp = "12:34",
	event = "CHAT_MSG_CHANNEL",
	channel = "Trade",
	view = "general",
	text = "ASCII words |cff88aaffцветноеслово|r, " .. url
		.. " another deliberately long ASCII tail with punctuation.",
}
local rendered = dock:FormatDisplayRecord(record)
local maximum = dock:MeasureMaximumDisplayLineWidth(rendered)
assert(maximum and maximum <= display.width - 1,
	"pixel validation left a manual segment wide enough for native second wrapping")

local lines = {}
for line in string.gmatch(rendered .. "\n", "(.-)\n") do
	lines[#lines + 1] = visibleMarkup(line)
end
assert(#lines > 2, "mixed ASCII/Cyrillic/URL fixture did not wrap")
for index = 2, #lines do
	assert(string.match(lines[index], "^  +%S"),
		"a manually wrapped continuation began unindented")
	local content = string.gsub(lines[index], "^%s+", "")
	assert(not string.match(content, "^[,%.;:!%?%)%]%}%%]"),
		"closing punctuation was orphaned at the beginning of a continuation")
end

-- Rejoining only the wrapper's indentation must recover the original unbroken
-- URL bytes, including UTF-8 and its trailing comma.
local rejoined = visibleMarkup(string.gsub(rendered, "\n +", ""))
assert(string.find(rejoined, url, 1, true),
	"safe wrapping split, rewrote, or dropped bytes from the UTF-8 URL token")

print("SmartDock wrap safety mock passed")
