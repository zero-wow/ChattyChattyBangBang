-- Focused no-client harness for explicit local diagnostics and UI error
-- routing. Run from the addon root with: lua Tests/MessageEngineFeedback.mock.lua

local now = 100
local received = {}
local nativeMessages = {}
local manualRouteOverride
unpack = unpack or table.unpack
local settings = {
	enabled = true,
	historyCapacity = 150,
	persistHistory = false,
	learnedSources = {},
	customViewRevision = 0,
	channelTargets = {},
}

ChattyChattyBangBang = {
	GetSmartSettings = function()
		return settings
	end,
	GetSmartViews = function()
		return {}
	end,
	IsRecordAllowedInView = function()
		return true
	end,
	Print = function()
		-- Listener failures are not part of this harness.
	end,
	GetMessageRouteOverride = function()
		return manualRouteOverride
	end,
}

GetTime = function()
	return now
end
time = function()
	return 1700000000 + math.floor(now)
end
date = function()
	return "12:00"
end
CreateFrame = function()
	return {
		SetScript = function(self, name, callback)
			self[name] = callback
		end,
		RegisterEvent = function()
			return true
		end,
		UnregisterAllEvents = function()
			return true
		end,
	}
end
DEFAULT_CHAT_FRAME = {
	AddMessage = function(_, text)
		table.insert(nativeMessages, text)
	end,
}

dofile("Core/MessageEngine.lua")

local engine = ChattyChattyBangBang.MessageEngine
engine:Initialize()
engine:SetEnabled(true)
engine:RegisterListener("feedback-test", function(record)
	table.insert(received, record)
end)

local routed, localRecord = ChattyChattyBangBang:DebugMessage("Clique invite: no mouseover or target")
assert(routed == true, "explicit local feedback did not enter Smart Chat")
assert(localRecord.event == "CCBB_LOCAL_MESSAGE" and localRecord.view == "system",
	"local feedback did not route to the System rail")
