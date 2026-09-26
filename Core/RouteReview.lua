local addon = ChattyChattyBangBang

-- A report is an explicit user action, never a chat-event hook. These records
-- live only in this profile's SavedVariables; WoW writes that file on logout
-- or /reload. Nothing here scans game files or transmits a report to Codex.
local REVIEW_SCHEMA = 1
local REVIEW_LIMIT = 50
local PUBLIC_TEXT_LIMIT = 512
local LABEL_LIMIT = 96
local EVIDENCE_LIMIT = 12
local EVIDENCE_TEXT_LIMIT = 160

addon.MESSAGE_ROUTE_REVIEW_SAVE_NOTE =
	"SavedVariables saves on logout or /reload. Reports are not sent automatically."

local publicEvents = {
	CHAT_MSG_CHANNEL = true,
	CHAT_MSG_SAY = true,
	CHAT_MSG_YELL = true,
	CHAT_MSG_EMOTE = true,
	CHAT_MSG_TEXT_EMOTE = true,
}

local routeCategories = {
	chat = true, group = true, general = true, sync = true,
	conversations = true, groupFinder = true, guildInvites = true,
	trade = true, pvp = true, guild = true, system = true, loot = true,
}

local sessionId

local function cleanText(value, limit)
	if type(value) ~= "string" then return nil end
	-- Labels and derived evidence are presentation text, not the captured
	-- classifier input. Remove formatting before they appear in review UIs.
	value = string.gsub(value, "|c%x%x%x%x%x%x%x%x", "")
	value = string.gsub(value, "|r", "")
	value = string.gsub(value, "|H[^|]-|h([^|]-)|h", "%1")
	value = string.gsub(value, "|T[^|]-|t", "[texture]")
	value = string.gsub(value, "|A[^|]-|a", "[atlas]")
	value = string.gsub(value, "[%z\1-\8\11\12\14-\31\127]", "")
	return string.sub(value, 1, limit)
end

local function cleanPublicText(value)
	if type(value) ~= "string" then return nil end
	-- Preserve printable WoW color/hyperlink codes in this explicit public
	-- snapshot: they are part of the exact string the classifier saw. Control
	-- bytes cannot create extra lines or terminal effects in later exports.
	value = string.gsub(value, "[%z\1-\31\127]", " ")
	return string.sub(value, 1, PUBLIC_TEXT_LIMIT)
end

local function positiveInteger(value)
	local number = tonumber(value)
	if not number or number ~= number or number == math.huge or number == -math.huge
		or number < 1 then return nil end
	return math.floor(number)
end

