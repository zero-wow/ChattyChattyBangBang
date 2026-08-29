-- Focused no-client contract for the fixed-size settings workspace.  The
-- console keeps its reviewed 840x570 logical layout, but scales and clamps as
-- one unit when UIParent is smaller or its effective viewport changes.

local Frame = {}
Frame.__index = Frame

local function frame(parent)
	return setmetatable({ parent = parent, shown = true, enabled = true, scripts = {}, events = {} }, Frame)
end

function Frame:SetPoint(...)
	self.point = { ... }
end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetAllPoints(target) self.allPoints = target or true end
function Frame:SetSize(width, height) self.width, self.height = width, height end
function Frame:SetWidth(width) self.width = width end
function Frame:SetHeight(height) self.height = height end
function Frame:GetWidth() return self.width or 0 end
function Frame:GetHeight() return self.height or 0 end
function Frame:SetScale(value) self.scale = value end
function Frame:GetScale() return self.scale or 1 end
function Frame:GetEffectiveScale()
	local parentScale = self.parent and self.parent.GetEffectiveScale and self.parent:GetEffectiveScale() or 1
	return parentScale * (self.scale or 1)
end
function Frame:SetClampedToScreen(value) self.clampedToScreen = value and true or false end
function Frame:SetFrameStrata() end
function Frame:SetToplevel() end
function Frame:SetMovable() end
function Frame:RegisterForDrag() end
function Frame:EnableMouse() end
function Frame:EnableMouseWheel(value) self.mouseWheelEnabled = value and true or false end
function Frame:SetScrollChild(child) self.scrollChild = child end
function Frame:SetVerticalScroll(value) self.verticalScroll = value end
function Frame:GetVerticalScroll() return self.verticalScroll or 0 end
function Frame:GetVerticalScrollRange() return self.verticalScrollRange or 0 end
function Frame:SetJustifyH() end
function Frame:SetTextColor() end
function Frame:SetTexture() end
function Frame:SetVertexColor() end
function Frame:SetAlpha() end
function Frame:SetAutoFocus() end
function Frame:SetMultiLine() end
function Frame:SetFontObject() end
function Frame:SetTextInsets() end
function Frame:SetMaxLetters() end
function Frame:ClearFocus() end
function Frame:SetFocus() end
function Frame:Raise() self.raised = true end
function Frame:StartMoving() self.moving = true end
function Frame:StopMovingOrSizing() self.moving = false end
function Frame:SetText(value) self.textValue = tostring(value or "") end
function Frame:GetText() return self.textValue or "" end
function Frame:IsShown() return self.shown ~= false end
function Frame:Enable() self.enabled = true end
function Frame:Disable() self.enabled = false end

function Frame:SetScript(name, callback)
	self.scripts[name] = callback
end
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
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:Show()
	self.shown = true
	if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Frame:Hide()
	self.shown = false
	if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Frame:CreateTexture() return frame(self) end
function Frame:CreateFontString() return frame(self) end

local function anchorPixels(relative, point)
	local scale = relative:GetEffectiveScale()
	local width = relative:GetWidth() * scale
	local height = relative:GetHeight() * scale
	local x = string.find(point or "CENTER", "LEFT", 1, true) and 0
		or (string.find(point or "CENTER", "RIGHT", 1, true) and width or (width / 2))
	local y = string.find(point or "CENTER", "BOTTOM", 1, true) and 0
		or (string.find(point or "CENTER", "TOP", 1, true) and height or (height / 2))
	return x, y
end

function Frame:GetCenter()
	if self == UIParent then
		return self:GetWidth() / 2, self:GetHeight() / 2
	end
	local point = self.point or { "CENTER", self.parent or UIParent, "CENTER", 0, 0 }
	local relative = point[2] or self.parent or UIParent
	local relativePoint = point[3] or point[1] or "CENTER"
	local baseX, baseY = anchorPixels(relative, relativePoint)
	local ownScale = self:GetEffectiveScale()
	local centerPixelsX = baseX + ((tonumber(point[4]) or 0) * ownScale)
	local centerPixelsY = baseY + ((tonumber(point[5]) or 0) * ownScale)
	return centerPixelsX / ownScale, centerPixelsY / ownScale
end
function Frame:GetLeft()
	local center = self:GetCenter()
	return center - (self:GetWidth() / 2)
end
function Frame:GetRight()
	local center = self:GetCenter()
	return center + (self:GetWidth() / 2)
end
function Frame:GetBottom()
	local _, center = self:GetCenter()
	return center - (self:GetHeight() / 2)
end
function Frame:GetTop()
	local _, center = self:GetCenter()
	return center + (self:GetHeight() / 2)
end

function CreateFrame(_, _, parent) return frame(parent) end

UIParent = frame()
UIParent:SetSize(800, 540)
GameFontNormalLarge = {}
GameFontNormal = {}
GameFontNormalSmall = {}
GameFontHighlightSmall = {}

