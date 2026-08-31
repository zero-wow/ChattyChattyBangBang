local addon = ChattyChattyBangBang
local Theme = addon.Theme
local Presentation = addon.Presentation
local Engine = addon.MessageEngine

-- Messenger deliberately owns one physical frame.  A player is represented by
-- a light-weight session/tab instead of another independent popout, so a busy
-- whisper session stays contained without throwing away the existing message
-- engine history.
local Manager = {}
addon.ConversationWindows = Manager
-- Tell Target is a Messenger command adapter rather than a second window
-- system.  Exposing the same controller gives Settings one narrow runtime
-- refresh target without duplicating session, focus, or slash-command state.
addon.TellTarget = Manager

local Window = {}
Window.__index = Window

local MAX_TABS = 12
local MAX_HISTORY = 200
local MAX_PENDING = 12
local MESSAGE_SCROLLBAR_RIGHT_INSET = 3
local MESSAGE_SCROLLBAR_VERTICAL_INSET = 4
local MESSAGE_SCROLLBAR_THUMB_WIDTH = 6
local MESSAGE_SCROLLBAR_MIN_THUMB_HEIGHT = 18
local MESSAGE_SCROLL_TO_BOTTOM_WIDTH = 10
local MESSAGE_SCROLL_TO_BOTTOM_HEIGHT = 14
local MESSAGE_SCROLL_TO_BOTTOM_GAP = 4
local TAB_NAME_DEFAULT_LENGTH = 14
local TAB_NAME_MIN_LENGTH = 4
local TAB_NAME_MAX_LENGTH = 32
local TAB_NAME_TRUNCATION_MARKER = "~"
local TAB_MINIMUM_WIDTH = 40
local TAB_TEXT_LEFT_INSET = 4
local TAB_TEXT_CONTROL_GAP = 2
local TAB_CLOSE_WIDTH = 11
local TAB_CLOSE_RIGHT_INSET = 2
local TAB_BADGE_RIGHT_INSET = 16

local whisperEvents = {
	CHAT_MSG_WHISPER = true,
	CHAT_MSG_WHISPER_INFORM = true,
}

local ACTION_ICON_ROOT = "Interface\\AddOns\\ChattyChattyBangBang\\Media\\Messenger\\"
local ACTION_ICON_V3_ROOT = ACTION_ICON_ROOT .. "V3\\"

-- The file stems intentionally differ from their action identifiers for the
-- two ignore actions.  Keeping that translation in one table means UI code
-- never leaks camelCase identifiers into asset paths.
local actionIconFiles = {
	reply = "reply",
	invite = "invite",
	friend = "friend",
	localIgnore = "local-ignore",
	serverIgnore = "server-ignore",
}

local actionIconStateSuffixes = {
	normal = "",
	hover = "-hover",
	pressed = "-pressed",
}

-- Cache only explicit texture failures.  The Wrath client does not expose a
-- filesystem API to addons, so SetTexture/GetTexture is the safest narrow
-- probe: a missing staged asset falls through to the V3 base art, then to the
-- established legacy icon instead of leaving an action button blank.
local unavailableActionIconTextures = {}

local function getActionIconFaction()
	if UnitFactionGroup and UnitFactionGroup("player") == "Horde" then
		return "Horde"
	end
	-- The historic neutral artwork was Alliance-blue.  Alliance is therefore
	-- the least surprising login-screen or unknown-faction fallback.
	return "Alliance"
end

local function getActionIconPath(iconName, state)
	local file = actionIconFiles[iconName]
	if not file then
		return nil
	end
	return ACTION_ICON_V3_ROOT
		.. getActionIconFaction()
		.. "\\"
		.. file
		.. (actionIconStateSuffixes[state] or actionIconStateSuffixes.normal)
		.. ".tga"
end

local function getLegacyActionIconPath(iconName)
	local file = actionIconFiles[iconName]
	if not file then
		return nil
	end
	if getActionIconFaction() == "Horde" then
		return ACTION_ICON_ROOT .. "Horde\\" .. file .. ".tga"
	end
	return ACTION_ICON_ROOT .. file .. ".tga"
end

local function sameTexturePath(left, right)
	if type(left) ~= "string" or type(right) ~= "string" then
		return left == right
	end
	left = string.lower(string.gsub(left, "/", "\\"))
	right = string.lower(string.gsub(right, "/", "\\"))
	return left == right
end

local function trySetActionIconTexture(texture, texturePath)
	if not texturePath or unavailableActionIconTextures[texturePath] then
		return false
	end

	local applied, accepted = pcall(texture.SetTexture, texture, texturePath)
	if not applied or accepted == false then
		unavailableActionIconTextures[texturePath] = true
		return false
	end

	-- A client that cannot resolve a texture leaves GetTexture nil.  Retain
	-- compatibility with lightweight test frames that do not expose GetTexture.
	if texture.GetTexture then
		local queried, appliedTexture = pcall(texture.GetTexture, texture)
		if queried and (not appliedTexture or (type(appliedTexture) == "string" and not sameTexturePath(appliedTexture, texturePath))) then
			unavailableActionIconTextures[texturePath] = true
			return false
		end
	end
	return true
end

local function setActionIconTexture(button, state)
	local iconName = button.definition and button.definition.iconName
	state = actionIconStateSuffixes[state] and state or "normal"
	local stagedPath = getActionIconPath(iconName, state)
	if trySetActionIconTexture(button.icon, stagedPath) then
		return true
	end

	-- A partial V3 install still uses the new base icon for hover/pressed.  If
	-- the staged pack itself is unavailable, retain the proven pre-V3 artwork.
	if state ~= "normal" and trySetActionIconTexture(button.icon, getActionIconPath(iconName, "normal")) then
		return true
	end
	if trySetActionIconTexture(button.icon, getLegacyActionIconPath(iconName)) then
		return true
	end

	button.icon:SetTexture(nil)
	return false
end

local function trim(text)
	return string.gsub(string.gsub(tostring(text or ""), "^%s+", ""), "%s+$", "")
end

local function cleanPlayerName(name)
	name = tostring(name or "")
	name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
	name = string.gsub(name, "|r", "")
	name = string.gsub(name, "|H.-|h(.-)|h", "%1")
	name = trim(name)
	if name == "" then
		return nil
	end
	return name
end

local function compactUnitNamePart(value)
	value = cleanPlayerName(value)
	if not value then
		return nil
	end
	value = string.gsub(value, "%s+", "")
	return value ~= "" and value or nil
end

local function playerKey(name)
	name = cleanPlayerName(name)
	return name and string.lower(name) or nil
end

local function getPartner(record)
	if not record or record.isBNet or not whisperEvents[record.event] then
		return nil
	end

	-- On Wrath clients arg2 is the other player for both WHISPER and
	-- WHISPER_INFORM.  The target fallback helps private-server variants that
	-- populate only arg5 for outgoing whispers.
	return cleanPlayerName(record.sender) or cleanPlayerName(record.target)
end

local function isLocallyIgnored(name)
	local settings = addon:GetSmartSettings()
	local ignores = settings.safety and settings.safety.localIgnores
	local key = playerKey(name)
	return key and ignores and ignores[key] == true or false
end

local function now()
	return GetTime and GetTime() or 0
end

local function printStatus(message)
	if addon.Print then
		addon:Print(message)
	end
end

local function setTightButtonLabel(button, label)
	label = tostring(label or "")
	if button.SetTextAutoFit then
		button:SetTextAutoFit(true)
		button:SetLabel(label)
		return
	end
	button:SetLabel(label)
	local textWidth = button.text and button.text.GetStringWidth and button.text:GetStringWidth()
	local minimum = button.GetHeight and button:GetHeight() or 16
	button:SetWidth(math.max(minimum, math.ceil(textWidth or (string.len(label) * 6)) + 10))
end

local function getConversationSettings()
	local settings = addon:GetSmartSettings()
	settings.conversations = settings.conversations or {}
	return settings.conversations
end

local function getActionButtonStyle()
	return getConversationSettings().actionButtonStyle == "icons" and "icons" or "text"
end

local function getMessengerAppearance()
	if type(addon.GetMessengerAppearanceSettings) == "function" then
		local ok, appearance = pcall(addon.GetMessengerAppearanceSettings, addon)
		if ok and type(appearance) == "table" then
			return appearance
		end
	end
	local stored = getConversationSettings().appearance
	stored = type(stored) == "table" and stored or {}
	local transparency = type(stored.transparency) == "table" and stored.transparency or {}
	return {
		transparency = {
			backgroundAlpha = math.max(0, math.min(1, tonumber(transparency.backgroundAlpha) or 1)),
			borderAlpha = math.max(0, math.min(1, tonumber(transparency.borderAlpha) or 1)),
			textAlpha = math.max(0, math.min(1, tonumber(transparency.textAlpha) or 1)),
			overallAlpha = math.max(0, math.min(1, tonumber(transparency.overallAlpha) or 1)),
		},
		colors = type(stored.colors) == "table" and stored.colors or {},
	}
end

local function resolveAppearanceColor(spec)
	if type(spec) ~= "table" or spec.mode == "inherit" or spec.mode == nil then
		return nil
	end
	if spec.mode == "theme" and type(spec.theme) == "string" and Theme.GetColor then
		return Theme:GetColor(spec.theme)
	end
	if spec.mode == "custom" then
		return math.max(0, math.min(1, tonumber(spec.r) or 1)),
			math.max(0, math.min(1, tonumber(spec.g) or 1)),
			math.max(0, math.min(1, tonumber(spec.b) or 1)), 1
	end
	return nil
end

local function normalizeVisibilityMode(value)
	value = type(value) == "string" and string.lower(value) or "inherit"
	if value == "show" or value == "shown" then
		value = "always"
	elseif value == "hover" or value == "mouseover" then
		value = "auto"
	elseif value == "onclick" then
		value = "click"
	elseif value == "compact" then
		value = "collapsed"
	elseif value == "hide" then
		value = "hidden"
	end
	if value ~= "inherit" and value ~= "always" and value ~= "auto"
		and value ~= "click" and value ~= "collapsed" and value ~= "hidden" then
		value = "inherit"
	end
	return value
end

local function resolveVisibilityMode(value, settings)
	local mode = normalizeVisibilityMode(value)
	if mode == "inherit" then
		return settings.chromeAutoHide == true and "auto" or "always"
	end
	return mode
end

local function getActionStripOrientation()
	return getConversationSettings().actionStripOrientation == "vertical" and "vertical" or "horizontal"
end

local function isActionStripCollapsed()
	return getConversationSettings().actionStripCollapsed == true
end

local function isFrameDescendant(frame, ancestor)
	local current = frame
	for _ = 1, 16 do
		if not current then
			return false
		end
		if current == ancestor then
			return true
		end
		if not current.GetParent then
			return false
		end
		current = current:GetParent()
	end
	return false
end

local function isFrameHovered(frame)
	if not frame or not frame.IsShown or not frame:IsShown() then
		return false
	end
	if GetMouseFocus and isFrameDescendant(GetMouseFocus(), frame) then
		return true
	end
	if MouseIsOver then
		local ok, hovered = pcall(MouseIsOver, frame)
		if ok then
			return hovered and true or false
		end
	end
	return false
end

local function sessionMatches(session, record)
	local partner = getPartner(record)
	return partner and session and playerKey(partner) == session.playerKey
end

local function compactName(name)
	name = tostring(name or "")
	if string.len(name) > 14 then
		return string.sub(name, 1, 11) .. "..."
	end
	return name
