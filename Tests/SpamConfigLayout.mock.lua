-- Focused no-client contract for the Spam Firewall settings workflow.
-- Run from the addon root with: lua Tests/SpamConfigLayout.mock.lua

local Frame = {}
Frame.__index = Frame

function Frame:SetPoint(...) self.point = { ... } end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetSize(width, height) self.width, self.height = width, height end
function Frame:SetWidth(width) self.width = width end
function Frame:SetHeight(height) self.height = height end
function Frame:SetAllPoints() end
function Frame:SetJustifyH() end
function Frame:SetTextColor() end
function Frame:SetTexture() end
function Frame:SetVertexColor() end
function Frame:SetMaxLetters() end
function Frame:SetFrameStrata() end
function Frame:SetAlpha(value) self.alpha = value end
function Frame:ClearFocus() self.focused = false end
function Frame:SetFocus() self.focused = true end
function Frame:SetText(value) self.textValue = tostring(value or "") end
function Frame:GetText() return self.textValue or "" end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown ~= false end
function Frame:Enable() self.enabled = true end
function Frame:Disable() self.enabled = false end
function Frame:EnableMouse(value) self.mouseEnabled = value and true or false end
function Frame:SetTooltip(title, body) self.tooltipTitle, self.tooltipBody = title, body end
function Frame:SetScript(name, callback)
	self.scripts = self.scripts or {}
	self.scripts[name] = callback
end
function Frame:HookScript(name, callback)
	self.scripts = self.scripts or {}
	self.scripts[name] = callback
end
function Frame:CreateTexture() return setmetatable({ shown = true }, Frame) end
function Frame:CreateFontString() return setmetatable({ shown = true }, Frame) end

local function frame(parent)
	return setmetatable({ parent = parent, shown = true, enabled = true }, Frame)
end

function CreateFrame(_, _, parent) return frame(parent) end

UIParent = frame()
GameFontNormalLarge = {}
GameFontNormal = {}
GameFontNormalSmall = {}
GameFontHighlightSmall = {}

local Theme = { texts = {}, frames = {}, textures = {} }
function Theme:GetColor() return 1, 1, 1, 1 end
function Theme:CreatePanel(parent)
	return frame(parent)
end
function Theme:CreateText(parent) return frame(parent) end
function Theme:CreateButton(parent, text, width, height)
	local button = frame(parent)
	button.width, button.height = width, height
	button.text = frame(button)
	button.text:SetText(text)
	function button:SetLabel(value) self.text:SetText(value) end
	function button:SetTheme(fill, border, color) self.theme = { fill, border, color } end
	return button
