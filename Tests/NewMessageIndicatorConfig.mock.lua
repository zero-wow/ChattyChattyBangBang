-- Focused UI contract for the compact NEW-marker appearance disclosure.
-- Run from the addon root with: lua Tests/NewMessageIndicatorConfig.mock.lua

local Frame = {}
Frame.__index = Frame

function Frame:SetPoint(...) self.point = { ... } end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetSize(width, height) self.width, self.height = width, height end
function Frame:SetWidth(width) self.width = width end
function Frame:SetHeight(height) self.height = height end
function Frame:SetAllPoints() end
function Frame:SetJustifyH() end
function Frame:SetTexture() end
function Frame:SetText(value) self.textValue = tostring(value or "") end
function Frame:GetText() return self.textValue or "" end
function Frame:SetTextColor() end
function Frame:SetVertexColor() end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown ~= false end
function Frame:SetScript(name, callback)
	self.scripts = self.scripts or {}
	self.scripts[name] = callback
end
function Frame:HookScript(name, callback)
	self.scripts = self.scripts or {}
	self.scripts[name] = callback
end
function Frame:ClearFocus() self.clearedFocus = true end
function Frame:CreateTexture() return setmetatable({ shown = true }, Frame) end
function Frame:CreateFontString() return setmetatable({ shown = true }, Frame) end

local function frame()
	return setmetatable({ shown = true }, Frame)
end

function CreateFrame()
	return frame()
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
function Theme:CreateText()
	return frame()
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
	return button
end
function Theme:CreateTightButton(parent, text, height, emphasis)
	-- Stress the real Config layout with a substantially wider live font. The
	-- reviewed tab row must contain complete labels without ellipses or overlap.
	local intrinsic = math.ceil(string.len(tostring(text or "")) * 7 * 1.7)
	return self:CreateButton(parent, text, math.max(height or 20, intrinsic + 10), height, emphasis)
end
function Theme:CreateCompactToggle(parent, text, width)
	local toggle = self:CreateButton(parent, text, width or 146, 20)
	function toggle:SetValue(value, silent)
		self.value = value and true or false
		if not silent and self.OnValueChanged then
			self:OnValueChanged(self.value)
		end
	end
	return toggle
end
function Theme:CreateEditBox()
	return frame()
end
function Theme:RegisterTexture() end
function Theme:RegisterFrame() end
function Theme:ApplyFrame() end
function Theme:RegisterRefreshCallback() end

local appearance = {
	position = { anchor = "header", point = "TOPRIGHT", x = 0, y = 0 },
	alpha = 1,
	scale = 1,
	font = "default",
	fontSize = 0,
	outline = "NONE",
	color = { mode = "theme", theme = "goldBright" },
	background = { mode = "theme", theme = "accentSoft" },
	border = { mode = "theme", theme = "gold" },
}
local settings = {
	textAppearance = { schema = 2, size = 0, outline = "INHERIT", spacing = 1 },
	dock = {
		visible = true,
		showComposer = true,
		composerAutoHide = false,
		railOrientation = "vertical",
		railVisibility = "always",
		headerVisibility = "hover",
		showScrollButtons = true,
		compactHeader = true,
		newMessages = { enabled = true, showCount = true, maxCount = 99, appearance = appearance },
		unreadCountAppearance = { schema = 1, alpha = 1, fontSize = 0 },
	},
}

ChattyChattyBangBang = { Theme = Theme }
local addon = ChattyChattyBangBang
function addon:GetSmartSettings() return settings end
function addon:GetNewMessageIndicatorSettings() return settings.dock.newMessages end
function addon:SetNewMessageIndicatorEnabled(value) settings.dock.newMessages.enabled = value and true or false return true end
function addon:SetNewMessageIndicatorShowCount(value) settings.dock.newMessages.showCount = value and true or false return true end
function addon:SetNewMessageIndicatorMaxCount(value)
	value = tonumber(value)
	if not value then return false end
	settings.dock.newMessages.maxCount = value
	return true, value
