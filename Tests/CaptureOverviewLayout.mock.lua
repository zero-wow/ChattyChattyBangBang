-- Run from addon root: lua Tests/CaptureOverviewLayout.mock.lua
local function widget(parent, height)
	local item = { parent = parent, height = height or 0 }
	function item:SetPoint(point, relative, relativePoint, x, y)
		self.point = { point, relative, relativePoint, x or 0, y or 0 }
	end
	function item:SetSize(width, newHeight) self.width, self.height = width, newHeight end
	function item:SetWidth(width) self.width = width end
	function item:SetHeight(newHeight) self.height = newHeight end
	function item:SetText(value) self.text = value end
	function item:SetTextColor() end
	function item:SetJustifyH() end
	function item:SetTexture() end
	function item:SetValue() end
	function item:CreateTexture() return widget(self) end
	return item
end

local hero, title, detail, status
local theme = { texts = {}, ICON_PATH = "mock-icon" }
function theme:CreatePanel(page)
	hero = widget(page)
	return hero
end
function theme:CreateText(parent, font)
	local text = widget(parent, font == "GameFontNormal" and 20 or 12)
	if parent == hero and not title then
		title = text
	elseif parent == hero and not detail then
		detail = text
	elseif parent == hero then
		status = text
	end
	return text
end
function theme:CreateToggle(page)
	return widget(page, 36)
end
function theme:GetColor() return 1, 1, 1, 1 end

local settings = {
	enabled = true, launcher = { minimap = { hide = false } },
}
ChattyChattyBangBang = {
	Theme = theme,
	GetSmartSettings = function() return settings end,
	SmartDock = { IsActive = function() return true end },
}
dofile("Core/Config.lua")
local config = ChattyChattyBangBang.CustomConfig
function config:CreatePage() return widget(nil) end
config:BuildHomePage()

assert(hero and title and detail and status and hero.width and hero.height,
	"Overview capture status was not built")
local titleLeft = title.point[4]
local detailRight = titleLeft + (detail.width or 0)
local statusRight = titleLeft + (status.width or 0)
assert(titleLeft >= 12 and detailRight <= hero.width - 12
	and statusRight <= hero.width - 12,
	"Overview text crosses the hero border or loses its visible gutter")
local titleTop = hero.height + title.point[5]
local detailTop = titleTop - title.height + detail.point[5]
local statusTop = detailTop - detail.height + status.point[5]
assert(hero.height - titleTop >= 8 and statusTop - status.height >= 12,
	"Overview does not reserve vertical room for wrapped detail and status")
local smallestScale = (540 - 24) / 570
assert((hero.width - statusRight) * smallestScale >= 10
	and (statusTop - status.height) * smallestScale >= 10,
	"Overview text loses its gutter in the smallest supported viewport")
print("Capture overview layout mock tests passed")
