-- Focused no-client integration contract for CONTENTS membership. Run from
-- the addon root with: lua Tests/ViewContentsMembership.mock.lua
--
-- A source has one inherited factual home. Checked non-home sources are full
-- additive feeds, classifier/custom memberships remain independent, and all
-- visible views reference one source-owned history record.

local now = 100
unpack = unpack or table.unpack

ChattyChattyBangBang = {
	db = {
		profile = {
			smartChat = {
				builtInSourceViewsSchema = 2,
				viewSourceMembershipSchema = 0,
				persistHistory = true,
				historyCapacity = 100,
				viewOptions = {
					general = { sources = {
						["channel:ascension"] = false,
						["channel:trade"] = false,
					} },
					trade = { sources = {
						["channel:ascension"] = true,
						["channel:trade"] = true,
					} },
				},
			},
		},
	},
	Print = function() end,
}

GetTime = function() return now end
time = function() return 1700000000 + math.floor(now) end
date = function() return "12:00" end
CreateFrame = function()
	return {
		SetScript = function(self, name, callback) self[name] = callback end,
		RegisterEvent = function() end,
		UnregisterAllEvents = function() end,
	}
end

dofile("Core/Settings.lua")
dofile("Core/MessageEngine.lua")

local addon = ChattyChattyBangBang
local settings = addon:GetSmartSettings()

-- Schema 0 used false-only exclusions. Every legacy false remains a hard
-- exclusion (even outside the clean home) so routes cannot unexpectedly add a
-- source back; only a redundant positive value for a built-in home is pruned.
assert(settings.viewSourceMembershipSchema == 1,
	"legacy CONTENTS profile did not advance to tri-state schema 1")
assert(settings.viewOptions.general.sources["channel:ascension"] == false
	and settings.viewOptions.general.sources["channel:trade"] == false,
	"migration discarded a legacy hard exclusion")
assert(settings.viewOptions.trade.sources["channel:ascension"] == true
	and settings.viewOptions.trade.sources["channel:trade"] == nil,
	"migration did not retain only Trade's genuine additive feed")

assert(addon:ResetViewSources("general") and addon:ResetViewSources("trade"),
	"clean source defaults could not be restored after migration")

local expectedHomes = {
	{ "local:say", "local", "general" },
	{ "channel:ascension", "channels", "general" },
	{ "channel:newcomers", "channels", "newcomers" },
	{ "channel:lookingforgroup", "channels", "groupFinder" },
	{ "channel:guildrecruitment", "channels", "guildInvites" },
	{ "channel:defense", "channels", "pvp" },
	{ "channel:defence", "channels", "pvp" },
	{ "channel:localdefence", "channels", "pvp" },
	{ "channel:world-defence", "channels", "pvp" },
	{ "channel:trade", "channels", "trade" },
	{ "conversation:whisper", "conversations", "conversations" },
	{ "group:party", "group", "group" },
	{ "guild:guild", "guild", "guild" },
	{ "system:message", "system", "system" },
	{ "loot:loot", "loot", "loot" },
	{ "addon:alcver", "sync", "sync" },
}
for index = 1, #expectedHomes do
	local fixture = expectedHomes[index]
	assert(addon:GetDefaultViewForSource(fixture[1], fixture[2]) == fixture[3],
		"wrong clean source home for " .. fixture[1])
end

local engine = addon.MessageEngine
engine:Initialize()
engine:SetEnabled(true)

local sourceFeed = assert(addon:CreateCustomView({
	label = "Ascension feed",
	key = "ASC",
	terms = {},
	enabled = true,
}))

local rebuilds = 0
addon.SmartDock = {
	frame = {},
	unread = { general = 4, trade = 3, [sourceFeed.id] = 2 },
	RefreshRailState = function() end,
	RebuildActiveView = function() rebuilds = rebuilds + 1 end,
}

assert(addon:SetViewSourceEnabled(sourceFeed.id, "channel:ascension", true),
	"custom view rejected an explicit positive source feed")
assert(settings.viewOptions[sourceFeed.id].sources["channel:ascension"] == true
	and rebuilds == 1 and addon.SmartDock.unread[sourceFeed.id] == 0,
	"positive feed did not persist and rebuild its live view")

local function findSourceDefinition(viewId, sourceId)
	local definitions = addon:GetViewSourceDefinitions(viewId)
	for index = 1, #definitions do
		if definitions[index].sourceId == sourceId or definitions[index].id == sourceId then
			return definitions[index]
		end
	end
	return nil
end

local addonSyncInGeneral = findSourceDefinition("general", "addon:alcver")
assert(addonSyncInGeneral and addonSyncInGeneral.feedLocked == true
	and addonSyncInGeneral.feedLockReason == "sync-only"
	and addonSyncInGeneral.enabled == false,
	"General's source definitions did not expose the locked ALCver quarantine")

engine:Capture("CHAT_MSG_CHANNEL",
	"LFM need tank healer DPS for Blackfathom Deeps dungeon",
	"Tester", nil, "9. Ascension", nil, nil, nil, 9, "Ascension")
local routed = engine.historyTail
assert(routed and routed.view == "groupFinder" and routed.views.groupFinder,
	"semantic fixture did not route to Group Finder")
assert(routed.views.general == nil and routed.views[sourceFeed.id] == nil,
	"query-time source membership was incorrectly copied into classifier membership")
assert(engine:GetMessages("general")[1] == routed
	and engine:GetMessages("groupFinder")[1] == routed
	and engine:GetMessages(sourceFeed.id)[1] == routed,
	"semantic route did not union source home, primary route, and custom feed")
