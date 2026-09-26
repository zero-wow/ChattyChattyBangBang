-- Run from the addon root with: lua Tests/Diagnostics.mock.lua
_G.ChattyChattyBangBangDiagnosticsDB = nil
_G.SlashCmdList = {}
_G.time = function() return 12345 end
_G.debugstack = function() return "Core/SmartDock.lua:1" end
local forwarded, activeHandler = 0, nil
_G.geterrorhandler = function() return function() forwarded = forwarded + 1 end end
_G.seterrorhandler = function(handler) activeHandler = handler end
local printed = {}
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) printed[#printed + 1] = message end }

dofile("Core/Diagnostics.lua")
local diagnostic = _G.ChattyChattyBangBangDiagnostics
assert(diagnostic.db.session == 1 and diagnostic.db.startup.stage == "diagnostics-loaded")
diagnostic:Mark("dock-build", "loading")
activeHandler("Interface/AddOns/ChattyChattyBangBang/Core/SmartDock.lua:123: failure")
assert(#diagnostic.db.entries == 1 and diagnostic.db.entries[1].stage == "dock-build")
activeHandler("Interface/AddOns/AnotherAddon/Other.lua:1: failure")
assert(#diagnostic.db.entries == 1 and forwarded == 2, "unrelated errors must not be saved")
diagnostic:PrintStatus()
assert(#printed == 2 and printed[2]:find("failure", 1, true), "diagnostic command output missing")
diagnostic.db.chatRecovery = {
	session = diagnostic.db.session, recovered = 2, pending = 1,
	unresolved = 3, fallbackFailed = true, time = 12345,
}
diagnostic:PrintStatus()
assert(#printed == 6 and printed[4]:find("2 restored, 1 waiting, 3 unresolved", 1, true)
	and printed[5]:find("SHOW BLIZZARD CHAT", 1, true),
	"diagnostic command did not explain current catch-up status and next action")
diagnostic.db.chatRecovery.session = 0
diagnostic:PrintStatus()
assert(#printed == 8, "diagnostic command reported stale recovery state from another session")

local started = false
_G.ChattyChattyBangBang = {
	IsEnabled = function() return true end,
	SetSmartChatEnabled = function(_, enabled) started = enabled; return true end,
}
_G.SlashCmdList.CCBB_START()
assert(started and diagnostic.db.startup.status == "ready", "manual activation failed")

print("Diagnostics mock tests passed")
