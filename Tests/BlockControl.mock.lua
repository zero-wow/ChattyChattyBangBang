-- Focused no-client harness for Message Blocks and UI-feedback coalescing.
-- Run from the addon root with: lua Tests/BlockControl.mock.lua

local now = 100
local received = {}
unpack = unpack or table.unpack

local settings = {
	enabled = true,
	historyCapacity = 150,
	persistHistory = false,
	learnedSources = {},
	customViewRevision = 0,
	channelTargets = {},
	blocks = {
		enabled = true,
		rules = {},
		sequence = 0,
		revision = 0,
		uiFeedback = {
			coalesce = true,
			window = 1.5,
		},
	},
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

dofile("Core/BlockControl.lua")
dofile("Core/MessageEngine.lua")

local blocks = ChattyChattyBangBang.BlockControl
local engine = ChattyChattyBangBang.MessageEngine
blocks:Initialize()
engine:Initialize()
engine:SetEnabled(true)
engine:RegisterListener("block-test", function(record)
	table.insert(received, record)
end)

-- First UI error remains visible; an identical quick repeat is coalesced, but
-- a distinct failure still makes it through immediately.
engine:Capture("UI_ERROR_MESSAGE", "Spell is not ready yet.")
assert(#received == 1, "first UI error should be visible")
now = now + 0.4
engine:Capture("UI_ERROR_MESSAGE", "Spell is not ready yet.")
assert(#received == 1, "identical UI error was not coalesced")
now = now + 0.1
engine:Capture("UI_ERROR_MESSAGE", "Ability is not ready yet.")
assert(#received == 2, "distinct UI error was incorrectly coalesced")
assert(ChattyChattyBangBang:GetBlockStats().uiCoalesced == 1,
	"coalescer stats did not record the suppressed repeat")

-- UI errors have no sender, so their quick-rule remains broad by player while
-- still being exact and scoped to this source/event.
local blockedRecord = received[2]
local quickBlock, rule = ChattyChattyBangBang:BlockRecord(blockedRecord)
assert(quickBlock and rule, "quick block action did not create a rule")
assert(rule.matchMode == "exact" and rule.allSources == false and rule.allEvents == false and rule.allSenders == true,
	"quick block was not narrowly scoped")
assert(#engine:GetMessages("system") == 1,
	"creating a rule did not immediately hide its existing matching line")
local archive = ChattyChattyBangBang:GetBlockedMessageArchive()
assert(#archive == 1 and archive[1].text == "Ability is not ready yet."
	and archive[1].reason == "rule" and archive[1].ruleId == rule.id,
	"quick block did not move the existing message to the archive")

now = now + 2
engine:Capture("UI_ERROR_MESSAGE", "Ability is not ready yet.")
assert(#received == 2, "manual block did not stop a later matching UI error")
assert(ChattyChattyBangBang:GetBlockStats().manual == 1,
	"manual block stats did not record the suppressed line")
archive = ChattyChattyBangBang:GetBlockedMessageArchive()
assert(#archive == 1 and archive[1].occurrences == 2,
	"later matching live blocks did not aggregate into the archive")

local description = assert(ChattyChattyBangBang:DescribeBlockRule(rule.id))
assert(string.find(description, "Exact", 1, true), "rule description lost its match mode")
assert(ChattyChattyBangBang:DeleteBlockRule(rule.id), "could not delete a quick block")
assert(#engine:GetMessages("system") == 1,
	"deleting a rule resurrected quarantined history")

-- General rules cover regular captured chat too, not only UI feedback.
local broad = assert(ChattyChattyBangBang:CreateBlockRule({
	name = "Hide test chatter",
	text = "test noise",
	matchMode = "contains",
	allSources = true,
	allEvents = true,
}))
now = now + 2
engine:Capture("CHAT_MSG_CHANNEL", "This is test noise from a channel.", "Tester", nil, "General", nil, nil, nil, 1, "General")
assert(#received == 2, "general message block did not stop regular chat")
assert(ChattyChattyBangBang:DeleteBlockRule(broad.id), "could not delete broad block")

-- Player-authored quick blocks are narrower than the legacy text/source/type
-- contract: they retain the sender's GUID and full name, so only that player
-- can be hidden by default.  A missing GUID on a later Ascension delivery
-- falls back to the saved full name, while a different realm-qualified player
-- with the same base name remains visible.
local playerText = "Player-targeted quick block"
now = now + 2
engine:Capture("CHAT_MSG_CHANNEL", playerText, "Target", nil, "Trade", nil, nil, nil, 2, "Trade", nil, 101, "Player-1-TARGET")
assert(#received == 3, "target player line did not reach the engine")
local playerRecord = received[#received]
local playerBlocked, playerRule = ChattyChattyBangBang:BlockRecord(playerRecord)
assert(playerBlocked and playerRule and playerRule.allSenders == false and playerRule.senderLabel == "Target",
	"player quick block did not retain a sender scope")
assert(playerRule.senderKeys["guid:player-1-target"] and playerRule.senderKeys["name:target"],
	"player quick block did not retain GUID and name identities")
assert(#engine:GetMessages() == 1, "player quick block did not immediately quarantine its existing line")

-- API callers may provide the identity keys directly.  Omitting allSenders is
-- intentionally interpreted as the safe, player-targeted scope rather than
-- accidentally broadening that rule during SavedVariables sanitation.
local inferredTargetRule = assert(ChattyChattyBangBang:CreateBlockRule({
	text = "Direct sender identity rule",
	matchMode = "exact",
	allSources = false,
	sources = { [playerRecord.sourceId] = true },
	allEvents = false,
	events = { [playerRecord.event] = true },
	senderKeys = { ["guid:player-1-direct"] = true, ["name:directtarget"] = true },
	senderLabel = "DirectTarget",
}))
assert(inferredTargetRule.allSenders == false and inferredTargetRule.senderKeys["name:directtarget"],
	"direct sender identity rule was widened during sanitation")
assert(ChattyChattyBangBang:DeleteBlockRule(inferredTargetRule.id), "could not delete direct sender identity rule")

now = now + 2
engine:Capture("CHAT_MSG_CHANNEL", playerText, "Target", nil, "Trade", nil, nil, nil, 2, "Trade", nil, 102)
assert(#received == 3, "GUID-less repeat from the same player escaped the quick block")
engine:Capture("CHAT_MSG_CHANNEL", playerText, "OtherPlayer", nil, "Trade", nil, nil, nil, 2, "Trade", nil, 103, "Player-1-OTHER")
assert(#received == 4, "quick block hid another player's identical message")
engine:Capture("CHAT_MSG_CHANNEL", playerText, "Target-OtherRealm", nil, "Trade", nil, nil, nil, 2, "Trade", nil, 104, "Player-1-TARGET-OTHER")
assert(#received == 5, "quick block collided with a different realm-qualified player")

local description = assert(ChattyChattyBangBang:DescribeBlockRule(playerRule.id))
assert(string.find(description, "player Target", 1, true), "player scope was not described clearly")
assert(ChattyChattyBangBang:SetBlockRuleAllSenders(playerRule.id, true), "player rule could not widen to any sender")
now = now + 2
engine:Capture("CHAT_MSG_CHANNEL", playerText, "ThirdPlayer", nil, "Trade", nil, nil, nil, 2, "Trade", nil, 105, "Player-1-THIRD")
assert(#received == 5, "widened player rule did not hide another sender")
assert(ChattyChattyBangBang:DeleteBlockRule(playerRule.id), "could not delete player quick block")

-- Explicit local diagnostics use the same gate. A block must not silently
-- fall back into DEFAULT_CHAT_FRAME after the dock rejects it.
local localRule = assert(ChattyChattyBangBang:CreateBlockRule({
	text = "Muted local feedback",
	matchMode = "exact",
	allSources = false,
	sources = { ["system:local-debug"] = true },
	allEvents = false,
	events = { CCBB_LOCAL_MESSAGE = true },
}))
local routed, reason = ChattyChattyBangBang:DebugMessage("Muted local feedback")
assert(routed == false and reason == "rule", "blocked local feedback escaped to native chat")
assert(ChattyChattyBangBang:DeleteBlockRule(localRule.id), "could not delete local block")

print("BlockControl mock tests passed")
