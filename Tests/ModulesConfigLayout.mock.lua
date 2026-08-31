-- Focused no-client contract for the human-facing Modules workspace.
--
-- This test intentionally describes the next Config layout before that layout
-- lands. Run from the addon root with:
--   lua Tests/ModulesConfigLayout.mock.lua

local Frame = {}
Frame.__index = Frame

local function frame(parent)
	return setmetatable({ parent = parent, shown = true, enabled = true }, Frame)
end

function Frame:SetPoint(...)
	self.point = { ... }
end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetAllPoints(target) self.allPoints = target or true end
function Frame:SetSize(width, height) self.width, self.height = width, height end
function Frame:SetWidth(width) self.width = width end
function Frame:SetHeight(height) self.height = height end
function Frame:GetWidth() return self.width or 0 end
function Frame:GetHeight() return self.height or 0 end
function Frame:SetText(value) self.textValue = tostring(value or "") end
function Frame:GetText() return self.textValue or "" end
function Frame:GetStringWidth() return string.len(self:GetText()) * 6 end
function Frame:SetTextColor() end
function Frame:SetJustifyH() end
function Frame:SetTexture() end
function Frame:SetVertexColor() end
function Frame:SetAlpha() end
function Frame:SetFrameStrata() end
function Frame:SetToplevel() end
function Frame:SetMovable() end
function Frame:RegisterForDrag() end
function Frame:EnableMouse() end
function Frame:Raise() end
function Frame:StartMoving() end
function Frame:StopMovingOrSizing() end
function Frame:SetAutoFocus() end
function Frame:SetMultiLine() end
function Frame:SetFontObject() end
function Frame:SetTextInsets() end
function Frame:ClearFocus() end
function Frame:SetFocus() end
function Frame:SetMaxLetters() end
function Frame:SetScrollChild(child) self.scrollChild = child end
function Frame:EnableMouseWheel(enabled) self.mouseWheelEnabled = enabled and true or false end
function Frame:SetVerticalScroll(value) self.verticalScroll = tonumber(value) or 0 end
function Frame:GetVerticalScroll() return self.verticalScroll or 0 end
function Frame:GetVerticalScrollRange() return self.verticalScrollRange or 0 end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown ~= false end
function Frame:Enable() self.enabled = true end
function Frame:Disable() self.enabled = false end
function Frame:IsEnabled() return self.enabled ~= false end
function Frame:SetScript(name, callback)
	self.scripts = self.scripts or {}
	self.scripts[name] = callback
end
function Frame:HookScript(name, callback)
	self.scripts = self.scripts or {}
	self.scripts[name] = callback
end
function Frame:CreateTexture()
	return frame(self)
end
function Frame:CreateFontString()
	return frame(self)
end

function CreateFrame(_, _, parent)
	return frame(parent)
end

UIParent = frame()
GameFontNormalLarge = {}
GameFontNormal = {}
GameFontNormalSmall = {}
GameFontHighlightSmall = {}

local Theme = {
	texts = {},
	frames = {},
	NO_BORDER = "none",
	ICON_PATH = "Interface\\Icons\\INV_Misc_QuestionMark",
}

function Theme:CreatePanel(parent)
	return frame(parent)
end
function Theme:CreateQuietPanel(parent)
	return frame(parent)
end
function Theme:CreateText(parent)
	return frame(parent)
end
function Theme:CreateButton(parent, text, width, height)
	local button = frame(parent)
	button:SetSize(width or 20, height or 20)
	button.text = frame(button)
	button.text:SetText(text)
	function button:SetLabel(value) self.text:SetText(value) end
	function button:SetTheme(fill, border, color) self.theme = { fill, border, color } end
	function button:SetHoverTheme(fill, border, color) self.hoverTheme = { fill, border, color } end
	function button:SetTooltip(title, body)
		self.tooltipTitle = title
		self.tooltipBody = body
	end
	return button
end
function Theme:CreateTightButton(parent, text, height)
	local button = self:CreateButton(parent, text, height or 20, height or 20)
	button:SetWidth(math.max(height or 20, button.text:GetStringWidth() + 6))
	return button
