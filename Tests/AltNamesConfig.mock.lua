-- Run from the Retail addon root: lua Tests/AltNamesConfig.mock.lua
dofile("Tests/ConfigViewport.mock.lua")
local addon = ChattyChattyBangBang
local theme, config = addon.Theme, addon.CustomConfig
local settings = { dock = { playerActions = {} }, safety = {} }
addon.GetSmartSettings = function() return settings end
dofile("Core/AltNames.lua")

function theme:CreateEditBox(parent, width, height)
	return self:CreateButton(parent, "", width, height)
end
function theme:CreateCompactToggle(parent, text, width)
	local toggle = self:CreateButton(parent, text, width, 20)
	function toggle:SetValue(value) self.value = value end
	return toggle
end
function theme:CreateToggle(parent, text)
	return self:CreateCompactToggle(parent, text, 636)
end

config.activePage = "safety"
config:BuildSafetyPage()
assert(config.content:GetHeight() >= 650, "alt-name editor was clipped at compact viewport")
assert(config.altNameFirstEdit.point[4] + config.altNameFirstEdit:GetWidth() + 14
	<= config.altNameSecondEdit.point[4], "character fields lost their visible gutter")
assert(config.altNameSecondEdit.point[4] + config.altNameSecondEdit:GetWidth() + 14
	<= config.altNameLinkButton.point[4]
	and config.altNameLinkButton.point[4] + config.altNameLinkButton:GetWidth() + 8 <= 636,
	"link action collided with the second name field or page edge")
config.altNameFirstEdit:SetText("Mira-Area52")
config.altNameSecondEdit:SetText("Neri-Area52")
config.altNameLinkButton:Click()
assert(config.altNameRows[1].remove:IsShown()
	and config.altNameRows[1].label:GetText():find("Mira-Area52", 1, true),
	"linked group did not appear in the player-action editor")
assert(config.altNameRows[1].remove.point[4] == -8
	and config.altNameRows[1].label:GetWidth() + 14 <= 636 - 8 - 80,
	"group removal target lost its text/button gutter")
config.altNameRows[1].remove:Click()
assert(#addon.AltNames:GetGroups() == 0 and not config.altNameRows[1].remove:IsShown(),
	"remove action did not clear the saved history-only group")
config.altNameLinkButton:Click()
config.altNameFirstEdit:SetText("Neri-Area52")
config.altNameUnlinkButton:Click()
assert(#addon.AltNames:GetGroups() == 0,
	"unlink action did not remove an individual name and dissolve the pair")
settings.altNameGroups = { groups = { { id = 1, names = {
	string.rep("A", 32), string.rep("B", 32), string.rep("C", 32),
} } } }
config:RefreshAltNamesPage()
assert(config.altNameRows[1].label:GetStringWidth() <= 526,
	"long linked-name list escaped its bounded row label")
print("Alt-name editor mock passed")