assert(engine.count == 1 and engine.byId[routed.id] == routed
	and settings.history.sources["channel:ascension"].count == 1,
	"additive views physically duplicated the semantic record")

local before = rebuilds
assert(addon:SetViewSourceEnabled("general", "channel:ascension", false),
	"General rejected an explicit source exclusion")
assert(settings.viewOptions.general.sources["channel:ascension"] == false
	and addon:IsRecordAllowedInView("general", routed, settings) == false
	and #engine:GetMessages("general") == 0
	and #engine:GetMessages("groupFinder") == 1
	and #engine:GetMessages(sourceFeed.id) == 1
	and rebuilds == before + 1,
	"explicit false was not a live per-view exclusion")

before = rebuilds
assert(addon:SetViewSourceEnabled("general", "channel:ascension", nil),
	"General rejected an explicit AUTO reset")
assert((not settings.viewOptions.general
		or not settings.viewOptions.general.sources
		or settings.viewOptions.general.sources["channel:ascension"] == nil)
	and engine:GetMessages("general")[1] == routed
	and rebuilds == before + 1,
	"nil did not restore General's inherited source home immediately")

assert(addon:SetMessageRouteOverride(routed, "trade"),
	"manual primary-route correction was rejected")
assert(routed.view == "trade" and routed.views.trade == true
	and routed.views.groupFinder == nil and routed.views.general == nil,
	"manual correction did not replace classifier-owned membership")
assert(engine:GetMessages("general")[1] == routed
	and engine:GetMessages("trade")[1] == routed
	and engine:GetMessages(sourceFeed.id)[1] == routed
	and engine.count == 1
	and settings.history.sources["channel:ascension"].count == 1,
	"manual route did not preserve additive source views around one record")

before = rebuilds
assert(addon:ResetViewSources(sourceFeed.id),
	"custom source feed could not be reset")
assert(#engine:GetMessages(sourceFeed.id) == 0 and rebuilds == before + 1,
	"custom feed reset did not rebuild history membership immediately")

-- Sync is a hard protocol quarantine rather than a presentation feed. Human
-- views cannot even save a checkbox state that would promise a leaked copy.
local accepted, reason = addon:SetViewSourceEnabled("general", "addon:alcver", true)
assert(accepted == false and reason == "sync-quarantined",
	"General accepted an impossible Sync source mirror")
accepted, reason = addon:SetViewSourceEnabled(sourceFeed.id, "addon:alcver", true)
assert(accepted == false and reason == "sync-quarantined",
	"custom view accepted an impossible Sync source mirror")
engine:Capture("CHAT_MSG_ADDON", "ALCver", "VERSION:1234", "GUILD", "SyncFriend")
local syncRecord = engine.historyTail
assert(syncRecord and syncRecord.isSync and syncRecord.view == "sync"
	and engine:GetMessages("sync")[1] == syncRecord,
	"known protocol record did not enter its Sync home")
assert(#engine:GetMessages("general") == 1
	and #engine:GetMessages(sourceFeed.id) == 0
	and addon:IsRecordIncludedBySource("general", syncRecord, settings) == false
	and addon:IsRecordIncludedBySource(sourceFeed.id, syncRecord, settings) == false,
	"a quarantined Sync record leaked into a human view")
assert(engine.count == 2 and engine.byId[syncRecord.id] == syncRecord
	and settings.history.sources["addon:alcver"].count == 1,
	"Sync quarantine duplicated or lost the physical protocol record")

-- A normal human source is equally locked out of the Sync tab until its
-- adjacent source-level mode is changed.
accepted, reason = addon:SetViewSourceEnabled("sync", "channel:ascension", true)
assert(accepted == false and reason == "sync-quarantined",
	"Sync accepted a normal human source through the per-view feed checkbox")
local normalInSync = findSourceDefinition("sync", "channel:ascension")
assert(normalInSync and normalInSync.feedLocked == true and normalInSync.enabled == false,
	"Sync source definitions did not expose the normal-source lock")

-- Marking the whole channel as Sync reclassifies retained history, clears all
-- obsolete unread badges, and flips which side of the quarantine is locked.
addon.SmartDock.unread.general = 7
addon.SmartDock.unread.trade = 6
addon.SmartDock.unread.sync = 5
addon.SmartDock.unread[sourceFeed.id] = 4
before = rebuilds
assert(addon:SetSourceSyncOverride("channel:ascension", true),
	"Ascension source could not be marked Sync")
for viewId, unread in pairs(addon.SmartDock.unread) do
	assert(unread == 0, "Sync mode change retained unread count for " .. tostring(viewId))
end
assert(rebuilds == before + 1 and routed.isSync == true and routed.view == "sync",
	"Sync mode change did not reclassify and rebuild retained history")
accepted, reason = addon:SetViewSourceEnabled("general", "channel:ascension", true)
assert(accepted == false and reason == "sync-quarantined",
	"marked Sync channel could still be positively fed into General")
local markedInGeneral = findSourceDefinition("general", "channel:ascension")
assert(markedInGeneral and markedInGeneral.feedLocked == true and markedInGeneral.enabled == false,
	"marked Sync definition did not lock its former human home")

-- Old SavedVariables or an interrupted reclassification may leave a stale
-- classifier membership. The quarantine gate must run before record.views.
routed.views.general = true
assert(addon:IsRecordAllowedInView("general", routed, settings) == false
	and #engine:GetMessages("general") == 0,
	"stale record.views membership leaked a Sync record into General")
routed.views.general = nil

print("View contents membership integration mock passed")
