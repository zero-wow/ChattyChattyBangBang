-- Focused no-client contract for Smart Chat's SharedMedia typography bridge.
-- Run from the addon root with:
--   lua Tests/SmartChatFontRuntime.mock.lua

local settings = { dock = {} }
local selected = {
	font = "Mono Test",
	size = 14,
	outline = "OUTLINE",
	spacing = 4,
}

ChatFontNormal = {
	GetFont = function()
		return "Fonts\\FRIZQT__.TTF", 12, ""
	end,
}

local media = {
	Fetch = function(_, kind, key)
		if kind == "font" and key == "Mono Test" then
			return "Interface\\AddOns\\Test\\Mono.ttf"
		end
	end,
	RegisterCallback = function(self, receiver, event)
		self.receiver, self.event = receiver, event
	end,
	UnregisterCallback = function(self, receiver, event)
		if self.receiver == receiver and self.event == event then
			self.receiver, self.event = nil, nil
		end
	end,
}

LibStub = function(name, silent)
	return name == "LibSharedMedia-3.0" and media or nil
end

ChattyChattyBangBang = {
	Theme = {},
	Presentation = {},
	GetSmartSettings = function()
		return settings
	end,
	GetSmartChatTextAppearance = function(_, viewId)
		return selected
	end,
}

dofile("Core/SmartDock.lua")

local addon = ChattyChattyBangBang
local dock = addon.SmartDock
local display = {
	SetFont = function(self, path, size, flags)
		self.path, self.size, self.flags = path, size, flags
	end,
	SetFontObject = function(self, fontObject)
		self.fontObject = fontObject
	end,
	SetSpacing = function(self, spacing)
		self.spacing = spacing
	end,
}
local measure = {
	SetFont = function(self, path, size, flags)
		self.path, self.size, self.flags = path, size, flags
	end,
	SetFontObject = function(self, fontObject)
		self.fontObject = fontObject
	end,
}

dock.display = display
dock.messageMeasure = measure
assert(dock:ApplySmartChatTextAppearance("general"), "SharedMedia Smart Chat font did not apply")
assert(display.path == "Interface\\AddOns\\Test\\Mono.ttf" and display.size == 14 and display.flags == "OUTLINE",
	"visible display did not receive the selected SharedMedia font")
assert(measure.path == display.path and measure.size == display.size and measure.flags == display.flags,
	"measurement FontString drifted from the visible chat font")
assert(display.spacing == 4, "visible display did not receive the selected line gap")

-- Wrath returns false (rather than throwing) when a requested face cannot be
-- loaded. Chatty must not report that stale proportional text as successfully
-- switched to a fixed-width font.
local rejectedDisplay = {
	SetFont = function() return false end,
	SetFontObject = function() end,
	SetSpacing = function(self, spacing) self.spacing = spacing end,
}
local rejectedMeasure = {
	SetFont = function() return false end,
	SetFontObject = function() end,
}
dock.display = rejectedDisplay
dock.messageMeasure = rejectedMeasure
assert(not dock:ApplySmartChatTextAppearance("general"),
	"a false SetFont result was incorrectly treated as a successful font change")
assert(rejectedDisplay.spacing == 4,
	"a rejected font should not prevent native line spacing from applying")
local rejectedRebuilds = 0
dock.active = true
dock.activeView = "group"
addon.MessageEngine = {}
dock.RebuildActiveView = function()
	rejectedRebuilds = rejectedRebuilds + 1
end
selected.spacing = 6
local rejectedFont, appliedSpacing = dock:RefreshSmartChatTextAppearance()
assert(not rejectedFont and appliedSpacing and rejectedDisplay.spacing == 6,
	"spacing refresh falsely reported a rejected font or skipped the requested gap")
assert(rejectedRebuilds == 1 and dock.smartChatTextSpacing == 6,
	"accepted line spacing did not rebuild/cache the active display after a font rejection")
dock.display = display
dock.messageMeasure = measure

selected = { size = 0, outline = "INHERIT", spacing = 0 }
assert(dock:ApplySmartChatTextAppearance("general"), "inherited chat font did not apply")
assert(display.fontObject == ChatFontNormal and measure.fontObject == ChatFontNormal,
	"default text appearance did not restore ChatFontNormal consistently")
assert(display.spacing == 0, "zero line gap should remain a valid tight layout")

local rebuilds = 0
dock.active = true
dock.activeView = "group"
addon.MessageEngine = {}
dock.RebuildActiveView = function()
	rebuilds = rebuilds + 1
end
selected = { font = "Mono Test", size = 13, outline = "NONE" }
assert(dock:RefreshSmartChatTextAppearance(), "live font refresh failed")
assert(rebuilds == 1, "live text appearance change did not rebuild the local buffer")

dock:RegisterSmartChatTextMediaCallback()
assert(media.receiver == dock and media.event == "LibSharedMedia_Registered",
	"Smart Chat did not register for SharedMedia font additions")
local callbackRefreshes = 0
dock.RefreshSmartChatTextAppearance = function()
	callbackRefreshes = callbackRefreshes + 1
	return true
end
dock:LibSharedMedia_Registered("LibSharedMedia_Registered", "font")
assert(callbackRefreshes == 1, "new SharedMedia fonts did not refresh the active dock")
dock:UnregisterSmartChatTextMediaCallback()
assert(media.receiver == nil, "Smart Chat left a SharedMedia callback behind after deactivation")

print("Smart Chat font runtime mock passed")
