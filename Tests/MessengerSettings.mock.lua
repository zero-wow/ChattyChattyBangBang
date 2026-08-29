ChattyChattyBangBang = {
	db = { profile = { smartChat = {} } },
}

dofile("Core/Settings.lua")
local addon = ChattyChattyBangBang
local settings = addon:GetSmartSettings().conversations
local exported = addon:GetMessengerSettings()

assert(exported.chromeAutoHide == false, "Messenger chrome auto-hide should be opt-in")
assert(exported.titleBarVisibility == "inherit"
	and exported.actionVisibility == "inherit"
	and exported.composerVisibility == "inherit",
	"Messenger regions should inherit the shared chrome behavior by default")
assert(exported.resolvedTitleBarVisibility == "always"
	and exported.resolvedActionVisibility == "always"
	and exported.resolvedComposerVisibility == "always",
	"inherit should preserve the existing always-visible Messenger by default")
exported.titleBarVisibility = "hidden"
assert(settings.titleBarVisibility == "inherit", "Messenger getter leaked SavedVariables")

local refreshes = 0
addon.ConversationWindows = {
	ApplySettings = function() refreshes = refreshes + 1 end,
}

local ok, value = addon:SetMessengerChromeAutoHideEnabled(true)
assert(ok and value == true and refreshes == 1, "shared Messenger auto-hide did not refresh live")
exported = addon:GetMessengerSettings()
assert(exported.resolvedTitleBarVisibility == "auto"
	and exported.resolvedActionVisibility == "auto"
	and exported.resolvedComposerVisibility == "auto",
	"inherit did not follow the Messenger-wide auto-hide switch")

ok, value = addon:SetMessengerElementVisibility("title bar", "hide")
assert(ok and value == "hidden" and settings.titleBarVisibility == "hidden",
	"title-bar visibility alias did not normalize")
ok, value = addon:SetMessengerElementVisibility("actions", "show")
assert(ok and value == "always" and settings.actionVisibility == "always",
	"action visibility alias did not normalize")
ok, value = addon:SetMessengerElementVisibility("reply", "auto")
assert(ok and value == "auto" and settings.composerVisibility == "auto",
	"reply-field visibility did not persist")
assert(not addon:SetMessengerElementVisibility("unknown", "always"),
	"unknown Messenger region was accepted")
assert(not addon:SetMessengerElementVisibility("title", "sometimes"),
	"unknown Messenger visibility mode was accepted")

ok, value = addon:SetMessengerActionButtonStyle("icon")
assert(ok and value == "icons" and settings.actionButtonStyle == "icons",
	"Messenger icon preference did not normalize")
assert(not addon:SetMessengerActionButtonStyle("pictures"),
	"invalid Messenger action style was accepted")
assert(addon:SetMessengerPopupWhispersEnabled(false))
assert(settings.autoOpenWhispers == false, "popup-whisper setting did not persist")
assert(addon:SetMessengerCombatDeferralEnabled(false))
assert(settings.deferInCombat == false, "combat-deferral setting did not persist")

addon.ConversationWindows = nil
addon.db.profile.smartChat = {
	conversations = {
		titleBarVisibility = false,
		actionVisibility = "mouse_over",
		composerVisibility = "shown",
		actionButtonStyle = "icon",
	},
}
settings = addon:GetSmartSettings().conversations
assert(settings.titleBarVisibility == "hidden"
	and settings.actionVisibility == "auto"
	and settings.composerVisibility == "always"
	and settings.actionButtonStyle == "icons",
	"legacy/malformed Messenger visibility values were not normalized")

print("MessengerSettings.mock.lua: PASS")
