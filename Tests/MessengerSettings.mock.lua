ChattyChattyBangBang = {
	db = { profile = { smartChat = {} } },
}

dofile("Core/Settings.lua")
local addon = ChattyChattyBangBang
local settings = addon:GetSmartSettings().conversations
local exported = addon:GetMessengerSettings()
local appearanceTargets = { "window", "title", "tabs", "chat", "reply", "border" }

assert(exported.chromeAutoHide == false, "Messenger chrome auto-hide should be opt-in")
assert(exported.actionStripCollapsed == false and exported.actionStripOrientation == "horizontal",
	"Messenger actions should start expanded on the tab row")
assert(settings.tabNameMaxLength == 14 and exported.tabNameMaxLength == 14,
	"Messenger tab-name length should default to 14 total visible characters")
assert(exported.minimumTabNameLength == 4 and exported.maximumTabNameLength == 32
	and exported.tabNameTruncationMarker == "~",
	"Messenger tab-name settings getter omitted its bounds or compact truncation marker")
assert(exported.titleBarVisibility == "inherit"
	and exported.actionVisibility == "inherit"
	and exported.composerVisibility == "inherit",
	"Messenger regions should inherit the shared chrome behavior by default")
assert(exported.resolvedTitleBarVisibility == "always"
	and exported.resolvedActionVisibility == "always"
	and exported.resolvedComposerVisibility == "always",
	"inherit should preserve the existing always-visible Messenger by default")
assert(type(addon.GetMessengerAppearanceSettings) == "function",
	"Messenger appearance getter is unavailable")
local appearance = addon:GetMessengerAppearanceSettings()
assert(appearance.schema == 1, "Messenger appearance schema should start at 1")
assert(appearance.transparency.backgroundAlpha == 1
	and appearance.transparency.borderAlpha == 1
	and appearance.transparency.textAlpha == 1
	and appearance.transparency.overallAlpha == 1,
	"Messenger transparency should preserve the existing fully opaque appearance by default")
for _, target in ipairs(appearanceTargets) do
	assert(type(appearance.colors[target]) == "table" and appearance.colors[target].mode == "inherit",
		"Messenger " .. target .. " color should inherit from the active theme by default")
end
assert(type(exported.appearance) == "table" and exported.appearance.schema == 1,
	"Messenger settings getter omitted the appearance contract")
appearance.transparency.backgroundAlpha = 0.25
appearance.colors.window.mode = "custom"
exported.appearance.transparency.borderAlpha = 0.25
exported.appearance.colors.border.mode = "custom"
assert(settings.appearance.transparency.backgroundAlpha == 1
	and settings.appearance.transparency.borderAlpha == 1
	and settings.appearance.colors.window.mode == "inherit"
	and settings.appearance.colors.border.mode == "inherit",
	"Messenger appearance getters leaked nested SavedVariables tables")
exported.titleBarVisibility = "hidden"
assert(settings.titleBarVisibility == "inherit", "Messenger getter leaked SavedVariables")

local refreshes = 0
addon.ConversationWindows = {
	ApplySettings = function() refreshes = refreshes + 1 end,
}

assert(type(addon.SetMessengerTabNameMaxLength) == "function",
	"Messenger tab-name maximum setter is unavailable")
local ok, value = addon:SetMessengerTabNameMaxLength("20")
assert(ok and value == 20 and settings.tabNameMaxLength == 20 and refreshes == 1,
	"Messenger tab-name maximum did not accept an integer edit-box value or refresh live")
local invalidTabNameLengths = { 3, 33, 20.5, "20.5", "twenty", math.huge, -math.huge }
for _, invalid in ipairs(invalidTabNameLengths) do
	local previousRefreshes = refreshes
	local accepted, reason = addon:SetMessengerTabNameMaxLength(invalid)
	assert(not accepted and reason == "invalid-length"
		and settings.tabNameMaxLength == 20 and refreshes == previousRefreshes,
		"invalid Messenger tab-name maximum changed settings or refreshed the window")
end
local previousRefreshes = refreshes
local accepted, reason = addon:SetMessengerTabNameMaxLength(nil)
assert(not accepted and reason == "invalid-length"
	and settings.tabNameMaxLength == 20 and refreshes == previousRefreshes,
	"nil Messenger tab-name maximum changed settings or refreshed the window")
refreshes = 0

ok, value = addon:SetMessengerChromeAutoHideEnabled(true)
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
ok, value = addon:SetMessengerElementVisibility("title", "on click")
assert(ok and value == "click" and settings.titleBarVisibility == "click",
	"on-click Messenger visibility did not normalize")
ok, value = addon:SetMessengerElementVisibility("actions", "collapsed")
assert(ok and value == "collapsed" and settings.actionVisibility == "collapsed",
	"collapsed Player Actions visibility did not persist")
exported = addon:GetMessengerSettings()
assert(exported.resolvedActionVisibility == "collapsed",
	"collapsed Player Actions visibility did not resolve independently")
assert(not addon:SetMessengerElementVisibility("title", "collapsed")
	and settings.titleBarVisibility == "click",
	"collapsed visibility was accepted for the Messenger title bar")
assert(not addon:SetMessengerElementVisibility("composer", "collapsed")
	and settings.composerVisibility == "auto",
	"collapsed visibility was accepted for the Messenger reply field")
assert(not addon:SetMessengerElementVisibility("unknown", "always"),
	"unknown Messenger region was accepted")
assert(not addon:SetMessengerElementVisibility("title", "sometimes"),
	"unknown Messenger visibility mode was accepted")