end
function Theme:CreateTightButton(parent, text, height)
	return self:CreateButton(parent, text, math.max(24, (#tostring(text) * 7) + 10), height)
end
function Theme:CreateEditBox(parent, width, height)
	local edit = frame(parent)
	edit.width, edit.height = width, height
	return edit
end
function Theme:CreateCompactToggle(parent, label, width)
	local toggle = frame(parent)
	toggle.width, toggle.height = width, 20
	toggle.label = frame(toggle)
	toggle.label:SetText(label)
	function toggle:SetValue(value, silent)
		self.checked = value and true or false
		if not silent and self.OnValueChanged then self:OnValueChanged(self.checked) end
	end
	return toggle
end
function Theme:RegisterTexture() end
function Theme:RegisterFrame() end
function Theme:ApplyFrame() end
function Theme:RegisterRefreshCallback() end

local settings = {
	spam = {
		enabled = true,
		exemptSelf = true,
		duplicate = {
			enabled = true, window = 12, allowedCopies = 1, minimumLength = 4, muteAfter = 3,
			caseInsensitive = true, collapseWhitespace = true, stripFormatting = true, ignorePunctuation = false,
		},
		burst = { enabled = true, window = 6, limit = 6, muteDuration = 15 },
		scopes = { channel = true, ["local"] = true, guild = true, group = true, whisper = true, bnet = true },
		escalation = { enabled = true, mutesBeforeBan = 3, strikeWindow = 1800 },
	},
}

local bans = {
	{
		id = "player-long", fullName = "ExtremelyLongPlayerNameThatMustNotReachTheCloseButton-Realm",
		source = "automatic", reason = "duplicate", strikes = 3, bannedAt = 100,
		lastChannel = "Trade", evidence = { { reason = "duplicate", channel = "Trade", message = "Repeated line" } },
	},
}
local spamController = { resetStats = 0, resetMemory = 0, clearedStrikes = 0 }
function spamController:RefreshSettings() end
function spamController:GetStats()
	return { enabled = true, registeredEvents = 12, blocked = 4, duplicates = 3, bursts = 1 }
end
function spamController:GetBans() return bans end
function spamController:GetBanStats() return { banned = #bans } end
function spamController:GetOffenderStats() return { offenders = 2, strikes = 3 } end
function spamController:GetBanReport(identity)
	for _, entry in ipairs(bans) do if entry.id == identity then return entry end end
end
function spamController:BanSender(name)
	bans[#bans + 1] = { id = string.lower(name), fullName = name, source = "manual" }
	return true
end
function spamController:UnbanSender(identity)
	for index, entry in ipairs(bans) do
		if entry.id == identity then table.remove(bans, index) return true end
	end
	return false
end
function spamController:ResetOffender() return true end
function spamController:ClearOffenders() self.clearedStrikes = self.clearedStrikes + 1 return 2 end
function spamController:ClearBans()
	local count = #bans
	for index = #bans, 1, -1 do table.remove(bans, index) end
	return count
end
function spamController:ResetStats() self.resetStats = self.resetStats + 1 end
function spamController:ResetForProfile() self.resetMemory = self.resetMemory + 1 end

ChattyChattyBangBang = { Theme = Theme, SpamControl = spamController }
local addon = ChattyChattyBangBang
function addon:GetSmartSettings() return settings end

local now = 50
GetTime = function() return now end
date = function() return "2026-01-01 12:00" end

dofile("Core/Config.lua")

local config = addon.CustomConfig
config.pages = {}
config.navigationButtons = {}
config.content = frame()
config.frame = frame()
config:BuildSpamPage()

assert(config.spamSection == "filters" and config.spamFiltersPane:IsShown()
	and not config.spamBansPane:IsShown(),
	"Spam Firewall did not open on FILTERS")
assert(config.spamFilterMode == "protections" and config.spamFilterSubPanes.protections:IsShown()
	and not config.spamFilterSubPanes.matching:IsShown() and not config.spamFilterSubPanes.chats:IsShown(),
	"FILTERS did not open on the two core protections")
for _, pane in pairs(config.spamFilterSubPanes) do
	assert(pane.point[4] == 0 and pane.point[5] == -32 and pane.width == 636 and pane.height == 300,
		"filter subpanes do not share one fixed bounded workspace")
end
assert(config.spamDuplicateToggle.parent == config.spamFilterSubPanes.protections
	and config.spamBurstToggle.parent == config.spamFilterSubPanes.protections,
	"the two plain-language protections leaked out of PROTECTIONS")
config.spamDuplicateToggle:SetValue(false)
assert(settings.spam.duplicate.enabled == false,
	"PROTECTIONS did not persist the existing duplicate setting")

config.spamFilterSubButtons.matching.scripts.OnClick()
assert(config.spamFilterMode == "matching" and config.spamFilterSubPanes.matching:IsShown()
	and not config.spamFilterSubPanes.protections:IsShown() and not config.spamFilterSubPanes.chats:IsShown(),
	"MATCHING DETAILS did not replace PROTECTIONS exclusively")
for _, edit in pairs(config.spamNumberEdits) do
	assert(edit.parent == config.spamFilterSubPanes.matching,
		"numeric matching detail leaked into another filter pane")
end
config.spamNumberEdits.duplicateWindow:SetText("30")
config.spamNumberEdits.duplicateWindow.scripts.OnEditFocusLost(config.spamNumberEdits.duplicateWindow)
assert(settings.spam.duplicate.window == 30,
	"MATCHING DETAILS did not persist through the existing numeric setting path")
config.spamFilterSubButtons.chats.scripts.OnClick()
assert(config.spamFilterMode == "chats" and config.spamFilterSubPanes.chats:IsShown()
	and not config.spamFilterSubPanes.protections:IsShown() and not config.spamFilterSubPanes.matching:IsShown(),
	"PROTECTED CHATS did not replace MATCHING DETAILS exclusively")
for _, toggle in pairs(config.spamScopeToggles) do
	assert(toggle.parent == config.spamFilterSubPanes.chats,
		"protected-chat choice leaked into another filter pane")
end
config.spamScopeToggles.channel:SetValue(false)
assert(settings.spam.scopes.channel == false,
	"PROTECTED CHATS did not persist through the existing scope setting path")

config.spamBansButton.scripts.OnClick()
assert(config.spamSection == "bans" and config.spamBansPane:IsShown()
	and not config.spamFiltersPane:IsShown(),
	"BAN LIST did not replace FILTERS")
assert(config.spamBanMode == "players" and config.spamBanSubPanes.players:IsShown()
	and not config.spamBanSubPanes.auto:IsShown() and not config.spamBanSubPanes.maintenance:IsShown(),
	"BAN LIST did not open on PLAYERS")
for _, pane in pairs(config.spamBanSubPanes) do
	assert(pane.point[4] == 0 and pane.point[5] == -32 and pane.width == 636 and pane.height == 300,
		"ban subpanes do not share one fixed bounded workspace")
end
assert(config.spamBanNameEdit.parent == config.spamBanSubPanes.players
	and config.spamBanRows[1].parent == config.spamBanSubPanes.players,
	"manual ban or player report list leaked outside PLAYERS")
assert(not config.spamBanPrevious:IsShown() and not config.spamBanNext:IsShown(),
	"single-page ban list showed inert pager arrows")

config:ShowSpamBanReport("player-long", bans[1])
assert(config.spamBanReport.title.width == 470,
	"ban report title was not capped away from its close button")
config:HideSpamBanReport()
for index = 2, 8 do
	bans[index] = { id = "player-" .. index, fullName = "Player" .. index, source = "manual" }
end
config:RefreshSpamBans(true)
assert(config.spamBanPrevious:IsShown() and config.spamBanNext:IsShown(),
	"multi-page ban list hid its pager arrows")

config.spamBanSubButtons.auto.scripts.OnClick()
assert(config.spamBanMode == "auto" and config.spamBanSubPanes.auto:IsShown()
	and not config.spamBanSubPanes.players:IsShown() and not config.spamBanSubPanes.maintenance:IsShown(),
	"AUTO-BAN did not replace PLAYERS exclusively")
assert(config.spamEscalationToggle.parent == config.spamBanSubPanes.auto
	and config.spamMutesToBanEdit.parent == config.spamBanSubPanes.auto
	and config.spamStrikeWindowEdit.parent == config.spamBanSubPanes.auto,
	"automatic escalation controls leaked outside AUTO-BAN")

config.spamBanSubButtons.maintenance.scripts.OnClick()
assert(config.spamBanMode == "maintenance" and config.spamBanSubPanes.maintenance:IsShown()
	and not config.spamBanSubPanes.players:IsShown() and not config.spamBanSubPanes.auto:IsShown(),
	"MAINTENANCE did not replace AUTO-BAN exclusively")
assert(config.spamClearBansButton.parent == config.spamBanSubPanes.maintenance
	and config.spamResetStatsButton.parent == config.spamBanSubPanes.maintenance
	and config.spamClearMemoryButton.parent == config.spamBanSubPanes.maintenance,
	"clear/reset actions leaked outside MAINTENANCE")
assert(config.spamBanNotice.parent == config.spamBansPane
	and config.spamBanNotice.parent ~= config.spamBanSubPanes.maintenance,
	"ban notice was not fixed across every ban subpane")

config.spamClearBansButton.scripts.OnClick()
assert(#bans == 8 and config.spamClearBansButton.text:GetText() == "CONFIRM",
	"CLEAR BANS lost its first confirmation step")
config.spamClearBansButton.scripts.OnClick()
assert(#bans == 0 and config.spamClearBansButton.text:GetText() == "CLEAR BANS",
	"confirmed CLEAR BANS did not clear and reset its action")
config.spamResetStatsButton.scripts.OnClick()
config.spamClearMemoryButton.scripts.OnClick()
assert(spamController.resetStats == 1 and spamController.resetMemory == 1,
	"maintenance reset actions did not reach the existing controller APIs")
assert(config.spamStatus.parent == config.spamPage,
	"spam status moved into a transient subpane instead of remaining fixed")

print("Spam config layout mock passed")
