-- Focused no-client harness for custom-view matching. Run from the addon root
-- with: lua Tests/CustomViewRouting.mock.lua
--
-- A channel-name term must keep matching later messages whose bodies do not
-- repeat that name. This is the normal setup for a rail such as NEWCOMERS.

local now = 100
local excludeNewcomersSource = false
local manualRouteOverride
local settings = {
	enabled = true,
	historyCapacity = 150,
	persistHistory = false,
	learnedSources = {},
	customViewRevision = 1,
	channelTargets = {},
}

local customViews = {
	{
		id = "customNewcomers",
		key = "NC",
		label = "Newcomers",
		terms = { "newcomers" },
		enabled = true,
		custom = true,
	},
}

ChattyChattyBangBang = {
	GetSmartSettings = function()
		return settings
	end,
	GetSmartViews = function()
		return customViews
	end,
	IsRecordAllowedInView = function(_, viewId, record)
		return not (excludeNewcomersSource and viewId == "customNewcomers"
			and record and record.sourceId == "channel:newcomers")
	end,
	Print = function()
		-- Listener failures are not part of this routing harness.
	end,
	GetMessageRouteOverride = function(_, record)
		return manualRouteOverride and record and record.text == "Welcome to the realm."
			and manualRouteOverride or nil
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
		RegisterEvent = function()
			return true
		end,
		UnregisterAllEvents = function()
			return true
		end,
	}
end

dofile("Core/MessageEngine.lua")

local engine = ChattyChattyBangBang.MessageEngine
engine:Initialize()
engine:SetEnabled(true)

local function captureNewcomers(text)
	-- CHAT_MSG_CHANNEL: channel number is arg8 and the stable base channel name
	-- is arg9. Neither test body intentionally contains "newcomers".
	engine:Capture("CHAT_MSG_CHANNEL", text, "Tester", nil, "1. Newcomers", nil, nil, nil, 1, "Newcomers")
	now = now + 1
end

captureNewcomers("Where can I find the quest trainer?")
captureNewcomers("Welcome to the realm.")

local routed = engine:GetMessages("customNewcomers")
assert(#routed == 2, "custom channel rail stopped matching messages after its first body match")
assert(routed[1].sourceId == "channel:newcomers" and routed[2].sourceId == "channel:newcomers",
	"channel-name matching did not use the stable learned source")
local analysis = engine:AnalyzeRecord(routed[1])
assert(analysis and analysis.customViews and analysis.customViews[1] == "customNewcomers",
	"route analysis did not explain the channel-name custom membership")

-- Source-fed custom rails yield to primary semantic routes. A Trade advert
-- from Newcomers belongs only in Trade; the source identity must not mirror it
-- back into the custom Newcomers rail.
captureNewcomers("WTS [Copper Bar] 5g")
local tradeMessages = engine:GetMessages("trade")
assert(#tradeMessages == 1 and tradeMessages[1].view == "trade",
	"automatic Trade inference did not receive the Newcomers advert")
assert(#engine:GetMessages("customNewcomers") == 2,
	"source-name matching mirrored an automatic Trade route back into Newcomers")

-- A manual MOVE is exclusive even when body text itself matches a custom rule.
-- Removing the correction and reclassifying restores the normal custom match.
customViews[1].terms = { "welcome" }
settings.customViewRevision = settings.customViewRevision + 1
manualRouteOverride = "trade"
engine:ReclassifyAll()
assert(#engine:GetMessages("trade") == 2 and #engine:GetMessages("customNewcomers") == 0,
	"manual MOVE did not remove the corrected message from its custom view")
local movedAnalysis = assert(engine:AnalyzeRecord(routed[2]))
assert(movedAnalysis.routeOverrideCategory == "trade" and #movedAnalysis.customViews == 0,
	"analysis still reported a custom membership after an exclusive MOVE")
manualRouteOverride = nil
engine:ReclassifyAll()
assert(#engine:GetMessages("customNewcomers") == 1,
	"UNDO did not restore the matching custom membership")

engine:Capture("CHAT_MSG_CHANNEL", "This belongs elsewhere.", "Tester", nil, "2. Trade", nil, nil, nil, 2, "Trade")
assert(#engine:GetMessages("customNewcomers") == 1,
	"a channel-name custom rule matched an unrelated public channel")

excludeNewcomersSource = true
assert(#engine:GetMessages("customNewcomers") == 0,
	"a custom source exclusion no longer hid a matching channel record")

print("Custom view routing mock passed")
