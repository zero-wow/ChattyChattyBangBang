-- Explicit route-review reports are bounded SavedVariables data, not an
-- automatically written or transmitted log. Run: lua Tests/RouteReview.mock.lua

local now = 100
ChattyChattyBangBang = {
	db = { profile = { smartChat = { persistHistory = true, historyCapacity = 100 } } },
	Print = function() end,
}
GetTime = function() return now end
time = function() return 1700000000 + now end
date = function() return "12:00" end
CreateFrame = function()
	return {
		SetScript = function(self, name, callback) self[name] = callback end,
		RegisterEvent = function() return true end,
		UnregisterAllEvents = function() end,
	}
end

dofile("Core/Settings.lua")
dofile("Core/MessageEngine.lua")
dofile("Core/RouteReview.lua")

local addon = ChattyChattyBangBang
local engine = addon.MessageEngine
engine:Initialize()

local function channel(text)
	now = now + 1
	return engine:Deliver(assert(engine:Normalize("CHAT_MSG_CHANNEL", text,
		"Seller", nil, "General", nil, nil, nil, 1, "General")))
end

local public = channel("|cffff0000WTS|r [Sword] 500g")
local ok, report = addon:ReportMessageRoute(public, "trade")
assert(ok and report.id == "review-1" and report.sessionId
	and report.recordEpoch == public.epoch and report.historySequence == public.historySequence,
	"public report lost its stable identity or captured chronology")
assert(report.publicSnapshot and report.publicText == "|cffff0000WTS|r [Sword] 500g"
	and report.sender == "Seller" and report.channel == "General"
	and report.currentView == public.view and report.captureRouteView == public.captureRouteView
	and report.expectedRoute == "trade" and report.semantic.scores.trade ~= nil,
	"public report lost exact safe evidence or route analysis")
assert(#report.reasons > 0 and #report.signals > 0,
	"public report did not capture classifier rationale")
assert(addon:ReportMessageRoute(public) == false,
	"same message generated a duplicate review")
local revised, revisedReport = addon:ReportMessageRoute(public, "groupFinder")
assert(revised and revisedReport.id == report.id and revisedReport.expectedRoute == "groupFinder"
	and #addon:GetMessageRouteReviews() == 1,
	"a later explicit expected route failed to update the existing review")
assert(#addon:GetMessageRouteReviews() == 1 and addon:GetSmartSettings().messageRouteReviews.nextId == 2,
	"duplicate advanced the queue")
report.semantic.scores.trade = 999
assert(addon:GetMessageRouteReviews()[1].semantic.scores.trade ~= 999,
	"UI copy could mutate SavedVariables evidence")

local whisper = engine:Deliver(assert(engine:Normalize("CHAT_MSG_WHISPER",
	"private whisper token", "PrivateSender")))
assert(addon:ReportMessageRoute(whisper))
local private = addon:GetMessageRouteReviews()[2]
assert(not private.publicSnapshot and private.snapshotOmitted == "non-public-message"
	and private.publicText == nil and private.sender == nil and private.channel == nil
	and private.reasons == nil and private.signals == nil and private.semantic == nil,
	"private message leaked body, sender, or derived evidence")

local addonLine = engine:NormalizeAddon("TEST", "private-addon-token", "PARTY", "AddonSender")
engine:Classify(addonLine)
engine:Deliver(addonLine)
assert(addon:ReportMessageRoute(addonLine))
local addonReport = addon:GetMessageRouteReviews()[3]
assert(addonReport.publicText == nil and addonReport.sender == nil
	and addonReport.semantic == nil and addonReport.event == "CHAT_MSG_ADDON",
	"add-on payload or sender leaked into route report")

-- A profile reload may assign a new runtime ID, but the original history
-- sequence still identifies a previously reported message.
engine:ResetForProfile()
local restored = engine:GetMessages()[1]
assert(restored and restored.historySequence == public.historySequence)
assert(addon:ReportMessageRoute(restored) == false,
	"SavedVariables restore allowed a duplicate route report")

for index = 1, 55 do
	assert(addon:ReportMessageRoute(channel("new public example " .. index)))
end
local reviews, note = addon:GetMessageRouteReviews()
assert(#reviews == 50 and reviews[1].id == "review-9" and reviews[50].id == "review-58",
	"review queue did not retain only the latest 50 stable IDs")
assert(type(note) == "string" and note:find("/reload", 1, true)
	and note:find("not sent automatically", 1, true),
	"SavedVariables flush and no-send notice missing")
assert(addon:ClearMessageRouteReviews() and #addon:GetMessageRouteReviews() == 0,
	"explicit clear did not remove saved reports")
assert(addon:GetSmartSettings().messageRouteReviews.nextId == 59,
	"clearing reused a prior stable report ID")
assert(not addon:ReportMessageRoute(public, "not-a-route")
	and #addon:GetMessageRouteReviews() == 0,
	"invalid expected route changed the queue")
local long = channel(string.rep("x", 600) .. "\nsecond line")
local saved, bounded = addon:ReportMessageRoute(long)
assert(saved and #bounded.publicText == 512 and bounded.publicTextTruncated
	and not string.find(bounded.publicText, "\n", 1, true),
	"public snapshot exceeded its cap or retained a control newline")

print("Route review mock passed")
