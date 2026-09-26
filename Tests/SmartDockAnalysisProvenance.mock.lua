-- The compact Message Analysis row shows original versus current route.
-- Run from the Retail addon root: lua Tests/SmartDockAnalysisProvenance.mock.lua
ChattyChattyBangBang = { Theme = {}, Presentation = {} }
dofile("Core/SmartDock.lua")

local addon = ChattyChattyBangBang
local dock = addon.SmartDock
local function widget()
	return {
		SetText = function(self, text) self.text = text end,
		Show = function(self) self.shown = true end,
		Hide = function(self) self.shown = false end,
	}
end
dock.analysisPanel = widget()
dock.analysisSource = widget()
dock.analysisRoute = widget()
dock.analysisRoute.analysisHit = {}
dock.analysisSignals = widget()
dock.analysisSignals.analysisHit = {}
dock.analysisWhy = widget()
dock.analysisWhy.analysisHit = {}
dock.analysisFootnote = widget()
dock.analysisRemoveOverride = widget()
dock.HideDisplayHoverHint = function() end
dock.RefreshMessageAnalysisLayout = function() return true end
dock.ScheduleMessageBlockActionRefresh = function() end

local analysis = {
	category = "general", view = "general", sourceLabel = "General",
	captureRouteCategory = "trade", captureRouteView = "trade",
	captureRouteReason = "semantic", signals = {}, reasons = { "Current rule left it in General." },
}
addon.AnalyzeRecord = function() return analysis end
assert(dock:ShowMessageAnalysis({ event = "CHAT_MSG_SYSTEM" }))
assert(dock.analysisRoute.text == "THEN Trade  |  NOW General"
	and dock.analysisRoute.analysisHit.analysisFullText:find("semantic score", 1, true),
	"Message Analysis failed to distinguish captured Trade from current General")
analysis.captureRouteView = nil
analysis.captureRouteCategory = nil
analysis.captureRouteReason = nil
assert(dock:ShowMessageAnalysis({ event = "CHAT_MSG_SYSTEM" }))
assert(dock.analysisRoute.text == "THEN Unknown  |  NOW General"
	and dock.analysisRoute.analysisHit.analysisFullText:find("saved before route tracking", 1, true)
	and dock.analysisWhy.analysisHit.analysisFullText:find("Original route unavailable", 1, true),
	"older retained message should identify unknown original routing")

analysis.category, analysis.view = "guildInvites", "guildInvites"
analysis.captureRouteView = "groupFinder"
analysis.captureRouteCategory = "groupFinder"
analysis.captureRouteReason = "pattern-rule"
analysis.semantic = { isGuildAdvert = true }
analysis.routeOverrideCategory = "guildInvites" -- pattern rules also set this engine field
analysis.signals = { "GROUP FINDER SCORE 10 / 7", "LFG +4 LF", "GUILD INVITES guild identity + invitation" }
analysis.reasons = { "Guild identity and recruiting invitation appear together; later role requests describe guild needs, not a one-off group." }
addon.SetMessageRouteOverride = function() return true end
addon.GetMessageRouteOverride = function() return nil end
addon.GetMessageRoutePatternOverride = function() return "guildInvites", 2 end
assert(dock:ShowMessageAnalysis({ event = "CHAT_MSG_CHANNEL", routePatternRuleIndex = 2 }))
assert(dock.analysisSignals.text:find("Guild identity + recruiting invitation", 1, true)
	and dock.analysisSignals.analysisHit.analysisFullText:find("LFG +4 LF", 1, true)
	and dock.analysisWhy.text:find("later role requests describe guild needs", 1, true)
	and dock.analysisRoute.analysisHit.analysisFullText:find("saved phrase rule", 1, true)
	and dock.analysisFootnote.text:find("phrase rule #2", 1, true)
	and dock.analysisRemoveOverride.shown == false,
	"readable guild analysis hid the decisive evidence or the saved rule")
addon.GetMessageRouteOverride = function() return "trade" end
assert(dock:ShowMessageAnalysis({ event = "CHAT_MSG_CHANNEL", routePatternRuleIndex = 2 })
	and dock.analysisRemoveOverride.shown == true
	and dock.analysisFootnote.text:find("Exact MOVE currently wins", 1, true),
	"exact UNDO and pattern-rule UNDO were not distinguished")

print("SmartDock analysis provenance mock passed")
