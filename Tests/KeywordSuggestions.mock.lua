-- Focused no-client harness for the review-only keyword suggestion engine.
-- Run from the addon root with: lua Tests/KeywordSuggestions.mock.lua

ChattyChattyBangBang = {
	db = { profile = { smartChat = {} } },
	MessageEngine = {
		listeners = {},
		RegisterListener = function(self, name, callback)
			self.listeners[name] = callback
		end,
	},
}

dofile("Core/Settings.lua")
dofile("Core/KeywordSuggestions.lua")

local addon = ChattyChattyBangBang
local engine = addon.KeywordSuggestions
engine:Initialize()
assert(addon.MessageEngine.listeners.keywordSuggestions, "suggestion listener was not registered")
assert(addon:GetKeywordSuggestionSettings().threshold == 5, "default suggestion threshold must be conservative")

local function record(text, sender, tick)
	return {
		event = "CHAT_MSG_CHANNEL",
		text = text,
		sender = sender,
		time = tick,
		epoch = 1000 + tick,
		sourceLabel = "Trade",
	}
end

-- Five distinct delivered messages from two senders offer one unknown game
-- noun. M-level terms remain known and never become candidates themselves.
for tick = 1, 5 do
	engine:Observe(record("Frostforge M" .. tick, tick % 2 == 0 and "Beta" or "Alpha", tick))
end
local suggestions = addon:GetKeywordSuggestions()
assert(#suggestions == 1 and suggestions[1].id == "frostforge", "repeated unknown term was not offered")
assert(suggestions[1].count == 5 and suggestions[1].source == "Trade", "suggestion report lost count/source")

assert(addon:AddKeywordSuggestionToGroup("frostforge", "dungeons"), "accepting suggestion into a group failed")
assert(#addon:GetKeywordSuggestions() == 0, "accepted suggestion remained queued")
local dungeons = addon:GetKeywordColorGroup("dungeons")
local containsFrostforge = false
for _, termSpec in ipairs(dungeons.terms) do
	local term = type(termSpec) == "table" and termSpec.term or termSpec
	if term == "frostforge" then containsFrostforge = true end
end
assert(containsFrostforge, "accepted suggestion was not added to its color group")

-- Repeated chatter from only one sender is not enough to create a review item.
for tick = 10, 14 do
	engine:Observe(record("Lonelystone M" .. tick, "Solo", tick))
end
assert(#addon:GetKeywordSuggestions() == 0, "single-sender repetition created a suggestion")

-- Link display text is explicitly ignored: suggestions should never learn item
-- names, spell links, or other markup labels from the chat renderer.
for tick = 20, 24 do
	engine:Observe(record("|Hitem:1|h[Linkedforge]|h M" .. tick, tick % 2 == 0 and "Beta" or "Alpha", tick))
end
assert(#addon:GetKeywordSuggestions() == 0, "link markup leaked a suggested term")

-- The bounded tracker must recover after expiry rather than reaching its cap
-- once and silently refusing to learn for the remainder of the session.
engine.tracked = {}
engine.trackedCount = 0
for index = 1, 120 do
	engine.tracked["expired" .. index] = { lastSeen = 1, messages = {} }
	engine.trackedCount = engine.trackedCount + 1
end
engine:PruneTracked(1000, 10)
assert(engine.trackedCount == 0, "expired tracker entries did not release capacity")
for tick = 30, 34 do
	engine:Observe(record("Capstone M" .. tick, tick % 2 == 0 and "Beta" or "Alpha", tick))
end
assert(addon:GetKeywordSuggestions()[1].id == "capstone", "tracker did not recover after capacity pruning")

assert(addon:DismissKeywordSuggestion("capstone"), "dismiss failed")
assert(#addon:GetKeywordSuggestions() == 0, "dismissed suggestion remained queued")

-- Expiry is a true rolling window: old messages and their sender contribution
-- leave the count while a term still has a fresh occurrence.
engine.tracked = {
	rollingstone = {
		count = 5,
		lastSeen = 100,
		messages = {
			oldA = { time = 1, sender = "alpha" }, oldB = { time = 2, sender = "alpha" },
			oldC = { time = 3, sender = "beta" }, oldD = { time = 4, sender = "beta" },
			fresh = { time = 100, sender = "beta" },
		},
		senderCounts = { alpha = 2, beta = 3 },
		distinctSenders = 2,
	},
}
engine.trackedCount = 1
engine:PruneTracked(100, 10)
local rolling = engine.tracked.rollingstone
assert(rolling and rolling.count == 1 and rolling.distinctSenders == 1, "rolling window retained expired message/sender counts")

-- Private and guild delivery is deliberately excluded before any sample can
-- enter the persisted report queue. Party/raid remains eligible group chat.
addon:ClearKeywordSuggestions()
for tick = 110, 114 do
	engine:Observe({ event = "CHAT_MSG_WHISPER", text = "Privateforge M" .. tick, sender = tick % 2 == 0 and "Beta" or "Alpha", time = tick, epoch = 2000 + tick })
	engine:Observe({ event = "CHAT_MSG_GUILD", text = "Guildforge M" .. tick, sender = tick % 2 == 0 and "Beta" or "Alpha", time = tick, epoch = 2000 + tick })
	engine:Observe({ event = "CHAT_MSG_BN_WHISPER", text = "BNetforge M" .. tick, sender = tick % 2 == 0 and "Beta" or "Alpha", time = tick, epoch = 2000 + tick })
end
assert(#addon:GetKeywordSuggestions() == 0, "private/guild chat leaked into persisted suggestions")

print("Keyword suggestion mock tests passed")
