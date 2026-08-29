-- Focused no-client integration contract for Shift > ANALYZE > MOVE. Run from
-- the addon root with: lua Tests/MessageRouteMove.mock.lua
--
-- The real Settings and MessageEngine modules are loaded together here. A
-- manual correction changes the primary route, while the record remains in its
-- factual source home and any explicitly checked source feeds. Membership is
-- a read-time union: all visible copies must still be one stored record.

local now = 100

ChattyChattyBangBang = {
	db = {
		profile = {
			smartChat = {
				persistHistory = true,
				historyCapacity = 100,
			},
		},
	},
	Print = function()
		-- Listener diagnostics are outside this routing contract.
	end,
}

GetTime = function()
	return now
end
time = function()
	return 1700000000 + math.floor(now)
end
date = function()
	return "12:00"
end
CreateFrame = function()
	return {
		SetScript = function(self, name, callback)
			self[name] = callback
		end,
		RegisterEvent = function() end,
		UnregisterAllEvents = function() end,
	}
end

dofile("Core/Settings.lua")
dofile("Core/MessageEngine.lua")

local addon = ChattyChattyBangBang
local engine = addon.MessageEngine
engine:Initialize()
engine:SetEnabled(true)

local sourceView = assert(addon:CreateCustomView({
	label = "Ascension source",
	key = "AS",
	terms = { "ascension" },
	enabled = true,
}))
local bodyView = assert(addon:CreateCustomView({
	label = "Saffron body",
	key = "SB",
	terms = { "saffron" },
	enabled = true,
}))
assert(addon:SetViewSourceEnabled(sourceView.id, "channel:ascension", true),
	"custom source feed could not be enabled")

local rebuilds = 0
local lastRebuild = {}
addon.SmartDock = {
	RebuildActiveView = function()
		rebuilds = rebuilds + 1
		lastRebuild.general = #engine:GetMessages("general")
		lastRebuild.trade = #engine:GetMessages("trade")
		lastRebuild.source = #engine:GetMessages(sourceView.id)
		lastRebuild.body = #engine:GetMessages(bodyView.id)
	end,
}

local function capture(text)
	engine:Capture("CHAT_MSG_CHANNEL", text, "Tester", nil, "9. Ascension",
		nil, nil, nil, 9, "Ascension")
	now = now + 1
end

local function assertPrimaryTrade(record, detail)
	assert(record and record.view == "trade" and record.category == "trade",
		detail .. " did not use Trade as its primary route")
	assert(record.views and record.views.trade == true and record.views.general == nil,
		detail .. " retained its old built-in membership")
	assert(record.views[sourceView.id] == nil and record.views[bodyView.id] == nil,
		detail .. " retained a classifier membership despite a manual primary route")
end

local function assertSameStoredRecord(record, detail)
	local general = engine:GetMessages("general")
	local trade = engine:GetMessages("trade")
	local source = engine:GetMessages(sourceView.id)
	assert(general[#general] == record and trade[#trade] == record and source[#source] == record,
		detail .. " was copied instead of shared across additive view membership")
end

capture("Saffron memo")
local original = engine:GetMessages("general")[1]
assert(original and original.views[sourceView.id] and original.views[bodyView.id],
	"fixture did not begin in General and both matching custom views")

assert(addon:SetMessageRouteOverride(original, "trade"),
	"manual Trade correction was rejected")
assert(rebuilds == 1 and lastRebuild.general == 1 and lastRebuild.trade == 1
	and lastRebuild.source == 1 and lastRebuild.body == 0 and engine.count == 1,
	"manual move did not synchronously rebuild the primary route plus additive feeds")
assertPrimaryTrade(original, "original message")
assertSameStoredRecord(original, "original message")

-- Exact manual corrections intentionally normalize case and runs of spaces.
-- A later copy must take the same route without requiring another MOVE click.
capture("  SAFFRON   MEMO  ")
local tradeMessages = engine:GetMessages("trade")
assert(#tradeMessages == 2, "normalized future copy did not inherit the saved Trade correction")
assert(#engine:GetMessages("general") == 2 and #engine:GetMessages(sourceView.id) == 2
	and #engine:GetMessages(bodyView.id) == 0 and engine.count == 2,
	"future corrected message lost its source home/feed or duplicated storage")
assertPrimaryTrade(tradeMessages[2], "normalized future copy")
assertSameStoredRecord(tradeMessages[2], "normalized future copy")

-- Classification and memberships are derived rather than persisted. Restoring
-- source-owned history must consult the separately saved exact correction.
engine:ResetForProfile()
tradeMessages = engine:GetMessages("trade")
assert(#tradeMessages == 2 and #engine:GetMessages("general") == 2
	and #engine:GetMessages(sourceView.id) == 2 and engine.count == 2,
	"persisted history did not restore the primary route and additive source views")
for index = 1, #tradeMessages do
	assertPrimaryTrade(tradeMessages[index], "restored message " .. tostring(index))
end

-- UNDO removes only the exact manual correction. The ordinary classifier and
-- both source/body custom matches become authoritative again immediately.
assert(addon:RemoveMessageRouteOverride(tradeMessages[1]),
	"manual Trade correction could not be removed")
local generalMessages = engine:GetMessages("general")
assert(rebuilds == 2 and #generalMessages == 2 and #engine:GetMessages("trade") == 0,
	"undo did not synchronously restore the messages to General")
for index = 1, #generalMessages do
	local record = generalMessages[index]
	assert(record.views[sourceView.id] and record.views[bodyView.id],
		"undo did not restore source and body custom memberships")
end

-- Automatic semantic routing is narrower than a manual MOVE. A custom term
-- found in the body remains a useful second lens, but a term matched only from
-- the broad public-channel identity must not mirror Trade back into that rail.
capture("Saffron WTS rare mount")
tradeMessages = engine:GetMessages("trade")
local automatic = tradeMessages[#tradeMessages]
assert(automatic and automatic.routeOverrideCategory == nil and automatic.views.trade,
	"automatic Trade fixture did not use semantic routing")
assert(automatic.views[sourceView.id] == nil,
	"source-name custom match mirrored an automatic Trade message")
assert(automatic.views[bodyView.id] == true,
	"deliberate body-text custom match was lost during automatic Trade routing")
assert(engine:GetMessages("general")[3] == automatic
	and engine:GetMessages(sourceView.id)[3] == automatic
	and engine:GetMessages(bodyView.id)[3] == automatic
	and engine.count == 3,
	"semantic route did not union source home, checked feed, and body match around one record")

print("Message route move integration mock passed")
