-- Focused no-client contract for the SmartDock's slim message scrollbar.
-- Run from the addon root with: lua Tests/SmartDockScrollbar.mock.lua

local settings = {
	dock = {
		showScrollButtons = true, -- persisted compatibility key now means scrollbar
	},
}

ChattyChattyBangBang = {
	Theme = {},
	Presentation = {},
	MessageEngine = {},
	GetSmartSettings = function() return settings end,
}

dofile("Core/SmartDock.lua")

local addon = ChattyChattyBangBang
local dock = addon.SmartDock

local display = {
	width = 400,
	height = 40,
	scroll = 7,
	setOffsetCalls = 0,
}
function display:GetWidth() return self.width end
function display:GetHeight() return self.height end
function display:GetFont() return "Fonts\\FRIZQT__.TTF", 10 end
function display:GetSpacing() return 0 end
function display:GetCurrentScroll() return self.scroll end
function display:AtBottom() return self.scroll == 0 end
function display:SetScrollOffset(value)
	self.setOffsetCalls = self.setOffsetCalls + 1
	self.scroll = value
end
function display:ScrollToBottom()
	self.scrollToBottomCalls = (self.scrollToBottomCalls or 0) + 1
	self.scroll = 0
end

local thumb = { shown = true, width = 6, height = 28 }
function thumb:SetWidth(value) self.width = value end
function thumb:SetHeight(value) self.height = value end
function thumb:Show() self.shown = true end
function thumb:Hide() self.shown = false end
function thumb:IsShown() return self.shown end

local bar = {
	height = 200,
	shown = true,
	mouseEnabled = true,
	thumb = thumb,
	scripts = {},
}
function bar:GetHeight() return self.height end
function bar:SetMinMaxValues(minimum, maximum)
	self.minimum, self.maximum = minimum, maximum
end
function bar:GetMinMaxValues() return self.minimum, self.maximum end
function bar:SetValue(value)
	self.value = value
	if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function bar:GetValue() return self.value end
function bar:GetThumbTexture() return self.thumb end
function bar:SetScript(name, callback) self.scripts[name] = callback end
function bar:EnableMouse(value) self.mouseEnabled = value and true or false end
function bar:Show() self.shown = true end
function bar:Hide() self.shown = false end
function bar:IsShown() return self.shown end

local bottom = { shown = false, scripts = {} }
function bottom:Show() self.shown = true end
function bottom:Hide() self.shown = false end
function bottom:IsShown() return self.shown end
function bottom:SetScript(name, callback) self.scripts[name] = callback end

addon.Theme.SetScrollBarThumbVisible = function(_, target, visible)
	target:GetThumbTexture()[visible and "Show" or "Hide"](target:GetThumbTexture())
end
addon.Theme.SetScrollBarThumbSize = function(_, target, width, height)
	target:GetThumbTexture():SetWidth(width)
	target:GetThumbTexture():SetHeight(height)
end

dock.display = display
dock.messageScrollbar = bar
dock.scrollToBottomButton = bottom
dock.IsAlignmentVisibleOnly = function() return false end
dock.RefreshMessageBands = function() return true end
dock.ScheduleMessageBlockActionRefresh = function(self)
	self.blockActionRefreshes = (self.blockActionRefreshes or 0) + 1
end
dock.ClearPendingMessages = function(self)
	self.clearPendingCalls = (self.clearPendingCalls or 0) + 1
	self.pendingVisible = 0
end
dock.displayMeasurementWidth = display.width
dock.displayRecords = {}
for index = 1, 20 do
	dock.displayRecords[index] = { record = { id = index }, lines = 1 }
end

-- Refreshing UI state must not feed the programmatic slider value back into
-- ScrollingMessageFrame. This models WoW's Slider, where SetValue fires the
-- same OnValueChanged callback used by mouse dragging.
bar.scripts.OnValueChanged = function(_, value)
	if dock.SetMessageScrollbarOffset then
		dock:SetMessageScrollbarOffset(value)
	end
end

