-- Focused UI-contract test for the consolidated Message Views workspace.  It
-- uses deliberately tiny WoW/Theme stand-ins so navigation aliases, compact
-- pagination, the custom-view draft, and the single selected editor can be
-- checked without a running client.

local Frame = {}
Frame.__index = Frame

function Frame:SetPoint(...)
	self.point = { ... }
end
function Frame:ClearAllPoints()
	self.point = nil
end
function Frame:SetSize(width, height)
	self.width = width
	self.height = height
end
function Frame:SetWidth(width) self.width = width end
function Frame:SetHeight(height) self.height = height end
function Frame:SetAllPoints() end
function Frame:SetScrollChild(child) self.scrollChild = child end
function Frame:EnableMouseWheel(enabled) self.mouseWheelEnabled = enabled and true or false end
function Frame:SetVerticalScroll(value) self.verticalScroll = value or 0 end
function Frame:GetVerticalScroll() return self.verticalScroll or 0 end
function Frame:GetVerticalScrollRange() return self.verticalScrollRange or 0 end
function Frame:SetJustifyH() end
function Frame:SetTextColor() end
function Frame:SetTexture() end
function Frame:SetVertexColor() end
function Frame:SetFrameStrata() end
function Frame:SetToplevel() end
function Frame:SetMovable() end
function Frame:SetAutoFocus() end
function Frame:SetMultiLine() end
function Frame:SetFontObject() end
function Frame:SetTextInsets() end
function Frame:RegisterForDrag() end
function Frame:EnableMouse() end
function Frame:ClearFocus() end
function Frame:SetFocus() end
function Frame:SetMaxLetters() end
function Frame:SetAlpha() end
function Frame:Raise() end
function Frame:StartMoving() end
function Frame:StopMovingOrSizing() end

function Frame:SetText(value)
	self.textValue = tostring(value or "")
end

function Frame:GetText()
	return self.textValue or ""
end

function Frame:GetStringWidth()
	return string.len(self:GetText()) * 6
end

function Frame:Show()
	self.shown = true
end

function Frame:Hide()
	self.shown = false
end

function Frame:IsShown()
	return self.shown ~= false
end

function Frame:Enable()
	self.enabled = true
end

function Frame:Disable()
	self.enabled = false
end

function Frame:SetScript(name, callback)
	self.scripts = self.scripts or {}
	self.scripts[name] = callback
end

function Frame:HookScript(name, callback)
	self.scripts = self.scripts or {}
	self.scripts[name] = callback
end

function Frame:CreateTexture()
	return setmetatable({ shown = true }, Frame)
end

function Frame:CreateFontString()
	return setmetatable({ shown = true }, Frame)
end

local function frame()
	return setmetatable({ shown = true, enabled = true }, Frame)
end

function CreateFrame(_, _, parent)
	local value = frame()
	value.parent = parent
	return value
end

UIParent = frame()
GameFontNormalLarge = {}
GameFontNormal = {}
GameFontNormalSmall = {}
GameFontHighlightSmall = {}

local Theme = {
	texts = {},
	frames = {},
}

function Theme:CreatePanel(parent)
	local value = frame()
	value.parent = parent
	return value
end

function Theme:CreateText(parent)
	local value = frame()
	value.parent = parent
	return value
end

function Theme:CreateButton(parent, text, width, height)
	local button = frame()
	button.parent = parent
	button:SetSize(width or 120, height or 22)
	button.text = frame()
	button.text:SetText(text)
	function button:SetLabel(value)
		self.text:SetText(value)
	end
	function button:SetTheme(fill, border, color)
		self.theme = { fill, border, color }
	end
	function button:SetTooltip(title, body)
		self.tooltipTitle = title
		self.tooltipBody = body
	end
	return button
end

function Theme:CreateTightButton(parent, text, height, emphasis)
	-- Simulate a partner client whose live button font is substantially wider
	-- than this mock's ordinary text metric. Tight controls must still reserve
	-- ten pixels of edge padding without relying on clipped fixed widths.
	local intrinsic = math.ceil(string.len(tostring(text or "")) * 7 * 1.7)
	return self:CreateButton(parent, text, math.max(height or 20, intrinsic + 10), height, emphasis)
end

function Theme:CreateEditBox(parent, width, height)
	local value = frame()
	value.parent = parent
	value:SetSize(width or 120, height or 22)
	return value
end

function Theme:CreateCompactToggle(parent, label, width)
	local button = frame()
	button.parent = parent
	button:SetSize(width or 146, 20)
	button.label = frame()
	button.label:SetText(label)
	button.box = frame()
	button.mark = frame()
	function button:SetValue(value, silent)
		self.checked = value and true or false
		self.mark:SetText(self.checked and "X" or "")
		if not silent and self.OnValueChanged then self:OnValueChanged(self.checked) end
	end
	return button
end

function Theme:RegisterTexture() end
function Theme:RegisterFrame() end
function Theme:ApplyFrame() end
function Theme:RegisterRefreshCallback() end
function Theme:GetColor()
	return 1, 1, 1, 1
end

local mockThemeNames = {
	"Obsidian Dawn", "Arcane Constellation", "Moonsteel", "Stormforged",
	"Deepwater", "Astral Tide", "Frostbound", "Ember Ledger",
	"Cinderwake", "Ebon Lantern", "Crimson Covenant", "Bloodmoon",
	"Verdant Reliquary",
}
Theme.ColorWays = {}
for _, name in ipairs(mockThemeNames) do
	Theme.ColorWays[name] = {
		background = { 0.02, 0.03, 0.04, 1 },
		surfaceRaised = { 0.08, 0.10, 0.14, 1 },
		accent = { 0.22, 0.48, 0.78, 1 },
		gold = { 0.88, 0.61, 0.24, 1 },
	}
