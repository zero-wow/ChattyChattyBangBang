local addon = ChattyChattyBangBang

-- A pure, bounded matcher for user-authored public-channel route rules. The
-- stored rule contains literal phrases, never executable patterns or Lua code.
-- The escaped Lua patterns below are a transparent preview of those phrases.
local Rules = {}
addon.RoutePatternRules = Rules

local MAX_TEXT_BYTES = 4096
local MAX_PHRASE_BYTES = 96
local MAX_TOTAL_PHRASE_BYTES = 384
local MAX_PHRASES_PER_SIDE = 6
local MAX_SOURCE_BYTES = 80
local MAX_RULES = 64

Rules.MAX_RULES = MAX_RULES

local destinations = {
	general = true, groupFinder = true, guildInvites = true,
	pvp = true, trade = true, system = true, loot = true,
}

local function trim(value)
	return (string.gsub(string.gsub(value, "^%s+", ""), "%s+$", ""))
end

-- A malformed control sequence fails closed. In particular, hyperlink payloads
-- must never accidentally become matchable body text. Labels remain visible.
local function visibleMarkup(value, depth)
	if depth > 2 then return nil, "nested-markup" end
	local lower = string.lower(value)
	local pieces = {}
	local index = 1
	while index <= #value do
		if string.sub(value, index, index) ~= "|" then
			pieces[#pieces + 1] = string.sub(value, index, index)
			index = index + 1
		else
			local marker = string.sub(lower, index + 1, index + 1)
			if marker == "|" then
				pieces[#pieces + 1] = "|"
				index = index + 2
			elseif marker == "c" then
				local color = string.sub(value, index + 2, index + 9)
				if #color ~= 8 or string.find(color, "[^%x]") then
					return nil, "malformed-color"
				end
				index = index + 10
			elseif marker == "r" then
				index = index + 2
		elseif marker == "n" then
			pieces[#pieces + 1] = " "
			index = index + 2
		elseif marker == "h" then
			local labelStart = string.find(lower, "|h", index + 2, true)
			local labelEnd = labelStart and string.find(lower, "|h", labelStart + 2, true)
			if not labelStart or not labelEnd then return nil, "malformed-hyperlink" end
			local label, reason = visibleMarkup(string.sub(value, labelStart + 2, labelEnd - 1), depth + 1)
			if not label then return nil, reason end
			pieces[#pieces + 1] = label
			index = labelEnd + 2
		elseif marker == "t" or marker == "a" then
			local closing = string.find(lower, "|" .. marker, index + 2, true)
			if not closing then return nil, "malformed-decoration" end
			index = closing + 2
		else
			return nil, "unsupported-markup"
		end
		end
	end
	return table.concat(pieces)
end

function Rules:NormalizeText(value)
	if type(value) ~= "string" then return nil, "invalid-text" end
	if #value > MAX_TEXT_BYTES then return nil, "text-too-long" end
	local visible, reason = visibleMarkup(value, 0)
	if not visible then return nil, reason end
	visible = string.gsub(visible, "[%z\1-\8\11\12\14-\31\127]", " ")
	visible = string.lower(trim(string.gsub(visible, "%s+", " ")))
	return visible
end

local function validatePhraseList(owner, list, required)
	if list == nil and not required then return {}, 0 end
	if type(list) ~= "table" then return nil, "invalid-phrase-list" end
	local count = 0
	for key in pairs(list) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return nil, "invalid-phrase-list"
		end
		count = count + 1
	end
	if count > MAX_PHRASES_PER_SIDE then return nil, "too-many-phrases" end
	if required and count == 0 then return nil, "missing-include" end
	local result, seen, total = {}, {}, 0
	for index = 1, count do
		local phrase = list[index]
		if type(phrase) ~= "string" or #phrase > MAX_PHRASE_BYTES then
			return nil, "invalid-phrase"
		end
		phrase = owner:NormalizeText(phrase)
		if not phrase or #phrase < 3 then return nil, "invalid-phrase" end
		if seen[phrase] then return nil, "duplicate-phrase" end
		seen[phrase] = true
		total = total + #phrase
		if total > MAX_TOTAL_PHRASE_BYTES then return nil, "phrases-too-long" end
		result[index] = phrase
	end
	return result, total
end

function Rules:Validate(raw)
	if type(raw) ~= "table" then return nil, "invalid-rule" end
	if not destinations[raw.destination] then return nil, "invalid-destination" end
	local sourceId = raw.sourceId
	if sourceId ~= nil then
		if type(sourceId) ~= "string" or #sourceId > MAX_SOURCE_BYTES then
			return nil, "invalid-source"
		end
		sourceId = string.lower(trim(sourceId))
		if not string.match(sourceId, "^channel:[%w%-]+$") then
			return nil, "invalid-source"
		end
	end
	local include, includeBytes = validatePhraseList(self, raw.include, true)
	if not include then return nil, includeBytes end
	local exclude, excludeBytes = validatePhraseList(self, raw.exclude, false)
	if not exclude then return nil, excludeBytes end
	if includeBytes + excludeBytes > MAX_TOTAL_PHRASE_BYTES then
		return nil, "phrases-too-long"
	end
	local seen = {}
	for index = 1, #include do seen[include[index]] = true end
	for index = 1, #exclude do
		if seen[exclude[index]] then return nil, "contradictory-phrase" end
	end
	return {
		destination = raw.destination,
		sourceId = sourceId,
		include = include,
		exclude = exclude,
	}
end

-- Validate a persisted list as one unit before it is saved or compiled. A
-- sparse or oversized table must not silently change rule ordering.
function Rules:ValidateSet(rawRules)
	if type(rawRules) ~= "table" then return nil, "invalid-rule-list" end
	local count = 0
	for key in pairs(rawRules) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return nil, "invalid-rule-list"
		end
		count = count + 1
	end
	if count > MAX_RULES then return nil, "too-many-rules" end
	local validated = {}
	for index = 1, count do
		local rule, reason = self:Validate(rawRules[index])
		if not rule then return nil, reason end
		validated[index] = rule
	end
	return validated
end

local function escapeLuaPattern(phrase)
	return (string.gsub(phrase, "([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"))
end

local function findSpans(text, phrase)
	local spans, cursor = {}, 1
	while cursor <= #text do
		local first, last = string.find(text, phrase, cursor, true)
		if not first then break end
		spans[#spans + 1] = { first = first, last = last, text = phrase }
		cursor = last + 1
	end
	return spans
end

local function ignoredSpans(text, matches)
	local sorted = {}
	for index = 1, #matches do sorted[index] = matches[index] end
	table.sort(sorted, function(a, b)
		if a.first == b.first then return a.last < b.last end
		return a.first < b.first
	end)
	local ignored, cursor = {}, 1
	for index = 1, #sorted do
		local span = sorted[index]
		if span.first > cursor then
			ignored[#ignored + 1] = { first = cursor, last = span.first - 1,
				text = string.sub(text, cursor, span.first - 1) }
		end
		cursor = math.max(cursor, span.last + 1)
	end
	if cursor <= #text then
		ignored[#ignored + 1] = { first = cursor, last = #text, text = string.sub(text, cursor) }
	end
	return ignored
end

-- Preview provides UI-ready matched and ignored spans in the normalized
-- visible message, plus each generated literal Lua pattern. Match uses plain
-- string.find, not those patterns; a user cannot inject pattern operators.
function Rules:Preview(rule, record)
	local validated, reason = self:Validate(rule)
	if not validated then return nil, reason end
	if type(record) ~= "table" then return nil, "invalid-record" end
	local text, textReason = self:NormalizeText(record.text or record.normalized)
	if not text then return nil, textReason end
	local included, excluded, matchedSpans = {}, {}, {}
	local includesPresent, excludesPresent = true, false
	local includePatterns, excludePatterns = {}, {}
	for index = 1, #validated.include do
		local phrase = validated.include[index]
		local spans = findSpans(text, phrase)
		included[index] = { phrase = phrase, spans = spans, found = #spans > 0 }
		includePatterns[index] = escapeLuaPattern(phrase)
		if #spans == 0 then includesPresent = false end
		for spanIndex = 1, #spans do matchedSpans[#matchedSpans + 1] = spans[spanIndex] end
	end
	for index = 1, #validated.exclude do
		local phrase = validated.exclude[index]
		local spans = findSpans(text, phrase)
		excluded[index] = { phrase = phrase, spans = spans, found = #spans > 0 }
		excludePatterns[index] = escapeLuaPattern(phrase)
		if #spans > 0 then excludesPresent = true end
	end
	local publicEvent = record.event == "CHAT_MSG_CHANNEL"
	local sourceMatches = validated.sourceId == nil
		or type(record.sourceId) == "string"
			and string.lower(record.sourceId) == validated.sourceId
	local matchReason
	if not publicEvent then matchReason = "public-channel-only"
	elseif not sourceMatches then matchReason = "source-mismatch"
	elseif not includesPresent then matchReason = "missing-include"
	elseif excludesPresent then matchReason = "excluded"
	else matchReason = "matched" end
	return {
		matches = matchReason == "matched",
		reason = matchReason,
		destination = validated.destination,
		sourceId = validated.sourceId,
		visibleText = text,
		include = included,
		exclude = excluded,
		matchedSpans = matchedSpans,
		ignoredSpans = ignoredSpans(text, matchedSpans),
		patternLanguage = "Lua patterns (escaped literal phrases)",
		includePatterns = includePatterns,
		excludePatterns = excludePatterns,
		luaPatternPreview = "ALL: " .. table.concat(includePatterns, " AND ")
			.. (#excludePatterns > 0 and ("; NONE: " .. table.concat(excludePatterns, " OR ")) or ""),
	}
end

function Rules:Match(rule, record)
	local preview, reason = self:Preview(rule, record)
	if not preview then return false, reason end
	return preview.matches, preview
end

return Rules
