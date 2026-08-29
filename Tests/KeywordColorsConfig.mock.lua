-- Focused UI-contract test for the Message Colors group inspector. Run from
-- the addon root with:
--   lua Tests/KeywordColorsConfig.mock.lua

local Frame = {}
Frame.__index = Frame

function Frame:SetPoint(point, relative, relativePoint, x, y)
	self.point = {
		point = point,
		relative = relative,
		relativePoint = relativePoint,
		x = x or 0,
		y = y or 0,
	}
end
function Frame:ClearAllPoints() end
function Frame:SetSize(width, height) self.width, self.height = width, height end
function Frame:SetWidth(width) self.width = width end
function Frame:SetHeight(height) self.height = height end
function Frame:SetAllPoints() end
function Frame:SetJustifyH() end
function Frame:SetAlpha(value) self.alpha = value end
function Frame:SetTexture() end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown ~= false end
function Frame:Enable() self.enabled = true end
function Frame:Disable() self.enabled = false end
function Frame:SetText(value) self.textValue = tostring(value or "") end
function Frame:GetText() return self.textValue or "" end
function Frame:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
function Frame:SetVertexColor(r, g, b, a) self.vertexColor = { r, g, b, a } end
function Frame:SetScript(name, callback)
	self.scripts = self.scripts or {}
	self.scripts[name] = callback
end
function Frame:HookScript(name, callback)
	self.scripts = self.scripts or {}
	self.scripts[name] = callback
end
function Frame:ClearFocus() self.clearedFocus = true end
function Frame:SetFocus() self.focused = true end
function Frame:SetMaxLetters(value) self.maxLetters = value end
function Frame:CreateTexture() return setmetatable({ shown = true, parent = self }, Frame) end
function Frame:CreateFontString() return setmetatable({ shown = true, parent = self }, Frame) end

local function frame(parent)
	return setmetatable({ shown = true, enabled = true, parent = parent }, Frame)
end

function CreateFrame(_, _, parent)
	return frame(parent)
end

UIParent = frame()
GameFontNormalLarge = {}
GameFontNormal = {}
GameFontNormalSmall = {}
GameFontHighlightSmall = {}

local palette = {
	goldBright = { 1, 0.8, 0.39, 1 },
	gold = { 0.88, 0.61, 0.24, 1 },
	accent = { 0.22, 0.48, 0.78, 1 },
	accentSoft = { 0.11, 0.24, 0.42, 1 },
	surface = { 0.055, 0.071, 0.102, 1 },
	surfaceRaised = { 0.085, 0.112, 0.158, 1 },
	borderMuted = { 0.17, 0.28, 0.42, 1 },
	text = { 0.91, 0.91, 0.86, 1 },
	textMuted = { 0.56, 0.63, 0.71, 1 },
	success = { 0.30, 0.82, 0.57, 1 },
	warning = { 1, 0.66, 0.25, 1 },
	danger = { 0.90, 0.30, 0.28, 1 },
}

local Theme = { texts = {}, frames = {}, textures = {} }
function Theme:GetColor(name)
	local color = palette[name] or palette.text
	return color[1], color[2], color[3], color[4]
end
function Theme:CreateText(parent)
	return frame(parent)
end
function Theme:CreateButton(parent, text, width, height)
	local button = frame(parent)
	button:SetSize(width or 20, height or 20)
	button.text = frame(button)
	button.text:SetText(text)
	function button:SetLabel(value)
		self.text:SetText(value)
	end
	function button:SetTheme(fill, border, color)
		self.theme = { fill, border, color }
	end
	return button
