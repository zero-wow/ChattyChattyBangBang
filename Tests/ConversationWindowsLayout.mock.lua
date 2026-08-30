local function expect(value, message)
	if not value then error(message or "expectation failed", 2) end
end

local frames = {}
local fontStrings = {}
local themedButtons = {}
local slimScrollbars = {}
local failTextures = false
local function newFrame(kind, parent)
	local object = {
		kind = kind,
		parent = parent,
		shown = true,
		width = 100,
		height = 20,
		alpha = 1,
		points = {},
		scripts = {},
		textValue = "",
		frameLevel = 1,
		mouseEnabled = true,
		currentScroll = 0,
	}
	frames[#frames + 1] = object
	function object:SetSize(width, height) self.width, self.height = width, height end
	function object:SetWidth(width) self.width = width end
	function object:SetHeight(height) self.height = height end
	function object:GetWidth() return self.width end
	function object:GetHeight() return self.height end
	function object:SetPoint(...) self.points[#self.points + 1] = { ... } end
	function object:ClearAllPoints() self.points = {} end
	function object:GetPoint() return "CENTER", UIParent, "CENTER", 0, 0 end
	function object:SetParent(nextParent) self.parent = nextParent end
	function object:GetParent() return self.parent end
	function object:Show() self.shown = true end
	function object:Hide() self.shown = false end
	function object:IsShown() return self.shown end
	function object:IsVisible() return self.shown end
	function object:SetAlpha(alpha) self.alpha = alpha end
	function object:GetAlpha() return self.alpha end
	function object:SetFrameLevel(level) self.frameLevel = level end
	function object:GetFrameLevel() return self.frameLevel end
	function object:EnableMouse(enabled) self.mouseEnabled = enabled and true or false end
	function object:IsMouseEnabled() return self.mouseEnabled end
	function object:EnableMouseWheel(enabled) self.mouseWheelEnabled = enabled and true or false end
	function object:SetOrientation(orientation) self.orientation = orientation end
	function object:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
	function object:GetMinMaxValues() return self.minimum or 0, self.maximum or 0 end
	function object:SetValueStep(step) self.valueStep = step end
	function object:SetValue(value)
		self.value = value
		if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
	end
	function object:GetValue() return self.value or 0 end
	function object:SetScript(name, callback) self.scripts[name] = callback end
	function object:HookScript(name, callback)
		local prior = self.scripts[name]
		if prior then
			self.scripts[name] = function(...)
				prior(...)
				callback(...)
			end
		else
			self.scripts[name] = callback
		end
	end
	function object:SetText(value) self.textValue = tostring(value or "") end
	function object:GetText() return self.textValue end
	function object:GetStringWidth() return string.len(self.textValue or "") * 6 end
	function object:SetTextColor(...) self.textColor = { ... } end
	function object:SetLabel(value)
		self.labelValue = tostring(value or "")
		if self.text then self.text:SetText(self.labelValue) end
	end
	function object:SetTheme(...) self.theme = { ... } end
	function object:CreateTexture()
		local texture = newFrame("Texture", self)
		function texture:SetTexture(path)
			if failTextures then self.texture = nil return false end
			self.texture = path
			return true
		end
		function texture:GetTexture() return self.texture end
		return texture
	end
	function object:HasFocus() return self.focused == true end
	function object:SetFocus()
		if self.focused then return end
		self.focused = true
		if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
	end
	function object:ClearFocus()
		if not self.focused then return end
		self.focused = false
		if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
	end
	function object:SetAttribute(key, value) self[key] = value end
	function object:GetAttribute(key) return self[key] end
	function object:Clear() self.messages = {} end
	function object:AddMessage(message)
		self.messages = self.messages or {}
		self.messages[#self.messages + 1] = message
	end
	function object:GetNumMessages() return #(rawget(self, "messages") or {}) end
	function object:GetNumLinesDisplayed() return rawget(self, "visibleLineCapacity") or 0 end
	function object:GetCurrentScroll() return self.currentScroll or 0 end
	function object:SetScrollOffset(value)
		self.setScrollOffsetCalls = (rawget(self, "setScrollOffsetCalls") or 0) + 1
		self.currentScroll = math.max(0, tonumber(value) or 0)
	end
	function object:ScrollUp()
		self.scrollUpCalls = (rawget(self, "scrollUpCalls") or 0) + 1
		local maximum = tonumber(rawget(self, "scrollMaximum")) or math.huge
		self.currentScroll = math.min(maximum, (tonumber(self.currentScroll) or 0) + 1)
	end
	function object:ScrollDown()
		self.scrollDownCalls = (rawget(self, "scrollDownCalls") or 0) + 1
		self.currentScroll = math.max(0, (tonumber(self.currentScroll) or 0) - 1)
	end
	function object:ScrollToBottom()
		self.scrollToBottomCalls = (rawget(self, "scrollToBottomCalls") or 0) + 1
		self.currentScroll = 0
	end
	function object:ScrollToTop()
		self.scrollToTopCalls = (rawget(self, "scrollToTopCalls") or 0) + 1
		self.currentScroll = math.max(0, tonumber(rawget(self, "scrollMaximum")) or 0)
	end
	function object:AtBottom() return (tonumber(self.currentScroll) or 0) == 0 end
	function object:GetFont() return "Fonts\\FRIZQT__.TTF", rawget(self, "fontSize") or 10 end
	function object:GetSpacing() return rawget(self, "spacing") or 0 end
	function object:SetThumbTexture(texture)
		self.thumbTexture = type(texture) == "table" and texture or self:CreateTexture()
	end
	function object:GetThumbTexture() return self.thumbTexture end
	function object:GetName() return nil end
	setmetatable(object, { __index = function(_, key)
		if type(key) == "string" and string.sub(key, 1, 1) == "_" then return nil end
		return function() end
	end })
	return object
end

UIParent = newFrame("UIParent")
ChatFontNormal = {}
function CreateFrame(kind, _, parent) return newFrame(kind, parent) end
function UnitFactionGroup() return "Alliance" end
function GetTime() return 100 end
local inCombat = false
function InCombatLockdown() return inCombat end
function MouseIsOver() return false end
function GetMouseFocus() return nil end

local hooks = {}
function hooksecurefunc(name, callback) hooks[name] = callback end
function ChatFrame_ReplyTell() end
function ChatFrame_ReplyTell2() end
function ChatEdit_ExtractTellTarget() end
function ChatEdit_GetLastTellTarget() return "ReplyTarget" end
function ChatEdit_GetLastToldTarget() return "ToldTarget" end
local escaped
function ChatEdit_OnEscapePressed(editBox) escaped = editBox end
ChatFrame1EditBox = newFrame("EditBox", UIParent)

local Theme = { ICON_PATH = "icon" }
function Theme:CreatePanel(parent, fillName, borderName)
	local panel = newFrame("Panel", parent)
	panel.themedPanel = true
	panel.fillName = fillName
	panel.borderName = borderName
	return panel
end
function Theme:CreateText(parent, _, colorName)
	local text = newFrame("FontString", parent)
	text.colorName = colorName
	fontStrings[#fontStrings + 1] = text
	return text
end
local function themedButton(parent, text, width, height)
	local button = newFrame("Button", parent)
	button:SetSize(width or 40, height or 18)
	button.text = Theme:CreateText(button)
	button:SetLabel(text)
	button.themedButton = true
	themedButtons[#themedButtons + 1] = button
	return button
end
function Theme:CreateTightButton(parent, text, height) return themedButton(parent, text, 40, height) end
function Theme:CreateButton(parent, text, width, height) return themedButton(parent, text, width, height) end
function Theme:GetColor() return 1, 1, 1, 1 end
function Theme:SetFrameOpacity(frame, fillAlpha, borderAlpha)
	frame.backgroundAlpha = fillAlpha
	frame.borderAlpha = borderAlpha
	return true
end
function Theme:SetScrollBarThumbVisible(scrollBar, visible)
	local thumb = scrollBar and scrollBar:GetThumbTexture()
	if not thumb then return end
	if visible then thumb:Show() else thumb:Hide() end
end
function Theme:SetScrollBarThumbSize(scrollBar, width, height)
	local thumb = scrollBar and scrollBar:GetThumbTexture()
	if thumb then thumb:SetSize(width, height) end
end
function Theme:CreateSlimScrollbar(parent)
	local scrollBar = newFrame("Slider", parent)
	scrollBar:SetOrientation("VERTICAL")
	scrollBar:SetWidth(8)
	scrollBar:SetMinMaxValues(0, 0)
	scrollBar:SetValueStep(1)
	local thumb = scrollBar:CreateTexture()
	thumb:SetSize(6, 18)
	scrollBar:SetThumbTexture(thumb)
	slimScrollbars[#slimScrollbars + 1] = scrollBar
	return scrollBar
end
function Theme:RegisterText(text, colorName) text.colorName = colorName end
function Theme:RegisterRefreshCallback(callback) self.refresh = callback end

local settings = {
	conversations = {
		autoOpenWhispers = true,
		deferInCombat = true,
		chromeAutoHide = false,
		titleBarVisibility = "inherit",
		actionVisibility = "inherit",
		composerVisibility = "inherit",
		actionButtonStyle = "text",
		actionStripCollapsed = false,
		actionStripOrientation = "horizontal",
		appearance = {
			transparency = {
				backgroundAlpha = 1,
				borderAlpha = 1,
				textAlpha = 1,
				overallAlpha = 1,
			},
			colors = {},
		},
		windowWidth = 360,
		windowHeight = 250,
	},
	safety = { localIgnores = {}, confirmServerIgnore = true },
}
local Engine = { listeners = {} }
function Engine:RegisterListener(id, callback) self.listeners[id] = callback end
function Engine:GetMessages() return {} end

ChattyChattyBangBang = {
	Theme = Theme,
	Presentation = {
		Color = function(_, value) return tostring(value or "") end,
		ColorizeMessage = function(_, value) return tostring(value or "") end,
	},
	MessageEngine = Engine,
	Compatibility = {},
}
function ChattyChattyBangBang:GetSmartSettings() return settings end
function ChattyChattyBangBang:GetMessengerAppearanceSettings()
	return settings.conversations.appearance
end

assert(loadfile("Core/ConversationWindows.lua"))()
local Manager = ChattyChattyBangBang.ConversationWindows
expect(Manager:Initialize(), "manager should initialize")
expect(hooks.ChatFrame_ReplyTell and hooks.ChatFrame_ReplyTell2 and hooks.ChatEdit_ExtractTellTarget,
	"native reply paths should be hooked")
Manager:SetEnabled(true)
local window = Manager:GetShell()
window.tabStrip:SetWidth(356)
window:ApplyChromeLayout(true)

expect(window.header:IsShown(), "default inherited title should be visible")
expect(window.actions:IsShown(), "default inherited actions should be visible")
expect(window.actionToggle:IsShown() and window.actionToggle.labelValue == "-",
	"Messenger should expose a separate compact action-strip control")
expect(window.composer:IsShown(), "default inherited composer should be visible")
expect(window.actions.parent == window.tabStrip, "actions must share the tab rail")
expect(rawget(window.actions, "themedPanel") ~= true, "actions must not create a second boxed toolbar")
expect(window.close.label:GetText() == "x" and rawget(window.close, "themedButton") ~= true,
	"shell close must be a bare lowercase text control")
for index = 1, #window.actionButtons do
	expect(window.actionButtons[index]:IsShown(), "every contextual action should be shown")
end

window.actionToggle.scripts.OnClick()
expect(settings.conversations.actionStripCollapsed == true and not window.actions:IsShown(),
	"action-strip control did not collapse and persist the social buttons")
expect(window.actionToggle.labelValue == "+", "collapsed action strip did not show an expand affordance")
window.actionToggle.scripts.OnClick()
expect(settings.conversations.actionStripCollapsed == false and window.actions:IsShown(),
	"action-strip control did not restore the social buttons")

-- COLLAPSED is a policy, not another spelling of the saved +/- preference.
-- It always starts with only the action toggle visible; a click expands the
-- strip for the current interaction without writing actionStripCollapsed.
local persistedActionCollapseCalls = 0
function ChattyChattyBangBang:SetMessengerActionStripCollapsed(collapsed)
	persistedActionCollapseCalls = persistedActionCollapseCalls + 1
	settings.conversations.actionStripCollapsed = collapsed and true or false
	Manager:ApplySettings()
	return true, settings.conversations.actionStripCollapsed
end
settings.conversations.actionVisibility = "collapsed"
settings.conversations.actionStripCollapsed = false
window:ApplyChromeLayout(true)
expect(window.actionToggle:IsShown() and not window.actions:IsShown(),
	"COLLAPSED player actions did not begin with a visible toggle and reclaimed strip")
window.actionToggle.scripts.OnClick()
expect(window.actionToggle:IsShown() and window.actions:IsShown(),
	"COLLAPSED player-action toggle did not transiently reveal the action strip")
expect(settings.conversations.actionStripCollapsed == false and persistedActionCollapseCalls == 0,
	"COLLAPSED transient expansion overwrote the separately saved strip preference")

Manager:OpenForPlayer("CollapsedAlice", true)
window.actionToggle.scripts.OnClick()
expect(window.actions:IsShown(), "COLLAPSED action strip could not expand for a selected player")
Manager:OpenForPlayer("CollapsedBob", true)
expect(not window.actions:IsShown(),
	"COLLAPSED player actions did not re-collapse when the selected session changed")
window.actionToggle.scripts.OnClick()
expect(window.actions:IsShown(), "COLLAPSED player actions did not re-expand before hide")
window:Hide()
window:Show()
expect(not window.actions:IsShown(), "COLLAPSED player actions did not re-collapse after Messenger hide")
window.actionToggle.scripts.OnClick()
expect(window.actions:IsShown(), "COLLAPSED player actions did not re-expand before an action")
window.actionButtons[1].scripts.OnClick()
expect(not window.actions:IsShown(), "COLLAPSED player actions did not re-collapse after an action")
expect(settings.conversations.actionStripCollapsed == false and persistedActionCollapseCalls == 0,
	"COLLAPSED lifecycle wrote the normal action-strip preference")
window.editBox:ClearFocus()

-- The policy owns its transient state even when the ordinary saved preference
-- was already collapsed before entering this mode. A click must still expand.
settings.conversations.actionStripCollapsed = true
window:ApplyChromeLayout(true)
window.actionToggle.scripts.OnClick()
expect(window.actions:IsShown(),
	"COLLAPSED policy could not transiently expand over a saved collapsed preference")
expect(settings.conversations.actionStripCollapsed == true and persistedActionCollapseCalls == 0,
	"COLLAPSED policy changed the saved collapsed preference while temporarily open")
ChattyChattyBangBang.SetMessengerActionStripCollapsed = nil
settings.conversations.actionVisibility = "inherit"
window:ApplyChromeLayout(true)
expect(not window.actions:IsShown(),
	"leaving COLLAPSED did not restore the separately saved collapsed preference")
settings.conversations.actionStripCollapsed = false
window:ApplyChromeLayout(true)

settings.conversations.titleBarVisibility = "hidden"
window:ApplyChromeLayout(true)
expect(not window.header:IsShown(), "hidden title must reclaim its row")
expect(window.close.parent == window.tabStrip, "close must move to the remaining top rail")
expect(window.content.points[1][2] == window.tabStrip,
	"content must remain below the tab/action rail")

settings.conversations.actionVisibility = "hidden"
window:ApplyChromeLayout(true)
expect(not window.actions:IsShown(), "hidden actions should release their rail width")

settings.conversations.titleBarVisibility = "click"
settings.conversations.actionVisibility = "click"
settings.conversations.composerVisibility = "click"
window.clickChromeRevealed = false
window:ApplyChromeLayout(true)
expect(not window.header:IsShown() and not window.actions:IsShown() and not window.composer:IsShown(),
	"on-click Messenger regions should begin reclaimed")
window.display.scripts.OnMouseUp(window.display, "LeftButton")
expect(window.header:IsShown() and window.actions:IsShown() and window.composer:IsShown(),
	"message-surface click did not reveal on-click Messenger regions")
window.display.scripts.OnHyperlinkEnter()
window.display.scripts.OnMouseUp(window.display, "LeftButton")
expect(window.header:IsShown(), "hyperlink click incorrectly toggled Messenger chrome")
window.display.scripts.OnHyperlinkLeave()
window.display.scripts.OnMouseUp(window.display, "LeftButton")
expect(not window.header:IsShown() and not window.actions:IsShown() and not window.composer:IsShown(),
	"second message-surface click did not reclaim on-click Messenger regions")

settings.conversations.chromeAutoHide = true
settings.conversations.titleBarVisibility = "inherit"
settings.conversations.actionVisibility = "inherit"
settings.conversations.composerVisibility = "inherit"
window.hovered = false
window:ApplyChromeLayout(true)
expect(not window.header:IsShown() and not window.actions:IsShown() and not window.composer:IsShown(),
	"inherited chrome should auto-hide while idle")
window.hovered = true
window:ApplyChromeLayout(true)
expect(window.header:IsShown() and window.actions:IsShown() and window.composer:IsShown(),
	"inherited chrome should reveal together on hover")

settings.conversations.chromeAutoHide = false
settings.conversations.titleBarVisibility = "always"
settings.conversations.actionVisibility = "always"
settings.conversations.composerVisibility = "hidden"
window.hovered = false
window:ApplyChromeLayout(true)
expect(not window.composer:IsShown(), "manual composer hide should reclaim its lane")

hooks.ChatFrame_ReplyTell(ChatFrame1EditBox)
expect(window.playerName == "ReplyTarget", "/r should select the reply conversation")
expect(window.composer:IsShown() and window.editBox:HasFocus(), "/r should reveal and focus the TO row")
expect(window.route:GetText() == "TO ReplyTarget", "reply row should name its destination")
expect(escaped == ChatFrame1EditBox, "native reply edit box should close after handoff")

-- Enter is the keyboard continuation path: a successful whisper should clear
-- only the sent draft while keeping the same player's temporarily revealed TO
-- row focused. The mouse send control retains its old non-stealing behavior,
-- and aborted sends must leave the user's text and focus exactly as they were.
local sentWhispers = {}
local function setReplyText(text)
	window.editBox:SetText(text)
	window.editBox.scripts.OnTextChanged(window.editBox)
end
SendChatMessage = function(message, chatType, language, target)
	sentWhispers[#sentWhispers + 1] = {
		message = message,
		chatType = chatType,
		language = language,
		target = target,
	}
end
local replySession = window:GetActiveSession()
setReplyText("first reply")
window.editBox.scripts.OnEnterPressed(window.editBox)
expect(#sentWhispers == 1 and sentWhispers[1].message == "first reply"
	and sentWhispers[1].chatType == "WHISPER" and sentWhispers[1].target == "ReplyTarget",
	"Enter did not send the active Messenger reply to its selected player")
expect(window.editBox:GetText() == "" and replySession.draft == "",
	"successful Enter send did not clear only the sent Messenger draft")
expect(window.playerName == "ReplyTarget" and window.editBox:HasFocus()
	and window.composer:IsShown() and window.transientComposer == true,
	"successful Enter send did not retain the focused transient TO row")

setReplyText("   ")
window.editBox.scripts.OnEnterPressed(window.editBox)
expect(#sentWhispers == 1 and window.editBox:GetText() == "   "
	and replySession.draft == "   " and window.editBox:HasFocus(),
	"empty Enter send changed the Messenger draft or its existing focus")

setReplyText("client unavailable")
SendChatMessage = nil
window.editBox.scripts.OnEnterPressed(window.editBox)
expect(window.editBox:GetText() == "client unavailable"
	and replySession.draft == "client unavailable" and window.editBox:HasFocus(),
	"unavailable whisper sending discarded the Messenger draft or focus")

SendChatMessage = function()
	error("mock whisper failure")
end
setReplyText("retry me")
window.editBox.scripts.OnEnterPressed(window.editBox)
expect(window.editBox:GetText() == "retry me" and replySession.draft == "retry me"
	and window.editBox:HasFocus(),
	"failed whisper sending discarded the Messenger draft or focus")

SendChatMessage = function(message, chatType, language, target)
	sentWhispers[#sentWhispers + 1] = {
		message = message,
		chatType = chatType,
		language = language,
		target = target,
	}
end
window.editBox:ClearFocus()
window:RevealComposer(false)
setReplyText("mouse send")
window.send.scripts.OnClick()
expect(#sentWhispers == 2 and sentWhispers[2].message == "mouse send"
	and not window.editBox:HasFocus(),
	"mouse Messenger send stole keyboard focus from another control")

-- A send callback can synchronously change the active conversation (through
-- another addon hook or client event). Complete the captured send, but never
-- clear or focus the newly selected player's composer.
window:SelectSession(replySession)
window:FocusComposer()
setReplyText("switching send")
SendChatMessage = function(message, chatType, language, target)
	sentWhispers[#sentWhispers + 1] = {
		message = message,
		chatType = chatType,
		language = language,
		target = target,
	}
	Manager:OpenForPlayer("SwitchTarget", true)
	setReplyText("new target draft")
	window.editBox:ClearFocus()
end
window.editBox.scripts.OnEnterPressed(window.editBox)
expect(#sentWhispers == 3 and sentWhispers[3].message == "switching send"
	and sentWhispers[3].target == "ReplyTarget" and replySession.draft == "",
	"session-changing Messenger send did not complete against its captured target")
expect(window.playerName == "SwitchTarget" and window.editBox:GetText() == "new target draft"
	and window:GetActiveSession().draft == "new target draft" and not window.editBox:HasFocus(),
	"completed Messenger send cleared or focused a newly selected conversation")
SendChatMessage = nil

settings.conversations.actionButtonStyle = "text"
failTextures = true
window.tabStrip:SetWidth(296)
window.actionsCompactForWidth = nil
window:ApplyChromeLayout(true)
for index = 1, #window.actionButtons do
	expect(window.actionButtons[index].usesIcon, "narrow Messenger must retain every action as an icon")
	expect(window.actionButtons[index].text:IsShown()
		and window.actionButtons[index].text:GetText() == window.actionButtons[index].definition.glyph,
		"missing icon media must fall back to an obvious action glyph")
end
window:ApplyChromeLayout(true)
for index = 1, #window.actionButtons do
	expect(window.actionButtons[index].usesIcon,
		"forced narrow layout restored text actions after the compact decision was cached")
end
failTextures = false
window.tabStrip:SetWidth(500)
window.frame:SetWidth(504)
window.actionsCompactForWidth = nil
window:ApplyChromeLayout(true)
for index = 1, #window.actionButtons do
	expect(not window.actionButtons[index].usesIcon, "text action preference should return when space permits")
end

settings.conversations.titleBarVisibility = "hidden"
settings.conversations.actionVisibility = "always"
settings.conversations.actionStripOrientation = "horizontal"
settings.conversations.actionStripCollapsed = false
window.frame:SetSize(300, 160)
window.tabStrip:SetWidth(296)
Manager:OpenForPlayer("VeryLongPlayerOne", true)
Manager:OpenForPlayer("VeryLongPlayerTwo", true)
window.tabOffset = 1
window:ApplyChromeLayout(true)
expect(window.tabAvailableWidth and window.tabAvailableWidth < 118,
	"minimum horizontal Messenger did not calculate a constrained tab lane")
for _, key in ipairs(Manager.tabOrder) do
	local tab = Manager.sessionsByKey[key] and Manager.sessionsByKey[key].tab
	if tab and tab:IsShown() then
		expect(tab:GetWidth() <= window.tabAvailableWidth,
			"long Messenger tab overlapped the pager/action reserve at minimum width")
	end
end
expect(window.confirm:GetWidth() == 284,
	"server-ignore confirmation does not preserve an eight-pixel minimum-shell gutter")

settings.conversations.actionStripOrientation = "vertical"
settings.conversations.actionStripCollapsed = false
settings.conversations.titleBarVisibility = "hidden"
settings.conversations.actionVisibility = "always"
settings.conversations.composerVisibility = "always"
window.tabStrip:SetWidth(245)
window:ApplyChromeLayout(true)
expect(window.actions.parent == window.frame, "vertical Messenger actions did not attach to the window side")
expect(window.actions.points[1][1] == "TOPRIGHT" and window.actions.points[2][1] == "BOTTOMRIGHT",
	"vertical Messenger actions do not span the protected side lane")
expect(window.content.points[2][4] < -2 and window.composer.points[2][4] < -2,
	"vertical Messenger actions did not reserve non-overlapping content/composer width")
for index = 2, #window.actionButtons do
	expect(window.actionButtons[index].points[1][1] == "TOP",
		"vertical Messenger actions were not stacked down the side")
end
expect(window.close.parent == window.tabStrip and window.close.label:GetText() == "x",
	"hidden Messenger header lost its relocated text-only close control")

settings.conversations.actionStripOrientation = "horizontal"
settings.conversations.autoOpenWhispers = false
settings.conversations.deferInCombat = true
inCombat = true
Manager:OpenForPlayer("Alice", true)
local activeBefore = window.playerKey
Manager:OnMessage({ id = 777, event = "CHAT_MSG_WHISPER", sender = "Bob", direction = "incoming", text = "hello" })
local bob = Manager.sessionsByKey.bob
expect(bob and bob.tab and bob.tab:IsShown(),
	"new incoming sender did not create a visible tab in the existing Messenger")
expect(window.playerKey == activeBefore and bob.unread == 1,
	"new sender stole the active conversation or lost its unread count")
expect(not Manager.pending.bob, "visible Messenger incorrectly deferred harmless tab intake in combat")

window:Hide()
Manager:OnMessage({ id = 778, event = "CHAT_MSG_WHISPER", sender = "Carol", direction = "incoming", text = "hello" })
expect(Manager.sessionsByKey.carol and Manager.sessionsByKey.carol.unread == 1 and not window.frame:IsShown(),
	"popup-disabled hidden Messenger did not retain the new sender tab quietly")

settings.conversations.autoOpenWhispers = true
Manager:OnMessage({ id = 779, event = "CHAT_MSG_WHISPER", sender = "Dan", direction = "incoming", text = "hello" })
expect(Manager.sessionsByKey.dan and Manager.pending.dan and not window.frame:IsShown(),
	"combat deferral should delay only the hidden-shell popup, not Dan's tab creation")

-- Messenger uses the same thumb-only slider language as the main chat panel.
-- Its dedicated lane remains reserved, while the thumb and V appear only when
-- the wrapped-message range can actually scroll.
expect(#slimScrollbars == 1 and window.messageScrollbar == slimScrollbars[1],
	"Messenger did not replace +/- scrolling with one shared slim scrollbar")
for index = 1, #themedButtons do
	local button = themedButtons[index]
	expect(button.parent ~= window.content or (button.labelValue ~= "+" and button.labelValue ~= "-"),
		"Messenger retained a +/- scroll button beside the slim scrollbar")
end
expect(window.scrollToBottomButton and window.scrollToBottomGlyph
	and window.scrollToBottomGlyph:GetText() == "V",
	"Messenger slim scrollbar did not expose its separate bottom-jump affordance")

local display = window.display
local scrollBar = window.messageScrollbar
local scrollThumb = scrollBar:GetThumbTexture()
display.messages = {}
for index = 1, 20 do display.messages[index] = "line " .. index end
display.visibleLineCapacity = 4
display.scrollMaximum = 16
display.currentScroll = 7
display.setScrollOffsetCalls = 0
scrollBar:SetHeight(200)
window.messageScrollMaximum = nil
expect(window:RefreshMessageScrollbar(true), "overflowing Messenger history did not report a scroll range")
expect(scrollBar.minimum == 0 and scrollBar.maximum == 16 and scrollBar:GetValue() == 9,
	"Messenger scrollbar did not invert offset seven across its sixteen-row range")
expect(display.setScrollOffsetCalls == 1,
	"programmatic Messenger scrollbar refresh fed its slider value back into the display")
expect(scrollThumb:IsShown() and scrollBar:IsMouseEnabled() and scrollThumb.width == 6
	and scrollThumb.height == 40,
	"Messenger scrollbar did not expose a proportional themed thumb for overflowing history")
expect(window.scrollToBottomButton:IsShown(),
	"Messenger bottom-jump affordance did not appear while scrolled away from newest")

-- Wrath's vertical Slider minimum is visually at the top; offset zero is the
-- newest line at the bottom. Both drag endpoints must therefore be inverted.
local activeSession = window:GetActiveSession()
activeSession.pendingVisible = 5
display.setScrollOffsetCalls = 0
scrollBar:SetValue(0)
expect(display.currentScroll == 16 and display.setScrollOffsetCalls == 1,
	("dragging Messenger's thumb to the top did not reveal its oldest row (offset=%s, calls=%s, max=%s)")
		:format(tostring(display.currentScroll), tostring(display.setScrollOffsetCalls),
			tostring(scrollBar._messageScrollMaximum)))
scrollBar:SetValue(16)
expect(display.currentScroll == 0 and display.setScrollOffsetCalls == 2,
	"dragging Messenger's thumb to the bottom did not reveal its newest row")
expect(activeSession.pendingVisible == 0 and not window.scrollToBottomButton:IsShown(),
	"dragging Messenger to newest did not clear its pending marker and V control")

display.currentScroll = 7
window.messageScrollMaximum = 16
display.scripts.OnMouseWheel(display, 1)
expect(display.currentScroll == 8 and scrollBar:GetValue() == 8,
	"message-surface wheel scrolling did not synchronize Messenger's slider")
scrollBar.scripts.OnMouseWheel(scrollBar, -1)
expect(display.currentScroll == 7 and scrollBar:GetValue() == 9,
	"scrollbar-lane wheel scrolling did not synchronize Messenger's message surface")

display.messages = { "one", "two", "three" }
display.visibleLineCapacity = 4
display.scrollMaximum = 0
display.currentScroll = 0
window.messageScrollMaximum = nil
expect(not window:RefreshMessageScrollbar(true),
	"non-overflowing Messenger history reported a stale scroll range")
expect(scrollBar:IsShown() and not scrollThumb:IsShown() and not scrollBar:IsMouseEnabled()
	and not window.scrollToBottomButton:IsShown(),
	"non-overflowing Messenger did not retain only its stable invisible scrollbar lane")

display.messages = {}
for index = 1, 20 do display.messages[index] = "line " .. index end
display.visibleLineCapacity = 4
display.scrollMaximum = 16
display.currentScroll = 8
window.messageScrollMaximum = nil
window:RefreshMessageScrollbar(true)
activeSession.pendingVisible = 4
window:UpdateNewButton()
local bottomCalls = rawget(display, "scrollToBottomCalls") or 0
window.scrollToBottomButton.scripts.OnClick()
expect(display.scrollToBottomCalls == bottomCalls + 1 and display.currentScroll == 0,
	"Messenger V control did not invoke the native scroll-to-bottom action")
expect(activeSession.pendingVisible == 0 and not window.newButton:IsShown()
	and not window.scrollToBottomButton:IsShown() and scrollBar:GetValue() == 16,
	"Messenger V control did not clear and synchronize newest-message state")

display.currentScroll = 6
window.messageScrollMaximum = 16
window:RefreshMessageScrollbar(false)
activeSession.pendingVisible = 3
window:UpdateNewButton()
bottomCalls = display.scrollToBottomCalls
window.newButton.scripts.OnClick()
expect(display.scrollToBottomCalls == bottomCalls + 1 and display.currentScroll == 0
	and activeSession.pendingVisible == 0 and not window.newButton:IsShown()
	and not window.scrollToBottomButton:IsShown() and scrollBar:GetValue() == 16,
	"Messenger NEW control did not share the synchronized bottom-jump path")

-- The minimum 300x160 shell must keep readable content clear of the 8px rail,
-- with an additional visible gutter before the 10px V hit target.
window.frame:SetSize(300, 160)
local displayRight = window.display.points[2]
local scrollTop, scrollBottom = scrollBar.points[1], scrollBar.points[2]
local bottomPoint = window.scrollToBottomButton.points[1]
expect(displayRight and displayRight[1] == "BOTTOMRIGHT" and displayRight[4] == -18,
	"minimum Messenger did not reserve its original eighteen-pixel scrollbar lane")
expect(scrollTop and scrollTop[1] == "TOPRIGHT" and scrollTop[4] == -3 and scrollTop[5] == -4
	and scrollBottom and scrollBottom[1] == "BOTTOMRIGHT" and scrollBottom[4] == -3
	and scrollBottom[5] >= 18,
	"Messenger slim thumb escaped its protected minimum-size right lane")
expect(bottomPoint and bottomPoint[1] == "BOTTOMRIGHT" and bottomPoint[4] == -3
	and bottomPoint[5] == 4 and window.scrollToBottomButton:GetWidth() == 10
	and math.abs(displayRight[4]) - (math.abs(bottomPoint[4]) + window.scrollToBottomButton:GetWidth()) >= 4,
	"Messenger V control overlaps text or the minimum-shell border gutter")

-- Background, border, text, and whole-window opacity are independent. The
-- appearance pass must cover the live display and dynamic FontStrings, then
-- run again after Theme refresh overwrites its registered panel styles.
local transparency = settings.conversations.appearance.transparency
transparency.backgroundAlpha = 0.25
transparency.borderAlpha = 0.6
transparency.textAlpha = 0.45
transparency.overallAlpha = 0.8
expect(window:RefreshAppearance(), "Messenger did not expose a live appearance refresh")
expect(window.frame:GetAlpha() == 0.8,
	"Messenger whole-window opacity was not applied only at the outer frame")
for name, panel in pairs({ frame = window.frame, header = window.header, tabs = window.tabStrip,
	content = window.content, composer = window.composer, confirm = window.confirm }) do
	expect(panel.backgroundAlpha == 0.25 and panel.borderAlpha == 0.6,
		("Messenger %s panel did not receive independent background and border opacity")
			:format(name))
end
expect(window.header:GetAlpha() == 1 and window.content:GetAlpha() == 1,
	"Messenger text/overall opacity leaked onto child panels")
expect(window.display:GetAlpha() == 0.45 and window.editBox:GetAlpha() == 0.45
	and window.title:GetAlpha() == 0.45 and window.route:GetAlpha() == 0.45
	and window.scrollToBottomGlyph:GetAlpha() == 0.45,
	"Messenger text opacity did not cover display, editor, and static FontStrings")
for index = 1, #fontStrings do
	expect(fontStrings[index]:GetAlpha() == 0.45,
		("Messenger text opacity skipped themed FontString %d"):format(index))
end
expect(activeSession.tab.text:GetAlpha() == 0.45 and activeSession.tab.badge:GetAlpha() == 0.45
	and activeSession.tab.close.label:GetAlpha() == 0.45,
	"Messenger text opacity did not cover dynamic tab FontStrings")

window.frame:SetAlpha(1)
window.frame.backgroundAlpha, window.frame.borderAlpha = 1, 1
window.confirm.backgroundAlpha, window.confirm.borderAlpha = 1, 1
window.display:SetAlpha(1)
window.title:SetAlpha(1)
activeSession.tab.text:SetAlpha(1)
expect(type(Theme.refresh) == "function", "Messenger did not register for live Theme refresh")
Theme.refresh()
expect(window.frame:GetAlpha() == 0.8 and window.frame.backgroundAlpha == 0.25
	and window.frame.borderAlpha == 0.6 and window.confirm.backgroundAlpha == 0.25
	and window.confirm.borderAlpha == 0.6 and window.display:GetAlpha() == 0.45
	and window.title:GetAlpha() == 0.45 and activeSession.tab.text:GetAlpha() == 0.45,
	"Theme refresh did not restore Messenger's independent appearance settings")

print("ConversationWindowsLayout.mock.lua: PASS")
