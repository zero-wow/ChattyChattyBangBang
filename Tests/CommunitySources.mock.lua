-- Run from addon root: lua Tests/CommunitySources.mock.lua
unpack = unpack or table.unpack
local registered, recoveryQueued = {}, 0
ChattyChattyBangBang = {
	db = { profile = { smartChat = {
		builtInSourceViewsSchema = 2,
		viewSourceMembershipSchema = 1,
		persistHistory = false,
		historyCapacity = 100,
		learnedSources = {
			["channel:trade"] = { sourceId = "channel:trade", sourceLabel = "Trade" },
		},
		viewOptions = { general = { sources = { ["community:111:3"] = false } } },
	} } },
	Print = function() end,
	ChatRecovery = { Queue = function() recoveryQueued = recoveryQueued + 1 end },
}
GetTime = function() return 1 end
time = function() return 1700000000 end
date = function() return "12:00" end
CreateFrame = function()
	return {
		SetScript = function() end,
		RegisterEvent = function(_, event) registered[event] = true; return true end,
		UnregisterAllEvents = function() end,
	}
end

dofile("Core/Settings.lua")
dofile("Core/MessageEngine.lua")
local addon = ChattyChattyBangBang
local settings = addon:GetSmartSettings()
local engine = addon.MessageEngine
engine:Initialize()
engine:SetEnabled(true)
assert(registered.CHAT_MSG_COMMUNITIES_CHANNEL,
	"current Retail Community event was not registered for capture")

local function communityArgs(text, sender, clubId, streamId, channelNumber)
	local args = { text, sender }
	args[4] = tostring(channelNumber or 1) .. ". Community:" .. clubId .. ":" .. streamId
	args[8] = channelNumber or 1
	args[9] = "Community:" .. clubId .. ":" .. streamId
	args[11] = 101
	args[18] = {}
	return args
end
local first = communityArgs("hello from stream one", "SharedName", 111, 3, 7)
local record = assert(engine:Normalize("CHAT_MSG_COMMUNITIES_CHANNEL", unpack(first, 1, 18)))
assert(record.sourceId == "community:111:3"
	and record.sourceGroup == "channels" and record.sourceLabel == "Community 111 / 3"
	and record.category == "general" and record.view == "general"
	and addon:GetDefaultViewForSource(record.sourceId) == "general",
	"Community line lost stable club/stream identity or sensible General home")
assert(settings.learnedSources["community:111:3"]
	and settings.learnedSources["channel:trade"]
	and settings.viewOptions.general.sources["community:111:3"] == false,
	"learning a Community source erased existing source settings")
assert(not engine:RecordBelongsToView(record, "general", settings),
	"saved Community source exclusion was not respected")

local shifted = communityArgs("same stream, new local number", "SharedName", 111, 3, 12)
local sameStream = assert(engine:Normalize("CHAT_MSG_COMMUNITIES_CHANNEL", unpack(shifted, 1, 18)))
local otherStream = communityArgs("other stream", "SharedName", 111, 4, 7)
local otherRecord = assert(engine:Normalize("CHAT_MSG_COMMUNITIES_CHANNEL", unpack(otherStream, 1, 18)))
assert(sameStream.sourceId == record.sourceId
	and otherRecord.sourceId == "community:111:4"
	and engine:RecordBelongsToView(otherRecord, "general", settings),
	"Community identity followed local channel number or merged separate streams")
local definitions = engine:GetSourceDefinitions()
local found = {}
for _, definition in ipairs(definitions) do found[definition.sourceId] = definition end
assert(found["community:111:3"] and found["community:111:4"]
	and found["channel:trade"] and found["community:111:3"].learned,
	"Community streams were not independently available as saved source controls")

local malformed = communityArgs("unidentified Community", "SharedName", 111, 3, 7)
malformed[9] = "Community:unknown"
local unknown = assert(engine:Normalize("CHAT_MSG_COMMUNITIES_CHANNEL", unpack(malformed, 1, 18)))
assert(unknown.sourceId == "event:chat-msg-communities-channel"
	and unknown.view == "general"
	and not settings.learnedSources["community:unknown"]
	and not settings.learnedSources[unknown.sourceId],
	"malformed Community identity was invented or readable text was dropped")
local public = assert(engine:Normalize("CHAT_MSG_CHANNEL", "public chat", "SharedName",
	nil, nil, nil, nil, nil, 7, "Community:111:3"))
assert(public.sourceId ~= record.sourceId,
	"public channel and Community stream shared a source identity")

engine:ResetForProfile()
definitions = engine:GetSourceDefinitions()
found = {}
for _, definition in ipairs(definitions) do found[definition.sourceId] = definition end
assert(found["community:111:3"] and found["community:111:4"]
	and settings.viewOptions.general.sources["community:111:3"] == false,
	"Community identities or saved source choice were lost on profile reload")

local secret = {}
canaccessvalue = function(value) return value ~= secret end
local restricted = communityArgs(secret, "SharedName", 111, 3, 7)
engine:Capture("CHAT_MSG_COMMUNITIES_CHANNEL", unpack(restricted, 1, 18))
assert(recoveryQueued == 1 and engine.count == 0,
	"restricted Community text was captured or bypassed native recovery")
local restrictedMetadata = communityArgs("text readable", "SharedName", 111, 3, 7)
restrictedMetadata[18] = secret
engine:Capture("CHAT_MSG_COMMUNITIES_CHANNEL", unpack(restrictedMetadata, 1, 18))
assert(recoveryQueued == 2 and engine.count == 0,
	"restricted Community metadata was read by the ordinary capture path")
canaccessvalue = nil
engine:Capture("CHAT_MSG_COMMUNITIES_CHANNEL", unpack(first, 1, 18))
assert(engine.count == 1 and engine:GetMessages("general")[1] == nil,
	"readable Community line ignored saved source exclusion or failed capture")
print("Community source mock tests passed")
