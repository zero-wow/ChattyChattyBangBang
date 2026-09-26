local addon = ChattyChattyBangBang
local Suggestions = {}
addon.KeywordSuggestions = Suggestions

local MAX_TRACKED_TERMS = 120
local MAX_DISTINCT_MESSAGES = 24
local MAX_SAMPLE_LENGTH = 120
local MAX_TERM_BYTES = 40
local MAX_TERM_CHARACTERS = 24
local MAX_DISMISSED = 96
local DEFAULT_THRESHOLD = 5
local DEFAULT_WINDOW = 900
local DEFAULT_MAX_SUGGESTIONS = 24
local GLOBAL_PRUNE_INTERVAL = 15
local CAPACITY_PRUNE_INTERVAL = 5

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
		local last = maximumLength
		-- Do not leave a partial UTF-8 codepoint in a saved sample or term.
		while last > 0 do
			local nextByte = string.byte(value, last + 1)
			if not nextByte or nextByte < 128 or nextByte > 191 then break end
			last = last - 1
		end
		value = string.sub(value, 1, last)
	end
	return value
end

-- WoW's Lua 5.1 string patterns classify bytes, not Unicode letters. Decode
-- only enough UTF-8 to keep common player-language scripts together. Invalid
-- sequences advance one byte and end a token instead of creating mojibake.
local function codepointAt(text, index)
	local first = string.byte(text, index)
	if not first then return nil, 0 end
	if first < 128 then return first, 1 end
	local second = string.byte(text, index + 1)
	if not second or second < 128 or second > 191 then return nil, 1 end
	if first >= 194 and first <= 223 then
		return (first - 192) * 64 + (second - 128), 2
	end
	local third = string.byte(text, index + 2)
	if not third or third < 128 or third > 191 then return nil, 1 end
	if first >= 224 and first <= 239 then
		if (first == 224 and second < 160) or (first == 237 and second >= 160) then return nil, 1 end
		return (first - 224) * 4096 + (second - 128) * 64 + (third - 128), 3
	end
	local fourth = string.byte(text, index + 3)
	if not fourth or fourth < 128 or fourth > 191 then return nil, 1 end
	if first >= 240 and first <= 244 then
		if (first == 240 and second < 144) or (first == 244 and second > 143) then return nil, 1 end
		return (first - 240) * 262144 + (second - 128) * 4096 + (third - 128) * 64 + (fourth - 128), 4
	end
	return nil, 1
end

local function isEastAsianLetter(codepoint)
	return (codepoint >= 0x3040 and codepoint <= 0x30FF)
		or (codepoint >= 0x3400 and codepoint <= 0x9FFF)
		or (codepoint >= 0xAC00 and codepoint <= 0xD7AF)
end

local function isLetter(codepoint)
	if not codepoint then return false end
	return (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122)
		or (codepoint >= 0x00C0 and codepoint <= 0x00D6)
		or (codepoint >= 0x00D8 and codepoint <= 0x00F6)
		or (codepoint >= 0x00F8 and codepoint <= 0x024F)
		or (codepoint >= 0x0370 and codepoint <= 0x052F)
		or (codepoint >= 0x0531 and codepoint <= 0x0588)
		or (codepoint >= 0x05D0 and codepoint <= 0x05EA)
		or (codepoint >= 0x0620 and codepoint <= 0x06FF)
		or (codepoint >= 0x0900 and codepoint <= 0x097F)
		or (codepoint >= 0x0E00 and codepoint <= 0x0E7F)
		or isEastAsianLetter(codepoint)
end

local function lowerCodepoint(codepoint)
	if codepoint >= 65 and codepoint <= 90 then return codepoint + 32 end
	if (codepoint >= 0x00C0 and codepoint <= 0x00D6)
		or (codepoint >= 0x00D8 and codepoint <= 0x00DE)
		or (codepoint >= 0x0391 and codepoint <= 0x03A1)
		or (codepoint >= 0x03A3 and codepoint <= 0x03AB)
		or (codepoint >= 0x0410 and codepoint <= 0x042F) then
		return codepoint + 32
	end
	if codepoint >= 0x0400 and codepoint <= 0x040F then return codepoint + 80 end
	return codepoint
