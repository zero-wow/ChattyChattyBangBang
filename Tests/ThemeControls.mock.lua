-- Focused no-client contract for attached config tabs and independent chrome
-- opacity. Run from the addon root with: lua Tests/ThemeControls.mock.lua

ChattyChattyBangBang = {}
function ChattyChattyBangBang:GetSmartSettings()
	return { colorway = "Obsidian Dawn" }
end

dofile("Core/Theme.lua")
local Theme = ChattyChattyBangBang.Theme

local frame = {}
function frame:SetBackdrop(value) self.backdrop = value end
function frame:SetBackdropColor(r, g, b, a) self.fill = { r, g, b, a } end
function frame:SetBackdropBorderColor(r, g, b, a) self.border = { r, g, b, a } end

Theme:RegisterFrame(frame, "background", "border")
local base = Theme.Colorways["Obsidian Dawn"]
Theme:SetFrameOpacity(frame, 0.5, 0.25)
assert(math.abs(frame.fill[4] - (base.background[4] * 0.5)) < 0.0001,
	"background opacity did not multiply the active theme alpha")
assert(math.abs(frame.border[4] - (base.border[4] * 0.25)) < 0.0001,
	"border opacity did not multiply the active theme alpha")
Theme:ApplyFrame(frame, "surfaceRaised", "gold")
assert(math.abs(frame.fill[4] - (base.surfaceRaised[4] * 0.5)) < 0.0001
	and math.abs(frame.border[4] - (base.gold[4] * 0.25)) < 0.0001,
	"temporary/hover theming discarded independent opacity multipliers")

local function texture()
	local value = { shown = true }
	function value:SetTexture(path) self.path = path end
	function value:SetPoint() end
	function value:SetHeight(height) self.height = height end
	function value:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
	function value:Show() self.shown = true end
	function value:Hide() self.shown = false end
	return value
end

local button = { scripts = {} }
function button:CreateTexture() return texture() end
function button:SetTheme(fill, border, text) self.theme = { fill, border, text } end
function button:SetHoverTheme(fill, border, text) self.hoverTheme = { fill, border, text } end
function button:HookScript(name, callback) self.scripts[name] = callback end

Theme:SetTabState(button, false)
assert(button._themeTabTrack and button._themeTabUnderline
	and not button._themeTabUnderline.shown,
	"unselected tab did not create its quiet baseline and hidden underline")
button.scripts.OnEnter(button)
assert(button._themeTabUnderline.shown, "hover did not reveal the tab navigation affordance")
button.scripts.OnLeave(button)
assert(not button._themeTabUnderline.shown, "unselected tab underline remained after hover")
Theme:SetTabState(button, true)
assert(button._themeTabSelected and button._themeTabUnderline.shown
	and button.theme[2] == Theme.NO_BORDER,
	"selected tab did not attach to its pane with a persistent underline")

print("Theme control mock tests passed")
