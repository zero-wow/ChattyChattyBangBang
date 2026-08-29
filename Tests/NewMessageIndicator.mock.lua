-- Focused no-client contract for the active-view NEW indicator preferences.
-- Run from the addon root with: lua Tests/NewMessageIndicator.mock.lua

ChattyChattyBangBang = {
	db = {
		profile = {
			smartChat = {},
		},
	},
}

dofile("Core/Settings.lua")

local addon = ChattyChattyBangBang
local settings = addon:GetSmartSettings()
assert(settings.dock.newMessages.enabled == true, "NEW indicator should default to enabled")
assert(settings.dock.newMessages.showCount == true, "NEW indicator should show its count by default")
assert(settings.dock.newMessages.maxCount == 99, "NEW indicator default cap changed")

local exported = addon:GetNewMessageIndicatorSettings()
exported.enabled = false
assert(settings.dock.newMessages.enabled == true, "indicator getter leaked its SavedVariables table")

local refreshes = 0
addon.SmartDock = {
	RefreshNewMessageIndicator = function()
		refreshes = refreshes + 1
	end,
	SetNewMessageIndicatorPreviewActive = function(self, active)
		self.previewActive = active
	end,
}
assert(addon:SetNewMessageIndicatorEnabled(false))
assert(addon:SetNewMessageIndicatorShowCount(false))
assert(addon:SetNewMessageIndicatorMaxCount(4))
assert(settings.dock.newMessages.enabled == false and settings.dock.newMessages.showCount == false,
	"indicator boolean setters did not persist")
assert(settings.dock.newMessages.maxCount == 9, "indicator cap did not clamp to a readable minimum")
assert(not addon:SetNewMessageIndicatorMaxCount("nope"), "invalid indicator cap was accepted")
assert(refreshes == 3, "only successful indicator setters should refresh the live dock")

local appearance = addon:GetNewMessageIndicatorAppearanceSettings()
assert(appearance.position.anchor == "header", "NEW marker should preserve its original header slot by default")
assert(appearance.alpha == 1 and appearance.scale == 1, "NEW marker appearance defaults changed")
assert(appearance.font == "default" and appearance.fontSize == 0 and appearance.outline == "NONE",
	"NEW marker font defaults should preserve the original UI font")
assert(appearance.color.mode == "theme" and appearance.color.theme == "goldBright",
	"NEW marker text should follow the existing theme gold by default")
appearance.position.anchor = "dock"
assert(settings.dock.newMessages.appearance.position.anchor == "header", "appearance getter leaked SavedVariables")

local options = addon:GetNewMessageIndicatorAppearanceOptions()
assert(#options.positions >= 5 and #options.fonts >= 3 and #options.outlines == 3,
	"NEW marker appearance options are incomplete")
options.fonts[1].id = "broken"
assert(addon:GetNewMessageIndicatorAppearanceOptions().fonts[1].id == "default", "appearance options getter leaked its table")

local positioned, position = addon:SetNewMessageIndicatorPosition("BOTTOMLEFT")
assert(positioned and position.anchor == "dock" and position.point == "BOTTOMLEFT" and position.x == 4 and position.y == 4,
	"dock placement preset did not use a safe inset")
positioned, position = addon:SetNewMessageIndicatorPosition({ anchor = "dock", point = "TOPRIGHT", x = -71, y = -9 })
assert(positioned and position.point == "TOPRIGHT" and position.x == -71 and position.y == -9,
	"free marker placement did not persist exactly")
assert(not addon:SetNewMessageIndicatorPosition({ anchor = "oops" }), "invalid marker anchor was accepted")

assert(addon:SetNewMessageIndicatorFont("chat"))
assert(addon:SetNewMessageIndicatorFontSize(4))
assert(addon:SetNewMessageIndicatorAlpha(3))
assert(addon:SetNewMessageIndicatorScale(0.1))
assert(addon:SetNewMessageIndicatorOutline("THICK"))
assert(addon:SetNewMessageIndicatorColor({ mode = "custom", r = 0.2, g = 0.3, b = 0.4, a = 0.5 }))
assert(addon:SetNewMessageIndicatorBackgroundColor("accentSoft"))
assert(addon:SetNewMessageIndicatorBorderColor({ mode = "theme", theme = "danger" }))
appearance = addon:GetNewMessageIndicatorAppearanceSettings()
assert(appearance.font == "chat" and appearance.fontSize == 8 and appearance.alpha == 1 and appearance.scale == 0.5,
	"appearance scalar setters did not clamp safely")
