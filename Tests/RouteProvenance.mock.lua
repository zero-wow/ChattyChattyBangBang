-- Capture-route provenance survives rule changes and SavedVariables restore.
-- Run from the Retail addon root: lua Tests/RouteProvenance.mock.lua
dofile("Tests/ChatHistory.mock.lua")

local addon = ChattyChattyBangBang
local engine = addon.MessageEngine
local settings = addon:GetSmartSettings()
settings.persistHistory = true
settings.historyCapacity = 100
engine:ClearHistory()

local tradeEnabled = true
addon.GetSemanticRouteEnabled = function(_, routeId)
	return routeId ~= "trade" or tradeEnabled
end
local record = assert(engine:Normalize("CHAT_MSG_CHANNEL", "WTS [Sword] 500g",
	"Seller", nil, "General", nil, nil, nil, 1, "General", nil, 501, "Player-1-PROVENANCE"))
assert(record.view == "trade" and record.captureRouteView == "trade"
	and record.captureRouteCategory == "trade" and record.captureRouteReason == "semantic",
	"initial General sale did not snapshot its Trade semantic route")
engine:Deliver(record)

tradeEnabled = false
assert(engine:ReclassifyAll() == 1 and record.view == "general"
	and record.captureRouteView == "trade" and record.captureRouteReason == "semantic",
	"reclassification rewrote the route used when the message was captured")
local analysis = assert(engine:AnalyzeRecord(record))
assert(analysis.view == "general" and analysis.captureRouteView == "trade"
	and analysis.captureRouteReason == "semantic",
	"analysis did not distinguish the saved capture route from current classification")

engine:ResetForProfile()
local restored = engine:GetMessages()[1]
assert(restored and restored.view == "general" and restored.captureRouteView == "trade"
	and restored.captureRouteCategory == "trade" and restored.captureRouteReason == "semantic",
	"SavedVariables restore lost capture provenance or failed to reclassify current routing")
tradeEnabled = true
engine:ReclassifyAll()
assert(restored.view == "trade" and restored.captureRouteView == "trade",
	"later rule changes did not preserve the original capture snapshot")

-- Existing saved histories have no provenance. Never present a newly computed
-- route as though it were known to be the original capture decision.
for _, ring in pairs(settings.history.sources) do
	for _, saved in pairs(ring.records) do
		saved.captureRouteCategory = nil
		saved.captureRouteView = nil
		saved.captureRouteReason = nil
	end
end
engine:ResetForProfile()
local legacy = engine:GetMessages()[1]
assert(legacy and legacy.view == "trade" and legacy.captureRouteView == nil,
	"legacy history fabricated a capture route during restore")
engine:ReclassifyAll()
assert(legacy.captureRouteView == nil and engine:AnalyzeRecord(legacy).captureRouteView == nil,
	"legacy capture route became falsely known during later reclassification")

print("Route provenance mock passed")
