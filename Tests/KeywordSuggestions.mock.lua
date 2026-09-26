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

-- Busy public chat should not sweep every tracked term on each line. The term
-- being observed still expires its own old occurrences before counting this
-- line, even between global sweeps.
addon:ClearKeywordSuggestions()
addon:GetSmartSettings().keywordSuggestions.window = 60
engine:ResetForProfile()
local originalPrune = engine.PruneTracked
local fullSweeps = 0
function engine:PruneTracked(...)
	fullSweeps = fullSweeps + 1
	return originalPrune(self, ...)
end
for tick = 1, 10 do
	engine:Observe(record("Windowforge M" .. tick, tick % 2 == 0 and "Beta" or "Alpha", tick))
end
assert(fullSweeps == 1, "keyword tracker still swept every term on every public line")
engine:Observe(record("Neutralforge M55", "Beta", 55))
local sweepsBefore = fullSweeps
engine:Observe(record("Windowforge M62", "Beta", 62))
assert(fullSweeps == sweepsBefore and engine.tracked.windowforge.count == 10,
	"observed term kept expired messages or forced an unnecessary global sweep")
engine.PruneTracked = originalPrune

-- Private and guild delivery is deliberately excluded before any sample can
-- enter the persisted report queue. Party/raid remains eligible group chat.
addon:ClearKeywordSuggestions()
for tick = 110, 114 do
	engine:Observe({ event = "CHAT_MSG_WHISPER", text = "Privateforge M" .. tick, sender = tick % 2 == 0 and "Beta" or "Alpha", time = tick, epoch = 2000 + tick })
	engine:Observe({ event = "CHAT_MSG_GUILD", text = "Guildforge M" .. tick, sender = tick % 2 == 0 and "Beta" or "Alpha", time = tick, epoch = 2000 + tick })
	engine:Observe({ event = "CHAT_MSG_BN_WHISPER", text = "BNetforge M" .. tick, sender = tick % 2 == 0 and "Beta" or "Alpha", time = tick, epoch = 2000 + tick })