end
function Theme:CreateCompactToggle(parent, label, width)
	local toggle = frame(parent)
	toggle:SetWidth(width or 180)
	toggle.label = frame(toggle)
	toggle.label:SetText(label)
	toggle.box = frame(toggle)
	toggle.mark = frame(toggle)
	function toggle:SetValue(value, silent)
		self.checked = value and true or false
		self.mark:SetText(self.checked and "X" or "")
		if not silent and self.OnValueChanged then self:OnValueChanged(self.checked) end
	end
	function toggle:SetTooltip(title, body)
		self.tooltipTitle = title
		self.tooltipBody = body
	end
	return toggle
end
function Theme:CreateEditBox(parent, width, height)
	local edit = frame(parent)
	edit:SetSize(width or 180, height or 20)
	return edit
end
function Theme:RegisterTexture() end
function Theme:RegisterFrame() end
function Theme:RegisterRefreshCallback() end
function Theme:ApplyFrame() end
function Theme:SetQuietRowState(button, selected) button.selected = selected and true or false end
function Theme:SetButtonRole(button, role, selected)
	button.role = role
	button.selected = selected and true or false
end
function Theme:GetColor() return 1, 1, 1, 1 end
function Theme:GetPalette()
	return {
		background = { 0, 0, 0, 1 }, surface = { 0, 0, 0, 1 },
		surfaceRaised = { 0, 0, 0, 1 }, accentSoft = { 0, 0, 0, 1 },
		gold = { 1, 0.8, 0.2, 1 }, accent = { 0.6, 0.4, 1, 1 },
	}
end

local modules = {}
for index = 1, 11 do
	modules[#modules + 1] = {
		id = index == 2 and "tell-target" or ("smart-" .. index),
		label = index == 1 and "Automatic Whisper Windows"
			or (index == 2 and "Tell Target (/tt)" or ("Chat Feature " .. index)),
		navLabel = index == 1 and "Whisper Windows" or nil,
		status = "smart",
		category = "Chat Features",
		statusLabel = "RUNS IN CHATTY",
		summary = "This feature runs on Chatty's own chat surface.",
		configPage = index == 2 and "conversations" or "dock",
		configSection = index == 2 and "opening" or nil,
		smartSetting = index == 1 and "composerAutoHide" or (index == 2 and "tellTargetEnabled" or nil),
	}
end
for index = 1, 11 do
	modules[#modules + 1] = {
		id = "native-" .. index,
		label = "Legacy Feature " .. index,
		status = "native",
		category = "Legacy Compatibility",
		statusLabel = "RUNS ONLY WITH NATIVE FALLBACK",
		summary = "This copied feature is dormant while Chatty owns chat.",
		preferenceEnabled = true,
	}
end
modules[#modules + 1] = {
	id = "adapter-1",
	label = "Mousewheel Scroll",
	navLabel = "Mousewheel",
	status = "adapter",
	category = "Legacy Compatibility",
	statusLabel = "NOT YET AVAILABLE",
	summary = "This feature has not yet been rebuilt for Chatty.",
	preferenceEnabled = true,
}

ChattyChattyBangBang = {
	Theme = Theme,
	VERSION = "test",
}
local addon = ChattyChattyBangBang

function addon:GetVersion() return "test" end
function addon:IsEnabled() return true end
function addon:GetSmartSettings() return { enabled = true } end
function addon:GetModuleCatalog() return modules end
function addon:GetModuleCatalogStatus(id)
	for _, module in ipairs(modules) do
		if module.id == id then return module end
	end
end
function addon:SetModuleCatalogPreference(id, enabled)
	local module = self:GetModuleCatalogStatus(id)
	if not module or module.status == "smart" then return false end
	module.preferenceEnabled = enabled and true or false
	return true, module
end
function addon:GetComposerAutoHideSetting() return true end
function addon:SetComposerAutoHide(value) self.composerAutoHide = value and true or false end
function addon:GetTellTargetSettings() return { enabled = self.tellTargetEnabled ~= false } end
function addon:SetTellTargetEnabled(value) self.tellTargetEnabled = value and true or false return true, self.tellTargetEnabled end

dofile("Core/Config.lua")

