-- Bounded retained-ID inbox. Run from the addon root: lua Tests/AlertInbox.mock.lua

function UnitName(unit) return unit == "player" and "Me" or nil end
function UnitGUID(unit) return unit == "player" and "Player-Me" or nil end
function GetTime() return 42 end

local settings = {
	safety = { localIgnores = {} },
	alerts = {
		enabled = true, popout = false, sound = false, sequence = 1, revision = 0,
		rules = { {
			id = "alert1", name = "Ping", enabled = true, terms = { "ping" },
			matchAll = false, wholeTerms = false, allSources = true, sources = {},
			revealDock = false, sound = false,
		} },
	},
}
local engine = { byId = {}, historyGeneration = 1 }
function engine:RegisterListener(name, callback) self.listener = callback end
ChattyChattyBangBang = { MessageEngine = engine }
function ChattyChattyBangBang:GetSmartSettings() return settings end
dofile("Core/Alerts.lua")

local inbox = ChattyChattyBangBang.AlertEngine
inbox:Initialize()
local function deliver(id, text, retained)
	local record = {
		id = id, event = "CHAT_MSG_WHISPER", sourceId = "whisper:incoming",
		sender = "Someone", guid = "Player-Other", direction = "incoming",
		text = text or "private ping body", normalized = "private ping body",
	}
	if retained ~= false then engine.byId[id] = record end
	assert(inbox:ProcessRecord(record), "expected alert match")
	return record
end

local held = deliver(1, "held private ping", false)
assert(#inbox:GetInboxRecords() == 0 and not inbox:IsInboxRecord(held),
	"held whisper entered the retained inbox")

local first = deliver(1)
for id = 2, 101 do deliver(id) end
local records = inbox:GetInboxRecords()
assert(#records == 100 and records[1].id == 101 and records[#records].id == 2,
	"inbox did not remain bounded and newest-first")
assert(not inbox:IsInboxRecord(first), "dropped oldest alert remained in the inbox")
for _, id in ipairs(inbox.inboxOrder) do
	assert(type(id) == "number", "inbox stored a record or message body")
end

engine.byId[101] = nil
assert(inbox:GetInboxRecords()[1].id == 100, "evicted alert remained visible")
engine.byId[100].blockedByBlockControl = true
assert(inbox:GetInboxRecords()[1].id == 99, "blocked alert remained visible")
engine.historyGeneration = 2
engine.byId = { [99] = { id = 99, alerts = { alert1 = true } } }
assert(not inbox:IsInboxRecord(engine.byId[99]),
	"an ID reused after history reset inherited an old inbox marker")
engine.byId = {}
assert(#inbox:GetInboxRecords() == 0, "old IDs survived history reset")
local reused = deliver(1)
assert(inbox:GetInboxRecords()[1] == reused, "reused runtime ID was not a fresh alert")
inbox:ResetForProfile()
assert(#inbox:GetInboxRecords() == 0, "profile reset retained the old inbox")

print("Alert inbox mock passed")
