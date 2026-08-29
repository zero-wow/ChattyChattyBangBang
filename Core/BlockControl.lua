local addon = ChattyChattyBangBang

-- Message Blocks are deliberately separate from Spam Control.  Spam Control
-- answers "is this sender flooding chat?" while this module answers "does the
-- player never want to see this kind of line?"  Keeping those concerns apart
-- makes a local UI failure (for example a cooldown error) inexpensive to hide
-- without accidentally muting another player.
local BlockControl = {}
addon.BlockControl = BlockControl

local MAX_RULES = 64
local MAX_TEXT_LENGTH = 160
local MAX_NAME_LENGTH = 40
local MAX_SOURCE_ID_LENGTH = 96
local MAX_EVENT_LENGTH = 64
local MAX_SOURCES = 128
local MAX_EVENTS = 64
local MAX_SENDER_KEYS = 4
local MAX_SENDER_KEY_LENGTH = 160
local MAX_SENDER_LABEL_LENGTH = 48
local ARCHIVE_SCHEMA = 1
local ARCHIVE_DEFAULT_MAX_ENTRIES = 500
local ARCHIVE_MIN_ENTRIES = 25
local ARCHIVE_MAX_ENTRIES = 1000
local ARCHIVE_DEFAULT_RETENTION_DAYS = 7
local ARCHIVE_MIN_RETENTION_DAYS = 1
local ARCHIVE_MAX_RETENTION_DAYS = 90
local MAX_ARCHIVE_TEXT_LENGTH = 512
local MAX_ARCHIVE_FINGERPRINT_LENGTH = 1024

local FALLBACK_BLOCKS = {
	enabled = true,
	rules = {},
	sequence = 0,
	revision = 0,
	uiFeedback = {
		coalesce = true,
		window = 1.5,
	},
	archive = {
		schema = ARCHIVE_SCHEMA,
		enabled = true,
		maxEntries = ARCHIVE_DEFAULT_MAX_ENTRIES,
		retentionDays = ARCHIVE_DEFAULT_RETENTION_DAYS,
		nextSequence = 1,
		entries = {},
	},
}

local eventLabels = {
	CCBB_LOCAL_MESSAGE = "Local add-on feedback",
	UI_ERROR_MESSAGE = "UI alerts and errors",
	CHAT_MSG_SYSTEM = "System messages",
	CHAT_MSG_SAY = "Say",
	CHAT_MSG_YELL = "Yell",
	CHAT_MSG_EMOTE = "Emotes",
	CHAT_MSG_TEXT_EMOTE = "Text emotes",
	CHAT_MSG_WHISPER = "Whispers",
	CHAT_MSG_WHISPER_INFORM = "Sent whispers",
	CHAT_MSG_BN_WHISPER = "Battle.net whispers",
	CHAT_MSG_BN_WHISPER_INFORM = "Sent Battle.net whispers",
	CHAT_MSG_BN_CONVERSATION = "Battle.net conversations",
	CHAT_MSG_AFK = "AFK replies",
	CHAT_MSG_DND = "DND replies",
	CHAT_MSG_CHANNEL = "Channels",
	CHAT_MSG_GUILD = "Guild chat",
	CHAT_MSG_GUILD_ACHIEVEMENT = "Guild achievements",
	CHAT_MSG_OFFICER = "Officer chat",
	CHAT_MSG_PARTY = "Party chat",
	CHAT_MSG_PARTY_LEADER = "Party leader chat",
	CHAT_MSG_RAID = "Raid chat",
	CHAT_MSG_RAID_LEADER = "Raid leader chat",
	CHAT_MSG_RAID_WARNING = "Raid warnings",
	CHAT_MSG_BATTLEGROUND = "Battleground chat",
	CHAT_MSG_BATTLEGROUND_LEADER = "Battleground leader chat",
	CHAT_MSG_INSTANCE_CHAT = "Instance chat",
	CHAT_MSG_INSTANCE_CHAT_LEADER = "Instance leader chat",
	CHAT_MSG_LOOT = "Loot messages",
	CHAT_MSG_MONEY = "Money messages",
	CHAT_MSG_ACHIEVEMENT = "Achievements",
	CHAT_MSG_BG_SYSTEM_NEUTRAL = "Battleground notices",
	CHAT_MSG_BG_SYSTEM_ALLIANCE = "Alliance battleground notices",
	CHAT_MSG_BG_SYSTEM_HORDE = "Horde battleground notices",
	CHAT_MSG_ADDON = "Add-on messages",
}

local function trim(value, maximumLength)
	if type(value) ~= "string" then
		return ""
	end
	value = string.gsub(value, "^%s+", "")
	value = string.gsub(value, "%s+$", "")
	if maximumLength and string.len(value) > maximumLength then
		value = string.sub(value, 1, maximumLength)
	end
	return value
end

local function copySet(values)
	local result = {}
	for key, selected in pairs(values or {}) do
		if selected then
			result[key] = true
		end
	end
	return result
end

local function normalizeMatchMode(value)
	if type(value) ~= "string" then
		return "contains"
	end
	value = string.lower(trim(value, 16))
	if value == "exact" or value == "equals" or value == "equal" or value == "full" then
		return "exact"
	end
	return "contains"
end

local function normalizeSourceId(value)
	return trim(value, MAX_SOURCE_ID_LENGTH)
end

local function normalizeEvent(value)
	value = string.upper(trim(value, MAX_EVENT_LENGTH))
	if value == "" or string.find(value, "^[A-Z][A-Z0-9_]*$") == nil then
		return nil
	end
	return value
end

local function cleanSenderText(value, maximumLength)
	local text = trim(value, maximumLength or MAX_SENDER_LABEL_LENGTH)
	local linked = string.match(text, "|Hplayer:([^:|]+)")
	if linked and linked ~= "" then
		text = linked
	else
		text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
		text = string.gsub(text, "|r", "")
		text = string.gsub(text, "^%[", "")
		text = string.gsub(text, "%]$", "")
	end
	return trim(text, maximumLength or MAX_SENDER_LABEL_LENGTH)
end

local function normalizeSenderName(value)
	local text = string.lower(cleanSenderText(value, MAX_SENDER_KEY_LENGTH))
	-- Keep a full realm-qualified name intact.  We deliberately do not fall
	-- back to the base name: Name-Realm and Name-OtherRealm must not collide.
	return string.gsub(text, "%s+", "")
end

local function normalizeIdentityToken(value)
	value = string.lower(trim(value, MAX_SENDER_KEY_LENGTH))
	if value == "" or value == "0" then
		return nil
	end
	return value
end