end

local function utf8CharacterLength(text, position)
	local first = string.byte(text, position) or 0
	if first >= 240 then return 4 end
	if first >= 224 then return 3 end
	if first >= 192 then return 2 end
	return 1
end

local function utf8CharacterCount(text)
	text = tostring(text or "")
	local count, cursor = 0, 1
	while cursor <= string.len(text) do
		cursor = cursor + utf8CharacterLength(text, cursor)
		count = count + 1
	end
	return count
end

local function utf8Prefix(text, characters)
	text = tostring(text or "")
	characters = math.max(0, math.floor(tonumber(characters) or 0))
	local cursor, count = 1, 0
	while cursor <= string.len(text) and count < characters do
		cursor = cursor + utf8CharacterLength(text, cursor)
		count = count + 1
	end
	return string.sub(text, 1, cursor - 1)
end

local function getTabNamePolicy()
	local policy
	if type(addon.GetMessengerSettings) == "function" then
		local ok, values = pcall(addon.GetMessengerSettings, addon)
		if ok and type(values) == "table" then
			policy = values
		end
	end
	policy = policy or getConversationSettings()
	local minimumLength = math.floor(tonumber(policy.minimumTabNameLength)
		or TAB_NAME_MIN_LENGTH)
	local maximumLength = math.floor(tonumber(policy.maximumTabNameLength)
		or TAB_NAME_MAX_LENGTH)
	minimumLength = math.max(1, minimumLength)
	maximumLength = math.max(minimumLength, maximumLength)
	local value = math.floor(tonumber(policy.tabNameMaxLength) or TAB_NAME_DEFAULT_LENGTH)
	local marker = tostring(policy.tabNameTruncationMarker or TAB_NAME_TRUNCATION_MARKER)
	if marker == "" then
		marker = TAB_NAME_TRUNCATION_MARKER
	end
	return math.max(minimumLength, math.min(maximumLength, value)), marker
end

local function truncateTabNameByCharacters(name, maximumLength, marker)
	name = tostring(name or "")
	marker = tostring(marker or TAB_NAME_TRUNCATION_MARKER)
	local characterCount = utf8CharacterCount(name)
	if characterCount <= maximumLength then
		return name, false, characterCount
	end
	return utf8Prefix(name, maximumLength - utf8CharacterCount(marker)) .. marker,
		true, maximumLength
end

local function measureTabLabel(tab, label)
	label = tostring(label or "")
	if tab.SetLabel then
		tab:SetLabel(label)
	elseif tab.text then
		tab.text:SetText(label)
	end
	local measured = tonumber(tab._themeIntrinsicTextWidth)
	if not measured and tab.text and tab.text.GetStringWidth then
		local ok, width = pcall(tab.text.GetStringWidth, tab.text)
		measured = ok and tonumber(width) or nil
	end
	return measured or (utf8CharacterCount(label) * 6)
end

