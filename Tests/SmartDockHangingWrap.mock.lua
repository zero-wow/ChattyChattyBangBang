-- Focused no-client contract for Smart Chat's native hanging-wrap bridge.
-- Run from the addon root with: lua Tests/SmartDockHangingWrap.mock.lua

ChattyChattyBangBang = {
	Theme = {},
	Presentation = {},
}

dofile("Core/SmartDock.lua")

local dock = ChattyChattyBangBang.SmartDock
local display = {
	SetIndentedWordWrap = function(self, enabled)
		self.indentedWordWrap = enabled
	end,
	SetNonSpaceWrap = function(self, enabled)
		self.nonSpaceWrap = enabled
	end,
}
local measure = {
	SetIndentedWordWrap = function(self, enabled)
		self.indentedWordWrap = enabled
	end,
	SetNonSpaceWrap = function(self, enabled)
		self.nonSpaceWrap = enabled
	end,
}

assert(dock:ApplyHangingMessageWrap(display, measure, false),
	"visible message frame did not accept the exact-wrap mode")
assert(display.indentedWordWrap == false and measure.indentedWordWrap == false,
	"the native generic indent remained active beneath explicit hanging breaks")
assert(display.nonSpaceWrap and measure.nonSpaceWrap,
	"long unbroken text can still escape the Smart Chat bounds")

assert(dock:ApplyHangingMessageWrap(display, measure, true),
	"unaligned views could not restore Blizzard's native wrapping")
assert(display.indentedWordWrap and measure.indentedWordWrap,
	"visible and measurement text diverged after native wrap was restored")

-- Runtime column capacity is measured from the actual active fixed-width face,
-- not guessed from font size. Two unused cells plus a one-pixel edge prevent a
-- second client wrap after Chatty inserts its explicit breaks.
local displayWidth = 401
display.GetWidth = function() return displayWidth end
measure.SetWidth = function(self, width) self.width = width end
measure.SetText = function(self, text) self.text = text end
measure.GetStringWidth = function(self)
	return self.text == string.rep("M", 32) and 320 or 0
end
dock.display = display
dock.messageMeasure = measure
assert(dock:GetDisplayColumnCapacity() == 38, "fixed-width display capacity was measured incorrectly")
displayWidth = 641
assert(dock:GetDisplayColumnCapacity() == 62,
	"resized display did not refresh the live fixed-width column capacity")
displayWidth = 401
assert(dock:GetDisplayColumnCapacity() == 38,
	"shrinking the display did not restore its narrower column capacity")

ChattyChattyBangBang.GetViewSourceColumnAlignment = function() return true end
ChattyChattyBangBang.GetViewSenderColumnAlignment = function() return false end
ChattyChattyBangBang.Presentation.FormatWrapped = function(_, record, sourceWidth, senderWidth, senderSpacing, columns)
	assert(record.id == 9 and sourceWidth == 12 and senderWidth == 16 and senderSpacing == 2,
		"exact renderer lost active alignment inputs")
	assert(columns == 38, "exact renderer did not receive conservative display columns")
	return "EXACT"
end
ChattyChattyBangBang.Presentation.Format = function() return "NATIVE" end
dock.activeView = "general"
dock.activeSourceColumnWidth = 12
dock.activeSenderColumnWidth = 16
dock.activeSenderColumnAlignmentSpacing = 2
assert(dock:FormatDisplayRecord({ id = 9 }) == "EXACT",
	"aligned Smart Chat did not select the exact hanging renderer")

print("SmartDock hanging-wrap mock passed")
