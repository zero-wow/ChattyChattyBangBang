local addon = ChattyChattyBangBang
local Theme = addon.Theme
local Config = {}
addon.CustomConfig = Config

local navigation = {
	{ id = "home", label = "Overview", group = "START HERE" },
	{ id = "dock", label = "Chat Window", group = "CHAT WINDOW" },
	{ id = "views", label = "Views & Tabs", group = "CHAT WINDOW" },
	{ id = "messenger", label = "Messenger", group = "CHAT WINDOW" },
	{ id = "safety", label = "Player Actions", group = "CHAT WINDOW" },
	{ id = "spam", label = "Spam Firewall", group = "RULES & SAFETY" },
	{ id = "blocks", label = "Message Blocks", group = "RULES & SAFETY" },
	{ id = "semantic", label = "Semantic Routes", group = "RULES & SAFETY" },
	{ id = "alerts", label = "Alerts", group = "RULES & SAFETY" },
	{ id = "colorways", label = "Themes", group = "APPEARANCE" },
	{ id = "keywords", label = "Keyword Highlights", group = "APPEARANCE" },
	{ id = "modules", label = "Modules", group = "TOOLS" },
	{ id = "integrations", label = "Chat Access", group = "TOOLS" },
	{ id = "about", label = "About", group = "TOOLS" },
}

-- One spacing scale keeps the settings console compact without making it
-- cramped.  Outer frames establish the workspace; controls only need the
-- breathing room required to scan and click them.
local PAGE_GUTTER = 8
local PAGE_WIDTH = 636
local PAGE_TOP = 46
local CONTROL_GAP = 3
-- The sidebar deliberately has no visible scroll bar. Its settings hierarchy
-- can grow when Modules is expanded, but the list still reads like a compact
-- settings block and simply responds to the mouse wheel over that area.
local NAV_LEFT = 6
local NAV_TOP = 8
local NAV_TITLE_HEIGHT = 14
local NAV_SECTION_HEIGHT = 14
local NAV_BUTTON_HEIGHT = 22
local NAV_CHILD_HEIGHT = 17
local NAV_SECTION_GAP = 6
local NAV_ROW_GAP = 2
local NAV_MODULE_INDENT = 10
local NAV_PAGER_HEIGHT = 17
local NAV_FOOTER_HEIGHT = 14
local NAV_ROW_WIDTH = 154
local NAV_DIVIDER_WIDTH = 1
local CONFIG_FRAME_WIDTH = 840
local CONFIG_FRAME_HEIGHT = 570
local CONFIG_VIEWPORT_GUTTER = 12

-- Keep the settings workspace at one stable logical size so every page can
-- retain its reviewed bounds, then scale the complete console only when the
-- current UIParent viewport cannot provide a real margin around it.  Edge
-- coordinates are converted through effective scale before clamping because
-- Region:GetLeft()/GetRight() use the region's coordinate space when a child
-- has an independent scale.  All APIs used here exist on the 3.3.5 Frame API;
-- callers still guard them so the small no-client mocks remain lightweight.
function Config:FitFrameToViewport()
	local frame = self.frame
	if not frame or not UIParent or not UIParent.GetWidth or not UIParent.GetHeight then
		return false
	end

	local viewportWidth = tonumber(UIParent:GetWidth()) or 0
	local viewportHeight = tonumber(UIParent:GetHeight()) or 0
	if viewportWidth <= 0 or viewportHeight <= 0 then
		return false
	end

	if frame.SetSize then
		frame:SetSize(CONFIG_FRAME_WIDTH, CONFIG_FRAME_HEIGHT)
	end
	local availableWidth = math.max(1, viewportWidth - (CONFIG_VIEWPORT_GUTTER * 2))
	local availableHeight = math.max(1, viewportHeight - (CONFIG_VIEWPORT_GUTTER * 2))
	local scale = math.min(1, availableWidth / CONFIG_FRAME_WIDTH, availableHeight / CONFIG_FRAME_HEIGHT)
	if scale <= 0 then
		return false
	end
	if frame.SetScale then
		frame:SetScale(scale)
	end
	frame._chattyViewportScale = scale
	if frame.SetClampedToScreen then
		frame:SetClampedToScreen(true)
	end

	local getLeft = frame.GetLeft
	local getRight = frame.GetRight
	local getTop = frame.GetTop
	local getBottom = frame.GetBottom
	if type(getLeft) ~= "function" or type(getRight) ~= "function"
		or type(getTop) ~= "function" or type(getBottom) ~= "function" then
		if frame.ClearAllPoints and frame.SetPoint then
			frame:ClearAllPoints()
			frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		end
		return true
	end

	local left, right = frame:GetLeft(), frame:GetRight()
	local top, bottom = frame:GetTop(), frame:GetBottom()
	if not left or not right or not top or not bottom then
		if frame.ClearAllPoints and frame.SetPoint then
			frame:ClearAllPoints()
			frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		end
		return true
	end

	local parentScale = UIParent.GetEffectiveScale and tonumber(UIParent:GetEffectiveScale()) or 1
	local frameScale = frame.GetEffectiveScale and tonumber(frame:GetEffectiveScale()) or (parentScale * scale)
	if not parentScale or parentScale <= 0 then parentScale = 1 end
	if not frameScale or frameScale <= 0 then frameScale = parentScale * scale end

	local viewportRight = viewportWidth * parentScale
	local viewportTop = viewportHeight * parentScale
	local gutter = CONFIG_VIEWPORT_GUTTER * parentScale
	local leftPixels, rightPixels = left * frameScale, right * frameScale
	local topPixels, bottomPixels = top * frameScale, bottom * frameScale
	local deltaX, deltaY = 0, 0
	if leftPixels < gutter then
		deltaX = gutter - leftPixels
	elseif rightPixels > viewportRight - gutter then
		deltaX = (viewportRight - gutter) - rightPixels
	end
	if bottomPixels < gutter then
		deltaY = gutter - bottomPixels
	elseif topPixels > viewportTop - gutter then
		deltaY = (viewportTop - gutter) - topPixels
	end

	if (deltaX ~= 0 or deltaY ~= 0) and frame.ClearAllPoints and frame.SetPoint then
		local centerPixelsX = ((leftPixels + rightPixels) / 2) + deltaX
		local centerPixelsY = ((bottomPixels + topPixels) / 2) + deltaY
		frame:ClearAllPoints()
		-- BOTTOMLEFT is a stable screen-space origin. SetPoint offsets are in the
		-- child's coordinate space, hence division by the frame effective scale.
		frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
			centerPixelsX / frameScale, centerPixelsY / frameScale)
	end
	return true
end

-- Navigation is intentionally drawn as quiet rows instead of a second stack
-- of full panels.  The outer settings frame establishes the boundary; the
-- rail only needs a gentle hover wash and one clear selected-state marker.
-- Keeping this local to Config also means the shell remains readable in every
-- theme, even themes whose normal action buttons are deliberately ornate.
local function setSolidTextureColor(texture, color)
	if not texture or not color then
		return
	end
	texture:SetTexture("Interface\\Buttons\\WHITE8X8")
	texture:SetVertexColor(color[1], color[2], color[3], color[4])
end

local function createQuietShellPanel(parent, fillName)
	if type(Theme.CreateQuietPanel) == "function" then
		return Theme:CreateQuietPanel(parent, fillName)
	end
	return CreateFrame("Frame", nil, parent)
end

-- Dense pages use a small visual vocabulary: quiet choices, a single selected
-- edge, and an accent only for the next important action.  Keeping these
-- helpers here lets the page builders remain readable on older Theme builds.
local function setChoiceStyle(button, selected, textName)
	if not button then return end
	-- Views already own a dedicated leading accent texture for drag feedback.
	-- Do not add a second selection stripe on top of it.
	if type(Theme.SetButtonRole) == "function" and not button.selectionAccent then
		Theme:SetButtonRole(button, "choice", selected)
		if textName and button.SetTheme then
			button:SetTheme(selected and "accentSoft" or "surface", selected and "gold" or Theme.NO_BORDER, textName)
		end
		return
	end
	if button.SetTheme then
		button:SetTheme(selected and "accentSoft" or "surface", selected and (button.selectionAccent and Theme.NO_BORDER or "gold") or Theme.NO_BORDER, selected and "goldBright" or (textName or "text"))
	end
end

-- Pane navigation should read as navigation at a glance. Theme builds that
-- know about attached tabs draw a continuous baseline and selected underline;
-- older/test themes retain a quiet selected choice without losing behavior.
local function setTabStyle(button, selected)
	if not button then return end
	button._configTab = true
	button._configTabSelected = selected and true or false
	if type(Theme.SetTabState) == "function" then
		Theme:SetTabState(button, selected)
	else
		setChoiceStyle(button, selected)
	end
end

local function setActionStyle(button, role, title, body)
	if not button then return end
	if type(Theme.SetButtonRole) == "function" then
		Theme:SetButtonRole(button, role or "quiet")
	end
	if title and button.SetTooltip then
		button:SetTooltip(title, body)
	end
end

-- Buttons already expose Theme tooltips. Compact toggles and edit fields do
-- not, so give every ambiguous dock control the same concise help treatment
-- without changing its visual language or replacing its existing hover code.
local function setControlTooltip(control, title, body)
	if not control or not title then return end
	if control.SetTooltip then
		control:SetTooltip(title, body)
		return
	end
	if not control.HookScript then return end
	control:HookScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 1, 1, true)
		if body and body ~= "" then
			GameTooltip:AddLine(body, 0.72, 0.76, 0.84, true)
		end
		GameTooltip:Show()
	end)
	control:HookScript("OnLeave", function(self)
		if GameTooltip and (not GameTooltip.GetOwner or GameTooltip:GetOwner() == self) then
			GameTooltip:Hide()
		end
	end)
end

function Config:ApplyNavigationRowStyle(button, active, hovered)
	if not button or not button.label then
		return
	end
	-- Lightweight test hosts and external shell embedders may provide only the
	-- Theme constructors. The navigation remains functional there; it simply
	-- skips palette-only decoration until a full Theme object is available.
	if type(Theme.GetPalette) ~= "function" or type(Theme.GetColor) ~= "function" then
		return
	end
	local palette = Theme:GetPalette()
	local fill = active and palette.accentSoft or (hovered and palette.surfaceRaised or nil)
	if fill then
		setSolidTextureColor(button.fill, fill)
		button.fill:Show()
	else
		button.fill:Hide()
	end
	if active then
		setSolidTextureColor(button.accent, palette.gold or palette.accent)
		button.accent:Show()
	else
		button.accent:Hide()
	end
	local textColor = active and "goldBright" or (hovered and "gold" or "textMuted")
	local r, g, b, a = Theme:GetColor(textColor)
	button.label:SetTextColor(r, g, b, a)
	if button.disclosure then
		button.disclosure:SetTextColor(r, g, b, a)
	end
end

local function createNavigationRow(parent, label, tooltip)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(NAV_ROW_WIDTH, NAV_BUTTON_HEIGHT)
	button:EnableMouse(true)
	button.fill = button:CreateTexture(nil, "BACKGROUND")
	button.fill:SetAllPoints(button)
	button.fill:Hide()
	button.accent = button:CreateTexture(nil, "BORDER")
	button.accent:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	button.accent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
	button.accent:SetWidth(2)
	button.accent:Hide()
	button.label = Theme:CreateText(button, "GameFontNormalSmall", "textMuted")
	button.label:SetPoint("LEFT", button, "LEFT", 7, 0)
	button.label:SetPoint("RIGHT", button, "RIGHT", -7, 0)
	button.label:SetJustifyH("LEFT")
	button.label:SetText(label or "")
	button.tooltipText = tooltip
	button:SetScript("OnEnter", function(self)
		Config:ApplyNavigationRowStyle(self, self.navActive == true, true)
		if self.tooltipText and GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.tooltipText, 1, 0.82, 0.3, true)
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function(self)
		Config:ApplyNavigationRowStyle(self, self.navActive == true, false)
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	return button
end

local function getAddonVersion()
	local version = addon.GetVersion and addon:GetVersion() or addon.VERSION
	if type(version) ~= "string" or version == "" then
		return "2.26.1"
	end
	return version
end

local function createHeading(parent, title, subtitle)
	local heading = Theme:CreateText(parent, "GameFontNormalLarge", "goldBright")
	heading:SetPoint("TOPLEFT", parent, "TOPLEFT", PAGE_GUTTER, -8)
	heading:SetText(title)

	local subheading = Theme:CreateText(parent, "GameFontHighlightSmall", "textMuted")
	subheading:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -2)
	subheading:SetWidth(PAGE_WIDTH)
	subheading:SetJustifyH("LEFT")
	subheading:SetText(subtitle)
	return heading, subheading
end

function Config:CreatePage(id)
	local page = CreateFrame("Frame", nil, self.content)
	page:SetAllPoints(self.content)
	page:Hide()
	self.pages[id] = page
	return page
end

function Config:RefreshNavigation()
	for id, button in pairs(self.navigationButtons) do
		local active = id == self.activePage
		if id == "modules" and button.disclosure then
			button.disclosure:SetText(self.modulesNavigationExpanded and "-" or "+")
		end
		button.navActive = active
		if button.label then
			self:ApplyNavigationRowStyle(button, active, false)
		elseif button.SetTheme then
			-- Keep the small mock/frame compatibility path for callers that build
			-- a navigation button before the full settings shell exists.
			button:SetTheme(active and "accentSoft" or "surface", active and "gold" or "borderMuted", active and "goldBright" or "textMuted")
		end
	end
	self:RefreshModuleNavigation()
	self:LayoutNavigation()
end

function Config:BuildHomePage()
	local page = self:CreatePage("home")
	createHeading(page, "Overview", "Start here for chat status and the controls you use every day.")

	local hero = Theme:CreatePanel(page, "surfaceRaised", "border")
	hero:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -PAGE_TOP)
	hero:SetSize(PAGE_WIDTH, 72)

	local icon = hero:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(Theme.ICON_PATH)
	icon:SetSize(46, 46)
	icon:SetPoint("LEFT", hero, "LEFT", 8, 0)

	local title = Theme:CreateText(hero, "GameFontNormal", "goldBright")
	title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -1)
	title:SetText("ChattyChattyBangBang")

	local detail = Theme:CreateText(hero, "GameFontHighlightSmall", "textMuted")
	detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
	detail:SetWidth(548)
	detail:SetJustifyH("LEFT")
	detail:SetText("Organized chat is the primary view. Disable it to restore native chat.")

	local status = Theme:CreateText(hero, "GameFontNormalSmall", "warning")
	status:SetPoint("TOPLEFT", detail, "BOTTOMLEFT", 0, -4)
	self.homeStatus = status

	local smartToggle = Theme:CreateToggle(page, "Enable Intelligent Chat UI", "Capture and route messages into organized views.")
	smartToggle:SetPoint("TOPLEFT", hero, "BOTTOMLEFT", 0, -5)
	smartToggle:SetWidth(PAGE_WIDTH)
	self.smartToggle = smartToggle
	smartToggle.OnValueChanged = function(_, value)
		addon:SetSmartChatEnabled(value)
		Config:RefreshHomeState()
	end

	local minimapToggle = Theme:CreateToggle(page, "Show minimap launcher", "Left toggles the dock; right opens settings; middle-click hides the launcher.")
	minimapToggle:SetPoint("TOPLEFT", smartToggle, "BOTTOMLEFT", 0, -4)
	minimapToggle:SetWidth(PAGE_WIDTH)
	self.minimapToggle = minimapToggle
	minimapToggle.OnValueChanged = function(_, value)
		addon:SetMinimapHidden(not value)
	end

	self:RefreshHomeState()
	return page
end

function Config:RefreshHomeState()
	if not self.homeStatus then
		return
	end
	local settings = addon:GetSmartSettings()
	self.smartToggle:SetValue(settings.enabled, true)
	self.minimapToggle:SetValue(not settings.launcher.minimap.hide, true)
	if settings.enabled and addon.SmartDock and addon.SmartDock:IsActive() then
		self.homeStatus:SetText("ACTIVE  -  Capturing and routing messages")
		Theme.texts[self.homeStatus] = "success"
	elseif settings.enabled and addon.SmartDock and addon.SmartDock.pendingEnabled then
		self.homeStatus:SetText("WAITING  -  Activates after combat")
		Theme.texts[self.homeStatus] = "warning"
	else
		if addon.legacyFallbackActive then
			self.homeStatus:SetText("STANDBY  -  Native chat is active")
		else
			self.homeStatus:SetText("STANDBY  -  Native or external chat is active")
		end
		Theme.texts[self.homeStatus] = "warning"
	end
	local r, g, b, a = Theme:GetColor(Theme.texts[self.homeStatus])
	self.homeStatus:SetTextColor(r, g, b, a)
end

local clampNumber
local DOCK_DEFAULT_WIDTH = 520
local DOCK_DEFAULT_HEIGHT = 250

local function getDockSettings()
	local settings = addon:GetSmartSettings()
	settings.dock = settings.dock or {}
	return settings.dock
end

local function applyDockRuntime(action, value)
	local dock = addon.SmartDock
	if not dock then
		return
	end
	if action == "railVisibility" then
		if dock.SetRailVisibility then
			dock:SetRailVisibility(value, false)
		elseif dock.ApplyLayout then
			dock:ApplyLayout()
		end
		return
	elseif action == "headerVisibility" then
		if dock.SetHeaderVisibility then
			dock:SetHeaderVisibility(value, false)
		elseif dock.ApplyLayout then
			dock:ApplyLayout()
		end
		return
	elseif action == "socialButton" then
		if dock.ApplySocialButtonVisibility then
			dock:ApplySocialButtonVisibility()
		end
		return
	elseif action == "visible" and dock.SetVisible then
		dock:SetVisible(value and true or false, true)
	elseif action == "collapsed" and dock.SetCollapsed then
		dock:SetCollapsed(value and true or false, true)
	end
	if dock.ApplyLayout then
		dock:ApplyLayout()
	end
	if action == "classificationTags" and dock.RebuildActiveView then
		dock:RebuildActiveView()
	end
end

function Config:SetDockStatus(text, colorName)
	if not self.dockStatus then
		return
	end
	colorName = colorName or "textMuted"
	self.dockStatus:SetText(text or "")
	Theme.texts[self.dockStatus] = colorName
	local r, g, b, a = Theme:GetColor(colorName)
	self.dockStatus:SetTextColor(r, g, b, a)
end

-- Chat Colors is a true Chat Window subtab.  It edits Blizzard's existing
-- chat-color state, which Smart Dock also uses for every visible source label.
-- Keep the UI state transient; the colors themselves are saved by the client.
local DOCK_CHAT_COLOR_ROWS = 10

local function getDockChatColorDefinitions()
	if type(addon.GetChatColorDefinitions) ~= "function" then
		return {}
	end
	local ok, definitions = pcall(addon.GetChatColorDefinitions, addon)
	return ok and type(definitions) == "table" and definitions or {}
end

local function getDockChatColorDefinition(id)
	if type(addon.GetChatColorDefinition) ~= "function" then
		return nil
	end
	local ok, definition = pcall(addon.GetChatColorDefinition, addon, id)
	return ok and type(definition) == "table" and definition or nil
end

local function setDockChatColorButtonTheme(button, active)
	if button and button.SetTheme then
		button:SetTheme(active and "accentSoft" or "surfaceRaised", active and "gold" or "borderMuted", active and "goldBright" or "text")
	end
end

local dockLayoutCategoryDefinitions = {
	window = {
		title = "WINDOW",
		heading = "Window",
		hint = "Show or collapse the chat frame and choose which supporting controls remain visible.",
		tooltip = "Frame visibility, collapsed state, social button, and helper tags.",
	},
	tabs = {
		title = "TABS + TITLE",
		heading = "Tabs & title bar",
		hint = "Choose when navigation appears, where it sits, and which title-bar controls are shown.",
		tooltip = "Chat-tab visibility, direction, title-bar visibility, and header controls.",
	},
	input = {
		title = "INPUT",
		heading = "Input & controls",
		hint = "Control the typing field and how much received chat each source restores after login.",
		tooltip = "Typing-field behavior and persistent received-chat history.",
	},
	readability = {
		title = "READABILITY",
		heading = "Message readability",
		hint = "Tune line spacing, let narrow windows simplify message details, and optionally shade alternating messages.",
		tooltip = "Global line spacing, responsive timestamp/channel/name visibility, and alternating message backgrounds.",
	},
	unread = {
		title = "UNREAD",
		heading = "Unread indicators",
		hint = "Configure the movable NEW marker and the unread numbers shown on inactive chat tabs.",
		tooltip = "NEW-marker behavior and styling, plus independent tab unread-count size and opacity.",
	},
}

local dockLayoutCategoryOrder = { "window", "tabs", "input", "readability", "unread" }

function Config:SetDockLayoutCategory(category)
	if not dockLayoutCategoryDefinitions[category] then
		category = "window"
	end
	if self.dockLayoutCategory == category then
		return
	end
	if self.dockLayoutCategory == "unread" and category ~= "unread" and self.dockMarkerPreviewActive then
		self:SetNewMessageIndicatorPreview(false)
	end
	self.dockLayoutCategory = category
	self:RefreshDockPage()
end

function Config:RefreshDockLayoutCategory()
	local layoutVisible = self.dockSection ~= "colors"
	local category = dockLayoutCategoryDefinitions[self.dockLayoutCategory] and self.dockLayoutCategory or "window"
	self.dockLayoutCategory = category

	for _, control in ipairs(self.dockLayoutNavigationControls or {}) do
		if layoutVisible then control:Show() else control:Hide() end
	end
	for id, controls in pairs(self.dockLayoutGroups or {}) do
		local visible = layoutVisible and id == category
		for _, control in ipairs(controls) do
			if visible then control:Show() else control:Hide() end
		end
	end
	for id, button in pairs(self.dockLayoutCategoryButtons or {}) do
		setTabStyle(button, layoutVisible and id == category)
	end

	local definition = dockLayoutCategoryDefinitions[category]
	if self.dockLayoutSectionTitle then
		self.dockLayoutSectionTitle:SetText(definition.heading)
	end
	if self.dockLayoutSectionHint then
		self.dockLayoutSectionHint:SetText(definition.hint)
	end
end

function Config:SetDockSection(section)
	section = section == "colors" and "colors" or "layout"
	if self.dockSection == section then
		return
	end
	self.dockSection = section
	if section ~= "layout" and self.dockMarkerPreviewActive then
		self:SetNewMessageIndicatorPreview(false)
	end
	self:RefreshDockPage()
end

function Config:SetDockColorsStatus(text, colorName)
	if not self.dockColorsStatus then
		return
	end
	colorName = colorName or "textMuted"
	self.dockColorsStatus:SetText(text or "")
	Theme.texts[self.dockColorsStatus] = colorName
	local r, g, b, a = Theme:GetColor(colorName)
	self.dockColorsStatus:SetTextColor(r, g, b, a)
end

function Config:SelectDockChatColor(id)
	local definition = getDockChatColorDefinition(id)
	if not definition then
		self:SetDockColorsStatus("That chat source is no longer available. Refreshing the list.", "warning")
		self.selectedDockChatColorId = nil
		self:RefreshDockChatColors()
		return false
	end
	self.selectedDockChatColorId = definition.id
	self:RefreshDockChatColors()
	return true
end

function Config:ApplyDockChatColor()
	if type(addon.SetChatColor) ~= "function" then
		self:SetDockColorsStatus("Blizzard chat-color controls are unavailable in this build.", "warning")
		return false
	end
	local definition = getDockChatColorDefinition(self.selectedDockChatColorId)
	if not definition then
		self:SetDockColorsStatus("Choose a chat source first.", "warning")
		return false
	end
	local edits = self.dockChatColorEdits or {}
	local components = {}
	for index = 1, 3 do
		local value = tonumber(edits[index] and edits[index]:GetText())
		if not value or value < 0 or value > 255 then
			self:SetDockColorsStatus("Use red, green, and blue values from 0 to 255.", "warning")
			return false
		end
		components[index] = math.floor(value + 0.5) / 255
	end
	local ok, accepted, detail = pcall(addon.SetChatColor, addon, definition.id, components[1], components[2], components[3])
	if not ok or accepted == false then
		self:SetDockColorsStatus("Could not apply that Blizzard chat color.", "warning")
		return false
	end
	self:SetDockColorsStatus("" .. definition.label .. " color applied to Blizzard chat and Chatty source labels.", "success")
	self:RefreshDockChatColors()
	return true
end

function Config:RefreshDockChatColors()
	if not self.dockColorsPanel then
		return
	end
	local definitions = getDockChatColorDefinitions()
	if #definitions == 0 then
		for _, row in ipairs(self.dockChatColorRows or {}) do
			row:Hide()
		end
		if self.dockChatColorEmpty then
			self.dockChatColorEmpty:Show()
		end
		return
	end
	if self.dockChatColorEmpty then
		self.dockChatColorEmpty:Hide()
	end
	local selected = getDockChatColorDefinition(self.selectedDockChatColorId)
	if not selected then
		selected = definitions[1]
		self.selectedDockChatColorId = selected.id
	end
	local pageCount = math.max(1, math.ceil(#definitions / DOCK_CHAT_COLOR_ROWS))
	local page = math.max(1, math.min(pageCount, tonumber(self.dockChatColorPage) or 1))
	self.dockChatColorPage = page
	local first = ((page - 1) * DOCK_CHAT_COLOR_ROWS) + 1
	for index, row in ipairs(self.dockChatColorRows or {}) do
		local definition = definitions[first + index - 1]
		if definition then
			row.definitionId = definition.id
			row:SetLabel(definition.label)
			setDockChatColorButtonTheme(row, definition.id == self.selectedDockChatColorId)
			if row.swatch then
				row.swatch:SetVertexColor(tonumber(definition.r) or 1, tonumber(definition.g) or 1, tonumber(definition.b) or 1, 1)
			end
			row:Show()
		else
			row.definitionId = nil
			row:Hide()
		end
	end
	if self.dockChatColorCount then
		self.dockChatColorCount:SetText(tostring(first) .. "-" .. tostring(math.min(#definitions, first + DOCK_CHAT_COLOR_ROWS - 1)) .. " / " .. tostring(#definitions))
		if pageCount > 1 then self.dockChatColorCount:Show() else self.dockChatColorCount:Hide() end
	end
	for _, button in ipairs({ self.dockChatColorPrevious, self.dockChatColorNext }) do
		if button then
			if pageCount > 1 then button:Show() else button:Hide() end
		end
	end
	if self.dockChatColorPrevious and self.dockChatColorPrevious.SetEnabled then self.dockChatColorPrevious:SetEnabled(page > 1) end
	if self.dockChatColorNext and self.dockChatColorNext.SetEnabled then self.dockChatColorNext:SetEnabled(page < pageCount) end

	if self.dockChatColorSelectedTitle then
		self.dockChatColorSelectedTitle:SetText(selected.label)
	end
	if self.dockChatColorSelectedDetail then
		self.dockChatColorSelectedDetail:SetText(selected.group .. "  -  Blizzard color used for this source label.")
	end
	if self.dockChatColorPreview then
		self.dockChatColorPreview:SetVertexColor(tonumber(selected.r) or 1, tonumber(selected.g) or 1, tonumber(selected.b) or 1, 1)
	end
	local components = { selected.r or 1, selected.g or 1, selected.b or 1 }
	for index, editBox in ipairs(self.dockChatColorEdits or {}) do
		editBox:SetText(tostring(math.floor((components[index] * 255) + 0.5)))
	end
end

function Config:RefreshDockSections()
	local colors = self.dockSection == "colors"
	if self.dockLayoutTabButton then
		setTabStyle(self.dockLayoutTabButton, not colors)
	end
	if self.dockColorsTabButton then
		setTabStyle(self.dockColorsTabButton, colors)
	end
	if self.dockHeadingSubtitle then
		self.dockHeadingSubtitle:SetText(colors
			and "Tune the native chat colors Chatty uses to distinguish every source inside a tab."
			or "Choose one area below. Every change applies immediately to the live chat window.")
	end
	self:RefreshDockLayoutCategory()
	if self.dockColorsPanel then
		if colors then
			self.dockColorsPanel:Show()
			self:RefreshDockChatColors()
		else
			self.dockColorsPanel:Hide()
		end
	end
end

-- Keep the advanced NEW-marker controls deliberately separate from its
-- day-to-day behavior.  A player should be able to turn the marker on or off
-- without having to learn a mini theme editor, while people who do want to
-- tune it get a compact, live-previewable surface in the same familiar page.
local markerAppearanceFallbackOptions = {
	fonts = {
		{ id = "default", label = "DEFAULT UI" },
		{ id = "chat", label = "CHAT FONT" },
		{ id = "system", label = "SYSTEM" },
		{ id = "number", label = "NUMERIC" },
	},
	outlines = {
		{ id = "NONE", label = "NONE" },
		{ id = "OUTLINE", label = "OUTLINE" },
		{ id = "THICKOUTLINE", label = "THICK" },
	},
	themeColors = {
		{ id = "goldBright", label = "GOLD" },
		{ id = "gold", label = "WARM GOLD" },
		{ id = "accent", label = "ACCENT" },
		{ id = "text", label = "TEXT" },
		{ id = "success", label = "SUCCESS" },
		{ id = "warning", label = "WARNING" },
		{ id = "danger", label = "DANGER" },
	},
}

local markerAppearanceColorKeys = {
	text = "color",
	background = "background",
	border = "border",
}

local markerAppearancePatchMethods = {
	font = "SetNewMessageIndicatorFont",
	fontSize = "SetNewMessageIndicatorFontSize",
	alpha = "SetNewMessageIndicatorAlpha",
	scale = "SetNewMessageIndicatorScale",
	outline = "SetNewMessageIndicatorOutline",
	color = "SetNewMessageIndicatorColor",
	background = "SetNewMessageIndicatorBackgroundColor",
	border = "SetNewMessageIndicatorBorderColor",
	position = "SetNewMessageIndicatorPosition",
}

local function callMarkerAppearanceAPI(name, ...)
	local method = addon[name]
	if type(method) ~= "function" then
		return false, "unavailable"
	end
	local ok, accepted, detail = pcall(method, addon, ...)
	if not ok then
		return false, detail
	end
	if accepted == false then
		return false, detail or "rejected"
	end
	return true, detail or accepted
end

local function getNewMessageIndicatorAppearance()
	local method = addon.GetNewMessageIndicatorAppearanceSettings
	if type(method) == "function" then
		local ok, appearance = pcall(method, addon)
		if ok and type(appearance) == "table" then
			-- Accept either the direct appearance copy or a future wrapper returned
			-- by an integration without ever exposing SavedVariables to this page.
			if type(appearance.appearance) == "table" and appearance.position == nil then
				appearance = appearance.appearance
			end
			return appearance
		end
	end
	local settingsMethod = addon.GetNewMessageIndicatorSettings
	if type(settingsMethod) == "function" then
		local ok, settings = pcall(settingsMethod, addon)
		if ok and type(settings) == "table" and type(settings.appearance) == "table" then
			return settings.appearance
		end
	end
	return nil
end

local function getNewMessageIndicatorAppearanceOptions()
	local method = addon.GetNewMessageIndicatorAppearanceOptions
	if type(method) == "function" then
		local ok, options = pcall(method, addon)
		if ok and type(options) == "table" then
			return options
		end
	end
	return markerAppearanceFallbackOptions
end

local function getMarkerAppearanceOptions(options, key)
	local values = type(options) == "table" and options[key] or nil
	if type(values) ~= "table" or #values == 0 then
		values = markerAppearanceFallbackOptions[key]
	end
	return values or {}
end

local function hasNewMessageIndicatorAppearanceAPI()
	if type(addon.SetNewMessageIndicatorAppearance) == "function" then
		return true
	end
	for _, methodName in pairs(markerAppearancePatchMethods) do
		if type(addon[methodName]) == "function" then
			return true
		end
	end
	return false
end

local function applyNewMessageIndicatorAppearancePatch(patch)
	if type(patch) ~= "table" then
		return false, "invalid"
	end
	local generic = addon.SetNewMessageIndicatorAppearance
	if type(generic) == "function" then
		return callMarkerAppearanceAPI("SetNewMessageIndicatorAppearance", patch)
	end
	-- A partial update may ship individual narrow setters first.  This fallback
	-- keeps the config page safe during that transition without writing directly
	-- into the profile table.
	local key, value = next(patch)
	if key and next(patch, key) == nil and markerAppearancePatchMethods[key] then
		return callMarkerAppearanceAPI(markerAppearancePatchMethods[key], value)
	end
	return false, "unavailable"
end

local function getMarkerColor(appearance, target)
	local key = markerAppearanceColorKeys[target] or "color"
	local color = type(appearance) == "table" and appearance[key] or nil
	return type(color) == "table" and color or {}
end

local function getMarkerColorComponents(color)
	color = type(color) == "table" and color or {}
	if color.mode == "theme" and type(color.theme) == "string" and Theme.GetColor then
		local r, g, b, a = Theme:GetColor(color.theme)
		if r then
			return r, g, b, a == nil and 1 or a
		end
	end
	return tonumber(color.r) or 1, tonumber(color.g) or 1, tonumber(color.b) or 1, tonumber(color.a) or 1
end

local function getMarkerAppearancePositionText(position)
	position = type(position) == "table" and position or {}
	if position.anchor == "dock" then
		local point = tostring(position.point or "CENTER")
		local x = math.floor((tonumber(position.x) or 0) + 0.5)
		local y = math.floor((tonumber(position.y) or 0) + 0.5)
		return "CUSTOM  " .. point .. "  " .. tostring(x) .. ", " .. tostring(y)
	end
	return "TITLE BAR"
end

local function setMarkerAppearanceButtonTheme(button, active, colorName)
	if not button or not button.SetTheme then
		return
	end
	button:SetTheme(active and "accentSoft" or "surfaceRaised", active and "gold" or "borderMuted", colorName or (active and "goldBright" or "text"))
end

function Config:SetNewMessageIndicatorAppearanceControlsVisible(visible)
	visible = visible
		and self.dockSection ~= "colors"
		and self.dockLayoutCategory == "unread"
	for _, control in ipairs(self.dockMarkerAppearanceControls or {}) do
		if visible then
			control:Show()
		else
			control:Hide()
		end
	end
end

local function hasRailUnreadCountAppearanceAPI()
	return type(addon.GetRailUnreadCountAppearanceSettings) == "function"
		and type(addon.SetRailUnreadCountAlpha) == "function"
		and type(addon.SetRailUnreadCountFontSize) == "function"
end

local function getRailUnreadCountAppearance()
	if type(addon.GetRailUnreadCountAppearanceSettings) ~= "function" then
		return nil
	end
	local ok, appearance = pcall(addon.GetRailUnreadCountAppearanceSettings, addon)
	return ok and type(appearance) == "table" and appearance or nil
end

function Config:SetRailUnreadCountAppearanceControlsVisible(visible)
	visible = visible
		and self.dockSection ~= "colors"
		and self.dockLayoutCategory == "unread"
	for _, control in ipairs(self.dockUnreadCountAppearanceControls or {}) do
		if visible then
			control:Show()
		else
			control:Hide()
		end
	end
end

function Config:RefreshRailUnreadCountAppearance()
	local hasAPI = hasRailUnreadCountAppearanceAPI()
	local unreadVisible = self.dockSection ~= "colors" and self.dockLayoutCategory == "unread"
	if self.dockUnreadCountAppearanceToggle then
		if hasAPI and unreadVisible then
			self.dockUnreadCountAppearanceToggle:SetLabel(self.dockUnreadCountAppearanceExpanded and "TAB COUNTS -" or "TAB COUNTS +")
			self.dockUnreadCountAppearanceToggle:Show()
		else
			self.dockUnreadCountAppearanceToggle:Hide()
		end
	end
	local expanded = hasAPI and unreadVisible and self.dockUnreadCountAppearanceExpanded == true
	self:SetRailUnreadCountAppearanceControlsVisible(expanded)
	if not expanded then
		return
	end

	local appearance = getRailUnreadCountAppearance() or {}
	if self.dockUnreadCountFontSizeEdit then
		self.dockUnreadCountFontSizeEdit:SetText(tostring(math.floor((tonumber(appearance.fontSize) or 0) + 0.5)))
	end
	if self.dockUnreadCountAlphaEdit then
		self.dockUnreadCountAlphaEdit:SetText(tostring(math.floor(((tonumber(appearance.alpha) or 1) * 100) + 0.5)))
	end
end

function Config:LayoutNewMessageIndicatorAppearance(expanded)
	local page = self.dockPage
	if not page then
		return
	end
	-- Size is now its own inspector, so expanding marker appearance never pushes
	-- another section through the bottom of the page. The shared status line is
	-- fixed to the bottom edge in every inspector state.
	if self.dockStatus then
		self.dockStatus:ClearAllPoints()
		self.dockStatus:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -474)
	end
end

function Config:RefreshNewMessageIndicatorAppearance()
	local hasAPI = hasNewMessageIndicatorAppearanceAPI()
	local unreadVisible = self.dockSection ~= "colors" and self.dockLayoutCategory == "unread"
	if self.dockMarkerAppearanceToggle then
		if hasAPI and unreadVisible then
			self.dockMarkerAppearanceToggle:SetLabel((self.dockMarkerAppearanceExpanded and "MARKER STYLE -" or "MARKER STYLE +"))
			self.dockMarkerAppearanceToggle:Show()
		else
			self.dockMarkerAppearanceToggle:Hide()
		end
	end
	local expanded = hasAPI and unreadVisible and self.dockMarkerAppearanceExpanded == true
		and self.dockUnreadCountAppearanceExpanded ~= true
	self:SetNewMessageIndicatorAppearanceControlsVisible(expanded)
	self:LayoutNewMessageIndicatorAppearance(expanded)
	if not expanded then
		return
	end

	local appearance = getNewMessageIndicatorAppearance() or {}
	local options = getNewMessageIndicatorAppearanceOptions()
	local fonts = getMarkerAppearanceOptions(options, "fonts")
	local outlines = getMarkerAppearanceOptions(options, "outlines")
	local themeColors = getMarkerAppearanceOptions(options, "themeColors")
	local fontId = tostring(appearance.font or "default")
	local outlineId = tostring(appearance.outline or "NONE")
	local target = self.dockMarkerColorTarget
	if target ~= "background" and target ~= "border" then
		target = "text"
		self.dockMarkerColorTarget = target
	end
	local selectedColor = getMarkerColor(appearance, target)
	local selectedTheme = selectedColor.mode == "theme" and selectedColor.theme or nil

	if self.dockMarkerPositionValue then
		self.dockMarkerPositionValue:SetText("POSITION  " .. getMarkerAppearancePositionText(appearance.position))
	end
	if self.dockMarkerPreviewButton then
		self.dockMarkerPreviewButton:SetLabel(self.dockMarkerPreviewActive and "HIDE PREVIEW" or "PREVIEW MARKER")
	end

	for index, button in ipairs(self.dockMarkerFontButtons or {}) do
		local option = fonts[index]
		if option then
			button.optionId = option.id
			button:SetLabel(option.label or string.upper(tostring(option.id or "FONT")))
			setMarkerAppearanceButtonTheme(button, option.id == fontId)
			button:Show()
		else
			button.optionId = nil
			button:Hide()
		end
	end
	for index, button in ipairs(self.dockMarkerOutlineButtons or {}) do
		local option = outlines[index]
		if option then
			button.optionId = option.id
			button:SetLabel(option.label or string.upper(tostring(option.id or "OUTLINE")))
			setMarkerAppearanceButtonTheme(button, option.id == outlineId)
			button:Show()
		else
			button.optionId = nil
			button:Hide()
		end
	end
	for index, button in ipairs(self.dockMarkerColorTargetButtons or {}) do
		local active = button.target == target
		setMarkerAppearanceButtonTheme(button, active)
	end
	for index, button in ipairs(self.dockMarkerThemeColorButtons or {}) do
		local option = themeColors[index]
		if option then
			button.optionId = option.id
			button:SetLabel(option.label or string.upper(tostring(option.id or "COLOR")))
			setMarkerAppearanceButtonTheme(button, option.id == selectedTheme, option.id)
			button:Show()
		else
			button.optionId = nil
			button:Hide()
		end
	end

	if self.dockMarkerFontSizeEdit then
		self.dockMarkerFontSizeEdit:SetText(tostring(math.floor((tonumber(appearance.fontSize) or 0) + 0.5)))
	end
	if self.dockMarkerScaleEdit then
		self.dockMarkerScaleEdit:SetText(tostring(math.floor(((tonumber(appearance.scale) or 1) * 100) + 0.5)))
	end
	if self.dockMarkerAlphaEdit then
		self.dockMarkerAlphaEdit:SetText(tostring(math.floor(((tonumber(appearance.alpha) or 1) * 100) + 0.5)))
	end
	local r, g, b, a = getMarkerColorComponents(selectedColor)
	local channels = { r, g, b, a }
	for index, editBox in ipairs(self.dockMarkerColorEdits or {}) do
		local maximum = index == 4 and 100 or 255
		editBox:SetText(tostring(math.floor((channels[index] * maximum) + 0.5)))
	end
end

function Config:ApplyNewMessageIndicatorAppearancePatch(patch, status)
	local accepted = applyNewMessageIndicatorAppearancePatch(patch)
	if not accepted then
		self:SetDockStatus("Marker appearance is unavailable in this build.", "warning")
		return false
	end
	-- A visual editor with no visible result is needlessly confusing. While its
	-- Customize section is open, every successful appearance change turns on a
	-- transient NEW sample automatically; it never creates an unread message or
	-- persists preview state. The explicit button still lets the player hide it.
	if self.dockMarkerAppearanceExpanded and not self.dockUnreadCountAppearanceExpanded and not self.dockMarkerPreviewActive then
		self:SetNewMessageIndicatorPreview(true)
	end
	self:RefreshDockPage()
	if status then
		self:SetDockStatus(status, "success")
	end
	return true
end

function Config:SetNewMessageIndicatorPreview(active)
	active = active and true or false
	local accepted = false
	if type(addon.SetNewMessageIndicatorPreviewActive) == "function" then
		accepted = callMarkerAppearanceAPI("SetNewMessageIndicatorPreviewActive", active)
	elseif addon.SmartDock and type(addon.SmartDock.SetNewMessageIndicatorPreview) == "function" then
		local ok, result = pcall(addon.SmartDock.SetNewMessageIndicatorPreview, addon.SmartDock, active)
		accepted = ok and result ~= false
	end
	if not accepted then
		self:SetDockStatus("Live marker preview is unavailable right now.", "warning")
		return false
	end
	self.dockMarkerPreviewActive = active
	self:RefreshNewMessageIndicatorAppearance()
	self:SetDockStatus(active and "Preview is visible. Hold SHIFT and drag NEW to place it." or "Marker preview hidden.", "success")
	return true
end

function Config:RefreshDockPage()
	if not self.dockPage then
		return
	end
	local dock = getDockSettings()
	if self.dockVisibleToggle then self.dockVisibleToggle:SetValue(dock.visible ~= false, true) end
	if self.dockCollapsedToggle then self.dockCollapsedToggle:SetValue(dock.collapsed == true, true) end
	if self.dockComposerAutoHideToggle then
		local autoHide = addon.GetComposerAutoHideSetting and addon:GetComposerAutoHideSetting()
		if autoHide == nil then
			autoHide = dock.composerAutoHide == true or dock.showComposer == false
		end
		self.dockComposerAutoHideToggle:SetValue(autoHide and true or false, true)
	end
	if self.dockEditBoxBorderToggle then
		local borderEnabled = addon.GetEditBoxBorderSetting and addon:GetEditBoxBorderSetting()
		if borderEnabled == nil then borderEnabled = dock.editBoxBorder == true end
		self.dockEditBoxBorderToggle:SetValue(borderEnabled and true or false, true)
	end
	local history = addon.GetChatHistorySettings and addon:GetChatHistorySettings() or {
		enabled = addon:GetSmartSettings().persistHistory ~= false,
		linesPerSource = tonumber(addon:GetSmartSettings().historyCapacity) or 1000,
	}
	if self.dockHistoryToggle then self.dockHistoryToggle:SetValue(history.enabled ~= false, true) end
	if self.dockHistoryLinesEdit then
		self.dockHistoryLinesEdit:SetText(tostring(math.floor(tonumber(history.linesPerSource) or 1000)))
	end
	local responsive = type(addon.GetResponsiveMetadata) == "function" and addon:GetResponsiveMetadata()
	if responsive == nil then responsive = dock.responsiveMetadata ~= false end
	if self.dockResponsiveMetadataToggle then self.dockResponsiveMetadataToggle:SetValue(responsive ~= false, true) end
	if self.dockLineSpacingEdit then
		local appearance
		if type(addon.GetSmartChatTextAppearance) == "function" then
			local ok, value = pcall(addon.GetSmartChatTextAppearance, addon, "global")
			if ok and type(value) == "table" then appearance = value end
		end
		appearance = appearance or addon:GetSmartSettings().textAppearance or {}
		self.dockLineSpacingEdit:SetText(tostring(math.floor((tonumber(appearance.spacing) or 1) + 0.5)))
	end
	local bands = addon.GetSmartChatMessageBandSettings and addon:GetSmartChatMessageBandSettings()
		or dock.messageBands or {}
	if self.dockMessageBandsToggle then self.dockMessageBandsToggle:SetValue(bands.enabled == true, true) end
	if self.dockMessageBandsScrollbarToggle then
		self.dockMessageBandsScrollbarToggle:SetValue(bands.extendUnderScrollbar == true, true)
	end
	local extent = bands.extent or "full"
	for id, button in pairs(self.dockMessageBandExtentButtons or {}) do
		setChoiceStyle(button, id == extent)
	end
	local bandColor = type(bands.color) == "table" and bands.color or {}
	local bandTheme = bandColor.mode == "theme" and (bandColor.theme or "surfaceRaised") or "custom"
	for id, button in pairs(self.dockMessageBandColorButtons or {}) do
		setChoiceStyle(button, id == bandTheme)
	end
	if self.dockMessageBandAlphaEdit then
		self.dockMessageBandAlphaEdit:SetText(tostring(math.floor(((tonumber(bands.alpha) or 0.50) * 100) + 0.5)))
	end
	if self.dockScrollToggle then self.dockScrollToggle:SetValue(dock.showScrollButtons ~= false, true) end
	if self.dockCompactTitleToggle then self.dockCompactTitleToggle:SetValue(dock.compactHeader ~= false, true) end
	if self.dockTagsToggle then self.dockTagsToggle:SetValue(dock.showClassificationTags ~= false, true) end
	if self.dockHideSocialToggle then self.dockHideSocialToggle:SetValue(dock.hideSocialButton == true, true) end
	local newMessages = addon.GetNewMessageIndicatorSettings and addon:GetNewMessageIndicatorSettings() or {}
	if self.dockNewMessagesToggle then self.dockNewMessagesToggle:SetValue(newMessages.enabled ~= false, true) end
	if self.dockNewMessagesCountToggle then self.dockNewMessagesCountToggle:SetValue(newMessages.showCount ~= false, true) end
	if self.dockNewMessagesMaxEdit then
		self.dockNewMessagesMaxEdit:SetText(tostring(tonumber(newMessages.maxCount) or 99))
	end
	local vertical = dock.railOrientation == "vertical"
	if self.dockHorizontalButton then
		self.dockHorizontalButton:SetTheme(vertical and "surfaceRaised" or "accentSoft", vertical and "borderMuted" or "gold", vertical and "text" or "goldBright")
	end
	if self.dockVerticalButton then
		self.dockVerticalButton:SetTheme(vertical and "accentSoft" or "surfaceRaised", vertical and "gold" or "borderMuted", vertical and "goldBright" or "text")
	end
	local railVisibility = dock.railVisibility or "always"
	local function styleRailVisibilityButton(button, active)
		if button then
			button:SetTheme(active and "accentSoft" or "surfaceRaised", active and "gold" or "borderMuted", active and "goldBright" or "text")
		end
	end
	styleRailVisibilityButton(self.dockRailAlwaysButton, railVisibility == "always")
	styleRailVisibilityButton(self.dockRailMouseoverButton, railVisibility == "mouseover")
	styleRailVisibilityButton(self.dockRailClickButton, railVisibility == "click")
	styleRailVisibilityButton(self.dockRailHiddenButton, railVisibility == "hidden")
	local headerVisibility = dock.headerVisibility or "hover"
	local function styleHeaderVisibilityButton(button, active)
		if button then
			button:SetTheme(active and "accentSoft" or "surfaceRaised", active and "gold" or "borderMuted", active and "goldBright" or "text")
		end
	end
	styleHeaderVisibilityButton(self.dockTitleBarAlwaysButton, headerVisibility == "always")
	styleHeaderVisibilityButton(self.dockTitleBarHoverButton, headerVisibility == "hover")
	styleHeaderVisibilityButton(self.dockTitleBarHiddenButton, headerVisibility == "hidden")
	if self.dockWidthEdit then self.dockWidthEdit:SetText(tostring(tonumber(dock.width) or DOCK_DEFAULT_WIDTH)) end
	if self.dockHeightEdit then self.dockHeightEdit:SetText(tostring(tonumber(dock.height) or DOCK_DEFAULT_HEIGHT)) end
	local transparency = addon.GetSmartChatWindowTransparency and addon:GetSmartChatWindowTransparency()
		or dock.transparency or {}
	if self.dockBackgroundAlphaEdit then
		self.dockBackgroundAlphaEdit:SetText(tostring(math.floor(((tonumber(transparency.backgroundAlpha) or 1) * 100) + 0.5)))
	end
	if self.dockBorderAlphaEdit then
		self.dockBorderAlphaEdit:SetText(tostring(math.floor(((tonumber(transparency.borderAlpha) or 1) * 100) + 0.5)))
	end
	if self.dockOverallAlphaEdit then
		self.dockOverallAlphaEdit:SetText(tostring(math.floor(((tonumber(transparency.overallAlpha) or 1) * 100) + 0.5)))
	end
	self:RefreshDockSections()
	self:RefreshNewMessageIndicatorAppearance()
	self:RefreshRailUnreadCountAppearance()
end

local function createDockToggle(parent, label, x, y, width, key, action)
	local toggle = Theme:CreateCompactToggle(parent, label, width)
	toggle:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	toggle.OnValueChanged = function(_, value)
		getDockSettings()[key] = value and true or false
		applyDockRuntime(action, value)
		Config:SetDockStatus("Layout applied immediately.", "success")
	end
	return toggle
end

function Config:BuildDockPage()
	local page = self:CreatePage("dock")
	self.dockPage = page
	local _, subtitle = createHeading(page, "Chat Window", "Choose one area below. Every change applies immediately to the live chat window.")
	self.dockHeadingSubtitle = subtitle
	self.dockColorsTabButton = Theme:CreateTightButton(page, "CHAT COLORS", 20, false)
	self.dockColorsTabButton:SetPoint("TOPRIGHT", page, "TOPRIGHT", -PAGE_GUTTER, -8)
	self.dockColorsTabButton:SetScript("OnClick", function()
		Config:SetDockSection("colors")
	end)
	self.dockLayoutTabButton = Theme:CreateTightButton(page, "LAYOUT", 20, false)
	self.dockLayoutTabButton:SetPoint("RIGHT", self.dockColorsTabButton, "LEFT", -CONTROL_GAP, 0)
	self.dockLayoutTabButton:SetScript("OnClick", function()
		Config:SetDockSection("layout")
	end)
	self.dockSection = self.dockSection == "colors" and "colors" or "layout"
	self.dockLayoutCategory = dockLayoutCategoryDefinitions[self.dockLayoutCategory] and self.dockLayoutCategory or "window"

	-- Layout is a small settings workspace, not one long form. Only one of these
	-- inspectors is visible at a time, which keeps related decisions together
	-- and leaves enough vertical room for every disclosed state.
	self.dockLayoutNavigationControls = {}
	self.dockLayoutCategoryButtons = {}
	local previousCategory
	for _, id in ipairs(dockLayoutCategoryOrder) do
		local definition = dockLayoutCategoryDefinitions[id]
		local button = Theme:CreateTightButton(page, definition.title, 22, false)
		if previousCategory then
			button:SetPoint("LEFT", previousCategory, "RIGHT", 5, 0)
		else
			button:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -48)
		end
		setControlTooltip(button, definition.heading, definition.tooltip)
		button:SetScript("OnClick", function()
			Config:SetDockLayoutCategory(id)
		end)
		self.dockLayoutCategoryButtons[id] = button
		table.insert(self.dockLayoutNavigationControls, button)
		previousCategory = button
	end
	self.dockLayoutSectionTitle = Theme:CreateText(page, "GameFontNormal", "goldBright")
	self.dockLayoutSectionTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -82)
	self.dockLayoutSectionHint = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	self.dockLayoutSectionHint:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -101)
	self.dockLayoutSectionHint:SetWidth(PAGE_WIDTH)
	self.dockLayoutSectionHint:SetJustifyH("LEFT")
	table.insert(self.dockLayoutNavigationControls, self.dockLayoutSectionTitle)
	table.insert(self.dockLayoutNavigationControls, self.dockLayoutSectionHint)

	local stateTitle = Theme:CreateText(page, "GameFontNormalSmall", "gold")
	stateTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -132)
	stateTitle:SetText("FRAME STATE")
	self.dockVisibleToggle = createDockToggle(page, "SHOW CHAT", PAGE_GUTTER, 151, 150, "visible", "visible")
	self.dockCollapsedToggle = createDockToggle(page, "COLLAPSE CHAT", 170, 151, 150, "collapsed", "collapsed")
	self.dockHideSocialToggle = createDockToggle(page, "HIDE SOCIAL BUTTON", PAGE_GUTTER, 181, 190, "hideSocialButton", "socialButton")
	self.dockTagsToggle = createDockToggle(page, "HELPER TAGS", 208, 181, 170, "showClassificationTags", "classificationTags")
	setControlTooltip(self.dockVisibleToggle, "Show chat", "Turns Chatty's organized chat window on or off.")
	setControlTooltip(self.dockCollapsedToggle, "Collapse chat", "Keeps only the compact title controls visible until the window is expanded.")
	setControlTooltip(self.dockHideSocialToggle, "Hide social button", "Removes Blizzard's social notification button from the Chatty window.")
	setControlTooltip(self.dockTagsToggle, "Helper tags", "Shows Chatty's routing hints on messages when available.")

	local transparencyTitle = Theme:CreateText(page, "GameFontNormalSmall", "gold")
	transparencyTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -231)
	transparencyTitle:SetText("WINDOW TRANSPARENCY")
	local transparencyHint = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	transparencyHint:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -250)
	transparencyHint:SetWidth(PAGE_WIDTH)
	transparencyHint:SetJustifyH("LEFT")
	transparencyHint:SetText("Background and border opacity leave chat text crisp. Whole UI also fades text and controls.")
	local function createTransparencyField(label, x, setterName, key)
		local fieldLabel = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
		fieldLabel:SetPoint("TOPLEFT", page, "TOPLEFT", x, -276)
		fieldLabel:SetText(label)
		local editBox = Theme:CreateEditBox(page, 64, 22, false)
		editBox:SetPoint("TOPLEFT", page, "TOPLEFT", x, -292)
		setControlTooltip(editBox, label .. " opacity", key == "overallAlpha"
			and "Fades the complete Chatty window, including messages and controls. Use 0 to 100%."
			or "Fades only this part of Chatty's chrome. Message text remains fully opaque. Use 0 to 100%.")
		local function commit()
			local value = tonumber(editBox:GetText())
			if not value or value < 0 or value > 100 then
				Config:RefreshDockPage()
				Config:SetDockStatus("Use opacity from 0% to 100%.", "warning")
				return
			end
			value = math.floor(value + 0.5) / 100
			if type(addon[setterName]) == "function" then
				addon[setterName](addon, value)
			else
				local dock = getDockSettings()
				dock.transparency = dock.transparency or {}
				dock.transparency[key] = value
				if addon.SmartDock and addon.SmartDock.RefreshTransparency then
					addon.SmartDock:RefreshTransparency()
				end
			end
			Config:RefreshDockPage()
			Config:SetDockStatus(label .. " opacity set to " .. tostring(math.floor(value * 100 + 0.5)) .. "%.", "success")
		end
		editBox:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
		editBox:HookScript("OnEditFocusLost", commit)
		return fieldLabel, editBox
	end
	local backgroundAlphaLabel
	backgroundAlphaLabel, self.dockBackgroundAlphaEdit = createTransparencyField("BACKGROUND %", PAGE_GUTTER,
		"SetSmartChatWindowBackgroundAlpha", "backgroundAlpha")
	local borderAlphaLabel
	borderAlphaLabel, self.dockBorderAlphaEdit = createTransparencyField("BORDER %", 118,
		"SetSmartChatWindowBorderAlpha", "borderAlpha")
	local overallAlphaLabel
	overallAlphaLabel, self.dockOverallAlphaEdit = createTransparencyField("WHOLE UI %", 228,
		"SetSmartChatWindowOverallAlpha", "overallAlpha")
	self.dockTransparencyResetButton = Theme:CreateTightButton(page, "RESET OPACITY", 22, false)
	self.dockTransparencyResetButton:SetPoint("LEFT", self.dockOverallAlphaEdit, "RIGHT", 8, 0)
	setControlTooltip(self.dockTransparencyResetButton, "Reset window opacity", "Restores background, border, messages, and controls to full opacity.")
	self.dockTransparencyResetButton:SetScript("OnClick", function()
		if type(addon.ResetSmartChatWindowTransparency) == "function" then
			addon:ResetSmartChatWindowTransparency()
		else
			getDockSettings().transparency = { backgroundAlpha = 1, borderAlpha = 1, overallAlpha = 1 }
			if addon.SmartDock and addon.SmartDock.RefreshTransparency then addon.SmartDock:RefreshTransparency() end
		end
		Config:RefreshDockPage()
		Config:SetDockStatus("Window opacity restored.", "success")
	end)

	local railVisibilityTitle = Theme:CreateText(page, "GameFontNormalSmall", "gold")
	railVisibilityTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -132)
	railVisibilityTitle:SetText("TAB VISIBILITY")
	local railVisibilityHint = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	railVisibilityHint:SetPoint("TOPLEFT", railVisibilityTitle, "BOTTOMLEFT", 0, -2)
	railVisibilityHint:SetText("When the GENERAL / CHAT / LFG navigation strip appears.")

	local directionTitle = Theme:CreateText(page, "GameFontNormalSmall", "gold")
	directionTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -210)
	directionTitle:SetText("TAB BAR DIRECTION")
	self.dockHorizontalButton = Theme:CreateTightButton(page, "HORIZONTAL", 22, false)
	self.dockHorizontalButton:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -228)
	self.dockHorizontalButton:SetScript("OnClick", function()
		getDockSettings().railOrientation = "horizontal"
		applyDockRuntime()
		Config:RefreshDockPage()
		Config:SetDockStatus("Horizontal chat tabs applied.", "success")
	end)
	setControlTooltip(self.dockHorizontalButton, "Horizontal tabs", "Places the chat-tab strip across the top or bottom edge selected by the dock layout.")
	self.dockVerticalButton = Theme:CreateTightButton(page, "VERTICAL", 22, false)
	self.dockVerticalButton:SetPoint("LEFT", self.dockHorizontalButton, "RIGHT", CONTROL_GAP, 0)
	self.dockVerticalButton:SetScript("OnClick", function()
		getDockSettings().railOrientation = "vertical"
		applyDockRuntime()
		Config:RefreshDockPage()
		Config:SetDockStatus("Vertical chat tabs applied.", "success")
	end)
	setControlTooltip(self.dockVerticalButton, "Vertical tabs", "Places the chat-tab strip along the side of the chat window.")

	local function createRailVisibilityButton(label, mode, anchor, relative)
		local button = Theme:CreateTightButton(page, label, 22, false)
		if relative then
			button:SetPoint("LEFT", anchor, "RIGHT", CONTROL_GAP, 0)
		else
			button:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -172)
		end
		button:SetScript("OnClick", function()
			getDockSettings().railVisibility = mode
			applyDockRuntime("railVisibility", mode)
			Config:RefreshDockPage()
			local status = mode == "always" and "Chat tabs stay visible."
				or (mode == "mouseover" and "Chat tabs appear while the mouse is over the dock."
				or (mode == "click" and "Chat tabs appear when the chat frame is clicked." or "Chat tabs remain hidden."))
			Config:SetDockStatus(status, "success")
		end)
		setControlTooltip(button, "Tab visibility: " .. string.lower(label), mode == "always" and "The chat-tab strip stays visible."
			or (mode == "mouseover" and "The strip appears while the pointer is over the chat window."
			or (mode == "click" and "The strip appears after clicking inside the chat window."
			or "The strip stays hidden until this setting is changed.")))
		return button
	end
	self.dockRailAlwaysButton = createRailVisibilityButton("ALWAYS", "always")
	self.dockRailMouseoverButton = createRailVisibilityButton("MOUSEOVER", "mouseover", self.dockRailAlwaysButton, true)
	self.dockRailClickButton = createRailVisibilityButton("ON CLICK", "click", self.dockRailMouseoverButton, true)
	self.dockRailHiddenButton = createRailVisibilityButton("HIDDEN", "hidden", self.dockRailClickButton, true)

	local titleBarVisibilityTitle = Theme:CreateText(page, "GameFontNormalSmall", "gold")
	titleBarVisibilityTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -266)
	titleBarVisibilityTitle:SetText("TITLE BAR: VISIBILITY")
	local function createTitleBarVisibilityButton(label, mode, anchor, relative)
		local button = Theme:CreateTightButton(page, label, 22, false)
		if relative then
			button:SetPoint("LEFT", anchor, "RIGHT", CONTROL_GAP, 0)
		else
			button:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -284)
		end
		button:SetScript("OnClick", function()
			getDockSettings().headerVisibility = mode
			applyDockRuntime("headerVisibility", mode)
			Config:RefreshDockPage()
			local status = mode == "always" and "Title bar stays visible."
				or (mode == "hover" and "Title bar appears while the mouse is over the dock."
				or "Title bar is hidden while expanded; a collapsed dock still shows its controls.")
			Config:SetDockStatus(status, mode == "hidden" and "warning" or "success")
		end)
		setControlTooltip(button, "Title bar: " .. string.lower(label), mode == "always" and "The title bar stays visible."
			or (mode == "hover" and "The title bar appears while the pointer is over the chat window."
			or "The title bar stays hidden while the chat window is expanded."))
		return button
	end
	self.dockTitleBarAlwaysButton = createTitleBarVisibilityButton("ALWAYS", "always")
	self.dockTitleBarHoverButton = createTitleBarVisibilityButton("ON HOVER", "hover", self.dockTitleBarAlwaysButton, true)
	self.dockTitleBarHiddenButton = createTitleBarVisibilityButton("HIDDEN", "hidden", self.dockTitleBarHoverButton, true)
	local headerControlsTitle = Theme:CreateText(page, "GameFontNormalSmall", "gold")
	headerControlsTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -324)
	headerControlsTitle:SetText("TITLE BAR CONTROLS")

	local chromeTitle = Theme:CreateText(page, "GameFontNormalSmall", "gold")
	chromeTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -132)
	chromeTitle:SetText("TYPING FIELD")
	self.dockComposerAutoHideToggle = Theme:CreateCompactToggle(page, "HIDE INPUT WHEN IDLE", 210)
	self.dockComposerAutoHideToggle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -151)
	self.dockComposerAutoHideToggle.OnValueChanged = function(_, value)
		if addon.SetComposerAutoHide then
			addon:SetComposerAutoHide(value)
		else
			local dock = getDockSettings()
			dock.composerAutoHide = value and true or false
			dock.showComposer = not dock.composerAutoHide
			applyDockRuntime()
		end
		Config:RefreshDockPage()
		Config:SetDockStatus(value
			and "Composer hides while idle and chat fills its space. Enter, /, or reply reveals it temporarily."
			or "Composer stays visible while idle.", "success")
	end
	self.dockScrollToggle = createDockToggle(page, "SLIM SCROLLBAR", PAGE_GUTTER, 342, 150, "showScrollButtons")
	self.dockCompactTitleToggle = createDockToggle(page, "COMPACT TITLE", 170, 342, 150, "compactHeader")
	setControlTooltip(self.dockScrollToggle, "Slim scrollbar", "Shows a narrow Colorway-aware drag thumb. A bottom-jump icon appears only while you are scrolled up; the mouse wheel always works over chat.")
	setControlTooltip(self.dockCompactTitleToggle, "Compact title", "Uses the shorter title-bar treatment to reserve more room for messages.")
	-- Keep this explicit: it affects only the background/border behind the
	-- shared typing field, not the channel selector, route menu, or chat frame.
	self.dockEditBoxBorderToggle = Theme:CreateCompactToggle(page, "TYPING FIELD BORDER", 220)
	self.dockEditBoxBorderToggle:SetPoint("TOPLEFT", page, "TOPLEFT", 238, -151)
	self.dockEditBoxBorderToggle.OnValueChanged = function(_, value)
		if addon.SetEditBoxBorderEnabled then
			addon:SetEditBoxBorderEnabled(value)
		else
			local dock = getDockSettings()
			dock.editBoxBorder = value and true or false
			dock.composerInputPolishSchema = 2
			applyDockRuntime()
		end
		Config:RefreshDockPage()
		Config:SetDockStatus(value
			and "Typing-field background and border shown."
			or "Typing field returns to the clean integrated chat surface.", "success")
	end
	setControlTooltip(self.dockComposerAutoHideToggle, "Hide input when idle", "The message list grows into this space. Enter, slash, or reply reveals the typing field again.")
	setControlTooltip(self.dockEditBoxBorderToggle, "Typing-field border", "Affects only the typing field's own background and border, not the channel selector or outer chat frame.")

	local historyTitle = Theme:CreateText(page, "GameFontNormalSmall", "gold")
	historyTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -211)
	historyTitle:SetText("RECEIVED CHAT HISTORY")
	self.dockHistoryToggle = Theme:CreateCompactToggle(page, "RESTORE AFTER LOGIN", 204)
	self.dockHistoryToggle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -230)
	self.dockHistoryToggle.OnValueChanged = function(_, value)
		if type(addon.SetChatHistoryPersistenceEnabled) == "function" then
			addon:SetChatHistoryPersistenceEnabled(value)
		else
			addon:GetSmartSettings().persistHistory = value and true or false
		end
		Config:RefreshDockPage()
		Config:SetDockStatus(value
			and "Received chat will restore separately for every source after login."
			or "Saved received-chat text erased; new history remains session-only.", value and "success" or "warning")
	end
	setControlTooltip(self.dockHistoryToggle, "Restore received chat after login",
		"Saves a bounded history for each source, including whispers, in this character's local SavedVariables. Turning this off erases the saved text immediately.")
	local historyLinesLabel = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	historyLinesLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 232, -214)
	historyLinesLabel:SetText("LINES / SOURCE")
	self.dockHistoryLinesEdit = Theme:CreateEditBox(page, 74, 22, false)
	self.dockHistoryLinesEdit:SetPoint("TOPLEFT", page, "TOPLEFT", 232, -230)
	setControlTooltip(self.dockHistoryLinesEdit, "History lines per source",
		"Keeps 100 to 10,000 received messages independently for each source. The default is 1,000.")
	local function commitHistoryLines()
		local value = tonumber(Config.dockHistoryLinesEdit:GetText())
		if not value or value < 100 or value > 10000 then
			Config:RefreshDockPage()
			Config:SetDockStatus("Use 100 to 10,000 history lines per source.", "warning")
			return
		end
		value = math.floor(value + 0.5)
		if type(addon.SetChatHistoryLinesPerSource) == "function" then
			addon:SetChatHistoryLinesPerSource(value)
		else
			addon:GetSmartSettings().historyCapacity = value
		end
		Config:RefreshDockPage()
		Config:SetDockStatus(tostring(value) .. " lines will be retained for each chat source.", "success")
	end
	self.dockHistoryLinesEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.dockHistoryLinesEdit:HookScript("OnEditFocusLost", commitHistoryLines)
	self.dockClearHistoryButton = Theme:CreateTightButton(page, "CLEAR HISTORY", 22, false)
	self.dockClearHistoryButton:SetPoint("LEFT", self.dockHistoryLinesEdit, "RIGHT", 8, 0)
	setActionStyle(self.dockClearHistoryButton, "danger", "Clear received-chat history",
		"Erases saved and current Chatty history for every source. Settings and block/spam rules are kept.")
	self.dockClearHistoryButton:SetScript("OnClick", function(self)
		if not self.confirming then
			self.confirming = true
			self:SetLabel("CONFIRM CLEAR")
			Config:SetDockStatus("Click CONFIRM CLEAR to erase received-chat history from every source.", "warning")
			return
		end
		self.confirming = false
		self:SetLabel("CLEAR HISTORY")
		if type(addon.ClearChatHistory) == "function" then addon:ClearChatHistory() end
		Config:SetDockStatus("Received-chat history cleared from every source.", "success")
	end)
	local historyHint = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	historyHint:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -260)
	historyHint:SetWidth(PAGE_WIDTH)
	historyHint:SetJustifyH("LEFT")
	historyHint:SetText("One shared copy of each message is stored, then restored into every matching tab without duplicating it.")

	local responsiveTitle = Theme:CreateText(page, "GameFontNormalSmall", "gold")
	responsiveTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -132)
	responsiveTitle:SetText("RESPONSIVE MESSAGE DETAILS")
	self.dockResponsiveMetadataToggle = Theme:CreateCompactToggle(page, "ADAPT TO WINDOW WIDTH", 240)
	self.dockResponsiveMetadataToggle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -151)
	self.dockResponsiveMetadataToggle.OnValueChanged = function(_, value)
		if type(addon.SetResponsiveMetadata) == "function" then
			addon:SetResponsiveMetadata(value)
		else
			getDockSettings().responsiveMetadata = value and true or false
			if addon.SmartDock and addon.SmartDock.RefreshResponsiveMetadata then
				addon.SmartDock:RefreshResponsiveMetadata()
			end
		end
		Config:SetDockStatus(value
			and "Narrow chat now sheds time, then channel, while keeping the message readable."
			or "Full timestamp, channel, and player metadata is locked on at every width.", "success")
	end
	setControlTooltip(self.dockResponsiveMetadataToggle, "Adapt details to window width",
		"Wide: time + channel + player. Medium: channel + player. Narrow: player. Extremely narrow: message only. Turning this off locks the full layout.")
	local lineSpacingTitle = Theme:CreateText(page, "GameFontNormalSmall", "gold")
	lineSpacingTitle:SetPoint("TOPLEFT", page, "TOPLEFT", 300, -132)
	lineSpacingTitle:SetText("GLOBAL LINE GAP")
	self.dockLineSpacingTitle = lineSpacingTitle
	self.dockLineSpacingEdit = Theme:CreateEditBox(page, 44, 22, false)
	self.dockLineSpacingEdit:SetPoint("TOPLEFT", page, "TOPLEFT", 300, -151)
	local lineSpacingHint = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	lineSpacingHint:SetPoint("LEFT", self.dockLineSpacingEdit, "RIGHT", 8, 0)
	lineSpacingHint:SetWidth(90)
	lineSpacingHint:SetJustifyH("LEFT")
	lineSpacingHint:SetText("0-8 PX / ALL TABS")
	self.dockLineSpacingHint = lineSpacingHint
	setControlTooltip(lineSpacingTitle, "Global line gap",
		"Adds 0 to 8 pixels between every rendered chat line, including wrapped lines. A tab can override this under Views & Tabs > Text.")
	setControlTooltip(self.dockLineSpacingEdit, "Global line gap",
		"Use a whole number from 0 to 8 pixels. This controls vertical spacing, not channel or player-name columns.")
	local function commitGlobalLineSpacing()
		local value = tonumber(Config.dockLineSpacingEdit:GetText())
		if value == nil or value ~= math.floor(value) or value < 0 or value > 8 then
			Config:RefreshDockPage()
			Config:SetDockStatus("Line gap must be a whole number from 0 to 8 pixels.", "warning")
			return
		end
		local accepted = false
		if type(addon.SetSmartChatTextAppearance) == "function" then
			local ok, result = pcall(addon.SetSmartChatTextAppearance, addon, "global", { spacing = value })
			accepted = ok and result ~= false
		else
			local settings = addon:GetSmartSettings()
			settings.textAppearance = type(settings.textAppearance) == "table" and settings.textAppearance or {}
			settings.textAppearance.spacing = value
			if addon.SmartDock and type(addon.SmartDock.RefreshSmartChatTextAppearance) == "function" then
				addon.SmartDock:RefreshSmartChatTextAppearance()
			end
			accepted = true
		end
		Config:RefreshDockPage()
		Config:SetDockStatus(accepted and ("Global line gap set to " .. tostring(value) .. " pixels.")
			or "Line gap could not be applied.", accepted and "success" or "warning")
	end
	self.dockLineSpacingEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.dockLineSpacingEdit:HookScript("OnEditFocusLost", commitGlobalLineSpacing)
	local responsiveHint = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	responsiveHint:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -180)
	responsiveHint:SetWidth(PAGE_WIDTH)
	responsiveHint:SetJustifyH("LEFT")
	responsiveHint:SetText("Your alignment and gap choices remain saved and return automatically when the window grows.")

	local bandsTitle = Theme:CreateText(page, "GameFontNormalSmall", "gold")
	bandsTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -225)
	bandsTitle:SetText("TABLE-STYLE MESSAGE ROWS")
	self.dockMessageBandsToggle = Theme:CreateCompactToggle(page, "ALTERNATING ROWS", 250)
	self.dockMessageBandsToggle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -244)
	self.dockMessageBandsToggle.OnValueChanged = function(_, value)
		if type(addon.SetSmartChatMessageBandsEnabled) == "function" then
			addon:SetSmartChatMessageBandsEnabled(value)
		else
			local dock = getDockSettings()
			dock.messageBands = dock.messageBands or {}
			dock.messageBands.enabled = value and true or false
			if addon.SmartDock and addon.SmartDock.RefreshMessageBands then addon.SmartDock:RefreshMessageBands() end
		end
		Config:SetDockStatus(value and "Alternating logical messages shaded." or "Message shading disabled.", "success")
	end
	setControlTooltip(self.dockMessageBandsToggle, "Shade alternating messages",
		"A wrapped message keeps one continuous background; the next logical chat entry alternates.")
	self.dockMessageBandsScrollbarToggle = Theme:CreateCompactToggle(page, "UNDER SCROLLBAR", 230)
	self.dockMessageBandsScrollbarToggle:SetPoint("LEFT", self.dockMessageBandsToggle, "RIGHT", CONTROL_GAP, 0)
	self.dockMessageBandsScrollbarToggle.OnValueChanged = function(_, value)
		if type(addon.SetSmartChatMessageBandExtendUnderScrollbar) == "function" then
			addon:SetSmartChatMessageBandExtendUnderScrollbar(value)
		else
			local dock = getDockSettings()
			dock.messageBands = dock.messageBands or {}
			dock.messageBands.extendUnderScrollbar = value and true or false
			if addon.SmartDock and addon.SmartDock.RefreshMessageBands then addon.SmartDock:RefreshMessageBands() end
		end
		Config:SetDockStatus(value and "Alternating shade now continues beneath the transparent scrollbar lane."
			or "Alternating shade now ends before the scrollbar lane.", "success")
	end
	setControlTooltip(self.dockMessageBandsScrollbarToggle, "Extend row shade",
		"Extends only the alternating background through the transparent scrollbar lane. Chat text, wrapping, hyperlinks, and scrollbar hit targets never move.")
	local extentTitle = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	extentTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -278)
	extentTitle:SetText("ROW SPAN")
	self.dockMessageBandExtentButtons = {}
	local previousExtent = extentTitle
	for _, definition in ipairs({
		{ id = "full", label = "FULL ROW" },
		{ id = "afterTimestamp", label = "AFTER TIME" },
		{ id = "afterChannel", label = "AFTER CHANNEL" },
		{ id = "afterPlayer", label = "AFTER PLAYER" },
	}) do
		local button = Theme:CreateTightButton(page, definition.label, 20, false)
		button:SetPoint("LEFT", previousExtent, "RIGHT", CONTROL_GAP, 0)
		button:SetScript("OnClick", function()
			if type(addon.SetSmartChatMessageBandExtent) == "function" then
				addon:SetSmartChatMessageBandExtent(definition.id)
			else
				local dock = getDockSettings()
				dock.messageBands = dock.messageBands or {}
				dock.messageBands.extent = definition.id
				if addon.SmartDock and addon.SmartDock.RefreshMessageBands then addon.SmartDock:RefreshMessageBands() end
			end
			Config:RefreshDockPage()
			Config:SetDockStatus(definition.label .. " background extent applied.", "success")
		end)
		self.dockMessageBandExtentButtons[definition.id] = button
		previousExtent = button
	end
	local bandColorTitle = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	bandColorTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -326)
	bandColorTitle:SetText("ROW COLOR")
	self.dockMessageBandColorButtons = {}
	local previousBandColor = bandColorTitle
	for _, definition in ipairs({
		{ id = "surfaceRaised", label = "NEUTRAL" },
		{ id = "accentSoft", label = "TINT" },
		{ id = "accent", label = "BRIGHT" },
		{ id = "gold", label = "GOLD" },
	}) do
		local button = Theme:CreateTightButton(page, definition.label, 20, false)
		button:SetPoint("LEFT", previousBandColor, "RIGHT", CONTROL_GAP, 0)
		button:SetScript("OnClick", function()
			local r, g, b = Theme:GetColor(definition.id)
			if type(addon.SetSmartChatMessageBandColor) == "function" then
				addon:SetSmartChatMessageBandColor(r, g, b, definition.id)
			else
				local dock = getDockSettings()
				dock.messageBands = dock.messageBands or {}
				dock.messageBands.color = { mode = "theme", theme = definition.id, r = r, g = g, b = b }
				if addon.SmartDock and addon.SmartDock.RefreshMessageBands then addon.SmartDock:RefreshMessageBands() end
			end
			Config:RefreshDockPage()
			Config:SetDockStatus(definition.label .. " message shade selected.", "success")
		end)
		self.dockMessageBandColorButtons[definition.id] = button
		previousBandColor = button
	end
	local bandAlphaLabel = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	bandAlphaLabel:SetPoint("LEFT", previousBandColor, "RIGHT", 12, 0)
	bandAlphaLabel:SetText("OPACITY %")
	self.dockMessageBandAlphaEdit = Theme:CreateEditBox(page, 44, 20, false)
	self.dockMessageBandAlphaEdit:SetPoint("LEFT", bandAlphaLabel, "RIGHT", 4, 0)
	setControlTooltip(self.dockMessageBandAlphaEdit, "Message shade opacity", "Use 0 to 100%. This affects only alternating backgrounds, never message text.")
	local function commitBandAlpha()
		local value = tonumber(Config.dockMessageBandAlphaEdit:GetText())
		if not value or value < 0 or value > 100 then
			Config:RefreshDockPage()
			Config:SetDockStatus("Use message shade opacity from 0% to 100%.", "warning")
			return
		end
		value = math.floor(value + 0.5) / 100
		if type(addon.SetSmartChatMessageBandAlpha) == "function" then
			addon:SetSmartChatMessageBandAlpha(value)
		else
			local dock = getDockSettings()
			dock.messageBands = dock.messageBands or {}
			dock.messageBands.alpha = value
			if addon.SmartDock and addon.SmartDock.RefreshMessageBands then addon.SmartDock:RefreshMessageBands() end
		end
		Config:RefreshDockPage()
		Config:SetDockStatus("Message shade opacity set to " .. tostring(math.floor(value * 100 + 0.5)) .. "%.", "success")
	end
	self.dockMessageBandAlphaEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.dockMessageBandAlphaEdit:HookScript("OnEditFocusLost", commitBandAlpha)
	self.dockMessageBandsResetButton = Theme:CreateTightButton(page, "RESET BANDS", 22, false)
	self.dockMessageBandsResetButton:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -386)
	self.dockMessageBandsResetButton:SetScript("OnClick", function()
		if type(addon.ResetSmartChatMessageBands) == "function" then addon:ResetSmartChatMessageBands() end
		Config:RefreshDockPage()
		Config:SetDockStatus("Alternating message backgrounds restored to defaults.", "success")
	end)
	local bandsHint = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	bandsHint:SetPoint("TOPLEFT", self.dockMessageBandsResetButton, "BOTTOMLEFT", 0, -8)
	bandsHint:SetWidth(PAGE_WIDTH)
	bandsHint:SetJustifyH("LEFT")
	bandsHint:SetText("FULL ROW + NEUTRAL creates the familiar, quiet zebra pattern used by readable tables.")

	local newMessagesTitle = Theme:CreateText(page, "GameFontNormalSmall", "gold")
	newMessagesTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -132)
	newMessagesTitle:SetText("BEHAVIOR")
	self.dockNewMessagesToggle = Theme:CreateCompactToggle(page, "SHOW MARKER", 142)
	self.dockNewMessagesToggle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -151)
	self.dockNewMessagesToggle.OnValueChanged = function(_, value)
		if addon.SetNewMessageIndicatorEnabled then
			addon:SetNewMessageIndicatorEnabled(value)
		end
		Config:SetDockStatus(value and "New-message marker enabled." or "New-message marker hidden.", "success")
	end
	self.dockNewMessagesCountToggle = Theme:CreateCompactToggle(page, "SHOW COUNT", 142)
	self.dockNewMessagesCountToggle:SetPoint("LEFT", self.dockNewMessagesToggle, "RIGHT", CONTROL_GAP, 0)
	self.dockNewMessagesCountToggle.OnValueChanged = function(_, value)
		if addon.SetNewMessageIndicatorShowCount then
			addon:SetNewMessageIndicatorShowCount(value)
		end
		Config:SetDockStatus(value and "Unread count shown on the marker." or "Marker now uses the compact NEW label.", "success")
	end
	local newMessagesCapLabel = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	newMessagesCapLabel:SetPoint("LEFT", self.dockNewMessagesCountToggle, "RIGHT", 18, 0)
	newMessagesCapLabel:SetText("CAP")
	self.dockNewMessagesMaxEdit = Theme:CreateEditBox(page, 54, 22, false)
	self.dockNewMessagesMaxEdit:SetPoint("LEFT", newMessagesCapLabel, "RIGHT", 6, 0)
	setControlTooltip(self.dockNewMessagesToggle, "Show unread marker", "Shows NEW when messages arrive outside the active tab or while the chat is not at the bottom.")
	setControlTooltip(self.dockNewMessagesCountToggle, "Show unread count", "Adds the number of unread messages to the marker.")
	setControlTooltip(self.dockNewMessagesMaxEdit, "Unread-count cap", "The highest count shown before the marker stops increasing. Use 9 to 999.")
	local function commitNewMessageCap()
		if not addon.SetNewMessageIndicatorMaxCount then
			return
		end
		local accepted, count = addon:SetNewMessageIndicatorMaxCount(self.dockNewMessagesMaxEdit:GetText())
		if not accepted then
			local current = addon.GetNewMessageIndicatorSettings and addon:GetNewMessageIndicatorSettings() or {}
			self.dockNewMessagesMaxEdit:SetText(tostring(tonumber(current.maxCount) or 99))
			Config:SetDockStatus("Use a whole-number cap from 9 to 999.", "warning")
			return
		end
		self.dockNewMessagesMaxEdit:SetText(tostring(count))
		Config:SetDockStatus("Unread count cap set to " .. tostring(count) .. ".", "success")
	end
	self.dockNewMessagesMaxEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.dockNewMessagesMaxEdit:HookScript("OnEditFocusLost", commitNewMessageCap)

	-- The basic marker controls above cover normal use.  Keep visual tuning
	-- behind one small disclosure so the Chat Window page remains scannable.
	self.dockMarkerAppearanceToggle = Theme:CreateTightButton(page, "MARKER STYLE +", 22, false)
	self.dockMarkerAppearanceToggle:SetWidth(96)
	self.dockMarkerAppearanceToggle:SetPoint("TOPLEFT", page, "TOPLEFT", 402, -151)
	setControlTooltip(self.dockMarkerAppearanceToggle, "Marker appearance", "Opens font, color, opacity, scale, and placement controls for the unread marker.")
	self.dockMarkerAppearanceToggle:SetScript("OnClick", function()
		if not hasNewMessageIndicatorAppearanceAPI() then
			Config:SetDockStatus("Marker appearance is unavailable in this build.", "warning")
			return
		end
		if Config.dockMarkerAppearanceExpanded and Config.dockMarkerPreviewActive then
			Config:SetNewMessageIndicatorPreview(false)
		end
		Config.dockUnreadCountAppearanceExpanded = false
		Config.dockMarkerAppearanceExpanded = not Config.dockMarkerAppearanceExpanded
		Config:RefreshDockPage()
		Config:SetDockStatus(Config.dockMarkerAppearanceExpanded
			and "Marker appearance controls opened. Preview it, then hold SHIFT and drag NEW to move it."
			or "Marker appearance controls closed.", "success")
	end)

	self.dockUnreadCountAppearanceToggle = Theme:CreateTightButton(page, "TAB COUNTS +", 22, false)
	self.dockUnreadCountAppearanceToggle:SetWidth(112)
	self.dockUnreadCountAppearanceToggle:SetPoint("TOPLEFT", page, "TOPLEFT", 506, -151)
	setControlTooltip(self.dockUnreadCountAppearanceToggle, "Tab unread counts",
		"Styles only the unread numbers on inactive chat tabs. It does not change the movable NEW marker or tab labels.")
	self.dockUnreadCountAppearanceToggle:SetScript("OnClick", function()
		if not hasRailUnreadCountAppearanceAPI() then
			Config:SetDockStatus("Tab unread-count appearance is unavailable in this build.", "warning")
			return
		end
		if Config.dockMarkerPreviewActive then
			Config:SetNewMessageIndicatorPreview(false)
		end
		Config.dockMarkerAppearanceExpanded = false
		Config.dockUnreadCountAppearanceExpanded = not Config.dockUnreadCountAppearanceExpanded
		Config:RefreshDockPage()
		Config:SetDockStatus(Config.dockUnreadCountAppearanceExpanded
			and "Tab unread-count appearance controls opened."
			or "Tab unread-count appearance controls closed.", "success")
	end)

	self.dockUnreadCountAppearanceControls = {}
	local function addUnreadCountAppearanceControl(control)
		table.insert(self.dockUnreadCountAppearanceControls, control)
		control:Hide()
		return control
	end
	self.dockUnreadCountAppearanceExpanded = self.dockUnreadCountAppearanceExpanded and true or false
	local unreadCountAppearanceTitle = addUnreadCountAppearanceControl(Theme:CreateText(page, "GameFontNormalSmall", "gold"))
	unreadCountAppearanceTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -194)
	unreadCountAppearanceTitle:SetText("TAB UNREAD COUNTS")
	local unreadCountAppearanceHint = addUnreadCountAppearanceControl(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	unreadCountAppearanceHint:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -215)
	unreadCountAppearanceHint:SetWidth(PAGE_WIDTH)
	unreadCountAppearanceHint:SetJustifyH("LEFT")
	unreadCountAppearanceHint:SetText("These settings affect only the number beside an inactive tab label; tab text and the NEW marker stay unchanged.")

	local unreadCountFontSizeLabel = addUnreadCountAppearanceControl(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	unreadCountFontSizeLabel:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -250)
	unreadCountFontSizeLabel:SetText("FONT SIZE")
	self.dockUnreadCountFontSizeEdit = addUnreadCountAppearanceControl(Theme:CreateEditBox(page, 44, 22, false))
	self.dockUnreadCountFontSizeEdit:SetPoint("LEFT", unreadCountFontSizeLabel, "RIGHT", 8, 0)
	local unreadCountFontSizeHint = addUnreadCountAppearanceControl(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	unreadCountFontSizeHint:SetPoint("LEFT", self.dockUnreadCountFontSizeEdit, "RIGHT", 8, 0)
	unreadCountFontSizeHint:SetWidth(145)
	unreadCountFontSizeHint:SetJustifyH("LEFT")
	unreadCountFontSizeHint:SetText("0 = TAB FONT / 8-16 PX")
	setControlTooltip(self.dockUnreadCountFontSizeEdit, "Tab unread-count font size",
		"Use 0 to inherit the tab font, or a whole size from 8 to 16 pixels. Chatty reserves enough room so the count cannot overlap the tab label.")

	local unreadCountAlphaLabel = addUnreadCountAppearanceControl(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	unreadCountAlphaLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 330, -250)
	unreadCountAlphaLabel:SetText("TEXT OPACITY")
	self.dockUnreadCountAlphaEdit = addUnreadCountAppearanceControl(Theme:CreateEditBox(page, 44, 22, false))
	self.dockUnreadCountAlphaEdit:SetPoint("LEFT", unreadCountAlphaLabel, "RIGHT", 8, 0)
	local unreadCountAlphaHint = addUnreadCountAppearanceControl(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	unreadCountAlphaHint:SetPoint("LEFT", self.dockUnreadCountAlphaEdit, "RIGHT", 8, 0)
	unreadCountAlphaHint:SetText("0-100%")
	setControlTooltip(self.dockUnreadCountAlphaEdit, "Tab unread-count opacity",
		"Changes only the unread number's text opacity. The tab label remains fully readable.")

	local function commitUnreadCountFontSize()
		local appearance = getRailUnreadCountAppearance() or {}
		local minimum = tonumber(appearance.minimumFontSize) or 8
		local maximum = tonumber(appearance.maximumFontSize) or 16
		local value = tonumber(Config.dockUnreadCountFontSizeEdit:GetText())
		if value == nil or value ~= math.floor(value) or (value ~= 0 and (value < minimum or value > maximum)) then
			Config:RefreshRailUnreadCountAppearance()
			Config:SetDockStatus("Use 0 to inherit the tab font, or a whole size from " .. tostring(minimum) .. " to " .. tostring(maximum) .. ".", "warning")
			return
		end
		local ok, accepted = pcall(addon.SetRailUnreadCountFontSize, addon, value)
		Config:RefreshRailUnreadCountAppearance()
		Config:SetDockStatus(ok and accepted ~= false and "Tab unread-count font size applied."
			or "Tab unread-count font size could not be applied.", ok and accepted ~= false and "success" or "warning")
	end
	local function commitUnreadCountAlpha()
		local value = tonumber(Config.dockUnreadCountAlphaEdit:GetText())
		if value == nil or value ~= math.floor(value) or value < 0 or value > 100 then
			Config:RefreshRailUnreadCountAppearance()
			Config:SetDockStatus("Use a whole tab unread-count opacity from 0% to 100%.", "warning")
			return
		end
		local ok, accepted = pcall(addon.SetRailUnreadCountAlpha, addon, value / 100)
		Config:RefreshRailUnreadCountAppearance()
		Config:SetDockStatus(ok and accepted ~= false and "Tab unread-count text opacity applied."
			or "Tab unread-count opacity could not be applied.", ok and accepted ~= false and "success" or "warning")
	end
	self.dockUnreadCountFontSizeEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.dockUnreadCountAlphaEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.dockUnreadCountFontSizeEdit:HookScript("OnEditFocusLost", commitUnreadCountFontSize)
	self.dockUnreadCountAlphaEdit:HookScript("OnEditFocusLost", commitUnreadCountAlpha)
	self.dockUnreadCountResetButton = addUnreadCountAppearanceControl(Theme:CreateTightButton(page, "RESET TAB COUNTS", 22, false))
	self.dockUnreadCountResetButton:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -292)
	setControlTooltip(self.dockUnreadCountResetButton, "Reset tab unread counts",
		"Restores inherited tab-font size and full unread-count opacity without changing the NEW marker.")
	self.dockUnreadCountResetButton:SetScript("OnClick", function()
		local ok, accepted = false, false
		if type(addon.ResetRailUnreadCountAppearance) == "function" then
			ok, accepted = pcall(addon.ResetRailUnreadCountAppearance, addon)
		end
		Config:RefreshRailUnreadCountAppearance()
		Config:SetDockStatus(ok and accepted ~= false and "Tab unread-count appearance restored."
			or "Tab unread-count reset is unavailable.", ok and accepted ~= false and "success" or "warning")
	end)
	local unreadCountFooterHint = addUnreadCountAppearanceControl(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	unreadCountFooterHint:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -330)
	unreadCountFooterHint:SetWidth(PAGE_WIDTH)
	unreadCountFooterHint:SetJustifyH("LEFT")
	unreadCountFooterHint:SetText("Lower opacity keeps unread numbers informative without letting them compete with the tab name.")

	self.dockMarkerAppearanceControls = {}
	local function addMarkerAppearanceControl(control)
		table.insert(self.dockMarkerAppearanceControls, control)
		control:Hide()
		return control
	end
	self.dockMarkerAppearanceExpanded = self.dockMarkerAppearanceExpanded and true or false
	self.dockMarkerColorTarget = self.dockMarkerColorTarget or "text"

	local appearanceTitle = addMarkerAppearanceControl(Theme:CreateText(page, "GameFontNormalSmall", "gold"))
	appearanceTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -194)
	appearanceTitle:SetText("APPEARANCE")

	self.dockMarkerPositionValue = addMarkerAppearanceControl(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	self.dockMarkerPositionValue:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -215)
	self.dockMarkerPositionValue:SetWidth(220)
	self.dockMarkerPositionValue:SetJustifyH("LEFT")
	self.dockMarkerPreviewButton = addMarkerAppearanceControl(Theme:CreateTightButton(page, "PREVIEW MARKER", 20, true))
	self.dockMarkerPreviewButton:SetPoint("TOPLEFT", page, "TOPLEFT", 238, -208)
	setControlTooltip(self.dockMarkerPreviewButton, "Preview marker", "Shows a temporary NEW marker without creating an unread message.")
	self.dockMarkerPreviewButton:SetScript("OnClick", function()
		Config:SetNewMessageIndicatorPreview(not Config.dockMarkerPreviewActive)
	end)
	self.dockMarkerResetPositionButton = addMarkerAppearanceControl(Theme:CreateTightButton(page, "TITLE BAR", 20, false))
	self.dockMarkerResetPositionButton:SetPoint("LEFT", self.dockMarkerPreviewButton, "RIGHT", CONTROL_GAP, 0)
	self.dockMarkerResetPositionButton:SetScript("OnClick", function()
		local accepted = callMarkerAppearanceAPI("SetNewMessageIndicatorPosition", "header")
		if not accepted then
			Config:SetDockStatus("Marker position reset is unavailable in this build.", "warning")
			return
		end
		Config:RefreshDockPage()
		Config:SetDockStatus("Marker returned to the title bar.", "success")
	end)
	setControlTooltip(self.dockMarkerResetPositionButton, "Return to title bar", "Moves the unread marker back to its default title-bar position.")
	self.dockMarkerResetAppearanceButton = addMarkerAppearanceControl(Theme:CreateTightButton(page, "RESET ALL", 20, false))
	self.dockMarkerResetAppearanceButton:SetPoint("LEFT", self.dockMarkerResetPositionButton, "RIGHT", CONTROL_GAP, 0)
	self.dockMarkerResetAppearanceButton:SetScript("OnClick", function()
		local accepted = callMarkerAppearanceAPI("ResetNewMessageIndicatorAppearance")
		if not accepted then
			Config:SetDockStatus("Marker appearance reset is unavailable in this build.", "warning")
			return
		end
		if Config.dockMarkerPreviewActive then
			Config:SetNewMessageIndicatorPreview(false)
			Config:SetDockStatus("Marker appearance restored to its theme defaults.", "success")
		else
			Config:RefreshDockPage()
			Config:SetDockStatus("Marker appearance restored to its theme defaults.", "success")
		end
	end)
	setControlTooltip(self.dockMarkerResetAppearanceButton, "Reset marker appearance", "Restores the marker font, scale, opacity, colors, and placement defaults.")
	local dragHint = addMarkerAppearanceControl(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	dragHint:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -238)
	dragHint:SetWidth(PAGE_WIDTH)
	dragHint:SetJustifyH("LEFT")
	dragHint:SetText("Preview it, then hold SHIFT and drag NEW anywhere inside this chat window. Size 0 uses the UI default.")

	local fontTitle = addMarkerAppearanceControl(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	fontTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -265)
	fontTitle:SetText("FONT")
	self.dockMarkerFontButtons = {}
	local previousFont = fontTitle
	for _, option in ipairs(markerAppearanceFallbackOptions.fonts) do
		local button = addMarkerAppearanceControl(Theme:CreateTightButton(page, option.label, 20, false))
		button:SetPoint("LEFT", previousFont, "RIGHT", CONTROL_GAP, 0)
		button:SetScript("OnClick", function(self)
			if self.optionId then
				Config:ApplyNewMessageIndicatorAppearancePatch({ font = self.optionId }, "Marker font applied.")
			end
		end)
		table.insert(self.dockMarkerFontButtons, button)
		previousFont = button
	end
	local fontSizeLabel = addMarkerAppearanceControl(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	fontSizeLabel:SetPoint("LEFT", previousFont, "RIGHT", 8, 0)
	fontSizeLabel:SetText("SIZE")
	self.dockMarkerFontSizeEdit = addMarkerAppearanceControl(Theme:CreateEditBox(page, 36, 20, false))
	self.dockMarkerFontSizeEdit:SetPoint("LEFT", fontSizeLabel, "RIGHT", 3, 0)
	local scaleLabel = addMarkerAppearanceControl(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	scaleLabel:SetPoint("LEFT", self.dockMarkerFontSizeEdit, "RIGHT", 7, 0)
	scaleLabel:SetText("SCALE %")
	self.dockMarkerScaleEdit = addMarkerAppearanceControl(Theme:CreateEditBox(page, 38, 20, false))
	self.dockMarkerScaleEdit:SetPoint("LEFT", scaleLabel, "RIGHT", 3, 0)
	local alphaLabel = addMarkerAppearanceControl(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	alphaLabel:SetPoint("LEFT", self.dockMarkerScaleEdit, "RIGHT", 7, 0)
	alphaLabel:SetText("ALPHA %")
	self.dockMarkerAlphaEdit = addMarkerAppearanceControl(Theme:CreateEditBox(page, 38, 20, false))
	self.dockMarkerAlphaEdit:SetPoint("LEFT", alphaLabel, "RIGHT", 3, 0)
	local function commitMarkerFontSize()
		local value = tonumber(Config.dockMarkerFontSizeEdit:GetText())
		if not value then
			Config:RefreshNewMessageIndicatorAppearance()
			Config:SetDockStatus("Use 0 for the normal font size, or a whole size from 8 to 32.", "warning")
			return
		end
		value = math.floor(value + 0.5)
		if value ~= 0 and (value < 8 or value > 32) then
			Config:RefreshNewMessageIndicatorAppearance()
			Config:SetDockStatus("Use 0 for the normal font size, or a whole size from 8 to 32.", "warning")
			return
		end
		Config:ApplyNewMessageIndicatorAppearancePatch({ fontSize = value }, "Marker font size applied.")
	end
	local function commitMarkerScale()
		local value = tonumber(Config.dockMarkerScaleEdit:GetText())
		if not value or value < 50 or value > 200 then
			Config:RefreshNewMessageIndicatorAppearance()
			Config:SetDockStatus("Use a marker scale from 50% to 200%.", "warning")
			return
		end
		Config:ApplyNewMessageIndicatorAppearancePatch({ scale = value / 100 }, "Marker scale applied.")
	end
	local function commitMarkerAlpha()
		local value = tonumber(Config.dockMarkerAlphaEdit:GetText())
		if not value or value < 0 or value > 100 then
			Config:RefreshNewMessageIndicatorAppearance()
			Config:SetDockStatus("Use marker opacity from 0% to 100%.", "warning")
			return
		end
		Config:ApplyNewMessageIndicatorAppearancePatch({ alpha = value / 100 }, "Marker opacity applied.")
	end
	for _, editBox in ipairs({ self.dockMarkerFontSizeEdit, self.dockMarkerScaleEdit, self.dockMarkerAlphaEdit }) do
		editBox:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	end
	self.dockMarkerFontSizeEdit:HookScript("OnEditFocusLost", commitMarkerFontSize)
	self.dockMarkerScaleEdit:HookScript("OnEditFocusLost", commitMarkerScale)
	self.dockMarkerAlphaEdit:HookScript("OnEditFocusLost", commitMarkerAlpha)

	local outlineTitle = addMarkerAppearanceControl(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	outlineTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -294)
	outlineTitle:SetText("OUTLINE")
	self.dockMarkerOutlineButtons = {}
	local previousOutline = outlineTitle
	for _, option in ipairs(markerAppearanceFallbackOptions.outlines) do
		local button = addMarkerAppearanceControl(Theme:CreateTightButton(page, option.label, 20, false))
		button:SetPoint("LEFT", previousOutline, "RIGHT", CONTROL_GAP, 0)
		button:SetScript("OnClick", function(self)
			if self.optionId then
				Config:ApplyNewMessageIndicatorAppearancePatch({ outline = self.optionId }, "Marker outline applied.")
			end
		end)
		table.insert(self.dockMarkerOutlineButtons, button)
		previousOutline = button
	end

	local colorTargetTitle = addMarkerAppearanceControl(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	colorTargetTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -323)
	colorTargetTitle:SetText("COLOR PART")
	self.dockMarkerColorTargetButtons = {}
	local previousTarget = colorTargetTitle
	for _, targetDefinition in ipairs({
		{ id = "text", label = "TEXT" },
		{ id = "background", label = "BACKGROUND" },
		{ id = "border", label = "BORDER" },
	}) do
		local button = addMarkerAppearanceControl(Theme:CreateTightButton(page, targetDefinition.label, 20, false))
		button.target = targetDefinition.id
		button:SetPoint("LEFT", previousTarget, "RIGHT", CONTROL_GAP, 0)
		button:SetScript("OnClick", function(self)
			Config.dockMarkerColorTarget = self.target
			Config:RefreshNewMessageIndicatorAppearance()
		end)
		table.insert(self.dockMarkerColorTargetButtons, button)
		previousTarget = button
	end

	local paletteTitle = addMarkerAppearanceControl(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	paletteTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -352)
	paletteTitle:SetText("PRESET")
	self.dockMarkerThemeColorButtons = {}
	local previousColor = paletteTitle
	for index, option in ipairs(markerAppearanceFallbackOptions.themeColors) do
		local button = addMarkerAppearanceControl(Theme:CreateTightButton(page, option.label, 20, false))
		button:SetPoint("LEFT", previousColor, "RIGHT", CONTROL_GAP, 0)
		button:SetScript("OnClick", function(self)
			if not self.optionId then
				return
			end
			local key = markerAppearanceColorKeys[Config.dockMarkerColorTarget] or "color"
			local patch = {}
			patch[key] = { mode = "theme", theme = self.optionId }
			Config:ApplyNewMessageIndicatorAppearancePatch(patch, "Marker color applied.")
		end)
		table.insert(self.dockMarkerThemeColorButtons, button)
		previousColor = button
	end
	local rgbaTitle = addMarkerAppearanceControl(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	rgbaTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -381)
	rgbaTitle:SetText("CUSTOM RGBA")
	self.dockMarkerColorEdits = {}
	local previousChannel = rgbaTitle
	for _, channel in ipairs({ "R", "G", "B", "A" }) do
		local channelLabel = addMarkerAppearanceControl(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
		channelLabel:SetPoint("LEFT", previousChannel, "RIGHT", 3, 0)
		channelLabel:SetText(channel)
		local editBox = addMarkerAppearanceControl(Theme:CreateEditBox(page, 32, 20, false))
		editBox:SetPoint("LEFT", channelLabel, "RIGHT", 2, 0)
		editBox.channel = channel
		table.insert(self.dockMarkerColorEdits, editBox)
		previousChannel = editBox
	end
	local function commitMarkerColor()
		local values = {}
		for index, editBox in ipairs(Config.dockMarkerColorEdits or {}) do
			local maximum = index == 4 and 100 or 255
			local value = tonumber(editBox:GetText())
			if not value or value < 0 or value > maximum then
				Config:RefreshNewMessageIndicatorAppearance()
				Config:SetDockStatus("Use RGB from 0 to 255 and alpha from 0 to 100.", "warning")
				return
			end
			values[index] = math.floor(value + 0.5) / maximum
		end
		local key = markerAppearanceColorKeys[Config.dockMarkerColorTarget] or "color"
		local patch = {}
		patch[key] = { mode = "custom", r = values[1], g = values[2], b = values[3], a = values[4] }
		Config:ApplyNewMessageIndicatorAppearancePatch(patch, "Custom marker color applied.")
	end
	for _, editBox in ipairs(self.dockMarkerColorEdits) do
		editBox:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
		editBox:HookScript("OnEditFocusLost", commitMarkerColor)
	end

	local sizeTitle = Theme:CreateText(page, "GameFontNormalSmall", "gold")
	sizeTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -339)
	sizeTitle:SetText("WINDOW SIZE")
	self.dockSizeTitle = sizeTitle
	local widthLabel = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	widthLabel:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -360)
	widthLabel:SetText("WIDTH")
	self.dockWidthLabel = widthLabel
	local heightLabel = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	heightLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 98, -360)
	heightLabel:SetText("HEIGHT")
	self.dockHeightLabel = heightLabel
	self.dockWidthEdit = Theme:CreateEditBox(page, 78, 22, false)
	self.dockWidthEdit:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -376)
	self.dockHeightEdit = Theme:CreateEditBox(page, 78, 22, false)
	self.dockHeightEdit:SetPoint("TOPLEFT", page, "TOPLEFT", 98, -376)
	setControlTooltip(self.dockWidthEdit, "Window width", "Enter a width from 360 to 1050 UI pixels.")
	setControlTooltip(self.dockHeightEdit, "Window height", "Enter a height from 160 to 720 UI pixels.")
	local function commitSize()
		local dock = getDockSettings()
		dock.width = clampNumber(Config.dockWidthEdit:GetText(), 360, 1050, DOCK_DEFAULT_WIDTH)
		dock.height = clampNumber(Config.dockHeightEdit:GetText(), 160, 720, DOCK_DEFAULT_HEIGHT)
		applyDockRuntime()
		Config:RefreshDockPage()
		Config:SetDockStatus("Dock size applied.", "success")
	end
	self.dockWidthEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.dockHeightEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.dockWidthEdit:HookScript("OnEditFocusLost", commitSize)
	self.dockHeightEdit:HookScript("OnEditFocusLost", commitSize)
	local resetSize = Theme:CreateTightButton(page, "RESET SIZE", 22, false)
	resetSize:SetPoint("LEFT", self.dockHeightEdit, "RIGHT", CONTROL_GAP, 0)
	self.dockResetSizeButton = resetSize
	setControlTooltip(resetSize, "Reset window size", "Restores Chatty's default compact width and height.")
	resetSize:SetScript("OnClick", function()
		local dock = getDockSettings()
		dock.width = DOCK_DEFAULT_WIDTH
		dock.height = DOCK_DEFAULT_HEIGHT
		applyDockRuntime()
		Config:RefreshDockPage()
		Config:SetDockStatus("Default compact size restored.", "success")
	end)

	self.dockLayoutGroups = {
		window = {
			stateTitle,
			self.dockVisibleToggle, self.dockCollapsedToggle,
			self.dockHideSocialToggle, self.dockTagsToggle,
			transparencyTitle, transparencyHint,
			backgroundAlphaLabel, borderAlphaLabel, overallAlphaLabel,
			self.dockBackgroundAlphaEdit, self.dockBorderAlphaEdit, self.dockOverallAlphaEdit,
			self.dockTransparencyResetButton,
			sizeTitle, widthLabel, heightLabel,
			self.dockWidthEdit, self.dockHeightEdit, resetSize,
		},
		tabs = {
			railVisibilityTitle, railVisibilityHint,
			self.dockRailAlwaysButton, self.dockRailMouseoverButton,
			self.dockRailClickButton, self.dockRailHiddenButton,
			directionTitle, self.dockHorizontalButton, self.dockVerticalButton,
			titleBarVisibilityTitle, self.dockTitleBarAlwaysButton,
			self.dockTitleBarHoverButton, self.dockTitleBarHiddenButton,
			headerControlsTitle,
			self.dockScrollToggle, self.dockCompactTitleToggle,
		},
		input = {
			chromeTitle, self.dockComposerAutoHideToggle, self.dockEditBoxBorderToggle,
			historyTitle, self.dockHistoryToggle, historyLinesLabel,
			self.dockHistoryLinesEdit, self.dockClearHistoryButton, historyHint,
		},
		readability = {
			responsiveTitle, self.dockResponsiveMetadataToggle,
			lineSpacingTitle, self.dockLineSpacingEdit, lineSpacingHint,
			responsiveHint,
			bandsTitle, self.dockMessageBandsToggle, self.dockMessageBandsScrollbarToggle, extentTitle,
			bandColorTitle, bandAlphaLabel, self.dockMessageBandAlphaEdit,
			self.dockMessageBandsResetButton, bandsHint,
		},
		unread = {
			newMessagesTitle, self.dockNewMessagesToggle, self.dockNewMessagesCountToggle,
			newMessagesCapLabel, self.dockNewMessagesMaxEdit,
			self.dockMarkerAppearanceToggle, self.dockUnreadCountAppearanceToggle,
		},
	}
	for _, button in pairs(self.dockMessageBandExtentButtons or {}) do
		table.insert(self.dockLayoutGroups.readability, button)
	end
	for _, button in pairs(self.dockMessageBandColorButtons or {}) do
		table.insert(self.dockLayoutGroups.readability, button)
	end

	self.dockStatus = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	self.dockStatus:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -474)
	self.dockStatus:SetWidth(PAGE_WIDTH)
	self.dockStatus:SetJustifyH("LEFT")
	self:SetDockStatus("Every control applies to the live dock without a reload.", "textMuted")

	-- The Color tab is an opaque sibling workspace rather than another nested
	-- card.  Keeping it in this page makes the relationship clear: these are
	-- the colors that separate individual sources inside the Chat Window.
	local colorsPanel = CreateFrame("Frame", nil, page)
	colorsPanel:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -42)
	-- The page workspace ends exactly 508px below its top.  Starting at y=42
	-- leaves 466px; keep the sibling pane inside that hard boundary.
	colorsPanel:SetSize(PAGE_WIDTH, 466)
	if page.GetFrameLevel and colorsPanel.SetFrameLevel then
		colorsPanel:SetFrameLevel((page:GetFrameLevel() or 0) + 20)
	end
	if colorsPanel.EnableMouse then
		colorsPanel:EnableMouse(true)
	end
	Theme:RegisterFrame(colorsPanel, "background", "border")
	colorsPanel:Hide()
	self.dockColorsPanel = colorsPanel

	local sourceTitle = Theme:CreateText(colorsPanel, "GameFontNormalSmall", "gold")
	sourceTitle:SetPoint("TOPLEFT", colorsPanel, "TOPLEFT", 10, -10)
	sourceTitle:SetText("CHAT SOURCES")
	local sourceHint = Theme:CreateText(colorsPanel, "GameFontHighlightSmall", "textMuted")
	sourceHint:SetPoint("TOPLEFT", sourceTitle, "BOTTOMLEFT", 0, -2)
	sourceHint:SetWidth(272)
	sourceHint:SetJustifyH("LEFT")
	sourceHint:SetText("Each source label uses this saved Blizzard chat color.")

	self.dockChatColorRows = {}
	for index = 1, DOCK_CHAT_COLOR_ROWS do
		local row = Theme:CreateButton(colorsPanel, "", 274, 21, false)
		row:SetPoint("TOPLEFT", colorsPanel, "TOPLEFT", 10, -45 - ((index - 1) * 24))
		row.text:ClearAllPoints()
		row.text:SetPoint("LEFT", row, "LEFT", 22, 0)
		row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		row.text:SetJustifyH("LEFT")
		row.swatch = row:CreateTexture(nil, "OVERLAY")
		row.swatch:SetTexture("Interface\\Buttons\\WHITE8x8")
		row.swatch:SetSize(10, 10)
		row.swatch:SetPoint("LEFT", row, "LEFT", 6, 0)
		row:SetScript("OnClick", function(self)
			if self.definitionId then
				Config:SelectDockChatColor(self.definitionId)
			end
		end)
		self.dockChatColorRows[index] = row
	end
	self.dockChatColorCount = Theme:CreateText(colorsPanel, "GameFontHighlightSmall", "textMuted")
	self.dockChatColorCount:SetPoint("TOPLEFT", colorsPanel, "TOPLEFT", 10, -292)
	self.dockChatColorCount:SetWidth(148)
	self.dockChatColorCount:SetJustifyH("CENTER")
	self.dockChatColorPrevious = Theme:CreateTightButton(colorsPanel, "<", 20, false)
	self.dockChatColorPrevious:SetPoint("LEFT", self.dockChatColorCount, "RIGHT", 4, 0)
	self.dockChatColorPrevious:SetScript("OnClick", function()
		Config.dockChatColorPage = math.max(1, (tonumber(Config.dockChatColorPage) or 1) - 1)
		Config:RefreshDockChatColors()
	end)
	self.dockChatColorNext = Theme:CreateTightButton(colorsPanel, ">", 20, false)
	self.dockChatColorNext:SetPoint("LEFT", self.dockChatColorPrevious, "RIGHT", CONTROL_GAP, 0)
	self.dockChatColorNext:SetScript("OnClick", function()
		Config.dockChatColorPage = (tonumber(Config.dockChatColorPage) or 1) + 1
		Config:RefreshDockChatColors()
	end)
	self.dockChatColorEmpty = Theme:CreateText(colorsPanel, "GameFontHighlightSmall", "warning")
	self.dockChatColorEmpty:SetPoint("TOPLEFT", colorsPanel, "TOPLEFT", 10, -52)
	self.dockChatColorEmpty:SetWidth(274)
	self.dockChatColorEmpty:SetJustifyH("LEFT")
	self.dockChatColorEmpty:SetText("Blizzard's chat-color table is not available yet.")
	self.dockChatColorEmpty:Hide()

	local inspector = Theme:CreateText(colorsPanel, "GameFontNormalSmall", "gold")
	inspector:SetPoint("TOPLEFT", colorsPanel, "TOPLEFT", 300, -10)
	inspector:SetText("SOURCE LABEL COLOR")
	self.dockChatColorSelectedTitle = Theme:CreateText(colorsPanel, "GameFontNormal", "goldBright")
	self.dockChatColorSelectedTitle:SetPoint("TOPLEFT", inspector, "BOTTOMLEFT", 0, -8)
	self.dockChatColorSelectedDetail = Theme:CreateText(colorsPanel, "GameFontHighlightSmall", "textMuted")
	self.dockChatColorSelectedDetail:SetPoint("TOPLEFT", self.dockChatColorSelectedTitle, "BOTTOMLEFT", 0, -2)
	self.dockChatColorSelectedDetail:SetWidth(310)
	self.dockChatColorSelectedDetail:SetJustifyH("LEFT")
	self.dockChatColorPreview = colorsPanel:CreateTexture(nil, "ARTWORK")
	self.dockChatColorPreview:SetTexture("Interface\\Buttons\\WHITE8x8")
	self.dockChatColorPreview:SetSize(308, 20)
	self.dockChatColorPreview:SetPoint("TOPLEFT", colorsPanel, "TOPLEFT", 300, -72)

	local rgbTitle = Theme:CreateText(colorsPanel, "GameFontHighlightSmall", "textMuted")
	rgbTitle:SetPoint("TOPLEFT", colorsPanel, "TOPLEFT", 300, -104)
	rgbTitle:SetText("RGB")
	self.dockChatColorEdits = {}
	local previousRGB = rgbTitle
	for _, channel in ipairs({ "R", "G", "B" }) do
		local label = Theme:CreateText(colorsPanel, "GameFontHighlightSmall", "textMuted")
		label:SetPoint("LEFT", previousRGB, "RIGHT", 8, 0)
		label:SetText(channel)
		local editBox = Theme:CreateEditBox(colorsPanel, 44, 20, false)
		editBox:SetPoint("LEFT", label, "RIGHT", 3, 0)
		editBox:HookScript("OnEnterPressed", function(self)
			self:ClearFocus()
			Config:ApplyDockChatColor()
		end)
		table.insert(self.dockChatColorEdits, editBox)
		previousRGB = editBox
	end
	self.dockChatColorApplyButton = Theme:CreateTightButton(colorsPanel, "APPLY COLOR", 22, true)
	self.dockChatColorApplyButton:SetPoint("TOPLEFT", colorsPanel, "TOPLEFT", 300, -132)
	self.dockChatColorApplyButton:SetScript("OnClick", function()
		Config:ApplyDockChatColor()
	end)
	local nativeHint = Theme:CreateText(colorsPanel, "GameFontHighlightSmall", "textMuted")
	nativeHint:SetPoint("TOPLEFT", colorsPanel, "TOPLEFT", 300, -166)
	nativeHint:SetWidth(310)
	nativeHint:SetJustifyH("LEFT")
	nativeHint:SetText("Applies to Blizzard chat too. Chatty repaints the visible tab immediately, including mixed source labels.")
	self.dockColorsStatus = Theme:CreateText(colorsPanel, "GameFontHighlightSmall", "textMuted")
	self.dockColorsStatus:SetPoint("TOPLEFT", colorsPanel, "TOPLEFT", 300, -218)
	self.dockColorsStatus:SetWidth(310)
	self.dockColorsStatus:SetJustifyH("LEFT")
	self:SetDockColorsStatus("Pick a source, tune RGB, then apply.", "textMuted")

	self:RefreshDockPage()
	return page
end

local builtInViewIds = {
	general = true,
	conversations = true,
	group = true,
	pvp = true,
	newcomers = true,
	groupFinder = true,
	guildInvites = true,
	trade = true,
	guild = true,
	system = true,
	loot = true,
	sync = true,
}

local function trim(value)
	return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

clampNumber = function(value, minimum, maximum, fallback)
	value = tonumber(value)
	if not value then
		value = fallback
	end
	value = math.floor(value + 0.5)
	return math.max(minimum, math.min(maximum, value))
end

local function isCustomView(view)
	return view and (view.custom == true or view.isCustom == true or not builtInViewIds[view.id])
end

local function getSmartViews()
	if addon.GetSmartViews then
		local ok, views = pcall(addon.GetSmartViews, addon)
		if ok and type(views) == "table" then
			return views
		end
	end
	return addon.SmartViews or {}
end

local function getTermsText(terms)
	if type(terms) == "table" then
		return table.concat(terms, ", ")
	end
	return tostring(terms or "")
end

local function parseTerms(text)
	local terms = {}
	local seen = {}
	for value in string.gmatch(tostring(text or ""), "[^,]+") do
		value = trim(value)
		local normalized = string.lower(value)
		if value ~= "" and not seen[normalized] then
			seen[normalized] = true
			table.insert(terms, value)
		end
	end
	return terms
end

function Config:SetViewsStatus(text, colorName)
	if not self.viewsStatus then
		return
	end
	colorName = colorName or "textMuted"
	self.viewsStatus:SetText(text or "")
	Theme.texts[self.viewsStatus] = colorName
	local r, g, b, a = Theme:GetColor(colorName)
	self.viewsStatus:SetTextColor(r, g, b, a)
end

function Config:EnsureBuiltInView()
	local settings = addon:GetSmartSettings()
	for _, view in ipairs(getSmartViews()) do
		if not isCustomView(view) and settings.views[view.id] then
			return false
		end
	end
	settings.views.general = true
	return true
end

function Config:RefreshRoutingOutput(preferredViewId, skipReclassify)
	local settings = addon:GetSmartSettings()
	if preferredViewId and settings.views[preferredViewId] == nil then
		settings.views[preferredViewId] = true
	end
	self:EnsureBuiltInView()

	local engine = addon.MessageEngine
	if not skipReclassify and engine and engine.ReclassifyAll then
		pcall(engine.ReclassifyAll, engine)
	end

	local dock = addon.SmartDock
	if not dock then
		return
	end
	if dock.RefreshViews then
		dock:RefreshViews()
	end
	if not dock.frame then
		return
	end

	local target = dock.activeView
	if not target or not settings.views[target] then
		target = preferredViewId and settings.views[preferredViewId] and preferredViewId or "general"
	end
	if dock.SelectView then
		dock:SelectView(target)
	elseif dock.RebuildActiveView then
		dock:RebuildActiveView()
	end
end

function Config:SetViewVisibility(viewId, value)
	local settings = addon:GetSmartSettings()
	local custom
	for _, definition in ipairs(getSmartViews()) do
		if definition.id == viewId then
			custom = isCustomView(definition)
			break
		end
	end
	if custom and addon.UpdateCustomView then
		addon:UpdateCustomView(viewId, { enabled = value and true or false })
	else
		settings.views[viewId] = value and true or false
	end
	local restored = self:EnsureBuiltInView()
	-- Custom APIs already reclassify once; built-in visibility changes do not
	-- alter stored memberships. Avoid a second full history scan here.
	self:RefreshRoutingOutput(value and viewId or nil, true)
	self:RefreshViewsPage()
	self:RefreshRailsPage(true)
	if restored then
		self:SetViewsStatus("General was restored because at least one built-in route must remain visible.", "warning")
	end
end

function Config:GetCustomViews()
	local custom = {}
	for _, view in ipairs(getSmartViews()) do
		if isCustomView(view) then
			table.insert(custom, view)
		end
	end
	table.sort(custom, function(left, right)
		return string.lower(left.label or left.id or "") < string.lower(right.label or right.id or "")
	end)
	return custom
end

function Config:FindView(viewId)
	if not viewId then
		return nil
	end
	for _, view in ipairs(getSmartViews()) do
		if view.id == viewId then
			return view
		end
	end
	return nil
end

function Config:FindCustomView(viewId)
	local view = self:FindView(viewId)
	return isCustomView(view) and view or nil
end

local function setViewEditBoxEnabled(editBox, enabled)
	if not editBox then
		return
	end
	if enabled then
		editBox:Enable()
	else
		editBox:Disable()
		editBox:ClearFocus()
	end
	local r, g, b, a = Theme:GetColor(enabled and "text" or "textMuted")
	editBox:SetTextColor(r, g, b, a)
	Theme:ApplyFrame(editBox, "inset", enabled and "borderMuted" or "border")
end

function Config:SetViewEditorMode(mode)
	local builtIn = mode == "builtIn"
	setViewEditBoxEnabled(self.viewNameEdit, true)
	setViewEditBoxEnabled(self.viewKeyEdit, true)
	setViewEditBoxEnabled(self.viewDescriptionEdit, true)
	if self.viewDescriptionEdit then
		self.viewDescriptionEdit:SetMaxLetters(builtIn and 120 or 160)
	end
	setViewEditBoxEnabled(self.viewTermsEdit, not builtIn)
	if self.viewTermsLabel then
		self.viewTermsLabel:SetText(builtIn and "CUSTOM MATCH TERMS - NOT USED BY BUILT-IN VIEWS" or "CUSTOM MATCH TERMS - COMMA SEPARATED")
	end
	if self.viewTermsHint then
		self.viewTermsHint:SetText(builtIn
			and "Built-in routing is read-only; optional classifiers are below."
			or "Matches text or channel names; checked feeds are added separately.")
	end
end

function Config:ClearCustomViewEditor()
	self.selectedViewId = nil
	self.selectedCustomViewId = nil
	self.pendingDeleteViewId = nil
	if not self.viewNameEdit then
		return
	end
	self.viewEditorTitle:SetText("NEW CUSTOM VIEW")
	self.viewNameEdit:SetText("")
	self.viewKeyEdit:SetText("")
	self.viewDescriptionEdit:SetText("")
	self.viewTermsEdit:SetText("")
	self:SetViewEditorMode("custom")
	self.viewVisibleToggle:SetValue(true, true)
	self.viewDeleteButton:SetLabel("DELETE")
	self.viewDeleteButton:Disable()
	self:SetViewsStatus("Name the route, give it a short rail key, then add comma-separated match terms.", "textMuted")
	self:RefreshViewsPage()
end

function Config:SelectView(viewId)
	local view = self:FindView(viewId)
	if not view then
		self:ClearCustomViewEditor()
		return
	end
	local custom = isCustomView(view)
	self.selectedViewId = view.id
	self.selectedCustomViewId = custom and view.id or nil
	self.pendingDeleteViewId = nil
	self.viewEditorTitle:SetText(custom and "EDIT CUSTOM VIEW" or "EDIT BUILT-IN VIEW")
	-- Apply mode-specific input limits before loading text. Otherwise moving
	-- directly from a 120-character built-in description to a legal 160-
	-- character custom description can truncate it during SetText.
	self:SetViewEditorMode(custom and "custom" or "builtIn")
	self.viewNameEdit:SetText(view.label or "")
	self.viewKeyEdit:SetText(view.key or "")
	self.viewDescriptionEdit:SetText(view.description or "")
	self.viewTermsEdit:SetText(custom and getTermsText(view.terms) or "")
	self.viewVisibleToggle:SetValue(addon:GetSmartSettings().views[view.id] ~= false, true)
	self.viewDeleteButton:SetLabel("DELETE")
	if custom then
		self.viewDeleteButton:Enable()
		self:SetViewsStatus("Editing " .. (view.label or view.id) .. ". Changes apply to captured history immediately.", "textMuted")
	else
		self.viewDeleteButton:Disable()
		self:SetViewsStatus("Editing " .. (view.label or view.id) .. ". Built-in classifier rules remain attached to this route.", "textMuted")
	end
	self:RefreshViewsPage()
end

function Config:SelectCustomView(viewId)
	self:SelectView(viewId)
end

function Config:SaveBuiltInView()
	local viewId = self.selectedViewId
	local view = self:FindView(viewId)
	if not view or isCustomView(view) then
		return
	end
	local label = trim(self.viewNameEdit:GetText())
	local key = trim(self.viewKeyEdit:GetText())
	local description = trim(self.viewDescriptionEdit:GetText())
	if label == "" or key == "" then
		self:SetViewsStatus("Both a view name and chat tab key are required.", "danger")
		return
	end
	if not addon.UpdateViewPresentation then
		self:SetViewsStatus("Built-in view editing is unavailable in this build.", "danger")
		return
	end

	local ok, result, err = pcall(addon.UpdateViewPresentation, addon, viewId, label, key, description)
	if not ok then
		err = result
		result = nil
	end
	if not result then
		self:SetViewsStatus(tostring(err or "The built-in view could not be updated."), "danger")
		return
	end

	self:RefreshViewsPage()
	self:RefreshRailsPage(true)
	self:SelectView(viewId)
	self:SetViewsStatus("Saved. The message view name, chat tab key, and description were updated.", "success")
end

function Config:SaveView()
	if self.selectedViewId and not self.selectedCustomViewId then
		self:SaveBuiltInView()
	else
		self:SaveCustomView()
	end
end

function Config:SaveCustomView()
	local wasCreating = not self.selectedCustomViewId
	local label = trim(self.viewNameEdit:GetText())
	local key = trim(self.viewKeyEdit:GetText())
	local description = trim(self.viewDescriptionEdit:GetText())
	local terms = parseTerms(self.viewTermsEdit:GetText())
	if label == "" then
		self:SetViewsStatus("A custom view needs a name.", "danger")
		return
	end
	if key == "" then
		key = string.upper(string.sub(label, 1, 3))
		self.viewKeyEdit:SetText(key)
	end
	if #terms == 0 then
		self:SetViewsStatus("Add at least one comma-separated match word or phrase.", "danger")
		return
	end
	if description == "" then
		description = "Messages matching this custom route."
		self.viewDescriptionEdit:SetText(description)
	end

	local data = {
		label = label,
		key = key,
		description = description,
		terms = terms,
		enabled = self.viewVisibleToggle.checked and true or false,
	}
	local result, err
	if self.selectedCustomViewId then
		if not addon.UpdateCustomView then
			self:SetViewsStatus("Custom view editing is unavailable in this build.", "danger")
			return
		end
		local ok
		ok, result, err = pcall(addon.UpdateCustomView, addon, self.selectedCustomViewId, data)
		if not ok then
			err = result
			result = nil
		end
		if result == false or (result == nil and err) then
			self:SetViewsStatus(tostring(err or "The custom view could not be updated."), "danger")
			return
		end
		result = type(result) == "table" and result or self:FindCustomView(self.selectedCustomViewId)
	else
		if not addon.CreateCustomView then
			self:SetViewsStatus("Custom view creation is unavailable in this build.", "danger")
			return
		end
		local ok
		ok, result, err = pcall(addon.CreateCustomView, addon, data)
		if not ok then
			err = result
			result = nil
		end
		if not result then
			self:SetViewsStatus(tostring(err or "The custom view could not be created."), "danger")
			return
		end
	end

	local viewId = type(result) == "table" and result.id or self.selectedCustomViewId
	if not viewId then
		self:SetViewsStatus("The custom view was saved but did not return an ID.", "danger")
		return
	end
	self.selectedViewId = viewId
	self.selectedCustomViewId = viewId
	self.pendingDeleteViewId = nil
	addon:GetSmartSettings().views[viewId] = self.viewVisibleToggle.checked and true or false
	self:RefreshRoutingOutput(viewId, true)
	self:RefreshViewsPage()
	self:SelectView(viewId)
	if wasCreating then
		self:SetMessageViewsSection("sources", true)
		self:SetViewsStatus("View created. Choose the message sources it should contain.", "success")
	else
		self:SetViewsStatus("Saved. Existing messages were routed again using the updated terms.", "success")
	end
end

function Config:DeleteCustomView()
	local viewId = self.selectedCustomViewId
	local view = self:FindCustomView(viewId)
	if not view then
		return
	end
	if self.pendingDeleteViewId ~= viewId then
		self.pendingDeleteViewId = viewId
		self.viewDeleteButton:SetLabel("CONFIRM")
		self:SetViewsStatus("Click CONFIRM to permanently remove " .. (view.label or viewId) .. ".", "warning")
		return
	end
	if not addon.DeleteCustomView then
		self:SetViewsStatus("Custom view deletion is unavailable in this build.", "danger")
		return
	end

	local ok, result, err = pcall(addon.DeleteCustomView, addon, viewId)
	if not ok then
		err = result
		result = nil
	end
	if result == false or (result == nil and err) then
		self:SetViewsStatus(tostring(err or "The custom view could not be deleted."), "danger")
		return
	end
	addon:GetSmartSettings().views[viewId] = nil
	self.selectedViewId = nil
	self.selectedCustomViewId = nil
	self.pendingDeleteViewId = nil
	self:RefreshRoutingOutput("general", true)
	self:ClearCustomViewEditor()
	self:SetViewsStatus("Custom view deleted. General remains available as the safe fallback.", "success")
end

function Config:RefreshViewsPage()
	if not self.viewsPage then
		return
	end
	local settings = addon:GetSmartSettings()
	if self.viewVisibleToggle and self.selectedViewId then
		-- Keep the editor's explicit visibility control synchronized when the
		-- isolated X box in either route list changes the selected view.
		self.viewVisibleToggle:SetValue(settings.views[self.selectedViewId] ~= false, true)
	end
	local viewsById = {}
	for _, view in ipairs(getSmartViews()) do
		viewsById[view.id] = view
	end
	for viewId, toggle in pairs(self.builtInViewToggles or {}) do
		local enabled = settings.views[viewId] ~= false
		toggle:SetValue(enabled, true)
		local row = self.builtInViewRows and self.builtInViewRows[viewId]
		local view = viewsById[viewId]
		if row and view then
			local selected = viewId == self.selectedViewId
			row:SetLabel((view.key or "-") .. "  " .. (view.label or view.id))
			row:SetTheme(selected and "accentSoft" or "surfaceRaised", selected and "gold" or "borderMuted",
				enabled and (selected and "goldBright" or "text") or "textMuted")
		end
	end

	local custom = self:GetCustomViews()
	local pageSize = #self.customViewRows
	local pageCount = math.max(1, math.ceil(#custom / pageSize))
	self.customViewPage = math.max(1, math.min(self.customViewPage or 1, pageCount))
	local startIndex = ((self.customViewPage - 1) * pageSize) + 1
	for rowIndex = 1, pageSize do
		local row = self.customViewRows[rowIndex]
		local view = custom[startIndex + rowIndex - 1]
		if view then
			row.viewId = view.id
			row.stateToggle.viewId = view.id
			local enabled = settings.views[view.id] ~= false
			row.stateToggle:SetValue(enabled, true)
			row:SetLabel((view.key or "-") .. "  " .. (view.label or view.id))
			local selected = view.id == self.selectedViewId
			row._themeFill = selected and "accentSoft" or "surfaceRaised"
			row._themeBorder = selected and "gold" or "borderMuted"
			if row.SetTheme then
				row:SetTheme(row._themeFill, row._themeBorder,
					enabled and (selected and "goldBright" or "text") or "textMuted")
			else
				Theme:ApplyFrame(row, row._themeFill, row._themeBorder)
			end
			row.stateToggle:Show()
			row:Show()
		else
			row.viewId = nil
			row.stateToggle.viewId = nil
			row.stateToggle:Hide()
			row:Hide()
		end
	end

	if #custom == 0 then
		self.customViewCount:SetText("No custom views")
	else
		local lastIndex = math.min(#custom, startIndex + pageSize - 1)
		self.customViewCount:SetText(startIndex .. "-" .. lastIndex .. " / " .. #custom)
	end
	if self.customViewPage > 1 then
		self.customViewPrevious:Enable()
	else
		self.customViewPrevious:Disable()
	end
	if self.customViewPage < pageCount then
		self.customViewNext:Enable()
	else
		self.customViewNext:Disable()
	end
end

-- Kept as an implementation reference while profiles that were created with
-- the old standalone pages continue to load.  The live builder is the single
-- Message Views workspace below.
function Config:BuildLegacyViewsPage()
	local page = self:CreatePage("views")
	self.viewsPage = page
	createHeading(page, "Organized Views", "Click a route name to edit it; use only its X box to show or hide it.")

	local builtIns = Theme:CreatePanel(page, "inset", "borderMuted")
	builtIns:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -PAGE_TOP)
	builtIns:SetSize(PAGE_WIDTH, 72)
	local builtInTitle = Theme:CreateText(builtIns, "GameFontNormalSmall", "gold")
	builtInTitle:SetPoint("TOPLEFT", builtIns, "TOPLEFT", 8, -6)
	builtInTitle:SetText("BUILT-IN ROUTES")
	local legend = Theme:CreateText(builtIns, "GameFontHighlightSmall", "textMuted")
	legend:SetPoint("TOPRIGHT", builtIns, "TOPRIGHT", -8, -6)
	legend:SetText("[X] shown   [ ] hidden   name edits")

	self.builtInViewToggles = {}
	self.builtInViewRows = {}
	local builtInIndex = 0
	for _, view in ipairs(getSmartViews()) do
		if not isCustomView(view) then
			builtInIndex = builtInIndex + 1
			local viewId = view.id
			local label = (view.key or "-") .. "  " .. (view.label or view.id)
			local toggle = Theme:CreateCompactToggle(builtIns, "", 18)
			toggle.label:ClearAllPoints()
			toggle.label:SetPoint("CENTER", toggle, "CENTER", 0, 0)
			toggle.label:Hide()
			local column = (builtInIndex - 1) % 4
			local rowIndex = math.floor((builtInIndex - 1) / 4)
			toggle:SetPoint("TOPLEFT", builtIns, "TOPLEFT", 8 + (column * 151), -24 - (rowIndex * 23))
			toggle.OnValueChanged = function(_, value)
				Config:SetViewVisibility(viewId, value)
			end
			local routeButton = Theme:CreateButton(builtIns, label, 126, 22, false)
			routeButton:SetPoint("LEFT", toggle, "RIGHT", 2, 0)
			routeButton.text:ClearAllPoints()
			routeButton.text:SetPoint("LEFT", routeButton, "LEFT", 2, 0)
			routeButton.text:SetPoint("RIGHT", routeButton, "RIGHT", -2, 0)
			routeButton.text:SetJustifyH("LEFT")
			routeButton:SetScript("OnClick", function()
				Config:SelectView(viewId)
			end)
			self.builtInViewToggles[viewId] = toggle
			self.builtInViewRows[viewId] = routeButton
		end
	end

	local work = Theme:CreatePanel(page, "surface", "borderMuted")
	work:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -126)
	work:SetSize(PAGE_WIDTH, 324)

	local divider = work:CreateTexture(nil, "ARTWORK")
	divider:SetTexture("Interface\\Buttons\\WHITE8x8")
	Theme:RegisterTexture(divider, "borderMuted")
	divider:SetPoint("TOPLEFT", work, "TOPLEFT", 184, -1)
	divider:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 184, 1)
	divider:SetWidth(1)

	local customTitle = Theme:CreateText(work, "GameFontNormalSmall", "gold")
	customTitle:SetPoint("TOPLEFT", work, "TOPLEFT", 8, -7)
	customTitle:SetText("CUSTOM VIEWS")
	local newButton = Theme:CreateButton(work, "NEW", 50, 22, true)
	newButton:SetPoint("TOPRIGHT", work, "TOPLEFT", 174, -5)
	newButton:SetScript("OnClick", function()
		Config:ClearCustomViewEditor()
	end)

	self.customViewRows = {}
	for index = 1, 9 do
		local stateToggle = Theme:CreateCompactToggle(work, "", 18)
		stateToggle.label:ClearAllPoints()
		stateToggle.label:SetPoint("CENTER", stateToggle, "CENTER", 0, 0)
		stateToggle.label:Hide()
		stateToggle:SetPoint("TOPLEFT", work, "TOPLEFT", 8, -29 - ((index - 1) * 23))
		stateToggle.OnValueChanged = function(self, value)
			if self.viewId then
				Config:SetViewVisibility(self.viewId, value)
			end
		end
		local row = Theme:CreateButton(work, "", 150, 22, false)
		row:SetPoint("LEFT", stateToggle, "RIGHT", 2, 0)
		row.stateToggle = stateToggle
		row.text:ClearAllPoints()
		row.text:SetPoint("LEFT", row, "LEFT", 3, 0)
		row.text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		row.text:SetJustifyH("LEFT")
		row:SetScript("OnClick", function(self)
			if self.viewId then
				Config:SelectView(self.viewId)
			end
		end)
		table.insert(self.customViewRows, row)
	end

	self.customViewCount = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	self.customViewCount:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 8, 12)
	self.customViewCount:SetWidth(86)
	self.customViewCount:SetJustifyH("LEFT")
	self.customViewPrevious = Theme:CreateButton(work, "<", 26, 22, false)
	self.customViewPrevious:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 94, 7)
	self.customViewPrevious:SetScript("OnClick", function()
		Config.customViewPage = math.max(1, (Config.customViewPage or 1) - 1)
		Config:RefreshViewsPage()
	end)
	self.customViewNext = Theme:CreateButton(work, ">", 26, 22, false)
	self.customViewNext:SetPoint("LEFT", self.customViewPrevious, "RIGHT", CONTROL_GAP, 0)
	self.customViewNext:SetScript("OnClick", function()
		Config.customViewPage = (Config.customViewPage or 1) + 1
		Config:RefreshViewsPage()
	end)

	self.viewEditorTitle = Theme:CreateText(work, "GameFontNormalSmall", "gold")
	self.viewEditorTitle:SetPoint("TOPLEFT", work, "TOPLEFT", 196, -7)
	self.viewEditorTitle:SetText("NEW CUSTOM VIEW")
	self.viewVisibleToggle = Theme:CreateCompactToggle(work, "SHOW IN RAIL", 112)
	self.viewVisibleToggle:SetPoint("TOPRIGHT", work, "TOPRIGHT", -8, -5)
	self.viewVisibleToggle.OnValueChanged = function(_, value)
		if Config.selectedViewId then
			Config:SetViewVisibility(Config.selectedViewId, value)
		end
	end

	local nameLabel = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	nameLabel:SetPoint("TOPLEFT", work, "TOPLEFT", 196, -32)
	nameLabel:SetText("VIEW NAME")
	local keyLabel = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	keyLabel:SetPoint("TOPLEFT", work, "TOPLEFT", 450, -32)
	keyLabel:SetText("RAIL KEY")
	self.viewNameEdit = Theme:CreateEditBox(work, 242, 24, false)
	self.viewNameEdit:SetPoint("TOPLEFT", work, "TOPLEFT", 196, -44)
	self.viewNameEdit:SetMaxLetters(40)
	self.viewKeyEdit = Theme:CreateEditBox(work, 154, 24, false)
	self.viewKeyEdit:SetPoint("TOPLEFT", work, "TOPLEFT", 450, -44)
	self.viewKeyEdit:SetMaxLetters(6)

	local descriptionLabel = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	descriptionLabel:SetPoint("TOPLEFT", work, "TOPLEFT", 196, -73)
	descriptionLabel:SetText("SHORT DESCRIPTION")
	self.viewDescriptionEdit = Theme:CreateEditBox(work, 408, 24, false)
	self.viewDescriptionEdit:SetPoint("TOPLEFT", work, "TOPLEFT", 196, -85)
	self.viewDescriptionEdit:SetMaxLetters(120)

	local termsLabel = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	termsLabel:SetPoint("TOPLEFT", work, "TOPLEFT", 196, -114)
	termsLabel:SetText("MATCH TERMS - COMMA SEPARATED")
	self.viewTermsLabel = termsLabel
	self.viewTermsEdit = Theme:CreateEditBox(work, 408, 96, true)
	self.viewTermsEdit:SetPoint("TOPLEFT", work, "TOPLEFT", 196, -126)
	-- 48 terms x 80 characters plus the 47 ", " separators used when loading
	-- an existing route. Match the model capacity so opening and saving a valid
	-- large custom view cannot silently truncate its classifier.
	self.viewTermsEdit:SetMaxLetters(3934)

	local hint = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	hint:SetPoint("TOPLEFT", self.viewTermsEdit, "BOTTOMLEFT", 0, -3)
	hint:SetWidth(408)
	hint:SetJustifyH("LEFT")
	hint:SetText("Example: molten core, attune, need tank")
	self.viewTermsHint = hint

	self.viewsStatus = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	self.viewsStatus:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 196, 36)
	self.viewsStatus:SetWidth(408)
	self.viewsStatus:SetJustifyH("LEFT")
	self.viewDeleteButton = Theme:CreateButton(work, "DELETE", 82, 24, false)
	self.viewDeleteButton:SetPoint("BOTTOMRIGHT", work, "BOTTOMRIGHT", -8, 7)
	self.viewDeleteButton:SetScript("OnClick", function()
		Config:DeleteCustomView()
	end)
	self.viewSaveButton = Theme:CreateButton(work, "SAVE", 74, 24, true)
	self.viewSaveButton:SetPoint("RIGHT", self.viewDeleteButton, "LEFT", -4, 0)
	self.viewSaveButton:SetScript("OnClick", function()
		Config:SaveView()
	end)

	self.viewNameEdit:SetScript("OnTabPressed", function()
		Config.viewKeyEdit:SetFocus()
	end)
	self.viewKeyEdit:SetScript("OnTabPressed", function()
		Config.viewDescriptionEdit:SetFocus()
	end)
	self.viewDescriptionEdit:SetScript("OnTabPressed", function()
		if Config.selectedViewId and not Config.selectedCustomViewId then
			Config.viewDescriptionEdit:ClearFocus()
		else
			Config.viewTermsEdit:SetFocus()
		end
	end)

	self.customViewPage = 1
	self:ClearCustomViewEditor()
	return page
end

function Config:GetRailDefinitions()
	local views = getSmartViews()
	local result = {}
	for index = 1, #views do
		result[index] = views[index]
	end
	return result
end

function Config:FindRailDefinition(viewId)
	for _, definition in ipairs(self:GetRailDefinitions()) do
		if definition.id == viewId then
			return definition
		end
	end
	return nil
end

function Config:SetRailsStatus(text, colorName)
	if not self.railsStatus then
		return
	end
	colorName = colorName or "textMuted"
	self.railsStatus:SetText(text or "")
	Theme.texts[self.railsStatus] = colorName
	local r, g, b, a = Theme:GetColor(colorName)
	self.railsStatus:SetTextColor(r, g, b, a)
end

function Config:RefreshRailRuntime()
	local dock = addon.SmartDock
	if not dock then
		return
	end
	if dock.RefreshViews then
		dock:RefreshViews()
	end
	if dock.active and dock.GetActiveDefinition then
		local definition = dock:GetActiveDefinition()
		if definition and dock.title then dock.title:SetText(definition.label) end
		if definition and dock.subtitle then dock.subtitle:SetText(definition.description) end
	end
	if dock.RebuildActiveView then
		dock:RebuildActiveView()
	end
end

function Config:GetRailSourceDefinitions(viewId)
	if addon.GetViewSourceDefinitions then
		local ok, sources = pcall(addon.GetViewSourceDefinitions, addon, viewId)
		if ok and type(sources) == "table" then
			return sources
		end
	end
	return {}
end

-- SYNC is a source-level routing decision, not a second per-rail checkbox.
-- Keep the small UI adapter here so older profiles/builds simply omit the
-- affordance until the routing core exposes the optional API.
function Config:CanManageSourceSync(source)
	if type(source) ~= "table"
		or (type(addon.SetSourceSyncMode) ~= "function" and type(addon.SetSourceSyncOverride) ~= "function") then
		return false
	end
	if source.syncEligible ~= nil then
		return source.syncEligible and true or false
	end
	return source.sourceGroup == "channels" or source.group == "channels"
end

function Config:GetSourceSyncMode(source)
	if type(source) ~= "table" then
		return nil
	end
	if source.syncMode ~= nil then
		return source.syncMode and true or false
	end
	if source.syncOverride ~= nil then
		return source.syncOverride and true or false
	end
	if source.syncState == "sync" then
		return true
	elseif source.syncState == "normal" or source.syncState == "human" then
		return false
	elseif source.syncState == "automatic" or source.syncState == "auto" then
		return nil
	end
	if type(addon.GetSourceSyncMode) == "function" then
		local sourceId = source.sourceId or source.id
		local ok, value = pcall(addon.GetSourceSyncMode, addon, sourceId)
		if ok and value ~= nil then
			return value and true or false
		end
	end
	if type(addon.GetSourceSyncOverride) == "function" then
		local sourceId = source.sourceId or source.id
		local ok, value = pcall(addon.GetSourceSyncOverride, addon, sourceId)
		if ok and value ~= nil then
			return value and true or false
		end
	end
	return nil
end

function Config:SetSourceSyncMode(sourceId, value)
	local setter = addon.SetSourceSyncMode or addon.SetSourceSyncOverride
	if type(setter) ~= "function" then
		self:SetRailsStatus("SYNC source controls are unavailable in this build.", "warning")
		return false
	end
	local ok, result, err = pcall(setter, addon, sourceId, value)
	if not ok then
		self:SetRailsStatus(tostring(result or "The SYNC source could not be updated."), "danger")
		return false
	end
	if result == false or (result == nil and err) then
		self:SetRailsStatus(tostring(err or "The SYNC source could not be updated."), "danger")
		return false
	end
	self:RefreshRailRuntime()
	self:RefreshRailSources()
	if value == true then
		self:SetRailsStatus("Marked this channel as SYNC. Its add-on traffic now routes through the SYNC message view.", "success")
	elseif value == false then
		self:SetRailsStatus("Forced this channel to NORMAL. Click NORMAL to restore automatic routing.", "success")
	else
		self:SetRailsStatus("Restored automatic routing for this channel.", "success")
	end
	return true
end

local function nextSourceSyncMode(mode)
	if mode == nil then
		return true
	elseif mode == true then
		return false
	end
	return nil
end

local function sourceSyncModeLabel(mode)
	if mode == true then
		return "SYNC"
	elseif mode == false then
		return "NORMAL"
	end
	return "AUTO"
end

function Config:RefreshRailSources()
	if not self.railSourceRows then
		return
	end
	local sources = self:GetRailSourceDefinitions(self.selectedRailId)
	local pageSize = #self.railSourceRows
	local pageCount = math.max(1, math.ceil(#sources / pageSize))
	self.railSourcePage = math.max(1, math.min(self.railSourcePage or 1, pageCount))
	local startIndex = ((self.railSourcePage - 1) * pageSize) + 1
	for rowIndex = 1, pageSize do
		local row = self.railSourceRows[rowIndex]
		local source = sources[startIndex + rowIndex - 1]
		if source then
			local sourceId = source.id or source.sourceId
			row.sourceId = sourceId
			local label = source.label or sourceId or "Source"
			row.sourceLabel = label
			local hasOverride = source.overridden or source.override ~= nil
			row.label:SetText((hasOverride and "* " or "") .. label)
			row:SetValue(source.enabled ~= false, true)
			row.feedLocked = source.feedLocked and true or false
			if row.feedLocked then
				row:Disable()
				setControlTooltip(row, "Sync-only source",
					"Use the adjacent AUTO / SYNC / NORMAL control to move this whole channel into or out of Sync.")
			else
				row:Enable()
				setControlTooltip(row, "Full source feed",
					"Checked keeps every message from this source here. Removing an expected feed also blocks its routed matches in this tab.")
			end
			local syncButton = row.syncButton
			if syncButton and self:CanManageSourceSync(source) then
				local syncMode = self:GetSourceSyncMode(source)
				row:SetWidth(row.syncWidth or 148)
				syncButton.sourceId = sourceId
				syncButton.syncMode = syncMode
				syncButton:SetLabel(sourceSyncModeLabel(syncMode))
				if syncMode == true then
					syncButton:SetTheme("accentSoft", "gold", "goldBright")
				elseif syncMode == false then
					syncButton:SetTheme("surfaceRaised", "accent", "text")
				else
					syncButton:SetTheme("surfaceRaised", "borderMuted", "textMuted")
				end
				syncButton:Show()
			elseif syncButton then
				row:SetWidth(row.normalWidth or 196)
				syncButton.sourceId = nil
				syncButton.syncMode = nil
				syncButton:Hide()
			end
			row:Show()
		else
			row.sourceId = nil
			row.sourceLabel = nil
			row.feedLocked = nil
			row:Enable()
			if row.syncButton then
				row.syncButton.sourceId = nil
				row.syncButton.syncMode = nil
				row.syncButton:Hide()
			end
			row:Hide()
		end
	end
	if #sources == 0 then
		self.railSourceCount:SetText("No sources observed")
	else
		local lastIndex = math.min(#sources, startIndex + pageSize - 1)
		self.railSourceCount:SetText(startIndex .. "-" .. lastIndex .. " / " .. #sources)
	end
	-- Do not leave inert page arrows on a one-page list.  The count still
	-- communicates how many sources exist, but navigation only appears when it
	-- can actually navigate somewhere.
	if pageCount > 1 then
		self.railSourcePrevious:Show()
		self.railSourceNext:Show()
		if self.railSourcePage > 1 then
			self.railSourcePrevious:Enable()
		else
			self.railSourcePrevious:Disable()
		end
		if self.railSourcePage < pageCount then
			self.railSourceNext:Enable()
		else
			self.railSourceNext:Disable()
		end
	else
		self.railSourcePrevious:Hide()
		self.railSourceNext:Hide()
	end
	if self.railSourceHint then
		self.railSourceHint:SetText("X keeps the whole source. Removed expected feeds stay hidden; other routes can add matches.")
	end
end

function Config:LoadRailEditor(viewId)
	local definition = self:FindRailDefinition(viewId)
	if not definition or not self.railNameEdit then
		return false
	end
	self.selectedRailId = definition.id
	self.railSourcePage = 1
	self.railEditorTitle:SetText("EDIT " .. string.upper(definition.label or definition.id))
	self.railNameEdit:SetText(definition.label or "")
	self.railKeyEdit:SetText(definition.key or "")
	self.railVisibleToggle:SetValue(addon:GetSmartSettings().views[definition.id] ~= false, true)
	if self.railResetNameButton then
		if definition.custom then self.railResetNameButton:Disable() else self.railResetNameButton:Enable() end
	end
	self:RefreshRailSources()
	return true
end

function Config:SelectRail(viewId)
	if not self:LoadRailEditor(viewId) then
		return
	end
	self:SetRailsStatus("Rename this tab or choose the full source feeds it always keeps.", "textMuted")
	self:RefreshRailsPage(true)
end

function Config:SaveRailPresentation()
	if not self.selectedRailId or not addon.UpdateViewPresentation then
		self:SetRailsStatus("Message view presentation editing is unavailable in this build.", "danger")
		return
	end
	local label = trim(self.railNameEdit:GetText())
	local key = trim(self.railKeyEdit:GetText())
	if label == "" or key == "" then
		self:SetRailsStatus("Both a display name and chat tab key are required.", "danger")
		return
	end
	local ok, result, err = pcall(addon.UpdateViewPresentation, addon, self.selectedRailId, label, key)
	if not ok or result == false or result == nil then
		self:SetRailsStatus(tostring((ok and err) or result or "The message view could not be renamed."), "danger")
		return
	end
	self:RefreshRailRuntime()
	self:RefreshRailsPage(true)
	self:LoadRailEditor(self.selectedRailId)
	self:SetRailsStatus("Message view name and chat tab key saved.", "success")
end

function Config:ResetRailPresentation()
	if not self.selectedRailId or not addon.ResetViewPresentation then
		return
	end
	local ok, result, err = pcall(addon.ResetViewPresentation, addon, self.selectedRailId)
	if not ok or result == false then
		self:SetRailsStatus(tostring((ok and err) or result or "The message view could not be reset."), "danger")
		return
	end
	self:RefreshRailRuntime()
	self:RefreshRailsPage(true)
	self:LoadRailEditor(self.selectedRailId)
	self:SetRailsStatus("Display name and chat tab key reset.", "success")
end

function Config:ResetRailSources()
	if not self.selectedRailId or not addon.ResetViewSources then
		return
	end
	local ok, result, err = pcall(addon.ResetViewSources, addon, self.selectedRailId)
	if not ok or result == false then
		self:SetRailsStatus(tostring((ok and err) or result or "Source rules could not be reset."), "danger")
		return
	end
	self:RefreshRailRuntime()
	self:RefreshRailSources()
	self:SetRailsStatus("Expected source feeds restored for this tab.", "success")
end

function Config:SetRailSourceEnabled(sourceId, enabled, sourceLabel)
	local viewId = self.selectedRailId
	if not viewId or not sourceId or type(addon.SetViewSourceEnabled) ~= "function" then
		self:SetRailsStatus("Message source controls are unavailable in this build.", "danger")
		self:RefreshRailSources()
		return false
	end

	local ok, result, err = pcall(addon.SetViewSourceEnabled, addon, viewId, sourceId, enabled)
	if not ok or result ~= true then
		local message = (ok and err) or result or "The source could not be updated."
		if message == "sync-quarantined" then
			message = "Sync-only traffic must be moved with the adjacent AUTO / SYNC / NORMAL control."
		end
		self:SetRailsStatus(tostring(message), "danger")
		-- The checkbox has already changed visually. Re-read the stored rule so
		-- a rejected write immediately returns it to its real state.
		self:RefreshRailSources()
		return false
	end

	-- Settings already rebuilds the active dock and clears only this rail's
	-- unread badge. A second dock rebuild from Config would just duplicate work.
	self:RefreshRailSources()
	local definition = self:FindRailDefinition(viewId)
	local railLabel = definition and (definition.label or definition.id) or viewId
	local label = trim(sourceLabel or sourceId)
	if enabled then
		self:SetRailsStatus("Keeping every " .. label .. " message in " .. railLabel
			.. ". Routed matches can also appear elsewhere.", "success")
	else
		self:SetRailsStatus("Stopped the full " .. label .. " feed in " .. railLabel
			.. ". Matching routes can still appear here.", "success")
	end
	return true
end

function Config:GetRailIndex(viewId, definitions)
	definitions = definitions or self:GetRailDefinitions()
	for index = 1, #definitions do
		if definitions[index].id == viewId then
			return index
		end
	end
	return nil
end

function Config:MoveRailToIndex(viewId, targetIndex, quiet)
	if not viewId then
		return false
	end
	local definitions = self:GetRailDefinitions()
	local currentIndex = self:GetRailIndex(viewId, definitions)
	if not currentIndex then
		if not quiet then self:SetRailsStatus("That message view is no longer available.", "danger") end
		return false
	end
	targetIndex = math.max(1, math.min(#definitions, math.floor(tonumber(targetIndex) or currentIndex)))
	if targetIndex == currentIndex then
		return true, currentIndex
	end
	if type(addon.MoveSmartViewToIndex) ~= "function" then
		if not quiet then self:SetRailsStatus("Chat-tab ordering is unavailable in this build. Restart Ascension after updating Chatty.", "warning") end
		return false
	end

	local ok, result, detail = pcall(addon.MoveSmartViewToIndex, addon, viewId, targetIndex)
	if not ok or result == false or result == nil then
		if not quiet then
			self:SetRailsStatus(tostring((ok and detail) or result or "The message view could not be moved."), "danger")
		end
		return false
	end

	local newIndex = tonumber(detail) or tonumber(result) or targetIndex
	self.selectedRailId = viewId
	self.railPage = math.max(1, math.ceil(newIndex / math.max(1, #self.railRows)))
	self:RefreshRailsPage(true)
	if not quiet then
		self:SetRailsStatus("Chat-tab order saved. The live tabs update immediately.", "success")
	end
	return true, newIndex
end

function Config:MoveRail(viewId, delta)
	local definitions = self:GetRailDefinitions()
	local currentIndex = self:GetRailIndex(viewId, definitions)
	if not currentIndex then
		return false
	end
	local targetIndex = math.max(1, math.min(#definitions, currentIndex + (delta or 0)))
	return self:MoveRailToIndex(viewId, targetIndex)
end

function Config:MoveRailBefore(viewId, targetViewId)
	if not viewId or not targetViewId or viewId == targetViewId then
		return false
	end
	local definitions = self:GetRailDefinitions()
	local currentIndex = self:GetRailIndex(viewId, definitions)
	local targetIndex = self:GetRailIndex(targetViewId, definitions)
	if not currentIndex or not targetIndex then
		return false
	end
	-- MoveSmartViewToIndex addresses the final list.  A source coming from above
	-- the target loses a slot before insertion, so place it one index earlier to
	-- make a drop mean exactly "before this rail".
	if currentIndex < targetIndex then
		targetIndex = targetIndex - 1
	end
	return self:MoveRailToIndex(viewId, targetIndex)
end

function Config:MoveRailAfter(viewId, targetViewId)
	if not viewId or not targetViewId or viewId == targetViewId then
		return false
	end
	local definitions = self:GetRailDefinitions()
	local currentIndex = self:GetRailIndex(viewId, definitions)
	local targetIndex = self:GetRailIndex(targetViewId, definitions)
	if not currentIndex or not targetIndex then
		return false
	end
	-- The target index passed to Settings is the final position after the source
	-- is removed. Moving a later rail below an earlier target therefore needs one
	-- extra slot; moving a rail down does not.
	if currentIndex > targetIndex then
		targetIndex = targetIndex + 1
	end
	return self:MoveRailToIndex(viewId, targetIndex)
end

function Config:ClearRailDragTarget()
	self.railDragTargetId = nil
	self.railDragAfterViewId = nil
	if self.railDragMarker then
		self.railDragMarker:Hide()
	end
end

function Config:BeginRailDrag(row)
	if not row or not row.viewId then
		return
	end
	self.railDragViewId = row.viewId
	self:ClearRailDragTarget()
	self.selectedRailId = row.viewId
	self.railSuppressClickUntil = (GetTime and GetTime() or 0) + 0.25
	self:LoadRailEditor(row.viewId)
	self:RefreshRailsPage(true)
	self:SetRailsStatus("Drop before a message view to place its chat tab there. UP / DN also works across pages.", "warning")
end

function Config:UpdateRailDragTarget(row)
	if not self.railDragViewId or not row or not row.viewId or row.viewId == self.railDragViewId then
		return
	end
	self.railDragTargetId = row.viewId
	self.railDragAfterViewId = nil
	if self.railDragMarker then
		self.railDragMarker:ClearAllPoints()
		self.railDragMarker:SetPoint("TOPLEFT", row, "TOPLEFT", 1, 1)
		self.railDragMarker:SetPoint("TOPRIGHT", row, "TOPRIGHT", -1, 1)
		self.railDragMarker:Show()
	end
end

function Config:UpdateRailDragAfterTarget(row)
	if not self.railDragViewId or not row or not row.viewId or row.viewId == self.railDragViewId then
		return
	end
	self.railDragTargetId = nil
	self.railDragAfterViewId = row.viewId
	if self.railDragMarker then
		self.railDragMarker:ClearAllPoints()
		self.railDragMarker:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 1, -1)
		self.railDragMarker:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, -1)
		self.railDragMarker:Show()
	end
end

function Config:EndRailDrag()
	local viewId = self.railDragViewId
	local targetViewId = self.railDragTargetId
	local afterViewId = self.railDragAfterViewId
	self.railDragViewId = nil
	self.railSuppressClickUntil = (GetTime and GetTime() or 0) + 0.25
	self:ClearRailDragTarget()
	if self.railDropAfter then self.railDropAfter:Hide() end
	if viewId and afterViewId then
		self:MoveRailAfter(viewId, afterViewId)
	elseif viewId and targetViewId then
		self:MoveRailBefore(viewId, targetViewId)
	end
end

function Config:ShouldSuppressRailClick()
	local now = GetTime and GetTime() or 0
	if self.railSuppressClickUntil and now <= self.railSuppressClickUntil then
		return true
	end
	self.railSuppressClickUntil = nil
	return false
end

function Config:RefreshRailOrderControls(definitions)
	if not self.railMoveUp or not self.railMoveDown then
		return
	end
	local index = self:GetRailIndex(self.selectedRailId, definitions)
	if not index then
		self.railMoveUp:Disable()
		self.railMoveDown:Disable()
		return
	end
	if index > 1 then self.railMoveUp:Enable() else self.railMoveUp:Disable() end
	if index < #definitions then self.railMoveDown:Enable() else self.railMoveDown:Disable() end
end

function Config:RefreshRailsPage(keepStatus)
	if not self.railsPage then
		return
	end
	local definitions = self:GetRailDefinitions()
	local pageSize = #self.railRows
	local pageCount = math.max(1, math.ceil(#definitions / pageSize))
	self.railPage = math.max(1, math.min(self.railPage or 1, pageCount))
	local startIndex = ((self.railPage - 1) * pageSize) + 1
	if not self:FindRailDefinition(self.selectedRailId) and definitions[1] then
		self.selectedRailId = definitions[1].id
	end
	local settings = addon:GetSmartSettings()
	local lastVisibleRow
	for rowIndex = 1, pageSize do
		local row = self.railRows[rowIndex]
		local definition = definitions[startIndex + rowIndex - 1]
		if definition then
			row.viewId = definition.id
			local marker = settings.views[definition.id] == false and "[ ]" or "[X]"
			row:SetLabel(marker .. "  " .. (definition.key or "-") .. "  " .. (definition.label or definition.id))
			local selected = definition.id == self.selectedRailId
			setChoiceStyle(row, selected)
			if row.selectionAccent then
				if selected then row.selectionAccent:Show() else row.selectionAccent:Hide() end
			end
			row:Show()
			lastVisibleRow = row
		else
			row.viewId = nil
			if row.selectionAccent then row.selectionAccent:Hide() end
			row:Hide()
		end
	end
	if self.railDropAfter then
		if self.railDragViewId and lastVisibleRow then
			self.railDropAfter:ClearAllPoints()
			self.railDropAfter:SetPoint("TOPLEFT", lastVisibleRow, "BOTTOMLEFT", 0, -2)
			self.railDropAfter:Show()
		else
			self.railDropAfter:Hide()
		end
	end
	if #definitions == 0 then
		self.railCount:SetText("No rails")
	else
		local lastIndex = math.min(#definitions, startIndex + pageSize - 1)
		if pageCount > 1 then
			self.railCount:SetText(startIndex .. "-" .. lastIndex .. " / " .. #definitions)
		else
			self.railCount:SetText(#definitions .. " RAILS")
		end
	end
	if pageCount > 1 then
		self.railPrevious:Show()
		self.railNext:Show()
		if self.railPage > 1 then self.railPrevious:Enable() else self.railPrevious:Disable() end
		if self.railPage < pageCount then self.railNext:Enable() else self.railNext:Disable() end
	else
		self.railPrevious:Hide()
		self.railNext:Hide()
	end
	self:RefreshRailOrderControls(definitions)
	self:LoadRailEditor(self.selectedRailId)
	if not keepStatus then
		self:SetRailsStatus("Drag a rail or use UP / DN. X controls whether a rail is shown.", "textMuted")
	end
end

function Config:BuildLegacyRailsPage()
	local page = self:CreatePage("rails")
	self.railsPage = page
	createHeading(page, "Tabs & Sources", "Drag tabs to reorder; use UP / DN for precision. Choose sources or send noisy channels to SYNC.")

	local work = Theme:CreatePanel(page, "surface", "borderMuted")
	work:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -52)
	work:SetSize(PAGE_WIDTH, 430)

	local divider = work:CreateTexture(nil, "ARTWORK")
	divider:SetTexture("Interface\\Buttons\\WHITE8x8")
	Theme:RegisterTexture(divider, "borderMuted")
	divider:SetPoint("TOPLEFT", work, "TOPLEFT", 190, -1)
	divider:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 190, 1)
	divider:SetWidth(1)

	local listTitle = Theme:CreateText(work, "GameFontNormalSmall", "gold")
	listTitle:SetPoint("TOPLEFT", work, "TOPLEFT", 10, -10)
	listTitle:SetText("ALL TABS")
	-- Ordering controls stay in the list header: compact enough not to steal
	-- editor space, explicit enough that the drag gesture is never the only way
	-- to arrange the live chat tabs.
	self.railMoveUp = Theme:CreateButton(work, "UP", 27, 20, false)
	self.railMoveUp:SetPoint("TOPLEFT", work, "TOPLEFT", 123, -7)
	self.railMoveUp:SetScript("OnClick", function()
		if Config.selectedRailId then Config:MoveRail(Config.selectedRailId, -1) end
	end)
	self.railMoveDown = Theme:CreateButton(work, "DN", 27, 20, false)
	self.railMoveDown:SetPoint("LEFT", self.railMoveUp, "RIGHT", 3, 0)
	self.railMoveDown:SetScript("OnClick", function()
		if Config.selectedRailId then Config:MoveRail(Config.selectedRailId, 1) end
	end)
	self.railRows = {}
	for index = 1, 12 do
		local row = Theme:CreateButton(work, "", 170, 23, false)
		row:SetPoint("TOPLEFT", work, "TOPLEFT", 10, -36 - ((index - 1) * 27))
		row.text:ClearAllPoints()
		row.text:SetPoint("LEFT", row, "LEFT", 7, 0)
		row.text:SetPoint("RIGHT", row, "RIGHT", -5, 0)
		row.text:SetJustifyH("LEFT")
		local selectionAccent = row:CreateTexture(nil, "OVERLAY")
		selectionAccent:SetTexture("Interface\\Buttons\\WHITE8x8")
		selectionAccent:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
		selectionAccent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 1, 1)
		selectionAccent:SetWidth(2)
		Theme:RegisterTexture(selectionAccent, "gold")
		selectionAccent:Hide()
		row.selectionAccent = selectionAccent
		row:RegisterForDrag("LeftButton")
		row:SetScript("OnClick", function(self)
			if not Config:ShouldSuppressRailClick() and self.viewId then Config:SelectRail(self.viewId) end
		end)
		row:SetScript("OnDragStart", function(self)
			Config:BeginRailDrag(self)
		end)
		row:SetScript("OnDragStop", function()
			Config:EndRailDrag()
		end)
		row:HookScript("OnEnter", function(self)
			Config:UpdateRailDragTarget(self)
		end)
		row:HookScript("OnLeave", function(self)
			if Config.railDragTargetId == self.viewId then
				Config:ClearRailDragTarget()
			end
		end)
		table.insert(self.railRows, row)
	end
	self.railDragMarker = work:CreateTexture(nil, "OVERLAY")
	self.railDragMarker:SetTexture("Interface\\Buttons\\WHITE8x8")
	self.railDragMarker:SetHeight(2)
	Theme:RegisterTexture(self.railDragMarker, "goldBright")
	self.railDragMarker:Hide()
	-- This invisible drop strip gives a dragged rail an unambiguous final slot
	-- after the last visible rail. It only exists while dragging; the gold line
	-- is the visible feedback, so the list stays just as compact at rest.
	self.railDropAfter = CreateFrame("Frame", nil, work)
	self.railDropAfter:SetSize(170, 8)
	self.railDropAfter:EnableMouse(true)
	self.railDropAfter:SetScript("OnEnter", function()
		local lastRow
		for _, candidate in ipairs(Config.railRows or {}) do
			if candidate:IsShown() then lastRow = candidate end
		end
		if lastRow then Config:UpdateRailDragAfterTarget(lastRow) end
	end)
	self.railDropAfter:SetScript("OnLeave", function()
		if Config.railDragAfterViewId then Config:ClearRailDragTarget() end
	end)
	self.railDropAfter:Hide()
	self.railCount = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	self.railCount:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 10, 15)
	self.railCount:SetWidth(86)
	self.railPrevious = Theme:CreateButton(work, "<", 26, 22, false)
	self.railPrevious:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 106, 9)
	self.railPrevious:SetScript("OnClick", function()
		Config.railPage = math.max(1, (Config.railPage or 1) - 1)
		local definitions = Config:GetRailDefinitions()
		local first = definitions[((Config.railPage - 1) * #Config.railRows) + 1]
		if first then Config.selectedRailId = first.id end
		Config:RefreshRailsPage(true)
	end)
	self.railNext = Theme:CreateButton(work, ">", 26, 22, false)
	self.railNext:SetPoint("LEFT", self.railPrevious, "RIGHT", 5, 0)
	self.railNext:SetScript("OnClick", function()
		Config.railPage = (Config.railPage or 1) + 1
		local definitions = Config:GetRailDefinitions()
		local first = definitions[((Config.railPage - 1) * #Config.railRows) + 1]
		if first then Config.selectedRailId = first.id end
		Config:RefreshRailsPage(true)
	end)

	self.railEditorTitle = Theme:CreateText(work, "GameFontNormalSmall", "gold")
	self.railEditorTitle:SetPoint("TOPLEFT", work, "TOPLEFT", 202, -10)
	self.railVisibleToggle = Theme:CreateCompactToggle(work, "SHOW IN RAIL", 112)
	self.railVisibleToggle:SetPoint("TOPRIGHT", work, "TOPRIGHT", -10, -6)
	self.railVisibleToggle.OnValueChanged = function(_, value)
		if Config.selectedRailId then
			Config:SetViewVisibility(Config.selectedRailId, value)
			Config:RefreshRailsPage(true)
		end
	end

	local nameLabel = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	nameLabel:SetPoint("TOPLEFT", work, "TOPLEFT", 202, -38)
	nameLabel:SetText("DISPLAY NAME")
	local keyLabel = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	keyLabel:SetPoint("TOPLEFT", work, "TOPLEFT", 456, -38)
	keyLabel:SetText("RAIL KEY")
	self.railNameEdit = Theme:CreateEditBox(work, 242, 24, false)
	self.railNameEdit:SetPoint("TOPLEFT", work, "TOPLEFT", 202, -51)
	self.railNameEdit:SetMaxLetters(40)
	self.railKeyEdit = Theme:CreateEditBox(work, 154, 24, false)
	self.railKeyEdit:SetPoint("TOPLEFT", work, "TOPLEFT", 456, -51)
	self.railKeyEdit:SetMaxLetters(6)

	local resetName = Theme:CreateButton(work, "RESET NAME", 94, 24, false)
	resetName:SetPoint("TOPLEFT", work, "TOPLEFT", 202, -83)
	resetName:SetScript("OnClick", function() Config:ResetRailPresentation() end)
	self.railResetNameButton = resetName
	local saveName = Theme:CreateButton(work, "SAVE NAME", 94, 24, true)
	saveName:SetPoint("LEFT", resetName, "RIGHT", 6, 0)
	saveName:SetScript("OnClick", function() Config:SaveRailPresentation() end)

	local sourceTitle = Theme:CreateText(work, "GameFontNormalSmall", "gold")
	sourceTitle:SetPoint("TOPLEFT", work, "TOPLEFT", 202, -124)
	sourceTitle:SetText("MESSAGE SOURCES")
	local sourceHint = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	sourceHint:SetPoint("TOPLEFT", sourceTitle, "BOTTOMLEFT", 0, -3)
	sourceHint:SetWidth(408)
	sourceHint:SetJustifyH("LEFT")
	sourceHint:SetText("Turn off a source here without changing what any other rail receives.")
	self.railSourceHint = sourceHint

	self.railSourceRows = {}
	for index = 1, 12 do
		local column = (index - 1) % 2
		local sourceRow = math.floor((index - 1) / 2)
		local toggle = Theme:CreateCompactToggle(work, "Source", 196)
		toggle:SetPoint("TOPLEFT", work, "TOPLEFT", 202 + (column * 205), -166 - (sourceRow * 26))
		toggle.OnValueChanged = function(self, value)
			Config:SetRailSourceEnabled(self.sourceId, value, self.sourceLabel)
		end
		local syncButton = Theme:CreateButton(work, "AUTO", 44, 22, false)
		syncButton:SetPoint("LEFT", toggle, "RIGHT", 4, 0)
		syncButton:Hide()
		syncButton:SetScript("OnClick", function(self)
			if self.sourceId then
				Config:SetSourceSyncMode(self.sourceId, nextSourceSyncMode(self.syncMode))
			end
		end)
		toggle.syncButton = syncButton
		table.insert(self.railSourceRows, toggle)
	end

	self.railSourceCount = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	self.railSourceCount:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 202, 74)
	self.railSourceCount:SetWidth(100)
	self.railSourcePrevious = Theme:CreateButton(work, "<", 26, 22, false)
	self.railSourcePrevious:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 306, 68)
	self.railSourcePrevious:SetScript("OnClick", function()
		Config.railSourcePage = math.max(1, (Config.railSourcePage or 1) - 1)
		Config:RefreshRailSources()
	end)
	self.railSourceNext = Theme:CreateButton(work, ">", 26, 22, false)
	self.railSourceNext:SetPoint("LEFT", self.railSourcePrevious, "RIGHT", 5, 0)
	self.railSourceNext:SetScript("OnClick", function()
		Config.railSourcePage = (Config.railSourcePage or 1) + 1
		Config:RefreshRailSources()
	end)

	self.railsStatus = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	self.railsStatus:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 202, 43)
	self.railsStatus:SetWidth(260)
	self.railsStatus:SetJustifyH("LEFT")
	local resetSources = Theme:CreateButton(work, "RESET EXPECTED", 116, 24, false)
	resetSources:SetPoint("BOTTOMRIGHT", work, "BOTTOMRIGHT", -10, 9)
	resetSources:SetScript("OnClick", function() Config:ResetRailSources() end)

	self.railPage = 1
	self.railSourcePage = 1
	self:RefreshRailsPage()
	return page
end

-- Message Views deliberately combines the former Organized Views and Rails &
-- Sources screens.  A view is the routing rule and its optional chat-tab
-- presentation, so splitting those two halves made common work needlessly
-- difficult.  Keep the legacy rail-named APIs below intact: they are used by
-- older callers and map to the same selected message view.
local legacyRefreshRailSources = Config.RefreshRailSources

local function messageViewListParts(definition)
	if not definition then
		return "-", "-"
	end
	local label = tostring(definition.label or definition.id or "View")
	local key = tostring(definition.key or "-")
	-- Built-ins ship in deliberate uppercase.  Custom names remain exactly as
	-- their owner entered them, so this does not silently restyle user work.
	if not isCustomView(definition) then
		label = string.upper(label)
		key = string.upper(key)
	end
	return key, label
end

-- The view list is deliberately narrow, so its key lane should be only as
-- wide as the labels actually need.  A fixed 48px text column made one-letter
-- keys look detached from their display names.  Measure every configured key
-- with the same font used by the rows, then keep a small, bounded gutter for
-- custom keys (the editor limits those to six characters).
local MESSAGE_VIEW_ROW_WIDTH = 156
local MESSAGE_VIEW_KEY_LEFT = 5
local MESSAGE_VIEW_KEY_MIN_WIDTH = 10
local MESSAGE_VIEW_KEY_MAX_WIDTH = 48
local MESSAGE_VIEW_KEY_DIVIDER_GUTTER = 4
local MESSAGE_VIEW_NAME_GUTTER = 6

local function getMessageViewSemanticCatalog()
	if type(addon.GetSemanticRouteCatalog) ~= "function" then
		return nil
	end
	local ok, catalog = pcall(addon.GetSemanticRouteCatalog, addon)
	if not ok or type(catalog) ~= "table" then
		return nil
	end
	return catalog
end

local function compactSemanticEvidence(categories, maximumLength)
	local groups = {}
	for _, category in ipairs(type(categories) == "table" and categories or {}) do
		if type(category) == "table" then
			local label = trim(category.label or category.id)
			local terms = {}
			for _, term in ipairs(type(category.terms) == "table" and category.terms or {}) do
				term = trim(term)
				if term ~= "" then
					table.insert(terms, term)
					if #terms == 2 then break end
				end
			end
			if label ~= "" then
				local points = tonumber(category.points)
				local group = label .. (points and ((points >= 0 and " +" or " ") .. tostring(points)) or "")
				if #terms > 0 then group = group .. ": " .. table.concat(terms, ", ") end
				table.insert(groups, group)
			end
		end
	end
	local summary = table.concat(groups, "  |  ")
	if summary == "" then summary = "Evidence groups unavailable." end
	maximumLength = maximumLength or 68
	if string.len(summary) > maximumLength then
		summary = string.sub(summary, 1, math.max(1, maximumLength - 3)) .. "..."
	end
	return summary
end

local function fullSemanticEvidence(route)
	local lines = {}
	local explanation = trim(route and route.explanation)
	if explanation ~= "" then table.insert(lines, explanation) end
	local threshold = tonumber(route and route.threshold)
	table.insert(lines, (route and route.enabled == false and "OFF" or "ENABLED")
		.. (threshold and ("  |  Threshold " .. tostring(threshold)) or ""))
	for _, category in ipairs(route and type(route.categories) == "table" and route.categories or {}) do
		if type(category) == "table" then
			local label = trim(category.label or category.id)
			local points = tonumber(category.points)
			local terms = {}
			for _, term in ipairs(type(category.terms) == "table" and category.terms or {}) do
				term = trim(term)
				if term ~= "" then table.insert(terms, term) end
			end
			if label ~= "" then
				local line = label .. (points and (" (" .. (points > 0 and "+" or "") .. tostring(points) .. ")") or "")
				if #terms > 0 then line = line .. ": " .. table.concat(terms, ", ") end
				table.insert(lines, line)
			end
		end
	end
	return table.concat(lines, "\n")
end

function Config:RefreshMessageViewSemanticCatalog()
	if not self.messageViewsSemanticCatalogRows then return end
	local catalog = getMessageViewSemanticCatalog()
	for index, row in ipairs(self.messageViewsSemanticCatalogRows) do
		local route = catalog and catalog[index]
		if type(route) == "table" then
			local label = string.upper(trim(route.label or route.id or ("ROUTE " .. index)))
			local state = route.enabled == false and "OFF" or "ON"
			local threshold = tonumber(route.threshold)
			row.title:SetText(label .. "  /  " .. state .. (threshold and ("  /  " .. tostring(threshold) .. "+") or ""))
			row.evidence:SetText(compactSemanticEvidence(route.categories, 36))
			row.semanticTooltipTitle = trim(route.label or route.id or "Semantic route") .. " evidence"
			row.semanticTooltipBody = fullSemanticEvidence(route)
			row:Show()
		else
			row.title:SetText(index == 1 and "SEMANTIC CATALOG UNAVAILABLE" or "")
			row.evidence:SetText(index == 1 and "Direct channel routes continue normally." or "")
			row.semanticTooltipTitle = "Semantic route catalog"
			row.semanticTooltipBody = "The read-only classifier catalog has not loaded. Direct channel routes continue normally."
			if index == 1 then row:Show() else row:Hide() end
		end
	end
end

function Config:LayoutMessageViewListColumns(definitions)
	local widest = MESSAGE_VIEW_KEY_MIN_WIDTH
	local measure = self.messageViewKeyMeasure
	for _, definition in ipairs(definitions or {}) do
		local key = messageViewListParts(definition)
		if measure then measure:SetText(key) end
		local measured = measure and measure.GetStringWidth and measure:GetStringWidth()
			or (string.len(tostring(key or "")) * 6)
		widest = math.max(widest, math.ceil(tonumber(measured) or 0))
	end
	widest = math.max(MESSAGE_VIEW_KEY_MIN_WIDTH, math.min(MESSAGE_VIEW_KEY_MAX_WIDTH, widest))
	local dividerX = MESSAGE_VIEW_KEY_LEFT + widest + MESSAGE_VIEW_KEY_DIVIDER_GUTTER
	local nameX = dividerX + MESSAGE_VIEW_NAME_GUTTER

	for _, row in ipairs(self.railRows or {}) do
		row.keyText:SetWidth(widest)
		row.columnDivider:ClearAllPoints()
		row.columnDivider:SetPoint("TOPLEFT", row, "TOPLEFT", dividerX, -3)
		row.columnDivider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", dividerX, 3)
		row.nameText:ClearAllPoints()
		row.nameText:SetPoint("LEFT", row, "LEFT", nameX, 0)
		row.nameText:SetPoint("RIGHT", row, "RIGHT", -3, 0)
	end

	if self.messageViewKeyHeader then
		self.messageViewKeyHeader:ClearAllPoints()
		self.messageViewKeyHeader:SetPoint("TOPLEFT", self.messageViewsPageWork, "TOPLEFT", 35, -61)
		self.messageViewKeyHeader:SetWidth(widest)
	end
	if self.messageViewNameHeader then
		self.messageViewNameHeader:ClearAllPoints()
		self.messageViewNameHeader:SetPoint("TOPLEFT", self.messageViewsPageWork, "TOPLEFT", 30 + nameX, -61)
		self.messageViewNameHeader:SetWidth(MESSAGE_VIEW_ROW_WIDTH - nameX - 3)
	end

	-- Retain the resolved geometry for focused layout QA and for any future
	-- narrow-list affordance that needs to align to these same columns.
	self.messageViewKeyColumnWidth = widest
	self.messageViewColumnDividerX = dividerX
	self.messageViewNameColumnX = nameX
end

function Config:ClearCustomViewEditor()
	self.selectedViewId = nil
	self.selectedCustomViewId = nil
	self.selectedRailId = nil
	self.pendingDeleteViewId = nil
	self.creatingCustomView = true
	self.messageViewsSection = "details"
	if not self.viewNameEdit then
		return
	end
	self.viewEditorTitle:SetText("NEW CUSTOM VIEW")
	self.viewNameEdit:SetText("")
	self.viewKeyEdit:SetText("")
	self.viewDescriptionEdit:SetText("")
	self.viewTermsEdit:SetText("")
	self:SetViewEditorMode("custom")
	self.viewVisibleToggle:SetValue(true, true)
	self.viewDeleteButton:SetLabel("DELETE")
	self.viewDeleteButton:Disable()
	if self.viewResetButton then self.viewResetButton:Disable() end
	self:RefreshMessageViewsPage(true)
	self:SetMessageViewsSection("details", true)
	self:SetViewsStatus("Give the view a name and matching words. Save it, then choose its contents.", "textMuted")
end

function Config:LoadRailEditor(viewId)
	local definition = self:FindRailDefinition(viewId)
	if not definition or not self.viewNameEdit then
		return false
	end
	local custom = isCustomView(definition)
	self.creatingCustomView = false
	self.selectedRailId = definition.id
	self.selectedViewId = definition.id
	self.selectedCustomViewId = custom and definition.id or nil
	self.pendingDeleteViewId = nil
	self.railSourcePage = 1
	-- The inspector header is deliberately sticky and terse: selection name on
	-- the left, visibility on the right. Editing controls live only inside the
	-- active goal pane below it.
	self.viewEditorTitle:SetText(string.upper(tostring(definition.label or definition.id)))
	self:SetViewEditorMode(custom and "custom" or "builtIn")
	self.viewNameEdit:SetText(definition.label or "")
	self.viewKeyEdit:SetText(definition.key or "")
	self.viewDescriptionEdit:SetText(definition.description or "")
	self.viewTermsEdit:SetText(custom and getTermsText(definition.terms) or "")
	self.viewVisibleToggle:SetValue(addon:GetSmartSettings().views[definition.id] ~= false, true)
	self.viewDeleteButton:SetLabel("DELETE")
	if custom then
		self.viewDeleteButton:Enable()
	else
		self.viewDeleteButton:Disable()
	end
	if self.viewResetButton then
		if custom then self.viewResetButton:Disable() else self.viewResetButton:Enable() end
	end
	self:RefreshRailSources()
	return true
end

function Config:SelectView(viewId)
	if not self:LoadRailEditor(viewId) then
		self:ClearCustomViewEditor()
		return
	end
	if self.messageViewsSection == "text" then
		self.messageTextAppearanceScope = viewId
	end
	self:RefreshMessageViewsPage(true)
	self:SetViewsStatus(self.messageViewsSection == "text"
		and "Choose all-tab text or keep a local override for this tab."
		or "Edit this message view, its matching rules, or the full source feeds it keeps.", "textMuted")
end

function Config:SelectCustomView(viewId)
	self:SelectView(viewId)
end

function Config:SelectRail(viewId)
	self:SelectView(viewId)
end

function Config:RefreshRailSources()
	if not self.railSourceRows then
		return
	end
	if not self.selectedRailId or self.creatingCustomView then
		for _, row in ipairs(self.railSourceRows) do
			row.sourceId = nil
			row.sourceLabel = nil
			if row.syncButton then
				row.syncButton.sourceId = nil
				row.syncButton.syncMode = nil
				row.syncButton:Hide()
			end
			row:Hide()
		end
		if self.railSourceCount then self.railSourceCount:SetText("SAVE A CUSTOM VIEW FIRST") end
		if self.railSourcePrevious then self.railSourcePrevious:Hide() end
		if self.railSourceNext then self.railSourceNext:Hide() end
		if self.railSourceHint then
			self.railSourceHint:SetText("Save this custom message view before choosing the message sources it receives.")
		end
		if self.messageViewsResetSourcesButton then self.messageViewsResetSourcesButton:Disable() end
		return
	end
	legacyRefreshRailSources(self)
	if self.railSourceHint then
		self.railSourceHint:SetText("X keeps the whole source. Removed expected feeds stay hidden; other routes can add matches.")
	end
	if self.messageViewsResetSourcesButton then self.messageViewsResetSourcesButton:Enable() end
end

-- Smart Chat text belongs with message views: the global choice is inherited
-- by every tab, while a selected tab can keep a deliberate local override.
-- Keep the selector data behind Settings' public LSM API so Config never
-- carries a second font registry or passes unchecked names to SetFont.
local function shortenSmartChatFontLabel(label, maximumLength)
	label = tostring(label or "")
	maximumLength = maximumLength or 31
	if string.len(label) <= maximumLength then
		return label
	end
	return string.sub(label, 1, math.max(1, maximumLength - 3)) .. "..."
end

local function getSmartChatTextAppearanceOptions()
	if type(addon.GetSmartChatTextAppearanceOptions) == "function" then
		local ok, options = pcall(addon.GetSmartChatTextAppearanceOptions, addon)
		if ok and type(options) == "table" then
			return options
		end
	end
	return {
		fonts = { { id = false, label = "INHERIT CURRENT CHAT FONT", inherit = true } },
		outlines = {
			{ id = "INHERIT", label = "INHERIT CHAT FONT" },
			{ id = "NONE", label = "NONE" },
			{ id = "OUTLINE", label = "OUTLINE" },
			{ id = "THICKOUTLINE", label = "THICK OUTLINE" },
		},
		size = { minimum = 8, maximum = 32, inherit = 0 },
		spacing = { minimum = 0, maximum = 8, default = 1 },
		entryGapRows = { minimum = 0, maximum = 2, default = 0 },
	}
end

local function getSmartChatTextAppearance(scope)
	if type(addon.GetSmartChatTextAppearance) == "function" then
		local ok, appearance = pcall(addon.GetSmartChatTextAppearance, addon, scope)
		if ok and type(appearance) == "table" then
			return appearance
		end
	end
	return { size = 0, outline = "INHERIT", spacing = 1, entryGapRows = 0 }
end

local function getSmartChatTextAppearanceOverride(scope)
	if scope == "global" or type(addon.GetSmartChatTextAppearanceOverride) ~= "function" then
		return nil
	end
	local ok, appearance = pcall(addon.GetSmartChatTextAppearanceOverride, addon, scope)
	if ok and type(appearance) == "table" then
		return appearance
	end
	return nil
end

function Config:GetSmartChatTextAppearanceScope()
	local scope = self.messageTextAppearanceScope
	if scope == "global" then
		return scope
	end
	if scope and self:FindRailDefinition(scope) then
		return scope
	end
	if self.selectedRailId and self:FindRailDefinition(self.selectedRailId) then
		return self.selectedRailId
	end
	return "global"
end

local function isFontPickerMouseOver(picker)
	if not picker then
		return false
	end
	if picker.IsMouseOver then
		local ok, inside = pcall(picker.IsMouseOver, picker)
		if ok and inside then
			return true
		end
	end
	-- Child edit boxes and rows can own focus on old clients. Follow their
	-- parents so an inside click is never mistaken for an outside dismissal.
	local getMouseFocus = (_G and _G.GetMouseFocus) or GetMouseFocus
	if type(getMouseFocus) ~= "function" then
		return false
	end
	local ok, focus = pcall(getMouseFocus)
	while ok and focus do
		if focus == picker then
			return true
		end
		if not focus.GetParent then
			break
		end
		focus = focus:GetParent()
	end
	return false
end

function Config:HideSmartChatTextFontPicker()
	local picker = self.messageTextFontPicker
	if picker then
		picker:Hide()
	end
	if self.messageTextFontSearch then
		if self.messageTextFontSearch.ClearFocus then self.messageTextFontSearch:ClearFocus() end
		self.messageTextFontSearch:SetText("")
	end
	self.messageTextFontOffset = 1
end

function Config:SetSmartChatTextAppearanceScope(scope, quiet)
	if scope ~= "global" and not self:FindRailDefinition(scope) then
		scope = self.selectedRailId and self:FindRailDefinition(self.selectedRailId) and self.selectedRailId or "global"
	end
	self.messageTextAppearanceScope = scope
	self.messageTextFontOffset = 1
	self:HideSmartChatTextFontPicker()
	self:SetMessageViewsSection("text", true)
	self:RefreshSmartChatTextAppearanceControls()
	if not quiet then
		self:SetViewsStatus(scope == "global"
			and "All message tabs inherit this text appearance unless a tab has its own override."
			or "This tab can inherit all-tab text or keep its own override.", "textMuted")
	end
end

-- The live chat's Shift affordance is a shortcut, not a second set of hidden
-- state-changing checkboxes. Open the one authoritative, labelled editor and
-- select its global scope so channel/name alignment cannot be mistaken for a
-- per-tab text override.
function Config:OpenGlobalTextAlignment()
	self:Open()
	if not self.frame then return false end
	self:ShowPage("views")
	self:SetSmartChatTextAppearanceScope("global", true)
	self:SetViewsStatus("Alignment applies to every tab. Configure channels, player names, gaps, and visible-only sizing here.", "textMuted")
	return true
end

function Config:ApplySmartChatTextAppearance(patch, status)
	if type(addon.SetSmartChatTextAppearance) ~= "function" then
		self:SetViewsStatus("Smart Chat text controls are unavailable in this build.", "warning")
		return false
	end
	local scope = self:GetSmartChatTextAppearanceScope()
	local ok, accepted, detail = pcall(addon.SetSmartChatTextAppearance, addon, scope, patch)
	if not ok or accepted == false then
		self:SetViewsStatus("Text appearance was not applied: " .. tostring(detail or "invalid setting") .. ".", "warning")
		return false
	end
	self:RefreshSmartChatTextAppearanceControls()
	if status then self:SetViewsStatus(status, "success") end
	return true
end

function Config:ResetSmartChatTextAppearance()
	if type(addon.ResetSmartChatTextAppearance) ~= "function" then
		self:SetViewsStatus("Smart Chat text controls are unavailable in this build.", "warning")
		return false
	end
	local scope = self:GetSmartChatTextAppearanceScope()
	local ok, accepted = pcall(addon.ResetSmartChatTextAppearance, addon, scope)
	if not ok or accepted == false then
		self:SetViewsStatus("Text appearance reset is unavailable right now.", "warning")
		return false
	end
	self:RefreshSmartChatTextAppearanceControls()
	self:SetViewsStatus(scope == "global"
		and "All-tab text returned to the current chat font. Local tab overrides remain intact."
		or "This tab now inherits all-tab text again.", "success")
	return true
end

local function applySmartChatTextPreview(fontString, fontKey)
	if not fontString then
		return
	end
	if fontKey and type(addon.ResolveSmartChatTextFont) == "function" then
		local ok, path = pcall(addon.ResolveSmartChatTextFont, addon, fontKey)
		if ok and type(path) == "string" and path ~= "" and fontString.SetFont then
			fontString:SetFont(path, 12, "")
			return
		end
	end
	if fontString.SetFontObject and _G.ChatFontNormal then
		fontString:SetFontObject(_G.ChatFontNormal)
	end
end

function Config:ScrollSmartChatTextFontPicker(delta)
	local picker = self.messageTextFontPicker
	if not picker or not picker:IsShown() then
		return
	end
	delta = tonumber(delta) or 0
	if delta == 0 then
		return
	end
	-- WoW reports a positive delta for wheel-up. Move one visible font at a
	-- time so the chooser behaves like a real compact dropdown rather than a
	-- page-flipping dialog.
	self.messageTextFontOffset = math.max(1, (tonumber(self.messageTextFontOffset) or 1)
		+ (delta > 0 and -1 or 1))
	self:RefreshSmartChatTextFontPicker()
end

local function filterSmartChatFontOptions(fonts, query)
	query = string.lower(trim(query))
	if query == "" then
		return fonts, query
	end
	local filtered = {}
	for index = 1, #fonts do
		local option = fonts[index]
		local label = string.lower(tostring(option and (option.label or option.lsmKey or option.id) or ""))
		-- Inherit must remain available even while filtering so a player can
		-- always clear a chosen override from the same compact popup.
		if option and (option.inherit or string.find(label, query, 1, true)) then
			table.insert(filtered, option)
		end
	end
	return filtered, query
end

function Config:RefreshSmartChatTextFontPicker()
	local picker = self.messageTextFontPicker
	if not picker or not picker:IsShown() then
		return
	end
	local options = getSmartChatTextAppearanceOptions()
	local fonts = type(options.fonts) == "table" and options.fonts or {}
	-- The seven-row chooser opens with all fonts visible and narrows live when
	-- the optional search field has text. Its list scrolls under the mouse.
	local searchText = self.messageTextFontSearch and self.messageTextFontSearch:GetText() or ""
	local filtered, query = filterSmartChatFontOptions(fonts, searchText)
	if self.messageTextFontSearchHint then
		if query == "" then self.messageTextFontSearchHint:Show() else self.messageTextFontSearchHint:Hide() end
	end
	local pageSize = #self.messageTextFontRows
	local maxOffset = math.max(1, #filtered - math.max(1, pageSize) + 1)
	self.messageTextFontOffset = math.max(1, math.min(tonumber(self.messageTextFontOffset) or 1, maxOffset))
	local startIndex = self.messageTextFontOffset
	local appearance = getSmartChatTextAppearance(self:GetSmartChatTextAppearanceScope())
	for rowIndex = 1, pageSize do
		local row = self.messageTextFontRows[rowIndex]
		local option = filtered[startIndex + rowIndex - 1]
		if option then
			row.option = option
			row:SetLabel(shortenSmartChatFontLabel(option.label or option.lsmKey or option.id, 34))
			row.text:ClearAllPoints()
			row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
			row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
			row.text:SetJustifyH("LEFT")
			applySmartChatTextPreview(row.text, option.inherit and nil or option.id)
			local selected = (option.inherit and appearance.font == nil)
				or (not option.inherit and option.id == appearance.font)
			setChoiceStyle(row, selected)
			row:Show()
		else
			row.option = nil
			row:Hide()
		end
	end
	if self.messageTextFontCount then
		local registeredCount = math.max(0, #filtered - 1) -- first row is Inherit
		if query ~= "" and registeredCount == 0 then
			self.messageTextFontCount:SetText("NO MATCHING FONTS")
		elseif registeredCount == 0 then
			self.messageTextFontCount:SetText("NO SHARED MEDIA FONTS")
		elseif #filtered > pageSize then
			self.messageTextFontCount:SetText("FONTS " .. startIndex .. "-" .. math.min(#filtered, startIndex + pageSize - 1) .. " / " .. #filtered)
		else
			self.messageTextFontCount:SetText(registeredCount .. " SHARED MEDIA FONT" .. (registeredCount == 1 and "" or "S"))
		end
	end
end

function Config:RefreshSmartChatTextAppearanceControls()
	if not self.messageViewsTextPane then
		return
	end
	local scope = self:GetSmartChatTextAppearanceScope()
	self.messageTextAppearanceScope = scope
	local appearance = getSmartChatTextAppearance(scope)
	local override = getSmartChatTextAppearanceOverride(scope)
	local isGlobal = scope == "global"
	local definition = not isGlobal and self:FindRailDefinition(scope) or nil
	if self.messageTextScopeTitle then
		self.messageTextScopeTitle:SetText(isGlobal and "ALL CHAT TABS" or string.upper(tostring((definition and definition.label) or scope)) .. " TAB")
	end
	if self.messageTextScopeHint then
		self.messageTextScopeHint:SetText(isGlobal
			and "Global text: every tab inherits this unless you override that tab."
			or (override and "This tab has a local text override. RESET THIS TAB restores inheritance."
				or "This tab inherits the all-tabs text appearance."))
	end
	local function style(button, active)
		if button then button:SetTheme(active and "accentSoft" or "surfaceRaised", active and "gold" or "borderMuted", active and "goldBright" or "text") end
	end
	style(self.messageTextAllTabsButton, isGlobal)
	style(self.messageTextThisTabButton, not isGlobal)
	if self.messageTextThisTabButton then
		if definition then self.messageTextThisTabButton:Enable() else self.messageTextThisTabButton:Disable() end
	end
	if self.allTabsTextButton then
		style(self.allTabsTextButton, isGlobal and self.messageViewsSection == "text")
	end
	if self.messageTextFontPreview then
		local label = appearance.font and tostring(appearance.font) or "INHERIT CURRENT CHAT FONT"
		self.messageTextFontPreview:SetText(shortenSmartChatFontLabel(label, 48))
		applySmartChatTextPreview(self.messageTextFontPreview, appearance.font)
	end
	if self.messageTextSizeEdit then
		self.messageTextSizeEdit:SetText(tostring(tonumber(appearance.size) or 0))
	end
	if self.messageTextSpacingEdit then
		self.messageTextSpacingEdit:SetText(tostring(tonumber(appearance.spacing) or 1))
	end
	if self.messageTextEntryGapEdit then
		self.messageTextEntryGapEdit:SetText(tostring(tonumber(appearance.entryGapRows) or 0))
	end
	for _, button in ipairs(self.messageTextOutlineButtons or {}) do
		style(button, button.outlineId == (appearance.outline or "INHERIT"))
	end
	if self.messageTextResetButton then
		self.messageTextResetButton:SetLabel(isGlobal and "RESET ALL TABS" or "RESET THIS TAB")
	end
	-- Alignment is deliberately global even while THIS TAB is editing a local
	-- font override.  Hiding these controls in per-tab scope made the feature
	-- look removed and left name alignment accessible only through an anonymous
	-- live-chat checkbox. Keep the complete, clearly labelled block present in
	-- both text scopes and state the all-tabs ownership in its heading.
	local viewId = self.selectedRailId or "general"
	local sourceAlignmentAvailable = type(addon.GetViewSourceColumnAlignment) == "function"
		and type(addon.SetViewSourceColumnAlignment) == "function"
	local senderAlignmentAvailable = type(addon.GetViewSenderColumnAlignment) == "function"
		and type(addon.SetViewSenderColumnAlignment) == "function"
	if self.messageTextAlignmentTitle then
		if sourceAlignmentAvailable or senderAlignmentAvailable then self.messageTextAlignmentTitle:Show()
		else self.messageTextAlignmentTitle:Hide() end
	end
	if self.messageTextColumnAlignmentToggle then
		if sourceAlignmentAvailable then
			local ok, enabled = pcall(addon.GetViewSourceColumnAlignment, addon, viewId)
			self.messageTextColumnAlignmentToggle:SetValue(ok and enabled == true, true)
			self.messageTextColumnAlignmentToggle:Show()
		else
			self.messageTextColumnAlignmentToggle:Hide()
		end
	end
	if self.messageTextSenderColumnAlignmentToggle then
		if senderAlignmentAvailable then
			local ok, enabled = pcall(addon.GetViewSenderColumnAlignment, addon, viewId)
			self.messageTextSenderColumnAlignmentToggle:SetValue(ok and enabled == true, true)
			self.messageTextSenderColumnAlignmentToggle:Show()
		else
			self.messageTextSenderColumnAlignmentToggle:Hide()
		end
	end
	if self.messageTextColumnAlignmentSpacingLabel then
		if type(addon.GetColumnAlignmentSpacing) == "function" then self.messageTextColumnAlignmentSpacingLabel:Show()
		else self.messageTextColumnAlignmentSpacingLabel:Hide() end
	end
	if self.messageTextColumnAlignmentSpacingEdit then
		if type(addon.GetColumnAlignmentSpacing) == "function" then
			self.messageTextColumnAlignmentSpacingEdit:SetText(tostring(addon:GetColumnAlignmentSpacing()))
			self.messageTextColumnAlignmentSpacingEdit:Show()
		else self.messageTextColumnAlignmentSpacingEdit:Hide() end
	end
	if self.messageTextColumnAlignmentSpacingHint then
		if type(addon.GetColumnAlignmentSpacing) == "function" then self.messageTextColumnAlignmentSpacingHint:Show()
		else self.messageTextColumnAlignmentSpacingHint:Hide() end
	end
	if self.messageTextSenderColumnAlignmentSpacingLabel then
		if type(addon.GetSenderColumnAlignmentSpacing) == "function" then self.messageTextSenderColumnAlignmentSpacingLabel:Show()
		else self.messageTextSenderColumnAlignmentSpacingLabel:Hide() end
	end
	if self.messageTextSenderColumnAlignmentSpacingEdit then
		if type(addon.GetSenderColumnAlignmentSpacing) == "function" then
			self.messageTextSenderColumnAlignmentSpacingEdit:SetText(tostring(addon:GetSenderColumnAlignmentSpacing()))
			self.messageTextSenderColumnAlignmentSpacingEdit:Show()
		else self.messageTextSenderColumnAlignmentSpacingEdit:Hide() end
	end
	if self.messageTextSenderColumnAlignmentSpacingHint then
		if type(addon.GetSenderColumnAlignmentSpacing) == "function" then self.messageTextSenderColumnAlignmentSpacingHint:Show()
		else self.messageTextSenderColumnAlignmentSpacingHint:Hide() end
	end
	if self.messageTextSenderColumnMaxLengthLabel then
		if type(addon.GetSenderColumnMaxLength) == "function" then self.messageTextSenderColumnMaxLengthLabel:Show()
		else self.messageTextSenderColumnMaxLengthLabel:Hide() end
	end
	if self.messageTextSenderColumnMaxLengthEdit then
		if type(addon.GetSenderColumnMaxLength) == "function" then
			self.messageTextSenderColumnMaxLengthEdit:SetText(tostring(addon:GetSenderColumnMaxLength()))
			self.messageTextSenderColumnMaxLengthEdit:Show()
		else self.messageTextSenderColumnMaxLengthEdit:Hide() end
	end
	if self.messageTextSenderColumnMaxLengthHint then
		if type(addon.GetSenderColumnMaxLength) == "function" then self.messageTextSenderColumnMaxLengthHint:Show()
		else self.messageTextSenderColumnMaxLengthHint:Hide() end
	end
	if self.messageTextAlignmentVisibleOnlyToggle then
		if type(addon.GetAlignmentVisibleOnly) == "function" then
			self.messageTextAlignmentVisibleOnlyToggle:SetValue(addon:GetAlignmentVisibleOnly() == true, true)
			self.messageTextAlignmentVisibleOnlyToggle:Show()
		else self.messageTextAlignmentVisibleOnlyToggle:Hide() end
	end
	self:RefreshSmartChatTextFontPicker()
end

function Config:SetMessageViewsSection(section, quiet)
	if section ~= "sources" and section ~= "text" then
		section = "details"
	end
	if section ~= "text" then
		self:HideSmartChatTextFontPicker()
	end
	self.messageViewsSection = section
	if self.messageViewsDetailsPane then
		if section == "details" then self.messageViewsDetailsPane:Show() else self.messageViewsDetailsPane:Hide() end
	end
	if self.messageViewsSourcesPane then
		if section == "sources" then self.messageViewsSourcesPane:Show() else self.messageViewsSourcesPane:Hide() end
	end
	if self.messageViewsTextPane then
		if section == "text" then self.messageViewsTextPane:Show() else self.messageViewsTextPane:Hide() end
	end
	setTabStyle(self.messageViewsDetailsButton, section == "details")
	setTabStyle(self.messageViewsSourcesButton, section == "sources")
	setTabStyle(self.messageViewsTextButton, section == "text")
	if section == "sources" then self:RefreshRailSources() end
	if section == "text" then self:RefreshSmartChatTextAppearanceControls() end
	if section == "details" then self:RefreshMessageViewSemanticCatalog() end
	if not quiet then
		local status = section == "sources" and "Choose what this tab contains and how noisy add-on channels are handled."
			or (section == "text" and "Choose all-tab text or a local override for the selected tab."
				or "Change the tab label and the rules that identify messages for this view.")
		self:SetViewsStatus(status, "textMuted")
	end
end

function Config:RefreshMessageViewsPage(keepStatus)
	if not self.messageViewsPage then
		return
	end
	local definitions = self:GetRailDefinitions()
	local selected = self.selectedRailId
	if selected and not self:FindRailDefinition(selected) then
		self.selectedRailId = nil
		self.selectedViewId = nil
		self.selectedCustomViewId = nil
		selected = nil
	end
	if not selected and not self.creatingCustomView and definitions[1] then
		selected = definitions[1].id
		self.selectedRailId = selected
	end

	local pageSize = #self.railRows
	local pageCount = math.max(1, math.ceil(#definitions / math.max(1, pageSize)))
	self.railPage = math.max(1, math.min(self.railPage or 1, pageCount))
	local startIndex = ((self.railPage - 1) * pageSize) + 1
	local settings = addon:GetSmartSettings()
	local lastVisibleRow
	for rowIndex = 1, pageSize do
		local row = self.railRows[rowIndex]
		local definition = definitions[startIndex + rowIndex - 1]
		if definition then
			local enabled = settings.views[definition.id] ~= false
			local isSelected = definition.id == selected
			local key, label = messageViewListParts(definition)
			row.viewId = definition.id
			row.stateToggle.viewId = definition.id
			row.stateToggle:SetValue(enabled, true)
			row:SetLabel(key)
			if row.nameText then row.nameText:SetText(label) end
			row.fullViewKey = key
			row.fullViewName = label
			if row.SetTooltip then
				row:SetTooltip(key .. " | " .. label,
					"Tab label: " .. key .. "\nDisplay name: " .. label .. "\nClick to edit. Shift-drag to reorder.")
			end
			setChoiceStyle(row, isSelected, enabled and (isSelected and "goldBright" or "text") or "textMuted")
			if row.SetViewTextState then row:SetViewTextState(enabled, isSelected) end
			if row.selectionAccent then
				if isSelected then row.selectionAccent:Show() else row.selectionAccent:Hide() end
			end
			row.stateToggle:Show()
			row:Show()
			lastVisibleRow = row
		else
			row.viewId = nil
			row.stateToggle.viewId = nil
			row.stateToggle:Hide()
			if row.selectionAccent then row.selectionAccent:Hide() end
			row:Hide()
		end
	end
	self:LayoutMessageViewListColumns(definitions)
	if self.railDropAfter then
		if self.railDragViewId and lastVisibleRow then
			self.railDropAfter:ClearAllPoints()
			self.railDropAfter:SetPoint("TOPLEFT", lastVisibleRow, "BOTTOMLEFT", 0, -2)
			self.railDropAfter:Show()
		else
			self.railDropAfter:Hide()
		end
	end
	if self.railCount then
		if #definitions == 0 then
			self.railCount:SetText("NO MESSAGE VIEWS")
		elseif pageCount > 1 then
			self.railCount:SetText(startIndex .. "-" .. math.min(#definitions, startIndex + pageSize - 1) .. " / " .. #definitions)
		else
			self.railCount:SetText(#definitions .. " VIEWS")
		end
	end
	if self.railPrevious and self.railNext then
		if pageCount > 1 then
			self.railPrevious:Show()
			self.railNext:Show()
			if self.railPage > 1 then self.railPrevious:Enable() else self.railPrevious:Disable() end
			if self.railPage < pageCount then self.railNext:Enable() else self.railNext:Disable() end
		else
			self.railPrevious:Hide()
			self.railNext:Hide()
		end
	end
	self:RefreshRailOrderControls(definitions)
	if selected then
		self:LoadRailEditor(selected)
	else
		self:RefreshRailSources()
	end
	self:SetMessageViewsSection(self.messageViewsSection or "details", true)
	if not keepStatus and not self.creatingCustomView then
		self:SetViewsStatus("Drag to order live chat tabs. Click a name to edit it; only its X changes visibility.", "textMuted")
	end
end

function Config:RefreshViewsPage(keepStatus)
	self:RefreshMessageViewsPage(keepStatus)
end

function Config:RefreshRailsPage(keepStatus)
	self:RefreshMessageViewsPage(keepStatus)
end

function Config:BuildViewsPage()
	if self.pages.views then
		return self.pages.views
	end
	local page = self:CreatePage("views")
	self.viewsPage = page
	self.railsPage = page
	self.messageViewsPage = page
	self.messageViewsUnified = true
	self.creatingCustomView = false
	createHeading(page, "Views & Tabs", "Choose what each tab shows, then arrange the order shown in your chat window.")

	local work = createQuietShellPanel(page, "surface")
	work:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -PAGE_TOP)
	work:SetSize(PAGE_WIDTH, 438)
	self.messageViewsPageWork = work

	local divider = work:CreateTexture(nil, "ARTWORK")
	divider:SetTexture("Interface\\Buttons\\WHITE8x8")
	Theme:RegisterTexture(divider, "borderMuted")
	divider:SetPoint("TOPLEFT", work, "TOPLEFT", 190, -1)
	divider:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 190, 1)
	divider:SetWidth(1)

	local listTitle = Theme:CreateText(work, "GameFontNormalSmall", "gold")
	listTitle:SetPoint("TOPLEFT", work, "TOPLEFT", 10, -9)
	listTitle:SetText("MESSAGE VIEWS")
	local newButton = Theme:CreateButton(work, "NEW CUSTOM", 76, 20, true)
	setActionStyle(newButton, "primary", "Create a custom view", "Start a new chat view, then choose its sources and tab label.")
	newButton:SetPoint("TOPRIGHT", work, "TOPLEFT", 180, -6)
	newButton:SetScript("OnClick", function()
		Config:ClearCustomViewEditor()
	end)
	-- This is a real GLOBAL entry for text appearance, not a hidden setting in
	-- Chat Window: it makes the inheritance relationship visible beside the
	-- tabs it controls.
	-- This is the one intentional non-tab entry in the view list: it owns the
	-- global default that every individual tab inherits until overridden.
	self.allTabsTextButton = Theme:CreateButton(work, "GLOBAL TEXT", 170, 22, false)
	setActionStyle(self.allTabsTextButton, "choice", "Text defaults for every tab", "Choose the shared font and outline. Individual tabs can override it later.")
	self.allTabsTextButton:SetPoint("TOPLEFT", work, "TOPLEFT", 10, -34)
	self.allTabsTextButton.text:ClearAllPoints()
	self.allTabsTextButton.text:SetPoint("LEFT", self.allTabsTextButton, "LEFT", 5, 0)
	self.allTabsTextButton.text:SetPoint("RIGHT", self.allTabsTextButton, "RIGHT", -5, 0)
	self.allTabsTextButton.text:SetJustifyH("LEFT")
	self.allTabsTextButton:SetScript("OnClick", function()
		Config:SetSmartChatTextAppearanceScope("global")
	end)

	self.messageViewKeyHeader = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	self.messageViewKeyHeader:SetPoint("TOPLEFT", work, "TOPLEFT", 35, -61)
	self.messageViewKeyHeader:SetWidth(MESSAGE_VIEW_KEY_MIN_WIDTH)
	self.messageViewKeyHeader:SetJustifyH("LEFT")
	self.messageViewKeyHeader:SetText("TAB")
	self.messageViewNameHeader = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	self.messageViewNameHeader:SetPoint("TOPLEFT", work, "TOPLEFT", 60, -61)
	self.messageViewNameHeader:SetWidth(123)
	self.messageViewNameHeader:SetJustifyH("LEFT")
	self.messageViewNameHeader:SetText("DISPLAY NAME")
	self.messageViewKeyMeasure = Theme:CreateText(work, "GameFontNormalSmall", "text")
	self.messageViewKeyMeasure:Hide()

	self.railRows = {}
	for index = 1, 12 do
		local stateToggle = Theme:CreateCompactToggle(work, "", 18)
		stateToggle.label:ClearAllPoints()
		stateToggle.label:SetPoint("CENTER", stateToggle, "CENTER", 0, 0)
		stateToggle.label:Hide()
		stateToggle:SetPoint("TOPLEFT", work, "TOPLEFT", 10, -75 - ((index - 1) * 26))
		stateToggle.OnValueChanged = function(self, value)
			if self.viewId then Config:SetViewVisibility(self.viewId, value) end
		end
		local row = Theme:CreateButton(work, "", MESSAGE_VIEW_ROW_WIDTH, 22, false)
		row:SetPoint("LEFT", stateToggle, "RIGHT", 2, 0)
		row.stateToggle = stateToggle
		row.text:ClearAllPoints()
		row.text:SetPoint("LEFT", row, "LEFT", 5, 0)
		row.text:SetWidth(MESSAGE_VIEW_KEY_MIN_WIDTH)
		row.text:SetJustifyH("LEFT")
		if row.text.SetWordWrap then row.text:SetWordWrap(false) end
		row.keyText = row.text
		local columnDivider = row:CreateTexture(nil, "ARTWORK")
		columnDivider:SetTexture("Interface\\Buttons\\WHITE8x8")
		columnDivider:SetPoint("TOPLEFT", row, "TOPLEFT", 19, -3)
		columnDivider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 19, 3)
		columnDivider:SetWidth(1)
		Theme:RegisterTexture(columnDivider, "borderMuted")
		row.columnDivider = columnDivider
		row.nameText = Theme:CreateText(row, "GameFontNormalSmall", "text")
		row.nameText:SetPoint("LEFT", row, "LEFT", 25, 0)
		row.nameText:SetPoint("RIGHT", row, "RIGHT", -3, 0)
		row.nameText:SetJustifyH("LEFT")
		if row.nameText.SetWordWrap then row.nameText:SetWordWrap(false) end
		function row:SetViewTextState(enabled, selected)
			self.viewEnabled = enabled and true or false
			self.viewSelected = selected and true or false
			local keyColor = selected and "goldBright" or (enabled and "gold" or "textMuted")
			local nameColor = selected and "goldBright" or (enabled and "text" or "textMuted")
			Theme.texts[self.keyText] = keyColor
			Theme.texts[self.nameText] = nameColor
			local kr, kg, kb, ka = Theme:GetColor(keyColor)
			local nr, ng, nb, na = Theme:GetColor(nameColor)
			self.keyText:SetTextColor(kr, kg, kb, ka)
			self.nameText:SetTextColor(nr, ng, nb, na)
		end
		local selectionAccent = row:CreateTexture(nil, "OVERLAY")
		selectionAccent:SetTexture("Interface\\Buttons\\WHITE8x8")
		selectionAccent:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
		selectionAccent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 1, 1)
		selectionAccent:SetWidth(2)
		Theme:RegisterTexture(selectionAccent, "gold")
		selectionAccent:Hide()
		row.selectionAccent = selectionAccent
		row:RegisterForDrag("LeftButton")
		row:SetScript("OnClick", function(self)
			if not Config:ShouldSuppressRailClick() and self.viewId then Config:SelectView(self.viewId) end
		end)
		row:SetScript("OnDragStart", function(self)
			Config:BeginRailDrag(self)
		end)
		row:SetScript("OnDragStop", function()
			Config:EndRailDrag()
		end)
		row:HookScript("OnEnter", function(self)
			Config:UpdateRailDragTarget(self)
			local r, g, b, a = Theme:GetColor(self.viewSelected and "goldBright" or "gold")
			self.keyText:SetTextColor(r, g, b, a)
			self.nameText:SetTextColor(r, g, b, a)
		end)
		row:HookScript("OnLeave", function(self)
			if Config.railDragTargetId == self.viewId then Config:ClearRailDragTarget() end
			self:SetViewTextState(self.viewEnabled, self.viewSelected)
		end)
		table.insert(self.railRows, row)
	end
	self.railDragMarker = work:CreateTexture(nil, "OVERLAY")
	self.railDragMarker:SetTexture("Interface\\Buttons\\WHITE8x8")
	self.railDragMarker:SetHeight(2)
	Theme:RegisterTexture(self.railDragMarker, "goldBright")
	self.railDragMarker:Hide()
	self.railDropAfter = CreateFrame("Frame", nil, work)
	self.railDropAfter:SetSize(MESSAGE_VIEW_ROW_WIDTH, 8)
	self.railDropAfter:EnableMouse(true)
	self.railDropAfter:SetScript("OnEnter", function()
		local lastRow
		for _, candidate in ipairs(Config.railRows or {}) do
			if candidate:IsShown() then lastRow = candidate end
		end
		if lastRow then Config:UpdateRailDragAfterTarget(lastRow) end
	end)
	self.railDropAfter:SetScript("OnLeave", function()
		if Config.railDragAfterViewId then Config:ClearRailDragTarget() end
	end)
	self.railDropAfter:Hide()
	self.railCount = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	self.railCount:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 10, 14)
	self.railCount:SetWidth(82)
	self.railCount:SetJustifyH("LEFT")
	self.railPrevious = Theme:CreateButton(work, "<", 24, 20, false)
	self.railPrevious:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 88, 8)
	self.railPrevious:SetScript("OnClick", function()
		Config.railPage = math.max(1, (Config.railPage or 1) - 1)
		local definitions = Config:GetRailDefinitions()
		local first = definitions[((Config.railPage - 1) * #Config.railRows) + 1]
		if first then Config.selectedRailId = first.id end
		Config.creatingCustomView = false
		Config:RefreshMessageViewsPage(true)
	end)
	self.railNext = Theme:CreateButton(work, ">", 24, 20, false)
	self.railNext:SetPoint("LEFT", self.railPrevious, "RIGHT", CONTROL_GAP, 0)
	self.railNext:SetScript("OnClick", function()
		Config.railPage = (Config.railPage or 1) + 1
		local definitions = Config:GetRailDefinitions()
		local first = definitions[((Config.railPage - 1) * #Config.railRows) + 1]
		if first then Config.selectedRailId = first.id end
		Config.creatingCustomView = false
		Config:RefreshMessageViewsPage(true)
	end)
	self.railMoveUp = Theme:CreateButton(work, "UP", 28, 20, false)
	self.railMoveUp:SetPoint("BOTTOMRIGHT", work, "BOTTOMLEFT", 148, 8)
	self.railMoveUp:SetScript("OnClick", function()
		if Config.selectedRailId then Config:MoveRail(Config.selectedRailId, -1) end
	end)
	self.railMoveDown = Theme:CreateButton(work, "DN", 28, 20, false)
	self.railMoveDown:SetPoint("LEFT", self.railMoveUp, "RIGHT", CONTROL_GAP, 0)
	self.railMoveDown:SetScript("OnClick", function()
		if Config.selectedRailId then Config:MoveRail(Config.selectedRailId, 1) end
	end)

	self.viewEditorTitle = Theme:CreateText(work, "GameFontNormalSmall", "gold")
	self.viewEditorTitle:SetPoint("TOPLEFT", work, "TOPLEFT", 202, -12)
	self.viewEditorTitle:SetWidth(250)
	self.viewVisibleToggle = Theme:CreateCompactToggle(work, "VISIBLE IN CHAT", 146)
	self.viewVisibleToggle:SetPoint("TOPRIGHT", work, "TOPRIGHT", -10, -6)
	setControlTooltip(self.viewVisibleToggle, "Show this chat tab", "Turn this off to keep the view and its rules without showing its tab in the chat window.")
	self.viewVisibleToggle.OnValueChanged = function(_, value)
		if Config.selectedViewId then
			Config:SetViewVisibility(Config.selectedViewId, value)
		end
	end
	-- Legacy rail fields are aliases, not a second editor.  This preserves
	-- pre-existing external Config calls while every user sees one inspector.
	self.railEditorTitle = self.viewEditorTitle
	self.railVisibleToggle = self.viewVisibleToggle

	-- These are exclusive task panes, not secondary pages. The sticky header
	-- above them never changes, so the player always knows which view is being
	-- edited while switching goals.
	self.messageViewsSourcesButton = Theme:CreateTightButton(work, "CONTENTS", 20, false)
	self.messageViewsSourcesButton:SetPoint("TOPLEFT", work, "TOPLEFT", 202, -42)
	setControlTooltip(self.messageViewsSourcesButton, "Contents", "Choose the message sources that appear in this view.")
	self.messageViewsSourcesButton:SetScript("OnClick", function()
		Config:SetMessageViewsSection("sources")
	end)
	self.messageViewsDetailsButton = Theme:CreateTightButton(work, "LABEL & RULES", 20, false)
	self.messageViewsDetailsButton:SetPoint("LEFT", self.messageViewsSourcesButton, "RIGHT", CONTROL_GAP, 0)
	setControlTooltip(self.messageViewsDetailsButton, "Label and rules", "Rename the tab and edit the words that identify messages for a custom view.")
	self.messageViewsDetailsButton:SetScript("OnClick", function()
		Config:SetMessageViewsSection("details")
	end)
	self.messageViewsTextButton = Theme:CreateTightButton(work, "TEXT", 20, false)
	self.messageViewsTextButton:SetPoint("LEFT", self.messageViewsDetailsButton, "RIGHT", CONTROL_GAP, 0)
	setControlTooltip(self.messageViewsTextButton, "Text", "Choose the font, size, outline, and aligned-column spacing for this view.")
	self.messageViewsTextButton:SetScript("OnClick", function()
		Config:SetSmartChatTextAppearanceScope(Config.selectedRailId or "global", true)
	end)

	local details = CreateFrame("Frame", nil, work)
	details:SetPoint("TOPLEFT", work, "TOPLEFT", 202, -74)
	details:SetPoint("BOTTOMRIGHT", work, "BOTTOMRIGHT", -10, 8)
	self.messageViewsDetailsPane = details
	local nameLabel = Theme:CreateText(details, "GameFontHighlightSmall", "textMuted")
	nameLabel:SetPoint("TOPLEFT", details, "TOPLEFT", 0, 0)
	nameLabel:SetText("DISPLAY NAME")
	local keyLabel = Theme:CreateText(details, "GameFontHighlightSmall", "textMuted")
	keyLabel:SetPoint("TOPLEFT", details, "TOPLEFT", 204, 0)
	keyLabel:SetText("TAB LABEL / KEY")
	self.viewNameEdit = Theme:CreateEditBox(details, 194, 24, false)
	self.viewNameEdit:SetPoint("TOPLEFT", details, "TOPLEFT", 0, -13)
	self.viewNameEdit:SetMaxLetters(40)
	self.viewKeyEdit = Theme:CreateEditBox(details, 204, 24, false)
	self.viewKeyEdit:SetPoint("TOPLEFT", details, "TOPLEFT", 204, -13)
	self.viewKeyEdit:SetMaxLetters(6)
	setControlTooltip(nameLabel, "Display name", "The full name used in settings and anywhere Chatty has enough room.")
	setControlTooltip(self.viewNameEdit, "Display name", "The full name used in settings and anywhere Chatty has enough room.")
	setControlTooltip(keyLabel, "Tab label / key", "The short label shown on the compact chat-tab bar. Keep it recognizable at a glance.")
	setControlTooltip(self.viewKeyEdit, "Tab label / key", "The short label shown on the compact chat-tab bar. Keep it recognizable at a glance.")
	self.railNameEdit = self.viewNameEdit
	self.railKeyEdit = self.viewKeyEdit
	local descriptionLabel = Theme:CreateText(details, "GameFontHighlightSmall", "textMuted")
	descriptionLabel:SetPoint("TOPLEFT", details, "TOPLEFT", 0, -47)
	descriptionLabel:SetText("SHORT DESCRIPTION")
	self.viewDescriptionEdit = Theme:CreateEditBox(details, 408, 24, false)
	self.viewDescriptionEdit:SetPoint("TOPLEFT", details, "TOPLEFT", 0, -60)
	self.viewDescriptionEdit:SetMaxLetters(160)
	self.viewTermsLabel = Theme:CreateText(details, "GameFontHighlightSmall", "textMuted")
	self.viewTermsLabel:SetPoint("TOPLEFT", details, "TOPLEFT", 0, -95)
	self.viewTermsLabel:SetText("CUSTOM MATCH TERMS - COMMA SEPARATED")
	self.viewTermsEdit = Theme:CreateEditBox(details, 408, 60, true)
	self.viewTermsEdit:SetPoint("TOPLEFT", details, "TOPLEFT", 0, -108)
	self.viewTermsEdit:SetMaxLetters(3934)
	self.viewTermsHint = Theme:CreateText(details, "GameFontHighlightSmall", "textMuted")
	self.viewTermsHint:SetPoint("TOPLEFT", self.viewTermsEdit, "BOTTOMLEFT", 0, -3)
	self.viewTermsHint:SetWidth(408)
	self.viewTermsHint:SetJustifyH("LEFT")
	self.viewTermsHint:SetText("Matches text or channel names; checked feeds are added separately.")

	-- The built-in classifier is not another editable term list. Keep its public
	-- catalog visible in a bounded read-only surface directly beneath the custom
	-- terms, with enough bottom gutter to protect the editor action row.
	local semanticCatalog = createQuietShellPanel(details, "surfaceRaised")
	semanticCatalog:SetPoint("TOPLEFT", details, "TOPLEFT", 0, -190)
	semanticCatalog:SetSize(408, 80)
	self.messageViewsSemanticCatalogPanel = semanticCatalog
	local semanticTitle = Theme:CreateText(semanticCatalog, "GameFontNormalSmall", "gold")
	semanticTitle:SetPoint("TOPLEFT", semanticCatalog, "TOPLEFT", 7, -5)
	semanticTitle:SetWidth(296)
	semanticTitle:SetJustifyH("LEFT")
	semanticTitle:SetText("BUILT-IN SEMANTIC ROUTING - READ ONLY")
	self.messageViewsSemanticCatalogTitle = semanticTitle
	local semanticOpen = Theme:CreateButton(semanticCatalog, "FULL ANALYZER", 92, 18, false)
	semanticOpen:SetPoint("TOPRIGHT", semanticCatalog, "TOPRIGHT", -6, -3)
	setControlTooltip(semanticOpen, "Open Semantic Routes", "See every route switch and analyze a sample message with full scoring evidence.")
	semanticOpen:SetScript("OnClick", function() Config:ShowPage("semantic") end)
	self.messageViewsSemanticCatalogOpen = semanticOpen
	self.messageViewsSemanticCatalogRows = {}
	for index = 1, 3 do
		local row = CreateFrame("Button", nil, semanticCatalog)
		row:SetPoint("TOPLEFT", semanticCatalog, "TOPLEFT", 7, -21 - ((index - 1) * 18))
		row:SetSize(394, 17)
		row:EnableMouse(true)
		row:SetScript("OnEnter", function(self)
			if not GameTooltip then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.semanticTooltipTitle or "Semantic route evidence", 1, 0.82, 0.3, true)
			if self.semanticTooltipBody and self.semanticTooltipBody ~= "" then
				GameTooltip:AddLine(self.semanticTooltipBody, 0.72, 0.76, 0.84, true)
			end
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function(self)
			if GameTooltip and (not GameTooltip.GetOwner or GameTooltip:GetOwner() == self) then GameTooltip:Hide() end
		end)
		row.title = Theme:CreateText(row, "GameFontNormalSmall", "text")
		row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		row.title:SetWidth(160)
		row.title:SetJustifyH("LEFT")
		if row.title.SetWordWrap then row.title:SetWordWrap(false) end
		row.evidence = Theme:CreateText(row, "GameFontHighlightSmall", "textMuted")
		row.evidence:SetPoint("TOPLEFT", row, "TOPLEFT", 166, 0)
		row.evidence:SetWidth(228)
		row.evidence:SetJustifyH("LEFT")
		if row.evidence.SetWordWrap then row.evidence:SetWordWrap(false) end
		table.insert(self.messageViewsSemanticCatalogRows, row)
	end
	-- A conservative 308px pane is shorter than the live 356px inspector. These
	-- bounds document and test the simultaneous visible rectangles at minimum
	-- size: 6px after the hint and 14px before the 24px bottom action row.
	details.semanticCatalogLayoutBounds = {
		paneWidth = 408, paneHeight = 308,
		termsTop = 108, termsBottom = 168, hintBottom = 182,
		catalogTop = 190, catalogBottom = 270, actionsTop = 284,
	}
	self:RefreshMessageViewSemanticCatalog()
	self.viewDeleteButton = Theme:CreateButton(details, "DELETE", 72, 24, false)
	self.viewDeleteButton:SetPoint("BOTTOMRIGHT", details, "BOTTOMRIGHT", 0, 0)
	self.viewDeleteButton:SetScript("OnClick", function() Config:DeleteCustomView() end)
	self.viewResetButton = Theme:CreateButton(details, "RESET NAME/KEY", 96, 24, false)
	self.viewResetButton:SetPoint("RIGHT", self.viewDeleteButton, "LEFT", -4, 0)
	self.viewResetButton:SetScript("OnClick", function() Config:ResetRailPresentation() end)
	self.viewSaveButton = Theme:CreateButton(details, "SAVE", 66, 24, true)
	self.viewSaveButton:SetPoint("RIGHT", self.viewResetButton, "LEFT", -4, 0)
	self.viewSaveButton:SetScript("OnClick", function() Config:SaveView() end)
	self.railResetNameButton = self.viewResetButton

	-- The compact text pane keeps font choices inside Views & Tabs. Its menu is
	-- a direct SharedMedia dropdown: registered faces appear as rows in their
	-- own type rather than making the player search before seeing any choice.
	local text = CreateFrame("Frame", nil, work)
	text:SetPoint("TOPLEFT", work, "TOPLEFT", 202, -74)
	text:SetPoint("BOTTOMRIGHT", work, "BOTTOMRIGHT", -10, 8)
	self.messageViewsTextPane = text
	local textTitle = Theme:CreateText(text, "GameFontNormalSmall", "gold")
	textTitle:SetPoint("TOPLEFT", text, "TOPLEFT", 0, 0)
	textTitle:SetText("TEXT APPEARANCE")
	self.messageTextScopeTitle = Theme:CreateText(text, "GameFontHighlightSmall", "textMuted")
	self.messageTextScopeTitle:SetPoint("TOPLEFT", textTitle, "BOTTOMLEFT", 0, -2)
	self.messageTextScopeTitle:SetWidth(182)
	self.messageTextScopeTitle:SetJustifyH("LEFT")
	self.messageTextAllTabsButton = Theme:CreateTightButton(text, "ALL TABS", 20, false)
	self.messageTextAllTabsButton:SetPoint("TOPRIGHT", text, "TOPRIGHT", -88, 0)
	self.messageTextAllTabsButton:SetScript("OnClick", function()
		Config:SetSmartChatTextAppearanceScope("global")
	end)
	self.messageTextThisTabButton = Theme:CreateTightButton(text, "THIS TAB", 20, false)
	self.messageTextThisTabButton:SetPoint("LEFT", self.messageTextAllTabsButton, "RIGHT", CONTROL_GAP, 0)
	self.messageTextThisTabButton:SetScript("OnClick", function()
		Config:SetSmartChatTextAppearanceScope(Config.selectedRailId or "global")
	end)
	self.messageTextScopeHint = Theme:CreateText(text, "GameFontHighlightSmall", "textMuted")
	self.messageTextScopeHint:SetPoint("TOPLEFT", text, "TOPLEFT", 0, -31)
	self.messageTextScopeHint:SetWidth(408)
	self.messageTextScopeHint:SetJustifyH("LEFT")

	local fontLabel = Theme:CreateText(text, "GameFontHighlightSmall", "textMuted")
	fontLabel:SetPoint("TOPLEFT", text, "TOPLEFT", 0, -54)
	fontLabel:SetText("FONT")
	self.messageTextFontPreview = Theme:CreateText(text, "GameFontNormalSmall", "text")
	self.messageTextFontPreview:SetPoint("TOPLEFT", text, "TOPLEFT", 42, -53)
	self.messageTextFontPreview:SetWidth(252)
	self.messageTextFontPreview:SetJustifyH("LEFT")
	self.messageTextChooseFontButton = Theme:CreateTightButton(text, "FONTS", 20, false)
	self.messageTextChooseFontButton:SetPoint("TOPRIGHT", text, "TOPRIGHT", 0, -49)
	self.messageTextChooseFontButton:SetScript("OnClick", function()
		if Config.messageTextFontPicker:IsShown() then
			Config:HideSmartChatTextFontPicker()
		else
			Config.messageTextFontOffset = 1
			Config.messageTextFontPicker:Show()
			Config:RefreshSmartChatTextFontPicker()
		end
	end)

	local sizeLabel = Theme:CreateText(text, "GameFontHighlightSmall", "textMuted")
	sizeLabel:SetPoint("TOPLEFT", text, "TOPLEFT", 0, -82)
	sizeLabel:SetText("SIZE")
	self.messageTextSizeLabel = sizeLabel
	self.messageTextSizeEdit = Theme:CreateEditBox(text, 42, 20, false)
	self.messageTextSizeEdit:SetPoint("LEFT", sizeLabel, "RIGHT", 5, 0)
	self.messageTextSizeEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.messageTextSizeEdit:HookScript("OnEditFocusLost", function()
		local options = getSmartChatTextAppearanceOptions()
		local size = tonumber(Config.messageTextSizeEdit:GetText())
		if not size then
			Config:RefreshSmartChatTextAppearanceControls()
			Config:SetViewsStatus("Use 0 to inherit the current chat size, or a whole size from " .. tostring(options.size.minimum) .. " to " .. tostring(options.size.maximum) .. ".", "warning")
			return
		end
		size = math.floor(size + 0.5)
		if size ~= 0 and (size < options.size.minimum or size > options.size.maximum) then
			Config:RefreshSmartChatTextAppearanceControls()
			Config:SetViewsStatus("Use 0 to inherit the current chat size, or a whole size from " .. tostring(options.size.minimum) .. " to " .. tostring(options.size.maximum) .. ".", "warning")
			return
		end
		Config:ApplySmartChatTextAppearance({ size = size }, "Text size applied.")
	end)
	local sizeHint = Theme:CreateText(text, "GameFontHighlightSmall", "textMuted")
	sizeHint:SetPoint("LEFT", self.messageTextSizeEdit, "RIGHT", 5, 0)
	sizeHint:SetWidth(92)
	sizeHint:SetJustifyH("LEFT")
	sizeHint:SetText("0 = CHAT FONT")
	self.messageTextSizeHint = sizeHint

	-- This is row padding on the native ScrollingMessageFrame, not a column
	-- gap. It remains available for both ALL TABS and THIS TAB scopes.
	local spacingLabel = Theme:CreateText(text, "GameFontHighlightSmall", "textMuted")
	spacingLabel:SetPoint("TOPLEFT", text, "TOPLEFT", 204, -82)
	spacingLabel:SetText("LINE GAP")
	self.messageTextSpacingLabel = spacingLabel
	self.messageTextSpacingEdit = Theme:CreateEditBox(text, 34, 20, false)
	self.messageTextSpacingEdit:SetPoint("LEFT", spacingLabel, "RIGHT", 5, 0)
	-- Leave enough room for a pasted decimal so validation can explain that this
	-- is a whole-pixel setting instead of silently truncating the input.
	self.messageTextSpacingEdit:SetMaxLetters(4)
	setControlTooltip(spacingLabel, "Line gap",
		"Use 0 to 8 pixels of padding between message lines. This does not change channel or player-name alignment.")
	setControlTooltip(self.messageTextSpacingEdit, "Line gap",
		"Use 0 to 8 pixels of padding between message lines. 1 is the compact default.")
	self.messageTextSpacingEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.messageTextSpacingEdit:HookScript("OnEditFocusLost", function()
		local options = getSmartChatTextAppearanceOptions()
		local spacing = tonumber(Config.messageTextSpacingEdit:GetText())
		local bounds = options.spacing or { minimum = 0, maximum = 8 }
		if spacing == nil then
			Config:RefreshSmartChatTextAppearanceControls()
			Config:SetViewsStatus("Line gap must be a whole number from " .. tostring(bounds.minimum) .. " to " .. tostring(bounds.maximum) .. " pixels.", "warning")
			return
		end
		if spacing ~= math.floor(spacing) or spacing < bounds.minimum or spacing > bounds.maximum then
			Config:RefreshSmartChatTextAppearanceControls()
			Config:SetViewsStatus("Line gap must be a whole number from " .. tostring(bounds.minimum) .. " to " .. tostring(bounds.maximum) .. " pixels.", "warning")
			return
		end
		Config:ApplySmartChatTextAppearance({ spacing = spacing }, "Line gap applied.")
	end)
	local spacingHint = Theme:CreateText(text, "GameFontHighlightSmall", "textMuted")
	spacingHint:SetPoint("LEFT", self.messageTextSpacingEdit, "RIGHT", 5, 0)
	spacingHint:SetText("0-8 PX")
	self.messageTextSpacingHint = spacingHint

	-- ScrollingMessageFrame only supports pixels between every rendered line.
	-- ENTRY GAP is deliberately separate: it inserts blank rows only between
	-- logical messages, so a wrapped message remains visually cohesive.
	local entryGapLabel = Theme:CreateText(text, "GameFontHighlightSmall", "textMuted")
	-- This shares the reset row. Anchor to the live-width reset button so wider
	-- client fonts retain an explicit gutter instead of pushing the two controls
	-- into one another.
	entryGapLabel:SetText("ENTRY GAP")
	self.messageTextEntryGapLabel = entryGapLabel
	self.messageTextEntryGapEdit = Theme:CreateEditBox(text, 34, 20, false)
	self.messageTextEntryGapEdit:SetPoint("LEFT", entryGapLabel, "RIGHT", 5, 0)
	self.messageTextEntryGapEdit:SetMaxLetters(2)
	setControlTooltip(entryGapLabel, "Entry gap",
		"Use 0 to 2 blank rows between logical messages. This is independent of LINE GAP, which spaces every rendered line.")
	setControlTooltip(self.messageTextEntryGapEdit, "Entry gap",
		"Use 0 to 2 blank rows between logical messages. 0 keeps the compact layout.")
	self.messageTextEntryGapEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.messageTextEntryGapEdit:HookScript("OnEditFocusLost", function()
		local options = getSmartChatTextAppearanceOptions()
		local rows = tonumber(Config.messageTextEntryGapEdit:GetText())
		local bounds = options.entryGapRows or { minimum = 0, maximum = 2 }
		if rows == nil or rows ~= math.floor(rows)
			or rows < bounds.minimum or rows > bounds.maximum then
			Config:RefreshSmartChatTextAppearanceControls()
			Config:SetViewsStatus("Entry gap must be a whole number from " .. tostring(bounds.minimum)
				.. " to " .. tostring(bounds.maximum) .. " rows.", "warning")
			return
		end
		Config:ApplySmartChatTextAppearance({ entryGapRows = rows }, "Entry gap applied.")
	end)
	local entryGapHint = Theme:CreateText(text, "GameFontHighlightSmall", "textMuted")
	entryGapHint:SetPoint("LEFT", self.messageTextEntryGapEdit, "RIGHT", 5, 0)
	entryGapHint:SetText("0-2")
	self.messageTextEntryGapHint = entryGapHint

	local outlineLabel = Theme:CreateText(text, "GameFontHighlightSmall", "textMuted")
	outlineLabel:SetPoint("TOPLEFT", text, "TOPLEFT", 0, -110)
	outlineLabel:SetText("OUTLINE")
	self.messageTextOutlineLabel = outlineLabel
	self.messageTextOutlineButtons = {}
	local previousOutlineButton
	for _, option in ipairs({
		{ id = "INHERIT", label = "INHERIT" },
		{ id = "NONE", label = "NONE" },
		{ id = "OUTLINE", label = "THIN" },
		{ id = "THICKOUTLINE", label = "THICK" },
	}) do
		local button = Theme:CreateTightButton(text, option.label, 20, false)
		button.outlineId = option.id
		if previousOutlineButton then
			button:SetPoint("LEFT", previousOutlineButton, "RIGHT", 4, 0)
		else
			button:SetPoint("LEFT", outlineLabel, "RIGHT", 6, 0)
		end
		button:SetScript("OnClick", function(self)
			Config:ApplySmartChatTextAppearance({ outline = self.outlineId }, "Text outline applied.")
		end)
		table.insert(self.messageTextOutlineButtons, button)
		previousOutlineButton = button
	end
	self.messageTextResetButton = Theme:CreateTightButton(text, "RESET THIS TAB", 20, false)
	self.messageTextResetButton:SetPoint("TOPLEFT", text, "TOPLEFT", 0, -138)
	self.messageTextResetButton:SetScript("OnClick", function()
		Config:ResetSmartChatTextAppearance()
	end)
	setControlTooltip(self.messageTextResetButton, "Reset this tab",
		"Removes this tab's text overrides and returns it to the ALL TABS appearance.")
	entryGapLabel:SetPoint("LEFT", self.messageTextResetButton, "RIGHT", 14, 0)
	self.messageTextAlignmentTitle = Theme:CreateText(text, "GameFontNormalSmall", "gold")
	self.messageTextAlignmentTitle:SetPoint("TOPLEFT", text, "TOPLEFT", 0, -166)
	self.messageTextAlignmentTitle:SetText("ALIGNMENT - ALL TABS")
	setControlTooltip(self.messageTextAlignmentTitle, "All-tabs alignment",
		"Channel and player-name lanes are shared by every tab. A tab-specific font override does not create different alignment rules.")

	self.messageTextColumnAlignmentToggle = Theme:CreateCompactToggle(text, "ALIGN CHANNELS", 184)
	self.messageTextColumnAlignmentToggle:SetPoint("TOPLEFT", text, "TOPLEFT", 0, -188)
	self.messageTextColumnAlignmentToggle.OnValueChanged = function(_, enabled)
		local viewId = Config.selectedRailId or "general"
		if type(addon.SetViewSourceColumnAlignment) ~= "function" then
			Config:RefreshSmartChatTextAppearanceControls()
			Config:SetViewsStatus("Column alignment is unavailable in this build.", "warning")
			return
		end
		local ok, accepted, selectedFixedFont = pcall(addon.SetViewSourceColumnAlignment, addon, viewId, enabled == true)
		if not ok or accepted ~= true then
			Config:RefreshSmartChatTextAppearanceControls()
			Config:SetViewsStatus("Column alignment was not changed.", "warning")
			return
		end
		Config:RefreshSmartChatTextAppearanceControls()
		if enabled and selectedFixedFont then
			Config:SetViewsStatus("Columns aligned with Source Code Pro. Change it here any time.", "success")
		else
			Config:SetViewsStatus(enabled and "Columns align in every message tab." or "Columns now use their natural source widths.", "success")
		end
	end
	setControlTooltip(self.messageTextColumnAlignmentToggle, "Align channels",
		"Gives visible channel/source labels one shared lane. A fixed-width SharedMedia font is selected automatically if alignment needs one.")

	self.messageTextColumnAlignmentSpacingLabel = Theme:CreateText(text, "GameFontHighlightSmall", "textMuted")
	self.messageTextColumnAlignmentSpacingLabel:SetPoint("TOPLEFT", text, "TOPLEFT", 204, -187)
	self.messageTextColumnAlignmentSpacingLabel:SetText("CHANNEL GAP")
	self.messageTextColumnAlignmentSpacingEdit = Theme:CreateEditBox(text, 34, 20, false)
	self.messageTextColumnAlignmentSpacingEdit:SetPoint("LEFT", self.messageTextColumnAlignmentSpacingLabel, "RIGHT", 5, 0)
	self.messageTextColumnAlignmentSpacingEdit:SetMaxLetters(2)
	setControlTooltip(self.messageTextColumnAlignmentSpacingLabel, "Channel gap",
		"Use -8 to 8. Positive values add space; negative values safely shorten/truncate the channel lane before its divider.")
	setControlTooltip(self.messageTextColumnAlignmentSpacingEdit, "Channel gap",
		"Use -8 to 8. Negative values compact the lane without allowing text to overlap.")
	self.messageTextColumnAlignmentSpacingEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.messageTextColumnAlignmentSpacingEdit:HookScript("OnEditFocusLost", function()
		if type(addon.SetColumnAlignmentSpacing) ~= "function" then return end
		local ok, spacing = addon:SetColumnAlignmentSpacing(Config.messageTextColumnAlignmentSpacingEdit:GetText())
		if not ok then
			Config:RefreshSmartChatTextAppearanceControls()
			Config:SetViewsStatus("Channel gap must be a whole number from -8 to 8.", "warning")
			return
		end
		Config:RefreshSmartChatTextAppearanceControls()
		Config:SetViewsStatus(tonumber(spacing) and tonumber(spacing) < 0
			and ("Channel lane compacted by " .. tostring(math.abs(tonumber(spacing))) .. " cells; long labels truncate safely.")
			or ("Channel gap set to " .. tostring(spacing) .. " cells."), "success")
	end)
	self.messageTextColumnAlignmentSpacingHint = Theme:CreateText(text, "GameFontHighlightSmall", "textMuted")
	self.messageTextColumnAlignmentSpacingHint:SetPoint("LEFT", self.messageTextColumnAlignmentSpacingEdit, "RIGHT", 5, 0)
	self.messageTextColumnAlignmentSpacingHint:SetText("-8 TO 8")

	self.messageTextSenderColumnAlignmentToggle = Theme:CreateCompactToggle(text, "ALIGN NAMES", 184)
	self.messageTextSenderColumnAlignmentToggle:SetPoint("TOPLEFT", text, "TOPLEFT", 0, -216)
	self.messageTextSenderColumnAlignmentToggle.OnValueChanged = function(_, enabled)
		local viewId = Config.selectedRailId or "general"
		if type(addon.SetViewSenderColumnAlignment) ~= "function" then
			Config:RefreshSmartChatTextAppearanceControls()
			Config:SetViewsStatus("Player-name alignment is unavailable in this build.", "warning")
			return
		end
		local ok, accepted, selectedFixedFont = pcall(addon.SetViewSenderColumnAlignment, addon, viewId, enabled == true)
		if not ok or accepted ~= true then
			Config:RefreshSmartChatTextAppearanceControls()
			Config:SetViewsStatus("Player-name alignment was not changed.", "warning")
			return
		end
		Config:RefreshSmartChatTextAppearanceControls()
		if enabled and selectedFixedFont then
			Config:SetViewsStatus("Player names aligned with Source Code Pro. Change the font here any time.", "success")
		else
			Config:SetViewsStatus(enabled and "Player names align in every message tab."
				or "Player names now use their natural widths.", "success")
		end
	end
	setControlTooltip(self.messageTextSenderColumnAlignmentToggle, "Align player names",
		"Gives [PLAYER] labels one shared lane before message text. Long names use the maximum length below, without changing stored chat.")

	self.messageTextSenderColumnAlignmentSpacingLabel = Theme:CreateText(text, "GameFontHighlightSmall", "textMuted")
	self.messageTextSenderColumnAlignmentSpacingLabel:SetPoint("TOPLEFT", text, "TOPLEFT", 204, -215)
	self.messageTextSenderColumnAlignmentSpacingLabel:SetText("[NAME] GAP")
	self.messageTextSenderColumnAlignmentSpacingEdit = Theme:CreateEditBox(text, 34, 20, false)
	self.messageTextSenderColumnAlignmentSpacingEdit:SetPoint("LEFT", self.messageTextSenderColumnAlignmentSpacingLabel, "RIGHT", 5, 0)
	self.messageTextSenderColumnAlignmentSpacingEdit:SetMaxLetters(2)
	setControlTooltip(self.messageTextSenderColumnAlignmentSpacingLabel, "Name gap",
		"Use -8 to 8. Negative values compact/truncate the [PLAYER] lane; text never overlaps the message body.")
	setControlTooltip(self.messageTextSenderColumnAlignmentSpacingEdit, "Name gap",
		"Use -8 to 8. Positive values add space after [PLAYER]; negative values shorten the aligned lane.")
	self.messageTextSenderColumnAlignmentSpacingEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.messageTextSenderColumnAlignmentSpacingEdit:HookScript("OnEditFocusLost", function()
		if type(addon.SetSenderColumnAlignmentSpacing) ~= "function" then return end
		local ok, spacing = addon:SetSenderColumnAlignmentSpacing(Config.messageTextSenderColumnAlignmentSpacingEdit:GetText())
		if not ok then
			Config:RefreshSmartChatTextAppearanceControls()
			Config:SetViewsStatus("[NAME] gap must be a whole number from -8 to 8.", "warning")
			return
		end
		Config:RefreshSmartChatTextAppearanceControls()
		Config:SetViewsStatus(tonumber(spacing) and tonumber(spacing) < 0
			and ("[PLAYER] lane compacted by " .. tostring(math.abs(tonumber(spacing))) .. " cells.")
			or ("[PLAYER] gap set to " .. tostring(spacing) .. " cells."), "success")
	end)
	self.messageTextSenderColumnAlignmentSpacingHint = Theme:CreateText(text, "GameFontHighlightSmall", "textMuted")
	self.messageTextSenderColumnAlignmentSpacingHint:SetPoint("LEFT", self.messageTextSenderColumnAlignmentSpacingEdit, "RIGHT", 5, 0)
	self.messageTextSenderColumnAlignmentSpacingHint:SetText("-8 TO 8")

	self.messageTextSenderColumnMaxLengthLabel = Theme:CreateText(text, "GameFontHighlightSmall", "textMuted")
	self.messageTextSenderColumnMaxLengthLabel:SetPoint("TOPLEFT", text, "TOPLEFT", 0, -243)
	self.messageTextSenderColumnMaxLengthLabel:SetText("MAX NAME")
	self.messageTextSenderColumnMaxLengthEdit = Theme:CreateEditBox(text, 34, 20, false)
	self.messageTextSenderColumnMaxLengthEdit:SetPoint("LEFT", self.messageTextSenderColumnMaxLengthLabel, "RIGHT", 5, 0)
	self.messageTextSenderColumnMaxLengthEdit:SetMaxLetters(2)
	self.messageTextSenderColumnMaxLengthEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.messageTextSenderColumnMaxLengthEdit:HookScript("OnEditFocusLost", function()
		if type(addon.SetSenderColumnMaxLength) ~= "function" then return end
		local ok, length = addon:SetSenderColumnMaxLength(Config.messageTextSenderColumnMaxLengthEdit:GetText())
		if not ok then
			Config:RefreshSmartChatTextAppearanceControls()
			Config:SetViewsStatus("Maximum player-name length must be 1 to 32 characters.", "warning")
			return
		end
		Config:RefreshSmartChatTextAppearanceControls()
		Config:SetViewsStatus("Aligned player names now use at most " .. tostring(length) .. " characters.", "success")
	end)
	self.messageTextSenderColumnMaxLengthHint = Theme:CreateText(text, "GameFontHighlightSmall", "textMuted")
	self.messageTextSenderColumnMaxLengthHint:SetPoint("LEFT", self.messageTextSenderColumnMaxLengthEdit, "RIGHT", 5, 0)
	self.messageTextSenderColumnMaxLengthHint:SetText("1-32")
	setControlTooltip(self.messageTextSenderColumnMaxLengthEdit, "Maximum player-name length",
		"Long names abbreviate inside their closing bracket so the message column stays aligned.")

	self.messageTextAlignmentVisibleOnlyToggle = Theme:CreateCompactToggle(text, "VISIBLE ONLY", 196)
	self.messageTextAlignmentVisibleOnlyToggle:SetPoint("TOPLEFT", text, "TOPLEFT", 204, -244)
	self.messageTextAlignmentVisibleOnlyToggle.OnValueChanged = function(_, enabled)
		if type(addon.SetAlignmentVisibleOnly) ~= "function" then return end
		addon:SetAlignmentVisibleOnly(enabled == true)
		Config:RefreshSmartChatTextAppearanceControls()
		Config:SetViewsStatus(enabled and "Only currently visible messages now decide column widths."
			or "The recent message buffer now decides column widths.", "success")
	end
	setControlTooltip(self.messageTextAlignmentVisibleOnlyToggle, "Align what you can see",
		"Recomputes channel and player widths from logical messages on screen as you scroll. Hidden history cannot stretch the current view.")

	local fontPicker = Theme:CreatePanel(text, "surface", "border")
	fontPicker:SetSize(322, 194)
	fontPicker:SetPoint("TOPRIGHT", self.messageTextChooseFontButton, "BOTTOMRIGHT", 0, -2)
	if fontPicker.SetFrameStrata then fontPicker:SetFrameStrata("DIALOG") end
	if fontPicker.SetFrameLevel then
		local textLevel = text.GetFrameLevel and text:GetFrameLevel() or 1
		fontPicker:SetFrameLevel(textLevel + 20)
	end
	fontPicker:Hide()
	if fontPicker.EnableMouseWheel then fontPicker:EnableMouseWheel(true) end
	fontPicker:SetScript("OnMouseWheel", function(_, delta)
		Config:ScrollSmartChatTextFontPicker(delta)
	end)
	fontPicker:SetScript("OnShow", function(self)
		-- The opening click originates on the FONTS control outside this popup.
		-- Wait for release before treating a later click as an outside-dismiss.
		self.awaitFontPickerMouseRelease = true
		self.fontPickerMouseDown = false
	end)
	fontPicker:SetScript("OnHide", function(self)
		self.awaitFontPickerMouseRelease = nil
		self.fontPickerMouseDown = nil
	end)
	fontPicker:SetScript("OnUpdate", function(self)
		local isMouseButtonDown = (_G and _G.IsMouseButtonDown) or IsMouseButtonDown
		if type(isMouseButtonDown) ~= "function" then return end
		local mouseDown = isMouseButtonDown("LeftButton") or isMouseButtonDown("RightButton")
		if not mouseDown then
			self.awaitFontPickerMouseRelease = nil
			self.fontPickerMouseDown = nil
			return
		end
		if self.awaitFontPickerMouseRelease then return end
		if not self.fontPickerMouseDown and not isFontPickerMouseOver(self) then
			self.fontPickerMouseDown = true
			Config:HideSmartChatTextFontPicker()
			return
		end
		self.fontPickerMouseDown = true
	end)
	self.messageTextFontPicker = fontPicker
	-- A quiet lowercase text x closes the popup without adding another boxed
	-- control to the font-selection surface.
	local closeButton = CreateFrame("Button", nil, fontPicker)
	closeButton:SetSize(16, 20)
	closeButton:SetPoint("TOPRIGHT", fontPicker, "TOPRIGHT", -5, -4)
	closeButton.text = Theme:CreateText(closeButton, "GameFontNormalSmall", "textMuted")
	closeButton.text:SetAllPoints(closeButton)
	closeButton.text:SetJustifyH("CENTER")
	closeButton.text:SetText("x")
	closeButton:SetScript("OnEnter", function(self)
		local r, g, b, a = Theme:GetColor("goldBright")
		self.text:SetTextColor(r, g, b, a)
	end)
	closeButton:SetScript("OnLeave", function(self)
		local r, g, b, a = Theme:GetColor("textMuted")
		self.text:SetTextColor(r, g, b, a)
	end)
	self.messageTextFontCloseButton = closeButton
	closeButton:SetScript("OnClick", function()
		Config:HideSmartChatTextFontPicker()
	end)
	self.messageTextFontSearch = Theme:CreateEditBox(fontPicker, 1, 20, false)
	self.messageTextFontSearch:ClearAllPoints()
	self.messageTextFontSearch:SetPoint("TOPLEFT", fontPicker, "TOPLEFT", 7, -5)
	self.messageTextFontSearch:SetPoint("TOPRIGHT", closeButton, "TOPLEFT", -4, 0)
	self.messageTextFontSearch:SetMaxLetters(48)
	self.messageTextFontSearchHint = Theme:CreateText(self.messageTextFontSearch, "GameFontHighlightSmall", "textMuted")
	self.messageTextFontSearchHint:SetPoint("LEFT", self.messageTextFontSearch, "LEFT", 5, 0)
	self.messageTextFontSearchHint:SetText("SEARCH FONTS...")
	self.messageTextFontSearch:HookScript("OnTextChanged", function()
		Config.messageTextFontOffset = 1
		Config:RefreshSmartChatTextFontPicker()
	end)
	self.messageTextFontRows = {}
	for index = 1, 7 do
		local row = Theme:CreateButton(fontPicker, "", 308, 20, false)
		row:SetPoint("TOPLEFT", fontPicker, "TOPLEFT", 7, -29 - ((index - 1) * 21))
		row.text:ClearAllPoints()
		row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
		row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		row.text:SetJustifyH("LEFT")
		row:SetScript("OnClick", function(self)
			if not self.option then return end
			Config:ApplySmartChatTextAppearance({ font = self.option.inherit and false or self.option.id }, "Text font applied.")
			Config:HideSmartChatTextFontPicker()
		end)
		if row.EnableMouseWheel then row:EnableMouseWheel(true) end
		row:SetScript("OnMouseWheel", function(_, delta)
			Config:ScrollSmartChatTextFontPicker(delta)
		end)
		table.insert(self.messageTextFontRows, row)
	end
	self.messageTextFontCount = Theme:CreateText(fontPicker, "GameFontHighlightSmall", "textMuted")
	self.messageTextFontCount:SetPoint("BOTTOMLEFT", fontPicker, "BOTTOMLEFT", 7, 7)
	self.messageTextFontCount:SetWidth(128)
	self.messageTextFontScrollHint = Theme:CreateText(fontPicker, "GameFontHighlightSmall", "textMuted")
	self.messageTextFontScrollHint:SetPoint("LEFT", self.messageTextFontCount, "RIGHT", 4, 0)
	self.messageTextFontScrollHint:SetWidth(176)
	self.messageTextFontScrollHint:SetJustifyH("RIGHT")
	self.messageTextFontScrollHint:SetText("MOUSE WHEEL: SCROLL")

	local sources = CreateFrame("Frame", nil, work)
	sources:SetPoint("TOPLEFT", work, "TOPLEFT", 202, -74)
	sources:SetPoint("BOTTOMRIGHT", work, "BOTTOMRIGHT", -10, 8)
	self.messageViewsSourcesPane = sources
	local sourceTitle = Theme:CreateText(sources, "GameFontNormalSmall", "gold")
	sourceTitle:SetPoint("TOPLEFT", sources, "TOPLEFT", 0, 0)
	sourceTitle:SetText("FULL SOURCE FEEDS KEPT HERE")
	self.railSourceHint = Theme:CreateText(sources, "GameFontHighlightSmall", "textMuted")
	self.railSourceHint:SetPoint("TOPLEFT", sourceTitle, "BOTTOMLEFT", 0, -3)
	self.railSourceHint:SetWidth(408)
	self.railSourceHint:SetJustifyH("LEFT")
	self.railSourceRows = {}
	for index = 1, 10 do
		-- A source and its routing mode form one sentence. Keep each pair on one
		-- full-width row instead of splitting the inspector into two cramped,
		-- visually unrelated columns.
		local toggle = Theme:CreateCompactToggle(sources, "Source", 330)
		toggle.normalWidth = 402
		toggle.syncWidth = 330
		toggle:SetPoint("TOPLEFT", sources, "TOPLEFT", 0, -39 - ((index - 1) * 24))
		toggle.OnValueChanged = function(self, value)
			Config:SetRailSourceEnabled(self.sourceId, value, self.sourceLabel)
		end
		local syncButton = Theme:CreateButton(sources, "AUTO", 68, 22, false)
		syncButton:SetPoint("LEFT", toggle, "RIGHT", 4, 0)
		syncButton:Hide()
		setControlTooltip(syncButton, "Channel handling", "AUTO follows Chatty's recommendation. SYNC isolates noisy add-on traffic. NORMAL keeps ordinary chat handling.")
		syncButton:SetScript("OnClick", function(self)
			if self.sourceId then Config:SetSourceSyncMode(self.sourceId, nextSourceSyncMode(self.syncMode)) end
		end)
		toggle.syncButton = syncButton
		table.insert(self.railSourceRows, toggle)
	end
	self.railSourceCount = Theme:CreateText(sources, "GameFontHighlightSmall", "textMuted")
	self.railSourceCount:SetPoint("BOTTOMLEFT", sources, "BOTTOMLEFT", 0, 7)
	self.railSourceCount:SetWidth(116)
	self.railSourcePrevious = Theme:CreateButton(sources, "<", 24, 20, false)
	self.railSourcePrevious:SetPoint("LEFT", self.railSourceCount, "RIGHT", 4, 0)
	self.railSourcePrevious:SetScript("OnClick", function()
		Config.railSourcePage = math.max(1, (Config.railSourcePage or 1) - 1)
		Config:RefreshRailSources()
	end)
	self.railSourceNext = Theme:CreateButton(sources, ">", 24, 20, false)
	self.railSourceNext:SetPoint("LEFT", self.railSourcePrevious, "RIGHT", CONTROL_GAP, 0)
	self.railSourceNext:SetScript("OnClick", function()
		Config.railSourcePage = (Config.railSourcePage or 1) + 1
		Config:RefreshRailSources()
	end)
	self.messageViewsResetSourcesButton = Theme:CreateButton(sources, "RESET EXPECTED", 108, 24, false)
	self.messageViewsResetSourcesButton:SetPoint("BOTTOMRIGHT", sources, "BOTTOMRIGHT", 0, 0)
	setControlTooltip(self.messageViewsResetSourcesButton, "Restore expected feeds", "Returns this tab to its clean factual sources. Routing and custom match rules remain unchanged.")
	self.messageViewsResetSourcesButton:SetScript("OnClick", function() Config:ResetRailSources() end)

	self.viewsStatus = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	self.viewsStatus:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 202, 43)
	self.viewsStatus:SetWidth(408)
	self.viewsStatus:SetJustifyH("LEFT")
	self.railsStatus = self.viewsStatus

	self.viewNameEdit:SetScript("OnTabPressed", function() Config.viewKeyEdit:SetFocus() end)
	self.viewKeyEdit:SetScript("OnTabPressed", function() Config.viewDescriptionEdit:SetFocus() end)
	self.viewDescriptionEdit:SetScript("OnTabPressed", function()
		if Config.selectedViewId and not Config.selectedCustomViewId then
			Config.viewDescriptionEdit:ClearFocus()
		else
			Config.viewTermsEdit:SetFocus()
		end
	end)

	self.railPage = 1
	self.railSourcePage = 1
	self.messageViewsSection = "details"
	self:RefreshMessageViewsPage()
	return page
end

function Config:BuildRailsPage()
	local page = self:BuildViewsPage()
	-- Keep the old page-table lookup valid for integrations that called the
	-- former builder directly.  It is an alias to the same frame, never a
	-- second UI surface.
	self.pages.rails = page
	return page
end

local function applySpamRuntime()
	local controller = addon.SpamControl
	if not controller then
		return
	end
	if controller.RefreshSettings then
		controller:RefreshSettings()
	else
		local settings = addon:GetSmartSettings()
		controller:SetEnabled(settings.spam and settings.spam.enabled)
	end
end

local function createSpamNumberField(parent, label, x, y, target, key, minimum, maximum, fallback)
	local caption = Theme:CreateText(parent, "GameFontHighlightSmall", "textMuted")
	caption:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	caption:SetText(label)
	local editBox = Theme:CreateEditBox(parent, 58, 24, false)
	editBox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(y + 14))
	editBox:SetText(tostring(clampNumber(target[key], minimum, maximum, fallback)))
	local function commit(self)
		local value = clampNumber(self:GetText(), minimum, maximum, fallback)
		target[key] = value
		self:SetText(tostring(value))
		applySpamRuntime()
		Config:RefreshSpamStatus()
	end
	editBox:HookScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	editBox:HookScript("OnEditFocusLost", commit)
	return editBox
end

local function createSpamMinutesField(parent, label, x, y, target, key, fallbackMinutes)
	local caption = Theme:CreateText(parent, "GameFontHighlightSmall", "textMuted")
	caption:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	caption:SetText(label)
	local editBox = Theme:CreateEditBox(parent, 58, 24, false)
	editBox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(y + 14))
	local seconds = clampNumber(target[key], 0, 2592000, fallbackMinutes * 60)
	editBox:SetText(tostring(math.floor((seconds / 60) + 0.5)))
	local function commit(self)
		local minutes = clampNumber(self:GetText(), 0, 43200, fallbackMinutes)
		target[key] = minutes * 60
		self:SetText(tostring(minutes))
		applySpamRuntime()
		Config:RefreshSpamStatus()
	end
	editBox:HookScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	editBox:HookScript("OnEditFocusLost", commit)
	return editBox
end

local function createSpamToggle(parent, label, x, y, target, key)
	local toggle = Theme:CreateCompactToggle(parent, label, 194)
	toggle:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	toggle:SetValue(target[key] ~= false, true)
	toggle.OnValueChanged = function(_, value)
		target[key] = value and true or false
		applySpamRuntime()
		Config:RefreshSpamStatus()
	end
	return toggle
end

local SPAM_BAN_PAGE_SIZE = 7

local function getSpamBans()
	local controller = addon.SpamControl
	if not controller or not controller.GetBans then
		return {}
	end
	local ok, result = pcall(controller.GetBans, controller)
	if not ok or type(result) ~= "table" then
		return {}
	end
	local bans = {}
	for index = 1, #result do
		local entry = result[index]
		if type(entry) == "table" then
			table.insert(bans, entry)
		elseif entry ~= nil then
			table.insert(bans, { id = entry, name = tostring(entry), fullName = tostring(entry) })
		end
	end
	-- Compatibility fallback for early profiles or alternate providers that
	-- expose bans as a keyed table instead of the controller's ordered array.
	if #bans == 0 then
		for key, entry in pairs(result) do
			if type(key) ~= "number" then
				if type(entry) == "table" then
					if not entry.id then entry.id = key end
					if not entry.name then entry.name = tostring(key) end
					table.insert(bans, entry)
				elseif entry then
					table.insert(bans, { id = key, name = tostring(key), fullName = tostring(key) })
				end
			end
		end
		table.sort(bans, function(left, right)
			local leftTime = tonumber(left.bannedAt) or 0
			local rightTime = tonumber(right.bannedAt) or 0
			if leftTime ~= rightTime then return leftTime > rightTime end
			return string.lower(tostring(left.fullName or left.name or "")) < string.lower(tostring(right.fullName or right.name or ""))
		end)
	end
	return bans
end

local function getSpamBanReport(identity, fallback)
	local controller = addon.SpamControl
	if controller and type(controller.GetBanReport) == "function" and identity then
		local ok, report = pcall(controller.GetBanReport, controller, identity)
		if ok and type(report) == "table" then
			return report
		end
	end
	return type(fallback) == "table" and fallback or nil
end

-- Ban records deliberately keep the explanation compact and local: Chatty
-- persists the kind of firewall incident and the eligible chat context, never
-- the player's raw message text. Older bans did not have this metadata, so
-- their row remains truthful instead of inventing a reason after the fact.
local function getSpamBanReason(entry, detailed)
	entry = type(entry) == "table" and entry or {}
	local source = entry.source == "automatic" and "automatic" or "manual"
	if source == "manual" then
		return detailed and "Manual local ban: added directly from Chatty's Ban List."
			or "MANUAL / ADDED BY YOU"
	end

	local reason = entry.reason or entry.lastReason
	local trigger = reason == "duplicate" and "REPEATED MESSAGE"
		or reason == "burst" and "RAPID MESSAGE FLOOD"
		or "FIREWALL ESCALATION"
	local strikes = math.max(0, math.floor(tonumber(entry.strikes) or 0))
	local muteText = strikes > 0 and (tostring(strikes) .. " MUTES") or "MUTE COUNT UNAVAILABLE"
	if not detailed then
		return "AUTO / " .. muteText .. " / " .. trigger
	end
	local context = ""
	local channel = trim(tostring(entry.lastChannel or ""))
	if channel ~= "" then
		context = " in " .. channel
	elseif entry.lastScope == "channel" then
		context = " in public chat"
	elseif entry.lastScope == "local" then
		context = " in local chat"
	elseif entry.lastScope == "group" then
		context = " in group chat"
	elseif entry.lastScope == "guild" then
		context = " in guild chat"
	elseif entry.lastScope == "whisper" then
		context = " in whispers"
	elseif entry.lastScope == "bnet" then
		context = " in Battle.net chat"
	end
	return "Automatic local ban: " .. muteText .. " reached your Mutes to Ban threshold. Latest trigger: "
		.. string.lower(trigger) .. context .. "."
end

local function formatSpamBanTimestamp(value)
	local timestamp = math.floor(tonumber(value) or 0)
	if timestamp <= 0 then
		return "TIME NOT RECORDED"
	end
	if date then
		local ok, result = pcall(date, "%Y-%m-%d %H:%M", timestamp)
		if ok and type(result) == "string" and result ~= "" then
			return result
		end
	end
	return tostring(timestamp)
end

local function getSpamCounter(methodName, key, fallback)
	local controller = addon.SpamControl
	local method = controller and controller[methodName]
	if not method then return fallback or 0 end
	local ok, result = pcall(method, controller)
	if ok and type(result) == "table" then
		return tonumber(result[key]) or fallback or 0
	end
	return fallback or 0
end

-- The filter lives ahead of both the native chat frames and the organized
-- dock.  A populated Ban List is only meaningful if that filter actually
-- attached, so expose the real runtime state instead of making users infer it
-- from an empty counter or a failed manual-ban button.
local function getSpamFirewallHealth()
	local controller = addon.SpamControl
	if type(controller) ~= "table" then
		-- Ascension caches a TOC's file list for the client process.  If the
		-- module was absent from that cache, /reload cannot load it; a client
		-- restart is the actionable recovery.
		return nil, nil, "FIREWALL MODULE MISSING / RESTART ASCENSION", "danger"
	end
	if type(controller.GetStats) ~= "function" then
		return controller, nil, "FIREWALL API OUT OF DATE / RELOAD UI", "danger"
	end

	local ok, stats = pcall(controller.GetStats, controller)
	if not ok or type(stats) ~= "table" then
		return controller, nil, "FIREWALL ERROR / RELOAD UI", "danger"
	end

	local settings
	if addon.GetSmartSettings then
		local settingsOk, result = pcall(addon.GetSmartSettings, addon)
		if settingsOk then settings = result end
	end
	local spam = type(settings) == "table" and settings.spam or nil
	if type(spam) == "table" and spam.enabled == false then
		return controller, stats, "FIREWALL DISABLED", "textMuted"
	end

	local registered = math.max(0, tonumber(stats.registeredEvents) or 0)
	if stats.enabled == true and registered > 0 then
		return controller, stats, "FIREWALL ACTIVE / " .. registered .. " CHAT EVENTS", "success"
	end
	if stats.enabled == true and stats.registeredEvents == nil then
		-- Older controller builds may not publish an event count.  Do not call
		-- that a failure solely because the optional diagnostic is absent.
		return controller, stats, "FIREWALL ACTIVE", "success"
	end
	return controller, stats, "FILTER NOT ATTACHED / RESTART ASCENSION", "danger"
end

local function getSpamBanServiceProblem()
	local controller, _, healthText = getSpamFirewallHealth()
	if not controller then
		return healthText
	end
	if type(controller.BanSender) ~= "function" then
		return "BAN API OUT OF DATE / RELOAD UI"
	end
	return nil
end

function Config:SetSpamNotice(text, colorName)
	if not self.spamBanNotice then return end
	colorName = colorName or "textMuted"
	self.spamBanNotice:SetText(text or "")
	Theme.texts[self.spamBanNotice] = colorName
	local r, g, b, a = Theme:GetColor(colorName)
	self.spamBanNotice:SetTextColor(r, g, b, a)
end

function Config:RefreshSpamHealth()
	if not self.spamHealth then
		return
	end
	local _, _, text, colorName = getSpamFirewallHealth()
	self.spamHealth:SetText(text)
	Theme.texts[self.spamHealth] = colorName
	local r, g, b, a = Theme:GetColor(colorName)
	self.spamHealth:SetTextColor(r, g, b, a)
end

function Config:SetSpamSection(section)
	section = section == "bans" and "bans" or "filters"
	self.spamSection = section
	if section ~= "bans" then
		self:HideSpamBanReport()
	end
	if self.spamFiltersPane then
		if section == "filters" then self.spamFiltersPane:Show() else self.spamFiltersPane:Hide() end
	end
	if self.spamBansPane then
		if section == "bans" then self.spamBansPane:Show() else self.spamBansPane:Hide() end
	end
	if self.spamFiltersButton then
		setTabStyle(self.spamFiltersButton, section == "filters")
	end
	if self.spamBansButton then
		setTabStyle(self.spamBansButton, section == "bans")
	end
	if section == "filters" then
		self:SetSpamFilterPane(self.spamFilterMode or "protections")
	else
		self:SetSpamBanPane(self.spamBanMode or "players")
		self:RefreshSpamBans(true)
	end
end

function Config:SetSpamFilterPane(mode)
	if mode ~= "matching" and mode ~= "chats" then mode = "protections" end
	self.spamFilterMode = mode
	for paneId, pane in pairs(self.spamFilterSubPanes or {}) do
		if paneId == mode then pane:Show() else pane:Hide() end
	end
	for paneId, button in pairs(self.spamFilterSubButtons or {}) do
		setTabStyle(button, paneId == mode)
	end
end

function Config:SetSpamBanPane(mode)
	if mode ~= "auto" and mode ~= "maintenance" then mode = "players" end
	self.spamBanMode = mode
	if mode ~= "players" then self:HideSpamBanReport() end
	for paneId, pane in pairs(self.spamBanSubPanes or {}) do
		if paneId == mode then pane:Show() else pane:Hide() end
	end
	for paneId, button in pairs(self.spamBanSubButtons or {}) do
		setTabStyle(button, paneId == mode)
	end
end

function Config:RefreshSpamBans(keepNotice)
	if not self.spamBanRows then return end
	local bans = getSpamBans()
	local pageCount = math.max(1, math.ceil(#bans / SPAM_BAN_PAGE_SIZE))
	self.spamBanPage = math.max(1, math.min(pageCount, self.spamBanPage or 1))
	local first = ((self.spamBanPage - 1) * SPAM_BAN_PAGE_SIZE) + 1
	for index = 1, SPAM_BAN_PAGE_SIZE do
		local row = self.spamBanRows[index]
		local entry = bans[first + index - 1]
		if entry then
			local name = tostring(entry.fullName or entry.name or entry.id or "Unknown")
			row.banIdentity = entry.id or entry.fullName or entry.name
			row.banEntry = entry
			row.reason = getSpamBanReason(entry, true)
			row.name:SetText(name)
			row.detail:SetText(getSpamBanReason(entry, false))
			local detailColor = entry.source == "automatic" and "warning" or "textMuted"
			Theme.texts[row.detail] = detailColor
			local r, g, b, a = Theme:GetColor(detailColor)
			row.detail:SetTextColor(r, g, b, a)
			row:Show()
		else
			row.banIdentity = nil
			row.banEntry = nil
			row.reason = nil
			row:Hide()
		end
	end
	if self.spamBanCount then
		self.spamBanCount:SetText(#bans .. " BANNED  /  PAGE " .. self.spamBanPage .. " OF " .. pageCount)
	end
	local hasPrevious = self.spamBanPage > 1
	local hasNext = self.spamBanPage < pageCount
	if self.spamBanPrevious then
		if pageCount > 1 then
			self.spamBanPrevious:Show()
			self.spamBanPrevious:SetAlpha(hasPrevious and 1 or 0.35)
			self.spamBanPrevious:EnableMouse(hasPrevious)
		else
			self.spamBanPrevious:Hide()
		end
	end
	if self.spamBanNext then
		if pageCount > 1 then
			self.spamBanNext:Show()
			self.spamBanNext:SetAlpha(hasNext and 1 or 0.35)
			self.spamBanNext:EnableMouse(hasNext)
		else
			self.spamBanNext:Hide()
		end
	end
	if self.spamBanSummary then
		local offenders = getSpamCounter("GetOffenderStats", "offenders", 0)
		local strikes = getSpamCounter("GetOffenderStats", "strikes", 0)
		self.spamBanSummary:SetText("WATCHED  " .. offenders .. "   ACTIVE STRIKES  " .. strikes)
	end
	if not keepNotice then self:SetSpamNotice("") end
end

function Config:AddSpamBan()
	if not self.spamBanNameEdit then return end
	local name = trim(self.spamBanNameEdit:GetText())
	if name == "" then
		self:SetSpamNotice("ENTER A PLAYER NAME", "warning")
		return
	end
	local controller = addon.SpamControl
	local serviceProblem = getSpamBanServiceProblem()
	if serviceProblem then
		self:SetSpamNotice(serviceProblem, "danger")
		self:RefreshSpamHealth()
		return
	end
	local ok, added, reason = pcall(controller.BanSender, controller, name, { source = "manual" })
	if not ok or not added then
		local messages = {
			invalid = "THAT PLAYER NAME IS NOT VALID",
			self = "YOU CANNOT BAN YOURSELF",
			capacity = "THE BAN LIST IS FULL",
		}
		self:SetSpamNotice(messages[reason] or "PLAYER COULD NOT BE BANNED", "danger")
		return
	end
	self.spamBanNameEdit:SetText("")
	self.spamBanNameEdit:ClearFocus()
	self.spamBanPage = 1
	self.spamClearBansExpires = nil
	if self.spamClearBansButton then self.spamClearBansButton:SetLabel("CLEAR BANS") end
	self:RefreshSpamBans(true)
	self:SetSpamNotice("BANNED " .. string.upper(name), "warning")
	self:RefreshSpamStatus()
end

function Config:UnbanSpamSender(identity)
	local controller = addon.SpamControl
	if not identity then return end
	if not controller or type(controller.UnbanSender) ~= "function" then
		self:SetSpamNotice(getSpamBanServiceProblem() or "UNBAN API OUT OF DATE / RELOAD UI", "danger")
		self:RefreshSpamHealth()
		return
	end
	local ok, removed = pcall(controller.UnbanSender, controller, identity)
	if ok and removed then
		self:SetSpamNotice("PLAYER REMOVED FROM THE BAN LIST", "success")
	else
		self:SetSpamNotice("PLAYER WAS ALREADY REMOVED", "textMuted")
	end
	self:RefreshSpamBans(true)
	self:RefreshSpamStatus()
end

function Config:ResetSpamSenderStrikes(identity)
	local controller = addon.SpamControl
	if not identity then return end
	if not controller or type(controller.ResetOffender) ~= "function" then
		self:SetSpamNotice(getSpamBanServiceProblem() or "STRIKE API OUT OF DATE / RELOAD UI", "danger")
		self:RefreshSpamHealth()
		return
	end
	local ok, removed = pcall(controller.ResetOffender, controller, identity)
	self:SetSpamNotice(ok and removed and "PLAYER STRIKE HISTORY RESET" or "NO ACTIVE STRIKE HISTORY", ok and "success" or "textMuted")
	self:RefreshSpamBans(true)
	self:RefreshSpamStatus()
end

function Config:HideSpamBanReport()
	if self.spamBanReport then
		self.spamBanReport:Hide()
	end
end

function Config:ShowSpamBanReport(identity, fallback)
	local report = getSpamBanReport(identity, fallback)
	if not report then
		self:SetSpamNotice("BAN REPORT IS NO LONGER AVAILABLE", "warning")
		return
	end

	if not self.spamBanReport then
		local dialog = Theme:CreatePanel(self.frame, "surfaceRaised", "gold")
		dialog:SetSize(530, 390)
		dialog:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
		dialog:SetFrameStrata("DIALOG")
		dialog:EnableMouse(true)
		self.spamBanReport = dialog

		local title = Theme:CreateText(dialog, "GameFontNormalLarge", "goldBright")
		title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 14, -12)
		title:SetWidth(470)
		title:SetJustifyH("LEFT")
		dialog.title = title
		local close = CreateFrame("Button", nil, dialog)
		close:SetSize(18, 18)
		close:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -8, -8)
		close.text = Theme:CreateText(close, "GameFontNormalSmall", "textMuted")
		close.text:SetAllPoints(close)
		close.text:SetJustifyH("CENTER")
		close.text:SetText("x")
		close:SetScript("OnEnter", function(self)
			local r, g, b, a = Theme:GetColor("goldBright")
			self.text:SetTextColor(r, g, b, a)
		end)
		close:SetScript("OnLeave", function(self)
			local r, g, b, a = Theme:GetColor("textMuted")
			self.text:SetTextColor(r, g, b, a)
		end)
		close:SetScript("OnClick", function() Config:HideSpamBanReport() end)

		local summary = Theme:CreateText(dialog, "GameFontHighlightSmall", "warning")
		summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
		summary:SetWidth(492)
		summary:SetJustifyH("LEFT")
		dialog.summary = summary
		local context = Theme:CreateText(dialog, "GameFontHighlightSmall", "textMuted")
		context:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -4)
		context:SetWidth(502)
		context:SetJustifyH("LEFT")
		dialog.context = context
		local evidenceTitle = Theme:CreateText(dialog, "GameFontNormalSmall", "gold")
		evidenceTitle:SetPoint("TOPLEFT", context, "BOTTOMLEFT", 0, -14)
		evidenceTitle:SetText("TRIGGERING MESSAGES")
		dialog.evidenceTitle = evidenceTitle
		local noEvidence = Theme:CreateText(dialog, "GameFontHighlightSmall", "textMuted")
		noEvidence:SetPoint("TOPLEFT", evidenceTitle, "BOTTOMLEFT", 0, -6)
		noEvidence:SetWidth(500)
		noEvidence:SetJustifyH("LEFT")
		dialog.noEvidence = noEvidence
		dialog.evidenceRows = {}
		for index = 1, 4 do
			local row = Theme:CreateText(dialog, "GameFontHighlightSmall", "text")
			row:SetPoint("TOPLEFT", evidenceTitle, "BOTTOMLEFT", 0, -6 - ((index - 1) * 43))
			row:SetWidth(500)
			row:SetJustifyH("LEFT")
			dialog.evidenceRows[index] = row
		end
		local unban = Theme:CreateButton(dialog, "UNBAN PLAYER", 112, 22, true)
		unban:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 14, 14)
		unban:SetScript("OnClick", function()
			if dialog.banIdentity then
				Config:UnbanSpamSender(dialog.banIdentity)
			end
			Config:HideSpamBanReport()
		end)
		local resetStrikes = Theme:CreateButton(dialog, "RESET STRIKES", 112, 22, false)
		resetStrikes:SetPoint("LEFT", unban, "RIGHT", 6, 0)
		resetStrikes:SetScript("OnClick", function()
			if dialog.banIdentity then
				Config:ResetSpamSenderStrikes(dialog.banIdentity)
			end
		end)
		local closeAction = Theme:CreateButton(dialog, "CLOSE", 68, 22, false)
		closeAction:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -14, 14)
		closeAction:SetScript("OnClick", function() Config:HideSpamBanReport() end)
	end

	local dialog = self.spamBanReport
	dialog.banIdentity = report.id or identity
	local name = tostring(report.fullName or report.name or report.id or "Unknown player")
	dialog.title:SetText("Ban report: " .. name)
	dialog.summary:SetText(getSpamBanReason(report, true))
	local context = "BANNED " .. formatSpamBanTimestamp(report.bannedAt)
	if report.lastEvent and report.lastEvent ~= "" then
		context = context .. "   EVENT " .. tostring(report.lastEvent)
	end
	dialog.context:SetText(context)
	local evidence = type(report.evidence) == "table" and report.evidence or {}
	for index, row in ipairs(dialog.evidenceRows) do
		local entry = evidence[index]
		if entry then
			local reason = entry.reason == "burst" and "RAPID FLOOD" or "REPEATED MESSAGE"
			local where = entry.channel and entry.channel ~= "" and (" / " .. string.upper(entry.channel)) or ""
			row:SetText(tostring(index) .. ". " .. reason .. where .. "\n" .. tostring(entry.message or "[Message unavailable]"))
			row:Show()
		else
			row:Hide()
		end
	end
	if #evidence > 0 then
		dialog.noEvidence:Hide()
	else
		dialog.noEvidence:SetText(report.source == "manual"
			and "This is a manual local ban. No observed messages were recorded."
			or "No message evidence was retained for this older ban.")
		dialog.noEvidence:Show()
	end
	dialog:Show()
end

function Config:ClearSpamStrikes()
	local controller = addon.SpamControl
	if not controller or type(controller.ClearOffenders) ~= "function" then
		self:SetSpamNotice(getSpamBanServiceProblem() or "STRIKE API OUT OF DATE / RELOAD UI", "danger")
		self:RefreshSpamHealth()
		return
	end
	local ok, removed = pcall(controller.ClearOffenders, controller)
	self:SetSpamNotice(ok and ((tonumber(removed) or 0) .. " STRIKE RECORDS CLEARED") or "STRIKES COULD NOT BE CLEARED", ok and "success" or "danger")
	self:RefreshSpamBans(true)
end

function Config:ClearSpamBans()
	local controller = addon.SpamControl
	if not controller or type(controller.ClearBans) ~= "function" then
		self:SetSpamNotice(getSpamBanServiceProblem() or "BAN API OUT OF DATE / RELOAD UI", "danger")
		self:RefreshSpamHealth()
		return
	end
	local now = GetTime and GetTime() or 0
	if not self.spamClearBansExpires or now > self.spamClearBansExpires then
		self.spamClearBansExpires = now + 5
		if self.spamClearBansButton then self.spamClearBansButton:SetLabel("CONFIRM") end
		self:SetSpamNotice("CLICK CONFIRM TO CLEAR EVERY BAN", "warning")
		return
	end
	local ok, removed = pcall(controller.ClearBans, controller)
	self.spamClearBansExpires = nil
	if self.spamClearBansButton then self.spamClearBansButton:SetLabel("CLEAR BANS") end
	self.spamBanPage = 1
	self:RefreshSpamBans(true)
	self:SetSpamNotice(ok and ((tonumber(removed) or 0) .. " BANS CLEARED") or "BANS COULD NOT BE CLEARED", ok and "success" or "danger")
	self:RefreshSpamStatus()
end

function Config:RefreshSpamStatus()
	local stats = {}
	if addon.SpamControl and addon.SpamControl.GetStats then
		local ok, result = pcall(addon.SpamControl.GetStats, addon.SpamControl)
		if ok and type(result) == "table" then stats = result end
	end
	self:RefreshSpamHealth()
	if not self.spamStatus then
		return
	end
	local blocked = tonumber(stats.blocked or stats.totalBlocked) or 0
	local duplicates = tonumber(stats.duplicates or stats.duplicateBlocked) or 0
	local bursts = tonumber(stats.bursts or stats.burstBlocked) or 0
	local banned = getSpamCounter("GetBanStats", "banned", #getSpamBans())
	self.spamStatus:SetText("BLOCKED  " .. blocked .. "   DUPLICATE  " .. duplicates .. "   BURST  " .. bursts .. "   BANNED  " .. banned)
	local colorName = (blocked > 0 or banned > 0) and "warning" or "textMuted"
	Theme.texts[self.spamStatus] = colorName
	local r, g, b, a = Theme:GetColor(colorName)
	self.spamStatus:SetTextColor(r, g, b, a)
end

function Config:BuildSpamPage()
	local page = self:CreatePage("spam")
	self.spamPage = page
	createHeading(page, "Spam Firewall", "Choose what Chatty blocks, how messages are compared, and how repeat offenders are handled.")

	local settings = addon:GetSmartSettings()
	settings.spam = settings.spam or {}
	settings.spam.duplicate = settings.spam.duplicate or {}
	settings.spam.burst = settings.spam.burst or {}
	settings.spam.scopes = settings.spam.scopes or {}
	settings.spam.escalation = settings.spam.escalation or {}
	local spam = settings.spam
	local escalation = settings.spam.escalation

	local master = Theme:CreateCompactToggle(page, "SPAM FIREWALL", 166)
	master:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -52)
	master:SetValue(spam.enabled ~= false, true)
	master.OnValueChanged = function(_, value)
		spam.enabled = value and true or false
		applySpamRuntime()
		Config:RefreshSpamStatus()
	end
	setControlTooltip(master, "Enable Spam Firewall", "Turns duplicate, flood, and local-ban filtering on or off without deleting its settings or bans.")
	self.spamHealth = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	self.spamHealth:SetPoint("TOPLEFT", page, "TOPLEFT", 186, -57)
	self.spamHealth:SetWidth(270)
	self.spamHealth:SetJustifyH("LEFT")

	self.spamFiltersButton = Theme:CreateButton(page, "FILTERS", 76, 22, false)
	setActionStyle(self.spamFiltersButton, "choice", "Protection rules", "Tune duplicate and sender-flood protection.")
	self.spamFiltersButton:SetScript("OnClick", function() Config:SetSpamSection("filters") end)
	self.spamBansButton = Theme:CreateButton(page, "BAN LIST", 91, 22, false)
	setActionStyle(self.spamBansButton, "choice", "Local ban list", "Review local bans, see the retained evidence, or remove one.")
	self.spamBansButton:SetPoint("TOPRIGHT", page, "TOPRIGHT", -PAGE_GUTTER, -52)
	self.spamFiltersButton:SetPoint("RIGHT", self.spamBansButton, "LEFT", -4, 0)
	self.spamBansButton:SetScript("OnClick", function() Config:SetSpamSection("bans") end)

	local filters = CreateFrame("Frame", nil, page)
	filters:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -85)
	filters:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -PAGE_GUTTER, 48)
	self.spamFiltersPane = filters
	self.spamFilterSubButtons = {}
	self.spamFilterSubPanes = {}
	local protectionsButton = Theme:CreateTightButton(filters, "PROTECTIONS", 20, false)
	protectionsButton:SetPoint("TOPLEFT", filters, "TOPLEFT", 0, 0)
	protectionsButton:SetScript("OnClick", function() Config:SetSpamFilterPane("protections") end)
	setActionStyle(protectionsButton, "choice", "Core protections", "The two plain-language protections that decide what the firewall blocks.")
	self.spamFilterSubButtons.protections = protectionsButton
	local matchingButton = Theme:CreateTightButton(filters, "MATCHING DETAILS", 20, false)
	matchingButton:SetPoint("LEFT", protectionsButton, "RIGHT", CONTROL_GAP, 0)
	matchingButton:SetScript("OnClick", function() Config:SetSpamFilterPane("matching") end)
	setActionStyle(matchingButton, "choice", "Message matching details", "Tune timing, normalization, and thresholds used by the two protections.")
	self.spamFilterSubButtons.matching = matchingButton
	local chatsButton = Theme:CreateTightButton(filters, "PROTECTED CHATS", 20, false)
	chatsButton:SetPoint("LEFT", matchingButton, "RIGHT", CONTROL_GAP, 0)
	chatsButton:SetScript("OnClick", function() Config:SetSpamFilterPane("chats") end)
	setActionStyle(chatsButton, "choice", "Protected chat types", "Choose which families of chat the firewall is allowed to filter.")
	self.spamFilterSubButtons.chats = chatsButton

	local protectionsPane = CreateFrame("Frame", nil, filters)
	protectionsPane:SetPoint("TOPLEFT", filters, "TOPLEFT", 0, -32)
	protectionsPane:SetSize(PAGE_WIDTH, 300)
	self.spamFilterSubPanes.protections = protectionsPane
	local matchingPane = CreateFrame("Frame", nil, filters)
	matchingPane:SetPoint("TOPLEFT", filters, "TOPLEFT", 0, -32)
	matchingPane:SetSize(PAGE_WIDTH, 300)
	self.spamFilterSubPanes.matching = matchingPane
	local chatsPane = CreateFrame("Frame", nil, filters)
	chatsPane:SetPoint("TOPLEFT", filters, "TOPLEFT", 0, -32)
	chatsPane:SetSize(PAGE_WIDTH, 300)
	self.spamFilterSubPanes.chats = chatsPane

	local protectionsTitle = Theme:CreateText(protectionsPane, "GameFontNormalSmall", "gold")
	protectionsTitle:SetPoint("TOPLEFT", protectionsPane, "TOPLEFT", 0, 0)
	protectionsTitle:SetText("WHAT SHOULD THE FIREWALL STOP?")
	self.spamDuplicateToggle = Theme:CreateCompactToggle(protectionsPane, "HIDE IDENTICAL REPEATS", 224)
	self.spamDuplicateToggle:SetPoint("TOPLEFT", protectionsPane, "TOPLEFT", 0, -34)
	local duplicate = self.spamDuplicateToggle
	duplicate:SetValue(spam.duplicate.enabled ~= false, true)
	duplicate.OnValueChanged = function(_, value)
		spam.duplicate.enabled = value and true or false
		applySpamRuntime()
		Config:RefreshSpamStatus()
	end
	setControlTooltip(duplicate, "Hide repeated copies", "The first allowed copies remain visible; later identical messages are hidden across all protected chats.")
	local duplicateHint = Theme:CreateText(protectionsPane, "GameFontHighlightSmall", "textMuted")
	duplicateHint:SetPoint("TOPLEFT", protectionsPane, "TOPLEFT", 232, -39)
	duplicateHint:SetWidth(396)
	duplicateHint:SetJustifyH("LEFT")
	duplicateHint:SetText("Stops the same player from repeating the same message across protected chats.")
	self.spamBurstToggle = Theme:CreateCompactToggle(protectionsPane, "MUTE RAPID SENDER FLOODS", 224)
	self.spamBurstToggle:SetPoint("TOPLEFT", protectionsPane, "TOPLEFT", 0, -104)
	local burst = self.spamBurstToggle
	burst:SetValue(spam.burst.enabled ~= false, true)
	burst.OnValueChanged = function(_, value)
		spam.burst.enabled = value and true or false
		applySpamRuntime()
		Config:RefreshSpamStatus()
	end
	setControlTooltip(burst, "Mute rapid sender floods", "Temporarily mutes a sender who posts too many messages inside the configured burst window.")
	local burstHint = Theme:CreateText(protectionsPane, "GameFontHighlightSmall", "textMuted")
	burstHint:SetPoint("TOPLEFT", protectionsPane, "TOPLEFT", 232, -109)
	burstHint:SetWidth(396)
	burstHint:SetJustifyH("LEFT")
	burstHint:SetText("Stops one sender from flooding many different messages in a short time.")
	local protectionNote = Theme:CreateText(protectionsPane, "GameFontHighlightSmall", "textMuted")
	protectionNote:SetPoint("TOPLEFT", protectionsPane, "TOPLEFT", 0, -184)
	protectionNote:SetWidth(PAGE_WIDTH)
	protectionNote:SetJustifyH("LEFT")
	protectionNote:SetText("Open MATCHING DETAILS only when you want to tune thresholds. PROTECTED CHATS controls where both protections apply.")

	local duplicateDetailsTitle = Theme:CreateText(matchingPane, "GameFontNormalSmall", "gold")
	duplicateDetailsTitle:SetPoint("TOPLEFT", matchingPane, "TOPLEFT", 0, 0)
	duplicateDetailsTitle:SetText("IDENTICAL REPEATS")
	self.spamNumberEdits = {}
	self.spamNumberEdits.duplicateWindow = createSpamNumberField(matchingPane, "WINDOW (SEC)", 0, 22, spam.duplicate, "window", 1, 300, 12)
	self.spamNumberEdits.allowedCopies = createSpamNumberField(matchingPane, "COPIES ALLOWED", 114, 22, spam.duplicate, "allowedCopies", 1, 10, 1)
	self.spamNumberEdits.minimumLength = createSpamNumberField(matchingPane, "MINIMUM LENGTH", 228, 22, spam.duplicate, "minimumLength", 0, 100, 4)
	-- The core advertises this capability by seeding the setting during its
	-- migration.  Do not create an unknown SavedVariables key on older builds.
	self.spamDuplicateMuteAfterEdit = nil
	if spam.duplicate.muteAfter ~= nil then
		self.spamDuplicateMuteAfterEdit = createSpamNumberField(matchingPane, "REPEATS TO MUTE", 342, 22, spam.duplicate, "muteAfter", 0, 100, 0)
		self.spamNumberEdits.muteAfter = self.spamDuplicateMuteAfterEdit
	end
	local repeatDetail = Theme:CreateText(matchingPane, "GameFontHighlightSmall", "textMuted")
	repeatDetail:SetPoint("TOPLEFT", matchingPane, "TOPLEFT", 456, -40)
	repeatDetail:SetWidth(176)
	repeatDetail:SetJustifyH("LEFT")
	repeatDetail:SetText("0 REPEATS TO MUTE = HIDE ONLY")
	local normalTitle = Theme:CreateText(matchingPane, "GameFontNormalSmall", "gold")
	normalTitle:SetPoint("TOPLEFT", matchingPane, "TOPLEFT", 0, -78)
	normalTitle:SetText("DUPLICATE NORMALIZATION")
	createSpamToggle(matchingPane, "CASE INSENSITIVE", 0, 96, spam.duplicate, "caseInsensitive")
	createSpamToggle(matchingPane, "COLLAPSE SPACES", 202, 96, spam.duplicate, "collapseWhitespace")
	createSpamToggle(matchingPane, "STRIP CHAT FORMATTING", 404, 96, spam.duplicate, "stripFormatting")
	createSpamToggle(matchingPane, "IGNORE PUNCTUATION", 0, 120, spam.duplicate, "ignorePunctuation")
	createSpamToggle(matchingPane, "ALLOW SELF (SKIP FILTER)", 202, 120, spam, "exemptSelf")
	local crossSourceHint = Theme:CreateText(matchingPane, "GameFontHighlightSmall", "textMuted")
	crossSourceHint:SetPoint("TOPLEFT", matchingPane, "TOPLEFT", 404, -124)
	crossSourceHint:SetWidth(194)
	crossSourceHint:SetJustifyH("LEFT")
	crossSourceHint:SetText("MATCHES ACROSS PROTECTED CHATS")
	local floodTitle = Theme:CreateText(matchingPane, "GameFontNormalSmall", "gold")
	floodTitle:SetPoint("TOPLEFT", matchingPane, "TOPLEFT", 0, -158)
	floodTitle:SetText("RAPID SENDER FLOODS")
	self.spamNumberEdits.burstWindow = createSpamNumberField(matchingPane, "BURST WINDOW", 0, 180, spam.burst, "window", 1, 60, 6)
	self.spamNumberEdits.messageLimit = createSpamNumberField(matchingPane, "MESSAGE LIMIT", 114, 180, spam.burst, "limit", 2, 50, 6)
	self.spamNumberEdits.muteDuration = createSpamNumberField(matchingPane, "MUTE (SEC)", 228, 180, spam.burst, "muteDuration", 1, 300, 15)
	local matchingHint = Theme:CreateText(matchingPane, "GameFontHighlightSmall", "textMuted")
	matchingHint:SetPoint("TOPLEFT", matchingPane, "TOPLEFT", 342, -198)
	matchingHint:SetWidth(286)
	matchingHint:SetJustifyH("LEFT")
	matchingHint:SetText("A sender is muted after MESSAGE LIMIT posts inside BURST WINDOW.")

	local scopeTitle = Theme:CreateText(chatsPane, "GameFontNormalSmall", "gold")
	scopeTitle:SetPoint("TOPLEFT", chatsPane, "TOPLEFT", 0, 0)
	scopeTitle:SetText("WHICH CHATS CAN THE FIREWALL FILTER?")
	local scopeHint = Theme:CreateText(chatsPane, "GameFontHighlightSmall", "textMuted")
	scopeHint:SetPoint("TOPLEFT", chatsPane, "TOPLEFT", 0, -20)
	scopeHint:SetWidth(PAGE_WIDTH)
	scopeHint:SetJustifyH("LEFT")
	scopeHint:SetText("Turn off a chat family to let its messages bypass duplicate, flood, and escalation checks.")
	self.spamScopeToggles = {
		channel = createSpamToggle(chatsPane, "PUBLIC CHANNELS", 0, 52, spam.scopes, "channel"),
		localChat = createSpamToggle(chatsPane, "SAY / YELL / EMOTE", 230, 52, spam.scopes, "local"),
		guild = createSpamToggle(chatsPane, "GUILD / OFFICER", 0, 88, spam.scopes, "guild"),
		group = createSpamToggle(chatsPane, "PARTY / RAID / BG", 230, 88, spam.scopes, "group"),
		whisper = createSpamToggle(chatsPane, "WHISPERS", 0, 124, spam.scopes, "whisper"),
		bnet = createSpamToggle(chatsPane, "BATTLE.NET", 230, 124, spam.scopes, "bnet"),
	}

	local bansPane = CreateFrame("Frame", nil, page)
	bansPane:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -85)
	bansPane:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -PAGE_GUTTER, 48)
	self.spamBansPane = bansPane
	self.spamBanSubButtons = {}
	self.spamBanSubPanes = {}
	local playersButton = Theme:CreateTightButton(bansPane, "PLAYERS", 20, false)
	playersButton:SetPoint("TOPLEFT", bansPane, "TOPLEFT", 0, 0)
	playersButton:SetScript("OnClick", function() Config:SetSpamBanPane("players") end)
	setActionStyle(playersButton, "choice", "Banned players", "Add a manual local ban, inspect reports, or unban one player.")
	self.spamBanSubButtons.players = playersButton
	local autoButton = Theme:CreateTightButton(bansPane, "AUTO-BAN", 20, false)
	autoButton:SetPoint("LEFT", playersButton, "RIGHT", CONTROL_GAP, 0)
	autoButton:SetScript("OnClick", function() Config:SetSpamBanPane("auto") end)
	setActionStyle(autoButton, "choice", "Automatic ban escalation", "Choose when repeated automatic mutes become a persistent local ban.")
	self.spamBanSubButtons.auto = autoButton
	local maintenanceButton = Theme:CreateTightButton(bansPane, "MAINTENANCE", 20, false)
	maintenanceButton:SetPoint("LEFT", autoButton, "RIGHT", CONTROL_GAP, 0)
	maintenanceButton:SetScript("OnClick", function() Config:SetSpamBanPane("maintenance") end)
	setActionStyle(maintenanceButton, "choice", "Firewall maintenance", "Reset counters or recent memory, clear strikes, or clear every local ban.")
	self.spamBanSubButtons.maintenance = maintenanceButton

	local playersPane = CreateFrame("Frame", nil, bansPane)
	playersPane:SetPoint("TOPLEFT", bansPane, "TOPLEFT", 0, -32)
	playersPane:SetSize(PAGE_WIDTH, 300)
	self.spamBanSubPanes.players = playersPane
	local autoPane = CreateFrame("Frame", nil, bansPane)
	autoPane:SetPoint("TOPLEFT", bansPane, "TOPLEFT", 0, -32)
	autoPane:SetSize(PAGE_WIDTH, 300)
	self.spamBanSubPanes.auto = autoPane
	local maintenancePane = CreateFrame("Frame", nil, bansPane)
	maintenancePane:SetPoint("TOPLEFT", bansPane, "TOPLEFT", 0, -32)
	maintenancePane:SetSize(PAGE_WIDTH, 300)
	self.spamBanSubPanes.maintenance = maintenancePane

	self.spamEscalationToggle = Theme:CreateCompactToggle(autoPane, "AUTOMATIC BAN ESCALATION", 224)
	self.spamEscalationToggle:SetPoint("TOPLEFT", autoPane, "TOPLEFT", 0, 0)
	local escalationToggle = self.spamEscalationToggle
	escalationToggle:SetValue(escalation.enabled ~= false, true)
	escalationToggle.OnValueChanged = function(_, value)
		escalation.enabled = value and true or false
		applySpamRuntime()
		Config:RefreshSpamStatus()
	end
	setControlTooltip(escalationToggle, "Automatically ban repeat offenders", "Each timed automatic mute adds a strike; enough strikes inside the window create a persistent local ban.")
	local escalationHint = Theme:CreateText(autoPane, "GameFontHighlightSmall", "textMuted")
	escalationHint:SetPoint("TOPLEFT", autoPane, "TOPLEFT", 232, -5)
	escalationHint:SetWidth(396)
	escalationHint:SetJustifyH("LEFT")
	escalationHint:SetText("Repeated automatic mutes become a persistent local ban.")
	self.spamMutesToBanEdit = createSpamNumberField(autoPane, "MUTES TO BAN", 0, 42, escalation, "mutesBeforeBan", 1, 100, 3)
	self.spamStrikeWindowEdit = createSpamMinutesField(autoPane, "STRIKE WINDOW (MIN)", 153, 42, escalation, "strikeWindow", 30)
	local escalationDetail = Theme:CreateText(autoPane, "GameFontHighlightSmall", "textMuted")
	escalationDetail:SetPoint("TOPLEFT", autoPane, "TOPLEFT", 0, -102)
	escalationDetail:SetWidth(520)
	escalationDetail:SetJustifyH("LEFT")
	escalationDetail:SetText("A strike is created only by an automatic timed mute. Manual bans do not change strike history.")

	local manualTitle = Theme:CreateText(playersPane, "GameFontNormalSmall", "gold")
	manualTitle:SetPoint("TOPLEFT", playersPane, "TOPLEFT", 0, 0)
	manualTitle:SetText("MANUAL LOCAL BAN")
	self.spamBanNameEdit = Theme:CreateEditBox(playersPane, 258, 22, false)
	self.spamBanNameEdit:SetPoint("TOPLEFT", playersPane, "TOPLEFT", 0, -18)
	setControlTooltip(self.spamBanNameEdit, "Player to ban locally", "Enter a player name. Chatty's local ban list is separate from WoW Ignore.")
	self.spamBanNameEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() Config:AddSpamBan() end)
	local addBan = Theme:CreateButton(playersPane, "BAN PLAYER", 88, 22, true)
	setActionStyle(addBan, "primary", "Ban this player locally", "Adds the entered player to Chatty's local ban list. It does not change WoW Ignore.")
	addBan:SetPoint("LEFT", self.spamBanNameEdit, "RIGHT", 4, 0)
	addBan:SetScript("OnClick", function() Config:AddSpamBan() end)
	local banListTitle = Theme:CreateText(playersPane, "GameFontNormalSmall", "gold")
	banListTitle:SetPoint("TOPLEFT", playersPane, "TOPLEFT", 0, -52)
	banListTitle:SetText("BANNED PLAYERS / CLICK FOR REPORT")
	self.spamBanCount = Theme:CreateText(playersPane, "GameFontHighlightSmall", "textMuted")
	self.spamBanCount:SetPoint("TOPRIGHT", playersPane, "TOPRIGHT", 0, -54)
	self.spamBanCount:SetWidth(200)
	self.spamBanCount:SetJustifyH("RIGHT")
	self.spamBanRows = {}
	for index = 1, SPAM_BAN_PAGE_SIZE do
		local row = CreateFrame("Button", nil, playersPane)
		row:SetPoint("TOPLEFT", playersPane, "TOPLEFT", 0, -72 - ((index - 1) * 23))
		row:SetPoint("TOPRIGHT", playersPane, "TOPRIGHT", 0, -72 - ((index - 1) * 23))
		row:SetHeight(20)
		row.name = Theme:CreateText(row, "GameFontNormalSmall", "text")
		row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.name:SetWidth(210)
		row.name:SetJustifyH("LEFT")
		row.detail = Theme:CreateText(row, "GameFontHighlightSmall", "textMuted")
		row.detail:SetPoint("LEFT", row, "LEFT", 216, 0)
		row.detail:SetWidth(350)
		row.detail:SetJustifyH("LEFT")
		row.unban = Theme:CreateTightButton(row, "UNBAN", 20, false)
		row.unban:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		row.unban:SetScript("OnClick", function() Config:UnbanSpamSender(row.banIdentity) end)
		row:SetScript("OnEnter", function(self)
			if self.banIdentity and self.reason then
				Config.spamBanHoverIdentity = self.banIdentity
				if GameTooltip then
					GameTooltip:SetOwner(self, "ANCHOR_LEFT")
					GameTooltip:AddLine("Ban report", 1, 0.8, 0.39)
					GameTooltip:AddLine(self.reason, 0.78, 0.84, 0.94, true)
					GameTooltip:AddLine("Click for retained messages and actions.", 0.55, 0.62, 0.72, true)
					GameTooltip:Show()
				else
					Config:SetSpamNotice(self.reason, "textMuted")
				end
			end
		end)
		row:SetScript("OnLeave", function(self)
			if Config.spamBanHoverIdentity == self.banIdentity then
				Config.spamBanHoverIdentity = nil
				if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == self then
					GameTooltip:Hide()
				elseif not GameTooltip then
					Config:SetSpamNotice("")
				end
			end
		end)
		row:SetScript("OnClick", function(self, button)
			if button == "LeftButton" and self.banIdentity then
				Config:ShowSpamBanReport(self.banIdentity, self.banEntry)
			end
		end)
		self.spamBanRows[index] = row
	end
	self.spamBanPrevious = Theme:CreateTightButton(playersPane, "<", 20, false)
	self.spamBanPrevious:SetPoint("TOPLEFT", playersPane, "TOPLEFT", 0, -239)
	self.spamBanPrevious:SetScript("OnClick", function()
		Config.spamBanPage = math.max(1, (Config.spamBanPage or 1) - 1)
		Config:RefreshSpamBans(true)
	end)
	self.spamBanNext = Theme:CreateTightButton(playersPane, ">", 20, false)
	self.spamBanNext:SetPoint("LEFT", self.spamBanPrevious, "RIGHT", 4, 0)
	self.spamBanNext:SetScript("OnClick", function()
		Config.spamBanPage = (Config.spamBanPage or 1) + 1
		Config:RefreshSpamBans(true)
	end)
	self.spamBanSummary = Theme:CreateText(playersPane, "GameFontHighlightSmall", "textMuted")
	self.spamBanSummary:SetPoint("LEFT", self.spamBanNext, "RIGHT", 9, 0)
	self.spamBanSummary:SetWidth(245)
	self.spamBanSummary:SetJustifyH("LEFT")

	local maintenanceTitle = Theme:CreateText(maintenancePane, "GameFontNormalSmall", "gold")
	maintenanceTitle:SetPoint("TOPLEFT", maintenancePane, "TOPLEFT", 0, 0)
	maintenanceTitle:SetText("RESET OR CLEAR FIREWALL DATA")
	local maintenanceHint = Theme:CreateText(maintenancePane, "GameFontHighlightSmall", "textMuted")
	maintenanceHint:SetPoint("TOPLEFT", maintenancePane, "TOPLEFT", 0, -20)
	maintenanceHint:SetWidth(PAGE_WIDTH)
	maintenanceHint:SetJustifyH("LEFT")
	maintenanceHint:SetText("These actions do not change protection settings. CLEAR BANS requires a second confirmation click.")
	local clearStrikes = Theme:CreateButton(maintenancePane, "CLEAR STRIKES", 116, 22, false)
	setActionStyle(clearStrikes, "quiet", "Clear automatic-ban strikes", "Keeps bans and settings; only clears recent escalation history.")
	clearStrikes:SetPoint("TOPLEFT", maintenancePane, "TOPLEFT", 0, -54)
	clearStrikes:SetScript("OnClick", function() Config:ClearSpamStrikes() end)
	local clearStrikesHint = Theme:CreateText(maintenancePane, "GameFontHighlightSmall", "textMuted")
	clearStrikesHint:SetPoint("LEFT", clearStrikes, "RIGHT", 10, 0)
	clearStrikesHint:SetText("Forget active mute strikes; existing bans stay in place.")
	self.spamClearBansButton = Theme:CreateButton(maintenancePane, "CLEAR BANS", 116, 22, false)
	setActionStyle(self.spamClearBansButton, "danger", "Clear all local bans", "Removes every locally saved Chatty ban after a second confirmation click.")
	self.spamClearBansButton:SetPoint("TOPLEFT", maintenancePane, "TOPLEFT", 0, -96)
	self.spamClearBansButton:SetScript("OnClick", function() Config:ClearSpamBans() end)
	local clearBansHint = Theme:CreateText(maintenancePane, "GameFontHighlightSmall", "textMuted")
	clearBansHint:SetPoint("LEFT", self.spamClearBansButton, "RIGHT", 10, 0)
	clearBansHint:SetText("Remove every local ban. The first click arms a five-second confirmation.")
	self.spamResetStatsButton = Theme:CreateButton(maintenancePane, "RESET STATS", 116, 22, false)
	setActionStyle(self.spamResetStatsButton, "quiet", "Reset session statistics", "Clears counters only; rules and bans remain unchanged.")
	self.spamResetStatsButton:SetPoint("TOPLEFT", maintenancePane, "TOPLEFT", 0, -138)
	self.spamResetStatsButton:SetScript("OnClick", function()
		if addon.SpamControl and addon.SpamControl.ResetStats then addon.SpamControl:ResetStats() end
		Config:RefreshSpamStatus()
	end)
	local resetStatsHint = Theme:CreateText(maintenancePane, "GameFontHighlightSmall", "textMuted")
	resetStatsHint:SetPoint("LEFT", self.spamResetStatsButton, "RIGHT", 10, 0)
	resetStatsHint:SetText("Clear BLOCKED / DUPLICATE / BURST counters only.")
	self.spamClearMemoryButton = Theme:CreateButton(maintenancePane, "CLEAR RECENT MEMORY", 150, 22, false)
	setActionStyle(self.spamClearMemoryButton, "quiet", "Forget recent spam memory", "Keeps rules and bans but clears recent duplicate and burst history.")
	self.spamClearMemoryButton:SetPoint("TOPLEFT", maintenancePane, "TOPLEFT", 0, -180)
	self.spamClearMemoryButton:SetScript("OnClick", function()
		if addon.SpamControl and addon.SpamControl.ResetForProfile then addon.SpamControl:ResetForProfile() end
		Config:RefreshSpamStatus()
		Config:SetSpamNotice("RECENT SPAM MEMORY CLEARED - BANS AND SETTINGS KEPT", "success")
	end)
	local clearMemoryHint = Theme:CreateText(maintenancePane, "GameFontHighlightSmall", "textMuted")
	clearMemoryHint:SetPoint("LEFT", self.spamClearMemoryButton, "RIGHT", 10, 0)
	clearMemoryHint:SetText("Forget recent duplicate and burst windows; bans stay in place.")

	self.spamBanNotice = Theme:CreateText(bansPane, "GameFontHighlightSmall", "textMuted")
	self.spamBanNotice:SetPoint("BOTTOMLEFT", bansPane, "BOTTOMLEFT", 0, 4)
	self.spamBanNotice:SetWidth(PAGE_WIDTH)
	self.spamBanNotice:SetJustifyH("LEFT")

	self.spamStatus = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	self.spamStatus:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", PAGE_GUTTER, 20)
	self.spamStatus:SetWidth(400)
	self.spamStatus:SetJustifyH("LEFT")
	self.spamBanPage = 1
	self.spamFilterMode = "protections"
	self.spamBanMode = "players"
	self:SetSpamSection(self.spamSection or "filters")
	self:RefreshSpamBans()
	self:RefreshSpamStatus()
	return page
end

local function getAlertSettings()
	local settings = addon:GetSmartSettings()
	settings.alerts = settings.alerts or {}
	local alerts = settings.alerts
	if alerts.enabled == nil then alerts.enabled = true end
	if alerts.popout == nil then alerts.popout = true end
	if alerts.sound == nil then alerts.sound = false end
	if alerts.autoHideSeconds == nil then alerts.autoHideSeconds = 12 end
	if type(alerts.rules) ~= "table" then alerts.rules = {} end
	return alerts
end

local function applyAlertRuntime()
	local engine = addon.AlertEngine
	if not engine then
		return
	end
	if engine.RefreshRules then engine:RefreshRules() end
	if engine.SetEnabled then engine:SetEnabled(getAlertSettings().enabled ~= false) end
end

local function getAlertRules()
	if addon.GetAlertRules then
		local ok, rules = pcall(addon.GetAlertRules, addon)
		if ok and type(rules) == "table" then
			return rules
		end
	end
	return {}
end

local function findAlertRule(ruleId)
	for _, rule in ipairs(getAlertRules()) do
		if rule.id == ruleId then
			return rule
		end
	end
	return nil
end

local function alertTermsText(terms)
	if type(terms) == "table" then
		return table.concat(terms, ", ")
	end
	return tostring(terms or "")
end

local function setTightButtonLabel(button, label)
	button:SetLabel(label)
	-- Current Theme buttons can measure the exact live font without reading a
	-- width-clipped FontString. Re-enable that shared behavior for dynamic labels
	-- such as CONFIRM DELETE and module destinations. The fallback remains for
	-- lightweight test hosts and older embedded Theme objects.
	if button.SetTextAutoFit then
		button:SetTextAutoFit(true)
		return
	end
	local previousWidth = button.text.GetWidth and button.text:GetWidth() or nil
	if button.text.SetWidth then button.text:SetWidth(4096) end
	local width = button.text.GetStringWidth and button.text:GetStringWidth() or (string.len(label or "") * 6)
	if previousWidth and button.text.SetWidth then button.text:SetWidth(previousWidth) end
	-- Five pixels per side protects live font rounding while retaining the
	-- settings console's compact density and an explicit border gutter.
	local minimumWidth = button.GetHeight and button:GetHeight() or 20
	button:SetWidth(math.max(minimumWidth, math.ceil(width or 0) + 10))
end

-- Lists use a real, separately clickable state box.  Prefixing a row label
-- with "[X]" made the state look interactive while the whole row merely opened
-- its editor.  Keeping the control separate gives the familiar compact X
-- behavior without making a click on the rule name unexpectedly pause it.
local function createListStateToggle(parent)
	local toggle = Theme:CreateCompactToggle(parent, "", 18)
	toggle.label:Hide()
	return toggle
end

function Config:SetAlertsStatus(text, colorName)
	if not self.alertsStatus then
		return
	end
	colorName = colorName or "textMuted"
	self.alertsStatus:SetText(text or "")
	Theme.texts[self.alertsStatus] = colorName
	local r, g, b, a = Theme:GetColor(colorName)
	self.alertsStatus:SetTextColor(r, g, b, a)
end

function Config:SetAlertRuleRowEnabled(ruleId, enabled)
	if not ruleId or not addon.UpdateAlertRule then
		return false
	end
	local ok, rule, reason = pcall(addon.UpdateAlertRule, addon, ruleId, {
		enabled = enabled and true or false,
	})
	if not ok or type(rule) ~= "table" then
		self:SetAlertsStatus(tostring((ok and reason) or rule or "Alert state could not be changed."), "danger")
		self:RefreshAlertsPage(true)
		return false
	end
	applyAlertRuntime()
	self:RefreshAlertsPage(true)
	self:SetAlertsStatus(enabled and "Alert enabled." or "Alert paused; its rule is preserved.", enabled and "success" or "warning")
	return true
end

function Config:RefreshAlertStats()
	if not self.alertStats then
		return
	end
	local stats = {}
	if addon.AlertEngine and addon.AlertEngine.GetStats then
		local ok, result = pcall(addon.AlertEngine.GetStats, addon.AlertEngine)
		if ok and type(result) == "table" then stats = result end
	end
	local matches = tonumber(stats.matches) or 0
	local records = tonumber(stats.matchedRecords) or 0
	self.alertStats:SetText("MATCHES  " .. matches .. "   MESSAGES  " .. records)
	local colorName = matches > 0 and "warning" or "textMuted"
	Theme.texts[self.alertStats] = colorName
	local r, g, b, a = Theme:GetColor(colorName)
	self.alertStats:SetTextColor(r, g, b, a)
end

function Config:GetAlertSourceDefinitions(ruleId)
	if addon.GetAlertSourceDefinitions then
		local ok, sources = pcall(addon.GetAlertSourceDefinitions, addon, ruleId)
		if ok and type(sources) == "table" then
			return sources
		end
	end
	return {}
end

function Config:SetAlertEditorEnabled(enabled)
	local controls = self.alertEditorControls or {}
	for _, control in ipairs(controls) do
		if enabled and control.Enable then control:Enable() elseif not enabled and control.Disable then control:Disable() end
	end
end

function Config:RefreshAlertInspectorPane()
	local mode = self.alertInspectorMode
	if mode ~= "notify" and mode ~= "sources" and mode ~= "global" then
		mode = "words"
	end
	self.alertInspectorMode = mode
	for paneId, pane in pairs(self.alertInspectorPanes or {}) do
		if paneId == mode then pane:Show() else pane:Hide() end
	end
	for paneId, button in pairs(self.alertInspectorButtons or {}) do
		setTabStyle(button, paneId == mode)
	end
	if self.alertEditorTitle then
		local rule = findAlertRule(self.selectedAlertRuleId)
		if mode == "global" then
			self.alertEditorTitle:SetText("GLOBAL ALERT SETTINGS")
		elseif rule then
			self.alertEditorTitle:SetText("EDIT " .. string.upper(rule.name or rule.id))
		else
			self.alertEditorTitle:SetText("NO ALERT SELECTED")
		end
	end
end

function Config:SetAlertInspectorPane(mode)
	if mode ~= "words" and mode ~= "notify" and mode ~= "sources" and mode ~= "global" then
		return
	end
	self.alertInspectorMode = mode
	self:RefreshAlertInspectorPane()
end

function Config:RefreshAlertNotifyHelp()
	local alerts = getAlertSettings()
	if self.alertRevealGateHint then
		self.alertRevealGateHint:SetText(alerts.popout == false
			and "GLOBAL CHAT REVEAL is off, so this rule cannot reveal the chat window until that gate is enabled."
			or "GLOBAL CHAT REVEAL allows this rule to reveal the chat window when it matches.")
	end
	if self.alertSoundGateHint then
		self.alertSoundGateHint:SetText(alerts.sound == true
			and "SOUND FOR ALL is on. Every matching rule plays a sound even when this rule switch is off."
			or "SOUND FOR ALL is off. Turn this on to play a sound only for this rule.")
	end
end

function Config:SetAlertSourcePager(button, visible, enabled)
	if not button then return end
	if not visible then
		button:Hide()
		return
	end
	button:Show()
	if enabled then
		button:Enable()
		button:SetAlpha(1)
	else
		button:Disable()
		button:SetAlpha(0.35)
	end
end

function Config:RefreshAlertSources()
	if not self.alertSourceRows then
		return
	end
	local rule = findAlertRule(self.selectedAlertRuleId)
	if not rule then
		for _, row in ipairs(self.alertSourceRows) do row.sourceId = nil row:Hide() end
		self.alertSourceCount:SetText("NO RULE SELECTED")
		self:SetAlertSourcePager(self.alertSourcePrevious, false, false)
		self:SetAlertSourcePager(self.alertSourceNext, false, false)
		if self.alertSourceHint then self.alertSourceHint:SetText("Create an alert to choose its channels.") end
		return
	end
	if rule.allSources ~= false then
		for _, row in ipairs(self.alertSourceRows) do row.sourceId = nil row:Hide() end
		self.alertSourceCount:SetText("ALL SOURCES")
		self:SetAlertSourcePager(self.alertSourcePrevious, false, false)
		self:SetAlertSourcePager(self.alertSourceNext, false, false)
		if self.alertSourceHint then self.alertSourceHint:SetText("Turn off ALL SOURCES to choose exact channels.") end
		return
	end
	if self.alertSourceHint then self.alertSourceHint:SetText("Only checked sources can trigger this rule.") end
	local sources = self:GetAlertSourceDefinitions(rule.id)
	local pageSize = #self.alertSourceRows
	local pageCount = math.max(1, math.ceil(#sources / pageSize))
	self.alertSourcePage = math.max(1, math.min(self.alertSourcePage or 1, pageCount))
	local startIndex = ((self.alertSourcePage - 1) * pageSize) + 1
	for rowIndex = 1, pageSize do
		local row = self.alertSourceRows[rowIndex]
		local source = sources[startIndex + rowIndex - 1]
		if source then
			row.sourceId = source.id or source.sourceId
			row.label:SetText(source.label or source.sourceLabel or row.sourceId or "Source")
			row:SetValue(source.selected == true, true)
			row:Show()
		else
			row.sourceId = nil
			row:Hide()
		end
	end
	if #sources == 0 then
		self.alertSourceCount:SetText("NO SOURCES OBSERVED")
	else
		local lastIndex = math.min(#sources, startIndex + pageSize - 1)
		self.alertSourceCount:SetText(pageCount > 1 and (startIndex .. "-" .. lastIndex .. " / " .. #sources) or (#sources .. " SOURCES"))
	end
	self:SetAlertSourcePager(self.alertSourcePrevious, pageCount > 1, self.alertSourcePage > 1)
	self:SetAlertSourcePager(self.alertSourceNext, pageCount > 1, self.alertSourcePage < pageCount)
end

function Config:LoadAlertEditor(ruleId)
	local rule = findAlertRule(ruleId)
	if not rule or not self.alertNameEdit then
		self.selectedAlertRuleId = nil
		self.alertEditorTitle:SetText("NO ALERT SELECTED")
		self.alertNameEdit:SetText("")
		self.alertTermsEdit:SetText("")
		self.alertEnabledToggle:SetValue(false, true)
		self.alertMatchAllToggle:SetValue(false, true)
		self.alertAllSourcesToggle:SetValue(true, true)
		self.alertRevealToggle:SetValue(false, true)
		self.alertRuleSoundToggle:SetValue(false, true)
		self:SetAlertEditorEnabled(false)
		if self.alertDeleteButton then
			setTightButtonLabel(self.alertDeleteButton, "DELETE")
			self.alertDeleteButton:Disable()
		end
		self:RefreshAlertSources()
		self:RefreshAlertNotifyHelp()
		self:RefreshAlertInspectorPane()
		return false
	end
	self.selectedAlertRuleId = rule.id
	self.alertEditorTitle:SetText("EDIT " .. string.upper(rule.name or rule.id))
	self.alertNameEdit:SetText(rule.name or "")
	self.alertTermsEdit:SetText(alertTermsText(rule.terms))
	self.alertEnabledToggle:SetValue(rule.enabled ~= false, true)
	self.alertMatchAllToggle:SetValue(rule.matchAll == true, true)
	self.alertAllSourcesToggle:SetValue(rule.allSources ~= false, true)
	self.alertRevealToggle:SetValue(rule.revealDock ~= false, true)
	self.alertRuleSoundToggle:SetValue(rule.sound == true, true)
	self:SetAlertEditorEnabled(true)
	if self.alertDeleteButton then self.alertDeleteButton:Enable() end
	if self.pendingDeleteAlertId ~= rule.id then
		self.pendingDeleteAlertId = nil
		setTightButtonLabel(self.alertDeleteButton, "DELETE")
	end
	self:RefreshAlertSources()
	self:RefreshAlertNotifyHelp()
	self:RefreshAlertInspectorPane()
	return true
end

function Config:SelectAlertRule(ruleId)
	self.alertSourcePage = 1
	self.alertInspectorMode = "words"
	self.pendingDeleteAlertId = nil
	if self:LoadAlertEditor(ruleId) then
		self:SetAlertsStatus("Edit the terms and exact sources for this alert.", "textMuted")
	end
	self:RefreshAlertsPage(true)
end

function Config:NewAlertRule()
	if not addon.CreateAlertRule then
		self:SetAlertsStatus("Alert rule creation is unavailable in this build.", "danger")
		return
	end
	local ok, rule, err = pcall(addon.CreateAlertRule, addon, {})
	if not ok or type(rule) ~= "table" then
		self:SetAlertsStatus(tostring((ok and err) or rule or "The alert could not be created."), "danger")
		return
	end
	self.selectedAlertRuleId = rule.id
	self.alertRulePage = math.max(1, math.ceil(#getAlertRules() / #self.alertRows))
	self.alertSourcePage = 1
	self.alertInspectorMode = "words"
	applyAlertRuntime()
	self:RefreshAlertsPage(true)
	self:SetAlertsStatus("New alert created. Add comma-separated words, or use [PLAYER_NAME] for your current character.", "success")
	self.alertNameEdit:SetFocus()
end

function Config:AddPlayerNameToAlertTerms()
	if not self.selectedAlertRuleId then
		self:SetAlertsStatus("Create or select an alert first.", "warning")
		return false
	end
	local terms = parseTerms(self.alertTermsEdit:GetText())
	local found = false
	for _, term in ipairs(terms) do
		local normalized = string.lower(trim(term))
		if normalized == "[player_name]" or normalized == "[player]" then
			found = true
			break
		end
	end
	if not found then
		if #terms >= 24 then
			self:SetAlertsStatus("This alert already has the maximum 24 terms.", "warning")
			return false
		end
		table.insert(terms, "[PLAYER_NAME]")
	end
	self.alertTermsEdit:SetText(table.concat(terms, ", "))
	if trim(self.alertNameEdit:GetText()) == "" then
		self.alertNameEdit:SetText("YOUR NAME")
	end
	return self:SaveAlertRule(false)
end

function Config:SaveAlertRule(quiet)
	if not self.selectedAlertRuleId or not addon.UpdateAlertRule then
		if not quiet then self:SetAlertsStatus("Select or create an alert first.", "danger") end
		return false
	end
	local name = trim(self.alertNameEdit:GetText())
	local terms = parseTerms(self.alertTermsEdit:GetText())
	if name == "" then
		if not quiet then self:SetAlertsStatus("An alert name is required.", "danger") end
		return false
	end
	local data = {
		name = name,
		terms = terms,
		enabled = self.alertEnabledToggle.checked == true,
		matchAll = self.alertMatchAllToggle.checked == true,
		allSources = self.alertAllSourcesToggle.checked == true,
		revealDock = self.alertRevealToggle.checked == true,
		sound = self.alertRuleSoundToggle.checked == true,
	}
	local ok, rule, err = pcall(addon.UpdateAlertRule, addon, self.selectedAlertRuleId, data)
	if not ok or type(rule) ~= "table" then
		if not quiet then self:SetAlertsStatus(tostring((ok and err) or rule or "The alert could not be saved."), "danger") end
		return false
	end
	self.pendingDeleteAlertId = nil
	applyAlertRuntime()
	self:RefreshAlertsPage(true)
	if not quiet then self:SetAlertsStatus("Alert saved and active immediately.", "success") end
	return true
end

function Config:DeleteAlertRule()
	if not self.selectedAlertRuleId or not addon.DeleteAlertRule then
		return
	end
	if self.pendingDeleteAlertId ~= self.selectedAlertRuleId then
		self.pendingDeleteAlertId = self.selectedAlertRuleId
		setTightButtonLabel(self.alertDeleteButton, "CONFIRM DELETE")
		self:SetAlertsStatus("Click CONFIRM DELETE to remove this rule.", "warning")
		return
	end
	local deletedId = self.selectedAlertRuleId
	local ok, result, err = pcall(addon.DeleteAlertRule, addon, deletedId)
	if not ok or result ~= true then
		self:SetAlertsStatus(tostring((ok and err) or result or "The alert could not be deleted."), "danger")
		return
	end
	self.pendingDeleteAlertId = nil
	self.selectedAlertRuleId = nil
	applyAlertRuntime()
	self:RefreshAlertsPage(true)
	self:SetAlertsStatus("Alert deleted.", "success")
end

function Config:ResetAlertSources()
	if not self.selectedAlertRuleId or not addon.ResetAlertRuleSources then
		return
	end
	local ok, result, err = pcall(addon.ResetAlertRuleSources, addon, self.selectedAlertRuleId)
	if not ok or result ~= true then
		self:SetAlertsStatus(tostring((ok and err) or result or "Sources could not be reset."), "danger")
		return
	end
	applyAlertRuntime()
	self:RefreshAlertsPage(true)
	self:SetAlertsStatus("This alert now watches every source.", "success")
end

function Config:RefreshAlertsPage(keepStatus)
	if not self.alertsPage then
		return
	end
	local alerts = getAlertSettings()
	self.alertGlobalEnabledToggle:SetValue(alerts.enabled ~= false, true)
	self.alertGlobalPopoutToggle:SetValue(alerts.popout ~= false, true)
	self.alertGlobalSoundToggle:SetValue(alerts.sound ~= false, true)
	self.alertAutoHideEdit:SetText(tostring(clampNumber(alerts.autoHideSeconds, 0, 120, 12)))
	self:RefreshAlertNotifyHelp()
	local rules = getAlertRules()
	local pageSize = #self.alertRows
	local pageCount = math.max(1, math.ceil(#rules / pageSize))
	self.alertRulePage = math.max(1, math.min(self.alertRulePage or 1, pageCount))
	local startIndex = ((self.alertRulePage - 1) * pageSize) + 1
	if not findAlertRule(self.selectedAlertRuleId) and rules[startIndex] then self.selectedAlertRuleId = rules[startIndex].id end
	for rowIndex = 1, pageSize do
		local row = self.alertRows[rowIndex]
		local rule = rules[startIndex + rowIndex - 1]
		if rule then
			row.ruleId = rule.id
			row.stateToggle.ruleId = rule.id
			row.stateToggle:SetValue(rule.enabled ~= false, true)
			row:SetLabel(rule.name or rule.id)
			local selected = rule.id == self.selectedAlertRuleId
			setChoiceStyle(row, selected)
			row:Show()
		else
			row.ruleId = nil
			row.stateToggle.ruleId = nil
			row:Hide()
		end
	end
	if #rules == 0 then
		self.alertRuleCount:SetText("No alert rules")
	else
		local lastIndex = math.min(#rules, startIndex + pageSize - 1)
		self.alertRuleCount:SetText(startIndex .. "-" .. lastIndex .. " / " .. #rules)
	end
	if pageCount > 1 then
		self.alertRulePrevious:Show()
		self.alertRuleNext:Show()
		if self.alertRulePage > 1 then self.alertRulePrevious:Enable() else self.alertRulePrevious:Disable() end
		if self.alertRulePage < pageCount then self.alertRuleNext:Enable() else self.alertRuleNext:Disable() end
	else
		self.alertRulePrevious:Hide()
		self.alertRuleNext:Hide()
	end
	self:LoadAlertEditor(self.selectedAlertRuleId)
	self:RefreshAlertInspectorPane()
	self:RefreshAlertStats()
	if not keepStatus then self:SetAlertsStatus("Click the X to pause a rule; click its name to edit it.", "textMuted") end
end

-- Semantic Routes deliberately owns only the optional text inference layer.
-- Event/source routes (party, whispers, loot, and so on) are factual and do
-- not belong behind an on/off switch.  The classifier is loaded separately,
-- so every API below is feature-detected and the page remains safe during an
-- update where an older MessageEngine is still present.
local SEMANTIC_ROUTE_OPTIONS = {
	{ id = "groupFinder", label = "GROUP FINDER", description = "LF/LFM, roles, dungeons, raids, and keystones." },
	{ id = "trade", label = "TRADE", description = "Buying, selling, prices, and services." },
	{ id = "pvp", label = "PVP", description = "Battleground, arena, queue, rating, and objective terms." },
}

local function semanticRouteCall(method, ...)
	local callback = addon[method]
	if type(callback) ~= "function" then
		return false, nil
	end
	local ok, result = pcall(callback, addon, ...)
	return ok, result
end

local function semanticRouteLabel(category)
	if category == "groupFinder" then return "GROUP FINDER" end
	if category == "guildInvites" then return "GUILD INVITES" end
	if category == "newcomers" then return "NEWCOMERS" end
	if category == "pvp" then return "PVP" end
	if category == "trade" then return "TRADE" end
	if category == "general" then return "GENERAL" end
	return type(category) == "string" and string.upper(category) or "GENERAL"
end

local function semanticRouteSignals(analysis, category)
	local values = analysis and (analysis.signals or analysis.evidence or analysis.reasons)
	if type(values) == "string" then return values end
	-- The weighted engine reports signals by candidate route, while the legacy
	-- inspector reports one flat list. Accept both shapes so this UI can remain
	-- a small consumer rather than duplicating classifier knowledge.
	if type(values) == "table" and type(values[category]) == "table" then
		values = values[category]
	end
	if type(values) == "table" and #values == 0 then
		-- A General result has no candidate named "general". Keep the useful
		-- partial evidence visible instead of making a close-but-insufficient
		-- Group Finder message look unexplained.
		local candidates = {}
		for _, routeId in ipairs({ "groupFinder", "trade", "pvp" }) do
			local candidate = values[routeId]
			if type(candidate) == "table" and #candidate > 0 then
				local compact = {}
				for index = 1, math.min(#candidate, 2) do
					local signal = tostring(candidate[index] or "")
					if string.len(signal) > 52 then signal = string.sub(signal, 1, 49) .. "..." end
					if signal ~= "" then table.insert(compact, signal) end
				end
				if #compact > 0 then
					table.insert(candidates, semanticRouteLabel(routeId) .. ": " .. table.concat(compact, ", "))
				end
			end
		end
		if #candidates > 0 then return table.concat(candidates, "\n") end
	end
	if type(values) ~= "table" or #values == 0 then return "No weighted evidence was returned." end
	local copy = {}
	for index = 1, math.min(#values, 3) do
		if type(values[index]) == "string" and values[index] ~= "" then
			local signal = values[index]
			if string.len(signal) > 52 then signal = string.sub(signal, 1, 49) .. "..." end
			table.insert(copy, signal)
		end
	end
	return #copy > 0 and table.concat(copy, "  |  ") or "No weighted evidence was returned."
end

function Config:GetSemanticRouteEnabled(routeId)
	local called, value = semanticRouteCall("GetSemanticRouteEnabled", routeId)
	if called and type(value) == "boolean" then
		return value, true
	end
	local settingsCalled, settings = semanticRouteCall("GetSemanticRouteSettings")
	if settingsCalled and type(settings) == "table" then
		local enabled = settings.enabled
		if type(enabled) == "table" and type(enabled[routeId]) == "boolean" then
			return enabled[routeId], true
		end
		if type(settings[routeId]) == "boolean" then
			return settings[routeId], true
		end
	end
	return false, false
end

function Config:SetSemanticRouteEnabled(routeId, enabled)
	local called, saved = semanticRouteCall("SetSemanticRouteEnabled", routeId, enabled and true or false)
	if called and saved ~= false then
		self:SetSemanticRoutesStatus(semanticRouteLabel(routeId) .. (enabled and " inference enabled." or " inference disabled; direct chat routes are unchanged."), "success")
		self:RefreshSemanticRoutesPage(true)
		return true
	end
	self:SetSemanticRoutesStatus("Semantic route controls are unavailable until the classifier loads.", "warning")
	self:RefreshSemanticRoutesPage(true)
	return false
end

function Config:SetSemanticRoutesStatus(text, colorName)
	if not self.semanticRoutesStatus then return end
	self.semanticRoutesStatus:SetText(text or "")
	local r, g, b, a = Theme:GetColor(colorName or "textMuted")
	self.semanticRoutesStatus:SetTextColor(r, g, b, a)
end

function Config:AnalyzeSemanticRouteText()
	if not self.semanticRoutesTestInput or not self.semanticRoutesResult then return end
	local text = self.semanticRoutesTestInput:GetText()
	text = type(text) == "string" and string.gsub(text, "^%s*(.-)%s*$", "%1") or ""
	if text == "" then
		self.semanticRoutesResult:SetText("TYPE A SAMPLE MESSAGE, THEN CHOOSE ANALYZE.")
		self:SetSemanticRoutesStatus("Nothing was analyzed.", "warning")
		return
	end

	local called, analysis = semanticRouteCall("AnalyzeSemanticRoute", text, "General")
	-- Older builds can still explain their current simple classifier. This path
	-- is read-only: it never inserts a chat record or changes a route.
	if (not called or type(analysis) ~= "table") and addon.MessageEngine and addon.MessageEngine.AnalyzeRecord then
		local ok, result = pcall(addon.MessageEngine.AnalyzeRecord, addon.MessageEngine, {
			event = "CHAT_MSG_CHANNEL", text = text, normalized = string.lower(text), channel = "General",
		})
		if ok then analysis = result end
	end
	if type(analysis) ~= "table" then
		self.semanticRoutesResult:SetText("ANALYZER UNAVAILABLE")
		self.semanticRoutesEvidence:SetText("The classifier has not loaded yet. Reload once the update is installed.")
		self:SetSemanticRoutesStatus("Semantic analysis is unavailable in this build.", "warning")
		return
	end

	local category = analysis.category or analysis.route or "general"
	local threshold = analysis.threshold
	if type(threshold) == "table" then threshold = threshold[category] end
	threshold = tonumber(threshold)
	local score, scoreDetail
	if type(analysis.scores) == "table" then
		score = analysis.scores[category]
		if score == nil then
			scoreDetail = "LFG " .. tostring(analysis.scores.groupFinder or 0)
				.. "  T " .. tostring(analysis.scores.trade or 0)
				.. "  PVP " .. tostring(analysis.scores.pvp or 0)
		end
	end
	local detail = "ROUTE: " .. semanticRouteLabel(category)
	if score then detail = detail .. "  -  SCORE " .. tostring(score) end
	if scoreDetail then detail = detail .. "  -  SCORES " .. scoreDetail end
	if threshold then detail = detail .. " / " .. tostring(threshold) end
	self.semanticRoutesResult:SetText(detail)
	self.semanticRoutesEvidence:SetText(semanticRouteSignals(analysis, category))
	self:SetSemanticRoutesStatus("Analysis is read-only. Shift > ANALYZE saves a primary route; checked source feeds remain visible.", "textMuted")
end

function Config:RefreshSemanticRoutesPage(keepStatus)
	if not self.semanticRoutesPage then return end
	local available = false
	for index = 1, #SEMANTIC_ROUTE_OPTIONS do
		local option = SEMANTIC_ROUTE_OPTIONS[index]
		local enabled, supported = self:GetSemanticRouteEnabled(option.id)
		available = available or supported
		local toggle = self.semanticRouteToggles and self.semanticRouteToggles[option.id]
		if toggle then
			toggle:SetValue(enabled, true)
			toggle:EnableMouse(supported)
			toggle:SetAlpha(supported and 1 or 0.45)
		end
	end
	if self.semanticRoutesAvailability then
		self.semanticRoutesAvailability:SetText(available
			and "Inference is optional. Defense, LookingForGroup, and GuildRecruitment sources remain direct."
			or "Waiting for the semantic classifier. Direct event and channel routes continue normally.")
	end
	if not keepStatus then
		self:SetSemanticRoutesStatus(available
			and "Higher-confidence combinations route automatically; inspect any live line with Shift > ANALYZE."
			or "Classifier controls will appear automatically when the routing engine is available.", available and "textMuted" or "warning")
	end
end

function Config:BuildSemanticRoutesPage()
	local page = self:CreatePage("semantic")
	self.semanticRoutesPage = page
	createHeading(page, "Semantic Routes", "Scores message topics for Group Finder, Trade, and PVP. Dedicated Defense, LFG, and guild-recruitment sources remain direct.")

	local work = createQuietShellPanel(page, "surface")
	work:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -PAGE_TOP)
	work:SetSize(PAGE_WIDTH, 214)

	local routeTitle = Theme:CreateText(work, "GameFontNormalSmall", "gold")
	routeTitle:SetPoint("TOPLEFT", work, "TOPLEFT", 8, -7)
	routeTitle:SetText("AUTOMATIC INFERENCE")
	self.semanticRouteToggles = {}
	for index = 1, #SEMANTIC_ROUTE_OPTIONS do
		local option = SEMANTIC_ROUTE_OPTIONS[index]
		local toggle = Theme:CreateCompactToggle(work, option.label, 158)
		toggle:SetPoint("TOPLEFT", work, "TOPLEFT", 8 + ((index - 1) * 166), -28)
		toggle.OnValueChanged = function(_, value)
			Config:SetSemanticRouteEnabled(option.id, value)
		end
		self.semanticRouteToggles[option.id] = toggle
		local description = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
		description:SetPoint("TOPLEFT", toggle, "BOTTOMLEFT", 0, -1)
		description:SetWidth(154)
		description:SetJustifyH("LEFT")
		description:SetText(option.description)
	end
	self.semanticRoutesAvailability = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	self.semanticRoutesAvailability:SetPoint("TOPLEFT", work, "TOPLEFT", 8, -80)
	self.semanticRoutesAvailability:SetWidth(PAGE_WIDTH - 16)
	self.semanticRoutesAvailability:SetJustifyH("LEFT")

	local testTitle = Theme:CreateText(work, "GameFontNormalSmall", "gold")
	testTitle:SetPoint("TOPLEFT", work, "TOPLEFT", 8, -106)
	testTitle:SetText("TEST A MESSAGE")
	self.semanticRoutesTestInput = Theme:CreateEditBox(work, 452, 22, false)
	self.semanticRoutesTestInput:SetPoint("TOPLEFT", work, "TOPLEFT", 8, -125)
	self.semanticRoutesTestInput:SetMaxLetters(240)
	self.semanticRoutesTestInput:SetText("LF tank / DPS [Keystone: example]")
	self.semanticRoutesTestInput:HookScript("OnEnterPressed", function(self)
		self:ClearFocus()
		Config:AnalyzeSemanticRouteText()
	end)
	local analyze = Theme:CreateTightButton(work, "ANALYZE", 22, true)
	setActionStyle(analyze, "primary", "Analyze this message", "Shows the evidence and score without moving or blocking anything.")
	analyze:SetPoint("LEFT", self.semanticRoutesTestInput, "RIGHT", CONTROL_GAP, 0)
	analyze:SetScript("OnClick", function() Config:AnalyzeSemanticRouteText() end)

	self.semanticRoutesResult = Theme:CreateText(work, "GameFontNormalSmall", "goldBright")
	self.semanticRoutesResult:SetPoint("TOPLEFT", work, "TOPLEFT", 8, -153)
	self.semanticRoutesEvidence = Theme:CreateText(work, "GameFontHighlightSmall", "text")
	self.semanticRoutesEvidence:SetPoint("TOPLEFT", self.semanticRoutesResult, "BOTTOMLEFT", 0, -2)
	self.semanticRoutesEvidence:SetWidth(PAGE_WIDTH - 16)
	self.semanticRoutesEvidence:SetJustifyH("LEFT")
	self.semanticRoutesStatus = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	self.semanticRoutesStatus:SetPoint("TOPLEFT", work, "BOTTOMLEFT", 2, -6)
	self.semanticRoutesStatus:SetWidth(PAGE_WIDTH - 4)
	self.semanticRoutesStatus:SetJustifyH("LEFT")

	self:RefreshSemanticRoutesPage()
	self:AnalyzeSemanticRouteText()
	return page
end

function Config:BuildAlertsPage()
	local page = self:CreatePage("alerts")
	self.alertsPage = page
	createHeading(page, "Alerts", "Choose an alert, then define its words, notification behavior, and allowed chat sources.")

	local work = createQuietShellPanel(page, "surface")
	work:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -PAGE_TOP)
	work:SetSize(PAGE_WIDTH, 390)
	local alerts = getAlertSettings()

	self.alertGlobalEnabledToggle = Theme:CreateCompactToggle(work, "ALERTS ON", 104)
	self.alertGlobalEnabledToggle:SetPoint("TOPLEFT", work, "TOPLEFT", 6, -4)
	self.alertGlobalEnabledToggle.OnValueChanged = function(_, value)
		alerts.enabled = value and true or false
		applyAlertRuntime()
		Config:SetAlertsStatus("Global alert state applied.", "success")
	end
	setControlTooltip(self.alertGlobalEnabledToggle, "Enable alerts", "Turns the complete alert system on or off without deleting any rules.")
	local masterHint = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	masterHint:SetPoint("LEFT", self.alertGlobalEnabledToggle, "RIGHT", 8, 0)
	masterHint:SetText("Rules stay saved when alerts are off. Global notification defaults are under GLOBAL.")

	local divider = work:CreateTexture(nil, "ARTWORK")
	divider:SetTexture("Interface\\Buttons\\WHITE8x8")
	Theme:RegisterTexture(divider, "borderMuted")
	divider:SetPoint("TOPLEFT", work, "TOPLEFT", 176, -28)
	divider:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 176, 1)
	divider:SetWidth(1)

	local listTitle = Theme:CreateText(work, "GameFontNormalSmall", "gold")
	listTitle:SetPoint("TOPLEFT", work, "TOPLEFT", 8, -34)
	listTitle:SetText("ALERT RULES")
	local newRule = Theme:CreateTightButton(work, "NEW", 22, true)
	setActionStyle(newRule, "primary", "Create an alert", "Creates a rule you can name, give words, and limit to selected sources.")
	newRule:SetPoint("TOPRIGHT", work, "TOPLEFT", 168, -29)
	newRule:SetScript("OnClick", function() Config:NewAlertRule() end)
	self.alertRows = {}
	for index = 1, 8 do
		local row = Theme:CreateButton(work, "", 160, 22, false)
		row:SetPoint("TOPLEFT", work, "TOPLEFT", 8, -54 - ((index - 1) * 23))
		row.stateToggle = createListStateToggle(row)
		row.stateToggle:SetPoint("LEFT", row, "LEFT", 2, 0)
		setControlTooltip(row.stateToggle, "Pause or resume this rule", "The rule stays saved when paused. Click the rest of the row to inspect it.")
		row.stateToggle.OnValueChanged = function(toggle, value)
			if toggle.ruleId then
				Config:SetAlertRuleRowEnabled(toggle.ruleId, value)
			end
		end
		row.text:ClearAllPoints()
		row.text:SetPoint("LEFT", row, "LEFT", 22, 0)
		row.text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		row.text:SetJustifyH("LEFT")
		row:SetScript("OnClick", function(self)
			if self.ruleId then Config:SelectAlertRule(self.ruleId) end
		end)
		table.insert(self.alertRows, row)
	end
	self.alertRuleCount = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	self.alertRuleCount:SetPoint("TOPLEFT", work, "TOPLEFT", 8, -248)
	self.alertRuleCount:SetWidth(82)
	self.alertRulePrevious = Theme:CreateTightButton(work, "<", 20, false)
	self.alertRulePrevious:SetPoint("TOPLEFT", work, "TOPLEFT", 94, -242)
	self.alertRulePrevious:SetScript("OnClick", function()
		Config.alertRulePage = math.max(1, (Config.alertRulePage or 1) - 1)
		local rules = getAlertRules()
		local first = rules[((Config.alertRulePage - 1) * #Config.alertRows) + 1]
		if first then Config.selectedAlertRuleId = first.id end
		Config:RefreshAlertsPage(true)
	end)
	self.alertRuleNext = Theme:CreateTightButton(work, ">", 20, false)
	self.alertRuleNext:SetPoint("LEFT", self.alertRulePrevious, "RIGHT", CONTROL_GAP, 0)
	self.alertRuleNext:SetScript("OnClick", function()
		Config.alertRulePage = (Config.alertRulePage or 1) + 1
		local rules = getAlertRules()
		local first = rules[((Config.alertRulePage - 1) * #Config.alertRows) + 1]
		if first then Config.selectedAlertRuleId = first.id end
		Config:RefreshAlertsPage(true)
	end)
	self.alertStats = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	self.alertStats:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 8, 34)
	self.alertStats:SetWidth(160)
	self.alertStats:SetJustifyH("LEFT")
	local resetStats = Theme:CreateTightButton(work, "RESET STATS", 20, false)
	setActionStyle(resetStats, "quiet", "Reset alert counters", "Clears only the displayed match counters. Alert rules are unchanged.")
	resetStats:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 8, 7)
	resetStats:SetScript("OnClick", function()
		if addon.AlertEngine and addon.AlertEngine.ResetStats then addon.AlertEngine:ResetStats() end
		Config:RefreshAlertStats()
	end)

	self.alertEditorTitle = Theme:CreateText(work, "GameFontNormalSmall", "gold")
	self.alertEditorTitle:SetPoint("TOPLEFT", work, "TOPLEFT", 188, -34)
	self.alertEditorTitle:SetWidth(422)
	self.alertEditorTitle:SetJustifyH("LEFT")

	self.alertInspectorButtons = {}
	self.alertInspectorPanes = {}
	local wordsTab = Theme:CreateTightButton(work, "WORDS", 20, false)
	wordsTab:SetPoint("TOPLEFT", work, "TOPLEFT", 188, -52)
	wordsTab:SetScript("OnClick", function() Config:SetAlertInspectorPane("words") end)
	setActionStyle(wordsTab, "choice", "Words to watch", "Name this rule and choose the words or phrases that trigger it.")
	self.alertInspectorButtons.words = wordsTab
	local notifyTab = Theme:CreateTightButton(work, "NOTIFY", 20, false)
	notifyTab:SetPoint("LEFT", wordsTab, "RIGHT", CONTROL_GAP, 0)
	notifyTab:SetScript("OnClick", function() Config:SetAlertInspectorPane("notify") end)
	setActionStyle(notifyTab, "choice", "Notification for this rule", "Choose whether this one rule reveals chat or plays a sound when it matches.")
	self.alertInspectorButtons.notify = notifyTab
	local sourcesTab = Theme:CreateTightButton(work, "SOURCES", 20, false)
	sourcesTab:SetPoint("LEFT", notifyTab, "RIGHT", CONTROL_GAP, 0)
	sourcesTab:SetScript("OnClick", function() Config:SetAlertInspectorPane("sources") end)
	setActionStyle(sourcesTab, "choice", "Sources for this rule", "Watch every source or limit this alert to exact chat sources.")
	self.alertInspectorButtons.sources = sourcesTab
	local globalTab = Theme:CreateTightButton(work, "GLOBAL BEHAVIOR", 20, false)
	globalTab:SetPoint("LEFT", sourcesTab, "RIGHT", CONTROL_GAP, 0)
	globalTab:SetScript("OnClick", function() Config:SetAlertInspectorPane("global") end)
	setActionStyle(globalTab, "choice", "Global notification behavior", "Set the reveal gate, sound-for-all override, and automatic hide time shared by alert rules.")
	self.alertInspectorButtons.global = globalTab

	local wordsPane = CreateFrame("Frame", nil, work)
	wordsPane:SetPoint("TOPLEFT", work, "TOPLEFT", 188, -82)
	wordsPane:SetSize(422, 254)
	self.alertInspectorPanes.words = wordsPane
	local notifyPane = CreateFrame("Frame", nil, work)
	notifyPane:SetPoint("TOPLEFT", work, "TOPLEFT", 188, -82)
	notifyPane:SetSize(422, 254)
	self.alertInspectorPanes.notify = notifyPane
	local sourcesPane = CreateFrame("Frame", nil, work)
	sourcesPane:SetPoint("TOPLEFT", work, "TOPLEFT", 188, -82)
	sourcesPane:SetSize(422, 254)
	self.alertInspectorPanes.sources = sourcesPane
	local globalPane = CreateFrame("Frame", nil, work)
	globalPane:SetPoint("TOPLEFT", work, "TOPLEFT", 188, -82)
	globalPane:SetSize(422, 254)
	self.alertInspectorPanes.global = globalPane

	local nameLabel = Theme:CreateText(wordsPane, "GameFontHighlightSmall", "textMuted")
	nameLabel:SetPoint("TOPLEFT", wordsPane, "TOPLEFT", 0, 0)
	nameLabel:SetText("NAME")
	self.alertNameEdit = Theme:CreateEditBox(wordsPane, 220, 22, false)
	self.alertNameEdit:SetPoint("TOPLEFT", wordsPane, "TOPLEFT", 0, -14)
	self.alertNameEdit:SetMaxLetters(40)
	setControlTooltip(self.alertNameEdit, "Alert name", "A short label used in the alert rule list and match statistics.")
	self.alertEnabledToggle = Theme:CreateCompactToggle(wordsPane, "ENABLED", 104)
	self.alertEnabledToggle:SetPoint("TOPLEFT", wordsPane, "TOPLEFT", 232, -13)
	setControlTooltip(self.alertEnabledToggle, "Enable this alert", "Pausing one alert keeps the rule saved while stopping its matches.")
	local termsLabel = Theme:CreateText(wordsPane, "GameFontHighlightSmall", "textMuted")
	termsLabel:SetPoint("TOPLEFT", wordsPane, "TOPLEFT", 0, -44)
	termsLabel:SetText("WORDS OR PHRASES  -  SEPARATE WITH COMMAS")
	self.alertTermsEdit = Theme:CreateEditBox(wordsPane, 422, 22, false)
	self.alertTermsEdit:SetPoint("TOPLEFT", wordsPane, "TOPLEFT", 0, -58)
	-- The engine accepts 24 terms of up to 80 bytes each. Keep the compact
	-- one-line editor, but do not silently prevent the UI from expressing that
	-- full rule capacity (the UI serializes the 23 separators as comma+space).
	self.alertTermsEdit:SetMaxLetters(1966)
	setControlTooltip(self.alertTermsEdit, "Terms to watch", "An alert can contain up to 24 comma-separated words, phrases, or supported variables.")
	self.alertMatchAllToggle = Theme:CreateCompactToggle(wordsPane, "MATCH ALL TERMS", 150)
	self.alertMatchAllToggle:SetPoint("TOPLEFT", wordsPane, "TOPLEFT", 0, -92)
	setControlTooltip(self.alertMatchAllToggle, "Require every term", "When off, any one term triggers this alert. When on, every listed term must appear.")
	self.alertUsePlayerNameButton = Theme:CreateTightButton(wordsPane, "ADD MY NAME", 20, false)
	self.alertUsePlayerNameButton:SetPoint("TOPLEFT", wordsPane, "TOPLEFT", 158, -92)
	setActionStyle(self.alertUsePlayerNameButton, "quiet", "Add your current character", "Appends [PLAYER_NAME] without replacing the terms already in this rule.")
	self.alertUsePlayerNameButton:SetScript("OnClick", function() Config:AddPlayerNameToAlertTerms() end)
	local wordsHint = Theme:CreateText(wordsPane, "GameFontHighlightSmall", "textMuted")
	wordsHint:SetPoint("TOPLEFT", wordsPane, "TOPLEFT", 0, -124)
	wordsHint:SetWidth(422)
	wordsHint:SetJustifyH("LEFT")
	wordsHint:SetText("[PLAYER_NAME] resolves when a message arrives, so the same rule follows whichever character is logged in.")
	local function commitRuleToggle()
		Config:SaveAlertRule(true)
	end
	self.alertEnabledToggle.OnValueChanged = commitRuleToggle
	self.alertMatchAllToggle.OnValueChanged = commitRuleToggle
	self.alertSaveButton = Theme:CreateTightButton(wordsPane, "SAVE RULE", 20, true)
	setActionStyle(self.alertSaveButton, "primary", "Save this alert", "Applies the current rule immediately.")
	self.alertSaveButton:SetPoint("TOPLEFT", wordsPane, "TOPLEFT", 0, -174)
	self.alertSaveButton:SetScript("OnClick", function() Config:SaveAlertRule(false) end)
	self.alertDeleteButton = Theme:CreateTightButton(wordsPane, "DELETE", 20, false)
	setActionStyle(self.alertDeleteButton, "danger", "Delete this alert", "Removes the selected alert rule after confirmation.")
	self.alertDeleteButton:SetPoint("LEFT", self.alertSaveButton, "RIGHT", CONTROL_GAP, 0)
	self.alertDeleteButton:SetScript("OnClick", function() Config:DeleteAlertRule() end)

	local notifyTitle = Theme:CreateText(notifyPane, "GameFontNormalSmall", "gold")
	notifyTitle:SetPoint("TOPLEFT", notifyPane, "TOPLEFT", 0, 0)
	notifyTitle:SetText("WHEN THIS RULE MATCHES")
	local notifyDetail = Theme:CreateText(notifyPane, "GameFontHighlightSmall", "textMuted")
	notifyDetail:SetPoint("TOPLEFT", notifyPane, "TOPLEFT", 0, -20)
	notifyDetail:SetWidth(422)
	notifyDetail:SetJustifyH("LEFT")
	notifyDetail:SetText("These choices belong to the selected rule. GLOBAL behavior can allow or override them.")
	self.alertRevealToggle = Theme:CreateCompactToggle(notifyPane, "REVEAL CHAT", 156)
	self.alertRevealToggle:SetPoint("TOPLEFT", notifyPane, "TOPLEFT", 0, -54)
	self.alertRevealToggle.OnValueChanged = commitRuleToggle
	setControlTooltip(self.alertRevealToggle, "Reveal chat for this rule", "Works only while GLOBAL CHAT REVEAL is enabled in Global Behavior.")
	self.alertRevealGateHint = Theme:CreateText(notifyPane, "GameFontHighlightSmall", "textMuted")
	self.alertRevealGateHint:SetPoint("TOPLEFT", notifyPane, "TOPLEFT", 0, -80)
	self.alertRevealGateHint:SetWidth(422)
	self.alertRevealGateHint:SetJustifyH("LEFT")
	self.alertRuleSoundToggle = Theme:CreateCompactToggle(notifyPane, "PLAY SOUND", 156)
	self.alertRuleSoundToggle:SetPoint("TOPLEFT", notifyPane, "TOPLEFT", 0, -126)
	self.alertRuleSoundToggle.OnValueChanged = commitRuleToggle
	setControlTooltip(self.alertRuleSoundToggle, "Sound for this rule", "SOUND FOR ALL overrides this switch and makes every matching rule play a sound.")
	self.alertSoundGateHint = Theme:CreateText(notifyPane, "GameFontHighlightSmall", "textMuted")
	self.alertSoundGateHint:SetPoint("TOPLEFT", notifyPane, "TOPLEFT", 0, -152)
	self.alertSoundGateHint:SetWidth(422)
	self.alertSoundGateHint:SetJustifyH("LEFT")

	local sourceTitle = Theme:CreateText(sourcesPane, "GameFontNormalSmall", "gold")
	sourceTitle:SetPoint("TOPLEFT", sourcesPane, "TOPLEFT", 0, 0)
	sourceTitle:SetText("WHERE CAN THIS ALERT TRIGGER?")
	self.alertAllSourcesToggle = Theme:CreateCompactToggle(sourcesPane, "ALL SOURCES", 154)
	self.alertAllSourcesToggle:SetPoint("TOPLEFT", sourcesPane, "TOPLEFT", 0, -26)
	setControlTooltip(self.alertAllSourcesToggle, "Watch every source", "Turn this off to reveal the exact source checklist below.")
	self.alertAllSourcesToggle.OnValueChanged = function(_, value)
		if value and Config.selectedAlertRuleId and addon.ResetAlertRuleSources then
			local ok, result, err = pcall(addon.ResetAlertRuleSources, addon, Config.selectedAlertRuleId)
			if not ok or result ~= true then
				Config:SetAlertsStatus(tostring((ok and err) or result or "Sources could not be reset."), "danger")
				Config:RefreshAlertsPage(true)
				return
			end
		end
		Config:SaveAlertRule(true)
	end
	self.alertSourceHint = Theme:CreateText(sourcesPane, "GameFontHighlightSmall", "textMuted")
	self.alertSourceHint:SetPoint("TOPLEFT", sourcesPane, "TOPLEFT", 0, -52)
	self.alertSourceHint:SetWidth(422)
	self.alertSourceHint:SetJustifyH("LEFT")
	self.alertSourceRows = {}
	for index = 1, 8 do
		local column = (index - 1) % 2
		local sourceRow = math.floor((index - 1) / 2)
		local toggle = Theme:CreateCompactToggle(sourcesPane, "Source", 207)
		toggle:SetPoint("TOPLEFT", sourcesPane, "TOPLEFT", column * 211, -80 - (sourceRow * 23))
		toggle.OnValueChanged = function(self, value)
			if Config.selectedAlertRuleId and self.sourceId and addon.SetAlertRuleSourceEnabled then
				local ok, result, err = pcall(addon.SetAlertRuleSourceEnabled, addon, Config.selectedAlertRuleId, self.sourceId, value)
				if not ok or result ~= true then
					Config:SetAlertsStatus(tostring((ok and err) or result or "Source could not be changed."), "danger")
					Config:RefreshAlertSources()
					return
				end
				applyAlertRuntime()
				Config:RefreshAlertSources()
			end
		end
		setControlTooltip(toggle, "Allow this source", "Only checked sources can trigger this alert while ALL SOURCES is off.")
		table.insert(self.alertSourceRows, toggle)
	end
	self.alertSourceCount = Theme:CreateText(sourcesPane, "GameFontHighlightSmall", "textMuted")
	self.alertSourceCount:SetPoint("TOPLEFT", sourcesPane, "TOPLEFT", 0, -177)
	self.alertSourceCount:SetWidth(128)
	self.alertSourcePrevious = Theme:CreateTightButton(sourcesPane, "<", 20, false)
	self.alertSourcePrevious:SetPoint("TOPLEFT", sourcesPane, "TOPLEFT", 128, -171)
	self.alertSourcePrevious:SetScript("OnClick", function()
		Config.alertSourcePage = math.max(1, (Config.alertSourcePage or 1) - 1)
		Config:RefreshAlertSources()
	end)
	self.alertSourceNext = Theme:CreateTightButton(sourcesPane, ">", 20, false)
	self.alertSourceNext:SetPoint("LEFT", self.alertSourcePrevious, "RIGHT", CONTROL_GAP, 0)
	self.alertSourceNext:SetScript("OnClick", function()
		Config.alertSourcePage = (Config.alertSourcePage or 1) + 1
		Config:RefreshAlertSources()
	end)

	local globalTitle = Theme:CreateText(globalPane, "GameFontNormalSmall", "gold")
	globalTitle:SetPoint("TOPLEFT", globalPane, "TOPLEFT", 0, 0)
	globalTitle:SetText("GLOBAL BEHAVIOR")
	local globalDetail = Theme:CreateText(globalPane, "GameFontHighlightSmall", "textMuted")
	globalDetail:SetPoint("TOPLEFT", globalPane, "TOPLEFT", 0, -20)
	globalDetail:SetWidth(422)
	globalDetail:SetJustifyH("LEFT")
	globalDetail:SetText("These defaults affect every enabled alert rule.")
	self.alertGlobalPopoutToggle = Theme:CreateCompactToggle(globalPane, "GLOBAL CHAT REVEAL", 190)
	self.alertGlobalPopoutToggle:SetPoint("TOPLEFT", globalPane, "TOPLEFT", 0, -50)
	self.alertGlobalPopoutToggle.OnValueChanged = function(_, value)
		alerts.popout = value and true or false
		applyAlertRuntime()
		Config:RefreshAlertNotifyHelp()
	end
	setControlTooltip(self.alertGlobalPopoutToggle, "Allow alerts to reveal chat", "This is the master gate for every per-rule REVEAL CHAT switch.")
	local popoutHint = Theme:CreateText(globalPane, "GameFontHighlightSmall", "textMuted")
	popoutHint:SetPoint("TOPLEFT", globalPane, "TOPLEFT", 0, -76)
	popoutHint:SetWidth(422)
	popoutHint:SetJustifyH("LEFT")
	popoutHint:SetText("When off, no alert rule can open or reveal the chat window.")
	self.alertGlobalSoundToggle = Theme:CreateCompactToggle(globalPane, "SOUND FOR ALL", 190)
	self.alertGlobalSoundToggle:SetPoint("TOPLEFT", globalPane, "TOPLEFT", 0, -112)
	self.alertGlobalSoundToggle.OnValueChanged = function(_, value)
		alerts.sound = value and true or false
		applyAlertRuntime()
		Config:RefreshAlertNotifyHelp()
	end
	setControlTooltip(self.alertGlobalSoundToggle, "Play sound for every alert", "Overrides individual rule sound switches while enabled.")
	local soundHint = Theme:CreateText(globalPane, "GameFontHighlightSmall", "textMuted")
	soundHint:SetPoint("TOPLEFT", globalPane, "TOPLEFT", 0, -138)
	soundHint:SetWidth(422)
	soundHint:SetJustifyH("LEFT")
	soundHint:SetText("When off, only rules with PLAY SOUND enabled make a sound.")
	local autoHideLabel = Theme:CreateText(globalPane, "GameFontHighlightSmall", "textMuted")
	autoHideLabel:SetPoint("TOPLEFT", globalPane, "TOPLEFT", 0, -184)
	autoHideLabel:SetText("AUTO-HIDE AFTER")
	self.alertAutoHideEdit = Theme:CreateEditBox(globalPane, 52, 22, false)
	self.alertAutoHideEdit:SetPoint("TOPLEFT", globalPane, "TOPLEFT", 112, -178)
	local autoHideHint = Theme:CreateText(globalPane, "GameFontHighlightSmall", "textMuted")
	autoHideHint:SetPoint("LEFT", self.alertAutoHideEdit, "RIGHT", 6, 0)
	autoHideHint:SetText("SECONDS  -  0 STAYS OPEN  -  MAX 120")
	local function commitAutoHide(self)
		alerts.autoHideSeconds = clampNumber(self:GetText(), 0, 120, 12)
		self:SetText(tostring(alerts.autoHideSeconds))
		applyAlertRuntime()
	end
	self.alertAutoHideEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.alertAutoHideEdit:HookScript("OnEditFocusLost", commitAutoHide)
	setControlTooltip(self.alertAutoHideEdit, "Automatic hide delay", "Enter 0 to keep revealed chat open, or 1 to 120 seconds before it hides again.")

	self.alertsStatus = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	self.alertsStatus:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 188, 10)
	self.alertsStatus:SetWidth(422)
	self.alertsStatus:SetJustifyH("LEFT")
	self.alertEditorControls = {
		self.alertNameEdit, self.alertTermsEdit, self.alertEnabledToggle, self.alertMatchAllToggle,
		self.alertAllSourcesToggle, self.alertRevealToggle, self.alertRuleSoundToggle,
		self.alertSaveButton, self.alertDeleteButton, self.alertUsePlayerNameButton,
	}
	self.alertNameEdit:SetScript("OnTabPressed", function() Config.alertTermsEdit:SetFocus() end)
	self.alertTermsEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() Config:SaveAlertRule(false) end)
	self.alertRulePage = 1
	self.alertSourcePage = 1
	self.alertInspectorMode = "words"
	self:RefreshAlertsPage()
	return page
end

-- Message Blocks are intentionally their own page. Spam Control suppresses
-- repeated player floods before chat reaches us; Blocks is for a player-owned
-- "I never need to see this line" rule, including local UI feedback.
local BLOCK_RULE_PAGE_SIZE = 8
local BLOCK_SCOPE_PAGE_SIZE = 8
local BLOCK_ARCHIVE_PAGE_SIZE = 8

local function getMessageBlockSettings()
	if addon.GetBlockSettings then
		local ok, result = pcall(addon.GetBlockSettings, addon)
		if ok and type(result) == "table" then
			result.uiFeedback = type(result.uiFeedback) == "table" and result.uiFeedback or {}
			if result.enabled == nil then result.enabled = true end
			if result.uiFeedback.coalesce == nil then result.uiFeedback.coalesce = true end
			if result.uiFeedback.window == nil then result.uiFeedback.window = 1.5 end
			return result
		end
	end
	local settings = addon:GetSmartSettings()
	settings.blocks = settings.blocks or {}
	local blocks = settings.blocks
	if blocks.enabled == nil then blocks.enabled = true end
	blocks.uiFeedback = blocks.uiFeedback or {}
	if blocks.uiFeedback.coalesce == nil then blocks.uiFeedback.coalesce = true end
	if blocks.uiFeedback.window == nil then blocks.uiFeedback.window = 1.5 end
	return blocks
end

local function getBlockRules()
	if addon.GetBlockRules then
		local ok, rules = pcall(addon.GetBlockRules, addon)
		if ok and type(rules) == "table" then
			return rules
		end
	end
	return {}
end

local function findBlockRule(ruleId)
	if not ruleId then return nil end
	for _, rule in ipairs(getBlockRules()) do
		if rule.id == ruleId then
			return rule
		end
	end
	return nil
end

local function applyBlockRuntime()
	local controller = addon.BlockControl
	if controller and controller.RefreshRules then
		pcall(controller.RefreshRules, controller, true)
	end
	if controller and controller.SetEnabled then
		pcall(controller.SetEnabled, controller, getMessageBlockSettings().enabled ~= false)
	end
end

local function clampBlockWindow(value)
	value = tonumber(value)
	if not value then value = 1.5 end
	value = math.max(0.25, math.min(10, value))
	return math.floor((value * 10) + 0.5) / 10
end

local function blockWindowText(value)
	value = clampBlockWindow(value)
	if value == math.floor(value) then
		return tostring(math.floor(value))
	end
	return string.format("%.1f", value)
end

local function getBlockedMessageArchive()
	if type(addon.GetBlockedMessageArchive) == "function" then
		local ok, entries = pcall(addon.GetBlockedMessageArchive, addon)
		if ok and type(entries) == "table" then return entries end
	end
	return {}
end

local function getBlockedMessageArchiveStats()
	if type(addon.GetBlockedMessageArchiveStats) == "function" then
		local ok, stats = pcall(addon.GetBlockedMessageArchiveStats, addon)
		if ok and type(stats) == "table" then return stats end
	end
	local blocks = getMessageBlockSettings()
	local archive = type(blocks.archive) == "table" and blocks.archive or {}
	return {
		enabled = archive.enabled ~= false,
		entries = type(archive.entries) == "table" and #archive.entries or 0,
		occurrences = type(archive.entries) == "table" and #archive.entries or 0,
		maxEntries = math.max(25, math.min(1000, math.floor(tonumber(archive.maxEntries) or 500))),
		retentionDays = math.max(1, math.min(90, math.floor(tonumber(archive.retentionDays) or 7))),
	}
end

local function blockedArchiveTimestamp(entry, key)
	local timestamp = trim(entry and entry[key .. "Timestamp"] or "")
	local epoch = tonumber(entry and entry[key .. "Epoch"])
	if epoch and epoch > 0 and date then
		local ok, formatted = pcall(date, "%Y-%m-%d %H:%M", epoch)
		if ok and type(formatted) == "string" and formatted ~= "" then return formatted end
	end
	return timestamp ~= "" and timestamp or "Unknown time"
end

function Config:SetBlockedArchiveStatus(text, colorName)
	if not self.blockedArchiveStatus then return end
	colorName = colorName or "textMuted"
	self.blockedArchiveStatus:SetText(text or "")
	Theme.texts[self.blockedArchiveStatus] = colorName
	local r, g, b, a = Theme:GetColor(colorName)
	self.blockedArchiveStatus:SetTextColor(r, g, b, a)
end

function Config:RefreshBlocksSection()
	local section = self.blocksSection == "archive" and "archive" or "rules"
	self.blocksSection = section
	setTabStyle(self.blockRulesSectionButton, section == "rules")
	setTabStyle(self.blockArchiveSectionButton, section == "archive")
	for _, frame in ipairs(self.blockRulesFrames or {}) do
		if section == "rules" then frame:Show() else frame:Hide() end
	end
	if self.blockedArchivePanel then
		if section == "archive" then self.blockedArchivePanel:Show() else self.blockedArchivePanel:Hide() end
	end
end

function Config:SetBlocksSection(section)
	if section ~= "archive" then section = "rules" end
	self.blocksSection = section
	self.pendingClearBlockedArchive = nil
	if self.blockedArchiveClearButton then setTightButtonLabel(self.blockedArchiveClearButton, "CLEAR ARCHIVE") end
	self:RefreshBlocksSection()
	if section == "archive" then self:RefreshBlockedMessagesPage() else self:RefreshBlocksPage() end
end

function Config:SelectBlockedArchiveEntry(entryId)
	self.selectedBlockedArchiveId = entryId
	self.pendingClearBlockedArchive = nil
	if self.blockedArchiveClearButton then setTightButtonLabel(self.blockedArchiveClearButton, "CLEAR ARCHIVE") end
	self:RefreshBlockedMessagesPage(true)
end

function Config:RefreshBlockedArchiveDetail(entries)
	if not self.blockedArchiveDetailTitle then return end
	local selected
	for index = 1, #(entries or {}) do
		if entries[index].id == self.selectedBlockedArchiveId then selected = entries[index] break end
	end
	if not selected then
		selected = entries and entries[1] or nil
		self.selectedBlockedArchiveId = selected and selected.id or nil
	end
	if not selected then
		self.blockedArchiveDetailTitle:SetText("NO BLOCKED MESSAGE SELECTED")
		self.blockedArchiveDetailMeta:SetText("Blocked messages collected by your own Message Block rules appear here.")
		self.blockedArchiveDetailText:SetText("")
		self.blockedArchiveDetailRule:SetText("")
		self.blockedArchiveDetailTiming:SetText("")
		return
	end
	local sender = trim(selected.sender) ~= "" and trim(selected.sender) or "System / no player"
	local source = trim(selected.sourceLabel) ~= "" and trim(selected.sourceLabel)
		or (trim(selected.channel) ~= "" and trim(selected.channel) or trim(selected.sourceId))
	if source == "" then source = "Unknown source" end
	local occurrences = math.max(1, math.floor(tonumber(selected.occurrences) or 1))
	self.blockedArchiveDetailTitle:SetText(string.upper(sender) .. (occurrences > 1 and ("  x" .. occurrences) or ""))
	self.blockedArchiveDetailMeta:SetText(source .. "  |  " .. (selected.event or "Unknown message type"))
	self.blockedArchiveDetailText:SetText(selected.text or "")
	self.blockedArchiveDetailRule:SetText("BLOCK RULE  " .. (trim(selected.ruleName) ~= "" and selected.ruleName or selected.ruleId or "Unknown rule"))
	self.blockedArchiveDetailTiming:SetText("FIRST  " .. blockedArchiveTimestamp(selected, "first")
		.. "\nLAST   " .. blockedArchiveTimestamp(selected, "last"))
end

function Config:RefreshBlockedMessagesPage(keepStatus)
	if not self.blockedArchivePanel then return end
	local stats = getBlockedMessageArchiveStats()
	local entries = getBlockedMessageArchive()
	if self.blockArchiveSectionButton then
		setTightButtonLabel(self.blockArchiveSectionButton, "BLOCKED MESSAGES (" .. tostring(tonumber(stats.entries) or #entries) .. ")")
	end
	self.blockedArchiveEnabledToggle:SetValue(stats.enabled ~= false, true)
	self.blockedArchiveRetentionEdit:SetText(tostring(math.floor(tonumber(stats.retentionDays) or 7)))
	self.blockedArchiveCapacityEdit:SetText(tostring(math.floor(tonumber(stats.maxEntries) or 500)))

	local pageCount = math.max(1, math.ceil(#entries / BLOCK_ARCHIVE_PAGE_SIZE))
	self.blockedArchivePage = math.max(1, math.min(self.blockedArchivePage or 1, pageCount))
	local startIndex = ((self.blockedArchivePage - 1) * BLOCK_ARCHIVE_PAGE_SIZE) + 1
	if self.selectedBlockedArchiveId then
		local found = false
		for index = 1, #entries do if entries[index].id == self.selectedBlockedArchiveId then found = true break end end
		if not found then self.selectedBlockedArchiveId = nil end
	end
	if not self.selectedBlockedArchiveId and entries[startIndex] then
		self.selectedBlockedArchiveId = entries[startIndex].id
	end
	for rowIndex = 1, #self.blockedArchiveRows do
		local row = self.blockedArchiveRows[rowIndex]
		local entry = entries[startIndex + rowIndex - 1]
		if entry then
			row.entryId = entry.id
			local sender = trim(entry.sender) ~= "" and trim(entry.sender) or "SYSTEM"
			local occurrences = math.max(1, math.floor(tonumber(entry.occurrences) or 1))
			row.text:SetText(sender .. (occurrences > 1 and ("  x" .. occurrences) or ""))
			local source = trim(entry.sourceLabel) ~= "" and trim(entry.sourceLabel) or trim(entry.channel)
			local snippet = string.gsub(entry.text or "", "[%c%s]+", " ")
			row.detail:SetText((entry.lastTimestamp or "") .. (source ~= "" and ("  " .. source) or "") .. "  " .. snippet)
			setChoiceStyle(row, entry.id == self.selectedBlockedArchiveId)
			row:Show()
		else
			row.entryId = nil
			row:Hide()
		end
	end
	if #entries == 0 then
		self.blockedArchiveCount:SetText(stats.enabled == false and "ARCHIVE OFF" or "NO BLOCKED MESSAGES")
	else
		local lastIndex = math.min(#entries, startIndex + BLOCK_ARCHIVE_PAGE_SIZE - 1)
		self.blockedArchiveCount:SetText(pageCount > 1 and (startIndex .. "-" .. lastIndex .. " / " .. #entries)
			or (#entries .. " UNIQUE  |  " .. tostring(tonumber(stats.occurrences) or #entries) .. " HITS"))
	end
	self:SetBlockPager(self.blockedArchivePrevious, pageCount > 1, self.blockedArchivePage > 1)
	self:SetBlockPager(self.blockedArchiveNext, pageCount > 1, self.blockedArchivePage < pageCount)
	self:RefreshBlockedArchiveDetail(entries)
	if not keepStatus then
		self:SetBlockedArchiveStatus(stats.enabled == false
			and "Archive is off; matching messages are still blocked but no plaintext review copy is kept."
			or "Expired entries are removed automatically; repeated copies are grouped with first and last times.", "textMuted")
	end
end

function Config:SetBlocksStatus(text, colorName)
	if not self.blocksStatus then return end
	colorName = colorName or "textMuted"
	self.blocksStatus:SetText(text or "")
	Theme.texts[self.blocksStatus] = colorName
	local r, g, b, a = Theme:GetColor(colorName)
	self.blocksStatus:SetTextColor(r, g, b, a)
end

function Config:RefreshBlockMatchButtons()
	local exact = self.blockMatchMode == "exact"
	local function apply(button, active)
		if not button then return end
		setChoiceStyle(button, active)
	end
	apply(self.blockExactButton, exact)
	apply(self.blockContainsButton, not exact)
end

function Config:RefreshBlockInspectorPane()
	local mode = self.blockInspectorMode
	if mode ~= "player" and mode ~= "where" then
		mode = "message"
	end
	self.blockInspectorMode = mode
	local panes = self.blockInspectorPanes or {}
	local buttons = self.blockInspectorButtons or {}
	for paneId, pane in pairs(panes) do
		if paneId == mode then pane:Show() else pane:Hide() end
	end
	for paneId, button in pairs(buttons) do
		setTabStyle(button, paneId == mode)
	end
end

function Config:SetBlockInspectorPane(mode)
	if mode ~= "message" and mode ~= "player" and mode ~= "where" then
		return
	end
	self.blockInspectorMode = mode
	self:RefreshBlockInspectorPane()
end

function Config:RefreshBlockScopeButtons()
	local sources = self.blockScopeMode ~= "events"
	local function apply(button, active)
		if not button then return end
		setTabStyle(button, active)
	end
	apply(self.blockScopeSourcesButton, sources)
	apply(self.blockScopeEventsButton, not sources)
	if self.blockAllSourcesToggle then
		if sources then self.blockAllSourcesToggle:Show() else self.blockAllSourcesToggle:Hide() end
	end
	if self.blockAllEventsToggle then
		if sources then self.blockAllEventsToggle:Hide() else self.blockAllEventsToggle:Show() end
	end
end

function Config:RefreshBlockSenderScope(data, editorEnabled)
	if not self.blockAllSendersToggle then return end
	local allSenders = not data or data.allSenders ~= false
	local hasTarget = data and type(data.senderKeys) == "table" and next(data.senderKeys) ~= nil
	self.blockAllSendersToggle:SetValue(allSenders, true)
	if editorEnabled and hasTarget then
		self.blockAllSendersToggle:Enable()
	else
		-- A broad/manual rule has no saved player to return to. It can still be
		-- edited normally; create a fresh Shift-hover quick block to target one.
		self.blockAllSendersToggle:Disable()
	end
	if self.blockSenderText then
		local colorName = hasTarget and "accent" or "textMuted"
		local label = hasTarget and trim(data.senderLabel, 48) or ""
		local player = hasTarget and (label ~= "" and label or "Saved player") or "NO PLAYER ATTACHED"
		self.blockSenderText:SetText(tostring(player))
		Theme.texts[self.blockSenderText] = colorName
		local r, g, b, a = Theme:GetColor(colorName)
		self.blockSenderText:SetTextColor(r, g, b, a)
	end
	if self.blockSenderHint then
		if hasTarget and allSenders then
			self.blockSenderHint:SetText("This rule currently applies to anyone even though a saved identity is present.")
		elseif hasTarget then
			self.blockSenderHint:SetText("Only this saved player's matching messages are hidden. Choosing ANY PLAYER removes this saved identity.")
		else
			self.blockSenderHint:SetText("No player identity is stored. Create a block from Shift-hover on a player message to target that player.")
		end
	end
end

function Config:SetBlockEditorEnabled(enabled)
	for _, control in ipairs(self.blockEditorControls or {}) do
		if enabled and control.Enable then
			control:Enable()
		elseif not enabled and control.Disable then
			control:Disable()
		end
	end
end

function Config:RefreshBlockStats()
	if not self.blocksStats then return end
	local stats = {}
	if addon.GetBlockStats then
		local ok, result = pcall(addon.GetBlockStats, addon)
		if ok and type(result) == "table" then stats = result end
	end
	local blocked = tonumber(stats.blocked) or 0
	local manual = tonumber(stats.manual) or 0
	local coalesced = tonumber(stats.uiCoalesced) or 0
	self.blocksStats:SetText("BLOCKED  " .. blocked .. "   RULE HITS  " .. manual .. "   UI REPEATS  " .. coalesced)
	local colorName = blocked > 0 and "warning" or "textMuted"
	Theme.texts[self.blocksStats] = colorName
	local r, g, b, a = Theme:GetColor(colorName)
	self.blocksStats:SetTextColor(r, g, b, a)
end

function Config:SetBlockPager(button, visible, enabled)
	if not button then return end
	if visible then
		button:Show()
		if enabled then
			button:Enable()
			button:SetAlpha(1)
		else
			button:Disable()
			button:SetAlpha(0.35)
		end
	else
		button:Hide()
	end
end

function Config:GetBlockSourceDefinitions(ruleId)
	if addon.GetBlockSourceDefinitions then
		local ok, result = pcall(addon.GetBlockSourceDefinitions, addon, ruleId)
		if ok and type(result) == "table" then return result end
	end
	return {}
end

function Config:GetBlockEventDefinitions(ruleId)
	if addon.GetBlockEventDefinitions then
		local ok, result = pcall(addon.GetBlockEventDefinitions, addon, ruleId)
		if ok and type(result) == "table" then return result end
	end
	return {}
end

function Config:RefreshBlockScope()
	if not self.blockScopeRows then return end
	local rule = findBlockRule(self.selectedBlockRuleId)
	local sourcesMode = self.blockScopeMode ~= "events"
	self:RefreshBlockScopeButtons()
	if not rule then
		for _, row in ipairs(self.blockScopeRows) do row.itemId = nil row:Hide() end
		self.blockScopeCount:SetText(self.blockDraft and "SAVE TO CHOOSE SCOPE" or "NO RULE SELECTED")
		self:SetBlockPager(self.blockScopePrevious, false, false)
		self:SetBlockPager(self.blockScopeNext, false, false)
		if self.blockScopeHint then
			self.blockScopeHint:SetText(self.blockDraft and "New rules start broad; save first, then narrow the sources or message types." or "Choose a block rule to edit its scope.")
		end
		return
	end

	local all = sourcesMode and rule.allSources ~= false or rule.allEvents ~= false
	if all then
		for _, row in ipairs(self.blockScopeRows) do row.itemId = nil row:Hide() end
		self.blockScopeCount:SetText(sourcesMode and "ALL SOURCES" or "ALL MESSAGE TYPES")
		self:SetBlockPager(self.blockScopePrevious, false, false)
		self:SetBlockPager(self.blockScopeNext, false, false)
		if self.blockScopeHint then
			self.blockScopeHint:SetText(sourcesMode and "Turn off ALL SOURCES to choose exact sources." or "Turn off ALL TYPES to choose exact message types.")
		end
		return
	end

	local definitions = sourcesMode and self:GetBlockSourceDefinitions(rule.id) or self:GetBlockEventDefinitions(rule.id)
	if self.blockScopeHint then
		self.blockScopeHint:SetText(sourcesMode and "Only checked sources can be blocked by this rule." or "Only checked message types can be blocked by this rule.")
	end
	local pageSize = #self.blockScopeRows
	local pageCount = math.max(1, math.ceil(#definitions / pageSize))
	self.blockScopePage = math.max(1, math.min(self.blockScopePage or 1, pageCount))
	local startIndex = ((self.blockScopePage - 1) * pageSize) + 1
	for rowIndex = 1, pageSize do
		local row = self.blockScopeRows[rowIndex]
		local definition = definitions[startIndex + rowIndex - 1]
		if definition then
			row.scopeKind = sourcesMode and "sources" or "events"
			row.itemId = definition.id or definition.sourceId or definition.event
			row.label:SetText(definition.label or definition.sourceLabel or definition.event or row.itemId or "Item")
			row:SetValue(definition.selected == true, true)
			row:Show()
		else
			row.itemId = nil
			row:Hide()
		end
	end
	if #definitions == 0 then
		self.blockScopeCount:SetText(sourcesMode and "NO SOURCES OBSERVED" or "NO MESSAGE TYPES")
	else
		local lastIndex = math.min(#definitions, startIndex + pageSize - 1)
		self.blockScopeCount:SetText(pageCount > 1 and (startIndex .. "-" .. lastIndex .. " / " .. #definitions) or (#definitions .. (sourcesMode and " SOURCES" or " TYPES")))
	end
	self:SetBlockPager(self.blockScopePrevious, pageCount > 1, self.blockScopePage > 1)
	self:SetBlockPager(self.blockScopeNext, pageCount > 1, self.blockScopePage < pageCount)
end

function Config:LoadBlockEditor(ruleId)
	local rule = findBlockRule(ruleId)
	local draft = not rule and self.blockDraft or nil
	if not rule and not draft then
		self.selectedBlockRuleId = nil
		self.blockEditorTitle:SetText("NO BLOCK SELECTED")
		self.blockNameEdit:SetText("")
		self.blockTextEdit:SetText("")
		self.blockMatchMode = "contains"
		self.blockEnabledToggle:SetValue(false, true)
		self.blockCaseToggle:SetValue(false, true)
		self.blockAllSourcesToggle:SetValue(true, true)
		self.blockAllEventsToggle:SetValue(true, true)
		self:SetBlockEditorEnabled(false)
		if self.blockDeleteButton then
			setTightButtonLabel(self.blockDeleteButton, "DELETE")
			self.blockDeleteButton:Disable()
		end
		self:RefreshBlockSenderScope(nil, false)
		self:RefreshBlockMatchButtons()
		self:RefreshBlockScope()
		self:RefreshBlockInspectorPane()
		return false
	end

	local data = rule or draft
	self.selectedBlockRuleId = rule and rule.id or nil
	self.blockEditorTitle:SetText(rule and ("EDIT " .. string.upper(rule.name or rule.id)) or "NEW BLOCK RULE")
	self.blockNameEdit:SetText(data.name or "")
	self.blockTextEdit:SetText(data.text or data.phrase or "")
	self.blockMatchMode = data.matchMode == "exact" and "exact" or "contains"
	self.blockEnabledToggle:SetValue(data.enabled ~= false, true)
	self.blockCaseToggle:SetValue(data.caseSensitive == true, true)
	self.blockAllSourcesToggle:SetValue(data.allSources ~= false, true)
	self.blockAllEventsToggle:SetValue(data.allEvents ~= false, true)
	self:SetBlockEditorEnabled(true)
	if self.blockDeleteButton then
		if rule then self.blockDeleteButton:Enable() else self.blockDeleteButton:Disable() end
	end
	self:RefreshBlockSenderScope(data, true)
	self:RefreshBlockMatchButtons()
	if self.blockDeleteButton and (not rule or self.pendingDeleteBlockId ~= rule.id) then
		self.pendingDeleteBlockId = nil
		setTightButtonLabel(self.blockDeleteButton, "DELETE")
	end
	self:RefreshBlockScope()
	self:RefreshBlockInspectorPane()
	return true
end

function Config:SelectBlockRule(ruleId)
	self.blockDraft = nil
	self.selectedBlockRuleId = ruleId
	self.blockScopePage = 1
	self.blockInspectorMode = "message"
	self.pendingDeleteBlockId = nil
	if self:LoadBlockEditor(ruleId) then
		self:SetBlocksStatus("Choose text, match behavior, and player/source/type scope.", "textMuted")
	end
	self:RefreshBlocksPage(true)
end

function Config:NewBlockRule()
	self.selectedBlockRuleId = nil
	self.pendingDeleteBlockId = nil
	self.blockScopePage = 1
	self.blockInspectorMode = "message"
	self.blockDraft = {
		name = "",
		text = "",
		matchMode = "contains",
		enabled = true,
		caseSensitive = false,
		allSources = true,
		allEvents = true,
		allSenders = true,
		senderKeys = {},
		senderLabel = "",
	}
	self:RefreshBlocksPage(true)
	self:SetBlocksStatus("Enter a phrase and save. New rules begin with all sources and message types.", "success")
	self.blockNameEdit:SetFocus()
end

function Config:SetBlockMatchMode(mode)
	self.blockMatchMode = mode == "exact" and "exact" or "contains"
	self:RefreshBlockMatchButtons()
	if self.selectedBlockRuleId then self:SaveBlockRule(true) end
end

function Config:SetBlockScopeMode(mode)
	self.blockScopeMode = mode == "events" and "events" or "sources"
	self.blockScopePage = 1
	self:RefreshBlockScope()
end

function Config:SetBlockAllScope(kind, value)
	if not self.selectedBlockRuleId then
		if self.blockDraft then
			self.blockDraft[kind == "sources" and "allSources" or "allEvents"] = value and true or false
		end
		self:RefreshBlockScope()
		return
	end
	local methodName = kind == "sources" and "SetBlockRuleAllSources" or "SetBlockRuleAllEvents"
	local method = addon[methodName]
	if not method then
		self:SetBlocksStatus("Scope controls are unavailable in this build.", "danger")
		self:RefreshBlocksPage(true)
		return
	end
	local ok, result, reason = pcall(method, addon, self.selectedBlockRuleId, value and true or false)
	if not ok or result ~= true then
		self:SetBlocksStatus(tostring((ok and reason) or result or "Scope could not be updated."), "danger")
		self:RefreshBlocksPage(true)
		return
	end
	self.blockScopePage = 1
	self:RefreshBlocksPage(true)
end

function Config:SetBlockAllSenders(value)
	if not self.selectedBlockRuleId then
		self:RefreshBlocksPage(true)
		return
	end
	local method = addon.SetBlockRuleAllSenders
	if not method then
		self:SetBlocksStatus("Player scope is unavailable in this build.", "danger")
		self:RefreshBlocksPage(true)
		return
	end
	local ok, result, reason = pcall(method, addon, self.selectedBlockRuleId, value and true or false)
	if not ok or result ~= true then
		local messages = {
			["no-sender"] = "This rule has no remembered player. Make a quick block from chat to target one.",
			["not-found"] = "That block rule is no longer available.",
		}
		self:SetBlocksStatus(messages[reason] or tostring((ok and reason) or result or "Player scope could not be updated."), "danger")
		self:RefreshBlocksPage(true)
		return
	end
	self:RefreshBlocksPage(true)
	self:SetBlocksStatus(value and "Block now applies to any player in its selected scope." or "Block now applies only to its saved player.", "success")
end

function Config:SetBlockScopeItem(kind, itemId, selected)
	if not self.selectedBlockRuleId or not itemId then return end
	local methodName = kind == "sources" and "SetBlockRuleSourceEnabled" or "SetBlockRuleEventEnabled"
	local method = addon[methodName]
	if not method then
		self:SetBlocksStatus("Scope controls are unavailable in this build.", "danger")
		self:RefreshBlockScope()
		return
	end
	local ok, result, reason = pcall(method, addon, self.selectedBlockRuleId, itemId, selected and true or false)
	if not ok or result ~= true then
		self:SetBlocksStatus(tostring((ok and reason) or result or "Scope could not be updated."), "danger")
	end
	self:RefreshBlockScope()
end

function Config:SaveBlockRule(quiet)
	local data = {
		name = trim(self.blockNameEdit:GetText()),
		text = trim(self.blockTextEdit:GetText()),
		matchMode = self.blockMatchMode == "exact" and "exact" or "contains",
		enabled = self.blockEnabledToggle.checked == true,
		caseSensitive = self.blockCaseToggle.checked == true,
		allSources = self.blockAllSourcesToggle.checked == true,
		allEvents = self.blockAllEventsToggle.checked == true,
	}
	if data.text == "" then
		if not quiet then self:SetBlocksStatus("Enter text or a phrase to block.", "danger") end
		return false
	end
	local method = self.selectedBlockRuleId and addon.UpdateBlockRule or addon.CreateBlockRule
	if not method then
		if not quiet then self:SetBlocksStatus("Message Blocks are unavailable in this build.", "danger") end
		return false
	end
	local ok, rule, reason
	if self.selectedBlockRuleId then
		ok, rule, reason = pcall(method, addon, self.selectedBlockRuleId, data)
	else
		ok, rule, reason = pcall(method, addon, data)
	end
	if not ok or type(rule) ~= "table" then
		if not quiet then self:SetBlocksStatus(tostring((ok and reason) or rule or "The block could not be saved."), "danger") end
		return false
	end
	self.blockDraft = nil
	self.selectedBlockRuleId = rule.id
	self.pendingDeleteBlockId = nil
	local rules = getBlockRules()
	for index = 1, #rules do
		if rules[index].id == rule.id then
			self.blockRulePage = math.max(1, math.ceil(index / BLOCK_RULE_PAGE_SIZE))
			break
		end
	end
	applyBlockRuntime()
	self:RefreshBlocksPage(true)
	if not quiet then self:SetBlocksStatus("Block saved and applied immediately.", "success") end
	return true
end

function Config:DeleteBlockRule()
	if not self.selectedBlockRuleId or not addon.DeleteBlockRule then return end
	if self.pendingDeleteBlockId ~= self.selectedBlockRuleId then
		self.pendingDeleteBlockId = self.selectedBlockRuleId
		setTightButtonLabel(self.blockDeleteButton, "CONFIRM DELETE")
		self:SetBlocksStatus("Click CONFIRM DELETE to remove this block.", "warning")
		return
	end
	local deletedId = self.selectedBlockRuleId
	local ok, result, reason = pcall(addon.DeleteBlockRule, addon, deletedId)
	if not ok or result ~= true then
		self:SetBlocksStatus(tostring((ok and reason) or result or "The block could not be deleted."), "danger")
		return
	end
	self.pendingDeleteBlockId = nil
	self.selectedBlockRuleId = nil
	applyBlockRuntime()
	self:RefreshBlocksPage(true)
	self:SetBlocksStatus("Block deleted.", "success")
end

function Config:CommitBlockCoalescing()
	if not self.blockCoalesceToggle then return end
	local enabled = self.blockCoalesceToggle.checked == true
	local window = clampBlockWindow(self.blockWindowEdit:GetText())
	if addon.SetUIFeedbackCoalescing then
		local ok, result, reason = pcall(addon.SetUIFeedbackCoalescing, addon, enabled, window)
		if not ok or result ~= true then
			self:SetBlocksStatus(tostring((ok and reason) or result or "UI feedback setting could not be applied."), "danger")
			return
		end
	else
		local raw = addon:GetSmartSettings()
		raw.blocks = raw.blocks or {}
		raw.blocks.uiFeedback = raw.blocks.uiFeedback or {}
		raw.blocks.uiFeedback.coalesce = enabled
		raw.blocks.uiFeedback.window = window
		applyBlockRuntime()
	end
	self.blockWindowEdit:SetText(blockWindowText(window))
	self:SetBlocksStatus(enabled and "Repeated identical UI errors are coalesced." or "Repeated UI errors will be shown individually.", enabled and "success" or "warning")
	self:RefreshBlockStats()
end

function Config:SetBlocksEnabled(enabled)
	if addon.SetBlockControlEnabled then
		local ok, result = pcall(addon.SetBlockControlEnabled, addon, enabled and true or false)
		if not ok then
			self:SetBlocksStatus(tostring(result or "Blocks could not be changed."), "danger")
			return
		end
	else
		local raw = addon:GetSmartSettings()
		raw.blocks = raw.blocks or {}
		raw.blocks.enabled = enabled and true or false
		applyBlockRuntime()
	end
	self:SetBlocksStatus(enabled and "Message Blocks enabled." or "Message Blocks disabled; rules are preserved.", enabled and "success" or "warning")
	self:RefreshBlocksPage(true)
end

function Config:SetBlockRuleRowEnabled(ruleId, enabled)
	if not ruleId then
		return false
	end
	local method = addon.SetBlockRuleEnabled or addon.UpdateBlockRule
	if not method then
		return false
	end
	local ok, rule, reason
	if addon.SetBlockRuleEnabled then
		ok, rule, reason = pcall(method, addon, ruleId, enabled and true or false)
	else
		ok, rule, reason = pcall(method, addon, ruleId, { enabled = enabled and true or false })
	end
	if not ok or type(rule) ~= "table" then
		self:SetBlocksStatus(tostring((ok and reason) or rule or "Block state could not be changed."), "danger")
		self:RefreshBlocksPage(true)
		return false
	end
	applyBlockRuntime()
	self:RefreshBlocksPage(true)
	self:SetBlocksStatus(enabled and "Block enabled." or "Block paused; its rule is preserved.", enabled and "success" or "warning")
	return true
end

function Config:RefreshBlocksPage(keepStatus)
	if not self.blocksPage then return end
	self:RefreshBlocksSection()
	if self.blocksSection == "archive" then
		self:RefreshBlockedMessagesPage(keepStatus)
		return
	end
	local settings = getMessageBlockSettings()
	self.blocksMasterToggle:SetValue(settings.enabled ~= false, true)
	self.blockCoalesceToggle:SetValue(settings.uiFeedback.coalesce ~= false, true)
	self.blockWindowEdit:SetText(blockWindowText(settings.uiFeedback.window))

	local rules = getBlockRules()
	local pageCount = math.max(1, math.ceil(#rules / BLOCK_RULE_PAGE_SIZE))
	self.blockRulePage = math.max(1, math.min(self.blockRulePage or 1, pageCount))
	local startIndex = ((self.blockRulePage - 1) * BLOCK_RULE_PAGE_SIZE) + 1
	if not self.blockDraft and not findBlockRule(self.selectedBlockRuleId) and rules[startIndex] then
		self.selectedBlockRuleId = rules[startIndex].id
	end
	for rowIndex = 1, #self.blockRows do
		local row = self.blockRows[rowIndex]
		local rule = rules[startIndex + rowIndex - 1]
		if rule then
			row.ruleId = rule.id
			local mode = (rule.allSenders == false and "PLAYER " or "") .. (rule.matchMode == "exact" and "EXACT" or "TEXT")
			row.stateToggle.ruleId = rule.id
			row.stateToggle:SetValue(rule.enabled ~= false, true)
			row:SetLabel(mode .. "  " .. (rule.name or rule.text or rule.id))
			local selected = not self.blockDraft and rule.id == self.selectedBlockRuleId
			setChoiceStyle(row, selected)
			row:Show()
		else
			row.ruleId = nil
			row.stateToggle.ruleId = nil
			row:Hide()
		end
	end
	if #rules == 0 then
		self.blockRuleCount:SetText("NO BLOCK RULES")
	else
		local lastIndex = math.min(#rules, startIndex + BLOCK_RULE_PAGE_SIZE - 1)
		self.blockRuleCount:SetText(pageCount > 1 and (startIndex .. "-" .. lastIndex .. " / " .. #rules) or (#rules .. " RULES"))
	end
	self:SetBlockPager(self.blockRulePrevious, pageCount > 1, self.blockRulePage > 1)
	self:SetBlockPager(self.blockRuleNext, pageCount > 1, self.blockRulePage < pageCount)
	if self.blockDraft then
		self:LoadBlockEditor(nil)
	else
		self:LoadBlockEditor(self.selectedBlockRuleId)
	end
	self:RefreshBlockStats()
	if self.blockArchiveSectionButton then
		local archiveStats = getBlockedMessageArchiveStats()
		setTightButtonLabel(self.blockArchiveSectionButton,
			"BLOCKED MESSAGES (" .. tostring(tonumber(archiveStats.entries) or 0) .. ")")
	end
	if not keepStatus then
		self:SetBlocksStatus("Click the X to pause a rule; click its name to edit it. Spam Firewall handles floods.", "textMuted")
	end
end

function Config:BuildBlocksPage()
	local page = self:CreatePage("blocks")
	self.blocksPage = page
	local _, blocksSubtitle = createHeading(page, "Message Blocks", "Create rules or review the messages they quarantined.")
	blocksSubtitle:SetWidth(350)
	self.blockArchiveSectionButton = Theme:CreateTightButton(page, "BLOCKED MESSAGES (0)", 20, false)
	self.blockArchiveSectionButton:SetPoint("TOPRIGHT", page, "TOPRIGHT", -PAGE_GUTTER, -8)
	self.blockArchiveSectionButton:SetScript("OnClick", function() Config:SetBlocksSection("archive") end)
	setActionStyle(self.blockArchiveSectionButton, "choice", "Blocked Messages",
		"Review the bounded local quarantine created by your own Message Block rules. Spam Firewall evidence is kept separately.")
	self.blockRulesSectionButton = Theme:CreateTightButton(page, "BLOCK RULES", 20, false)
	self.blockRulesSectionButton:SetPoint("RIGHT", self.blockArchiveSectionButton, "LEFT", -CONTROL_GAP, 0)
	self.blockRulesSectionButton:SetScript("OnClick", function() Config:SetBlocksSection("rules") end)
	setActionStyle(self.blockRulesSectionButton, "choice", "Block Rules",
		"Create and edit the rules that quarantine matching messages.")

	local work = createQuietShellPanel(page, "surface")
	work:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -PAGE_TOP)
	work:SetSize(PAGE_WIDTH, 390)

	self.blocksMasterToggle = Theme:CreateCompactToggle(work, "BLOCKS ENABLED", 136)
	self.blocksMasterToggle:SetPoint("TOPLEFT", work, "TOPLEFT", 6, -4)
	self.blocksMasterToggle.OnValueChanged = function(_, value) Config:SetBlocksEnabled(value) end
	setControlTooltip(self.blocksMasterToggle, "Enable message blocks", "Turns every saved block rule on or off without deleting any rules.")
	local masterHint = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	masterHint:SetPoint("LEFT", self.blocksMasterToggle, "RIGHT", 8, 0)
	masterHint:SetText("Rules hide matching lines immediately. Spam Firewall handles repeated floods.")

	local divider = work:CreateTexture(nil, "ARTWORK")
	divider:SetTexture("Interface\\Buttons\\WHITE8x8")
	Theme:RegisterTexture(divider, "borderMuted")
	divider:SetPoint("TOPLEFT", work, "TOPLEFT", 176, -28)
	divider:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 176, 1)
	divider:SetWidth(1)

	local listTitle = Theme:CreateText(work, "GameFontNormalSmall", "gold")
	listTitle:SetPoint("TOPLEFT", work, "TOPLEFT", 8, -34)
	listTitle:SetText("BLOCK RULES")
	local newRule = Theme:CreateTightButton(work, "NEW", 20, true)
	setActionStyle(newRule, "primary", "Create a message block", "Starts a new rule. A block is for one unwanted pattern; Spam Firewall handles floods.")
	newRule:SetPoint("TOPRIGHT", work, "TOPLEFT", 168, -29)
	newRule:SetScript("OnClick", function() Config:NewBlockRule() end)
	self.blockRows = {}
	for index = 1, BLOCK_RULE_PAGE_SIZE do
		local row = Theme:CreateButton(work, "", 160, 22, false)
		row:SetPoint("TOPLEFT", work, "TOPLEFT", 8, -54 - ((index - 1) * 23))
		row.stateToggle = createListStateToggle(row)
		row.stateToggle:SetPoint("LEFT", row, "LEFT", 2, 0)
		row.stateToggle.OnValueChanged = function(toggle, value)
			if toggle.ruleId then
				Config:SetBlockRuleRowEnabled(toggle.ruleId, value)
			end
		end
		row.text:ClearAllPoints()
		row.text:SetPoint("LEFT", row, "LEFT", 22, 0)
		row.text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		row.text:SetJustifyH("LEFT")
		row:SetScript("OnClick", function(self)
			if self.ruleId then Config:SelectBlockRule(self.ruleId) end
		end)
		table.insert(self.blockRows, row)
	end
	self.blockRuleCount = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	self.blockRuleCount:SetPoint("TOPLEFT", work, "TOPLEFT", 8, -248)
	self.blockRuleCount:SetWidth(84)
	self.blockRulePrevious = Theme:CreateTightButton(work, "<", 20, false)
	self.blockRulePrevious:SetPoint("TOPLEFT", work, "TOPLEFT", 94, -242)
	self.blockRulePrevious:SetScript("OnClick", function()
		Config.blockRulePage = math.max(1, (Config.blockRulePage or 1) - 1)
		local rules = getBlockRules()
		local first = rules[((Config.blockRulePage - 1) * BLOCK_RULE_PAGE_SIZE) + 1]
		if first then Config.selectedBlockRuleId = first.id end
		Config.blockDraft = nil
		Config:RefreshBlocksPage(true)
	end)
	self.blockRuleNext = Theme:CreateTightButton(work, ">", 20, false)
	self.blockRuleNext:SetPoint("LEFT", self.blockRulePrevious, "RIGHT", CONTROL_GAP, 0)
	self.blockRuleNext:SetScript("OnClick", function()
		Config.blockRulePage = (Config.blockRulePage or 1) + 1
		local rules = getBlockRules()
		local first = rules[((Config.blockRulePage - 1) * BLOCK_RULE_PAGE_SIZE) + 1]
		if first then Config.selectedBlockRuleId = first.id end
		Config.blockDraft = nil
		Config:RefreshBlocksPage(true)
	end)
	self.blocksStats = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	self.blocksStats:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 8, 34)
	self.blocksStats:SetWidth(160)
	self.blocksStats:SetJustifyH("LEFT")
	local resetStats = Theme:CreateTightButton(work, "RESET STATS", 20, false)
	setActionStyle(resetStats, "quiet", "Reset block counters", "Clears the displayed hit counters. Saved block rules are unchanged.")
	resetStats:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 8, 7)
	resetStats:SetScript("OnClick", function()
		if addon.ResetBlockStats then pcall(addon.ResetBlockStats, addon) end
		Config:RefreshBlockStats()
	end)

	self.blockEditorTitle = Theme:CreateText(work, "GameFontNormalSmall", "gold")
	self.blockEditorTitle:SetPoint("TOPLEFT", work, "TOPLEFT", 188, -34)
	self.blockEditorTitle:SetWidth(422)
	self.blockEditorTitle:SetJustifyH("LEFT")

	self.blockInspectorButtons = {}
	self.blockInspectorPanes = {}
	local messageTab = Theme:CreateTightButton(work, "MESSAGE", 20, false)
	messageTab:SetPoint("TOPLEFT", work, "TOPLEFT", 188, -52)
	messageTab:SetScript("OnClick", function() Config:SetBlockInspectorPane("message") end)
	setActionStyle(messageTab, "choice", "Message pattern", "Edit the phrase and choose whether it must match exactly or only be contained in a line.")
	self.blockInspectorButtons.message = messageTab
	local playerTab = Theme:CreateTightButton(work, "PLAYER", 20, false)
	playerTab:SetPoint("LEFT", messageTab, "RIGHT", CONTROL_GAP, 0)
	playerTab:SetScript("OnClick", function() Config:SetBlockInspectorPane("player") end)
	setActionStyle(playerTab, "choice", "Player scope", "Choose whether the rule applies to anyone or only the player remembered by a Shift-hover block.")
	self.blockInspectorButtons.player = playerTab
	local whereTab = Theme:CreateTightButton(work, "WHERE", 20, false)
	whereTab:SetPoint("LEFT", playerTab, "RIGHT", CONTROL_GAP, 0)
	whereTab:SetScript("OnClick", function() Config:SetBlockInspectorPane("where") end)
	setActionStyle(whereTab, "choice", "Source and message-type scope", "Limit the rule to selected chat sources or message types.")
	self.blockInspectorButtons.where = whereTab

	local messagePane = CreateFrame("Frame", nil, work)
	messagePane:SetPoint("TOPLEFT", work, "TOPLEFT", 188, -82)
	messagePane:SetSize(422, 254)
	self.blockInspectorPanes.message = messagePane
	local playerPane = CreateFrame("Frame", nil, work)
	playerPane:SetPoint("TOPLEFT", work, "TOPLEFT", 188, -82)
	playerPane:SetSize(422, 254)
	self.blockInspectorPanes.player = playerPane
	local wherePane = CreateFrame("Frame", nil, work)
	wherePane:SetPoint("TOPLEFT", work, "TOPLEFT", 188, -82)
	wherePane:SetSize(422, 254)
	self.blockInspectorPanes.where = wherePane

	local nameLabel = Theme:CreateText(messagePane, "GameFontHighlightSmall", "textMuted")
	nameLabel:SetPoint("TOPLEFT", messagePane, "TOPLEFT", 0, 0)
	nameLabel:SetText("NAME")
	self.blockNameEdit = Theme:CreateEditBox(messagePane, 220, 22, false)
	self.blockNameEdit:SetPoint("TOPLEFT", messagePane, "TOPLEFT", 0, -14)
	self.blockNameEdit:SetMaxLetters(40)
	setControlTooltip(self.blockNameEdit, "Rule name", "A short label used only in this settings list.")
	self.blockEnabledToggle = Theme:CreateCompactToggle(messagePane, "ENABLED", 104)
	self.blockEnabledToggle:SetPoint("TOPLEFT", messagePane, "TOPLEFT", 232, -13)
	setControlTooltip(self.blockEnabledToggle, "Enable this rule", "Pausing one rule keeps it saved while allowing matching lines through.")
	local textLabel = Theme:CreateText(messagePane, "GameFontHighlightSmall", "textMuted")
	textLabel:SetPoint("TOPLEFT", messagePane, "TOPLEFT", 0, -44)
	textLabel:SetText("TEXT OR PHRASE")
	self.blockTextEdit = Theme:CreateEditBox(messagePane, 422, 22, false)
	self.blockTextEdit:SetPoint("TOPLEFT", messagePane, "TOPLEFT", 0, -58)
	self.blockTextEdit:SetMaxLetters(160)
	setControlTooltip(self.blockTextEdit, "Text to hide", "Enter the visible words Chatty should compare against each message.")
	local matchLabel = Theme:CreateText(messagePane, "GameFontHighlightSmall", "textMuted")
	matchLabel:SetPoint("TOPLEFT", messagePane, "TOPLEFT", 0, -90)
	matchLabel:SetText("MATCH")
	self.blockContainsButton = Theme:CreateTightButton(messagePane, "CONTAINS", 20, false)
	self.blockContainsButton:SetPoint("TOPLEFT", messagePane, "TOPLEFT", 0, -104)
	self.blockContainsButton:SetScript("OnClick", function() Config:SetBlockMatchMode("contains") end)
	setActionStyle(self.blockContainsButton, "choice", "Contains phrase", "Hides a line when this phrase appears anywhere inside it.")
	self.blockExactButton = Theme:CreateTightButton(messagePane, "EXACT", 20, false)
	self.blockExactButton:SetPoint("LEFT", self.blockContainsButton, "RIGHT", CONTROL_GAP, 0)
	self.blockExactButton:SetScript("OnClick", function() Config:SetBlockMatchMode("exact") end)
	setActionStyle(self.blockExactButton, "choice", "Exact message", "Hides only a line whose complete visible text matches this phrase.")
	self.blockCaseToggle = Theme:CreateCompactToggle(messagePane, "MATCH CASE", 112)
	self.blockCaseToggle:SetPoint("LEFT", self.blockExactButton, "RIGHT", 8, 0)
	setControlTooltip(self.blockCaseToggle, "Match uppercase and lowercase", "When off, Chatty treats uppercase and lowercase letters as the same.")
	self.blockEnabledToggle.OnValueChanged = function() if Config.selectedBlockRuleId then Config:SaveBlockRule(true) end end
	self.blockCaseToggle.OnValueChanged = function() if Config.selectedBlockRuleId then Config:SaveBlockRule(true) end end
	local messageHint = Theme:CreateText(messagePane, "GameFontHighlightSmall", "textMuted")
	messageHint:SetPoint("TOPLEFT", messagePane, "TOPLEFT", 0, -134)
	messageHint:SetWidth(422)
	messageHint:SetJustifyH("LEFT")
	messageHint:SetText("CONTAINS is best for recurring text inside longer messages. EXACT is safest for one complete line.")
	self.blockSaveButton = Theme:CreateTightButton(messagePane, "SAVE RULE", 20, true)
	setActionStyle(self.blockSaveButton, "primary", "Save this block", "Applies the current rule immediately.")
	self.blockSaveButton:SetPoint("TOPLEFT", messagePane, "TOPLEFT", 0, -174)
	self.blockSaveButton:SetScript("OnClick", function() Config:SaveBlockRule(false) end)
	self.blockDeleteButton = Theme:CreateTightButton(messagePane, "DELETE", 20, false)
	setActionStyle(self.blockDeleteButton, "danger", "Delete this block", "Removes the selected block rule after confirmation.")
	self.blockDeleteButton:SetPoint("LEFT", self.blockSaveButton, "RIGHT", CONTROL_GAP, 0)
	self.blockDeleteButton:SetScript("OnClick", function() Config:DeleteBlockRule() end)

	local playerTitle = Theme:CreateText(playerPane, "GameFontNormalSmall", "gold")
	playerTitle:SetPoint("TOPLEFT", playerPane, "TOPLEFT", 0, 0)
	playerTitle:SetText("WHO CAN MATCH THIS RULE?")
	local playerDetail = Theme:CreateText(playerPane, "GameFontHighlightSmall", "textMuted")
	playerDetail:SetPoint("TOPLEFT", playerPane, "TOPLEFT", 0, -20)
	playerDetail:SetWidth(422)
	playerDetail:SetJustifyH("LEFT")
	playerDetail:SetText("A rule made from Shift-hover remembers that message's player. A manually created rule begins broad.")
	local savedPlayerLabel = Theme:CreateText(playerPane, "GameFontHighlightSmall", "textMuted")
	savedPlayerLabel:SetPoint("TOPLEFT", playerPane, "TOPLEFT", 0, -56)
	savedPlayerLabel:SetText("SAVED PLAYER")
	self.blockSenderText = Theme:CreateText(playerPane, "GameFontNormal", "textMuted")
	self.blockSenderText:SetPoint("TOPLEFT", playerPane, "TOPLEFT", 0, -70)
	self.blockSenderText:SetWidth(422)
	self.blockSenderText:SetJustifyH("LEFT")
	self.blockAllSendersToggle = Theme:CreateCompactToggle(playerPane, "ANY PLAYER", 152)
	self.blockAllSendersToggle:SetPoint("TOPLEFT", playerPane, "TOPLEFT", 0, -100)
	self.blockAllSendersToggle.OnValueChanged = function(_, value) Config:SetBlockAllSenders(value) end
	setControlTooltip(self.blockAllSendersToggle, "Apply to any player", "Broadens this rule and removes its saved identity. Use Shift-hover on a player message to create another targeted rule.")
	self.blockSenderHint = Theme:CreateText(playerPane, "GameFontHighlightSmall", "textMuted")
	self.blockSenderHint:SetPoint("TOPLEFT", playerPane, "TOPLEFT", 0, -128)
	self.blockSenderHint:SetWidth(422)
	self.blockSenderHint:SetJustifyH("LEFT")

	local scopeTitle = Theme:CreateText(wherePane, "GameFontNormalSmall", "gold")
	scopeTitle:SetPoint("TOPLEFT", wherePane, "TOPLEFT", 0, 0)
	scopeTitle:SetText("LIMIT BY")
	self.blockScopeSourcesButton = Theme:CreateTightButton(wherePane, "SOURCES", 20, false)
	self.blockScopeSourcesButton:SetPoint("TOPLEFT", wherePane, "TOPLEFT", 72, 3)
	self.blockScopeSourcesButton:SetScript("OnClick", function() Config:SetBlockScopeMode("sources") end)
	setActionStyle(self.blockScopeSourcesButton, "choice", "Chat sources", "Choose the visible chat sources where this rule is allowed to hide messages.")
	self.blockScopeEventsButton = Theme:CreateTightButton(wherePane, "MESSAGE TYPES", 20, false)
	self.blockScopeEventsButton:SetPoint("LEFT", self.blockScopeSourcesButton, "RIGHT", CONTROL_GAP, 0)
	self.blockScopeEventsButton:SetScript("OnClick", function() Config:SetBlockScopeMode("events") end)
	setActionStyle(self.blockScopeEventsButton, "choice", "Message types", "Choose the underlying WoW message types where this rule is allowed to run.")
	self.blockAllSourcesToggle = Theme:CreateCompactToggle(wherePane, "ALL SOURCES", 154)
	self.blockAllSourcesToggle:SetPoint("TOPLEFT", wherePane, "TOPLEFT", 0, -30)
	self.blockAllSourcesToggle.OnValueChanged = function(_, value) Config:SetBlockAllScope("sources", value) end
	setControlTooltip(self.blockAllSourcesToggle, "Use every source", "Turn this off to reveal a checklist of exact chat sources.")
	self.blockAllEventsToggle = Theme:CreateCompactToggle(wherePane, "ALL MESSAGE TYPES", 194)
	self.blockAllEventsToggle:SetPoint("TOPLEFT", wherePane, "TOPLEFT", 0, -30)
	self.blockAllEventsToggle.OnValueChanged = function(_, value) Config:SetBlockAllScope("events", value) end
	setControlTooltip(self.blockAllEventsToggle, "Use every message type", "Turn this off to reveal a checklist of exact WoW chat event types.")
	self.blockScopeHint = Theme:CreateText(wherePane, "GameFontHighlightSmall", "textMuted")
	self.blockScopeHint:SetPoint("TOPLEFT", wherePane, "TOPLEFT", 0, -54)
	self.blockScopeHint:SetWidth(422)
	self.blockScopeHint:SetJustifyH("LEFT")
	self.blockScopeRows = {}
	for index = 1, BLOCK_SCOPE_PAGE_SIZE do
		local column = (index - 1) % 2
		local scopeRow = math.floor((index - 1) / 2)
		local toggle = Theme:CreateCompactToggle(wherePane, "Scope", 207)
		toggle:SetPoint("TOPLEFT", wherePane, "TOPLEFT", column * 211, -80 - (scopeRow * 23))
		toggle.OnValueChanged = function(self, value)
			if self.itemId and self.scopeKind then Config:SetBlockScopeItem(self.scopeKind, self.itemId, value) end
		end
		setControlTooltip(toggle, "Include this location", "Only checked items can be affected when the ALL option above is off.")
		table.insert(self.blockScopeRows, toggle)
	end
	self.blockScopeCount = Theme:CreateText(wherePane, "GameFontHighlightSmall", "textMuted")
	self.blockScopeCount:SetPoint("TOPLEFT", wherePane, "TOPLEFT", 0, -177)
	self.blockScopeCount:SetWidth(128)
	self.blockScopePrevious = Theme:CreateTightButton(wherePane, "<", 20, false)
	self.blockScopePrevious:SetPoint("TOPLEFT", wherePane, "TOPLEFT", 128, -171)
	self.blockScopePrevious:SetScript("OnClick", function()
		Config.blockScopePage = math.max(1, (Config.blockScopePage or 1) - 1)
		Config:RefreshBlockScope()
	end)
	self.blockScopeNext = Theme:CreateTightButton(wherePane, ">", 20, false)
	self.blockScopeNext:SetPoint("LEFT", self.blockScopePrevious, "RIGHT", CONTROL_GAP, 0)
	self.blockScopeNext:SetScript("OnClick", function()
		Config.blockScopePage = (Config.blockScopePage or 1) + 1
		Config:RefreshBlockScope()
	end)

	self.blocksStatus = Theme:CreateText(work, "GameFontHighlightSmall", "textMuted")
	self.blocksStatus:SetPoint("BOTTOMLEFT", work, "BOTTOMLEFT", 188, 10)
	self.blocksStatus:SetWidth(422)
	self.blocksStatus:SetJustifyH("LEFT")

	-- Local UI failures have no player and are not ordinary phrase rules. Keep
	-- their repeat suppression in its own page-level utility strip so editing a
	-- block never appears to modify cooldown/error handling by accident.
	local repeats = createQuietShellPanel(page, "surface")
	repeats:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -442)
	repeats:SetSize(PAGE_WIDTH, 56)
	local repeatsTitle = Theme:CreateText(repeats, "GameFontNormalSmall", "gold")
	repeatsTitle:SetPoint("TOPLEFT", repeats, "TOPLEFT", 6, -5)
	repeatsTitle:SetText("UI ERROR REPEATS")
	local repeatsHint = Theme:CreateText(repeats, "GameFontHighlightSmall", "textMuted")
	repeatsHint:SetPoint("TOPLEFT", repeats, "TOPLEFT", 6, -23)
	repeatsHint:SetWidth(332)
	repeatsHint:SetJustifyH("LEFT")
	repeatsHint:SetText("Combines rapid identical cooldown and action errors; distinct errors still appear.")
	self.blockCoalesceToggle = Theme:CreateCompactToggle(repeats, "COMBINE REPEATS", 160)
	self.blockCoalesceToggle:SetPoint("TOPLEFT", repeats, "TOPLEFT", 344, -5)
	self.blockCoalesceToggle.OnValueChanged = function() Config:CommitBlockCoalescing() end
	setControlTooltip(self.blockCoalesceToggle, "Combine identical UI errors", "Keeps the first error visible, then hides only identical copies inside the time window.")
	local windowLabel = Theme:CreateText(repeats, "GameFontHighlightSmall", "textMuted")
	windowLabel:SetPoint("TOPLEFT", repeats, "TOPLEFT", 510, -11)
	windowLabel:SetText("SECONDS")
	self.blockWindowEdit = Theme:CreateEditBox(repeats, 48, 22, false)
	self.blockWindowEdit:SetPoint("TOPLEFT", repeats, "TOPLEFT", 578, -5)
	self.blockWindowEdit:SetMaxLetters(4)
	self.blockWindowEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.blockWindowEdit:HookScript("OnEditFocusLost", function() Config:CommitBlockCoalescing() end)
	setControlTooltip(self.blockWindowEdit, "Repeat window in seconds", "Allowed range: 0.25 to 10 seconds.")
	self.blockRulesFrames = { work, repeats }

	-- Blocked Messages is a separate review task, not a fourth nested rule pane.
	-- It occupies the same bounded workspace as the rules and keeps an explicit
	-- 8px outer gutter plus 10px around its divider at the minimum config size.
	local archivePanel = createQuietShellPanel(page, "surface")
	archivePanel:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -PAGE_TOP)
	archivePanel:SetSize(PAGE_WIDTH, 452)
	archivePanel:Hide()
	self.blockedArchivePanel = archivePanel

	self.blockedArchiveEnabledToggle = Theme:CreateCompactToggle(archivePanel, "KEEP ARCHIVE", 156)
	self.blockedArchiveEnabledToggle:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 8, -6)
	self.blockedArchiveEnabledToggle.OnValueChanged = function(_, enabled)
		local ok, accepted
		if type(addon.SetBlockedMessageArchiveEnabled) == "function" then
			ok, accepted = pcall(addon.SetBlockedMessageArchiveEnabled, addon, enabled == true)
		else
			local archive = getMessageBlockSettings().archive or {}
			getMessageBlockSettings().archive = archive
			archive.enabled = enabled and true or false
			if not archive.enabled then archive.entries = {} archive.nextSequence = 1 end
			ok, accepted = true, true
		end
		Config.selectedBlockedArchiveId = nil
		Config.blockedArchivePage = 1
		Config:RefreshBlockedMessagesPage(true)
		Config:SetBlockedArchiveStatus(ok and accepted ~= false and (enabled
			and "Blocked-message review is enabled. Expired entries are cleaned automatically."
			or "Archive disabled and retained blocked-message plaintext erased.")
			or "Archive privacy setting could not be changed.", ok and accepted ~= false and "success" or "danger")
	end
	setControlTooltip(self.blockedArchiveEnabledToggle, "Keep blocked-message history",
		"Stores a bounded plaintext review copy in this profile's SavedVariables. Turning it off erases the archive immediately; rules keep blocking.")

	local retentionLabel = Theme:CreateText(archivePanel, "GameFontHighlightSmall", "textMuted")
	retentionLabel:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 178, -11)
	retentionLabel:SetWidth(86)
	retentionLabel:SetJustifyH("LEFT")
	retentionLabel:SetText("DAYS")
	self.blockedArchiveRetentionEdit = Theme:CreateEditBox(archivePanel, 46, 22, false)
	self.blockedArchiveRetentionEdit:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 270, -6)
	self.blockedArchiveRetentionEdit:SetMaxLetters(2)
	setControlTooltip(self.blockedArchiveRetentionEdit, "Automatic cleanup age", "Keep blocked-message aggregates for 1 to 90 days. Cleanup runs on capture, review, and profile load.")
	local function commitArchiveRetention()
		local value = tonumber(Config.blockedArchiveRetentionEdit:GetText())
		if not value or value < 1 or value > 90 then
			Config:RefreshBlockedMessagesPage(true)
			Config:SetBlockedArchiveStatus("Retention must be a whole number from 1 to 90 days.", "warning")
			return
		end
		local ok, accepted = pcall(addon.SetBlockedMessageArchiveRetentionDays, addon, value)
		Config:RefreshBlockedMessagesPage(true)
		Config:SetBlockedArchiveStatus(ok and accepted == true and "Blocked-message retention updated; expired entries were removed now."
			or "Retention could not be updated.", ok and accepted == true and "success" or "danger")
	end
	self.blockedArchiveRetentionEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.blockedArchiveRetentionEdit:HookScript("OnEditFocusLost", commitArchiveRetention)

	local capacityLabel = Theme:CreateText(archivePanel, "GameFontHighlightSmall", "textMuted")
	capacityLabel:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 330, -11)
	capacityLabel:SetWidth(30)
	capacityLabel:SetJustifyH("LEFT")
	capacityLabel:SetText("CAP")
	self.blockedArchiveCapacityEdit = Theme:CreateEditBox(archivePanel, 52, 22, false)
	self.blockedArchiveCapacityEdit:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 366, -6)
	self.blockedArchiveCapacityEdit:SetMaxLetters(4)
	setControlTooltip(self.blockedArchiveCapacityEdit, "Maximum unique blocked messages", "Keep 25 to 1,000 unique sender/message/rule aggregates. Older entries are removed first.")
	local function commitArchiveCapacity()
		local value = tonumber(Config.blockedArchiveCapacityEdit:GetText())
		if not value or value < 25 or value > 1000 then
			Config:RefreshBlockedMessagesPage(true)
			Config:SetBlockedArchiveStatus("Archive cap must be a whole number from 25 to 1,000.", "warning")
			return
		end
		local ok, accepted = pcall(addon.SetBlockedMessageArchiveCapacity, addon, value)
		Config:RefreshBlockedMessagesPage(true)
		Config:SetBlockedArchiveStatus(ok and accepted == true and "Blocked-message archive cap updated; excess oldest entries were removed now."
			or "Archive cap could not be updated.", ok and accepted == true and "success" or "danger")
	end
	self.blockedArchiveCapacityEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.blockedArchiveCapacityEdit:HookScript("OnEditFocusLost", commitArchiveCapacity)

	self.blockedArchiveClearButton = Theme:CreateTightButton(archivePanel, "CLEAR ARCHIVE", 20, false)
	self.blockedArchiveClearButton:SetPoint("TOPRIGHT", archivePanel, "TOPRIGHT", -8, -6)
	setActionStyle(self.blockedArchiveClearButton, "danger", "Clear blocked-message history",
		"Erases archived plaintext and occurrence times. Message Block rules, Spam Firewall evidence, and normal chat history are unchanged.")
	self.blockedArchiveClearButton:SetScript("OnClick", function()
		if not Config.pendingClearBlockedArchive then
			Config.pendingClearBlockedArchive = true
			setTightButtonLabel(Config.blockedArchiveClearButton, "CONFIRM CLEAR")
			Config:SetBlockedArchiveStatus("Click CONFIRM CLEAR to erase only the blocked-message archive.", "warning")
			return
		end
		local ok, accepted = pcall(addon.ClearBlockedMessageArchive, addon)
		Config.pendingClearBlockedArchive = nil
		Config.selectedBlockedArchiveId = nil
		Config.blockedArchivePage = 1
		setTightButtonLabel(Config.blockedArchiveClearButton, "CLEAR ARCHIVE")
		Config:RefreshBlockedMessagesPage(true)
		Config:SetBlockedArchiveStatus(ok and accepted == true and "Blocked-message archive cleared. Rules and Spam Firewall evidence were kept."
			or "Blocked-message archive could not be cleared.", ok and accepted == true and "success" or "danger")
	end)

	local privacy = Theme:CreateText(archivePanel, "GameFontHighlightSmall", "textMuted")
	privacy:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 8, -34)
	privacy:SetWidth(620)
	privacy:SetHeight(28)
	privacy:SetJustifyH("LEFT")
	if privacy.SetJustifyV then privacy:SetJustifyV("TOP") end
	privacy:SetText("Only messages quarantined by your own Message Block rules appear here. Text is stored locally until it expires, is cleared, or KEEP ARCHIVE is turned off.")

	local archiveDivider = archivePanel:CreateTexture(nil, "ARTWORK")
	archiveDivider:SetTexture("Interface\\Buttons\\WHITE8x8")
	Theme:RegisterTexture(archiveDivider, "borderMuted")
	archiveDivider:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 266, -76)
	archiveDivider:SetPoint("BOTTOMLEFT", archivePanel, "BOTTOMLEFT", 266, 26)
	archiveDivider:SetWidth(1)

	local archiveListTitle = Theme:CreateText(archivePanel, "GameFontNormalSmall", "gold")
	archiveListTitle:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 8, -76)
	archiveListTitle:SetText("QUARANTINED MESSAGES")
	self.blockedArchiveRows = {}
	for index = 1, BLOCK_ARCHIVE_PAGE_SIZE do
		local row = Theme:CreateButton(archivePanel, "", 248, 36, false)
		row:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 8, -96 - ((index - 1) * 37))
		row.text:ClearAllPoints()
		row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -3)
		row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -3)
		row.text:SetHeight(14)
		row.text:SetJustifyH("LEFT")
		if row.text.SetWordWrap then row.text:SetWordWrap(false) end
		row.detail = Theme:CreateText(row, "GameFontHighlightSmall", "textMuted")
		row.detail:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 3)
		row.detail:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 3)
		row.detail:SetHeight(13)
		row.detail:SetJustifyH("LEFT")
		if row.detail.SetWordWrap then row.detail:SetWordWrap(false) end
		row:SetScript("OnClick", function(self)
			if self.entryId then Config:SelectBlockedArchiveEntry(self.entryId) end
		end)
		self.blockedArchiveRows[index] = row
	end
	self.blockedArchiveCount = Theme:CreateText(archivePanel, "GameFontHighlightSmall", "textMuted")
	self.blockedArchiveCount:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 8, -400)
	self.blockedArchiveCount:SetWidth(150)
	self.blockedArchiveCount:SetJustifyH("LEFT")
	self.blockedArchivePrevious = Theme:CreateTightButton(archivePanel, "<", 20, false)
	self.blockedArchivePrevious:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 166, -394)
	self.blockedArchivePrevious:SetScript("OnClick", function()
		Config.blockedArchivePage = math.max(1, (Config.blockedArchivePage or 1) - 1)
		Config.selectedBlockedArchiveId = nil
		Config:RefreshBlockedMessagesPage(true)
	end)
	self.blockedArchiveNext = Theme:CreateTightButton(archivePanel, ">", 20, false)
	self.blockedArchiveNext:SetPoint("LEFT", self.blockedArchivePrevious, "RIGHT", CONTROL_GAP, 0)
	self.blockedArchiveNext:SetScript("OnClick", function()
		Config.blockedArchivePage = (Config.blockedArchivePage or 1) + 1
		Config.selectedBlockedArchiveId = nil
		Config:RefreshBlockedMessagesPage(true)
	end)

	self.blockedArchiveDetailTitle = Theme:CreateText(archivePanel, "GameFontNormal", "goldBright")
	self.blockedArchiveDetailTitle:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 278, -76)
	self.blockedArchiveDetailTitle:SetWidth(350)
	self.blockedArchiveDetailTitle:SetJustifyH("LEFT")
	self.blockedArchiveDetailMeta = Theme:CreateText(archivePanel, "GameFontHighlightSmall", "textMuted")
	self.blockedArchiveDetailMeta:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 278, -98)
	self.blockedArchiveDetailMeta:SetWidth(350)
	self.blockedArchiveDetailMeta:SetJustifyH("LEFT")
	local messageLabel = Theme:CreateText(archivePanel, "GameFontNormalSmall", "gold")
	messageLabel:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 278, -128)
	messageLabel:SetText("ORIGINAL BLOCKED TEXT")
	self.blockedArchiveDetailText = Theme:CreateText(archivePanel, "GameFontHighlight", "text")
	self.blockedArchiveDetailText:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 278, -148)
	self.blockedArchiveDetailText:SetWidth(350)
	self.blockedArchiveDetailText:SetHeight(116)
	self.blockedArchiveDetailText:SetJustifyH("LEFT")
	if self.blockedArchiveDetailText.SetJustifyV then self.blockedArchiveDetailText:SetJustifyV("TOP") end
	self.blockedArchiveDetailRule = Theme:CreateText(archivePanel, "GameFontHighlightSmall", "warning")
	self.blockedArchiveDetailRule:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 278, -282)
	self.blockedArchiveDetailRule:SetWidth(350)
	self.blockedArchiveDetailRule:SetJustifyH("LEFT")
	self.blockedArchiveDetailTiming = Theme:CreateText(archivePanel, "GameFontHighlightSmall", "textMuted")
	self.blockedArchiveDetailTiming:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 278, -310)
	self.blockedArchiveDetailTiming:SetWidth(350)
	self.blockedArchiveDetailTiming:SetHeight(42)
	self.blockedArchiveDetailTiming:SetJustifyH("LEFT")
	if self.blockedArchiveDetailTiming.SetJustifyV then self.blockedArchiveDetailTiming:SetJustifyV("TOP") end
	local archiveNote = Theme:CreateText(archivePanel, "GameFontHighlightSmall", "textMuted")
	archiveNote:SetPoint("TOPLEFT", archivePanel, "TOPLEFT", 278, -360)
	archiveNote:SetWidth(350)
	archiveNote:SetHeight(36)
	archiveNote:SetJustifyH("LEFT")
	if archiveNote.SetJustifyV then archiveNote:SetJustifyV("TOP") end
	archiveNote:SetText("Deleting or pausing a rule stops future blocking; quarantined messages do not silently return to normal chat history.")
	self.blockedArchiveStatus = Theme:CreateText(archivePanel, "GameFontHighlightSmall", "textMuted")
	self.blockedArchiveStatus:SetPoint("BOTTOMLEFT", archivePanel, "BOTTOMLEFT", 278, 8)
	self.blockedArchiveStatus:SetWidth(350)
	self.blockedArchiveStatus:SetHeight(28)
	self.blockedArchiveStatus:SetJustifyH("LEFT")
	if self.blockedArchiveStatus.SetJustifyV then self.blockedArchiveStatus:SetJustifyV("BOTTOM") end

	self.blockEditorControls = {
		self.blockNameEdit, self.blockTextEdit, self.blockEnabledToggle, self.blockCaseToggle,
		self.blockExactButton, self.blockContainsButton, self.blockAllSourcesToggle, self.blockAllEventsToggle, self.blockAllSendersToggle,
		self.blockSaveButton, self.blockDeleteButton, self.blockScopeSourcesButton, self.blockScopeEventsButton,
	}
	self.blockNameEdit:SetScript("OnTabPressed", function() Config.blockTextEdit:SetFocus() end)
	self.blockTextEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() Config:SaveBlockRule(false) end)
	self.blockRulePage = 1
	self.blockScopePage = 1
	self.blockScopeMode = "sources"
	self.blocksSection = self.blocksSection == "archive" and "archive" or "rules"
	self.blockedArchivePage = 1
	self.blockInspectorMode = "message"
	self:RefreshBlocksPage()
	return page
end

local function getMessengerSettings()
	if type(addon.GetMessengerSettings) == "function" then
		return addon:GetMessengerSettings()
	end
	local settings = addon:GetSmartSettings()
	settings.conversations = settings.conversations or {}
	return settings.conversations
end

local function applyMessengerRuntime()
	local manager = addon.ConversationWindows
	if not manager then
		return
	end
	if manager.ApplySettings then
		manager:ApplySettings()
	elseif manager.RefreshSettings then
		manager:RefreshSettings()
	end
end

local function setMessengerBoolean(apiName, fallbackKey, value)
	if type(addon[apiName]) == "function" then
		return addon[apiName](addon, value)
	end
	local settings = addon:GetSmartSettings()
	settings.conversations = settings.conversations or {}
	settings.conversations[fallbackKey] = value and true or false
	applyMessengerRuntime()
	return true, settings.conversations[fallbackKey]
end

local function setMessengerVisibility(element, mode)
	if type(addon.SetMessengerElementVisibility) == "function" then
		return addon:SetMessengerElementVisibility(element, mode)
	end
	local keys = { title = "titleBarVisibility", actions = "actionVisibility", composer = "composerVisibility" }
	local key = keys[element]
	if not key then return false end
	local settings = addon:GetSmartSettings()
	settings.conversations = settings.conversations or {}
	settings.conversations[key] = mode
	applyMessengerRuntime()
	return true, mode
end

local function setMessengerActionStyle(style)
	if type(addon.SetMessengerActionButtonStyle) == "function" then
		return addon:SetMessengerActionButtonStyle(style)
	end
	local settings = addon:GetSmartSettings()
	settings.conversations = settings.conversations or {}
	settings.conversations.actionButtonStyle = style
	applyMessengerRuntime()
	return true, style
end

local function setMessengerActionStripOrientation(orientation)
	if type(addon.SetMessengerActionStripOrientation) == "function" then
		return addon:SetMessengerActionStripOrientation(orientation)
	end
	local settings = addon:GetSmartSettings()
	settings.conversations = settings.conversations or {}
	settings.conversations.actionStripOrientation = orientation == "vertical" and "vertical" or "horizontal"
	applyMessengerRuntime()
	return true, settings.conversations.actionStripOrientation
end

local function setMessengerActionStripCollapsed(collapsed)
	if type(addon.SetMessengerActionStripCollapsed) == "function" then
		return addon:SetMessengerActionStripCollapsed(collapsed)
	end
	local settings = addon:GetSmartSettings()
	settings.conversations = settings.conversations or {}
	settings.conversations.actionStripCollapsed = collapsed and true or false
	applyMessengerRuntime()
	return true, settings.conversations.actionStripCollapsed
end

local function setMessengerTabNameMaxLength(value)
	if type(addon.SetMessengerTabNameMaxLength) == "function" then
		return addon:SetMessengerTabNameMaxLength(value)
	end
	local settings = addon:GetSmartSettings()
	settings.conversations = settings.conversations or {}
	settings.conversations.tabNameMaxLength = value
	applyMessengerRuntime()
	return true, value
end

local messengerAppearanceDefaultTokens = {
	window = "background",
	title = "surfaceRaised",
	tabs = "surface",
	chat = "inset",
	reply = "surfaceRaised",
	border = "border",
}

local function getMessengerAppearanceSettings()
	if type(addon.GetMessengerAppearanceSettings) == "function" then
		local ok, appearance = pcall(addon.GetMessengerAppearanceSettings, addon)
		if ok and type(appearance) == "table" then return appearance end
	end
	local settings = addon:GetSmartSettings()
	settings.conversations = settings.conversations or {}
	settings.conversations.appearance = settings.conversations.appearance or {
		schema = 1,
		transparency = { backgroundAlpha = 1, borderAlpha = 1, textAlpha = 1, overallAlpha = 1 },
		colors = {},
	}
	settings.conversations.appearance.transparency = settings.conversations.appearance.transparency or {}
	settings.conversations.appearance.colors = settings.conversations.appearance.colors or {}
	return settings.conversations.appearance
end

local function setMessengerAppearanceAlpha(apiName, key, value)
	if type(addon[apiName]) == "function" then
		return addon[apiName](addon, value)
	end
	local appearance = getMessengerAppearanceSettings()
	appearance.transparency[key] = math.max(0, math.min(1, tonumber(value) or 1))
	applyMessengerRuntime()
	return true, appearance.transparency[key]
end

local function setMessengerAppearanceColor(target, spec)
	if type(addon.SetMessengerAppearanceColor) == "function" then
		return addon:SetMessengerAppearanceColor(target, spec)
	end
	local appearance = getMessengerAppearanceSettings()
	appearance.colors[target] = spec
	applyMessengerRuntime()
	return true, spec
end

local messengerSectionDefinitions = {
	opening = {
		label = "OPENING",
		heading = "Opening",
		hint = "Choose when a new private conversation opens the shared Messenger window.",
	},
	tabs = {
		label = "TABS",
		heading = "Conversation tabs",
		hint = "Choose how much of each player name the Messenger tab rail may show.",
	},
	visibility = {
		label = "VISIBILITY",
		heading = "Window visibility",
		hint = "Give the title, player actions, and reply field one clear reveal policy each.",
	},
	actions = {
		label = "ACTIONS",
		heading = "Player actions",
		hint = "Choose how Reply, Invite, Friend, Chatty Mute, and WoW Ignore are presented.",
	},
	appearance = {
		label = "APPEARANCE",
		heading = "Appearance",
		hint = "Tune Messenger surfaces independently while keeping meaningful message colors intact.",
	},
}

local messengerSectionOrder = { "opening", "tabs", "visibility", "actions", "appearance" }

function Config:SetMessengerSection(section)
	if not messengerSectionDefinitions[section] then
		section = "opening"
	end
	self.messengerSection = section
	self:RefreshMessengerPage()
	return section
end

function Config:RefreshMessengerSections()
	if not self.messengerPage then
		return
	end
	local section = messengerSectionDefinitions[self.messengerSection] and self.messengerSection or "opening"
	self.messengerSection = section
	for id, controls in pairs(self.messengerSectionGroups or {}) do
		local visible = id == section
		for _, control in ipairs(controls) do
			if visible then control:Show() else control:Hide() end
		end
	end
	for id, button in pairs(self.messengerSectionButtons or {}) do
		setTabStyle(button, id == section)
	end
	local definition = messengerSectionDefinitions[section]
	if self.messengerSectionTitle then
		self.messengerSectionTitle:SetText(definition.heading)
	end
	if self.messengerSectionHint then
		self.messengerSectionHint:SetText(definition.hint)
	end
end

function Config:RefreshMessengerPage()
	if not self.messengerPage then
		return
	end

	local settings = getMessengerSettings()
	if self.messengerWhispersToggle then
		self.messengerWhispersToggle:SetValue(settings.autoOpenWhispers ~= false, true)
	end
	if self.messengerCombatToggle then
		self.messengerCombatToggle:SetValue(settings.deferInCombat ~= false, true)
	end
	if self.messengerTellTargetToggle then
		self.messengerTellTargetToggle:SetValue(settings.tellTargetEnabled ~= false, true)
	end
	if self.messengerReplyCommandFocusToggle then
		self.messengerReplyCommandFocusToggle:SetValue(settings.focusReplyFieldOnCommands ~= false, true)
	end
	if self.messengerTabNameMaxLengthEdit then
		local tabNameMaxLength = tonumber(settings.tabNameMaxLength)
		if not tabNameMaxLength or tabNameMaxLength ~= math.floor(tabNameMaxLength)
			or tabNameMaxLength < 4 or tabNameMaxLength > 32 then
			tabNameMaxLength = 14
		end
		self.messengerTabNameMaxLengthEdit:SetText(tostring(tabNameMaxLength))
	end
	if self.messengerChromeAutoHideToggle then
		self.messengerChromeAutoHideToggle:SetValue(settings.chromeAutoHide == true, true)
	end

	local visibility = {
		title = settings.titleBarVisibility or "inherit",
		actions = settings.actionVisibility or "inherit",
		composer = settings.composerVisibility or "inherit",
	}
	local resolved = {
		title = settings.resolvedTitleBarVisibility,
		actions = settings.resolvedActionVisibility,
		composer = settings.resolvedComposerVisibility,
	}
	for element, row in pairs(self.messengerVisibilityRows or {}) do
		local selected = visibility[element]
		for mode, button in pairs(row.buttons or {}) do
			setChoiceStyle(button, mode == selected)
		end
		local current = resolved[element]
		if not current then
			current = selected == "inherit" and (settings.chromeAutoHide and "auto" or "always") or selected
		end
		local currentLabel = current == "auto" and "MOUSEOVER"
			or (current == "click" and "ON CLICK" or string.upper(current or "always"))
		row.resolved:SetText("NOW: " .. currentLabel)
	end

	local iconsActive = settings.actionButtonStyle == "icons"
	setChoiceStyle(self.messengerTextButtons, not iconsActive)
	setChoiceStyle(self.messengerIconButtons, iconsActive)
	local vertical = settings.actionStripOrientation == "vertical"
	setChoiceStyle(self.messengerHorizontalButton, not vertical)
	setChoiceStyle(self.messengerVerticalButton, vertical)
	if self.messengerActionCollapsedToggle then
		self.messengerActionCollapsedToggle:SetValue(settings.actionStripCollapsed == true, true)
		local policyCollapsed = visibility.actions == "collapsed"
		if policyCollapsed and self.messengerActionCollapsedToggle.Disable then
			self.messengerActionCollapsedToggle:Disable()
		elseif not policyCollapsed and self.messengerActionCollapsedToggle.Enable then
			self.messengerActionCollapsedToggle:Enable()
		end
	end

	local appearance = settings.appearance or getMessengerAppearanceSettings()
	local transparency = appearance.transparency or {}
	for key, editBox in pairs(self.messengerAppearanceAlphaEdits or {}) do
		editBox:SetText(tostring(math.floor(((tonumber(transparency[key]) or 1) * 100) + 0.5)))
	end
	local target = self.messengerAppearanceColorTarget or "window"
	if not messengerAppearanceDefaultTokens[target] then target = "window" end
	self.messengerAppearanceColorTarget = target
	for id, button in pairs(self.messengerAppearanceTargetButtons or {}) do
		setChoiceStyle(button, id == target)
	end
	local spec = appearance.colors and appearance.colors[target] or { mode = "inherit" }
	local selectedPreset = spec.mode == "inherit" and "inherit"
		or (spec.mode == "theme" and spec.theme or nil)
	for id, button in pairs(self.messengerAppearancePresetButtons or {}) do
		setChoiceStyle(button, id == selectedPreset)
	end
	local r, g, b
	if spec.mode == "custom" then
		r, g, b = spec.r, spec.g, spec.b
	else
		local token = spec.mode == "theme" and spec.theme or messengerAppearanceDefaultTokens[target]
		r, g, b = Theme:GetColor(token)
	end
	local channels = { r, g, b }
	for index, editBox in ipairs(self.messengerAppearanceColorEdits or {}) do
		editBox:SetText(tostring(math.floor(((tonumber(channels[index]) or 1) * 255) + 0.5)))
	end
	self:RefreshMessengerSections()
end

function Config:BuildMessengerPage()
	local page = self:CreatePage("messenger")
	self.messengerPage = page
	self.messengerHeading = createHeading(page, "Messenger", "Private conversations share one window, with a compact tab for each player.")

	self.messengerSectionButtons = {}
	local previousSectionButton
	for _, id in ipairs(messengerSectionOrder) do
		local sectionId = id
		local definition = messengerSectionDefinitions[id]
		local button = Theme:CreateTightButton(page, definition.label, 22, false)
		if previousSectionButton then
			button:SetPoint("LEFT", previousSectionButton, "RIGHT", 6, 0)
		else
			button:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -48)
		end
		setControlTooltip(button, definition.heading, definition.hint)
		button:SetScript("OnClick", function()
			Config:SetMessengerSection(sectionId)
		end)
		self.messengerSectionButtons[id] = button
		previousSectionButton = button
	end

	self.messengerSectionTitle = Theme:CreateText(page, "GameFontNormal", "goldBright")
	self.messengerSectionTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -82)
	self.messengerSectionHint = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	self.messengerSectionHint:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -101)
	self.messengerSectionHint:SetWidth(PAGE_WIDTH)
	self.messengerSectionHint:SetJustifyH("LEFT")

	local openingControls = {}
	local function addOpening(control)
		table.insert(openingControls, control)
		return control
	end
	local behaviorTitle = addOpening(Theme:CreateText(page, "GameFontNormalSmall", "gold"))
	behaviorTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -132)
	behaviorTitle:SetText("AUTOMATIC OPENING")

	self.messengerWhispersToggle = addOpening(Theme:CreateCompactToggle(page, "AUTO-OPEN WHISPERS", PAGE_WIDTH))
	self.messengerWhispersToggle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -151)
	self.messengerWhispersToggle.OnValueChanged = function(_, value)
		setMessengerBoolean("SetMessengerPopupWhispersEnabled", "autoOpenWhispers", value)
	end
	setControlTooltip(self.messengerWhispersToggle, "Auto-open incoming whispers", "Opens Messenger when another player whispers you. A tab and unread count are retained either way.")

	self.messengerCombatToggle = addOpening(Theme:CreateCompactToggle(page, "WAIT UNTIL COMBAT ENDS", PAGE_WIDTH))
	self.messengerCombatToggle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -181)
	self.messengerCombatToggle.OnValueChanged = function(_, value)
		setMessengerBoolean("SetMessengerCombatDeferralEnabled", "deferInCombat", value)
	end
	setControlTooltip(self.messengerCombatToggle, "Wait until combat ends", "Queues automatic popup requests during combat. An explicit reply still opens immediately.")

	local behaviorDetail = addOpening(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	behaviorDetail:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -214)
	behaviorDetail:SetWidth(PAGE_WIDTH)
	behaviorDetail:SetHeight(36)
	behaviorDetail:SetJustifyH("LEFT")
	behaviorDetail:SetText("New whispers join the existing Messenger shell. /r, Reply, and player-name actions can still open it when automatic opening is off.")

	local shortcutsTitle = addOpening(Theme:CreateText(page, "GameFontNormalSmall", "gold"))
	shortcutsTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -264)
	shortcutsTitle:SetText("CHAT SHORTCUTS")

	self.messengerTellTargetToggle = addOpening(Theme:CreateCompactToggle(page, "ENABLE /TT TELL TARGET", PAGE_WIDTH))
	self.messengerTellTargetToggle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -283)
	self.messengerTellTargetToggle.OnValueChanged = function(_, value)
		setMessengerBoolean("SetTellTargetEnabled", "tellTargetEnabled", value)
		Config:RefreshMessengerPage()
	end
	setControlTooltip(self.messengerTellTargetToggle, "Tell your target with /tt",
		"With a player targeted, /tt opens that person's Messenger tab. Add text after /tt to send it immediately and keep the reply field ready.")

	self.messengerReplyCommandFocusToggle = addOpening(Theme:CreateCompactToggle(page, "FOCUS REPLY FIELD FOR /R AND /TT", PAGE_WIDTH))
	self.messengerReplyCommandFocusToggle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -313)
	self.messengerReplyCommandFocusToggle.OnValueChanged = function(_, value)
		setMessengerBoolean("SetMessengerReplyCommandFocusEnabled", "focusReplyFieldOnCommands", value)
		Config:RefreshMessengerPage()
	end
	setControlTooltip(self.messengerReplyCommandFocusToggle, "Focus Messenger after a chat shortcut",
		"Keeps the selected person's Messenger reply field focused after /r or /tt, including after sending /tt text. Turn it off to leave keyboard focus with the normal chat command.")

	local shortcutsDetail = addOpening(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	shortcutsDetail:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -346)
	shortcutsDetail:SetSize(PAGE_WIDTH, 42)
	shortcutsDetail:SetJustifyH("LEFT")
	if shortcutsDetail.SetJustifyV then shortcutsDetail:SetJustifyV("TOP") end
	shortcutsDetail:SetText("/tt uses your current player target. /r uses the last whisper target. Both select the matching Messenger tab; explicit commands ignore automatic-popup and combat deferral.")

	local tabControls = {}
	local function addTab(control)
		table.insert(tabControls, control)
		return control
	end
	self.messengerTabNameLengthTitle = addTab(Theme:CreateText(page, "GameFontNormalSmall", "gold"))
	self.messengerTabNameLengthTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -132)
	self.messengerTabNameLengthTitle:SetText("PLAYER NAME LENGTH")

	self.messengerTabNameMaxLengthEdit = addTab(Theme:CreateEditBox(page, 54, 22, false))
	self.messengerTabNameMaxLengthEdit:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -151)
	self.messengerTabNameMaxLengthEdit:SetMaxLetters(2)
	setControlTooltip(self.messengerTabNameMaxLengthEdit, "Player name length",
		"Sets the maximum player-name characters shown on a Messenger tab. Use a whole number from 4 to 32.")

	self.messengerTabNameLengthHint = addTab(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	self.messengerTabNameLengthHint:SetPoint("LEFT", self.messengerTabNameMaxLengthEdit, "RIGHT", 8, 0)
	self.messengerTabNameLengthHint:SetText("4-32 CHARACTERS")

	self.messengerTabNameLengthDetail = addTab(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	self.messengerTabNameLengthDetail:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -190)
	self.messengerTabNameLengthDetail:SetWidth(PAGE_WIDTH)
	self.messengerTabNameLengthDetail:SetHeight(32)
	self.messengerTabNameLengthDetail:SetJustifyH("LEFT")
	if self.messengerTabNameLengthDetail.SetJustifyV then
		self.messengerTabNameLengthDetail:SetJustifyV("TOP")
	end
	self.messengerTabNameLengthDetail:SetText("The limit includes '~'. Narrow Messenger windows may shorten names further to keep every tab control usable.")

	local function commitMessengerTabNameMaxLength()
		local rawValue = tostring(Config.messengerTabNameMaxLengthEdit:GetText() or "")
		local value = string.match(rawValue, "^%d+$") and tonumber(rawValue) or nil
		if not value or value ~= math.floor(value) or value < 4 or value > 32 then
			Config:RefreshMessengerPage()
			Config.messengerStatus:SetText("Use a whole player-name length from 4 to 32.")
			return
		end
		local ok, saved = setMessengerTabNameMaxLength(value)
		Config:RefreshMessengerPage()
		if ok == false then
			Config.messengerStatus:SetText("Player-name length could not be changed.")
			return
		end
		saved = tonumber(saved) or value
		Config.messengerStatus:SetText("Messenger player-name length set to " .. tostring(saved) .. " characters.")
	end
	self.messengerTabNameMaxLengthEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.messengerTabNameMaxLengthEdit:HookScript("OnEditFocusLost", commitMessengerTabNameMaxLength)

	local visibilityControls = {}
	local function addVisibility(control)
		table.insert(visibilityControls, control)
		return control
	end
	local autoTitle = addVisibility(Theme:CreateText(page, "GameFontNormalSmall", "gold"))
	autoTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -132)
	autoTitle:SetText("DEFAULT FOR INHERIT")

	self.messengerChromeAutoHideToggle = addVisibility(Theme:CreateCompactToggle(page, "HIDE CHROME WHEN IDLE", PAGE_WIDTH))
	self.messengerChromeAutoHideToggle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -151)
	self.messengerChromeAutoHideToggle.OnValueChanged = function(_, value)
		setMessengerBoolean("SetMessengerChromeAutoHideEnabled", "chromeAutoHide", value)
		Config:RefreshMessengerPage()
	end
	setControlTooltip(self.messengerChromeAutoHideToggle, "Shared Messenger auto-hide", "Every region set to INHERIT follows this switch. Explicit ALWAYS, MOUSEOVER, ON CLICK, COLLAPSED, and HIDDEN choices remain independent.")

	local autoDetail = addVisibility(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	autoDetail:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -178)
	autoDetail:SetWidth(PAGE_WIDTH)
	autoDetail:SetJustifyH("LEFT")
	autoDetail:SetText("INHERIT keeps these regions coordinated. A choice on a row below overrides this shared idle behavior.")

	local visibilityTitle = addVisibility(Theme:CreateText(page, "GameFontNormalSmall", "gold"))
	visibilityTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -212)
	visibilityTitle:SetText("WINDOW REGIONS")

	self.messengerVisibilityRows = {}
	local modeDefinitions = {
		{ id = "inherit", label = "INHERIT", detail = "Follow the shared idle setting above." },
		{ id = "always", label = "ALWAYS", detail = "Keep this region visible." },
		{ id = "auto", label = "MOUSEOVER", detail = "Show this region while the pointer is over Messenger." },
		{ id = "click", label = "ON CLICK", detail = "Reveal or reclaim this region by clicking the message area." },
		{ id = "hidden", label = "HIDDEN", detail = "Remove this region and reclaim its space." },
	}
	local function createVisibilityRow(element, label, y, help)
		local row = { buttons = {}, controls = {} }
		local rowLabel = addVisibility(Theme:CreateText(page, "GameFontNormalSmall", "text"))
		rowLabel:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -y)
		rowLabel:SetJustifyH("LEFT")
		rowLabel:SetText(label)
		row.label = rowLabel
		table.insert(row.controls, rowLabel)
		row.resolved = addVisibility(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
		row.resolved:SetPoint("TOPRIGHT", page, "TOPRIGHT", -PAGE_GUTTER, -y)
		row.resolved:SetJustifyH("RIGHT")
		table.insert(row.controls, row.resolved)
		local previous
		local rowDefinitions = {}
		for index = 1, #modeDefinitions do
			local definition = modeDefinitions[index]
			if element == "actions" and definition.id == "hidden" then
				rowDefinitions[#rowDefinitions + 1] = {
					id = "collapsed",
					label = "COLLAPSED",
					detail = "Keep the reveal control visible and start closed every time; clicking it opens actions temporarily.",
				}
			end
			rowDefinitions[#rowDefinitions + 1] = definition
		end
		for index = 1, #rowDefinitions do
			local definition = rowDefinitions[index]
			local button = addVisibility(Theme:CreateTightButton(page, definition.label, 20, false))
			if previous then
				button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
			else
				button:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -y - 20)
			end
			button:SetScript("OnClick", function()
				setMessengerVisibility(element, definition.id)
				Config:RefreshMessengerPage()
			end)
			setControlTooltip(button, definition.label .. " - " .. label, definition.detail .. " " .. help)
			row.buttons[definition.id] = button
			table.insert(row.controls, button)
			previous = button
		end
		self.messengerVisibilityRows[element] = row
	end
	createVisibilityRow("title", "TITLE BAR", 236, "When hidden, the bare x moves to the tab rail so Messenger can still be closed.")
	createVisibilityRow("actions", "PLAYER ACTIONS", 292, "Reply, Invite, Friend, Chatty Mute, and WoW Ignore are controlled together.")
	createVisibilityRow("composer", "TO / REPLY", 348, "HIDDEN normally reclaims the row, but /r and Reply temporarily reveal and focus it.")

	local visibilityDetail = addVisibility(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	visibilityDetail:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -406)
	visibilityDetail:SetWidth(PAGE_WIDTH)
	visibilityDetail:SetJustifyH("LEFT")
	visibilityDetail:SetText("The conversation tab rail and its close control always remain reachable.")

	local actionControls = {}
	local function addAction(control)
		table.insert(actionControls, control)
		return control
	end
	local actionsTitle = addAction(Theme:CreateText(page, "GameFontNormalSmall", "gold"))
	actionsTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -132)
	actionsTitle:SetText("BUTTON STYLE")

	self.messengerTextButtons = addAction(Theme:CreateTightButton(page, "TEXT", 22, false))
	self.messengerTextButtons:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -151)
	self.messengerTextButtons:SetScript("OnClick", function()
		setMessengerActionStyle("text")
		Config:RefreshMessengerPage()
	end)
	setControlTooltip(self.messengerTextButtons, "Text action buttons", "Shows readable Reply, Invite, Friend, Mute, and Block labels whenever the window is wide enough.")

	self.messengerIconButtons = addAction(Theme:CreateTightButton(page, "ICONS", 22, false))
	self.messengerIconButtons:SetPoint("LEFT", self.messengerTextButtons, "RIGHT", 6, 0)
	self.messengerIconButtons:SetScript("OnClick", function()
		setMessengerActionStyle("icons")
		Config:RefreshMessengerPage()
	end)
	setControlTooltip(self.messengerIconButtons, "Icon action buttons", "Uses the compact faction-aware Messenger icons, with readable tooltips on hover.")

	local actionsDetail = addAction(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	actionsDetail:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -181)
	actionsDetail:SetWidth(PAGE_WIDTH)
	actionsDetail:SetJustifyH("LEFT")
	actionsDetail:SetText("Text labels automatically compact to icons when the Messenger window is too narrow.")

	local placementTitle = addAction(Theme:CreateText(page, "GameFontNormalSmall", "gold"))
	placementTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -218)
	placementTitle:SetText("PLACEMENT")
	self.messengerHorizontalButton = addAction(Theme:CreateTightButton(page, "HORIZONTAL", 22, false))
	self.messengerHorizontalButton:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -237)
	self.messengerHorizontalButton:SetScript("OnClick", function()
		setMessengerActionStripOrientation("horizontal")
		Config:RefreshMessengerPage()
	end)
	setControlTooltip(self.messengerHorizontalButton, "Horizontal player actions", "Keeps the action strip on the same row as the conversation tabs.")
	self.messengerVerticalButton = addAction(Theme:CreateTightButton(page, "VERTICAL", 22, false))
	self.messengerVerticalButton:SetPoint("LEFT", self.messengerHorizontalButton, "RIGHT", 6, 0)
	self.messengerVerticalButton:SetScript("OnClick", function()
		setMessengerActionStripOrientation("vertical")
		Config:RefreshMessengerPage()
	end)
	setControlTooltip(self.messengerVerticalButton, "Vertical player actions", "Places the action strip in a narrow column beside the conversation.")
	local placementDetail = addAction(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	placementDetail:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -267)
	placementDetail:SetWidth(PAGE_WIDTH)
	placementDetail:SetJustifyH("LEFT")
	placementDetail:SetText("Horizontal shares the tab row. Vertical reserves a slim side rail without covering messages.")

	local collapseTitle = addAction(Theme:CreateText(page, "GameFontNormalSmall", "gold"))
	collapseTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -304)
	collapseTitle:SetText("COLLAPSE CONTROL")
	self.messengerActionCollapsedToggle = addAction(Theme:CreateCompactToggle(page, "REMEMBER COLLAPSED", PAGE_WIDTH))
	self.messengerActionCollapsedToggle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -323)
	self.messengerActionCollapsedToggle.OnValueChanged = function(_, value)
		setMessengerActionStripCollapsed(value)
		Config:RefreshMessengerPage()
	end
	setControlTooltip(self.messengerActionCollapsedToggle, "Remember manual collapse", "Keeps your last collapsed layout for normal visibility modes. The COLLAPSED visibility policy above always starts closed and ignores this preference.")
	local collapseDetail = addAction(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	collapseDetail:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -351)
	collapseDetail:SetWidth(PAGE_WIDTH)
	collapseDetail:SetJustifyH("LEFT")
	collapseDetail:SetText("The compact control stays discoverable; collapsing never disables Reply, Invite, Friend, Mute, or Block.")

	local safetyTitle = addAction(Theme:CreateText(page, "GameFontNormalSmall", "gold"))
	safetyTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -400)
	safetyTitle:SetText("SOCIAL SAFETY")
	local safetyDetail = addAction(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	safetyDetail:SetPoint("TOPLEFT", safetyTitle, "BOTTOMLEFT", 0, -2)
	safetyDetail:SetWidth(PAGE_WIDTH)
	safetyDetail:SetJustifyH("LEFT")
	safetyDetail:SetText("Local Mute affects only Chatty. WoW Ignore asks for confirmation. /r selects the matching tab and focuses its TO row.")

	local appearanceControls = {}
	local function addAppearance(control)
		table.insert(appearanceControls, control)
		return control
	end
	local opacityTitle = addAppearance(Theme:CreateText(page, "GameFontNormalSmall", "gold"))
	opacityTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -132)
	opacityTitle:SetText("OPACITY")
	local opacityHint = addAppearance(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	opacityHint:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -151)
	opacityHint:SetWidth(PAGE_WIDTH)
	opacityHint:SetJustifyH("LEFT")
	opacityHint:SetText("Background and border stay independent from text. Whole UI multiplies every Messenger element.")

	self.messengerAppearanceAlphaEdits = {}
	local alphaDefinitions = {
		{ key = "backgroundAlpha", label = "BACKGROUND %", api = "SetMessengerBackgroundAlpha", x = 116, y = 174 },
		{ key = "borderAlpha", label = "BORDER %", api = "SetMessengerBorderAlpha", x = 326, y = 174 },
		{ key = "textAlpha", label = "TEXT %", api = "SetMessengerTextAlpha", x = 116, y = 208 },
		{ key = "overallAlpha", label = "WHOLE UI %", api = "SetMessengerOverallAlpha", x = 326, y = 208 },
	}
	for _, definition in ipairs(alphaDefinitions) do
		local editBox = addAppearance(Theme:CreateEditBox(page, 64, 22, false))
		editBox:SetPoint("TOPLEFT", page, "TOPLEFT", definition.x, -definition.y)
		editBox:SetMaxLetters(3)
		local label = addAppearance(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
		label:SetPoint("RIGHT", editBox, "LEFT", -8, 0)
		label:SetWidth(100)
		label:SetJustifyH("RIGHT")
		label:SetText(definition.label)
		setControlTooltip(editBox, definition.label, definition.key == "backgroundAlpha"
			and "Changes Messenger panel fills without fading text or borders. Use a whole percent from 0 to 100."
			or (definition.key == "borderAlpha"
				and "Changes Messenger panel borders without fading text or backgrounds. Use a whole percent from 0 to 100."
				or (definition.key == "textAlpha"
					and "Fades Messenger labels and whisper text while preserving their semantic colors. Use a whole percent from 0 to 100."
					or "Fades the entire Messenger, including text and controls. Use a whole percent from 0 to 100.")))
		local function commitAlpha()
			local value = tonumber(editBox:GetText())
			if not value or value < 0 or value > 100 or value ~= math.floor(value) then
				Config:RefreshMessengerPage()
				Config.messengerStatus:SetText("Use a whole opacity percentage from 0 to 100.")
				return
			end
			setMessengerAppearanceAlpha(definition.api, definition.key, value / 100)
			Config:RefreshMessengerPage()
			Config.messengerStatus:SetText(definition.label .. " set to " .. tostring(value) .. "%.")
		end
		editBox:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
		editBox:HookScript("OnEditFocusLost", commitAlpha)
		self.messengerAppearanceAlphaEdits[definition.key] = editBox
	end
	self.messengerOpacityResetButton = addAppearance(Theme:CreateTightButton(page, "RESET OPACITY", 22, false))
	self.messengerOpacityResetButton:SetPoint("TOPLEFT", page, "TOPLEFT", 410, -208)
	self.messengerOpacityResetButton:SetScript("OnClick", function()
		setMessengerAppearanceAlpha("SetMessengerBackgroundAlpha", "backgroundAlpha", 1)
		setMessengerAppearanceAlpha("SetMessengerBorderAlpha", "borderAlpha", 1)
		setMessengerAppearanceAlpha("SetMessengerTextAlpha", "textAlpha", 1)
		setMessengerAppearanceAlpha("SetMessengerOverallAlpha", "overallAlpha", 1)
		Config:RefreshMessengerPage()
		Config.messengerStatus:SetText("Messenger opacity restored without changing its colors.")
	end)
	setControlTooltip(self.messengerOpacityResetButton, "Reset Messenger opacity", "Restores panel, border, text, and whole-window opacity to 100% without changing color choices.")

	local colorsTitle = addAppearance(Theme:CreateText(page, "GameFontNormalSmall", "gold"))
	colorsTitle:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -246)
	colorsTitle:SetText("COLORS")
	local colorsHint = addAppearance(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	colorsHint:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -265)
	colorsHint:SetWidth(PAGE_WIDTH)
	colorsHint:SetJustifyH("LEFT")
	colorsHint:SetText("INHERIT follows the active Colorway. Presets follow its palette; custom RGB remains fixed.")

	local colorTargetLabel = addAppearance(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	colorTargetLabel:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -292)
	colorTargetLabel:SetText("PART")
	self.messengerAppearanceTargetButtons = {}
	local previousTarget = colorTargetLabel
	for _, definition in ipairs({
		{ id = "window", label = "WINDOW" }, { id = "title", label = "TITLE" },
		{ id = "tabs", label = "TABS" }, { id = "chat", label = "CHAT" },
		{ id = "reply", label = "REPLY" }, { id = "border", label = "BORDER" },
	}) do
		local button = addAppearance(Theme:CreateTightButton(page, definition.label, 20, false))
		button:SetPoint("LEFT", previousTarget, "RIGHT", 6, 0)
		button:SetScript("OnClick", function()
			Config.messengerAppearanceColorTarget = definition.id
			Config:RefreshMessengerPage()
		end)
		setControlTooltip(button, definition.label .. " color", "Choose which Messenger surface the preset and custom RGB controls edit.")
		self.messengerAppearanceTargetButtons[definition.id] = button
		previousTarget = button
	end

	local presetLabel = addAppearance(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	presetLabel:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -326)
	presetLabel:SetText("PRESET")
	self.messengerAppearancePresetButtons = {}
	local previousPreset = presetLabel
	local firstPresetButton
	for index, definition in ipairs({
		{ id = "inherit", label = "INHERIT" },
		{ id = "background", label = "BACKGROUND" },
		{ id = "surface", label = "SURFACE" },
		{ id = "surfaceRaised", label = "RAISED" },
		{ id = "inset", label = "INSET" },
		{ id = "accent", label = "ACCENT" },
		{ id = "gold", label = "GOLD" },
	}) do
		local button = addAppearance(Theme:CreateTightButton(page, definition.label, 20, false))
		if index == 5 then
			button:SetPoint("TOPLEFT", firstPresetButton, "BOTTOMLEFT", 0, -4)
		else
			button:SetPoint("LEFT", previousPreset, "RIGHT", 6, 0)
		end
		button:SetScript("OnClick", function()
			setMessengerAppearanceColor(Config.messengerAppearanceColorTarget or "window",
				definition.id == "inherit" and { mode = "inherit" }
					or { mode = "theme", theme = definition.id })
			Config:RefreshMessengerPage()
			Config.messengerStatus:SetText(definition.label .. " color applied to " .. string.upper(Config.messengerAppearanceColorTarget or "window") .. ".")
		end)
		setControlTooltip(button, definition.label .. " preset", definition.id == "inherit"
			and "Restores this part's original role in the active Colorway."
			or "Uses this live Colorway token; changing Themes will update it too.")
		self.messengerAppearancePresetButtons[definition.id] = button
		if index == 1 then firstPresetButton = button end
		previousPreset = button
	end

	local customLabel = addAppearance(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	customLabel:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -382)
	customLabel:SetText("CUSTOM RGB")
	self.messengerAppearanceColorEdits = {}
	local previousChannel = customLabel
	for _, channel in ipairs({ "R", "G", "B" }) do
		local label = addAppearance(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
		label:SetPoint("LEFT", previousChannel, "RIGHT", 6, 0)
		label:SetText(channel)
		local editBox = addAppearance(Theme:CreateEditBox(page, 38, 20, false))
		editBox:SetPoint("LEFT", label, "RIGHT", 3, 0)
		editBox:SetMaxLetters(3)
		self.messengerAppearanceColorEdits[#self.messengerAppearanceColorEdits + 1] = editBox
		previousChannel = editBox
	end
	self.messengerAppearanceApplyColorButton = addAppearance(Theme:CreateTightButton(page, "APPLY RGB", 20, true))
	self.messengerAppearanceApplyColorButton:SetPoint("LEFT", previousChannel, "RIGHT", 8, 0)
	local function applyCustomMessengerColor()
		local values = {}
		for index, editBox in ipairs(Config.messengerAppearanceColorEdits or {}) do
			local value = tonumber(editBox:GetText())
			if not value or value < 0 or value > 255 or value ~= math.floor(value) then
				Config:RefreshMessengerPage()
				Config.messengerStatus:SetText("Use whole RGB values from 0 to 255.")
				return
			end
			values[index] = value / 255
		end
		setMessengerAppearanceColor(Config.messengerAppearanceColorTarget or "window", {
			mode = "custom", r = values[1], g = values[2], b = values[3],
		})
		Config:RefreshMessengerPage()
		Config.messengerStatus:SetText("Custom RGB applied to " .. string.upper(Config.messengerAppearanceColorTarget or "window") .. ".")
	end
	self.messengerAppearanceApplyColorButton:SetScript("OnClick", applyCustomMessengerColor)
	setControlTooltip(self.messengerAppearanceApplyColorButton, "Apply custom Messenger color", "Applies the RGB values to the selected part and keeps them fixed when the global Colorway changes.")
	for _, editBox in ipairs(self.messengerAppearanceColorEdits) do
		editBox:HookScript("OnEnterPressed", function(self) self:ClearFocus(); applyCustomMessengerColor() end)
	end

	self.messengerAppearanceInheritButton = addAppearance(Theme:CreateTightButton(page, "USE INHERITED COLOR", 22, false))
	self.messengerAppearanceInheritButton:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -416)
	self.messengerAppearanceInheritButton:SetScript("OnClick", function()
		setMessengerAppearanceColor(Config.messengerAppearanceColorTarget or "window", { mode = "inherit" })
		Config:RefreshMessengerPage()
		Config.messengerStatus:SetText("Selected Messenger part restored to its Colorway role.")
	end)
	self.messengerAppearanceResetButton = addAppearance(Theme:CreateTightButton(page, "RESET APPEARANCE", 22, false))
	self.messengerAppearanceResetButton:SetPoint("LEFT", self.messengerAppearanceInheritButton, "RIGHT", 8, 0)
	self.messengerAppearanceResetButton:SetScript("OnClick", function()
		if type(addon.ResetMessengerAppearance) == "function" then
			addon:ResetMessengerAppearance()
		else
			local settings = addon:GetSmartSettings()
			settings.conversations.appearance = nil
			applyMessengerRuntime()
		end
		Config:RefreshMessengerPage()
		Config.messengerStatus:SetText("Messenger opacity and colors restored to defaults.")
	end)
	setControlTooltip(self.messengerAppearanceResetButton, "Reset Messenger appearance", "Restores all Messenger opacity and color settings without changing tabs, visibility, or saved conversations.")
	local appearanceDetail = addAppearance(Theme:CreateText(page, "GameFontHighlightSmall", "textMuted"))
	appearanceDetail:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -450)
	appearanceDetail:SetWidth(PAGE_WIDTH)
	appearanceDetail:SetJustifyH("LEFT")
	appearanceDetail:SetText("Semantic text colors and the slim thumb keep their Colorway meaning.")

	self.messengerSectionGroups = {
		opening = openingControls,
		tabs = tabControls,
		visibility = visibilityControls,
		actions = actionControls,
		appearance = appearanceControls,
	}
	self.messengerStatus = Theme:CreateText(page, "GameFontHighlightSmall", "success")
	self.messengerStatus:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -474)
	self.messengerStatus:SetWidth(PAGE_WIDTH)
	self.messengerStatus:SetJustifyH("LEFT")
	self.messengerStatus:SetText("Every Messenger setting applies immediately; no reload is required.")

	self.messengerSection = messengerSectionDefinitions[self.messengerSection] and self.messengerSection or "opening"
	self:RefreshMessengerPage()
	return page
end

local legacyThemeOrder = {
	"Obsidian Dawn",
	"Moonsteel",
	"Ember Ledger",
}

-- Twelve cards fit in the existing workspace as a clean 3 x 4 gallery.  More
-- palettes therefore add a compact page instead of pushing cards into the
-- footer or bringing back the oversized empty preview area.
local COLORWAY_COLUMNS = 3
local COLORWAY_PAGE_SIZE = 12
local COLORWAY_CARD_WIDTH = 206
local COLORWAY_CARD_HEIGHT = 76
local COLORWAY_COLUMN_GAP = 5
local COLORWAY_ROW_GAP = 6

local function getThemeNames()
	if Theme.GetColorwayNames then
		local names = Theme:GetColorwayNames()
		if type(names) == "table" and #names > 0 then
			return names
		end
	end

	-- The public Theme API above supplies the deliberate gallery order.  Keep a
	-- small fallback for an older Theme module so the settings page stays usable
	-- during a partial upgrade instead of depending on unordered table traversal.
	local palettes = Theme.ColorWays or Theme.Colorways or {}
	local names, legacyRank = {}, {}
	for index = 1, #legacyThemeOrder do
		local name = legacyThemeOrder[index]
		if palettes[name] then
			names[#names + 1] = name
			legacyRank[name] = index
		end
	end
	for name in pairs(palettes) do
		if not legacyRank[name] then
			names[#names + 1] = name
		end
	end
	table.sort(names, function(left, right)
		local leftLegacy = legacyRank[left]
		local rightLegacy = legacyRank[right]
		if leftLegacy and rightLegacy then
			return leftLegacy < rightLegacy
		elseif leftLegacy then
			return true
		elseif rightLegacy then
			return false
		end
		return left < right
	end)
	return names
end

local function getCompactThemeDescription(name)
	local info = Theme.GetColorwayInfo and Theme:GetColorwayInfo(name)
	local description = info and info.description
	if type(description) ~= "string" or description == "" then
		description = "A coordinated alternate palette."
	end

	-- Theme cards are deliberately short.  Keep a two-line sentence from
	-- changing the compact grid's rhythm when a future palette uses a longer
	-- description.
	local maxLength = 34
	if string.len(description) > maxLength then
		local shortened = string.sub(description, 1, maxLength - 3)
		local lastSpace = string.match(shortened, "^.*() ")
		if lastSpace and lastSpace > 22 then
			shortened = string.sub(shortened, 1, lastSpace - 1)
		end
		description = shortened .. "..."
	end
	return description
end

function Config:CreateColorwayCard(parent, name, xOffset, yOffset)
	local palettes = Theme.ColorWays or Theme.Colorways or {}
	local palette = palettes[name]
	if not palette then
		return nil
	end
	local card = CreateFrame("Button", nil, parent)
	-- The swatches are the preview; do not spend a tall card on empty space
	-- beneath them.  The description and APPLY affordance still have their own
	-- clean line, but the gallery stays dense enough to scan as one palette set.
	card:SetSize(206, 76)
	card:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, -(yOffset or PAGE_TOP))
	Theme:RegisterFrame(card, "surface", "borderMuted")
	card.colorwayName = name

	local title = Theme:CreateText(card, "GameFontNormalSmall", "text")
	title:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -6)
	title:SetWidth(146)
	title:SetJustifyH("LEFT")
	title:SetText(name)

	local selected = Theme:CreateText(card, "GameFontNormalSmall", "goldBright")
	selected:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -6)
	selected:SetText("ACTIVE")
	card.selected = selected

	local samples = { "background", "surfaceRaised", "accent", "gold" }
	for index = 1, #samples do
		local color = palette[samples[index]]
		local swatch = card:CreateTexture(nil, "ARTWORK")
		swatch:SetTexture("Interface\\Buttons\\WHITE8x8")
		swatch:SetVertexColor(color[1], color[2], color[3], color[4])
		swatch:SetSize(46, 16)
		swatch:SetPoint("TOPLEFT", card, "TOPLEFT", 6 + ((index - 1) * 49), -25)
		swatch:Show()
	end

	local description = Theme:CreateText(card, "GameFontHighlightSmall", "textMuted")
	description:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -47)
	description:SetWidth(196)
	description:SetJustifyH("LEFT")
	description:SetText(getCompactThemeDescription(name))

	local choose = Theme:CreateText(card, "GameFontNormalSmall", "gold")
	choose:SetPoint("BOTTOM", card, "BOTTOM", 0, 3)
	choose:SetText("APPLY")
	card.choose = choose

	card:SetScript("OnClick", function()
		addon:SetColorway(name)
		Config:RefreshColorwayCards()
	end)
	card:SetScript("OnEnter", function(self)
		Theme:ApplyFrame(self, "surfaceRaised", "goldBright")
	end)
	card:SetScript("OnLeave", function(self)
		Config:RefreshColorwayCards()
	end)
	return card
end

function Config:BuildColorwaysPage()
	local page = self:CreatePage("colorways")
	createHeading(page, "Themes", "Dark-first palettes for every ChattyChattyBangBang frame. Choose one to apply it live.")
	self.colorwayCards = {}
	self.colorwayPage = 1
	local names = getThemeNames()
	for index = 1, #names do
		local card = self:CreateColorwayCard(
			page,
			names[index],
			PAGE_GUTTER,
			PAGE_TOP
		)
		if card then
			self.colorwayCards[#self.colorwayCards + 1] = card
		end
	end

	self.colorwayPagerText = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	self.colorwayPagerText:SetPoint("TOPLEFT", page, "TOPLEFT", 250, -382)
	self.colorwayPagerText:SetWidth(112)
	self.colorwayPagerText:SetJustifyH("CENTER")
	self.colorwayPrevious = Theme:CreateTightButton(page, "<", 20, false)
	self.colorwayPrevious:SetPoint("LEFT", self.colorwayPagerText, "RIGHT", 4, 0)
	self.colorwayPrevious:SetScript("OnClick", function()
		Config.colorwayPage = math.max(1, (tonumber(Config.colorwayPage) or 1) - 1)
		Config:RefreshColorwayCards()
	end)
	self.colorwayNext = Theme:CreateTightButton(page, ">", 20, false)
	self.colorwayNext:SetPoint("LEFT", self.colorwayPrevious, "RIGHT", CONTROL_GAP, 0)
	self.colorwayNext:SetScript("OnClick", function()
		Config.colorwayPage = (tonumber(Config.colorwayPage) or 1) + 1
		Config:RefreshColorwayCards()
	end)
	self:RefreshColorwayCards()
	return page
end

function Config:RefreshColorwayCards()
	if not self.colorwayCards then
		return
	end
	local active = addon:GetSmartSettings().colorway
	if Theme.ResolveColorwayName then
		active = Theme:ResolveColorwayName(active)
	end
	local pageCount = math.max(1, math.ceil(#self.colorwayCards / COLORWAY_PAGE_SIZE))
	local page = math.max(1, math.min(pageCount, tonumber(self.colorwayPage) or 1))
	self.colorwayPage = page
	for index = 1, #self.colorwayCards do
		local card = self.colorwayCards[index]
		local cardPage = math.floor((index - 1) / COLORWAY_PAGE_SIZE) + 1
		if cardPage == page then
			local slot = (index - 1) % COLORWAY_PAGE_SIZE
			local column = slot % COLORWAY_COLUMNS
			local row = math.floor(slot / COLORWAY_COLUMNS)
			card:ClearAllPoints()
			card:SetPoint(
				"TOPLEFT",
				self.pages.colorways,
				"TOPLEFT",
				PAGE_GUTTER + (column * (COLORWAY_CARD_WIDTH + COLORWAY_COLUMN_GAP)),
				-(PAGE_TOP + (row * (COLORWAY_CARD_HEIGHT + COLORWAY_ROW_GAP)))
			)
			card:Show()
		else
			card:Hide()
		end
		local selected = card.colorwayName == active
		if selected then
			card.selected:Show()
		else
			card.selected:Hide()
		end
		if card.choose then
			card.choose:SetText(selected and "CURRENT" or "APPLY")
		end
		Theme:ApplyFrame(card, selected and "accentSoft" or "surface", selected and "gold" or "borderMuted")
	end

	local showPager = pageCount > 1
	if self.colorwayPagerText then
		self.colorwayPagerText:SetText("THEMES " .. tostring(page) .. " / " .. tostring(pageCount))
		if showPager then self.colorwayPagerText:Show() else self.colorwayPagerText:Hide() end
	end
	for _, button in ipairs({ self.colorwayPrevious, self.colorwayNext }) do
		if button then
			if showPager then button:Show() else button:Hide() end
		end
	end
	if self.colorwayPrevious and self.colorwayPrevious.SetEnabled then
		self.colorwayPrevious:SetEnabled(page > 1)
	end
	if self.colorwayNext and self.colorwayNext.SetEnabled then
		self.colorwayNext:SetEnabled(page < pageCount)
	end
end

-- Message colors are semantic groups, not a separate selector for every
-- spelling.  The inspector shows the exact vocabulary attached to a group so
-- a player can change TANK once and immediately know that OT and "tnak" follow
-- it too.  The compact fallback keeps an older settings core usable if this UI
-- is loaded beside it during an update.
local fallbackKeywordColorGroups = {
	{
		id = "groupFinder",
		label = "GROUP FINDER",
		color = "goldBright",
		defaultColor = "goldBright",
		terms = { "lfg", "lfm", "lf", "lf1m", "lf2m", "lf3m", "lf4m", "lf5m", "lf6m", "lf1dps" },
	},
	{
		id = "tank",
		label = "TANK / OFF-TANK",
		color = "accent",
		defaultColor = "accent",
		terms = { "tank", "tnak", "ot", "off tank" },
	},
	{
		id = "healer",
		label = "HEALER",
		color = "success",
		defaultColor = "success",
		terms = { "heal", "healer" },
	},
	{
		id = "damage",
		label = "DAMAGE",
		color = "danger",
		defaultColor = "danger",
		terms = { "dps" },
	},
	{
		id = "trade",
		label = "TRADE / REQUIREMENTS",
		color = "gold",
		defaultColor = "gold",
		terms = { "need", "ilvl", "wts", "wtb", "wtt" },
	},
	{
		id = "dungeons",
		label = "DUNGEONS",
		color = "goldBright",
		defaultColor = "goldBright",
		terms = { "deadmines" },
	},
}

local fallbackKeywordColorOptions = {
	{ id = "goldBright", label = "GOLD BRIGHT" },
	{ id = "gold", label = "GOLD" },
	{ id = "accent", label = "ACCENT" },
	{ id = "success", label = "SUCCESS" },
	{ id = "warning", label = "WARNING" },
	{ id = "danger", label = "DANGER" },
	{ id = "text", label = "NEUTRAL" },
}

local function getKeywordColorOptions()
	if addon.GetKeywordColorOptions then
		local ok, options = pcall(addon.GetKeywordColorOptions, addon)
		if ok and type(options) == "table" and #options > 0 then
			return options
		end
	end
	return fallbackKeywordColorOptions
end

local function getKeywordColorSettings()
	local settings = addon:GetSmartSettings()
	if type(settings.keywordColors) ~= "table" then
		settings.keywordColors = {}
	end
	return settings.keywordColors
end

local function getKeywordColorTerm(termSpec)
	if type(termSpec) == "table" then
		termSpec = termSpec.term
	end
	return type(termSpec) == "string" and termSpec or nil
end

local function getKeywordColorTerms(group)
	local terms = {}
	for _, termSpec in ipairs((group and group.terms) or {}) do
		local term = getKeywordColorTerm(termSpec)
		if term and term ~= "" then
			table.insert(terms, term)
		end
	end
	return terms
end

local function getFallbackKeywordColorGroups()
	local colors = getKeywordColorSettings()
	local result = {}
	for index = 1, #fallbackKeywordColorGroups do
		local source = fallbackKeywordColorGroups[index]
		local group = {
			id = source.id,
			label = source.label,
			defaultColor = source.defaultColor or source.color,
			terms = {},
		}
		for termIndex, term in ipairs(source.terms) do
			group.terms[termIndex] = term
		end
		local firstTerm = getKeywordColorTerm(group.terms[1])
		group.color = (firstTerm and colors[string.lower(firstTerm)]) or source.color or "text"
		table.insert(result, group)
	end
	return result
end

local function getKeywordColorGroups()
	if addon.GetKeywordColorGroups then
		local ok, groups = pcall(addon.GetKeywordColorGroups, addon)
		if ok and type(groups) == "table" and #groups > 0 then
			return groups
		end
	end
	return getFallbackKeywordColorGroups()
end

local function findKeywordColorGroup(groups, groupId)
	for index = 1, #groups do
		if groups[index].id == groupId then
			return groups[index], index
		end
	end
	return nil
end

local keywordClassLabels = {
	DEATHKNIGHT = "DEATH KNIGHT CLASS",
}

local function getKeywordColorLabel(colorName)
	local className = type(colorName) == "string" and string.match(colorName, "^class:([A-Z]+)$")
	if className then
		return keywordClassLabels[className] or (className .. " CLASS")
	end
	local options = getKeywordColorOptions()
	for index = 1, #options do
		if options[index].id == colorName then
			return options[index].label
		end
	end
	return string.upper(tostring(colorName or "NEUTRAL"))
end

local function getKeywordColorRGB(colorName)
	local className = type(colorName) == "string" and string.match(colorName, "^class:([A-Z]+)$")
	if className then
		local classColors = (type(_G) == "table" and _G.RAID_CLASS_COLORS) or RAID_CLASS_COLORS
		local color = classColors and classColors[className]
		if color then
			local r = color.r or color[1]
			local g = color.g or color[2]
			local b = color.b or color[3]
			local a = color.a or color[4] or 1
			if r and g and b then
				return r, g, b, a
			end
		end
	end
	return Theme:GetColor(colorName or "text")
end

local function setKeywordColorVisual(object, colorName, texture)
	local r, g, b, a = getKeywordColorRGB(colorName)
	if texture then
		object:SetVertexColor(r, g, b, a)
	else
		object:SetTextColor(r, g, b, a)
	end
end

local function getKeywordGroupColor(group)
	if type(group) ~= "table" then
		return "text"
	end
	if type(group.color) == "string" and group.color ~= "" then
		return group.color
	end
	local colors = getKeywordColorSettings()
	for _, term in ipairs(getKeywordColorTerms(group)) do
		local color = colors[string.lower(term)]
		if type(color) == "string" and color ~= "" then
			return color
		end
	end
	return group.defaultColor or "text"
end

local function getKeywordTermDisplay(term)
	if string.lower(term) == "ilvl" then
		return "iLvL"
	end
	return string.upper(term)
end

local function applyKeywordGroupFallback(group, colorName)
	local terms = getKeywordColorTerms(group)
	if #terms == 0 then
		return false, "empty-group"
	end
	if addon.SetKeywordColor then
		for _, term in ipairs(terms) do
			local ok, applied, reason = pcall(addon.SetKeywordColor, addon, term, colorName)
			if not ok then
				return false, "settings-error"
			end
			if not applied then
				return false, reason or "unavailable"
			end
		end
		return true
	end
	local colors = getKeywordColorSettings()
	for _, term in ipairs(terms) do
		colors[string.lower(term)] = colorName
	end
	return true
end

function Config:SetKeywordColorsStatus(text, colorName)
	if not self.keywordColorStatus then
		return
	end
	self.keywordColorStatus:SetText(text or "")
	Theme.texts[self.keywordColorStatus] = colorName or "textMuted"
	local r, g, b, a = Theme:GetColor(Theme.texts[self.keywordColorStatus])
	self.keywordColorStatus:SetTextColor(r, g, b, a)
end

local function callKeywordColorAPI(name, ...)
	local method = addon[name]
	if type(method) ~= "function" then
		return false, nil, "unavailable"
	end
	local ok, first, second, third = pcall(method, addon, ...)
	if not ok then
		return false, nil, "settings-error"
	end
	return true, first, second, third
end

-- The selected group has two jobs: manage its vocabulary or choose its color.
-- Keep them in fixed, mutually exclusive panes so changing tasks never causes
-- the inspector to grow, collapse, or push another control off the page.
function Config:SetKeywordColorInspectorSection(section)
	if self.keywordColorGroupDraft then
		section = "color"
	elseif section ~= "color" then
		section = "words"
	end
	self.keywordColorInspectorSection = section
	if self.keywordColorInspectorWordsPane then
		if section == "words" then self.keywordColorInspectorWordsPane:Show() else self.keywordColorInspectorWordsPane:Hide() end
	end
	if self.keywordColorInspectorColorPane then
		if section == "color" then self.keywordColorInspectorColorPane:Show() else self.keywordColorInspectorColorPane:Hide() end
	end
	local drafting = self.keywordColorGroupDraft ~= nil
	if self.keywordColorInspectorWordsButton then
		if drafting then self.keywordColorInspectorWordsButton:Hide() else self.keywordColorInspectorWordsButton:Show() end
		setTabStyle(self.keywordColorInspectorWordsButton, section == "words")
	end
	if self.keywordColorInspectorColorButton then
		if drafting then self.keywordColorInspectorColorButton:Hide() else self.keywordColorInspectorColorButton:Show() end
		setTabStyle(self.keywordColorInspectorColorButton, section == "color")
	end
end

function Config:BeginKeywordColorGroupCreation()
	if type(addon.CreateKeywordColorGroup) ~= "function" then
		self:SetKeywordColorsStatus("Personal color groups are unavailable until Settings finishes loading.", "warning")
		return
	end
	self.keywordColorGroupDraft = { color = "accent" }
	self.keywordColorInspectorSection = "color"
	if self.keywordColorNewGroupNameEdit then
		self.keywordColorNewGroupNameEdit:SetText("")
		if self.keywordColorNewGroupNameEdit.SetFocus then
			self.keywordColorNewGroupNameEdit:SetFocus()
		end
	end
	self:RefreshKeywordColorsPage(true)
	self:SetKeywordColorsStatus("Name a personal group, choose its color, then create it.", "textMuted")
end

function Config:CancelKeywordColorGroupCreation()
	if not self.keywordColorGroupDraft then
		return
	end
	self.keywordColorGroupDraft = nil
	self.keywordColorInspectorSection = "words"
	if self.keywordColorNewGroupNameEdit then
		self.keywordColorNewGroupNameEdit:SetText("")
		self.keywordColorNewGroupNameEdit:ClearFocus()
	end
	self:RefreshKeywordColorsPage(true)
	self:SetKeywordColorsStatus("New color group cancelled.", "textMuted")
end

function Config:CreateKeywordColorGroup()
	local draft = self.keywordColorGroupDraft
	if not draft then
		return
	end
	local label = self.keywordColorNewGroupNameEdit and self.keywordColorNewGroupNameEdit:GetText() or ""
	local called, created, groupOrReason = callKeywordColorAPI("CreateKeywordColorGroup", label, draft.color or "accent")
	if not called or created ~= true then
		local messages = {
			["invalid-label"] = "Use a short name with letters, numbers, spaces, +, -, &, or /.",
			["duplicate-label"] = "A color group already has that name.",
			["group-limit"] = "You have reached the 48 personal-group limit.",
			["invalid-color"] = "Choose one of the available colors first.",
		}
		self:SetKeywordColorsStatus(messages[groupOrReason] or ("Could not create the group: " .. tostring(groupOrReason or "unavailable")), "danger")
		return
	end
	local group = type(groupOrReason) == "table" and groupOrReason or nil
	self.keywordColorGroupDraft = nil
	if group and group.id then
		self.selectedKeywordColorGroupId = group.id
	else
		local groups = getKeywordColorGroups()
		local createdLabel = string.lower(tostring(label))
		for _, candidate in ipairs(groups) do
			if string.lower(tostring(candidate.label)) == createdLabel then
				self.selectedKeywordColorGroupId = candidate.id
				break
			end
		end
	end
	self.keywordColorTermPage = 1
	self.keywordColorInspectorSection = "words"
	self:RefreshKeywordColorsPage(true)
	self:SetKeywordColorsStatus("Personal color group created. Add the words or phrases that belong to it.", "success")
end

function Config:AddKeywordColorGroupWord()
	local group = findKeywordColorGroup(getKeywordColorGroups(), self.selectedKeywordColorGroupId)
	if not group then
		self:SetKeywordColorsStatus("Select a color group before adding a word.", "warning")
		return
	end
	if self.keywordColorGroupDraft then
		self:SetKeywordColorsStatus("Create the group first, then add its words.", "warning")
		return
	end
	local term = self.keywordColorTermAddEdit and self.keywordColorTermAddEdit:GetText() or ""
	local caseSensitive = self.keywordColorTermCaseToggle and self.keywordColorTermCaseToggle.checked == true
	local called, added, reason, ownerId = callKeywordColorAPI("AddKeywordColorGroupTerm", group.id, term, caseSensitive)
	if not called or added ~= true then
		if reason == "already-in-group" then
			local owner = findKeywordColorGroup(getKeywordColorGroups(), ownerId)
			self:SetKeywordColorsStatus("That word already belongs to " .. (owner and (owner.label or owner.id) or "another color group") .. ".", "warning")
		elseif reason == "group-full" then
			self:SetKeywordColorsStatus("This group already has 128 words or phrases.", "warning")
		elseif reason == "invalid-term" then
			self:SetKeywordColorsStatus("Use a word or short phrase (letters, numbers, spaces, +, -, and apostrophes).", "warning")
		else
			self:SetKeywordColorsStatus("Could not add that word: " .. tostring(reason or "unavailable"), "danger")
		end
		return
	end
	if self.keywordColorTermAddEdit then
		self.keywordColorTermAddEdit:SetText("")
		self.keywordColorTermAddEdit:ClearFocus()
	end
	if self.keywordColorTermCaseToggle then
		self.keywordColorTermCaseToggle:SetValue(false, true)
	end
	self.keywordColorTermPage = 9999
	self:RefreshKeywordColorsPage(true)
	self:SetKeywordColorsStatus(reason == "already-present"
		and "That word is already in this color group."
		or ("Added to " .. (group.label or "COLOR GROUP") .. "."), "success")
end

function Config:DeleteSelectedKeywordColorGroup()
	local group = findKeywordColorGroup(getKeywordColorGroups(), self.selectedKeywordColorGroupId)
	if not group or group.custom ~= true then
		self:SetKeywordColorsStatus("Only personal color groups can be deleted. Built-in groups can be reset instead.", "warning")
		return
	end
	local called, deleted, reason = callKeywordColorAPI("DeleteKeywordColorGroup", group.id)
	if not called or deleted ~= true then
		self:SetKeywordColorsStatus("Could not delete " .. (group.label or "that group") .. ": " .. tostring(reason or "unavailable"), "danger")
		return
	end
	self.selectedKeywordColorGroupId = nil
	self.keywordColorTermPage = 1
	self:RefreshKeywordColorsPage(true)
	self:SetKeywordColorsStatus((group.label or "Personal group") .. " deleted.", "success")
end

function Config:SetKeywordColorPager(button, visible, enabled)
	if not button then
		return
	end
	if visible then
		button:Show()
		if enabled then
			button:Enable()
			button:SetAlpha(1)
		else
			button:Disable()
			button:SetAlpha(0.35)
		end
	else
		button:Hide()
	end
end

-- Suggestions are intentionally a report/review path, not an extension of
-- the renderer.  A candidate never changes chat colors until the player picks
-- a target group and explicitly adds it.  Keep every API call guarded so a
-- partial update can still open the established Message Colors editor.
local function callKeywordSuggestionAPI(name, ...)
	local method = addon[name]
	if type(method) ~= "function" then
		return false, nil, "unavailable"
	end
	local ok, first, second, third = pcall(method, addon, ...)
	if not ok then
		return false, nil, "api-error"
	end
	return true, first, second, third
end

local function hasKeywordSuggestionReadAPI()
	return type(addon.GetKeywordSuggestions) == "function"
end

local function getKeywordSuggestionSettings()
	local called, settings = callKeywordSuggestionAPI("GetKeywordSuggestionSettings")
	if not called or type(settings) ~= "table" then
		return nil
	end
	local threshold = tonumber(settings.threshold)
	if threshold == nil then
		threshold = tonumber(settings.minimumCount) or tonumber(settings.minCount)
	end
	return {
		enabled = settings.enabled == true,
		threshold = threshold and math.max(1, math.floor(threshold + 0.5)) or nil,
	}
end

local function compactKeywordSuggestionText(value, maximumLength)
	if type(value) ~= "string" then
		return ""
	end
	value = string.gsub(value, "%s+", " ")
	-- A captured sample is untrusted chat text. Render its pipes literally so a
	-- color/link escape cannot restyle this configuration surface.
	value = string.gsub(value, "|", "||")
	value = trim(value, maximumLength and (maximumLength + 1) or nil)
	if maximumLength and string.len(value) > maximumLength then
		value = string.sub(value, 1, math.max(1, maximumLength - 3)) .. "..."
	end
	return value
end

local function getKeywordSuggestionWord(candidate)
	if type(candidate) ~= "table" then
		return ""
	end
	return compactKeywordSuggestionText(candidate.word or candidate.term or candidate.label, 64)
end

local function keywordSuggestionIdsMatch(left, right)
	if left == nil or right == nil then
		return false
	end
	return tostring(left) == tostring(right)
end

local function getKeywordSuggestions()
	local called, candidates = callKeywordSuggestionAPI("GetKeywordSuggestions")
	if not called or type(candidates) ~= "table" then
		return {}
	end
	-- Accept a future named wrapper without changing the compact UI contract.
	if type(candidates.candidates) == "table" then
		candidates = candidates.candidates
	end
	local result = {}
	for _, candidate in ipairs(candidates) do
		local word = getKeywordSuggestionWord(candidate)
		local id = type(candidate) == "table" and (candidate.id or candidate.word or candidate.term) or nil
		if id ~= nil and word ~= "" then
			table.insert(result, {
				id = id,
				word = word,
				count = math.max(0, math.floor(tonumber(candidate.count) or 0)),
				source = compactKeywordSuggestionText(candidate.source, 24),
				sample = compactKeywordSuggestionText(candidate.sample, 56),
			})
		end
	end
	return result
end

local function findKeywordSuggestion(candidates, id)
	for index = 1, #candidates do
		if keywordSuggestionIdsMatch(candidates[index].id, id) then
			return candidates[index], index
		end
	end
	return nil
end

function Config:SetKeywordSuggestionStatus(text, colorName)
	if not self.keywordSuggestionStatus then
		return
	end
	self.keywordSuggestionStatus:SetText(text or "")
	Theme.texts[self.keywordSuggestionStatus] = colorName or "textMuted"
	local r, g, b, a = Theme:GetColor(Theme.texts[self.keywordSuggestionStatus])
	self.keywordSuggestionStatus:SetTextColor(r, g, b, a)
end

function Config:SetKeywordSuggestionControlEnabled(control, enabled)
	if not control then
		return
	end
	if enabled then
		if control.Enable then control:Enable() end
		if control.SetAlpha then control:SetAlpha(1) end
	else
		if control.Disable then control:Disable() end
		if control.SetAlpha then control:SetAlpha(0.38) end
	end
end

function Config:SelectKeywordSuggestion(id)
	if not findKeywordSuggestion(getKeywordSuggestions(), id) then
		return
	end
	self.selectedKeywordSuggestionId = id
	self:RefreshKeywordSuggestionsPanel(true)
end

-- Deliberately no automatic target: a report remains harmless until the
-- player explicitly selects one of their existing semantic color groups.
function Config:SelectKeywordSuggestionGroup(groupId)
	if not findKeywordColorGroup(getKeywordColorGroups(), groupId) then
		return
	end
	self.selectedKeywordSuggestionGroupId = groupId
	self:RefreshKeywordSuggestionsPanel(true)
end

function Config:SetKeywordSuggestionEnabled(enabled)
	local called, changed, reason = callKeywordSuggestionAPI("SetKeywordSuggestionsEnabled", enabled and true or false)
	if not called or changed == false then
		self:SetKeywordSuggestionStatus("Candidate reporting could not be updated: " .. tostring(reason or "unavailable"), "danger")
		return false
	end
	self:SetKeywordSuggestionStatus(enabled and "Candidate reporting enabled. Reports never color messages automatically." or "Candidate reporting paused.", "success")
	self:RefreshKeywordSuggestionsPanel(true)
	return true
end

function Config:CommitKeywordSuggestionThreshold()
	if not self.keywordSuggestionThresholdEdit then
		return
	end
	local threshold = tonumber(self.keywordSuggestionThresholdEdit:GetText())
	if threshold == nil then
		self:SetKeywordSuggestionStatus("Use a whole-number minimum seen count.", "warning")
		self:RefreshKeywordSuggestionsPanel(true)
		return
	end
	threshold = math.max(1, math.floor(threshold + 0.5))
	local called, changed, normalized = callKeywordSuggestionAPI("SetKeywordSuggestionThreshold", threshold)
	if not called or changed == false then
		self:SetKeywordSuggestionStatus("Candidate threshold could not be updated: " .. tostring(normalized or "unavailable"), "danger")
		self:RefreshKeywordSuggestionsPanel(true)
		return
	end
	self:SetKeywordSuggestionStatus("Candidates now need " .. tostring(tonumber(normalized) or threshold) .. " sightings before review.", "success")
	self:RefreshKeywordSuggestionsPanel(true)
end

function Config:AddSelectedKeywordSuggestion()
	local candidates = getKeywordSuggestions()
	local candidate = findKeywordSuggestion(candidates, self.selectedKeywordSuggestionId)
	if not candidate then
		self:SetKeywordSuggestionStatus("Select a reported candidate first.", "warning")
		return
	end
	local group = findKeywordColorGroup(getKeywordColorGroups(), self.selectedKeywordSuggestionGroupId)
	if not group then
		self:SetKeywordSuggestionStatus("Choose a target color group before adding this word.", "warning")
		return
	end
	local called, added, reason = callKeywordSuggestionAPI("AddKeywordSuggestionToGroup", candidate.id, group.id)
	if not called or added == false then
		self:SetKeywordSuggestionStatus("Could not add " .. string.upper(candidate.word) .. ": " .. tostring(reason or "unavailable"), "danger")
		return
	end
	self.selectedKeywordSuggestionId = nil
	self:SetKeywordSuggestionStatus(string.upper(candidate.word) .. " added to " .. (group.label or group.id) .. ".", "success")
	self:RefreshKeywordColorsPage(true)
end

function Config:DismissSelectedKeywordSuggestion()
	local candidate = findKeywordSuggestion(getKeywordSuggestions(), self.selectedKeywordSuggestionId)
	if not candidate then
		self:SetKeywordSuggestionStatus("Select a reported candidate first.", "warning")
		return
	end
	local called, dismissed, reason = callKeywordSuggestionAPI("DismissKeywordSuggestion", candidate.id)
	if not called or dismissed == false then
		self:SetKeywordSuggestionStatus("Could not dismiss " .. string.upper(candidate.word) .. ": " .. tostring(reason or "unavailable"), "danger")
		return
	end
	self.selectedKeywordSuggestionId = nil
	self:SetKeywordSuggestionStatus(string.upper(candidate.word) .. " dismissed from the report.", "success")
	self:RefreshKeywordSuggestionsPanel(true)
end

function Config:ClearKeywordSuggestions()
	local called, cleared, reason = callKeywordSuggestionAPI("ClearKeywordSuggestions")
	if not called or cleared == false then
		self:SetKeywordSuggestionStatus("Could not clear reported candidates: " .. tostring(reason or "unavailable"), "danger")
		return
	end
	self.selectedKeywordSuggestionId = nil
	self:SetKeywordSuggestionStatus("Reported candidates cleared. No message colors were changed.", "success")
	self:RefreshKeywordSuggestionsPanel(true)
end

function Config:SelectKeywordColorGroup(groupId)
	local groups = getKeywordColorGroups()
	if not findKeywordColorGroup(groups, groupId) then
		return
	end
	-- A real selection is the natural cancellation gesture for the compact
	-- creation form; do not leave a half-made group shadowing its inspector.
	local wasDrafting = self.keywordColorGroupDraft ~= nil
	self.keywordColorGroupDraft = nil
	if self.keywordColorNewGroupNameEdit then
		self.keywordColorNewGroupNameEdit:SetText("")
		self.keywordColorNewGroupNameEdit:ClearFocus()
	end
	self.selectedKeywordColorGroupId = groupId
	self.keywordColorTermPage = 1
	if wasDrafting then
		self.keywordColorInspectorSection = "words"
	end
	self:RefreshKeywordColorsPage()
end

-- Retain the old selection entry point for any local snippets that selected a
-- one-word color.  It now selects the owning group instead of splitting the
-- group back into separate controls.
function Config:SelectKeywordColorTerm(keyword)
	keyword = type(keyword) == "string" and string.lower(keyword) or ""
	for _, group in ipairs(getKeywordColorGroups()) do
		for _, term in ipairs(getKeywordColorTerms(group)) do
			if string.lower(term) == keyword then
				return self:SelectKeywordColorGroup(group.id)
			end
		end
	end
end

function Config:ApplyKeywordColor(colorName)
	if self.keywordColorGroupDraft then
		self.keywordColorGroupDraft.color = colorName
		self:RefreshKeywordColorsPage(true)
		self:SetKeywordColorsStatus("New group color set to " .. getKeywordColorLabel(colorName) .. ".", "success")
		return
	end
	local groups = getKeywordColorGroups()
	local group = findKeywordColorGroup(groups, self.selectedKeywordColorGroupId)
	if not group then
		self:SetKeywordColorsStatus("Select a color group first.", "warning")
		return
	end
	local applied, reason
	if addon.SetKeywordColorGroup then
		local ok
		ok, applied, reason = pcall(addon.SetKeywordColorGroup, addon, group.id, colorName)
		if not ok then
			applied, reason = false, "settings-error"
		end
	else
		applied, reason = applyKeywordGroupFallback(group, colorName)
	end
	if not applied then
		self:SetKeywordColorsStatus("That color is unavailable: " .. tostring(reason or colorName), "danger")
		return
	end
	self:SetKeywordColorsStatus((group.label or "GROUP") .. " now uses " .. getKeywordColorLabel(colorName) .. ".", "success")
	self:RefreshKeywordColorsPage(true)
end

function Config:ResetSelectedKeywordColorGroup()
	local group = findKeywordColorGroup(getKeywordColorGroups(), self.selectedKeywordColorGroupId)
	local defaultColor = group and group.defaultColor
	if not group or type(defaultColor) ~= "string" or defaultColor == "" then
		self:SetKeywordColorsStatus("That group has no restorable default.", "warning")
		return
	end
	local applied, reason
	if addon.SetKeywordColorGroup then
		local ok
		ok, applied, reason = pcall(addon.SetKeywordColorGroup, addon, group.id, defaultColor)
		if not ok then
			applied, reason = false, "settings-error"
		end
	else
		applied, reason = applyKeywordGroupFallback(group, defaultColor)
	end
	if not applied then
		self:SetKeywordColorsStatus("Could not restore this group: " .. tostring(reason or "unavailable"), "danger")
		return
	end
	self:SetKeywordColorsStatus((group.label or "GROUP") .. " restored to " .. getKeywordColorLabel(defaultColor) .. ".", "success")
	self:RefreshKeywordColorsPage(true)
end

function Config:ResetKeywordColors()
	local reset, reason
	if addon.ResetKeywordColorGroups then
		local ok
		ok, reset, reason = pcall(addon.ResetKeywordColorGroups, addon)
		if not ok then
			reset, reason = false, "settings-error"
		end
	elseif addon.ResetKeywordColors then
		local ok
		ok, reset, reason = pcall(addon.ResetKeywordColors, addon)
		if not ok then
			reset, reason = false, "settings-error"
		end
	else
		reset = true
		for _, group in ipairs(getKeywordColorGroups()) do
			local defaultColor = group.defaultColor or group.color
			if type(defaultColor) == "string" then
				local applied, applyReason = applyKeywordGroupFallback(group, defaultColor)
				if not applied then
					reset, reason = false, applyReason
					break
				end
			end
		end
	end
	if not reset then
		self:SetKeywordColorsStatus("Message color reset is unavailable: " .. tostring(reason), "danger")
		return
	end
	self:SetKeywordColorsStatus("Built-in groups restored; personal groups were kept.", "success")
	self:RefreshKeywordColorsPage(true)
end

function Config:RefreshKeywordColorsPage(keepStatus)
	if not self.keywordColorGroupRows then
		return
	end
	local groups = getKeywordColorGroups()
	if #groups == 0 then
		return
	end
	local selectedGroup, selectedIndex = findKeywordColorGroup(groups, self.selectedKeywordColorGroupId)
	if not selectedGroup then
		selectedGroup, selectedIndex = groups[1], 1
		self.selectedKeywordColorGroupId = selectedGroup.id
	end

	local groupRows = #self.keywordColorGroupRows
	local groupPageCount = math.max(1, math.ceil(#groups / groupRows))
	local selectedPage = math.ceil(selectedIndex / groupRows)
	self.keywordColorGroupPage = math.max(1, math.min(self.keywordColorGroupPage or selectedPage, groupPageCount))
	if selectedPage ~= self.keywordColorGroupPage then
		self.keywordColorGroupPage = selectedPage
	end
	local groupStart = ((self.keywordColorGroupPage - 1) * groupRows) + 1
	for rowIndex = 1, groupRows do
		local row = self.keywordColorGroupRows[rowIndex]
		local group = groups[groupStart + rowIndex - 1]
		if group then
			local colorName = getKeywordGroupColor(group)
			local selected = group.id == selectedGroup.id
			row.groupId = group.id
			row.label:SetText(group.label or group.id or "GROUP")
			setKeywordColorVisual(row.label, colorName)
			setKeywordColorVisual(row.accent, colorName, true)
			setKeywordColorVisual(row.swatch, colorName, true)
			local fillR, fillG, fillB, fillA = Theme:GetColor(selected and "accentSoft" or "surfaceRaised")
			row.highlight:SetVertexColor(fillR, fillG, fillB, fillA * (selected and 0.86 or 0.42))
			if selected or row.hovered then
				row.highlight:Show()
			else
				row.highlight:Hide()
			end
			row:Show()
		else
			row.groupId = nil
			row.hovered = nil
			row:Hide()
		end
	end
	if self.keywordColorGroupCount then
		local lastGroup = math.min(#groups, groupStart + groupRows - 1)
		self.keywordColorGroupCount:SetText(groupPageCount > 1 and (groupStart .. "-" .. lastGroup .. " / " .. #groups) or (#groups .. " GROUPS"))
	end
	self:SetKeywordColorPager(self.keywordColorGroupPrevious, groupPageCount > 1, self.keywordColorGroupPage > 1)
	self:SetKeywordColorPager(self.keywordColorGroupNext, groupPageCount > 1, self.keywordColorGroupPage < groupPageCount)

	local drafting = type(self.keywordColorGroupDraft) == "table"
	local selectedColor = getKeywordGroupColor(selectedGroup)
	local inspectorColor = drafting and (self.keywordColorGroupDraft.color or "accent") or selectedColor
	local defaultColor = selectedGroup.defaultColor or selectedColor
	local canCreateGroups = type(addon.CreateKeywordColorGroup) == "function"
	local canAddTerms = type(addon.AddKeywordColorGroupTerm) == "function"
	local function setShown(widget, visible)
		if not widget then
			return
		end
		if visible then
			widget:Show()
		else
			widget:Hide()
		end
	end
	setShown(self.keywordColorNewGroupButton, canCreateGroups and not drafting)
	if self.keywordColorInspectorTitle then
		self.keywordColorInspectorTitle:SetText(drafting and "NEW PERSONAL GROUP" or (selectedGroup.label or selectedGroup.id or "COLOR GROUP"))
		setKeywordColorVisual(self.keywordColorInspectorTitle, inspectorColor)
	end
	if self.keywordColorInspectorValue then
		self.keywordColorInspectorValue:SetText("CURRENT  " .. getKeywordColorLabel(inspectorColor))
		setKeywordColorVisual(self.keywordColorInspectorValue, inspectorColor)
	end
	if self.keywordColorInspectorSwatch then
		setKeywordColorVisual(self.keywordColorInspectorSwatch, inspectorColor, true)
	end
	setShown(self.keywordColorInspectorValue, not drafting)
	setShown(self.keywordColorNewGroupNameLabel, drafting)
	setShown(self.keywordColorNewGroupNameEdit, drafting)
	setShown(self.keywordColorCreateGroupButton, drafting)
	setShown(self.keywordColorCancelGroupButton, drafting)
	setShown(self.keywordColorWordsTitle, not drafting)
	if self.keywordColorPaletteTitle then
		self.keywordColorPaletteTitle:SetText(drafting and "CHOOSE A COLOR" or "COLOR")
	end
	setShown(self.keywordColorMaintenanceTitle, not drafting)

	local terms = drafting and {} or getKeywordColorTerms(selectedGroup)
	local termRows = #self.keywordColorTermRows
	local termPageCount = math.max(1, math.ceil(#terms / termRows))
	self.keywordColorTermPage = math.max(1, math.min(self.keywordColorTermPage or 1, termPageCount))
	local termStart = ((self.keywordColorTermPage - 1) * termRows) + 1
	for rowIndex = 1, termRows do
		local row = self.keywordColorTermRows[rowIndex]
		local term = terms[termStart + rowIndex - 1]
		if not drafting and term then
			row.label:SetText(getKeywordTermDisplay(term))
			setKeywordColorVisual(row.label, inspectorColor)
			setKeywordColorVisual(row.accent, inspectorColor, true)
			row:Show()
		else
			row:Hide()
		end
	end
	if self.keywordColorTermCount then
		local lastTerm = math.min(#terms, termStart + termRows - 1)
		self.keywordColorTermCount:SetText(drafting and "CHOOSE A COLOR" or (termPageCount > 1 and (termStart .. "-" .. lastTerm .. " / " .. #terms) or (#terms .. " WORDS")))
	end
	setShown(self.keywordColorTermCount, not drafting)
	self:SetKeywordColorPager(self.keywordColorTermPrevious, not drafting and termPageCount > 1, self.keywordColorTermPage > 1)
	self:SetKeywordColorPager(self.keywordColorTermNext, not drafting and termPageCount > 1, self.keywordColorTermPage < termPageCount)
	setShown(self.keywordColorTermAddLabel, not drafting and canAddTerms)
	setShown(self.keywordColorTermAddEdit, not drafting and canAddTerms)
	setShown(self.keywordColorTermCaseToggle, not drafting and canAddTerms)
	setShown(self.keywordColorTermAddButton, not drafting and canAddTerms)

	if self.keywordColorOptionButtons then
		for index = 1, #self.keywordColorOptionButtons do
			local button = self.keywordColorOptionButtons[index]
			local active = button.colorName == inspectorColor
			button:SetTheme(active and "accentSoft" or "surface", active and "gold" or "borderMuted", button.colorName)
		end
	end
	if self.keywordColorDefaultButton then
		local isClassDefault = type(defaultColor) == "string" and string.match(defaultColor, "^class:[A-Z]+$") ~= nil
		self.keywordColorDefaultButton:SetLabel(isClassDefault and "CLASS DEFAULT" or (selectedGroup.custom == true and "USE START COLOR" or "USE DEFAULT"))
		local currentDefault = selectedColor == defaultColor
		self.keywordColorDefaultButton:SetTheme(currentDefault and "accentSoft" or "surface", currentDefault and "gold" or "borderMuted", currentDefault and "goldBright" or "text")
	end
	setShown(self.keywordColorDefaultButton, not drafting)
	setShown(self.keywordColorResetBuiltInsButton, not drafting)
	setShown(self.keywordColorDeleteGroupButton, not drafting and selectedGroup.custom == true)
	self:SetKeywordColorInspectorSection(self.keywordColorInspectorSection)
	if not keepStatus then
		if drafting then
			self:SetKeywordColorsStatus("Name your personal group, choose its color, then create it.", "textMuted")
		else
			self:SetKeywordColorsStatus("SELECTED  " .. (selectedGroup.label or "GROUP") .. "  -  " .. #terms .. " WORDS  -  " .. getKeywordColorLabel(selectedColor), "textMuted")
		end
	end
	if self.RefreshKeywordSuggestionsPanel then
		self:RefreshKeywordSuggestionsPanel(keepStatus)
	end
end

local KEYWORD_SUGGESTION_ROWS_PER_PAGE = 8
local KEYWORD_SUGGESTION_GROUP_ROWS_PER_PAGE = 6

-- Reviewing a candidate, tuning the report, and clearing the queue are three
-- different decisions. One fixed pane is visible at a time; the queue can no
-- longer compete with global settings or its destructive maintenance action.
function Config:SetKeywordSuggestionsSection(section)
	if section ~= "settings" and section ~= "more" then
		section = "review"
	end
	self.keywordSuggestionSection = section
	local panes = {
		review = self.keywordSuggestionReviewPane,
		settings = self.keywordSuggestionSettingsPane,
		more = self.keywordSuggestionMorePane,
	}
	for id, pane in pairs(panes) do
		if pane then
			if id == section then pane:Show() else pane:Hide() end
		end
	end
	setTabStyle(self.keywordSuggestionReviewButton, section == "review")
	setTabStyle(self.keywordSuggestionSettingsButton, section == "settings")
	setTabStyle(self.keywordSuggestionMoreButton, section == "more")
end

function Config:RefreshKeywordSuggestionsPanel(keepStatus)
	if not self.keywordSuggestionsPanel then
		return
	end
	local available = hasKeywordSuggestionReadAPI()
	if self.keywordSuggestionsSectionButton then
		if available then
			self.keywordSuggestionsSectionButton:Show()
		else
			self.keywordSuggestionsSectionButton:Hide()
		end
	end
	if not available then
		self.keywordSuggestionsPanel:Hide()
		if self.keywordColorsSection == "suggestions" then
			self:SetKeywordColorsSection("colors")
		end
		return
	end

	local settings = getKeywordSuggestionSettings()
	local canSetEnabled = type(addon.SetKeywordSuggestionsEnabled) == "function"
	local canSetThreshold = type(addon.SetKeywordSuggestionThreshold) == "function"
	if self.keywordSuggestionTrackingToggle then
		if settings then
			self.keywordSuggestionTrackingToggle:SetValue(settings.enabled, true)
			self.keywordSuggestionTrackingToggle:Show()
			self:SetKeywordSuggestionControlEnabled(self.keywordSuggestionTrackingToggle, canSetEnabled)
		else
			self.keywordSuggestionTrackingToggle:Hide()
		end
	end
	if self.keywordSuggestionThresholdLabel then
		if settings and settings.threshold then self.keywordSuggestionThresholdLabel:Show() else self.keywordSuggestionThresholdLabel:Hide() end
	end
	if self.keywordSuggestionThresholdEdit then
		if settings and settings.threshold then
			self.keywordSuggestionThresholdEdit:SetText(tostring(settings.threshold))
			self.keywordSuggestionThresholdEdit:Show()
			self:SetKeywordSuggestionControlEnabled(self.keywordSuggestionThresholdEdit, canSetThreshold)
		else
			self.keywordSuggestionThresholdEdit:Hide()
		end
	end
	if self.keywordSuggestionSettingsNote then
		self.keywordSuggestionSettingsNote:SetText(settings
			and "REPORT ONLY - candidates never recolor chat until you add them."
			or "REPORT ONLY - reporting settings are unavailable in this build.")
	end

	local candidates = getKeywordSuggestions()
	local selected, selectedIndex = findKeywordSuggestion(candidates, self.selectedKeywordSuggestionId)
	if not selected then
		selected, selectedIndex = candidates[1], candidates[1] and 1 or nil
		self.selectedKeywordSuggestionId = selected and selected.id or nil
	end
	local candidatePageCount = math.max(1, math.ceil(#candidates / KEYWORD_SUGGESTION_ROWS_PER_PAGE))
	local selectedPage = selectedIndex and math.ceil(selectedIndex / KEYWORD_SUGGESTION_ROWS_PER_PAGE) or 1
	self.keywordSuggestionPage = math.max(1, math.min(self.keywordSuggestionPage or selectedPage, candidatePageCount))
	if selectedIndex and selectedPage ~= self.keywordSuggestionPage then
		self.keywordSuggestionPage = selectedPage
	end
	local candidateStart = ((self.keywordSuggestionPage - 1) * KEYWORD_SUGGESTION_ROWS_PER_PAGE) + 1
	for rowIndex, row in ipairs(self.keywordSuggestionRows or {}) do
		local candidate = candidates[candidateStart + rowIndex - 1]
		if candidate then
			local isSelected = keywordSuggestionIdsMatch(candidate.id, self.selectedKeywordSuggestionId)
			row.suggestionId = candidate.id
			row.word:SetText(string.upper(compactKeywordSuggestionText(candidate.word, 26)))
			row.count:SetText("x" .. tostring(candidate.count))
			row.source:SetText(candidate.source ~= "" and string.upper(candidate.source) or "CHAT")
			local r, g, b, a = Theme:GetColor(isSelected and "accentSoft" or "surfaceRaised")
			row.highlight:SetVertexColor(r, g, b, a * (isSelected and 0.86 or 0.34))
			if isSelected or row.hovered then row.highlight:Show() else row.highlight:Hide() end
			row:Show()
		else
			row.suggestionId = nil
			row.hovered = nil
			row:Hide()
		end
	end
	if self.keywordSuggestionCount then
		local last = math.min(#candidates, candidateStart + KEYWORD_SUGGESTION_ROWS_PER_PAGE - 1)
		self.keywordSuggestionCount:SetText(#candidates == 0 and "NO CANDIDATES" or (candidateStart .. "-" .. last .. " / " .. #candidates))
	end
	self:SetKeywordColorPager(self.keywordSuggestionPrevious, candidatePageCount > 1, self.keywordSuggestionPage > 1)
	self:SetKeywordColorPager(self.keywordSuggestionNext, candidatePageCount > 1, self.keywordSuggestionPage < candidatePageCount)

	if self.keywordSuggestionWord then
		if selected then
			self.keywordSuggestionWord:SetText(string.upper(selected.word))
			self.keywordSuggestionMeta:SetText("SEEN " .. tostring(selected.count) .. "   |   " .. (selected.source ~= "" and string.upper(selected.source) or "CHAT"))
			self.keywordSuggestionSample:SetText(selected.sample ~= "" and selected.sample or "No sample text was retained.")
		else
			self.keywordSuggestionWord:SetText("NO CANDIDATE SELECTED")
			self.keywordSuggestionMeta:SetText("Choose an item from the review queue.")
			self.keywordSuggestionSample:SetText("")
		end
	end

	local groups = getKeywordColorGroups()
	local selectedTarget, selectedTargetIndex = findKeywordColorGroup(groups, self.selectedKeywordSuggestionGroupId)
	if self.selectedKeywordSuggestionGroupId and not selectedTarget then
		self.selectedKeywordSuggestionGroupId = nil
	end
	local targetPageCount = math.max(1, math.ceil(#groups / KEYWORD_SUGGESTION_GROUP_ROWS_PER_PAGE))
	local targetSelectedPage = selectedTargetIndex and math.ceil(selectedTargetIndex / KEYWORD_SUGGESTION_GROUP_ROWS_PER_PAGE) or 1
	self.keywordSuggestionGroupPage = math.max(1, math.min(self.keywordSuggestionGroupPage or targetSelectedPage, targetPageCount))
	if selectedTargetIndex and targetSelectedPage ~= self.keywordSuggestionGroupPage then
		self.keywordSuggestionGroupPage = targetSelectedPage
	end
	local targetStart = ((self.keywordSuggestionGroupPage - 1) * KEYWORD_SUGGESTION_GROUP_ROWS_PER_PAGE) + 1
	for rowIndex, row in ipairs(self.keywordSuggestionGroupRows or {}) do
		local group = groups[targetStart + rowIndex - 1]
		if group then
			local colorName = getKeywordGroupColor(group)
			local isSelected = group.id == self.selectedKeywordSuggestionGroupId
			row.groupId = group.id
			row.label:SetText(group.label or group.id or "GROUP")
			setKeywordColorVisual(row.label, colorName)
			setKeywordColorVisual(row.accent, colorName, true)
			local r, g, b, a = Theme:GetColor(isSelected and "accentSoft" or "surfaceRaised")
			row.highlight:SetVertexColor(r, g, b, a * (isSelected and 0.88 or 0.34))
			if isSelected or row.hovered then row.highlight:Show() else row.highlight:Hide() end
			row:Show()
		else
			row.groupId = nil
			row.hovered = nil
			row:Hide()
		end
	end
	if self.keywordSuggestionGroupCount then
		local last = math.min(#groups, targetStart + KEYWORD_SUGGESTION_GROUP_ROWS_PER_PAGE - 1)
		self.keywordSuggestionGroupCount:SetText(targetPageCount > 1 and (targetStart .. "-" .. last .. " / " .. #groups) or (#groups .. " GROUPS"))
	end
	self:SetKeywordColorPager(self.keywordSuggestionGroupPrevious, targetPageCount > 1, self.keywordSuggestionGroupPage > 1)
	self:SetKeywordColorPager(self.keywordSuggestionGroupNext, targetPageCount > 1, self.keywordSuggestionGroupPage < targetPageCount)
	if self.keywordSuggestionTargetHint then
		self.keywordSuggestionTargetHint:SetText(selectedTarget
			and "TARGET  " .. (selectedTarget.label or selectedTarget.id)
			or "TARGET  CHOOSE A COLOR GROUP")
		setKeywordColorVisual(self.keywordSuggestionTargetHint, selectedTarget and getKeywordGroupColor(selectedTarget) or "warning")
	end

	local canAdd = selected ~= nil and selectedTarget ~= nil and type(addon.AddKeywordSuggestionToGroup) == "function"
	self:SetKeywordSuggestionControlEnabled(self.keywordSuggestionAddButton, canAdd)
	self:SetKeywordSuggestionControlEnabled(self.keywordSuggestionDismissButton, selected ~= nil and type(addon.DismissKeywordSuggestion) == "function")
	self:SetKeywordSuggestionControlEnabled(self.keywordSuggestionClearButton, #candidates > 0 and type(addon.ClearKeywordSuggestions) == "function")
	if not keepStatus then
		self:SetKeywordSuggestionStatus(#candidates == 0
			and "No candidates are waiting for review."
			or "Select a target color group before adding a candidate.", "textMuted")
	end
	self:SetKeywordSuggestionsSection(self.keywordSuggestionSection)
end

function Config:SetKeywordColorsSection(section)
	local available = hasKeywordSuggestionReadAPI()
	if section ~= "suggestions" or not available then
		section = "colors"
	end
	self.keywordColorsSection = section
	if self.keywordColorsPanel then
		if section == "colors" then self.keywordColorsPanel:Show() else self.keywordColorsPanel:Hide() end
	end
	if self.keywordSuggestionsPanel then
		if section == "suggestions" then self.keywordSuggestionsPanel:Show() else self.keywordSuggestionsPanel:Hide() end
	end
	if self.keywordColorGroupsSectionButton then
		setTabStyle(self.keywordColorGroupsSectionButton, section == "colors")
	end
	if self.keywordSuggestionsSectionButton then
		setTabStyle(self.keywordSuggestionsSectionButton, section == "suggestions")
	end
	if section == "suggestions" then
		self:RefreshKeywordSuggestionsPanel(true)
	end
end

function Config:BuildKeywordColorsPage()
	local page = self:CreatePage("keywords")
	createHeading(page, "Keyword Highlights", "Color related words together, then review optional reports before adding anything.")

	local function setFixedBounds(frame, parent, left, top, width, height)
		frame:SetSize(width, height)
		frame:SetPoint("TOPLEFT", parent, "TOPLEFT", left, -top)
		-- Focused mocks use the same numbers to guard the small-window layout.
		frame.keywordLayoutBounds = { left = left, top = top, width = width, height = height }
	end

	self.keywordSuggestionsSectionButton = Theme:CreateTightButton(page, "SUGGESTIONS", 20, false)
	self.keywordSuggestionsSectionButton:SetPoint("TOPRIGHT", page, "TOPRIGHT", -PAGE_GUTTER, -8)
	self.keywordSuggestionsSectionButton:SetScript("OnClick", function()
		Config:SetKeywordColorsSection("suggestions")
	end)
	setActionStyle(self.keywordSuggestionsSectionButton, "quiet", "Suggestions", "Review frequently seen words before adding them to a color group.")
	self.keywordColorGroupsSectionButton = Theme:CreateTightButton(page, "COLOR GROUPS", 20, false)
	self.keywordColorGroupsSectionButton:SetPoint("RIGHT", self.keywordSuggestionsSectionButton, "LEFT", -CONTROL_GAP, 0)
	self.keywordColorGroupsSectionButton:SetScript("OnClick", function()
		Config:SetKeywordColorsSection("colors")
	end)
	setActionStyle(self.keywordColorGroupsSectionButton, "quiet", "Color groups", "Choose the words and color that belong together.")

	local colorsPanel = CreateFrame("Frame", nil, page)
	colorsPanel:SetAllPoints(page)
	self.keywordColorsPanel = colorsPanel
	local suggestionPanel = CreateFrame("Frame", nil, page)
	suggestionPanel:SetAllPoints(page)
	suggestionPanel:Hide()
	self.keywordSuggestionsPanel = suggestionPanel

	-- Left: stable inventory. Right: one fixed inspector task at a time.
	local groupRowWidth, groupRowHeight, groupRows = 202, 20, 12
	local inspectorLeft, inspectorWidth = 218, 426
	local listPane = CreateFrame("Frame", nil, colorsPanel)
	setFixedBounds(listPane, colorsPanel, PAGE_GUTTER, PAGE_TOP, groupRowWidth, 290)
	self.keywordColorListPane = listPane
	local listTitle = Theme:CreateText(listPane, "GameFontNormalSmall", "gold")
	listTitle:SetPoint("TOPLEFT", listPane, "TOPLEFT", 0, -4)
	listTitle:SetText("COLOR GROUPS")
	self.keywordColorNewGroupButton = Theme:CreateTightButton(listPane, "NEW GROUP", 20, true)
	self.keywordColorNewGroupButton:SetPoint("TOPRIGHT", listPane, "TOPRIGHT", 0, 0)
	self.keywordColorNewGroupButton:SetScript("OnClick", function()
		Config:BeginKeywordColorGroupCreation()
	end)
	setActionStyle(self.keywordColorNewGroupButton, "primary", "New color group", "Create a personal group, then add its words or phrases.")

	self.keywordColorGroupRows = {}
	for index = 1, groupRows do
		local row = CreateFrame("Button", nil, listPane)
		row:SetSize(groupRowWidth, groupRowHeight)
		row:SetPoint("TOPLEFT", listPane, "TOPLEFT", 0, -22 - ((index - 1) * groupRowHeight))
		row.highlight = row:CreateTexture(nil, "BACKGROUND")
		row.highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
		row.highlight:SetAllPoints(row)
		row.highlight:Hide()
		row.accent = row:CreateTexture(nil, "ARTWORK")
		row.accent:SetTexture("Interface\\Buttons\\WHITE8x8")
		row.accent:SetSize(2, 14)
		row.accent:SetPoint("LEFT", row, "LEFT", 1, 0)
		row.label = Theme:CreateText(row, "GameFontNormalSmall", "text")
		row.label:SetPoint("LEFT", row, "LEFT", 7, 0)
		row.label:SetWidth(181)
		row.label:SetJustifyH("LEFT")
		row.swatch = row:CreateTexture(nil, "ARTWORK")
		row.swatch:SetTexture("Interface\\Buttons\\WHITE8x8")
		row.swatch:SetSize(5, 14)
		row.swatch:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		row:SetScript("OnClick", function(self)
			if self.groupId then Config:SelectKeywordColorGroup(self.groupId) end
		end)
		row:SetScript("OnEnter", function(self)
			self.hovered = true
			Config:RefreshKeywordColorsPage(true)
		end)
		row:SetScript("OnLeave", function(self)
			self.hovered = false
			Config:RefreshKeywordColorsPage(true)
		end)
		table.insert(self.keywordColorGroupRows, row)
	end
	self.keywordColorGroupCount = Theme:CreateText(listPane, "GameFontHighlightSmall", "textMuted")
	self.keywordColorGroupCount:SetPoint("TOPLEFT", listPane, "TOPLEFT", 0, -268)
	self.keywordColorGroupCount:SetWidth(112)
	self.keywordColorGroupCount:SetJustifyH("LEFT")
	self.keywordColorGroupPrevious = Theme:CreateTightButton(listPane, "<", 20, false)
	self.keywordColorGroupPrevious:SetPoint("LEFT", self.keywordColorGroupCount, "RIGHT", 4, 0)
	self.keywordColorGroupPrevious:SetScript("OnClick", function()
		Config.keywordColorGroupPage = math.max(1, (Config.keywordColorGroupPage or 1) - 1)
		Config:RefreshKeywordColorsPage(true)
	end)
	self.keywordColorGroupNext = Theme:CreateTightButton(listPane, ">", 20, false)
	self.keywordColorGroupNext:SetPoint("LEFT", self.keywordColorGroupPrevious, "RIGHT", CONTROL_GAP, 0)
	self.keywordColorGroupNext:SetScript("OnClick", function()
		Config.keywordColorGroupPage = (Config.keywordColorGroupPage or 1) + 1
		Config:RefreshKeywordColorsPage(true)
	end)

	local inspectorTitle = Theme:CreateText(colorsPanel, "GameFontNormalSmall", "gold")
	inspectorTitle:SetPoint("TOPLEFT", colorsPanel, "TOPLEFT", inspectorLeft, -PAGE_TOP)
	inspectorTitle:SetWidth(400)
	inspectorTitle:SetJustifyH("LEFT")
	inspectorTitle:SetText("COLOR GROUP")
	self.keywordColorInspectorTitle = inspectorTitle
	local swatch = colorsPanel:CreateTexture(nil, "ARTWORK")
	swatch:SetTexture("Interface\\Buttons\\WHITE8x8")
	swatch:SetSize(11, 11)
	swatch:SetPoint("TOPRIGHT", colorsPanel, "TOPLEFT", inspectorLeft + inspectorWidth, -47)
	self.keywordColorInspectorSwatch = swatch

	self.keywordColorInspectorWordsButton = Theme:CreateTightButton(colorsPanel, "WORDS", 20, false)
	self.keywordColorInspectorWordsButton:SetPoint("TOPLEFT", colorsPanel, "TOPLEFT", inspectorLeft, -68)
	self.keywordColorInspectorWordsButton:SetScript("OnClick", function()
		Config:SetKeywordColorInspectorSection("words")
	end)
	setActionStyle(self.keywordColorInspectorWordsButton, "quiet", "Words", "Review or add every word and phrase that shares this color.")
	self.keywordColorInspectorColorButton = Theme:CreateTightButton(colorsPanel, "COLOR", 20, false)
	self.keywordColorInspectorColorButton:SetPoint("LEFT", self.keywordColorInspectorWordsButton, "RIGHT", CONTROL_GAP, 0)
	self.keywordColorInspectorColorButton:SetScript("OnClick", function()
		Config:SetKeywordColorInspectorSection("color")
	end)
	setActionStyle(self.keywordColorInspectorColorButton, "quiet", "Color", "Choose the shared color or restore this group.")

	local wordsPane = CreateFrame("Frame", nil, colorsPanel)
	setFixedBounds(wordsPane, colorsPanel, inspectorLeft, 94, inspectorWidth, 330)
	self.keywordColorInspectorWordsPane = wordsPane
	local colorPane = CreateFrame("Frame", nil, colorsPanel)
	setFixedBounds(colorPane, colorsPanel, inspectorLeft, 94, inspectorWidth, 330)
	colorPane:Hide()
	self.keywordColorInspectorColorPane = colorPane

	local wordsTitle = Theme:CreateText(wordsPane, "GameFontNormalSmall", "gold")
	wordsTitle:SetPoint("TOPLEFT", wordsPane, "TOPLEFT", 0, -4)
	wordsTitle:SetText("WORDS USING THIS COLOR")
	self.keywordColorWordsTitle = wordsTitle
	self.keywordColorTermRows = {}
	local termColumnWidth, termRowHeight, termRowsPerColumn = 202, 20, 6
	for index = 1, termRowsPerColumn * 2 do
		local zeroIndex = index - 1
		local column = math.floor(zeroIndex / termRowsPerColumn)
		local rowIndex = zeroIndex % termRowsPerColumn
		local row = CreateFrame("Frame", nil, wordsPane)
		row:SetSize(termColumnWidth, termRowHeight)
		row:SetPoint("TOPLEFT", wordsPane, "TOPLEFT", column * 206, -26 - (rowIndex * termRowHeight))
		row.accent = row:CreateTexture(nil, "ARTWORK")
		row.accent:SetTexture("Interface\\Buttons\\WHITE8x8")
		row.accent:SetSize(2, 12)
		row.accent:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.label = Theme:CreateText(row, "GameFontHighlightSmall", "text")
		row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
		row.label:SetWidth(termColumnWidth - 8)
		row.label:SetJustifyH("LEFT")
		table.insert(self.keywordColorTermRows, row)
	end
	self.keywordColorTermCount = Theme:CreateText(wordsPane, "GameFontHighlightSmall", "textMuted")
	self.keywordColorTermCount:SetPoint("TOPLEFT", wordsPane, "TOPLEFT", 0, -152)
	self.keywordColorTermCount:SetWidth(360)
	self.keywordColorTermCount:SetJustifyH("LEFT")
	self.keywordColorTermPrevious = Theme:CreateTightButton(wordsPane, "<", 20, false)
	self.keywordColorTermPrevious:SetPoint("TOPLEFT", wordsPane, "TOPLEFT", 380, -152)
	self.keywordColorTermPrevious:SetScript("OnClick", function()
		Config.keywordColorTermPage = math.max(1, (Config.keywordColorTermPage or 1) - 1)
		Config:RefreshKeywordColorsPage(true)
	end)
	self.keywordColorTermNext = Theme:CreateTightButton(wordsPane, ">", 20, false)
	self.keywordColorTermNext:SetPoint("TOPLEFT", wordsPane, "TOPLEFT", 403, -152)
	self.keywordColorTermNext:SetScript("OnClick", function()
		Config.keywordColorTermPage = (Config.keywordColorTermPage or 1) + 1
		Config:RefreshKeywordColorsPage(true)
	end)
	self.keywordColorTermAddLabel = Theme:CreateText(wordsPane, "GameFontHighlightSmall", "textMuted")
	self.keywordColorTermAddLabel:SetPoint("TOPLEFT", wordsPane, "TOPLEFT", 0, -198)
	self.keywordColorTermAddLabel:SetText("ADD WORD / PHRASE")
	self.keywordColorTermAddEdit = Theme:CreateEditBox(wordsPane, 180, 22, false)
	self.keywordColorTermAddEdit:SetPoint("TOPLEFT", wordsPane, "TOPLEFT", 0, -213)
	self.keywordColorTermAddEdit:SetMaxLetters(40)
	self.keywordColorTermAddEdit:HookScript("OnEnterPressed", function(self)
		self:ClearFocus()
		Config:AddKeywordColorGroupWord()
	end)
	self.keywordColorTermCaseToggle = Theme:CreateCompactToggle(wordsPane, "MATCH CASE", 112)
	self.keywordColorTermCaseToggle:SetPoint("LEFT", self.keywordColorTermAddEdit, "RIGHT", CONTROL_GAP, 0)
	setControlTooltip(self.keywordColorTermCaseToggle, "Match case", "Only highlight this spelling when its uppercase and lowercase letters also match.")
	self.keywordColorTermAddButton = Theme:CreateTightButton(wordsPane, "ADD", 22, true)
	self.keywordColorTermAddButton:SetPoint("LEFT", self.keywordColorTermCaseToggle, "RIGHT", CONTROL_GAP, 0)
	self.keywordColorTermAddButton:SetScript("OnClick", function()
		Config:AddKeywordColorGroupWord()
	end)
	setActionStyle(self.keywordColorTermAddButton, "primary", "Add word or phrase", "Add this text to the selected color group.")

	self.keywordColorInspectorValue = Theme:CreateText(colorPane, "GameFontHighlightSmall", "textMuted")
	self.keywordColorInspectorValue:SetPoint("TOPLEFT", colorPane, "TOPLEFT", 0, -4)
	self.keywordColorInspectorValue:SetText("CURRENT")
	self.keywordColorNewGroupNameLabel = Theme:CreateText(colorPane, "GameFontHighlightSmall", "textMuted")
	self.keywordColorNewGroupNameLabel:SetPoint("TOPLEFT", colorPane, "TOPLEFT", 0, -4)
	self.keywordColorNewGroupNameLabel:SetText("NAME")
	self.keywordColorNewGroupNameEdit = Theme:CreateEditBox(colorPane, 260, 22, false)
	self.keywordColorNewGroupNameEdit:SetPoint("TOPLEFT", colorPane, "TOPLEFT", 0, -20)
	self.keywordColorNewGroupNameEdit:SetMaxLetters(32)
	self.keywordColorNewGroupNameEdit:HookScript("OnEnterPressed", function(self)
		self:ClearFocus()
		Config:CreateKeywordColorGroup()
	end)
	self.keywordColorPaletteTitle = Theme:CreateText(colorPane, "GameFontNormalSmall", "gold")
	self.keywordColorPaletteTitle:SetPoint("TOPLEFT", colorPane, "TOPLEFT", 0, -56)
	self.keywordColorPaletteTitle:SetText("COLOR")
	self.keywordColorOptionButtons = {}
	for index, option in ipairs(getKeywordColorOptions()) do
		local button = Theme:CreateTightButton(colorPane, option.label, 20, false)
		local zeroIndex = index - 1
		local column = zeroIndex % 4
		local rowIndex = math.floor(zeroIndex / 4)
		button:SetWidth(102)
		button:SetPoint("TOPLEFT", colorPane, "TOPLEFT", column * 106, -76 - (rowIndex * 24))
		button.colorName = option.id
		button:SetScript("OnClick", function(self)
			Config:ApplyKeywordColor(self.colorName)
		end)
		table.insert(self.keywordColorOptionButtons, button)
	end
	self.keywordColorDefaultButton = Theme:CreateTightButton(colorPane, "USE DEFAULT", 20, false)
	self.keywordColorDefaultButton:SetPoint("TOPLEFT", colorPane, "TOPLEFT", 0, -144)
	self.keywordColorDefaultButton:SetScript("OnClick", function()
		Config:ResetSelectedKeywordColorGroup()
	end)
	setActionStyle(self.keywordColorDefaultButton, "quiet", "Restore this group", "Return only this group's color to its built-in or starting color.")
	self.keywordColorCreateGroupButton = Theme:CreateTightButton(colorPane, "CREATE GROUP", 20, true)
	self.keywordColorCreateGroupButton:SetPoint("TOPLEFT", colorPane, "TOPLEFT", 0, -144)
	self.keywordColorCreateGroupButton:SetScript("OnClick", function()
		Config:CreateKeywordColorGroup()
	end)
	setActionStyle(self.keywordColorCreateGroupButton, "primary", "Create group", "Create this personal group and continue directly to its words.")
	self.keywordColorCancelGroupButton = Theme:CreateTightButton(colorPane, "CANCEL", 20, false)
	self.keywordColorCancelGroupButton:SetPoint("LEFT", self.keywordColorCreateGroupButton, "RIGHT", CONTROL_GAP, 0)
	self.keywordColorCancelGroupButton:SetScript("OnClick", function()
		Config:CancelKeywordColorGroupCreation()
	end)
	setActionStyle(self.keywordColorCancelGroupButton, "quiet", "Cancel", "Discard this unfinished group.")
	self.keywordColorMaintenanceTitle = Theme:CreateText(colorPane, "GameFontNormalSmall", "gold")
	self.keywordColorMaintenanceTitle:SetPoint("TOPLEFT", colorPane, "TOPLEFT", 0, -190)
	self.keywordColorMaintenanceTitle:SetText("MAINTENANCE")
	local reset = Theme:CreateTightButton(colorPane, "RESET BUILT-INS", 20, false)
	reset:SetPoint("TOPLEFT", colorPane, "TOPLEFT", 0, -210)
	reset:SetScript("OnClick", function()
		Config:ResetKeywordColors()
	end)
	setActionStyle(reset, "quiet", "Reset built-in groups", "Restore built-in colors while keeping every personal group.")
	self.keywordColorResetBuiltInsButton = reset
	self.keywordColorDeleteGroupButton = Theme:CreateTightButton(colorPane, "DELETE GROUP", 20, false)
	self.keywordColorDeleteGroupButton:SetPoint("LEFT", reset, "RIGHT", CONTROL_GAP, 0)
	self.keywordColorDeleteGroupButton:SetScript("OnClick", function()
		Config:DeleteSelectedKeywordColorGroup()
	end)
	setActionStyle(self.keywordColorDeleteGroupButton, "danger", "Delete personal group", "Delete this personal group. Built-in groups cannot be deleted.")
	self.keywordColorStatus = Theme:CreateText(colorsPanel, "GameFontHighlightSmall", "textMuted")
	self.keywordColorStatus:SetPoint("TOPLEFT", colorsPanel, "TOPLEFT", inspectorLeft, -448)
	self.keywordColorStatus:SetWidth(inspectorWidth)
	self.keywordColorStatus:SetJustifyH("LEFT")

	-- Suggestions retain the safe explicit-target contract, but each operation
	-- now owns a calm pane instead of sharing one dense report surface.
	self.keywordSuggestionReviewButton = Theme:CreateTightButton(suggestionPanel, "REVIEW", 20, false)
	self.keywordSuggestionReviewButton:SetPoint("TOPLEFT", suggestionPanel, "TOPLEFT", PAGE_GUTTER, -48)
	self.keywordSuggestionReviewButton:SetScript("OnClick", function()
		Config:SetKeywordSuggestionsSection("review")
	end)
	setActionStyle(self.keywordSuggestionReviewButton, "quiet", "Review", "Inspect a candidate, choose its target group, then add or dismiss it.")
	self.keywordSuggestionSettingsButton = Theme:CreateTightButton(suggestionPanel, "REPORT SETTINGS", 20, false)
	self.keywordSuggestionSettingsButton:SetPoint("LEFT", self.keywordSuggestionReviewButton, "RIGHT", CONTROL_GAP, 0)
	self.keywordSuggestionSettingsButton:SetScript("OnClick", function()
		Config:SetKeywordSuggestionsSection("settings")
	end)
	setActionStyle(self.keywordSuggestionSettingsButton, "quiet", "Report settings", "Control whether candidates are collected and how often they must appear.")
	self.keywordSuggestionMoreButton = Theme:CreateTightButton(suggestionPanel, "MORE", 20, false)
	self.keywordSuggestionMoreButton:SetPoint("LEFT", self.keywordSuggestionSettingsButton, "RIGHT", CONTROL_GAP, 0)
	self.keywordSuggestionMoreButton:SetScript("OnClick", function()
		Config:SetKeywordSuggestionsSection("more")
	end)
	setActionStyle(self.keywordSuggestionMoreButton, "quiet", "More", "Open report maintenance without changing any configured colors.")

	local reviewPane = CreateFrame("Frame", nil, suggestionPanel)
	setFixedBounds(reviewPane, suggestionPanel, PAGE_GUTTER, 76, PAGE_WIDTH, 366)
	self.keywordSuggestionReviewPane = reviewPane
	local settingsPane = CreateFrame("Frame", nil, suggestionPanel)
	setFixedBounds(settingsPane, suggestionPanel, PAGE_GUTTER, 76, PAGE_WIDTH, 366)
	settingsPane:Hide()
	self.keywordSuggestionSettingsPane = settingsPane
	local morePane = CreateFrame("Frame", nil, suggestionPanel)
	setFixedBounds(morePane, suggestionPanel, PAGE_GUTTER, 76, PAGE_WIDTH, 366)
	morePane:Hide()
	self.keywordSuggestionMorePane = morePane

	local queueWidth, inspectorX, inspectorWidthSuggestion = 210, 222, 414
	local queueTitle = Theme:CreateText(reviewPane, "GameFontNormalSmall", "gold")
	queueTitle:SetPoint("TOPLEFT", reviewPane, "TOPLEFT", 0, -4)
	queueTitle:SetText("REVIEW QUEUE")
	self.keywordSuggestionRows = {}
	for index = 1, KEYWORD_SUGGESTION_ROWS_PER_PAGE do
		local row = CreateFrame("Button", nil, reviewPane)
		row:SetSize(queueWidth, 23)
		row:SetPoint("TOPLEFT", reviewPane, "TOPLEFT", 0, -24 - ((index - 1) * 24))
		row.highlight = row:CreateTexture(nil, "BACKGROUND")
		row.highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
		row.highlight:SetAllPoints(row)
		row.highlight:Hide()
		row.accent = row:CreateTexture(nil, "ARTWORK")
		row.accent:SetTexture("Interface\\Buttons\\WHITE8x8")
		row.accent:SetSize(2, 17)
		row.accent:SetPoint("LEFT", row, "LEFT", 1, 0)
		row.word = Theme:CreateText(row, "GameFontNormalSmall", "text")
		row.word:SetPoint("TOPLEFT", row, "TOPLEFT", 7, -1)
		row.word:SetWidth(152)
		row.word:SetJustifyH("LEFT")
		row.count = Theme:CreateText(row, "GameFontHighlightSmall", "gold")
		row.count:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -1)
		row.source = Theme:CreateText(row, "GameFontHighlightSmall", "textMuted")
		row.source:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 7, 1)
		row.source:SetWidth(184)
		row.source:SetJustifyH("LEFT")
		row:SetScript("OnClick", function(self)
			if self.suggestionId ~= nil then Config:SelectKeywordSuggestion(self.suggestionId) end
		end)
		row:SetScript("OnEnter", function(self)
			self.hovered = true
			Config:RefreshKeywordSuggestionsPanel(true)
		end)
		row:SetScript("OnLeave", function(self)
			self.hovered = false
			Config:RefreshKeywordSuggestionsPanel(true)
		end)
		table.insert(self.keywordSuggestionRows, row)
	end
	self.keywordSuggestionCount = Theme:CreateText(reviewPane, "GameFontHighlightSmall", "textMuted")
	self.keywordSuggestionCount:SetPoint("TOPLEFT", reviewPane, "TOPLEFT", 0, -224)
	self.keywordSuggestionCount:SetWidth(114)
	self.keywordSuggestionCount:SetJustifyH("LEFT")
	self.keywordSuggestionPrevious = Theme:CreateTightButton(reviewPane, "<", 20, false)
	self.keywordSuggestionPrevious:SetPoint("TOPLEFT", reviewPane, "TOPLEFT", 118, -224)
	self.keywordSuggestionPrevious:SetScript("OnClick", function()
		Config.keywordSuggestionPage = math.max(1, (Config.keywordSuggestionPage or 1) - 1)
		Config:RefreshKeywordSuggestionsPanel(true)
	end)
	self.keywordSuggestionNext = Theme:CreateTightButton(reviewPane, ">", 20, false)
	self.keywordSuggestionNext:SetPoint("TOPLEFT", reviewPane, "TOPLEFT", 141, -224)
	self.keywordSuggestionNext:SetScript("OnClick", function()
		Config.keywordSuggestionPage = (Config.keywordSuggestionPage or 1) + 1
		Config:RefreshKeywordSuggestionsPanel(true)
	end)

	local selectedTitle = Theme:CreateText(reviewPane, "GameFontNormalSmall", "gold")
	selectedTitle:SetPoint("TOPLEFT", reviewPane, "TOPLEFT", inspectorX, -4)
	selectedTitle:SetText("1  SAMPLE")
	self.keywordSuggestionWord = Theme:CreateText(reviewPane, "GameFontNormal", "text")
	self.keywordSuggestionWord:SetPoint("TOPLEFT", reviewPane, "TOPLEFT", inspectorX, -24)
	self.keywordSuggestionWord:SetWidth(inspectorWidthSuggestion)
	self.keywordSuggestionWord:SetJustifyH("LEFT")
	self.keywordSuggestionMeta = Theme:CreateText(reviewPane, "GameFontHighlightSmall", "textMuted")
	self.keywordSuggestionMeta:SetPoint("TOPLEFT", reviewPane, "TOPLEFT", inspectorX, -45)
	self.keywordSuggestionMeta:SetWidth(inspectorWidthSuggestion)
	self.keywordSuggestionMeta:SetJustifyH("LEFT")
	self.keywordSuggestionSample = Theme:CreateText(reviewPane, "GameFontHighlightSmall", "text")
	self.keywordSuggestionSample:SetPoint("TOPLEFT", reviewPane, "TOPLEFT", inspectorX, -64)
	self.keywordSuggestionSample:SetWidth(inspectorWidthSuggestion)
	self.keywordSuggestionSample:SetJustifyH("LEFT")
	if self.keywordSuggestionSample.SetWordWrap then self.keywordSuggestionSample:SetWordWrap(false) end

	local targetTitle = Theme:CreateText(reviewPane, "GameFontNormalSmall", "gold")
	targetTitle:SetPoint("TOPLEFT", reviewPane, "TOPLEFT", inspectorX, -104)
	targetTitle:SetText("2  TARGET GROUP")
	self.keywordSuggestionTargetHint = Theme:CreateText(reviewPane, "GameFontHighlightSmall", "warning")
	self.keywordSuggestionTargetHint:SetPoint("TOPLEFT", reviewPane, "TOPLEFT", inspectorX, -123)
	self.keywordSuggestionTargetHint:SetWidth(inspectorWidthSuggestion)
	self.keywordSuggestionTargetHint:SetJustifyH("LEFT")
	self.keywordSuggestionGroupRows = {}
	local targetRowWidth, targetRowsPerColumn = 192, 3
	for index = 1, KEYWORD_SUGGESTION_GROUP_ROWS_PER_PAGE do
		local zeroIndex = index - 1
		local column = math.floor(zeroIndex / targetRowsPerColumn)
		local rowIndex = zeroIndex % targetRowsPerColumn
		local row = CreateFrame("Button", nil, reviewPane)
		row:SetSize(targetRowWidth, 20)
		row:SetPoint("TOPLEFT", reviewPane, "TOPLEFT", inspectorX + (column * 198), -144 - (rowIndex * 22))
		row.highlight = row:CreateTexture(nil, "BACKGROUND")
		row.highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
		row.highlight:SetAllPoints(row)
		row.highlight:Hide()
		row.accent = row:CreateTexture(nil, "ARTWORK")
		row.accent:SetTexture("Interface\\Buttons\\WHITE8x8")
		row.accent:SetSize(2, 13)
		row.accent:SetPoint("LEFT", row, "LEFT", 1, 0)
		row.label = Theme:CreateText(row, "GameFontNormalSmall", "text")
		row.label:SetPoint("LEFT", row, "LEFT", 7, 0)
		row.label:SetWidth(targetRowWidth - 9)
		row.label:SetJustifyH("LEFT")
		row:SetScript("OnClick", function(self)
			if self.groupId then Config:SelectKeywordSuggestionGroup(self.groupId) end
		end)
		row:SetScript("OnEnter", function(self)
			self.hovered = true
			Config:RefreshKeywordSuggestionsPanel(true)
		end)
		row:SetScript("OnLeave", function(self)
			self.hovered = false
			Config:RefreshKeywordSuggestionsPanel(true)
		end)
		table.insert(self.keywordSuggestionGroupRows, row)
	end
	self.keywordSuggestionGroupCount = Theme:CreateText(reviewPane, "GameFontHighlightSmall", "textMuted")
	self.keywordSuggestionGroupCount:SetPoint("TOPLEFT", reviewPane, "TOPLEFT", inspectorX, -218)
	self.keywordSuggestionGroupCount:SetWidth(102)
	self.keywordSuggestionGroupCount:SetJustifyH("LEFT")
	self.keywordSuggestionGroupPrevious = Theme:CreateTightButton(reviewPane, "<", 20, false)
	self.keywordSuggestionGroupPrevious:SetPoint("TOPLEFT", reviewPane, "TOPLEFT", inspectorX + 106, -218)
	self.keywordSuggestionGroupPrevious:SetScript("OnClick", function()
		Config.keywordSuggestionGroupPage = math.max(1, (Config.keywordSuggestionGroupPage or 1) - 1)
		Config:RefreshKeywordSuggestionsPanel(true)
	end)
	self.keywordSuggestionGroupNext = Theme:CreateTightButton(reviewPane, ">", 20, false)
	self.keywordSuggestionGroupNext:SetPoint("TOPLEFT", reviewPane, "TOPLEFT", inspectorX + 129, -218)
	self.keywordSuggestionGroupNext:SetScript("OnClick", function()
		Config.keywordSuggestionGroupPage = (Config.keywordSuggestionGroupPage or 1) + 1
		Config:RefreshKeywordSuggestionsPanel(true)
	end)
	local addTitle = Theme:CreateText(reviewPane, "GameFontNormalSmall", "gold")
	addTitle:SetPoint("TOPLEFT", reviewPane, "TOPLEFT", inspectorX, -254)
	addTitle:SetText("3  ADD")
	self.keywordSuggestionAddButton = Theme:CreateTightButton(reviewPane, "ADD TO GROUP", 20, true)
	self.keywordSuggestionAddButton:SetPoint("TOPLEFT", reviewPane, "TOPLEFT", inspectorX, -274)
	self.keywordSuggestionAddButton:SetScript("OnClick", function()
		Config:AddSelectedKeywordSuggestion()
	end)
	setActionStyle(self.keywordSuggestionAddButton, "primary", "Add to group", "Add the selected candidate only to the explicit target shown above.")
	self.keywordSuggestionDismissButton = Theme:CreateTightButton(reviewPane, "DISMISS", 20, false)
	self.keywordSuggestionDismissButton:SetPoint("LEFT", self.keywordSuggestionAddButton, "RIGHT", CONTROL_GAP, 0)
	self.keywordSuggestionDismissButton:SetScript("OnClick", function()
		Config:DismissSelectedKeywordSuggestion()
	end)
	setActionStyle(self.keywordSuggestionDismissButton, "quiet", "Dismiss candidate", "Remove this candidate from the report without changing any color group.")

	local settingsTitle = Theme:CreateText(settingsPane, "GameFontNormalSmall", "gold")
	settingsTitle:SetPoint("TOPLEFT", settingsPane, "TOPLEFT", 0, -4)
	settingsTitle:SetText("REPORT SETTINGS")
	local settingsDetail = Theme:CreateText(settingsPane, "GameFontHighlightSmall", "textMuted")
	settingsDetail:SetPoint("TOPLEFT", settingsPane, "TOPLEFT", 0, -26)
	settingsDetail:SetWidth(PAGE_WIDTH)
	settingsDetail:SetJustifyH("LEFT")
	settingsDetail:SetText("Choose whether Chatty collects repeated candidate words and how much evidence it needs.")
	self.keywordSuggestionTrackingToggle = Theme:CreateCompactToggle(settingsPane, "TRACK CANDIDATES", 162)
	self.keywordSuggestionTrackingToggle:SetPoint("TOPLEFT", settingsPane, "TOPLEFT", 0, -58)
	self.keywordSuggestionTrackingToggle.OnValueChanged = function(_, value)
		Config:SetKeywordSuggestionEnabled(value)
	end
	setControlTooltip(self.keywordSuggestionTrackingToggle, "Track candidates", "Build a private review report. This never colors chat automatically.")
	self.keywordSuggestionThresholdLabel = Theme:CreateText(settingsPane, "GameFontHighlightSmall", "textMuted")
	self.keywordSuggestionThresholdLabel:SetPoint("LEFT", self.keywordSuggestionTrackingToggle, "RIGHT", 14, 0)
	self.keywordSuggestionThresholdLabel:SetText("MIN SEEN")
	self.keywordSuggestionThresholdEdit = Theme:CreateEditBox(settingsPane, 46, 20, false)
	self.keywordSuggestionThresholdEdit:SetPoint("LEFT", self.keywordSuggestionThresholdLabel, "RIGHT", 5, 0)
	self.keywordSuggestionThresholdEdit:HookScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	self.keywordSuggestionThresholdEdit:HookScript("OnEditFocusLost", function()
		Config:CommitKeywordSuggestionThreshold()
	end)
	setControlTooltip(self.keywordSuggestionThresholdEdit, "Minimum sightings", "A word must be seen this many times before it enters the review queue.")
	self.keywordSuggestionSettingsNote = Theme:CreateText(settingsPane, "GameFontHighlightSmall", "textMuted")
	self.keywordSuggestionSettingsNote:SetPoint("TOPLEFT", settingsPane, "TOPLEFT", 0, -88)
	self.keywordSuggestionSettingsNote:SetWidth(PAGE_WIDTH)
	self.keywordSuggestionSettingsNote:SetJustifyH("LEFT")

	local moreTitle = Theme:CreateText(morePane, "GameFontNormalSmall", "gold")
	moreTitle:SetPoint("TOPLEFT", morePane, "TOPLEFT", 0, -4)
	moreTitle:SetText("REPORT MAINTENANCE")
	local moreDetail = Theme:CreateText(morePane, "GameFontHighlightSmall", "textMuted")
	moreDetail:SetPoint("TOPLEFT", morePane, "TOPLEFT", 0, -28)
	moreDetail:SetWidth(PAGE_WIDTH)
	moreDetail:SetJustifyH("LEFT")
	moreDetail:SetText("Clearing the review queue does not remove words from a group or change any message color.")
	self.keywordSuggestionClearButton = Theme:CreateTightButton(morePane, "CLEAR REVIEW QUEUE", 20, false)
	self.keywordSuggestionClearButton:SetPoint("TOPLEFT", morePane, "TOPLEFT", 0, -62)
	self.keywordSuggestionClearButton:SetScript("OnClick", function()
		Config:ClearKeywordSuggestions()
	end)
	setActionStyle(self.keywordSuggestionClearButton, "danger", "Clear review queue", "Remove every reported candidate. Configured color groups remain unchanged.")

	self.keywordSuggestionStatus = Theme:CreateText(suggestionPanel, "GameFontHighlightSmall", "textMuted")
	self.keywordSuggestionStatus:SetPoint("TOPLEFT", suggestionPanel, "TOPLEFT", PAGE_GUTTER, -450)
	self.keywordSuggestionStatus:SetWidth(PAGE_WIDTH)
	self.keywordSuggestionStatus:SetJustifyH("LEFT")

	self.selectedKeywordColorGroupId = self.selectedKeywordColorGroupId or getKeywordColorGroups()[1].id
	self.keywordColorGroupPage = self.keywordColorGroupPage or 1
	self.keywordColorTermPage = self.keywordColorTermPage or 1
	self.keywordColorInspectorSection = self.keywordColorInspectorSection or "words"
	self.keywordSuggestionPage = self.keywordSuggestionPage or 1
	self.keywordSuggestionGroupPage = self.keywordSuggestionGroupPage or 1
	self.keywordSuggestionSection = self.keywordSuggestionSection or "review"
	self.keywordColorsSection = self.keywordColorsSection or "colors"
	self:RefreshKeywordColorsPage()
	self:SetKeywordColorsSection(self.keywordColorsSection)
	return page
end

-- The copied Chatter modules modify ChatFrameN directly, while Intelligent
-- Chat owns SmartDock.  This page deliberately uses ModuleCatalog rather than
-- the old Ace options, so the UI can never imply that a native hook is active
-- in the Smart Chat path.
local MODULE_ROWS_PER_PAGE = 10
local MODULE_NAV_ROWS_PER_PAGE = 4

local function getModuleCatalog()
	if addon.GetModuleCatalog then
		return addon:GetModuleCatalog() or {}
	end
	return {}
end

-- The original Chatter modules are still present in the addon.  Count their
-- actual Smart Chat status here so the UI can explain the migration honestly
-- instead of making a player hunt through implementation-facing filters.
local function getModuleCatalogCounts(catalog)
	local counts = { smart = 0, native = 0, adapter = 0 }
	for _, module in ipairs(catalog or {}) do
		if counts[module.status] ~= nil then
			counts[module.status] = counts[module.status] + 1
		end
	end
	return counts
end

local function moduleStatusColor(module)
	if module and module.status == "smart" then
		return "goldBright"
	elseif module and module.status == "adapter" then
		return "warning"
	end
	return "textMuted"
end

local function moduleHumanStatus(module)
	if module and module.status == "smart" then
		return "RUNS IN CHATTY"
	elseif module and module.status == "adapter" then
		return "NOT YET AVAILABLE"
	end
	return "RUNS ONLY WITH NATIVE FALLBACK"
end

local function normalizeModuleFilter(filter)
	-- Module filters are local UI state, not SavedVariables. Normalize the old
	-- implementation-facing values so a live profile reload lands in one of the
	-- two player-facing workspaces without needing a migration.
	if filter == "legacy" or filter == "native" or filter == "adapter" then
		return "legacy"
	end
	return "features"
end

local function moduleFilterFor(module)
	return module and module.status == "smart" and "features" or "legacy"
end

function Config:GetFilteredModules()
	local filter = normalizeModuleFilter(self.moduleFilter)
	self.moduleFilter = filter
	local result = {}
	for _, module in ipairs(getModuleCatalog()) do
		if (filter == "features" and module.status == "smart")
			or (filter == "legacy" and (module.status == "native" or module.status == "adapter")) then
			table.insert(result, module)
		end
	end
	return result
end

function Config:SetModuleStatus(text, colorName)
	if not self.modulesStatus then
		return
	end
	self.modulesStatus:SetText(text or "")
	Theme.texts[self.modulesStatus] = colorName or "textMuted"
	local r, g, b, a = Theme:GetColor(Theme.texts[self.modulesStatus])
	self.modulesStatus:SetTextColor(r, g, b, a)
end

function Config:SelectModule(id)
	local allModules = getModuleCatalog()
	local selected
	for _, module in ipairs(allModules) do
		if module.id == id then
			selected = module
			break
		end
	end
	if selected then
		self.moduleFilter = moduleFilterFor(selected)
		self.selectedModuleId = id
	end
	for index, module in ipairs(self:GetFilteredModules()) do
		if module.id == id then
			self.moduleListPage = math.ceil(index / MODULE_ROWS_PER_PAGE)
			break
		end
	end
	for index, module in ipairs(allModules) do
		if module.id == id then
			self.moduleNavigationPage = math.ceil(index / MODULE_NAV_ROWS_PER_PAGE)
			break
		end
	end
	self:RefreshModulesPage(true)
	self:RefreshNavigation()
end

function Config:RefreshModulesPage(keepStatus)
	if not self.modulesPage then
		return
	end
	local modules = self:GetFilteredModules()
	local catalog = getModuleCatalog()
	local catalogCounts = getModuleCatalogCounts(catalog)
	if self.moduleOverview then
		if self.moduleFilter == "legacy" then
			self.moduleOverview:SetText(tostring(catalogCounts.native)
				.. " run only with native fallback; " .. tostring(catalogCounts.adapter)
				.. " not yet available in Chatty.")
		else
			self.moduleOverview:SetText(tostring(catalogCounts.smart)
				.. " features run directly in Chatty.")
		end
	end
	local selected
	for _, module in ipairs(modules) do
		if module.id == self.selectedModuleId then
			selected = module
			break
		end
	end
	if not selected then
		selected = modules[1]
		self.selectedModuleId = selected and selected.id or nil
	end

	local pageCount = math.max(1, math.ceil(#modules / MODULE_ROWS_PER_PAGE))
	self.moduleListPage = math.max(1, math.min(self.moduleListPage or 1, pageCount))
	local first = ((self.moduleListPage - 1) * MODULE_ROWS_PER_PAGE) + 1
	for index, row in ipairs(self.moduleRows or {}) do
		local module = modules[first + index - 1]
		if module then
			row.moduleId = module.id
			row.label:SetText(module.label)
			row.status:SetText(moduleHumanStatus(module))
			Theme.texts[row.status] = moduleStatusColor(module)
			local r, g, b, a = Theme:GetColor(Theme.texts[row.status])
			row.status:SetTextColor(r, g, b, a)
			local active = module.id == self.selectedModuleId
			setChoiceStyle(row, active)
			row:Show()
		else
			row.moduleId = nil
			row:Hide()
		end
	end

	for id, button in pairs(self.moduleFilterButtons or {}) do
		local active = id == self.moduleFilter
		setTabStyle(button, active)
	end
	if self.moduleListTitle then
		self.moduleListTitle:SetText(self.moduleFilter == "legacy" and "LEGACY COMPATIBILITY" or "CHAT FEATURES")
	end
	if self.moduleListCount then
		self.moduleListCount:SetText(#modules == 0 and "NO MODULES" or (tostring(first) .. "-" .. tostring(math.min(#modules, first + MODULE_ROWS_PER_PAGE - 1)) .. " / " .. tostring(#modules)))
	end
	if self.moduleListPrevious then
		if pageCount > 1 and self.moduleListPage > 1 then self.moduleListPrevious:Show() else self.moduleListPrevious:Hide() end
	end
	if self.moduleListNext then
		if pageCount > 1 and self.moduleListPage < pageCount then self.moduleListNext:Show() else self.moduleListNext:Hide() end
	end
	if self.moduleListPrevious and self.moduleListNext and self.moduleListPanel then
		self.moduleListPrevious:ClearAllPoints()
		self.moduleListNext:ClearAllPoints()
		if self.moduleListNext:IsShown() then
			self.moduleListNext:SetPoint("BOTTOMRIGHT", self.moduleListPanel, "BOTTOMRIGHT", -8, 6)
			if self.moduleListPrevious:IsShown() then
				self.moduleListPrevious:SetPoint("RIGHT", self.moduleListNext, "LEFT", -CONTROL_GAP, 0)
			end
		elseif self.moduleListPrevious:IsShown() then
			self.moduleListPrevious:SetPoint("BOTTOMRIGHT", self.moduleListPanel, "BOTTOMRIGHT", -8, 6)
		end
	end

	if not selected then
		self.moduleInspectorTitle:SetText("No module available")
		self.moduleInspectorStatus:SetText("")
		self.moduleInspectorSummary:SetText("Module compatibility data is unavailable until the addon finishes loading.")
		self.modulePreferenceToggle:Hide()
		if self.moduleSmartToggle then self.moduleSmartToggle:Hide() end
		self.moduleOpenConfig:Hide()
		self.moduleNativeNote:SetText("")
		return
	end

	self.moduleInspectorTitle:SetText(selected.label)
	self.moduleInspectorStatus:SetText(moduleHumanStatus(selected))
	Theme.texts[self.moduleInspectorStatus] = moduleStatusColor(selected)
	local r, g, b, a = Theme:GetColor(Theme.texts[self.moduleInspectorStatus])
	self.moduleInspectorStatus:SetTextColor(r, g, b, a)
	self.moduleInspectorSummary:SetText(selected.summary or "")

	if selected.status == "smart" then
		self.modulePreferenceToggle:Hide()
		local hasSmartToggle = false
		if selected.smartSetting == "composerAutoHide" and addon.SetComposerAutoHide then
			hasSmartToggle = true
			self.moduleSmartToggle.label:SetText("AUTO-HIDE WHEN IDLE")
			local enabled = addon.GetComposerAutoHideSetting and addon:GetComposerAutoHideSetting()
			self.moduleSmartToggle:SetValue(enabled and true or false, true)
			self.moduleSmartToggle:Show()
		elseif selected.smartSetting == "editBoxBorder" and addon.SetEditBoxBorderEnabled then
			hasSmartToggle = true
			self.moduleSmartToggle.label:SetText("TYPING FIELD BORDER")
			local enabled = addon.GetEditBoxBorderSetting and addon:GetEditBoxBorderSetting()
			self.moduleSmartToggle:SetValue(enabled == true, true)
			self.moduleSmartToggle:Show()
		elseif selected.smartSetting == "tellTargetEnabled" and addon.SetTellTargetEnabled then
			hasSmartToggle = true
			self.moduleSmartToggle.label:SetText("ENABLE /TT TELL TARGET")
			local tellTarget = addon.GetTellTargetSettings and addon:GetTellTargetSettings()
			self.moduleSmartToggle:SetValue(not tellTarget or tellTarget.enabled ~= false, true)
			self.moduleSmartToggle:Show()
		else
			self.moduleSmartToggle:Hide()
		end
		local destination = selected.configPage == "views" and "VIEWS & TABS"
			or ((selected.configPage == "conversations" or selected.configPage == "messenger") and "MESSENGER" or "CHAT WINDOW")
		setTightButtonLabel(self.moduleOpenConfig, "OPEN " .. destination)
		self.moduleOpenConfig:ClearAllPoints()
		self.moduleOpenConfig:SetPoint("TOPLEFT", self.moduleInspectorPanel, "TOPLEFT", 8, hasSmartToggle and -154 or -126)
		self.moduleOpenConfig:Show()
		if selected.smartSetting == "composerAutoHide" then
			self.moduleNativeNote:SetText("Idle only: Enter, /, or reply temporarily reveals the composer, and the message surface uses its space when it closes.")
		elseif selected.smartSetting == "editBoxBorder" then
			self.moduleNativeNote:SetText("Adds a background and border only behind the typing field. SAY, send, and the shared chat route stay clean; old native Edit Box Polish hooks remain off.")
		elseif selected.smartSetting == "tellTargetEnabled" then
			self.moduleNativeNote:SetText("/tt opens your current player target in Messenger. Text after /tt sends once, then the same reply field stays ready when shortcut focus is enabled.")
		else
			self.moduleNativeNote:SetText("This feature runs directly in Chatty. Its copied fallback code stays dormant so it cannot alter hidden chat frames.")
		end
	elseif selected.status == "native" or selected.status == "adapter" then
		self.moduleSmartToggle:Hide()
		self.modulePreferenceToggle.label:SetText("KEEP ENABLED FOR NATIVE FALLBACK")
		self.modulePreferenceToggle:SetValue(selected.preferenceEnabled ~= false, true)
		self.modulePreferenceToggle:Show()
		self.moduleOpenConfig:Hide()
		local note = "This copied feature stays dormant while Chatty owns chat. The saved choice applies only after Chatty is disabled and native fallback takes over."
		if selected.status == "adapter" then
			note = "This feature has not been rebuilt for Chatty yet. Its saved choice applies only to native fallback and never enables the copied hook while Chatty owns chat."
		end
		self.moduleNativeNote:SetText(note)
	end
	if not keepStatus then
		self:SetModuleStatus("")
	end
end

function Config:BuildModulesPage()
	local page = self:CreatePage("modules")
	self.modulesPage = page
	createHeading(page, "Modules", "See which familiar chat features work here and which are kept only for native-chat fallback.")

	self.moduleOverview = Theme:CreateText(page, "GameFontHighlightSmall", "textMuted")
	self.moduleOverview:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -PAGE_TOP)
	self.moduleOverview:SetWidth(PAGE_WIDTH)
	self.moduleOverview:SetJustifyH("LEFT")

	local filters = {
		{
			id = "features",
			label = "CHAT FEATURES",
			tooltip = "Features implemented on Chatty's own chat surface.",
		},
		{
			id = "legacy",
			label = "LEGACY COMPATIBILITY",
			tooltip = "Older Chatter features kept for native-chat fallback, including features not yet rebuilt for Chatty.",
		},
	}
	self.moduleFilterButtons = {}
	local previous
	for _, filter in ipairs(filters) do
		local button = Theme:CreateTightButton(page, filter.label, 20, false)
		setActionStyle(button, "choice", filter.label, filter.tooltip)
		if previous then
			button:SetPoint("LEFT", previous, "RIGHT", CONTROL_GAP, 0)
		else
			button:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -68)
		end
		button:SetScript("OnClick", function()
			Config.moduleFilter = filter.id
			Config.moduleListPage = 1
			Config:RefreshModulesPage(true)
		end)
		self.moduleFilterButtons[filter.id] = button
		previous = button
	end

	local list = createQuietShellPanel(page, "inset")
	list:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -94)
	list:SetSize(248, 356)
	self.moduleListPanel = list
	local listTitle = Theme:CreateText(list, "GameFontNormalSmall", "gold")
	listTitle:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -7)
	listTitle:SetText("CHAT FEATURES")
	self.moduleListTitle = listTitle
	self.moduleRows = {}
	for index = 1, MODULE_ROWS_PER_PAGE do
		local row = Theme:CreateButton(list, "", 232, 29, false)
		row:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -25 - ((index - 1) * 30))
		row.label = row.text
		row.label:ClearAllPoints()
		row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 5, -2)
		row.label:SetPoint("TOPRIGHT", row, "TOPRIGHT", -5, -2)
		row.label:SetJustifyH("LEFT")
		if row.label.SetWordWrap then row.label:SetWordWrap(false) end
		row.status = Theme:CreateText(row, "GameFontHighlightSmall", "textMuted")
		row.status:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 5, 2)
		row.status:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -5, 2)
		row.status:SetJustifyH("LEFT")
		if row.status.SetWordWrap then row.status:SetWordWrap(false) end
		row:SetScript("OnClick", function(self)
			if self.moduleId then Config:SelectModule(self.moduleId) end
		end)
		self.moduleRows[index] = row
	end
	self.moduleListCount = Theme:CreateText(list, "GameFontHighlightSmall", "textMuted")
	self.moduleListCount:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 8, 8)
	self.moduleListPrevious = Theme:CreateTightButton(list, "<", 18, false)
	self.moduleListPrevious:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -30, 6)
	self.moduleListPrevious:SetScript("OnClick", function()
		Config.moduleListPage = math.max(1, (Config.moduleListPage or 1) - 1)
		Config:RefreshModulesPage(true)
	end)
	self.moduleListNext = Theme:CreateTightButton(list, ">", 18, false)
	self.moduleListNext:SetPoint("LEFT", self.moduleListPrevious, "RIGHT", CONTROL_GAP, 0)
	self.moduleListNext:SetScript("OnClick", function()
		Config.moduleListPage = (Config.moduleListPage or 1) + 1
		Config:RefreshModulesPage(true)
	end)

	local inspector = createQuietShellPanel(page, "surface")
	inspector:SetPoint("TOPLEFT", page, "TOPLEFT", 274, -94)
	inspector:SetSize(362, 356)
	self.moduleInspectorPanel = inspector
	self.moduleInspectorTitle = Theme:CreateText(inspector, "GameFontNormalLarge", "goldBright")
	self.moduleInspectorTitle:SetPoint("TOPLEFT", inspector, "TOPLEFT", 8, -8)
	self.moduleInspectorTitle:SetWidth(346)
	self.moduleInspectorTitle:SetJustifyH("LEFT")
	self.moduleInspectorStatus = Theme:CreateText(inspector, "GameFontNormalSmall", "textMuted")
	self.moduleInspectorStatus:SetPoint("TOPLEFT", inspector, "TOPLEFT", 8, -31)
	self.moduleInspectorStatus:SetWidth(346)
	self.moduleInspectorStatus:SetJustifyH("LEFT")
	self.moduleInspectorSummary = Theme:CreateText(inspector, "GameFontHighlightSmall", "text")
	self.moduleInspectorSummary:SetPoint("TOPLEFT", inspector, "TOPLEFT", 8, -54)
	self.moduleInspectorSummary:SetSize(346, 58)
	self.moduleInspectorSummary:SetJustifyH("LEFT")

	self.modulePreferenceToggle = Theme:CreateCompactToggle(inspector, "KEEP ENABLED FOR NATIVE FALLBACK", 330)
	self.modulePreferenceToggle:SetPoint("TOPLEFT", inspector, "TOPLEFT", 8, -126)
	self.modulePreferenceToggle.OnValueChanged = function(_, value)
		local module = addon.GetModuleCatalogStatus and addon:GetModuleCatalogStatus(Config.selectedModuleId)
		if not module or not addon.SetModuleCatalogPreference then
			Config:SetModuleStatus("Legacy fallback preferences are unavailable.", "warning")
			Config:RefreshModulesPage(true)
			return
		end
		local saved = addon:SetModuleCatalogPreference(module.id, value)
		Config:SetModuleStatus(saved and "Native fallback preference saved. Chatty did not enable copied fallback code." or "Could not save that feature preference.", saved and "success" or "warning")
		Config:RefreshModulesPage(true)
	end
	setControlTooltip(self.modulePreferenceToggle, "Native fallback preference", "This saved choice is used only after Chatty is disabled and native chat takes over.")
	self.moduleSmartToggle = Theme:CreateCompactToggle(inspector, "AUTO-HIDE WHEN IDLE", 330)
	self.moduleSmartToggle:SetPoint("TOPLEFT", inspector, "TOPLEFT", 8, -126)
	self.moduleSmartToggle.OnValueChanged = function(_, value)
		local module = addon.GetModuleCatalogStatus and addon:GetModuleCatalogStatus(Config.selectedModuleId)
		if not module then
			Config:SetModuleStatus("That Chatty feature is unavailable.", "warning")
			Config:RefreshModulesPage(true)
			return
		end
		if module.smartSetting == "composerAutoHide" and addon.SetComposerAutoHide then
			addon:SetComposerAutoHide(value)
			Config:SetModuleStatus(value
				and "Idle composer auto-hide enabled. Enter, /, or reply reveals it."
				or "Idle composer auto-hide disabled; the composer stays visible.", "success")
		elseif module.smartSetting == "editBoxBorder" and addon.SetEditBoxBorderEnabled then
			addon:SetEditBoxBorderEnabled(value)
			Config:SetModuleStatus(value
				and "Typing-field background and border shown."
				or "Typing field returned to the clean integrated surface.", "success")
		elseif module.smartSetting == "tellTargetEnabled" and addon.SetTellTargetEnabled then
			addon:SetTellTargetEnabled(value)
			Config:SetModuleStatus(value
				and "/tt Tell Target enabled for Messenger."
				or "/tt Tell Target disabled; native fallback remains unchanged.", "success")
		else
			Config:SetModuleStatus("That Chatty feature is unavailable.", "warning")
			Config:RefreshModulesPage(true)
			return
		end
		if module.smartSetting == "tellTargetEnabled" then
			Config:RefreshMessengerPage()
		else
			Config:RefreshDockPage()
		end
		Config:RefreshModulesPage(true)
	end
	setControlTooltip(self.moduleSmartToggle, "Feature setting", "Changes this feature directly on Chatty's own chat surface.")
	self.moduleSmartToggle:Hide()

	self.moduleOpenConfig = Theme:CreateTightButton(inspector, "OPEN CHAT WINDOW", 22, true)
	setActionStyle(self.moduleOpenConfig, "primary", "Open this feature's settings", "Takes you directly to the page that owns this Chatty feature.")
	self.moduleOpenConfig:SetPoint("TOPLEFT", inspector, "TOPLEFT", 8, -126)
	self.moduleOpenConfig:SetScript("OnClick", function()
		local module = addon.GetModuleCatalogStatus and addon:GetModuleCatalogStatus(Config.selectedModuleId)
		if module and module.configPage then
			Config:ShowPage(module.configPage)
			if module.configSection and Config.activePage == "messenger" then
				Config:SetMessengerSection(module.configSection)
			end
		end
	end)
	self.moduleNativeNote = Theme:CreateText(inspector, "GameFontHighlightSmall", "textMuted")
	self.moduleNativeNote:SetPoint("TOPLEFT", inspector, "TOPLEFT", 8, -190)
	self.moduleNativeNote:SetSize(346, 76)
	self.moduleNativeNote:SetJustifyH("LEFT")
	self.modulesStatus = Theme:CreateText(inspector, "GameFontHighlightSmall", "textMuted")
	self.modulesStatus:SetPoint("TOPLEFT", inspector, "TOPLEFT", 8, -286)
	self.modulesStatus:SetSize(346, 54)
	self.modulesStatus:SetJustifyH("LEFT")

	self.moduleFilter = normalizeModuleFilter(self.moduleFilter)
	local catalog = getModuleCatalog()
	local filtered = self:GetFilteredModules()
	self.selectedModuleId = self.selectedModuleId or (filtered[1] and filtered[1].id) or (catalog[1] and catalog[1].id)
	self:RefreshModulesPage()
	return page
end

function Config:RefreshSafetyPage()
	if not self.playerActionAutoHideToggle then
		return
	end
	local settings
	if type(addon.GetPlayerActionMenuSettings) == "function" then
		local ok, result = pcall(addon.GetPlayerActionMenuSettings, addon)
		if ok and type(result) == "table" then
			settings = result
		end
	end
	if not settings then
		local smart = addon:GetSmartSettings()
		local stored = smart.dock and smart.dock.playerActions or {}
		settings = {
			autoHide = stored.autoHide ~= false,
			autoHideSeconds = math.max(1, math.min(120, math.floor(tonumber(stored.autoHideSeconds) or 10))),
		}
	end
	self.playerActionAutoHideToggle:SetValue(settings.autoHide ~= false, true)
	self.playerActionAutoHideSecondsEdit:SetText(tostring(settings.autoHideSeconds or 10))
	if self.safetyConfirmIgnoreToggle then
		local smart = addon:GetSmartSettings()
		self.safetyConfirmIgnoreToggle:SetValue(smart.safety.confirmServerIgnore ~= false, true)
	end
end

function Config:BuildSafetyPage()
	local page = self:CreatePage("safety")
	createHeading(page, "Player Actions", "Control the menu opened from a player name and confirm server-side ignore actions.")

	local playerPanel = CreateFrame("Frame", nil, page)
	playerPanel:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -PAGE_TOP)
	playerPanel:SetSize(PAGE_WIDTH, 102)
	local playerTitle = Theme:CreateText(playerPanel, "GameFontNormal", "gold")
	playerTitle:SetPoint("TOPLEFT", playerPanel, "TOPLEFT", 0, 0)
	playerTitle:SetText("PLAYER ACTION MENU")
	local playerDetail = Theme:CreateText(playerPanel, "GameFontHighlightSmall", "textMuted")
	playerDetail:SetPoint("TOPLEFT", playerTitle, "BOTTOMLEFT", 0, -2)
	playerDetail:SetWidth(PAGE_WIDTH)
	playerDetail:SetJustifyH("LEFT")
	playerDetail:SetText("Clicking outside always closes this menu. Auto-hide is an extra timeout when no action is chosen.")

	self.playerActionAutoHideToggle = Theme:CreateCompactToggle(playerPanel, "AUTO-HIDE PLAYER ACTIONS", 264)
	self.playerActionAutoHideToggle:SetPoint("TOPLEFT", playerPanel, "TOPLEFT", 0, -46)
	self.playerActionAutoHideToggle.OnValueChanged = function(_, value)
		if type(addon.SetPlayerActionMenuAutoHideEnabled) == "function" then
			addon:SetPlayerActionMenuAutoHideEnabled(value)
		else
			local dock = addon:GetSmartSettings().dock
			dock.playerActions = dock.playerActions or {}
			dock.playerActions.autoHide = value and true or false
		end
		Config:RefreshSafetyPage()
	end
	setControlTooltip(self.playerActionAutoHideToggle, "Automatic player-action hide", "When enabled, the player-action menu closes after the configured 1 to 120 second delay. Clicking outside still closes it immediately.")

	local secondsLabel = Theme:CreateText(playerPanel, "GameFontHighlightSmall", "textMuted")
	secondsLabel:SetPoint("TOPLEFT", playerPanel, "TOPLEFT", 286, -32)
	secondsLabel:SetText("SECONDS")
	self.playerActionAutoHideSecondsEdit = Theme:CreateEditBox(playerPanel, 58, 22, false)
	self.playerActionAutoHideSecondsEdit:SetPoint("TOPLEFT", playerPanel, "TOPLEFT", 286, -48)
	setControlTooltip(self.playerActionAutoHideSecondsEdit, "Player-action timeout", "Enter 1 to 120 seconds. The default is 10 seconds.")
	local function commitPlayerActionSeconds()
		local seconds = tonumber(Config.playerActionAutoHideSecondsEdit:GetText())
		if not seconds or seconds < 1 or seconds > 120 then
			Config:RefreshSafetyPage()
			return
		end
		seconds = math.floor(seconds + 0.5)
		if type(addon.SetPlayerActionMenuAutoHideSeconds) == "function" then
			addon:SetPlayerActionMenuAutoHideSeconds(seconds)
		else
			local dock = addon:GetSmartSettings().dock
			dock.playerActions = dock.playerActions or {}
			dock.playerActions.autoHideSeconds = seconds
		end
		Config:RefreshSafetyPage()
	end
	self.playerActionAutoHideSecondsEdit:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	self.playerActionAutoHideSecondsEdit:HookScript("OnEditFocusLost", commitPlayerActionSeconds)

	local ignore = Theme:CreateToggle(page, "Confirm before adding a player to WoW Ignore", "Require confirmation before changing the server ignore list.")
	ignore:SetPoint("TOPLEFT", playerPanel, "BOTTOMLEFT", 0, -8)
	ignore:SetWidth(PAGE_WIDTH)
	self.safetyConfirmIgnoreToggle = ignore
	ignore.OnValueChanged = function(_, value)
		addon:GetSmartSettings().safety.confirmServerIgnore = value and true or false
	end

	local panel = CreateFrame("Frame", nil, page)
	panel:SetPoint("TOPLEFT", ignore, "BOTTOMLEFT", 0, -5)
	panel:SetSize(PAGE_WIDTH, 60)
	local title = Theme:CreateText(panel, "GameFontNormal", "gold")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	title:SetText("ACTION SCOPE")
	local text = Theme:CreateText(panel, "GameFontHighlightSmall", "textMuted")
	text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
	text:SetWidth(600)
	text:SetJustifyH("LEFT")
	text:SetText("CHATTY MUTE affects this addon only. WOW IGNORE changes WoW's list.\nWHISPER, INVITE, and ADD FRIEND run only when clicked.")
	self:RefreshSafetyPage()
	return page
end

function Config:SetIntegrationsStatus(text, colorName)
	if not self.integrationsStatus then
		return
	end
	colorName = colorName or "textMuted"
	self.integrationsStatus:SetText(text or "")
	Theme.texts[self.integrationsStatus] = colorName
	local r, g, b, a = Theme:GetColor(colorName)
	self.integrationsStatus:SetTextColor(r, g, b, a)
end

function Config:RefreshIntegrationsPage()
	if not self.integrationsPage then
		return
	end

	local settings = addon:GetSmartSettings()
	if self.integrationsMinimapToggle and settings.launcher and settings.launcher.minimap then
		self.integrationsMinimapToggle:SetValue(not settings.launcher.minimap.hide, true)
	end

	local commandOutput
	if type(addon.GetLocalCommandOutputSettings) == "function" then
		local ok, result = pcall(addon.GetLocalCommandOutputSettings, addon)
		if ok and type(result) == "table" then
			commandOutput = result
		end
	end
	commandOutput = commandOutput or settings.localCommandOutput or {}
	local enabled = commandOutput.enabled ~= false
	local destination = commandOutput.destination == "active" and "active" or "system"
	if self.localCommandOutputToggle then
		self.localCommandOutputToggle:SetValue(enabled, true)
	end
	if self.localCommandOutputSystemButton then
		setChoiceStyle(self.localCommandOutputSystemButton, destination == "system")
	end
	if self.localCommandOutputActiveButton then
		setChoiceStyle(self.localCommandOutputActiveButton, destination == "active")
	end

	if not enabled then
		self:SetIntegrationsStatus(
			"Capture is off. Blizzard still prints normally, but hidden native chat may make that output invisible.",
			"warning")
	elseif destination == "active" then
		self:SetIntegrationsStatus(
			"The selected Chatty tab is the primary route; SYNC falls back to SYSTEM. CONTENTS can still mirror this source.",
			"textMuted")
	else
		self:SetIntegrationsStatus(
			"SYSTEM is the primary route. VIEWS & TABS > CONTENTS can also mirror Local add-on feedback.",
			"textMuted")
	end
end

function Config:BuildIntegrationsPage()
	local page = self:CreatePage("integrations")
	self.integrationsPage = page
	createHeading(page, "Chat Access", "Choose launchers and where local command output appears.")

	local minimap = Theme:CreateToggle(page, "Show minimap launcher", "Left toggles the dock; right opens settings; middle-click hides it.")
	minimap:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -PAGE_TOP)
	minimap:SetWidth(PAGE_WIDTH)
	self.integrationsMinimapToggle = minimap
	minimap.OnValueChanged = function(_, value)
		addon:SetMinimapHidden(not value)
		Config:RefreshIntegrationsPage()
	end

	local ldb = CreateFrame("Frame", nil, page)
	ldb:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", 0, -5)
	ldb:SetSize(PAGE_WIDTH, 42)
	self.integrationsLdbPanel = ldb
	local title = Theme:CreateText(ldb, "GameFontNormalSmall", "gold")
	title:SetPoint("TOPLEFT", ldb, "TOPLEFT", 0, 0)
	title:SetText("LDB LAUNCHER")
	local detail = Theme:CreateText(ldb, "GameFontHighlightSmall", "textMuted")
	detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
	detail:SetWidth(600)
	detail:SetJustifyH("LEFT")
	detail:SetText("Any LDB display can expose the same left, right, and middle-click controls.")

	-- Diagnostic command output is deliberately isolated in one quiet surface:
	-- the controls configure only /run, /script, and /dump, never the broad
	-- DEFAULT_CHAT_FRAME:AddMessage stream. Every child retains an eight-pixel
	-- gutter from the panel edge, with destination buttons on their own row so
	-- wider fonts cannot collide with the capture toggle.
	local commandPanel = createQuietShellPanel(page, "surface")
	commandPanel:SetPoint("TOPLEFT", ldb, "BOTTOMLEFT", 0, -10)
	commandPanel:SetSize(PAGE_WIDTH, 150)
	self.localCommandOutputPanel = commandPanel

	local commandTitle = Theme:CreateText(commandPanel, "GameFontNormalSmall", "gold")
	commandTitle:SetPoint("TOPLEFT", commandPanel, "TOPLEFT", 8, -7)
	commandTitle:SetText("LOCAL COMMAND OUTPUT")
	self.localCommandOutputTitle = commandTitle

	local commandDetail = Theme:CreateText(commandPanel, "GameFontHighlightSmall", "textMuted")
	commandDetail:SetPoint("TOPLEFT", commandPanel, "TOPLEFT", 8, -25)
	commandDetail:SetSize(PAGE_WIDTH - 16, 24)
	commandDetail:SetJustifyH("LEFT")
	commandDetail:SetText("Catch text printed by /run, /script, and /dump without intercepting ordinary chat or other add-ons.")
	self.localCommandOutputDetail = commandDetail

	local capture = Theme:CreateCompactToggle(commandPanel, "CAPTURE /RUN + /DUMP OUTPUT", PAGE_WIDTH - 16)
	capture:SetPoint("TOPLEFT", commandPanel, "TOPLEFT", 8, -57)
	capture.OnValueChanged = function(_, value)
		if type(addon.SetLocalCommandOutputCaptureEnabled) ~= "function" then
			Config:RefreshIntegrationsPage()
			Config:SetIntegrationsStatus("Local command capture is unavailable in this build.", "warning")
			return
		end
		local ok, accepted = pcall(addon.SetLocalCommandOutputCaptureEnabled, addon, value and true or false)
		if not ok or accepted == false then
			Config:RefreshIntegrationsPage()
			Config:SetIntegrationsStatus("Local command capture could not be changed.", "warning")
			return
		end
		Config:RefreshIntegrationsPage()
	end
	setControlTooltip(capture, "Capture local command output",
		"Copies only text printed while /run, /script, or /dump is executing. Ordinary chat-frame output is never captured by this setting.")
	self.localCommandOutputToggle = capture

	local destinationLabel = Theme:CreateText(commandPanel, "GameFontHighlightSmall", "textMuted")
	destinationLabel:SetPoint("TOPLEFT", commandPanel, "TOPLEFT", 8, -88)
	destinationLabel:SetWidth(96)
	destinationLabel:SetJustifyH("LEFT")
	destinationLabel:SetText("PRIMARY TAB")
	self.localCommandOutputDestinationLabel = destinationLabel

	local systemButton = Theme:CreateTightButton(commandPanel, "SYSTEM (SYS)", 20, false)
	systemButton:SetPoint("TOPLEFT", commandPanel, "TOPLEFT", 112, -84)
	setActionStyle(systemButton, "choice", "Route command output to System",
		"Uses SYSTEM as the primary message route. Any additional CONTENTS selections remain additive.")
	self.localCommandOutputSystemButton = systemButton

	local activeButton = Theme:CreateTightButton(commandPanel, "ACTIVE TAB", 20, false)
	activeButton:SetPoint("LEFT", systemButton, "RIGHT", CONTROL_GAP, 0)
	setActionStyle(activeButton, "choice", "Route command output to the active tab",
		"Uses the selected Chatty tab when the command runs. SYNC safely falls back to SYSTEM.")
	self.localCommandOutputActiveButton = activeButton

	local function chooseDestination(destination)
		if type(addon.SetLocalCommandOutputDestination) ~= "function" then
			Config:SetIntegrationsStatus("Local command routing is unavailable in this build.", "warning")
			return
		end
		local ok, accepted = pcall(addon.SetLocalCommandOutputDestination, addon, destination)
		if not ok or accepted == false then
			Config:RefreshIntegrationsPage()
			Config:SetIntegrationsStatus("Local command routing could not be changed.", "warning")
			return
		end
		Config:RefreshIntegrationsPage()
	end
	systemButton:SetScript("OnClick", function() chooseDestination("system") end)
	activeButton:SetScript("OnClick", function() chooseDestination("active") end)

	self.integrationsStatus = Theme:CreateText(commandPanel, "GameFontHighlightSmall", "textMuted")
	self.integrationsStatus:SetPoint("TOPLEFT", commandPanel, "TOPLEFT", 8, -114)
	self.integrationsStatus:SetSize(PAGE_WIDTH - 16, 28)
	self.integrationsStatus:SetJustifyH("LEFT")
	if self.integrationsStatus.SetJustifyV then self.integrationsStatus:SetJustifyV("TOP") end

	self:RefreshIntegrationsPage()
	return page
end

function Config:BuildAboutPage()
	local page = self:CreatePage("about")
	createHeading(page, "About", "What this Chatty build does and which client behavior it preserves.")

	local lines = {
		"- Organizes each received message once, then shares it with the tabs that need it.",
		"- Keeps a bounded recent history instead of growing SavedVariables forever.",
		"- Uses explainable routes for Group Finder, Trade, system notices, blocks, and spam.",
		"- Uses Chatty's own frames, themes, and compact controls.",
		"- Preserves Ascension-era social actions, launchers, and native-chat fallback.",
	}

	local panel = CreateFrame("Frame", nil, page)
	panel:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_GUTTER, -PAGE_TOP)
	panel:SetSize(PAGE_WIDTH, 104)
	local y = -2
	for index = 1, #lines do
		local line = Theme:CreateText(panel, "GameFontHighlightSmall", "text")
		line:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
		line:SetWidth(PAGE_WIDTH)
		line:SetJustifyH("LEFT")
		line:SetText(lines[index])
		y = y - 20
	end
	return page
end

local builders = {
	home = Config.BuildHomePage,
	dock = Config.BuildDockPage,
	views = Config.BuildViewsPage,
	modules = Config.BuildModulesPage,
	-- `rails` remains an accepted external page id below, but it deliberately
	-- resolves to the single Message Views workspace instead of creating a
	-- second configuration surface.
	rails = Config.BuildRailsPage,
	spam = Config.BuildSpamPage,
	blocks = Config.BuildBlocksPage,
	semantic = Config.BuildSemanticRoutesPage,
	alerts = Config.BuildAlertsPage,
	messenger = Config.BuildMessengerPage,
	colorways = Config.BuildColorwaysPage,
	keywords = Config.BuildKeywordColorsPage,
	safety = Config.BuildSafetyPage,
	integrations = Config.BuildIntegrationsPage,
	about = Config.BuildAboutPage,
}

function Config:ShowPage(id)
	-- Retain the old internal page key for any external opener created before
	-- Messenger was given its own dedicated configuration section.
	if id == "conversations" then
		id = "messenger"
	elseif id == "rails" or id == "organized" or id == "organizedViews" then
		id = "views"
	end
	-- Both overlays are parented to the root settings frame so they can sit over
	-- their page content. Close them explicitly when their owning page is left;
	-- hiding only the page frame would otherwise let an old overlay resurface.
	if id ~= "views" then
		self:HideSmartChatTextFontPicker()
	end
	if id ~= "spam" then
		self:HideSpamBanReport()
	end
	for _, page in pairs(self.pages) do
		page:Hide()
	end
	if not self.pages[id] then
		builders[id](self)
	end
	self.activePage = id
	self.pages[id]:Show()
	self:RefreshNavigation()
	if id == "home" then
		self:RefreshHomeState()
	elseif id == "dock" then
		self:RefreshDockPage()
	elseif id == "views" then
		self:RefreshMessageViewsPage()
	elseif id == "modules" then
		self:RefreshModulesPage()
	elseif id == "spam" then
		self:RefreshSpamStatus()
		if self.spamSection == "bans" then
			self:RefreshSpamBans(true)
		end
	elseif id == "blocks" then
		self:RefreshBlocksPage()
	elseif id == "semantic" then
		self:RefreshSemanticRoutesPage()
	elseif id == "alerts" then
		self:RefreshAlertsPage()
	elseif id == "messenger" then
		self:RefreshMessengerPage()
	elseif id == "safety" then
		self:RefreshSafetyPage()
	elseif id == "integrations" then
		self:RefreshIntegrationsPage()
	elseif id == "colorways" then
		self:RefreshColorwayCards()
	elseif id == "keywords" then
		self:RefreshKeywordColorsPage()
	end
end

function Config:ShowConflictDialog(conflicts)
	if not conflicts or #conflicts == 0 then
		if self.conflictFrame then
			self.conflictFrame:Hide()
		end
		return
	end

	if not self.conflictFrame then
		local dialog = Theme:CreatePanel(self.frame, "background", "gold")
		dialog:SetSize(560, 402)
		dialog:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
		dialog:SetFrameStrata("FULLSCREEN_DIALOG")
		dialog:EnableMouse(true)
		dialog.rows = {}
		self.conflictFrame = dialog

		local title = Theme:CreateText(dialog, "GameFontNormalLarge", "goldBright")
		title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 14, -13)
		title:SetText("Choose your active chat system")
		local description = Theme:CreateText(dialog, "GameFontHighlightSmall", "textMuted")
		description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
		description:SetWidth(532)
		description:SetJustifyH("LEFT")
		description:SetText("Select conflicting chat addons to disable, then reload.")

		local cancel = Theme:CreateButton(dialog, "KEEP CURRENT", 132, 26, false)
		cancel:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 14, 14)
		cancel:SetScript("OnClick", function()
			dialog:Hide()
			addon:SetSmartChatEnabled(false)
			Config:RefreshHomeState()
		end)

		local confirm = Theme:CreateButton(dialog, "DISABLE + RELOAD", 158, 26, true)
		confirm:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -14, 14)
		confirm:SetScript("OnClick", function()
			local selected = {}
			for addonName, enabled in pairs(dialog.selections or {}) do
				if enabled then
					table.insert(selected, addonName)
				end
			end
			if #selected > 0 then
				addon:GetSmartSettings().enabled = true
				addon.Compatibility:DisableAddonsAndReload(selected)
			else
				dialog:Hide()
				addon:SetSmartChatEnabled(false)
				Config:RefreshHomeState()
			end
		end)
	end

	local dialog = self.conflictFrame
	local columnCount = #conflicts > 10 and 2 or 1
	local rowsPerColumn = math.ceil(#conflicts / columnCount)
	dialog:SetHeight(math.min(540, 150 + (rowsPerColumn * 42)))
	for index = 1, #dialog.rows do
		dialog.rows[index]:Hide()
	end
	dialog.selections = {}
	for index = 1, #conflicts do
		local conflict = conflicts[index]
		local row = dialog.rows[index]
		if not row then
			row = Theme:CreateToggle(dialog, conflict.title, conflict.name)
			row.OnValueChanged = function(self, value)
				if self.addonName then
					dialog.selections[self.addonName] = value
				end
			end
			dialog.rows[index] = row
		end
		row.addonName = conflict.name
		row.label:SetText(conflict.title)
		row.description:SetText(conflict.name)
		row:ClearAllPoints()
		local column = math.floor((index - 1) / rowsPerColumn)
		local columnRow = (index - 1) % rowsPerColumn
		row:SetWidth(columnCount == 2 and 260 or 532)
		row:SetPoint("TOPLEFT", dialog, "TOPLEFT", 14 + (column * 272), -72 - (columnRow * 42))
		row:SetValue(true, true)
		row:Show()
		dialog.selections[conflict.name] = true
	end
	dialog:Show()
end

function Config:ReloadProfile()
	if not self.frame then
		return
	end
	if self.dockMarkerPreviewActive then
		if type(addon.SetNewMessageIndicatorPreviewActive) == "function" then
			callMarkerAppearanceAPI("SetNewMessageIndicatorPreviewActive", false)
		elseif addon.SmartDock and type(addon.SmartDock.SetNewMessageIndicatorPreview) == "function" then
			pcall(addon.SmartDock.SetNewMessageIndicatorPreview, addon.SmartDock, false)
		end
	end
	self.dockMarkerPreviewActive = false
	if self.conflictFrame then
		self.conflictFrame:Hide()
	end
	self:HideSpamBanReport()
	self:HideSmartChatTextFontPicker()
	for _, page in pairs(self.pages) do
		page:Hide()
	end
	self.pages = {}
	self.smartToggle = nil
	self.minimapToggle = nil
	self.homeStatus = nil
	self.integrationsPage = nil
	self.integrationsMinimapToggle = nil
	self.integrationsLdbPanel = nil
	self.localCommandOutputPanel = nil
	self.localCommandOutputTitle = nil
	self.localCommandOutputDetail = nil
	self.localCommandOutputToggle = nil
	self.localCommandOutputDestinationLabel = nil
	self.localCommandOutputSystemButton = nil
	self.localCommandOutputActiveButton = nil
	self.integrationsStatus = nil
	self.dockPage = nil
	self.dockHeadingSubtitle = nil
	self.dockLayoutTabButton = nil
	self.dockColorsTabButton = nil
	self.dockColorsPanel = nil
	self.dockChatColorRows = nil
	self.dockChatColorCount = nil
	self.dockChatColorPrevious = nil
	self.dockChatColorNext = nil
	self.dockChatColorEmpty = nil
	self.dockChatColorSelectedTitle = nil
	self.dockChatColorSelectedDetail = nil
	self.dockChatColorPreview = nil
	self.dockChatColorEdits = nil
	self.dockChatColorApplyButton = nil
	self.dockColorsStatus = nil
	self.dockChatColorPage = nil
	self.selectedDockChatColorId = nil
	self.dockSection = nil
	self.dockLayoutCategory = nil
	self.dockLayoutNavigationControls = nil
	self.dockLayoutCategoryButtons = nil
	self.dockLayoutSectionTitle = nil
	self.dockLayoutSectionHint = nil
	self.dockLayoutGroups = nil
	self.dockVisibleToggle = nil
	self.dockCollapsedToggle = nil
	self.dockHideSocialToggle = nil
	self.dockComposerAutoHideToggle = nil
	self.dockEditBoxBorderToggle = nil
	self.dockScrollToggle = nil
	self.dockCompactTitleToggle = nil
	self.dockTagsToggle = nil
	self.dockBackgroundAlphaEdit = nil
	self.dockBorderAlphaEdit = nil
	self.dockOverallAlphaEdit = nil
	self.dockTransparencyResetButton = nil
	self.dockHistoryToggle = nil
	self.dockHistoryLinesEdit = nil
	self.dockClearHistoryButton = nil
	self.dockResponsiveMetadataToggle = nil
	self.dockLineSpacingTitle = nil
	self.dockLineSpacingEdit = nil
	self.dockLineSpacingHint = nil
	self.dockMessageBandsToggle = nil
	self.dockMessageBandsScrollbarToggle = nil
	self.dockMessageBandExtentButtons = nil
	self.dockMessageBandColorButtons = nil
	self.dockMessageBandAlphaEdit = nil
	self.dockMessageBandsResetButton = nil
	self.dockNewMessagesToggle = nil
	self.dockNewMessagesCountToggle = nil
	self.dockNewMessagesMaxEdit = nil
	self.dockMarkerAppearanceToggle = nil
	self.dockUnreadCountAppearanceToggle = nil
	self.dockUnreadCountAppearanceControls = nil
	self.dockUnreadCountFontSizeEdit = nil
	self.dockUnreadCountAlphaEdit = nil
	self.dockUnreadCountResetButton = nil
	self.dockUnreadCountAppearanceExpanded = nil
	self.dockMarkerAppearanceControls = nil
	self.dockMarkerPositionValue = nil
	self.dockMarkerPreviewButton = nil
	self.dockMarkerResetPositionButton = nil
	self.dockMarkerResetAppearanceButton = nil
	self.dockMarkerFontButtons = nil
	self.dockMarkerFontSizeEdit = nil
	self.dockMarkerScaleEdit = nil
	self.dockMarkerAlphaEdit = nil
	self.dockMarkerOutlineButtons = nil
	self.dockMarkerColorTargetButtons = nil
	self.dockMarkerThemeColorButtons = nil
	self.dockMarkerColorEdits = nil
	self.dockMarkerAppearanceExpanded = nil
	self.dockMarkerColorTarget = nil
	self.dockSizeTitle = nil
	self.dockWidthLabel = nil
	self.dockHeightLabel = nil
	self.dockResetSizeButton = nil
	self.dockHorizontalButton = nil
	self.dockVerticalButton = nil
	self.dockRailAlwaysButton = nil
	self.dockRailMouseoverButton = nil
	self.dockRailClickButton = nil
	self.dockRailHiddenButton = nil
	self.dockTitleBarAlwaysButton = nil
	self.dockTitleBarHoverButton = nil
	self.dockTitleBarHiddenButton = nil
	self.dockWidthEdit = nil
	self.dockHeightEdit = nil
	self.dockStatus = nil
	self.modulesPage = nil
	self.moduleOverview = nil
	self.moduleFilterButtons = nil
	self.moduleListPanel = nil
	self.moduleRows = nil
	self.moduleListTitle = nil
	self.moduleListCount = nil
	self.moduleListPrevious = nil
	self.moduleListNext = nil
	self.moduleInspectorPanel = nil
	self.moduleInspectorTitle = nil
	self.moduleInspectorStatus = nil
	self.moduleInspectorSummary = nil
	self.modulePreferenceToggle = nil
	self.moduleSmartToggle = nil
	self.moduleOpenConfig = nil
	self.moduleNativeNote = nil
	self.modulesStatus = nil
	self.moduleListPage = nil
	self.selectedModuleId = nil
	self.messengerPage = nil
	self.messengerHeading = nil
	self.messengerSection = nil
	self.messengerSectionButtons = nil
	self.messengerSectionTitle = nil
	self.messengerSectionHint = nil
	self.messengerSectionGroups = nil
	self.messengerStatus = nil
	self.messengerWhispersToggle = nil
	self.messengerCombatToggle = nil
	self.messengerTellTargetToggle = nil
	self.messengerReplyCommandFocusToggle = nil
	self.messengerTabNameLengthTitle = nil
	self.messengerTabNameMaxLengthEdit = nil
	self.messengerTabNameLengthHint = nil
	self.messengerTabNameLengthDetail = nil
	self.messengerChromeAutoHideToggle = nil
	self.messengerVisibilityRows = nil
	self.messengerTextButtons = nil
	self.messengerIconButtons = nil
	self.messengerHorizontalButton = nil
	self.messengerVerticalButton = nil
	self.messengerActionCollapsedToggle = nil
	self.messengerAppearanceAlphaEdits = nil
	self.messengerOpacityResetButton = nil
	self.messengerAppearanceColorTarget = nil
	self.messengerAppearanceTargetButtons = nil
	self.messengerAppearancePresetButtons = nil
	self.messengerAppearanceColorEdits = nil
	self.messengerAppearanceApplyColorButton = nil
	self.messengerAppearanceInheritButton = nil
	self.messengerAppearanceResetButton = nil
	self.semanticRoutesPage = nil
	self.semanticRouteToggles = nil
	self.semanticRoutesAvailability = nil
	self.semanticRoutesTestInput = nil
	self.semanticRoutesResult = nil
	self.semanticRoutesEvidence = nil
	self.semanticRoutesStatus = nil
	self.colorwayCards = nil
	self.colorwayPage = nil
	self.colorwayPagerText = nil
	self.colorwayPrevious = nil
	self.colorwayNext = nil
	self.keywordColorsPanel = nil
	self.keywordSuggestionsPanel = nil
	self.keywordColorGroupsSectionButton = nil
	self.keywordSuggestionsSectionButton = nil
	self.keywordColorOptionButtons = nil
	self.keywordColorGroupRows = nil
	self.keywordColorGroupCount = nil
	self.keywordColorGroupPrevious = nil
	self.keywordColorGroupNext = nil
	self.keywordColorListPane = nil
	self.keywordColorInspectorTitle = nil
	self.keywordColorInspectorValue = nil
	self.keywordColorInspectorSwatch = nil
	self.keywordColorInspectorWordsButton = nil
	self.keywordColorInspectorColorButton = nil
	self.keywordColorInspectorWordsPane = nil
	self.keywordColorInspectorColorPane = nil
	self.keywordColorNewGroupButton = nil
	self.keywordColorNewGroupNameLabel = nil
	self.keywordColorNewGroupNameEdit = nil
	self.keywordColorCreateGroupButton = nil
	self.keywordColorCancelGroupButton = nil
	self.keywordColorWordsTitle = nil
	self.keywordColorTermRows = nil
	self.keywordColorTermCount = nil
	self.keywordColorTermPrevious = nil
	self.keywordColorTermNext = nil
	self.keywordColorTermAddLabel = nil
	self.keywordColorTermAddEdit = nil
	self.keywordColorTermCaseToggle = nil
	self.keywordColorTermAddButton = nil
	self.keywordColorPaletteTitle = nil
	self.keywordColorMaintenanceTitle = nil
	self.keywordColorDefaultButton = nil
	self.keywordColorResetBuiltInsButton = nil
	self.keywordColorDeleteGroupButton = nil
	self.keywordColorStatus = nil
	self.keywordSuggestionReviewButton = nil
	self.keywordSuggestionSettingsButton = nil
	self.keywordSuggestionMoreButton = nil
	self.keywordSuggestionReviewPane = nil
	self.keywordSuggestionSettingsPane = nil
	self.keywordSuggestionMorePane = nil
	self.keywordSuggestionTrackingToggle = nil
	self.keywordSuggestionThresholdLabel = nil
	self.keywordSuggestionThresholdEdit = nil
	self.keywordSuggestionSettingsNote = nil
	self.keywordSuggestionRows = nil
	self.keywordSuggestionCount = nil
	self.keywordSuggestionPrevious = nil
	self.keywordSuggestionNext = nil
	self.keywordSuggestionWord = nil
	self.keywordSuggestionMeta = nil
	self.keywordSuggestionSample = nil
	self.keywordSuggestionTargetHint = nil
	self.keywordSuggestionGroupRows = nil
	self.keywordSuggestionGroupCount = nil
	self.keywordSuggestionGroupPrevious = nil
	self.keywordSuggestionGroupNext = nil
	self.keywordSuggestionAddButton = nil
	self.keywordSuggestionDismissButton = nil
	self.keywordSuggestionClearButton = nil
	self.keywordSuggestionStatus = nil
	self.selectedKeywordColorGroupId = nil
	self.keywordColorGroupDraft = nil
	self.keywordColorGroupPage = nil
	self.keywordColorTermPage = nil
	self.keywordColorInspectorSection = nil
	self.selectedKeywordSuggestionId = nil
	self.selectedKeywordSuggestionGroupId = nil
	self.keywordSuggestionPage = nil
	self.keywordSuggestionGroupPage = nil
	self.keywordSuggestionSection = nil
	self.keywordColorsSection = nil
	self.viewsPage = nil
	self.messageViewsPage = nil
	self.messageViewsPageWork = nil
	self.messageViewsUnified = nil
	self.messageViewsSection = nil
	self.messageViewsDetailsButton = nil
	self.messageViewsSourcesButton = nil
	self.messageViewsTextButton = nil
	self.messageViewsDetailsPane = nil
	self.messageViewsSourcesPane = nil
	self.messageViewsTextPane = nil
	self.messageViewsSemanticCatalogPanel = nil
	self.messageViewsSemanticCatalogTitle = nil
	self.messageViewsSemanticCatalogOpen = nil
	self.messageViewsSemanticCatalogRows = nil
	self.allTabsTextButton = nil
	self.messageViewKeyHeader = nil
	self.messageViewNameHeader = nil
	self.messageViewKeyMeasure = nil
	self.messageViewKeyColumnWidth = nil
	self.messageViewColumnDividerX = nil
	self.messageViewNameColumnX = nil
	self.messageTextAllTabsButton = nil
	self.messageTextThisTabButton = nil
	self.messageTextScopeTitle = nil
	self.messageTextScopeHint = nil
	self.messageTextChooseFontButton = nil
	self.messageTextFontPreview = nil
	self.messageTextSizeLabel = nil
	self.messageTextSizeEdit = nil
	self.messageTextSizeHint = nil
	self.messageTextSpacingLabel = nil
	self.messageTextSpacingEdit = nil
	self.messageTextSpacingHint = nil
	self.messageTextEntryGapLabel = nil
	self.messageTextEntryGapEdit = nil
	self.messageTextEntryGapHint = nil
	self.messageTextOutlineLabel = nil
	self.messageTextOutlineButtons = nil
	self.messageTextResetButton = nil
	self.messageTextResetHint = nil
	self.messageTextAlignmentTitle = nil
	self.messageTextColumnAlignmentToggle = nil
	self.messageTextColumnAlignmentHint = nil
	self.messageTextColumnAlignmentSpacingLabel = nil
	self.messageTextColumnAlignmentSpacingEdit = nil
	self.messageTextColumnAlignmentSpacingHint = nil
	self.messageTextSenderColumnAlignmentToggle = nil
	self.messageTextSenderColumnAlignmentSpacingLabel = nil
	self.messageTextSenderColumnAlignmentSpacingEdit = nil
	self.messageTextSenderColumnAlignmentSpacingHint = nil
	self.messageTextSenderColumnMaxLengthLabel = nil
	self.messageTextSenderColumnMaxLengthEdit = nil
	self.messageTextSenderColumnMaxLengthHint = nil
	self.messageTextAlignmentVisibleOnlyToggle = nil
	self.messageTextFontPicker = nil
	self.messageTextFontCloseButton = nil
	self.messageTextFontSearch = nil
	self.messageTextFontSearchHint = nil
	self.messageTextFontRows = nil
	self.messageTextFontCount = nil
	self.messageTextFontScrollHint = nil
	self.messageTextFontOffset = nil
	self.messageTextAppearanceScope = nil
	self.awaitFontPickerMouseRelease = nil
	self.fontPickerMouseDown = nil
	self.messageViewsResetSourcesButton = nil
	self.creatingCustomView = nil
	self.builtInViewToggles = nil
	self.builtInViewRows = nil
	self.customViewRows = nil
	self.customViewCount = nil
	self.customViewPrevious = nil
	self.customViewNext = nil
	self.viewEditorTitle = nil
	self.viewNameEdit = nil
	self.viewKeyEdit = nil
	self.viewDescriptionEdit = nil
	self.viewTermsEdit = nil
	self.viewTermsLabel = nil
	self.viewTermsHint = nil
	self.viewVisibleToggle = nil
	self.viewSaveButton = nil
	self.viewDeleteButton = nil
	self.viewResetButton = nil
	self.viewsStatus = nil
	self.selectedViewId = nil
	self.selectedCustomViewId = nil
	self.pendingDeleteViewId = nil
	self.railsPage = nil
	self.railRows = nil
	self.railCount = nil
	self.railPrevious = nil
	self.railNext = nil
	self.railMoveUp = nil
	self.railMoveDown = nil
	self.railDragMarker = nil
	self.railDropAfter = nil
	self.railDragViewId = nil
	self.railDragTargetId = nil
	self.railDragAfterViewId = nil
	self.railSuppressClickUntil = nil
	self.railEditorTitle = nil
	self.railNameEdit = nil
	self.railKeyEdit = nil
	self.railVisibleToggle = nil
	self.railResetNameButton = nil
	self.railSourceRows = nil
	self.railSourceHint = nil
	self.railSourceCount = nil
	self.railSourcePrevious = nil
	self.railSourceNext = nil
	self.railsStatus = nil
	self.selectedRailId = nil
	self.railPage = nil
	self.railSourcePage = nil
	self.spamPage = nil
	self.spamHealth = nil
	self.spamStatus = nil
	self.spamFiltersPane = nil
	self.spamBansPane = nil
	self.spamFiltersButton = nil
	self.spamBansButton = nil
	self.spamFilterSubButtons = nil
	self.spamFilterSubPanes = nil
	self.spamFilterMode = nil
	self.spamBanSubButtons = nil
	self.spamBanSubPanes = nil
	self.spamBanMode = nil
	self.spamDuplicateToggle = nil
	self.spamBurstToggle = nil
	self.spamNumberEdits = nil
	self.spamDuplicateMuteAfterEdit = nil
	self.spamScopeToggles = nil
	self.spamEscalationToggle = nil
	self.spamMutesToBanEdit = nil
	self.spamStrikeWindowEdit = nil
	self.spamBanNameEdit = nil
	self.spamClearBansButton = nil
	self.spamBanRows = nil
	self.spamBanCount = nil
	self.spamBanPrevious = nil
	self.spamBanNext = nil
	self.spamBanSummary = nil
	self.spamBanNotice = nil
	self.spamResetStatsButton = nil
	self.spamClearMemoryButton = nil
	self.spamBanPage = nil
	self.spamBanHoverIdentity = nil
	self.spamClearBansExpires = nil
	self.blocksPage = nil
	self.blocksSection = nil
	self.blockRulesSectionButton = nil
	self.blockArchiveSectionButton = nil
	self.blockRulesFrames = nil
	self.blocksMasterToggle = nil
	self.blockCoalesceToggle = nil
	self.blockWindowEdit = nil
	self.blockRows = nil
	self.blockRuleCount = nil
	self.blockRulePrevious = nil
	self.blockRuleNext = nil
	self.blocksStats = nil
	self.blockEditorTitle = nil
	self.blockInspectorButtons = nil
	self.blockInspectorPanes = nil
	self.blockInspectorMode = nil
	self.blockNameEdit = nil
	self.blockTextEdit = nil
	self.blockEnabledToggle = nil
	self.blockCaseToggle = nil
	self.blockExactButton = nil
	self.blockContainsButton = nil
	self.blockAllSourcesToggle = nil
	self.blockAllEventsToggle = nil
	self.blockAllSendersToggle = nil
	self.blockSaveButton = nil
	self.blockDeleteButton = nil
	self.blockSenderText = nil
	self.blockSenderHint = nil
	self.blockScopeSourcesButton = nil
	self.blockScopeEventsButton = nil
	self.blockScopeHint = nil
	self.blockScopeRows = nil
	self.blockScopeCount = nil
	self.blockScopePrevious = nil
	self.blockScopeNext = nil
	self.blocksStatus = nil
	self.blockedArchivePanel = nil
	self.blockedArchiveEnabledToggle = nil
	self.blockedArchiveRetentionEdit = nil
	self.blockedArchiveCapacityEdit = nil
	self.blockedArchiveClearButton = nil
	self.blockedArchiveRows = nil
	self.blockedArchiveCount = nil
	self.blockedArchivePrevious = nil
	self.blockedArchiveNext = nil
	self.blockedArchiveDetailTitle = nil
	self.blockedArchiveDetailMeta = nil
	self.blockedArchiveDetailText = nil
	self.blockedArchiveDetailRule = nil
	self.blockedArchiveDetailTiming = nil
	self.blockedArchiveStatus = nil
	self.blockedArchivePage = nil
	self.selectedBlockedArchiveId = nil
	self.pendingClearBlockedArchive = nil
	self.blockEditorControls = nil
	self.selectedBlockRuleId = nil
	self.blockDraft = nil
	self.pendingDeleteBlockId = nil
	self.blockRulePage = nil
	self.blockScopePage = nil
	self.blockScopeMode = nil
	self.alertsPage = nil
	self.alertGlobalEnabledToggle = nil
	self.alertGlobalPopoutToggle = nil
	self.alertGlobalSoundToggle = nil
	self.alertAutoHideEdit = nil
	self.alertRows = nil
	self.alertRuleCount = nil
	self.alertRulePrevious = nil
	self.alertRuleNext = nil
	self.alertStats = nil
	self.alertEditorTitle = nil
	self.alertInspectorButtons = nil
	self.alertInspectorPanes = nil
	self.alertInspectorMode = nil
	self.alertNameEdit = nil
	self.alertTermsEdit = nil
	self.alertEnabledToggle = nil
	self.alertMatchAllToggle = nil
	self.alertAllSourcesToggle = nil
	self.alertRevealToggle = nil
	self.alertRuleSoundToggle = nil
	self.alertSaveButton = nil
	self.alertDeleteButton = nil
	self.alertUsePlayerNameButton = nil
	self.alertRevealGateHint = nil
	self.alertSoundGateHint = nil
	self.alertSourceHint = nil
	self.alertSourceRows = nil
	self.alertSourceCount = nil
	self.alertSourcePrevious = nil
	self.alertSourceNext = nil
	self.alertsStatus = nil
	self.alertEditorControls = nil
	self.selectedAlertRuleId = nil
	self.pendingDeleteAlertId = nil
	self.alertRulePage = nil
	self.alertSourcePage = nil
	self:ShowPage(self.activePage or "home")
end

function Config:Shutdown()
	if self.conflictFrame then
		self.conflictFrame:Hide()
	end
	self:HideSpamBanReport()
	if self.frame then
		self.frame:Hide()
	end
end

function Config:RefreshModuleNavigation()
	if not self.moduleNavigationButtons then
		return
	end
	local modules = addon.GetModuleCatalog and addon:GetModuleCatalog() or {}
	local pageCount = math.max(1, math.ceil(#modules / MODULE_NAV_ROWS_PER_PAGE))
	self.moduleNavigationPage = math.max(1, math.min(self.moduleNavigationPage or 1, pageCount))
	local first = ((self.moduleNavigationPage - 1) * MODULE_NAV_ROWS_PER_PAGE) + 1
	for index, button in ipairs(self.moduleNavigationButtons) do
		local module = modules[first + index - 1]
		if module then
			button.moduleId = module.id
			local navigationLabel = module.navLabel or module.label
			if button.label then
				button.label:SetText(string.upper(navigationLabel))
			elseif button.SetLabel then
				button:SetLabel(string.upper(navigationLabel))
			end
			button.tooltipText = tostring(module.label or navigationLabel) .. "\n" .. moduleHumanStatus(module)
			local active = module.id == self.selectedModuleId and self.activePage == "modules"
			button.navActive = active
			if button.label then
				self:ApplyNavigationRowStyle(button, active, false)
			elseif button.SetTheme then
				button:SetTheme(active and "accentSoft" or "surface", active and "gold" or "borderMuted", active and "goldBright" or "textMuted")
			end
			if self.modulesNavigationExpanded then button:Show() else button:Hide() end
		else
			button.moduleId = nil
			button:Hide()
		end
	end
	local showPager = self.modulesNavigationExpanded and pageCount > 1
	if self.moduleNavigationCount then
		self.moduleNavigationCount:SetText(tostring(self.moduleNavigationPage) .. "/" .. tostring(pageCount))
		if showPager then self.moduleNavigationCount:Show() else self.moduleNavigationCount:Hide() end
	end
	if self.moduleNavigationPrevious then
		if showPager and self.moduleNavigationPage > 1 then self.moduleNavigationPrevious:Show() else self.moduleNavigationPrevious:Hide() end
	end
	if self.moduleNavigationNext then
		if showPager and self.moduleNavigationPage < pageCount then self.moduleNavigationNext:Show() else self.moduleNavigationNext:Hide() end
	end
end

function Config:LayoutNavigation()
	if not self.navigationOrder or not self.navTitle or not self.navContent then
		return
	end
	local content = self.navContent
	local y = NAV_TOP
	self.navTitle:ClearAllPoints()
	self.navTitle:SetPoint("TOPLEFT", content, "TOPLEFT", NAV_LEFT, -y)
	self.navTitle:Show()
	y = y + NAV_TITLE_HEIGHT
	local activeGroup
	for _, item in ipairs(self.navigationOrder) do
		if item.group ~= activeGroup then
			activeGroup = item.group
			local groupLabel = self.navigationSectionLabels and self.navigationSectionLabels[activeGroup]
			if groupLabel then
				groupLabel:ClearAllPoints()
				y = y + NAV_SECTION_GAP
				groupLabel:SetPoint("TOPLEFT", content, "TOPLEFT", NAV_LEFT, -y)
				groupLabel:Show()
				y = y + NAV_SECTION_HEIGHT
			end
		end
		local button = self.navigationButtons[item.id]
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", content, "TOPLEFT", NAV_LEFT, -y)
		button._navTop = y
		y = y + NAV_BUTTON_HEIGHT + NAV_ROW_GAP
		if item.id == "modules" and self.modulesNavigationExpanded then
			for _, child in ipairs(self.moduleNavigationButtons or {}) do
				if child:IsShown() then
					child:ClearAllPoints()
					-- Every module child is anchored directly to the scroll content.
					-- This is a single flat level, not a chain of relative points, so
					-- it cannot turn into a staircase as the list is recycled.
					child:SetPoint("TOPLEFT", content, "TOPLEFT", NAV_LEFT + NAV_MODULE_INDENT, -y)
					child._navTop = y
					y = y + NAV_CHILD_HEIGHT + NAV_ROW_GAP
				end
			end
			if self.moduleNavigationCount and self.moduleNavigationCount:IsShown() then
				self.moduleNavigationCount:ClearAllPoints()
				self.moduleNavigationCount:SetPoint("TOPLEFT", content, "TOPLEFT", NAV_LEFT + NAV_MODULE_INDENT, -y)
				self.moduleNavigationPrevious:ClearAllPoints()
				self.moduleNavigationNext:ClearAllPoints()
				local pagerAnchor = self.moduleNavigationCount
				if self.moduleNavigationPrevious:IsShown() then
					self.moduleNavigationPrevious:SetPoint("LEFT", pagerAnchor, "RIGHT", 5, 0)
					pagerAnchor = self.moduleNavigationPrevious
				end
				if self.moduleNavigationNext:IsShown() then
					self.moduleNavigationNext:SetPoint("LEFT", pagerAnchor, "RIGHT", pagerAnchor == self.moduleNavigationCount and 5 or 2, 0)
				end
				y = y + NAV_PAGER_HEIGHT + NAV_ROW_GAP
			end
		end
	end
	if self.navFooter then
		self.navFooter:ClearAllPoints()
		y = y + NAV_SECTION_GAP
		self.navFooter:SetPoint("TOPLEFT", content, "TOPLEFT", NAV_LEFT, -y)
		self.navFooter:Show()
		y = y + NAV_FOOTER_HEIGHT + NAV_TOP
	end
	if content.SetHeight then
		content:SetHeight(math.max(1, y))
	end
	-- A collapsing section may reduce the scroll range. Clamp the previous
	-- offset so the settings list never remains stranded below its new end.
	local scroll = self.navScroll
	if scroll and scroll.GetVerticalScrollRange and scroll.SetVerticalScroll then
		local range = tonumber(scroll:GetVerticalScrollRange()) or 0
		local current = scroll.GetVerticalScroll and tonumber(scroll:GetVerticalScroll()) or 0
		scroll:SetVerticalScroll(math.max(0, math.min(range, current or 0)))
	end
	self:KeepActiveNavigationVisible()
end

function Config:KeepActiveNavigationVisible()
	local scroll = self.navScroll
	if not scroll or not scroll.GetHeight or not scroll.GetVerticalScrollRange or not scroll.SetVerticalScroll then
		return
	end
	local active
	for _, button in pairs(self.navigationButtons or {}) do
		if button.navActive then
			active = button
			break
		end
	end
	for _, button in ipairs(self.moduleNavigationButtons or {}) do
		if button.navActive then
			active = button
			break
		end
	end
	if not active or not active._navTop then
		return
	end
	local viewport = tonumber(scroll:GetHeight()) or 0
	local range = tonumber(scroll:GetVerticalScrollRange()) or 0
	if viewport <= 0 or range <= 0 then
		return
	end
	local current = scroll.GetVerticalScroll and (tonumber(scroll:GetVerticalScroll()) or 0) or 0
	local top = active._navTop
	local bottom = top + (tonumber(active:GetHeight()) or NAV_BUTTON_HEIGHT)
	if top < current + 3 then
		scroll:SetVerticalScroll(math.max(0, top - 3))
	elseif bottom > current + viewport - 3 then
		scroll:SetVerticalScroll(math.min(range, bottom - viewport + 3))
	end
end

function Config:BuildFrame()
	if self.frame then
		return
	end

	local frame = Theme:CreatePanel(UIParent, "background", "border")
	frame:SetSize(CONFIG_FRAME_WIDTH, CONFIG_FRAME_HEIGHT)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetMovable(true)
	if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		Config:FitFrameToViewport()
	end)
	if frame.RegisterEvent then
		-- UI_SCALE_CHANGED is present on the target client, while pcall keeps
		-- unusual 3.3.5 forks that omit either event from rejecting the frame.
		pcall(frame.RegisterEvent, frame, "UI_SCALE_CHANGED")
		pcall(frame.RegisterEvent, frame, "DISPLAY_SIZE_CHANGED")
		frame:SetScript("OnEvent", function(_, event)
			if event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
				Config:FitFrameToViewport()
			end
		end)
	end
	frame:Hide()
	self.frame = frame
	self.pages = {}
	self.navigationButtons = {}
	-- Placement preview is intentionally temporary. Closing the settings window
	-- must never leave a synthetic NEW marker behind in normal play.
	frame:HookScript("OnHide", function()
		if Config.dockMarkerPreviewActive then
			Config:SetNewMessageIndicatorPreview(false)
		end
	end)
	frame:HookScript("OnShow", function()
		Config:FitFrameToViewport()
	end)

	-- The shell uses one outer boundary. Header, navigation, and workspace are
	-- deliberately quiet surfaces separated by hairlines, so the actual page
	-- controls, not a wall of boxes, carry the user's attention.
	local header = createQuietShellPanel(frame, "surface")
	header:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
	header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
	header:SetHeight(44)
	local headerDivider = header:CreateTexture(nil, "BORDER")
	headerDivider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
	headerDivider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
	headerDivider:SetHeight(NAV_DIVIDER_WIDTH)
	if Theme.RegisterTexture then Theme:RegisterTexture(headerDivider, "borderMuted") end

	local icon = header:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(Theme.ICON_PATH)
	icon:SetSize(30, 30)
	icon:SetPoint("LEFT", header, "LEFT", 8, 0)

	local title = Theme:CreateText(header, "GameFontNormal", "goldBright")
	title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -4)
	title:SetText("ChattyChattyBangBang")
	local subtitle = Theme:CreateText(header, "GameFontHighlightSmall", "textMuted")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -1)
	subtitle:SetText("WRATH / ASCENSION CHAT  v" .. getAddonVersion())

	local close = CreateFrame("Button", nil, header)
	close:SetSize(18, 18)
	close.text = Theme:CreateText(close, "GameFontNormalSmall", "textMuted")
	close.text:SetAllPoints(close)
	close.text:SetJustifyH("CENTER")
	close.text:SetText("x")
	close:SetPoint("RIGHT", header, "RIGHT", -8, 0)
	close:SetScript("OnEnter", function(self)
		local r, g, b, a = Theme:GetColor("goldBright")
		self.text:SetTextColor(r, g, b, a)
		if GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:SetText("Close settings", 1, 0.82, 0.3)
			GameTooltip:Show()
		end
	end)
	close:SetScript("OnLeave", function(self)
		local r, g, b, a = Theme:GetColor("textMuted")
		self.text:SetTextColor(r, g, b, a)
		if GameTooltip then GameTooltip:Hide() end
	end)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)

	local sidebar = createQuietShellPanel(frame, "surface")
	sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -56)
	sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 6)
	sidebar:SetWidth(170)
	self.sidebar = sidebar
	local sidebarDivider = sidebar:CreateTexture(nil, "BORDER")
	sidebarDivider:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, 0)
	sidebarDivider:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 0)
	sidebarDivider:SetWidth(NAV_DIVIDER_WIDTH)
	if Theme.RegisterTexture then Theme:RegisterTexture(sidebarDivider, "borderMuted") end

	-- The settings list can grow temporarily when Modules is expanded. Keep it
	-- in a wheel-only scroll surface instead of letting nested rows push the
	-- normal sections out of the sidebar. There is intentionally no scrollbar:
	-- this reads as one compact settings block, not a second list widget.
	local navScroll = CreateFrame("ScrollFrame", nil, sidebar)
	navScroll:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, 0)
	navScroll:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -NAV_DIVIDER_WIDTH, 0)
	if navScroll.EnableMouseWheel then
		navScroll:EnableMouseWheel(true)
	end
	local navContent = CreateFrame("Frame", nil, navScroll)
	navContent:SetWidth(168)
	navContent:SetHeight(1)
	if navScroll.SetScrollChild then
		navScroll:SetScrollChild(navContent)
	end
	self.navScroll = navScroll
	self.navContent = navContent

	local function scrollNavigation(delta)
		if not navScroll.GetVerticalScrollRange or not navScroll.SetVerticalScroll then
			return
		end
		local range = tonumber(navScroll:GetVerticalScrollRange()) or 0
		if range <= 0 then
			return
		end
		local current = navScroll.GetVerticalScroll and (tonumber(navScroll:GetVerticalScroll()) or 0) or 0
		navScroll:SetVerticalScroll(math.max(0, math.min(range, current - ((tonumber(delta) or 0) * 34))))
	end
	local function bindNavigationWheel(widget)
		if not widget then
			return
		end
		if widget.EnableMouseWheel then
			widget:EnableMouseWheel(true)
		end
		if widget.HookScript then
			widget:HookScript("OnMouseWheel", function(_, delta)
				scrollNavigation(delta)
			end)
		elseif widget.SetScript then
			widget:SetScript("OnMouseWheel", function(_, delta)
				scrollNavigation(delta)
			end)
		end
	end
	bindNavigationWheel(navScroll)
	bindNavigationWheel(navContent)
	bindNavigationWheel(sidebar)

	local navTitle = Theme:CreateText(navContent, "GameFontNormalSmall", "gold")
	navTitle:SetText("SETTINGS")
	self.navTitle = navTitle
	self.navigationOrder = navigation
	self.navigationSectionLabels = {}
	for _, item in ipairs(navigation) do
		if item.group and not self.navigationSectionLabels[item.group] then
			local section = Theme:CreateText(navContent, "GameFontHighlightSmall", "textMuted")
			section:SetWidth(154)
			section:SetJustifyH("LEFT")
			section:SetText(item.group)
			self.navigationSectionLabels[item.group] = section
		end
	end

	for index = 1, #navigation do
		local item = navigation[index]
		local pageId = item.id
		local help = {
			modules = "Review Chatty features and choose which built-in behavior you want to use.",
			semantic = "See how Chatty recognizes message intent and sends messages to a view.",
			integrations = "Connect Chatty with compatible addons and local diagnostic output.",
			views = "Create and organize the message views that appear as chat tabs.",
		}
		local button = createNavigationRow(navContent, string.upper(item.label), help[pageId])
		button.pageId = pageId
		if pageId == "modules" then
			button.disclosure = Theme:CreateText(button, "GameFontNormalSmall", "textMuted")
			button.disclosure:SetPoint("RIGHT", button, "RIGHT", -7, 0)
			button.disclosure:SetJustifyH("RIGHT")
			button.label:ClearAllPoints()
			button.label:SetPoint("LEFT", button, "LEFT", 7, 0)
			button.label:SetPoint("RIGHT", button.disclosure, "LEFT", -4, 0)
		end
		button:SetScript("OnClick", function()
			if pageId == "modules" then
				-- Opening Modules should never unexpectedly collapse the nested
				-- choices. Once the page is already active, the same button becomes
				-- its compact expand/collapse control.
				if Config.activePage ~= "modules" then
					Config.modulesNavigationExpanded = true
				else
					Config.modulesNavigationExpanded = not Config.modulesNavigationExpanded
				end
				Config:ShowPage("modules")
			else
				Config:ShowPage(pageId)
			end
		end)
		bindNavigationWheel(button)
		self.navigationButtons[pageId] = button
	end
	self.moduleNavigationButtons = {}
	for index = 1, MODULE_NAV_ROWS_PER_PAGE do
		local child = createNavigationRow(navContent, "", "Open this module's settings.")
		child:SetSize(144, NAV_CHILD_HEIGHT)
		child.label:ClearAllPoints()
		child.label:SetPoint("LEFT", child, "LEFT", 6, 0)
		child.label:SetPoint("RIGHT", child, "RIGHT", -4, 0)
		child:SetScript("OnClick", function(self)
			if self.moduleId then
				Config:SelectModule(self.moduleId)
				Config:ShowPage("modules")
			end
		end)
		bindNavigationWheel(child)
		self.moduleNavigationButtons[index] = child
	end
	self.moduleNavigationCount = Theme:CreateText(navContent, "GameFontHighlightSmall", "textMuted")
	self.moduleNavigationPrevious = Theme:CreateTightButton(navContent, "<", 17, false)
	self.moduleNavigationPrevious:SetScript("OnClick", function()
		Config.moduleNavigationPage = math.max(1, (Config.moduleNavigationPage or 1) - 1)
		Config:RefreshNavigation()
	end)
	bindNavigationWheel(self.moduleNavigationPrevious)
	self.moduleNavigationNext = Theme:CreateTightButton(navContent, ">", 17, false)
	self.moduleNavigationNext:SetScript("OnClick", function()
		Config.moduleNavigationPage = (Config.moduleNavigationPage or 1) + 1
		Config:RefreshNavigation()
	end)
	bindNavigationWheel(self.moduleNavigationNext)

	local navFooter = Theme:CreateText(navContent, "GameFontHighlightSmall", "textMuted")
	navFooter:SetWidth(154)
	navFooter:SetJustifyH("LEFT")
	navFooter:SetText("/chattychattybangbang")
	self.navFooter = navFooter
	self.modulesNavigationExpanded = self.modulesNavigationExpanded and true or false
	self:RefreshNavigation()

	local content = createQuietShellPanel(frame, "surface")
	content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 6, 0)
	content:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -56)
	content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
	self.content = content

	Theme:RegisterRefreshCallback(function()
		if Config.frame then
			Config:RefreshNavigation()
			Config:RefreshColorwayCards()
			Config:RefreshKeywordColorsPage(true)
			Config:RefreshMessageViewsPage(true)
			Config:RefreshSpamStatus()
			Config:RefreshBlocksPage(true)
			Config:RefreshSemanticRoutesPage(true)
			Config:RefreshDockPage()
			Config:RefreshSafetyPage()
			Config:RefreshIntegrationsPage()
			Config:RefreshModulesPage(true)
			Config:RefreshAlertsPage(true)
		end
	end)
end

function Config:Open()
	if addon.IsEnabled and not addon:IsEnabled() then
		return
	end
	self:BuildFrame()
	self:FitFrameToViewport()
	self.frame:Show()
	self:ShowPage(self.activePage or "home")
	self.frame:Raise()
end