end
function addon:GetNewMessageIndicatorAppearanceSettings() return appearance end
function addon:GetNewMessageIndicatorAppearanceOptions()
	return {
		fonts = {
			{ id = "default", label = "DEFAULT UI" }, { id = "chat", label = "CHAT FONT" },
			{ id = "system", label = "SYSTEM" }, { id = "number", label = "NUMERIC" },
		},
		outlines = {
			{ id = "NONE", label = "NONE" }, { id = "OUTLINE", label = "OUTLINE" }, { id = "THICKOUTLINE", label = "THICK" },
		},
		themeColors = {
			{ id = "goldBright", label = "GOLD" }, { id = "gold", label = "WARM GOLD" },
			{ id = "accent", label = "ACCENT" }, { id = "text", label = "TEXT" },
			{ id = "success", label = "SUCCESS" }, { id = "warning", label = "WARNING" },
			{ id = "danger", label = "DANGER" },
		},
	}
end
function addon:SetNewMessageIndicatorAppearance(patch)
	for key, value in pairs(patch or {}) do
		appearance[key] = value
	end
	return true, appearance
end
function addon:SetNewMessageIndicatorPosition(position)
	if position == "header" then
		appearance.position = { anchor = "header", point = "TOPRIGHT", x = 0, y = 0 }
		return true, appearance.position
	end
	return false, "invalid-position"
end
function addon:ResetNewMessageIndicatorAppearance()
	appearance.position = { anchor = "header", point = "TOPRIGHT", x = 0, y = 0 }
	appearance.alpha, appearance.scale = 1, 1
	appearance.font, appearance.fontSize, appearance.outline = "default", 0, "NONE"
	appearance.color = { mode = "theme", theme = "goldBright" }
	appearance.background = { mode = "theme", theme = "accentSoft" }
	appearance.border = { mode = "theme", theme = "gold" }
	return true, appearance
end
function addon:SetNewMessageIndicatorPreviewActive(active)
	self.previewActive = active and true or false
	return true
end
function addon:GetRailUnreadCountAppearanceSettings()
	return {
		alpha = settings.dock.unreadCountAppearance.alpha,
		fontSize = settings.dock.unreadCountAppearance.fontSize,
		minimumFontSize = 8,
		maximumFontSize = 16,
	}
end
function addon:SetRailUnreadCountAlpha(value)
	settings.dock.unreadCountAppearance.alpha = value
	return true, value
end
function addon:SetRailUnreadCountFontSize(value)
	settings.dock.unreadCountAppearance.fontSize = value
	return true, value
end
function addon:ResetRailUnreadCountAppearance()
	settings.dock.unreadCountAppearance.alpha = 1
	settings.dock.unreadCountAppearance.fontSize = 0
	return true
end
function addon:GetSmartChatTextAppearance(scope)
	assert(scope == "global", "Dock readability requested a non-global text appearance")
	return settings.textAppearance
end
function addon:SetSmartChatTextAppearance(scope, patch)
	assert(scope == "global", "Dock readability changed a non-global text appearance")
	for key, value in pairs(patch or {}) do settings.textAppearance[key] = value end
	return true, settings.textAppearance
end

local chatColors = {
	{ id = "say", label = "SAY", group = "LOCAL", r = 0.8, g = 0.8, b = 0.8 },
	{ id = "party", label = "PARTY", group = "GROUP", r = 0.4, g = 0.8, b = 1 },
}
function addon:GetChatColorDefinitions() return chatColors end
function addon:GetChatColorDefinition(id)
	for _, definition in ipairs(chatColors) do
		if definition.id == id then return definition end
	end
end
function addon:SetChatColor(id, r, g, b)
	local definition = self:GetChatColorDefinition(id)
	if not definition then return false, "not-found" end
	definition.r, definition.g, definition.b = r, g, b
	return true
end

dofile("Core/Config.lua")

local config = addon.CustomConfig
config.pages = {}
config.navigationButtons = {}
config.content = frame()
config:BuildDockPage()

local categoryOrder = { "window", "tabs", "input", "readability", "unread" }
local categoryWidth = 0
for index, id in ipairs(categoryOrder) do
	local button = config.dockLayoutCategoryButtons[id]
	categoryWidth = categoryWidth + button.width + (index > 1 and 5 or 0)
	assert(button.width >= math.ceil(string.len(button.text:GetText()) * 7 * 1.7) + 10,
		"Chat Window category " .. id .. " clipped its wide-font label")
