-- Focused no-client contract for moving a title-bar-hidden dock from a blank
-- portion of its visible Chat Tabs Rail.
-- Run from the addon root with: lua Tests/SmartDockRailMove.mock.lua

local settings = {
	dock = {
		headerVisibility = "hidden",
		locked = false,
		width = 520,
		height = 250,
		point = "BOTTOMLEFT",
		x = 28,
		y = 34,
	},
}

ChattyChattyBangBang = {
	Theme = {},
	Presentation = {},
	GetSmartSettings = function()
		return settings
	end,
}

local inCombat = false
InCombatLockdown = function()
	return inCombat
end

local cursorX, cursorY = 100, 100
GetCursorPosition = function()
	return cursorX, cursorY
end
UIParent = {
	GetEffectiveScale = function()
		return 1
	end,
}

local mouseDown = true
IsMouseButtonDown = function()
	return mouseDown
end

dofile("Core/SmartDock.lua")

local dock = ChattyChattyBangBang.SmartDock
local frame = {
	shown = true,
	width = 640,
	height = 310,
	IsShown = function(self) return self.shown end,
	StartMoving = function(self) self.started = (self.started or 0) + 1 end,
	StopMovingOrSizing = function(self) self.stopped = (self.stopped or 0) + 1 end,
	GetPoint = function() return "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 41, 57 end,
	GetWidth = function(self) return self.width end,
	GetHeight = function(self) return self.height end,
}
local rail = {
	IsShown = function() return true end,
	IsMouseOver = function() return true end,
}
local blankTab = {
	IsShown = function() return true end,
	IsMouseOver = function() return false end,
}
local settingsButton = {
	IsShown = function() return true end,
	IsMouseOver = function() return false end,
}

dock.active = true
dock.built = true
dock.collapsedState = false
dock.frame = frame
dock.rail = rail
dock.railButtons = { general = blankTab }
dock.railSettingsButton = settingsButton
dock.ScheduleHeaderHoverRefresh = function(self, delay) self.hoverRefreshDelay = delay end
dock.CancelHeaderHoverRefresh = function() end
dock.SetHeaderHover = function() end

assert(dock:CanMoveFromRail(), "hidden-header visible rail should provide a move handle")
settings.dock.headerVisibility = "hover"
assert(not dock:CanMoveFromRail(), "visible/hover title bar incorrectly added a second move handle")
settings.dock.headerVisibility = "hidden"
settings.dock.locked = true
assert(not dock:CanMoveFromRail(), "locked dock exposed a rail move handle")
settings.dock.locked = false
inCombat = true
assert(not dock:CanMoveFromRail(), "combat exposed a rail move handle")
inCombat = false

blankTab.IsMouseOver = function() return true end
assert(not dock:IsMouseOverRailBackground(), "a tab click was treated as blank rail")
blankTab.IsMouseOver = function() return false end
settingsButton.IsMouseOver = function() return true end
assert(not dock:IsMouseOverRailBackground(), "the settings glyph was treated as blank rail")
settingsButton.IsMouseOver = function() return false end
assert(dock:IsMouseOverRailBackground(), "unused rail background was not recognized")

-- A candidate is inert until the cursor has moved the configured threshold.
dock.railMovePress = { x = cursorX, y = cursorY }
cursorX = 102
dock:UpdateRailMove()
assert(not dock.railMoveActive and not frame.started, "short rail movement started a dock move")
cursorX = 105
dock:UpdateRailMove()
assert(dock.railMoveActive and frame.started == 1, "threshold rail drag did not begin moving the dock")
assert(dock:HandleRailBackgroundMouseUp("LeftButton"), "rail mouse-up did not finish an active move")
assert(frame.stopped == 1, "rail move did not stop frame movement")
assert(settings.dock.width == 640 and settings.dock.height == 310 and settings.dock.x == 41 and settings.dock.y == 57,
	"rail move did not persist dock geometry")

print("SmartDock blank-rail move mock tests passed")
