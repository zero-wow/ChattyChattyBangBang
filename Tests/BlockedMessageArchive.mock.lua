-- Focused no-client contract for the separate, bounded Blocked Messages
-- archive. Run from the addon root with: lua Tests/BlockedMessageArchive.mock.lua

local now = 100
local settings = {
	enabled = true,
	historyCapacity = 100,
	persistHistory = true,
	learnedSources = {},
	customViews = {},
	customViewRevision = 0,
	channelTargets = {},
	spam = { escalation = { offenders = { sentinel = true }, bans = { sentinel = true } } },
	blocks = {
		enabled = true,
		rules = {},
		sequence = 0,
		revision = 0,
		uiFeedback = { coalesce = true, window = 1.5 },
	},
}

ChattyChattyBangBang = {
	GetSmartSettings = function() return settings end,
	GetSmartViews = function() return {} end,
	IsRecordAllowedInView = function() return true end,
	Print = function() end,
}

GetTime = function() return now end
time = function() return 1700000000 + math.floor(now) end
date = function() return string.format("12:%02d", math.floor(now) % 60) end
CreateFrame = function()
	return {
		SetScript = function(self, name, callback) self[name] = callback end,
		RegisterEvent = function() return true end,
		UnregisterEvent = function() return true end,
	}
end

dofile("Core/BlockControl.lua")
dofile("Core/MessageEngine.lua")

local addon = ChattyChattyBangBang
local blocks = addon.BlockControl
local engine = addon.MessageEngine
blocks:Initialize()
engine:Initialize()
engine:SetEnabled(true)

