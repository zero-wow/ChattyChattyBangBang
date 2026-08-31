-- Focused no-client contract for responsive metadata, independent SmartDock
-- opacity, and logical-message band persistence.

ChattyChattyBangBang = {
	db = {
		profile = {
			smartChat = {
				dock = {
					responsiveMetadata = false,
					transparency = {
						backgroundAlpha = -2,
						borderAlpha = 3,
						overallAlpha = 0.4,
					},
					messageBands = {
						enabled = true,
						extent = "unknown",
						extendUnderScrollbar = "yes",
						color = { mode = "custom", r = -1, g = 2, b = 0.5 },
						alpha = 4,
					},
				},
			},
		},
	},
}

dofile("Core/Settings.lua")
local addon = ChattyChattyBangBang
local settings = addon:GetSmartSettings()
local dock = settings.dock

assert(addon:GetResponsiveMetadata() == false,
	"explicit responsive metadata preference was not preserved")
assert(dock.transparency.backgroundAlpha == 0 and dock.transparency.borderAlpha == 1
	and dock.transparency.overallAlpha == 0.4,
	"independent opacity settings were not normalized to 0..1")
assert(dock.messageBands.enabled and dock.messageBands.extent == "full"
	and dock.messageBands.extendUnderScrollbar == false
	and dock.messageBands.color.mode == "custom"
	and dock.messageBands.color.r == 0 and dock.messageBands.color.g == 1
	and dock.messageBands.color.b == 0.5 and dock.messageBands.alpha == 1,
	"message-band settings were not normalized without losing custom color mode")

local responsiveRefreshes, opacityRefreshes, bandRefreshes = 0, 0, 0
addon.SmartDock = {
	RefreshResponsiveMetadata = function() responsiveRefreshes = responsiveRefreshes + 1 end,
	RefreshTransparency = function() opacityRefreshes = opacityRefreshes + 1 end,
	RefreshMessageBands = function() bandRefreshes = bandRefreshes + 1 end,
}

assert(addon:SetResponsiveMetadata(true))
assert(settings.dock.responsiveMetadata == true and responsiveRefreshes == 1,
	"responsive metadata setter did not persist and refresh immediately")

assert(not addon:SetSmartChatWindowBackgroundAlpha("bad"),
	"invalid background alpha was accepted")
assert(addon:SetSmartChatWindowBackgroundAlpha(0.25))
assert(addon:SetSmartChatWindowBorderAlpha(0.5))
assert(addon:SetSmartChatWindowOverallAlpha(0.75))
local transparency = addon:GetSmartChatWindowTransparency()
assert(transparency.backgroundAlpha == 0.25 and transparency.borderAlpha == 0.5
	and transparency.overallAlpha == 0.75 and opacityRefreshes == 3,
	"window opacity setters did not remain independent or refresh live")
transparency.backgroundAlpha = 1
assert(settings.dock.transparency.backgroundAlpha == 0.25,
	"window opacity getter leaked its SavedVariables table")

assert(addon:SetSmartChatMessageBandsEnabled(false))
assert(addon:SetSmartChatMessageBandExtent("afterPlayer"))
assert(not addon:SetSmartChatMessageBandExtent("outside"),
	"invalid message-band extent was accepted")
assert(addon:SetSmartChatMessageBandExtendUnderScrollbar(true))
assert(addon:SetSmartChatMessageBandColor(0.1, 0.2, 0.3))
assert(addon:SetSmartChatMessageBandAlpha(0.35))
local bands = addon:GetSmartChatMessageBandSettings()
assert(not bands.enabled and bands.extent == "afterPlayer"
	and bands.extendUnderScrollbar == true
	and bands.color.mode == "custom" and bands.color.theme == nil
	and bands.alpha == 0.35 and bandRefreshes == 5,
	"custom message-band setters did not persist or refresh live")
assert(addon:SetSmartChatMessageBandColor(0.8, 0.6, 0.2, "gold"))
bands = addon:GetSmartChatMessageBandSettings()
assert(bands.color.mode == "theme" and bands.color.theme == "gold",
	"theme-linked message-band color was not preserved")
bands.color.theme = "danger"
assert(settings.dock.messageBands.color.theme == "gold",
	"message-band getter leaked its SavedVariables table")

assert(addon:ResetSmartChatWindowTransparency())
assert(settings.dock.transparency.backgroundAlpha == 1
	and settings.dock.transparency.borderAlpha == 1
	and settings.dock.transparency.overallAlpha == 1,
	"window opacity reset did not restore defaults")
assert(addon:ResetSmartChatMessageBands())
assert(settings.dock.messageBands.enabled == false
	and settings.dock.messageBands.extent == "full"
	and settings.dock.messageBands.extendUnderScrollbar == false
	and settings.dock.messageBands.schema == 2
	and settings.dock.messageBands.color.theme == "surfaceRaised"
	and settings.dock.messageBands.alpha == 0.50,
	"message-band reset did not restore defaults")

-- Only the exact first-release factory style is upgraded. A deliberate
-- accent choice with a different opacity remains a player choice.
addon.db.profile.smartChat.dock.messageBands = {
	enabled = true,
	extent = "full",
	color = { mode = "theme", theme = "accentSoft", r = 0.16, g = 0.28, b = 0.42 },
	alpha = 0.16,
}
bands = addon:GetSmartChatMessageBandSettings()
assert(bands.schema == 2 and bands.color.theme == "surfaceRaised" and bands.alpha == 0.50,
	"legacy factory accent stripes were not migrated to neutral table rows")
addon.db.profile.smartChat.dock.messageBands = {
	enabled = true,
	extent = "afterPlayer",
	extendUnderScrollbar = true,
	color = { mode = "theme", theme = "accentSoft", r = 0.16, g = 0.28, b = 0.42 },
	alpha = 0.22,
}
bands = addon:GetSmartChatMessageBandSettings()
assert(bands.color.theme == "accentSoft" and bands.alpha == 0.22
	and bands.extent == "afterPlayer" and bands.extendUnderScrollbar == true,
	"deliberate message-band styling was overwritten by the factory migration")

print("Smart Chat readability settings mock passed")