local function normalizeSenderKey(value)
	value = trim(value, MAX_SENDER_KEY_LENGTH)
	local kind, payload = string.match(value, "^([%a]+):(.*)$")
	if not kind then
		return nil
	end
	kind = string.lower(kind)
	if kind == "guid" then
		payload = normalizeIdentityToken(payload)
	elseif kind == "bnet" then
		payload = normalizeIdentityToken(payload)
		if payload and tonumber(payload) and tonumber(payload) <= 0 then
			payload = nil
		end
	elseif kind == "name" then
		payload = string.lower(trim(payload, MAX_SENDER_KEY_LENGTH))
		payload = string.gsub(payload, "%s+", "")
		if payload == "" then
			payload = nil
		end
	else
		return nil
	end
	return payload and (kind .. ":" .. payload) or nil
end

local function normalizeSenderKeys(value)
	local result = {}
	local count = 0
	local function add(candidate)
		if count >= MAX_SENDER_KEYS then
			return false
		end
		local key = normalizeSenderKey(candidate)
		if key and not result[key] then
			result[key] = true
			count = count + 1
		end
		return count < MAX_SENDER_KEYS
	end
	if type(value) == "string" then
		add(value)
	elseif type(value) == "table" then
		for index = 1, #value do
			if not add(value[index]) then
				break
			end
		end
		if count < MAX_SENDER_KEYS then
			for key, selected in pairs(value) do
				if type(key) == "string" and selected and not add(key) then
					break
				end
			end
		end
	end
	return result
end

local function senderKeysForRecord(record)
	local keys = {}
	if type(record) ~= "table" then
		return keys, ""
	end
	local guid = normalizeIdentityToken(record.guid)
	if guid then
		keys["guid:" .. guid] = true
	end
	local event = type(record.event) == "string" and record.event or ""
	local isBNet = record.isBNet == true or string.find(event, "^CHAT_MSG_BN_") ~= nil
	local bnetAccountId = isBNet and normalizeIdentityToken(record.bnetAccountId) or nil
	if bnetAccountId and (not tonumber(bnetAccountId) or tonumber(bnetAccountId) > 0) then
		keys["bnet:" .. bnetAccountId] = true
	end
	local normalizedName = normalizeSenderName(record.sender)
	if normalizedName ~= "" then
		keys["name:" .. normalizedName] = true
	end
	return keys, cleanSenderText(record.sender, MAX_SENDER_LABEL_LENGTH)
end

local function normalizeSources(value)
	if type(value) ~= "table" then
		return {}
	end
	local sources = {}
	local count = 0
	local function add(sourceId)
		if count >= MAX_SOURCES then
			return false
		end
		sourceId = normalizeSourceId(sourceId)
		if sourceId ~= "" and not sources[sourceId] then
			sources[sourceId] = true
			count = count + 1
		end
		return count < MAX_SOURCES
	end
	for index = 1, #value do
		if not add(value[index]) then
			break
		end
	end
	if count < MAX_SOURCES then
		for sourceId, selected in pairs(value) do
			if type(sourceId) == "string" and selected and not add(sourceId) then
				break
			end
		end
	end
	return sources
end

local function normalizeEvents(value)
	if type(value) ~= "table" then
		return {}
	end
	local events = {}
	local count = 0
	local function add(event)
		if count >= MAX_EVENTS then
			return false
		end
		event = normalizeEvent(event)
		if event and not events[event] then
			events[event] = true
			count = count + 1
		end
		return count < MAX_EVENTS
	end
	for index = 1, #value do
		if not add(value[index]) then
			break
		end
	end
	if count < MAX_EVENTS then
		for event, selected in pairs(value) do
			if type(event) == "string" and selected and not add(event) then
				break
			end
		end
	end
	return events
end

local function readRuleText(source)
	if type(source) ~= "table" then
		return ""
	end
	local value = source.text
	if value == nil then
		value = source.phrase
	end
	if value == nil then
		value = source.term
	end
	if value == nil and type(source.terms) == "table" then
		value = source.terms[1]
	end
	return trim(value, MAX_TEXT_LENGTH)
end

local function isSafeRuleId(id)
	return type(id) == "string"
		and string.len(id) <= 32
		and string.find(id, "^[%a][%w_%-]*$") ~= nil
end

local function defaultRuleName(text, index)
	text = trim(text, 26)
	if text == "" then
		return "Message Block " .. tostring(index)
	end
	if string.len(text) == 26 then
		text = text .. "..."
	end
	return "Block: " .. text
end

local function sanitizeRule(source, id, index)
	source = type(source) == "table" and source or {}
	local text = readRuleText(source)
	local name = trim(source.name, MAX_NAME_LENGTH)
	if name == "" then
		name = defaultRuleName(text, index)
	end
	local allSources = source.allSources ~= false
	local allEvents = source.allEvents ~= false
	local senderKeys = normalizeSenderKeys(source.senderKeys or source.senderIds or source.senders)
	local hasSenderKeys = next(senderKeys) ~= nil
	-- Existing rules predate sender scoping and must stay broad.  A caller that
	-- supplies valid sender keys without an explicit allSenders flag is clearly
	-- asking for a targeted rule, so preserve that useful API shape too.
	local allSenders
	if source.allSenders == nil then
		allSenders = not hasSenderKeys
	else
		allSenders = source.allSenders ~= false
	end
	if not allSenders and not hasSenderKeys then
		allSenders = true
	end
	local senderLabel = allSenders and "" or cleanSenderText(source.senderLabel or source.senderName or source.sender, MAX_SENDER_LABEL_LENGTH)
	return {
		id = id,
		name = name,
		enabled = source.enabled ~= false,
		text = text,
		matchMode = normalizeMatchMode(source.matchMode or source.mode),
		caseSensitive = source.caseSensitive and true or false,
		allSources = allSources,
		sources = allSources and {} or normalizeSources(source.sources),
		allEvents = allEvents,
		events = allEvents and {} or normalizeEvents(source.events),
		allSenders = allSenders,
		senderKeys = allSenders and {} or senderKeys,
		senderLabel = senderLabel,
	}
end

local ruleFields = {
	id = true,
	name = true,
	enabled = true,
	text = true,
	matchMode = true,
	caseSensitive = true,
	allSources = true,
	sources = true,
	allEvents = true,
	events = true,
	allSenders = true,
	senderKeys = true,
	senderLabel = true,
}

local function setsEqual(left, right)
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	for key, selected in pairs(left) do
		if type(key) ~= "string" or selected ~= true or right[key] ~= true then
			return false
		end
	end
	for key, selected in pairs(right) do
		if selected ~= true or left[key] ~= true then
			return false
		end
	end
	return true
end

local function rulesEqual(left, right)
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	for key in pairs(left) do
		if not ruleFields[key] then
			return false
		end
	end
	if left.id ~= right.id or left.name ~= right.name or left.enabled ~= right.enabled
		or left.text ~= right.text or left.matchMode ~= right.matchMode
		or left.caseSensitive ~= right.caseSensitive
		or left.allSources ~= right.allSources or left.allEvents ~= right.allEvents
		or left.allSenders ~= right.allSenders or left.senderLabel ~= right.senderLabel then
		return false
	end
	return setsEqual(left.sources, right.sources)
		and setsEqual(left.events, right.events)
		and setsEqual(left.senderKeys, right.senderKeys)
