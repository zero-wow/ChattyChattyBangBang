-- Focused no-client contract for SmartDock's transient alert/player surfaces.
-- Run from the addon root with: lua Tests/SmartDockTransientPanels.mock.lua

ChattyChattyBangBang = {
	Theme = {},
	Presentation = {},
	GetSmartSettings = function()
		return { dock = { showScrollButtons = true } }
	end,
}

dofile("Core/SmartDock.lua")

local addon = ChattyChattyBangBang
local dock = addon.SmartDock

local function frame(width, height)
	local value = {
		width = width or 360,
		height = height or 106,
		shown = false,
		points = {},
	}
	function value:ClearAllPoints() self.points = {} end
	function value:SetPoint(...)
		table.insert(self.points, { ... })
	end
	function value:GetWidth() return self.width end
	function value:GetHeight() return self.height end
	function value:SetWidth(nextWidth) self.width = nextWidth end
	function value:SetHeight(nextHeight) self.height = nextHeight end
	function value:IsShown() return self.shown end
	function value:IsMouseOver() return self.over == true end
	function value:Show() self.shown = true end
	function value:Hide() self.shown = false end
	function value:SetText(text) self.text = text end
	return value
end

local function pointFor(subject, pointName)
	for _, point in ipairs(subject.points or {}) do
		if point[1] == pointName then return point end
	end
	return nil
end

local function offset(subject, pointName)
	local point = assert(pointFor(subject, pointName), "missing " .. pointName .. " layout anchor")
	return tonumber(point[5]) or 0, point
end

dock.frame = frame(360, 160)
dock.content = frame(360, 106)
dock.display = frame()
function dock.display:AtBottom() return (self.scrollOffset or 0) == 0 end
function dock.display:GetCurrentScroll() return self.scrollOffset or 0 end
function dock.display:SetScrollOffset(value) self.scrollOffset = value end
function dock.display:ScrollToBottom() self.scrollOffset = 0 end
dock.messageScrollbar = frame(8, 62)
dock.scrollToBottomButton = frame(10, 16)
dock.emptyState = frame()
dock.alertBar = frame(356, 34)
dock.playerActions = frame(356, 46)
dock.alertActive = false

assert(type(dock.RefreshTransientMessageLayout) == "function",
	"SmartDock did not expose one coordinated transient-message layout pass")

local exactPlayerRecord = { id = 42, sender = "Linked" }
local exactAnalysisRecord = { id = 43, text = "analyze me" }
dock.actionRecord = exactPlayerRecord
dock.analysisRecord = exactAnalysisRecord
dock.hoveredHyperlink = "ccbbplayer:42"

local function assertInteractionState(label)
	assert(dock.actionRecord == exactPlayerRecord,
		label .. " discarded the exact player hyperlink record")
	assert(dock.analysisRecord == exactAnalysisRecord,
		label .. " discarded the active Shift analysis record")
	assert(dock.hoveredHyperlink == "ccbbplayer:42",
		label .. " disturbed native hyperlink hover state")
end

local function refresh(label)
	assert(dock:RefreshTransientMessageLayout(), label .. " layout refresh failed")
	assertInteractionState(label)
end

-- Baseline: the chat viewport owns its ordinary four-pixel inset, the slim
-- scrollbar retains its V-button lane, and the empty label follows the actual
-- message viewport rather than the unreserved content panel.
refresh("baseline")
assert(offset(dock.display, "TOPLEFT") == -4 and offset(dock.display, "BOTTOMRIGHT") == 4,
	"baseline message viewport insets changed")
assert(offset(dock.messageScrollbar, "TOPRIGHT") == -4
	and offset(dock.messageScrollbar, "BOTTOMRIGHT") == 24,
	"baseline slim-scrollbar lane changed")
assert(offset(dock.scrollToBottomButton, "BOTTOMRIGHT") == 4,
	"baseline jump-to-bottom inset changed")
