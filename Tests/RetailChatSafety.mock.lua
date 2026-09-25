-- Run from the addon root with: lua Tests/RetailChatSafety.mock.lua
local activated = 0
local lastToldTarget
ChatFrameUtil = {
	ActivateChat = function() activated = activated + 1 end,
	SetLastToldTarget = function(name, chatType)
		lastToldTarget = { name, chatType }
	end,
}
ChattyChattyBangBang = {
	Theme = {},
	Presentation = {},
	ClientAPI = { IsRetail = function() return true end },
}
dofile("Core/SmartDock.lua")
local dock = ChattyChattyBangBang.SmartDock
dock.IsReadOnlyView = function() return false end
local actualApplyComposerRoute = dock.ApplyComposerRoute
dock.ApplyComposerRoute = function() return true end
dock.editBox = {}
dock:ActivateComposer()
assert(activated == 1, "Retail composer did not use ChatFrameUtil.ActivateChat")
dock.ApplyComposerRoute = actualApplyComposerRoute

local route, target = "WHISPER", "RetailFriend"
local box = {
	SetChatType = function(self, value) self.chatType = value end,
	GetChatType = function(self) return self.chatType end,
	SetTellTarget = function(self, value) self.tellTarget = value end,
	GetTellTarget = function(self) return self.tellTarget end,
	UpdateHeader = function(self) self.headerUpdated = true end,
}
dock.editBox = box
dock.GetComposerRoute = function() return route, target end
dock.HideNativeComposerChrome = function() end
assert(dock:ApplyComposerRoute(), "Retail composer route did not apply")
assert(box.chatType == "WHISPER" and box.tellTarget == "RetailFriend"
	and box.headerUpdated and lastToldTarget and lastToldTarget[2] == "WHISPER",
	"Retail composer did not use current edit-box methods")
assert(dock:CaptureComposerRouteFromEditBox(), "Retail route could not be read back")

local native = { shown = true, alpha = 1, mouse = true }
function native:IsShown() return self.shown end
function native:GetAlpha() return self.alpha end
function native:IsMouseEnabled() return self.mouse end
function native:SetAlpha(value) self.alpha = value end
function native:EnableMouse(value) self.mouse = value end
function native:Hide() self.shown = false end
function native:Show() self.shown = true end
function native:HookScript() end
ChatFrame1 = native
NUM_CHAT_WINDOWS = 1
local settings = { dock = { hideNativeChat = true } }
ChattyChattyBangBang.GetSmartSettings = function() return settings end
dock.active = true
local shown = true
dock.frame = { IsShown = function() return shown end }
dock.visibleState = true
dock:HideNativeChat()
assert(dock.nativeSnapshot and not native.shown,
	"explicit Retail preference did not hide Blizzard chat")
dock.visibleState = false
dock:SyncNativeChatVisibility()
assert(native.shown and dock.nativeSnapshot == nil,
	"hiding Smart Dock must restore Blizzard chat")
dock.visibleState = true
settings.dock.hideNativeChat = false
dock:SyncNativeChatVisibility()
assert(native.shown, "turning off native-chat hiding did not keep Blizzard chat visible")
settings.dock.hideNativeChat = true
dock:SyncNativeChatVisibility()
assert(not native.shown, "turning native-chat hiding back on did not apply")
shown = false
dock:SyncNativeChatVisibility()
assert(native.shown, "a hidden Smart Dock left Blizzard chat hidden")
dock:SuppressTemporaryChatFrame({})
assert(dock.nativeSnapshot == nil, "hidden Smart Dock suppressed temporary chat")

print("Retail chat safety mock tests passed")
