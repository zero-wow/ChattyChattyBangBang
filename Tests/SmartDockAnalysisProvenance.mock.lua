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
dock.analysisWhy = widget()
dock.analysisWhy.analysisHit = {}
dock.analysisFootnote = widget()
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

print("SmartDock analysis provenance mock passed")
