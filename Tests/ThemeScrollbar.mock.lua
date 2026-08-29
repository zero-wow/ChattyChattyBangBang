-- Focused no-client contract for Chatty's shared, colorway-aware scrollbar.
-- Run from the addon root with: lua Tests/ThemeScrollbar.mock.lua

local activeColorway = "Obsidian Dawn"

ChattyChattyBangBang = {}
function ChattyChattyBangBang:GetSmartSettings()
	return { colorway = activeColorway }
end

UIParent = {}

local Texture = {}
Texture.__index = Texture
function Texture:SetTexture(value) self.texture = value end
function Texture:SetPoint(...) self.point = { ... } end
function Texture:SetAllPoints(target) self.allPoints = target or true end
function Texture:SetWidth(value) self.width = value end
function Texture:SetHeight(value) self.height = value end
function Texture:SetSize(width, height) self.width, self.height = width, height end
function Texture:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
function Texture:SetAlpha(value) self.alpha = value end
function Texture:GetAlpha() return self.alpha == nil and 1 or self.alpha end
function Texture:Show() self.shown = true end
function Texture:Hide() self.shown = false end
function Texture:IsShown() return self.shown ~= false end

local Frame = {}
Frame.__index = Frame
function Frame:SetWidth(value) self.width = value end
function Frame:GetWidth() return self.width or 0 end
function Frame:SetHeight(value) self.height = value end
function Frame:GetHeight() return self.height or 0 end
function Frame:SetSize(width, height) self.width, self.height = width, height end
function Frame:SetPoint(...) self.point = { ... } end
function Frame:SetAllPoints(target) self.allPoints = target or true end
function Frame:SetOrientation(value) self.orientation = value end
function Frame:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
function Frame:GetMinMaxValues() return self.minimum or 0, self.maximum or 0 end
function Frame:SetValueStep(value) self.valueStep = value end
function Frame:SetValue(value) self.value = value end
function Frame:GetValue() return self.value or 0 end
function Frame:SetThumbTexture(value)
	if type(value) == "table" then
		self.thumbTexture = value
	else
		self.thumbTexture = setmetatable({ shown = true, texture = value }, Texture)
	end
end
function Frame:GetThumbTexture() return self.thumbTexture end
function Frame:SetScript(name, callback) self.scripts[name] = callback end
function Frame:HookScript(name, callback)
	local previous = self.scripts[name]
	self.scripts[name] = previous and function(...)
		previous(...)
		callback(...)
	end or callback
end
function Frame:EnableMouseWheel(value) self.mouseWheel = value end
function Frame:CreateTexture()
	local texture = setmetatable({ shown = true }, Texture)
	table.insert(self.createdTextures, texture)
	return texture
end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown ~= false end
function Frame:SetBackdrop() end
function Frame:SetBackdropColor() end
function Frame:SetBackdropBorderColor() end
function Frame:GetName() return self.name end
function Frame:GetRegions()
	return unpack(self.createdTextures)
end

function CreateFrame(frameType, name, parent)
	return setmetatable({
		frameType = frameType,
		name = name,
		parent = parent,
		shown = true,
		scripts = {},
		createdTextures = {},
	}, Frame)
end

dofile("Core/Theme.lua")
local Theme = ChattyChattyBangBang.Theme

local scrollbar = Theme:CreateSlimScrollbar(UIParent)
assert(scrollbar and scrollbar.frameType == "Slider", "slim scrollbar was not built as a native Slider")
assert(scrollbar.orientation == "VERTICAL", "slim scrollbar did not use a vertical value axis")
assert(scrollbar:GetWidth() == 8, "slim scrollbar did not use its compact eight-pixel hit rail")
assert(scrollbar.valueStep == 1, "message scrollbar did not move in whole visual-line steps")
assert(scrollbar.ScrollUpButton == nil and scrollbar.ScrollDownButton == nil,
	"new slim scrollbar recreated the stock arrow buttons")

local thumb = scrollbar:GetThumbTexture()
local track = scrollbar._themeTrack
assert(thumb and thumb == scrollbar:GetThumbTexture(),
	"slim scrollbar did not expose its drag thumb")
assert(thumb.width == 6 and (thumb.height or 0) >= 18,
	"drag thumb did not use the requested six-pixel width and safe minimum height")