assert(localRecord.sourceId == "system:local-debug", "local feedback source is not independently configurable")
assert(#received == 1 and #nativeMessages == 0, "local feedback duplicated into native chat")
local systemRouted, systemRecord = ChattyChattyBangBang:SystemMessage("Quest helper: ready")
assert(systemRouted == true and systemRecord.event == "CCBB_LOCAL_MESSAGE" and #received == 2,
	"public SystemMessage bridge did not route local add-on output to System")

engine:Capture("UI_ERROR_MESSAGE", 1, "You are already in a group.")
assert(#received == 3, "two-argument UI_ERROR_MESSAGE was not captured")
assert(received[3].event == "UI_ERROR_MESSAGE" and received[3].view == "system",
	"UI error did not route to System")

-- Some client paths send the same failure to CHAT_MSG_SYSTEM. Keep one dock
-- line rather than displaying the duplicated feedback twice.
engine:Capture("CHAT_MSG_SYSTEM", "You are already in a group.")
assert(#received == 3, "paired UI/system feedback was duplicated")

now = now + 1
engine:Capture("UI_ERROR_MESSAGE", "Target is not in range.")
assert(#received == 4 and received[4].text == "Target is not in range.",
	"single-string UI_ERROR_MESSAGE layout was not captured")

-- A registered add-on prefix is not automatically synchronization traffic.
-- Human-readable payloads must remain visible in System; only the exact
-- ALCver VERSION handshake is quarantined in Sync.
engine:Capture("CHAT_MSG_ADDON", "Questie", "Objective updated", "PARTY", "QuestFriend")
assert(#received == 5 and received[5].view == "system"
	and received[5].sourceId == "system:addon-feedback"
	and received[5].text == "Questie: Objective updated",
	"ordinary add-on feedback did not route to System")
engine:Capture("CHAT_MSG_ADDON", "ALCver", "VERSION:1234", "GUILD", "SyncFriend")
assert(#received == 6 and received[6].view == "sync" and received[6].sourceId == "addon:alcver",
	"known ALCver protocol traffic was not kept in Sync")

-- Smart Dock must not replay arbitrary global ChatFrame filters. A stateful
-- external filter would see the native delivery and this capture as two lines
-- and incorrectly suppress the latter (ElvUI's throttle behaves this way).
local externalFilterCalls = 0
local firewallCalls = 0
ChatFrame_GetMessageEventFilters = function()
	return {
		function()
			externalFilterCalls = externalFilterCalls + 1
			return true
		end,
	}
end
ChattyChattyBangBang.SpamControl = {
	ShouldBlockEngineEvent = function(_, event)
		firewallCalls = firewallCalls + 1
		return false
	end,
}
engine:Capture(
	"CHAT_MSG_CHANNEL", "A regular channel line", "OtherPlayer", nil,
	"Trade", nil, nil, nil, 2, "Trade", nil, 99, "Player-1-OTHER", 0, 0
)
assert(#received == 7 and received[7].event == "CHAT_MSG_CHANNEL" and received[7].bnetAccountId == nil,
	"ordinary channel chat was not captured")
assert(externalFilterCalls == 0,
	"MessageEngine replayed a third-party ChatFrame filter")
assert(firewallCalls == 1,
	"MessageEngine did not query its dedicated SpamControl bridge")

-- Recruitment traffic appears in General/Ascension and Trade as often as it
-- does in an explicitly named LFG channel.  Strong intent must reach LFG;
-- everyday requests for help and commercial Keystone sales must not.
local function channelRecord(text, channel, sender)
	return engine:Normalize(
		"CHAT_MSG_CHANNEL", text, sender == nil and "Recruiter" or sender, nil,
		channel, nil, nil, nil, 2, channel, nil, 100, "Player-1-RECRUITER", 0, 0
	)
end

-- These factual public sources get dedicated built-in views. Newcomers is a
-- fallback after focused LFG/Trade inference, while GuildRecruitment remains
-- source-authoritative even when its recruitment copy contains those words.
local newcomersConversation = channelRecord("Where is the class trainer?", "Newcomers")
assert(newcomersConversation.view == "newcomers"
	and newcomersConversation.sourceId == "channel:newcomers",
	"ordinary Newcomers channel conversation did not route to its built-in view")
local newcomersAnalysis = assert(engine:AnalyzeRecord(newcomersConversation))
assert(table.concat(newcomersAnalysis.reasons, " "):find("Newcomers channel fallback", 1, true)
	and table.concat(newcomersAnalysis.signals, " "):find("NEWCOMERS exact channel source", 1, true),
	"Newcomers analysis did not disclose its exact-source fallback")
assert(channelRecord("LF pumper DPS for M10", "Newcomers").view == "groupFinder",
	"strong LFG intent in Newcomers did not peel into Group Finder")
assert(channelRecord("WTS Keystone boost", "Newcomers").view == "trade",
	"strong Trade intent in Newcomers did not peel into Trade")
assert(channelRecord("selling [Arcane Crystal]", "Newcomers").view == "trade",
	"transaction-shaped Trade intent in Newcomers did not peel into Trade")

local guildInvite = channelRecord("Friendly social guild recruiting all players", "GuildRecruitment")
assert(guildInvite.view == "guildInvites"
	and guildInvite.sourceId == "channel:guildrecruitment",
	"GuildRecruitment did not route to the built-in Guild Invites view")
assert(channelRecord("LFM tank DPS for [Keystone: Test] - WTS carries", "GuildRecruitment").view == "guildInvites",
	"LFG/Trade language overrode the authoritative GuildRecruitment source")
assert(channelRecord("Selling [Arcane Crystal] for 5g each, PST", "GuildRecruitment").view == "guildInvites",
	"transaction-shaped Trade evidence overrode the authoritative GuildRecruitment source")
local guildInviteAnalysis = assert(engine:AnalyzeRecord(guildInvite))
assert(table.concat(guildInviteAnalysis.reasons, " "):find("Exact GuildRecruitment channel source route", 1, true)
	and table.concat(guildInviteAnalysis.signals, " "):find("GUILD INVITES exact GuildRecruitment source", 1, true),
	"Guild Invites analysis did not disclose its authoritative source route")
assert(settings.channelTargets.newcomers == 2 and settings.channelTargets.guildInvites == 2,
	"built-in source views did not retain their observed composer channel targets")

local ordinaryGuildChat = engine:Normalize("CHAT_MSG_GUILD", "Hello guild", "Guildmate")
assert(ordinaryGuildChat.view == "guild" and ordinaryGuildChat.sourceId == "guild:guild",
	"ordinary guild chat was confused with the public GuildRecruitment source")

local keystoneRecruiting = channelRecord("[Keystone: Dire Maul East (11)] NEED 2 DPS", "Ascension")
assert(keystoneRecruiting.view == "groupFinder" and keystoneRecruiting.tags["intent:recruiting"],
	"Keystone role recruitment in Ascension did not route to LFG")

-- A linked activity followed only by requested roles is common Ascension LFG
-- shorthand.  The dungeon, level, player prefix, role order, and whitespace
-- are not stable, so route the semantic combination rather than exact text.
local linkedRoleFixtures = {
	"[Keystone: Shadowfang Keep - Arugal's Rise (9)] tank heal",
	"[Keystone: Shadowfang Keep - Arugal's Rise (9)] dps heal",
	"[Keystone: Shadowfang Keep - Arugal's Rise (9)] heal",
	"[Keystone: Uldaman (24)] 1 tank",
	"[Keystone: Uldaman (24)] 2tanks / 1x healer",
	"dps [Keystone: The Nexus (99)]",
	"[  Keystone : Unknown Depths (42)]\n   2   dps",
	"[Dungeon: An Arbitrary Future Instance (7)] healer",
	"|cffffff00|Hkeystone:123:77|h[Keystone: Markup Cavern (77)]|h|r tank / dps",
}
for index = 1, #linkedRoleFixtures do
	local record = channelRecord(linkedRoleFixtures[index], "Ascension")
	assert(record.view == "groupFinder" and record.tags["intent:recruiting"],
		"linked activity role fixture " .. tostring(index) .. " did not route to LFG")
	local analysis = assert(engine:AnalyzeRecord(record))
	assert(analysis.semantic.scores.groupFinder >= analysis.semantic.threshold.groupFinder
		and table.concat(analysis.semantic.signals.groupFinder, " "):find("linked activity + requested role", 1, true),
		"linked activity role fixture " .. tostring(index) .. " did not explain its synergy evidence")
end
assert(channelRecord("[Keystone: Uldaman (24)] is a fun route", "Ascension").view == "general",
	"a linked Keystone without requested roles was incorrectly routed to LFG")
assert(channelRecord("My tank finally got a Keystone today", "Ascension").view == "general",
	"unlinked conversational Keystone text was incorrectly routed to LFG")
assert(channelRecord("[Keystone: Uldaman (24)] what tank spec should I play?", "Ascension").view == "general",
	"linked conversational role text was incorrectly treated as a role request")
assert(channelRecord("selling [Keystone: Uldaman (24)] tank spot", "Trade - City").view == "trade",
	"sub-threshold commercial wording was incorrectly promoted to Group Finder")
assert(channelRecord("[Keystone: Uldaman (24)] tank boost", "Ascension").view ~= "groupFinder",
	"a low-score commercial role mention received the linked-role shorthand bonus")
assert(channelRecord("WTS [Keystone: Uldaman (24)] tank boost", "Ascension").view == "trade",
	"commercial wording did not keep a linked Keystone role advertisement in Trade")
local pumperRecruiting = channelRecord("LF pumper DPS for M10", "General - Stormwind City")
assert(pumperRecruiting.view == "groupFinder" and pumperRecruiting.tags["role:dps"],
	"LF pumper DPS in General did not route to LFG")
local pumperAnalysis = assert(engine:AnalyzeRecord(pumperRecruiting), "LFG route inspector returned no analysis")
assert(pumperAnalysis.category == "groupFinder" and pumperAnalysis.view == "groupFinder",
	"route inspector did not report the stored LFG destination")
assert(table.concat(pumperAnalysis.signals, " "):find("LFG intent", 1, true)
	and table.concat(pumperAnalysis.signals, " "):find("Group role", 1, true),
	"route inspector did not disclose the matched LFG signals")
assert(pumperAnalysis.semantic and pumperAnalysis.semantic.scores.groupFinder >= pumperAnalysis.semantic.threshold.groupFinder
	and table.concat(pumperAnalysis.semantic.signals.groupFinder, " "):find("LF", 1, true),
	"route inspector did not expose Group Finder score evidence")
assert(pumperRecruiting.view == "groupFinder" and pumperRecruiting.tags["role:dps"],
	"route inspector mutated the captured record")
manualRouteOverride = "general"
local manuallyCorrected = channelRecord("LF tank [Keystone: Test]", "Ascension")
assert(manuallyCorrected.view == "general" and manuallyCorrected.routeOverrideCategory == "general",
	"exact public route override did not take priority over the heuristic")
local overrideAnalysis = assert(engine:AnalyzeRecord(manuallyCorrected))
assert(overrideAnalysis.routeOverrideCategory == "general"
	and table.concat(overrideAnalysis.reasons, " "):find("Exact public%-channel route override"),
	"route inspector did not disclose the exact manual override")
manualRouteOverride = nil
assert(channelRecord("Ranger 36 LF RDF", "Ascension").view == "groupFinder",
	"LF RDF in Ascension did not route to LFG")
local dungeonRecruiting = ChattyChattyBangBang:AnalyzeSemanticRoute("LF tank for Blackrock Depths")
assert(dungeonRecruiting.category == "groupFinder"
	and dungeonRecruiting.scores.groupFinder >= dungeonRecruiting.threshold.groupFinder
	and table.concat(dungeonRecruiting.signals.groupFinder, " "):find("dungeon reference", 1, true),
	"LF plus dungeon evidence did not reach Group Finder")

-- Configuration consumes a compact read-only catalog rather than carrying a
-- second copy of MessageEngine's built-in vocabulary and thresholds.
local semanticCatalog = ChattyChattyBangBang:GetSemanticRouteCatalog()
assert(#semanticCatalog == 3
	and semanticCatalog[1].id == "groupFinder" and semanticCatalog[1].label == "Group Finder"
	and semanticCatalog[2].id == "trade" and semanticCatalog[2].label == "Trade"
	and semanticCatalog[3].id == "pvp" and semanticCatalog[3].label == "PVP",
	"semantic route catalog order or stable route identity changed")
assert(semanticCatalog[1].threshold == dungeonRecruiting.threshold.groupFinder
	and semanticCatalog[2].threshold == dungeonRecruiting.threshold.trade
	and semanticCatalog[3].threshold == dungeonRecruiting.threshold.pvp,
	"semantic route catalog thresholds drifted from live analysis")
assert(semanticCatalog[1].enabled == true and semanticCatalog[2].enabled == true
	and semanticCatalog[3].enabled == true,
	"semantic route catalog did not use the classifier's default enabled state")
assert(type(semanticCatalog[1].explanation) == "string" and semanticCatalog[1].explanation ~= ""
	and type(semanticCatalog[1].categories) == "table" and #semanticCatalog[1].categories > 0
	and type(semanticCatalog[1].categories[1].terms) == "table" and #semanticCatalog[1].categories[1].terms > 0,
	"semantic route catalog omitted its explanation or evidence groups")
assert(semanticCatalog[1].explanation:find("routes here directly", 1, true)
	and semanticCatalog[2].explanation:find("fallback home", 1, true)
	and semanticCatalog[2].explanation:find("peel", 1, true)
	and semanticCatalog[3].explanation:find("route here directly", 1, true),
	"semantic route catalog did not explain direct versus topic-based routing")
local lfgCatalogPoints = {}
for _, category in ipairs(semanticCatalog[1].categories) do
	lfgCatalogPoints[category.id] = category.points
end
assert(lfgCatalogPoints.lfm == 8 and lfgCatalogPoints.lfg == 7
	and lfgCatalogPoints["lf-count-role"] == 8 and lfgCatalogPoints.lf == 4
	and lfgCatalogPoints["group-phrases"] == 8 and lfgCatalogPoints["requested-role"] == 3
	and lfgCatalogPoints.need == 2 and lfgCatalogPoints.more == 1
	and lfgCatalogPoints.keystone == 3 and lfgCatalogPoints["activity-context"] == 3
	and lfgCatalogPoints["dungeon-reference"] == 3 and lfgCatalogPoints["activity-links"] == 1
	and lfgCatalogPoints["commercial-counterevidence"] == -9,
	"Group Finder catalog did not expose the classifier's exact signal scores")
local tradeCatalogPoints = {}
for _, category in ipairs(semanticCatalog[2].categories) do
	tradeCatalogPoints[category.id] = category.points
end
assert(tradeCatalogPoints["trade-shorthand"] == 9 and tradeCatalogPoints["buy-sell"] == 6
	and tradeCatalogPoints["transaction-context"] == 1 and tradeCatalogPoints["commercial-services"] == 4,
	"Trade catalog did not expose the classifier's exact signal scores")
local pvpCatalogPoints = {}
for _, category in ipairs(semanticCatalog[3].categories) do
	pvpCatalogPoints[category.id] = category.points
end
assert(pvpCatalogPoints["explicit-context"] == 4 and pvpCatalogPoints["named-activity"] == 5
	and pvpCatalogPoints["arena-bracket"] == 6 and pvpCatalogPoints.queue == 3
	and pvpCatalogPoints.team == 3 and pvpCatalogPoints.objective == 5
	and pvpCatalogPoints["tactical-call"] == 3 and pvpCatalogPoints["pvp-role"] == 2
	and pvpCatalogPoints.rating == 3 and pvpCatalogPoints.recruitment == 2
	and pvpCatalogPoints["pve-counterevidence"] == -6
	and pvpCatalogPoints["commercial-counterevidence"] == -9,
	"PVP catalog did not expose the classifier's exact signal scores")
local originalCatalogTerm = semanticCatalog[1].categories[1].terms[1]
semanticCatalog[1].categories[1].terms[1] = "caller mutation"
assert(ChattyChattyBangBang:GetSemanticRouteCatalog()[1].categories[1].terms[1] == originalCatalogTerm,
	"semantic route catalog exposed mutable classifier definitions")
ChattyChattyBangBang.GetSemanticRouteEnabled = function(_, routeId)
	return routeId ~= "trade"
end
local catalogWithTradeOff = ChattyChattyBangBang:GetSemanticRouteCatalog()
assert(catalogWithTradeOff[1].enabled == true and catalogWithTradeOff[2].enabled == false
	and catalogWithTradeOff[3].enabled == true,
	"semantic route catalog did not read the live enabled state")
ChattyChattyBangBang.GetSemanticRouteEnabled = nil

assert(ChattyChattyBangBang:AnalyzeSemanticRoute("Keystone discussion").category == "general",
	"Keystone alone was incorrectly treated as a group advertisement")
assert(ChattyChattyBangBang:AnalyzeSemanticRoute("WTS Keystone boost").category == "trade",
	"commercial wording did not outweigh incidental Keystone language")

-- BUYING/SELLING alone remains deliberately one point short. A structurally
-- transactional ad, supported market link, amount, or CTA closes that 6/7 gap
-- without teaching conversational idioms or service-only prose to route Trade.
local transactionTradeFixtures = {
	"selling [Arcane Crystal]",
	"  SELLING\n[Keystone: Uldaman (24)] tank spot  ",
	"now buying |cffa335ee|Hitem:123|h[Ancient Sword]|h|r",
	"I'm buying ore for 5g each, PST",
	"not buying |Hitem:123|h[Ancient Sword]|h for 20g",
}
for index = 1, #transactionTradeFixtures do
	local record = channelRecord(transactionTradeFixtures[index], "Ascension")
	assert(record.view == "trade",
		"transaction Trade fixture " .. tostring(index) .. " did not route to Trade")
	local analysis = assert(engine:AnalyzeRecord(record))
	assert(analysis.semantic.scores.trade >= analysis.semantic.threshold.trade
		and table.concat(analysis.semantic.signals.trade, " "):find("buy/sell transaction context", 1, true),
		"transaction Trade fixture " .. tostring(index) .. " did not explain its context evidence")
end

local conversationalTradeFixtures = {
	"I'm buying that idea",
	"Buying that idea",
	"I'm not buying this argument",
	"Selling people on this tank build",
	"The vendor is selling potions",
	"Crafting is fun",
	"Can someone make a portal?",
}
for index = 1, #conversationalTradeFixtures do
	local record = channelRecord(conversationalTradeFixtures[index], "Ascension")
	assert(record.view == "general",
		"conversational Trade fixture " .. tostring(index) .. " left General")
	local analysis = assert(engine:AnalyzeRecord(record))
	assert(not table.concat(analysis.semantic.signals.trade, " "):find("buy/sell transaction context", 1, true),
		"conversational Trade fixture " .. tostring(index) .. " received transaction context")
end

local tradeRecruiting = channelRecord("LFM need healer for Keystone: Blackfathom Deeps", "Trade - City")
assert(tradeRecruiting.view == "groupFinder",
	"clear recruitment in Trade did not take priority over its channel name")
assert(channelRecord("I need help with this quest", "General").view == "general",
	"ordinary request for help was incorrectly routed to LFG")
assert(channelRecord("WTS Keystone boost", "General").view == "trade",
	"commercial Keystone sale was incorrectly routed to LFG")

-- PVP inference requires corroborating evidence. Strong arena brackets,
-- battleground queues, and objective calls route automatically, while one
-- ambiguous word, dungeon queues, and commercial carries keep their existing
-- destinations.
local pvpFixtures = {
	"LFM healer for 2v2 arena team",
	"queue WSG premade",
	"LF healer 3s",
	"EFC incoming tunnel",
	"need FC and healer",
}
for index = 1, #pvpFixtures do
	local record = channelRecord(pvpFixtures[index], "Ascension")
	assert(record.view == "pvp" and record.tags and record.tags["intent:pvp"],
		"PVP fixture " .. tostring(index) .. " did not route to PVP")
	local analysis = assert(engine:AnalyzeRecord(record))
	assert(analysis.semantic.scores.pvp >= analysis.semantic.threshold.pvp
		and #analysis.semantic.signals.pvp >= 2,
		"PVP fixture " .. tostring(index) .. " did not expose corroborating score evidence")
end
assert(channelRecord("Arena is fun tonight", "Ascension").view == "general",
	"one ambiguous PVP context word stole ordinary conversation")
assert(channelRecord("I'll be ready in 2s", "Ascension").view == "general",
	"arena bracket shorthand routed an ordinary time expression without corroboration")
local dungeonQueue = channelRecord("our team need healer for dungeon queue", "Ascension")
assert(dungeonQueue.view == "groupFinder",
	"ambiguous queue/team wording routed a dungeon recruitment message to " .. tostring(dungeonQueue.view))
assert(channelRecord("queue for RDF need healer", "Ascension").view == "groupFinder",
	"PVP inference stole an RDF recruitment message")
assert(channelRecord("WTS arena boost for 20g", "Ascension").view == "trade",
	"PVP inference stole a commercial arena carry")
assert(channelRecord("our team killed the raid boss", "Ascension").view == "general",
	"PVP inference stole generic raid combat conversation")
assert(channelRecord("the defense rating of this tank is great", "Ascension").view == "general",
	"PVP inference stole generic defense/build conversation")

-- When more than one optional classifier qualifies, the largest margin above
-- that route's own threshold wins. Merely checking PVP first would incorrectly
-- steal this dungeon recruitment line because it also mentions WSG.
local mixedSemantic = channelRecord("LF tank/dps [Keystone: Test] WSG", "Ascension")
local mixedAnalysis = assert(engine:AnalyzeRecord(mixedSemantic))
assert(mixedSemantic.view == "groupFinder"
	and mixedAnalysis.semantic.scores.groupFinder - mixedAnalysis.semantic.threshold.groupFinder
		> mixedAnalysis.semantic.scores.pvp - mixedAnalysis.semantic.threshold.pvp
	and mixedAnalysis.semantic.semanticWinner.id == "groupFinder",
	"semantic arbitration did not choose the strongest threshold margin")

-- Purpose-built public sources remain authoritative above optional inference.
assert(channelRecord("LFM healer for 2v2 arena team", "LookingForGroup").view == "groupFinder",
	"PVP inference overrode the direct LookingForGroup channel route")
assert(channelRecord("LFM healer for 2v2 arena team", "GuildRecruitment").view == "guildInvites",
	"PVP inference overrode the direct GuildRecruitment channel route")
for _, defenseChannel in ipairs({ "Defense - Elwynn Forest", "LocalDefense", "WorldDefense" }) do
	local record = channelRecord("Enemy activity reported", defenseChannel)
	assert(record.view == "pvp", defenseChannel .. " did not route directly to PVP")
	local analysis = assert(engine:AnalyzeRecord(record))
	assert(analysis.semantic.isDefenseChannel
		and table.concat(analysis.reasons, " "):find("Defense%-family channel source route to PVP"),
		defenseChannel .. " did not explain its direct PVP source route")
end

manualRouteOverride = "general"
assert(channelRecord("queue WSG premade", "Ascension").view == "general",
	"manual route correction did not take priority over PVP inference")
manualRouteOverride = nil

ChattyChattyBangBang.GetSemanticRouteEnabled = function(_, routeId)
	return routeId ~= "pvp"
end
assert(channelRecord("queue WSG premade", "Ascension").view == "general",
	"disabling optional PVP inference did not keep inferred chat in General")
assert(channelRecord("Enemy activity reported", "LocalDefense").view == "pvp",
	"disabling PVP inference incorrectly disabled its direct Defense source route")
ChattyChattyBangBang.GetSemanticRouteEnabled = nil

-- Ascension can relay a realm zone-defense alert through an ordinary channel.
-- Its exact wording must receive the PVP route and distinct source before
-- semantic scoring, while a merely similar sentence remains ordinary chat.
local relayedUnderAttack = channelRecord("|cffffff00The Crossroads is under attack!|r", "Ascension", "")
assert(relayedUnderAttack.view == "pvp"
	and relayedUnderAttack.sourceId == "system:under-attack",
	"channel-relayed zone under attack notice was not routed to PVP")
local relayedUnderAttackAnalysis = assert(engine:AnalyzeRecord(relayedUnderAttack))
assert(table.concat(relayedUnderAttackAnalysis.signals, " "):find("PVP exact zone%-defense notice")
	and table.concat(relayedUnderAttackAnalysis.reasons, " "):find("zone%-defense notice route to PVP before semantic inference"),
	"channel-relayed zone under attack analysis did not disclose its PVP route")
assert(channelRecord("This is under attacker's planned strategy", "Ascension").view == "general",
	"ordinary conversation was incorrectly classified as a zone defense notice")
assert(channelRecord("Our guild is under attack!", "Ascension").view == "general",
	"player-authored attack conversation was incorrectly classified as a zone defense notice")
assert(channelRecord("My base is under attack right now", "Ascension").view == "general",
	"non-client attack wording was incorrectly classified as a zone defense notice")

-- Party, raid, and instance traffic belongs to Group. Battleground chat and
-- battleground system notices are factual PVP sources on the PVP rail.
engine:Capture("CHAT_MSG_PARTY", "Ready when you are.", "PartyPlayer")
assert(#received == 8 and received[8].view == "group" and received[8].sourceId == "group:party",
	"party chat did not route to the Group rail")
local battlegroundChat = engine:Normalize("CHAT_MSG_BATTLEGROUND", "Incoming at stables", "PvpPlayer")
assert(battlegroundChat.view == "pvp" and battlegroundChat.sourceId == "group:battleground"
	and battlegroundChat.sourceGroup == "pvp",
	"native battleground chat did not route directly to PVP")
local battlegroundNotice = engine:Normalize("CHAT_MSG_BG_SYSTEM_NEUTRAL", "The battle begins!")
assert(battlegroundNotice.view == "pvp" and battlegroundNotice.sourceId == "system:battleground"
	and battlegroundNotice.sourceGroup == "pvp",
	"native battleground notice did not route directly to PVP")
local restoredBattleground = {
	event = "CHAT_MSG_BATTLEGROUND", text = "Old saved battleground line",
	normalized = "old saved battleground line", sourceId = "group:battleground",
	sourceGroup = "group", sourceLabel = "Battleground chat",
}
engine:Classify(restoredBattleground)
assert(restoredBattleground.view == "pvp" and restoredBattleground.sourceId == "group:battleground"
	and restoredBattleground.sourceGroup == "pvp",
	"restored battleground history did not retain its source ID while migrating to PVP")

-- Zone-defense notices are supplied by their own client event, not guessed
-- from player text.  They stay in PVP by default and expose a dedicated
-- source toggle so they can be moved/hidden without affecting all system chat.
engine:Capture("CHAT_MSG_ZONE_UNDER_ATTACK", "The Crossroads is under attack!")
assert(#received == 9 and received[9].view == "pvp"
	and received[9].sourceId == "system:under-attack"
	and received[9].sourceGroup == "pvp"
	and received[9].sourceLabel == "Zone under attack",
	"zone under attack notice was not routed as a configurable PVP source")
local foundUnderAttackSource = false
for _, definition in ipairs(engine:GetSourceDefinitions()) do
	if definition.sourceId == "system:under-attack" then
		foundUnderAttackSource = definition.sourceGroup == "pvp"
			and definition.sourceLabel == "Zone under attack"
		break
	end
end
assert(foundUnderAttackSource, "zone under attack source is missing from Message Sources")

settings.enabled = false
local fallback, reason = ChattyChattyBangBang:DebugMessage("Clique invite: native fallback")
assert(fallback == false and reason == "native-fallback", "disabled Smart Chat did not use native fallback")
assert(#nativeMessages == 1, "native fallback did not write exactly one line")

print("MessageEngine feedback mock tests passed")