end
function Theme:GetColorwayNames()
	local copy = {}
	for index = 1, #mockThemeNames do copy[index] = mockThemeNames[index] end
	return copy
end
function Theme:GetColorwayInfo()
	return { description = "A compact dark palette." }
end
function Theme:ResolveColorwayName(name)
	return name or "Obsidian Dawn"
end

local settings = {
	colorway = "Obsidian Dawn",
	dock = {
		sourceColumnAlignment = false,
		senderColumnAlignment = false,
		columnAlignmentSpacing = 2,
		senderColumnAlignmentSpacing = 2,
		senderColumnMaxLength = 14,
		alignmentVisibleOnly = false,
	},
	conversations = {
		autoOpenWhispers = true,
		deferInCombat = true,
		chromeAutoHide = false,
		titleBarVisibility = "inherit",
		actionVisibility = "inherit",
		composerVisibility = "inherit",
		actionButtonStyle = "text",
	},
	views = {
		general = true,
		trade = true,
		guild = true,
		sync = true,
	},
}

ChattyChattyBangBang = {
	Theme = Theme,
	SmartViews = {},
}

local addon = ChattyChattyBangBang
local views = {
	{ id = "general", label = "GENERAL", key = "G", description = "General chat" },
	{ id = "trade", label = "TRADE", key = "T", description = "Trade chat" },
	{ id = "guild", label = "GUILD", key = "GU", description = "Guild chat" },
	{ id = "sync", label = "SYNC", key = "SYNC", description = "Add-on sync traffic" },
}

function addon:GetSmartSettings()
	return settings
end

function addon:GetMessengerSettings()
	local conversations = settings.conversations
	local function resolved(mode)
		return mode == "inherit" and (conversations.chromeAutoHide and "auto" or "always") or mode
	end
	return {
		autoOpenWhispers = conversations.autoOpenWhispers,
		deferInCombat = conversations.deferInCombat,
		chromeAutoHide = conversations.chromeAutoHide,
		titleBarVisibility = conversations.titleBarVisibility,
		actionVisibility = conversations.actionVisibility,
		composerVisibility = conversations.composerVisibility,
		actionButtonStyle = conversations.actionButtonStyle,
		resolvedTitleBarVisibility = resolved(conversations.titleBarVisibility),
		resolvedActionVisibility = resolved(conversations.actionVisibility),
		resolvedComposerVisibility = resolved(conversations.composerVisibility),
	}
end

function addon:SetMessengerPopupWhispersEnabled(value) settings.conversations.autoOpenWhispers = value return true end
function addon:SetMessengerCombatDeferralEnabled(value) settings.conversations.deferInCombat = value return true end
function addon:SetMessengerChromeAutoHideEnabled(value) settings.conversations.chromeAutoHide = value return true end
function addon:SetMessengerElementVisibility(element, mode)
	local keys = { title = "titleBarVisibility", actions = "actionVisibility", composer = "composerVisibility" }
	settings.conversations[keys[element]] = mode
	return true, mode
end
function addon:SetMessengerActionButtonStyle(style) settings.conversations.actionButtonStyle = style return true end

function addon:GetSmartViews()
	return views
end

local sourceOverrides = {}
local sourceSetterRebuilds = 0
local sourceResetRebuilds = 0
local sourceHomes = {
	["channel:general"] = "general",
	["channel:trade"] = "trade",
	["system:message"] = "system",
	["addon:alcver"] = "sync",
}
function addon:GetViewSourceDefinitions(viewId)
	local overrides = sourceOverrides[viewId] or {}
	local function definition(id, label, group)
		local defaultEnabled = sourceHomes[id] == viewId
		local override = overrides[id]
		local feedLocked = (sourceHomes[id] == "sync") ~= (viewId == "sync")
		return {
			id = id,
			label = label,
			sourceGroup = group,
			defaultEnabled = defaultEnabled,
			override = override,
			feedLocked = feedLocked,
			feedLockReason = feedLocked and "sync-only" or nil,
			enabled = not feedLocked and (override == nil and defaultEnabled or override == true),
		}
	end
	return {
		definition("channel:general", "General", "channels"),
		definition("channel:trade", "Trade", "channels"),
		definition("system:message", "System", "system"),
		definition("addon:alcver", "ALCver add-on sync", "sync"),
	}
end

local semanticEnabled = { groupFinder = true, trade = true, pvp = true }
function addon:GetSemanticRouteCatalog()
	return {
		{
			id = "groupFinder", label = "Group Finder", enabled = semanticEnabled.groupFinder, threshold = 7,
			explanation = "Routes public chat when group-recruiting evidence reaches the score threshold.",
			categories = {
				{ id = "shorthand", label = "Recruiting shorthand", terms = { "LFG", "LFM", "LF" } },
				{ id = "roles", label = "Requested roles", points = 3, terms = { "tank", "healer", "DPS" } },
				{ id = "counter", label = "Commercial counterevidence", points = -9, terms = { "Trade evidence at threshold" } },
			},
		},
		{
			id = "trade", label = "Trade", enabled = semanticEnabled.trade, threshold = 6,
			explanation = "Routes public chat when buying, selling, or service evidence reaches the score threshold.",
			categories = {
				{ id = "shorthand", label = "Transaction shorthand", points = 9, terms = { "WTS", "WTB", "WTT" } },
				{ id = "services", label = "Commercial services", points = 4, terms = { "crafting", "enchanting" } },
			},
		},
		{
			id = "pvp", label = "PVP", enabled = semanticEnabled.pvp, threshold = 8,
			explanation = "Defense channels route directly; public chat needs enough battleground or arena evidence.",
			categories = {
				{ id = "activity", label = "PVP activity", points = 5, terms = { "battleground", "arena", "Wintergrasp" } },
				{ id = "objective", label = "PVP objectives", points = 3, terms = { "flag", "base", "incoming" } },
			},
		},
	}