local _, emptyCenter = offset(dock.emptyState, "CENTER")
assert(emptyCenter[2] == dock.display and (emptyCenter[3] == nil or emptyCenter[3] == "CENTER"),
	"empty-state label is not centered in the readable message viewport")

-- A timed notice is painted two pixels inside content. Its 34px surface plus
-- two-pixel separation is added ahead of the display's own four-pixel inset,
-- leaving a real four-pixel visual gutter instead of painting over chat text.
dock.alertActive = true
dock.alertBar.shown = true
refresh("alert")
assert(offset(dock.display, "TOPLEFT") == -40,
	"shown alert did not reserve its 34px row, separation, and message gutter")
assert(offset(dock.messageScrollbar, "TOPRIGHT") == -40,
	"slim scrollbar still runs underneath the shown alert")
assert(offset(dock.display, "BOTTOMRIGHT") == 4
	and offset(dock.scrollToBottomButton, "BOTTOMRIGHT") == 4,
	"top alert incorrectly displaced bottom message controls")
local alertBottom = 2 + dock.alertBar:GetHeight()
local displayTop = math.abs(offset(dock.display, "TOPLEFT"))
assert(displayTop - alertBottom == 4,
	"alert and message text do not retain their explicit four-pixel gutter")

-- A resize drag must update the safety geometry even when only the alert is
-- visible, without rebuilding visible-only alignment on every size tick.
local resizeViewportRefreshes = 0
local originalResizeViewportChanged = dock.HandleDisplayViewportChanged
dock.HandleDisplayViewportChanged = function()
	resizeViewportRefreshes = resizeViewportRefreshes + 1
end
dock.display:Show()
dock.messageScrollbar:Show()
dock.scrollToBottomButton:Show()
dock.content.height = 78
assert(dock:RefreshTransientMessageLayout(true),
	"alert resize could not refresh the transient message geometry")
assert(dock.display:IsShown(),
	"alert resize hid a still-usable message line")
assert(not dock.messageScrollbar:IsShown() and not dock.scrollToBottomButton:IsShown(),
	"alert resize left undersized scroll controls crossing the minimum content lane")
assert(resizeViewportRefreshes == 0,
	"alert resize rebuilt visible message scope during an active size drag")
dock.content.height = 106
dock.HandleDisplayViewportChanged = originalResizeViewportChanged

-- Closing or timing out the notice converges on DismissAlert. Exercise that
-- real path so it cannot hide the art while leaving a permanent blank row.
dock.alertRecord = { id = 44 }
dock:DismissAlert(true)
assert(offset(dock.display, "TOPLEFT") == -4
	and offset(dock.messageScrollbar, "TOPRIGHT") == -4,
	"alert dismissal did not restore the full readable viewport")
assert(dock.analysisRecord == exactAnalysisRecord and dock.hoveredHyperlink == "ccbbplayer:42",
	"alert dismissal damaged Shift analysis or hyperlink state")

-- The player menu uses its live height: 46px in one row, 66px at narrow width.
-- The display, V button, and slim scrollbar all move together, so neither a
-- clickable name menu nor a message control covers text at the minimum dock.
dock.playerActionName = frame()
dock.playerActionButtons = {}
dock.playerActions:SetHeight(46)
assert(dock:ShowPlayerActions(exactPlayerRecord) ~= false,
	"clicking a player name could not show its action surface")
assertInteractionState("wide player actions")
assert(offset(dock.display, "BOTTOMRIGHT") == 52,
	"wide player actions did not reserve their live row and message gutter")
assert(offset(dock.scrollToBottomButton, "BOTTOMRIGHT") == 52
	and offset(dock.messageScrollbar, "BOTTOMRIGHT") == 72,
	"bottom message controls still overlap the wide player-action row")

dock.playerActions:SetHeight(66)
refresh("compact player actions")
assert(offset(dock.display, "BOTTOMRIGHT") == 72,
	"compact player actions did not reserve both rows and message gutter")
