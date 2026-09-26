-- Focused no-client coverage for default alerts and dynamic alert variables.
-- Run from the addon root with: lua Tests/Alerts.mock.lua

local currentPlayerName = "Stovos"
function UnitName(unit)
	return unit == "player" and currentPlayerName or nil
end
function UnitGUID(unit)
	return unit == "player" and "Player-Unit-Test" or nil
end
function GetTime()
	return 10
end

ChattyChattyBangBang = {
	db = { profile = { smartChat = {} } },
	MessageEngine = {
		RegisterListener = function(self, name, callback)
			self.listeners = self.listeners or {}
			self.listeners[name] = callback
		end,
	},
	SmartDock = {
		OnAlert = function(self, record, rule)
			self.alerts = (self.alerts or 0) + 1
			self.lastRule = rule.id
		end,
	},
}

dofile("Core/Settings.lua")
dofile("Core/Alerts.lua")

local addon = ChattyChattyBangBang
local rules = addon:GetAlertRules()
assert(#rules == 1, "new profile did not receive the default alert")
assert(rules[1].name == "YOUR NAME" and rules[1].terms[1] == "[PLAYER_NAME]", "default player-name alert is malformed")

local variables = addon:GetAlertVariables()
assert(#variables == 1 and variables[1].token == "[PLAYER_NAME]" and variables[1].value == "Stovos", "player-name variable is not exposed")

addon.AlertEngine:Initialize()
local matched = addon.AlertEngine:ProcessRecord({
	event = "CHAT_MSG_CHANNEL",
	sourceId = "channel:trade",
	sender = "OtherPlayer",
	guid = "Player-Other",
	direction = "incoming",
	normalized = "lf1 healer for stovos group",
	text = "LF1 healer for Stovos group",
})
assert(matched, "[PLAYER_NAME] did not resolve to the active player")
assert(addon.SmartDock.alerts == 1 and addon.SmartDock.lastRule == "alert1", "default rule did not reveal the dock")

-- Retail plays SoundKit IDs, not the old string sound name. If the sound call
-- fails, retain the file fallback instead of silently swallowing that error.
local playedKit, fallbackCount
SOUNDKIT = { RAID_WARNING = 12345 }
PlaySound = function(id) playedKit = id; return true end
PlaySoundFile = function() fallbackCount = (fallbackCount or 0) + 1; return true end
addon:GetSmartSettings().alerts.sound = true
assert(addon.AlertEngine:ProcessRecord({
	event = "CHAT_MSG_CHANNEL", sourceId = "channel:trade", sender = "AnotherPlayer",
	guid = "Player-Another", direction = "incoming", normalized = "stovos, hello",
	text = "Stovos, hello",
}), "sound test did not match the alert")
assert(playedKit == 12345 and not fallbackCount,
	"Retail alert did not use the numeric SoundKit ID")
PlaySound = function() error("sound unavailable") end
assert(addon.AlertEngine:ProcessRecord({
	event = "CHAT_MSG_CHANNEL", sourceId = "channel:trade", sender = "ThirdPlayer",
	guid = "Player-Third", direction = "incoming", normalized = "stovos again",
	text = "Stovos again",
}), "fallback sound test did not match the alert")
assert(fallbackCount == 1, "failed SoundKit playback did not try the file fallback")
SOUNDKIT, PlaySound, PlaySoundFile = nil, nil, nil

local skippedSelf = addon.AlertEngine:ProcessRecord({
	event = "CHAT_MSG_CHANNEL",
	sourceId = "channel:trade",
	sender = "Stovos",
	guid = "Player-Unit-Test",
	direction = "outgoing",
	normalized = "stovos",
	text = "Stovos",
})
assert(not skippedSelf, "self-authored messages should not trigger the default name alert")

local updated = addon:UpdateAlertRule("alert1", { terms = { "[PLAYER]" } })
assert(updated and updated.terms[1] == "[PLAYER_NAME]", "[PLAYER] alias was not canonicalized")
currentPlayerName = "Krynn"
addon.AlertEngine:ResetForProfile()
matched = addon.AlertEngine:ProcessRecord({
	event = "CHAT_MSG_GUILD",
	sourceId = "guild:guild",
	sender = "OtherPlayer",
	guid = "Player-Other",
	direction = "incoming",
	normalized = "krynn are you online?",
	text = "Krynn are you online?",
})
assert(matched, "variable did not follow the current character after an identity refresh")

print("Alert variable mock tests passed")
