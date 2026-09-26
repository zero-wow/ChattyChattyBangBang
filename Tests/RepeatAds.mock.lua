-- Run from the addon root with: lua Tests/RepeatAds.mock.lua
-- Slow public adverts need a separate day-scale rule from rapid duplicates.
local now = 100
local filters = {}
local settings = {
	spam = {
		enabled = true,
		exemptSelf = true,
		duplicate = { enabled = false },
		burst = { enabled = false },
		escalation = { enabled = false, offenders = {}, bans = {} },
		scopes = { channel = true, ["local"] = false, guild = false,
			group = false, whisper = true, bnet = false },
		-- Omit repeatAds deliberately: its safe, default-on policy must work
		-- for a pre-feature SavedVariables profile too.
	},
}
ChattyChattyBangBang = { GetSmartSettings = function() return settings end }
GetTime = function() return now end
time = function() return 1700000000 + math.floor(now) end
UnitName = function() return "Tester", "Realm" end
UnitGUID = function() return "Player-1-TESTER" end
GetRealmName = function() return "Realm" end
ChatFrame_AddMessageEventFilter = function(event, callback) filters[event] = callback; return true end
ChatFrame_RemoveMessageEventFilter = function(event) filters[event] = nil; return true end

dofile("Core/SpamControl.lua")
local control = ChattyChattyBangBang.SpamControl
assert(control:Initialize(), "repeat-ad firewall did not initialize")

local line = 0
local function chat(event, message, sender, channel)
	line = line + 1
	return select(1, control:OnChatFilter({}, event, message, sender or "Seller-Realm",
		nil, channel or "General", nil, nil, nil, 1, channel or "General",
		nil, line, "Player-1-SELLER"))
end

local ad = "WTS: |cffffffff|Hitem:123|h[Shiny Sword]|h|r 50g PST"
local sameAd = "wts - [Shiny Sword], 50g; pst"
assert(chat("CHAT_MSG_CHANNEL", ad) == false, "first public advert should be visible")
now = now + 600
assert(chat("CHAT_MSG_CHANNEL", sameAd, nil, "Trade") == true,
	"case, markup, punctuation, or channel hopping reset the repeat-ad rule")
assert(control:GetStats().repeatAdsBlocked == 1, "repeat-ad statistics did not count the hidden copy")

-- A reply, a different seller, and private correspondence must not inherit
-- a public advert's presentation limit.
assert(chat("CHAT_MSG_CHANNEL", "Thanks, I'll check and get back to you") == false,
	"ordinary public conversation was caught as a sale advert")
assert(chat("CHAT_MSG_CHANNEL", "What does WTS mean in this channel, exactly?") == false,
	"a conversation mentioning the market abbreviation was treated as an advert")
assert(chat("CHAT_MSG_CHANNEL", "Selling points are not the same as prices") == false,
	"an ordinary selling-point sentence was treated as an advert")
assert(chat("CHAT_MSG_CHANNEL", sameAd, "OtherSeller-Realm") == false,
	"a different seller inherited somebody else's advert history")
assert(chat("CHAT_MSG_WHISPER", sameAd) == false,
	"public repeat-ad policy touched a whisper")
assert(chat("CHAT_MSG_CHANNEL", "WTS?") == false,
	"short conversational text was treated as a sale advert")

-- Item links plus an explicit gold price identify repeat listings even when
-- their surrounding words do not use English sale vocabulary.
local localizedAd = "Sprzedam |Hitem:123|h[Shiny Sword]|h za 50g, napisz do mnie"
now = now + 1
assert(chat("CHAT_MSG_CHANNEL", localizedAd, "LocaleSeller-Realm") == false,
	"first localized linked listing should be visible")
now = now + 600
assert(chat("CHAT_MSG_CHANNEL", localizedAd, "LocaleSeller-Realm") == true,
	"priced linked listing bypassed the repeat-ad rule without English wording")
local unpricedLink = "Look at |Hitem:124|h[Shiny Sword]|h, it is so cool"
now = now + 1
assert(chat("CHAT_MSG_CHANNEL", unpricedLink, "ChatSeller-Realm") == false)
now = now + 600
assert(chat("CHAT_MSG_CHANNEL", unpricedLink, "ChatSeller-Realm") == false,
	"ordinary repeated item-link chat was mistaken for a priced listing")
local unlinkedPrice = "My repair bill was exactly 50g today"
now = now + 1
assert(chat("CHAT_MSG_CHANNEL", unlinkedPrice, "ChatSeller-Realm") == false)
now = now + 600
assert(chat("CHAT_MSG_CHANNEL", unlinkedPrice, "ChatSeller-Realm") == false,
	"ordinary repeated price discussion was mistaken for a linked listing")

-- The same ad gets a little daylight, never a sender-wide mute or ban.
now = 100 + 3600
assert(chat("CHAT_MSG_CHANNEL", sameAd) == false, "one-hour follow-up was not allowed")
now = now + 3600
assert(chat("CHAT_MSG_CHANNEL", sameAd) == false, "third spaced advert was not allowed")
now = now + 3600
assert(chat("CHAT_MSG_CHANNEL", sameAd) == false, "fourth spaced advert was not allowed")
now = now + 3600
assert(chat("CHAT_MSG_CHANNEL", sameAd) == true, "fifth daily advert escaped the cap")
assert(chat("CHAT_MSG_CHANNEL", "WTS [Different Item] 75g PST") == false,
	"a distinct sale was wrongly suppressed with the first ad")
assert(control:GetStats().strikes == 0 and control:GetStats().automaticBans == 0,
	"slow-ad hiding created a sender-wide punishment")

-- Persist the small public fingerprint ledger through a fresh addon instance.
dofile("Core/SpamControl.lua")
control = ChattyChattyBangBang.SpamControl
assert(control:Initialize(), "repeat-ad ledger could not restore after reload")
now = now + 300
assert(chat("CHAT_MSG_CHANNEL", sameAd) == true,
	"reloading cleared the rolling-day advert limit")
settings.spam.repeatAds.enabled = false
control:RefreshSettings()
now = now + 20
assert(chat("CHAT_MSG_CHANNEL", sameAd) == false,
	"turning off repeat-ad protection still hid a public advert")
settings.spam.repeatAds.enabled = true
control:RefreshSettings()
now = now + 20
assert(chat("CHAT_MSG_CHANNEL", sameAd) == true,
	"turning repeat-ad protection back on lost its saved daily ledger")
now = 100 + 86400
assert(chat("CHAT_MSG_CHANNEL", sameAd) == false,
	"a new rolling day did not permit a new first copy")

-- Persistent map capacity is hard-bounded even when every seller posts a
-- different eligible advert. This also protects SavedVariables growth.
for index = 1, 530 do
	now = now + 1
	chat("CHAT_MSG_CHANNEL", "WTS item number " .. tostring(index) .. " for 50g PST", "Seller" .. index .. "-Realm")
end
local count = 0
for _ in pairs(settings.spam.repeatAds.seen) do count = count + 1 end
assert(count <= 512 and control:GetStats().trackedRepeatAds <= 512,
	"persistent repeat-ad fingerprints exceeded the hard limit")
print("Repeat-ad mock tests passed")