dock:RefreshMessageScrollbar()
assert(bar.minimum == 0 and bar.maximum == 16,
	"scrollbar range did not equal total visual rows minus viewport capacity")
assert(bar.value == 9,
	"Wrath vertical slider did not invert GetCurrentScroll so newest remains at the bottom")
assert(display.setOffsetCalls == 0,
	"programmatic scrollbar refresh recursively changed the message viewport")
assert(thumb:IsShown() and bar.mouseEnabled,
	"overflowing message history did not expose an interactive thumb")
assert(thumb.width == 6 and thumb.height == 40,
	"overflowing thumb was not proportional to the four-of-twenty visible rows")
assert(bottom:IsShown(),
	"scroll-to-bottom affordance was not shown while overflow was scrolled back")

-- Wrath places a vertical Slider's minimum at the top, while
-- ScrollingMessageFrame offset zero means the newest line at the bottom. The
-- bridge must therefore invert the full range in both directions.
assert(type(dock.SetMessageScrollbarOffset) == "function",
	"SmartDock did not expose its testable scrollbar-to-display bridge")
dock:SetMessageScrollbarOffset(0)
assert(display.scroll == 16 and display.setOffsetCalls == 1,
	"dragging the thumb to the top did not reveal the maximum/oldest offset")
dock.pendingVisible = 5
dock:SetMessageScrollbarOffset(16)
assert(display.scroll == 0 and display.setOffsetCalls == 2,
	"dragging the thumb to the bottom did not reveal offset zero/newest")
assert(dock.pendingVisible == 0 and dock.clearPendingCalls == 1,
	"dragging the thumb to newest did not clear pending messages")

display.scroll = 0
dock:RefreshMessageScrollbar()
assert(bar.value == 16,
	"newest message offset did not settle the Wrath slider at its bottom/max endpoint")
assert(not bottom:IsShown(),
	"scroll-to-bottom affordance remained visible after reaching the bottom")

-- With no overflow the eight-pixel layout lane may remain reserved to prevent
-- rewrap jitter, but the thumb and its hit target must disappear.
dock.displayRecords = {
	{ record = { id = 1 }, lines = 1 },
	{ record = { id = 2 }, lines = 1 },
	{ record = { id = 3 }, lines = 1 },
}
dock:RefreshMessageScrollbar()
assert(bar.minimum == 0 and bar.maximum == 0,
	"non-overflowing messages retained a stale scrollbar range")
assert(not thumb:IsShown() and not bar.mouseEnabled and not bottom:IsShown(),
	"non-overflowing messages retained scrollbar or bottom-button chrome")

settings.dock.showScrollButtons = false
dock.displayRecords = {}
for index = 1, 20 do dock.displayRecords[index] = { record = { id = index }, lines = 1 } end
display.scroll = 6
dock:RefreshMessageScrollbar()
assert(not bar:IsShown() and not bottom:IsShown(),
	"disabled scrollbar setting left the thumb rail or bottom affordance visible")
settings.dock.showScrollButtons = true

-- The bottom affordance is a distinct action: it must clear the unread marker
-- and synchronize the rail immediately after native ScrollToBottom.
dock.displayRecords = {}
for index = 1, 20 do dock.displayRecords[index] = { record = { id = index }, lines = 1 } end
display.scroll = 8
dock.pendingVisible = 5
dock.clearPendingCalls = 0
dock.RefreshNewMessageIndicator = function(self)
	self.indicatorRefreshes = (self.indicatorRefreshes or 0) + 1
end
assert(type(dock.ScrollMessageDisplayToBottom) == "function",
	"SmartDock did not expose its scroll-to-bottom action")
dock:ScrollMessageDisplayToBottom()
assert(display.scrollToBottomCalls == 1 and display.scroll == 0,
	"bottom affordance did not invoke native ScrollToBottom")
assert(dock.pendingVisible == 0 and dock.clearPendingCalls == 1,
	"bottom affordance did not clear pending messages")
assert(not bottom:IsShown(),
	"bottom affordance did not immediately hide after reaching the bottom")

print("SmartDock slim-scrollbar mock passed")