end

local function ruleListsEqual(left, right)
	if type(left) ~= "table" or #left ~= #right then
		return false
	end
	for key in pairs(left) do
		if type(key) ~= "number" or key < 1 or key > #right or key ~= math.floor(key) then
			return false
		end
	end
	for index = 1, #right do
		if not rulesEqual(left[index], right[index]) then
			return false
		end
	end
	return true
end

local function copyRule(rule)
	return {
		id = rule.id,
		name = rule.name,
		enabled = rule.enabled,
		text = rule.text,
		matchMode = rule.matchMode,
		caseSensitive = rule.caseSensitive,
		allSources = rule.allSources,
		sources = copySet(rule.sources),
		allEvents = rule.allEvents,
		events = copySet(rule.events),
		allSenders = rule.allSenders,
		senderKeys = copySet(rule.senderKeys),
		senderLabel = rule.senderLabel,
	}
end

local function clampArchiveEntries(value)
	value = tonumber(value)
	if value == nil then
		value = ARCHIVE_DEFAULT_MAX_ENTRIES
	end
	value = math.floor(value + 0.5)
	if value < ARCHIVE_MIN_ENTRIES then
		return ARCHIVE_MIN_ENTRIES
	elseif value > ARCHIVE_MAX_ENTRIES then
		return ARCHIVE_MAX_ENTRIES
	end
	return value
end

local function clampArchiveRetentionDays(value)
	value = tonumber(value)
	if value == nil then
		value = ARCHIVE_DEFAULT_RETENTION_DAYS
	end
	value = math.floor(value + 0.5)
	if value < ARCHIVE_MIN_RETENTION_DAYS then
		return ARCHIVE_MIN_RETENTION_DAYS
	elseif value > ARCHIVE_MAX_RETENTION_DAYS then
		return ARCHIVE_MAX_RETENTION_DAYS
	end
	return value
end

local function normalizeArchiveEpoch(value)
	value = tonumber(value)
	if value == nil or value < 0 then
		return 0
	end
	return math.floor(value)
end

local function normalizeArchiveOccurrences(value)
	value = math.floor(tonumber(value) or 1)
	if value < 1 then
		return 1
	elseif value > 1000000000 then
		return 1000000000
	end
	return value
end

local function copyArchiveEntry(entry)
	return {
		id = entry.id,
		text = entry.text,
		sender = entry.sender,
		senderKey = entry.senderKey,
		sourceId = entry.sourceId,
		sourceLabel = entry.sourceLabel,
		sourceGroup = entry.sourceGroup,
		event = entry.event,
		channel = entry.channel,
		reason = entry.reason,
		ruleId = entry.ruleId,
		ruleName = entry.ruleName,
		occurrences = entry.occurrences,
		firstEpoch = entry.firstEpoch,
		firstTimestamp = entry.firstTimestamp,
		lastEpoch = entry.lastEpoch,
		lastTimestamp = entry.lastTimestamp,
	}
end