assert(not track or not track:IsShown() or track:GetAlpha() == 0,
	"thumb-only scrollbar left a visible track behind the message text")
assert(Theme.scrollBars[scrollbar] and Theme.scrollBars[scrollbar].thumb == thumb,
	"scrollbar thumb was not registered with the shared colorway skin")

Theme:SetScrollBarThumbVisible(scrollbar, false)
assert(not thumb:IsShown() and thumb:GetAlpha() == 0,
	"empty/non-scrollable rail did not suppress its drag thumb")
Theme:SetScrollBarThumbVisible(scrollbar, true)
assert(thumb:IsShown() and thumb:GetAlpha() > 0,
	"scrollable rail did not restore its drag thumb")

local initialThumbColor = thumb.color
activeColorway = "Obsidian Sunbeam"
Theme:Refresh()
local expected = Theme.Colorways[activeColorway].accent
assert(thumb.color and thumb.color ~= initialThumbColor
	and math.abs(thumb.color[1] - expected[1]) < 0.0001
	and math.abs(thumb.color[2] - expected[2]) < 0.0001
	and math.abs(thumb.color[3] - expected[3]) < 0.0001,
	"drag thumb did not follow the active colorway after a live theme refresh")

assert(scrollbar.scripts.OnEnter and scrollbar.scripts.OnLeave,
	"slim scrollbar did not expose hover feedback")
scrollbar.scripts.OnEnter(scrollbar)
expected = Theme.Colorways[activeColorway].goldBright
assert(math.abs(thumb.color[1] - expected[1]) < 0.0001
	and math.abs(thumb.color[2] - expected[2]) < 0.0001
	and math.abs(thumb.color[3] - expected[3]) < 0.0001,
	"hover did not promote the thumb to the colorway's bright accent")
scrollbar.scripts.OnLeave(scrollbar)
expected = Theme.Colorways[activeColorway].accent
assert(math.abs(thumb.color[1] - expected[1]) < 0.0001,
	"leaving the scrollbar did not restore its ordinary accent")

-- Existing stock scrollbars (currently Copy Chat) use the same treatment.
-- Skinning must remove Blizzard's broad arrows/track while preserving the
-- native slider and its scrolling behavior.
local stock = CreateFrame("Slider", "MockStockScrollBar", UIParent)
stock:SetWidth(16)
stock.ScrollUpButton = CreateFrame("Button", nil, stock)
stock.ScrollDownButton = CreateFrame("Button", nil, stock)
stock._stockTrack = stock:CreateTexture()
_G.MockStockScrollBarScrollUpButton = stock.ScrollUpButton
_G.MockStockScrollBarScrollDownButton = stock.ScrollDownButton
_G.MockStockScrollBarBackground = stock._stockTrack
local returned = Theme:SkinScrollBar(stock)
assert(returned == stock, "stock scrollbar skin did not return the original live control")
assert(not stock.ScrollUpButton:IsShown() and not stock.ScrollDownButton:IsShown(),
	"stock scrollbar arrows remained visible after the shared slim skin")
assert(stock:GetWidth() <= 10 and stock:GetThumbTexture(),
	"stock scrollbar did not receive the same compact themed thumb")
assert(not stock._stockTrack:IsShown() or stock._stockTrack:GetAlpha() == 0,
	"stock scrollbar retained visible non-thumb artwork")

local copyFrame = CreateFrame("ScrollFrame", "MockCopyScroll", UIParent)
local copyBar = CreateFrame("Slider", "MockCopyScrollScrollBar", copyFrame)
_G.MockCopyScrollScrollBar = copyBar
_G.MockCopyScrollScrollBarScrollUpButton = CreateFrame("Button", nil, copyBar)
_G.MockCopyScrollScrollBarScrollDownButton = CreateFrame("Button", nil, copyBar)
assert(Theme:SkinScrollFrame(copyFrame) == copyBar and copyBar:GetWidth() == 8,
	"named UIPanelScrollFrame did not resolve and receive Chatty's slim shared skin")
assert(not _G.MockCopyScrollScrollBarScrollUpButton:IsShown()
	and not _G.MockCopyScrollScrollBarScrollDownButton:IsShown(),
	"named Copy Chat-style scroll frame retained its stock arrow caps")

print("Theme slim-scrollbar mock passed")
