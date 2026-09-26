-- Run from the Retail addon root: lua Tests/ConfigKeyboardEntry.mock.lua
dofile("Tests/ConfigViewport.mock.lua")
local addon = ChattyChattyBangBang
local config = addon.CustomConfig
local savedMode, modeWrites = "simple", 0
addon.GetConfigMode = function() return savedMode end
addon.SetConfigMode = function(_, mode) savedMode = mode; modeWrites = modeWrites + 1 end
assert(config.headerKeyboardHint:GetStringWidth() <= config.headerKeyboardHint:GetWidth()
	and config.headerKeyboardHint.point[4] == -50
	and config.closeButton.point[4] == -8,
	"700x500 header keyboard hint clips or touches the close target")
local hint = config.headerKeyboardHint
hint.GetStringWidth = function(self) return #self:GetText() * 11 end
config:FitKeywordScopeText(hint, "/ccbb tabs", 120)
assert(hint:GetStringWidth() <= 120 and hint:GetText() == "/ccbb tabs",
	"wide-font header hint clipped the keyboard command")
local headerWidth, titleLeft, hintLeft = 640, 46, 640 - 50 - 128
assert(titleLeft + #config.headerTitle:GetText() * 12 + 12 <= hintLeft
	and titleLeft + #config.headerSubtitle:GetText() * 12 + 12 <= hintLeft
	and hintLeft + 128 + 12 <= headerWidth - 8 - 30,
	"700x500 wide-font header title, subtitle, hint, or close button lost a gutter")

assert(not config:OpenKeyboardTabs("not-a-page") and modeWrites == 0,
	"bad keyboard-entry page changed settings or opened the editor")
assert(config:OpenKeyboardTabs("dock") and config.activePage == "dock"
	and config.keyboardTabFocus and config.keyboardTabFocus.keyboardFocusVisible
	and config.frame.keyboardEnabled,
	"explicit keyboard entry did not focus a visible Chat Window tab")
assert(config:GetMode() == "advanced" and savedMode == "simple" and modeWrites == 0,
	"keyboard entry changed the saved Simple/Advanced preference")
config.frame:Hide()
assert(config.keyboardTabSessionAdvanced == nil and config:GetMode() == "simple"
	and config.keyboardTabFocus == nil and not config.frame.keyboardEnabled,
	"closing keyboard entry failed to restore saved Simple mode and game input")
local propagation = config.frame.SetPropagateKeyboardInput
config.frame.SetPropagateKeyboardInput = false
assert(not config:OpenKeyboardTabs("dock") and not config.frame.keyboardEnabled
	and savedMode == "simple" and modeWrites == 0,
	"unsupported keyboard propagation trapped a key or changed saved mode")
config.frame.SetPropagateKeyboardInput = propagation
config.frame:Hide()

local sourceFile = assert(io.open("ChattyChattyBangBang.lua", "rb"))
local source = sourceFile:read("*a")
sourceFile:close()
assert(source:find('RegisterChatCommand("ccbb", "OpenConfig")', 1, true)
	and source:find('RegisterChatCommand("ChattyChattyBangBang", "OpenConfig")', 1, true),
	"short slash command replaced or failed to accompany the established long command")
local commandFunction = source:match("(function ChattyChattyBangBang:OpenConfig%(input%).-)function ChattyChattyBangBang:WhisperGuardCommand")
assert(commandFunction and (loadstring or load)(commandFunction))()
local dispatched
config.OpenKeyboardTabs = function(_, page) dispatched = page; return true end
assert(addon:OpenConfig("tabs views") and dispatched == "views",
	"/ccbb tabs did not dispatch its optional page to the keyboard-entry path")
print("Config keyboard-entry mock passed")