end
assert(config.dockLayoutCategoryButtons.input.text:GetText() == "INPUT"
	and categoryWidth <= 636,
	"Chat Window category tabs overflow the 636px page under wider live font metrics")

assert(config.dockLayoutCategory == "window" and config.dockVisibleToggle:IsShown(),
	"Chat Window did not open on the focused Window inspector")
assert(not config.dockMarkerAppearanceToggle:IsShown(),
	"Unread controls leaked into the Window inspector")
config.dockLayoutCategoryButtons.unread.scripts.OnClick(config.dockLayoutCategoryButtons.unread)
assert(config.dockMarkerAppearanceToggle:IsShown(), "appearance disclosure was not exposed when its API exists")
assert(config.dockMarkerAppearanceToggle.width == 96 and config.dockMarkerAppearanceToggle.point[4] == 402
	and config.dockUnreadCountAppearanceToggle.width == 112 and config.dockUnreadCountAppearanceToggle.point[4] == 506
	and (506 - (402 + 96)) == 8 and (644 - (506 + 112)) == 26,
	"Unread disclosure buttons did not reserve fixed text padding, an 8px gutter, and a safe right edge")
assert(not config.dockMarkerPositionValue:IsShown(), "advanced marker controls were visible before Customize")

config.dockMarkerAppearanceToggle.scripts.OnClick(config.dockMarkerAppearanceToggle)
assert(config.dockMarkerAppearanceExpanded and config.dockMarkerPositionValue:IsShown(),
	"Customize did not reveal the compact marker editor")
assert(not config.dockUnreadCountFontSizeEdit:IsShown(),
	"Tab unread-count controls overlapped the marker editor")
assert(not config.dockSizeTitle:IsShown(), "Window size leaked into the expanded Unread inspector")

config.dockMarkerFontButtons[2].scripts.OnClick(config.dockMarkerFontButtons[2])
assert(appearance.font == "chat", "font option did not use the appearance patch API")
assert(addon.previewActive and config.dockMarkerPreviewActive,
	"an appearance edit did not automatically turn on the transient live marker preview")
config.dockMarkerScaleEdit:SetText("125")
config.dockMarkerScaleEdit.scripts.OnEditFocusLost(config.dockMarkerScaleEdit)
assert(appearance.scale == 1.25, "scale percent was not converted to the appearance API value")
config.dockMarkerAlphaEdit:SetText("65")
config.dockMarkerAlphaEdit.scripts.OnEditFocusLost(config.dockMarkerAlphaEdit)
assert(appearance.alpha == 0.65, "alpha percent was not converted to the appearance API value")

config.dockMarkerColorTargetButtons[2].scripts.OnClick(config.dockMarkerColorTargetButtons[2])
config.dockMarkerColorEdits[1]:SetText("12")
config.dockMarkerColorEdits[2]:SetText("34")
config.dockMarkerColorEdits[3]:SetText("56")
config.dockMarkerColorEdits[4]:SetText("78")
config.dockMarkerColorEdits[4].scripts.OnEditFocusLost(config.dockMarkerColorEdits[4])
assert(appearance.background.mode == "custom" and appearance.background.r == (12 / 255)
	and appearance.background.a == 0.78, "custom RGBA path did not target the selected background layer")

appearance.position = { anchor = "dock", point = "BOTTOMLEFT", x = 19, y = 11 }
config.dockMarkerResetPositionButton.scripts.OnClick(config.dockMarkerResetPositionButton)
assert(appearance.position.anchor == "header", "Title Bar action did not reset only the marker position")
assert(appearance.background.mode == "custom", "Title Bar action reset marker styling instead of position only")

config.dockMarkerResetAppearanceButton.scripts.OnClick(config.dockMarkerResetAppearanceButton)
assert(appearance.font == "default" and appearance.background.mode == "theme" and not addon.previewActive,
	"reset did not restore marker appearance and clear its temporary preview")
assert(settings.dock.newMessages.enabled and settings.dock.newMessages.showCount and settings.dock.newMessages.maxCount == 99,
	"appearance reset changed the independent marker behavior settings")

