-- Smart Dock's session-only composer recall must not replace Blizzard's
-- command/Alt-arrow history or retain private message bodies.
-- Run from the addon root: lua Tests/SmartDockComposerHistory.mock.lua

ChattyChattyBangBang = { Theme = {}, Presentation = {} }
dofile("Core/SmartDock.lua")
local dock = ChattyChattyBangBang.SmartDock

local altDown, controlDown, shiftDown = false, false, false
IsAltKeyDown = function() return altDown end
IsControlKeyDown = function() return controlDown end
IsShiftKeyDown = function() return shiftDown end
issecretvalue = function(value) return value == "synthetic secret" end

local editBox = {
	text = "",
	chatType = "SAY",
	hooks = {},
	propagation = nil,
	altArrowMode = true,
}
function editBox:HookScript(script, callback)
	assert(not self.hooks[script], "composer history installed a duplicate " .. script .. " hook")
	self.hooks[script] = callback
end
function editBox:GetText() return self.text end
function editBox:SetText(text)
	self.text = text
	if self.hooks.OnTextChanged then self.hooks.OnTextChanged(self, false) end
end
function editBox:GetChatType() return self.chatType end
function editBox:GetAltArrowKeyMode() return self.altArrowMode end
function editBox:SetCursorPosition(position) self.cursor = position end
function editBox:SetPropagateKeyboardInput(enabled) self.propagation = enabled end

EventRegistry = {
	registrations = 0,
	RegisterCallback = function(self, event, callback, owner)
		assert(event == "ChatFrame.OnEditBoxPreSendText")
		self.registrations = self.registrations + 1
		self.callback, self.owner = callback, owner
	end,
}

dock.active = true
dock.editBox = editBox
dock:BindComposerHistory(editBox)
dock:BindComposerHistory(editBox)
assert(EventRegistry.registrations == 1 and EventRegistry.owner == dock,
	"pre-send history callback was missing or installed more than once")
assert(not editBox.hooks.OnArrowPressed and editBox.altArrowMode == true,
	"Chatty replaced Blizzard's native Alt-arrow command/history handler")

local function send(text, chatType)
	editBox.text = text
	editBox.chatType = chatType or "SAY"
	EventRegistry.callback(EventRegistry.owner, editBox)
end
local function key(direction)
	editBox.hooks.OnKeyDown(editBox, direction)
end

send("first public line")
send("second public line", "GUILD")
send("second public line", "GUILD")
assert(#dock.composerHistory == 2, "identical consecutive sends should not crowd the recall list")
send("private text", "WHISPER")
send("battle.net private text", "BN_WHISPER")
send("conversation private text", "BN_CONVERSATION")
send("/reload", "SAY")
send(" /dump hidden", "SAY")
send("synthetic secret", "SAY")
send("   ", "SAY")
assert(#dock.composerHistory == 2, "private replies, slash commands, or blank text entered Chatty recall")

editBox.chatType = "SAY"
editBox.text = "unfinished draft"
key("UP")
assert(editBox.text == "second public line" and dock.composerHistoryDraft == "unfinished draft"
	and editBox.propagation == false, "Up did not recall the newest public send or preserve the draft")
editBox.hooks.OnKeyUp(editBox, "UP")
assert(editBox.propagation == true, "handled arrow propagation remained suppressed after key release")
key("UP")
assert(editBox.text == "first public line", "second Up did not reach the older send")
key("UP")
assert(editBox.text == "first public line", "Up moved past the oldest retained send")
key("DOWN")
assert(editBox.text == "second public line", "Down did not move toward the newest send")
key("DOWN")
assert(editBox.text == "unfinished draft" and dock.composerHistoryIndex == nil
	and dock.composerHistoryDraft == nil, "Down did not restore and release the unsent draft")

editBox.text = "/ccbb con"
key("UP")
assert(editBox.text == "/ccbb con" and dock.composerHistoryIndex == nil,
	"a partially typed slash command was overwritten by Chatty recall")
editBox.text = "another draft"
altDown = true
key("UP")
altDown = false
assert(editBox.text == "another draft" and dock.composerHistoryIndex == nil,
	"Alt+Up must remain reserved for Blizzard's native command history")
controlDown = true
key("UP")
controlDown = false
assert(editBox.text == "another draft" and dock.composerHistoryIndex == nil,
	"modified arrow key was captured by Chatty recall")
editBox.altArrowMode = false
key("UP")
editBox.altArrowMode = true
assert(editBox.text == "another draft" and dock.composerHistoryIndex == nil,
	"Chatty double-stepped an edit box whose native arrows were enabled")

AutoCompleteBox = { parent = editBox, IsShown = function() return true end }
key("UP")
assert(editBox.text == "another draft" and dock.composerHistoryIndex == nil,
	"Chatty recall stole an arrow from Blizzard's autocomplete popup")
AutoCompleteBox = nil

editBox.chatType = "WHISPER"
key("UP")
assert(editBox.text == "another draft" and dock.composerHistoryIndex == nil,
	"Chatty recall appeared while a private reply was active")
editBox.chatType = "SAY"
key("UP")
editBox.text = "edited recalled line"
editBox.hooks.OnTextChanged(editBox, true)
assert(dock.composerHistoryIndex == nil and dock.composerHistoryDraft == nil
	and not dock:HandleComposerHistoryKey(editBox, "DOWN"),
	"typing after recall did not return to ordinary draft editing")

for index = 1, 101 do
	send("line " .. index)
end
assert(#dock.composerHistory == 100 and dock.composerHistory[1] == "line 2"
	and dock.composerHistory[100] == "line 101", "recall exceeded its 100-message session cap")

dock:ClearComposerHistory()
assert(dock.composerHistory == nil and dock.composerHistoryIndex == nil
	and dock.composerHistoryDraft == nil, "deactivation/profile reset did not clear session recall")
print("Smart Dock composer history mock passed")
