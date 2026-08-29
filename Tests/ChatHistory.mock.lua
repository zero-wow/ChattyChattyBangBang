-- Focused no-client harness for received-message persistence. Run from the
-- addon root with: lua Tests/ChatHistory.mock.lua

local now = 100
local settings = {
	enabled = true,
	historyCapacity = 100,
	persistHistory = true,
	learnedSources = {},
	customViews = {},
	customViewRevision = 0,
	channelTargets = {},
}

ChattyChattyBangBang = {
	GetSmartSettings = function() return settings end,
	GetSmartViews = function()
		return {
			{ id = "extra", custom = true, enabled = true, terms = { "shared-multi-view" } },
			{ id = "another", custom = true, enabled = true, terms = { "shared-multi-view" } },
		}
	end,
	IsRecordAllowedInView = function() return true end,
	Print = function() end,
}

GetTime = function() return now end
time = function() return 1700000000 + now end
date = function() return "12:00" end
CreateFrame = function()
	return {
		SetScript = function(self, name, callback) self[name] = callback end,
		RegisterEvent = function() return true end,
		UnregisterAllEvents = function() return true end,
	}
end

dofile("Core/MessageEngine.lua")
local engine = ChattyChattyBangBang.MessageEngine
engine:Initialize()

local function deliverChannel(channel, number, text)
	now = now + 1
	local record = assert(engine:Normalize(
		"CHAT_MSG_CHANNEL", text, "HistoryTester", nil,
		channel, nil, nil, nil, number, channel, nil, now, "Player-1-HISTORY"
	))
	return engine:Deliver(record)
end

-- Every busy source owns its allowance. Interleaving two channels must not let
-- one evict the other's lines, and one message with several view memberships
-- must still occupy exactly one persisted source slot.
for index = 1, 115 do
	deliverChannel("General", 1, "general-" .. index)
	deliverChannel("Trade", 2, "trade-" .. index)
