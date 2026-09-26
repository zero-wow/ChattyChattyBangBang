-- Run from addon root: lua Tests/LearnedSourceRetention.mock.lua
unpack = unpack or table.unpack
local currentEpoch = 200000
local currentSessionSeconds = 1
ChattyChattyBangBang = {
	db = { profile = { smartChat = {
		builtInSourceViewsSchema = 2,
		viewSourceMembershipSchema = 1,
		persistHistory = false,
		learnedSources = {},
	} } },
	Print = function() end,
}
GetTime = function() return currentSessionSeconds end
time = function() return currentEpoch end
date = function() return "12:00" end
CreateFrame = function()
	return {
		SetScript = function() end,
		RegisterEvent = function() return true end,
		UnregisterAllEvents = function() end,
	}
end

dofile("Core/Settings.lua")
dofile("Core/MessageEngine.lua")
local addon = ChattyChattyBangBang
local engine = addon.MessageEngine
engine:Initialize()
local settings = addon:GetSmartSettings()

local function countSources(tableOfSources)
	local count = 0
	for _ in pairs(tableOfSources) do count = count + 1 end
	return count
end

local function id(number)
	return string.format("channel:source%03d", number)
end

-- An old over-cap profile is migrated by recency, preserving explicit tab
-- choices and source-fed views even when those channels were rarely seen.
settings.learnedSources = {}
for number = 1, 67 do
	settings.learnedSources[id(number)] = {
		sourceLabel = "Source " .. number,
		lastSeenAt = number * 1000,
	}
end
settings.viewOptions = { custom1 = { sources = { [id(1)] = true } } }
settings.channelTabDecisions = { [id(2)] = "custom2" }
engine:LoadLearnedSources()
assert(countSources(engine.learnedSources) == 64
	and countSources(settings.learnedSources) == 64,
	"over-cap learned sources were not bounded in memory and SavedVariables")
assert(engine.learnedSources[id(1)] and engine.learnedSources[id(2)],
	"explicitly attached or accepted channel was evicted at load")
assert(not engine.learnedSources[id(3)] and not engine.learnedSources[id(4)]
	and not engine.learnedSources[id(5)] and engine.learnedSources[id(6)],
	"load order did not prefer recently used unprotected sources")

-- Runtime usage is exact in-session; a channel seen just now survives even if
-- its durable timestamp is older than the other sources.
currentEpoch = 201000
engine:LearnSource({ event = "CHAT_MSG_CHANNEL", sourceId = id(6), sourceLabel = "Source 6" })
assert(settings.learnedSources[id(6)].lastSeenAt == currentEpoch,
	"active source did not persist its recency after the sampling interval")
currentEpoch = currentEpoch + 599
engine:LearnSource({ event = "CHAT_MSG_CHANNEL", sourceId = id(6), sourceLabel = "Source 6" })
assert(settings.learnedSources[id(6)].lastSeenAt == 201000,
	"every repeated line rewrote the persisted recency")
currentEpoch = currentEpoch + 1
engine:LearnSource({ event = "CHAT_MSG_CHANNEL", sourceId = id(6), sourceLabel = "Source 6" })
assert(settings.learnedSources[id(6)].lastSeenAt == 201600,
	"sampled recency did not advance after ten minutes")
engine:LearnSource({ event = "CHAT_MSG_CHANNEL", sourceId = id(68), sourceLabel = "Source 68" })
assert(engine.learnedSources[id(68)] and engine.learnedSources[id(6)]
	and not engine.learnedSources[id(7)],
	"new source failed to replace the least recently used unprotected source")
assert(countSources(settings.learnedSources) == 64 and not settings.learnedSources[id(7)],
	"evicted learned source remained in persistent storage")
engine:LearnSource({ event = "CHAT_MSG_CHANNEL", sourceId = id(69), sourceLabel = "Source 69" })
assert(not engine.learnedSources[id(69)] and countSources(settings.learnedSources) == 64,
	"rapid over-cap messages churned the saved source set per line")
currentSessionSeconds = currentSessionSeconds + 30
engine:LearnSource({ event = "CHAT_MSG_CHANNEL", sourceId = id(69), sourceLabel = "Source 69" })
assert(engine.learnedSources[id(69)] and countSources(settings.learnedSources) == 64,
	"a new source stayed excluded after the eviction cooldown")

-- When all available slots are explicitly used in views, a newly discovered
-- source still has its record identity, but the cache does not steal a tab's
-- source definition from the player.
settings.learnedSources = {}
settings.viewOptions = { custom1 = { sources = {} } }
settings.channelTabDecisions = {}
for number = 1, 64 do
	settings.learnedSources[id(number)] = { sourceLabel = "Protected " .. number }
	settings.viewOptions.custom1.sources[id(number)] = true
end
engine:LoadLearnedSources()
engine:LearnSource({ event = "CHAT_MSG_CHANNEL", sourceId = id(65), sourceLabel = "New" })
assert(not engine.learnedSources[id(65)] and countSources(settings.learnedSources) == 64,
	"all-protected learned source set was overwritten or allowed to grow")

-- Legacy definitions had no recency field. They migrate safely and acquire
-- a sampled time on their next actual message, not on every later message.
settings.viewOptions = {}
settings.learnedSources = {
	["channel:legacy"] = { label = "Legacy" },
	["channel:badclock"] = { sourceLabel = "Bad clock", lastSeenAt = math.huge },
}
engine:LoadLearnedSources()
assert(settings.learnedSources["channel:legacy"].lastSeenAt == 0
	and settings.learnedSources["channel:badclock"].lastSeenAt == 0,
	"legacy or invalid timestamps were not normalized safely")
engine:LearnSource({ event = "CHAT_MSG_CHANNEL", sourceId = "channel:legacy", sourceLabel = "Legacy" })
assert(settings.learnedSources["channel:legacy"].lastSeenAt == currentEpoch,
	"legacy channel failed to acquire a persisted recency sample")

print("Learned source retention mock passed")