local delivered = {}
engine:RegisterListener("archive-test", function(record) delivered[#delivered + 1] = record end)

local function captureChannel(text, sender, lineId)
	now = now + 1
	engine:Capture("CHAT_MSG_CHANNEL", text, sender or "ArchiveTester", nil,
		"Trade", nil, nil, nil, 2, "Trade", nil, lineId or now, "Player-1-ARCHIVE")
end

-- A quick block removes an existing persisted line, moves it into a separate
-- archive, and does not leave it in any normal history ring.
captureChannel("Archive this exact message", "ArchiveTester", 1)
assert(#delivered == 1 and engine.count == 1, "seed message was not delivered")
local original = delivered[1]
local ok, rule = addon:BlockRecord(original)
assert(ok and rule, "quick block did not create a rule")
assert(engine.count == 0 and #engine:GetMessages() == 0,
	"existing block match remained in normal runtime history")
assert(settings.history and next(settings.history.sources) == nil,
	"existing block match remained in persisted normal history")

local archive = addon:GetBlockedMessageArchive()
assert(#archive == 1, "quick block did not create one archive entry")
local entry = archive[1]
assert(entry.text == "Archive this exact message" and entry.sender == "ArchiveTester"
	and entry.sourceId == "channel:trade" and entry.event == "CHAT_MSG_CHANNEL"
	and entry.ruleId == rule.id and entry.reason == "rule" and entry.occurrences == 1,
	"archive entry lost required review metadata")

-- Reapplying is idempotent because the normal record has already been
-- unlinked. A reload or later config refresh cannot duplicate this entry.
engine:ReapplyBlockRules()
archive = addon:GetBlockedMessageArchive()
assert(#archive == 1 and archive[1].occurrences == 1,
	"reapplying block rules duplicated an archived historical record")

-- A later live copy is never delivered/stored, but aggregates onto the same
-- archive row so repeated unwanted messages remain reviewable without bloat.
now = now + 10
engine:Capture("CHAT_MSG_CHANNEL", "Archive this exact message", "ArchiveTester", nil,
	"Trade", nil, nil, nil, 2, "Trade", nil, 2, "Player-1-ARCHIVE")
assert(#delivered == 1 and engine.count == 0 and #engine:GetMessages() == 0,
	"later blocked copy entered normal history or listeners")
archive = addon:GetBlockedMessageArchive()
assert(#archive == 1 and archive[1].occurrences == 2 and archive[1].lastEpoch > archive[1].firstEpoch,
	"later blocked copy did not aggregate first/last occurrence metadata")

-- Deleting only changes future matching. Quarantined content is not replayed
-- from the archive into normal chat.
assert(addon:DeleteBlockRule(rule.id), "quick block could not be deleted")
assert(engine.count == 0 and #engine:GetMessages() == 0,
	"deleting a block resurrected quarantined content")
captureChannel("Archive this exact message", "ArchiveTester", 3)
assert(#delivered == 2 and engine.count == 1,
	"deleted block still suppressed a future line")

-- Automatic UI-error coalescing is intentionally not a manual archive event.
assert(addon:ClearBlockedMessageArchive(), "could not clear archive before coalescer test")
now = now + 1
engine:Capture("UI_ERROR_MESSAGE", "Spell is not ready yet.")
now = now + 0.2
engine:Capture("UI_ERROR_MESSAGE", "Spell is not ready yet.")
assert(#addon:GetBlockedMessageArchive() == 0,
	"automatic UI-error coalescing incorrectly wrote a manual block archive entry")

-- Capacity and age cleanup happen inside the archive, never in spam evidence.
local archiveRule = { id = "archive-rule", name = "Archive Rule" }
assert(addon:SetBlockedMessageArchiveCapacity(1) and addon:GetBlockedMessageArchiveStats().maxEntries == 25,
	"archive capacity did not enforce its documented lower bound")
for index = 1, 26 do
	now = now + 1
	blocks:ArchiveRecord({
		text = "capacity-" .. index,
		normalized = "capacity-" .. index,
		sender = "ArchiveTester",
		sourceId = "channel:trade",
		sourceLabel = "Trade",
		sourceGroup = "channels",
		event = "CHAT_MSG_CHANNEL",
		epoch = time(),
		timestamp = date(),
	}, "rule", archiveRule)
end
archive = addon:GetBlockedMessageArchive()
assert(#archive == 25 and archive[#archive].text == "capacity-2" and archive[1].text == "capacity-26",
	"archive capacity did not evict the oldest entry")
-- A repeat is a current occurrence, not an old row: it must move to the
-- newest end before later capacity cleanup decides what to evict.
now = now + 1
blocks:ArchiveRecord({
	text = "capacity-2", normalized = "capacity-2", sender = "ArchiveTester",
	sourceId = "channel:trade", sourceLabel = "Trade", sourceGroup = "channels",
	event = "CHAT_MSG_CHANNEL", epoch = time(), timestamp = date(),
}, "rule", archiveRule)
archive = addon:GetBlockedMessageArchive()
assert(archive[1].text == "capacity-2" and archive[#archive].text == "capacity-3",
	"deduped archive entry was not ordered by its latest occurrence")
now = now + 1
blocks:ArchiveRecord({
	text = "capacity-27", normalized = "capacity-27", sender = "ArchiveTester",
	sourceId = "channel:trade", sourceLabel = "Trade", sourceGroup = "channels",
	event = "CHAT_MSG_CHANNEL", epoch = time(), timestamp = date(),
}, "rule", archiveRule)
archive = addon:GetBlockedMessageArchive()
local retainedRepeat, evictedOld = false, false
for index = 1, #archive do
	retainedRepeat = retainedRepeat or archive[index].text == "capacity-2"
	evictedOld = evictedOld or archive[index].text == "capacity-3"
end
assert(retainedRepeat and not evictedOld,
	"capacity cleanup evicted a recently repeated archive entry instead of the oldest one")
assert(addon:SetBlockedMessageArchiveRetentionDays(1), "archive retention setter failed")
local beforeExpiredInsert = #settings.blocks.archive.entries
blocks:ArchiveRecord({
	text = "already old", normalized = "already old", sender = "ArchiveTester",
	sourceId = "channel:trade", sourceLabel = "Trade", sourceGroup = "channels",
	event = "CHAT_MSG_CHANNEL", epoch = time() - (3 * 86400), timestamp = "old",
}, "rule", archiveRule)
assert(#settings.blocks.archive.entries == beforeExpiredInsert,
	"an already-expired historical record entered the archive before cleanup")
archive = addon:GetBlockedMessageArchive()
for index = 1, #archive do
	assert(archive[index].text ~= "already old", "archive retained an immediately expired entry")
end
assert(settings.spam.escalation.offenders.sentinel and settings.spam.escalation.bans.sentinel,
	"archive cleanup touched independent spam-ban evidence")

-- Turning off archival is a privacy action: it immediately removes retained
-- plaintext but blocks continue to operate normally.
assert(addon:SetBlockedMessageArchiveEnabled(false), "could not disable archive")
assert(#addon:GetBlockedMessageArchive() == 0,
	"disabling archive left blocked plaintext behind")
assert(addon:SetBlockedMessageArchiveEnabled(true), "could not re-enable archive")
assert(addon:ClearBlockedMessageArchive(), "explicit archive clear failed")
assert(#addon:GetBlockedMessageArchive() == 0,
	"explicit archive clear left entries behind")

print("Blocked message archive mock tests passed")
