-- Focused no-client contract for the independently styled/movable NEW marker.
-- Run from the addon root with: lua Tests/NewMessageIndicatorAppearance.mock.lua

ChattyChattyBangBang = {
	Theme = {
		frames = {},
		texts = {},
		palette = {
			goldBright = { 1, 0.8, 0.39, 1 },
			accentSoft = { 0.11, 0.24, 0.42, 0.99 },
			gold = { 0.88, 0.61, 0.24, 1 },
			text = { 0.82, 0.86, 0.92, 1 },
		},
		GetColor = function(self, name)
			local color = self.palette[name] or self.palette.text
			return color[1], color[2], color[3], color[4]
		end,
	},
	Presentation = {},
	db = { profile = { smartChat = {} } },
}

dofile("Core/Settings.lua")
dofile("Core/SmartDock.lua")

local addon = ChattyChattyBangBang
local dock = addon.SmartDock
local settings = addon:GetSmartSettings()

local function fakeFrame(width, height)
	local frame = {
		width = width or 0,
		height = height or 0,
		shown = true,
		level = 1,
	}
	function frame:IsShown() return self.shown end
	function frame:Show() self.shown = true end
	function frame:Hide() self.shown = false end
	function frame:GetWidth() return self.width end
	function frame:GetHeight() return self.height end
	function frame:GetFrameLevel() return self.level end
	function frame:SetFrameLevel(level) self.level = level end
	return frame
end

local frame = fakeFrame(500, 250)
local header = fakeFrame(496, 24)
local collapse = fakeFrame(18, 18)
local text = {
	SetTextColor = function(self, r, g, b, a) self.color = { r, g, b, a } end,
	SetFont = function(self, path, size, flags)
		self.font = { path, size, flags }
		self.fontSize = size
		return true
	end,
	SetFontObject = function(self, object)
		self.fontObject = object
		self.fontSize = 10
	end,
	GetStringWidth = function(self)
		return #(self.label or "") * (self.fontSize or 6)
	end,
}
local button = fakeFrame(50, 18)
button.parent = header
button.text = text
function button:GetParent() return self.parent end
function button:SetParent(parent) self.parent = parent end
function button:ClearAllPoints() self.point = nil end
function button:SetPoint(...) self.point = { ... } end
function button:SetBackdropColor(r, g, b, a) self.background = { r, g, b, a } end
function button:SetBackdropBorderColor(r, g, b, a) self.border = { r, g, b, a } end
function button:SetAlpha(alpha) self.alpha = alpha end
function button:GetScale() return self.scale or 1 end
function button:SetScale(scale) self.scale = scale end
function button:SetLabel(label)
	self.label = label
	self.text.label = label
end
function button:SetWidth(width) self.width = width end

dock.frame = frame
dock.header = header
dock.collapseButton = collapse
dock.newButton = button
dock.active = true
dock.built = true
dock.collapsedState = false
dock.pendingVisible = 6

-- The untouched default retains the exact old inline title-bar slot.
dock:RefreshNewMessageIndicator(false)
assert(button.parent == header, "default NEW marker left its title-bar parent")
assert(button.point and button.point[1] == "RIGHT" and button.point[2] == collapse,
	"default NEW marker no longer uses the original inline slot")

-- Locking the outer dock protects its frame geometry; it must not prevent the
-- marker's separate Shift-drag visual preference.
settings.dock.locked = true
assert(dock:CanMoveNewMessageIndicator(), "locked dock incorrectly disabled marker placement")
settings.dock.locked = false