local function addTooltip(button, text)
	button._tooltipText = text
	button:HookScript("OnEnter", function(self)
		if not self.usesIcon or not GameTooltip then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(self._tooltipText or "", 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	button:HookScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
end

local function setActionIconState(button, state)
	if not button.usesIcon then
		button.icon:Hide()
		return
	end

	-- V3 supplies authored normal/hover/pressed sprites.  Do not tint, scale,
	-- nudge, or clone them at runtime: each visible interaction state is the
	-- deliberate artwork rather than a synthetic color effect.
	button.icon:ClearAllPoints()
	button.icon:SetSize(14, 14)
	button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.icon:SetVertexColor(1, 1, 1, 1)
	if setActionIconTexture(button, state) then
		button.icon:Show()
		button.text:Hide()
	else
		button.icon:Hide()
		-- A missing/partially staged media pack must never turn a social action
		-- into an invisible hit target. Keep the compact semantic glyph readable.
		button.text:SetText(button.definition and button.definition.glyph or "?")
		button.text:Show()
	end
end

function Window:GetActiveSession()
	return self.playerKey and Manager.sessionsByKey and Manager.sessionsByKey[self.playerKey] or nil
end

function Window:RestorePosition()
	local settings = getConversationSettings()
	local width = math.max(300, math.min(620, tonumber(settings.windowWidth) or 360))
	local height = math.max(160, math.min(500, tonumber(settings.windowHeight) or 250))
	settings.windowWidth = width
	settings.windowHeight = height
	self.frame:SetSize(width, height)
	settings.windowPositions = settings.windowPositions or {}

	-- New profiles use one shared position.  The old per-player position is
	-- intentionally left alone so a profile downgrade remains harmless.
	local position = settings.windowPositions.messenger
	self.frame:ClearAllPoints()
	if position and position.point and position.relativePoint then
		self.frame:SetPoint(
			position.point,
			UIParent,
			position.relativePoint,
			tonumber(position.x) or 0,
			tonumber(position.y) or 0
		)
	else
		self.frame:SetPoint("CENTER", UIParent, "CENTER", -140, 80)
	end
end

function Window:SavePosition()
	local point, _, relativePoint, x, y = self.frame:GetPoint(1)
	local settings = getConversationSettings()
	settings.windowWidth = math.floor(self.frame:GetWidth())
	settings.windowHeight = math.floor(self.frame:GetHeight())
	settings.windowPositions = settings.windowPositions or {}
	settings.windowPositions.messenger = {
		point = point or "CENTER",
		relativePoint = relativePoint or point or "CENTER",
		x = math.floor(tonumber(x) or 0),
		y = math.floor(tonumber(y) or 0),
	}
end

function Window:FormatRecord(record, session)
	local timestamp = Presentation:Color(record.timestamp or "", "textMuted")
	local separator = Presentation:Color("  |  ", "borderMuted")
	local message = Presentation:ColorizeMessage(record.text or "")
	local label
	local direction

	if record.direction == "outgoing" then
		label = Presentation:Color("YOU", "goldBright")
		direction = Presentation:Color(">", "gold")
	else
		label = Presentation:GetColoredName(record) or Presentation:Color(session.playerName, "text")
		direction = Presentation:Color("<", "accent")
	end

	return timestamp .. separator .. direction .. " " .. label .. "  " .. message
end

function Window:UpdateNewButton()
	local session = self:GetActiveSession()
	if not session or not session.pendingVisible or session.pendingVisible < 1 then
		self.newButton:Hide()
		return
	end
	setTightButtonLabel(self.newButton, tostring(session.pendingVisible) .. " NEW")
	self.newButton:Show()
end

local function setMessengerDisplayScrollOffset(display, offset)
	offset = math.max(0, math.floor((tonumber(offset) or 0) + 0.5))
	if display.SetScrollOffset then
		display:SetScrollOffset(offset)
		return true
	end
	if not display.ScrollToBottom then return false end
	display:ScrollToBottom()
	for _ = 1, offset do
		if not display.ScrollUp then break end
		display:ScrollUp()
	end
	return true
end

function Window:GetMessageScrollMaximum()
	local display = self.display
	if not display then return 0 end
	local current = display.GetCurrentScroll
		and math.max(0, math.floor((tonumber(display:GetCurrentScroll()) or 0) + 0.5)) or 0
	local maximum
	-- ScrollingMessageFrame exposes its exact wrapped range only through its
	-- current offset. Probe the top, then restore in the same frame; this keeps
	-- the thumb accurate for wrapped whispers without adding fake messages.
	if display.ScrollToTop and display.GetCurrentScroll then
		display:ScrollToTop()
		maximum = math.max(0, math.floor((tonumber(display:GetCurrentScroll()) or 0) + 0.5))
		setMessengerDisplayScrollOffset(display, math.min(current, maximum))
	else
		local total = display.GetNumMessages and tonumber(display:GetNumMessages()) or 0
		local visible = display.GetNumLinesDisplayed and tonumber(display:GetNumLinesDisplayed()) or 0
		maximum = math.max(0, math.floor(total - visible))
	end
	self.messageScrollMaximum = maximum
	return maximum
end

function Window:SetMessageScrollbarOffset(value)
	local display = self.display
	local scrollBar = self.messageScrollbar
	if not display or not scrollBar or scrollBar._messageScrollUpdating then return false end
	local maximum = math.max(0, math.floor(tonumber(scrollBar._messageScrollMaximum)
		or tonumber(self.messageScrollMaximum) or 0))
	local sliderValue = math.max(0, math.min(maximum, math.floor((tonumber(value) or 0) + 0.5)))
	setMessengerDisplayScrollOffset(display, maximum - sliderValue)
	if maximum - sliderValue == 0 or (display.AtBottom and display:AtBottom()) then
		local session = self:GetActiveSession()
		if session then session.pendingVisible = 0 end
		self:UpdateNewButton()
	end
	self:RefreshMessageScrollbar(false)
	return true
end

function Window:ScrollMessageDisplayToBottom()
	if not self.display then return false end
	if self.display.ScrollToBottom then self.display:ScrollToBottom() end
	local session = self:GetActiveSession()
	if session then session.pendingVisible = 0 end
	self:UpdateNewButton()
	self:RefreshMessageScrollbar(false)
	return true
end

function Window:RefreshMessageScrollbar(recalculate)
	local scrollBar = self.messageScrollbar
	local display = self.display
	if not scrollBar or not display then return false end
	local maximum = tonumber(self.messageScrollMaximum)
	if recalculate or maximum == nil then maximum = self:GetMessageScrollMaximum() end
	maximum = math.max(0, math.floor(tonumber(maximum) or 0))
	local scrollOffset = display.GetCurrentScroll
		and math.max(0, math.floor((tonumber(display:GetCurrentScroll()) or 0) + 0.5)) or 0
	scrollOffset = math.min(maximum, scrollOffset)

	scrollBar._messageScrollUpdating = true
	scrollBar._messageScrollMaximum = maximum
	if scrollBar.SetMinMaxValues then scrollBar:SetMinMaxValues(0, maximum) end
	if scrollBar.SetValue then scrollBar:SetValue(maximum - scrollOffset) end
	scrollBar._messageScrollUpdating = nil

	local overflow = maximum > 0
	if scrollBar.Show then scrollBar:Show() end
	if scrollBar.EnableMouse then scrollBar:EnableMouse(overflow) end
	if Theme.SetScrollBarThumbVisible then Theme:SetScrollBarThumbVisible(scrollBar, overflow) end
	if overflow and Theme.SetScrollBarThumbSize then
		local height = scrollBar.GetHeight and tonumber(scrollBar:GetHeight()) or 0
		local visible = display.GetNumLinesDisplayed and tonumber(display:GetNumLinesDisplayed()) or 1
		visible = math.max(1, visible)
		local thumbHeight = math.max(MESSAGE_SCROLLBAR_MIN_THUMB_HEIGHT,
			math.floor(height * math.min(1, visible / (visible + maximum)) + 0.5))
		Theme:SetScrollBarThumbSize(scrollBar, MESSAGE_SCROLLBAR_THUMB_WIDTH, thumbHeight)
	end
	local atBottom = scrollOffset == 0 or (display.AtBottom and display:AtBottom())
	if self.scrollToBottomButton then
		if overflow and not atBottom then self.scrollToBottomButton:Show()
		else self.scrollToBottomButton:Hide() end
	end
	return overflow
end

function Window:RenderSession(session)
	self.display:Clear()
	self.messageScrollMaximum = nil
	self.newButton:Hide()
	if not session then
		self.empty:SetText("Choose a Messenger tab to begin.")
		self.empty:Show()
		self:RefreshMessageScrollbar(true)
		return
	end

	session.renderedIds = {}
	session.renderedCount = 0
	session.pendingVisible = 0
	if not Engine or not Engine.GetMessages or isLocallyIgnored(session.playerName) then
		self.empty:SetText("No whisper history with this player yet.")
		self.empty:Show()
		self:RefreshMessageScrollbar(true)
		return
	end

	local records = Engine:GetMessages("conversations") or {}
	local history = {}
	for index = #records, 1, -1 do
		local record = records[index]
		if sessionMatches(session, record) then
			history[#history + 1] = record
			if #history >= MAX_HISTORY then
				break
			end
		end
	end

	for index = #history, 1, -1 do
		local record = history[index]
		self.display:AddMessage(self:FormatRecord(record, session), 1, 1, 1)
		if record.id then
			session.renderedIds[record.id] = true
		end
		session.renderedCount = session.renderedCount + 1
	end

	if #history > 0 then
		self.empty:Hide()
		self.display:ScrollToBottom()
	else
		self.empty:SetText("No whisper history with this player yet.")
		self.empty:Show()
	end
	self:RefreshMessageScrollbar(true)
end

function Window:RebuildHistory()
	self:RenderSession(self:GetActiveSession())
end

function Window:AddRecord(record, suppressScrollNotice)
	local session = self:GetActiveSession()
	if not record or not record.id or not session or session.renderedIds[record.id] or not sessionMatches(session, record) then
		return
	end
	if isLocallyIgnored(session.playerName) then
		return
	end

	if session.renderedCount >= MAX_HISTORY then
		self:RenderSession(session)
		return
	end

	local wasAtBottom = self.display:AtBottom()
	self.display:AddMessage(self:FormatRecord(record, session), 1, 1, 1)
	session.renderedIds[record.id] = true
	session.renderedCount = session.renderedCount + 1
	session.lastUsed = now()
	self.empty:Hide()

	if suppressScrollNotice or wasAtBottom then
		self.display:ScrollToBottom()
	else
		session.pendingVisible = session.pendingVisible + 1
		self:UpdateNewButton()
	end
	self:RefreshMessageScrollbar(true)
end

function Window:RefreshAppearance()
	if not self.frame then return false end
	local appearance = getMessengerAppearance()
	local transparency = appearance.transparency or {}
	local backgroundAlpha = math.max(0, math.min(1, tonumber(transparency.backgroundAlpha) or 1))
	local borderAlpha = math.max(0, math.min(1, tonumber(transparency.borderAlpha) or 1))
	local textAlpha = math.max(0, math.min(1, tonumber(transparency.textAlpha) or 1))
	local overallAlpha = math.max(0, math.min(1, tonumber(transparency.overallAlpha) or 1))
	local colors = type(appearance.colors) == "table" and appearance.colors or {}

	self.frame:SetAlpha(overallAlpha)
	local panels = {
		{ frame = self.frame, part = "window" },
		{ frame = self.header, part = "title" },
		{ frame = self.tabStrip, part = "tabs" },
		{ frame = self.content, part = "chat" },
		{ frame = self.composer, part = "reply" },
		-- Confirmation keeps its danger palette, but opacity still follows the
		-- Messenger so it never appears as a disconnected opaque card.
		{ frame = self.confirm },
	}
	local borderR, borderG, borderB, borderA = resolveAppearanceColor(colors.border)
	for index = 1, #panels do
		local panel = panels[index].frame
		if panel then
			if Theme.SetFrameOpacity then
				Theme:SetFrameOpacity(panel, backgroundAlpha, borderAlpha)
			elseif Theme.ApplyFrame and Theme.frames and Theme.frames[panel] then
				local style = Theme.frames[panel]
				Theme:ApplyFrame(panel, style.fill, style.border)
			end
			local part = panels[index].part
			local fillR, fillG, fillB, fillA = resolveAppearanceColor(part and colors[part] or nil)
			if fillR and panel.SetBackdropColor then
				panel:SetBackdropColor(fillR, fillG, fillB, (fillA or 1) * backgroundAlpha)
			end
			if part and borderR and panel.SetBackdropBorderColor then
				panel:SetBackdropBorderColor(borderR, borderG, borderB, (borderA or 1) * borderAlpha)
			end
		end
	end

	-- SetAlpha multiplies the existing semantic/class/hyperlink colors instead
	-- of replacing them. Message meaning therefore survives a quieter text
	-- setting, and WHOLE UI remains a separate outer-frame multiplier.
	local texts = {}
	local function addText(region)
		if region then texts[#texts + 1] = region end
	end
	addText(self.title)
	addText(self.subtitle)
	addText(self.close and self.close.label)
	addText(self.empty)
	addText(self.route)
	addText(self.placeholder)
	addText(self.tabPrevious and self.tabPrevious.text)
	addText(self.tabNext and self.tabNext.text)
	addText(self.actionToggle and self.actionToggle.text)
	addText(self.newButton and self.newButton.text)
	addText(self.send and self.send.text)
	addText(self.scrollToBottomGlyph)
	addText(self.confirmTitle)
	addText(self.confirmText)
	addText(self.confirmCancel and self.confirmCancel.text)
	addText(self.confirmAccept and self.confirmAccept.text)
	for index = 1, #(self.actionButtons or {}) do
		addText(self.actionButtons[index].text)
	end
	for index = 1, #(self.tabPool or {}) do
		local tab = self.tabPool[index]
		addText(tab.text)
		addText(tab.badge)
		addText(tab.close and tab.close.label)
	end
	for index = 1, #texts do
		local region = texts[index]
		if region and region.SetAlpha then region:SetAlpha(textAlpha) end
	end
	if self.display and self.display.SetAlpha then self.display:SetAlpha(textAlpha) end
	if self.editBox and self.editBox.SetAlpha then self.editBox:SetAlpha(textAlpha) end
	return true
end

function Window:GetVisibilityState()
	local settings = getConversationSettings()
	local hovered = self.hovered == true
	local focused = self.editBox and self.editBox.HasFocus and self.editBox:HasFocus() or false
	local titleMode = resolveVisibilityMode(settings.titleBarVisibility, settings)
	local actionMode = resolveVisibilityMode(settings.actionVisibility, settings)
	local composerMode = resolveVisibilityMode(settings.composerVisibility, settings)
	local function visible(mode, transient)
		if transient then
			return true
		end
		if mode == "always" then
			return true
		end
		if mode == "auto" then
			return hovered
		end
		return mode == "click" and self.clickChromeRevealed == true or false
	end
	local actionsCollapsed = isActionStripCollapsed()
	if actionMode == "collapsed" then
		actionsCollapsed = self.transientActionsExpanded ~= true
	end
	return {
		titleMode = titleMode,
		actionMode = actionMode,
		composerMode = composerMode,
		actionOrientation = getActionStripOrientation(),
		actionsCollapsed = actionsCollapsed,
		title = visible(titleMode),
		actions = actionMode == "collapsed" or visible(actionMode),
		composer = visible(composerMode, focused or self.transientComposer == true),
	}
end

function Window:HasClickVisibilityMode()
	local settings = getConversationSettings()
	return resolveVisibilityMode(settings.titleBarVisibility, settings) == "click"
		or resolveVisibilityMode(settings.actionVisibility, settings) == "click"
		or resolveVisibilityMode(settings.composerVisibility, settings) == "click"
end

function Window:ToggleClickChrome()
	if not self:HasClickVisibilityMode() then
		return false
	end
	self.clickChromeRevealed = not self.clickChromeRevealed
	self:ApplyChromeLayout(true)
	return self.clickChromeRevealed
end

function Window:SetActionStripCollapsed(collapsed)
	collapsed = collapsed and true or false
	if type(addon.SetMessengerActionStripCollapsed) == "function" then
		addon:SetMessengerActionStripCollapsed(collapsed)
	else
		getConversationSettings().actionStripCollapsed = collapsed
		self:ApplyChromeLayout(true)
	end
	return collapsed
end

function Window:ToggleActionStrip()
	local settings = getConversationSettings()
	if resolveVisibilityMode(settings.actionVisibility, settings) == "collapsed" then
		self.transientActionsExpanded = not self.transientActionsExpanded
		self:ApplyChromeLayout(true)
		return self.transientActionsExpanded
	end
	return self:SetActionStripCollapsed(not isActionStripCollapsed())
end

function Window:UpdateRouteLabel(session)
	local label = "TO"
	if session and session.playerName then
		label = "TO " .. compactName(session.playerName)
	end
	self.route:SetText(label)
	local measured = self.route.GetStringWidth and self.route:GetStringWidth() or (string.len(label) * 6)
	self.route:SetWidth(math.max(16, math.min(112, math.ceil(tonumber(measured) or 16))))
	self.editBox:ClearAllPoints()
	self.editBox:SetPoint("LEFT", self.route, "RIGHT", 4, 0)
	self.editBox:SetPoint("RIGHT", self.send, "LEFT", -3, 0)
end

function Window:ApplyChromeLayout(force)
	if not self.frame or not self.tabStrip or not self.content or not self.composer then
		return
	end
	local state = self:GetVisibilityState()
	local modeSignature = table.concat({ state.titleMode, state.actionMode, state.composerMode }, ":")
	if self.visibilityModeSignature and self.visibilityModeSignature ~= modeSignature then
		self.clickChromeRevealed = false
		self.transientActionsExpanded = false
		state = self:GetVisibilityState()
	end
	self.visibilityModeSignature = modeSignature
	local previous = self.visibilityState
	if not force and previous
		and previous.title == state.title
		and previous.actions == state.actions
		and previous.composer == state.composer
		and previous.actionOrientation == state.actionOrientation
		and previous.actionsCollapsed == state.actionsCollapsed then
		return
	end
	self.visibilityState = state
	local actionsExpanded = state.actions and not state.actionsCollapsed
	local sizingWidth = math.max(1, (self.frame:GetWidth() or 300) - 4)
	self:RefreshActionButtonSizing(state, sizingWidth)
	local sideInset = actionsExpanded and state.actionOrientation == "vertical"
		and ((tonumber(self.actionWidth) or 24) + 3) or 0

	self.header:ClearAllPoints()
	self.header:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 2, -2)
	self.header:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -2 - sideInset, -2)
	if state.title then
		self.header:Show()
	else
		self.header:Hide()
	end

	self.tabStrip:ClearAllPoints()
	if state.title then
		self.tabStrip:SetPoint("TOPLEFT", self.header, "BOTTOMLEFT", 0, -2)
		self.tabStrip:SetPoint("TOPRIGHT", self.header, "BOTTOMRIGHT", 0, -2)
	else
		self.tabStrip:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 2, -2)
		self.tabStrip:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -2 - sideInset, -2)
	end

	self.close:ClearAllPoints()
	if self.close.SetParent then
		self.close:SetParent(state.title and self.header or self.tabStrip)
	end
	self.close:SetPoint("RIGHT", state.title and self.header or self.tabStrip, "RIGHT", -3, 0)
	if self.close.SetFrameLevel then
		local parent = state.title and self.header or self.tabStrip
		self.close:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 1) + 3)
	end
	self.close:Show()

	if self.actionToggle then
		if state.actions then
			self.actionToggle:Show()
			self.actionToggle:SetLabel(state.actionsCollapsed and "+" or "-")
			if self.actionToggle.SetTooltip then
				self.actionToggle:SetTooltip("Player actions", state.actionMode == "collapsed"
					and "Temporarily show or hide Reply, Invite, Friend, Mute, and Block. This policy always starts collapsed."
					or "Show or hide Reply, Invite, Friend, Mute, and Block. The choice is saved.")
			end
		else
			self.actionToggle:Hide()
		end
	end
	if actionsExpanded then
		if self.actions.SetParent then
			self.actions:SetParent(state.actionOrientation == "vertical" and self.frame or self.tabStrip)
		end
		self.actions:ClearAllPoints()
		if state.actionOrientation == "vertical" then
			self.actions:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -2, -2)
			self.actions:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -2, 2)
			self.actions:SetWidth(tonumber(self.actionWidth) or 24)
		end
		self.actions:Show()
	else
		self.actions:Hide()
	end

	self.content:ClearAllPoints()
	self.content:SetPoint("TOPLEFT", self.tabStrip, "BOTTOMLEFT", 0, -2)
	self.composer:ClearAllPoints()
	self.composer:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 2, 2)
	self.composer:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -2 - sideInset, 2)
	if state.composer then
		self.composer:Show()
		self.content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -2 - sideInset, 28)
	else
		self.composer:Hide()
		self.content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -2 - sideInset, 2)
	end
	if self.grip then
		self.grip:ClearAllPoints()
		self.grip:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -2 - sideInset, -1)
	end

	self:RefreshTabs()
	self:RefreshAppearance()
