local addon = ChattyChattyBangBang

local AlertEngine = {}
addon.AlertEngine = AlertEngine

local MAX_RULES = 32
local MAX_TERMS = 24
local MAX_TERM_LENGTH = 80
local MAX_NAME_LENGTH = 40
local MAX_SOURCE_ID_LENGTH = 96
local MAX_SOURCES = 128

-- Variables are stored in a deliberately small, explicit syntax.  They are
-- resolved only while matching a received record, so [PLAYER_NAME] always
-- means the character currently logged into this client instead of the name
-- that happened to exist when the rule was saved.
local ALERT_VARIABLES = {
	["[player_name]"] = {
		token = "[PLAYER_NAME]",
		label = "YOUR CHARACTER NAME",
		description = "Matches the currently logged-in character's name.",
	},
	["[player]"] = {
		token = "[PLAYER_NAME]",
		label = "YOUR CHARACTER NAME",
		description = "Matches the currently logged-in character's name.",
	},
}

local DEFAULT_ALERT_RULE = {
	id = "alert1",
	name = "YOUR NAME",
	enabled = true,
	terms = { "[PLAYER_NAME]" },
	matchAll = false,
	allSources = true,
	sources = {},
	revealDock = true,
	sound = false,
}

local FALLBACK_ALERTS = {
	enabled = true,
	popout = true,
	sound = false,
	autoHideSeconds = 12,
	rules = { DEFAULT_ALERT_RULE },
	sequence = 1,
	revision = 0,
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

local function senderKey(value)
	if type(value) ~= "string" then
		return nil
	end
	value = string.gsub(value, "|c%x%x%x%x%x%x%x%x", "")
	value = string.gsub(value, "|r", "")
	value = string.gsub(value, "|H.-|h(.-)|h", "%1")
	value = trim(value, 128)
	return value ~= "" and string.lower(value) or nil
end

local function refreshPlayerIdentity(self)
	self.playerGUID = UnitGUID and UnitGUID("player") or nil
	self.playerName = UnitName and UnitName("player") or nil
end

local function isSelfRecord(self, record)
	if record.direction == "outgoing" then
		return true
	end
	if not self.playerGUID and not self.playerName then
		refreshPlayerIdentity(self)
	end
	local recordGUID = type(record.guid) == "string" and record.guid ~= "" and record.guid or nil
	if recordGUID and self.playerGUID and self.playerGUID ~= "" then
		return recordGUID == self.playerGUID
	end
	-- Use a name only when one of the GUIDs is unavailable. Keep the comparison
	-- exact so a same-named player from another realm cannot trigger this path.
	return type(record.sender) == "string" and self.playerName and record.sender == self.playerName or false
end

local function isLocallyIgnored(record, settings)
	local safety = type(settings.safety) == "table" and settings.safety or nil
	local ignores = safety and safety.localIgnores
	if type(ignores) ~= "table" or next(ignores) == nil then
		return false
	end
	local key = senderKey(record.sender)
	return key and ignores[key] == true or false
end

local function copyTerms(terms)
	local result = {}
	for index = 1, #(terms or {}) do
		result[index] = terms[index]
	end
	return result
end

local function copySources(sources)
	local result = {}
	for sourceId, selected in pairs(sources or {}) do
		if selected then
			result[sourceId] = true
		end
	end
	return result
end

local function copyRule(rule)
	return {
		id = rule.id,
		name = rule.name,
		enabled = rule.enabled,
		terms = copyTerms(rule.terms),
		matchAll = rule.matchAll,
		allSources = rule.allSources,
		sources = copySources(rule.sources),
		revealDock = rule.revealDock,
		sound = rule.sound,
	}
end

local function normalizeTerms(value)
	local terms = {}
	local seen = {}
	local function add(term)
		if #terms >= MAX_TERMS then
			return false
		end
		local normalized = string.lower(trim(term, MAX_TERM_LENGTH))
		local variable = ALERT_VARIABLES[normalized]
		term = variable and variable.token or normalized
		if term ~= "" and not seen[normalized] then
			seen[normalized] = true
			table.insert(terms, term)
		end
		return #terms < MAX_TERMS
	end

	if type(value) == "string" then
		for term in string.gmatch(value, "([^,]+)") do
			if not add(term) then
				break
			end
		end
	elseif type(value) == "table" then
		for index = 1, #value do
			if not add(value[index]) then
				break
			end
		end
		if #terms < MAX_TERMS then
			for term, selected in pairs(value) do
				if type(term) == "string" and selected and not add(term) then
					break
				end
			end
		end
	end
	return terms
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
		sourceId = trim(sourceId, MAX_SOURCE_ID_LENGTH)
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

local function isSafeRuleId(id)
	return type(id) == "string"
		and string.len(id) <= 32
		and string.find(id, "^[%a][%w_%-]*$") ~= nil
end

local function sanitizeRule(source, id, index)
	source = type(source) == "table" and source or {}
	local name = trim(source.name, MAX_NAME_LENGTH)
	if name == "" then
		name = "Alert " .. tostring(index)
	end
	local allSources = source.allSources ~= false
	return {
		id = id,
		name = name,
		enabled = source.enabled ~= false,
		terms = normalizeTerms(source.terms),
		matchAll = source.matchAll and true or false,
		allSources = allSources,
		sources = allSources and {} or normalizeSources(source.sources),
		revealDock = source.revealDock ~= false,
		sound = source.sound and true or false,
	}
end

local ruleFields = {
	id = true,
	name = true,
	enabled = true,
	terms = true,
	matchAll = true,
	allSources = true,
	sources = true,
	revealDock = true,
	sound = true,
}

local function arrayEqual(left, right)
	if type(left) ~= "table" or type(right) ~= "table" or #left ~= #right then
		return false
	end
	for key in pairs(left) do
		if type(key) ~= "number" or key < 1 or key > #right or key ~= math.floor(key) then
			return false
		end
	end
	for index = 1, #right do
		if left[index] ~= right[index] then
			return false
		end
	end
	return true
end

local function sourceSetsEqual(left, right)
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	for sourceId, selected in pairs(left) do
		if type(sourceId) ~= "string" or selected ~= true or right[sourceId] ~= true then
			return false
		end
	end
	for sourceId, selected in pairs(right) do
		if selected ~= true or left[sourceId] ~= true then
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
		or left.matchAll ~= right.matchAll or left.allSources ~= right.allSources
		or left.revealDock ~= right.revealDock or left.sound ~= right.sound then
		return false
	end
	return arrayEqual(left.terms, right.terms) and sourceSetsEqual(left.sources, right.sources)
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

local function getAlertSettings()
	local smart = addon.GetSmartSettings and addon:GetSmartSettings() or nil
	if type(smart) ~= "table" then
		smart = { alerts = FALLBACK_ALERTS }
	end
	if type(smart.alerts) ~= "table" then
		smart.alerts = {}
	end
	local settings = smart.alerts
	if settings.enabled == nil then
		settings.enabled = true
	else
		settings.enabled = settings.enabled and true or false
	end
	if settings.popout == nil then
		settings.popout = true
	else
		settings.popout = settings.popout and true or false
	end
	settings.sound = settings.sound and true or false
	settings.autoHideSeconds = tonumber(settings.autoHideSeconds) or 12
	if settings.autoHideSeconds < 0 then
		settings.autoHideSeconds = 0
	elseif settings.autoHideSeconds > 300 then
		settings.autoHideSeconds = 300
	end
	settings.sequence = math.max(0, math.floor(tonumber(settings.sequence) or 0))
	settings.revision = math.max(0, math.floor(tonumber(settings.revision) or 0))
	if type(settings.rules) ~= "table" then
		settings.rules = {}
	end
	return settings, smart
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
				id = "alert" .. tostring(sequence)
			until not usedIds[id]
		else
			local number = string.match(id, "^alert(%d+)$")
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
	local rules = normalizeStoredRules(settings)
	for index = 1, #rules do
		if rules[index].id == id then
			return rules[index], index
		end
	end
	return nil
end

local function markRulesChanged(settings)
	settings.revision = math.max(0, math.floor(tonumber(settings.revision) or 0)) + 1
	AlertEngine:RefreshRules(true)
end

function addon:GetAlertRules()
	local settings = getAlertSettings()
	local rules = normalizeStoredRules(settings)
	local result = {}
	for index = 1, #rules do
		result[index] = copyRule(rules[index])
	end
	return result
end

function addon:GetAlertVariables()
	local variables = {}
	local playerName = UnitName and UnitName("player") or nil
	for _, key in ipairs({ "[player_name]" }) do
		local definition = ALERT_VARIABLES[key]
		if definition then
			table.insert(variables, {
				token = definition.token,
				label = definition.label,
				description = definition.description,
				value = playerName,
			})
		end
	end
	return variables
end

function addon:CreateAlertRule(data)
	local settings = getAlertSettings()
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
		id = "alert" .. tostring(settings.sequence)
	until not usedIds[id]

	local rule = sanitizeRule(data, id, #rules + 1)
	table.insert(rules, rule)
	markRulesChanged(settings)
	return copyRule(rule)
end

function addon:UpdateAlertRule(id, data)
	local settings = getAlertSettings()
	local existing, index = findRule(settings, id)
	if not existing then
		return nil, "not-found"
	end
	data = type(data) == "table" and data or {}
	local enabled = existing.enabled
	local matchAll = existing.matchAll
	local allSources = existing.allSources
	local revealDock = existing.revealDock
	local sound = existing.sound
	if data.enabled ~= nil then
		enabled = data.enabled and true or false
	end
	if data.matchAll ~= nil then
		matchAll = data.matchAll and true or false
	end
	if data.allSources ~= nil then
		allSources = data.allSources and true or false
	end
	if data.revealDock ~= nil then
		revealDock = data.revealDock and true or false
	end
	if data.sound ~= nil then
		sound = data.sound and true or false
	end

	local merged = {
		name = data.name ~= nil and data.name or existing.name,
		enabled = enabled,
		terms = data.terms ~= nil and data.terms or existing.terms,
		matchAll = matchAll,
		allSources = allSources,
		sources = data.sources ~= nil and data.sources or existing.sources,
		revealDock = revealDock,
		sound = sound,
	}
	local updated = sanitizeRule(merged, existing.id, index)
	if not rulesEqual(existing, updated) then
		settings.rules[index] = updated
		markRulesChanged(settings)
	end
	return copyRule(updated)
end

function addon:DeleteAlertRule(id)
	local settings = getAlertSettings()
	local _, index = findRule(settings, id)
	if not index then
		return false, "not-found"
	end
	table.remove(settings.rules, index)
	markRulesChanged(settings)
	return true
end

function addon:GetAlertSourceDefinitions(ruleId)
	local settings = getAlertSettings()
	local rule = findRule(settings, ruleId)
	if not rule then
		return {}
	end

	local definitions = {}
	if addon.MessageEngine and addon.MessageEngine.GetSourceDefinitions then
		definitions = addon.MessageEngine:GetSourceDefinitions()
	end
	local result = {}
	for index = 1, #definitions do
		local source = definitions[index]
		local sourceId = trim(source.sourceId or source.id, MAX_SOURCE_ID_LENGTH)
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

function addon:SetAlertRuleSourceEnabled(ruleId, sourceId, value)
	sourceId = trim(sourceId, MAX_SOURCE_ID_LENGTH)
	if sourceId == "" then
		return false, "invalid-source"
	end
	local settings = getAlertSettings()
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
			local definitionId = trim(definitions[index].sourceId or definitions[index].id, MAX_SOURCE_ID_LENGTH)
			if definitionId ~= "" then
				rule.sources[definitionId] = true
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
		markRulesChanged(settings)
	end
	return true
end

function addon:ResetAlertRuleSources(ruleId)
	local settings = getAlertSettings()
	local rule = findRule(settings, ruleId)
	if not rule then
		return false, "not-found"
	end
	if not rule.allSources or next(rule.sources) ~= nil then
		rule.allSources = true
		rule.sources = {}
		markRulesChanged(settings)
	end
	return true
end

function AlertEngine:RefreshRules(force)
	local settings = getAlertSettings()
	local rules = normalizeStoredRules(settings)
	local revision = settings.revision
	if not force and self.compiledRevision == revision then
		return
	end

	local allSources = {}
	local bySource = {}
	for index = 1, #rules do
		local rule = rules[index]
		if rule.enabled and #rule.terms > 0 then
			local compiled = {
				id = rule.id,
				name = rule.name,
				terms = rule.terms,
				matchAll = rule.matchAll,
				revealDock = rule.revealDock,
				sound = rule.sound,
			}
			if rule.allSources then
				table.insert(allSources, compiled)
			else
				for sourceId in pairs(rule.sources) do
					local list = bySource[sourceId]
					if not list then
						list = {}
						bySource[sourceId] = list
					end
					table.insert(list, compiled)
				end
			end
		end
	end
	self.compiledAllSources = allSources
	self.compiledBySource = bySource
	self.compiledRevision = revision
end

local function resolveRuleTerm(self, term)
	local variable = ALERT_VARIABLES[string.lower(tostring(term or ""))]
	if not variable then
		return string.lower(tostring(term or ""))
	end
	if not self.playerName or self.playerName == "" then
		refreshPlayerIdentity(self)
	end
	local name = trim(self.playerName, MAX_TERM_LENGTH)
	if name == "" then
		return nil
	end
	return string.lower(name)
end

local function matchesRule(self, normalized, rule)
	if rule.matchAll then
		for index = 1, #rule.terms do
			local term = resolveRuleTerm(self, rule.terms[index])
			if not term or not string.find(normalized, term, 1, true) then
				return false
			end
		end
		return true
	end
	for index = 1, #rule.terms do
		local term = resolveRuleTerm(self, rule.terms[index])
		if term and string.find(normalized, term, 1, true) then
			return true
		end
	end
	return false
end

local function playAlertSound()
	if PlaySound then
		pcall(PlaySound, "RaidWarning")
	elseif PlaySoundFile then
		pcall(PlaySoundFile, "Sound\\Interface\\RaidWarning.wav")
	end
end

function AlertEngine:ProcessRecord(record)
	if not self.enabled or type(record) ~= "table" then
		return false
	end
	local settings, smartSettings = getAlertSettings()
	if settings.enabled == false then
		return false
	end
	if isSelfRecord(self, record) or isLocallyIgnored(record, smartSettings) then
		return false
	end
	if self.compiledRevision ~= settings.revision then
		self:RefreshRules()
	end

	local normalized = record.normalized
	if type(normalized) ~= "string" then
		normalized = string.lower(type(record.text) == "string" and record.text or "")
		record.normalized = normalized
	end
	if normalized == "" then
		return false
	end

	local specific = self.compiledBySource and self.compiledBySource[record.sourceId] or nil
	local allSources = self.compiledAllSources or {}
	local matchedRecord = false
	local shouldSound = false
	local function processList(list)
		for index = 1, #list do
			local rule = list[index]
			if matchesRule(self, normalized, rule) then
				record.alerts = type(record.alerts) == "table" and record.alerts or {}
				if not record.alerts[rule.id] then
					record.alerts[rule.id] = true
					matchedRecord = true
					self.stats.matches = self.stats.matches + 1
					self.stats.lastRuleId = rule.id
					self.stats.lastRuleName = rule.name
					self.stats.lastMatchTime = GetTime and GetTime() or 0
					if settings.popout and rule.revealDock and addon.SmartDock and addon.SmartDock.OnAlert then
						pcall(addon.SmartDock.OnAlert, addon.SmartDock, record, rule)
					end
					if settings.sound or rule.sound then
						shouldSound = true
					end
				end
			end
		end
	end

	-- Sync is a quarantine rail.  A broad all-sources rule must not turn a
	-- machine version handshake into a dock pop-out or sound.  A player can
	-- still deliberately alert on a Sync source by selecting it on that rule.
	if not record.isSync then
		processList(allSources)
	end
	if specific then
		processList(specific)
	end
	if matchedRecord then
		self.stats.matchedRecords = self.stats.matchedRecords + 1
		if shouldSound then
			playAlertSound()
		end
	end
	return matchedRecord
end

function AlertEngine:GetStats()
	local stats = self.stats or {}
	return {
		matches = tonumber(stats.matches) or 0,
		matchedRecords = tonumber(stats.matchedRecords) or 0,
		lastRuleId = stats.lastRuleId,
		lastRuleName = stats.lastRuleName,
		lastMatchTime = tonumber(stats.lastMatchTime) or 0,
	}
end

function AlertEngine:ResetStats()
	self.stats = {
		matches = 0,
		matchedRecords = 0,
		lastRuleId = nil,
		lastRuleName = nil,
		lastMatchTime = 0,
	}
end

function AlertEngine:ResetForProfile()
	self.compiledRevision = nil
	self.compiledAllSources = {}
	self.compiledBySource = {}
	self:ResetStats()
	refreshPlayerIdentity(self)
	local settings = getAlertSettings()
	self.enabled = settings.enabled ~= false
	self:RefreshRules(true)
end

function AlertEngine:SetEnabled(enabled)
	self.enabled = enabled and true or false
	if self.enabled then
		self:RefreshRules()
	end
end

function AlertEngine:Initialize()
	local firstInitialization = not self.initialized
	self.initialized = true
	if not self.listenerRegistered and addon.MessageEngine and addon.MessageEngine.RegisterListener then
		addon.MessageEngine:RegisterListener("AlertEngine", function(record)
			AlertEngine:ProcessRecord(record)
		end)
		self.listenerRegistered = true
	end
	if firstInitialization then
		self:ResetForProfile()
	end
end