ok, value = addon:SetMessengerActionButtonStyle("icon")
assert(ok and value == "icons" and settings.actionButtonStyle == "icons",
	"Messenger icon preference did not normalize")
assert(not addon:SetMessengerActionButtonStyle("pictures"),
	"invalid Messenger action style was accepted")
ok, value = addon:SetMessengerActionStripOrientation("side")
assert(ok and value == "vertical" and settings.actionStripOrientation == "vertical",
	"Messenger side action-strip alias did not normalize")
assert(not addon:SetMessengerActionStripOrientation("diagonal"),
	"invalid Messenger action-strip orientation was accepted")
ok, value = addon:SetMessengerActionStripCollapsed(true)
assert(ok and value == true and settings.actionStripCollapsed == true,
	"Messenger collapsed action-strip preference did not persist")

assert(type(addon.SetMessengerBackgroundAlpha) == "function"
	and type(addon.SetMessengerBorderAlpha) == "function"
	and type(addon.SetMessengerTextAlpha) == "function"
	and type(addon.SetMessengerOverallAlpha) == "function",
	"Messenger transparency setters are unavailable")
ok, value = addon:SetMessengerBackgroundAlpha(4)
assert(ok and value == 1 and settings.appearance.transparency.backgroundAlpha == 1,
	"Messenger background alpha did not clamp to 1")
ok, value = addon:SetMessengerBorderAlpha(-2)
assert(ok and value == 0 and settings.appearance.transparency.borderAlpha == 0,
	"Messenger border alpha did not clamp to 0")
ok, value = addon:SetMessengerTextAlpha(0.35)
assert(ok and value == 0.35 and settings.appearance.transparency.textAlpha == 0.35,
	"Messenger text alpha did not persist")
ok, value = addon:SetMessengerOverallAlpha(0.6)
assert(ok and value == 0.6 and settings.appearance.transparency.overallAlpha == 0.6,
	"Messenger overall alpha did not persist")
assert(not addon:SetMessengerOverallAlpha("opaque")
	and settings.appearance.transparency.overallAlpha == 0.6,
	"invalid Messenger alpha was accepted or changed the saved value")

assert(type(addon.SetMessengerAppearanceColor) == "function",
	"Messenger appearance color setter is unavailable")
assert(addon:SetMessengerAppearanceColor("window", "inherit")
	and settings.appearance.colors.window.mode == "inherit",
	"Messenger color setter rejected theme inheritance")
assert(addon:SetMessengerAppearanceColor("title", "accent")
	and settings.appearance.colors.title.mode == "theme"
	and settings.appearance.colors.title.theme == "accent",
	"Messenger color setter rejected a valid theme token")
assert(addon:SetMessengerAppearanceColor("chat", {
	mode = "custom",
	r = 0.2,
	g = 0.4,
	b = 0.6,
}) and settings.appearance.colors.chat.mode == "custom"
	and settings.appearance.colors.chat.r == 0.2
	and settings.appearance.colors.chat.g == 0.4
	and settings.appearance.colors.chat.b == 0.6,
	"Messenger color setter did not normalize custom RGB")
assert(not addon:SetMessengerAppearanceColor("unknown", "accent"),
	"unknown Messenger appearance color target was accepted")
assert(not addon:SetMessengerAppearanceColor("tabs", "not-a-theme-token"),
	"invalid Messenger theme token was accepted")

appearance = addon:GetMessengerAppearanceSettings()
appearance.colors.chat.r = 0.9
assert(settings.appearance.colors.chat.r == 0.2,
	"Messenger appearance getter leaked a custom color table")
assert(type(addon.ResetMessengerAppearance) == "function",
	"Messenger appearance reset is unavailable")
assert(addon:ResetMessengerAppearance())
appearance = addon:GetMessengerAppearanceSettings()
assert(appearance.transparency.backgroundAlpha == 1
	and appearance.transparency.borderAlpha == 1
	and appearance.transparency.textAlpha == 1
	and appearance.transparency.overallAlpha == 1,
	"Messenger appearance reset did not restore transparency defaults")
for _, target in ipairs(appearanceTargets) do
	assert(appearance.colors[target].mode == "inherit",
		"Messenger appearance reset did not restore the " .. target .. " color default")
end
assert(settings.actionStripCollapsed == true and settings.actionVisibility == "collapsed",
	"Messenger appearance reset changed legacy Player Actions preferences")
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
		actionStripCollapsed = true,
		actionStripOrientation = "right",
		tabNameMaxLength = "far too long",
	},
}
settings = addon:GetSmartSettings().conversations
assert(settings.titleBarVisibility == "hidden"
	and settings.actionVisibility == "auto"
	and settings.composerVisibility == "always"
	and settings.actionButtonStyle == "icons"
	and settings.actionStripCollapsed == true
	and settings.actionStripOrientation == "vertical"
	and settings.tabNameMaxLength == 14,
	"legacy/malformed Messenger visibility values were not normalized")
settings.tabNameMaxLength = 100
settings = addon:GetSmartSettings().conversations
assert(settings.tabNameMaxLength == 14,
	"out-of-range legacy Messenger tab-name maximum was not repaired to the default")
assert(settings.appearance.schema == 1
	and settings.appearance.transparency.backgroundAlpha == 1
	and settings.appearance.transparency.borderAlpha == 1
	and settings.appearance.transparency.textAlpha == 1
	and settings.appearance.transparency.overallAlpha == 1,
	"legacy Messenger profiles did not receive appearance defaults")
for _, target in ipairs(appearanceTargets) do
	assert(settings.appearance.colors[target].mode == "inherit",
		"legacy Messenger profile did not inherit the " .. target .. " color")
end

print("MessengerSettings.mock.lua: PASS")