end
assert(#addon:GetKeywordSuggestions() == 0, "private/guild chat leaked into persisted suggestions")

-- Lua 5.1's %a sees UTF-8 bytes as punctuation. Preserve complete common-
-- script words, fold simple Cyrillic/Latin-1 capitals, and reject symbols.
local function expectUnicodeSuggestion(word, expected, firstTick)
	addon:ClearKeywordSuggestions()
	for tick = firstTick, firstTick + 4 do
		engine:Observe(record(word .. " M" .. tick,
			tick % 2 == 0 and "Beta" or "Alpha", tick))
	end
	local found = addon:GetKeywordSuggestions()
	assert(#found == 1 and found[1].id == expected,
		"UTF-8 word was dropped, fragmented, or offered under the wrong key: " .. tostring(expected))
end

expectUnicodeSuggestion("Рейдовый", "рейдовый", 200)
expectUnicodeSuggestion("рейдовый", "рейдовый", 210)
expectUnicodeSuggestion("Überraschung", "überraschung", 220)
expectUnicodeSuggestion("副本", "副本", 230)
expectUnicodeSuggestion("던전", "던전", 240)
local decomposedCafe = "Cafe" .. string.char(0xCC, 0x81)
expectUnicodeSuggestion(decomposedCafe, "cafe" .. string.char(0xCC, 0x81), 235)
addon:ClearKeywordSuggestions()
for tick = 245, 249 do
	local word = tick % 2 == 0 and "Рейдовый" or "рейдовый"
	engine:Observe(record(word .. " M" .. tick,
		tick % 2 == 0 and "Beta" or "Alpha", tick))
end
local folded = addon:GetKeywordSuggestions()
assert(#folded == 1 and folded[1].id == "рейдовый" and folded[1].count == 5,
	"mixed Cyrillic case was split into separate suggestion counters")

addon:ClearKeywordSuggestions()
for tick = 250, 254 do
	engine:Observe(record("😀😀😀😀 M" .. tick,
		tick % 2 == 0 and "Beta" or "Alpha", tick))
	engine:Observe(record("Ab" .. string.char(0xD0) .. "cd M" .. tick,
		tick % 2 == 0 and "Beta" or "Alpha", tick + 10))
end
assert(#addon:GetKeywordSuggestions() == 0,
	"emoji or malformed UTF-8 became a candidate keyword")

addon:ClearKeywordSuggestions()
for tick = 270, 274 do
	engine:Observe(record(string.rep("副", 14) .. " M" .. tick,
		tick % 2 == 0 and "Beta" or "Alpha", tick))
end
assert(#addon:GetKeywordSuggestions() == 0 and engine.trackedCount == 0,
	"oversized UTF-8 token bypassed the bounded term limit")

-- Queue entries (including short chat samples) persist by default. In
-- session-only mode they remain usable now but never enter SavedVariables;
-- the in-memory counting ledger always disappears on a profile/reload reset.
addon:ClearKeywordSuggestionData()
local savedSuggestions = addon:GetSmartSettings().keywordSuggestions
assert(addon:GetKeywordSuggestionSettings().retainQueue == true,
	"existing profiles did not keep their original retained-queue behavior")
for tick = 300, 304 do
	engine:Observe(record("Keepforge M" .. tick, tick % 2 == 0 and "Beta" or "Alpha", tick))
end
assert(#savedSuggestions.queue == 1 and savedSuggestions.queue[1].sample ~= "",
	"default review queue and its sample were not saved in SavedVariables")
assert(addon:DismissKeywordSuggestion("keepforge"), "could not dismiss the retained candidate")
for tick = 310, 314 do
	engine:Observe(record("Temporaryforge M" .. tick, tick % 2 == 0 and "Beta" or "Alpha", tick))
end
assert(addon:SetKeywordSuggestionQueueRetention(false), "session-only queue choice failed")
assert(#savedSuggestions.queue == 0 and #addon:GetKeywordSuggestions() == 1,
	"session-only choice did not remove the stored queue while keeping this session's report")
assert(addon:GetKeywordSuggestionSettings().dismissedCount == 1,
	"session-only queue choice silently forgot dismissed terms")
engine:ResetForProfile()
assert(#addon:GetKeywordSuggestions() == 0 and savedSuggestions.dismissed.keepforge,
	"session-only queue survived reset or dismissed terms were lost")
for tick = 320, 324 do
	engine:Observe(record("Sessionforge M" .. tick, tick % 2 == 0 and "Beta" or "Alpha", tick))
end
assert(#savedSuggestions.queue == 0 and addon:GetKeywordSuggestions()[1].id == "sessionforge",
	"session-only observations leaked back into SavedVariables")
assert(addon:SetKeywordSuggestionQueueRetention(true), "return to retained queue failed")
assert(savedSuggestions.queue[1].id == "sessionforge",
	"return to retained queue did not save the current review item")
addon:ClearKeywordSuggestions()
assert(#savedSuggestions.queue == 0 and savedSuggestions.dismissed.keepforge,
	"CLEAR REVIEW QUEUE erased dismissal history or failed to clear the queue")
assert(addon:ClearKeywordSuggestionData(), "erase report data failed")
assert(next(savedSuggestions.dismissed) == nil and #savedSuggestions.queue == 0
	and engine.trackedCount == 0,
	"erase report data left queue, dismissals, or in-session observations behind")
local retainedGroup = addon:GetKeywordColorGroup("dungeons")
local stillColored = false
for _, termSpec in ipairs(retainedGroup.terms or {}) do
	if termSpec == "frostforge" then stillColored = true break end
end
assert(stillColored, "erasing suggestion data removed a user-accepted color-group word")

-- Old profiles with no retention field keep their saved queue. A profile that
-- explicitly chose session-only must not resurrect stale imported queue data.
savedSuggestions.retainQueue = nil
savedSuggestions.queue = { { id = "legacyforge", term = "legacyforge", count = 5 } }
assert(addon:GetKeywordSuggestionSettings().retainQueue == true
	and addon:GetKeywordSuggestions()[1].id == "legacyforge",
	"legacy queue was silently discarded during retention migration")
savedSuggestions.retainQueue = false
engine:ResetForProfile()
assert(#savedSuggestions.queue == 0 and #addon:GetKeywordSuggestions() == 0,
	"session-only profile restored old queued samples from SavedVariables")

print("Keyword suggestion mock tests passed")
