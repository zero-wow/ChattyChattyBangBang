-- Run from the addon root with: lua Tests/RetailReplyHooks.mock.lua
local hooks = {}
hooksecurefunc = function(owner, method, callback)
	assert(owner == ChatFrameUtil and type(method) == "string")
	hooks[method] = callback
end
ChatFrameUtil = {
	ReplyTell = function() end,
	ReplyTell2 = function() end,
	GetLastTellTarget = function() return "ReplyFriend" end,
	GetLastToldTarget = function() return "ToldFriend" end,
}
ChattyChattyBangBang = { Theme = {}, Presentation = {}, MessageEngine = {} }
dofile("Core/ConversationWindows.lua")
local manager = ChattyChattyBangBang.ConversationWindows
local chosen
manager.ActivateReplyTarget = function(_, name, editBox)
	chosen = { name, editBox }
end
manager:InstallReplyHooks()
assert(hooks.ReplyTell and hooks.ReplyTell2, "Retail reply functions were not hooked")
local editBox = {}
hooks.ReplyTell({ editBox = editBox })
assert(chosen[1] == "ReplyFriend" and chosen[2] == editBox, "/r lost its Retail target")
hooks.ReplyTell2({ editBox = editBox })
assert(chosen[1] == "ToldFriend", "/rr lost its Retail target")

print("Retail reply hooks mock tests passed")