end

local function appendCodepoint(parts, codepoint)
	if codepoint < 128 then
		parts[#parts + 1] = string.char(codepoint)
	elseif codepoint < 2048 then
		parts[#parts + 1] = string.char(192 + math.floor(codepoint / 64), 128 + codepoint % 64)
	elseif codepoint < 65536 then
		parts[#parts + 1] = string.char(224 + math.floor(codepoint / 4096),
			128 + math.floor(codepoint / 64) % 64, 128 + codepoint % 64)
	else
		parts[#parts + 1] = string.char(240 + math.floor(codepoint / 262144),
			128 + math.floor(codepoint / 4096) % 64, 128 + math.floor(codepoint / 64) % 64,
			128 + codepoint % 64)
	end
end

local function foldTerm(term)
	local parts = {}
	local index = 1
	while index <= #term do
		local codepoint, width = codepointAt(term, index)
		if codepoint then
			appendCodepoint(parts, lowerCodepoint(codepoint))
		else
			parts[#parts + 1] = string.sub(term, index, index)
		end
		index = index + width
	end
	return table.concat(parts)
end

local function scanTokens(text, callback)
	local start, lastLetterEnd, letters, nonAscii, eastAsian, tooLong
	local function flush()
		if start and lastLetterEnd and not tooLong then
			if callback(string.sub(text, start, lastLetterEnd), letters, nonAscii, eastAsian) == false then
				return false
			end
		end
		start, lastLetterEnd, letters, nonAscii, eastAsian, tooLong = nil, nil, nil, nil, nil, nil
		return true
	end
	local index = 1
	while index <= #text do
		local codepoint, width = codepointAt(text, index)
		if isLetter(codepoint) then
			if not start then start, letters = index, 0 end
			letters = letters + 1
			lastLetterEnd = index + width - 1
			if codepoint >= 128 then nonAscii = true end
			if isEastAsianLetter(codepoint) then eastAsian = true end
			if letters > MAX_TERM_CHARACTERS or lastLetterEnd - start + 1 > MAX_TERM_BYTES then tooLong = true end
		elseif start and codepoint and codepoint >= 0x0300 and codepoint <= 0x036F then
			-- A decomposed accent belongs to the preceding letter, including at
			-- the end of a word. It does not count as a separate letter.
			lastLetterEnd = index + width - 1
		elseif start and (codepoint == 39 or codepoint == 45 or codepoint == 0x2019) then
			-- Keep internal joiners, but not trailing punctuation.
		else
			if not flush() then return end
		end
		index = index + width
	end
	flush()
end

-- Shared with the existing keyword-color API: accepted suggestions must be
-- valid group terms, and the renderer needs the same byte-aligned comparison.
function Suggestions:NormalizeTerm(term)
	return foldTerm(type(term) == "string" and term or "")
end

function Suggestions:IsSafeGroupTerm(term)
	if type(term) ~= "string" or term == "" or #term > MAX_TERM_BYTES then return false end
	local index = 1
	while index <= #term do
		local codepoint, width = codepointAt(term, index)
		if not codepoint then return false end
		local first = index == 1
		local asciiDigit = codepoint >= 48 and codepoint <= 57
		local accepted = isLetter(codepoint) or asciiDigit
		if not first then
			accepted = accepted or codepoint == 39 or codepoint == 43 or codepoint == 45
				or codepoint == 32 or codepoint == 0x2019
				or (codepoint >= 0x0300 and codepoint <= 0x036F)
		end
		if not accepted then return false end
		index = index + width
	end
	return true
end

function Suggestions:IsWordAt(text, position)
	if type(text) ~= "string" or position < 1 or position > #text then return false end
	while position > 1 do
		local current = string.byte(text, position)
		if not current or current < 128 or current > 191 then break end
		position = position - 1
	end
	local codepoint = codepointAt(text, position)
	return isLetter(codepoint) or (codepoint and codepoint >= 48 and codepoint <= 57)
		or (codepoint and codepoint >= 0x0300 and codepoint <= 0x036F) or false
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
	if value.retainQueue == nil then value.retainQueue = true end
	value.retainQueue = value.retainQueue and true or false
	value.threshold = math.max(2, math.min(10, math.floor(tonumber(value.threshold) or DEFAULT_THRESHOLD)))
	value.window = math.max(60, math.min(3600, math.floor(tonumber(value.window) or DEFAULT_WINDOW)))
	value.maxSuggestions = math.max(6, math.min(48, math.floor(tonumber(value.maxSuggestions) or DEFAULT_MAX_SUGGESTIONS)))
	value.dismissed = type(value.dismissed) == "table" and value.dismissed or {}
	value.queue = type(value.queue) == "table" and value.queue or {}
	-- Session-only queues never live in SavedVariables, including after a
	-- profile import or an older partially migrated profile is loaded.
	if not value.retainQueue and next(value.queue) ~= nil then value.queue = {} end
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

local function activeQueue(settings)
	if settings.retainQueue == false then
		Suggestions.sessionQueue = Suggestions.sessionQueue or {}
		return Suggestions.sessionQueue
	end
	return settings.queue
end

local function setActiveQueue(settings, queue)
	if settings.retainQueue == false then
		Suggestions.sessionQueue = queue
		settings.queue = {}
	else
		settings.queue = queue
	end
end

local function findQueueEntry(settings, id)
	for index, entry in ipairs(activeQueue(settings)) do
		if type(entry) == "table" and entry.id == id then
			return entry, index
		end
	end
	return nil, nil
end

local function compactQueue(settings)
	local valid = {}
	local seen = {}
	for _, entry in ipairs(activeQueue(settings)) do
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
	local compacted = {}
	for index = 1, math.min(settings.maxSuggestions, #valid) do
		table.insert(compacted, valid[index])
	end
	setActiveQueue(settings, compacted)
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
			known[foldTerm(term)] = true
		end
	end
	for _, group in ipairs(settings.keywordColorGroups or {}) do
		for _, termSpec in ipairs(group.terms or {}) do
			local term = type(termSpec) == "table" and termSpec.term or termSpec
			if type(term) == "string" then
				known[foldTerm(term)] = true
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
	self.sessionQueue = {}
	self.lastGlobalPruneAt = nil
	self.lastGlobalPruneWindow = nil
	self.lastCapacityPruneAt = nil
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

local function isCandidateTerm(term, letters, nonAscii, eastAsian, known)
	local validLength
	if nonAscii then
		validLength = letters >= (eastAsian and 2 or 3)
			and letters <= MAX_TERM_CHARACTERS and #term <= MAX_TERM_BYTES
	else
		-- Keep the preexisting ASCII admission range, including hyphenated
		-- terms whose visible byte length differs from their letter count.
		validLength = #term >= 4 and #term <= 24
	end
	return validLength
		and not stopWords[term]
		and not known[term]
end

local function pruneTrackedEntry(self, term, entry, now, window)
	if not entry.lastSeen or now < entry.lastSeen or now - entry.lastSeen > window then
		self.tracked[term] = nil
		self.trackedCount = math.max(0, (self.trackedCount or 1) - 1)
		return
	end
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
	else
		entry.lastPrunedAt = now
		entry.lastPrunedWindow = window
	end
end

function Suggestions:PruneTracked(now, window)
	for term, entry in pairs(self.tracked or {}) do
		pruneTrackedEntry(self, term, entry, now, window)
	end
	self.lastGlobalPruneAt = now
	self.lastGlobalPruneWindow = window
	self.lastCapacityPruneAt = now
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
	table.insert(activeQueue(settings), {
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
	-- A full 120-term sweep on every public line scales badly in a busy city.
	-- Sweep periodically; a term seen on this line is still pruned immediately
	-- below, so its rolling threshold and distinct-sender count stay exact.
	if not self.lastGlobalPruneAt or now < self.lastGlobalPruneAt
		or now - self.lastGlobalPruneAt >= GLOBAL_PRUNE_INTERVAL
		or self.lastGlobalPruneWindow ~= settings.window then
		self:PruneTracked(now, settings.window)
	end
	local known = self:RefreshKnownTerms()
	local clean = cleanMessage(record.text)
	local senderKey = string.lower(trim(record.guid or record.sender or "unknown", 96))
	local messageFingerprint = senderKey .. "\031" .. string.lower(clean)
	local seenThisRecord = {}
	local observed = 0
	scanTokens(clean, function(rawTerm, letters, nonAscii, eastAsian)
		local term = foldTerm(rawTerm)
		if not seenThisRecord[term] and not settings.dismissed[term]
			and isCandidateTerm(term, letters, nonAscii, eastAsian, known) then
			seenThisRecord[term] = true
			observed = observed + 1
			if observed > 12 then
				return false
			end
			local entry = self.tracked[term]
			if entry and (entry.lastPrunedAt ~= now or entry.lastPrunedWindow ~= settings.window) then
				pruneTrackedEntry(self, term, entry, now, settings.window)
				entry = self.tracked[term]
			end
			if not entry then
				if self.trackedCount and self.trackedCount >= MAX_TRACKED_TERMS then
					if not self.lastCapacityPruneAt or now < self.lastCapacityPruneAt
						or now - self.lastCapacityPruneAt >= CAPACITY_PRUNE_INTERVAL then
						self:PruneTracked(now, settings.window)
					end
					if self.trackedCount >= MAX_TRACKED_TERMS then return false end
				end
				entry = { count = 0, firstSeen = now, lastSeen = now,
					lastPrunedAt = now, lastPrunedWindow = settings.window,
					firstEpoch = epochForRecord(record), messages = {}, senderCounts = {}, distinctSenders = 0 }
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
	end)
end

function addon:GetKeywordSuggestionSettings()
	local settings = getSettings()
	local dismissedCount = 0
	for _ in pairs(settings.dismissed) do dismissedCount = dismissedCount + 1 end
	return {
		enabled = settings.enabled,
		retainQueue = settings.retainQueue,
		threshold = settings.threshold,
		window = settings.window,
		maxSuggestions = settings.maxSuggestions,
		queueCount = #activeQueue(settings),
		dismissedCount = dismissedCount,
		observedTermCount = Suggestions.trackedCount or 0,
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

function addon:SetKeywordSuggestionQueueRetention(retain)
	local settings = getSettings()
	retain = retain and true or false
	if settings.retainQueue == retain then return true, retain end
	local current = copy(activeQueue(settings))
	settings.retainQueue = retain
	setActiveQueue(settings, current)
	if retain then Suggestions.sessionQueue = nil end
	compactQueue(settings)
	return true, retain
end

function addon:GetKeywordSuggestions()
	local settings = getSettings()
	compactQueue(settings)
	return copy(activeQueue(settings))
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
	table.remove(activeQueue(settings), index)
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
	table.remove(activeQueue(settings), index)
	settings.dismissed[id] = time and time() or 0
	compactDismissals(settings)
	Suggestions:DropTracked(id)
	return true
end

function addon:ClearKeywordSuggestions()
	local settings = getSettings()
	setActiveQueue(settings, {})
	if Suggestions.tracked then Suggestions.tracked = {}; Suggestions.trackedCount = 0 end
	Suggestions.lastGlobalPruneAt = nil
	Suggestions.lastGlobalPruneWindow = nil
	Suggestions.lastCapacityPruneAt = nil
	return true
end

function addon:ClearKeywordSuggestionData()
	local settings = getSettings()
	self:ClearKeywordSuggestions()
	settings.dismissed = {}
	settings.sequence = 0
	return true
end
