-- Focused no-client harness for Smart Dock's Shift-hover record resolution and
-- the narrow BlockControl hand-off. Run from the addon root with:
-- lua Tests/SmartDockBlockAction.mock.lua

local cursorX, cursorY = 20, 25
local blockCalls = {}
local displayHeight, displayBottom = 100, 0
local alignmentSettingsOpenCount = 0
local alignmentMutationCount = 0
local tooltipLines = {}
local shiftDown = true

UIParent = {
	GetEffectiveScale = function()
		return 1
	end,
}

GameTooltip = {
	SetOwner = function(self, owner) self.owner = owner end,
	AddLine = function(_, text) table.insert(tooltipLines, tostring(text or "")) end,
	Show = function(self) self.shown = true end,
	Hide = function(self) self.shown = false end,
	GetOwner = function(self) return self.owner end,
}

GetCursorPosition = function()
	return cursorX, cursorY
end

IsShiftKeyDown = function()
	return shiftDown
end

ChattyChattyBangBang = {
	Theme = {},
	Presentation = {},
	Config = {
		OpenGlobalTextAlignment = function()
			alignmentSettingsOpenCount = alignmentSettingsOpenCount + 1
		end,
	},
	BlockControl = {
		IsAvailable = function()
			return true
		end,
	},
	MessageEngine = {
		GetMessageById = function(_, id)
			return { id = tonumber(id), text = "linked" }
		end,
	},
	AnalyzeRecord = function()
		return { signals = {}, reasons = {} }
	end,
}

function ChattyChattyBangBang:SetViewSourceColumnAlignment()
	alignmentMutationCount = alignmentMutationCount + 1
end

function ChattyChattyBangBang:SetViewSenderColumnAlignment()
	alignmentMutationCount = alignmentMutationCount + 1
end

function ChattyChattyBangBang.Theme:CreateTightButton(parent, label, height)
	local button = {
		parent = parent,
		label = tostring(label or ""),
		height = height or 18,
		scripts = {},
		hooks = {},
	}
	button.text = {
		GetStringWidth = function()
			return #button.label * 6
		end,
		SetText = function(_, value)
			button.label = tostring(value or "")
		end,
	}
	function button:SetFrameLevel(level) self.frameLevel = level end
	function button:SetPoint(...) self.point = { ... } end
	function button:SetScript(name, callback) self.scripts[name] = callback end
	function button:HookScript(name, callback) self.hooks[name] = callback end
	function button:SetLabel(value) self.label = tostring(value or "") end
	function button:SetWidth(width) self.width = width end
	function button:GetWidth() return self.width or 0 end
	function button:Show() self.shown, self.hidden = true, false end
	function button:Hide() self.shown, self.hidden = false, true end
	function button:IsMouseOver() return false end
	return button
end