config.dockUnreadCountAppearanceToggle.scripts.OnClick(config.dockUnreadCountAppearanceToggle)
assert(config.dockUnreadCountAppearanceExpanded and config.dockUnreadCountFontSizeEdit:IsShown()
	and not config.dockMarkerPositionValue:IsShown(),
	"Tab Counts did not replace the marker editor in the shared inspector")
config.dockUnreadCountFontSizeEdit:SetText("13")
config.dockUnreadCountFontSizeEdit.scripts.OnEditFocusLost(config.dockUnreadCountFontSizeEdit)
config.dockUnreadCountAlphaEdit:SetText("35")
config.dockUnreadCountAlphaEdit.scripts.OnEditFocusLost(config.dockUnreadCountAlphaEdit)
assert(settings.dock.unreadCountAppearance.fontSize == 13
	and settings.dock.unreadCountAppearance.alpha == 0.35,
	"tab unread-count font size or text opacity did not use its public API")
config.dockUnreadCountResetButton.scripts.OnClick(config.dockUnreadCountResetButton)
assert(settings.dock.unreadCountAppearance.fontSize == 0
	and settings.dock.unreadCountAppearance.alpha == 1,
	"tab unread-count reset changed neither independent appearance setting")
config.dockUnreadCountAppearanceToggle.scripts.OnClick(config.dockUnreadCountAppearanceToggle)
assert(not config.dockUnreadCountAppearanceExpanded and not config.dockUnreadCountFontSizeEdit:IsShown(),
	"Tab Counts did not collapse its advanced controls")

assert(not config.dockMarkerAppearanceExpanded and not config.dockMarkerPositionValue:IsShown(),
	"opening Tab Counts did not close the marker editor")
config.dockMarkerAppearanceToggle.scripts.OnClick(config.dockMarkerAppearanceToggle)
assert(config.dockMarkerAppearanceExpanded and config.dockMarkerPositionValue:IsShown(),
	"Marker Style did not reopen after Tab Counts closed")
config.dockMarkerAppearanceToggle.scripts.OnClick(config.dockMarkerAppearanceToggle)
assert(not config.dockMarkerAppearanceExpanded and not config.dockMarkerPositionValue:IsShown(),
	"Marker Style did not collapse its advanced controls")
config.dockLayoutCategoryButtons.window.scripts.OnClick(config.dockLayoutCategoryButtons.window)
assert(config.dockSizeTitle:IsShown() and config.dockSizeTitle.point[5] == -339,
	"Window inspector did not restore its independent size controls")
assert(config.dockBackgroundAlphaEdit:IsShown() and config.dockBorderAlphaEdit:IsShown()
	and config.dockOverallAlphaEdit:IsShown(),
	"Window inspector did not expose independent background, border, and whole-UI opacity")
config.dockBackgroundAlphaEdit:SetText("55")
config.dockBackgroundAlphaEdit.scripts.OnEditFocusLost(config.dockBackgroundAlphaEdit)
config.dockBorderAlphaEdit:SetText("70")
config.dockBorderAlphaEdit.scripts.OnEditFocusLost(config.dockBorderAlphaEdit)
config.dockOverallAlphaEdit:SetText("85")
config.dockOverallAlphaEdit.scripts.OnEditFocusLost(config.dockOverallAlphaEdit)
assert(settings.dock.transparency.backgroundAlpha == 0.55
	and settings.dock.transparency.borderAlpha == 0.70
	and settings.dock.transparency.overallAlpha == 0.85,
	"independent window opacity controls did not persist their fallback values")

config.dockLayoutCategoryButtons.input.scripts.OnClick(config.dockLayoutCategoryButtons.input)
assert(config.dockHistoryToggle:IsShown() and config.dockHistoryLinesEdit:IsShown()
	and config.dockClearHistoryButton:IsShown(),
	"Input & Controls did not expose received-chat history as one bounded task")
assert(config.dockScrollToggle.text:GetText() == "SLIM SCROLLBAR",
	"Input & Controls still described the removed +/- buttons instead of the thumb-only scrollbar")
config.dockHistoryLinesEdit:SetText("2500")
config.dockHistoryLinesEdit.scripts.OnEditFocusLost(config.dockHistoryLinesEdit)
assert(settings.historyCapacity == 2500, "history lines/source did not persist through the fallback path")
config.dockHistoryToggle:SetValue(false)
assert(settings.persistHistory == false, "restore-after-login toggle did not update history persistence")

