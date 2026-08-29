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
function InCombatLockdown() return false end
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
expect(window.composer:IsShown(), "default inherited composer should be visible")
expect(window.actions.parent == window.tabStrip, "actions must share the tab rail")
expect(rawget(window.actions, "themedPanel") ~= true, "actions must not create a second boxed toolbar")
expect(window.close.label:GetText() == "x" and rawget(window.close, "themedButton") ~= true,
	"shell close must be a bare lowercase text control")
for index = 1, #window.actionButtons do
	expect(window.actionButtons[index]:IsShown(), "every contextual action should be shown")
end

settings.conversations.titleBarVisibility = "hidden"
window:ApplyChromeLayout(true)
expect(not window.header:IsShown(), "hidden title must reclaim its row")
expect(window.close.parent == window.tabStrip, "close must move to the remaining top rail")
expect(window.content.points[1][2] == window.tabStrip,
	"content must remain below the tab/action rail")

settings.conversations.actionVisibility = "hidden"
window:ApplyChromeLayout(true)
expect(not window.actions:IsShown(), "hidden actions should release their rail width")

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
failTextures = false
window.tabStrip:SetWidth(356)
window.actionsCompactForWidth = nil
window:ApplyChromeLayout(true)
for index = 1, #window.actionButtons do
	expect(not window.actionButtons[index].usesIcon, "text action preference should return when space permits")
end

print("ConversationWindowsLayout.mock.lua: PASS")