local Theme = {
	texts = {}, frames = {}, textures = {}, NO_BORDER = "none",
	ICON_PATH = "Interface\\Icons\\INV_Misc_QuestionMark",
}
function Theme:GetColor() return 1, 1, 1, 1 end
function Theme:GetPalette()
	return {
		background = { 0, 0, 0, 1 }, surface = { 0, 0, 0, 1 },
		surfaceRaised = { 0, 0, 0, 1 }, accentSoft = { 0, 0, 0, 1 },
		gold = { 1, 0.8, 0.2, 1 }, accent = { 0.5, 0.5, 1, 1 },
	}
end
function Theme:CreatePanel(parent) return frame(parent) end
function Theme:CreateQuietPanel(parent) return frame(parent) end
function Theme:CreateText(parent) return frame(parent) end
function Theme:CreateButton(parent, text, width, height)
	local button = frame(parent)
	button:SetSize(width or 20, height or 20)
	button.text = frame(button)
	button.text:SetText(text)
	function button:SetLabel(value) self.text:SetText(value) end
	function button:SetTheme() end
	function button:SetHoverTheme() end
	function button:SetTooltip(title, body) self.tooltipTitle, self.tooltipBody = title, body end
	return button
end
function Theme:CreateTightButton(parent, text, height)
	return self:CreateButton(parent, text, math.max(height or 20, (#tostring(text) * 6) + 6), height or 20)
end
function Theme:RegisterTexture() end
function Theme:RegisterFrame() end
function Theme:ApplyFrame() end
function Theme:RegisterRefreshCallback(callback) self.refreshCallback = callback end

ChattyChattyBangBang = { Theme = Theme }
local addon = ChattyChattyBangBang

dofile("Core/Config.lua")
local config = addon.CustomConfig
config:BuildFrame()
config.ShowPage = function(self, page) self.activePage = page end

local function nearlyEqual(left, right)
	return math.abs((left or 0) - (right or 0)) < 0.0001
end

local function boundsPixels(widget)
	local scale = widget:GetEffectiveScale()
	return widget:GetLeft() * scale, widget:GetRight() * scale,
		widget:GetBottom() * scale, widget:GetTop() * scale
end

local function assertViewportGutters(widget, width, height, context)
	local left, right, bottom, top = boundsPixels(widget)
	assert(left >= 12 - 0.001 and right <= width - 12 + 0.001,
		context .. " lost its horizontal 12px screen gutters")
	assert(bottom >= 12 - 0.001 and top <= height - 12 + 0.001,
		context .. " lost its vertical 12px screen gutters")
end

-- Open and OnShow both apply the viewport fit. The page keeps its logical
-- dimensions while the whole console uses the limiting height ratio.
config:Open()
local expectedSmallScale = (540 - 24) / 570
assert(config.frame:GetWidth() == 840 and config.frame:GetHeight() == 570,
	"viewport fitting changed the reviewed 840x570 logical workspace")
assert(nearlyEqual(config.frame:GetScale(), expectedSmallScale),
	"small viewport did not scale the complete settings workspace")
assert(config.frame.clampedToScreen,
	"settings frame did not retain the client's built-in screen clamp")
assertViewportGutters(config.frame, 800, 540, "small viewport")

-- Both target-client viewport events are registered. A larger display restores
-- exact 1:1 scale without moving any edge beyond the safe screen area.
assert(config.frame.events.UI_SCALE_CHANGED and config.frame.events.DISPLAY_SIZE_CHANGED,
	"settings frame did not register both viewport-change events")
UIParent:SetSize(1600, 1000)
config.frame.scripts.OnEvent(config.frame, "DISPLAY_SIZE_CHANGED")
assert(nearlyEqual(config.frame:GetScale(), 1),
	"large viewport incorrectly upscaled or retained the compact scale")
assertViewportGutters(config.frame, 1600, 1000, "large viewport")

-- A moved panel may be beyond two edges when scale/display settings change.
-- The UI-scale event must pull only the offending position back inside.
config.frame:ClearAllPoints()
config.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", -200, -200)
config.frame.scripts.OnEvent(config.frame, "UI_SCALE_CHANGED")
assertViewportGutters(config.frame, 1600, 1000, "off-screen clamp")

-- OnShow is an independent safeguard for clients that update UIParent before
-- dispatching their display event or while the settings frame is hidden.
UIParent:SetSize(700, 500)
config.frame:Hide()
config.frame:Show()
local expectedNarrowScale = (700 - 24) / 840
assert(nearlyEqual(config.frame:GetScale(), expectedNarrowScale),
	"OnShow did not refit the workspace to the new limiting width")
assertViewportGutters(config.frame, 700, 500, "OnShow viewport")

print("Config viewport mock tests passed")