end

function addon:SetViewSourceEnabled(viewId, sourceId, enabled)
	assert(sourceId)
	assert(type(enabled) == "boolean")
	sourceOverrides[viewId] = sourceOverrides[viewId] or {}
	sourceOverrides[viewId][sourceId] = enabled
	sourceSetterRebuilds = sourceSetterRebuilds + 1
	return true
end

function addon:ResetViewSources(viewId)
	sourceOverrides[viewId] = nil
	sourceResetRebuilds = sourceResetRebuilds + 1
	return true
end

function addon:UpdateViewPresentation()
	return true
end

function addon:CreateCustomView(data)
	local view = {
		id = "custom-test",
		label = data.label,
		key = data.key,
		description = data.description,
		terms = data.terms,
		custom = true,
	}
	views[#views + 1] = view
	settings.views[view.id] = data.enabled ~= false
	return view
end

function addon:SetColorway(name)
	settings.colorway = name
	return name
end

function addon:GetSmartChatTextAppearanceOptions()
	local fonts = { { id = false, label = "INHERIT CURRENT CHAT FONT", inherit = true } }
	for index = 1, 12 do
		fonts[#fonts + 1] = { id = "Font " .. index, label = "Font " .. index }
	end
	return {
		fonts = fonts,
		outlines = {},
		size = { minimum = 8, maximum = 32, inherit = 0 },
		spacing = { minimum = 0, maximum = 8, default = 1 },
	}
end

function addon:GetSmartChatTextAppearance()
	return { size = 0, outline = "INHERIT", spacing = 1 }
end

function addon:GetViewSourceColumnAlignment()
	return settings.dock.sourceColumnAlignment
end
function addon:SetViewSourceColumnAlignment(_, enabled)
	settings.dock.sourceColumnAlignment = enabled and true or false
	return true, settings.dock.sourceColumnAlignment, false
end
function addon:GetViewSenderColumnAlignment()
	return settings.dock.senderColumnAlignment
end
function addon:SetViewSenderColumnAlignment(_, enabled)
	settings.dock.senderColumnAlignment = enabled and true or false
	return true, settings.dock.senderColumnAlignment, false
end
function addon:GetColumnAlignmentSpacing() return settings.dock.columnAlignmentSpacing end
function addon:SetColumnAlignmentSpacing(value)
	settings.dock.columnAlignmentSpacing = tonumber(value)
	return true, settings.dock.columnAlignmentSpacing
end
function addon:GetSenderColumnAlignmentSpacing() return settings.dock.senderColumnAlignmentSpacing end
function addon:SetSenderColumnAlignmentSpacing(value)
	settings.dock.senderColumnAlignmentSpacing = tonumber(value)
	return true, settings.dock.senderColumnAlignmentSpacing
end
function addon:GetSenderColumnMaxLength() return settings.dock.senderColumnMaxLength end
function addon:SetSenderColumnMaxLength(value)
	settings.dock.senderColumnMaxLength = tonumber(value)
	return true, settings.dock.senderColumnMaxLength
end
function addon:GetAlignmentVisibleOnly() return settings.dock.alignmentVisibleOnly end
function addon:SetAlignmentVisibleOnly(enabled)
	settings.dock.alignmentVisibleOnly = enabled and true or false
	return true, settings.dock.alignmentVisibleOnly
end

dofile("Core/Config.lua")

local config = addon.CustomConfig
config.pages = {}
config.navigationButtons = {}
config.content = frame()
config:BuildViewsPage()

config:BuildMessengerPage()
assert(config.messengerVisibilityRows.title and config.messengerVisibilityRows.actions
	and config.messengerVisibilityRows.composer,
	"Messenger options did not expose all three independently controlled regions")
for _, element in ipairs({ "title", "actions", "composer" }) do
	local row = config.messengerVisibilityRows[element]
	assert(row.buttons.inherit and row.buttons.always and row.buttons.auto and row.buttons.hidden,
		"Messenger region lost INHERIT / SHOW / AUTO / HIDE choices")
	for _, button in pairs(row.buttons) do
		assert(button.parent == config.messengerPage, "Messenger visibility choice escaped its page")
	end
end
assert(config.messengerVisibilityRows.title.buttons.inherit.point[4] == 120
	and config.messengerVisibilityRows.title.buttons.inherit.point[5] == -195,
	"Messenger title visibility row moved outside its bounded control grid")
assert(config.messengerVisibilityRows.actions.buttons.inherit.point[5] == -229
	and config.messengerVisibilityRows.composer.buttons.inherit.point[5] == -263,
	"Messenger region rows can overlap each other")
config.messengerChromeAutoHideToggle:SetValue(true)
assert(settings.conversations.chromeAutoHide == true,
	"Messenger shared auto-hide control did not use the public setter")
config.messengerVisibilityRows.title.buttons.hidden.scripts.OnClick()
assert(settings.conversations.titleBarVisibility == "hidden"
	and config.messengerVisibilityRows.title.resolved:GetText() == "CURRENT: HIDDEN",
	"Messenger title-bar HIDE choice did not persist and refresh")
config.messengerIconButtons.scripts.OnClick()
assert(settings.conversations.actionButtonStyle == "icons",
	"Messenger action appearance did not use the public setter")

assert(config.viewsPage == config.railsPage, "views and rails built separate pages")
assert(config.messageViewsPage == config.viewsPage, "unified workspace was not registered")
assert(config:BuildRailsPage() == config.viewsPage and config.pages.rails == config.viewsPage,
	"legacy builder did not preserve the single-page alias")
assert(#config.railRows == 12, "message-view list lost compact paged rows")
assert(config.selectedViewId == "general", "first message view was not selected")
assert(config.railRows[1].selectionAccent:IsShown(), "selected message view lost its accent marker")
assert(config.railRows[1].keyText:GetText() == "G" and config.railRows[1].nameText:GetText() == "GENERAL",
	"message-view row did not split tab label and display name into aligned columns")
assert(config.railRows[1].width == 156 and config.messageViewKeyColumnWidth == 24
	and config.railRows[1].keyText.width == 24 and config.messageViewColumnDividerX == 33
	and config.messageViewNameColumnX == 39,
	"message-view columns did not compact to the measured four-character key")
assert(config.messageViewColumnDividerX - (5 + config.messageViewKeyColumnWidth) == 4
	and config.messageViewNameColumnX - config.messageViewColumnDividerX == 6,
	"message-view key, divider, and name gutters lost their compact alignment")
assert(config.messageViewNameHeader.point[4] == 69
	and config.messageViewNameHeader.width == 114,
	"message-view headers did not follow the measured row columns")
assert(config.railDropAfter.width == 156,
	"after-last drag target extended beyond the bounded message-view row")
assert(config.railPrevious:IsShown() == false and config.railNext:IsShown() == false,
	"one-page message-view list showed inert pager controls")
assert(config.railSourcePrevious:IsShown() == false and config.railSourceNext:IsShown() == false,
	"one-page source list showed inert pager controls")
assert(config.viewEditorTitle:GetText() == "GENERAL",
	"sticky inspector header included editing instructions instead of only the selected name")
assert(config.messageViewsSourcesButton.text:GetText() == "CONTENTS"
	and config.messageViewsDetailsButton.text:GetText() == "LABEL & RULES"
	and config.messageViewsTextButton.text:GetText() == "TEXT",
	"message-view inspector lost its three user-goal panes")
local activeMessageViewTab = config.messageViewsSection == "sources" and config.messageViewsSourcesButton
	or (config.messageViewsSection == "text" and config.messageViewsTextButton)
	or config.messageViewsDetailsButton
assert(config.messageViewsSourcesButton._configTab and config.messageViewsDetailsButton._configTab
	and config.messageViewsTextButton._configTab and activeMessageViewTab._configTabSelected,
	"message-view pane navigation still looks like unrelated action buttons")
assert(config.viewNameEdit.parent == config.messageViewsDetailsPane
	and config.viewKeyEdit.parent == config.messageViewsDetailsPane,
	"label fields leaked out of LABEL & RULES into the sticky inspector header")
assert(config.viewTermsLabel:GetText() == "CUSTOM MATCH TERMS - NOT USED BY BUILT-IN VIEWS"
	and config.viewTermsHint:GetText():find("routing is read%-only")
	and string.len(config.viewTermsHint:GetText()) <= 66,
	"built-in view rules did not distinguish custom terms from the read-only classifier")
assert(config.viewTermsEdit.height == 60
	and config.messageViewsSemanticCatalogPanel.parent == config.messageViewsDetailsPane
	and config.messageViewsSemanticCatalogPanel.point[4] == 0
	and config.messageViewsSemanticCatalogPanel.point[5] == -190
	and config.messageViewsSemanticCatalogPanel.width == 408
	and config.messageViewsSemanticCatalogPanel.height == 80,
	"read-only semantic catalog escaped its bounded minimum-size inspector surface")
local semanticBounds = config.messageViewsDetailsPane.semanticCatalogLayoutBounds
assert(semanticBounds.paneWidth == 408 and semanticBounds.paneHeight == 308
	and semanticBounds.catalogTop - semanticBounds.hintBottom >= 8
	and semanticBounds.actionsTop - semanticBounds.catalogBottom >= 8
	and semanticBounds.actionsTop + 24 <= semanticBounds.paneHeight,
	"custom terms, semantic catalog, and action row can overlap at minimum config size")
assert(config.messageViewsSemanticCatalogTitle:GetText() == "BUILT-IN SEMANTIC ROUTING - READ ONLY"
	and config.messageViewsSemanticCatalogOpen.text:GetText() == "FULL ANALYZER",
	"semantic catalog lost its read-only identity or route to the full analyzer")
assert(config.messageViewsSemanticCatalogRows[1].title:GetText():find("GROUP FINDER", 1, true)
	and config.messageViewsSemanticCatalogRows[1].title:GetText():find("ON", 1, true)
	and config.messageViewsSemanticCatalogRows[1].title:GetText():find("7+", 1, true)
	and config.messageViewsSemanticCatalogRows[2].title:GetText():find("TRADE", 1, true)
	and config.messageViewsSemanticCatalogRows[2].title:GetText():find("6+", 1, true)
	and config.messageViewsSemanticCatalogRows[3].title:GetText():find("PVP", 1, true)
	and config.messageViewsSemanticCatalogRows[3].title:GetText():find("8+", 1, true),
	"compact catalog did not show Group Finder/Trade/PVP state and threshold")
assert(config.messageViewsSemanticCatalogRows[1].evidence:GetText():find("Recruiting shorthand", 1, true)
	and config.messageViewsSemanticCatalogRows[2].evidence:GetText():find("Transaction shorthand", 1, true)
	and config.messageViewsSemanticCatalogRows[3].evidence:GetText():find("PVP activity", 1, true),
	"compact catalog omitted concise evidence groups")
for index = 1, 3 do
	local row = config.messageViewsSemanticCatalogRows[index]
	assert(row.point[4] == 7 and row.point[5] == -21 - ((index - 1) * 18)
		and row.width == 394 and row.height == 17
		and row.title.width == 160
		and row.evidence.point[4] == 166 and row.evidence.width == 228
		and row.evidence.point[4] - row.title.width >= 6
		and 21 + ((index - 1) * 18) + row.height <= 76,
		"semantic catalog row " .. index .. " lost its bounded gutters or bottom clearance")
end
assert(config.messageViewsSemanticCatalogRows[1].semanticTooltipBody:find("Commercial counterevidence", 1, true)
	and config.messageViewsSemanticCatalogRows[1].semanticTooltipBody:find("Trade evidence at threshold", 1, true)
	and config.messageViewsSemanticCatalogRows[2].semanticTooltipBody:find("Commercial services", 1, true)
	and config.messageViewsSemanticCatalogRows[2].semanticTooltipBody:find("enchanting", 1, true),
	"route tooltip did not preserve the complete read-only evidence catalog")
assert(config.viewNameEdit.point[4] == 0 and config.viewKeyEdit.point[4] == 204,
	"two-column label fields exceeded the bounded 408px inspector grid")
assert(config.messageTextSizeLabel.point[4] == 0 and config.messageTextSizeLabel.point[5] == -82
	and config.messageTextSizeEdit.width == 42 and config.messageTextSizeHint.width == 92,
	"text size controls lost their explicit bounded row")
assert(config.messageTextSpacingLabel.point[4] == 204 and config.messageTextSpacingLabel.point[5] == -82
	and config.messageTextSpacingEdit.width == 34 and config.messageTextSpacingEdit.point[4] == 5,
	"line-gap controls escaped or overlapped the bounded SIZE row")
assert(config.messageTextOutlineLabel.point[4] == 0 and config.messageTextOutlineLabel.point[5] == -110
	and config.messageTextOutlineButtons[1].point[2] == config.messageTextOutlineLabel
	and config.messageTextOutlineButtons[1].point[4] == 6,
	"outline controls were not reflowed below the size row")
local outlineLabelWidth = math.ceil(string.len(config.messageTextOutlineLabel:GetText()) * 7 * 1.7)
local outlineRowWidth = outlineLabelWidth + 6
for index, button in ipairs(config.messageTextOutlineButtons) do
	outlineRowWidth = outlineRowWidth + button.width + (index > 1 and 4 or 0)
	assert(button.width >= math.ceil(string.len(button.text:GetText()) * 7 * 1.7) + 10,
		"outline choice " .. tostring(index) .. " clipped its wider live label")
end
assert(outlineRowWidth <= 408
	and math.abs(config.messageTextOutlineLabel.point[5]) >= math.abs(config.messageTextSizeLabel.point[5]) + 24,
	"text size and outline controls can overlap or exceed the minimum inspector width")
assert(config.messageTextResetButton.point[5] == -138
	and config.messageTextAlignmentTitle:GetText() == "ALIGNMENT - ALL TABS"
	and config.messageTextAlignmentTitle.point[5] == -166,
	"text-pane rows did not reserve vertical space after the outline reflow")
assert(config.messageTextColumnAlignmentToggle.label:GetText() == "ALIGN CHANNELS"
	and config.messageTextColumnAlignmentToggle.point[4] == 0
	and config.messageTextColumnAlignmentToggle.point[5] == -188
	and config.messageTextColumnAlignmentToggle.width == 184,
	"channel alignment did not get a clearly labelled bounded control")
assert(config.messageTextSenderColumnAlignmentToggle.label:GetText() == "ALIGN NAMES"
	and config.messageTextSenderColumnAlignmentToggle.point[4] == 0
	and config.messageTextSenderColumnAlignmentToggle.point[5] == -216
	and config.messageTextSenderColumnAlignmentToggle.width == 184,
	"player-name alignment did not get a clearly labelled bounded control")
assert(config.messageTextColumnAlignmentSpacingLabel.point[4] == 204
	and config.messageTextColumnAlignmentSpacingLabel.point[5] == -187
	and config.messageTextSenderColumnAlignmentSpacingLabel.point[4] == 204
	and config.messageTextSenderColumnAlignmentSpacingLabel.point[5] == -215,
	"channel/name gap fields escaped their 20px-gutter alignment grid")
assert(config.messageTextSenderColumnMaxLengthLabel.point[4] == 0
	and config.messageTextSenderColumnMaxLengthLabel.point[5] == -243
	and config.messageTextAlignmentVisibleOnlyToggle.point[4] == 204
	and config.messageTextAlignmentVisibleOnlyToggle.point[5] == -244
	and config.messageTextAlignmentVisibleOnlyToggle.width == 196
	and config.messageTextAlignmentVisibleOnlyToggle.point[4] + config.messageTextAlignmentVisibleOnlyToggle.width <= 400,
	"alignment detail row lost its 8px right gutter inside the 408px pane")
assert(config.messageTextAlignmentVisibleOnlyToggle.label:GetText() == "VISIBLE ONLY"
	and math.ceil(string.len(config.messageTextAlignmentVisibleOnlyToggle.label:GetText()) * 7 * 1.7)
		<= config.messageTextAlignmentVisibleOnlyToggle.width - 18,
	"visible-only alignment control cannot contain its wider live label")
assert(math.abs(config.messageTextSenderColumnAlignmentToggle.point[5]
	- config.messageTextColumnAlignmentToggle.point[5]) >= 28
	and math.abs(config.messageTextSenderColumnMaxLengthLabel.point[5]
	- config.messageTextSenderColumnAlignmentToggle.point[5]) >= 27,
	"alignment rows lost their visible vertical gutters")
for index, row in ipairs(config.railSourceRows) do
	assert(row.point[4] == 0 and row.normalWidth == 402 and row.syncWidth == 330,
		"source row " .. tostring(index) .. " did not use the bounded full-width contents layout")
	assert(row.syncButton.tooltipBody and row.syncButton.tooltipBody:find("AUTO", 1, true)
		and row.syncButton.tooltipBody:find("SYNC", 1, true)
		and row.syncButton.tooltipBody:find("NORMAL", 1, true),
		"source routing mode did not explain AUTO / SYNC / NORMAL")
end
assert(config.railSourceHint:GetText()
	== "X keeps the whole source. Removed expected feeds stay hidden; other routes can add matches.",
	"CONTENTS did not explain that source feeds and matching routes are additive")
assert(config.railSourceRows[4].enabled == false
	and type(config.railSourceRows[4].scripts.OnEnter) == "function",
	"CONTENTS did not disable and explain an impossible Sync source feed")

-- Settings owns the one live rebuild. Config refreshes only the rows and uses
-- wording that makes this an additive feed rather than an exclusive move.
config.railSourceRows[2]:SetValue(true)
assert(sourceOverrides.general["channel:trade"] == true and sourceSetterRebuilds == 1,
	"CONTENTS did not save the checked Trade feed through the live setter")
assert(config.viewsStatus:GetText():find("Keeping every Trade message in GENERAL", 1, true)
	and config.viewsStatus:GetText():find("Routed matches can also appear elsewhere", 1, true),
	"checked-source status did not explain additive live membership")
config.messageViewsResetSourcesButton.scripts.OnClick()
assert(sourceOverrides.general == nil and sourceResetRebuilds == 1
	and config.railSourceRows[2].checked == false,
	"RESET EXPECTED did not restore General's clean source feeds")
assert(config.viewsStatus:GetText() == "Expected source feeds restored for this tab.",
	"source reset did not confirm the clean built-in homes")

-- The X and the row intentionally do different jobs: visibility changes only
-- from the compact X, while clicking the row merely loads its editor.
config.railRows[1].stateToggle:SetValue(false)
assert(settings.views.general == false, "message-view X did not update visibility")
config.railRows[1].scripts.OnClick(config.railRows[1])
assert(settings.views.general == false, "clicking a message-view row changed visibility")

config:ShowPage("rails")
assert(config.activePage == "views", "old rails opener did not route to Message Views")

config:ClearCustomViewEditor()
assert(config.creatingCustomView == true and config.selectedViewId == nil,
	"NEW CUSTOM did not immediately select a custom-view draft")
assert(config.messageViewsSection == "details", "custom draft did not open its details editor")
assert(config.viewTermsLabel:GetText() == "CUSTOM MATCH TERMS - COMMA SEPARATED"
	and config.viewTermsHint:GetText() == "Matches text or channel names; checked feeds are added separately."
	and string.len(config.viewTermsHint:GetText()) <= 66
	and config.messageViewsSemanticCatalogTitle:GetText():find("READ ONLY", 1, true),
	"custom view editor did not keep personal terms distinct from built-in routing")

config:SetMessageViewsSection("sources", true)
assert(config.messageViewsSourcesPane:IsShown() and not config.messageViewsDetailsPane:IsShown(),
	"source inspector did not replace details in the single editor")
assert(config.railSourcePrevious:IsShown() == false and config.railSourceNext:IsShown() == false,
	"custom draft displayed source pagination before it could be saved")

-- Creating a view is a short guided flow: define its label/rules, save once,
-- then land directly in Contents to decide what the new tab receives.
config:SetMessageViewsSection("details", true)
config.viewNameEdit:SetText("Dungeons")
config.viewKeyEdit:SetText("DNG123")
config.viewTermsEdit:SetText("dungeon, keystone")
config:SaveView()
assert(config.selectedViewId == "custom-test" and config.messageViewsSection == "sources"
	and config.messageViewsSourcesPane:IsShown(),
	"new custom view did not advance from label/rules to the contents step")
assert(config.messageViewKeyColumnWidth == 36 and config.messageViewColumnDividerX == 45
	and config.messageViewNameColumnX == 51,
	"six-character custom key did not expand the shared list columns by its measured width")

-- Text appearance is a first-class GLOBAL entry in Views & Tabs. The compact
-- LSM chooser opens directly onto visible registered-font rows; its inherited
-- fallback stays usable even when the media library is absent.
config.allTabsTextButton.scripts.OnClick(config.allTabsTextButton)
assert(config.messageViewsSection == "text" and config.messageViewsTextPane:IsShown(),
	"GLOBAL TEXT did not open the global Smart Chat text editor")
assert(config:GetSmartChatTextAppearanceScope() == "global",
	"global text entry did not retain its explicit all-tabs scope")
assert(config.messageTextColumnAlignmentToggle:IsShown()
	and config.messageTextSenderColumnAlignmentToggle:IsShown(),
	"global text did not expose both independent alignment controls")
config.messageTextColumnAlignmentToggle:SetValue(true)
config.messageTextSenderColumnAlignmentToggle:SetValue(true)
assert(settings.dock.sourceColumnAlignment and settings.dock.senderColumnAlignment,
	"channel/name alignment controls did not update their independent global settings")
config:SetSmartChatTextAppearanceScope("custom-test", true)
assert(config.messageTextColumnAlignmentToggle:IsShown()
	and config.messageTextSenderColumnAlignmentToggle:IsShown()
	and config.messageTextAlignmentTitle:IsShown(),
	"global alignment controls disappeared while editing a per-tab text override")
config:SetSmartChatTextAppearanceScope("global", true)
config.messageTextSpacingEdit:SetText("1.5")
config.messageTextSpacingEdit.scripts.OnEditFocusLost(config.messageTextSpacingEdit)
assert(config.messageTextSpacingEdit:GetText() == "1" and config.viewsStatus:GetText():find("whole number", 1, true),
	"line-gap UI rounded a decimal instead of rejecting it as a noninteger")
config.messageTextChooseFontButton.scripts.OnClick(config.messageTextChooseFontButton)
assert(config.messageTextFontPicker:IsShown() and config.messageTextFontRows[1]:IsShown(),
	"compact font dropdown did not expose the inherited current-chat fallback")
assert(config.messageTextFontCloseButton:IsShown(),
	"compact font dropdown did not expose its close affordance")
assert(config.messageTextFontPicker.mouseWheelEnabled and config.messageTextFontPicker.scripts.OnMouseWheel,
	"font dropdown did not bind mouse-wheel scrolling")
assert(config.messageTextFontPrevious == nil and config.messageTextFontNext == nil,
	"font dropdown retained obsolete pager buttons")
assert(config.messageTextFontSearch and config.messageTextFontSearch.scripts.OnTextChanged,
	"font dropdown did not expose a live search field")
assert(config.messageTextFontPicker.scripts.OnUpdate,
	"font dropdown did not bind outside-click dismissal")
config.messageTextFontPicker.scripts.OnMouseWheel(config.messageTextFontPicker, -1)
assert(config.messageTextFontOffset == 2 and config.messageTextFontRows[1].option.id == "Font 1",
	"font dropdown wheel did not advance its compact list by one face")
config.messageTextFontSearch:SetText("Font 9")
config.messageTextFontSearch.scripts.OnTextChanged(config.messageTextFontSearch)
assert(config.messageTextFontRows[1].option.inherit and config.messageTextFontRows[2].option.id == "Font 9",
	"font dropdown search did not retain inherit and narrow to the matching face")

-- The picker is a root-level overlay. Section and page navigation must close
-- it explicitly rather than depending on a later outside-click OnUpdate.
config:SetMessageViewsSection("details", true)
assert(not config.messageTextFontPicker:IsShown(),
	"leaving the Text inspector did not close the font picker")
config:SetMessageViewsSection("text", true)
config.messageTextChooseFontButton.scripts.OnClick(config.messageTextChooseFontButton)
assert(config.messageTextFontPicker:IsShown(), "font picker did not reopen for page-navigation coverage")
config.pages.about = frame()
config.spamBanReport = frame()
config.spamBanReport:Show()
config:ShowPage("about")
assert(not config.messageTextFontPicker:IsShown(),
	"leaving Message Views did not close the root-level font picker")
assert(not config.spamBanReport:IsShown(),
	"leaving Spam did not close the root-level ban report overlay")

-- Modules is a compact, catalog-backed inspector.  Selection must bring the
-- row into both its own paged list and the expanded nested navigation page.
local modules = {}
for index = 1, 15 do
	modules[index] = {
		id = "module-" .. index,
		label = "Module " .. index,
		status = index == 1 and "smart" or (index == 2 and "adapter" or "native"),
		statusLabel = index == 1 and "RUNS IN CHATTY" or (index == 2 and "NOT YET AVAILABLE" or "RUNS ONLY WITH NATIVE FALLBACK"),
		summary = "Test module " .. index,
		preferenceEnabled = true,
		configPage = index == 1 and "dock" or nil,
	}
end
function addon:GetModuleCatalog()
	return modules
end
function addon:GetModuleCatalogStatus(id)
	for _, module in ipairs(modules) do
		if module.id == id then return module end
	end
end
function addon:SetModuleCatalogPreference(id, enabled)
	local module = self:GetModuleCatalogStatus(id)
	if module then module.preferenceEnabled = enabled and true or false end
	return module ~= nil
end

config:BuildModulesPage()
assert(#config.moduleRows == 10, "modules list lost its compact two-line paging")
config.moduleNavigationButtons = {
	Theme:CreateButton(UIParent, ""), Theme:CreateButton(UIParent, ""),
	Theme:CreateButton(UIParent, ""), Theme:CreateButton(UIParent, ""),
}
config.moduleNavigationCount = Theme:CreateText(UIParent)
config.moduleNavigationPrevious = Theme:CreateButton(UIParent, "<")
config.moduleNavigationNext = Theme:CreateButton(UIParent, ">")
config.modulesNavigationExpanded = true
config:SelectModule("module-15")
assert(config.moduleListPage == 2, "module selection did not reveal its inspector-list row")
assert(config.moduleNavigationPage == 4, "module selection did not reveal its nested navigation row")
assert(config.moduleNavigationButtons[3].moduleId == "module-15", "nested module navigation selected the wrong page")

-- The expandable Modules strip is one flat, bounded list of module names.
-- Its rows must not accumulate indentation and masquerade as nested settings.
config.navigationOrder = { { id = "modules" } }
config.navTitle = frame()
config.navContent = frame()
config.navigationButtons = { modules = frame() }
config.modulesNavigationExpanded = true
config.moduleNavigationCount = frame()
config.moduleNavigationCount:Hide()
config.navFooter = frame()
for _, child in ipairs(config.moduleNavigationButtons) do child:Show() end
config:LayoutNavigation()
assert(config.moduleNavigationButtons[1].point[2] == config.navContent
	and config.moduleNavigationButtons[1].point[4] == 16,
	"first module row lost its single visual indent")
for index = 2, #config.moduleNavigationButtons do
	assert(config.moduleNavigationButtons[index].point[2] == config.navContent
		and config.moduleNavigationButtons[index].point[4] == 16,
		"module navigation stopped using a single fixed indent at row " .. tostring(index))
end
assert(config.navigationButtons.modules.point[2] == config.navContent
	and config.navigationButtons.modules.point[4] == 6,
	"main navigation row inherited a module child indent")

-- The live Settings sidebar is a wheel-only scroll surface. It retains the
-- expandable flat module list without a visible scrollbar or cascading the
-- subsequent ordinary sections to the child indentation.
config.frame = nil
config:BuildFrame()
assert(config.navScroll and config.navContent and config.navScroll.scrollChild == config.navContent,
	"Settings navigation did not create a scroll content surface")
assert(config.navScroll.mouseWheelEnabled and config.navScroll.scripts and config.navScroll.scripts.OnMouseWheel,
	"Settings navigation did not bind mouse-wheel scrolling")
config.modulesNavigationExpanded = true
config:RefreshNavigation()
assert(config.moduleNavigationButtons[1].point[2] == config.navContent
	and config.moduleNavigationButtons[1].point[4] == 16,
	"live module child did not use the fixed nested indent")
assert(config.navigationButtons.safety.point[2] == config.navContent
	and config.navigationButtons.safety.point[4] == 6,
	"Safety inherited an expanded-module indent")
config.navScroll.verticalScrollRange = 300
config.navScroll:SetVerticalScroll(80)
config.navScroll.scripts.OnMouseWheel(config.navScroll, -1)
assert(config.navScroll:GetVerticalScroll() == 114,
	"Settings mouse wheel did not move its hidden scroll surface")

-- The Theme gallery stays compact as the collection grows: cards paginate in
-- place rather than spilling beneath the page workspace, and a pager only
-- appears once it has more than one page to navigate.
config:BuildColorwaysPage()
assert(#config.colorwayCards == #mockThemeNames, "theme gallery omitted a palette")
assert(config.colorwayPagerText:IsShown(), "multi-page theme gallery hid its pager")
assert(config.colorwayCards[1]:IsShown() and config.colorwayCards[12]:IsShown(),
	"first theme page did not show its twelve compact cards")
assert(not config.colorwayCards[13]:IsShown(), "second-page theme card leaked into the first page")
config.colorwayNext.scripts.OnClick()
assert(config.colorwayPage == 2 and config.colorwayCards[13]:IsShown() and not config.colorwayCards[1]:IsShown(),
	"theme pager did not switch the compact gallery page")
config.colorwayCards[13].scripts.OnClick()
assert(settings.colorway == "Verdant Reliquary", "theme card did not apply its palette")

-- Semantic Routes presents only the optional text-inference switches. Exact
-- event/source routing is deliberately absent from this UI. The test also
-- exercises the public classifier API shape without needing the live engine.
function addon:GetSemanticRouteEnabled(routeId)
	return semanticEnabled[routeId]
end
function addon:SetSemanticRouteEnabled(routeId, enabled)
	semanticEnabled[routeId] = enabled and true or false
	return true
end
function addon:AnalyzeSemanticRoute(text)
	assert(type(text) == "string" and text ~= "", "semantic test text was not supplied")
	return {
		category = "groupFinder",
		scores = { groupFinder = 9, trade = 0 },
		threshold = 5,
		signals = { "LF language +3", "Keystone activity +4", "Role request +2" },
	}
end
config:BuildSemanticRoutesPage()
assert(config.semanticRouteToggles.groupFinder.checked and config.semanticRouteToggles.trade.checked
	and config.semanticRouteToggles.pvp.checked,
	"semantic route switches did not load their public settings")
config.semanticRouteToggles.trade:SetValue(false)
assert(semanticEnabled.trade == false,
	"semantic route switch did not use the public setter")
config:RefreshMessageViewSemanticCatalog()
assert(config.messageViewsSemanticCatalogRows[2].title:GetText():find("OFF", 1, true),
	"LABEL & RULES catalog did not refresh the live Trade enabled state")
config.semanticRoutesTestInput:SetText("LF DPS [Keystone: test]")
config:AnalyzeSemanticRouteText()
assert(config.semanticRoutesResult:GetText():find("GROUP FINDER", 1, true)
	and config.semanticRoutesResult:GetText():find("9", 1, true),
	"semantic analyzer did not display its route and score")
assert(config.semanticRoutesEvidence:GetText():find("Keystone activity", 1, true),
	"semantic analyzer did not display its evidence")

local savedSemanticAnalyze = addon.AnalyzeSemanticRoute
function addon:AnalyzeSemanticRoute()
	return {
		category = "general",
		scores = { groupFinder = 6, trade = 5, pvp = 7 },
		threshold = { groupFinder = 7, trade = 6, pvp = 8 },
		signals = {
			groupFinder = { "first LFG clue", "second LFG clue", "third LFG clue must not be shown" },
			trade = { "first Trade clue", "second Trade clue", "third Trade clue must not be shown" },
			pvp = { "first PVP clue", "second PVP clue", "third PVP clue must not be shown" },
		},
	}
end
config:AnalyzeSemanticRouteText()
local generalEvidence = config.semanticRoutesEvidence:GetText()
local _, evidenceLines = string.gsub(generalEvidence, "\n", "\n")
assert(config.semanticRoutesResult:GetText():find("LFG 6", 1, true)
	and config.semanticRoutesResult:GetText():find("PVP 7", 1, true)
	and evidenceLines == 2
	and not generalEvidence:find("third", 1, true),
	"general semantic result was ambiguous or allowed unbounded evidence to overflow")
addon.AnalyzeSemanticRoute = savedSemanticAnalyze

local savedSemanticCatalog = addon.GetSemanticRouteCatalog
addon.GetSemanticRouteCatalog = nil
config:RefreshMessageViewSemanticCatalog()
assert(config.messageViewsSemanticCatalogRows[1].title:GetText() == "SEMANTIC CATALOG UNAVAILABLE"
	and not config.messageViewsSemanticCatalogRows[2]:IsShown()
	and not config.messageViewsSemanticCatalogRows[3]:IsShown(),
	"LABEL & RULES did not fail safely when the optional catalog API was absent")
addon.GetSemanticRouteCatalog = savedSemanticCatalog
config:RefreshMessageViewSemanticCatalog()
assert(config.messageViewsSemanticCatalogRows[2]:IsShown()
	and config.messageViewsSemanticCatalogRows[3]:IsShown(),
	"semantic catalog did not recover after its public API became available")
config.messageViewsSemanticCatalogOpen.scripts.OnClick()
assert(config.activePage == "semantic",
	"FULL ANALYZER did not open the complete Semantic Routes page")

print("Message Views config mock passed")