local function copyEvidence(source)
	local result = {}
	if type(source) ~= "table" then return result end
	for index = 1, math.min(#source, EVIDENCE_LIMIT) do
		local value = cleanText(source[index], EVIDENCE_TEXT_LIMIT)
		if value and value ~= "" then result[#result + 1] = value end
	end
	return result
end

local function copyScores(semantic)
	if type(semantic) ~= "table" then return nil end
	local scores, thresholds, enabled = {}, {}, {}
	for _, key in ipairs({ "groupFinder", "trade", "pvp" }) do
		scores[key] = tonumber(semantic.scores and semantic.scores[key]) or 0
		thresholds[key] = tonumber(semantic.threshold and semantic.threshold[key]) or 0
		enabled[key] = semantic.enabled and semantic.enabled[key] == true or false
	end
	return { scores = scores, thresholds = thresholds, enabled = enabled }
end

local function copyEntry(entry)
	local result = {}
	for key, value in pairs(entry) do
		if type(value) == "table" then
			local nested = {}
			for nestedKey, nestedValue in pairs(value) do
				if type(nestedValue) == "table" then
					local inner = {}
					for innerKey, innerValue in pairs(nestedValue) do
						inner[innerKey] = innerValue
					end
					nested[nestedKey] = inner
				else
					nested[nestedKey] = nestedValue
				end
			end
			result[key] = nested
		else
			result[key] = value
		end
	end
	return result
end

local function getQueue(owner, create)
	local settings = owner:GetSmartSettings()
	local queue = type(settings.messageRouteReviews) == "table" and settings.messageRouteReviews or nil
	if not queue then
		if not create then return nil end
		queue = { schema = REVIEW_SCHEMA, nextId = 1, entries = {} }
		settings.messageRouteReviews = queue
	end
	queue.schema = REVIEW_SCHEMA
	queue.nextId = positiveInteger(queue.nextId) or 1
	if type(queue.entries) ~= "table" then queue.entries = {} end
	-- Malformed/hand-edited SavedVariables must not turn this into an unbounded
	-- archive. Keep newest array entries, with a fixed upper bound.
	while #queue.entries > REVIEW_LIMIT do table.remove(queue.entries, 1) end
	return queue
end

local function isSameMessage(entry, record, currentSession)
	if type(entry) ~= "table" or entry.event ~= record.event
		or entry.sourceId ~= record.sourceId
		or entry.recordEpoch ~= record.epoch then return false end
	local sequence = positiveInteger(record.historySequence)
	if sequence and entry.historySequence == sequence then
		return entry.publicText == (publicEvents[record.event]
			and cleanPublicText(record.text) or nil)
	end
	return not sequence and entry.sessionId == currentSession
		and entry.runtimeId == positiveInteger(record.id)
end

-- The record is the already-captured row selected by the user. expectedRoute
-- is optional: reporting does not silently move the line or install a rule.
function addon:ReportMessageRoute(record, expectedRoute)
	if type(record) ~= "table" or type(record.event) ~= "string" then
		return false, "invalid-record"
	end
	if not (self.db and self.db.profile) then return false, "not-ready" end
	if expectedRoute ~= nil and not routeCategories[expectedRoute] then
		return false, "invalid-expected-route"
	end
	local engine = self.MessageEngine
	if not engine or type(engine.AnalyzeRecord) ~= "function" then
		return false, "analysis-unavailable"
	end
	local ok, analysis = pcall(engine.AnalyzeRecord, engine, record)
	if not ok or type(analysis) ~= "table" then
		return false, "analysis-unavailable"
	end
	local queue = getQueue(self, true)
	if not sessionId then
		local epoch = positiveInteger(time and time()) or 0
		sessionId = "session-" .. epoch .. "-" .. queue.nextId
	end
	for index = 1, #queue.entries do
		local prior = queue.entries[index]
		if isSameMessage(prior, record, sessionId) then
			-- A later explicit destination choice edits the same review rather
			-- than trapping the player with an incomplete first report.
			if expectedRoute and prior.expectedRoute ~= expectedRoute then
				prior.expectedRoute = expectedRoute
				return true, copyEntry(prior)
			end
			return false, "already-reported", copyEntry(prior)
		end
	end

	local isPublic = publicEvents[record.event] and not record.isAddonMessage
		and not record.isSync
	local entry = {
		id = "review-" .. queue.nextId,
		sessionId = sessionId,
		reportedAtEpoch = positiveInteger(time and time()) or 0,
		recordEpoch = positiveInteger(record.epoch) or 0,
		historySequence = positiveInteger(record.historySequence),
		runtimeId = positiveInteger(record.id),
		event = cleanText(record.event, LABEL_LIMIT),
		sourceGroup = cleanText(record.sourceGroup, LABEL_LIMIT),
		sourceId = cleanText(record.sourceId, LABEL_LIMIT),
		sourceLabel = cleanText(record.sourceLabel, LABEL_LIMIT),
		captureRouteCategory = cleanText(record.captureRouteCategory, LABEL_LIMIT),
		captureRouteView = cleanText(record.captureRouteView, LABEL_LIMIT),
		captureRouteReason = cleanText(record.captureRouteReason, LABEL_LIMIT),
		currentCategory = cleanText(analysis.category, LABEL_LIMIT),
		currentView = cleanText(analysis.view, LABEL_LIMIT),
		routeOverrideCategory = cleanText(analysis.routeOverrideCategory, LABEL_LIMIT),
		expectedRoute = expectedRoute,
		publicSnapshot = isPublic and true or false,
	}
	if isPublic then
		entry.publicText = cleanPublicText(record.text)
		entry.publicTextTruncated = type(record.text) == "string"
			and #record.text > PUBLIC_TEXT_LIMIT or false
		entry.sender = cleanText(record.sender, LABEL_LIMIT)
		entry.channel = cleanText(record.channel, LABEL_LIMIT)
		entry.reasons = copyEvidence(analysis.reasons)
		entry.signals = copyEvidence(analysis.signals)
		entry.semantic = copyScores(analysis.semantic)
	else
		-- Add-on traffic, whispers, guild/group chat and local/system feedback
		-- may include private data. Keep only their event and route metadata.
		entry.snapshotOmitted = "non-public-message"
	end
	queue.nextId = queue.nextId + 1
	queue.entries[#queue.entries + 1] = entry
	if #queue.entries > REVIEW_LIMIT then table.remove(queue.entries, 1) end
	return true, copyEntry(entry)
end

function addon:GetMessageRouteReviews()
	local queue = getQueue(self, false)
	local results = {}
	if queue then
		for index = 1, #queue.entries do
			if type(queue.entries[index]) == "table" then
				results[#results + 1] = copyEntry(queue.entries[index])
			end
		end
	end
	return results, self.MESSAGE_ROUTE_REVIEW_SAVE_NOTE
end

function addon:ClearMessageRouteReviews()
	if not (self.db and self.db.profile) then return false, "not-ready" end
	local queue = getQueue(self, true)
	queue.entries = {}
	return true
end
