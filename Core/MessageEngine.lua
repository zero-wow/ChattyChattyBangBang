local addon = ChattyChattyBangBang
local Engine = {}
addon.MessageEngine = Engine

local chatEvents = {
	"CHAT_MSG_SAY",
	"CHAT_MSG_YELL",
	"CHAT_MSG_EMOTE",
	"CHAT_MSG_TEXT_EMOTE",
	"CHAT_MSG_WHISPER",
	"CHAT_MSG_WHISPER_INFORM",
	"CHAT_MSG_BN_WHISPER",
	"CHAT_MSG_BN_WHISPER_INFORM",
	"CHAT_MSG_BN_CONVERSATION",
	"CHAT_MSG_AFK",
	"CHAT_MSG_DND",
	"CHAT_MSG_CHANNEL",
	"CHAT_MSG_ADDON",
	"CHAT_MSG_GUILD",
	"CHAT_MSG_GUILD_ACHIEVEMENT",
	"CHAT_MSG_OFFICER",
	"CHAT_MSG_PARTY",
	"CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID",
	"CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_BATTLEGROUND",
	"CHAT_MSG_BATTLEGROUND_LEADER",
	"CHAT_MSG_SYSTEM",
	-- UI errors are emitted by the client UI rather than a native chat frame.
	-- Capture them explicitly so action failures remain visible while Smart Dock
	-- owns and hides ChatFrame1.
	"UI_ERROR_MESSAGE",
	"CHAT_MSG_LOOT",
	"CHAT_MSG_MONEY",
	"CHAT_MSG_ACHIEVEMENT",
	"CHAT_MSG_BG_SYSTEM_NEUTRAL",
	"CHAT_MSG_BG_SYSTEM_ALLIANCE",
	"CHAT_MSG_BG_SYSTEM_HORDE",
	-- Zone-defense notices are their own client event.  Keep them distinct from
	-- ordinary system text so players can silence or target them independently.
	"CHAT_MSG_ZONE_UNDER_ATTACK",
	"CHAT_MSG_INSTANCE_CHAT",
	"CHAT_MSG_INSTANCE_CHAT_LEADER",
}

local localCommandRefreshEvents = {
	"ADDON_LOADED",
	"PLAYER_LOGIN",
}

local directCategories = {
	CHAT_MSG_WHISPER = "conversations",
	CHAT_MSG_WHISPER_INFORM = "conversations",
	CHAT_MSG_BN_WHISPER = "conversations",
	CHAT_MSG_BN_WHISPER_INFORM = "conversations",
	CHAT_MSG_BN_CONVERSATION = "conversations",
	CHAT_MSG_AFK = "conversations",
	CHAT_MSG_DND = "conversations",
	CHAT_MSG_GUILD = "guild",
	CHAT_MSG_GUILD_ACHIEVEMENT = "guild",
	CHAT_MSG_OFFICER = "guild",
	CHAT_MSG_PARTY = "group",
	CHAT_MSG_PARTY_LEADER = "group",
	CHAT_MSG_RAID = "group",
	CHAT_MSG_RAID_LEADER = "group",
	CHAT_MSG_RAID_WARNING = "group",
	CHAT_MSG_BATTLEGROUND = "pvp",
	CHAT_MSG_BATTLEGROUND_LEADER = "pvp",
	CHAT_MSG_INSTANCE_CHAT = "group",
	CHAT_MSG_INSTANCE_CHAT_LEADER = "group",
	CHAT_MSG_LOOT = "loot",
	CHAT_MSG_MONEY = "loot",
	CHAT_MSG_SYSTEM = "system",
	UI_ERROR_MESSAGE = "system",
	CCBB_LOCAL_MESSAGE = "system",
	CHAT_MSG_ACHIEVEMENT = "system",
	CHAT_MSG_BG_SYSTEM_NEUTRAL = "pvp",
	CHAT_MSG_BG_SYSTEM_ALLIANCE = "pvp",
	CHAT_MSG_BG_SYSTEM_HORDE = "pvp",
	CHAT_MSG_ZONE_UNDER_ATTACK = "pvp",
	CHAT_MSG_SAY = "chat",
	CHAT_MSG_YELL = "chat",
	CHAT_MSG_EMOTE = "chat",
	CHAT_MSG_TEXT_EMOTE = "chat",
	-- Known protocol handshakes are reclassified into Sync below. Other add-on
	-- output is human-visible feedback and belongs in System, where it can be
	-- hidden through the normal source control if a player does not want it.
	CHAT_MSG_ADDON = "system",
}

-- A source describes where a line originated, independently from its semantic
-- classification.  Views can use that stable identity as a non-destructive
-- visibility filter without changing a record's existing memberships.
local sourceGroupLabels = {
	["local"] = "Local",
	conversations = "Conversations",
	channels = "Channels",
	sync = "Sync",
	guild = "Guild",
	group = "Group",
	pvp = "PVP",
	system = "System",
	loot = "Loot",
	other = "Other",
}

local eventSources = {}
local staticSourceDefinitions = {}
local staticSourceOrder = {}

local function registerStaticSource(event, sourceGroup, sourceId, sourceLabel)
	eventSources[event] = {
		sourceGroup = sourceGroup,
		sourceId = sourceId,
		sourceLabel = sourceLabel,
	}
	if not staticSourceDefinitions[sourceId] then
		staticSourceDefinitions[sourceId] = {
			id = sourceId,
			sourceId = sourceId,
			group = sourceGroup,
			sourceGroup = sourceGroup,
			groupLabel = sourceGroupLabels[sourceGroup] or sourceGroup,
			sourceLabel = sourceLabel,
			label = sourceLabel,
			static = true,
		}
		table.insert(staticSourceOrder, sourceId)
	end
end

registerStaticSource("CHAT_MSG_SAY", "local", "local:say", "Say")
registerStaticSource("CHAT_MSG_YELL", "local", "local:yell", "Yell")
registerStaticSource("CHAT_MSG_EMOTE", "local", "local:emote", "Emotes")
registerStaticSource("CHAT_MSG_TEXT_EMOTE", "local", "local:text-emote", "Text emotes")

-- This source describes the narrow AscensionLogs version handshake. Other
-- add-on payloads are deliberately System feedback rather than protocol Sync.
registerStaticSource("CHAT_MSG_ADDON", "sync", "addon:alcver", "ALCver add-on sync")
-- A source definition without a live event is intentional: NormalizeAddon
-- assigns it to all non-protocol CHAT_MSG_ADDON records, while the source list
-- still exposes one simple SYSTEM toggle instead of one row per add-on prefix.
registerStaticSource("CCBB_ADDON_FEEDBACK", "system", "system:addon-feedback", "Add-on feedback")

registerStaticSource("CHAT_MSG_WHISPER", "conversations", "conversation:whisper", "Whispers")
registerStaticSource("CHAT_MSG_WHISPER_INFORM", "conversations", "conversation:whisper", "Whispers")
registerStaticSource("CHAT_MSG_BN_WHISPER", "conversations", "conversation:bnet-whisper", "Battle.net whispers")
registerStaticSource("CHAT_MSG_BN_WHISPER_INFORM", "conversations", "conversation:bnet-whisper", "Battle.net whispers")
registerStaticSource("CHAT_MSG_BN_CONVERSATION", "conversations", "conversation:bnet-conversation", "Battle.net conversations")
registerStaticSource("CHAT_MSG_AFK", "conversations", "conversation:afk", "AFK replies")
registerStaticSource("CHAT_MSG_DND", "conversations", "conversation:dnd", "DND replies")

registerStaticSource("CHAT_MSG_GUILD", "guild", "guild:guild", "Guild chat")
registerStaticSource("CHAT_MSG_GUILD_ACHIEVEMENT", "guild", "guild:achievement", "Guild achievements")
registerStaticSource("CHAT_MSG_OFFICER", "guild", "guild:officer", "Officer chat")

registerStaticSource("CHAT_MSG_PARTY", "group", "group:party", "Party chat")
registerStaticSource("CHAT_MSG_PARTY_LEADER", "group", "group:party", "Party chat")
registerStaticSource("CHAT_MSG_RAID", "group", "group:raid", "Raid chat")
registerStaticSource("CHAT_MSG_RAID_LEADER", "group", "group:raid", "Raid chat")
registerStaticSource("CHAT_MSG_RAID_WARNING", "group", "group:raid-warning", "Raid warnings")
registerStaticSource("CHAT_MSG_BATTLEGROUND", "pvp", "group:battleground", "Battleground chat")
registerStaticSource("CHAT_MSG_BATTLEGROUND_LEADER", "pvp", "group:battleground", "Battleground chat")
registerStaticSource("CHAT_MSG_INSTANCE_CHAT", "group", "group:instance", "Instance chat")
registerStaticSource("CHAT_MSG_INSTANCE_CHAT_LEADER", "group", "group:instance", "Instance chat")

registerStaticSource("CHAT_MSG_SYSTEM", "system", "system:message", "System messages")
registerStaticSource("UI_ERROR_MESSAGE", "system", "system:ui-error", "UI alerts and errors")
-- This is an internal record type, not a WoW event.  It is used by the tiny
-- public DebugMessage bridge for macros and local add-ons, avoiding a broad
-- ChatFrame:AddMessage hook (which would duplicate normal chat and recurse).
registerStaticSource("CCBB_LOCAL_MESSAGE", "system", "system:local-debug", "Local add-on feedback")
registerStaticSource("CHAT_MSG_ACHIEVEMENT", "system", "system:achievement", "Achievements")
registerStaticSource("CHAT_MSG_BG_SYSTEM_NEUTRAL", "pvp", "system:battleground", "Battleground notices")
registerStaticSource("CHAT_MSG_BG_SYSTEM_ALLIANCE", "pvp", "system:battleground", "Battleground notices")
registerStaticSource("CHAT_MSG_BG_SYSTEM_HORDE", "pvp", "system:battleground", "Battleground notices")
registerStaticSource("CHAT_MSG_ZONE_UNDER_ATTACK", "pvp", "system:under-attack", "Zone under attack")

registerStaticSource("CHAT_MSG_LOOT", "loot", "loot:loot", "Loot messages")
registerStaticSource("CHAT_MSG_MONEY", "loot", "loot:money", "Money messages")

local roleTokens = {
	{ token = "tank", tag = "role:tank" },
	{ token = "tanks", tag = "role:tank" },
	{ token = "healer", tag = "role:healer" },
	{ token = "healers", tag = "role:healer" },
	{ token = "heal", tag = "role:healer" },
	{ token = "heals", tag = "role:healer" },
	{ token = "dps", tag = "role:dps" },
}

local function contains(text, needle)
	return string.find(text, needle, 1, true) ~= nil
end

local function containsAny(text, tokens)
	for index = 1, #tokens do
		if contains(text, tokens[index]) then
			return true
		end
	end
	return false
end

-- Chat recruitment language is deliberately matched as words instead of
-- arbitrary substrings.  "need help" must remain a normal General line, but
-- "NEED 2 DPS" and "LF pumper DPS" must not depend on the sender being in an
-- LFG-named channel.  Lua's frontier patterns are available on the 3.3 client
-- and keep punctuation such as [Keystone: ...] harmless.
local function hasWord(text, word)
	return string.find(text, "%f[%w]" .. word .. "%f[^%w]") ~= nil
end

local function hasAnyWord(text, words)
	for index = 1, #words do
		if hasWord(text, words[index]) then
			return true
		end
	end
	return false
end

-- Ascension can relay a zone-defense alert through a public channel instead of
-- CHAT_MSG_ZONE_UNDER_ATTACK.  Match only the complete client notice wording;
-- do not turn ordinary attack-related conversation into a System message.
local function isZoneUnderAttackNotice(text, sender)
	-- The realm relay is a senderless, yellow client notice. Player-authored
	-- conversation can contain the same words and must never acquire a System
	-- source merely because its sentence discusses an attack.
	if type(text) ~= "string" or sender ~= "" then return false end
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	text = string.gsub(text, "|r", "")
	text = string.gsub(text, "%s+", " ")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	return string.find(text, "^.+%s+is%s+under%s+attack!$") ~= nil
end

-- Text-driven routes use small, explainable evidence scores instead of a
-- brittle one-word switch.  This is intentionally only for public-channel
-- routing: direct event routes (guild, party, whispers, system, etc.) stay
-- authoritative.
local LFG_ROUTE_THRESHOLD = 7
local TRADE_ROUTE_THRESHOLD = 7
local PVP_ROUTE_THRESHOLD = 8
local lfgEvidencePoints = {
	lfm = 8,
	lfg = 7,
	lfCount = 8,
	lf = 4,
	groupPhrase = 8,
	role = 3,
	need = 2,
	more = 1,
	keystone = 3,
	activity = 3,
	dungeon = 3,
	linkedRole = 1,
	commercialCounter = -9,
}
local tradeEvidencePoints = {
	shorthand = 9,
	buySell = 6,
	transactionContext = 1,
	service = 4,
}
local pvpEvidencePoints = {
	explicitContext = 4,
	namedActivity = 5,
	bracket = 6,
	queue = 3,
	team = 3,
	objective = 5,
	tacticalCall = 3,
	role = 2,
	rating = 3,
	recruitment = 2,
	pveCounter = -6,
	commercialCounter = -9,
}

