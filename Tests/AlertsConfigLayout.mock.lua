-- Focused no-client contract for the Alerts settings workflow.
-- Run from the addon root with: lua Tests/AlertsConfigLayout.mock.lua

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
	alerts = {
		enabled = true,
		popout = false,
		sound = true,
		autoHideSeconds = 300,
	},
}
local rules = {
	{
		id = "alert-1", name = "Keystone", enabled = true,
		terms = { "keystone" }, matchAll = false,
		allSources = false, sources = { ["source-1"] = true },
		revealDock = true, sound = false,
	},
}
settings.alerts.rules = rules

ChattyChattyBangBang = { Theme = Theme }
local addon = ChattyChattyBangBang
function addon:GetSmartSettings() return settings end
function addon:GetAlertRules() return rules end
function addon:GetAlertSourceDefinitions()
	local result = {}
	for index = 1, 10 do
		result[index] = { id = "source-" .. index, label = "Source " .. index, selected = index == 1 }
	end
	return result
end
function addon:UpdateAlertRule(ruleId, patch)
	assert(ruleId == rules[1].id)
	for key, value in pairs(patch or {}) do rules[1][key] = value end
	return rules[1]
end
function addon:CreateAlertRule(data)
	data = data or {}
	data.id = "alert-2"
	data.name = data.name or "NEW ALERT"
	data.terms = data.terms or {}
	data.enabled = data.enabled ~= false
	data.allSources = data.allSources ~= false
	data.sources = data.sources or {}
	data.revealDock = data.revealDock ~= false
	rules[#rules + 1] = data
	return data
end
function addon:DeleteAlertRule(ruleId)
	for index, rule in ipairs(rules) do
		if rule.id == ruleId then table.remove(rules, index) return true end
	end
	return false
end
function addon:ResetAlertRuleSources(ruleId)
	for _, rule in ipairs(rules) do
		if rule.id == ruleId then rule.allSources, rule.sources = true, {} return true end
	end
	return false
end
function addon:SetAlertRuleSourceEnabled(ruleId, sourceId, enabled)
	for _, rule in ipairs(rules) do
		if rule.id == ruleId then
			rule.sources[sourceId] = enabled and true or nil
			return true
		end
	end
	return false
end

addon.AlertEngine = {
	stats = { matches = 2, matchedRecords = 1 },
	RefreshRules = function() end,
	SetEnabled = function() end,
	GetStats = function(self) return self.stats end,
	ResetStats = function(self) self.stats = { matches = 0, matchedRecords = 0 } end,
}

dofile("Core/Config.lua")

local config = addon.CustomConfig
config.pages = {}
config.navigationButtons = {}
config.content = frame()
config:BuildAlertsPage()

assert(config.alertInspectorMode == "words" and config.alertInspectorPanes.words:IsShown(),
	"Alerts did not open on its primary WORDS task")
assert(not config.alertInspectorPanes.notify:IsShown() and not config.alertInspectorPanes.sources:IsShown()
	and not config.alertInspectorPanes.global:IsShown(),
	"inactive alert inspectors were visible together")
for _, pane in pairs(config.alertInspectorPanes) do
	assert(pane.point[4] == 188 and pane.point[5] == -82 and pane.width == 422 and pane.height == 254,
		"alert inspector panes do not share one fixed bounded workspace")
	assert(188 + pane.width <= 636 and 82 + pane.height <= 390,
		"alert inspector escaped the 636x390 work surface")
end
local work = config.alertGlobalEnabledToggle.parent
assert(work ~= config.alertInspectorPanes.global,
	"ALERTS ON moved into a replaceable inspector instead of remaining the page master")
assert(config.alertNameEdit.parent == config.alertInspectorPanes.words
	and config.alertTermsEdit.parent == config.alertInspectorPanes.words
	and config.alertSaveButton.parent == config.alertInspectorPanes.words,
	"word fields or actions leaked outside the WORDS inspector")

config.alertInspectorButtons.words.scripts.OnClick()
config.alertUsePlayerNameButton.scripts.OnClick()
assert(config.alertTermsEdit:GetText() == "keystone, [PLAYER_NAME]",
	"ADD MY NAME replaced existing terms instead of appending the player variable")
config.alertUsePlayerNameButton.scripts.OnClick()
assert(config.alertTermsEdit:GetText() == "keystone, [PLAYER_NAME]",
	"ADD MY NAME duplicated an existing player variable")

config.alertInspectorButtons.notify.scripts.OnClick()
assert(config.alertInspectorMode == "notify" and config.alertInspectorPanes.notify:IsShown()
	and not config.alertInspectorPanes.words:IsShown() and not config.alertInspectorPanes.sources:IsShown()
	and not config.alertInspectorPanes.global:IsShown(),
	"NOTIFY did not replace the previous inspector exclusively")
assert(config.alertRevealGateHint:GetText():find("cannot reveal", 1, true),
	"per-rule reveal help did not explain the disabled global gate")
assert(config.alertSoundGateHint:GetText():find("Every matching rule", 1, true),
	"per-rule sound help did not explain the global sound override")
assert(config.alertRevealToggle.parent == config.alertInspectorPanes.notify
	and config.alertRuleSoundToggle.parent == config.alertInspectorPanes.notify,
	"per-rule notification controls leaked outside NOTIFY")

config.alertInspectorButtons.sources.scripts.OnClick()
assert(config.alertInspectorMode == "sources" and config.alertInspectorPanes.sources:IsShown()
	and not config.alertInspectorPanes.words:IsShown() and not config.alertInspectorPanes.notify:IsShown()
	and not config.alertInspectorPanes.global:IsShown(),
	"SOURCES did not replace the previous inspector exclusively")
for index, row in ipairs(config.alertSourceRows) do
	local x = row.point[4]
	local y = math.abs(row.point[5])
	assert(row.parent == config.alertInspectorPanes.sources and x + row.width <= 422 and y + row.height <= 254,
		"source row " .. index .. " escaped its fixed inspector")
end
assert(config.alertSourcePrevious:IsShown() and config.alertSourceNext:IsShown(),
	"multi-page source list hid its pager")

config.alertInspectorButtons.global.scripts.OnClick()
assert(config.alertInspectorMode == "global" and config.alertInspectorPanes.global:IsShown()
	and not config.alertInspectorPanes.words:IsShown() and not config.alertInspectorPanes.notify:IsShown()
	and not config.alertInspectorPanes.sources:IsShown(),
	"GLOBAL BEHAVIOR did not replace the previous inspector exclusively")
assert(config.alertEditorTitle:GetText() == "GLOBAL ALERT SETTINGS",
	"global inspector retained a misleading selected-rule title")
assert(config.alertGlobalPopoutToggle.parent == config.alertInspectorPanes.global
	and config.alertGlobalSoundToggle.parent == config.alertInspectorPanes.global
	and config.alertAutoHideEdit.parent == config.alertInspectorPanes.global,
	"global behavior controls leaked outside GLOBAL")
assert(config.alertAutoHideEdit:GetText() == "120",
	"GLOBAL auto-hide display exceeded SmartDock's actual 120-second maximum")
config.alertAutoHideEdit:SetText("999")
config.alertAutoHideEdit.scripts.OnEditFocusLost(config.alertAutoHideEdit)
assert(settings.alerts.autoHideSeconds == 120 and config.alertAutoHideEdit:GetText() == "120",
	"GLOBAL auto-hide editor did not clamp to SmartDock's actual maximum")
assert(config.alertGlobalPopoutToggle.tooltipBody and config.alertGlobalSoundToggle.tooltipBody
	and config.alertAutoHideEdit.tooltipBody,
	"global alert behavior lost its concise help")

-- The rule list pager is itself progressive: one page must not show inert arrows.
assert(not config.alertRulePrevious:IsShown() and not config.alertRuleNext:IsShown(),
	"single-page alert rule list showed inert pager controls")

print("Alerts config layout mock passed")
