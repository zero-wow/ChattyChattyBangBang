local addon = ChattyChattyBangBang
local Suggestions = {}
addon.KeywordSuggestions = Suggestions

local MAX_TRACKED_TERMS = 120
local MAX_DISTINCT_MESSAGES = 24
local MAX_SAMPLE_LENGTH = 120
local MAX_DISMISSED = 96
local DEFAULT_THRESHOLD = 5
local DEFAULT_WINDOW = 900
local DEFAULT_MAX_SUGGESTIONS = 24

local acceptedEvents = {
	CHAT_MSG_SAY = true,
	CHAT_MSG_YELL = true,
	CHAT_MSG_CHANNEL = true,
	CHAT_MSG_PARTY = true,
	CHAT_MSG_PARTY_LEADER = true,
	CHAT_MSG_RAID = true,
	CHAT_MSG_RAID_LEADER = true,
	CHAT_MSG_RAID_WARNING = true,
	CHAT_MSG_INSTANCE_CHAT = true,
	CHAT_MSG_INSTANCE_CHAT_LEADER = true,
}

-- Deliberately small, conservative noise vocabulary. This is not a language
-- model: it only keeps the review queue from filling with connective words and
-- ordinary chat boilerplate while leaving game-specific nouns discoverable.
local stopWords = {
	["a"] = true, ["an"] = true, ["and"] = true, ["are"] = true, ["as"] = true,
	["at"] = true, ["be"] = true, ["but"] = true, ["by"] = true, ["can"] = true,
	["do"] = true, ["done"] = true, ["doing"] = true, ["for"] = true, ["from"] = true, ["get"] = true, ["go"] = true, ["going"] = true, ["good"] = true, ["got"] = true, ["great"] = true,
	["have"] = true, ["he"] = true, ["her"] = true, ["here"] = true, ["how"] = true,
	["i"] = true, ["if"] = true, ["im"] = true, ["in"] = true, ["is"] = true,
	["it"] = true, ["its"] = true, ["join"] = true, ["just"] = true, ["level"] = true, ["levels"] = true, ["like"] = true, ["looking"] = true, ["make"] = true, ["me"] = true, ["more"] = true, ["much"] = true,
	["my"] = true, ["need"] = true, ["no"] = true, ["not"] = true, ["now"] = true, ["of"] = true, ["ok"] = true, ["only"] = true, ["on"] = true, ["one"] = true, ["or"] = true, ["other"] = true, ["our"] = true, ["out"] = true,
	["people"] = true, ["please"] = true, ["pls"] = true, ["really"] = true, ["right"] = true, ["run"] = true, ["runs"] = true, ["some"] = true, ["so"] = true, ["than"] = true, ["that"] = true, ["the"] = true,
	["them"] = true, ["then"] = true, ["there"] = true, ["these"] = true, ["they"] = true, ["this"] = true, ["those"] = true, ["time"] = true, ["to"] = true, ["up"] = true, ["very"] = true, ["want"] = true, ["was"] = true, ["we"] = true, ["well"] = true, ["will"] = true, ["with"] = true, ["work"] = true, ["would"] = true, ["wtf"] = true,
	["yeah"] = true, ["yes"] = true, ["you"] = true, ["your"] = true,
	["http"] = true, ["https"] = true, ["www"] = true, ["com"] = true, ["net"] = true,
}

local function trim(value, maximumLength)
	if type(value) ~= "string" then
		return ""
	end
	value = string.gsub(value, "^%s+", "")
	value = string.gsub(value, "%s+$", "")
	if maximumLength and #value > maximumLength then
		value = string.sub(value, 1, maximumLength)
	end
	return value
end

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in pairs(value) do
		result[key] = copy(child)
	end
	return result
end

local function nowForRecord(record)
	local stamp = type(record) == "table" and tonumber(record.time) or nil
	if stamp and stamp >= 0 then
		return stamp
	end
	return GetTime and GetTime() or 0
end

local function epochForRecord(record)
	local stamp = type(record) == "table" and tonumber(record.epoch) or nil
	if stamp and stamp > 0 then
		return math.floor(stamp)
	end
	return time and time() or 0
end

