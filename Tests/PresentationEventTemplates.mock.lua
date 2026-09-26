-- Run from the Retail addon root: lua Tests/PresentationEventTemplates.mock.lua

ChattyChattyBangBang = {}
local addon = ChattyChattyBangBang
addon.Theme = {
	GetPalette = function()
		return { text = { 1, 1, 1 }, textMuted = { 1, 1, 1 }, borderMuted = { 1, 1, 1 } }
	end,
	GetColor = function()
		return 1, 1, 1
	end,
}
addon.GetSmartSettings = function()
	return { keywordColorGroups = {}, keywordColors = {}, dock = {} }
end

dofile("Core/Presentation.lua")
local presentation = addon.Presentation

local savedGuildAchievement = {
	id = 1,
	event = "CHAT_MSG_GUILD_ACHIEVEMENT",
	sender = "Cindry-Hyjal",
	text = "%s has earned the achievement |cffffff00|Hachievement:10826|h[Mythic: Cenarius]|h|r!",
}
local original = savedGuildAchievement.text
assert(presentation:FormatEventText(savedGuildAchievement) ==
	"Cindry-Hyjal has earned the achievement |cffffff00|Hachievement:10826|h[Mythic: Cenarius]|h|r!",
	"saved guild-achievement template was not formatted using its event sender")
local _, rendered = presentation:FormatParts(savedGuildAchievement)
local renderedPlain = rendered:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
assert(string.find(renderedPlain, "Cindry-Hyjal has earned", 1, true),
	"historical achievement still showed a raw %s in the visible chat row")
assert(savedGuildAchievement.text == original, "presentation modified the historical raw record")

assert(presentation:FormatEventText({
	event = "CHAT_MSG_ACHIEVEMENT", sender = "Mira", text = "%1$s earned it (100%% complete)",
}) == "Mira earned it (100% complete)", "positional or escaped percent format failed")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_GUILD_ACHIEVEMENT", text = "%2$s earned %1$s at level %3$d",
	formatArgs = { "Hero", "Mira", 80 },
}) == "Mira earned Hero at level 80", "multiple typed positional arguments failed")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_ACHIEVEMENT", text = "%s reached %03d", formatArgs = { "Mira", 7 },
}) == "Mira reached 007", "sequential typed arguments failed")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_ACHIEVEMENT", text = "%2$s reached %s", formatArgs = { "Mira" },
}) == "%2$s reached Mira", "missing positional argument was guessed")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_ACHIEVEMENT", sender = "Mira", text = "%s has %t and 100% progress",
}) == "Mira has %t and 100% progress", "native substitution or literal percent was corrupted")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_GUILD_ITEM_LOOTED", sender = "Mira", text = "$s looted an item",
}) == "Mira looted an item", "guild-item event's native $s replacement failed")

_G.CHAT_IGNORED = "You are ignoring %s."
_G.CHAT_FILTERED = "Message from %s was filtered."
_G.CHAT_RESTRICTED_TRIAL = "Trial accounts cannot use this chat."
assert(presentation:FormatEventText({
	event = "CHAT_MSG_IGNORED", sender = "Mira", text = "IGNORED",
}) == "You are ignoring Mira.", "ignored status was left as an event marker")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_FILTERED", sender = "Mira", text = "FILTERED",
}) == "Message from Mira was filtered.", "filtered status was left as an event marker")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_RESTRICTED", text = "RESTRICTED",
}) == "Trial accounts cannot use this chat.", "restricted status did not use Blizzard's localized notice")
_G.CHAT_IGNORED = nil
_G.CHAT_FILTERED = nil
_G.CHAT_RESTRICTED_TRIAL = nil

