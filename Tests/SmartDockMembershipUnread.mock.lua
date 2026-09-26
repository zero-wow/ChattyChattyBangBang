-- No-client integration: retained membership and live unread badges agree.
-- Run from addon root: lua Tests/SmartDockMembershipUnread.mock.lua

unpack = unpack or table.unpack
local now = 100
GetTime = function() return now end
time = function() return 1700000000 + now end
date = function() return "12:00" end
CreateFrame = function()
	return {
		SetScript = function(self, name, callback) self[name] = callback end,
		RegisterEvent = function() end,
		UnregisterAllEvents = function() end,
	}
end

ChattyChattyBangBang = {
	db = { profile = { smartChat = { persistHistory = false } } },
	Print = function() end,
}
dofile("Core/Settings.lua")
dofile("Core/MessageEngine.lua")
dofile("Core/SmartDock.lua")

local addon = ChattyChattyBangBang
local settings = addon:GetSmartSettings()
local engine = addon.MessageEngine
engine:Initialize()
local mirror = assert(addon:CreateCustomView({
	label = "Heroic offers", key = "HERO", terms = { "heroic" }, enabled = true,
}))
local dock = addon.SmartDock
dock.active = true
dock.activeView = "system" -- none of the fixtures belong to the open tab
dock.railButtons = { general = {}, trade = {}, [mirror.id] = {} }
dock.unread = { general = 0, trade = 0, [mirror.id] = 0 }
dock.RefreshRailState = function() end

local function captureOffer(sender)
	now = now + 1
	local record = assert(engine:Capture("CHAT_MSG_CHANNEL", "-WTS- heroic run 325K",
		sender, nil, "9. Ascension", nil, nil, nil, 9, "Ascension"))
	assert(record.view == "trade", "offer fixture did not route to Trade")
	dock:OnMessage(record)
	return record
end

local first = captureOffer("SellerOne")
assert(#engine:GetMessages("general") == 0
	and engine:GetMessages("trade")[1] == first
	and engine:GetMessages(mirror.id)[1] == first,
	"classifier route and custom body-term mirror disagreed with retained membership")
assert(dock.unread.general == 0 and dock.unread.trade == 1
	and dock.unread[mirror.id] == 1,
	"unread badges disagreed with Trade-only route plus custom mirror")

assert(addon:SetViewSourceEnabled("general", "channel:ascension", true),
	"explicit General Contents mirror could not be enabled")
local second = captureOffer("SellerTwo")
assert(engine:GetMessages("general")[1] == first
	and engine:GetMessages("general")[2] == second,
	"Contents mirror did not expose both retained offers in General")
assert(dock.unread.general == 1 and dock.unread.trade == 2
	and dock.unread[mirror.id] == 2,
	"new mirrored offer did not increment exactly its visible tabs")

assert(addon:SetViewSourceEnabled("general", "channel:ascension", false),
	"explicit General source exclusion could not be enabled")
local third = captureOffer("SellerThree")
assert(#engine:GetMessages("general") == 0 and dock.unread.general == 0,
	"source exclusion leaked a new offer into General or its unread badge")
assert(engine:GetMessages("trade")[3] == third and dock.unread.trade == 3,
	"source exclusion accidentally removed Trade membership")

-- A defensive block marker must suppress both retained reads and live badges,
-- even if an old/interrupted history row still carries route memberships.
local beforeUnread = dock.unread.trade
third.blockedByBlockControl = true
assert(not engine:RecordBelongsToView(third, "trade", settings)
	and not dock:IsRecordVisibleInView("trade", third, settings)
	and #engine:GetMessages("trade") == 2,
	"blocked row remained a visible Trade member")
dock:OnMessage(third)
assert(dock.unread.trade == beforeUnread,
	"blocked row incremented Trade unread")

-- Held first-contact whispers never become records at all: the guard runs
-- before normalization, retention, listeners, or any dock unread calculation.
local beforeCount = engine.count
addon.WhisperGuard = { ShouldBlockEngineEvent = function() return true end }
assert(engine:Capture("CHAT_MSG_WHISPER", "hello", "Stranger") == nil
	and engine.count == beforeCount and dock.unread.trade == beforeUnread,
	"held whisper reached normal history or changed unread")

print("SmartDock membership/unread integration mock passed")