function ChattyChattyBangBang:BlockRecord(record, mode)
	table.insert(blockCalls, { record = record, mode = mode })
	return true, { id = #blockCalls }
end

dofile("Core/SmartDock.lua")

local dock = ChattyChattyBangBang.SmartDock
local display = {
	GetLeft = function() return 0 end,
	GetRight = function() return 300 end,
	GetTop = function() return 100 end,
	GetBottom = function() return displayBottom end,
	GetHeight = function() return displayHeight end,
	GetWidth = function() return 300 end,
	GetFont = function() return "Fonts\\FRIZQT__.TTF", 10 end,
	GetSpacing = function() return 0 end,
	GetNumLinesDisplayed = function(self) return self.visibleLines end,
	GetCurrentScroll = function(self) return self.scroll end,
}

dock.display = display
dock.displayMeasurementWidth = 300 -- Entries below already have known line counts.
dock.displayRecords = {
	{ record = { id = 1, text = "Spell is not ready yet.", event = "UI_ERROR_MESSAGE" }, lines = 1 },
	{ record = { id = 2, text = "Ability is not ready yet.", event = "UI_ERROR_MESSAGE" }, lines = 1 },
	{ record = { id = 3, text = "ordinary player message", event = "CHAT_MSG_CHANNEL", sender = "Tester" }, lines = 1 },
}

-- Three records in a ten-line frame are bottom aligned. Blank top space must
-- not accidentally target the newest record.
display.visibleLines = 3
display.scroll = 0
cursorY = 95
assert(dock:GetDisplayRecordAtCursor() == nil, "blank history area selected a record")
cursorY = 25
assert(dock:GetDisplayRecordAtCursor().id == 1, "first visible line did not resolve the local error")
cursorY = 15
assert(dock:GetDisplayRecordAtCursor().id == 2, "second visible line did not resolve")
cursorY = 5
assert(dock:GetDisplayRecordAtCursor().id == 3, "third visible line did not resolve ordinary chat")

-- A scrolled frame uses ScrollingMessageFrame's documented line offset from
-- the end. Verify it maps into the historic cache rather than only recent data.
dock.displayRecords = {}
for index = 1, 10 do
	table.insert(dock.displayRecords, { record = { id = index, text = "record " .. index }, lines = 1 })
end
display.visibleLines = 3
display.scroll = 2
displayHeight, displayBottom = 30, 70
cursorY = 95
assert(dock:GetDisplayRecordAtCursor().id == 6, "scrolled top line resolved the wrong record")
cursorY = 75
assert(dock:GetDisplayRecordAtCursor().id == 8, "scrolled bottom line resolved the wrong record")

-- Hyperlinked player names retain the exact MessageEngine record id and win
-- over geometry when the mouse is over the sender link.
dock.hoveredHyperlink = "ccbbplayer:42"
assert(dock:GetShiftHoveredRecord().id == 42, "player hyperlink did not resolve its exact record")
dock.hoveredHyperlink = nil

-- The action stays out of normal chat until Shift is held over a real line,
-- then anchors to that line's right edge instead of adding markup to text.
displayHeight, displayBottom = 100, 0
display.visibleLines, display.scroll = 3, 0
dock.displayRecords = {
	{ record = { id = 1, text = "Spell is not ready yet.", event = "UI_ERROR_MESSAGE" }, lines = 1 },
	{ record = { id = 2, text = "Ability is not ready yet.", event = "UI_ERROR_MESSAGE" }, lines = 1 },
	{ record = { id = 3, text = "ordinary player message", event = "CHAT_MSG_CHANNEL", sender = "Tester" }, lines = 1 },
}
cursorY = 25
local action = {
	GetHeight = function() return 18 end,
	GetWidth = function() return 38 end,
	ClearAllPoints = function(self) self.cleared = true end,
	SetPoint = function(self, ...) self.point = { ... } end,
	Show = function(self) self.shown = true end,
	Hide = function(self) self.shown, self.hidden = false, true end,
	IsMouseOver = function(self) return self.hovered == true end,
}
local analysisAction = {
	GetHeight = action.GetHeight,
	GetWidth = action.GetWidth,
	ClearAllPoints = action.ClearAllPoints,
	SetPoint = action.SetPoint,
	Show = action.Show,
	Hide = action.Hide,
	IsMouseOver = action.IsMouseOver,
}
local choices = {
	Hide = function(self) self.hidden = true end,
	IsMouseOver = function() return false end,
	IsShown = function() return false end,
}
-- The alignment affordance must treat the actual ScrollingMessageFrame as chat
-- surface, but it is now one named route to persistent settings rather than two
-- anonymous state-mutating boxes.
local contentWidth = 408
local content = {
	GetWidth = function() return contentWidth end,
	GetFrameLevel = function() return 1 end,
	IsMouseOver = function() return false end,
}
display.IsMouseOver = function() return true end
dock.active = true
dock.IsCollapsed = function() return false end
dock.blockAction = action
dock.analysisAction = analysisAction
dock.blockChoices = choices
dock.content = content
dock:BuildSourceColumnAlignmentControl()
dock.ScheduleMessageBlockActionRefresh = function() end
dock:UpdateMessageBlockAction()
assert(action.shown and analysisAction.shown and dock.blockActionRecord.id == 1,
	"Shift-hover did not expose both actions for the local-error record")
assert(action.point and action.point[1] == "TOPRIGHT" and action.point[2] == display,
	"action did not anchor to the visible message frame")
local alignmentButton = dock.columnAlignmentSettingsButton
assert(alignmentButton and alignmentButton.shown and alignmentButton.label == "ALIGN SETTINGS",
	"Shift over the actual message display did not expose the named alignment-settings shortcut")
assert(alignmentButton.width >= (#alignmentButton.label * 6) + 8,
	"alignment shortcut did not preserve four pixels of internal text gutter per side")
assert(alignmentButton.point and alignmentButton.point[1] == "TOPRIGHT"
	and alignmentButton.point[2] == content and alignmentButton.point[4] == -4
	and alignmentButton.point[5] == -4,
	"alignment shortcut lost its explicit four-pixel outer gutters")
tooltipLines = {}
alignmentButton.hooks.OnEnter(alignmentButton)
local tooltipText = table.concat(tooltipLines, "\n")
assert(string.find(tooltipText, "ALIGN CHANNELS", 1, true)
	and string.find(tooltipText, "ALIGN NAMES", 1, true)
	and string.find(tooltipText, "META", 1, true),
	"alignment shortcut tooltip omitted the persistent controls or live diagnostics")
alignmentButton.scripts.OnClick(alignmentButton)
assert(alignmentSettingsOpenCount == 1 and alignmentMutationCount == 0,
	"alignment shortcut changed live alignment state instead of opening Global Text")

contentWidth = 300
dock:UpdateSourceColumnAlignmentControl()
assert(alignmentButton.label == "ALIGN" and alignmentButton.width >= (#alignmentButton.label * 6) + 8,
	"minimum-width chat did not use the bounded ALIGN label with safe text padding")

-- Shift actions identify one logical chat entry, not merely the wrapped row
-- beneath the cursor. The highlight must cover all visible content rows while
-- excluding the entry-gap spacer that belongs before the message.
local highlight = {
	points = {},
	ClearAllPoints = function(self) self.points = {} end,
	SetPoint = function(self, ...) table.insert(self.points, { ... }) end,
	SetVertexColor = function(self, ...) self.color = { ... } end,
	Show = function(self) self.shown, self.hidden = true, false end,
	Hide = function(self) self.shown, self.hidden = false, true end,
}
dock.messageActionHighlight = highlight
displayHeight, displayBottom = 50, 50
display.visibleLines, display.scroll = 5, 0
local wrappedRecord = { id = 12, text = "one logical entry wrapped onto three rows" }
dock.displayRecords = {
	{ record = { id = 11, text = "older" }, lines = 1, gapRows = 0 },
	{ record = wrappedRecord, lines = 4, gapRows = 1, contentLines = 3 },
	{ record = { id = 13, text = "newer" }, lines = 1, gapRows = 0 },
}
cursorY = 75
action.hovered, analysisAction.hovered = false, false
dock:UpdateMessageBlockAction()
assert(action.shown and analysisAction.shown and dock.blockActionRecord == wrappedRecord,
	"wrapped Shift-hover did not retain the exact logical action record")
assert(highlight.shown and #highlight.points == 2,
	"visible Shift actions did not expose one logical-entry highlight")
assert(highlight.points[1][1] == "TOPLEFT" and highlight.points[1][2] == display
	and highlight.points[2][1] == "BOTTOMRIGHT" and highlight.points[2][2] == display,
	"logical-entry highlight was not bounded by the readable chat viewport")
assert(highlight.points[1][5] == -10 and highlight.points[2][5] == -40,
	"wrapped highlight included the entry-gap row or failed to cover all three content rows")

-- When the viewport clips the first wrapped row, the same logical selection is
-- clipped to the two rows that are actually visible instead of bleeding above
-- the frame or moving onto the neighboring entry.
displayHeight, displayBottom = 30, 70
cursorY = 95
dock:UpdateMessageBlockAction()
assert(dock.blockActionRecord == wrappedRecord and highlight.shown,
	"partially clipped wrapped entry lost its Shift selection")
assert(highlight.points[1][5] == 0 and highlight.points[2][5] == -20,
	"logical-entry highlight did not clip to the wrapped rows visible in the viewport")

-- Leaving the message for either action retains the visual association. Once
-- neither the chat nor its actions own the interaction, central cleanup must
-- remove both the controls and their highlight.
shiftDown = false
display.IsMouseOver = function() return false end
action.hovered = true
dock:UpdateMessageBlockAction()
assert(action.shown and highlight.shown,
	"moving from the selected message onto its action discarded the line highlight")
action.hovered = false
dock:UpdateMessageBlockAction()
assert(not action.shown and not analysisAction.shown and not highlight.shown,
	"hidden Shift actions left a stale logical-entry highlight")

shiftDown = true
display.IsMouseOver = function() return true end
displayHeight, displayBottom = 50, 50
cursorY = 75
dock:UpdateMessageBlockAction()
assert(highlight.shown, "Shift actions could not restore their logical-entry highlight")
dock:HideMessageBlockControls()
assert(not highlight.shown, "central action cleanup did not hide the logical-entry highlight")

dock.RebuildActiveView = function(self)
	self.rebuilt = (self.rebuilt or 0) + 1
end
local localError = { id = 99, text = "Spell is not ready yet.", event = "UI_ERROR_MESSAGE" }
assert(dock:CanUseMessageBlocks(), "available BlockControl was not recognized")
assert(dock:ApplyMessageBlock(localError, "exact") == true, "local UI error could not create an exact block")
assert(#blockCalls == 1 and blockCalls[1].record == localError and blockCalls[1].mode == "exact",
	"block hand-off lost record or mode")
assert(dock.rebuilt == 1, "successful block did not refresh the active dock")

print("SmartDock block-action mock tests passed")
