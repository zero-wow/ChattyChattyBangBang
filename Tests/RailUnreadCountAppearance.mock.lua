-- Focused no-client contract for inactive Smart Chat rail unread-count text.
-- Run from the addon root with: lua tests/RailUnreadCountAppearance.mock.lua

ChattyChattyBangBang = {
	Theme = {
		GetColor = function() return 1, 0.8, 0.39, 1 end,
		ApplyFrame = function() end,
	},
	Presentation = {},
	db = { profile = { smartChat = {} } },
}

dofile("Core/Settings.lua")

local addon = ChattyChattyBangBang
local settings = addon:GetSmartSettings()
local appearance = addon:GetRailUnreadCountAppearanceSettings()
assert(appearance.alpha == 1 and appearance.fontSize == 0
	and appearance.minimumFontSize == 8 and appearance.maximumFontSize == 16,
	"rail unread-count defaults or documented bounds changed")

local refreshes = 0
addon.SmartDock = {
	RefreshUnreadCountAppearance = function() refreshes = refreshes + 1 end,
}
assert(addon:SetRailUnreadCountAlpha(0.35))
assert(addon:SetRailUnreadCountFontSize(4))
assert(settings.dock.unreadCountAppearance.alpha == 0.35
	and settings.dock.unreadCountAppearance.fontSize == 8,
	"rail unread-count setters did not clamp safely")
assert(addon:SetRailUnreadCountAppearance({ alpha = 3, fontSize = 99 }))
assert(settings.dock.unreadCountAppearance.alpha == 1
	and settings.dock.unreadCountAppearance.fontSize == 16,
	"combined unread-count appearance patch did not clamp")
assert(not addon:SetRailUnreadCountAlpha("bad") and not addon:SetRailUnreadCountFontSize("bad"),
	"invalid unread-count values were accepted")
assert(refreshes == 3, "only successful unread-count writes should refresh the live rail")

-- Existing/future-looking malformed SavedVariables must migrate independently
-- of the separate active-view NEW marker subtree.
settings.dock.unreadCountAppearance = { schema = 99, alpha = -4, fontSize = 3 }
appearance = addon:GetRailUnreadCountAppearanceSettings()
assert(appearance.alpha == 0 and appearance.fontSize == 8,
	"malformed rail unread-count appearance did not repair safely")

addon:GetRailUnreadCountAppearanceSettings() -- normalize before SmartDock reads it
addon.SmartDock = nil
addon.GetSmartViews = function()
	return { { id = "custom", key = "NC" } }
end
dofile("Core/SmartDock.lua")

local dock = addon.SmartDock
local function makeText(text)
	return {
		value = text,
		SetText = function(self, value) self.value = value end,
		SetTextColor = function(self, r, g, b, a) self.color = { r, g, b, a } end,
		SetFont = function(self, _, size) self.fontSize = size return true end,
		SetFontObject = function(self) self.fontSize = 10 end,
		GetStringWidth = function(self) return #(self.value or "") * ((self.fontSize or 10) * 0.6) end,
	}
end
local function makeButton()
	local button = { shown = true, definition = { id = "custom", key = "NC" } }
	button.text = makeText("NC")
	button.unread = makeText("")
	button.unreadDefaultFontPath = "Fonts\\ARIALN.TTF"
	button.unreadDefaultFontFlags = ""
	function button:IsShown() return self.shown end
	function button:SetSize(width, height) self.width, self.height = width, height end
	function button:GetWidth() return self.width or 38 end
	function button:GetHeight() return self.height or 20 end
	function button.unread:Show() self.shown = true end
	function button.unread:Hide() self.shown = false end
	function button.unread:IsShown() return self.shown == true end
	return button
end
local content = {
	SetWidth = function(self, width) self.width = width end,
	SetHeight = function(self, height) self.height = height end,
}
local button = makeButton()
dock.railButtons = { custom = button }
dock.railContent = content
dock.unread = { custom = 125 }
dock.activeView = "general"

assert(addon:SetRailUnreadCountAppearance({ alpha = 0.4, fontSize = 16 }))
dock:RefreshRailState()
assert(button.unread.value == "99+" and button.unread.color[4] == 0.4,
	"rail unread alpha did not affect only the numeric count")
assert(button.width >= 50 and content.width >= button.width,
	"larger unread count did not reserve a non-overlapping rail-tab lane")
assert(button.text.color and button.text.color[4] == 1 and button.text.fontSize == nil,
	"unread appearance unexpectedly changed tab-key alpha or font size")

print("Rail unread-count appearance mock passed")
