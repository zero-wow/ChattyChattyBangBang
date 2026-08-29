-- Focused no-client contract for the Message Blocks settings workflow.
-- Run from the addon root with: lua Tests/BlocksConfigLayout.mock.lua

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
	blocks = {
		enabled = true,
		uiFeedback = { coalesce = true, window = 1.5 },
	},
}
local rules = {
	{
		id = "block-1", name = "Vendor spam", text = "cheap goods", enabled = true,
		matchMode = "contains", caseSensitive = false,
		allSources = false, sources = { ["channel:trade"] = true },
		allEvents = true, events = {}, allSenders = false,
		senderKeys = { ["name:trader"] = true }, senderLabel = "Trader",
	},
}
local blockedArchive = {
	{
		id = "blocked2", text = "cheap goods cheap goods", sender = "Trader",
		sourceId = "channel:trade", sourceLabel = "Trade", event = "CHAT_MSG_CHANNEL",
		ruleId = "block-1", ruleName = "Vendor spam", occurrences = 2,
		firstTimestamp = "10:01", lastTimestamp = "10:03", firstEpoch = 100, lastEpoch = 120,
	},
	{
		id = "blocked1", text = "older unwanted line", sender = "Other",
		sourceId = "channel:general", sourceLabel = "General", event = "CHAT_MSG_CHANNEL",
		ruleId = "block-1", ruleName = "Vendor spam", occurrences = 1,
		firstTimestamp = "09:58", lastTimestamp = "09:58", firstEpoch = 80, lastEpoch = 80,
	},
}
local archiveSettings = { enabled = true, maxEntries = 500, retentionDays = 7 }

ChattyChattyBangBang = { Theme = Theme }
local addon = ChattyChattyBangBang
function addon:GetSmartSettings() return settings end
function addon:GetBlockSettings() return settings.blocks end
function addon:GetBlockRules() return rules end
function addon:GetBlockStats() return { blocked = 3, manual = 2, uiCoalesced = 4 } end
function addon:GetBlockSourceDefinitions()
	local result = {}
	for index = 1, 10 do
		result[index] = { id = "source-" .. index, label = "Source " .. index, selected = index == 1 }
	end
	return result
end
function addon:GetBlockEventDefinitions()
	return { { id = "CHAT_MSG_CHANNEL", label = "Channel chat", selected = true } }
end
function addon:UpdateBlockRule(ruleId, patch)
	assert(ruleId == rules[1].id)
	for key, value in pairs(patch or {}) do rules[1][key] = value end
	return rules[1]