assert(appearance.outline == "THICKOUTLINE" and appearance.color.mode == "custom" and appearance.color.a == 0.5,
	"appearance font/color setters did not persist")
assert(appearance.background.theme == "accentSoft" and appearance.border.theme == "danger",
	"appearance palette setters did not persist")
assert(not addon:SetNewMessageIndicatorFont("not-a-font"), "invalid marker font was accepted")
assert(not addon:SetNewMessageIndicatorAlpha("nope"), "invalid marker alpha was accepted")

local applied, patched = addon:SetNewMessageIndicatorAppearance({
	position = { x = 16, y = -12 },
	alpha = 0.6,
	color = { r = 0.9, g = 0.1, b = 0.2, a = 0.8 },
})
assert(applied and patched.position.x == 16 and patched.position.y == -12 and patched.alpha == 0.6,
	"combined marker appearance patch did not commit")
assert(patched.color.mode == "custom" and patched.color.r == 0.9 and patched.color.a == 0.8,
	"combined custom color patch was not normalized")
assert(addon:SetNewMessageIndicatorPreviewActive(true) and addon.SmartDock.previewActive,
	"transient marker preview did not reach the dock")
assert(addon:SetNewMessageIndicatorPreviewActive(false) and not addon.SmartDock.previewActive,
	"transient marker preview did not clear")

assert(addon:ResetNewMessageIndicatorAppearance())
appearance = addon:GetNewMessageIndicatorAppearanceSettings()
assert(appearance.position.anchor == "header" and appearance.font == "default" and appearance.alpha == 1,
	"appearance-only reset did not restore marker defaults")
assert(settings.dock.newMessages.enabled == false and settings.dock.newMessages.showCount == false,
	"appearance-only reset changed marker behavior settings")

-- A hand-edited future-looking shape must be repaired even if it falsely
-- claims the current schema; the dock should never inherit invalid anchors,
-- font flags, or out-of-range alpha values from SavedVariables.
settings.dock.newMessages.appearance = {
	schema = 1,
	position = { anchor = "broken", point = "NOWHERE", x = "nope", y = 99999 },
	alpha = 9,
	scale = 0,
	font = "bad-font",
	fontSize = 3,
	outline = "impossible",
	color = { mode = "custom", r = -1, g = 3, b = "bad", a = 2 },
}
appearance = addon:GetNewMessageIndicatorAppearanceSettings()
assert(appearance.position.anchor == "header" and appearance.position.point == "TOPRIGHT"
	and appearance.alpha == 1 and appearance.scale == 0.5 and appearance.font == "default"
	and appearance.fontSize == 8 and appearance.outline == "NONE",
	"malformed marker appearance did not migrate safely")
assert(appearance.color.mode == "custom" and appearance.color.r == 0 and appearance.color.g == 1
	and appearance.color.b == 0.39 and appearance.color.a == 1,
	"malformed custom marker color did not clamp/fall back safely")

addon.Theme = {}
addon.Presentation = {}
dofile("Core/SmartDock.lua")

local dock = addon.SmartDock
local button = {
	Show = function(self) self.shown = true end,
	Hide = function(self) self.shown = false end,
	SetLabel = function(self, value) self.label = value end,
	SetWidth = function(self, value) self.width = value end,
}
dock.newButton = button
dock.active = true
dock.collapsedState = false
dock.pendingVisible = 17

-- The disabled control hides without discarding the unread count.
dock:RefreshNewMessageIndicator(false)
assert(button.shown == false and dock.pendingVisible == 17,
	"disabled NEW indicator either showed or discarded pending messages")

assert(addon:SetNewMessageIndicatorEnabled(true))
assert(button.shown == true and button.label == "NEW",
	"countless NEW mode did not apply live")

assert(addon:SetNewMessageIndicatorShowCount(true))
assert(addon:SetNewMessageIndicatorMaxCount(12))
assert(button.label == "NEW 12+", "NEW count cap did not apply live")

dock:ClearPendingMessages()
assert(dock.pendingVisible == 0 and button.shown == false,
	"jumping to newest did not clear the transient NEW indicator")

print("New-message indicator mock tests passed")