config.dockLayoutCategoryButtons.readability.scripts.OnClick(config.dockLayoutCategoryButtons.readability)
assert(config.dockResponsiveMetadataToggle:IsShown() and config.dockMessageBandsToggle:IsShown()
	and config.dockMessageBandsScrollbarToggle:IsShown()
	and config.dockMessageBandAlphaEdit:IsShown() and config.dockLineSpacingEdit:IsShown(),
	"Readability did not isolate responsive metadata and alternating-message controls")
assert(config.dockMessageBandsToggle.text:GetText() == "ALTERNATING ROWS"
	and config.dockMessageBandsScrollbarToggle.text:GetText() == "UNDER SCROLLBAR",
	"message band toggles lost their compact wide-font-safe labels")
assert(config.dockMessageBandsScrollbarToggle.width == 230
	and config.dockMessageBandsScrollbarToggle.point[2] == config.dockMessageBandsToggle
	and config.dockMessageBandsScrollbarToggle.point[3] == "RIGHT"
	and config.dockMessageBandsScrollbarToggle.point[4] == 3,
	"full-bleed row control did not retain its same-row gutter and reviewed width")
config.dockLineSpacingEdit:SetText("4")
config.dockLineSpacingEdit.scripts.OnEditFocusLost(config.dockLineSpacingEdit)
assert(settings.textAppearance.spacing == 4,
	"Readability's discoverable global line-gap control did not apply to all tabs")
config.dockLineSpacingEdit:SetText("1.5")
config.dockLineSpacingEdit.scripts.OnEditFocusLost(config.dockLineSpacingEdit)
assert(settings.textAppearance.spacing == 4 and config.dockLineSpacingEdit:GetText() == "4",
	"Readability rounded a decimal line gap instead of rejecting it truthfully")
config.dockResponsiveMetadataToggle:SetValue(false)
assert(settings.dock.responsiveMetadata == false, "responsive metadata lock did not persist")
config.dockMessageBandsToggle:SetValue(true)
config.dockMessageBandsScrollbarToggle:SetValue(true)
config.dockMessageBandExtentButtons.afterPlayer.scripts.OnClick(config.dockMessageBandExtentButtons.afterPlayer)
config.dockMessageBandAlphaEdit:SetText("22")
config.dockMessageBandAlphaEdit.scripts.OnEditFocusLost(config.dockMessageBandAlphaEdit)
assert(settings.dock.messageBands.enabled and settings.dock.messageBands.extent == "afterPlayer"
	and settings.dock.messageBands.extendUnderScrollbar == true
	and settings.dock.messageBands.alpha == 0.22,
	"alternating logical-message settings did not persist through the fallback path")
assert(config.dockLayoutCategoryButtons.window._configTab
	and config.dockLayoutCategoryButtons.readability._configTabSelected,
	"Chat Window task navigation still looks like unrelated action buttons")

config.dockColorsTabButton.scripts.OnClick(config.dockColorsTabButton)
assert(config.dockSection == "colors" and config.dockColorsPanel:IsShown(), "Chat Colors tab did not open inside Chat Window")
assert(config.selectedDockChatColorId == "say", "Chat Colors did not select the first native source")
config.dockChatColorEdits[1]:SetText("10")
config.dockChatColorEdits[2]:SetText("20")
config.dockChatColorEdits[3]:SetText("30")
config.dockChatColorApplyButton.scripts.OnClick(config.dockChatColorApplyButton)
assert(chatColors[1].r == (10 / 255) and chatColors[1].g == (20 / 255) and chatColors[1].b == (30 / 255),
	"Chat Colors editor did not use the native color API")
config.dockLayoutTabButton.scripts.OnClick(config.dockLayoutTabButton)
assert(config.dockSection == "layout" and not config.dockColorsPanel:IsShown(), "Layout tab did not return from Chat Colors")
config.dockHideSocialToggle:SetValue(true)
assert(settings.dock.hideSocialButton == true, "Hide Social Button did not persist in Chat Window settings")

print("New-message indicator config mock passed")