end

function Window:RefreshHoverState()
	local hovered = isFrameHovered(self.frame)
	if hovered ~= self.hovered then
		self.hovered = hovered
		self:ApplyChromeLayout(false)
	end
end

function Window:RevealComposer(focus)
	self.transientComposer = true
	self:Show()
	self:ApplyChromeLayout(true)
	if focus and self.playerName and not isLocallyIgnored(self.playerName) then
		self.editBox:SetFocus()
	end
end

function Window:UpdateComposerForSession(session)
	if not session then
		self.editBox:SetText("")
		self.placeholder:Show()
		self:UpdateRouteLabel(nil)
		return
	end

	self.editBox:SetText(session.draft or "")
	self.editBox:ClearFocus()
	self:UpdateRouteLabel(session)
	if trim(session.draft or "") == "" then
		self.placeholder:Show()
	else
		self.placeholder:Hide()
	end
end

function Window:SelectSession(session)
	if not session then
		return
	end

	local previous = self:GetActiveSession()
	if previous and self.editBox then
		previous.draft = self.editBox:GetText() or ""
	end

	self.playerName = session.playerName
	self.playerKey = session.playerKey
	self.transientActionsExpanded = false
	self.lastUsed = now()
	session.lastUsed = self.lastUsed
	session.unread = 0
	self.title:SetText(session.playerName)
	self.subtitle:SetText("MESSENGER")
	self.confirm:Hide()
	self:UpdateComposerForSession(session)
	self:RenderSession(session)
	-- A selected/new conversation must never be hidden beyond a crowded tab
	-- strip.  Starting its viewport at this tab is compact and deterministic.
	for index = 1, #(Manager.tabOrder or {}) do
		if Manager.tabOrder[index] == session.playerKey then
			self.tabOffset = index
			break
		end
	end
	self:ApplyChromeLayout(true)
end

function Window:Show(record)
	self.lastUsed = now()
	if not self.frame:IsShown() then
		self:RebuildHistory()
		self.frame:Show()
	elseif record then
		self:AddRecord(record)
	end
	self:ApplyChromeLayout(true)
	self.frame:Raise()
end

function Window:Hide()
	if Manager.pendingComposerFocusKey == self.playerKey then
		Manager:CancelQueuedComposerFocus()
	end
	self.transientComposer = false
	self.clickChromeRevealed = false
	self.transientActionsExpanded = false
	self.editBox:ClearFocus()
	self.confirm:Hide()
	self.frame:Hide()
	self.lastUsed = now()
end

function Window:FocusComposer()
	if self.playerName and not isLocallyIgnored(self.playerName) then
		self:RevealComposer(true)
	end
end

function Window:Send()
	local session = self:GetActiveSession()
	if not session or not self.playerName or isLocallyIgnored(self.playerName) then
		return
	end
	local retainFocus = self.editBox and self.editBox.HasFocus and self.editBox:HasFocus() or false
	local sentPlayerKey = self.playerKey
	local sentPlayerName = self.playerName

	local message = trim(self.editBox:GetText())
	if message == "" then
		self.editBox:SetFocus()
		return
	end

	if not SendChatMessage then
		printStatus("Whisper sending is unavailable on this client.")
		return
	end

	local ok, err = pcall(SendChatMessage, message, "WHISPER", nil, sentPlayerName)
	if not ok then
		printStatus("Could not whisper " .. sentPlayerName .. ": " .. tostring(err))
		return
	end

	session.draft = ""
	-- A synchronous chat hook may select another Messenger tab. The whisper was
	-- still sent to the captured target, but the shared edit box now belongs to
	-- the new session and must not be cleared or focused by the old send.
	if self:GetActiveSession() ~= session or self.playerKey ~= sentPlayerKey then
		return
	end
	self.editBox:SetText("")
	-- Enter means the player is continuing this conversation. Keep the reply
	-- field active after a successful send, including when REPLY or /r had
	-- temporarily revealed an otherwise-hidden composer. A mouse-only send from
	-- an unfocused field must not steal keyboard focus.
	self.transientComposer = retainFocus
	if retainFocus then
		self.placeholder:Hide()
	else
		self.placeholder:Show()
	end
	self:ApplyChromeLayout(true)
	if retainFocus then self.editBox:SetFocus() end
end

function Window:ApplyLocalIgnore()
	if not self.playerName then
		return
	end
	local settings = addon:GetSmartSettings()
	settings.safety = settings.safety or {}
	settings.safety.localIgnores = settings.safety.localIgnores or {}
	settings.safety.localIgnores[playerKey(self.playerName)] = true
	printStatus(self.playerName .. " is now hidden by ChattyChattyBangBang local ignore.")
	Manager:Close(self.playerKey)
	if addon.SmartDock and addon.SmartDock.RebuildActiveView then
		addon.SmartDock:RebuildActiveView()
	end
end

function Window:ApplyServerIgnore()
	if self.playerName and addon.Compatibility and addon.Compatibility.AddServerIgnore then
		addon.Compatibility:AddServerIgnore(self.playerName)
	end
	self.confirm:Hide()
	Manager:Close(self.playerKey)
end

function Window:ShowServerIgnoreConfirmation()
	local settings = addon:GetSmartSettings()
	if self.playerName and settings.safety and settings.safety.confirmServerIgnore then
		self.confirmText:SetText("Add " .. self.playerName .. " to the actual WoW ignore list?")
		self.confirm:Show()
		self.confirm:SetFrameLevel(self.frame:GetFrameLevel() + 40)
	else
		self:ApplyServerIgnore()
	end
end

