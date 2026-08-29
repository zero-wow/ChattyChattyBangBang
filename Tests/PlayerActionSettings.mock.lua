-- Focused no-client contract for the player-name action menu settings.
-- Run from the addon root with: lua Tests/PlayerActionSettings.mock.lua

ChattyChattyBangBang = {
	db = { profile = { smartChat = {} } },
}

dofile("Core/Settings.lua")

local addon = ChattyChattyBangBang
local settings = addon:GetSmartSettings()
local menu = addon:GetPlayerActionMenuSettings()
assert(settings.dock.playerActions.autoHide == true, "player actions should auto-hide by default")
assert(menu.autoHideSeconds == 10, "player-action default timeout changed")
assert(menu.minimumAutoHideSeconds == 1 and menu.maximumAutoHideSeconds == 120,
	"player-action timeout bounds changed")

local refreshes = 0
addon.SmartDock = {
	RefreshPlayerActionDismissal = function() refreshes = refreshes + 1 end,
}

local ok, value = addon:SetPlayerActionMenuAutoHideEnabled(false)
assert(ok and value == false and settings.dock.playerActions.autoHide == false,
	"player-action auto-hide did not disable")
ok, value = addon:SetPlayerActionMenuAutoHideSeconds(0)
assert(ok and value == 1, "player-action timeout did not clamp to its minimum")
ok, value = addon:SetPlayerActionMenuAutoHideSeconds(999)
assert(ok and value == 120, "player-action timeout did not clamp to its maximum")
ok, value = addon:SetPlayerActionMenuAutoHideSeconds(9.6)
assert(ok and value == 10, "player-action timeout did not normalize to whole seconds")
assert(refreshes == 4, "live player-action settings did not refresh the open menu")
assert(addon:SetPlayerActionMenuAutoHideSeconds("not-a-number") == false,
	"invalid player-action timeout was accepted")

addon.SmartDock = nil
addon.db.profile = { smartChat = { dock = { playerActions = "broken" } } }
menu = addon:GetPlayerActionMenuSettings()
assert(menu.autoHide == true and menu.autoHideSeconds == 10,
	"malformed player-action settings did not self-heal")

print("Player action settings mock passed")