-- Human-readable classifier vocabulary lives beside the executable evidence
-- rules so configuration UI can describe the built-ins without maintaining a
-- second copy.  Pattern-shaped entries are labels only; callers never receive
-- Lua patterns or functions through the public catalog below.
local lfgShorthandTerms = { "LFM", "LFG", "LF#", "LF#DPS", "LF" }
local lfgPhraseTerms = {
	lookingForGroup = "looking for group",
	lookingForMore = "looking for more",
	groupForming = "group forming",
	formingGroup = "forming group",
}
local lfgContextTerms = {
	"group", "dungeon", "heroic", "mythic", "raid", "instance", "rdf", "rhc", "pumper", "pump",
}
local lfgNeedTerms = { "need", "more" }
local lfgKeystoneTerm = "keystone"
local tradeShorthandTerms = { "wts", "wtb", "wtt" }
local tradeBuySellTerms = { "selling", "buying" }
local tradeServiceTerms = { "boost", "service", "services", "crafting", "enchanting", "portal", "portals" }
local pvpExplicitTerms = { "pvp", "battleground", "battlegrounds", "arena", "arenas", "world pvp", "wpvp", "honor farm" }
local pvpNamedActivityTerms = {
	"warsong gulch", "arathi basin", "alterac valley", "eye of the storm",
	"strand of the ancients", "isle of conquest", "wintergrasp",
}
local pvpActivityAcronyms = { "bg", "rbg", "wsg", "ab", "av", "eots", "sota", "ioc", "wg" }
local pvpBracketTerms = { "2v2", "3v3", "5v5", "2s", "3s", "5s" }
local pvpQueueTerms = { "queue", "queued", "queueing", "queuing", "queue pop" }
local pvpTeamTerms = { "premade", "arena team", "pvp team", "bg team", "rated team" }
local pvpObjectiveTerms = {
	"fc", "efc", "flag carrier", "enemy flag carrier", "capture the flag", "cap flag",
	"defend base", "defend the base", "stables", "blacksmith", "lumber mill", "gold mine",
}
local pvpTacticalTerms = { "inc", "incoming", "defend", "defending", "cap", "capture", "peel" }
local pvpRoleTerms = { "healer", "healers", "heal", "heals", "dps", "tank", "tanks" }
local pvpRatingTerms = { "honor", "conquest", "rating", "mmr", "current rating", "cr" }
local pvpRecruitmentTerms = { "lf", "lfm", "need", "looking for", "forming", "recruiting" }
local pvpPveCounterTerms = { "dungeon", "heroic", "mythic", "raid", "instance", "rdf", "rhc" }

local function newEvidence()
	return { score = 0, signals = {} }
end

local function addEvidence(evidence, points, label)
	evidence.score = evidence.score + points
	table.insert(evidence.signals, string.format("%+d %s", points, label))
end

local dungeonTerms = {
	-- Names are safe in ordinary prose; abbreviations below are only scored in
	-- combination with recruiting language, never enough to route on their own.
	"deadmines", "dire maul", "scarlet monastery", "blackrock depths",
	"lower blackrock spire", "upper blackrock spire", "stratholme",
	"scholomance", "utgarde keep", "the nexus", "azjol%-nerub", "ahn'kahet",
	"drak'tharon", "gundrak", "halls of lightning", "halls of stone",
	"culling of stratholme", "trial of the champion", "forge of souls",
	"pit of saron", "halls of reflection",
}

local dungeonAcronyms = {
	"rfc", "sfk", "bfd", "rfd", "uld", "zf", "mara", "brd", "lbrs",
	"ubrs", "dmn", "dme", "dmw", "dtk", "hol", "hos", "fos", "hor",
}

local function hasDungeonReference(text)
	for index = 1, #dungeonTerms do
		if string.find(text, dungeonTerms[index]) then
			return true
		end
	end
	return hasAnyWord(text, dungeonAcronyms)
end

-- Ascension's clickable activity links expose a stable visible label even
-- though the dungeon name, level, role order, and hyperlink payload can vary.
-- Strip that variable wrapper, then accept the one-point semantic interaction
-- only when the remaining text is compact role/count request shorthand.  That
-- prevents linked conversations such as "what tank spec should I play?" from
-- receiving the same bonus as "1 tank / heal".
local roleRequestShorthandWords = {
	tank = true, tanks = true,
	heal = true, heals = true, healer = true, healers = true,
	dps = true,
	["and"] = true, ["or"] = true, x = true,
	need = true, needs = true, needed = true, more = true,
	last = true, pls = true, please = true,
}

local roleRequestWords = { "tank", "tanks", "heal", "heals", "healer", "healers", "dps" }

local function isRoleRequestToken(token)
	if token == "tank" or token == "tanks" or token == "heal" or token == "heals"
		or token == "healer" or token == "healers" or token == "dps" then
		return true
	end
	return string.find(token, "^%d+tanks?$") ~= nil
		or string.find(token, "^%d+heals?$") ~= nil
		or string.find(token, "^%d+healers?$") ~= nil
		or string.find(token, "^%d+dps$") ~= nil
end

local function hasRoleRequestReference(text)
	if hasAnyWord(text, roleRequestWords) then
		return true
	end
	return string.find(text, "%f[%w]%d+%s*tanks?%f[^%w]") ~= nil
		or string.find(text, "%f[%w]%d+%s*heals?%f[^%w]") ~= nil
		or string.find(text, "%f[%w]%d+%s*healers?%f[^%w]") ~= nil
		or string.find(text, "%f[%w]%d+%s*dps%f[^%w]") ~= nil
end

local function getLinkedGroupActivityRemainder(text)
	local stripped = text
	local linkedCount = 0
	local count
	stripped, count = string.gsub(stripped, "%[%s*keystone%s*:.-%]", " ")
	linkedCount = linkedCount + count
	stripped, count = string.gsub(stripped, "%[%s*dungeon%s*:.-%]", " ")
	linkedCount = linkedCount + count
	if linkedCount == 0 then
		return nil
	end
	-- Remove WoW's hyperlink/color/texture control sequences after the visible
	-- activity label is gone.  Other visible prose remains and therefore fails
	-- the shorthand allowlist below instead of being silently ignored.
	stripped = string.gsub(stripped, "|[Hh].-|[Hh]", " ")
	stripped = string.gsub(stripped, "|[Hh]", " ")
	stripped = string.gsub(stripped, "|c%x%x%x%x%x%x%x%x", " ")
	stripped = string.gsub(stripped, "|r", " ")
	stripped = string.gsub(stripped, "|[Tt].-|[Tt]", " ")
	return stripped
end

local function isLinkedRoleRequestShorthand(text)
	local remainder = getLinkedGroupActivityRemainder(text)
	if not remainder then
		return false
	end
	local sawRole = false
	for token in string.gmatch(remainder, "[%w]+") do
		if isRoleRequestToken(token) then
			sawRole = true
		elseif not tonumber(token) and not roleRequestShorthandWords[token]
			and string.find(token, "^%d+x$") == nil and string.find(token, "^x%d+$") == nil then
			return false
		end
	end
	return sawRole
end

local tradeTransactionWords = {
	"pst", "whisper", "offer", "offers", "price", "prices", "each",
	"stack", "stacks", "mats", "reagents", "tip", "tips", "fee", "fees",
	"commission", "commissions",
}

local tradeAdLeadWords = {
	now = true,
	still = true,
	currently = true,
}

local conversationalBuyingObjects = {
	"idea", "argument", "story", "excuse", "theory", "logic", "notion",
	"claim", "explanation", "concept", "plan", "strategy", "time",
	"dream", "dreams",
}

local conversationalBuyingDeterminers = {
	"a", "an", "that", "this", "the", "your", "his", "her", "their", "our",
}

local conversationalSellingTargets = {
	"me", "you", "him", "her", "us", "them", "people", "everyone",
	"guild", "group", "team", "raid", "my%s+guild", "our%s+guild", "the%s+guild",
}

local function getTradeVisibleText(text)
	local visible = string.lower(type(text) == "string" and text or "")
	-- Preserve the label a player actually sees while removing transport markup
	-- that would otherwise look like words before a leading SELLING/BUYING ad.
	visible = string.gsub(visible, "|[Hh].-|[Hh](.-)|[Hh]", "%1")
	visible = string.gsub(visible, "|[Tt].-|[Tt]", " ")
	visible = string.gsub(visible, "|[Aa].-|[Aa]", " ")
	visible = string.gsub(visible, "|c%x%x%x%x%x%x%x%x", "")
	visible = string.gsub(visible, "|r", "")
	visible = string.gsub(visible, "%s+", " ")
	visible = string.gsub(visible, "^%s+", "")
	visible = string.gsub(visible, "%s+$", "")
	return visible
end

local function hasTradeMarketLink(text)
	text = string.lower(type(text) == "string" and text or "")
	return string.find(text, "|hitem:", 1, true) ~= nil
		or string.find(text, "|htrade:", 1, true) ~= nil
		or string.find(text, "|henchant:", 1, true) ~= nil
end

local function hasTradeCurrencyAmount(text)
	return string.find(text, "%f[%d]%d[%d,%.]*%s*[gsc]%f[^%a]") ~= nil
		or string.find(text, "%f[%d]%d[%d,%.]*%s*gold%f[^%a]") ~= nil
end

local function isConversationalBuySellUsage(text)
	if string.find(text, "%f[%a]buying%s+into%f[^%a]")
		or string.find(text, "%f[%a]buying%s+it%f[^%a]") then
		return true
	end
	for objectIndex = 1, #conversationalBuyingObjects do
		local object = conversationalBuyingObjects[objectIndex]
		if string.find(text, "%f[%a]buying%s+" .. object .. "%f[^%a]") then
			return true
		end
		for determinerIndex = 1, #conversationalBuyingDeterminers do
			local determiner = conversationalBuyingDeterminers[determinerIndex]
			if string.find(text, "%f[%a]buying%s+" .. determiner .. "%s+" .. object .. "%f[^%a]") then
				return true
			end
		end
	end
	for index = 1, #conversationalSellingTargets do
		if string.find(text, "%f[%a]selling%s+" .. conversationalSellingTargets[index] .. "%s+on%f[^%a]") then
			return true
		end
	end
	return string.find(text, "%f[%a]selling%s+point%f[^%a]") ~= nil
		or string.find(text, "%f[%a]selling%s+points%f[^%a]") ~= nil
end

local function hasLeadingBuySellAdvertisement(text)
	local words = {}
	for word in string.gmatch(text, "%a+") do
		table.insert(words, word)
		if #words >= 6 then break end
	end
	local index = 1
	while tradeAdLeadWords[words[index]] do
		index = index + 1
	end
	local verb = words[index]
	return (verb == "selling" or verb == "buying") and words[index + 1] ~= nil
end

local function hasBuySellTransactionContext(text)
	local visible = getTradeVisibleText(text)
	-- A supported market link or an explicit amount is authoritative enough to
	-- identify real negotiation even in a phrase such as "not buying [item] for
	-- 20g". Weaker ad/CTA wording still yields to common conversational idioms.
	if hasTradeMarketLink(text) or hasTradeCurrencyAmount(visible) then
		return true
	end
	if isConversationalBuySellUsage(visible) then
		return false
	end
	return hasLeadingBuySellAdvertisement(visible)
		or hasAnyWord(visible, tradeTransactionWords)
end

local function getTradeEvidence(text)
	local evidence = newEvidence()
	if type(text) ~= "string" or text == "" then
		return evidence
	end
	if hasAnyWord(text, tradeShorthandTerms) then
		addEvidence(evidence, tradeEvidencePoints.shorthand, "WTS / WTB / WTT")
	end
	local hasBuySell = hasAnyWord(text, tradeBuySellTerms)
	if hasBuySell then
		addEvidence(evidence, tradeEvidencePoints.buySell, "buying or selling")
	end
	-- BUYING/SELLING is intentionally one point short by itself because those
	-- words appear in ordinary conversation. An ad shape, market link, amount,
	-- or transaction CTA supplies only the missing point instead of lowering the
	-- global threshold or promoting ambiguous service words on their own.
	if hasBuySell and hasBuySellTransactionContext(text) then
		addEvidence(evidence, tradeEvidencePoints.transactionContext, "buy/sell transaction context")
	end
	if hasAnyWord(text, tradeServiceTerms) then
		addEvidence(evidence, tradeEvidencePoints.service, "commercial service")
	end
	return evidence
end

local function getLfgEvidence(text)
	local evidence = newEvidence()
	if type(text) ~= "string" or text == "" then
		return evidence
	end

	local hasRole = hasRoleRequestReference(text)
	local hasKeystone = hasWord(text, lfgKeystoneTerm)
	local hasLfm = hasWord(text, string.lower(lfgShorthandTerms[1]))
	local hasLfg = hasWord(text, string.lower(lfgShorthandTerms[2]))
	local hasLf = hasWord(text, string.lower(lfgShorthandTerms[5]))
	local hasLfCount = string.find(text, "%f[%w]lf%d+%f[^%w]") ~= nil
	local hasCompactLfRole = string.find(text, "%f[%w]lf%d*dps%f[^%w]") ~= nil
	local hasLookingFor = contains(text, lfgPhraseTerms.lookingForGroup) or contains(text, lfgPhraseTerms.lookingForMore)
	local hasForming = contains(text, lfgPhraseTerms.groupForming) or contains(text, lfgPhraseTerms.formingGroup)
	local hasNeed = hasWord(text, lfgNeedTerms[1])
	local hasMore = hasWord(text, lfgNeedTerms[2])
	local hasActivity = hasAnyWord(text, lfgContextTerms)
	local hasDungeon = hasDungeonReference(text)
	local hasLinkedRoleRequest = hasRole and isLinkedRoleRequestShorthand(text) or false

	if hasLfm then addEvidence(evidence, lfgEvidencePoints.lfm, "LFM") end
	if hasLfg then addEvidence(evidence, lfgEvidencePoints.lfg, "LFG") end
	if hasLfCount then addEvidence(evidence, lfgEvidencePoints.lfCount, "LF#")
	elseif hasCompactLfRole then addEvidence(evidence, lfgEvidencePoints.lfCount, "LF#DPS")
	elseif hasLf then addEvidence(evidence, lfgEvidencePoints.lf, "LF") end
	if hasLookingFor then addEvidence(evidence, lfgEvidencePoints.groupPhrase, "looking for group/more") end
	if hasForming then addEvidence(evidence, lfgEvidencePoints.groupPhrase, "forming group") end
	if hasRole then addEvidence(evidence, lfgEvidencePoints.role, "requested role") end
	if hasNeed then addEvidence(evidence, lfgEvidencePoints.need, "need") end
	if hasMore then addEvidence(evidence, lfgEvidencePoints.more, "more") end
	if hasKeystone then addEvidence(evidence, lfgEvidencePoints.keystone, "Keystone") end
	if hasActivity then addEvidence(evidence, lfgEvidencePoints.activity, "group activity") end
	if hasDungeon then addEvidence(evidence, lfgEvidencePoints.dungeon, "dungeon reference") end
	-- A linked activity plus a requested party role is stronger than either
	-- clue alone.  This one-point interaction closes the intentional 6/7 gap
	-- without lowering the global threshold or making a lone role/Keystone word
	-- route ordinary conversation.  Commercial language is still penalized
	-- below, so sales keep the Trade destination.
	if hasLinkedRoleRequest and hasRole then
		addEvidence(evidence, lfgEvidencePoints.linkedRole, "linked activity + requested role")
	end

	-- A clear commercial offer should not become LFG merely because it mentions
	-- a Keystone or a role.  The negative evidence remains visible in ANALYZE.
	local tradeEvidence = getTradeEvidence(text)
	if tradeEvidence.score >= TRADE_ROUTE_THRESHOLD then
		addEvidence(evidence, lfgEvidencePoints.commercialCounter, "commercial trade/service wording")
	end

	if evidence.score >= LFG_ROUTE_THRESHOLD then
		if hasLfg and not (hasLfm or hasNeed or hasRole or hasLf or hasLookingFor or hasForming) then
			evidence.intent = "seeking"
		else
			evidence.intent = "recruiting"
		end
	end
	return evidence