local function normalizeSettings(settings)
	settings.keywordSuggestions = type(settings.keywordSuggestions) == "table" and settings.keywordSuggestions or {}
	local value = settings.keywordSuggestions
	if value.enabled == nil then value.enabled = true end
	value.enabled = value.enabled and true or false
	value.threshold = math.max(2, math.min(10, math.floor(tonumber(value.threshold) or DEFAULT_THRESHOLD)))
	value.window = math.max(60, math.min(3600, math.floor(tonumber(value.window) or DEFAULT_WINDOW)))
	value.maxSuggestions = math.max(6, math.min(48, math.floor(tonumber(value.maxSuggestions) or DEFAULT_MAX_SUGGESTIONS)))
	value.dismissed = type(value.dismissed) == "table" and value.dismissed or {}
	value.queue = type(value.queue) == "table" and value.queue or {}
	value.sequence = math.max(0, math.floor(tonumber(value.sequence) or 0))
	return value
end

local function getSettings()
	return normalizeSettings(addon:GetSmartSettings())
end

local function queueSort(left, right)
	if (left.count or 0) ~= (right.count or 0) then
		return (left.count or 0) > (right.count or 0)
	end
	return tostring(left.term or "") < tostring(right.term or "")
end

local function compactDismissals(settings)
	local entries = {}
	for id, stamp in pairs(settings.dismissed) do
		if type(id) == "string" then
			table.insert(entries, { id = id, stamp = tonumber(stamp) or 0 })
		end
	end
	table.sort(entries, function(left, right)
		return left.stamp > right.stamp
	end)
	settings.dismissed = {}
	for index = 1, math.min(MAX_DISMISSED, #entries) do
		settings.dismissed[entries[index].id] = entries[index].stamp
	end
end

local function findQueueEntry(settings, id)
	for index, entry in ipairs(settings.queue) do
		if type(entry) == "table" and entry.id == id then
			return entry, index
		end
	end
	return nil, nil
end

local function compactQueue(settings)
	local valid = {}
	local seen = {}
	for _, entry in ipairs(settings.queue) do
		if type(entry) == "table" and type(entry.id) == "string" and entry.id ~= "" and not seen[entry.id] then
			entry.term = trim(entry.term or entry.label or entry.id, 40)
			entry.label = entry.term
			entry.count = math.max(0, math.floor(tonumber(entry.count) or 0))
			entry.sample = trim(entry.sample, MAX_SAMPLE_LENGTH)
			entry.source = trim(entry.source, 80)
			seen[entry.id] = true
			table.insert(valid, entry)
		end
	end
	table.sort(valid, queueSort)
	settings.queue = {}
	for index = 1, math.min(settings.maxSuggestions, #valid) do
		table.insert(settings.queue, valid[index])
	end
end

local function cleanMessage(text)
	text = tostring(text or "")
	-- Omit links and textures entirely instead of learning their display labels.
	text = string.gsub(text, "|H.-|h.-|h", " ")
	text = string.gsub(text, "|T.-|t", " ")
	text = string.gsub(text, "|A.-|a", " ")
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	text = string.gsub(text, "|r", "")
	text = string.gsub(text, "{[^}]-}", " ")
	return text
end

function Suggestions:RefreshKnownTerms()
	local settings = addon:GetSmartSettings()
	local revision = tonumber(settings.keywordColorRevision) or 0
	if self.knownTerms and self.knownRevision == revision then
		return self.knownTerms
	end
	local known = {}
	for term in pairs(settings.keywordColors or {}) do
		if type(term) == "string" then
			known[string.lower(term)] = true
		end
	end
	for _, group in ipairs(settings.keywordColorGroups or {}) do
		for _, termSpec in ipairs(group.terms or {}) do
			local term = type(termSpec) == "table" and termSpec.term or termSpec
			if type(term) == "string" then
				known[string.lower(term)] = true
			end
		end
	end
	self.knownTerms = known
	self.knownRevision = revision
	return known
end

function Suggestions:ResetForProfile()
	self.tracked = {}
	self.trackedCount = 0
	self.knownTerms = nil
	self.knownRevision = nil
	local settings = getSettings()
	compactDismissals(settings)
	compactQueue(settings)
	self:AttachListener()
end

function Suggestions:AttachListener()
	local engine = addon.MessageEngine
	if engine and type(engine.RegisterListener) == "function" then
		engine:RegisterListener("keywordSuggestions", function(record)
			Suggestions:Observe(record)
		end)
		return true
	end
	return false
end

function Suggestions:Initialize()
	if not self.initialized then
		self.initialized = true
	end
	self:ResetForProfile()
	return true
end

local function isCandidateTerm(term, known)
	return #term >= 4 and #term <= 24
		and not stopWords[term]
		and not known[term]
		and not string.find(term, "^%d", 1)
end

function Suggestions:PruneTracked(now, window)
	for term, entry in pairs(self.tracked or {}) do
		if not entry.lastSeen or now < entry.lastSeen or now - entry.lastSeen > window then
			self.tracked[term] = nil
			self.trackedCount = math.max(0, (self.trackedCount or 1) - 1)
		else
			for fingerprint, occurrence in pairs(entry.messages or {}) do
				local seenAt = tonumber(type(occurrence) == "table" and occurrence.time or occurrence) or 0
				if now < seenAt or now - seenAt > window then
					local sender = type(occurrence) == "table" and occurrence.sender or nil
					entry.messages[fingerprint] = nil
					entry.count = math.max(0, (entry.count or 1) - 1)
					if sender and entry.senderCounts and entry.senderCounts[sender] then
						entry.senderCounts[sender] = entry.senderCounts[sender] - 1
						if entry.senderCounts[sender] <= 0 then
							entry.senderCounts[sender] = nil
							entry.distinctSenders = math.max(0, (entry.distinctSenders or 1) - 1)
						end
					end
				end
			end
			if (entry.count or 0) <= 0 then
				self.tracked[term] = nil
				self.trackedCount = math.max(0, (self.trackedCount or 1) - 1)
			end
		end
	end
end

local function trimEntryMessages(entry)
	local retained = 0
	local oldestFingerprint, oldestOccurrence
	for fingerprint, occurrence in pairs(entry.messages or {}) do
		retained = retained + 1
		local occurrenceTime = tonumber(type(occurrence) == "table" and occurrence.time or occurrence) or 0
		local oldestTime = tonumber(type(oldestOccurrence) == "table" and oldestOccurrence.time or oldestOccurrence) or 0
		if not oldestOccurrence or occurrenceTime < oldestTime then
			oldestFingerprint, oldestOccurrence = fingerprint, occurrence
		end
	end
	if retained <= MAX_DISTINCT_MESSAGES or not oldestFingerprint then
		return
	end
	entry.messages[oldestFingerprint] = nil
	entry.count = math.max(0, (entry.count or 1) - 1)
	local sender = type(oldestOccurrence) == "table" and oldestOccurrence.sender or nil
	if sender and entry.senderCounts and entry.senderCounts[sender] then
		entry.senderCounts[sender] = entry.senderCounts[sender] - 1
		if entry.senderCounts[sender] <= 0 then
			entry.senderCounts[sender] = nil
			entry.distinctSenders = math.max(0, (entry.distinctSenders or 1) - 1)
		end
	end
end

function Suggestions:DropTracked(term)
	if self.tracked and self.tracked[term] then
		self.tracked[term] = nil
		self.trackedCount = math.max(0, (self.trackedCount or 1) - 1)
	end
end

function Suggestions:Offer(term, entry, record, settings)
	if settings.dismissed[term] then
		return
	end
	local queued = findQueueEntry(settings, term)
	local source = trim(record.sourceLabel or record.channel or record.event, 80)
	local sample = trim(cleanMessage(record.text), MAX_SAMPLE_LENGTH)
	if queued then
		queued.count = entry.count
		queued.lastSeen = epochForRecord(record)
		queued.source = source
		queued.sample = sample
		return
	end
	settings.sequence = settings.sequence + 1
	table.insert(settings.queue, {
		id = term,
		term = term,
		label = term,
		count = entry.count,
		sample = sample,
		source = source,
		firstSeen = entry.firstEpoch,
		lastSeen = epochForRecord(record),
		sequence = settings.sequence,
	})
	compactQueue(settings)
end

function Suggestions:Observe(record)
	if type(record) ~= "table" or not acceptedEvents[record.event] or record.direction == "outgoing" then
		return
	end
	if addon.MessageEngine and addon.MessageEngine.loadingPersistence then
		return
	end
	local settings = getSettings()
	if not settings.enabled or record.isSync or type(record.text) ~= "string" then
		return
	end
	local now = nowForRecord(record)
	self.tracked = self.tracked or {}
	self:PruneTracked(now, settings.window)
	local known = self:RefreshKnownTerms()
	local clean = cleanMessage(record.text)
	local senderKey = string.lower(trim(record.guid or record.sender or "unknown", 96))
	local messageFingerprint = senderKey .. "\031" .. string.lower(clean)
	local seenThisRecord = {}
	local observed = 0
	for rawTerm in string.gmatch(clean, "[%a][%a%'%-]*") do
		local term = string.lower(rawTerm)
		if not seenThisRecord[term] and not settings.dismissed[term] and isCandidateTerm(term, known) then
			seenThisRecord[term] = true
			observed = observed + 1
			if observed > 12 then
				break
			end
			local entry = self.tracked[term]
			if not entry then
				if self.trackedCount and self.trackedCount >= MAX_TRACKED_TERMS then
					break
				end
				entry = { count = 0, firstSeen = now, lastSeen = now, firstEpoch = epochForRecord(record), messages = {}, senderCounts = {}, distinctSenders = 0 }
				self.tracked[term] = entry
				self.trackedCount = (self.trackedCount or 0) + 1
			end
			if not entry.messages[messageFingerprint] then
				entry.messages[messageFingerprint] = { time = now, sender = senderKey }
				entry.count = entry.count + 1
				entry.senderCounts = entry.senderCounts or {}
				if not entry.senderCounts[senderKey] then
					entry.distinctSenders = (entry.distinctSenders or 0) + 1
				end
				entry.senderCounts[senderKey] = (entry.senderCounts[senderKey] or 0) + 1
				trimEntryMessages(entry)
				entry.lastSeen = now
				if entry.count >= settings.threshold and (entry.distinctSenders or 0) >= 2 then
					self:Offer(term, entry, record, settings)
				end
			end
		end
	end
end

function addon:GetKeywordSuggestionSettings()
	local settings = getSettings()
	return {
		enabled = settings.enabled,
		threshold = settings.threshold,
		window = settings.window,
		maxSuggestions = settings.maxSuggestions,
	}
end

function addon:SetKeywordSuggestionsEnabled(enabled)
	local settings = getSettings()
	settings.enabled = enabled and true or false
	return true, settings.enabled
end

function addon:SetKeywordSuggestionEnabled(enabled)
	return self:SetKeywordSuggestionsEnabled(enabled)
end

function addon:SetKeywordSuggestionThreshold(threshold)
	threshold = tonumber(threshold)
	if not threshold then
		return false, "invalid-threshold"
	end
	local settings = getSettings()
	settings.threshold = math.max(2, math.min(10, math.floor(threshold + 0.5)))
	return true, settings.threshold
end

function addon:GetKeywordSuggestions()
	local settings = getSettings()
	compactQueue(settings)
	return copy(settings.queue)
end

function addon:AddKeywordSuggestionToGroup(id, groupId)
	id = trim(id, 40)
	local settings = getSettings()
	local entry, index = findQueueEntry(settings, id)
	if not entry then
		return false, "unknown-suggestion"
	end
	if type(self.AddKeywordColorGroupTerm) ~= "function" then
		return false, "groups-unavailable"
	end
	local ok, reason = self:AddKeywordColorGroupTerm(groupId, entry.term)
	if not ok then
		return false, reason
	end
	table.remove(settings.queue, index)
	Suggestions:DropTracked(id)
	return true, reason
end

function addon:DismissKeywordSuggestion(id)
	id = trim(id, 40)
	local settings = getSettings()
	local _, index = findQueueEntry(settings, id)
	if not index then
		return false, "unknown-suggestion"
	end
	table.remove(settings.queue, index)
	settings.dismissed[id] = time and time() or 0
	compactDismissals(settings)
	Suggestions:DropTracked(id)
	return true
end

function addon:ClearKeywordSuggestions()
	local settings = getSettings()
	settings.queue = {}
	if Suggestions.tracked then Suggestions.tracked = {}; Suggestions.trackedCount = 0 end
	return true
end
