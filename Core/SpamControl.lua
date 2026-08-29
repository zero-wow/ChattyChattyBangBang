local addon = ChattyChattyBangBang

local SpamControl = {}
addon.SpamControl = SpamControl

-- These are deliberately limited to player-authored chat. System, loot,
-- achievement, monster, and combat events must never enter the firewall.
local eventDefinitions = {
	{ event = "CHAT_MSG_CHANNEL", scope = "channel" },
	{ event = "CHAT_MSG_SAY", scope = "local" },
	{ event = "CHAT_MSG_YELL", scope = "local" },
	{ event = "CHAT_MSG_EMOTE", scope = "local" },
	{ event = "CHAT_MSG_TEXT_EMOTE", scope = "local" },
	{ event = "CHAT_MSG_GUILD", scope = "guild" },
	{ event = "CHAT_MSG_OFFICER", scope = "guild" },
	{ event = "CHAT_MSG_PARTY", scope = "group" },
	{ event = "CHAT_MSG_PARTY_LEADER", scope = "group" },
	{ event = "CHAT_MSG_RAID", scope = "group" },
	{ event = "CHAT_MSG_RAID_LEADER", scope = "group" },
	{ event = "CHAT_MSG_RAID_WARNING", scope = "group" },
	{ event = "CHAT_MSG_BATTLEGROUND", scope = "group" },
	{ event = "CHAT_MSG_BATTLEGROUND_LEADER", scope = "group" },
	-- Ascension may expose the later group aliases. Registration is protected
	-- with pcall, so stock 3.3.5 clients simply decline unsupported events.
	{ event = "CHAT_MSG_INSTANCE_CHAT", scope = "group" },
	{ event = "CHAT_MSG_INSTANCE_CHAT_LEADER", scope = "group" },
	{ event = "CHAT_MSG_WHISPER", scope = "whisper" },
	{ event = "CHAT_MSG_WHISPER_INFORM", scope = "whisper", selfEvent = true },
	{ event = "CHAT_MSG_BN_WHISPER", scope = "bnet" },
	{ event = "CHAT_MSG_BN_WHISPER_INFORM", scope = "bnet", selfEvent = true },
	{ event = "CHAT_MSG_BN_CONVERSATION", scope = "bnet" },
}

local definitionByEvent = {}
SpamControl.Events = {}
for index = 1, #eventDefinitions do
	local definition = eventDefinitions[index]
	definitionByEvent[definition.event] = definition
	SpamControl.Events[index] = definition.event
end

local DEFAULTS = {
	enabled = true,
	exemptSelf = true,
	duplicate = {
		enabled = true,
		window = 12,
		allowedCopies = 1,
		-- Number of suppressed repeat copies that must arrive before this
		-- particular duplicate pattern upgrades into a sender mute.  Zero keeps
		-- duplicate filtering as hide-only behavior.
		muteAfter = 3,
		minimumLength = 4,
		caseInsensitive = true,
		collapseWhitespace = true,
		stripFormatting = true,
		ignorePunctuation = false,
		crossChannels = true,
	},
	burst = {
		enabled = true,
		window = 6,
		limit = 6,
		muteDuration = 15,
	},
	escalation = {
		enabled = true,
		mutesBeforeBan = 3,
		strikeWindow = 1800,
	},
	scopes = {
		channel = true,
		["local"] = true,
		guild = false,
		group = false,
		whisper = false,
		bnet = false,
	},
}

-- All hot-path collections are hard bounded. Ring replacement gives constant
-- insertion/eviction cost, while the tiny sweep budget retires expired state
-- without periodic full-table scans or OnUpdate work.
local DUPLICATE_CAPACITY = 4096
local BURST_CAPACITY = 2048
local DECISION_CAPACITY = 1024
local OFFENDER_CAPACITY = 256
local BAN_CAPACITY = 256
-- Evidence is intentionally captured only when a timed mute earns a strike,
-- never for ordinary chat.  A tiny retained trail explains an automatic ban
-- without turning the spam firewall into a chat logger.
local BAN_EVIDENCE_CAPACITY = 4
local BAN_EVIDENCE_MESSAGE_LENGTH = 240
local CLEANUP_BUDGET = 2
-- ChatFrame filters fan a single network line out to each receiving frame,
-- and MessageEngine replays that filter chain once for capture.  This is a
-- synchronous, sub-frame operation.  Never keep an allow decision alive for
-- seconds merely because a server supplied a line ID: Ascension can reuse a
-- line ID for a genuinely new message.
local DECISION_FANOUT_TTL = 0.075
local DECISION_FRAME_CAPACITY = 16
local DECISION_NO_FRAME = {}
-- A distinct pseudo-frame for MessageEngine's direct firewall query. It is
-- never a Blizzard ChatFrame, so native per-frame fanout remains separate.
local DECISION_ENGINE_REPLAY_FRAME = {}
local SEPARATOR = string.char(31)

local function packValues(...)
	return { n = select("#", ...), ... }
end

local function booleanSetting(value, defaultValue)
	if value == nil then
		return defaultValue
	end
	return value ~= false and value ~= 0
end

local function numberSetting(value, defaultValue, minimum, maximum, integer)
	local result = tonumber(value) or defaultValue
	if result < minimum then
		result = minimum
	elseif result > maximum then
		result = maximum
	end
	if integer then
		result = math.floor(result + 0.5)
	end
	return result
end

local function compileSettings()
	local smart = addon.GetSmartSettings and addon:GetSmartSettings() or nil
	local spam = smart and type(smart.spam) == "table" and smart.spam or {}
	local duplicate = type(spam.duplicate) == "table" and spam.duplicate or {}
	local burst = type(spam.burst) == "table" and spam.burst or {}
	local escalation = type(spam.escalation) == "table" and spam.escalation or {}
	local scopes = type(spam.scopes) == "table" and spam.scopes or {}

	return {
		enabled = booleanSetting(spam.enabled, DEFAULTS.enabled),
		exemptSelf = booleanSetting(spam.exemptSelf, DEFAULTS.exemptSelf),
		duplicate = {
			enabled = booleanSetting(duplicate.enabled, DEFAULTS.duplicate.enabled),
			window = numberSetting(duplicate.window, DEFAULTS.duplicate.window, 0.1, 3600, false),
			allowedCopies = numberSetting(duplicate.allowedCopies, DEFAULTS.duplicate.allowedCopies, 1, 100, true),
			muteAfter = numberSetting(duplicate.muteAfter, DEFAULTS.duplicate.muteAfter, 0, 100, true),
			minimumLength = numberSetting(duplicate.minimumLength, DEFAULTS.duplicate.minimumLength, 0, 1024, true),
			caseInsensitive = booleanSetting(duplicate.caseInsensitive, DEFAULTS.duplicate.caseInsensitive),
			collapseWhitespace = booleanSetting(duplicate.collapseWhitespace, DEFAULTS.duplicate.collapseWhitespace),
			stripFormatting = booleanSetting(duplicate.stripFormatting, DEFAULTS.duplicate.stripFormatting),
			ignorePunctuation = booleanSetting(duplicate.ignorePunctuation, DEFAULTS.duplicate.ignorePunctuation),
			-- Kept in the saved schema for backwards compatibility.  Duplicate
			-- protection is deliberately sender + normalized message only now:
			-- moving the same line between Trade, General, and other eligible
			-- sources must not reset its flood history.
			crossChannels = true,
		},
		burst = {
			enabled = booleanSetting(burst.enabled, DEFAULTS.burst.enabled),
			window = numberSetting(burst.window, DEFAULTS.burst.window, 0.1, 300, false),
			limit = numberSetting(burst.limit, DEFAULTS.burst.limit, 1, 1000, true),
			muteDuration = numberSetting(burst.muteDuration, DEFAULTS.burst.muteDuration, 0, 3600, false),
		},
		escalation = {
			enabled = booleanSetting(escalation.enabled, DEFAULTS.escalation.enabled),
			mutesBeforeBan = numberSetting(escalation.mutesBeforeBan, DEFAULTS.escalation.mutesBeforeBan, 1, 100, true),
			strikeWindow = numberSetting(escalation.strikeWindow, DEFAULTS.escalation.strikeWindow, 0, 2592000, true),
		},
		scopes = {
			channel = booleanSetting(scopes.channel, DEFAULTS.scopes.channel),
			["local"] = booleanSetting(scopes["local"], DEFAULTS.scopes["local"]),
			guild = booleanSetting(scopes.guild, DEFAULTS.scopes.guild),
			group = booleanSetting(scopes.group, DEFAULTS.scopes.group),
			whisper = booleanSetting(scopes.whisper, DEFAULTS.scopes.whisper),
			bnet = booleanSetting(scopes.bnet, DEFAULTS.scopes.bnet),
		},
	}
