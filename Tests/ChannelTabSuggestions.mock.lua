-- Run from addon root: lua Tests/ChannelTabSuggestions.mock.lua
unpack = unpack or table.unpack
ChattyChattyBangBang = {
	db = { profile = { smartChat = {
		builtInSourceViewsSchema = 2,
		viewSourceMembershipSchema = 1,
		persistHistory = false,
		learnedSources = {},
	} } },
	Print = function() end,
}
GetTime = function() return 1 end
time = function() return 1700000000 end
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
local originalViews = #addon:GetSmartViews()

local public = assert(engine:Normalize("CHAT_MSG_CHANNEL", "ordinary public text", "Speaker",
	nil, nil, nil, nil, nil, 4, "4. CraftingHub"))
assert(public.sourceId == "channel:craftinghub" and public.view == "general",
	"unfamiliar public channel did not keep its normal General home")
local stock = assert(engine:Normalize("CHAT_MSG_CHANNEL", "ordinary General text", "Speaker",
	nil, nil, nil, nil, nil, 1, "1. General"))
assert(stock.sourceId == "channel:general", "stock public channel source changed")
local communityArgs = { "community text", "Speaker" }
communityArgs[4] = "7. Community:111:3"
communityArgs[8] = 7
communityArgs[9] = "Community:111:3"
communityArgs[11] = 101
communityArgs[18] = {}
local community = assert(engine:Normalize("CHAT_MSG_COMMUNITIES_CHANNEL", unpack(communityArgs, 1, 18)))
assert(community.sourceId == "community:111:3", "Community stream lost stable identity")
assert(#addon:GetSmartViews() == originalViews and not settings.channelTabDecisions[public.sourceId],
	"learning a channel silently created a tab or decision")

local suggestions = addon:GetChannelTabSuggestions()
assert(#suggestions == 2 and suggestions[1].state == "new" and suggestions[2].state == "new",
	"new public/Community channels were not suggested separately")
for _, suggestion in ipairs(suggestions) do
	assert(suggestion.sourceId ~= stock.sourceId, "stock General was incorrectly suggested")
end
assert(engine:RecordBelongsToView(public, "general", settings),
	"suggestion alone removed the line from General")

assert(addon:IgnoreChannelTabSuggestion(community.sourceId), "ignore choice was rejected")
assert(settings.channelTabDecisions[community.sourceId] == "ignored"
	and #addon:GetSmartViews() == originalViews,
	"ignoring a suggestion created a tab or failed to persist")
suggestions = addon:GetChannelTabSuggestions()
assert(suggestions[2].state == "ignored", "ignored channel was not distinguishable")

local view = assert(addon:AcceptChannelTabSuggestion(public.sourceId))
assert(view.custom and #view.terms == 0 and settings.viewOptions[view.id].sources[public.sourceId] == true,
	"accepted channel did not create a source-only tab")
assert(settings.channelTabDecisions[public.sourceId] == view.id
	and #addon:GetSmartViews() == originalViews + 1,
	"accepted suggestion did not persist a single view")
assert(engine:RecordBelongsToView(public, view.id, settings)
	and engine:RecordBelongsToView(public, "general", settings),
	"accepted tab moved the old line out of its original view")
assert(not addon:AcceptChannelTabSuggestion(public.sourceId), "duplicate channel tab was allowed")

engine:ResetForProfile()
suggestions = addon:GetChannelTabSuggestions()
local byId = {}
for _, suggestion in ipairs(suggestions) do byId[suggestion.sourceId] = suggestion end
assert(byId[public.sourceId].state == "added" and byId[public.sourceId].viewId == view.id
	and byId[community.sourceId].state == "ignored",
	"accept/ignore decisions did not survive profile reinitialization")
assert(not addon:IgnoreChannelTabSuggestion(public.sourceId),
	"ignoring an already-added tab should not silently delete it")
assert(not addon:AcceptChannelTabSuggestion("community:unknown"),
	"invented or unstable Community identity created a tab")
assert(addon:DeleteCustomView(view.id), "suggested tab could not be removed")
assert(settings.channelTabDecisions[public.sourceId] == "ignored"
	and not engine:RecordBelongsToView(public, view.id, settings)
	and engine:RecordBelongsToView(public, "general", settings),
	"deleting a suggested tab recreated its prompt or erased original chat")

print("Channel tab suggestion mock passed")
