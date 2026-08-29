-- Focused no-client coverage for the native Blizzard chat-color bridge.
-- Run from the addon root with: lua Tests/ChatColors.mock.lua

local colors = {
	SAY = { r = 0.8, g = 0.8, b = 0.8 },
	PARTY = { r = 0.4, g = 0.8, b = 1 },
	GUILD = { r = 0.2, g = 0.9, b = 0.4 },
	CHANNEL = { r = 0.7, g = 0.7, b = 0.7 },
	CHANNEL7 = { r = 0.9, g = 0.5, b = 0.1 },
	BATTLEGROUND = { r = 1, g = 0.5, b = 0.2 },
	BATTLEGROUND_LEADER = { r = 1, g = 0.6, b = 0.2 },
	BG_SYSTEM_NEUTRAL = { r = 1, g = 0.72, b = 0.1 },
	BG_SYSTEM_ALLIANCE = { r = 0.3, g = 0.5, b = 1 },
	BG_SYSTEM_HORDE = { r = 1, g = 0.25, b = 0.25 },
}

ChatTypeInfo = colors
function GetMessageTypeColor(id)
	local color = colors[id]
	return color and color.r, color and color.g, color and color.b
end
function ChangeChatColor(id, r, g, b)
	colors[id] = { r = r, g = g, b = b }
end
function GetChannelList()
	return 7, "Trade"
end
function GetChannelName(name)
	if name == "Trade" then
		return 7, "Trade"
	end
	return 0
end

ChattyChattyBangBang = {
	SmartDock = {
		RebuildActiveView = function(self)
			self.rebuilds = (self.rebuilds or 0) + 1
		end,
	},
}

dofile("Core/ChatColors.lua")
local addon = ChattyChattyBangBang

local definitions = addon:GetChatColorDefinitions()
local foundTrade, pvpDefinitionCount = false, 0
for _, definition in ipairs(definitions) do
	if definition.id == "channel:7" then
		foundTrade = definition.label == "TRADE" and definition.colorType == "CHANNEL7"
	end
	if definition.group == "PVP" then pvpDefinitionCount = pvpDefinitionCount + 1 end
end
assert(foundTrade, "active channel was not exposed as a native color definition")
assert(pvpDefinitionCount == 5, "battleground and defense colors were not grouped under PVP")

local partyR, partyG, partyB = addon:GetChatColorForRecord({ event = "CHAT_MSG_PARTY" })
assert(partyR == 0.4 and partyG == 0.8 and partyB == 1, "party source did not use Blizzard PARTY color")
local channelR, channelG, channelB = addon:GetChatColorForRecord({ event = "CHAT_MSG_CHANNEL", channel = "7. Trade", channelNumber = 3 })
assert(channelR == 0.9 and channelG == 0.5 and channelB == 0.1, "live channel-name lookup did not beat a stale stored slot")
local oldChannelR = addon:GetChatColorForRecord({ event = "CHAT_MSG_CHANNEL", channel = "Old Channel", channelNumber = 7 })
assert(oldChannelR == 0.7, "departed historical channel borrowed a live channel slot")
local defenseR, defenseG, defenseB = addon:GetChatColorForRecord({ event = "CHAT_MSG_ZONE_UNDER_ATTACK" })
assert(defenseR == 1 and defenseG == 0.72 and defenseB == 0.1,
	"zone-defense alert did not reuse the native PVP notice color")

assert(addon:SetChatColor("party", 0.1, 0.2, 0.3), "could not apply native party color")
assert(colors.PARTY.r == 0.1 and colors.PARTY.g == 0.2 and colors.PARTY.b == 0.3, "ChangeChatColor was not called")
assert(addon.SmartDock.rebuilds == 1, "dock history was not repainted after a color change")
assert(not addon:SetChatColor("missing", 1, 1, 1), "unknown color definition was accepted")

addon.Theme = {
	GetPalette = function()
		return {
			text = { 0.9, 0.9, 0.9, 1 },
			textMuted = { 0.5, 0.5, 0.5, 1 },
			accent = { 0.2, 0.5, 0.8, 1 },
			gold = { 0.9, 0.6, 0.2, 1 },
			goldBright = { 1, 0.8, 0.4, 1 },
			warning = { 1, 0.6, 0.2, 1 },
			success = { 0.3, 0.8, 0.5, 1 },
			danger = { 0.9, 0.3, 0.3, 1 },
			borderMuted = { 0.2, 0.3, 0.4, 1 },
		}
	end,
	GetColor = function(self, name)
		local color = self:GetPalette()[name] or self:GetPalette().text
		return color[1], color[2], color[3], color[4]
	end,
}
function addon:GetSmartSettings()
	return { keywordColors = {}, keywordColorGroups = {}, keywordColorRevision = 0, dock = {} }
end

function UnitName(unit)
	if unit == "target" then
		return "TargetName"
	elseif unit == "focus" then
		return "FocusName"
	end
end

-- The native resolver handles brace/group expressions; Presentation also
-- expands the client-standard unit substitutions in a percent-only line.
function ChatFrame_ReplaceIconAndGroupExpressions(text)
	return (text:gsub("{group1}", "Group One"))
end

dofile("Core/Presentation.lua")
assert(addon.Presentation:GetSource({ event = "CHAT_MSG_ZONE_UNDER_ATTACK", view = "pvp" }) == "DEFENSE",
	"zone-defense source label was not compact enough for the PVP rail")
local formatted = addon.Presentation:Format({
	id = 1,
	event = "CHAT_MSG_PARTY",
	view = "general",
	timestamp = "12:00",
	sender = "Tester",
	text = "hello",
})
assert(string.find(formatted, "|cff1a334dPARTY|r", 1, true), "non-channel source labels did not use the native party color")
assert(string.find(addon.Presentation:ColorizeMessage("Invite %t"), "TargetName", 1, true),
	"target substitution did not expand")
assert(string.find(addon.Presentation:ColorizeMessage("Focus %f"), "FocusName", 1, true),
	"focus substitution did not expand")
assert(string.find(addon.Presentation:ColorizeMessage("{group1}"), "Group One", 1, true),
	"brace native substitutions did not reach the client resolver")
assert(string.find(addon.Presentation:ColorizeMessage("literal %s"), "%s", 1, true),
	"Lua format placeholder was incorrectly invented as a chat substitution")

print("Chat color mock tests passed")