-- A visual font override must remeasure the already-visible label after the
-- font is applied, rather than leaving the compact default-font width behind.
ChatFontNormal = {
	GetFont = function() return "Fonts\\ARIALN.TTF", 11, "" end,
}
assert(addon:SetNewMessageIndicatorAppearance({ font = "chat", fontSize = 20 }))
dock:RefreshNewMessageIndicator(false)
assert(button:GetWidth() >= (#(button.label or "") * 20) + 4,
	"marker label was not remeasured after its font-size override")

-- A custom free placement becomes a dock child, retains its appearance, and
-- stays visible independently of hidden hover-only title chrome.
assert(addon:SetNewMessageIndicatorAppearance({
	position = { anchor = "dock", point = "BOTTOMRIGHT", x = -4, y = 4 },
	alpha = 0.65,
	scale = 1.25,
	color = { mode = "custom", r = 0.2, g = 0.7, b = 1, a = 0.9 },
	background = { mode = "custom", r = 0.1, g = 0.1, b = 0.1, a = 0.8 },
	border = { mode = "custom", r = 1, g = 0.2, b = 0.1, a = 1 },
}))
header:Hide()
dock:RefreshNewMessageIndicator(false)
assert(button.parent == frame and button:IsShown(), "custom marker did not remain a visible dock overlay")
assert(button.point and button.point[1] == "BOTTOMRIGHT", "custom dock point was not applied")
assert(button.alpha == 0.65 and button.scale == 1.25, "marker alpha or scale override was lost")
assert(button.text.color[1] == 0.2 and button.background[4] == 0.8 and button.border[2] == 0.2,
	"custom marker colors were not applied")
assert(addon.Theme.frames[button] == nil and addon.Theme.texts[text] == nil,
	"custom RGBA marker colors should not remain registered as theme tokens")

-- Bounds include the scaled marker, not merely its unscaled hit rectangle.
local point, x, y = dock:ClampNewMessageIndicatorDockPosition("TOPLEFT", 9999, -9999)
assert(point == "TOPLEFT"
	and x <= frame:GetWidth() - (button:GetWidth() * button:GetScale()) - 2
	and y >= -frame:GetHeight() + (button:GetHeight() * button:GetScale()) + 2,
	"free marker placement was not bounded to the dock surface")

-- Token choices remain registered, so a later colorway refresh can repaint
-- them, while custom overrides above can always be reapplied directly.
assert(addon:SetNewMessageIndicatorAppearance({
	color = "goldBright",
	background = "accentSoft",
	border = "gold",
}))
dock:RefreshNewMessageIndicator(false)
assert(addon.Theme.frames[button] and addon.Theme.frames[button].fill == "accentSoft"
	and addon.Theme.frames[button].border == "gold", "theme background/border registration was not updated")
assert(addon.Theme.texts[text] == "goldBright", "theme text registration was not updated")

-- Preview does not manufacture unread state, and Shift-drag persistence goes
-- through Settings instead of writing an ad-hoc frame point.
dock.pendingVisible = 0
assert(dock:SetNewMessageIndicatorPreviewActive(true))
assert(button:IsShown() and dock.pendingVisible == 0, "preview changed unread state or failed to show")
dock.newMessageIndicatorMove = { dragging = true, point = "TOPLEFT", x = 18, y = -24 }
assert(dock:EndNewMessageIndicatorMove(), "completed marker drag was not persisted")
local appearance = addon:GetNewMessageIndicatorAppearanceSettings()
assert(appearance.position.anchor == "dock" and appearance.position.point == "TOPLEFT"
	and appearance.position.x == 18 and appearance.position.y == -24,
	"marker drag did not persist through the public position API")
assert(dock.pendingVisible == 0, "marker drag altered unread state")

-- A button can be reparented during a drag, so the OnUpdate driver must also
-- notice mouse release. A held Shift commits a completed move; a released
-- Shift restores rather than leaving the driver alive or persisting a move.
IsMouseButtonDown = function() return false end
IsShiftKeyDown = function() return true end
dock.newMessageIndicatorMove = { dragging = true, point = "BOTTOM", x = 7, y = 9 }
assert(not dock:UpdateNewMessageIndicatorMove() and dock.newMessageIndicatorMove == nil,
	"marker move driver did not finish after a missed mouse-up")
appearance = addon:GetNewMessageIndicatorAppearanceSettings()
assert(appearance.position.point == "BOTTOM" and appearance.position.x == 7 and appearance.position.y == 9,
	"held-Shift driver release did not persist the completed marker move")

assert(addon:SetNewMessageIndicatorPosition("header"))
IsShiftKeyDown = function() return false end
dock.newMessageIndicatorMove = { dragging = true, point = "TOPLEFT", x = 33, y = -18 }
assert(not dock:UpdateNewMessageIndicatorMove() and dock.newMessageIndicatorMove == nil,
	"marker move driver did not cancel when Shift was released")
appearance = addon:GetNewMessageIndicatorAppearanceSettings()
assert(appearance.position.anchor == "header",
	"marker move driver persisted a drag after the configuration modifier was released")
IsMouseButtonDown = nil
IsShiftKeyDown = nil

print("New-message indicator appearance mock tests passed")
