-- Run from the addon root: lua Tests/ConversationIndexedPaging.mock.lua
dofile("Tests/ConversationWindowsLayout.mock.lua")

local addon = ChattyChattyBangBang
local manager = addon.ConversationWindows
local engine = addon.MessageEngine
local function expect(value, message)
	if not value then error(message, 2) end
end

local indexed = {}
for id = 1, 425 do
	indexed[id] = { id = id, event = "CHAT_MSG_WHISPER", sender = "Archive",
		direction = "incoming", text = "line " .. id }
end
engine.GetMessages = function() error("Messenger scanned the flat transcript") end
engine.GetConversationKey = function(_, record)
	return record.sender and string.lower(record.sender)
end
engine.GetConversationCount = function(_, key, anchor)
	if key ~= "archive" then return 0 end
	if not anchor then return #indexed end
	return math.min(#indexed, anchor)
end
engine.GetConversationPage = function(self, key, page, size, anchor)
	local records = {}
	local total = self:GetConversationCount(key, anchor)
	local last = total - (page - 1) * size
	for id = math.max(1, last - size + 1), last do
		records[#records + 1] = indexed[id]
	end
	return records, total, indexed[#indexed] and indexed[#indexed].id
end

manager:ResetForProfile()
manager:SetEnabled(true)
local session = manager:AcquireSession("Archive")
manager:SelectSession(session.playerKey)
local shell = manager:GetShell()
shell:Show()
expect(session.historyTotal == 425 and session.historyPageCount == 3
	and session.renderedIds[425] and session.renderedIds[226],
	"Messenger did not load the indexed newest page")
shell:ChangeHistoryPage(2)
expect(session.historyPage == 3 and session.renderedCount == 25
	and session.renderedIds[1] and session.renderedIds[25],
	"Messenger did not load the indexed oldest page")

shell:ChangeHistoryPage(-2)
local newRecord = { id = 426, event = "CHAT_MSG_WHISPER", sender = "Archive",
	direction = "incoming", text = "line 426" }
indexed[426] = newRecord
manager:OnMessage(newRecord)
expect(session.historyTotal == 426 and session.historyPageCount == 3
	and session.renderedIds[426],
	"live Messenger append did not use the indexed partner count")

engine.RecordBelongsToView = function(_, record)
	return record.id ~= 427
end
local excluded = { id = 427, event = "CHAT_MSG_WHISPER", sender = "Archive",
	direction = "incoming", text = "excluded by CONTENTS" }
manager:OnMessage(excluded)
expect(not session.renderedIds[427] and session.historyTotal == 426
	and (session.unread or 0) == 0,
	"excluded whisper was live-appended or counted unread in Messenger")

print("ConversationIndexedPaging.mock.lua: PASS")
