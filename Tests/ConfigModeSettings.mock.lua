-- Run from the addon root with: lua Tests/ConfigModeSettings.mock.lua
ChattyChattyBangBang = { db = { profile = { smartChat = {} } } }
dofile("Core/Settings.lua")
local addon = ChattyChattyBangBang

assert(addon:GetConfigMode() == "simple", "existing profiles must start in simple mode")
assert(addon:IsConfigSetupCompleted() == true,
	"an existing profile was mistakenly sent through first-install setup")
assert(not addon:SetConfigMode("expert"), "unknown config mode was accepted")
assert(addon:SetConfigMode("advanced") and addon:GetConfigMode() == "advanced",
	"advanced mode was not persisted")
assert(addon:SetConfigSetupCompleted(false) and not addon:IsConfigSetupCompleted(),
	"setup completion preference did not persist")
assert(addon:SetConfigSetupCompleted(true) and addon:IsConfigSetupCompleted(),
	"completing setup was not persisted")

addon.db.profile.smartChat = {}
addon._freshInstall = true
assert(addon:GetConfigMode() == "simple" and not addon:IsConfigSetupCompleted(),
	"genuine new install did not receive simple first-run setup")
assert(addon._freshInstall == nil, "fresh-install signal was not consumed")
assert(addon:SetConfigSetupCompleted(true))
assert(addon:GetSmartSettings().configUI.setupCompleted == true,
	"ordinary settings reads reopened completed first-run setup")
print("Config mode settings mock tests passed")
