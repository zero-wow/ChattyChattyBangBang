-- Run from the Retail addon root: lua Tests/RoutePatternRules.mock.lua

ChattyChattyBangBang = {}
dofile("Core/RoutePatternRules.lua")

local rules = assert(ChattyChattyBangBang.RoutePatternRules)

local function public(text, sourceId)
	return { event = "CHAT_MSG_CHANNEL", sourceId = sourceId or "channel:general", text = text }
end

local guildRule = {
	destination = "guildInvites",
	sourceId = "channel:general",
	include = { "[Guild:", "is a new guild" },
	exclude = { "pug tonight" },
}
local guildText = "[Guild: Baby Wipes] is a new guild, we're 8/8 normal venomous abyss "
	.. "and heroic tidebound. raid is saturday 7pm - 9pm pacific. "
	.. "lf healers and dps, hmu if interested"

local canonical = assert(rules:Validate(guildRule))
assert(canonical.destination == "guildInvites" and canonical.sourceId == "channel:general"
	and canonical.include[1] == "[guild:" and canonical.include[2] == "is a new guild",
	"rule validation did not preserve a reusable guild-intro condition")

local matched, preview = rules:Match(guildRule, public(guildText))
assert(matched and preview.matches and preview.reason == "matched"
	and preview.destination == "guildInvites", "screenshot guild advertisement did not match")
assert(preview.include[1].found and preview.include[2].found
	and preview.includePatterns[1] == "%[guild:"
	and preview.patternLanguage == "Lua patterns (escaped literal phrases)",
	"preview did not show escaped literal Lua-pattern anchors")
assert(#preview.matchedSpans == 2
	and string.find(preview.ignoredSpans[#preview.ignoredSpans].text,
		"lf healers and dps", 1, true),
	"role wording was not left outside the positive guild match")

local linked = "|cffffd100|Hguild:1234:5678|h[Guild: Baby Wipes]|h|r "
	.. "is a new guild. |TInterface\\Icons\\Spell_Holy_Heal:16|t LF healers and DPS"
local linkedPreview = assert(rules:Preview(guildRule, public(linked)))
assert(linkedPreview.matches and linkedPreview.visibleText ==
	"[guild: baby wipes] is a new guild. lf healers and dps",
	"WoW hyperlink payload, color, or texture markup leaked into matching text")
assert(rules:Match(guildRule, public("[Guild: Another Name] is a new guild. LF tanks")),
	"another guild name did not match the same selected intro")

local matchedOther, other = rules:Match(guildRule,
	public(guildText, "channel:lookingforgroup"))
assert(not matchedOther and other.reason == "source-mismatch",
	"exact source scope accepted another public channel")
local privateMatched, private = rules:Match(guildRule,
	{ event = "CHAT_MSG_GUILD", sourceId = "channel:general", text = guildText })
assert(not privateMatched and private.reason == "public-channel-only",
	"a private/direct chat event matched a public route rule")
assert(not rules:Match(guildRule, public("LFM healers and DPS for heroic raid tonight")),
	"ordinary group finding matched guild recruitment")
assert(not rules:Match(guildRule, public("My guild cleared heroic yesterday; LF healer for a PUG")),
	"a casual guild mention matched guild recruitment")
assert(not rules:Match(guildRule, public("LF guild for weekend raids, healer here")),
	"a player seeking a guild matched a guild advertisement")
local excluded, excludedPreview = rules:Match(guildRule,
	public("[Guild: Baby Wipes] is a new guild, pug tonight"))
assert(not excluded and excludedPreview.reason == "excluded"
	and excludedPreview.exclude[1].found,
	"excluded phrase did not veto an otherwise matching guild intro")

local literalRule = { destination = "trade", include = { "a.*" } }
local literalPreview = assert(rules:Preview(literalRule, public("this is ordinary chat")))
assert(not literalPreview.matches and literalPreview.includePatterns[1] == "a%.%*",
	"pattern operators were not treated as literal preview text")
assert(rules:Match(literalRule, public("literal a.* here")),
	"literal pattern-shaped phrase failed to match itself")

local invalidRules = {
	{ destination = "guild", include = { "new guild" } }, -- private destination
	{ destination = "guildInvites", include = {} },
	{ destination = "guildInvites", sourceId = "channel:general.*", include = { "new guild" } },
	{ destination = "guildInvites", include = { "new guild" }, exclude = { "NEW GUILD" } },
	{ destination = "guildInvites", include = { "ab" } },
	{ destination = "guildInvites", include = { string.rep("x", 97) } },
	{ destination = "guildInvites", include = { "one", "two", "three", "four", "five", "six", "seven" } },
}
for index = 1, #invalidRules do
	assert(rules:Validate(invalidRules[index]) == nil,
		"unsafe/invalid rule " .. index .. " passed validation")
end
assert(#assert(rules:ValidateSet({ guildRule })) == 1,
	"a small persisted rule list failed validation")
local oversized = {}
for index = 1, rules.MAX_RULES + 1 do oversized[index] = guildRule end
local noList, listReason = rules:ValidateSet(oversized)
assert(noList == nil and listReason == "too-many-rules",
	"persisted rule count was not bounded")

local malformed, reason = rules:Match(guildRule,
	public("|Hguild:new guild without closing label"))
assert(not malformed and reason == "malformed-hyperlink",
	"malformed hyperlink payload became matchable text")
local tooLong, tooLongReason = rules:Match(guildRule, public(string.rep("x", 4097)))
assert(not tooLong and tooLongReason == "text-too-long",
	"unbounded chat text was scanned")

print("Route pattern rule matcher tests passed")