end
function addon:CreateBlockRule(data)
	data.id = "block-2"
	rules[#rules + 1] = data
	return data
end
function addon:DeleteBlockRule(ruleId)
	for index, rule in ipairs(rules) do
		if rule.id == ruleId then table.remove(rules, index) return true end
	end
	return false
end
function addon:SetBlockRuleEnabled(ruleId, enabled)
	for _, rule in ipairs(rules) do
		if rule.id == ruleId then rule.enabled = enabled return rule end
	end
end
function addon:SetBlockRuleAllSenders(ruleId, enabled)
	for _, rule in ipairs(rules) do
		if rule.id == ruleId then rule.allSenders = enabled return true end
	end
	return false
end
function addon:SetBlockRuleAllSources(ruleId, enabled)
	for _, rule in ipairs(rules) do if rule.id == ruleId then rule.allSources = enabled return true end end
	return false
end
function addon:SetBlockRuleAllEvents(ruleId, enabled)
	for _, rule in ipairs(rules) do if rule.id == ruleId then rule.allEvents = enabled return true end end
	return false
end
function addon:SetBlockRuleSourceEnabled() return true end
function addon:SetBlockRuleEventEnabled() return true end
function addon:SetUIFeedbackCoalescing(_, enabled, window)
	settings.blocks.uiFeedback.coalesce = enabled
	settings.blocks.uiFeedback.window = window
	return true
end
function addon:SetBlockControlEnabled(_, enabled)
	settings.blocks.enabled = enabled
	return true
end
function addon:ResetBlockStats() return true end
function addon:GetBlockedMessageArchive() return blockedArchive end
function addon:GetBlockedMessageArchiveStats()
	local occurrences = 0
	for _, entry in ipairs(blockedArchive) do occurrences = occurrences + entry.occurrences end
	return {
		enabled = archiveSettings.enabled, entries = #blockedArchive, occurrences = occurrences,
		maxEntries = archiveSettings.maxEntries, retentionDays = archiveSettings.retentionDays,
	}
end
function addon:SetBlockedMessageArchiveEnabled(enabled)
	archiveSettings.enabled = enabled and true or false
	if not archiveSettings.enabled then blockedArchive = {} end
	return true, archiveSettings.enabled
end
function addon:SetBlockedMessageArchiveCapacity(value)
	archiveSettings.maxEntries = math.floor(tonumber(value))
	return true, archiveSettings.maxEntries
end
function addon:SetBlockedMessageArchiveRetentionDays(value)
	archiveSettings.retentionDays = math.floor(tonumber(value))
	return true, archiveSettings.retentionDays
end
function addon:ClearBlockedMessageArchive()
	blockedArchive = {}
	return true
end

dofile("Core/Config.lua")

local config = addon.CustomConfig
config.pages = {}
config.navigationButtons = {}
config.content = frame()
config:BuildBlocksPage()

assert(config.blockInspectorMode == "message" and config.blockInspectorPanes.message:IsShown(),
	"Message Blocks did not open on its primary MESSAGE task")
assert(not config.blockInspectorPanes.player:IsShown() and not config.blockInspectorPanes.where:IsShown(),
	"inactive block inspectors were visible together")
for _, pane in pairs(config.blockInspectorPanes) do
	assert(pane.point[4] == 188 and pane.point[5] == -82 and pane.width == 422 and pane.height == 254,
		"block inspector panes do not share one fixed bounded workspace")
	assert(188 + pane.width <= 636 and 82 + pane.height <= 390,
		"block inspector escaped the 636x390 work surface")
end
assert(config.blockNameEdit.parent == config.blockInspectorPanes.message
	and config.blockTextEdit.parent == config.blockInspectorPanes.message,
	"message fields leaked outside the MESSAGE inspector")
assert(config.blockSaveButton.parent == config.blockInspectorPanes.message
	and config.blockDeleteButton.parent == config.blockInspectorPanes.message,
	"message actions leaked into unrelated scopes")

config.blockInspectorButtons.player.scripts.OnClick()
assert(config.blockInspectorMode == "player" and config.blockInspectorPanes.player:IsShown()
	and not config.blockInspectorPanes.message:IsShown() and not config.blockInspectorPanes.where:IsShown(),
	"PLAYER did not replace the previous inspector exclusively")
assert(config.blockSenderText:GetText() == "Trader" and config.blockAllSendersToggle.enabled,
	"saved player identity did not produce an editable player scope")
assert(config.blockAllSendersToggle.parent == config.blockInspectorPanes.player
	and config.blockSenderHint.parent == config.blockInspectorPanes.player,
	"player controls leaked outside the PLAYER inspector")

config.blockInspectorButtons.where.scripts.OnClick()
assert(config.blockInspectorMode == "where" and config.blockInspectorPanes.where:IsShown()
	and not config.blockInspectorPanes.message:IsShown() and not config.blockInspectorPanes.player:IsShown(),
	"WHERE did not replace the previous inspector exclusively")
assert(config.blockAllSourcesToggle:IsShown() and not config.blockAllEventsToggle:IsShown(),
	"source and message-type all-scope controls overlapped")
for index, row in ipairs(config.blockScopeRows) do
	local x = row.point[4]
	local y = math.abs(row.point[5])
	assert(row.parent == config.blockInspectorPanes.where and x + row.width <= 422 and y + row.height <= 254,
		"WHERE scope row " .. index .. " escaped its fixed inspector")
end
config.blockScopeEventsButton.scripts.OnClick()
assert(not config.blockAllSourcesToggle:IsShown() and config.blockAllEventsToggle:IsShown(),
	"message-type scope did not replace source scope in place")

assert(config.blockCoalesceToggle.parent ~= config.blockInspectorPanes.message
	and config.blockCoalesceToggle.parent ~= config.blockInspectorPanes.player
	and config.blockCoalesceToggle.parent ~= config.blockInspectorPanes.where,
	"UI error repeat handling remained mixed into a phrase-rule inspector")
local repeats = config.blockCoalesceToggle.parent
assert(repeats.point[2] == config.blocksPage and repeats.point[4] == 8 and repeats.point[5] == -442
	and repeats.width == 636 and repeats.height == 56 and 442 + repeats.height <= 508,
	"UI ERROR REPEATS escaped the page or overlapped the rule workspace")
assert(config.blockCoalesceToggle.tooltipBody and config.blockWindowEdit.tooltipBody,
	"ambiguous UI-error repeat controls lost their concise help")

-- BLOCK RULES and BLOCKED MESSAGES are sibling page tasks. The quarantine is
-- bounded inside the same workspace and reserves visible gutters on both sides
-- of its list/detail divider instead of touching it with text or hit targets.
assert(config.blocksSection == "rules" and config.blockRulesFrames[1]:IsShown()
	and not config.blockedArchivePanel:IsShown(),
	"Message Blocks did not default to the rule task exclusively")
config.blockArchiveSectionButton.scripts.OnClick()
assert(config.blocksSection == "archive" and config.blockedArchivePanel:IsShown()
	and not config.blockRulesFrames[1]:IsShown() and not config.blockRulesFrames[2]:IsShown(),
	"Blocked Messages did not replace both rule surfaces exclusively")
local archivePanel = config.blockedArchivePanel
assert(archivePanel.point[2] == config.blocksPage and archivePanel.point[4] == 8
	and archivePanel.point[5] == -46 and archivePanel.width == 636 and archivePanel.height == 452
	and 46 + archivePanel.height <= 508,
	"Blocked Messages escaped the minimum config workspace")
assert(config.blockedArchiveEnabledToggle.point[4] == 8,
	"archive controls lost their explicit left border gutter")
for index, row in ipairs(config.blockedArchiveRows) do
	local rowRight = row.point[4] + row.width
	assert(row.parent == archivePanel and rowRight <= 256,
		"blocked row " .. index .. " touched or crossed the divider gutter")
end
local detailX = config.blockedArchiveDetailTitle.point[4]
assert(detailX == 278 and detailX - (config.blockedArchiveRows[1].point[4] + config.blockedArchiveRows[1].width) >= 20,
	"blocked list/detail regions lack a visible two-sided divider gutter")
assert(detailX + config.blockedArchiveDetailTitle.width == 628 and 636 - 628 == 8,
	"blocked detail text lost its right border gutter")
assert(config.blockedArchiveRows[1]:IsShown() and config.blockedArchiveRows[1].text:GetText() == "Trader  x2"
	and config.blockedArchiveDetailText:GetText() == "cheap goods cheap goods",
	"archive list/detail did not hydrate the newest selected aggregate")
assert(not config.blockedArchivePrevious:IsShown() and not config.blockedArchiveNext:IsShown(),
	"single-page blocked archive exposed dead pager buttons")
config.blockedArchiveRetentionEdit:SetText("30")
config.blockedArchiveRetentionEdit.scripts.OnEditFocusLost()
config.blockedArchiveCapacityEdit:SetText("750")
config.blockedArchiveCapacityEdit.scripts.OnEditFocusLost()
assert(archiveSettings.retentionDays == 30 and archiveSettings.maxEntries == 750,
	"blocked archive cleanup controls did not persist through their public APIs")
config.blockedArchiveEnabledToggle:SetValue(false)
assert(not archiveSettings.enabled and #blockedArchive == 0
	and config.blockedArchiveCount:GetText() == "ARCHIVE OFF",
	"privacy disable did not erase retained blocked-message plaintext immediately")
config.blockRulesSectionButton.scripts.OnClick()
assert(config.blocksSection == "rules" and config.blockRulesFrames[1]:IsShown()
	and config.blockRulesFrames[2]:IsShown() and not config.blockedArchivePanel:IsShown(),
	"returning to Block Rules did not restore both rule surfaces exclusively")

print("Message Blocks config layout mock passed")
