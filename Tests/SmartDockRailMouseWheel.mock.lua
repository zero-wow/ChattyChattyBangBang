-- Focused no-client contract for mouse-wheel scrolling across every Smart
-- Chat tab-rail surface. Run from the addon root with:
-- lua Tests/SmartDockRailMouseWheel.mock.lua

local settings = {
	dock = {
		railOrientation = "horizontal",
	},
}

ChattyChattyBangBang = {
	Theme = {},
	Presentation = {},
	GetSmartSettings = function()
		return settings
	end,
}

dofile("Core/SmartDock.lua")

local dock = ChattyChattyBangBang.SmartDock
local scroll = {
	horizontalRange = 100,
	horizontal = 44,
	verticalRange = 120,
	vertical = 60,
	GetHorizontalScrollRange = function(self) return self.horizontalRange end,
	GetHorizontalScroll = function(self) return self.horizontal end,
	SetHorizontalScroll = function(self, value) self.horizontal = value end,
	GetVerticalScrollRange = function(self) return self.verticalRange end,
	GetVerticalScroll = function(self) return self.vertical end,
	SetVerticalScroll = function(self, value) self.vertical = value end,
}
dock.railScroll = scroll

-- In a horizontal rail, wheel-up pans left and wheel-down pans right. The
-- unused vertical axis must remain untouched.
assert(dock:HandleRailMouseWheel(1), "horizontal wheel-up did not scroll left")
assert(scroll.horizontal == 0, "horizontal wheel-up used the wrong step or axis")
assert(scroll.vertical == 60, "horizontal wheel changed vertical scroll")
assert(dock:HandleRailMouseWheel(-1), "horizontal wheel-down did not scroll right")
assert(scroll.horizontal == 44, "horizontal wheel-down used the wrong step")
scroll.horizontal = 90
assert(dock:HandleRailMouseWheel(-1), "horizontal end clamp did not accept movement")
assert(scroll.horizontal == 100, "horizontal scroll exceeded its range")
assert(not dock:HandleRailMouseWheel(-1), "horizontal scroll reported movement past its end")

-- Vertical rails retain their existing up/down behavior.
settings.dock.railOrientation = "vertical"
scroll.horizontal = 35
scroll.vertical = 60
assert(dock:HandleRailMouseWheel(1), "vertical wheel-up did not scroll up")
assert(scroll.vertical == 16, "vertical wheel-up used the wrong step")
assert(scroll.horizontal == 35, "vertical wheel changed horizontal scroll")
assert(dock:HandleRailMouseWheel(-1), "vertical wheel-down did not scroll down")
assert(scroll.vertical == 60, "vertical wheel-down used the wrong step")
scroll.verticalRange = 0
scroll.vertical = 0
assert(not dock:HandleRailMouseWheel(-1), "zero-range rail reported movement")

-- The actual regression: tabs and fixed controls sit above the ScrollFrame on
-- Wrath, so each child surface must accept wheel input itself and forward it to
-- the shared axis-aware handler. Binding is idempotent.
local surface = {
	hooks = {},
	EnableMouseWheel = function(self, enabled) self.mouseWheelEnabled = enabled end,
	HookScript = function(self, script, handler)
		self.hooks[script] = self.hooks[script] or {}
		table.insert(self.hooks[script], handler)
	end,
}
assert(dock:BindRailMouseWheel(surface), "rail child did not bind mouse-wheel input")
assert(surface.mouseWheelEnabled == true, "rail child did not enable mouse-wheel input")
assert(#surface.hooks.OnMouseWheel == 1, "rail child did not receive one wheel handler")
assert(not dock:BindRailMouseWheel(surface), "rail child bound the handler twice")
assert(#surface.hooks.OnMouseWheel == 1, "idempotent bind duplicated the wheel handler")

settings.dock.railOrientation = "horizontal"
scroll.horizontalRange = 100
scroll.horizontal = 0
surface.hooks.OnMouseWheel[1](surface, -1)
assert(scroll.horizontal == 44, "tab-surface wheel did not pan the horizontal rail")

-- Wheel handling must not create or alter any Shift-drag reorder state.
assert(dock.railTabDrag == nil and dock.railMovePress == nil and dock.railMoveActive == nil,
	"rail wheel input interfered with tab reorder or dock movement")

print("SmartDock rail mouse-wheel mock tests passed")