_G.ChatFrameUtil = {
	GetOutMessageFormatKey = function(chatType)
		return chatType == "PING" and "Ping from %s: " or
			chatType == "CHANNEL_LIST" and "[%d. %s] " or nil
	end,
	ResolvePrefixedChannelName = function(channel)
		return channel == "Trade" and "Trade - City" or channel
	end,
}
assert(presentation:FormatEventText({
	event = "CHAT_MSG_PING", sender = "Mira", text = "Watch out!",
}) == "Ping from Mira: Watch out!", "ping notice omitted Blizzard's formatted sender prefix")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_CHANNEL_LIST", channel = "Trade", channelNumber = 2,
	text = "3 members: Mira, Sol",
}) == "[2. Trade - City] 3 members: Mira, Sol", "channel list omitted its localized prefix")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_CHANNEL_LIST", channel = "Trade", channelNumber = 2,
	text = "100% available: %s",
}) == "[2. Trade - City] 100% available: %s", "channel-list text was treated as a format template")
_G.CHAT_YOU_JOINED_NOTICE = "Joined %2$s (%1$d)."
_G.CHAT_INVITE_NOTICE = "Invited to %1$s by %2$s."
_G.CHAT_KICKED_NOTICE = "%3$s kicked %4$s from %2$s (%1$d)."
assert(presentation:FormatEventText({
	event = "CHAT_MSG_CHANNEL_NOTICE", channel = "Trade", channelNumber = 2,
	text = "YOU_JOINED",
}) == "Joined Trade - City (2).", "channel notice was left as a raw event marker")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_CHANNEL_NOTICE_USER", channel = "Trade", channelNumber = 2,
	sender = "Mira", text = "INVITE",
}) == "Invited to Trade - City by Mira.", "channel invite notice was left as a raw marker")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_CHANNEL_NOTICE_USER", channel = "Trade", channelNumber = 2,
	sender = "Mira", target = "Sol", text = "KICKED",
}) == "Mira kicked Sol from Trade - City (2).", "two-user channel notice used wrong arguments")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_CHANNEL_NOTICE", channel = "Trade", channelNumber = 2,
	text = "UNKNOWN_NOTICE",
}) == "UNKNOWN_NOTICE", "unknown channel notice invented a string")
_G.CHAT_YOU_JOINED_NOTICE = nil
_G.CHAT_INVITE_NOTICE = nil
_G.CHAT_KICKED_NOTICE = nil
_G.ChatFrameUtil = nil

_G.BN_INLINE_TOAST_FRIEND_REQUEST = "New friend request."
_G.BN_INLINE_TOAST_FRIEND_PENDING = "%d friend requests pending."
_G.BN_INLINE_TOAST_FRIEND_ONLINE = "%s is online."
_G.BN_INLINE_TOAST_FRIEND_REMOVED = "%s is no longer your friend."
_G.BNGetNumFriendInvites = function() return 3 end
assert(presentation:FormatEventText({
	event = "CHAT_MSG_BN_INLINE_TOAST_ALERT", text = "FRIEND_REQUEST",
}) == "New friend request.", "friend-request marker was shown raw")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_BN_INLINE_TOAST_ALERT", text = "FRIEND_PENDING",
}) == "3 friend requests pending.", "pending-friend marker omitted the count")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_BN_INLINE_TOAST_ALERT", sender = "Mira", text = "FRIEND_ONLINE",
}) == "Mira is online.", "friend-online marker omitted the sender")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_BN_INLINE_TOAST_ALERT", sender = "Mira", text = "FRIEND_REMOVED",
}) == "Mira is no longer your friend.", "friend-removed marker omitted the sender")
assert(presentation:FormatEventText({
	event = "CHAT_MSG_BN_INLINE_TOAST_ALERT", sender = "Mira", text = "SOME_OTHER_VALUE",
}) == "SOME_OTHER_VALUE", "unknown Battle.net marker invented a string")
_G.BN_INLINE_TOAST_FRIEND_REQUEST = nil
_G.BN_INLINE_TOAST_FRIEND_PENDING = nil
_G.BN_INLINE_TOAST_FRIEND_ONLINE = nil
_G.BN_INLINE_TOAST_FRIEND_REMOVED = nil
_G.BNGetNumFriendInvites = nil

for _, event in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_GUILD", "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT" }) do
	assert(presentation:FormatEventText({ event = event, sender = "Mira", text = "%s says 100%%" })
		== "%s says 100%%", event .. " was incorrectly treated as a printf template")
end

local oldCanAccess = _G.canaccessvalue
_G.canaccessvalue = function(value) return value ~= "secret" end
assert(presentation:FormatEventText({
	event = "CHAT_MSG_ACHIEVEMENT", sender = "secret", text = "%s has earned it",
}) == "%s has earned it", "inaccessible Retail payload was formatted")
_G.CHAT_IGNORED = "You are ignoring %s."
assert(presentation:FormatEventText({
	event = "CHAT_MSG_IGNORED", sender = "secret", text = "IGNORED",
}) == "IGNORED", "inaccessible Retail status sender was formatted")
_G.CHAT_IGNORED = nil
_G.BN_INLINE_TOAST_FRIEND_ONLINE = "%s is online."
assert(presentation:FormatEventText({
	event = "CHAT_MSG_BN_INLINE_TOAST_ALERT", sender = "secret", text = "FRIEND_ONLINE",
}) == "FRIEND_ONLINE", "inaccessible Battle.net sender was formatted")
_G.BN_INLINE_TOAST_FRIEND_ONLINE = nil
_G.canaccessvalue = oldCanAccess

print("Presentation event-template tests passed")