assert(offset(dock.scrollToBottomButton, "BOTTOMRIGHT") == 72
	and offset(dock.messageScrollbar, "BOTTOMRIGHT") == 92,
	"bottom message controls still overlap compact player actions")
local panelTop = dock.content:GetHeight() - (2 + dock.playerActions:GetHeight())
local displayBottom = dock.content:GetHeight() - offset(dock.display, "BOTTOMRIGHT")
assert(panelTop - displayBottom == 4 and displayBottom > 0,
	"360x160 minimum dock leaves no safe message lane above compact player actions")

-- Click-out, timeout, one-shot action, tab switch, and dock hide all converge on
-- HidePlayerActions; exercise that shared path and require the exact lane back.
dock.actionRecord = exactPlayerRecord
dock:HidePlayerActions()
assert(offset(dock.display, "BOTTOMRIGHT") == 4
	and offset(dock.scrollToBottomButton, "BOTTOMRIGHT") == 4
	and offset(dock.messageScrollbar, "BOTTOMRIGHT") == 24,
	"player-action dismissal did not restore bottom message bounds")
assert(dock.actionRecord == nil and dock.analysisRecord == exactAnalysisRecord,
	"closing player actions did not clear only its own linked record")

-- Exercise both automatic closing triggers instead of assuming that all callers
-- remembered to reflow after hiding the panel.
local mouseDown = false
IsMouseButtonDown = function(button)
	return button == "LeftButton" and mouseDown
end
addon.GetPlayerActionMenuSettings = function()
	return { autoHide = true, autoHideSeconds = 1 }
end

dock.playerActions.over = false
dock.playerActions:Show()
dock.playerActions:SetHeight(66)
dock.actionRecord = exactPlayerRecord
refresh("player-action timeout setup")
assert(dock:RefreshPlayerActionDismissal(), "could not arm player-action timeout")
assert(not dock:UpdatePlayerActionDismissal(1), "player-action timeout did not close the menu")
assert(offset(dock.display, "BOTTOMRIGHT") == 4,
	"player-action timeout left chat permanently inset")

dock.playerActions:Show()
dock.actionRecord = exactPlayerRecord
mouseDown = false
refresh("player-action click-out setup")
assert(dock:RefreshPlayerActionDismissal(), "could not arm player-action click-out")
mouseDown = true
assert(not dock:UpdatePlayerActionDismissal(0), "outside click did not close player actions")
assert(offset(dock.display, "BOTTOMRIGHT") == 4,
	"outside click left chat permanently inset")
mouseDown = false

-- Header + horizontal tabs + reserved composer can leave only ~78px of content
-- at the supported 360x160 minimum. A compact two-row player menu cannot share
-- that safely with a usable message/scroll lane, so the lane disappears only
-- for the menu's lifetime and returns exactly afterward.
dock.content.height = 78
dock.display:Show()
dock.emptyState:Show()
dock.messageScrollbar:Show()
dock.scrollToBottomButton:Show()
dock.playerActions:Show()
dock.playerActions:SetHeight(66)
dock.actionRecord = exactPlayerRecord
refresh("minimum-height compact player actions")
assert(not dock.display:IsShown() and not dock.emptyState:IsShown(),
	"minimum-height compact player menu left a clipped message row visible")
assert(not dock.messageScrollbar:IsShown() and not dock.scrollToBottomButton:IsShown(),
	"minimum-height compact player menu left inverted scroll controls visible")
dock:HidePlayerActions()
assert(dock.display:IsShown() and dock.emptyState:IsShown(),
	"closing the compact player menu did not restore the hidden message lane")
assert(offset(dock.display, "BOTTOMRIGHT") == 4,
	"minimum-height player-menu close did not release its reservation")