end
local all = engine:GetMessages()
assert(#all == 200, "per-source history did not retain 100 lines from each channel")
assert(all[1].text == "general-16" and all[2].text == "trade-16",
	"cross-source chronology or independent eviction changed")

local mirrored = deliverChannel("General", 1, "shared-multi-view-line")
assert(mirrored.views.general and mirrored.views.extra and mirrored.views.another,
	"test message was not classified into several views before persistence")
engine:RebuildPersistence()
local persisted = settings.history
assert(persisted.schema == 2 and persisted.linesPerSource == 100,
	"history did not use the per-source schema")
local persistentCount, sharedCount, sourceCount = 0, 0, 0
for _, ring in pairs(persisted.sources) do
	sourceCount = sourceCount + 1
	persistentCount = persistentCount + ring.count
	for _, record in pairs(ring.records) do
		if record.text == "shared-multi-view-line" then sharedCount = sharedCount + 1 end
	end
end
assert(sourceCount == 2 and persistentCount == 200,
	"per-source persistent rings have the wrong bounded total")
assert(sharedCount == 1, "one physical message was duplicated for its extra views")

-- Simulate login/reload against the same SavedVariables table. Restore assigns
-- fresh runtime IDs, reclassifies against current rules, and preserves the one
-- exact chronological chain used by GetMessages.
engine:ResetForProfile()
all = engine:GetMessages()
assert(#all == 200, "reload did not restore every source's retained history")
local previousSequence = 0
sharedCount = 0
for index = 1, #all do
	assert(all[index].historySequence > previousSequence,
		"restored messages are not in original cross-source order")
	previousSequence = all[index].historySequence
	if all[index].text == "shared-multi-view-line" then sharedCount = sharedCount + 1 end
end
assert(sharedCount == 1, "reload duplicated a message that belonged to several views")
assert(#engine:GetMessages("extra") == 1 and #engine:GetMessages("another") == 1,
	"current custom-view classification was not reapplied after restore")
assert(engine:GetHistoryStats().sources == 2 and engine:GetHistoryStats().lines == 200,
	"history diagnostics do not report the restored source/line counts")

-- Capacity is user-configurable over the promised range. Invalid extremes are
-- clamped without discarding retained lines when the allowance grows.
assert(engine:SetHistoryLinesPerSource(10000) == 10000,
	"10,000 lines per source is not supported")
assert(settings.historyCapacity == 10000 and #engine:GetMessages() == 200,
	"growing the source allowance discarded history")
assert(engine:SetHistoryLinesPerSource(1) == 100,
	"per-source history did not enforce its safe 100-line minimum")

-- Schema 1 was a single global ring. Its exact order must survive migration,
-- then records are redistributed once by source and current block rules apply.
settings.historyCapacity = 100
settings.history = {
	schema = 1,
	capacity = 4,
	count = 4,
	writeIndex = 1,
	records = {
		{ epoch = 1, timestamp = "00:01", event = "CHAT_MSG_CHANNEL", text = "old-general", sender = "A", channel = "General", sourceId = "channel:general", sourceGroup = "channels", sourceLabel = "General" },
		{ epoch = 2, timestamp = "00:02", event = "CHAT_MSG_CHANNEL", text = "old-trade", sender = "B", channel = "Trade", sourceId = "channel:trade", sourceGroup = "channels", sourceLabel = "Trade" },
		{ epoch = 3, timestamp = "00:03", event = "CHAT_MSG_SYSTEM", text = "BLOCK ME", sourceId = "system:message", sourceGroup = "system", sourceLabel = "System messages" },
		{ epoch = 4, timestamp = "00:04", event = "CHAT_MSG_GUILD", text = "old-guild", sender = "C", sourceId = "guild:guild", sourceGroup = "guild", sourceLabel = "Guild chat" },
	},
}
ChattyChattyBangBang.BlockControl = {
	ShouldBlock = function(_, record)
		return record.text == "BLOCK ME", "rule", { id = "test" }
	end,
	ArchiveRecord = function(self, record, reason, rule)
		self.archived = self.archived or {}
		table.insert(self.archived, {
			text = record.text,
			reason = reason,
			ruleId = rule and rule.id,
		})
	end,
}
engine:ResetForProfile()
assert(settings.history.schema == 2 and #engine:GetMessages() == 3,
	"schema-1 migration did not reapply current block rules")
assert(engine.count == 3, "blocked history was not removed from normal runtime storage")
assert(#ChattyChattyBangBang.BlockControl.archived == 1
	and ChattyChattyBangBang.BlockControl.archived[1].text == "BLOCK ME",
	"blocked persisted history was not moved to the separate archive path")
for _, ring in pairs(settings.history.sources) do
	for _, record in pairs(ring.records) do
		assert(record.text ~= "BLOCK ME", "blocked history remained in persisted normal storage")
	end
end
ChattyChattyBangBang.BlockControl.ShouldBlock = function() return false end
engine:ReapplyBlockRules()
assert(#engine:GetMessages() == 3 and engine:GetMessages()[1].text == "old-general"
	and engine:GetMessages()[3].text == "old-guild",
	"quarantined history was resurrected after a rule stopped matching")

-- CLEAR removes both the live transcript and its SavedVariables copy. When
-- persistence is disabled, later chat remains session-only and cannot return.
assert(engine:ClearHistory())
assert(#engine:GetMessages() == 0 and settings.history.schema == 2
	and next(settings.history.sources) == nil,
	"clear history left live or saved message text behind")
settings.persistHistory = false
deliverChannel("General", 1, "session-only")
assert(settings.history == nil or next(settings.history.sources) == nil,
	"disabled persistence wrote a received message to SavedVariables")
engine:ResetForProfile()
assert(#engine:GetMessages() == 0, "session-only history returned after reload")

print("Chat history mock tests passed")
