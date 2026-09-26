-- Saved phrase rules route public messages without executing user patterns.
ChattyChattyBangBang = {
	db = { profile = { smartChat = {} } },
	Print = function() end,
}
GetTime = function() return 100 end
time = function() return 1700000000 end
date = function() return "12:00" end
CreateFrame = function()
	return { SetScript = function() end, RegisterEvent = function() end,
		UnregisterAllEvents = function() end }
end
dofile("Core/Settings.lua")
dofile("Core/RoutePatternRules.lua")
dofile("Core/MessageEngine.lua")

local addon = ChattyChattyBangBang
local engine = addon.MessageEngine
engine:Initialize()
engine:SetEnabled(true)
local function record(text, sourceId)
	local result = {
		event = "CHAT_MSG_CHANNEL", text = text, normalized = string.lower(text),
		channel = sourceId == "channel:trade" and "Trade - Silvermoon City"
			or "General - Silvermoon City", sourceId = sourceId or "channel:general",
		sourceGroup = "public", sender = "Tester",
	}
	engine:Classify(result)
	return result
end

local screenshot = record("[Guild: Baby Wipes] is a new guild, we're 8/8 normal venomous abyss and heroic tidebound. LF healers and dps, hmu if interested")
assert(screenshot.view == "guildInvites", "guild identity did not outrank later party-role words")
assert(engine:RecordBelongsToView(screenshot, "guildInvites")
	and not engine:RecordBelongsToView(screenshot, "general"),
	"guild ad was still mirrored into General without an explicit Contents choice")
assert(addon:SetViewSourceEnabled("general", "channel:general", true)
	and engine:RecordBelongsToView(screenshot, "general"),
	"explicit General Contents choice could not mirror the guild ad")
assert(addon:SetViewSourceEnabled("general", "channel:general", nil),
	"General Contents override fixture could not be cleared")
local sample = record("Baby Wipes recruiting for raids. LF healers and DPS")
assert(sample.view == "groupFinder", "fixture needs a Group Finder misroute to correct")
assert(addon:SetMessageRouteOverride(sample, "trade"), "exact route fixture failed")
local ok, index = addon:SetMessageRoutePatternRule(sample, {
	destination = "guildInvites", sourceId = "channel:general",
	include = { "Baby Wipes", "recruiting for raids" }, exclude = { "PUG" },
})
assert(ok and index == 1, "bounded permanent phrase rule was not saved")
assert(addon:GetMessageRouteOverride(sample) == nil,
	"old exact correction continued to shadow the new phrase rule")
engine:Classify(sample)
assert(sample.view == "guildInvites" and sample.routePatternRuleIndex == 1,
	"saved phrase rule did not correct the inspected message")
local future = record("Baby Wipes recruiting for raids tomorrow; LF tanks")
assert(future.view == "guildInvites" and future.routePatternRuleIndex == 1,
	"future variant did not inherit the permanent phrase rule")
local updated, updatedIndex = addon:SetMessageRoutePatternRule(sample, {
	destination = "guildInvites", sourceId = "channel:general",
	include = { "Baby Wipes", "recruiting for raids" },
	exclude = { "PUG", "boost" },
}, 1)
assert(updated and updatedIndex == 1 and #addon:GetMessageRoutePatternRules() == 1,
	"editing an active phrase rule duplicated it instead of replacing it")
local originalReclassify = engine.ReclassifyAll
engine.ReclassifyAll = function() error("synthetic reclassification failure") end
local failed, failure = addon:SetMessageRoutePatternRule(sample, {
	destination = "trade", include = { "Baby Wipes" },
}, 1)
engine.ReclassifyAll = originalReclassify
assert(not failed and failure == "refresh-failed"
	and addon:GetMessageRoutePatternRules()[1].destination == "guildInvites",
	"failed reclassification left a half-saved permanent route rule")
assert(record("Baby Wipes recruiting for raids PUG tonight; LF healers").view ~= "guildInvites",
	"excluded phrase did not prevent overbroad redirection")
assert(record("Baby Wipes recruiting for raids; LF healers", "channel:trade").view ~= "guildInvites",
	"source-scoped rule redirected a different channel")
assert(not addon:SetMessageRoutePatternRule({ event = "CHAT_MSG_WHISPER", text = "hi" }, {
	destination = "guildInvites", include = { "hi there" },
}), "private whisper was accepted as a public rule sample")
assert(addon:RemoveMessageRoutePatternRule(1), "permanent phrase rule could not be removed")
engine:Classify(future)
assert(future.view == "groupFinder" and not future.routePatternRuleIndex,
	"undo did not restore ordinary semantic routing")
print("Message pattern route integration mock passed")
