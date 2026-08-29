-- Focused no-client contract for player-action dismissal, links, and geometry.
-- Run from the addon root with: lua Tests/PlayerActionMenu.mock.lua

local mouse = { LeftButton = false, RightButton = false, MiddleButton = false }
IsMouseButtonDown = function(button) return mouse[button] == true end

ChattyChattyBangBang = {
	Theme = {},
	Presentation = {},
	MessageEngine = {
		GetMessageById = function(_, id) return { id = tonumber(id), sender = "Linked" } end,
	},
}

dofile("Core/SmartDock.lua")

local addon = ChattyChattyBangBang
local dock = addon.SmartDock
local menuSettings = { autoHide = true, autoHideSeconds = 10 }
addon.GetPlayerActionMenuSettings = function() return menuSettings end

local panel = { shown = true, over = false, width = 400 }
function panel:IsShown() return self.shown end
function panel:IsMouseOver() return self.over end
function panel:Show() self.shown = true end
function panel:Hide() self.shown = false end
function panel:GetWidth() return self.width end
function panel:SetHeight(value) self.height = value end

dock.playerActions = panel
dock.actionRecord = { id = 1, sender = "Tester" }
assert(dock:RefreshPlayerActionDismissal(), "shown player menu did not arm dismissal")
assert(dock.playerActionAutoHideRemaining == 10, "default timeout was not armed")
assert(dock:UpdatePlayerActionDismissal(9.9), "player menu hid before its timeout")
assert(not dock:UpdatePlayerActionDismissal(0.1) and not panel.shown,
	"player menu did not hide at its timeout")

panel.shown, panel.over = true, false
mouse.LeftButton = false
dock:RefreshPlayerActionDismissal()
mouse.LeftButton = true
assert(not dock:UpdatePlayerActionDismissal(0) and not panel.shown,
	"outside left press did not dismiss the player menu")

panel.shown, panel.over = true, true
mouse.LeftButton = false
dock:RefreshPlayerActionDismissal()
mouse.RightButton = true
assert(dock:UpdatePlayerActionDismissal(0) and panel.shown,
	"inside press incorrectly dismissed the player menu")
mouse.RightButton = false
dock:UpdatePlayerActionDismissal(0)
panel.over = false
mouse.MiddleButton = true
assert(not dock:UpdatePlayerActionDismissal(0) and not panel.shown,
	"outside middle press did not dismiss the player menu")
mouse.MiddleButton = false

panel.shown = true
menuSettings.autoHide = false
dock:RefreshPlayerActionDismissal()
assert(dock.playerActionAutoHideRemaining == nil and dock:UpdatePlayerActionDismissal(30),
	"disabled auto-hide still expired")

local function button(width)
	return {
		GetWidth = function() return width end,
		ClearAllPoints = function(self) self.point = nil end,
		SetPoint = function(self, ...) self.point = { ... } end,
	}
end
dock.playerActionButtons = { button(50), button(45), button(70), button(80), button(75) }
panel.width = 400
local laidOut, compact = dock:RefreshPlayerActionsLayout()
assert(laidOut and not compact and panel.height == 46,
	"wide player-action geometry did not use one compact row")
assert(dock.playerActionButtons[1].point[1] == "BOTTOMLEFT"
	and dock.playerActionButtons[1].point[5] == 4,
	"wide player-action row has the wrong inset")
panel.width = 308
laidOut, compact = dock:RefreshPlayerActionsLayout()
assert(laidOut and compact and panel.height == 66,
	"narrow player-action geometry did not split safely")
assert(dock.playerActionButtons[1].point[5] == 24
	and dock.playerActionButtons[4].point[1] == "BOTTOMLEFT"
	and dock.playerActionButtons[4].point[5] == 4,
	"narrow player-action rows overlap or use the wrong bounds")

local linked
dock.ShowPlayerActions = function(_, record) linked = record end
dock:HandleHyperlink("ccbbplayer:42", "[Linked]", "LeftButton")
assert(linked and linked.id == 42, "player hyperlink lost its exact MessageEngine record")
local delegated
ChatFrame_OnHyperlinkShow = function(_, link) delegated = link end
dock:HandleHyperlink("item:123", "[Item]", "LeftButton")
assert(delegated == "item:123", "non-player hyperlink no longer delegates to Blizzard")

local source = assert(io.open("Core/SmartDock.lua", "rb")):read("*a")
for _, label in ipairs({ "WHISPER", "INVITE", "ADD FRIEND", "CHATTY MUTE", "WOW IGNORE" }) do
	assert(string.find(source, 'label = "' .. label .. '"', 1, true), "missing explicit action label: " .. label)
end
assert(string.find(source, "Dock:HidePlayerActions()\n\t\t\taction.action(record)", 1, true),
	"one-shot player actions do not close before dispatch")

print("Player action menu mock passed")
