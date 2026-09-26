-- Run from the addon root: lua Tests/ConversationHistoryIndex.mock.lua
dofile("Tests/ChatHistory.mock.lua")

local addon = ChattyChattyBangBang
local engine = addon.MessageEngine
local settings = addon:GetSmartSettings()
local function expect(value, message)
	if not value then error(message, 2) end
end

settings.persistHistory = false
settings.historyCapacity = 450
engine:ResetForProfile()

local nextId = 0
local function add(event, sender, sourceId, text, accountId, target, view)
	nextId = nextId + 1
	view = view or "conversations"
	local record = {
		id = nextId, event = event, sender = sender, target = target,
		text = text or tostring(nextId), sourceId = sourceId,
		isBNet = accountId ~= nil, bnetAccountId = accountId,
		view = view, views = { [view] = true },
	}
	engine:Store(record)
	return record
end

for index = 1, 425 do
	add("CHAT_MSG_WHISPER", "Archive", "conversation:incoming", "archive " .. index)
	if index <= 70 then
		add("CHAT_MSG_WHISPER", "Other", "conversation:other", "other " .. index)
	end
end
local key = "archive"
expect(engine:GetConversationCount(key) == 425 and engine:GetConversationCount("other") == 70,
	"partner counts leaked across interleaved source records")
local newest, total, anchor = engine:GetConversationPage(key, 1, 200)
expect(total == 425 and #newest == 200 and newest[1].text == "archive 226"
	and newest[200].text == "archive 425", "newest page or anchor was wrong")
local middle = engine:GetConversationPage(key, 2, 200, anchor)
local oldest = engine:GetConversationPage(key, 3, 200, anchor)
expect(#middle == 200 and middle[1].text == "archive 26"
	and middle[200].text == "archive 225" and #oldest == 25
	and oldest[1].text == "archive 1" and oldest[25].text == "archive 25",
	"ranked older pages were incomplete or out of order")

for index = 426, 435 do
	add("CHAT_MSG_WHISPER", "Archive", "conversation:incoming", "archive " .. index)
end
expect(engine:GetConversationCount(key) == 435 and engine:GetConversationCount(key, anchor) == 425,
	"frozen page counted arrivals newer than its anchor")
newest = engine:GetConversationPage(key, 1, 200, anchor)
expect(newest[1].text == "archive 226" and newest[200].text == "archive 425",
	"new arrivals shifted a frozen Messenger page")

-- The source ring can remove an arbitrary middle entry from the partner
-- index: incoming and outgoing whisper sources have independent caps.
for index = 1, 300 do
	add("CHAT_MSG_WHISPER_INFORM", "Archive", "conversation:outgoing", "outgoing " .. index)
