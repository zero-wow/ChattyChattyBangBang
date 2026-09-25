-- Run from the addon root with: lua Tests/RetailChatSafety.mock.lua
local activated = 0
ChatFrameUtil = {
	ActivateChat = function() activated = activated + 1 end,
}
ChattyChattyBangBang = {
	Theme = {},
	Presentation = {},
	ClientAPI = { IsRetail = function() return true end },
}
dofile("Core/SmartDock.lua")
local dock = ChattyChattyBangBang.SmartDock
dock.IsReadOnlyView = function() return false end
dock.ApplyComposerRoute = function() return true end
dock.editBox = {}
dock:ActivateComposer()
assert(activated == 1, "Retail composer did not use ChatFrameUtil.ActivateChat")

dock:HideNativeChat()
assert(dock.nativeSnapshot == nil, "Retail native chat must remain visible for restricted messages")
dock.active = true
dock:SuppressTemporaryChatFrame({})
assert(dock.nativeSnapshot == nil, "Retail temporary chat was suppressed")

print("Retail chat safety mock tests passed")
