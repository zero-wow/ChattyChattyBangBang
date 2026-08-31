-- Focused no-client contract for SmartDock opacity application.

local applied = {}
local Theme = {
	SetFrameOpacity = function(_, frame, fillAlpha, borderAlpha)
		applied[frame] = { fillAlpha, borderAlpha }
	end,
}

ChattyChattyBangBang = {
	Theme = Theme,
	GetSmartChatWindowTransparency = function()
		return { backgroundAlpha = 0.35, borderAlpha = 0.6, overallAlpha = 0.8 }
	end,
}

dofile("Core/SmartDock.lua")
local dock = ChattyChattyBangBang.SmartDock

local frame = {
	SetAlpha = function(self, alpha) self.alpha = alpha end,
}
local header, rail, content, composer, editBorder, alertBar, playerActions = {}, {}, {}, {}, {}, {}, {}
local messageText = {}
dock.frame = frame
dock.header = header
dock.rail = rail
dock.content = content
dock.composer = composer
dock.composerEditBoxBorder = editBorder
dock.alertBar = alertBar
dock.playerActions = playerActions
dock.display = messageText

local ok, appearance = dock:RefreshTransparency()
assert(ok and frame.alpha == 0.8 and appearance.overallAlpha == 0.8,
	"whole-window opacity was not applied to the SmartDock root")
for _, panel in ipairs({ frame, header, rail, content, composer, editBorder }) do
	assert(applied[panel] and applied[panel][1] == 0.35 and applied[panel][2] == 0.6,
		"background/border opacity did not reach every persistent chrome surface")
end
for _, panel in ipairs({ alertBar, playerActions }) do
	assert(applied[panel] and applied[panel][1] == 1 and applied[panel][2] == 1,
		"transient notice/player panel inherited unreadable Smart Chat chrome transparency")
end
assert(applied[messageText] == nil and messageText.alpha == nil,
	"independent chrome opacity faded message text")

print("Smart Chat transparency mock passed")
