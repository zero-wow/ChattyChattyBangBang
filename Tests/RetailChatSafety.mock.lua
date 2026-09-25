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

dock:HideNativeChat()
assert(dock.nativeSnapshot == nil, "Retail native chat must remain visible for restricted messages")
dock.active = true
dock:SuppressTemporaryChatFrame({})
assert(dock.nativeSnapshot == nil, "Retail temporary chat was suppressed")

print("Retail chat safety mock tests passed")
