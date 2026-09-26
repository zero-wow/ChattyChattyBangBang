-- Focused no-client contract for the responsive settings workspace. The page
-- canvas remains readable at 652px, while compact screens use a page scroller
-- and temporary navigation drawer rather than shrinking the whole console.

local Frame = {}
Frame.__index = Frame

local function frame(parent)
	return setmetatable({ parent = parent, shown = true, enabled = true, scripts = {}, events = {} }, Frame)
end

function Frame:SetPoint(...)
	self.point = { ... }
	self.points = self.points or {}
	self.points[#self.points + 1] = self.point
end
function Frame:ClearAllPoints() self.point, self.points = nil, nil end
function Frame:SetAllPoints(target) self.allPoints = target or true end
function Frame:SetSize(width, height)
	assert(type(width) == "number" and type(height) == "number",
		"SetSize requires numeric width and height")
	self.width, self.height = width, height
end
function Frame:SetWidth(width) self.width = width end
function Frame:SetHeight(height) self.height = height end
function Frame:GetWidth() return self.width or 0 end
function Frame:GetHeight() return self.height or 0 end
function Frame:SetScale(value) self.scale = value end
function Frame:GetScale() return self.scale or 1 end
function Frame:GetEffectiveScale()
	local parentScale = self.parent and self.parent.GetEffectiveScale and self.parent:GetEffectiveScale() or 1
	return parentScale * (self.scale or 1)
end
function Frame:SetClampedToScreen(value) self.clampedToScreen = value and true or false end
function Frame:SetFrameStrata() end
function Frame:SetToplevel() end
function Frame:SetMovable() end
function Frame:RegisterForDrag() end
function Frame:EnableMouse() end
function Frame:EnableMouseWheel(value) self.mouseWheelEnabled = value and true or false end
function Frame:SetScrollChild(child) self.scrollChild = child end
function Frame:SetVerticalScroll(value) self.verticalScroll = value end
function Frame:GetVerticalScroll() return self.verticalScroll or 0 end
function Frame:GetVerticalScrollRange() return self.verticalScrollRange or 0 end
function Frame:SetJustifyH() end
function Frame:SetTextColor() end
function Frame:SetTexture() end
function Frame:SetVertexColor() end
function Frame:SetAlpha() end
function Frame:SetAutoFocus() end
function Frame:SetMultiLine() end
function Frame:SetFontObject() end
function Frame:SetTextInsets() end
function Frame:SetMaxLetters() end
function Frame:ClearFocus() end
function Frame:SetFocus() end
function Frame:EnableKeyboard(enabled) self.keyboardEnabled = enabled and true or false end
function Frame:SetPropagateKeyboardInput(enabled) self.propagateKeyboardInput = enabled and true or false end
function Frame:IsVisible()
	if not self:IsShown() then return false end
	return not self.parent or not self.parent.IsVisible or self.parent:IsVisible()
end
function Frame:IsEnabled() return self.enabled ~= false end
function Frame:Raise() self.raised = true end
function Frame:StartMoving() self.moving = true end
function Frame:StopMovingOrSizing() self.moving = false end
function Frame:SetText(value) self.textValue = tostring(value or "") end
function Frame:GetText() return self.textValue or "" end
local textUnit = 6
function Frame:GetStringWidth() return #self:GetText() * textUnit end
function Frame:IsShown() return self.shown ~= false end
function Frame:Enable() self.enabled = true end
function Frame:Disable() self.enabled = false end

function Frame:SetScript(name, callback)
	self.scripts[name] = callback
end
function Frame:GetScript(name) return self.scripts[name] end
function Frame:Click(button)
	if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end
end
function Frame:HookScript(name, callback)
	local previous = self.scripts[name]
	if previous then
		self.scripts[name] = function(...)
			previous(...)
			callback(...)
		end
	else
		self.scripts[name] = callback
	end
end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:Show()
	self.shown = true
	if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Frame:Hide()
	self.shown = false
	if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Frame:CreateTexture() return frame(self) end
function Frame:CreateFontString() return frame(self) end

local function anchorPixels(relative, point)
	local scale = relative:GetEffectiveScale()
	local width = relative:GetWidth() * scale
	local height = relative:GetHeight() * scale
	local x = string.find(point or "CENTER", "LEFT", 1, true) and 0
		or (string.find(point or "CENTER", "RIGHT", 1, true) and width or (width / 2))
	local y = string.find(point or "CENTER", "BOTTOM", 1, true) and 0
		or (string.find(point or "CENTER", "TOP", 1, true) and height or (height / 2))
	return x, y
end

function Frame:GetCenter()
	if self == UIParent then
		return self:GetWidth() / 2, self:GetHeight() / 2
	end
	local point = self.point or { "CENTER", self.parent or UIParent, "CENTER", 0, 0 }
	local relative = point[2] or self.parent or UIParent
	local relativePoint = point[3] or point[1] or "CENTER"
	local baseX, baseY = anchorPixels(relative, relativePoint)
	local ownScale = self:GetEffectiveScale()
	local centerPixelsX = baseX + ((tonumber(point[4]) or 0) * ownScale)
	local centerPixelsY = baseY + ((tonumber(point[5]) or 0) * ownScale)
	return centerPixelsX / ownScale, centerPixelsY / ownScale
end
function Frame:GetLeft()
	local center = self:GetCenter()
	return center - (self:GetWidth() / 2)
end
function Frame:GetRight()
	local center = self:GetCenter()
	return center + (self:GetWidth() / 2)
end
function Frame:GetBottom()
	local _, center = self:GetCenter()
	return center - (self:GetHeight() / 2)
end
function Frame:GetTop()
	local _, center = self:GetCenter()
	return center + (self:GetHeight() / 2)
end

function CreateFrame(_, _, parent) return frame(parent) end

UIParent = frame()
UIParent:SetSize(800, 540)
GameFontNormalLarge = {}
GameFontNormal = {}
GameFontNormalSmall = {}
GameFontHighlightSmall = {}

local Theme = {
	texts = {}, frames = {}, textures = {}, NO_BORDER = "none",
	ICON_PATH = "Interface\\Icons\\INV_Misc_QuestionMark",
}
function Theme:GetColor() return 1, 1, 1, 1 end
function Theme:GetPalette()
	return {
		background = { 0, 0, 0, 1 }, surface = { 0, 0, 0, 1 },
		surfaceRaised = { 0, 0, 0, 1 }, accentSoft = { 0, 0, 0, 1 },
		gold = { 1, 0.8, 0.2, 1 }, accent = { 0.5, 0.5, 1, 1 },
	}
end
function Theme:CreatePanel(parent) return frame(parent) end
function Theme:CreateQuietPanel(parent) return frame(parent) end
function Theme:CreateText(parent) return frame(parent) end
function Theme:CreateButton(parent, text, width, height)
	local button = frame(parent)
	button:SetSize(width or 20, height or 20)
	button.text = frame(button)
	button.text:SetText(text)
	function button:SetLabel(value) self.text:SetText(value) end
	function button:SetTheme() end
	function button:SetHoverTheme() end
	function button:SetTooltip(title, body) self.tooltipTitle, self.tooltipBody = title, body end
	return button
end
function Theme:CreateTightButton(parent, text, height)
	return self:CreateButton(parent, text, math.max(height or 20, (#tostring(text) * 6) + 6), height or 20)
end
function Theme:RegisterTexture() end
function Theme:RegisterFrame() end
function Theme:ApplyFrame() end
function Theme:RegisterRefreshCallback(callback) self.refreshCallback = callback end
function Theme:SetTabFocus(button, focused) if button then button.keyboardFocusVisible = focused and true or false end end

ChattyChattyBangBang = { Theme = Theme }
local addon = ChattyChattyBangBang

dofile("Core/Config.lua")
local config = addon.CustomConfig
config:BuildFrame()
config.ShowPage = function(self, page) self.activePage = page end

local function nearlyEqual(left, right)
	return math.abs((left or 0) - (right or 0)) < 0.0001
end

local function boundsPixels(widget)
	local scale = widget:GetEffectiveScale()
	return widget:GetLeft() * scale, widget:GetRight() * scale,
		widget:GetBottom() * scale, widget:GetTop() * scale
end

local function assertViewportGutters(widget, width, height, context)
	local left, right, bottom, top = boundsPixels(widget)
	assert(left >= 12 - 0.001 and right <= width - 12 + 0.001,
		context .. " lost its horizontal 12px screen gutters")
	assert(bottom >= 12 - 0.001 and top <= height - 12 + 0.001,
		context .. " lost its vertical 12px screen gutters")
end

-- At 800x540 the panel reflows to an unscaled 776x516 compact workspace.
config:Open()
assert(config.frame:GetWidth() == 776 and config.frame:GetHeight() == 516,
	"compact viewport did not reflow the workspace")
assert(config.headerTitle:GetText() == "ChattyChattyBangBang",
	"the full brand title disappeared despite room in the header")
assert(nearlyEqual(config.frame:GetScale(), 1),
	"compact viewport shrank all settings text and hit targets")
assert(config.frame.clampedToScreen,
	"settings frame did not retain the client's built-in screen clamp")
assertViewportGutters(config.frame, 800, 540, "small viewport")
local close = config.closeButton
assert(close and close:GetWidth() == 30 and close:GetHeight() == 30,
	"settings close button did not provide its enlarged logical hit target")
assert(close.point and close.point[1] == "RIGHT" and close.point[3] == "RIGHT"
	and close.point[4] == -8 and close.parent:GetHeight() == 44,
	"settings close target lost its header inset or vertical gutter")

local function hasAnchor(widget, point, relative, relativePoint, x, y)
	for _, anchor in ipairs(widget.points or {}) do
		if anchor[1] == point and anchor[2] == relative and anchor[3] == relativePoint
			and anchor[4] == x and anchor[5] == y then
			return true
		end
	end
	return false
end

-- The fixed page canvas has 8px control gutters and its centered compact
-- viewport retains ample side margins. The drawer stays closed until asked.
assert(config.sidebar:GetWidth() == 170
	and hasAnchor(config.sidebar, "TOPLEFT", config.frame, "TOPLEFT", 6, -56)
	and config.content:GetWidth() == 652
	and config.contentViewport:GetWidth() == 652
	and config.contentViewport.scrollChild == config.content
	and hasAnchor(config.contentViewport, "TOP", config.frame, "TOP", 0, -56)
	and not config.sidebar:IsShown() and config.navigationMenuButton:IsShown(),
	"settings workspace or page control lost its explicit divider/edge gutters")
assert(config.navContent:GetWidth() == 169
	and config.navigationButtons.desk:GetWidth() == 154
	and hasAnchor(config.navigationButtons.desk, "TOPLEFT", config.navContent, "TOPLEFT", 6, -42),
	"sidebar navigation row no longer leaves space before its divider")
assert(config.content:GetHeight() == 508 and config.frame:GetHeight() - 62 == 454
	and hasAnchor(config.contentViewport, "BOTTOM", config.frame, "BOTTOM", 0, 6),
	"compact settings lost the scrollable excess page height")
config.navigationMenuButton.scripts.OnClick()
assert(config.sidebar:IsShown(), "compact PAGES control did not reveal navigation")
config.navigationMenuButton.scripts.OnClick()
assert(not config.sidebar:IsShown(), "compact PAGES control did not close navigation")

-- The slim cue stays off when every page fits; once the hierarchy overflows,
-- its thumb follows scroll position and is separated from row and divider.
assert(not config.navScrollTrack:IsShown() and not config.navScrollThumb:IsShown(),
	"non-overflowing navigation showed a misleading scroll cue")
config.navScroll.verticalScrollRange = 120
config:UpdateSidebarScrollAffordance()
assert(config.navScrollTrack:IsShown() and config.navScrollThumb:IsShown()
	and config.navScrollThumb:GetWidth() == 3 and config.navScrollTrack:GetWidth() == 2,
	"overflowing navigation did not expose a slim scroll cue")
assert(config.navigationButtons.desk:GetWidth() + 6 <= config.sidebar:GetWidth() - 10
	and config.navScrollTrack.point[4] == -5,
	"navigation row, scroll cue, and sidebar divider lost their visible gutters")
local topThumbOffset = config.navScrollThumb.point[5]
config.navScroll:SetVerticalScroll(60)
config:UpdateSidebarScrollAffordance()
assert(config.navScrollThumb.point[5] < topThumbOffset,
	"sidebar scroll thumb did not follow its scroll position")
config.navScroll.verticalScrollRange = 0
config:UpdateSidebarScrollAffordance()
assert(not config.navScrollTrack:IsShown() and not config.navScrollThumb:IsShown(),
	"sidebar cue remained visible after content fit")
config.contentViewport.verticalScrollRange = 94
config.contentViewport.scripts.OnMouseWheel(config.contentViewport, -1)
assert(config.contentViewport:GetVerticalScroll() == 34,
	"compact page viewport did not scroll a tall settings page")

-- Both target-client viewport events are registered. A larger display restores
-- exact 1:1 scale without moving any edge beyond the safe screen area.
assert(config.frame.events.UI_SCALE_CHANGED and config.frame.events.DISPLAY_SIZE_CHANGED,
	"settings frame did not register both viewport-change events")
UIParent:SetSize(1600, 1000)
config.frame.scripts.OnEvent(config.frame, "DISPLAY_SIZE_CHANGED")
assert(config.frame:GetWidth() == 840 and config.frame:GetHeight() == 570
	and nearlyEqual(config.frame:GetScale(), 1),
	"large viewport did not restore the unscaled side-by-side workspace")
assert(config.sidebar:IsShown() and not config.navigationMenuButton:IsShown()
	and hasAnchor(config.contentViewport, "TOPLEFT", config.sidebar, "TOPRIGHT", 6, 0),
	"wide viewport did not restore the sidebar and workspace gutter")
assertViewportGutters(config.frame, 1600, 1000, "large viewport")

-- A wide-font theme is measured from actual text rather than forcing a
-- 170px rail that clips the longest label. Content keeps its own 652px canvas.
textUnit = 10
config:FitFrameToViewport()
assert(config.sidebar:GetWidth() == 234 and config.navContent:GetWidth() == 233
	and config.navigationButtons.desk:GetWidth() == 218
	and config.frame:GetWidth() == 904 and config.content:GetWidth() == 652,
	"wide navigation labels did not receive width without shrinking pages")
for _, button in pairs(config.navigationButtons) do
	assert(#button.label:GetText() * textUnit <= button:GetWidth() - 14,
		"wide-font navigation label clipped inside its row")
end
textUnit = 6
config:FitFrameToViewport()

-- A moved panel may be beyond two edges when scale/display settings change.
-- The UI-scale event must pull only the offending position back inside.
config.frame:ClearAllPoints()
config.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", -200, -200)
config.frame.scripts.OnEvent(config.frame, "UI_SCALE_CHANGED")
assertViewportGutters(config.frame, 1600, 1000, "off-screen clamp")

-- OnShow is an independent safeguard for clients that update UIParent before
-- dispatching their display event or while the settings frame is hidden.
UIParent:SetSize(700, 500)
config.frame:Hide()
config.frame:Show()
assert(config.frame:GetWidth() == 676 and config.frame:GetHeight() == 476
	and nearlyEqual(config.frame:GetScale(), 1),
	"OnShow did not reflow to the minimum unscaled 700x500 layout")
assert(config.headerTitle:GetText() == "ChattyChattyBangBang",
	"minimum-width header shortened its title although its controls fit")
assertViewportGutters(config.frame, 700, 500, "OnShow viewport")
assert(config.frame:GetHeight() - 62 == 414 and config.content:GetHeight() == 508,
	"minimum viewport did not keep its pages scrollable at normal text size")
assert(close:GetWidth() * close:GetEffectiveScale() >= 24
	and close:GetHeight() * close:GetEffectiveScale() >= 24,
	"settings close hit target became too small at the minimum reviewed viewport")

-- If a theme's glyphs are very wide, the title abbreviates before it can
-- collide with PAGES, the mode switch, or the close target.
textUnit = 16
local normalModeWidth, normalMenuWidth = config.modeButton:GetWidth(), config.navigationMenuButton:GetWidth()
config.modeButton:SetWidth(#config.modeButton.text:GetText() * textUnit + 16)
config.navigationMenuButton:SetWidth(#config.navigationMenuButton.text:GetText() * textUnit + 16)
config:FitFrameToViewport()
assert(config.headerTitle:GetText() == "Chatty",
	"wide-font minimum header did not abbreviate before controls collide")
local titleEnd = 6 + 8 + 30 + 8 + (#config.headerTitle:GetText() * textUnit)
local rightReserved = 6 + 8 + close:GetWidth() + 10 + config.modeButton:GetWidth()
	+ config.navigationMenuButton:GetWidth() + 8
assert(titleEnd + 12 <= config.frame:GetWidth() - rightReserved,
	"wide-font header title still overlaps its right-side controls")
config.modeButton:SetWidth(normalModeWidth)
config.navigationMenuButton:SetWidth(normalMenuWidth)
textUnit = 6
config:FitFrameToViewport()

-- Below the reviewed minimum, fitting the fixed page canvas requires a
-- bounded fallback scale; it still cannot drift outside the screen gutters.
UIParent:SetSize(600, 400)
config:FitFrameToViewport()
assert(config.frame:GetScale() < 1, "sub-minimum viewport did not use its emergency fit")
assertViewportGutters(config.frame, 600, 400, "sub-minimum viewport")

-- Tab-key navigation is opt-in after a tab click. It must not listen while the
-- compact settings frame merely sits open, and only its handled keys may be
-- consumed; ordinary game keys and edit-box typing release focus.
UIParent:SetSize(700, 500)
config:FitFrameToViewport()
config.activePage = "dock"
local first = Theme:CreateButton(config.content, "LAYOUT", 70, 20)
first:SetPoint("TOPLEFT", config.content, "TOPLEFT", 8, -8)
local second = Theme:CreateButton(config.content, "COLORS", 70, 20)
second:SetPoint("LEFT", first, "RIGHT", 6, 0)
local detail = Theme:CreateButton(config.content, "WINDOW", 70, 20)
detail:SetPoint("TOPLEFT", config.content, "TOPLEFT", 8, -48)
local activated = 0
second:SetScript("OnClick", function() activated = activated + 1 end)
detail:SetScript("OnClick", function() activated = activated + 10 end)
config:RegisterKeyboardTab(first, "dock/1-main", 1)
config:RegisterKeyboardTab(second, "dock/1-main", 2)
config:RegisterKeyboardTab(detail, "dock/2-layout", 1)
assert(config.frame.keyboardEnabled ~= true and config.keyboardTabFocus == nil,
	"settings captured keyboard input before a tab was focused")
first:Click()
assert(config.keyboardTabFocus == first and first.keyboardFocusVisible
	and config.frame.keyboardEnabled and config.frame.propagateKeyboardInput,
	"click hook did not enable opt-in focus with fail-open propagation")
config.frame.scripts.OnKeyDown(config.frame, "RIGHT")
assert(config.keyboardTabFocus == second and second.keyboardFocusVisible
	and not first.keyboardFocusVisible and activated == 1
	and config.frame.propagateKeyboardInput == false,
	"right arrow did not focus and activate the next tab in its own group")
config.frame.scripts.OnKeyUp(config.frame, "RIGHT")
assert(config.frame.propagateKeyboardInput,
	"handled arrow left keyboard propagation disabled after key release")
config.frame.scripts.OnKeyDown(config.frame, "TAB")
assert(config.keyboardTabFocus == detail and activated == 1,
	"Tab did not focus the next visible subpage group without activating it")
IsShiftKeyDown = function() return true end
config.frame.scripts.OnKeyDown(config.frame, "TAB")
assert(config.keyboardTabFocus == second, "Shift-Tab did not reverse keyboard focus")
IsShiftKeyDown = nil
config.frame.scripts.OnKeyDown(config.frame, "ENTER")
assert(activated == 2, "Enter did not activate the keyboard-focused tab")
second:Hide()
config.frame.scripts.OnKeyDown(config.frame, "RIGHT")
assert(config.keyboardTabFocus == first and activated == 2,
	"arrow navigation did not skip a hidden tab")
assert(not config:FocusKeyboardTab(second), "a hidden tab accepted keyboard focus")
config.frame.scripts.OnKeyDown(config.frame, "W")
assert(config.keyboardTabFocus == nil and not config.frame.keyboardEnabled
	and config.frame.propagateKeyboardInput,
	"ordinary gameplay keys remained captured or were not propagated")
assert(config:FocusKeyboardTab(first), "tab focus could not be re-entered for propagation failure")
local normalPropagation = config.frame.SetPropagateKeyboardInput
config.frame.SetPropagateKeyboardInput = function(self, enabled)
	if not enabled then error("suppression unavailable") end
	return normalPropagation(self, enabled)
end
config.frame.scripts.OnKeyDown(config.frame, "RIGHT")
assert(activated == 2 and config.keyboardTabFocus == nil
	and not config.frame.keyboardEnabled and config.frame.propagateKeyboardInput,
	"failed key suppression still activated a tab or trapped game input")
config.frame.SetPropagateKeyboardInput = normalPropagation
assert(config:FocusKeyboardTab(first), "tab focus could not be re-entered")
GetCurrentKeyBoardFocus = function() return {} end
config.frame.scripts.OnKeyDown(config.frame, "TAB")
assert(config.keyboardTabFocus == nil and not config.frame.keyboardEnabled
	and config.frame.propagateKeyboardInput,
	"focused edit field did not release tab navigation before typing")
GetCurrentKeyBoardFocus = nil
assert(config:FocusKeyboardTab(detail), "detail tab focus could not be entered")
config.frame.scripts.OnKeyDown(config.frame, "ESCAPE")
assert(config.keyboardTabFocus == nil and not config.frame.keyboardEnabled
	and config.frame.propagateKeyboardInput,
	"Escape did not release tab focus cleanly")
detail:SetScript("OnClick", function() error("tab action failed") end)
assert(config:FocusKeyboardTab(detail), "detail tab could not receive focus for error test")
config.frame.scripts.OnKeyDown(config.frame, "ENTER")
assert(config.keyboardTabFocus == nil and not config.frame.keyboardEnabled
	and config.frame.propagateKeyboardInput,
	"a failing tab action left keyboard input trapped")
assert(config:FocusKeyboardTab(first), "tab focus could not be entered before hide")
config.frame:Hide()
assert(config.keyboardTabFocus == nil and not config.frame.keyboardEnabled
	and not first.keyboardFocusVisible,
	"hiding settings left a keyboard trap or stale focus cue")
assert(not config:FocusKeyboardTab(first) and not config.frame.keyboardEnabled,
	"a hidden settings frame accepted keyboard focus")
config.frame:Show()
local propagate = config.frame.SetPropagateKeyboardInput
config.frame.SetPropagateKeyboardInput = false
assert(not config:FocusKeyboardTab(first) and not config.frame.keyboardEnabled,
	"missing Retail propagation API did not fail closed")
config.frame.SetPropagateKeyboardInput = propagate
assert(first.point[4] == 8 and second.point[4] == 6 and detail.point[4] == 8
	and first:GetHeight() == 20 and detail:GetHeight() == 20,
	"compact tab controls lost their edge and between-control gutters")

print("Config viewport mock tests passed")
