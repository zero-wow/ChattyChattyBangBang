-- Focused no-client contract for Shift > ANALYZE > MOVE. Run from the addon
-- root with: lua Tests/SmartDockMessageRouteMove.mock.lua
--
-- Settings rebuilds SmartDock synchronously while the click handler is still
-- running. RebuildActiveView closes the inspector and clears analysisRecord;
-- the handler must retain the selected record across that boundary.

ChattyChattyBangBang = {
	Theme = {},
	Presentation = {},
}

dofile("Core/SmartDock.lua")

local addon = ChattyChattyBangBang
local dock = addon.SmartDock
local selected = {
	id = 17,
	event = "CHAT_MSG_CHANNEL",
	text = "WTS rare mount",
}
local savedRecord, savedCategory
local rebuilds, reopened = 0, 0

dock.analysisRecord = selected
dock.analysisRouteDestination = "trade"
dock.analysisFootnote = {
	SetText = function(self, value)
		self.value = value
	end,
}
dock.RebuildActiveView = function(self)
	rebuilds = rebuilds + 1
	-- This is the relevant first action of the real RebuildActiveView path.
	self:HideMessageBlockControls()
end
dock.ShowMessageAnalysis = function(self, record)
	reopened = reopened + 1
	self.analysisRecord = record
	return true
end

addon.SetMessageRouteOverride = function(_, record, category)
	savedRecord = record
	savedCategory = category
	-- Mirror Settings' synchronous reclassify/rebuild callback.
	dock:RebuildActiveView()
	return true, category
end

local moved, reason = dock:MoveSelectedMessageRouteOverride()
assert(moved == true and reason == nil, "MOVE handler rejected a valid Trade destination")
assert(savedRecord == selected and savedCategory == "trade",
	"MOVE handler did not save the selected record and destination")
assert(rebuilds == 1 and reopened == 1 and dock.analysisRecord == selected,
	"MOVE handler lost the selected record when synchronous rebuild cleared analysisRecord")
assert(dock.analysisFootnote.value
	and string.find(dock.analysisFootnote.value, "Primary route moved to TRADE", 1, true)
	and string.find(dock.analysisFootnote.value, "Checked source feeds remain", 1, true)
	and string.find(dock.analysisFootnote.value, "identical public text follows this route", 1, true),
	"MOVE confirmation did not explain primary routing and additive source feeds")

-- Eight safe public destinations use a compact two-column selector. Four rows
-- need explicit 4px top/bottom gutters instead of ending on the panel border.
local menuHeight
dock.analysisRouteMenu = {
	SetHeight = function(_, value) menuHeight = value end,
}
dock.analysisRouteMenuButtons = {}
for index = 1, 8 do
	dock.analysisRouteMenuButtons[index] = {
		SetLabel = function() end,
		SetTheme = function() end,
		Show = function(self) self.shown = true end,
		Hide = function(self) self.shown = false end,
	}
end
dock.GetMessageRouteOverrideDestinations = function()
	return {
		{ id = "general", label = "GENERAL" },
		{ id = "groupFinder", label = "GROUP FINDER" },
		{ id = "guildInvites", label = "GUILD INVITES" },
		{ id = "pvp", label = "PVP" },
		{ id = "trade", label = "TRADE" },
		{ id = "newcomers", label = "NEWCOMERS" },
		{ id = "system", label = "SYSTEM" },
		{ id = "loot", label = "LOOT" },
	}
end
dock.analysisRouteDestination = "pvp"
assert(dock:RefreshMessageRouteOverrideMenu() and menuHeight == 86,
	"eight-route MOVE selector lost its two-column four-row gutter budget")
for index = 1, 8 do
	assert(dock.analysisRouteMenuButtons[index].shown,
		"MOVE selector did not expose destination " .. index)
end

print("SmartDock message route move mock passed")