end

local function getPvpEvidence(text)
	local evidence = newEvidence()
	if type(text) ~= "string" or text == "" then
		return evidence
	end

	local hasExplicitContext = hasAnyWord(text, pvpExplicitTerms)
	local hasNamedActivity = containsAny(text, pvpNamedActivityTerms)
		or hasAnyWord(text, pvpActivityAcronyms)
	local hasBracket = hasAnyWord(text, pvpBracketTerms)
	local hasQueue = hasAnyWord(text, pvpQueueTerms)
	local hasObjective = hasAnyWord(text, pvpObjectiveTerms)
	local hasTacticalCall = hasAnyWord(text, pvpTacticalTerms)
	local hasStrongPvpIdentity = hasExplicitContext or hasNamedActivity or hasBracket or hasObjective
	local hasPvpContext = hasStrongPvpIdentity or hasQueue
	local hasTeam = hasWord(text, "premade")
		or containsAny(text, pvpTeamTerms)
		or (hasPvpContext and hasWord(text, "team"))
	if hasTeam then hasPvpContext = true end
	local hasRole = hasPvpContext and hasAnyWord(text, pvpRoleTerms)
	local hasRating = hasPvpContext and hasAnyWord(text, pvpRatingTerms)
	local hasRecruitment = hasPvpContext and hasAnyWord(text, pvpRecruitmentTerms)

	if hasExplicitContext then addEvidence(evidence, pvpEvidencePoints.explicitContext, "explicit PVP context") end
	if hasNamedActivity then addEvidence(evidence, pvpEvidencePoints.namedActivity, "battleground name or acronym") end
	if hasBracket then addEvidence(evidence, pvpEvidencePoints.bracket, "arena bracket") end
	if hasQueue then addEvidence(evidence, pvpEvidencePoints.queue, "queue language") end
	if hasTeam then addEvidence(evidence, pvpEvidencePoints.team, "PVP team or premade") end
	if hasObjective then addEvidence(evidence, pvpEvidencePoints.objective, "battleground objective") end
	if hasObjective and hasTacticalCall then
		addEvidence(evidence, pvpEvidencePoints.tacticalCall, "objective tactical call")
	end
	if hasRole then addEvidence(evidence, pvpEvidencePoints.role, "PVP role") end
	if hasRating then addEvidence(evidence, pvpEvidencePoints.rating, "PVP reward or rating") end
	if hasRecruitment then addEvidence(evidence, pvpEvidencePoints.recruitment, "PVP recruitment") end

	-- Generic queue/team/role wording is common in dungeon conversation. It only
	-- counts against PVP when no unmistakable PVP activity, bracket, or objective
	-- was present; Wintergrasp raids and arena recruitment remain legitimate.
	local hasPveContext = hasWord(text, "keystone") or hasDungeonReference(text)
		or hasAnyWord(text, pvpPveCounterTerms)
	if hasPveContext and not hasStrongPvpIdentity then
		addEvidence(evidence, pvpEvidencePoints.pveCounter, "PVE activity wording")
	end

	-- Commercial arena carries belong to Trade. This uses the same executable
	-- Trade score and threshold shown by ANALYZE, rather than a second ad list.
	local tradeEvidence = getTradeEvidence(text)
	if tradeEvidence.score >= TRADE_ROUTE_THRESHOLD then
		addEvidence(evidence, pvpEvidencePoints.commercialCounter, "commercial trade/service wording")
	end
	return evidence
end

local function getLfgIntent(text)
	return getLfgEvidence(text).intent
end

local MAX_LEARNED_CHANNEL_SOURCES = 64

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

-- Ascension uses zero as a placeholder in the Battle.net argument slots of
-- ordinary chat events. It is never an account identity and must not survive
-- into records where another subsystem could accidentally index it.
local function usableBnetAccountId(value)
	if value == nil then
		return nil
	end
	local text = tostring(value)
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	if text == "" or text == "0" then
		return nil
	end
	local numeric = tonumber(text)
	if numeric and numeric <= 0 then
		return nil
	end
	return text
end

local function copySourceDefinition(definition)
	return {
		id = definition.sourceId,
		sourceId = definition.sourceId,
		group = definition.sourceGroup,
		sourceGroup = definition.sourceGroup,
		groupLabel = definition.groupLabel or sourceGroupLabels[definition.sourceGroup] or definition.sourceGroup,
		label = definition.sourceLabel,
		sourceLabel = definition.sourceLabel,
		static = definition.static and true or false,
		learned = definition.learned and true or false,
	}
end

local function channelSourceToken(value)
	value = string.lower(trim(value, 80))
	value = string.gsub(value, "^%d+%.%s*", "")
	value = string.gsub(value, "[^%w]+", "-")
	value = string.gsub(value, "%-+", "-")
	value = string.gsub(value, "^%-+", "")
	value = string.gsub(value, "%-+$", "")
	if value == "" then
		return "unknown"
	end
	return string.sub(value, 1, 64)
end

local function getChannelSource(record)
	local label = trim(record.channel, 80)
	label = string.gsub(label, "^%d+%.%s*", "")
	-- Wrath's arg9 can be zone-qualified (for example, "General -
	-- Stormwind City"). Keep one stable source across zone changes.
	local baseLabel = string.match(label, "^(.-)%s+%-%s+.+$")
	if baseLabel then
		label = trim(baseLabel, 80)
	end
	if label == "" then
		label = "Channel"
	end
	return "channels", "channel:" .. channelSourceToken(label), label
end

local function getFallbackSource(event)
	local token = string.lower(type(event) == "string" and event or "message")
	token = string.gsub(token, "[^%w]+", "-")
	token = string.gsub(token, "%-+", "-")
	token = string.gsub(token, "^%-+", "")
	token = string.gsub(token, "%-+$", "")
	if token == "" then
		token = "message"
	end
	return "other", "event:" .. token, "Other messages"
end

local function addTag(record, tag)
	if not record.tags then
		record.tags = {}
	end
	record.tags[tag] = true
end

local HISTORY_SCHEMA = 2
local HISTORY_DEFAULT_LINES_PER_SOURCE = 1000
local HISTORY_MIN_LINES_PER_SOURCE = 100
local HISTORY_MAX_LINES_PER_SOURCE = 10000

local persistedFields = {
	-- Classification, tags, and view memberships are deliberately absent: they
	-- are derived again from the current rules on restore. One physical record
	-- is saved under its source even when it belongs to several views.
	"historySequence", "epoch", "timestamp", "event", "text", "sender", "language",
	"channel", "channelNumber", "target", "flags", "lineId", "guid", "class",
	"presenceId", "bnetAccountId", "isBNet", "direction",
	"sourceGroup", "sourceId", "sourceLabel",
	"isAddonMessage", "addonPrefix", "addonPayload", "addonDistribution",
	-- /run and /dump may be routed to the tab that was active when they ran.
	-- Keep that factual primary destination stable when saved history reloads.
	"localCommandView",
}

local function copyRecordForPersistence(record)
	local saved = {}
	for index = 1, #persistedFields do
		local key = persistedFields[index]
		saved[key] = record[key]
	end
	return saved
end

local function normalizeHistoryLinesPerSource(value)
	local lines = tonumber(value)
	if lines == nil then
		lines = HISTORY_DEFAULT_LINES_PER_SOURCE
	end
	lines = math.floor(lines + 0.5)
	if lines < HISTORY_MIN_LINES_PER_SOURCE then
		lines = HISTORY_MIN_LINES_PER_SOURCE
	elseif lines > HISTORY_MAX_LINES_PER_SOURCE then
		lines = HISTORY_MAX_LINES_PER_SOURCE
	end
	return lines
end

local function getRingRecords(ring, maximumRecords)
	local result = {}
	if type(ring) ~= "table" or type(ring.records) ~= "table" then
		return result
	end
	local capacity = math.max(0, math.floor(tonumber(ring.capacity) or 0))
	local count = math.max(0, math.floor(math.min(tonumber(ring.count) or 0, capacity)))
	if tonumber(maximumRecords) then
		count = math.min(count, math.max(0, math.floor(tonumber(maximumRecords))))
	end
	local writeIndex = math.floor(tonumber(ring.writeIndex) or 1)
	if capacity < 1 or count < 1 then
		return result
	end
	writeIndex = ((writeIndex - 1) % capacity) + 1
	local first = writeIndex - count
	while first < 1 do
		first = first + capacity
	end
	for offset = 0, count - 1 do
		local index = first + offset
		if index > capacity then
			index = index - capacity
		end
		if type(ring.records[index]) == "table" then
			table.insert(result, ring.records[index])
		end
	end
	return result
end

local function getHistorySourceId(record)
	local sourceId = type(record) == "table" and record.sourceId or nil
	if type(sourceId) == "string" then
		sourceId = trim(sourceId, 96)
	end
	if not sourceId or sourceId == "" then
		local event = type(record) == "table" and record.event or nil
		local token = string.lower(type(event) == "string" and event or "message")
		token = string.gsub(token, "[^%w]+", "-")
		token = string.gsub(token, "%-+", "-")
		token = string.gsub(token, "^%-+", "")
		token = string.gsub(token, "%-+$", "")
		if token == "" then token = "message" end
		sourceId = "event:" .. token
	end
	return sourceId
end

local function createPersistentHistory(linesPerSource)
	return {
		schema = HISTORY_SCHEMA,
		linesPerSource = normalizeHistoryLinesPerSource(linesPerSource),
		nextSequence = 1,
		sources = {},
	}
end

