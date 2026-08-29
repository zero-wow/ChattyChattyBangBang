-- Focused no-client contract for Shift-drag ordering in the live chat rail.
-- Run from the addon root with: lua Tests/SmartDockRailReorder.mock.lua

local settings = {
	dock = {
		railOrientation = "vertical",
	},
}

local definitions = {
	{ id = "a" },
	{ id = "b" },
	{ id = "c" },
}
local moved = {}

ChattyChattyBangBang = {
	Theme = {},
	Presentation = {},
	GetSmartSettings = function()
		return settings
	end,
	GetSmartViews = function()
		return definitions
	end,
	MoveSmartViewToIndex = function(_, viewId, targetIndex)
		table.insert(moved, { viewId, targetIndex })
		local currentIndex
		for index = 1, #definitions do
			if definitions[index].id == viewId then
				currentIndex = index
				break
			end
		end
		local definition = table.remove(definitions, currentIndex)
		table.insert(definitions, targetIndex, definition)
		return true, targetIndex
	end,
}

local inCombat = false
InCombatLockdown = function()
	return inCombat
end

local clock = 10
GetTime = function()
	return clock
end

dofile("Core/SmartDock.lua")

local dock = ChattyChattyBangBang.SmartDock
local function shownFrame()
	return {
		IsShown = function()
			return true
		end,
	}
end

local function button(id, x, y)
	return {
		viewId = id,
		IsShown = function()
			return true
		end,
		GetCenter = function()
			return x, y
		end,
		IsMouseOver = function(self)
			return self.mouseOver == true
		end,
	}
end

local marker = {
	shown = false,
	ClearAllPoints = function(self)
		self.points = {}
	end,
	SetPoint = function(self, ...)
		self.points = self.points or {}
		table.insert(self.points, { ... })
	end,
	SetWidth = function(self, value)
		self.width = value
	end,
	SetHeight = function(self, value)
		self.height = value
	end,
	Show = function(self)
		self.shown = true
	end,
	Hide = function(self)
		self.shown = false
	end,
}

dock.active = true
dock.built = true
dock.collapsedState = false
dock.frame = shownFrame()
dock.rail = shownFrame()
dock.railTabReorderMarker = marker
dock.railButtons = {
	a = button("a", 30, 300),
	b = button("b", 30, 270),
	c = button("c", 30, 240),
}
dock.RefreshRailState = function() end
dock.RefreshViews = function() end
dock.CancelHeaderHoverRefresh = function() end
dock.ScheduleHeaderHoverRefresh = function() end
dock.SetHeaderHover = function() end

assert(dock:CanReorderRailTabs(), "visible expanded rail should allow Shift-drag configuration")
inCombat = true
assert(not dock:CanReorderRailTabs(), "combat should reject mutable rail reordering")
inCombat = false

-- Vertical rails read top-to-bottom. Dropping below C means after C, even
-- when the source was above it in the original list.
dock.railTabDragViewId = "a"
dock.railTabDragButton = dock.railButtons.a
local target, after = dock:UpdateRailTabDropTarget(30, 220)
assert(target == "c" and after == true, "vertical bottom drop did not resolve after the final visible tab")
assert(marker.shown and marker.height == 2, "vertical drop marker was not shown as a compact horizontal line")
assert(dock:FinishRailTabReorder(true), "vertical Shift-drop did not commit")
assert(moved[#moved][1] == "a" and moved[#moved][2] == 3, "vertical final-index adjustment was wrong")
assert(definitions[1].id == "b" and definitions[2].id == "c" and definitions[3].id == "a",
	"vertical move did not produce the expected order")

-- Reset the source order, then move C before A. This exercises the inverse
-- adjustment (source comes after its target in the original list).
definitions = {
	{ id = "a" },
	{ id = "b" },
	{ id = "c" },
}
dock.railTabDragViewId = "c"
dock.railTabDragButton = dock.railButtons.c
target, after = dock:UpdateRailTabDropTarget(30, 330)
assert(target == "a" and after == false, "vertical top drop did not resolve before the first tab")
assert(dock:FinishRailTabReorder(true), "vertical before-drop did not commit")
assert(moved[#moved][1] == "c" and moved[#moved][2] == 1, "vertical before-drop used the wrong final index")

-- Horizontal rails use the same API math but a left-to-right hit test. A
-- pointer between B and C means after B / before C.
definitions = {
	{ id = "a" },
	{ id = "b" },
	{ id = "c" },
}
settings.dock.railOrientation = "horizontal"
dock.railButtons = {
	a = button("a", 30, 20),
	b = button("b", 70, 20),
	c = button("c", 110, 20),
}
dock.railTabDragViewId = "a"
dock.railTabDragButton = dock.railButtons.a
target, after = dock:UpdateRailTabDropTarget(90, 20)
assert(target == "c" and after == false, "horizontal midpoint did not resolve before C")
assert(marker.shown and marker.width == 2, "horizontal drop marker was not shown as a compact vertical line")
assert(dock:FinishRailTabReorder(true), "horizontal Shift-drop did not commit")
assert(moved[#moved][1] == "a" and moved[#moved][2] == 2, "horizontal final-index adjustment was wrong")
assert(definitions[1].id == "b" and definitions[2].id == "a" and definitions[3].id == "c",
	"horizontal move did not produce the expected order")

-- Suppression is source-specific, so a drag that does not emit a native click
-- cannot eat the player's next click on a different rail.
dock:SuppressRailTabClick("a")
assert(not dock:ShouldSuppressRailTabClick("b"), "drag suppression leaked to another tab")
assert(dock:ShouldSuppressRailTabClick("a"), "drag source click was not suppressed")

print("SmartDock rail Shift-drag mock tests passed")
