local function expect(value, message)
	if not value then error(message or "expectation failed", 2) end
end

local frames = {}
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
	function object:SetFrameLevel(level) self.frameLevel = level end
	function object:GetFrameLevel() return self.frameLevel end
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
	function object:AtBottom() return true end
	function object:GetName() return nil end
	setmetatable(object, { __index = function()
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
function Theme:CreatePanel(parent)
	local panel = newFrame("Panel", parent)
	panel.themedPanel = true
	return panel
end
function Theme:CreateText(parent)
	return newFrame("FontString", parent)
end
local function themedButton(parent, text, width, height)
	local button = newFrame("Button", parent)
	button:SetSize(width or 40, height or 18)
	button.text = Theme:CreateText(button)
	button:SetLabel(text)
	button.themedButton = true
	return button
end
function Theme:CreateTightButton(parent, text, height) return themedButton(parent, text, 40, height) end
function Theme:CreateButton(parent, text, width, height) return themedButton(parent, text, width, height) end
function Theme:GetColor() return 1, 1, 1, 1 end
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

print("ConversationWindowsLayout.mock.lua: PASS")