end

local function currentTime()
	if GetTime then
		return GetTime()
	end
	return 0
end

local function wallTime()
	-- Strike windows must survive /reload and client restarts.  GetTime is only
	-- session uptime, while time() is present on the 3.3.5 Lua API.
	if time then
		return tonumber(time()) or 0
	end
	if GetServerTime then
		return tonumber(GetServerTime()) or 0
	end
	return currentTime()
end

local function shallowCopy(source)
	local result = {}
	if type(source) == "table" then
		for key, value in pairs(source) do
			result[key] = value
		end
	end
	return result
end

local function copyEvidence(entries)
	local result = {}
	if type(entries) ~= "table" then
		return result
	end
	for index = 1, math.min(#entries, BAN_EVIDENCE_CAPACITY) do
		local entry = entries[index]
		if type(entry) == "table" then
			result[#result + 1] = shallowCopy(entry)
		end
	end
	return result
end

local function trimText(value, maximum)
	local text = tostring(value or "")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	if maximum and string.len(text) > maximum then
		text = string.sub(text, 1, maximum)
	end
	return text
end

local function addStrikeEvidence(record, reason, definition, event, channelName, message, timestamp)
	if type(record) ~= "table" then
		return
	end
	local private = definition and (definition.scope == "whisper" or definition.scope == "bnet")
	local text = private and "[Private message text is not retained]" or trimText(message, BAN_EVIDENCE_MESSAGE_LENGTH)
	if text == "" then
		return
	end
	local entries = type(record.evidence) == "table" and record.evidence or {}
	record.evidence = entries
	entries[#entries + 1] = {
		message = text,
		reason = reason == "duplicate" and "duplicate" or "burst",
		scope = trimText(definition and definition.scope, 24),
		event = trimText(event, 64),
		channel = definition and definition.scope == "channel" and trimText(channelName, 96) or nil,
		at = math.max(0, math.floor(tonumber(timestamp) or 0)),
	}
	while #entries > BAN_EVIDENCE_CAPACITY do
		table.remove(entries, 1)
	end
end

-- Ascension supplies 0 in the Battle.net argument slots for many ordinary
-- CHAT_MSG_* events.  Zero is a placeholder, not a player identity.  Keeping
-- it out of every identity/index path is essential: otherwise one automatic
-- ban can accidentally turn into a global "bnet:0" ban for channel traffic.
local function usableBnetAccountId(value)
	local text = trimText(value, 64)
	if text == "" or text == "0" then
		return nil
	end
	local numeric = tonumber(text)
	if numeric and numeric <= 0 then
		return nil
	end
	return text
end

local function cleanSenderText(value)
	local text = trimText(value, 128)
	local linked = string.match(text, "|Hplayer:([^:|]+)")
	if linked and linked ~= "" then
		text = linked
	else
		text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
		text = string.gsub(text, "|r", "")
		text = string.gsub(text, "^%[", "")
		text = string.gsub(text, "%]$", "")
	end
	return trimText(text, 96)
end

local function normalizedSenderName(value)
	local text = string.lower(cleanSenderText(value))
	-- Realm names are transported without spaces by WoW, but GetRealmName can
	-- include them. Normalizing them here keeps manual and event identities equal.
	text = string.gsub(text, "%s+", "")
	return text
end

local function baseSenderName(value)
	local normalized = normalizedSenderName(value)
	return string.match(normalized, "^([^-]+)") or normalized
end

local function refreshPlayerIdentity(self)
	local name, unitRealm
	if UnitName then
		name, unitRealm = UnitName("player")
	end
	local guid = UnitGUID and UnitGUID("player") or nil
	local realm = unitRealm
	if (not realm or realm == "") and GetRealmName then
		realm = GetRealmName()
	end
	self.playerName = name and baseSenderName(name) or nil
	self.playerFullName = name and normalizedSenderName(name) or nil
	if name and realm and realm ~= "" then
		self.playerFullName = normalizedSenderName(name .. "-" .. realm)
	end
	self.playerGUID = guid
end

local function isSelfMessage(self, definition, sender, guid)
	if definition.selfEvent then
		return true
	end
	if guid and guid ~= "" and self.playerGUID and self.playerGUID ~= "" then
		return guid == self.playerGUID
	end
	if not self.playerName then
		refreshPlayerIdentity(self)
	end
	local normalized = normalizedSenderName(sender)
	if normalized == "" then
		return false
	end
	if self.playerFullName and normalized == self.playerFullName then
		return true
	end
	-- A realm-less sender is local to this client.  Never use only the base name
	-- when the event supplied a realm because another realm may share the name.
	return not string.find(normalized, "-", 1, true)
		and self.playerName
		and normalized == self.playerName
		or false
end

local function normalizeMessage(message, config)
	local text = tostring(message or "")
	if config.stripFormatting then
		-- Keep hyperlink display text, but discard transport/color/texture markup.
		text = string.gsub(text, "|H.-|h(.-)|h", "%1")
		text = string.gsub(text, "|T.-|t", " ")
		text = string.gsub(text, "|A.-|a", " ")
		text = string.gsub(text, "|K.-|k", " ")
		text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
		text = string.gsub(text, "|r", "")
		text = string.gsub(text, "||", "|")
	end
	if config.caseInsensitive then
		text = string.lower(text)
	end
	if config.ignorePunctuation then
		text = string.gsub(text, "%p+", "")
	end
	if config.collapseWhitespace then
		text = string.gsub(text, "%s+", " ")
		text = string.gsub(text, "^%s+", "")
		text = string.gsub(text, "%s+$", "")
	end
	return text
end

local function resetDecisionState(self)
	self.decisionCache = {}
	self.decisionRing = {}
	self.decisionInsert = 0
	self.decisionSweep = 0
	self.decisionCount = 0
end

local function resetBoundedState(self)
	self.duplicateState = {}
	self.duplicateRing = {}
	self.duplicateInsert = 0
	self.duplicateSweep = 0
	self.duplicateCount = 0

	self.burstState = {}
	self.burstRing = {}
	self.burstInsert = 0
	self.burstSweep = 0
	self.burstCount = 0

	resetDecisionState(self)
end

local function insertBounded(self, mapName, ringName, insertName, countName, capacity, key, entry)
	local map = self[mapName]
	local existing = map[key]
	if existing then
		return existing
	end

	local index = (self[insertName] % capacity) + 1
	local ring = self[ringName]
	local displaced = ring[index]
	if displaced and map[displaced.key] == displaced.entry then
		map[displaced.key] = nil
		self[countName] = self[countName] - 1
	end

	map[key] = entry
	ring[index] = { key = key, entry = entry }
	self[insertName] = index
	self[countName] = self[countName] + 1
	return entry
end

local function sweepBounded(self, mapName, ringName, sweepName, countName, capacity, now)
	local map = self[mapName]
	local ring = self[ringName]
	local index = self[sweepName]
	for _ = 1, CLEANUP_BUDGET do
		index = (index % capacity) + 1
		local slot = ring[index]
		if slot then
			local current = map[slot.key]
			if current ~= slot.entry then
				ring[index] = nil
			elseif current.expires and current.expires <= now then
				map[slot.key] = nil
				ring[index] = nil
				self[countName] = self[countName] - 1
			end
		end
	end
	self[sweepName] = index
end

local function sweepExpired(self, now)
	sweepBounded(self, "duplicateState", "duplicateRing", "duplicateSweep", "duplicateCount", DUPLICATE_CAPACITY, now)
	sweepBounded(self, "burstState", "burstRing", "burstSweep", "burstCount", BURST_CAPACITY, now)
	sweepBounded(self, "decisionCache", "decisionRing", "decisionSweep", "decisionCount", DECISION_CAPACITY, now)
end

local function senderIdentity(self, definition, sender, guid, bnetAccountId)
	if definition.selfEvent then
		return self.playerGUID or self.playerName or "self"
	end
	local usableBnetId = definition.scope == "bnet" and usableBnetAccountId(bnetAccountId) or nil
	if usableBnetId then
		return "bnet:" .. usableBnetId
	end
	if guid and guid ~= "" then
		return "guid:" .. tostring(guid)
	end
	local name = normalizedSenderName(sender)
	if name == "" then
		return nil
	end
	return "name:" .. name
end

local function ensurePersistentStorage(self)
	local smart = addon.GetSmartSettings and addon:GetSmartSettings() or nil
	if type(smart) ~= "table" then
		smart = {}
	end
	if type(smart.spam) ~= "table" then
		smart.spam = {}
	end
	if type(smart.spam.escalation) ~= "table" then
		smart.spam.escalation = {}
	end
	local storage = smart.spam.escalation
	if type(storage.offenders) ~= "table" then
		storage.offenders = {}
	end
	if type(storage.bans) ~= "table" then
		storage.bans = {}
	end
	storage.nextBanSequence = math.max(0, math.floor(tonumber(storage.nextBanSequence) or 0))
	self.persistent = storage
	return storage
end

local function persistentCount(records)
	local count = 0
	if type(records) == "table" then
		for _ in pairs(records) do
			count = count + 1
		end
	end
	return count
end

local function indexRecord(index, key, record, timestampField)
	if not key or key == "" then
		return
	end
	local existing = index[key]
	if not existing
		or (tonumber(record[timestampField]) or 0) >= (tonumber(existing[timestampField]) or 0)
	then
		index[key] = record
	end
end

local function indexIdentityRecord(index, record, timestampField)
	local id = tostring(record.id or "")
	indexRecord(index, id, record, timestampField)
	if record.guid and record.guid ~= "" then
		indexRecord(index, "guid:" .. tostring(record.guid), record, timestampField)
	end
	local bnetAccountId = usableBnetAccountId(record.bnetAccountId)
	record.bnetAccountId = bnetAccountId
	if bnetAccountId then
		indexRecord(index, "bnet:" .. bnetAccountId, record, timestampField)
	end

	local normalized = normalizedSenderName(record.normalizedName or record.fullName or record.name)
	if normalized ~= "" then
		record.normalizedName = normalized
		indexRecord(index, "name:" .. normalized, record, timestampField)
	end
	-- Only an explicitly manual, realm-less ban is broad. A realm-less
	-- automatic offender/ban must not absorb a later Name-OtherRealm sender.
	if record.broadName and record.broadBaseName and record.broadBaseName ~= "" then
		indexRecord(index, "name:" .. record.broadBaseName, record, timestampField)
	end
end

local function rebuildPersistentIndexes(self)
	local storage = ensurePersistentStorage(self)
	self.offenderIndex = {}
	self.banIndex = {}
	self.offenderCount = 0
	self.banCount = 0

	local invalid = {}
	for id, record in pairs(storage.offenders) do
		if type(id) ~= "string" or id == "" or type(record) ~= "table" then
			invalid[#invalid + 1] = id
		elseif record.bnetAccountId ~= nil and not usableBnetAccountId(record.bnetAccountId) then
			-- An offender carrying the old bnet:0 placeholder was aggregated with
			-- unrelated normal-chat senders. It is not a trustworthy strike ledger.
			invalid[#invalid + 1] = id
		else
			record.id = id
			record.strikes = math.max(0, math.floor(tonumber(record.strikes) or 0))
			record.firstStrike = tonumber(record.firstStrike) or 0
			record.lastStrike = tonumber(record.lastStrike) or 0
			indexIdentityRecord(self.offenderIndex, record, "lastStrike")
			self.offenderCount = self.offenderCount + 1
		end
	end
	for index = 1, #invalid do
		storage.offenders[invalid[index]] = nil
	end

	invalid = {}
	for id, record in pairs(storage.bans) do
		if type(id) ~= "string" or id == "" or type(record) ~= "table" then
			invalid[#invalid + 1] = id
		elseif record.source == "automatic" and record.bnetAccountId ~= nil
			and not usableBnetAccountId(record.bnetAccountId) then
			-- Automatic bnet:0 bans were created by the placeholder-identity bug.
			-- Remove them rather than allowing a corrupted shared identity to keep
			-- hiding unrelated players. Manual bans are retained below.
			invalid[#invalid + 1] = id
		else
			record.id = id
			record.source = record.source == "automatic" and "automatic" or "manual"
			record.bnetAccountId = usableBnetAccountId(record.bnetAccountId)
			record.strikes = math.max(0, math.floor(tonumber(record.strikes) or 0))
			record.bannedAt = tonumber(record.bannedAt) or 0
			indexIdentityRecord(self.banIndex, record, "bannedAt")
			self.banCount = self.banCount + 1
		end
	end
	for index = 1, #invalid do
		storage.bans[invalid[index]] = nil
	end
end

local function senderDescriptor(self, definition, sender, guid, bnetAccountId)
	local fullName = cleanSenderText(sender)
	local normalized = normalizedSenderName(fullName)
	local displayName = string.match(fullName, "^([^-]+)") or fullName
	local realm = string.match(fullName, "^[^-]+%-(.+)$")
	local usableBnetId = definition.scope == "bnet" and usableBnetAccountId(bnetAccountId) or nil
	local primary = senderIdentity(self, definition, sender, guid, usableBnetId)
	if not primary then
		return nil
	end
	return {
		id = primary,
		name = displayName ~= "" and displayName or fullName,
		fullName = fullName,
		realm = realm,
		normalizedName = normalized,
		baseName = baseSenderName(normalized),
		guid = guid and guid ~= "" and tostring(guid) or nil,
		bnetAccountId = usableBnetId,
	}
end

-- Duplicate and burst state needs one identity that survives an Ascension
-- event arriving once without its GUID and again with it.  The persistent
-- moderation ledger still prefers GUIDs (and keeps its GUID/name aliases),
-- but a short-lived flood window should not be evadable merely because the
-- client omitted optional metadata for one delivery.  Public chat names are
-- realm-qualified when the client supplies a realm; the old GUID-less path
-- already used that same normalized name as its fallback.
local function floodIdentity(descriptor)
	if type(descriptor) ~= "table" then
		return nil
	end
	local bnetAccountId = usableBnetAccountId(descriptor.bnetAccountId)
	if bnetAccountId then
		return "bnet:" .. bnetAccountId
	end
	local normalized = trimText(descriptor.normalizedName, 96)
	if normalized ~= "" then
		return "name:" .. normalized
	end
	return descriptor.id
end

local function descriptorFromRecord(record)
	local normalized = normalizedSenderName(record.normalizedName or record.fullName or record.name)
	return {
		id = record.id,
		name = record.name,
		fullName = record.fullName,
		realm = record.realm,
		normalizedName = normalized,
		baseName = baseSenderName(normalized),
		guid = record.guid,
		bnetAccountId = usableBnetAccountId(record.bnetAccountId),
	}
end

local function findIdentityRecord(index, descriptor, allowBroadName)
	if type(index) ~= "table" or type(descriptor) ~= "table" then
		return nil
	end
	local record = descriptor.id and index[descriptor.id] or nil
	if record then
		return record
	end
	if descriptor.guid then
		record = index["guid:" .. tostring(descriptor.guid)]
		if record then return record end
	end
	if usableBnetAccountId(descriptor.bnetAccountId) then
		record = index["bnet:" .. tostring(descriptor.bnetAccountId)]
		if record then return record end
	end
	if descriptor.normalizedName and descriptor.normalizedName ~= "" then
		record = index["name:" .. descriptor.normalizedName]
		if record then return record end
	end
	-- A base-name fallback is reserved for manual, realm-less bans. Offender
	-- strikes never merge players merely because their base names are equal.
	if allowBroadName and descriptor.baseName and descriptor.baseName ~= "" then
		record = index["name:" .. descriptor.baseName]
		if record and record.broadName then
			return record
		end
	end
	return nil
end

local function findManagedRecord(records, value, timestampField)
	if type(records) ~= "table" then
		return nil
	end
	local direct = records[value]
	if type(direct) == "table" then
		return direct
	end
	local normalized = normalizedSenderName(value)
	if normalized == "" then
		return nil
	end
	local best
	for _, record in pairs(records) do
		if type(record) == "table" then
			local full = normalizedSenderName(record.normalizedName or record.fullName)
			local display = normalizedSenderName(record.name)
			if normalized == full or normalized == display then
				if not best
					or (tonumber(record[timestampField]) or 0) > (tonumber(best[timestampField]) or 0)
				then
					best = record
				end
			end
		end
	end
	return best
end

local function updateIdentityFields(record, descriptor)
	if descriptor.name and descriptor.name ~= "" then record.name = descriptor.name end
	if descriptor.fullName and descriptor.fullName ~= "" then record.fullName = descriptor.fullName end
	if descriptor.realm and descriptor.realm ~= "" then record.realm = descriptor.realm end
	if descriptor.normalizedName and descriptor.normalizedName ~= "" then
		record.normalizedName = descriptor.normalizedName
	end
	if descriptor.guid and descriptor.guid ~= "" then record.guid = descriptor.guid end
	local bnetAccountId = usableBnetAccountId(descriptor.bnetAccountId)
	if bnetAccountId then
		record.bnetAccountId = bnetAccountId
	end
end

local function enrichBanIdentity(self, record, descriptor)
	local oldNormalized = normalizedSenderName(record.normalizedName or record.fullName or record.name)
	updateIdentityFields(record, descriptor)
	local newNormalized = normalizedSenderName(record.normalizedName or record.fullName or record.name)
	if oldNormalized ~= "" and oldNormalized ~= newNormalized then
		local oldKey = "name:" .. oldNormalized
		if self.banIndex[oldKey] == record
			and (not record.broadName or oldNormalized ~= record.broadBaseName)
		then
			self.banIndex[oldKey] = nil
		end
	end
	-- The record object is already stored persistently. Adding its latest stable
	-- aliases is O(1) and avoids a hot-path scan/rebuild on every banned line.
	indexIdentityRecord(self.banIndex, record, "bannedAt")
end

local function pruneExpiredOffenders(self, now)
	local window = self.config and self.config.escalation and self.config.escalation.strikeWindow or 0
	if window <= 0 then
		return 0
	end
	local storage = ensurePersistentStorage(self)
	local removed = 0
	for id, record in pairs(storage.offenders) do
		local lastStrike = type(record) == "table" and tonumber(record.lastStrike) or nil
		-- A backwards wall clock (or a fallback GetTime from an earlier session)
		-- must never grant an effectively permanent strike window.
		if not lastStrike or lastStrike <= 0 or now < lastStrike or now - lastStrike > window then
			storage.offenders[id] = nil
			removed = removed + 1
		end
	end
	if removed > 0 then
		rebuildPersistentIndexes(self)
	end
	return removed
end

local function removeOldestOffender(self)
	local storage = ensurePersistentStorage(self)
	local oldestId
	local oldestAt
	for id, record in pairs(storage.offenders) do
		local at = type(record) == "table" and tonumber(record.lastStrike) or 0
		if not oldestAt or at < oldestAt then
			oldestAt = at
			oldestId = id
		end
	end
	if oldestId then
		storage.offenders[oldestId] = nil
		return true
	end
	return false
end

local function descriptorIsSelf(self, descriptor)
	if not descriptor then
		return false
	end
	if descriptor.guid and descriptor.guid ~= "" and self.playerGUID and self.playerGUID ~= "" then
		-- A stable GUID disagreement is authoritative. Never fall through to a
		-- base-name comparison that could exempt a same-name player on a realm.
		return descriptor.guid == self.playerGUID
	end
	if descriptor.normalizedName and self.playerFullName
		and descriptor.normalizedName == self.playerFullName
	then
		return true
	end
	return descriptor.normalizedName
		and not string.find(descriptor.normalizedName, "-", 1, true)
		and self.playerName
		and descriptor.normalizedName == self.playerName
		or false
end

local function manualDescriptor(self, name, metadata)
	metadata = type(metadata) == "table" and metadata or {}
	local fullName = cleanSenderText(name ~= nil and name or metadata.fullName or metadata.name)
	local normalized = normalizedSenderName(fullName)
	if normalized == "" then
		return nil
	end
	local guid = trimText(metadata.guid, 128)
	local bnetAccountId = usableBnetAccountId(metadata.bnetAccountId)
	local id
	if guid ~= "" then
		id = "guid:" .. guid
	elseif bnetAccountId then
		id = "bnet:" .. bnetAccountId
	else
		id = "name:" .. normalized
	end
	return {
		id = id,
		name = string.match(fullName, "^([^-]+)") or fullName,
		fullName = fullName,
		realm = string.match(fullName, "^[^-]+%-(.+)$"),
		normalizedName = normalized,
		baseName = baseSenderName(normalized),
		guid = guid ~= "" and guid or nil,
		bnetAccountId = bnetAccountId,
	}
end

local function copyBanReasonFields(target, reason, details)
	reason = reason == "duplicate" and "duplicate" or reason == "burst" and "burst" or "manual"
	target.reason = reason
	if type(details) ~= "table" then
		return
	end
	target.lastReason = details.lastReason == "duplicate" and "duplicate"
		or details.lastReason == "burst" and "burst"
		or reason
	target.lastScope = trimText(details.lastScope, 24)
	target.lastEvent = trimText(details.lastEvent, 64)
	target.lastChannel = trimText(details.lastChannel, 96)
	target.lastTriggeredAt = math.max(0, math.floor(tonumber(details.lastTriggeredAt) or 0))
	-- Freeze the strike samples onto the ban itself. Offender ledgers can expire
	-- or be cleared later, while a persistent ban still needs a truthful report.
	target.evidence = copyEvidence(details.evidence)
end

local function addBan(self, descriptor, source, strikes, reason, details)
	local existing = findIdentityRecord(self.banIndex, descriptor, true)
	if existing then
		enrichBanIdentity(self, existing, descriptor)
		existing.strikes = math.max(tonumber(existing.strikes) or 0, tonumber(strikes) or 0)
		if source == "automatic" then
			copyBanReasonFields(existing, reason, details)
		end
		return true, existing, false
	end

	local storage = ensurePersistentStorage(self)
	if persistentCount(storage.bans) >= BAN_CAPACITY then
		return false, "capacity", false
	end
	local id = descriptor.id
	if not id or id == "" then
		return false, "invalid", false
	end
	local record = {
		id = id,
		name = descriptor.name,
		fullName = descriptor.fullName,
		realm = descriptor.realm,
		normalizedName = descriptor.normalizedName,
		guid = descriptor.guid,
		bnetAccountId = descriptor.bnetAccountId,
		source = source == "automatic" and "automatic" or "manual",
		strikes = math.max(0, math.floor(tonumber(strikes) or 0)),
		bannedAt = wallTime(),
	}
	copyBanReasonFields(record, source == "automatic" and reason or "manual", details)
	if record.source == "manual"
		and not descriptor.guid
		and not descriptor.bnetAccountId
		and descriptor.normalizedName ~= ""
		and not string.find(descriptor.normalizedName, "-", 1, true)
	then
		record.broadName = true
		record.broadBaseName = descriptor.baseName
	end
	storage.bans[id] = record
	storage.nextBanSequence = (storage.nextBanSequence or 0) + 1
	rebuildPersistentIndexes(self)
	resetDecisionState(self)
	return true, record, true
end

local function resetOffenderForDescriptor(self, descriptor)
	local record = findIdentityRecord(self.offenderIndex, descriptor)
	if not record then
		return false
	end
	local storage = ensurePersistentStorage(self)
	storage.offenders[record.id] = nil
	rebuildPersistentIndexes(self)
	return true
end

local function recordMuteStrike(self, descriptor, reason, definition, event, channelName, message)
	if not descriptor or descriptorIsSelf(self, descriptor) then
		return false
	end
	local now = wallTime()
	pruneExpiredOffenders(self, now)
	local storage = ensurePersistentStorage(self)
	local record = findIdentityRecord(self.offenderIndex, descriptor)
	if not record then
		if persistentCount(storage.offenders) >= OFFENDER_CAPACITY then
			removeOldestOffender(self)
			rebuildPersistentIndexes(self)
		end
		record = {
			id = descriptor.id,
			strikes = 0,
			firstStrike = now,
			lastStrike = 0,
		}
		updateIdentityFields(record, descriptor)
		storage.offenders[record.id] = record
	else
		updateIdentityFields(record, descriptor)
	end

	local window = self.config.escalation.strikeWindow
	local lastStrike = tonumber(record.lastStrike) or 0
	if lastStrike <= 0 or now < lastStrike or (window > 0 and now - lastStrike > window) then
		record.strikes = 0
		record.firstStrike = now
	end
	record.strikes = math.min((tonumber(record.strikes) or 0) + 1, 1000000)
	record.lastStrike = now
	record.lastReason = reason == "duplicate" and "duplicate" or "burst"
	record.lastScope = trimText(definition and definition.scope, 24)
	record.lastEvent = trimText(event, 64)
	record.lastChannel = record.lastScope == "channel" and trimText(channelName, 96) or nil
	record.lastTriggeredAt = now
	addStrikeEvidence(record, record.lastReason, definition, event, channelName, message, now)
	if not record.firstStrike or record.firstStrike <= 0 then
		record.firstStrike = now
	end
	rebuildPersistentIndexes(self)

	self.stats.newMutes = self.stats.newMutes + 1
	self.stats.strikes = self.stats.strikes + 1
	if self.config.escalation.enabled
		and record.strikes >= self.config.escalation.mutesBeforeBan
	then
		local ok, _, created = addBan(self, descriptor, "automatic", record.strikes, record.lastReason, record)
		if ok and created then
			self.stats.automaticBans = self.stats.automaticBans + 1
			return true
		elseif not ok then
			self.stats.banCapacityReached = self.stats.banCapacityReached + 1
		end
	end
	return false
end

local function decisionPart(value)
	local text = tostring(value or "")
	-- Prefixing each field keeps a pipe/control-character inside player text
	-- from ever making two different event signatures compare equal.
	return tostring(string.len(text)) .. ":" .. text
end

local function decisionIdentity(event, message, sender, channelName, target, channelNumber, channelBaseName, lineId, guid, bnetAccountId)
	-- A line ID remains useful as one component of the signature, but it is
	-- never the whole key.  Several Ascension chat sources reuse line IDs, and
	-- a two-second line-ID allow cache lets their repeat floods bypass every
	-- duplicate and burst counter.
	return table.concat({
		decisionPart(event),
		decisionPart(lineId),
		decisionPart(sender),
		decisionPart(message),
		decisionPart(channelName),
		decisionPart(target),
		decisionPart(channelNumber),
		decisionPart(channelBaseName),
		decisionPart(guid),
		decisionPart(bnetAccountId),
	}, SEPARATOR)
end

local function addDecisionFrame(entry, frame)
	local frames = entry.frames
	if not frames then
		frames = {}
		entry.frames = frames
	end
	local count = entry.frameCount or 0
	if count < DECISION_FRAME_CAPACITY then
		count = count + 1
		frames[count] = frame
		entry.frameCount = count
	end
end

local function isDecisionFanout(entry, frame, now, fromEngineReplay)
	if not entry or entry.expires <= now then
		return false
	end
	if fromEngineReplay then
		-- MessageEngine receives the raw event independently and asks only this
		-- firewall through its dedicated pseudo-frame. Mark that distinct query
		-- separately from native ChatFrame fanout. This lets a genuine next line
		-- from the same native frame start a fresh decision immediately, even
		-- when the server recycled its line ID and payload.
		if entry.engineReplaySeen then
			return false
		end
		entry.engineReplaySeen = true
		return true
	end

	local frameKey = frame or DECISION_NO_FRAME
	local frames = entry.frames
	local count = entry.frameCount or 0
	for index = 1, count do
		if frames[index] == frameKey then
			-- Native filters invoke a given ChatFrame once per physical message.
			-- A repeat for the same frame is therefore a new delivery, not a
			-- cache hit.  MessageEngine's same-frame replay is handled above.
			return false
		end
	end

	-- Different chat frames are normal fanout.  The list is deliberately tiny
	-- and fixed-size: WotLK exposes far fewer than this many chat windows, and
	-- remote chat text can never grow this state.
	addDecisionFrame(entry, frameKey)
	return true
end

local function cacheDecision(self, key, blocked, now, frame, fromEngineReplay)
	local entry = self.decisionCache[key]
	if not entry then
		entry = insertBounded(
			self,
			"decisionCache",
			"decisionRing",
			"decisionInsert",
			"decisionCount",
			DECISION_CAPACITY,
			key,
			{}
		)
	end
	local previousCount = entry.frameCount or 0
	if entry.frames then
		for index = 1, previousCount do
			entry.frames[index] = nil
		end
	end
	entry.blocked = blocked and true or false
	entry.created = now
	entry.expires = now + DECISION_FANOUT_TTL
	entry.engineReplaySeen = fromEngineReplay and true or false
	entry.frameCount = 0
	-- A replay normally passes DEFAULT_CHAT_FRAME too, but it is not a native
	-- delivery to that frame.  Keeping the two ledgers separate covers either
	-- dispatch order: native-before-engine and engine-before-native.
	if not fromEngineReplay then
		addDecisionFrame(entry, frame or DECISION_NO_FRAME)
	end
end

local function checkSenderMute(self, key, now)
	local entry = self.burstState[key]
	if not entry or (tonumber(entry.mutedUntil) or 0) <= now then
		return false
	end
	entry.expires = math.max(tonumber(entry.windowEnds) or now, entry.mutedUntil)
	return true, entry.muteSource or "burst"
end

local function beginSenderMute(self, key, now, duration, source)
	if duration <= 0 then
		return false
	end
	local entry = self.burstState[key]
	if not entry then
		entry = insertBounded(
			self,
			"burstState",
			"burstRing",
			"burstInsert",
			"burstCount",
			BURST_CAPACITY,
			key,
			{
				count = 0,
				windowEnds = now,
				mutedUntil = 0,
				expires = now,
			}
		)
	end
	if (tonumber(entry.mutedUntil) or 0) > now then
		return false
	end
	entry.mutedUntil = now + duration
	entry.muteSource = source
	entry.expires = math.max(tonumber(entry.windowEnds) or now, entry.mutedUntil)
	return true
end

local function checkBurst(self, key, now, config)
	local entry = self.burstState[key]
	if not entry then
		entry = insertBounded(
			self,
			"burstState",
			"burstRing",
			"burstInsert",
			"burstCount",
			BURST_CAPACITY,
			key,
			{
				count = 1,
				windowEnds = now + config.window,
				mutedUntil = 0,
				expires = now + config.window,
			}
		)
		return false
	end

	if entry.mutedUntil > now then
		entry.expires = math.max(entry.windowEnds, entry.mutedUntil)
		return true, entry.muteSource == "duplicate" and "duplicateMuted" or "muted", false
	end
	if now >= entry.windowEnds then
		entry.count = 1
		entry.windowEnds = now + config.window
		entry.mutedUntil = 0
		entry.expires = entry.windowEnds
		return false
	end

	entry.count = math.min(entry.count + 1, config.limit + 1)
	if entry.count > config.limit then
		entry.mutedUntil = now + config.muteDuration
		entry.muteSource = "burst"
		entry.expires = math.max(entry.windowEnds, entry.mutedUntil)
		-- Only the transition into a real timed mute creates a strike. Repeated
		-- lines while muted return above and ChatFrame fan-out is decision-cached.
		return true, "burst", config.muteDuration > 0
	end
	entry.expires = entry.windowEnds
	return false
end

local function checkDuplicate(self, key, now, config)
	local entry = self.duplicateState[key]
	if not entry then
		entry = insertBounded(
			self,
			"duplicateState",
			"duplicateRing",
			"duplicateInsert",
			"duplicateCount",
			DUPLICATE_CAPACITY,
			key,
			{ count = 1, expires = now + config.window }
		)
		return false
	end
	if entry.expires <= now then
		entry.count = 1
		entry.expires = now + config.window
		return false
	end

	-- Keep one overflow slot even when timed duplicate mutes are disabled so
	-- hide-only duplicate filtering still recognizes every repeat.
	local maximumCount = config.allowedCopies + math.max(1, config.muteAfter)
	entry.count = math.min(entry.count + 1, maximumCount)
	-- Sliding expiry keeps a sustained duplicate flood suppressed until it has
	-- been quiet for one complete duplicate window.
	entry.expires = now + config.window
	if entry.count <= config.allowedCopies then
		return false
	end
	-- muteAfter counts suppressed copies, not the allowed first copy.  This
	-- makes one accidental repeat harmless while a persistent identical flood
	-- earns the same timed mute/strike/escalation path as a burst flood.
	local suppressed = entry.count - config.allowedCopies
	return true, config.muteAfter > 0 and suppressed >= config.muteAfter
end

local function evaluate(self, definition, event, message, sender, channelName, channelNumber, channelBaseName, guid, bnetAccountId, now)
	local config = self.config
	-- Inform events are delivery echoes for the user's own sent whispers. Their
	-- sender argument is the recipient, so name/GUID exemption cannot identify
	-- them reliably. Never hide them, even when exemptSelf is disabled.
	if definition.selfEvent then
		return false, "self"
	end
	local selfMessage = isSelfMessage(self, definition, sender, guid)
	local descriptor = senderDescriptor(self, definition, sender, guid, bnetAccountId)
	if not descriptor then
		return false, "sender"
	end
	-- A local ban is stronger than an analysis-scope toggle: once banned, every
	-- intercepted incoming player-chat event is hidden until explicit unban.
	-- Delivery echoes and the user's own messages can never be locally banned.
	if not selfMessage then
		local ban = findIdentityRecord(self.banIndex, descriptor, true)
		if ban then
			enrichBanIdentity(self, ban, descriptor)
			return true, "localBan"
		end
	end
	if not config.scopes[definition.scope] then
		return false, "scope"
	end
	if config.exemptSelf and selfMessage then
		return false, "self"
	end

	local senderKey = floodIdentity(descriptor)
	if not senderKey or senderKey == "" then
		return false, "sender"
	end
	-- A sender cannot evade a timed mute or burst threshold by hopping between
	-- channels.  Scope toggles above still decide which sources Chatty watches;
	-- once an eligible remote sender is being watched, the sender is the whole
	-- rate-limit identity.
	local senderFloodKey = senderKey
	local muted, muteSource = checkSenderMute(self, senderFloodKey, now)
	if muted then
		if muteSource == "duplicate" then
			return true, "duplicateMuted"
		end
		return true, "muted"
	end

	if config.burst.enabled then
		local blocked, reason, newMute = checkBurst(self, senderFloodKey, now, config.burst)
		if blocked then
			if newMute and not selfMessage then
				recordMuteStrike(self, descriptor, "burst", definition, event, channelName, message)
			end
			return true, reason
		end
	end

	if config.duplicate.enabled then
		local normalized = normalizeMessage(message, config.duplicate)
		if string.len(normalized) < config.duplicate.minimumLength then
			return false, "short"
		end
		-- Do not put event, channel, or source into this key.  A person pasting
		-- the same advert into different channels is still one duplicate episode.
		local key = senderKey .. SEPARATOR .. normalized
		local blocked, shouldMute = checkDuplicate(self, key, now, config.duplicate)
		if blocked then
			if shouldMute and beginSenderMute(self, senderFloodKey, now, config.burst.muteDuration, "duplicate") then
				if not selfMessage then
					recordMuteStrike(self, descriptor, "duplicate", definition, event, channelName, message)
				end
				return true, "duplicateMute"
			end
			return true, "duplicate"
		end
	end

	return false, "allowed"
end

local function prepare(self)
	if self.initialized then
		return
	end
	self.initialized = true
	self.enabled = false
	self.registeredEvents = {}
	self.config = compileSettings()
	resetBoundedState(self)
	refreshPlayerIdentity(self)
	rebuildPersistentIndexes(self)
	pruneExpiredOffenders(self, wallTime())
	self.filter = function(frame, event, ...)
		return SpamControl:OnChatFilter(frame, event, ...)
	end
	self:ResetStats()
end

function SpamControl:OnChatFilter(frame, event, ...)
	local definition = definitionByEvent[event]
	if not self.enabled or not definition then
		return false, ...
	end

	local message, sender, _, channelName, target, _, _, channelNumber, channelBaseName, _, lineId, guid, bnSenderId, extendedBnetId = ...
	-- Protocol channels are intentionally quarantined by the Sync rail, not
	-- treated as player spam.  This check has to happen before the duplicate /
	-- burst states because MessageEngine runs chat filters before it captures a
	-- record; blocking here would make the protocol line vanish entirely.
	if event == "CHAT_MSG_CHANNEL" and addon.IsSyncProtocolMessage then
		local isSync = addon:IsSyncProtocolMessage(event, message, channelName, channelBaseName)
		if isSync then
			return false, ...
		end
	end

	local now = currentTime()
	-- Only Battle.net events own these arguments. Ascension fills arg13/14 with
	-- a zero placeholder for ordinary chat, so never carry it into a normal
	-- player identity or a persistent ban lookup.
	local bnetAccountId
	if definition.scope == "bnet" then
		bnetAccountId = usableBnetAccountId(extendedBnetId) or usableBnetAccountId(bnSenderId)
	end
	local decisionKey = decisionIdentity(
		event,
		message,
		sender,
		channelName,
		target,
		channelNumber,
		channelBaseName,
		lineId,
		guid,
		bnetAccountId
	)
	local cached = self.decisionCache[decisionKey]
	local fromEngineReplay = (self.messageEngineReplayDepth or 0) > 0
	if isDecisionFanout(cached, frame, now, fromEngineReplay) then
		self.stats.cacheHits = self.stats.cacheHits + 1
		if cached.blocked then
			return true
		end
		return false, ...
	end
	-- Every Blizzard chat frame (and MessageEngine) can ask about the same line.
	-- Cached fan-out should be almost free; only a new decision pays cleanup.
	sweepExpired(self, now)

	local blocked, reason = evaluate(
		self,
		definition,
		event,
		message,
		sender,
		channelName,
		channelNumber,
		channelBaseName,
		guid,
		bnetAccountId,
		now
	)
	cacheDecision(self, decisionKey, blocked, now, frame, fromEngineReplay)

	local stats = self.stats
	stats.processed = stats.processed + 1
	if blocked then
		stats.blocked = stats.blocked + 1
		if reason == "duplicate" then
			stats.duplicateBlocked = stats.duplicateBlocked + 1
		elseif reason == "duplicateMute" then
			stats.duplicateBlocked = stats.duplicateBlocked + 1
			stats.duplicateMuteBlocked = stats.duplicateMuteBlocked + 1
		elseif reason == "duplicateMuted" then
			stats.duplicateBlocked = stats.duplicateBlocked + 1
			stats.duplicateMutedBlocked = stats.duplicateMutedBlocked + 1
		elseif reason == "burst" then
			stats.burstBlocked = stats.burstBlocked + 1
		elseif reason == "muted" then
			stats.mutedBlocked = stats.mutedBlocked + 1
		elseif reason == "localBan" then
			stats.localBanBlocked = stats.localBanBlocked + 1
		end
		return true
	end

	stats.allowed = stats.allowed + 1
	if reason == "self" then
		stats.selfExempted = stats.selfExempted + 1
	elseif reason == "scope" then
		stats.scopeBypassed = stats.scopeBypassed + 1
	elseif reason == "short" then
		stats.shortBypassed = stats.shortBypassed + 1
	elseif reason == "sender" then
		stats.senderBypassed = stats.senderBypassed + 1
	end
	return false, ...
end

-- MessageEngine receives the same chat event independently of Blizzard's
-- ChatFrames.  Do not make it replay the entire global ChatFrame filter list:
-- stateful third-party filters (ElvUI's chat throttle is one example) see the
-- replay as a second message and can hide every normal channel line. Query
-- only our own firewall through this narrow bridge. The shared decision ledger
-- coalesces this with the native filter fanout without trusting server line IDs.
function SpamControl:ShouldBlockEngineEvent(event, ...)
	prepare(self)
	if not self.enabled or not definitionByEvent[event] then
		return false
	end

	self.messageEngineReplayDepth = (self.messageEngineReplayDepth or 0) + 1
	local ok, resultOrError = pcall(function(...)
		return packValues(self:OnChatFilter(DECISION_ENGINE_REPLAY_FRAME, event, ...))
	end, ...)
	self.messageEngineReplayDepth = self.messageEngineReplayDepth - 1
	if not ok then
		-- A filter failure must not turn the chat renderer into a black hole.
		-- Native ChatFrame filters retain Blizzard's normal error behavior; the
		-- direct capture bridge fails open and lets the line remain visible.
		return false
	end
	return resultOrError[1] and true or false
end

function SpamControl:Initialize()
	prepare(self)
	self.config = compileSettings()
	rebuildPersistentIndexes(self)
	pruneExpiredOffenders(self, wallTime())
	return self:SetEnabled(self.config.enabled)
end

function SpamControl:SetEnabled(enabled)
	prepare(self)
	self.config = compileSettings()
	ensurePersistentStorage(self)
	local shouldEnable = enabled and true or false
	if shouldEnable == self.enabled then
		return true
	end

	if not shouldEnable then
		local removeFilter = _G.ChatFrame_RemoveMessageEventFilter
		if removeFilter then
			for event in pairs(self.registeredEvents) do
				pcall(removeFilter, event, self.filter)
			end
		end
		self.registeredEvents = {}
		self.enabled = false
		resetBoundedState(self)
		return true
	end

	local addFilter = _G.ChatFrame_AddMessageEventFilter
	if not addFilter then
		return false
	end

	local registered = 0
	for index = 1, #eventDefinitions do
		local event = eventDefinitions[index].event
		local ok, result = pcall(addFilter, event, self.filter)
		if ok and result ~= false then
			self.registeredEvents[event] = true
			registered = registered + 1
		end
	end
	self.enabled = registered > 0
	return self.enabled
end

function SpamControl:ResetForProfile()
	prepare(self)
	self.config = compileSettings()
	resetBoundedState(self)
	refreshPlayerIdentity(self)
	rebuildPersistentIndexes(self)
	pruneExpiredOffenders(self, wallTime())
	return self:SetEnabled(self.config.enabled)
end

function SpamControl:RefreshSettings()
	prepare(self)
	self.config = compileSettings()
	-- Existing expiry/count state was built under the previous windows and
	-- normalization rules. Drop it so every control takes effect immediately;
	-- session statistics intentionally remain intact.
	resetBoundedState(self)
	rebuildPersistentIndexes(self)
	pruneExpiredOffenders(self, wallTime())
	return self:SetEnabled(self.config.enabled)
end

function SpamControl:GetStats()
	prepare(self)
	local result = {}
	for key, value in pairs(self.stats) do
		result[key] = value
	end
	local registered = 0
	for _ in pairs(self.registeredEvents) do
		registered = registered + 1
	end
	result.enabled = self.enabled and true or false
	result.registeredEvents = registered
	result.trackedDuplicates = self.duplicateCount
	result.trackedBursts = self.burstCount
	result.cachedDecisions = self.decisionCount
	result.bans = self.banCount or 0
	result.offenders = self.offenderCount or 0
	-- Concise aliases are the stable surface consumed by the configuration UI.
	result.duplicates = result.duplicateBlocked
	result.bursts = result.burstBlocked + result.mutedBlocked
	result.duplicateMutes = result.duplicateMuteBlocked + result.duplicateMutedBlocked
	return result
end

function SpamControl:ResetStats()
	self.stats = {
		processed = 0,
		allowed = 0,
		blocked = 0,
		duplicateBlocked = 0,
		duplicateMuteBlocked = 0,
		duplicateMutedBlocked = 0,
		burstBlocked = 0,
		mutedBlocked = 0,
		localBanBlocked = 0,
		newMutes = 0,
		strikes = 0,
		automaticBans = 0,
		manualBans = 0,
		unbans = 0,
		banCapacityReached = 0,
		cacheHits = 0,
		selfExempted = 0,
		scopeBypassed = 0,
		shortBypassed = 0,
		senderBypassed = 0,
	}
end

local function newestFirst(left, right, timestampField)
	local leftTime = tonumber(left[timestampField]) or 0
	local rightTime = tonumber(right[timestampField]) or 0
	if leftTime ~= rightTime then
		return leftTime > rightTime
	end
	return string.lower(tostring(left.fullName or left.name or left.id or ""))
		< string.lower(tostring(right.fullName or right.name or right.id or ""))
end

function SpamControl:GetBans()
	prepare(self)
	rebuildPersistentIndexes(self)
	local result = {}
	local storage = ensurePersistentStorage(self)
	for _, record in pairs(storage.bans) do
		if type(record) == "table" then
			local copy = shallowCopy(record)
			copy.evidence = copyEvidence(record.evidence)
			result[#result + 1] = copy
		end
	end
	table.sort(result, function(left, right)
		return newestFirst(left, right, "bannedAt")
	end)
	return result
end

-- Stable, read-only evidence API for the Ban List.  The UI never receives a
-- live SavedVariables table, so opening a report cannot accidentally mutate a
-- ban or its retained incident samples.
function SpamControl:GetBanReport(idOrName)
	prepare(self)
	local value = trimText(idOrName, 160)
	if value == "" then
		return nil
	end
	local storage = ensurePersistentStorage(self)
	local record = findManagedRecord(storage.bans, value, "bannedAt")
	if not record then
		local descriptor = manualDescriptor(self, value)
		record = descriptor and findIdentityRecord(self.banIndex, descriptor, true) or nil
	end
	if not record then
		return nil
	end
	local report = shallowCopy(record)
	report.evidence = copyEvidence(record.evidence)
	return report
end

function SpamControl:GetOffenders()
	prepare(self)
	pruneExpiredOffenders(self, wallTime())
	local result = {}
	local storage = ensurePersistentStorage(self)
	for _, record in pairs(storage.offenders) do
		if type(record) == "table" then
			result[#result + 1] = shallowCopy(record)
		end
	end
	table.sort(result, function(left, right)
		return newestFirst(left, right, "lastStrike")
	end)
	return result
end

function SpamControl:BanSender(name, metadata)
	prepare(self)
	local descriptor = manualDescriptor(self, name, metadata)
	if not descriptor then
		return false, "invalid"
	end
	if descriptorIsSelf(self, descriptor) then
		return false, "self"
	end
	local offender = findIdentityRecord(self.offenderIndex, descriptor)
	local strikes = type(metadata) == "table" and tonumber(metadata.strikes) or nil
	if not strikes and offender then
		strikes = offender.strikes
	end
	local ok, record, created = addBan(self, descriptor, "manual", strikes, "manual")
	if not ok then
		return false, record
	end
	if created then
		self.stats.manualBans = self.stats.manualBans + 1
	end
	return true, shallowCopy(record)
end

function SpamControl:UnbanSender(idOrName)
	prepare(self)
	local value = trimText(idOrName, 160)
	if value == "" then
		return false
	end
	local storage = ensurePersistentStorage(self)
	local record = findManagedRecord(storage.bans, value, "bannedAt")
	if not record then
		local descriptor = manualDescriptor(self, value)
		record = descriptor and findIdentityRecord(self.banIndex, descriptor, true) or nil
	end
	if not record then
		return false
	end
	local descriptor = descriptorFromRecord(record)
	storage.bans[record.id] = nil
	resetOffenderForDescriptor(self, descriptor)
	rebuildPersistentIndexes(self)
	resetDecisionState(self)
	self.stats.unbans = self.stats.unbans + 1
	return true
end

function SpamControl:ClearBans()
	prepare(self)
	local storage = ensurePersistentStorage(self)
	local removed = persistentCount(storage.bans)
	if removed <= 0 then
		return 0
	end
	-- Clearing a ban is an explicit pardon. Remove the associated strike ledger
	-- too so a sender cannot be immediately auto-banned on the next timed mute.
	local offenderIds = {}
	for _, ban in pairs(storage.bans) do
		if type(ban) == "table" then
			local offender = findIdentityRecord(self.offenderIndex, descriptorFromRecord(ban))
			if offender then offenderIds[offender.id] = true end
		end
	end
	for id in pairs(offenderIds) do
		storage.offenders[id] = nil
	end
	for id in pairs(storage.bans) do
		storage.bans[id] = nil
	end
	rebuildPersistentIndexes(self)
	resetDecisionState(self)
	self.stats.unbans = self.stats.unbans + removed
	return removed
end

function SpamControl:ResetOffender(idOrName)
	prepare(self)
	local value = trimText(idOrName, 160)
	if value == "" then
		return false
	end
	local storage = ensurePersistentStorage(self)
	local record = findManagedRecord(storage.offenders, value, "lastStrike")
	if not record then
		local descriptor = manualDescriptor(self, value)
		record = descriptor and findIdentityRecord(self.offenderIndex, descriptor) or nil
	end
	if not record then
		return false
	end
	storage.offenders[record.id] = nil
	rebuildPersistentIndexes(self)
	return true
end

function SpamControl:ClearOffenders()
	prepare(self)
	local storage = ensurePersistentStorage(self)
	local removed = persistentCount(storage.offenders)
	for id in pairs(storage.offenders) do
		storage.offenders[id] = nil
	end
	rebuildPersistentIndexes(self)
	return removed
end

function SpamControl:GetBanStats()
	prepare(self)
	local result = { banned = 0, automatic = 0, manual = 0, capacity = BAN_CAPACITY }
	local storage = ensurePersistentStorage(self)
	for _, record in pairs(storage.bans) do
		if type(record) == "table" then
			result.banned = result.banned + 1
			if record.source == "automatic" then
				result.automatic = result.automatic + 1
			else
				result.manual = result.manual + 1
			end
		end
	end
	return result
end

function SpamControl:GetOffenderStats()
	prepare(self)
	pruneExpiredOffenders(self, wallTime())
	local result = { offenders = 0, strikes = 0, capacity = OFFENDER_CAPACITY }
	local storage = ensurePersistentStorage(self)
	for _, record in pairs(storage.offenders) do
		if type(record) == "table" then
			result.offenders = result.offenders + 1
			result.strikes = result.strikes + math.max(0, tonumber(record.strikes) or 0)
		end
	end
	return result
end