-- A message arriving while the tiny lane is suppressed must replace the stale
-- empty-state snapshot when the menu closes.
local originalUpdateEmptyState = dock.UpdateEmptyState
local originalViewportChanged = dock.HandleDisplayViewportChanged
dock.built = true
dock.activeView = "general"
dock.displayRecords = {}
dock.HandleDisplayViewportChanged = function() return false end
dock.UpdateEmptyState = function(self, count)
	self.restoredEmptyCount = count
	if count > 0 then self.emptyState:Hide() else self.emptyState:Show() end
end
dock.emptyState:Show()
dock.playerActions:Show()
dock.playerActions:SetHeight(66)
dock.actionRecord = exactPlayerRecord
refresh("minimum-height message arrival setup")
dock.displayRecords = { { record = { id = 45 } } }
dock:UpdateEmptyState(1)
dock:HidePlayerActions()
assert(dock.restoredEmptyCount == 1 and not dock.emptyState:IsShown(),
	"closing a tiny player menu resurrected stale empty text over a new message")

-- A reader who was already scrolled up can receive messages while the display
-- is suppressed. Wrath advances the live offset to keep the same text in view;
-- reopening must retain that new offset instead of restoring a stale snapshot.
dock.display.scrollOffset = 5
dock.playerActions:Show()
dock.playerActions:SetHeight(66)
dock.actionRecord = exactPlayerRecord
refresh("minimum-height scrolled-reader setup")
dock.display.scrollOffset = 7
dock:HidePlayerActions()
assert(dock.display.scrollOffset == 7,
	"closing a tiny player menu jumped a scrolled reader toward newer messages")
dock.display.scrollOffset = 0
dock.UpdateEmptyState = originalUpdateEmptyState
dock.HandleDisplayViewportChanged = originalViewportChanged
dock.built = nil
dock.activeView = nil
dock.displayRecords = nil
dock.content.height = 106

-- If the menu replaces an alert that temporarily revealed a hidden/collapsed
-- dock, closing the menu inherits and completes that exact restoration.
local originalApplyLayout = dock.ApplyLayout
dock.ApplyLayout = function(self)
	self:RefreshTransientMessageLayout()
	return true
end
dock.SyncDockHoverState = function() end
dock.active = true
dock.visibleState = true
dock.collapsedState = false
dock.stateRevision = 0
dock.frame:Show()
dock.alertActive = true
dock.alertBar:Show()
dock.alertPending = { wasVisible = false, wasCollapsed = true, revision = 0 }
dock:ShowPlayerActions(exactPlayerRecord)
assert(dock.playerActionAlertRestore ~= nil and dock.alertPending == nil,
	"player menu discarded the alert's saved dock state")
dock:HidePlayerActions()
assert(dock.visibleState == false and dock.collapsedState == true and not dock.frame:IsShown(),
	"player-menu dismissal failed to restore the alert-revealed dock")
assert(dock.playerActionAlertRestore == nil and dock.alertPending == nil,
	"player-menu alert restoration left stale transient state")
dock.ApplyLayout = originalApplyLayout
dock.active = nil
dock.visibleState = nil
dock.collapsedState = nil

-- The analysis drawer remains a deliberate overlay, but it must contract inside
-- the outer 360x160 frame instead of crossing a narrow content lane or border.
dock.content.width = 300
dock.analysisPanel = frame(356, 154)
assert(dock:RefreshMessageAnalysisLayout(), "analysis layout refresh failed")
assert(dock.analysisPanel:GetWidth() == 352 and dock.analysisPanel:GetHeight() == 152,
	"analysis drawer crossed the minimum outer-frame gutters")
local analysisPoint = assert(pointFor(dock.analysisPanel, "TOPRIGHT"),
	"analysis drawer lost its outer-frame anchor")
assert(analysisPoint[2] == dock.frame,
	"analysis drawer still clips itself to the shorter message-content lane")
assert(analysisPoint[4] == -4 and analysisPoint[5] == -4,
	"analysis drawer lost its right/top border gutters")
assert(28 + 292 <= dock.analysisPanel:GetWidth() - 4,
	"analysis route dropdown can cross the narrowed drawer border")

print("SmartDock transient-panel layout mock passed")
