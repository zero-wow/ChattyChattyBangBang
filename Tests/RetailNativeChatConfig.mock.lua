-- Focused no-client contract for the Retail native-chat visibility choice.
-- Run from the addon root with: lua Tests/RetailNativeChatConfig.mock.lua

local file = assert(io.open("Core/Config.lua", "rb"))
local source = file:read("*a")
file:close()

assert(source:find('"HIDE BLIZZARD CHAT"', 1, true), "native-chat choice is missing from Chat Window")
assert(source:find('self.dockHideNativeChatToggle, nativeChatWarning,', 1, true),
	"native-chat choice or warning is missing from the Window inspector group")
assert(source:find('self.dockHideNativeChatToggle:SetValue(dock.hideNativeChat == true, true)', 1, true),
	"native-chat choice does not reflect the saved setting")
assert(source:find('Retail may mark chat secret during lockdown.', 1, true),
	"Retail secret-message risk is not explained next to the choice")

local addon = { Theme = {} }
ChattyChattyBangBang = addon
dofile("Core/Config.lua")

local function getUpvalue(owner, expected)
	for index = 1, 100 do
		local name, value = debug.getupvalue(owner, index)
		if not name then break end
		if name == expected then return value end
	end
end
local applyDockRuntime = getUpvalue(addon.CustomConfig.BuildDockPage, "applyDockRuntime")
assert(type(applyDockRuntime) == "function", "native-chat runtime applier is unavailable")

local dock = { active = true, frame = { IsShown = function() return true end }, syncCount = 0 }
function dock:SyncNativeChatVisibility() self.syncCount = self.syncCount + 1 end
function dock:HideNativeChat() self.hideCount = (self.hideCount or 0) + 1 end
function dock:RestoreNativeChat() self.restoreCount = (self.restoreCount or 0) + 1 end
addon.SmartDock = dock

applyDockRuntime("nativeChat", true)
applyDockRuntime("nativeChat", false)
assert(dock.syncCount == 2 and not dock.hideCount and not dock.restoreCount,
	"native-chat choice bypassed SmartDock's visibility/safety arbiter")

dock.SyncNativeChatVisibility = nil
applyDockRuntime("nativeChat", true)
assert(dock.hideCount == 1, "visible dock did not apply the native-chat preference")
applyDockRuntime("nativeChat", false)
assert(dock.restoreCount == 1, "disabling the preference did not restore native chat")
dock.active = false
applyDockRuntime("nativeChat", true)
assert(dock.hideCount == 1, "inactive Chatty hid Blizzard chat")

-- Retail treats the fifth color parameter as numeric alpha, not legacy wrap.
-- These are the two tooltip paths that produced in-game SetText errors.
GameTooltip = {
	SetOwner = function() end,
	SetText = function(_, _, _, _, _, alpha, wrap)
		assert(type(alpha) == "number" and type(wrap) == "boolean",
			"tooltip title passed wrap in the numeric alpha slot")
	end,
	AddLine = function(_, _, _, _, _, alpha, wrap)
		assert(type(alpha) == "number" and type(wrap) == "boolean",
			"tooltip body passed wrap in the numeric alpha slot")
	end,
	Show = function() end,
	Hide = function() end,
}
local setControlTooltip = getUpvalue(addon.CustomConfig.BuildDockPage, "setControlTooltip")
assert(type(setControlTooltip) == "function", "config tooltip helper is unavailable")
local control = { scripts = {} }
function control:HookScript(event, callback) self.scripts[event] = callback end
setControlTooltip(control, "Title", "Body")
control.scripts.OnEnter(control)

local function frame()
	local widget = { scripts = {} }
	function widget:SetSize() end
	function widget:EnableMouse() end
	function widget:CreateTexture() return frame() end
	function widget:SetAllPoints() end
	function widget:Hide() end
	function widget:SetPoint() end
	function widget:SetWidth() end
	function widget:SetJustifyH() end
	function widget:SetText() end
	function widget:SetScript(event, callback) self.scripts[event] = callback end
	return widget
end
CreateFrame = function() return frame() end
function addon.Theme:CreateText() return frame() end
local createNavigationRow = getUpvalue(addon.CustomConfig.BuildFrame, "createNavigationRow")
assert(type(createNavigationRow) == "function", "config navigation helper is unavailable")
local row = createNavigationRow({}, "Semantic routes", "Open semantic routes")
row.scripts.OnEnter(row)

print("Retail native chat config mock passed")