function Window:CreateTab(session)
	local tab = Theme:CreateButton(self.tabStrip, "", 50, 18, false)
	tab:SetHeight(18)
	tab.session = session
	tab.text:ClearAllPoints()
	tab.text:SetPoint("LEFT", tab, "LEFT", 4, 0)
	tab.text:SetJustifyH("LEFT")

	local badge = Theme:CreateText(tab, "GameFontNormalSmall", "goldBright")
	badge:SetPoint("RIGHT", tab, "RIGHT", -16, 0)
	badge:SetJustifyH("RIGHT")
	tab.badge = badge

	local close = CreateFrame("Button", nil, tab)
	close:SetSize(11, 14)
	close:SetPoint("RIGHT", tab, "RIGHT", -2, 0)
	close.label = Theme:CreateText(close, "GameFontNormalSmall", "textMuted")
	close.label:SetPoint("CENTER", close, "CENTER", 0, 0)
	close.label:SetText("x")
	close:SetScript("OnEnter", function()
		local r, g, b, a = Theme:GetColor("danger")
		close.label:SetTextColor(r, g, b, a)
	end)
	close:SetScript("OnLeave", function()
		local r, g, b, a = Theme:GetColor("textMuted")
		close.label:SetTextColor(r, g, b, a)
	end)
	close:SetScript("OnClick", function()
		Manager:Close(session.playerKey)
	end)
	tab.close = close

	tab:SetScript("OnClick", function()
		Manager:SelectSession(session.playerKey)
	end)

	session.tab = tab
	self.tabPool[#self.tabPool + 1] = tab
	self:RefreshAppearance()
	return tab
end

function Window:GetTabLabelAvailableWidth(tab, tabWidth)
	tabWidth = math.max(0, tonumber(tabWidth) or (tab and tab:GetWidth()) or 0)
	local badgeWidth = tab and tonumber(tab.badgeWidth) or 0
	local fixedWidth
	if badgeWidth > 0 then
		-- The badge's right inset also reserves the close x and the visible
		-- gutter between those two independent hit/read targets.
		fixedWidth = TAB_TEXT_LEFT_INSET + TAB_TEXT_CONTROL_GAP
			+ badgeWidth + TAB_BADGE_RIGHT_INSET
	else
		fixedWidth = TAB_TEXT_LEFT_INSET + TAB_TEXT_CONTROL_GAP
			+ TAB_CLOSE_WIDTH + TAB_CLOSE_RIGHT_INSET
	end
	return math.max(0, tabWidth - fixedWidth), fixedWidth
end

function Window:FitTabLabel(session, tab, tabWidth, maximumLength, marker)
	if not session or not tab then
		return "", false
	end

	local fullName = tostring(session.playerName or "")
	if maximumLength == nil or marker == nil then
		maximumLength, marker = getTabNamePolicy()
	end
	local markerLength = utf8CharacterCount(marker)
	local preferredLabel, shortened = truncateTabNameByCharacters(fullName, maximumLength, marker)
	local availableWidth = self:GetTabLabelAvailableWidth(tab, tabWidth)
	local label = preferredLabel
	local measuredWidth = measureTabLabel(tab, label)

	if measuredWidth > availableWidth then
		local fullLength = utf8CharacterCount(fullName)
		local prefixLength = math.min(fullLength - markerLength, maximumLength - markerLength)
		shortened = true
		while prefixLength >= 0 do
			label = utf8Prefix(fullName, prefixLength) .. marker
			measuredWidth = measureTabLabel(tab, label)
			if measuredWidth <= availableWidth then
				break
			end
			prefixLength = prefixLength - 1
		end
		if prefixLength < 0 then
			label = ""
			measuredWidth = measureTabLabel(tab, label)
		end
	end

	tab.preferredLabel = preferredLabel
	tab.visibleLabel = label
	tab.fullPlayerName = fullName
	tab.nameShortened = shortened
	tab.labelAvailableWidth = availableWidth
	tab.labelMeasuredWidth = measuredWidth
	if tab.SetTooltip then
		if shortened then
			tab:SetTooltip(fullName, marker .. " marks a shortened name.")
		else
			tab:SetTooltip(nil, nil)
		end
	end
	return label, shortened
end

function Window:UpdateTab(session, maximumLength, marker)
	local tab = session.tab or self:CreateTab(session)
	local unread = tonumber(session.unread) or 0
	if unread > 0 then
		local badgeLabel = unread > 99 and "99+" or tostring(unread)
		tab.badge:SetText(badgeLabel)
		tab.badge:Show()
		tab.text:ClearAllPoints()
		tab.text:SetPoint("LEFT", tab, "LEFT", TAB_TEXT_LEFT_INSET, 0)
		tab.text:SetPoint("RIGHT", tab.badge, "LEFT", -TAB_TEXT_CONTROL_GAP, 0)
		local measuredBadge = tab.badge.GetStringWidth and tab.badge:GetStringWidth() or nil
		tab.badgeWidth = math.max(1, math.ceil(tonumber(measuredBadge)
			or (utf8CharacterCount(badgeLabel) * 6)))
	else
		tab.badge:SetText("")
		tab.badge:Hide()
		tab.text:ClearAllPoints()
		tab.text:SetPoint("LEFT", tab, "LEFT", TAB_TEXT_LEFT_INSET, 0)
		tab.text:SetPoint("RIGHT", tab.close, "LEFT", -TAB_TEXT_CONTROL_GAP, 0)
		tab.badgeWidth = 0
	end

	if maximumLength == nil or marker == nil then
		maximumLength, marker = getTabNamePolicy()
	end
	local preferredLabel = truncateTabNameByCharacters(session.playerName, maximumLength, marker)
	local textWidth = measureTabLabel(tab, preferredLabel)
	local _, fixedWidth = self:GetTabLabelAvailableWidth(tab, 0)
	local markerWidth = measureTabLabel(tab, marker)
	tab.minimumWidth = math.max(TAB_MINIMUM_WIDTH, math.ceil(markerWidth) + fixedWidth)
	tab.naturalWidth = math.max(tab.minimumWidth, math.ceil(textWidth) + fixedWidth)
	tab:SetWidth(tab.naturalWidth)
	self:FitTabLabel(session, tab, tab.naturalWidth, maximumLength, marker)
	if session.playerKey == self.playerKey then
		tab:SetTheme("accentSoft", "gold", "goldBright")
	else
		tab:SetTheme("surface", "borderMuted", "textMuted")
	end
end

function Window:RefreshActionButtonSizing(state, stripWidth)
	state = state or self.visibilityState or self:GetVisibilityState()
	stripWidth = tonumber(stripWidth) or 0
	local orientation = state.actionOrientation == "vertical" and "vertical" or "horizontal"
	self:UpdateActionButtons(false, orientation)

	local compact = false
	if state.actions and not state.actionsCollapsed and orientation == "horizontal"
		and getActionButtonStyle() == "text" then
		-- Reserve one maximum-width player tab and, when siblings exist, both
		-- pager controls. Unlike a fixed pixel breakpoint, this responds to the
		-- live font metrics, hidden-header close button, and action-label widths.
		local tabReserve = TAB_MINIMUM_WIDTH
		for index = 1, #(Manager.tabOrder or {}) do
			local session = Manager.sessionsByKey[Manager.tabOrder[index]]
			local tab = session and session.tab
			tabReserve = math.max(tabReserve,
				tonumber(tab and tab.naturalWidth) or tonumber(tab and tab:GetWidth()) or 0)
		end
		local pagerReserve = #(Manager.tabOrder or {}) > 1 and (38 + 4) or 4
		local required = 2 + tabReserve + pagerReserve
		if not state.title then
			required = required + 18
		end
		if self.actionToggle then
			required = required + (self.actionToggle:GetWidth() or 18) + 3
		end
		required = required + (tonumber(self.actionWidth) or 0) + 3
		compact = stripWidth < required
		if compact then
			self:UpdateActionButtons(true, orientation)
		end
	end
	self.actionsCompactForWidth = compact
	return compact
end

function Window:RefreshTabs()
	local order = Manager.tabOrder or {}
	-- One normalized policy snapshot is enough for every tab in this layout pass.
	-- GetSmartSettings performs profile normalization, so repeating it for every
	-- label/pixel-fit would make each incoming whisper needlessly expensive.
	local maximumLength, marker = getTabNamePolicy()
	for index = 1, #order do
		local session = Manager.sessionsByKey[order[index]]
		if session then
			self:UpdateTab(session, maximumLength, marker)
		end
	end

	local stripWidth = self.tabStrip:GetWidth()
	if not stripWidth or stripWidth < 1 then
		stripWidth = self.frame:GetWidth() - 4
	end
	local state = self.visibilityState or self:GetVisibilityState()
	local actionsExpanded = state.actions and not state.actionsCollapsed
	self:RefreshActionButtonSizing(state, stripWidth)
	local closeOnStrip = not state.title
	local rightReserve = 2
	local rightAnchor = self.tabStrip
	local rightAnchorPoint = "RIGHT"
	if closeOnStrip then
		rightReserve = rightReserve + 18
		rightAnchor = self.close
		rightAnchorPoint = "LEFT"
	end
	if state.actions and self.actionToggle then
		self.actionToggle:ClearAllPoints()
		self.actionToggle:SetPoint("RIGHT", rightAnchor, rightAnchorPoint, -3, 0)
		rightReserve = rightReserve + (self.actionToggle:GetWidth() or 18) + 3
		rightAnchor = self.actionToggle
		rightAnchorPoint = "LEFT"
	end
	if actionsExpanded and state.actionOrientation == "horizontal" then
		self.actions:ClearAllPoints()
		self.actions:SetPoint("RIGHT", rightAnchor, rightAnchorPoint, -3, 0)
		rightReserve = rightReserve + (tonumber(self.actionWidth) or 0) + 3
		rightAnchor = self.actions
		rightAnchorPoint = "LEFT"
	end
	self.tabNext:ClearAllPoints()
	self.tabNext:SetPoint("RIGHT", rightAnchor, rightAnchorPoint, -2, 0)

	if #order == 0 then
		self.tabPrevious:Hide()
		self.tabNext:Hide()
		return
	end

	local total = 2
	for index = 1, #order do
		local session = Manager.sessionsByKey[order[index]]
		if session and session.tab then
			total = total + session.tab:GetWidth() + 2
		end
	end

	-- A single tab can be shortened in place; showing inactive < / > controls
	-- would only steal more of its label lane. Pagers exist to reach siblings.
	local controlsVisible = #order > 1 and total > (stripWidth - rightReserve)
	local available = stripWidth - rightReserve - (controlsVisible and 38 or 4)
	available = math.max(40, available)
	self.tabAvailableWidth = available
	if controlsVisible then
		self.tabPrevious:Show()
		self.tabNext:Show()
	else
		self.tabPrevious:Hide()
		self.tabNext:Hide()
	end

	self.tabOffset = math.max(1, math.min(self.tabOffset or 1, #order))
	local used = 0
	local previous
	for index = 1, #order do
		local session = Manager.sessionsByKey[order[index]]
		local tab = session and session.tab
		if tab then
			tab:Hide()
			if index >= self.tabOffset then
				local naturalWidth = tonumber(tab.naturalWidth) or tab:GetWidth()
				local minimumWidth = math.min(available,
					tonumber(tab.minimumWidth) or TAB_MINIMUM_WIDTH)
				local leadingGap = previous and 2 or 0
				local remaining = math.max(0, available - used - leadingGap)
				local fittedWidth = math.min(naturalWidth, remaining)
				local nextWidth = fittedWidth + leadingGap
				if (not previous) or (fittedWidth >= minimumWidth and used + nextWidth <= available) then
					local appliedWidth = math.max(minimumWidth, fittedWidth)
					tab:SetWidth(appliedWidth)
					self:FitTabLabel(session, tab, appliedWidth, maximumLength, marker)
					tab:ClearAllPoints()
					if previous then
						tab:SetPoint("LEFT", previous, "RIGHT", 2, 0)
					else
						tab:SetPoint("LEFT", self.tabStrip, "LEFT", controlsVisible and 20 or 2, 0)
					end
					tab:Show()
					previous = tab
					used = used + appliedWidth + leadingGap
				end
			end
		end
	end

	self.tabPrevious:SetAlpha(self.tabOffset > 1 and 1 or 0.45)
	self.tabNext:SetAlpha(previous and previous ~= (Manager.sessionsByKey[order[#order]] and Manager.sessionsByKey[order[#order]].tab) and 1 or 0.45)
end

function Window:MoveTabOffset(delta)
	local count = #(Manager.tabOrder or {})
	self.tabOffset = math.max(1, math.min(count, (self.tabOffset or 1) + delta))
	self:RefreshTabs()
end

function Window:EnsureTabVisible(key)
	for index = 1, #(Manager.tabOrder or {}) do
		if Manager.tabOrder[index] == key then
			self.tabOffset = index
			self:RefreshTabs()
			return true
		end
	end
	return false
end

function Window:UpdateActionButtons(forceIcons, orientation)
	orientation = orientation == "vertical" and "vertical" or "horizontal"
	local style = getActionButtonStyle()
	local useIcons = style == "icons" or forceIcons == true
	local totalWidth = 0
	local totalHeight = 0
	local maximumWidth = 0
	for index = 1, #self.actionButtons do
		local button = self.actionButtons[index]
		local definition = button.definition
		button.usesIcon = useIcons
		if useIcons then
			button:SetWidth(20)
			button:SetLabel("")
			button.text:Hide()
			setActionIconState(button, "normal")
		else
			button.text:Show()
			button.icon:Hide()
			setTightButtonLabel(button, definition.label)
		end
		button:Show()
		local buttonWidth = button.GetWidth and button:GetWidth() or 20
		local buttonHeight = button.GetHeight and button:GetHeight() or 18
		maximumWidth = math.max(maximumWidth, buttonWidth)
		if orientation == "horizontal" then
			totalWidth = totalWidth + buttonWidth
			if index > 1 then
				totalWidth = totalWidth + 2
			end
		else
			totalHeight = totalHeight + buttonHeight
			if index > 1 then
				totalHeight = totalHeight + 3
			end
		end
	end

	local previous
	for index = 1, #self.actionButtons do
		local button = self.actionButtons[index]
		button:ClearAllPoints()
		if orientation == "vertical" then
			button:SetWidth(maximumWidth)
			if previous then
				button:SetPoint("TOP", previous, "BOTTOM", 0, -3)
			else
				button:SetPoint("TOP", self.actions, "TOP", 0, -4)
			end
		elseif previous then
			button:SetPoint("LEFT", previous, "RIGHT", 2, 0)
		else
			button:SetPoint("LEFT", self.actions, "LEFT", 2, 0)
		end
		previous = button
	end
	self.actionWidth = (orientation == "vertical" and maximumWidth or totalWidth) + 4
	self.actionHeight = (orientation == "vertical" and totalHeight or 16) + 4
	self.actions:SetWidth(self.actionWidth)
	self.actions:SetHeight(self.actionHeight)
end

function Window:OnThemeRefresh()
	self.actionsCompactForWidth = nil
	self:ApplyChromeLayout(true)
	if self.frame:IsShown() then
		self:RebuildHistory()
	end
	self:RefreshMessageScrollbar(true)
	self:RefreshAppearance()
end

function Window:Reset()
	self:Hide()
	self.hovered = false
	self.clickChromeRevealed = false
	self.transientActionsExpanded = false
	self.visibilityModeSignature = nil
	self.transientComposer = false
	self.playerName = nil
	self.playerKey = nil
	self.lastUsed = now()
	self.title:SetText("Messenger")
	self.subtitle:SetText("PRIVATE")
	self.display:Clear()
	self.empty:SetText("Choose a Messenger tab to begin.")
	self.empty:Show()
	self.newButton:Hide()
	self.editBox:SetText("")
	self.placeholder:Show()
	self:UpdateRouteLabel(nil)
	self.tabOffset = 1
	for index = 1, #self.tabPool do
		self.tabPool[index]:Hide()
	end
end

function Manager:BuildWindow()
	local window = setmetatable({ tabPool = {}, tabOffset = 1 }, Window)

	local frame = Theme:CreatePanel(UIParent, "background", "border")
	frame:SetSize(360, 250)
	frame:SetMinResize(300, 160)
	frame:SetMaxResize(620, 500)
	frame:SetResizable(true)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:Hide()
	window.frame = frame

	frame:SetScript("OnMouseDown", function()
		frame:Raise()
	end)
	frame:SetScript("OnShow", function()
		window:ApplyChromeLayout(true)
	end)
	frame:SetScript("OnUpdate", function(_, elapsed)
		window.hoverElapsed = (window.hoverElapsed or 0) + (tonumber(elapsed) or 0)
		if window.hoverElapsed >= 0.08 then
			window.hoverElapsed = 0
			window:RefreshHoverState()
		end
	end)

	local header = Theme:CreatePanel(frame, "surfaceRaised", "gold")
	header:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
	header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
	header:SetHeight(24)
	window.header = header
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	header:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		window:SavePosition()
	end)

	local icon = header:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(Theme.ICON_PATH)
	icon:SetSize(16, 16)
	icon:SetPoint("LEFT", header, "LEFT", 3, 0)

	local title = Theme:CreateText(header, "GameFontNormalSmall", "goldBright")
	title:SetPoint("LEFT", icon, "RIGHT", 4, 0)
	title:SetPoint("RIGHT", header, "RIGHT", -68, 0)
	title:SetJustifyH("LEFT")
	title:SetText("Messenger")
	window.title = title

	local subtitle = Theme:CreateText(header, "GameFontHighlightSmall", "textMuted")
	subtitle:SetPoint("RIGHT", header, "RIGHT", -24, 0)
	subtitle:SetWidth(58)
	subtitle:SetJustifyH("RIGHT")
	subtitle:SetText("PRIVATE")
	window.subtitle = subtitle

	-- The shell close is deliberately bare text. It follows the surviving top
	-- rail when the title is hidden instead of leaving behind a boxed orphan.
	local close = CreateFrame("Button", nil, header)
	close:SetSize(14, 18)
	close.label = Theme:CreateText(close, "GameFontNormalSmall", "textMuted")
	close.label:SetPoint("CENTER", close, "CENTER", 0, 0)
	close.label:SetText("x")
	close:SetScript("OnEnter", function()
		local r, g, b, a = Theme:GetColor("danger")
		close.label:SetTextColor(r, g, b, a)
	end)
	close:SetScript("OnLeave", function()
		local r, g, b, a = Theme:GetColor("textMuted")
		close.label:SetTextColor(r, g, b, a)
	end)
	close:SetScript("OnClick", function()
		-- Header close hides the shell but preserves the tab sessions for the
		-- next whisper.  Individual tab x buttons close one conversation.
		window:Hide()
	end)
	window.close = close

	local tabStrip = Theme:CreatePanel(frame, "surface", "borderMuted")
	tabStrip:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
	tabStrip:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -2)
	tabStrip:SetHeight(20)
	window.tabStrip = tabStrip
	tabStrip:EnableMouse(true)
	tabStrip:RegisterForDrag("LeftButton")
	tabStrip:SetScript("OnDragStart", function(self)
		if window.visibilityState and not window.visibilityState.title
			and (not GetMouseFocus or GetMouseFocus() == self) then
			frame:StartMoving()
		end
	end)
	tabStrip:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		window:SavePosition()
	end)

	local tabPrevious = Theme:CreateTightButton(tabStrip, "<", 16, false)
	tabPrevious:SetPoint("LEFT", tabStrip, "LEFT", 2, 0)
	tabPrevious:SetScript("OnClick", function()
		window:MoveTabOffset(-1)
	end)
	window.tabPrevious = tabPrevious

	local tabNext = Theme:CreateTightButton(tabStrip, ">", 16, false)
	tabNext:SetPoint("RIGHT", tabStrip, "RIGHT", -2, 0)
	tabNext:SetScript("OnClick", function()
		window:MoveTabOffset(1)
	end)
	window.tabNext = tabNext

	-- This is deliberately separate from the < / > tab pager. It is always a
	-- compact, obvious control for the selected player's social-action strip.
	local actionToggle = Theme:CreateTightButton(tabStrip, "+", 18, false)
	actionToggle:SetWidth(18)
	actionToggle:SetScript("OnClick", function()
		window:ToggleActionStrip()
	end)
	if actionToggle.SetTooltip then
		actionToggle:SetTooltip("Player actions", "Show or hide Reply, Invite, Friend, Mute, and Block. The choice is saved.")
	end
	window.actionToggle = actionToggle

	tabStrip:SetScript("OnSizeChanged", function()
		window:RefreshTabs()
	end)

	-- Context actions share the tab rail; no second boxed toolbar or vertical
	-- lane is spent on controls that only affect the selected conversation.
	local actions = CreateFrame("Frame", nil, tabStrip)
	actions:SetHeight(20)
	window.actions = actions
	window.actionButtons = {}

	local actionDefinitions = {
		{
			label = "REPLY",
			tooltip = "Focus the reply field",
			glyph = ">",
			iconName = "reply",
			callback = function()
				window:FocusComposer()
			end,
		},
		{
			label = "INVITE",
			tooltip = "Invite this player to your group",
			glyph = "+",
			iconName = "invite",
			callback = function()
				if addon.Compatibility and window.playerName then
					addon.Compatibility:InvitePlayer(window.playerName)
				end
			end,
		},
		{
			label = "FRIEND",
			tooltip = "Add this player as a friend",
			glyph = "F",
			iconName = "friend",
			callback = function()
				if addon.Compatibility and window.playerName then
					addon.Compatibility:AddFriend(window.playerName)
				end
			end,
		},
		{
			label = "MUTE",
			tooltip = "Hide this player in ChattyChattyBangBang",
			glyph = "M",
			iconName = "localIgnore",
			callback = function()
				window:ApplyLocalIgnore()
			end,
		},
		{
			label = "BLOCK",
			tooltip = "Add this player to the WoW ignore list",
			glyph = "!",
			iconName = "serverIgnore",
			callback = function()
				window:ShowServerIgnoreConfirmation()
			end,
		},
	}
	for index = 1, #actionDefinitions do
		local definition = actionDefinitions[index]
		local button = Theme:CreateTightButton(actions, definition.label, 18, index == 1)
		button.definition = definition
		button.icon = button:CreateTexture(nil, "OVERLAY")
		button.icon:SetSize(14, 14)
		button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
		button.icon:Hide()
		button:HookScript("OnEnter", function(self)
			setActionIconState(self, "hover")
		end)
		button:HookScript("OnLeave", function(self)
			setActionIconState(self, "normal")
		end)
		button:HookScript("OnMouseDown", function(self)
			setActionIconState(self, "pressed")
		end)
		button:HookScript("OnMouseUp", function(self)
			setActionIconState(self, "hover")
		end)
		button:SetScript("OnClick", function()
			definition.callback()
			local settings = getConversationSettings()
			if resolveVisibilityMode(settings.actionVisibility, settings) == "collapsed" then
				window.transientActionsExpanded = false
				window:ApplyChromeLayout(true)
			end
		end)
		addTooltip(button, definition.tooltip)
		window.actionButtons[#window.actionButtons + 1] = button
	end
	window:UpdateActionButtons()

	local content = Theme:CreatePanel(frame, "inset", "borderMuted")
	content:EnableMouse(true)
	window.content = content

	local display = CreateFrame("ScrollingMessageFrame", nil, content)
	display:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -4)
	display:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -18, 4)
	display:SetFontObject(ChatFontNormal)
	display:SetJustifyH("LEFT")
	display:SetFading(false)
	display:SetInsertMode("BOTTOM")
	display:SetMaxLines(MAX_HISTORY)
	display:SetSpacing(1)
	display:SetHyperlinksEnabled(true)
	display:EnableMouse(true)
	display:EnableMouseWheel(true)
	display:SetScript("OnMouseWheel", function(_, delta)
		if delta > 0 then
			display:ScrollUp()
		else
			display:ScrollDown()
		end
		if display:AtBottom() then
			local session = window:GetActiveSession()
			if session then
				session.pendingVisible = 0
			end
			window:UpdateNewButton()
		end
		window:RefreshMessageScrollbar(false)
	end)
	display:SetScript("OnHyperlinkClick", function(_, link, text, button)
		if ChatFrame_OnHyperlinkShow then
			ChatFrame_OnHyperlinkShow(display, link, text, button)
		elseif SetItemRef then
			SetItemRef(link, text, button)
		end
	end)
	display:SetScript("OnHyperlinkEnter", function()
		window.hoveredHyperlink = true
	end)
	display:SetScript("OnHyperlinkLeave", function()
		window.hoveredHyperlink = false
	end)
	local function toggleClickChrome(_, button)
		if button == "LeftButton" and not window.hoveredHyperlink then
			window:ToggleClickChrome()
		end
	end
	content:SetScript("OnMouseUp", toggleClickChrome)
	display:SetScript("OnMouseUp", toggleClickChrome)
	window.display = display

	local empty = Theme:CreateText(content, "GameFontHighlight", "textMuted")
	empty:SetPoint("CENTER", content, "CENTER", 0, 0)
	empty:SetText("Choose a Messenger tab to begin.")
	window.empty = empty

	local messageScrollbar = Theme:CreateSlimScrollbar(content)
	messageScrollbar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -MESSAGE_SCROLLBAR_RIGHT_INSET,
		-MESSAGE_SCROLLBAR_VERTICAL_INSET)
	messageScrollbar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -MESSAGE_SCROLLBAR_RIGHT_INSET,
		MESSAGE_SCROLLBAR_VERTICAL_INSET + MESSAGE_SCROLL_TO_BOTTOM_HEIGHT + MESSAGE_SCROLL_TO_BOTTOM_GAP)
	messageScrollbar:EnableMouseWheel(true)
	messageScrollbar:SetScript("OnValueChanged", function(_, value)
		window:SetMessageScrollbarOffset(value)
	end)
	messageScrollbar:SetScript("OnMouseWheel", function(_, delta)
		if delta > 0 then display:ScrollUp() else display:ScrollDown() end
		if display:AtBottom() then
			local session = window:GetActiveSession()
			if session then session.pendingVisible = 0 end
			window:UpdateNewButton()
		end
		window:RefreshMessageScrollbar(false)
	end)
	window.messageScrollbar = messageScrollbar

	local scrollToBottom = CreateFrame("Button", nil, content)
	scrollToBottom:SetSize(MESSAGE_SCROLL_TO_BOTTOM_WIDTH, MESSAGE_SCROLL_TO_BOTTOM_HEIGHT)
	scrollToBottom:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -MESSAGE_SCROLLBAR_RIGHT_INSET,
		MESSAGE_SCROLLBAR_VERTICAL_INSET)
	local scrollToBottomGlyph = Theme:CreateText(scrollToBottom, "GameFontNormalSmall", "accent")
	scrollToBottomGlyph:SetAllPoints(scrollToBottom)
	scrollToBottomGlyph:SetJustifyH("CENTER")
	scrollToBottomGlyph:SetText("V")
	scrollToBottom:HookScript("OnEnter", function()
		Theme:RegisterText(scrollToBottomGlyph, "goldBright")
	end)
	scrollToBottom:HookScript("OnLeave", function()
		Theme:RegisterText(scrollToBottomGlyph, "accent")
	end)
	scrollToBottom:SetScript("OnClick", function()
		window:ScrollMessageDisplayToBottom()
	end)
	addTooltip(scrollToBottom, "Go to the latest whisper")
	scrollToBottom:Hide()
	window.scrollToBottomButton = scrollToBottom
	window.scrollToBottomGlyph = scrollToBottomGlyph

	local newButton = Theme:CreateTightButton(content, "NEW", 16, true)
	newButton:SetPoint("TOPRIGHT", content, "TOPRIGHT", -20, -2)
	newButton:SetScript("OnClick", function()
		window:ScrollMessageDisplayToBottom()
	end)
	newButton:Hide()
	window.newButton = newButton
	content:SetScript("OnSizeChanged", function()
		window:RefreshMessageScrollbar(true)
	end)

	local composer = Theme:CreatePanel(frame, "surfaceRaised", "borderMuted")
	composer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
	composer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
	composer:SetHeight(24)
	composer:EnableMouse(true)
	window.composer = composer

	local route = Theme:CreateText(composer, "GameFontNormalSmall", "gold")
	route:SetPoint("LEFT", composer, "LEFT", 4, 0)
	route:SetText("TO")
	route:SetWidth(16)
	route:SetJustifyH("LEFT")
	window.route = route

	local send = Theme:CreateTightButton(composer, ">", 18, true)
	-- The send control is deliberately flush to the composer edge: only the
	-- two-pixel frame inset remains, not a phantom resize gutter.
	send:SetPoint("RIGHT", composer, "RIGHT", -2, 0)
	window.send = send

	local editBox = CreateFrame("EditBox", nil, composer)
	editBox:SetPoint("LEFT", route, "RIGHT", 4, 0)
	editBox:SetPoint("RIGHT", send, "LEFT", -3, 0)
	editBox:SetHeight(20)
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetAutoFocus(false)
	editBox:SetMultiLine(false)
	editBox:SetMaxLetters(255)
	editBox:SetTextInsets(2, 2, 0, 0)
	editBox:SetScript("OnEnterPressed", function()
		window:Send()
	end)
	editBox:SetScript("OnEscapePressed", function(self)
		window.transientComposer = false
		self:ClearFocus()
		window:ApplyChromeLayout(true)
	end)
	editBox:SetScript("OnEditFocusGained", function()
		window.transientComposer = true
		window.placeholder:Hide()
		window:ApplyChromeLayout(true)
	end)
	editBox:SetScript("OnEditFocusLost", function(self)
		window.transientComposer = false
		if trim(self:GetText()) == "" then
			window.placeholder:Show()
		end
		window:ApplyChromeLayout(true)
	end)
	editBox:SetScript("OnTextChanged", function(self)
		local session = window:GetActiveSession()
		if session then
			session.draft = self:GetText() or ""
		end
	end)
	window.editBox = editBox

	local placeholder = Theme:CreateText(composer, "GameFontHighlightSmall", "textMuted")
	placeholder:SetPoint("LEFT", editBox, "LEFT", 2, 0)
	placeholder:SetPoint("RIGHT", editBox, "RIGHT", -2, 0)
	placeholder:SetJustifyH("LEFT")
	placeholder:SetText("Write a private message...")
	window.placeholder = placeholder

	composer:SetScript("OnMouseDown", function()
		window:FocusComposer()
	end)
	send:SetScript("OnClick", function()
		window:Send()
	end)

	local grip = CreateFrame("Button", nil, frame)
	grip:SetSize(8, 3)
	grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, -1)
	-- Keep a shallow invisible bottom-edge resize target.  It has no visual nib
	-- and stays below the flush send button's hit area.
	grip:SetScript("OnMouseDown", function()
		frame:StartSizing("BOTTOMRIGHT")
	end)
	grip:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
		window:SavePosition()
	end)
	window.grip = grip

	local confirm = Theme:CreatePanel(frame, "background", "danger")
	-- The Messenger minimum is 300px wide. Keep a visible eight-pixel gutter
	-- between this modal and the shell border even at that exact minimum.
	confirm:SetSize(284, 104)
	confirm:SetPoint("CENTER", frame, "CENTER", 0, 0)
	confirm:Hide()
	window.confirm = confirm

	local confirmTitle = Theme:CreateText(confirm, "GameFontNormal", "danger")
	confirmTitle:SetPoint("TOPLEFT", confirm, "TOPLEFT", 8, -8)
	confirmTitle:SetText("Server Ignore")
	window.confirmTitle = confirmTitle

	local confirmText = Theme:CreateText(confirm, "GameFontHighlightSmall", "text")
	confirmText:SetPoint("TOPLEFT", confirmTitle, "BOTTOMLEFT", 0, -4)
	confirmText:SetWidth(268)
	confirmText:SetJustifyH("LEFT")
	window.confirmText = confirmText

	local cancel = Theme:CreateTightButton(confirm, "CANCEL", 20, false)
	cancel:SetPoint("BOTTOMLEFT", confirm, "BOTTOMLEFT", 8, 8)
	cancel:SetScript("OnClick", function()
		confirm:Hide()
	end)
	window.confirmCancel = cancel

	local accept = Theme:CreateTightButton(confirm, "ADD TO WOW IGNORE", 20, true)
	accept:SetPoint("BOTTOMRIGHT", confirm, "BOTTOMRIGHT", -8, 8)
	accept:SetScript("OnClick", function()
		window:ApplyServerIgnore()
	end)
	window.confirmAccept = accept

	window:RestorePosition()
	window:UpdateRouteLabel(nil)
	window:ApplyChromeLayout(true)
	window:RefreshMessageScrollbar(true)
	window:RefreshAppearance()
	return window
