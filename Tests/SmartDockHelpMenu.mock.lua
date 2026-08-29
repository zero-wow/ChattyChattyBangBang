-- Focused no-client contract for Smart Dock's hover-launched help menu.
-- Run from the addon root with: lua Tests/SmartDockHelpMenu.mock.lua

local blocksAvailable = true

ChattyChattyBangBang = {
	Theme = {},
	Presentation = {},
	BlockControl = {
		IsAvailable = function()
			return blocksAvailable
		end,
	},
}

dofile("Core/SmartDock.lua")

local dock = ChattyChattyBangBang.SmartDock
local title, rows = dock:GetChatHelpPageContent(1)
assert(title == "CHAT HELP: BASICS", "first help page is not the everyday-controls page")
assert(#rows == 4 and rows[1][1] == "TABS" and rows[2][1] == "WRITE",
	"basic help rows are incomplete or out of order")
assert(string.find(rows[2][2], "SAY", 1, true), "composer route guidance is missing from chat help")
assert(string.find(rows[3][2], "SHIFT", 1, true), "block gesture guidance is missing from chat help")

title, rows = dock:GetChatHelpPageContent(2)
assert(title == "CHAT HELP: ARRANGE", "second help page is not the arrange-controls page")
assert(#rows == 4 and rows[1][1] == "ORDER" and rows[2][1] == "ALIGN",
	"arrange help rows are incomplete or out of order")
assert(string.find(rows[1][2], "SHIFT%-drag"), "tab reordering guidance is missing from chat help")
assert(string.find(rows[2][2], "Global Text", 1, true)
	and string.find(rows[2][2], "ALIGN CHANNELS", 1, true)
	and string.find(rows[2][2], "ALIGN NAMES", 1, true)
	and string.find(rows[2][2], "ALIGN SETTINGS", 1, true),
	"alignment help does not route the user to the two named Global Text controls")
assert(not string.find(rows[2][2], "tick ALIGN", 1, true),
	"alignment help still describes the removed anonymous check box")
assert(string.find(rows[3][2], "resize", 1, true), "edge-resize guidance is missing from chat help")

blocksAvailable = false
title, rows = dock:GetChatHelpPageContent(1)
assert(string.find(rows[3][2], "unavailable", 1, true),
	"help menu does not explain an unavailable Message Blocks controller")

print("SmartDock help-menu mock tests passed")