end
settings.historyCapacity = 100
engine:PruneHistoryToSourceLimit(100)
local reference = {}
for _, record in ipairs(engine:GetMessages()) do
	if engine:GetConversationKey(record) == key then reference[#reference + 1] = record end
end
expect(#reference == 200 and engine:GetConversationCount(key) == #reference,
	"source-cap pruning left stale partner counts")
newest, total = engine:GetConversationPage(key, 1, 200)
expect(total == #reference and #newest == #reference,
	"source-cap pruning advertised an empty or duplicate page")
for index = 1, #reference do
	expect(newest[index] == reference[index], "partner index ordering diverged from canonical history")
end
settings.viewOptions = {
	conversations = { sources = { ["conversation:outgoing"] = false } },
}
local previousAllowed = addon.IsRecordAllowedInView
addon.IsRecordAllowedInView = function(_, viewId, record)
	local options = settings.viewOptions[viewId]
	return not (options and options.sources and options.sources[record.sourceId] == false)
end
local incomingOnly, incomingTotal = engine:GetConversationPage(key, 1, 200)
expect(incomingTotal == 100 and #incomingOnly == 100
	and incomingOnly[1].text == "archive 336"
	and incomingOnly[100].text == "archive 435",
	"explicit Conversations source exclusion was ignored by indexed paging")
settings.viewOptions = {}
addon.IsRecordAllowedInView = previousAllowed

addon.BlockControl.ShouldBlock = function(_, record)
	return record.text == "outgoing 250", "rule", { id = "test" }
end
expect(engine:ReapplyBlockRules() == 1 and engine:GetConversationCount(key) == 199,
	"retroactive block did not remove the partner's indexed entry")
addon.BlockControl.ShouldBlock = function() return false end
local retainedBeforeAnchor = 0
for _, record in ipairs(engine:GetMessages()) do
	if engine:GetConversationKey(record) == key and record.id <= anchor then
		retainedBeforeAnchor = retainedBeforeAnchor + 1
	end
end
expect(engine:GetConversationCount(key, anchor) == retainedBeforeAnchor,
	"frozen anchor counted evicted or retrospectively blocked records")

-- Battle.net accounts never collapse into a same-name character or into one
-- another, including numeric IDs provided as strings.
local bnA = add("CHAT_MSG_BN_WHISPER", "SharedName", "conversation:bnet", "a", "517")
add("CHAT_MSG_BN_WHISPER", "SharedName", "conversation:bnet", "b", "518")
add("CHAT_MSG_WHISPER", "SharedName", "conversation:character", "c")
expect(engine:GetConversationKey(bnA) == "bnet:517"
	and engine:GetConversationCount("bnet:517") == 1
	and engine:GetConversationCount("bnet:518") == 1
	and engine:GetConversationCount("sharedname") == 1,
	"Battle.net partner identity merged with another account or character")
expect(engine:GetConversationKey({ event = "CHAT_MSG_WHISPER_INFORM", sender = "",
		target = "  |cffffffffLinked-Realm|r  " }) == "linked-realm",
	"target fallback or color markup changed Messenger's partner key")

local oldGetMessages = engine.GetMessages
engine.GetMessages = function() error("page query fell back to a full-history scan") end
local indexedPage, indexedTotal = engine:GetConversationPage(key, 1, 200)
expect(#indexedPage == indexedTotal and indexedTotal == 199,
	"page query depended on the full-history view")
engine.GetMessages = oldGetMessages
settings.persistHistory = true
engine:RebuildPersistence()
engine:ResetForProfile()
local restoredArchive = 0
for _, record in ipairs(engine:GetMessages()) do
	if engine:GetConversationKey(record) == key then restoredArchive = restoredArchive + 1 end
end
expect(engine:GetConversationCount(key) == restoredArchive
	and restoredArchive == 99 -- restored incoming/outgoing share the canonical 100-line source
	and engine:GetConversationCount("bnet:517") == 1
	and engine:GetConversationCount("bnet:518") == 1,
	"SavedVariables restore failed to rebuild partner indexes")
engine:ClearHistory()
expect(engine:GetConversationCount(key) == 0
	and #engine:GetConversationPage(key, 1, 200) == 0,
	"clear history retained conversation index entries")

-- If a provider moves a whisper's primary view, the partner index must not
-- override the same membership rules used by GetMessages("conversations").
add("CHAT_MSG_WHISPER", "Rerouted", "conversation:rerouted", "moved", nil, nil, "trade")
expect(engine:GetConversationCount("rerouted") == 0
	and #engine:GetConversationPage("rerouted", 1, 200) == 0,
	"indexed Messenger included a whisper excluded by its view membership")
addon.IsRecordIncludedBySource = function(_, viewId, record)
	return viewId == "conversations" and record.sourceId == "conversation:rerouted"
end
expect(engine:GetConversationCount("rerouted") == 1
	and #engine:GetConversationPage("rerouted", 1, 200) == 1,
	"indexed Messenger ignored an explicit source mirror")
addon.IsRecordIncludedBySource = nil
engine:ReclassifyAll()
expect(engine:GetConversationCount("rerouted") == 1,
	"reclassification failed to refresh indexed view membership")

print("ConversationHistoryIndex.mock.lua: PASS")
