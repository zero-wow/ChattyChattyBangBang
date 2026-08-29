-- Focused no-client contract for live, single-line Tight-button text fitting.
-- Run from the addon root with: lua Tests/ThemeTextFit.mock.lua

local metricScale = 1

ChattyChattyBangBang = {}
function ChattyChattyBangBang:GetSmartSettings()
	return { colorway = "Obsidian Dawn" }
end

GameFontNormalSmall = {}
UIParent = {}

local FontString = {}
FontString.__index = FontString
function FontString:SetPoint() end
function FontString:SetJustifyH(value) self.justify = value end
function FontString:SetTextColor() end
function FontString:SetText(value) self.text = tostring(value or "") end
function FontString:SetWidth(value) self.width = value end
function FontString:GetWidth() return self.width end
function FontString:SetHeight(value) self.height = value end
function FontString:SetWordWrap(value) self.wordWrap = value end
function FontString:SetNonSpaceWrap(value) self.nonSpaceWrap = value end
function FontString:GetFont() return "mock-font", 10, "" end
function FontString:GetStringWidth()
	local intrinsic = string.len(self.text or "") * 7 * metricScale
	-- Model a 3.3.5 client that reports the clipped region when constrained.
	if self.width then return math.min(intrinsic, self.width) end
	return intrinsic
end

local Frame = {}
Frame.__index = Frame
function Frame:SetWidth(value)
	self.width = value
	local callback = self.scripts and self.scripts.OnSizeChanged
	if callback then callback(self, self.width, self.height) end
end
function Frame:GetWidth() return self.width end
function Frame:SetHeight(value)
	self.height = value
	local callback = self.scripts and self.scripts.OnSizeChanged
	if callback then callback(self, self.width, self.height) end
end
function Frame:GetHeight() return self.height end
function Frame:SetBackdrop(value) self.backdrop = value end
function Frame:SetBackdropColor() end
function Frame:SetBackdropBorderColor() end
function Frame:SetScript(name, callback) self.scripts[name] = callback end
function Frame:HookScript(name, callback)
	local previous = self.scripts[name]
	if previous then
		self.scripts[name] = function(...)
			previous(...)
			callback(...)
		end
	else
		self.scripts[name] = callback
	end
end
function Frame:CreateFontString()
	return setmetatable({}, FontString)
end

function CreateFrame()
	return setmetatable({ scripts = {} }, Frame)
end

GameTooltip = {
	lines = {},
	SetOwner = function(self, owner) self.owner = owner end,
	GetOwner = function(self) return self.owner end,
	SetText = function(self, value) self.title = value end,
	AddLine = function(self, value) table.insert(self.lines, value) end,
	Show = function(self) self.shown = true end,
	Hide = function(self) self.shown = false end,
}

dofile("Core/Theme.lua")
local Theme = ChattyChattyBangBang.Theme

local tight = Theme:CreateTightButton(UIParent, "MOUSEOVER", 22, false)
local initialIntrinsic = string.len("MOUSEOVER") * 7
assert(tight:GetWidth() >= initialIntrinsic + Theme.TIGHT_BUTTON_PADDING,
	"Tight button measured its already-constrained FontString")
assert(tight.text.wordWrap == false and tight.text.nonSpaceWrap == false,
	"button labels were not forced to a single line")
assert(tight.text:GetWidth() == tight:GetWidth() - (Theme.BUTTON_TEXT_INSET * 2),
	"button label did not reserve the shared visible edge gutter")
assert(not tight._themeLabelClipped, "fresh auto-fitted label was still clipped")

metricScale = 1.35
tight.scripts.OnShow(tight)
local shownIntrinsic = string.len("MOUSEOVER") * 7 * metricScale
assert(tight:GetWidth() >= math.ceil(shownIntrinsic) + Theme.TIGHT_BUTTON_PADDING,
	"OnShow did not follow late font/UI-scale metrics")

tight:SetLabel("CONFIRM DELETE")
local changedIntrinsic = string.len("CONFIRM DELETE") * 7 * metricScale
assert(tight:GetWidth() >= math.ceil(changedIntrinsic) + Theme.TIGHT_BUTTON_PADDING,
	"SetLabel did not refit a dynamic Tight-button label")

local refreshed = Theme:CreateTightButton(UIParent, "LAYOUT", 20, false)
local beforeRefresh = refreshed:GetWidth()
metricScale = 1.7
Theme:Refresh()
assert(refreshed:GetWidth() > beforeRefresh and not refreshed._themeLabelClipped,
	"Theme refresh did not remeasure auto-sized button labels")

local capped = Theme:CreateTightButton(UIParent, "GLOBAL BEHAVIOR", 20, false)
capped:SetWidth(48)
assert(not capped._themeTightAutoFit and capped._themeExplicitWidth,
	"an explicit Tight-button width was not preserved as a caller-owned cap")
local cappedWidth = capped:GetWidth()
metricScale = 2
capped.scripts.OnShow(capped)
Theme:Refresh()
assert(capped:GetWidth() == cappedWidth and capped._themeLabelClipped,
	"Show/Refresh overrode an explicit width or failed to detect clipping")
capped.scripts.OnEnter(capped)
assert(GameTooltip.shown and GameTooltip.title == "GLOBAL BEHAVIOR",
	"a clipped fixed-width button did not expose its complete label")

local fixed = Theme:CreateButton(UIParent, "FIXED WIDTH LABEL", 42, 20, false)
fixed:SetLabel("AN EVEN LONGER FIXED LABEL")
assert(fixed:GetWidth() == 42 and fixed._themeLabelClipped,
	"ordinary fixed-width buttons expanded or lost their safe clipping")

print("Theme text-fit mock tests passed")
