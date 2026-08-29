-- Focused no-client contract for the Smart Dock's edge-aware resize state.
-- Run from the addon root with: lua Tests/SmartDockResize.mock.lua

local settings = {
	dock = {
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
	MessageEngine = {},
	GetSmartSettings = function()
		return settings
	end,
}

local inCombat = false
InCombatLockdown = function()
	return inCombat
end

dofile("Core/SmartDock.lua")

local dock = ChattyChattyBangBang.SmartDock
local frame = {
	shown = true,
	resizable = true,
	width = 640,
	height = 310,
	GetPoint = function()
		return "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 41, 57
	end,
	GetWidth = function(self)
		return self.width
	end,
	GetHeight = function(self)
		return self.height
	end,
	IsShown = function(self)
		return self.shown
	end,
	IsResizable = function(self)
		return self.resizable
	end,
	StartSizing = function(self, direction)
		self.started = direction
	end,
	StopMovingOrSizing = function(self)
		self.stopped = (self.stopped or 0) + 1
	end,
}

local highlight = {
	shown = false,
	Show = function(self)
		self.shown = true
	end,
	Hide = function(self)
		self.shown = false
	end,
}

local left = {
	resizeId = "left",
	resizeDirection = "LEFT",
	resizeHighlights = { highlight },
	IsMouseOver = function()
		return false
	end,
}

dock.frame = frame
dock.active = true
dock.activeView = "general"
dock.built = false
dock.collapsedState = false
dock.resizeHandles = { left = left }
dock.resizeHandleList = { left }
-- EndResize's production scheduling driver requires a real UI frame; the
-- behavior under test is completion and persistence, not that driver itself.
dock.ScheduleHeaderHoverRefresh = function(self, delay)
	self.hoverRefreshDelay = delay
end
local responsiveRebuilds = 0
dock.RebuildActiveViewPreservingScroll = function()
	responsiveRebuilds = responsiveRebuilds + 1
end

assert(dock:CanResize(), "expanded, visible unlocked dock should resize")
settings.dock.locked = true
assert(not dock:CanResize(), "locked dock exposed an edge resize target")
settings.dock.locked = false
dock.collapsedState = true
assert(not dock:CanResize(), "collapsed dock exposed an edge resize target")
dock.collapsedState = false
inCombat = true
assert(not dock:CanResize(), "combat should not begin a free-form resize")
inCombat = false

-- The border segment itself is the affordance.  Hovering an enabled edge
-- lights it; leaving it restores the ordinary themed frame border.
dock:SetResizeHover("left")
assert(highlight.shown, "hovered resize edge did not light its border segment")
dock:SetResizeHover(nil)
assert(not highlight.shown, "resize border highlight did not clear on leave")

assert(dock:BeginResize("left"), "left edge did not begin resizing")
assert(frame.started == "LEFT", "left edge used the wrong StartSizing direction")
assert(highlight.shown, "active resize edge did not keep its border highlight")
assert(dock.resizeDragRegion == "left" and dock.headerDragActive,
	"resize did not hold hover layout steady during the drag")
assert(not dock:EndResize("right"), "unrelated edge ended an active resize")
assert(dock:EndResize("left"), "matching edge did not finish resizing")
assert(frame.stopped == 1, "resize did not stop frame sizing exactly once")
assert(settings.dock.width == 640 and settings.dock.height == 310,
	"resize completion did not persist bounded frame dimensions")
assert(settings.dock.point == "BOTTOMLEFT" and settings.dock.x == 41 and settings.dock.y == 57,
	"resize completion did not persist frame position")
assert(dock.resizeDragRegion == nil and not dock.headerDragActive,
	"resize state leaked after mouse-up")
assert(responsiveRebuilds == 1,
	"resize completion did not immediately rebuild width-sensitive presentation")

print("SmartDock edge-resize mock tests passed")