local function archiveSenderIdentity(record)
	local keys, label = senderKeysForRecord(record)
	for _, kind in ipairs({ "guid:", "bnet:", "name:" }) do
		for key in pairs(keys) do
			if string.sub(key, 1, #kind) == kind then
				return key, label
			end
		end
	end
	return "", label
end

local function archiveFingerprint(record, rule, senderKey)
	local text = type(record.normalized) == "string" and record.normalized
		or string.lower(type(record.text) == "string" and record.text or "")
	local parts = {
		trim(rule and rule.id, 32),
		normalizeSourceId(record and record.sourceId),
		normalizeEvent(record and record.event) or "",
		senderKey or "",
		trim(text, MAX_ARCHIVE_TEXT_LENGTH),
	}
	return trim(table.concat(parts, "\031"), MAX_ARCHIVE_FINGERPRINT_LENGTH)
end

local function sanitizeArchiveEntry(source, index)
	if type(source) ~= "table" then
		return nil
	end
	local text = trim(source.text, MAX_ARCHIVE_TEXT_LENGTH)
	if text == "" then
		return nil
	end
	local firstEpoch = normalizeArchiveEpoch(source.firstEpoch or source.epoch)
	local lastEpoch = normalizeArchiveEpoch(source.lastEpoch or firstEpoch)
	if lastEpoch < firstEpoch then
		lastEpoch = firstEpoch
	end
	local senderKey = normalizeSenderKey(source.senderKey) or ""
	local entry = {
		id = isSafeRuleId(source.id) and source.id or ("blocked" .. tostring(index)),
		fingerprint = trim(source.fingerprint, MAX_ARCHIVE_FINGERPRINT_LENGTH),
		text = text,
		sender = cleanSenderText(source.sender, MAX_SENDER_LABEL_LENGTH),
		senderKey = senderKey,
		sourceId = normalizeSourceId(source.sourceId),
		sourceLabel = trim(source.sourceLabel, MAX_SOURCE_ID_LENGTH),
		sourceGroup = trim(source.sourceGroup, 32),
		event = normalizeEvent(source.event) or "UNKNOWN",
		channel = trim(source.channel, MAX_SOURCE_ID_LENGTH),
		reason = trim(source.reason, 32),
		ruleId = trim(source.ruleId, 32),
		ruleName = trim(source.ruleName, MAX_NAME_LENGTH),
		occurrences = normalizeArchiveOccurrences(source.occurrences),
		firstEpoch = firstEpoch,
		firstTimestamp = trim(source.firstTimestamp or source.timestamp, 16),
		lastEpoch = lastEpoch,
		lastTimestamp = trim(source.lastTimestamp or source.timestamp, 16),
	}
	if entry.reason == "" then entry.reason = "rule" end
	if entry.fingerprint == "" then
		entry.fingerprint = trim(table.concat({ entry.ruleId, entry.sourceId, entry.event, entry.senderKey, string.lower(entry.text) }, "\031"), MAX_ARCHIVE_FINGERPRINT_LENGTH)
	end
	return entry
end

local function archiveNowEpoch()
	return normalizeArchiveEpoch(time and time() or 0)
end

local function pruneArchive(archive, nowEpoch)
	local entries = type(archive.entries) == "table" and archive.entries or {}
	local retained = {}
	local minimumEpoch = nowEpoch > 0 and nowEpoch - (archive.retentionDays * 86400) or nil
	for index = 1, #entries do
		local entry = sanitizeArchiveEntry(entries[index], index)
		-- Old installs and hand-edited values without a wall-clock timestamp are
		-- kept only until the capacity bound evicts them. A session GetTime value
		-- cannot safely decide age across reloads.
		if entry and (not minimumEpoch or entry.lastEpoch == 0 or entry.lastEpoch >= minimumEpoch) then
			table.insert(retained, entry)
		end
	end
	while #retained > archive.maxEntries do
		table.remove(retained, 1)
	end
	archive.entries = retained
	return retained
end

local function ensureArchive(settings)
	local archive = type(settings.archive) == "table" and settings.archive or {}
	settings.archive = archive
	archive.schema = ARCHIVE_SCHEMA
	archive.enabled = archive.enabled ~= false
	archive.maxEntries = clampArchiveEntries(archive.maxEntries)
	archive.retentionDays = clampArchiveRetentionDays(archive.retentionDays)
	archive.nextSequence = math.max(1, math.floor(tonumber(archive.nextSequence) or 1))
	if type(archive.entries) ~= "table" then
		archive.entries = {}
	end
	local entries = pruneArchive(archive, archiveNowEpoch())
	-- A hand-edited/older archive may have entries but no reliable sequence.
	-- Never reuse an existing blocked<ID> row identifier in that situation.
	for index = 1, #entries do
		local number = string.match(entries[index].id or "", "^blocked(%d+)$")
		if number then
			archive.nextSequence = math.max(archive.nextSequence, (tonumber(number) or 0) + 1)
		end
	end
	return archive
end

local function normalizeBlockSettings(settings)
	if type(settings) ~= "table" then
		settings = {}
	end
	if settings.enabled == nil then
		settings.enabled = true
	else
		settings.enabled = settings.enabled and true or false
	end
	if type(settings.rules) ~= "table" then
		settings.rules = {}
	end
	settings.sequence = math.max(0, math.floor(tonumber(settings.sequence) or 0))
	settings.revision = math.max(0, math.floor(tonumber(settings.revision) or 0))
	if type(settings.uiFeedback) ~= "table" then
		settings.uiFeedback = {}
	end
	local uiFeedback = settings.uiFeedback
	if uiFeedback.coalesce == nil then
		uiFeedback.coalesce = true
	else
		uiFeedback.coalesce = uiFeedback.coalesce and true or false
	end
	local window = tonumber(uiFeedback.window)
	if window == nil then
		window = 1.5
	end
	if window < 0.25 then
		window = 0.25
	elseif window > 10 then
		window = 10
	end
	uiFeedback.window = window
	ensureArchive(settings)
	return settings
end

local function getBlockSettings()
	local smart = addon.GetSmartSettings and addon:GetSmartSettings() or nil
	if type(smart) ~= "table" then
		smart = { blocks = FALLBACK_BLOCKS }
	end
	if type(smart.blocks) ~= "table" then
		smart.blocks = {}
	end
	return normalizeBlockSettings(smart.blocks), smart
end

local function normalizeStoredRules(settings)
	local source = type(settings.rules) == "table" and settings.rules or {}
	local sourceIndexes = {}
	for key, rule in pairs(source) do
		if type(key) == "number" and key >= 1 and key == math.floor(key) and type(rule) == "table" then
			if #sourceIndexes < MAX_RULES then
				table.insert(sourceIndexes, key)
			else
				local largestPosition = 1
				for index = 2, #sourceIndexes do
					if sourceIndexes[index] > sourceIndexes[largestPosition] then
						largestPosition = index
					end
				end
				if key < sourceIndexes[largestPosition] then
					sourceIndexes[largestPosition] = key
				end
			end
		end
	end
	table.sort(sourceIndexes)

	local originalSequence = settings.sequence
	local sequence = math.max(0, math.floor(tonumber(settings.sequence) or 0))
	local usedIds = {}
	local rules = {}
	for sourceIndex = 1, #sourceIndexes do
		if #rules >= MAX_RULES then
			break
		end
		local raw = source[sourceIndexes[sourceIndex]]
		local id = raw.id
		if not isSafeRuleId(id) or usedIds[id] then
			repeat
				sequence = sequence + 1
				id = "block" .. tostring(sequence)
			until not usedIds[id]
		else
			local number = string.match(id, "^block(%d+)$")
			if number then
				sequence = math.max(sequence, tonumber(number) or 0)
			end
		end
		usedIds[id] = true
		table.insert(rules, sanitizeRule(raw, id, #rules + 1))
	end

	local changed = originalSequence ~= sequence or not ruleListsEqual(source, rules)
	settings.rules = rules
	settings.sequence = sequence
	if changed then
		settings.revision = settings.revision + 1
	end
	return rules, changed
end

local function findRule(settings, id)
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local rules = normalizeStoredRules(settings)
	for index = 1, #rules do
		if rules[index].id == id then
			return rules[index], index
		end
	end
	return nil
end

local function rebuildDock()
	local dock = addon.SmartDock
	if dock and dock.RebuildActiveView then
		dock:RebuildActiveView()
	end
end

local function notifyRulesChanged(settings)
	settings.revision = math.max(0, math.floor(tonumber(settings.revision) or 0)) + 1
	BlockControl:RefreshRules(true)
	if addon.MessageEngine and addon.MessageEngine.ReapplyBlockRules then
		addon.MessageEngine:ReapplyBlockRules()
	else
		rebuildDock()
	end
end

local function recordText(record, caseSensitive)
	if type(record) ~= "table" then
		return ""
	end
	if caseSensitive then
		return type(record.text) == "string" and record.text or ""
	end
	if type(record.normalized) == "string" then
		return record.normalized
	end
	return string.lower(type(record.text) == "string" and record.text or "")
end

local function ruleMatchesRecord(rule, record)
	if type(rule) ~= "table" or type(record) ~= "table" or not rule.enabled or rule.text == "" then
		return false
	end
	if not rule.allSources and (type(record.sourceId) ~= "string" or not rule.sources[record.sourceId]) then
		return false
	end
	if not rule.allEvents and (type(record.event) ~= "string" or not rule.events[record.event]) then
		return false
	end
	if not rule.allSenders then
		local recordKeys = senderKeysForRecord(record)
		local senderMatches = false
		for key in pairs(recordKeys) do
			if rule.senderKeys[key] then
				senderMatches = true
				break
			end
		end
		if not senderMatches then
			return false
		end
	end
	local message = recordText(record, rule.caseSensitive)
	local text = rule.caseSensitive and rule.text or string.lower(rule.text)
	if rule.matchMode == "exact" then
		return message == text
	end
	return string.find(message, text, 1, true) ~= nil
end

function BlockControl:IsAvailable()
	return true
end

function BlockControl:RefreshRules(force)
	local settings = getBlockSettings()
	local revision = settings.revision
	if not force and self.settings == settings and self.compiledRevision == revision then
		return settings
	end

	local rules = normalizeStoredRules(settings)
	revision = settings.revision
	local all = {}
	local bySource = {}
	local byEvent = {}
	local bySourceEvent = {}
	for index = 1, #rules do
		local rule = rules[index]
		if rule.enabled and rule.text ~= "" then
			if rule.allSources and rule.allEvents then
				table.insert(all, rule)
			elseif not rule.allSources and rule.allEvents then
				for sourceId in pairs(rule.sources) do
					local list = bySource[sourceId]
					if not list then
						list = {}
						bySource[sourceId] = list
					end
					table.insert(list, rule)
				end
			elseif rule.allSources and not rule.allEvents then
				for event in pairs(rule.events) do
					local list = byEvent[event]
					if not list then
						list = {}
						byEvent[event] = list
					end
					table.insert(list, rule)
				end
			else
				for sourceId in pairs(rule.sources) do
					local sourceEvents = bySourceEvent[sourceId]
					if not sourceEvents then
						sourceEvents = {}
						bySourceEvent[sourceId] = sourceEvents
					end
					for event in pairs(rule.events) do
						local list = sourceEvents[event]
						if not list then
							list = {}
							sourceEvents[event] = list
						end
						table.insert(list, rule)
					end
				end
			end
		end
	end

	self.settings = settings
	self.compiledAll = all
	self.compiledBySource = bySource
	self.compiledByEvent = byEvent
	self.compiledBySourceEvent = bySourceEvent
	self.compiledRevision = revision
	return settings
end

function BlockControl:GetRuntimeSettings()
	-- The hot path never normalizes SavedVariables. Profile changes call
	-- ResetForProfile, and public setters immediately refresh the compiled maps.
	-- The reference check is a small extra guard for a profile changed by AceDB
	-- before its callback reaches us.
	local profile = addon.db and addon.db.profile
	local candidate = profile and profile.smartChat and profile.smartChat.blocks
	if not self.settings or (candidate and candidate ~= self.settings) then
		return self:RefreshRules(true)
	end
	return self.settings
end

function BlockControl:GetSettings()
	local settings = self:RefreshRules()
	return {
		enabled = settings.enabled,
		uiFeedback = {
			coalesce = settings.uiFeedback.coalesce,
			window = settings.uiFeedback.window,
		},
	}
end

function addon:GetBlockSettings()
	return BlockControl:GetSettings()
end

function addon:SetBlockControlEnabled(enabled)
	local settings = getBlockSettings()
	local nextValue = enabled and true or false
	if settings.enabled ~= nextValue then
		settings.enabled = nextValue
		BlockControl:SetEnabled(nextValue)
		if addon.MessageEngine and addon.MessageEngine.ReapplyBlockRules then
			addon.MessageEngine:ReapplyBlockRules()
		else
			rebuildDock()
		end
	end
	return settings.enabled
end

function addon:SetUIFeedbackCoalescing(enabled, window)
	local settings = getBlockSettings()
	local feedback = settings.uiFeedback
	feedback.coalesce = enabled and true or false
	if window ~= nil then
		window = tonumber(window)
		if window == nil then
			return false, "invalid-window"
		end
		if window < 0.25 then
			window = 0.25
		elseif window > 10 then
			window = 10
		end
		feedback.window = window
	end
	BlockControl.recentUIFeedback = {}
	BlockControl.lastUIFeedbackPrune = nil
	return true, {
		enabled = feedback.coalesce,
		window = feedback.window,
	}
end

function addon:GetBlockRules()
	local settings = getBlockSettings()
	local rules = normalizeStoredRules(settings)
	local result = {}
	for index = 1, #rules do
		result[index] = copyRule(rules[index])
	end
	return result
end

function addon:CreateBlockRule(data)
	data = type(data) == "table" and data or {}
	if readRuleText(data) == "" then
		return nil, "empty-text"
	end
	local settings = getBlockSettings()
	local rules = normalizeStoredRules(settings)
	if #rules >= MAX_RULES then
		return nil, "limit"
	end
	local usedIds = {}
	for index = 1, #rules do
		usedIds[rules[index].id] = true
	end
	local id
	repeat
		settings.sequence = settings.sequence + 1
		id = "block" .. tostring(settings.sequence)
	until not usedIds[id]
	local rule = sanitizeRule(data, id, #rules + 1)
	table.insert(rules, rule)
	notifyRulesChanged(settings)
	return copyRule(rule)
end

function addon:UpdateBlockRule(id, data)
	local settings = getBlockSettings()
	local existing, index = findRule(settings, id)
	if not existing then
		return nil, "not-found"
	end
	data = type(data) == "table" and data or {}
	local changedText = data.text ~= nil or data.phrase ~= nil or data.term ~= nil or data.terms ~= nil
	local text = changedText and readRuleText(data) or existing.text
	if text == "" then
		return nil, "empty-text"
	end
	-- Do not use `condition and value or fallback` for booleans here: a
	-- deliberate false would otherwise fall through to the old value.  Besides
	-- ordinary enable/scope edits, this is important for a sender-targeted
	-- quick block whose scope can be widened or restored by the editor.
	local function mergedBoolean(key, fallback)
		if data[key] ~= nil then
			return data[key] and true or false
		end
		return fallback and true or false
	end
	local merged = {
		name = data.name ~= nil and data.name or existing.name,
		enabled = mergedBoolean("enabled", existing.enabled),
		text = text,
		matchMode = (data.matchMode ~= nil or data.mode ~= nil) and (data.matchMode or data.mode) or existing.matchMode,
		caseSensitive = mergedBoolean("caseSensitive", existing.caseSensitive),
		allSources = mergedBoolean("allSources", existing.allSources),
		sources = data.sources ~= nil and data.sources or existing.sources,
		allEvents = mergedBoolean("allEvents", existing.allEvents),
		events = data.events ~= nil and data.events or existing.events,
		allSenders = mergedBoolean("allSenders", existing.allSenders),
		senderKeys = data.senderKeys ~= nil and data.senderKeys or existing.senderKeys,
		senderLabel = data.senderLabel ~= nil and data.senderLabel or existing.senderLabel,
	}
	local updated = sanitizeRule(merged, existing.id, index)
	if not rulesEqual(existing, updated) then
		settings.rules[index] = updated
		notifyRulesChanged(settings)
	end
	return copyRule(updated)
end

function addon:SetBlockRuleEnabled(id, enabled)
	return self:UpdateBlockRule(id, { enabled = enabled })
end

function addon:ToggleBlockRule(id)
	local settings = getBlockSettings()
	local rule = findRule(settings, id)
	if not rule then
		return nil, "not-found"
	end
	return self:UpdateBlockRule(id, { enabled = not rule.enabled })
end

function addon:DeleteBlockRule(id)
	local settings = getBlockSettings()
	local _, index = findRule(settings, id)
	if not index then
		return false, "not-found"
	end
	table.remove(settings.rules, index)
	notifyRulesChanged(settings)
	return true
end

function addon:GetBlockSourceDefinitions(ruleId)
	local settings = getBlockSettings()
	local rule = findRule(settings, ruleId)
	if not rule then
		return {}
	end
	local definitions = addon.MessageEngine and addon.MessageEngine.GetSourceDefinitions
		and addon.MessageEngine:GetSourceDefinitions() or {}
	local result = {}
	local seen = {}
	for index = 1, #definitions do
		local source = definitions[index]
		local sourceId = normalizeSourceId(source.sourceId or source.id)
		if sourceId ~= "" then
			table.insert(result, {
				id = sourceId,
				sourceId = sourceId,
				label = source.sourceLabel or source.label or sourceId,
				sourceLabel = source.sourceLabel or source.label or sourceId,
				group = source.sourceGroup or source.group or "other",
				sourceGroup = source.sourceGroup or source.group or "other",
				groupLabel = source.groupLabel,
				static = source.static and true or false,
				learned = source.learned and true or false,
				selected = rule.allSources or rule.sources[sourceId] == true,
			})
			seen[sourceId] = true
		end
	end
	-- A saved rule must remain editable after a server channel was renamed or a
	-- source was pruned from the learned-source cache.
	for sourceId in pairs(rule.sources) do
		if not seen[sourceId] then
			table.insert(result, {
				id = sourceId,
				sourceId = sourceId,
				label = sourceId,
				sourceLabel = sourceId,
				group = "other",
				sourceGroup = "other",
				selected = true,
			})
		end
	end
	table.sort(result, function(left, right)
		if left.sourceGroup ~= right.sourceGroup then
			return left.sourceGroup < right.sourceGroup
		end
		return left.sourceLabel < right.sourceLabel
	end)
	return result
end

function addon:SetBlockRuleAllSources(ruleId, value)
	local settings = getBlockSettings()
	local rule = findRule(settings, ruleId)
	if not rule then
		return false, "not-found"
	end
	local enabled = value and true or false
	if rule.allSources ~= enabled or (enabled and next(rule.sources) ~= nil) then
		rule.allSources = enabled
		if enabled then
			rule.sources = {}
		end
		notifyRulesChanged(settings)
	end
	return true
end

function addon:SetBlockRuleSourceEnabled(ruleId, sourceId, value)
	sourceId = normalizeSourceId(sourceId)
	if sourceId == "" then
		return false, "invalid-source"
	end
	local settings = getBlockSettings()
	local rule = findRule(settings, ruleId)
	if not rule then
		return false, "not-found"
	end
	local selected = value and true or false
	local changed = false
	if rule.allSources then
		if selected then
			return true
		end
		rule.sources = {}
		local definitions = addon.MessageEngine and addon.MessageEngine.GetSourceDefinitions
			and addon.MessageEngine:GetSourceDefinitions() or {}
		for index = 1, #definitions do
			local knownId = normalizeSourceId(definitions[index].sourceId or definitions[index].id)
			if knownId ~= "" then
				rule.sources[knownId] = true
			end
		end
		rule.allSources = false
		changed = true
	end
	if selected and not rule.sources[sourceId] then
		rule.sources[sourceId] = true
		changed = true
	elseif not selected and rule.sources[sourceId] then
		rule.sources[sourceId] = nil
		changed = true
	end
	if changed then
		notifyRulesChanged(settings)
	end
	return true
end

function addon:ResetBlockRuleSources(ruleId)
	return self:SetBlockRuleAllSources(ruleId, true)
end

function addon:GetBlockEventDefinitions(ruleId)
	local settings = getBlockSettings()
	local rule = findRule(settings, ruleId)
	if not rule then
		return {}
	end
	local events = {}
	for event, label in pairs(eventLabels) do
		table.insert(events, {
			id = event,
			event = event,
			label = label,
			selected = rule.allEvents or rule.events[event] == true,
		})
	end
	for event in pairs(rule.events) do
		if not eventLabels[event] then
			table.insert(events, {
				id = event,
				event = event,
				label = event,
				selected = true,
			})
		end
	end
	table.sort(events, function(left, right)
		return left.label < right.label
	end)
	return events
end

function addon:SetBlockRuleAllEvents(ruleId, value)
	local settings = getBlockSettings()
	local rule = findRule(settings, ruleId)
	if not rule then
		return false, "not-found"
	end
	local enabled = value and true or false
	if rule.allEvents ~= enabled or (enabled and next(rule.events) ~= nil) then
		rule.allEvents = enabled
		if enabled then
			rule.events = {}
		end
		notifyRulesChanged(settings)
	end
	return true
end

function addon:SetBlockRuleEventEnabled(ruleId, event, value)
	event = normalizeEvent(event)
	if not event then
		return false, "invalid-event"
	end
	local settings = getBlockSettings()
	local rule = findRule(settings, ruleId)
	if not rule then
		return false, "not-found"
	end
	local selected = value and true or false
	local changed = false
	if rule.allEvents then
		if selected then
			return true
		end
		rule.events = {}
		for knownEvent in pairs(eventLabels) do
			rule.events[knownEvent] = true
		end
		rule.allEvents = false
		changed = true
	end
	if selected and not rule.events[event] then
		rule.events[event] = true
		changed = true
	elseif not selected and rule.events[event] then
		rule.events[event] = nil
		changed = true
	end
	if changed then
		notifyRulesChanged(settings)
	end
	return true
end

function addon:ResetBlockRuleEvents(ruleId)
	return self:SetBlockRuleAllEvents(ruleId, true)
end

-- A sender-targeted rule comes from a concrete chat record.  The editor may
-- always widen it back to every player, but it cannot safely invent a player
-- target for an older broad rule.
function addon:SetBlockRuleAllSenders(ruleId, value)
	local settings = getBlockSettings()
	local rule = findRule(settings, ruleId)
	if not rule then
		return false, "not-found"
	end
	local allSenders = value and true or false
	if not allSenders and next(rule.senderKeys or {}) == nil then
		return false, "no-sender"
	end
	if rule.allSenders ~= allSenders or (allSenders and (next(rule.senderKeys or {}) ~= nil or rule.senderLabel ~= "")) then
		rule.allSenders = allSenders
		if allSenders then
			rule.senderKeys = {}
			rule.senderLabel = ""
		end
		notifyRulesChanged(settings)
	end
	return true
end

function BlockControl:GetSuggestedRule(record)
	if type(record) ~= "table" then
		return nil, "invalid-record"
	end
	local text = trim(record.text, MAX_TEXT_LENGTH)
	if text == "" then
		return nil, "empty-text"
	end
	local sourceId = normalizeSourceId(record.sourceId)
	local event = normalizeEvent(record.event)
	local senderKeys, senderLabel = senderKeysForRecord(record)
	local hasSender = next(senderKeys) ~= nil
	return {
		name = defaultRuleName(text, 1),
		text = text,
		matchMode = "exact",
		caseSensitive = false,
		-- A Shift-hover quick block should be narrowly safe: hide this player's
		-- exact message in its current source/type.  UI/local feedback has no
		-- sender identity and intentionally remains an any-player rule.
		allSources = sourceId == "",
		sources = sourceId ~= "" and { [sourceId] = true } or {},
		allEvents = event == nil,
		events = event and { [event] = true } or {},
		allSenders = not hasSender,
		senderKeys = hasSender and senderKeys or {},
		senderLabel = hasSender and senderLabel or "",
	}
end

function addon:CreateBlockRuleFromRecord(record, options)
	local suggestion, reason = BlockControl:GetSuggestedRule(record)
	if not suggestion then
		return nil, reason
	end
	if type(options) == "string" then
		suggestion.matchMode = options
	elseif type(options) == "table" then
		for key, value in pairs(options) do
			suggestion[key] = value
		end
	end
	return self:CreateBlockRule(suggestion)
end

function BlockControl:BlockRecord(record, mode)
	local rule, reason = addon:CreateBlockRuleFromRecord(record, mode)
	if rule then
		return true, rule
	end
	return false, reason
end

function addon:BlockRecord(record, mode)
	return BlockControl:BlockRecord(record, mode)
end

function addon:TestBlockRule(idOrRule, record)
	local rule
	if type(idOrRule) == "string" then
		local settings = getBlockSettings()
		rule = findRule(settings, idOrRule)
	elseif type(idOrRule) == "table" then
		rule = sanitizeRule(idOrRule, idOrRule.id or "preview", 1)
	end
	if not rule then
		return false, "not-found"
	end
	return ruleMatchesRecord(rule, record), rule
end

function addon:DescribeBlockRule(idOrRule)
	local rule
	if type(idOrRule) == "string" then
		local settings = getBlockSettings()
		rule = findRule(settings, idOrRule)
	elseif type(idOrRule) == "table" then
		rule = idOrRule
	end
	if type(rule) ~= "table" then
		return nil, "not-found"
	end
	local match = rule.matchMode == "exact" and "Exact" or "Contains"
	local sensitivity = rule.caseSensitive and "case-sensitive" or "case-insensitive"
	local sourceScope = rule.allSources and "all sources" or "selected sources"
	local eventScope = rule.allEvents and "all message types" or "selected message types"
	local senderScope = rule.allSenders and "any player" or ("player " .. tostring(rule.senderLabel ~= "" and rule.senderLabel or "saved identity"))
	return match .. " \"" .. tostring(rule.text or "") .. "\" (" .. sensitivity
		.. "; " .. senderScope .. "; " .. sourceScope .. "; " .. eventScope .. ")"
end

local function incrementStat(stats, key)
	stats[key] = (tonumber(stats[key]) or 0) + 1
end

function BlockControl:ResetStats()
	self.stats = {
		blocked = 0,
		manual = 0,
		uiCoalesced = 0,
		lastRuleId = nil,
		lastRuleName = nil,
		lastReason = nil,
		lastText = nil,
		lastTime = 0,
	}
end

function BlockControl:GetStats()
	local stats = self.stats or {}
	return {
		blocked = tonumber(stats.blocked) or 0,
		manual = tonumber(stats.manual) or 0,
		uiCoalesced = tonumber(stats.uiCoalesced) or 0,
		lastRuleId = stats.lastRuleId,
		lastRuleName = stats.lastRuleName,
		lastReason = stats.lastReason,
		lastText = stats.lastText,
		lastTime = tonumber(stats.lastTime) or 0,
	}
end

function addon:GetBlockStats()
	return BlockControl:GetStats()
end

function addon:ResetBlockStats()
	BlockControl:ResetStats()
	return true
end

-- The blocked-message archive is deliberately independent from normal chat
-- history.  A player may keep ordinary history disabled while retaining a
-- small, explicitly disclosed review trail for messages hidden by their own
-- manual rules.
function BlockControl:ArchiveRecord(record, reason, rule)
	if reason ~= "rule" or type(record) ~= "table" or type(rule) ~= "table" then
		return nil, "not-manual-rule"
	end
	local settings = getBlockSettings()
	local archive = ensureArchive(settings)
	if archive.enabled == false then
		return nil, "archive-disabled"
	end
	local text = trim(record.text, MAX_ARCHIVE_TEXT_LENGTH)
	if text == "" then
		return nil, "empty-text"
	end
	-- Retention is a wall-clock policy, never a property of the record being
	-- archived. A historical line can be years old; using its epoch as the
	-- prune clock would let it bypass expiry until a later archive read.
	local nowEpoch = archiveNowEpoch()
	local occurrenceEpoch = normalizeArchiveEpoch(record.epoch)
	local timestamp = trim(record.timestamp, 16)
	local senderKey, sender = archiveSenderIdentity(record)
	local fingerprint = archiveFingerprint(record, rule, senderKey)
	local entries = pruneArchive(archive, nowEpoch)
	if nowEpoch > 0 and occurrenceEpoch > 0
		and occurrenceEpoch < nowEpoch - (archive.retentionDays * 86400)
	then
		-- The normal history caller still unlinks this stale match. It simply
		-- does not create a fresh retained copy in the review archive.
		return nil, "expired"
	end

	for index = #entries, 1, -1 do
		local entry = entries[index]
		if entry.fingerprint == fingerprint then
			entry.occurrences = normalizeArchiveOccurrences(entry.occurrences + 1)
			local previousLastEpoch = normalizeArchiveEpoch(entry.lastEpoch)
			if occurrenceEpoch >= previousLastEpoch then
				entry.lastEpoch = occurrenceEpoch
				entry.lastTimestamp = timestamp ~= "" and timestamp or entry.lastTimestamp
			end
			-- Array order is retention/capacity order. A repeated occurrence must
			-- become the newest row, otherwise a frequently recurring block can be
			-- evicted based on its first occurrence instead of its latest one.
			table.remove(entries, index)
			table.insert(entries, entry)
			return copyArchiveEntry(entry)
		end
	end

	local id = "blocked" .. tostring(archive.nextSequence)
	archive.nextSequence = archive.nextSequence + 1
	local entry = {
		id = id,
		fingerprint = fingerprint,
		text = text,
		sender = sender,
		senderKey = senderKey,
		sourceId = normalizeSourceId(record.sourceId),
		sourceLabel = trim(record.sourceLabel, MAX_SOURCE_ID_LENGTH),
		sourceGroup = trim(record.sourceGroup, 32),
		event = normalizeEvent(record.event) or "UNKNOWN",
		channel = trim(record.channel, MAX_SOURCE_ID_LENGTH),
		reason = "rule",
		ruleId = trim(rule.id, 32),
		ruleName = trim(rule.name, MAX_NAME_LENGTH),
		occurrences = 1,
		firstEpoch = occurrenceEpoch,
		firstTimestamp = timestamp,
		lastEpoch = occurrenceEpoch,
		lastTimestamp = timestamp,
	}
	table.insert(entries, entry)
	pruneArchive(archive, nowEpoch)
	return copyArchiveEntry(entry)
end

function BlockControl:GetArchive()
	local settings = getBlockSettings()
	local archive = ensureArchive(settings)
	local entries = pruneArchive(archive, archiveNowEpoch())
	local result = {}
	for index = #entries, 1, -1 do
		result[#result + 1] = copyArchiveEntry(entries[index])
	end
	return result
end

function BlockControl:GetArchiveStats()
	local settings = getBlockSettings()
	local archive = ensureArchive(settings)
	local entries = pruneArchive(archive, archiveNowEpoch())
	local occurrences = 0
	for index = 1, #entries do
		occurrences = occurrences + normalizeArchiveOccurrences(entries[index].occurrences)
	end
	return {
		enabled = archive.enabled ~= false,
		entries = #entries,
		occurrences = occurrences,
		maxEntries = archive.maxEntries,
		retentionDays = archive.retentionDays,
	}
end

function BlockControl:ClearArchive()
	local settings = getBlockSettings()
	local archive = ensureArchive(settings)
	archive.entries = {}
	archive.nextSequence = 1
	return true
end

function addon:GetBlockedMessageArchive()
	return BlockControl:GetArchive()
end

function addon:GetBlockedMessageArchiveStats()
	return BlockControl:GetArchiveStats()
end

function addon:SetBlockedMessageArchiveEnabled(enabled)
	local settings = getBlockSettings()
	local archive = ensureArchive(settings)
	archive.enabled = enabled and true or false
	if archive.enabled == false then
		-- This is intentionally a privacy action, matching received-history
		-- persistence: disabling saved blocked-message review erases plaintext
		-- that was already retained instead of leaving it behind invisibly.
		archive.entries = {}
		archive.nextSequence = 1
	end
	return true, archive.enabled
end

function addon:SetBlockedMessageArchiveCapacity(value)
	if tonumber(value) == nil then
		return false, "invalid-capacity"
	end
	local settings = getBlockSettings()
	local archive = ensureArchive(settings)
	archive.maxEntries = clampArchiveEntries(value)
	pruneArchive(archive, archiveNowEpoch())
	return true, archive.maxEntries
end

function addon:SetBlockedMessageArchiveRetentionDays(value)
	if tonumber(value) == nil then
		return false, "invalid-retention"
	end
	local settings = getBlockSettings()
	local archive = ensureArchive(settings)
	archive.retentionDays = clampArchiveRetentionDays(value)
	pruneArchive(archive, archiveNowEpoch())
	return true, archive.retentionDays
end

function addon:ClearBlockedMessageArchive()
	return BlockControl:ClearArchive()
end

local function uiFeedbackFingerprint(record)
	local text = recordText(record, false)
	text = string.gsub(text, "%s+", " ")
	return trim(text, MAX_TEXT_LENGTH)
end

function BlockControl:ShouldCoalesceUIFeedback(record, settings, options)
	if record.event ~= "UI_ERROR_MESSAGE" or settings.uiFeedback.coalesce == false
		or (options and options.skipCoalescer) then
		return false
	end
	local fingerprint = uiFeedbackFingerprint(record)
	if fingerprint == "" then
		return false
	end
	local now = tonumber(record.time) or (GetTime and GetTime()) or 0
	local window = settings.uiFeedback.window or 1.5
	self.recentUIFeedback = self.recentUIFeedback or {}
	local previous = self.recentUIFeedback[fingerprint]
	self.recentUIFeedback[fingerprint] = now

	-- Bound this tiny session-only cache.  A macro can produce thousands of
	-- distinct errors across a long session; we retain only recent fingerprints.
	local retention = math.max(window * 2, 3)
	if not self.lastUIFeedbackPrune or now - self.lastUIFeedbackPrune >= retention then
		for key, seenAt in pairs(self.recentUIFeedback) do
			if now < seenAt or now - seenAt > retention then
				self.recentUIFeedback[key] = nil
			end
		end
		self.lastUIFeedbackPrune = now
	end
	return previous ~= nil and now >= previous and now - previous <= window
end

function BlockControl:ShouldBlock(record, options)
	if type(record) ~= "table" then
		return false
	end
	local settings = self:GetRuntimeSettings()
	if not self.enabled or not settings or settings.enabled == false then
		return false
	end
	if self.compiledRevision ~= settings.revision then
		settings = self:RefreshRules(true)
	end

	if self:ShouldCoalesceUIFeedback(record, settings, options) then
		if not (options and options.countStats == false) then
			self.stats = self.stats or {}
			incrementStat(self.stats, "blocked")
			incrementStat(self.stats, "uiCoalesced")
			self.stats.lastRuleId = nil
			self.stats.lastRuleName = "Repeated UI feedback"
			self.stats.lastReason = "ui-coalesced"
			self.stats.lastText = record.text
			self.stats.lastTime = tonumber(record.time) or 0
		end
		return true, "ui-coalesced"
	end

	local sourceId = record.sourceId
	local event = record.event
	local sourceEvents = sourceId and self.compiledBySourceEvent and self.compiledBySourceEvent[sourceId]
	local function processList(list)
		if type(list) ~= "table" then
			return nil
		end
		for index = 1, #list do
			if ruleMatchesRecord(list[index], record) then
				return list[index]
			end
		end
		return nil
	end
	-- Keep these four dispatches explicit. A Lua array containing a nil scoped
	-- list has an undefined length, which could otherwise skip a later scope.
	local rule = processList(self.compiledAll)
		or processList(sourceId and self.compiledBySource and self.compiledBySource[sourceId])
		or processList(event and self.compiledByEvent and self.compiledByEvent[event])
		or processList(sourceEvents and event and sourceEvents[event])
	if rule then
		if not (options and options.countStats == false) then
			self.stats = self.stats or {}
			incrementStat(self.stats, "blocked")
			incrementStat(self.stats, "manual")
			self.stats.lastRuleId = rule.id
			self.stats.lastRuleName = rule.name
			self.stats.lastReason = "rule"
			self.stats.lastText = record.text
			self.stats.lastTime = tonumber(record.time) or 0
		end
		return true, "rule", rule
	end
	return false
end

function BlockControl:ResetForProfile()
	self.settings = nil
	self.compiledRevision = nil
	self.compiledAll = {}
	self.compiledBySource = {}
	self.compiledByEvent = {}
	self.compiledBySourceEvent = {}
	self.recentUIFeedback = {}
	self.lastUIFeedbackPrune = nil
	self:ResetStats()
	local settings = self:RefreshRules(true)
	self.enabled = settings.enabled ~= false
	return settings
end

function BlockControl:SetEnabled(enabled)
	self.enabled = enabled and true or false
	if self.enabled then
		self:RefreshRules()
	end
	return self.enabled
end

function BlockControl:Initialize()
	if not self.initialized then
		self.initialized = true
		self:ResetForProfile()
	end
	return true
end