end

function Manager:GetShell()
	if not self.shell then
		self.shell = self:BuildWindow()
		self.windowPool = { self.shell } -- retained for callers that inspect the old pool
	end
	return self.shell
end

function Manager:RemoveSession(key, suppressSelection)
	local session = key and self.sessionsByKey[key]
	if not session then
		return
	end

	local shell = self.shell
	local removedIndex
	for index = 1, #self.tabOrder do
		if self.tabOrder[index] == key then
			removedIndex = index
			table.remove(self.tabOrder, index)
			break
		end
	end
	if session.tab then
		session.tab:Hide()
	end
	self.sessionsByKey[key] = nil
	self.windowsByKey[key] = nil

	if not shell then
		return
	end
	if shell.playerKey == key then
		shell.playerKey = nil
		shell.playerName = nil
		shell.confirm:Hide()
		if #self.tabOrder > 0 and not suppressSelection then
			local nextKey = self.tabOrder[math.min(removedIndex or 1, #self.tabOrder)]
			self:SelectSession(nextKey)
		else
			shell:Hide()
		end
	else
		shell:RefreshTabs()
	end
end

function Manager:AcquireSession(name)
	local key = playerKey(name)
	if not key then
		return nil
	end

	local existing = self.sessionsByKey[key]
	if existing then
		return existing
	end

	local shell = self:GetShell()
	if #self.tabOrder >= MAX_TABS then
		local leastKey
		local leastUsed
		for index = 1, #self.tabOrder do
			local candidateKey = self.tabOrder[index]
			local candidate = self.sessionsByKey[candidateKey]
			if candidate and candidateKey ~= shell.playerKey and (not leastUsed or candidate.lastUsed < leastUsed) then
				leastKey = candidateKey
				leastUsed = candidate.lastUsed
			end
		end
		if leastKey then
			self:RemoveSession(leastKey, true)
		end
	end

	local session = {
		playerName = cleanPlayerName(name),
		playerKey = key,
		renderedIds = {},
		renderedCount = 0,
		pendingVisible = 0,
		unread = 0,
		draft = "",
		lastUsed = now(),
		frame = shell.frame, -- light compatibility for legacy callers
	}
	self.sessionsByKey[key] = session
	self.windowsByKey[key] = shell
	table.insert(self.tabOrder, key)
	shell:CreateTab(session)
	shell:RefreshTabs()
	return session
end

-- Internal compatibility with the old vocabulary.  It now returns the shared
-- shell after making the target session available, not a second physical frame.
function Manager:AcquireWindow(name)
	local session = self:AcquireSession(name)
	return session and self:GetShell() or nil
end

function Manager:SelectSession(key)
	local session = key and self.sessionsByKey[key]
	if not session then
		return nil
	end
	local shell = self:GetShell()
	shell:SelectSession(session)
	return shell
end

function Manager:QueueOpen(record)
	local name = getPartner(record)
	local key = playerKey(name)
	if not key then
		return
	end

	if not self.pending[key] then
		if #self.pendingOrder >= MAX_PENDING then
			local expired = table.remove(self.pendingOrder, 1)
			self.pending[expired] = nil
		end
		table.insert(self.pendingOrder, key)
	end
	-- The message engine owns history, so replacing the representative record
	-- cannot discard a combat-time whisper from the eventual conversation.
	self.pending[key] = record
	self.lifecycle:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function Manager:DrainPending()
	self.lifecycle:UnregisterEvent("PLAYER_REGEN_ENABLED")
	if not self.enabled then
		self.pending = {}
		self.pendingOrder = {}
		return
	end

	local order = self.pendingOrder
	local pending = self.pending
	self.pendingOrder = {}
	self.pending = {}
	for index = 1, #order do
		local record = pending[order[index]]
		if record and not isLocallyIgnored(getPartner(record)) then
			self:OpenForRecord(record, true)
		end
	end
end

function Manager:OpenForRecord(record, bypassCombatDeferral)
	if not self.enabled then
		return nil, "disabled"
	end

	local name = getPartner(record)
	if not name then
		return nil, record and record.isBNet and "bnet" or "not-whisper"
	end
	if isLocallyIgnored(name) then
		return nil, "locally-ignored"
	end

	local settings = getConversationSettings()
	if not bypassCombatDeferral and settings.deferInCombat and InCombatLockdown and InCombatLockdown() then
		self:QueueOpen(record)
		return nil, "deferred"
	end

	local session = self:AcquireSession(name)
	if not session then
		return nil, "invalid-player"
	end
	local shell = self:SelectSession(session.playerKey)
	shell:Show(record)
	return shell
end

function Manager:OpenForPlayer(name, bypassCombatDeferral)
	name = cleanPlayerName(name)
	if not name then
		return nil, "invalid-player"
	end
	return self:OpenForRecord({
		event = "CHAT_MSG_WHISPER",
		sender = name,
		direction = "incoming",
		isBNet = false,
	}, bypassCombatDeferral)
end

function Manager:Close(player)
	local key = playerKey(player)
	if not key then
		if self.shell then
			self.shell:Hide()
		end
		return
	end
	self:RemoveSession(key)
end

function Manager:OnMessage(record)
	if not self.enabled or not record or record.isBNet or not whisperEvents[record.event] then
		return
	end

	local name = getPartner(record)
	local key = playerKey(name)
	if not key or isLocallyIgnored(name) then
		return
	end

	local session = self.sessionsByKey[key]
	local shell = self.shell
	local shellWasShown = shell and shell.frame:IsShown() or false
	-- Tab intake is not popup behavior. Every incoming whisper gets a session
	-- immediately so an already-open Messenger cannot silently omit a new
	-- player, and a hidden Messenger retains the tab for its next manual open.
	if not session and record.event == "CHAT_MSG_WHISPER" then
		session = self:AcquireSession(name)
		shell = self.shell
	end
	if session and shellWasShown and shell then
		if shell.playerKey == key then
			shell:AddRecord(record)
		elseif record.direction ~= "outgoing" then
			session.unread = (tonumber(session.unread) or 0) + 1
			session.lastUsed = now()
			shell:RefreshTabs()
			shell:EnsureTabVisible(key)
		end
		return
	end

	local settings = getConversationSettings()
	if record.event == "CHAT_MSG_WHISPER" and session and shell then
		session.unread = (tonumber(session.unread) or 0) + 1
		session.lastUsed = now()
		shell:RefreshTabs()
	end
	if record.event == "CHAT_MSG_WHISPER" and settings.autoOpenWhispers then
		self:OpenForRecord(record)
	end
end

function Manager:ApplySettings()
	self:RefreshTellTargetCommand()
	if self.shell then
		self.shell.actionsCompactForWidth = nil
		self.shell:ApplyChromeLayout(true)
		self.shell:RefreshAppearance()
	end
end

function Manager:RefreshSettings()
	self:ApplySettings()
end

function Manager:SetEnabled(enabled)
	if enabled and not self.initialized and not self:Initialize() then
		return false
	end
	self.enabled = enabled and true or false
	if self.enabled then
		self:ApplySettings()
		return true
	end
	self:RefreshTellTargetCommand()
	self:CancelQueuedComposerFocus()

	if self.lifecycle then
		self.lifecycle:UnregisterEvent("PLAYER_REGEN_ENABLED")
	end
	self.pending = {}
	self.pendingOrder = {}
	if self.shell then
		self.shell:Hide()
	end
	return true
end

function Manager:ResetForProfile()
	self:SetEnabled(false)
	self.windowsByKey = {}
	self.sessionsByKey = {}
	self.tabOrder = {}
	if self.shell then
		self.shell:Reset()
	end
end

local function getChatFrameEditBox(chatFrame)
	if chatFrame then
		local editBox = chatFrame.editBox
		if editBox then return editBox end
		if chatFrame.GetName then
			local ok, name = pcall(chatFrame.GetName, chatFrame)
			editBox = ok and name and _G[name .. "EditBox"] or nil
			if editBox then return editBox end
		end
		-- Keep a narrow compatibility fallback for private-client variants that
		-- pass the EditBox itself instead of stock Wrath's ChatFrame argument.
		if chatFrame.SetText and chatFrame.GetAttribute then return chatFrame end
	end
	return _G.ChatFrame1EditBox
end

function Manager:ShouldFocusReplyFieldOnCommands()
	return getConversationSettings().focusReplyFieldOnCommands ~= false
end

function Manager:CancelQueuedComposerFocus()
	self.pendingComposerFocusKey = nil
	if self.focusDriver and self.focusDriver.Hide then
		self.focusDriver:Hide()
	end
end

function Manager:QueueComposerFocus(key)
	key = playerKey(key)
	if not key or not self.enabled or not self:ShouldFocusReplyFieldOnCommands() then
		self:CancelQueuedComposerFocus()
		return false
	end
	self.pendingComposerFocusKey = key
	if self.focusDriver and self.focusDriver.Show then
		self.focusDriver:Show()
	end
	return true
end

function Manager:ApplyQueuedComposerFocus()
	local key = self.pendingComposerFocusKey
	self.pendingComposerFocusKey = nil
	if not key or not self.enabled or not self:ShouldFocusReplyFieldOnCommands() then
		return false
	end

	local shell = self.shell
	if not shell or shell.playerKey ~= key or not shell.frame
		or not shell.frame.IsShown or not shell.frame:IsShown()
		or isLocallyIgnored(shell.playerName) then
		return false
	end
	shell:RevealComposer(true)
	return true
end

function Manager:ResolveTellTarget()
	if UnitExists and not UnitExists("target") then
		return nil, "no-target"
	end
	if not UnitIsPlayer or not UnitIsPlayer("target") then
		return nil, "not-player"
	end

	local isSelf = UnitIsUnit and UnitIsUnit("player", "target") or false
	if not isSelf and UnitGUID then
		local playerGUID = UnitGUID("player")
		local targetGUID = UnitGUID("target")
		isSelf = playerGUID and targetGUID and playerGUID == targetGUID or false
	end
	if isSelf then
		return nil, "self"
	end

	if not UnitName then
		return nil, "no-name"
	end
	local name, realm = UnitName("target")
	name = compactUnitNamePart(name)
	realm = compactUnitNamePart(realm)
	if not name then
		return nil, "no-name"
	end
	-- Wrath returns a separate realm only when it is useful.  Ascension builds
	-- vary, so accept either that tuple or an already-qualified Name-Realm and
	-- never use friendly/assist checks that would reject valid cross-faction
	-- private-server whispers before the server can apply its own policy.
	if realm and not string.find(name, "-", 1, true) then
		name = name .. "-" .. realm
	end
	return name
end

function Manager:PrintTellTargetFailure(reason)
	local messages = {
		["no-target"] = "/tt needs a player target.",
		["not-player"] = "/tt can only tell a player target.",
		["self"] = "/tt cannot open a conversation with yourself.",
		["no-name"] = "Chatty could not read that target's player name.",
		["locally-ignored"] = "That player is hidden by Chatty local ignore.",
	}
	printStatus(messages[reason] or "Chatty could not open that target in Messenger.")
end

function Manager:ActivateConversationTarget(name, nativeEditBox)
	if not self.enabled then
		return nil, "disabled"
	end
	name = cleanPlayerName(name)
	if not name then
		return nil, "no-target"
	end

	local shell, reason = self:OpenForPlayer(name, true)
	if not shell then
		return nil, reason
	end

	if self:ShouldFocusReplyFieldOnCommands() then
		shell:RevealComposer(true)
		-- FrameXML can finish deactivating the slash-command edit box after a
		-- secure post-hook returns.  Close only that native field now, then repeat
		-- the Messenger focus on the next frame so /r and /tt reliably end in the
		-- intended TO field instead of losing keyboard focus during cleanup.
		local native = nativeEditBox or _G.ChatFrame1EditBox
		if native and native ~= shell.editBox and ChatEdit_OnEscapePressed then
			pcall(ChatEdit_OnEscapePressed, native)
		end
		self:QueueComposerFocus(shell.playerKey)
	else
		self:CancelQueuedComposerFocus()
	end
	return shell
end

function Manager:ActivateReplyTarget(name, nativeEditBox)
	if not self.enabled then
		return nil, "disabled"
	end
	name = cleanPlayerName(name)
	if not name then
		return nil, "no-target"
	end

	local key = playerKey(name)
	local stamp = now()
	if self.lastReplyKey == key and stamp - (self.lastReplyAt or 0) < 0.05
		and self.shell and self.shell.playerKey == key then
		-- Repeated reply callbacks must not build another session, but they still
		-- reinforce the final focus in case FrameXML cleanup runs between them.
		if self:ShouldFocusReplyFieldOnCommands() then
			self.shell:RevealComposer(true)
			local native = nativeEditBox or _G.ChatFrame1EditBox
			if native and native ~= self.shell.editBox and ChatEdit_OnEscapePressed then
				pcall(ChatEdit_OnEscapePressed, native)
			end
			self:QueueComposerFocus(key)
		end
		return self.shell
	end
	self.lastReplyKey = key
	self.lastReplyAt = stamp

	local shell, reason = self:ActivateConversationTarget(name, nativeEditBox)
	if not shell then
		return nil, reason
	end
	return shell
end

function Manager:ActivateTellTarget(input, nativeEditBox)
	if not self.enabled or getConversationSettings().tellTargetEnabled == false then
		return nil, "disabled"
	end
	local name, reason = self:ResolveTellTarget()
	if not name then
		self:PrintTellTargetFailure(reason)
		return nil, reason
	end

	local shell
	shell, reason = self:ActivateConversationTarget(name, nativeEditBox)
	if not shell then
		self:PrintTellTargetFailure(reason)
		return nil, reason
	end

	input = tostring(input or "")
	if trim(input) ~= "" then
		local session = shell:GetActiveSession()
		if session then session.draft = input end
		shell.editBox:SetText(input)
		if shell.placeholder then shell.placeholder:Hide() end
		shell:Send()
	end
	return shell
end

function Manager:RefreshTellTargetCommand()
	local shouldOwn = self.enabled and getConversationSettings().tellTargetEnabled ~= false
	if shouldOwn and not self.tellTargetCommandRegistered then
		if type(addon.RegisterChatCommand) ~= "function" then
			return false
		end
		local callback = function(input, editBox)
			return Manager:ActivateTellTarget(input, editBox)
		end
		-- The Smart owner is explicit and persistent: Manager disable/settings
		-- changes release it, while the copied native fallback remains a weak
		-- AceConsole owner that follows its module lifecycle.
		local ok, registered = pcall(addon.RegisterChatCommand, addon, "tt", callback, true)
		if ok and registered ~= false then
			self.tellTargetCommandRegistered = true
			self.tellTargetCommandCallback = callback
			return true
		end
		return false
	elseif not shouldOwn and self.tellTargetCommandRegistered then
		-- AceConsole uses one global slot per slash command. A conflict/fallback
		-- transition can replace our callback before Manager is told to disable;
		-- never unregister that newer owner while clearing our own stale state.
		local slashCommands = _G and _G.SlashCmdList
		local liveCallback = type(slashCommands) == "table" and slashCommands.ACECONSOLE_TT or nil
		local stillOwnsLiveCommand = liveCallback == nil or liveCallback == self.tellTargetCommandCallback
		if stillOwnsLiveCommand and type(addon.UnregisterChatCommand) == "function" then
			pcall(addon.UnregisterChatCommand, addon, "tt")
		end
		self.tellTargetCommandRegistered = false
		self.tellTargetCommandCallback = nil
	end
	return self.tellTargetCommandRegistered == true
end

function Manager:InstallReplyHooks()
	if self.replyHooksInstalled or not hooksecurefunc then
		return
	end
	self.replyHooksInstalled = true
	if type(ChatFrame_ReplyTell) == "function" then
		hooksecurefunc("ChatFrame_ReplyTell", function(chatFrame)
			local target = ChatEdit_GetLastTellTarget and ChatEdit_GetLastTellTarget()
			Manager:ActivateReplyTarget(target, getChatFrameEditBox(chatFrame))
		end)
	end
	if type(ChatFrame_ReplyTell2) == "function" then
		hooksecurefunc("ChatFrame_ReplyTell2", function(chatFrame)
			local target = ChatEdit_GetLastToldTarget and ChatEdit_GetLastToldTarget()
			Manager:ActivateReplyTarget(target, getChatFrameEditBox(chatFrame))
		end)
	end
end

function Manager:Initialize()
	if self.initialized then
		return true
	end
	if not Engine or not Engine.RegisterListener then
		return false
	end

	self.initialized = true
	self.enabled = false
	self.windowPool = {}
	self.windowsByKey = {}
	self.sessionsByKey = {}
	self.tabOrder = {}
	self.pending = {}
	self.pendingOrder = {}
	self.lifecycle = CreateFrame("Frame")
	self.lifecycle:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" then
			Manager:DrainPending()
		end
	end)
	self.focusDriver = CreateFrame("Frame")
	self.focusDriver:Hide()
	self.focusDriver:SetScript("OnUpdate", function(frame)
		frame:Hide()
		Manager:ApplyQueuedComposerFocus()
	end)

	Engine:RegisterListener("ConversationWindows", function(record)
		Manager:OnMessage(record)
	end)

	Theme:RegisterRefreshCallback(function()
		if Manager.shell then
			Manager.shell:OnThemeRefresh()
		end
	end)
	self:InstallReplyHooks()
	return true
end