local function appendPersistentRecord(history, record)
	if type(history) ~= "table" or type(record) ~= "table" then
		return
	end
	local capacity = normalizeHistoryLinesPerSource(history.linesPerSource)
	local sourceId = getHistorySourceId(record)
	local sources = history.sources
	if type(sources) ~= "table" then
		sources = {}
		history.sources = sources
	end
	local ring = sources[sourceId]
	if type(ring) ~= "table" or ring.capacity ~= capacity or type(ring.records) ~= "table" then
		local previous = getRingRecords(ring, capacity)
		ring = { capacity = capacity, count = 0, writeIndex = 1, records = {} }
		sources[sourceId] = ring
		local first = math.max(1, #previous - capacity + 1)
		for index = first, #previous do
			ring.records[ring.writeIndex] = previous[index]
			ring.writeIndex = ring.writeIndex + 1
			if ring.writeIndex > capacity then ring.writeIndex = 1 end
			ring.count = math.min(ring.count + 1, capacity)
		end
	end
	ring.records[ring.writeIndex] = copyRecordForPersistence(record)
	ring.writeIndex = ring.writeIndex + 1
	if ring.writeIndex > capacity then ring.writeIndex = 1 end
	ring.count = math.min(ring.count + 1, capacity)
	local sequence = tonumber(record.historySequence)
	if sequence and sequence >= (tonumber(history.nextSequence) or 1) then
		history.nextSequence = math.floor(sequence) + 1
	end
end

local function getPersistentHistoryRecords(history, maximumPerSource)
	local entries = {}
	local order = 0
	local isSourceSchema = type(history) == "table" and history.schema == HISTORY_SCHEMA
		and type(history.sources) == "table"
	if isSourceSchema then
		local limit = normalizeHistoryLinesPerSource(maximumPerSource or history.linesPerSource)
		for _, ring in pairs(history.sources) do
			local records = getRingRecords(ring, limit)
			for index = 1, #records do
				order = order + 1
				local record = records[index]
				entries[#entries + 1] = {
					record = record,
					sequence = tonumber(record.historySequence),
					epoch = tonumber(record.epoch) or 0,
					order = order,
				}
			end
		end
	else
		-- Schema 1 was one global ring. Its traversal order is already exact;
		-- retain it as the final tie-break while assigning schema-2 sequences.
		local records = getRingRecords(history, HISTORY_MAX_LINES_PER_SOURCE)
		for index = 1, #records do
			order = order + 1
			entries[#entries + 1] = {
				record = records[index],
				sequence = tonumber(records[index].historySequence),
				epoch = tonumber(records[index].epoch) or 0,
				order = order,
			}
		end
	end
	if isSourceSchema then
		local allSequenced = true
		for index = 1, #entries do
			if not entries[index].sequence then allSequenced = false break end
		end
		if allSequenced then
			table.sort(entries, function(left, right)
				if left.sequence ~= right.sequence then return left.sequence < right.sequence end
				if left.epoch ~= right.epoch then return left.epoch < right.epoch end
				return left.order < right.order
			end)
		else
			-- A hand-edited/corrupt schema-2 table can omit sequences. Epoch is
			-- the only cross-source order still recoverable in that case.
			table.sort(entries, function(left, right)
				if left.epoch ~= right.epoch then return left.epoch < right.epoch end
				return left.order < right.order
			end)
		end
	end
	local records = {}
	local nextSequence = 1
	for index = 1, #entries do
		local record = entries[index].record
		local sequence = tonumber(record.historySequence)
		if not sequence or sequence < nextSequence then
			sequence = nextSequence
		end
		record.historySequence = math.floor(sequence)
		nextSequence = record.historySequence + 1
		records[#records + 1] = record
	end
	return records, nextSequence
end

local function ensurePersistentHistory(settings, linesPerSource)
	local capacity = normalizeHistoryLinesPerSource(linesPerSource)
	local current = settings.history
	if type(current) == "table" and current.schema == HISTORY_SCHEMA
		and current.linesPerSource == capacity and type(current.sources) == "table" then
		current.nextSequence = math.max(1, math.floor(tonumber(current.nextSequence) or 1))
		return current
	end
	local records, nextSequence = getPersistentHistoryRecords(current, capacity)
	local rebuilt = createPersistentHistory(capacity)
	for index = 1, #records do
		appendPersistentRecord(rebuilt, records[index])
	end
	rebuilt.nextSequence = math.max(tonumber(rebuilt.nextSequence) or 1, nextSequence or 1)
	settings.history = rebuilt
	return rebuilt
end

local function semanticRouteEnabled(routeId)
	if addon.GetSemanticRouteEnabled then
		return addon:GetSemanticRouteEnabled(routeId)
	end
	return true
end

local function combineCatalogTerms(...)
	local combined = {}
	for sourceIndex = 1, select("#", ...) do
		local source = select(sourceIndex, ...)
		for termIndex = 1, #(source or {}) do
			combined[#combined + 1] = source[termIndex]
		end
	end
	return combined
end

local tradeTransactionCatalogTerms = combineCatalogTerms(
	tradeTransactionWords,
	{ "leading buy/sell advertisement", "item/trade/enchant link", "gold or coin amount" })

local semanticRouteCatalogDefinitions = {
	{
		id = "groupFinder",
		label = "Group Finder",
		threshold = LFG_ROUTE_THRESHOLD,
		explanation = "A LookingForGroup channel routes here directly; other public chat needs enough group-recruiting evidence.",
		categories = {
			{
				id = "lfm", label = "Looking for more shorthand", points = lfgEvidencePoints.lfm,
				terms = { lfgShorthandTerms[1] },
			},
			{
				id = "lfg", label = "Looking for group shorthand", points = lfgEvidencePoints.lfg,
				terms = { lfgShorthandTerms[2] },
			},
			{
				id = "lf-count-role", label = "Compact count or role request", points = lfgEvidencePoints.lfCount,
				terms = { lfgShorthandTerms[3], lfgShorthandTerms[4] },
			},
			{
				id = "lf", label = "Looking-for shorthand", points = lfgEvidencePoints.lf,
				terms = { lfgShorthandTerms[5] },
			},
			{
				id = "group-phrases", label = "Clear group phrases", points = lfgEvidencePoints.groupPhrase,
				terms = {
					lfgPhraseTerms.lookingForGroup, lfgPhraseTerms.lookingForMore,
					lfgPhraseTerms.groupForming, lfgPhraseTerms.formingGroup,
				},
			},
			{ id = "requested-role", label = "Requested role", points = lfgEvidencePoints.role, terms = roleRequestWords },
			{ id = "need", label = "Need wording", points = lfgEvidencePoints.need, terms = { lfgNeedTerms[1] } },
			{ id = "more", label = "More wording", points = lfgEvidencePoints.more, terms = { lfgNeedTerms[2] } },
			{ id = "keystone", label = "Keystone reference", points = lfgEvidencePoints.keystone, terms = { lfgKeystoneTerm } },
			{ id = "activity-context", label = "Group activity context", points = lfgEvidencePoints.activity, terms = lfgContextTerms },
			{
				id = "dungeon-reference", label = "Dungeon reference", points = lfgEvidencePoints.dungeon,
				terms = { "named dungeon or dungeon acronym" },
			},
			{
				id = "activity-links", label = "Linked activity plus requested role", points = lfgEvidencePoints.linkedRole,
				terms = { "Keystone or Dungeon link", "tank", "healer", "DPS" },
			},
			{
				id = "commercial-counterevidence", label = "Commercial wording counts against this route", points = lfgEvidencePoints.commercialCounter,
				terms = { "Trade evidence at threshold" },
			},
		},
	},
	{
		id = "trade",
		label = "Trade",
		threshold = TRADE_ROUTE_THRESHOLD,
		explanation = "Trade is the fallback home for its channel; stronger topic evidence may peel a line into Group Finder or PVP. Other public chat needs enough transaction evidence.",
		categories = {
			{ id = "trade-shorthand", label = "Transaction shorthand", points = tradeEvidencePoints.shorthand, terms = tradeShorthandTerms },
			{ id = "buy-sell", label = "Buying or selling", points = tradeEvidencePoints.buySell, terms = tradeBuySellTerms },
			{
				id = "transaction-context", label = "Transaction context", points = tradeEvidencePoints.transactionContext,
				terms = tradeTransactionCatalogTerms,
			},
			{ id = "commercial-services", label = "Commercial services", points = tradeEvidencePoints.service, terms = tradeServiceTerms },
		},
	},
	{
		id = "pvp",
		label = "PVP",
		threshold = PVP_ROUTE_THRESHOLD,
		explanation = "Battleground events, zone-under-attack notices, and Defense-family channels route here directly; other public chat needs corroborating PVP evidence.",
		categories = {
			{
				id = "direct-pvp-sources", label = "Direct PVP sources",
				terms = { "Battleground events", "Defense", "LocalDefense", "WorldDefense", "is under attack notice" },
			},
			{ id = "explicit-context", label = "Explicit PVP context", points = pvpEvidencePoints.explicitContext, terms = pvpExplicitTerms },
			{
				id = "named-activity", label = "Battleground name or acronym", points = pvpEvidencePoints.namedActivity,
				terms = combineCatalogTerms(pvpNamedActivityTerms, pvpActivityAcronyms),
			},
			{ id = "arena-bracket", label = "Arena bracket", points = pvpEvidencePoints.bracket, terms = pvpBracketTerms },
			{ id = "queue", label = "Queue wording", points = pvpEvidencePoints.queue, terms = pvpQueueTerms },
			{ id = "team", label = "PVP team or premade", points = pvpEvidencePoints.team, terms = pvpTeamTerms },
			{ id = "objective", label = "Battleground objective", points = pvpEvidencePoints.objective, terms = pvpObjectiveTerms },
			{ id = "tactical-call", label = "Objective plus tactical call", points = pvpEvidencePoints.tacticalCall, terms = pvpTacticalTerms },
			{ id = "pvp-role", label = "Role with PVP context", points = pvpEvidencePoints.role, terms = pvpRoleTerms },
			{ id = "rating", label = "Reward or rating with PVP context", points = pvpEvidencePoints.rating, terms = pvpRatingTerms },
			{ id = "recruitment", label = "Recruitment with PVP context", points = pvpEvidencePoints.recruitment, terms = pvpRecruitmentTerms },
			{ id = "pve-counterevidence", label = "PVE wording counts against ambiguous clues", points = pvpEvidencePoints.pveCounter, terms = pvpPveCounterTerms },
			{ id = "commercial-counterevidence", label = "Commercial wording counts against this route", points = pvpEvidencePoints.commercialCounter, terms = { "Trade evidence at threshold" } },
		},
	},
}

local function copySemanticRouteCatalog()
	local result = {}
	for routeIndex = 1, #semanticRouteCatalogDefinitions do
		local definition = semanticRouteCatalogDefinitions[routeIndex]
		local route = {
			id = definition.id,
			label = definition.label,
			threshold = definition.threshold,
			enabled = semanticRouteEnabled(definition.id) and true or false,
			explanation = definition.explanation,
			categories = {},
		}
		for categoryIndex = 1, #definition.categories do
			local source = definition.categories[categoryIndex]
			local category = {
				id = source.id,
				label = source.label,
				terms = {},
			}
			if source.points ~= nil then
				category.points = source.points
			end
			for termIndex = 1, #(source.terms or {}) do
				category.terms[termIndex] = source.terms[termIndex]
			end
			route.categories[categoryIndex] = category
		end
		result[routeIndex] = route
	end
	return result
end

local publicSourceViewById = {
	["channel:newcomers"] = "newcomers",
	["channel:guildrecruitment"] = "guildInvites",
}

local function getPublicSourceView(sourceId, channel)
	if publicSourceViewById[sourceId] then
		return publicSourceViewById[sourceId]
	end
	local label = trim(channel, 80)
	label = string.gsub(label, "^%d+%.%s*", "")
	local baseLabel = string.match(label, "^(.-)%s+%-%s+.+$")
	if baseLabel then label = trim(baseLabel, 80) end
	return publicSourceViewById["channel:" .. channelSourceToken(label)]
end

local defenseChannelTokens = {
	defense = true,
	localdefense = true,
	worlddefense = true,
	localdefence = true,
	worlddefence = true,
}

local function isDefensePublicSource(sourceId, channel)
	local sourceToken = type(sourceId) == "string" and string.match(string.lower(sourceId), "^channel:(.+)$") or nil
	if sourceToken then
		sourceToken = string.gsub(sourceToken, "[^%w]", "")
		if defenseChannelTokens[sourceToken] then return true end
	end

	local label = trim(channel, 80)
	label = string.gsub(label, "^%d+%.%s*", "")
	local baseLabel = string.match(label, "^(.-)%s+%-%s+.+$")
	if baseLabel then label = trim(baseLabel, 80) end
	local channelToken = string.gsub(channelSourceToken(label), "[^%w]", "")
	return defenseChannelTokens[channelToken] and true or false
end

-- Semantic scores use route-specific thresholds, so compare the amount by
-- which each candidate clears its own threshold rather than raw points. This
-- prevents a newly-added route from winning merely because its `elseif`
-- happened to appear first. Ties remain deterministic and prefer the more
-- topic-specific PVP route, then Group Finder, then Trade.
local semanticRouteTiePriority = { pvp = 3, groupFinder = 2, trade = 1 }

local function selectStrongestSemanticRoute(candidates)
	local winner
	for routeId, candidate in pairs(candidates) do
		if candidate.enabled and candidate.evidence.score >= candidate.threshold then
			local margin = candidate.evidence.score - candidate.threshold
			local priority = semanticRouteTiePriority[routeId] or 0
			if not winner or margin > winner.margin
				or (margin == winner.margin and priority > winner.priority) then
				winner = {
					id = routeId,
					score = candidate.evidence.score,
					threshold = candidate.threshold,
					margin = margin,
					priority = priority,
				}
			end
		end
	end
	return winner and winner.id or nil, winner
end

local function analyzeSemanticRoute(text, channel, sourceId, sender)
	text = string.lower(type(text) == "string" and text or "")
	channel = string.lower(type(channel) == "string" and channel or "")
	local lfg = getLfgEvidence(text)
	local trade = getTradeEvidence(text)
	local pvp = getPvpEvidence(text)
	local isUnderAttackNotice = isZoneUnderAttackNotice(text, sender)
	local isDefenseChannel = isDefensePublicSource(sourceId, channel)
	local sourceView = getPublicSourceView(sourceId, channel)
	local isNewcomersSource = sourceView == "newcomers"
	local isGuildRecruitmentSource = sourceView == "guildInvites"
	local isLfgChannel = contains(channel, "lookingforgroup") or contains(channel, "looking for group")
	local isTradeChannel = contains(channel, "trade")
	local lfgEnabled = semanticRouteEnabled("groupFinder")
	local tradeEnabled = semanticRouteEnabled("trade")
	local pvpEnabled = semanticRouteEnabled("pvp")
	local semanticCategory, semanticWinner = selectStrongestSemanticRoute({
		groupFinder = { evidence = lfg, threshold = LFG_ROUTE_THRESHOLD, enabled = lfgEnabled },
		trade = { evidence = trade, threshold = TRADE_ROUTE_THRESHOLD, enabled = tradeEnabled },
		pvp = { evidence = pvp, threshold = PVP_ROUTE_THRESHOLD, enabled = pvpEnabled },
	})
	local category, reasons = "general", {}

	-- Native/relayed defense traffic is a factual PVP source. It stays direct
	-- even when optional PVP text inference is disabled.
	if isUnderAttackNotice then
		category = "pvp"
		table.insert(reasons, "Exact zone-defense notice route to PVP.")
	elseif isDefenseChannel then
		category = "pvp"
		table.insert(reasons, "Defense-family channel source route to PVP.")
	-- GuildRecruitment is a factual single-purpose source. Keep it together even
	-- when an invite happens to mention a dungeon, role, service, or price.
	elseif isGuildRecruitmentSource then
		category = "guildInvites"
		table.insert(reasons, "Exact GuildRecruitment channel source route.")
	-- A purpose-built LFG channel is a source route, not semantic inference.
	elseif isLfgChannel then
		category = "groupFinder"
		table.insert(reasons, "Looking-for-group channel route.")
	elseif semanticCategory then
		category = semanticCategory
		table.insert(reasons, string.format("%s had the strongest qualifying score (%d / %d).",
			semanticCategory == "groupFinder" and "Group Finder" or string.upper(semanticCategory),
			semanticWinner.score, semanticWinner.threshold))
	elseif isTradeChannel then
		category = "trade"
		table.insert(reasons, "Trade channel route.")
	-- Newcomers is a useful home for ordinary onboarding conversation, but
	-- strong LFG/Trade/PVP intent above deliberately peels into a focused view.
	elseif isNewcomersSource then
		category = "newcomers"
		table.insert(reasons, "Newcomers channel fallback after LFG/Trade/PVP inference.")
	else
		if not lfgEnabled then table.insert(reasons, "Group Finder inference is disabled.") end
		if not tradeEnabled then table.insert(reasons, "Trade inference is disabled.") end
		if not pvpEnabled then table.insert(reasons, "PVP inference is disabled.") end
		if #reasons == 0 then table.insert(reasons, "No semantic route reached its threshold.") end
	end

	return {
		category = category,
		scores = { groupFinder = lfg.score, trade = trade.score, pvp = pvp.score },
		threshold = { groupFinder = LFG_ROUTE_THRESHOLD, trade = TRADE_ROUTE_THRESHOLD, pvp = PVP_ROUTE_THRESHOLD },
		signals = { groupFinder = lfg.signals, trade = trade.signals, pvp = pvp.signals },
		intent = lfg.intent,
		isUnderAttackNotice = isUnderAttackNotice,
		isDefenseChannel = isDefenseChannel,
		isNewcomersSource = isNewcomersSource,
		isGuildRecruitmentSource = isGuildRecruitmentSource,
		isLfgChannel = isLfgChannel,
		isTradeChannel = isTradeChannel,
		enabled = { groupFinder = lfgEnabled, trade = tradeEnabled, pvp = pvpEnabled },
		semanticWinner = semanticWinner,
		reasons = reasons,
	}
end

local function classifyChannel(record)
	return analyzeSemanticRoute(record.normalized, record.channel, record.sourceId, record.sender).category
end

local viewForCategory = {
	chat = "general",
	group = "group",
	general = "general",
	sync = "sync",
	conversations = "conversations",
	newcomers = "newcomers",
	groupFinder = "groupFinder",
	guildInvites = "guildInvites",
	trade = "trade",
	pvp = "pvp",
	guild = "guild",
	system = "system",
	loot = "loot",
}

local localCommandBuiltInViews = {}
for _, viewId in pairs(viewForCategory) do
	localCommandBuiltInViews[viewId] = true
end

local function isLocalCommandOutputViewAvailable(viewId)
	if type(viewId) ~= "string" or viewId == "" or viewId == "sync" then
		return false
	end
	if viewId == "system" then
		return true
	end

	-- GetSmartViews includes enabled state and custom rails. If it is not yet
	-- available during an unusually early startup call, built-ins remain safe;
	-- unknown custom IDs fall back to System rather than losing the output.
	if type(addon.GetSmartViews) == "function" then
		local ok, views = pcall(addon.GetSmartViews, addon)
		if ok and type(views) == "table" then
			for index = 1, #views do
				local definition = views[index]
				if type(definition) == "table" and definition.id == viewId then
					return definition.enabled ~= false
				end
			end
		end
	end
	return localCommandBuiltInViews[viewId] == true
end

local function normalizeLocalCommandOutputView(viewId)
	return isLocalCommandOutputViewAvailable(viewId) and viewId or "system"
end

local function isKnownSyncAddonPayload(prefix, payload)
	-- CHAT_MSG_ADDON is not a wildcard feed: it only arrives for prefixes that
	-- another addon has registered.  Even then, recording every payload would
	-- turn the Sync rail into a protocol dump.  Keep the initial receiver exact
	-- and cheap for AscensionLogsCompanion's version handshake.
	if type(prefix) ~= "string" or type(payload) ~= "string"
		or string.len(prefix) > 32 or string.len(payload) > 96 then
		return false
	end
	return string.lower(prefix) == "alcver"
		and string.match(string.lower(payload), "^version:%d+$") ~= nil
end

local function clearGeneratedClassification(record)
	record.category = nil
	record.view = nil
	record.views = nil
	record.isSync = nil
	record.syncReason = nil
	record.routeOverrideCategory = nil
	if type(record.tags) ~= "table" then
		return
	end
	for tag in pairs(record.tags) do
		if type(tag) == "string" and (string.find(tag, "intent:", 1, true) == 1
			or string.find(tag, "role:", 1, true) == 1) then
			record.tags[tag] = nil
		end
	end
	if next(record.tags) == nil then
		record.tags = nil
	end
end

function Engine:InvalidateSyncClassifier()
	self.compiledSyncRevision = nil
	self.compiledSyncSources = nil
end

function Engine:CompileSyncSources(force)
	local cache = addon.GetSyncRoutingCache and addon:GetSyncRoutingCache()
	local revision = cache and cache.revision or 0
	if not force and self.compiledSyncRevision == revision and self.compiledSyncSources then
		return self.compiledSyncSources
	end

	local sources = {}
	if cache and type(cache.sources) == "table" then
		for sourceId, mode in pairs(cache.sources) do
			if type(sourceId) == "string" and (mode == true or mode == false) then
				sources[sourceId] = mode
			end
		end
	end
	self.compiledSyncRevision = revision
	self.compiledSyncSources = sources
	return sources
end

function Engine:IsSyncRecord(record)
	if type(record) ~= "table" then
		return false, nil
	end
	if record.event == "CHAT_MSG_ADDON" then
		if record.isAddonMessage and isKnownSyncAddonPayload(record.addonPrefix, record.addonPayload) then
			return true, "addon"
		end
		-- NormalizeAddon is the only live path that stores CHAT_MSG_ADDON, so a
		-- saved record at this dedicated source is a known handshake even if an
		-- older SavedVariables serializer omitted its protocol metadata.
		if record.sourceId == "addon:alcver" then
			return true, "addon-persisted"
		end
		return false, nil
	end
	if record.event ~= "CHAT_MSG_CHANNEL" then
		return false, nil
	end

	local sourceId = record.sourceId
	local modes = self:CompileSyncSources()
	local mode = sourceId and modes[sourceId]
	if mode == true then
		return true, "source"
	elseif mode == false then
		return false, "source-normal"
	end
	if addon.IsSyncProtocolMessage then
		local matched, reason = addon:IsSyncProtocolMessage(record.event, record.text, record.channel, record.channel)
		return matched and true or false, reason
	end
	return false, nil
end

function Engine:LoadLearnedSources()
	self.learnedSources = {}
	self.learnedSourceCount = 0
	local settings = addon:GetSmartSettings()
	local stored = type(settings.learnedSources) == "table" and settings.learnedSources or {}
	local sourceIds = {}
	for sourceId, definition in pairs(stored) do
		if type(sourceId) == "string" and type(definition) == "table"
			and string.find(sourceId, "channel:", 1, true) == 1 then
			table.insert(sourceIds, sourceId)
		end
	end
	table.sort(sourceIds)

	local normalized = {}
	for index = 1, #sourceIds do
		if self.learnedSourceCount >= MAX_LEARNED_CHANNEL_SOURCES then
			break
		end
		local sourceId = trim(sourceIds[index], 96)
		local storedDefinition = stored[sourceIds[index]]
		local sourceLabel = trim(storedDefinition.sourceLabel or storedDefinition.label, 80)
		if sourceId ~= "" and sourceLabel ~= "" then
			local definition = {
				sourceId = sourceId,
				sourceGroup = "channels",
				sourceLabel = sourceLabel,
				groupLabel = sourceGroupLabels.channels,
				learned = true,
			}
			self.learnedSources[sourceId] = definition
			normalized[sourceId] = {
				sourceId = sourceId,
				sourceGroup = "channels",
				sourceLabel = sourceLabel,
			}
			self.learnedSourceCount = self.learnedSourceCount + 1
		end
	end
	settings.learnedSources = normalized
end

function Engine:LearnSource(record)
	if type(record) ~= "table" or record.event ~= "CHAT_MSG_CHANNEL"
		or type(record.sourceId) ~= "string" or record.sourceId == "" then
		return
	end
	self.learnedSources = self.learnedSources or {}
	self.learnedSourceCount = self.learnedSourceCount or 0

	local sourceId = record.sourceId
	local sourceLabel = trim(record.sourceLabel, 80)
	if sourceLabel == "" then
		return
	end
	local existing = self.learnedSources[sourceId]
	if existing and existing.sourceLabel == sourceLabel then
		return
	end
	if not existing and self.learnedSourceCount >= MAX_LEARNED_CHANNEL_SOURCES then
		return
	end

	local definition = {
		sourceId = sourceId,
		sourceGroup = "channels",
		sourceLabel = sourceLabel,
		groupLabel = sourceGroupLabels.channels,
		learned = true,
	}
	self.learnedSources[sourceId] = definition
	if not existing then
		self.learnedSourceCount = self.learnedSourceCount + 1
	end

	local settings = addon:GetSmartSettings()
	if type(settings.learnedSources) ~= "table" then
		settings.learnedSources = {}
	end
	settings.learnedSources[sourceId] = {
		sourceId = sourceId,
		sourceGroup = "channels",
		sourceLabel = sourceLabel,
	}
end

function Engine:EnsureSource(record)
	if type(record) ~= "table" then
		return record
	end
	if type(record.sourceId) == "string" and record.sourceId ~= ""
		and type(record.sourceGroup) == "string" and record.sourceGroup ~= ""
		and type(record.sourceLabel) == "string" and record.sourceLabel ~= "" then
		-- History from before the PVP rail already carries the stable source IDs
		-- used by saved visibility settings. Refresh only the presentation group
		-- and label for factual PVP events; retaining the ID avoids splitting that
		-- history or losing a player's source toggle.
		local staticSource = directCategories[record.event] == "pvp" and eventSources[record.event] or nil
		if staticSource and record.sourceId == staticSource.sourceId then
			record.sourceGroup = staticSource.sourceGroup
			record.sourceLabel = staticSource.sourceLabel
		end
		if record.event == "CHAT_MSG_CHANNEL" then
			self:LearnSource(record)
		end
		return record
	end

	local sourceGroup, sourceId, sourceLabel
	if record.event == "CHAT_MSG_CHANNEL" then
		sourceGroup, sourceId, sourceLabel = getChannelSource(record)
	else
		local source = eventSources[record.event]
		if source then
			sourceGroup = source.sourceGroup
			sourceId = source.sourceId
			sourceLabel = source.sourceLabel
		else
			sourceGroup, sourceId, sourceLabel = getFallbackSource(record.event)
		end
	end
	record.sourceGroup = sourceGroup
	record.sourceId = sourceId
	record.sourceLabel = sourceLabel
	if record.event == "CHAT_MSG_CHANNEL" then
		self:LearnSource(record)
	end
	return record
end

function Engine:GetStaticSourceDefinitions()
	local definitions = {}
	for index = 1, #staticSourceOrder do
		local sourceId = staticSourceOrder[index]
		table.insert(definitions, copySourceDefinition(staticSourceDefinitions[sourceId]))
	end
	return definitions
end

function Engine:GetLearnedSourceDefinitions()
	local definitions = {}
	local sourceIds = {}
	for sourceId in pairs(self.learnedSources or {}) do
		table.insert(sourceIds, sourceId)
	end
	table.sort(sourceIds)
	for index = 1, #sourceIds do
		local definition = self.learnedSources[sourceIds[index]]
		if definition then
			table.insert(definitions, copySourceDefinition(definition))
		end
	end
	return definitions
end

function Engine:GetSourceDefinitions()
	local definitions = self:GetStaticSourceDefinitions()
	local learned = self:GetLearnedSourceDefinitions()
	for index = 1, #learned do
		table.insert(definitions, learned[index])
	end
	table.sort(definitions, function(left, right)
		if left.sourceGroup ~= right.sourceGroup then
			return left.sourceGroup < right.sourceGroup
		end
		return left.sourceLabel < right.sourceLabel
	end)
	return definitions
end

function Engine:CompileCustomViews(force)
	local settings = addon:GetSmartSettings()
	local revision = math.max(0, math.floor(tonumber(settings.customViewRevision) or 0))
	if not force and self.compiledCustomViewRevision == revision then
		return self.compiledCustomViews or {}
	end

	local definitions = addon:GetSmartViews()
	revision = math.max(0, math.floor(tonumber(settings.customViewRevision) or 0))
	local compiled = {}
	for index = 1, #definitions do
		local definition = definitions[index]
		if definition.custom and definition.enabled ~= false and type(definition.terms) == "table" and #definition.terms > 0 then
			local terms = {}
			for termIndex = 1, #definition.terms do
				local term = definition.terms[termIndex]
				if type(term) == "string" and term ~= "" then
					table.insert(terms, term)
				end
			end
			if #terms > 0 then
				table.insert(compiled, {
					id = definition.id,
					terms = terms,
				})
			end
		end
	end

	self.compiledCustomViews = compiled
	self.compiledCustomViewRevision = revision
	return compiled
end

-- Custom terms are normally body text. Public-channel labels are useful
-- identifiers too (for example, a custom NEWCOMERS rail), but only for public
-- channel records: expanding this to every source would make broad words such
-- as "guild" capture every guild-chat line regardless of its body.
local function getCustomViewTermMatch(record, normalized, term)
	if string.find(normalized, term, 1, true) then
		return "body"
	end
	if record.event ~= "CHAT_MSG_CHANNEL" then
		return nil
	end
	local function matchesChannelField(field)
		return type(field) == "string" and string.find(string.lower(field), term, 1, true) ~= nil
	end
	-- Keep these explicit rather than iterating a table: an older persisted
	-- record can be missing sourceLabel while still carrying a valid sourceId.
	if matchesChannelField(record.sourceLabel)
		or matchesChannelField(record.sourceId)
		or matchesChannelField(record.channel) then
		return "source"
	end
	return nil
end

local function shouldApplyCustomViewMatch(record, primaryView, matchKind)
	-- MOVE is an explicit exclusive correction. Keeping a mirrored custom
	-- membership would make the line appear not to move and contradict the
	-- destination selected in Shift > ANALYZE. UNDO clears the override and the
	-- next reclassification restores any matching custom membership.
	if record.routeOverrideCategory then
		return false
	end
	-- A channel-name term is a convenient source feed (for example NEWCOMERS),
	-- not a second copy of messages already understood as Trade, Group Finder,
	-- System, or Loot. Preserve broader user-authored source lenses when the
	-- primary route is that factual source's built-in home; the exact legacy NC
	-- shape is migrated away by Settings. Body-text rules remain intentional
	-- mirrors everywhere that is not manually moved.
	if matchKind == "source" and primaryView ~= "general"
		and primaryView ~= "newcomers" and primaryView ~= "guildInvites" then
		return false
	end
	return matchKind ~= nil
end

function Engine:ApplyCustomViews(record, skipCustomViews)
	local memberships = {}
	local primaryView = record.view or "general"
	record.view = primaryView
	memberships[primaryView] = true
	if skipCustomViews then
		record.views = memberships
		return memberships
	end

	local normalized = record.normalized
	if type(normalized) ~= "string" then
		normalized = string.lower(type(record.text) == "string" and record.text or "")
		record.normalized = normalized
	end
	local compiled = self:CompileCustomViews()
	for index = 1, #compiled do
		local rule = compiled[index]
		for termIndex = 1, #rule.terms do
			local term = rule.terms[termIndex]
			local matchKind = getCustomViewTermMatch(record, normalized, term)
			if shouldApplyCustomViewMatch(record, primaryView, matchKind) then
				memberships[rule.id] = true
				break
			end
		end
	end
	record.views = memberships
	return memberships
end

function Engine:Classify(record)
	if type(record) ~= "table" then
		return
	end
	if type(record.normalized) ~= "string" then
		record.normalized = string.lower(type(record.text) == "string" and record.text or "")
	end
	self:EnsureSource(record)
	-- Some Ascension realm alerts arrive as CHAT_MSG_CHANNEL.  Give the exact
	-- zone-defense phrase the same independently configurable PVP source as
	-- the native event, without pattern-routing any other player chatter.
	if record.event == "CHAT_MSG_CHANNEL" and isZoneUnderAttackNotice(record.normalized, record.sender) then
		record.sourceGroup = "pvp"
		record.sourceId = "system:under-attack"
		record.sourceLabel = "Zone under attack"
	end
	clearGeneratedClassification(record)

	local isSync, syncReason = self:IsSyncRecord(record)
	if isSync then
		record.category = "sync"
		record.view = "sync"
		record.isSync = true
		record.syncReason = syncReason
		-- Protocol lines are intentionally Sync-only.  Letting a custom text
		-- rule mirror them back into a human rail would defeat the point of
		-- quarantining a noisy source.
		self:ApplyCustomViews(record, true)
		return
	end
	record.isSync = false

	local category = directCategories[record.event]
	if not category and record.event == "CHAT_MSG_CHANNEL" then
		local override = addon.GetMessageRouteOverride and addon:GetMessageRouteOverride(record)
		if override then
			category = override
			record.routeOverrideCategory = override
		else
			category = classifyChannel(record)
		end
	end
	record.category = category or "general"
	record.view = viewForCategory[record.category] or "general"

	if record.category == "groupFinder" then
		local intent = getLfgIntent(record.normalized)
		if intent == "recruiting" then
			addTag(record, "intent:recruiting")
		elseif intent == "seeking" then
			addTag(record, "intent:seeking")
		end

		for index = 1, #roleTokens do
			local role = roleTokens[index]
			if contains(record.normalized, role.token) then
				addTag(record, role.tag)
			end
		end
	elseif record.category == "trade" then
		if contains(record.normalized, "wts") or contains(record.normalized, "selling") then
			addTag(record, "intent:selling")
		elseif contains(record.normalized, "wtb") or contains(record.normalized, "buying") then
			addTag(record, "intent:buying")
		elseif contains(record.normalized, "wtt") then
			addTag(record, "intent:trading")
		end
	elseif record.category == "pvp" then
		addTag(record, "intent:pvp")
		for index = 1, #roleTokens do
			local role = roleTokens[index]
			if hasWord(record.normalized, role.token) then
				addTag(record, role.tag)
			end
		end
	end

	local provider = addon.Compatibility and addon.Compatibility:GetProvider()
	if provider and provider.ClassifyMessage then
		provider:ClassifyMessage(record)
	end
	self:ApplyCustomViews(record)

	-- Command output remains System-classified and keeps its independently
	-- configurable source, but its primary presentation tab may be the tab that
	-- was active when the command ran. Replace only the generated primary
	-- membership; preserve deliberate custom term matches and source feeds.
	if record.localCommandView then
		local targetView = normalizeLocalCommandOutputView(record.localCommandView)
		local previousView = record.view
		local memberships = type(record.views) == "table" and record.views or {}
		if previousView and previousView ~= targetView then
			memberships[previousView] = nil
		end
		record.localCommandView = targetView
		record.view = targetView
		memberships[targetView] = true
		record.views = memberships
	end
end

-- Return a small, read-only explanation of the routing decision for one
-- already-captured record.  This deliberately reuses the classifier's inputs
-- but never calls Classify or changes a record: Shift-hover inspection must be
-- safe to use on history, blocked lines, and live chat alike.
function Engine:AnalyzeRecord(record)

	if type(record) ~= "table" then
		return nil, "invalid-record"
	end

	local normalized = record.normalized
	if type(normalized) ~= "string" then
		normalized = string.lower(type(record.text) == "string" and record.text or "")
	end
	local channel = string.lower(type(record.channel) == "string" and record.channel or "")
	local reasons, signals, customViews = {}, {}, {}
	local isSync, syncReason = self:IsSyncRecord(record)
	local computedCategory, semanticAnalysis

	if isSync then
		computedCategory = "sync"
		table.insert(reasons, "Known SYNC protocol" .. (syncReason and (" (" .. syncReason .. ")") or ""))
	elseif directCategories[record.event] then
		computedCategory = directCategories[record.event]
		table.insert(reasons, "Direct event route: " .. tostring(record.event))
	elseif record.event == "CHAT_MSG_CHANNEL" then
		semanticAnalysis = analyzeSemanticRoute(normalized, channel, record.sourceId, record.sender)
		local isUnderAttackNotice = semanticAnalysis.isUnderAttackNotice
		local isDefenseChannel = semanticAnalysis.isDefenseChannel
		local isNewcomersSource = semanticAnalysis.isNewcomersSource
		local isGuildRecruitmentSource = semanticAnalysis.isGuildRecruitmentSource
		local intent = semanticAnalysis.intent
		local isLfgChannel = semanticAnalysis.isLfgChannel
		local isTradeChannel = semanticAnalysis.isTradeChannel
		local hasRole = hasAnyWord(normalized, { "tank", "healer", "heal", "dps" })
		local hasKeystone = hasWord(normalized, "keystone")
		local hasLf = hasWord(normalized, "lf") or hasWord(normalized, "lfm") or hasWord(normalized, "lfg")
		local hasLfCount = string.find(normalized, "%f[%w]lf%d+%f[^%w]") ~= nil

		table.insert(signals, string.format("GROUP FINDER SCORE %d / %d", semanticAnalysis.scores.groupFinder, semanticAnalysis.threshold.groupFinder))
		for index = 1, #semanticAnalysis.signals.groupFinder do
			table.insert(signals, "LFG " .. semanticAnalysis.signals.groupFinder[index])
		end
		table.insert(signals, string.format("TRADE SCORE %d / %d", semanticAnalysis.scores.trade, semanticAnalysis.threshold.trade))
		for index = 1, #semanticAnalysis.signals.trade do
			table.insert(signals, "TRADE " .. semanticAnalysis.signals.trade[index])
		end
		table.insert(signals, string.format("PVP SCORE %d / %d", semanticAnalysis.scores.pvp, semanticAnalysis.threshold.pvp))
		for index = 1, #semanticAnalysis.signals.pvp do
			table.insert(signals, "PVP " .. semanticAnalysis.signals.pvp[index])
		end
		if isLfgChannel then
			table.insert(signals, "LFG channel")
		end
		if intent then
			table.insert(signals, "LFG intent: " .. intent)
		end
		if hasLf or hasLfCount then
			table.insert(signals, "LF / LFM / LFG language")
		end
		if hasRole then
			table.insert(signals, "Group role requested")
		end
		if hasKeystone then
			table.insert(signals, "Keystone activity")
		end
		if isTradeChannel then
			table.insert(signals, "Trade channel")
		end
		if isNewcomersSource then
			table.insert(signals, "NEWCOMERS exact channel source")
		end
		if isGuildRecruitmentSource then
			table.insert(signals, "GUILD INVITES exact GuildRecruitment source")
		end
		if isUnderAttackNotice then
			table.insert(signals, "PVP exact zone-defense notice")
		end
		if isDefenseChannel then
			table.insert(signals, "PVP Defense-family channel source")
		end

		local override = addon.GetMessageRouteOverride and addon:GetMessageRouteOverride(record)
		if override then
			computedCategory = override
			table.insert(reasons, "Exact public-channel route override: " .. override .. ".")
		elseif isUnderAttackNotice then
			computedCategory = "pvp"
			table.insert(reasons, "Exact zone-defense notice route to PVP before semantic inference.")
		elseif isDefenseChannel then
			computedCategory = "pvp"
			table.insert(reasons, "Defense-family channel source route to PVP before semantic inference.")
		else
			computedCategory = semanticAnalysis.category
			if computedCategory == "groupFinder" then
				for index = 1, #semanticAnalysis.reasons do table.insert(reasons, semanticAnalysis.reasons[index]) end
			elseif computedCategory == "trade" then
				for index = 1, #semanticAnalysis.reasons do table.insert(reasons, semanticAnalysis.reasons[index]) end
			else
				for index = 1, #semanticAnalysis.reasons do table.insert(reasons, semanticAnalysis.reasons[index]) end
			end
		end
	else
		computedCategory = "general"
		table.insert(reasons, "No channel classifier applies; kept in General.")
	end

	local analysisPrimaryView = record.view or viewForCategory[computedCategory] or "general"
	local analysisOverride = record.routeOverrideCategory
		or (addon.GetMessageRouteOverride and addon:GetMessageRouteOverride(record))
	local compiledCustomViews = self:CompileCustomViews() or {}
	for index = 1, #compiledCustomViews do
		local definition = compiledCustomViews[index]
		for termIndex = 1, #(definition.terms or {}) do
			local term = definition.terms[termIndex]
			local matchKind = type(term) == "string" and term ~= ""
				and getCustomViewTermMatch(record, normalized, term) or nil
			local analysisRecord = record
			if analysisOverride and not record.routeOverrideCategory then
				analysisRecord = { routeOverrideCategory = analysisOverride }
			end
			if shouldApplyCustomViewMatch(analysisRecord, analysisPrimaryView, matchKind) then
				table.insert(customViews, definition.id)
				break
			end
		end
	end

	local category = record.category or computedCategory or "general"
	local view = record.view or viewForCategory[category] or "general"
	if record.category and record.category ~= computedCategory then
		table.insert(reasons, "Compatibility provider adjusted the final category to " .. tostring(record.category) .. ".")
	end
	if #customViews > 0 then
		table.insert(reasons, "Also visible in custom view: " .. table.concat(customViews, ", ") .. ".")
	end

	return {
		id = record.id,
		event = record.event,
		category = category,
		view = view,
		sourceGroup = record.sourceGroup,
		sourceId = record.sourceId,
		sourceLabel = record.sourceLabel,
		channel = record.channel,
		reasons = reasons,
		signals = signals,
		customViews = customViews,
		routeOverrideCategory = analysisOverride,
		blocked = record.blockedByBlockControl and true or false,
		blockReason = record.blockReason,
		semantic = semanticAnalysis,
	}
end

function Engine:NormalizeAddon(...)
	local prefix, payload, distribution, sender = ...
	prefix = trim(prefix, 32)
	payload = trim(payload, 512)
	if prefix == "" or payload == "" then
		return nil
	end

	local isSync = isKnownSyncAddonPayload(prefix, payload)
	-- Keep the exact ALCver wire spelling in SYNC, while human-visible feedback
	-- gets a readable delimiter between its registered prefix and payload.
	local message = isSync and (prefix .. ":" .. payload) or (prefix .. ": " .. payload)
	local record = {
		id = self.nextId,
		time = GetTime and GetTime() or 0,
		epoch = time and time() or 0,
		timestamp = date and date("%H:%M") or "",
		event = "CHAT_MSG_ADDON",
		text = message,
		normalized = string.lower(message),
		sender = sender,
		channel = distribution,
		direction = "incoming",
		isAddonMessage = true,
		addonPrefix = prefix,
		addonPayload = payload,
		addonDistribution = distribution,
	}
	if not isSync then
		record.sourceGroup = "system"
		record.sourceId = "system:addon-feedback"
		record.sourceLabel = "Add-on feedback"
	end
	self.nextId = self.nextId + 1
	self:Classify(record)
	return record
end

function Engine:NormalizeUIError(...)
	-- Wrath sends UI_ERROR_MESSAGE as (messageType, message), while a few
	-- private-client paths expose only the final string.  Accept both shapes;
	-- a malformed UI event must never prevent later feedback from being shown.
	local messageType, message = ...
	if type(message) ~= "string" or message == "" then
		message = type(messageType) == "string" and messageType or nil
	end
	message = trim(message, 512)
	if message == "" then
		return nil
	end

	local record = {
		id = self.nextId,
		time = GetTime and GetTime() or 0,
		epoch = time and time() or 0,
		timestamp = date and date("%H:%M") or "",
		event = "UI_ERROR_MESSAGE",
		text = message,
		normalized = string.lower(message),
		direction = "incoming",
	}
	self.nextId = self.nextId + 1
	self:Classify(record)
	return record
end

function Engine:GetLocalCommandOutputSettings()
	if type(addon.GetLocalCommandOutputSettings) == "function" then
		local ok, settings = pcall(addon.GetLocalCommandOutputSettings, addon)
		if ok and type(settings) == "table" then
			return {
				enabled = settings.enabled ~= false,
				destination = settings.destination == "active" and "active" or "system",
			}
		end
	end
	local smart = type(addon.GetSmartSettings) == "function" and addon:GetSmartSettings() or nil
	local settings = type(smart) == "table" and smart.localCommandOutput or nil
	return {
		enabled = not settings or settings.enabled ~= false,
		destination = settings and settings.destination == "active" and "active" or "system",
	}
end

function Engine:ResolveLocalCommandOutputView(settings)
	settings = type(settings) == "table" and settings or self:GetLocalCommandOutputSettings()
	if settings.destination ~= "active" then
		return "system"
	end

	local viewId
	local dock = addon.SmartDock
	if dock and type(dock.activeView) == "string" then
		viewId = dock.activeView
	end
	if not viewId and type(addon.GetSmartSettings) == "function" then
		local smart = addon:GetSmartSettings()
		viewId = type(smart) == "table" and type(smart.dock) == "table"
			and smart.dock.activeView or nil
	end
	return normalizeLocalCommandOutputView(viewId)
end

function Engine:CaptureLocalFeedback(text, destinationView)
	-- Intentionally direct: print() / DEFAULT_CHAT_FRAME:AddMessage() are not
	-- chat events. The general public bridge remains explicit; the command
	-- bridge below observes AddMessage only inside /run, /script, or /dump.
	-- Command inspectors can legitimately emit wider table/value rows than an
	-- ordinary chat line. Preserve a useful bounded row without letting a macro
	-- inject an unbounded SavedVariables string.
	text = trim(text, destinationView and 2048 or 512)
	if text == "" then
		return nil, "empty"
	end
	if not self.records then
		return nil, "not-initialized"
	end

	local record = {
		id = self.nextId,
		time = GetTime and GetTime() or 0,
		epoch = time and time() or 0,
		timestamp = date and date("%H:%M") or "",
		event = "CCBB_LOCAL_MESSAGE",
		text = text,
		normalized = string.lower(text),
		direction = "incoming",
		sourceGroup = "system",
		sourceId = "system:local-debug",
		sourceLabel = "Local add-on feedback",
		localCommandView = type(destinationView) == "string"
			and normalizeLocalCommandOutputView(destinationView) or nil,
	}
	self.nextId = self.nextId + 1
	self:Classify(record)
	local delivered, reason = self:TryDeliver(record)
	if delivered then
		return delivered
	end
	return nil, reason
end

function Engine:CaptureLocalCommandFrameOutput(text)
	local stack = self.localCommandCaptureViews
	local destinationView = type(stack) == "table" and stack[#stack] or nil
	if not self.enabled or type(destinationView) ~= "string" then
		return nil, "inactive"
	end
	-- A presentation/settings fault must never turn a working Blizzard command
	-- into a failed /run or /dump after its native output has already printed.
	local ok, record, reason = pcall(self.CaptureLocalFeedback, self, text, destinationView)
	if ok then
		return record, reason
	end
	return nil, "capture-error"
end

local localCommandAliases = {
	["/run"] = true,
	["/script"] = true,
	["/dump"] = true,
}

local function getLocalCommandSlashKeys()
	local keys, seen, aliasesByKey = {}, {}, {}
	for globalName, alias in pairs(_G) do
		local key = type(globalName) == "string"
			and string.match(globalName, "^SLASH_(.-)%d+$") or nil
		local normalizedAlias = type(alias) == "string"
			and string.lower(trim(alias, 24)) or nil
		if key and localCommandAliases[normalizedAlias] then
			aliasesByKey[key] = aliasesByKey[key] or {}
			table.insert(aliasesByKey[key], normalizedAlias)
			if not seen[key] then
				seen[key] = true
				table.insert(keys, key)
			end
		end
	end
	table.sort(keys)
	return keys, aliasesByKey
end

function Engine:RefreshLocalCommandCapture()
	local frame = _G.DEFAULT_CHAT_FRAME
	if frame and type(frame.AddMessage) == "function" and type(hooksecurefunc) == "function" then
		self.localCommandHookedFrames = self.localCommandHookedFrames or {}
		if not self.localCommandHookedFrames[frame] then
			local ok = pcall(hooksecurefunc, frame, "AddMessage", function(_, text)
				Engine:CaptureLocalCommandFrameOutput(text)
			end)
			if ok then
				self.localCommandHookedFrames[frame] = true
			end
		end
	end

	local slashCommands = _G.SlashCmdList
	if type(slashCommands) ~= "table" then
		return
	end
	self.localCommandSlashWrappers = self.localCommandSlashWrappers or {}
	local slashKeys, aliasesByKey = getLocalCommandSlashKeys()
	for _, key in ipairs(slashKeys) do
		local current = slashCommands[key]
		local existing = self.localCommandSlashWrappers[key]
		if type(current) == "function" and (not existing or current ~= existing.wrapper) then
			local original = current
			local wrapper = function(...)
				local destinationView = false
				if Engine.enabled then
					local settingsOk, settings = pcall(Engine.GetLocalCommandOutputSettings, Engine)
					if settingsOk and type(settings) == "table" and settings.enabled then
						local viewOk, resolved = pcall(Engine.ResolveLocalCommandOutputView, Engine, settings)
						if viewOk and type(resolved) == "string" then
							destinationView = resolved
						end
					end
				end
				Engine.localCommandCaptureViews = Engine.localCommandCaptureViews or {}
				table.insert(Engine.localCommandCaptureViews, destinationView)
				local ok, first, second, third, fourth, fifth = pcall(original, ...)
				table.remove(Engine.localCommandCaptureViews)
				if not ok then
					error(first, 0)
				end
				return first, second, third, fourth, fifth
			end
			self.localCommandSlashWrappers[key] = {
				original = original,
				wrapper = wrapper,
			}
			slashCommands[key] = wrapper
			-- Wrath caches resolved slash handlers separately. Merely replacing
			-- SlashCmdList leaves an already-used /run or /dump pointing at the old
			-- function, so invalidate only the three aliases we deliberately own.
			local slashHash = _G.hash_SlashCmdList
			if type(slashHash) == "table" then
				for _, alias in ipairs(aliasesByKey[key] or {}) do
					slashHash[string.upper(alias)] = nil
				end
			end
		end
	end
end

local function writeNativeDebugFallback(text)
	local frame = _G.DEFAULT_CHAT_FRAME
	if frame and type(frame.AddMessage) == "function" then
		frame:AddMessage("|cff72d8ff[Chatty Debug]|r " .. text)
		return false, "native-fallback"
	end
	return false, "no-chat-frame"
end

-- Public, explicit local-feedback bridge.  This is intentionally not a hook:
-- callers opt in with ChattyChattyBangBang:DebugMessage("...") and the line
-- becomes a System-rail record only while Smart Chat is actively presenting.
-- With Smart Chat off, retain useful diagnostics in the native chat frame.
function addon:DebugMessage(text)
	text = trim(text, 512)
	if text == "" then
		return false, "empty"
	end

	local settings = self.GetSmartSettings and self:GetSmartSettings()
	local engine = self.MessageEngine
	if settings and settings.enabled and engine and engine.enabled
		and type(engine.CaptureLocalFeedback) == "function" then
		local record, reason = engine:CaptureLocalFeedback(text)
		if record then
			return true, record
		end
		if reason == "empty" or reason == "blocked" or reason == "rule" or reason == "ui-coalesced" then
			return false, reason
		end
	end
	return writeNativeDebugFallback(text)
end

-- A clearer public name for other add-ons. It deliberately shares the same
-- narrow one-way path as DebugMessage rather than hooking every AddMessage
-- call made by every chat addon on the client.
function addon:SystemMessage(text)
	return self:DebugMessage(text)
end

-- Public read-only route inspector used by Smart Dock's Shift-hover ANALYZE
-- control.  Keeping this bridge narrow means other UI can show the same
-- explanation without duplicating or mutating MessageEngine's classifier.
function addon:AnalyzeRecord(record)
	if self.MessageEngine and type(self.MessageEngine.AnalyzeRecord) == "function" then
		return self.MessageEngine:AnalyzeRecord(record)
	end
	return nil, "unavailable"
end

-- Public, read-only preview for configuration UI and diagnostics.  It only
-- evaluates public-channel semantic routes; it never captures a line or edits
-- the player's per-message manual corrections.
function addon:AnalyzeSemanticRoute(text, channel)
	return analyzeSemanticRoute(string.lower(type(text) == "string" and text or ""), channel)
end

-- Stable read-only classifier catalog for configuration UI. Every call returns
-- fresh route/category/term tables, so consumers can format or annotate their
-- copy without mutating MessageEngine's authoritative definitions.
function addon:GetSemanticRouteCatalog()
	return copySemanticRouteCatalog()
end

-- Macro-sized alias.  It stays safe when this add-on is disabled or loading:
-- DebugMessage routes to the System rail when possible and this fallback
-- keeps the diagnostic visible in DEFAULT_CHAT_FRAME otherwise.
_G.CCBB_Debug = function(text)
	local currentAddon = _G.ChattyChattyBangBang
	if currentAddon and type(currentAddon.DebugMessage) == "function" then
		return currentAddon:DebugMessage(text)
	end
	return writeNativeDebugFallback(trim(text, 512))
end

_G.CCBB_System = function(text)
	local currentAddon = _G.ChattyChattyBangBang
	if currentAddon and type(currentAddon.SystemMessage) == "function" then
		return currentAddon:SystemMessage(text)
	end
	return writeNativeDebugFallback(trim(text, 512))
end

function Engine:Normalize(event, ...)
	if event == "CHAT_MSG_ADDON" then
		return self:NormalizeAddon(...)
	end
	if event == "UI_ERROR_MESSAGE" then
		return self:NormalizeUIError(...)
	end
	local message, sender, language, channelName, target, flags, _, channelNumber, channelBaseName, _, lineId, guid, presenceId, bnetAccountId = ...
	if type(message) ~= "string" then
		return nil
	end

	local now = GetTime and GetTime() or 0
	local class
	-- Ascension occasionally supplies an empty string in the sender-GUID slot.
	-- GetPlayerInfoByGUID rejects that value and would otherwise abort capture for
	-- the entire chat line.  Class colour is presentation metadata, so an
	-- invalid GUID must never be allowed to break routing or spam filtering.
	if type(guid) == "string" and guid ~= "" and GetPlayerInfoByGUID then
		local ok, _, classToken = pcall(GetPlayerInfoByGUID, guid)
		if ok then
			class = classToken
		end
	end
	local isBNet = string.find(event, "CHAT_MSG_BN_", 1, true) == 1
	if isBNet then
		-- Wrath backports commonly expose the stable BN sender ID at arg13;
		-- some Ascension paths provide a newer extended ID at arg14 instead.
		bnetAccountId = usableBnetAccountId(bnetAccountId) or usableBnetAccountId(presenceId)
	else
		bnetAccountId = nil
	end
	local record = {
		id = self.nextId,
		time = now,
		epoch = time and time() or 0,
		timestamp = date and date("%H:%M") or "",
		event = event,
		text = message,
		normalized = string.lower(message),
		sender = sender,
		language = language,
		channel = channelBaseName or channelName,
		channelNumber = channelNumber,
		target = target,
		flags = flags,
		lineId = lineId,
		guid = guid,
		class = class,
		presenceId = presenceId,
		bnetAccountId = bnetAccountId,
		isBNet = isBNet,
		direction = (event == "CHAT_MSG_WHISPER_INFORM" or event == "CHAT_MSG_BN_WHISPER_INFORM") and "outgoing" or "incoming",
	}
	self.nextId = self.nextId + 1
	self:Classify(record)
	if (record.view == "groupFinder" or record.view == "trade" or record.view == "pvp"
		or record.view == "newcomers" or record.view == "guildInvites")
		and tonumber(channelNumber) and tonumber(channelNumber) > 0 then
		addon:GetSmartSettings().channelTargets[record.view] = tonumber(channelNumber)
	end
	return record
end

function Engine:Persist(record)
	local settings = addon:GetSmartSettings()
	if not settings.persistHistory or self.loadingPersistence then
		return
	end
	local history = ensurePersistentHistory(settings, self.capacity)
	appendPersistentRecord(history, record)
end

local function clearRuntimeHistory(engine)
	engine.records = {}
	engine.byId = {}
	engine.sourceHistories = {}
	engine.historyHead = nil
	engine.historyTail = nil
	engine.count = 0
	-- Retained as a harmless compatibility field for integrations that used to
	-- inspect the global ring. Storage itself is now source-owned.
	engine.writeIndex = 1
end

local function unlinkRuntimeRecord(engine, record)
	if type(record) ~= "table" then return end
	local previous = record._historyPrevious
	local nextRecord = record._historyNext
	if previous then previous._historyNext = nextRecord else engine.historyHead = nextRecord end
	if nextRecord then nextRecord._historyPrevious = previous else engine.historyTail = previous end

	local sourceId = record._historySourceId
	local source = sourceId and engine.sourceHistories[sourceId] or nil
	if source then
		local sourcePrevious = record._sourceHistoryPrevious
		local sourceNext = record._sourceHistoryNext
		if sourcePrevious then sourcePrevious._sourceHistoryNext = sourceNext else source.head = sourceNext end
		if sourceNext then sourceNext._sourceHistoryPrevious = sourcePrevious else source.tail = sourcePrevious end
		source.count = math.max(0, (tonumber(source.count) or 1) - 1)
		if source.count == 0 then engine.sourceHistories[sourceId] = nil end
	end

	if record.id ~= nil then
		engine.byId[record.id] = nil
		engine.records[record.id] = nil
	end
	record._historyPrevious = nil
	record._historyNext = nil
	record._sourceHistoryPrevious = nil
	record._sourceHistoryNext = nil
	record._historySourceId = nil
	engine.count = math.max(0, (tonumber(engine.count) or 1) - 1)
end

local function appendRuntimeRecord(engine, record)
	local sourceId = getHistorySourceId(record)
	record.sourceId = record.sourceId or sourceId
	record._historySourceId = sourceId
	record._historyPrevious = engine.historyTail
	record._historyNext = nil
	if engine.historyTail then engine.historyTail._historyNext = record else engine.historyHead = record end
	engine.historyTail = record

	local source = engine.sourceHistories[sourceId]
	if not source then
		source = { count = 0, head = nil, tail = nil }
		engine.sourceHistories[sourceId] = source
	end
	record._sourceHistoryPrevious = source.tail
	record._sourceHistoryNext = nil
	if source.tail then source.tail._sourceHistoryNext = record else source.head = record end
	source.tail = record
	source.count = source.count + 1

	engine.records[record.id] = record
	engine.byId[record.id] = record
	engine.count = engine.count + 1
	while source.count > engine.capacity and source.head do
		unlinkRuntimeRecord(engine, source.head)
	end
end

function Engine:PruneHistoryToSourceLimit(linesPerSource)
	local capacity = normalizeHistoryLinesPerSource(linesPerSource)
	self.capacity = capacity
	local sourceIds = {}
	for sourceId in pairs(self.sourceHistories or {}) do sourceIds[#sourceIds + 1] = sourceId end
	for index = 1, #sourceIds do
		local source = self.sourceHistories[sourceIds[index]]
		while source.count > capacity and source.head do
			unlinkRuntimeRecord(self, source.head)
		end
	end
	return capacity
end

function Engine:RebuildPersistence()
	local settings = addon:GetSmartSettings()
	if not settings.persistHistory then
		settings.history = nil
		return false
	end
	local history = createPersistentHistory(self.capacity or settings.historyCapacity)
	local record = self.historyHead
	while record do
		appendPersistentRecord(history, record)
		record = record._historyNext
	end
	history.nextSequence = math.max(tonumber(history.nextSequence) or 1, tonumber(self.nextHistorySequence) or 1)
	settings.history = history
	return true
end

function Engine:ClearPersistentHistory()
	local settings = addon:GetSmartSettings()
	settings.history = nil
	return true
end

function Engine:SetHistoryLinesPerSource(linesPerSource)
	local capacity = self:PruneHistoryToSourceLimit(linesPerSource)
	local settings = addon:GetSmartSettings()
	settings.historyCapacity = capacity
	if settings.persistHistory then
		self:RebuildPersistence()
	end
	if addon.SmartDock and addon.SmartDock.RebuildActiveView then
		addon.SmartDock:RebuildActiveView()
	end
	return capacity
end

function Engine:ClearHistory()
	clearRuntimeHistory(self)
	self.nextId = 1
	self.nextHistorySequence = 1
	local settings = addon:GetSmartSettings()
	if settings.persistHistory then
		settings.history = createPersistentHistory(settings.historyCapacity)
	else
		settings.history = nil
	end
	if addon.SmartDock and addon.SmartDock.RebuildActiveView then
		addon.SmartDock:RebuildActiveView()
	end
	return true
end

function Engine:GetHistoryStats()
	local sourceCount = 0
	for _ in pairs(self.sourceHistories or {}) do sourceCount = sourceCount + 1 end
	return {
		lines = tonumber(self.count) or 0,
		sources = sourceCount,
		linesPerSource = normalizeHistoryLinesPerSource(self.capacity),
	}
end

function Engine:Store(record)
	local settings = addon:GetSmartSettings()
	local capacity = normalizeHistoryLinesPerSource(settings.historyCapacity)
	if self.capacity ~= capacity then
		self:PruneHistoryToSourceLimit(capacity)
	end

	local sequence = tonumber(record.historySequence)
	local nextSequence = math.max(1, math.floor(tonumber(self.nextHistorySequence) or 1))
	if not sequence or sequence < nextSequence then
		sequence = nextSequence
	end
	record.historySequence = math.floor(sequence)
	self.nextHistorySequence = record.historySequence + 1
	appendRuntimeRecord(self, record)
	self:Persist(record)
end

function Engine:ResetForProfile()
	clearRuntimeHistory(self)
	self.recentSystemFeedback = nil
	self.lastSystemFeedbackPrune = nil
	self.capacity = normalizeHistoryLinesPerSource(addon:GetSmartSettings().historyCapacity)
	self.nextId = 1
	self.nextHistorySequence = 1
	self.compiledCustomViewRevision = nil
	self.compiledCustomViews = nil
	self:InvalidateSyncClassifier()
	self:LoadLearnedSources()

	local settings = addon:GetSmartSettings()
	if settings.persistHistory then
		local savedRecords = getPersistentHistoryRecords(settings.history, self.capacity)
		self.loadingPersistence = true
		for index = 1, #savedRecords do
			local record = copyRecordForPersistence(savedRecords[index])
			if type(record.text) == "string" and type(record.event) == "string" then
				record.id = self.nextId
				record.time = 0
				record.normalized = record.normalized or string.lower(record.text)
				self.nextId = self.nextId + 1
				-- Source identity must be current before the record enters its source
				-- ring; schema-1 or hand-edited records may not have stored it.
				self:Classify(record)
				self:Store(record)
			end
		end
		self.loadingPersistence = false
		-- Also converts schema 1 and resized schema-2 rings in one bounded pass.
		self:RebuildPersistence()
	end
	self:ReclassifyAll()
	self:ReapplyBlockRules()
end

function Engine:ReclassifyAll()
	self.compiledCustomViewRevision = nil
	self:CompileCustomViews(true)
	self:CompileSyncSources(true)
	local changed = 0
	if not self.count or self.count == 0 then
		return changed
	end

	local record = self.historyHead
	while record do
		self:Classify(record)
		changed = changed + 1
		record = record._historyNext
	end
	return changed
end

function Engine:GetMessageById(id)
	return self.byId and self.byId[tonumber(id)] or nil
end

-- One stored record can be visible through two independent lenses: its
-- classifier/custom-rule membership and any full physical-source feed checked
-- under a tab's CONTENTS page. The union is evaluated at read time so changing
-- a checkbox updates history immediately without duplicating or rewriting it.
function Engine:RecordBelongsToView(record, viewId, settings)
	if type(record) ~= "table" then return false end
	if type(viewId) ~= "string" or viewId == "" then return true end
	if addon.IsRecordAllowedInView
		and addon:IsRecordAllowedInView(viewId, record, settings) == false then
		return false
	end

	local memberships = record.views
	if type(memberships) == "table" then
		if memberships[viewId] then return true end
	elseif record.view == viewId then
		return true
	end

	if addon.IsRecordIncludedBySource then
		return addon:IsRecordIncludedBySource(viewId, record, settings) == true
	elseif addon.IsRecordSourceIncludedInView then
		return addon:IsRecordSourceIncludedInView(viewId, record, settings) == true
	end
	return false
end

function Engine:GetMessages(viewId)
	local messages = {}
	if not self.count or self.count == 0 then
		return messages
	end
	local viewSettings
	if viewId and addon.GetSmartSettings then
		viewSettings = addon:GetSmartSettings()
	end

	local record = self.historyHead
	while record do
		local belongsToView = not viewId or self:RecordBelongsToView(record, viewId, viewSettings)
		if record and not record.blockedByBlockControl and belongsToView then
			table.insert(messages, record)
		end
		record = record._historyNext
	end
	return messages
end

function Engine:RegisterListener(name, callback)
	if name and type(callback) == "function" then
		self.listeners = self.listeners or {}
		self.listeners[name] = callback
	end
end

function Engine:UnregisterListener(name)
	if self.listeners then
		self.listeners[name] = nil
	end
end

local SYSTEM_FEEDBACK_DEDUPE_WINDOW = 0.35
local SYSTEM_FEEDBACK_RETENTION = 2

local function getSystemFeedbackFingerprint(text)
	text = string.lower(type(text) == "string" and text or "")
	text = string.gsub(text, "%s+", " ")
	return trim(text, 512)
end

function Engine:IsDuplicateSystemFeedback(record)
	if type(record) ~= "table"
		or (record.event ~= "CHAT_MSG_SYSTEM" and record.event ~= "UI_ERROR_MESSAGE") then
		return false
	end

	local fingerprint = getSystemFeedbackFingerprint(record.text)
	if fingerprint == "" then
		return false
	end
	local now = tonumber(record.time) or (GetTime and GetTime()) or 0
	self.recentSystemFeedback = self.recentSystemFeedback or {}
	local previous = self.recentSystemFeedback[fingerprint]
	local duplicate = previous and previous.event ~= record.event
		and now >= previous.time and now - previous.time <= SYSTEM_FEEDBACK_DEDUPE_WINDOW
	self.recentSystemFeedback[fingerprint] = {
		event = record.event,
		time = now,
	}

	-- UI/system feedback is low-volume, but keep the dedupe ledger bounded for
	-- marathon Ascension sessions instead of retaining each distinct error.
	if not self.lastSystemFeedbackPrune or now - self.lastSystemFeedbackPrune >= SYSTEM_FEEDBACK_RETENTION then
		for key, entry in pairs(self.recentSystemFeedback) do
			if now < entry.time or now - entry.time > SYSTEM_FEEDBACK_RETENTION then
				self.recentSystemFeedback[key] = nil
			end
		end
		self.lastSystemFeedbackPrune = now
	end
	return duplicate and true or false
end

-- Message Blocks are an explicit presentation gate, not a ChatFrame hook.
-- This lets a player hide a noisy UI error or selected message pattern without
-- re-running filters, altering Blizzard event dispatch, or recursing through
-- DEFAULT_CHAT_FRAME:AddMessage.
function Engine:ShouldBlockRecord(record)
	local control = addon.BlockControl
	if not control or type(control.ShouldBlock) ~= "function" then
		return false
	end
	local blocked, reason, rule = control:ShouldBlock(record)
	if blocked then
		record.blockedByBlockControl = true
		record.blockReason = reason
		record.blockRuleId = type(rule) == "table" and rule.id or nil
		return true, reason, rule
	end
	return false
end

function Engine:TryDeliver(record)
	if self:IsDuplicateSystemFeedback(record) then
		return nil, "duplicate-system-feedback"
	end
	local blocked, reason, rule = self:ShouldBlockRecord(record)
	if blocked then
		-- Manual blocks quarantine their own matches before they can enter normal
		-- runtime or persisted history. UI repeat coalescing deliberately has no
		-- archive: it is automatic noise control, not a player-authored rule.
		local control = addon.BlockControl
		if reason == "rule" and control and type(control.ArchiveRecord) == "function" then
			control:ArchiveRecord(record, reason, rule)
		end
		return nil, reason or "blocked"
	end
	return self:Deliver(record)
end

function Engine:Deliver(record)
	if type(record) ~= "table" then
		return nil
	end
	self:Store(record)

	for name, callback in pairs(self.listeners or {}) do
		local ok, err = pcall(callback, record)
		if not ok then
			self.listenerErrors = self.listenerErrors or {}
			if not self.listenerErrors[name] then
				self.listenerErrors[name] = true
				addon:Print("Message listener '" .. tostring(name) .. "' failed: " .. tostring(err))
			end
		end
	end
	return record
end

-- Rules normally run before a record enters history. Re-evaluate the bounded
-- in-memory history whenever a rule changes so a Shift-hover block moves every
-- already-visible match into the separate Blocked Messages archive immediately.
-- UI feedback coalescing is deliberately skipped: it controls live repeats,
-- not old history, and is never archived as though it were a manual block.
function Engine:ReapplyBlockRules()
	if not self.historyHead or not self.count or self.count == 0 then
		if addon.SmartDock and addon.SmartDock.RebuildActiveView then
			addon.SmartDock:RebuildActiveView()
		end
		return 0
	end
	local control = addon.BlockControl
	if not control or type(control.ShouldBlock) ~= "function" then
		return 0
	end
	local changed = 0
	local record = self.historyHead
	while record do
		-- unlinkRuntimeRecord clears the list pointers, so retain the next node
		-- before evaluating/removing the current one.
		local nextRecord = record._historyNext
		record.blockedByBlockControl = nil
		record.blockReason = nil
		record.blockRuleId = nil
		local blocked, reason, rule = control:ShouldBlock(record, {
			skipCoalescer = true,
			countStats = false,
		})
		if blocked then
			if reason == "rule" and type(control.ArchiveRecord) == "function" then
				control:ArchiveRecord(record, reason, rule)
			end
			unlinkRuntimeRecord(self, record)
			changed = changed + 1
		end
		record = nextRecord
	end
	-- Runtime removal alone is not enough: the normal transcript's separate
	-- SavedVariables ring must be rebuilt once from the survivors so a reload
	-- cannot bring quarantined text back.
	if changed > 0 and addon:GetSmartSettings().persistHistory then
		self:RebuildPersistence()
	end
	if addon.SmartDock and addon.SmartDock.RebuildActiveView then
		addon.SmartDock:RebuildActiveView()
	end
	return changed
end

function Engine:Capture(event, ...)
	local record
	if event == "CHAT_MSG_ADDON" then
		-- Add-on traffic has a distinct argument layout, so do not feed it through
		-- player-chat filters or SpamControl. NormalizeAddon safely separates the
		-- exact ALCver handshake (Sync) from human-visible add-on feedback (System).
		record = self:NormalizeAddon(...)
	elseif event == "UI_ERROR_MESSAGE" then
		-- UI errors do not travel through ChatFrame event filters.  Treating
		-- their argument layout as a chat line would both lose the text and let
		-- a chat filter incorrectly suppress an important local failure.
		record = self:NormalizeUIError(...)
	else
		-- Never replay every global ChatFrame filter here. Several established
		-- addons use stateful filters (for example ElvUI's throttle): native chat
		-- has already shown the event once, and a second call makes those filters
		-- believe this is a duplicate. That would silently black-hole normal
		-- channel/local traffic from Smart Dock. Our own SpamControl is queried
		-- directly instead, so its intentional blocks still apply to both native
		-- chat and this renderer without running third-party filters twice.
		local firewall = addon.SpamControl
		if firewall and type(firewall.ShouldBlockEngineEvent) == "function"
			and firewall:ShouldBlockEngineEvent(event, ...)
		then
			return
		end
		record = self:Normalize(event, ...)
	end
	if not record then
		return
	end
	self:TryDeliver(record)
end

function Engine:Initialize()
	if self.frame then
		return
	end

	clearRuntimeHistory(self)
	self.listeners = {}
	self.listenerErrors = {}
	self.capacity = HISTORY_DEFAULT_LINES_PER_SOURCE
	self.nextId = 1
	self.nextHistorySequence = 1
	self.compiledCustomViewRevision = nil
	self.compiledCustomViews = nil
	self:InvalidateSyncClassifier()
	self.frame = CreateFrame("Frame")
	self.frame:SetScript("OnEvent", function(_, event, ...)
		if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
			Engine:RefreshLocalCommandCapture()
			return
		end
		Engine:Capture(event, ...)
	end)
	self:ResetForProfile()
end

function Engine:SetEnabled(enabled)
	if not self.frame then
		return
	end

	local shouldEnable = enabled and true or false
	if self.enabled == shouldEnable then
		return
	end
	self.enabled = shouldEnable

	if shouldEnable then
		self:RefreshLocalCommandCapture()
		for index = 1, #chatEvents do
			pcall(self.frame.RegisterEvent, self.frame, chatEvents[index])
		end
		for index = 1, #localCommandRefreshEvents do
			pcall(self.frame.RegisterEvent, self.frame, localCommandRefreshEvents[index])
		end
	else
		self.localCommandCaptureViews = {}
		self.frame:UnregisterAllEvents()
	end
end