end
function Theme:CreateTightButton(parent, text, height, emphasis)
	local button = self:CreateButton(parent, text, height, height, emphasis)
	button:SetWidth(math.max(height or 20, (#tostring(text or "") * 6) + 6))
	return button
end
function Theme:CreateCompactToggle(parent, text, width)
	local toggle = self:CreateButton(parent, text, width or 120, 20)
	toggle.checked = false
	function toggle:SetValue(value, silent)
		self.checked = value and true or false
		if not silent and self.OnValueChanged then
			self:OnValueChanged(self.checked)
		end
	end
	return toggle
end
function Theme:CreateEditBox(parent, width, height)
	local edit = frame(parent)
	edit:SetSize(width or 180, height or 22)
	return edit
end
function Theme:RegisterTexture() end
function Theme:RegisterFrame() end
function Theme:ApplyFrame() end
function Theme:RegisterRefreshCallback() end

RAID_CLASS_COLORS = {
	MAGE = { r = 0.25, g = 0.78, b = 0.92 },
}

local groups = {
	{
		id = "groupFinder",
		label = "GROUP FINDER",
		color = "goldBright",
		defaultColor = "goldBright",
		terms = {
			"lfg", "lfm", "lf", "lf1m", "lf2m", "lf3m", "lf4m",
			"lf5m", "lf6m", "lf1dps", "group", "looking", "finder",
		},
	},
	{
		id = "tank",
		label = "TANK / OFF-TANK",
		color = "accent",
		defaultColor = "accent",
		terms = { "tank", "tnak", "ot", "off tank" },
	},
	{
		id = "mage",
		label = "MAGE",
		color = "class:MAGE",
		defaultColor = "class:MAGE",
		terms = { "mage" },
	},
}
for index = 1, 11 do
	table.insert(groups, {
		id = "utility-" .. index,
		label = "UTILITY " .. index,
		color = "text",
		defaultColor = "text",
		terms = { "word" .. index },
	})
end

local settings = {
	keywordColorGroups = groups,
	keywordColors = {},
}

ChattyChattyBangBang = { Theme = Theme }
local addon = ChattyChattyBangBang
function addon:GetSmartSettings()
	return settings
end
function addon:GetKeywordColorOptions()
	return {
		{ id = "goldBright", label = "GOLD BRIGHT" },
		{ id = "gold", label = "GOLD" },
		{ id = "accent", label = "ACCENT" },
		{ id = "success", label = "SUCCESS" },
		{ id = "warning", label = "WARNING" },
		{ id = "danger", label = "DANGER" },
		{ id = "text", label = "NEUTRAL" },
	}
end
function addon:GetKeywordColorGroups()
	return settings.keywordColorGroups
end
function addon:SetKeywordColorGroup(groupId, colorSpec)
	for _, group in ipairs(settings.keywordColorGroups) do
		if group.id == groupId then
			group.color = colorSpec
			for _, termSpec in ipairs(group.terms) do
				local term = type(termSpec) == "table" and termSpec.term or termSpec
				settings.keywordColors[string.lower(term)] = colorSpec
			end
			return true
		end
	end
	return false, "unknown-group"
end
function addon:ResetKeywordColorGroups()
	for _, group in ipairs(settings.keywordColorGroups) do
		if group.custom ~= true then
			group.color = group.defaultColor
		end
	end
	return true
end
function addon:CreateKeywordColorGroup(label, colorSpec)
	label = tostring(label or "")
	if label == "" then return false, "invalid-label" end
	for _, group in ipairs(settings.keywordColorGroups) do
		if string.lower(group.label) == string.lower(label) then
			return false, "duplicate-label"
		end
	end
	local group = {
		id = "custom-" .. string.lower(string.gsub(label, "[^%a%d]+", "-")),
		label = label,
		color = colorSpec,
		defaultColor = colorSpec,
		terms = {},
		custom = true,
	}
	table.insert(settings.keywordColorGroups, group)
	return true, group
end
function addon:DeleteKeywordColorGroup(groupId)
	for index, group in ipairs(settings.keywordColorGroups) do
		if group.id == groupId then
			if group.custom ~= true then return false, "built-in-group" end
			table.remove(settings.keywordColorGroups, index)
			return true
		end
	end
	return false, "unknown-group"
end
function addon:AddKeywordColorGroupTerm(groupId, term, caseSensitive)
	term = tostring(term or "")
	if term == "" then return false, "invalid-term" end
	for _, group in ipairs(settings.keywordColorGroups) do
		for _, existingSpec in ipairs(group.terms or {}) do
			local existing = type(existingSpec) == "table" and existingSpec.term or existingSpec
			if string.lower(existing) == string.lower(term) then
				if group.id == groupId then return true, "already-present" end
				return false, "already-in-group", group.id
			end
		end
	end
	for _, group in ipairs(settings.keywordColorGroups) do
		if group.id == groupId then
			table.insert(group.terms, caseSensitive and { term = term, caseSensitive = true } or term)
			settings.keywordColors[string.lower(term)] = group.color
			return true
		end
	end
	return false, "unknown-group"
end

local suggestionSettings = {
	enabled = true,
	threshold = 5,
}
local suggestions = {}
for index = 1, 9 do
	table.insert(suggestions, {
		id = "candidate-" .. index,
		term = "candidate" .. index,
		label = "candidate" .. index,
		count = index + 4,
		source = index % 2 == 0 and "Trade" or "General",
		sample = "Sample message for candidate " .. index,
	})
end
function addon:GetKeywordSuggestionSettings()
	return suggestionSettings
end
function addon:SetKeywordSuggestionsEnabled(value)
	suggestionSettings.enabled = value and true or false
	return true
end
function addon:SetKeywordSuggestionThreshold(value)
	suggestionSettings.threshold = math.max(1, math.floor(tonumber(value) or 1))
	return true, suggestionSettings.threshold
end
function addon:GetKeywordSuggestions()
	return suggestions
end
local function removeSuggestion(id)
	for index, candidate in ipairs(suggestions) do
		if candidate.id == id then
			table.remove(suggestions, index)
			return candidate
		end
	end
end
function addon:AddKeywordSuggestionToGroup(id, groupId)
	local candidate = removeSuggestion(id)
	if not candidate then return false, "unknown-candidate" end
	for _, group in ipairs(settings.keywordColorGroups) do
		if group.id == groupId then
			table.insert(group.terms, candidate.term)
			return true
		end
	end
	return false, "unknown-group"
end
function addon:DismissKeywordSuggestion(id)
	return removeSuggestion(id) and true or false, "unknown-candidate"
end
function addon:ClearKeywordSuggestions()
	for index = #suggestions, 1, -1 do
		table.remove(suggestions, index)
	end
	return true
end

dofile("Core/Config.lua")

local config = addon.CustomConfig
config.pages = {}
config.navigationButtons = {}
config.content = frame()
config:BuildKeywordColorsPage()

local function paneRight(pane)
	local bounds = assert(pane and pane.keywordLayoutBounds, "fixed pane lost its layout bounds")
	return bounds.left + bounds.width
end

local function paneBottom(pane)
	local bounds = assert(pane and pane.keywordLayoutBounds, "fixed pane lost its layout bounds")
	return bounds.top + bounds.height
end

local function assertPaneInside(pane, name)
	local bounds = assert(pane and pane.keywordLayoutBounds, name .. " has no fixed bounds")
	assert(bounds.left >= 8 and paneRight(pane) <= 644, name .. " escaped the 636px workspace width")
	assert(bounds.top >= 46 and paneBottom(pane) <= 490, name .. " escaped the compact workspace height")
end

local function localTop(widget)
	assert(widget and widget.point and widget.point.point == "TOPLEFT", "control lost its fixed TOPLEFT anchor")
	return -(widget.point.y or 0)
end

local function exactlyOneShown(...)
	local shown = 0
	for index = 1, select("#", ...) do
		if select(index, ...):IsShown() then shown = shown + 1 end
	end
	return shown == 1
end

assertPaneInside(config.keywordColorListPane, "color-group list")
assertPaneInside(config.keywordColorInspectorWordsPane, "words inspector")
assertPaneInside(config.keywordColorInspectorColorPane, "color inspector")
assert(paneRight(config.keywordColorListPane) <= config.keywordColorInspectorWordsPane.keywordLayoutBounds.left,
	"color-group inventory overlaps its inspector")
assert(config.keywordColorInspectorWordsPane.keywordLayoutBounds.left == config.keywordColorInspectorColorPane.keywordLayoutBounds.left
	and paneRight(config.keywordColorInspectorWordsPane) == paneRight(config.keywordColorInspectorColorPane),
	"exclusive group inspectors do not share stable bounds")
assert(exactlyOneShown(config.keywordColorInspectorWordsPane, config.keywordColorInspectorColorPane),
	"default group inspector exposed more than one task")
assert(config.keywordColorInspectorSection == "words" and config.keywordColorInspectorWordsPane:IsShown(),
	"group inspector did not default to WORDS")
assert(localTop(config.keywordColorTermRows[12]) + config.keywordColorTermRows[12].height <= localTop(config.keywordColorTermPrevious),
	"word grid overlaps its pager")
assert(localTop(config.keywordColorTermPrevious) + config.keywordColorTermPrevious.height <= localTop(config.keywordColorTermAddEdit),
	"word pager overlaps the add-word form")
assert(localTop(config.keywordColorOptionButtons[7]) + config.keywordColorOptionButtons[7].height <= localTop(config.keywordColorDefaultButton),
	"bounded color palette overlaps the selected-group action")
assert((config.keywordColorOptionButtons[4].point.x + config.keywordColorOptionButtons[4].width) <= 426,
	"four-column color palette escaped the inspector")

config:SetKeywordColorInspectorSection("color")
assert(config.keywordColorInspectorSection == "color" and config.keywordColorInspectorColorPane:IsShown()
	and not config.keywordColorInspectorWordsPane:IsShown(), "COLOR did not replace WORDS in place")
config:SetKeywordColorInspectorSection("words")

assert(#config.keywordColorGroupRows == 12, "group list did not use compact paging")
assert(#config.keywordColorTermRows == 12, "term inspector did not use compact paging")
assert(config.selectedKeywordColorGroupId == "groupFinder", "first color group was not selected")
assert(config.keywordColorGroupNext:IsShown(), "group pager was hidden with a second page")
assert(config.keywordColorTermNext:IsShown(), "term pager was hidden with a thirteenth term")

config.keywordColorTermNext.scripts.OnClick(config.keywordColorTermNext)
assert(config.keywordColorTermPage == 2, "term pager did not advance")

config:SelectKeywordColorTerm("tnak")
assert(config.selectedKeywordColorGroupId == "tank", "legacy term selection did not select its shared group")
config:ApplyKeywordColor("warning")
assert(settings.keywordColorGroups[2].color == "warning", "group color was not changed")
assert(settings.keywordColors.tank == "warning" and settings.keywordColors.tnak == "warning",
	"group editor did not update every shared tank spelling")

config:SelectKeywordColorGroup("mage")
config:ApplyKeywordColor("danger")
assert(settings.keywordColorGroups[3].color == "danger", "class group did not allow an override")
config:ResetSelectedKeywordColorGroup()
assert(settings.keywordColorGroups[3].color == "class:MAGE", "class group did not restore its symbolic default")
assert(config.keywordColorInspectorSwatch.vertexColor[1] == 0.25, "class swatch did not use RAID_CLASS_COLORS")

config:SelectKeywordColorGroup("utility-11")
assert(config.keywordColorGroupPage == 2, "selection did not reveal its group-list page")

config:BeginKeywordColorGroupCreation()
assert(config.keywordColorGroupDraft and config.keywordColorNewGroupNameEdit:IsShown(),
	"personal-group creation did not open its compact form")
assert(config.keywordColorInspectorSection == "color" and config.keywordColorInspectorColorPane:IsShown()
	and not config.keywordColorInspectorWordsPane:IsShown(), "new-group flow did not focus the COLOR pane")
assert(not config.keywordColorInspectorWordsButton:IsShown() and not config.keywordColorInspectorColorButton:IsShown(),
	"new-group flow left unrelated inspector navigation visible")
assert(config.keywordColorNewGroupNameEdit.parent == config.keywordColorInspectorColorPane
	and config.keywordColorOptionButtons[1].parent == config.keywordColorInspectorColorPane
	and localTop(config.keywordColorNewGroupNameEdit) < localTop(config.keywordColorOptionButtons[1])
	and localTop(config.keywordColorOptionButtons[1]) < localTop(config.keywordColorCreateGroupButton),
	"new-group flow is not ordered NAME -> COLOR -> CREATE")
assert(not config.keywordColorTermAddEdit:IsShown(), "draft group incorrectly exposed its word editor")
config.keywordColorNewGroupNameEdit:SetText("Raid Calls")
config:ApplyKeywordColor("success")
config:CreateKeywordColorGroup()
local customId = "custom-raid-calls"
assert(config.selectedKeywordColorGroupId == customId, "created group was not selected")
assert(config.keywordColorTermAddEdit:IsShown(), "created group did not expose its word editor")
assert(config.keywordColorInspectorSection == "words" and config.keywordColorInspectorWordsPane:IsShown()
	and not config.keywordColorInspectorColorPane:IsShown(), "created group did not continue directly to WORDS")
assert(config.keywordColorInspectorWordsButton:IsShown() and config.keywordColorInspectorColorButton:IsShown(),
	"normal group inspector navigation did not return after creation")
config.keywordColorTermAddEdit:SetText("world buff")
config.keywordColorTermAddButton.scripts.OnClick(config.keywordColorTermAddButton)
local createdGroup
for _, group in ipairs(settings.keywordColorGroups) do
 	if group.id == customId then createdGroup = group break end
end
assert(createdGroup and createdGroup.terms[1] == "world buff" and createdGroup.color == "success",
	"personal group did not retain its phrase and selected color")
config:DeleteSelectedKeywordColorGroup()
assert(config.selectedKeywordColorGroupId == "groupFinder", "deleting a personal group did not restore a safe selection")
config:BeginKeywordColorGroupCreation()
config:CancelKeywordColorGroupCreation()
assert(config.keywordColorGroupDraft == nil and config.keywordColorInspectorSection == "words"
	and config.keywordColorInspectorWordsPane:IsShown(), "cancelling a new group did not restore WORDS")

config:SetKeywordColorsSection("suggestions")
assert(config.keywordSuggestionsPanel:IsShown() and not config.keywordColorsPanel:IsShown(),
	"Suggestions review surface was not reachable from Message Colors")
assertPaneInside(config.keywordSuggestionReviewPane, "suggestion review")
assertPaneInside(config.keywordSuggestionSettingsPane, "suggestion settings")
assertPaneInside(config.keywordSuggestionMorePane, "suggestion maintenance")
assert(config.keywordSuggestionReviewPane.keywordLayoutBounds.left == config.keywordSuggestionSettingsPane.keywordLayoutBounds.left
	and paneBottom(config.keywordSuggestionReviewPane) == paneBottom(config.keywordSuggestionMorePane),
	"exclusive suggestion panes do not share stable bounds")
assert(config.keywordSuggestionSection == "review"
	and exactlyOneShown(config.keywordSuggestionReviewPane, config.keywordSuggestionSettingsPane, config.keywordSuggestionMorePane),
	"Suggestions did not open to one focused REVIEW pane")
assert(config.keywordSuggestionAddButton.parent == config.keywordSuggestionReviewPane
	and config.keywordSuggestionTrackingToggle.parent == config.keywordSuggestionSettingsPane
	and config.keywordSuggestionClearButton.parent == config.keywordSuggestionMorePane,
	"suggestion actions were not separated by task")
assert(localTop(config.keywordSuggestionRows[8]) + config.keywordSuggestionRows[8].height <= localTop(config.keywordSuggestionPrevious),
	"suggestion queue overlaps its pager")
assert(localTop(config.keywordSuggestionGroupRows[6]) + config.keywordSuggestionGroupRows[6].height <= localTop(config.keywordSuggestionGroupPrevious),
	"target groups overlap their pager")
assert(localTop(config.keywordSuggestionGroupPrevious) + config.keywordSuggestionGroupPrevious.height <= localTop(config.keywordSuggestionAddButton),
	"target-group pager overlaps the ADD stage")
config:SetKeywordSuggestionsSection("settings")
assert(config.keywordSuggestionSettingsPane:IsShown()
	and exactlyOneShown(config.keywordSuggestionReviewPane, config.keywordSuggestionSettingsPane, config.keywordSuggestionMorePane),
	"REPORT SETTINGS did not replace REVIEW in place")
config:SetKeywordSuggestionsSection("more")
assert(config.keywordSuggestionMorePane:IsShown()
	and exactlyOneShown(config.keywordSuggestionReviewPane, config.keywordSuggestionSettingsPane, config.keywordSuggestionMorePane),
	"MORE did not replace REPORT SETTINGS in place")
config:SetKeywordSuggestionsSection("review")
assert(#config.keywordSuggestionRows == 8, "candidate queue did not use compact pagination")
assert(#config.keywordSuggestionGroupRows == 6, "target group picker did not use compact pagination")
assert(config.keywordSuggestionNext:IsShown(), "candidate pager was hidden with a second page")
assert(config.keywordSuggestionGroupNext:IsShown(), "target group pager was hidden with a later page")
assert(config.selectedKeywordSuggestionId == "candidate-1", "first report candidate was not selected for review")
assert(string.find(config.keywordSuggestionMeta:GetText(), "GENERAL", 1, true), "selected candidate did not show its source")
assert(string.find(config.keywordSuggestionSample:GetText(), "Sample message", 1, true), "selected candidate did not show a compact sample")
assert(config.selectedKeywordSuggestionGroupId == nil, "report UI silently assigned a target color group")
assert(config.keywordSuggestionAddButton.enabled == false, "add action enabled without an explicit target group")

config:SelectKeywordSuggestionGroup("tank")
assert(config.selectedKeywordSuggestionGroupId == "tank", "target group selection did not persist")
assert(config.keywordSuggestionAddButton.enabled == true, "add action stayed disabled after explicit selection")
config:AddSelectedKeywordSuggestion()
assert(#suggestions == 8 and settings.keywordColorGroups[2].terms[#settings.keywordColorGroups[2].terms] == "candidate1",
	"explicit add did not move the reviewed candidate into its selected group")

config:SetKeywordSuggestionsSection("settings")
config.keywordSuggestionTrackingToggle:SetValue(false)
assert(suggestionSettings.enabled == false, "candidate reporting toggle did not call the exposed setting API")
config.keywordSuggestionThresholdEdit:SetText("7")
config:CommitKeywordSuggestionThreshold()
assert(suggestionSettings.threshold == 7, "candidate threshold did not call the exposed setting API")

config:SetKeywordSuggestionsSection("review")
config:DismissSelectedKeywordSuggestion()
assert(#suggestions == 7, "dismiss did not remove the selected report candidate")
config:SetKeywordSuggestionsSection("more")
config:ClearKeywordSuggestions()
assert(#suggestions == 0, "clear did not empty the report queue")

addon.GetKeywordSuggestions = nil
config:RefreshKeywordSuggestionsPanel()
assert(not config.keywordSuggestionsSectionButton:IsShown() and config.keywordColorsSection == "colors",
	"missing suggestion API did not fall back to the established color editor")

print("Keyword colors config mock passed")