local failures = {}
local function expect(value, message)
	if not value then failures[#failures + 1] = message end
end
local function shown(widget)
	return widget and widget:IsShown() or false
end
local function buttonText(button)
	return button and button.text and button.text:GetText() or ""
end
local function pointX(widget)
	return widget and widget.point and tonumber(widget.point[4]) or nil
end

local config = addon.CustomConfig
config:BuildFrame()
config.navigationButtons.modules.scripts.OnClick(config.navigationButtons.modules)

-- The top-level choice is about player goals, not implementation taxonomy.
local modeButtons = config.moduleFilterButtons or {}
local modeCount = 0
for _ in pairs(modeButtons) do modeCount = modeCount + 1 end
expect(modeCount == 2, "Modules must expose exactly two user-facing modes")
expect(buttonText(modeButtons.features) == "CHAT FEATURES",
	"first mode must be CHAT FEATURES")
expect(buttonText(modeButtons.legacy) == "LEGACY COMPATIBILITY",
	"second mode must be LEGACY COMPATIBILITY")
expect(config.moduleFilter == "features", "CHAT FEATURES must be the default mode")

-- The list is compact but gives the full human status its own second line.
expect(config.moduleListPanel ~= nil, "Modules must retain a named list panel for layout checks")
expect(config.moduleListPanel and config.moduleListPanel.width == 248,
	"module list must be 248 pixels wide")
expect(#(config.moduleRows or {}) == 10, "module list must use ten compact rows per page")
for index, row in ipairs(config.moduleRows or {}) do
	expect(row.width == 232 and row.height == 29,
		"module row " .. tostring(index) .. " must be 232x29")
	expect(row.label and row.status and row.label ~= row.status,
		"module row " .. tostring(index) .. " must separate name and status lines")
	expect(row.label and row.status and row.label.point and row.status.point
		and row.label.point[1] ~= row.status.point[1],
		"module row " .. tostring(index) .. " must place name and status on distinct vertical lines")
end
expect(config.moduleRows and config.moduleRows[1]
	and config.moduleRows[1].status:GetText() == "RUNS IN CHATTY",
	"Chatty feature rows must use the human RUNS IN CHATTY status")

-- The list and fixed inspector must fit the 636px work grid with an 8px gap.
local listX = pointX(config.moduleListPanel)
local inspectorX = pointX(config.moduleInspectorPanel)
local listRight = listX and config.moduleListPanel and (listX + config.moduleListPanel.width) or nil
local inspectorRight = inspectorX and config.moduleInspectorPanel
	and (inspectorX + config.moduleInspectorPanel.width) or nil
expect(config.moduleInspectorPanel ~= nil, "Modules must retain a fixed inspector panel")
expect(listRight and inspectorX and listRight <= inspectorX - 8,
	"module list and inspector must retain an 8px separation")
expect(inspectorRight and inspectorRight <= 644,
	"module inspector must remain inside the page's x=644 right bound")
expect(config.moduleInspectorSummary and config.moduleInspectorSummary.height == 58,
	"module summary needs a fixed 58px region so it cannot overlap actions")

-- Selecting across categories must reveal the feature in the correct mode.
config:SelectModule("native-1")
expect(config.moduleFilter == "legacy",
	"selecting a native feature must switch to LEGACY COMPATIBILITY")
expect(config.moduleInspectorStatus:GetText() == "RUNS ONLY WITH NATIVE FALLBACK",
	"native feature inspector must use the full human status")
expect(shown(config.modulePreferenceToggle) and not shown(config.moduleSmartToggle)
	and not shown(config.moduleOpenConfig),
	"legacy inspector controls must not overlap Chatty-only controls")

config:SelectModule("smart-1")
expect(config.moduleFilter == "features",
	"selecting a Chatty feature must switch to CHAT FEATURES")
expect(config.moduleInspectorStatus:GetText() == "RUNS IN CHATTY",
	"Chatty feature inspector must use the full human status")
expect(not shown(config.modulePreferenceToggle) and shown(config.moduleSmartToggle),
	"Chatty inspector must not expose the native-fallback preference")

config:SelectModule("tell-target")
expect(shown(config.moduleSmartToggle)
	and config.moduleSmartToggle.label:GetText() == "ENABLE /TT TELL TARGET",
	"Tell Target did not expose its live Chatty setting in the module inspector")
config.moduleSmartToggle:SetValue(false)
expect(addon.tellTargetEnabled == false,
	"Tell Target module toggle did not use its public Smart setting")
local openedPage, openedSection
local originalShowPage = config.ShowPage
local originalSetMessengerSection = config.SetMessengerSection
config.ShowPage = function(self, pageId)
	openedPage = pageId == "conversations" and "messenger" or pageId
	self.activePage = openedPage
end
config.SetMessengerSection = function(_, section)
	openedSection = section
end
config.moduleOpenConfig.scripts.OnClick()
config.ShowPage = originalShowPage
config.SetMessengerSection = originalSetMessengerSection
expect(openedPage == "messenger" and openedSection == "opening",
	"Tell Target module did not open Messenger directly at its shortcut settings")

config:SelectModule("adapter-1")
expect(config.moduleFilter == "legacy",
	"selecting an unavailable feature must switch to LEGACY COMPATIBILITY")
expect(config.moduleInspectorStatus:GetText() == "NOT YET AVAILABLE",
	"unported feature inspector must say NOT YET AVAILABLE")
expect(not (shown(config.modulePreferenceToggle) and shown(config.moduleSmartToggle)),
	"adapter inspector must not stack incompatible control sets")

-- Each pager shows only directions that can actually move to another page.
config.moduleFilter = "features"
config.moduleListPage = 1
config:RefreshModulesPage(true)
expect(not shown(config.moduleListPrevious) and shown(config.moduleListNext),
	"first module page must hide Previous and show Next")
config.moduleListPage = 2
config:RefreshModulesPage(true)
expect(shown(config.moduleListPrevious) and not shown(config.moduleListNext),
	"last module page must show Previous and hide Next")

-- Expanded Settings navigation remains one flat child level. Compact labels
-- fit the rail, while the tooltip preserves the full feature name and status.
config.modulesNavigationExpanded = true
config.moduleNavigationPage = 1
config:RefreshNavigation()
local firstChild = config.moduleNavigationButtons and config.moduleNavigationButtons[1]
expect(firstChild and firstChild.label:GetText() == "WHISPER WINDOWS",
	"sidebar child must use the compact navLabel")
local fullTooltip = firstChild and table.concat({
	tostring(firstChild.tooltipText or ""),
	tostring(firstChild.tooltipTitle or ""),
	tostring(firstChild.tooltipBody or ""),
}, " ") or ""
expect(fullTooltip:find("Automatic Whisper Windows", 1, true)
	and fullTooltip:find("RUNS IN CHATTY", 1, true),
	"sidebar tooltip must preserve the full feature name and human status")
for index, child in ipairs(config.moduleNavigationButtons or {}) do
	expect(child.point and child.point[2] == config.navContent and pointX(child) == 16,
		"module sidebar child " .. tostring(index) .. " must use one fixed x=16 indent")
end
expect(config.navigationButtons.safety.point[2] == config.navContent
	and pointX(config.navigationButtons.safety) == 6,
	"ordinary navigation rows must return to x=6 after expanded modules")

config.moduleNavigationPage = 1
config:RefreshNavigation()
expect(not shown(config.moduleNavigationPrevious) and shown(config.moduleNavigationNext),
	"first sidebar module page must hide Previous and show Next")
config.moduleNavigationPage = math.ceil(#modules / 4)
config:RefreshNavigation()
expect(shown(config.moduleNavigationPrevious) and not shown(config.moduleNavigationNext),
	"last sidebar module page must show Previous and hide Next")

-- A sidebar child selection uses the same category-aware selection path.
local adapterPage = math.ceil(#modules / 4)
config.moduleNavigationPage = adapterPage
config:RefreshNavigation()
local adapterChild
for _, child in ipairs(config.moduleNavigationButtons or {}) do
	if child.moduleId == "adapter-1" then adapterChild = child break end
end
expect(adapterChild and adapterChild.scripts and adapterChild.scripts.OnClick,
	"sidebar must expose a clickable child for the unavailable feature")
if adapterChild and adapterChild.scripts and adapterChild.scripts.OnClick then
	config.moduleFilter = "features"
	adapterChild.scripts.OnClick(adapterChild)
	expect(config.selectedModuleId == "adapter-1" and config.moduleFilter == "legacy",
		"sidebar child selection must auto-switch to LEGACY COMPATIBILITY")
end

-- Rebuilding pages after a profile change must discard both bounded work
-- surfaces and create fresh ones rather than retaining orphaned references.
local oldListPanel = config.moduleListPanel
local oldInspectorPanel = config.moduleInspectorPanel
config:ReloadProfile()
expect(config.moduleListPanel and config.moduleListPanel ~= oldListPanel
	and config.moduleInspectorPanel and config.moduleInspectorPanel ~= oldInspectorPanel,
	"profile reload must rebuild both Modules work surfaces")

if #failures > 0 then
	error("Modules Config layout contract failed:\n - " .. table.concat(failures, "\n - "), 0)
end

print("Modules Config layout mock passed")
