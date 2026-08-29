-- Focused no-client contract for the idle-only SmartDock composer setting.
-- Run from the addon root with: lua Tests/ComposerAutoHide.mock.lua

ChattyChattyBangBang = {
	db = {
		profile = {
			smartChat = {},
		},
	},
}

dofile("Core/Settings.lua")

local addon = ChattyChattyBangBang
local settings = addon:GetSmartSettings()
assert(settings.dock.composerAutoHide == false, "composer auto-hide should be safe opt-in by default")
assert(settings.dock.showComposer == true, "legacy composer visibility mirror should default visible")
assert(addon:GetComposerAutoHideSetting() == false, "composer auto-hide getter default changed")
assert(addon:GetEditBoxBorderSetting() == false,
	"typing-field border should default off so the composer remains integrated")

local calls = {}
addon.SmartDock = {
	ApplyLayout = function()
		table.insert(calls, "layout")
	end,
	RefreshComposerVisibility = function()
		table.insert(calls, "visibility")
	end,
}

local changed, enabled = addon:SetComposerAutoHide(true)
assert(changed and enabled, "composer auto-hide did not enable")
assert(settings.dock.composerAutoHide == true and settings.dock.showComposer == false,
	"composer auto-hide did not keep the legacy mirror in sync")
assert(calls[1] == "layout" and calls[2] == "visibility", "live dock refresh did not reflow then reveal")

calls = {}
changed, enabled = addon:SetComposerAutoHide(false)
assert(changed and not enabled, "composer auto-hide did not disable")
assert(settings.dock.composerAutoHide == false and settings.dock.showComposer == true,
	"composer auto-hide disable did not restore the legacy mirror")
assert(calls[1] == "layout" and calls[2] == "visibility", "disable did not refresh the live dock")

local borderRefreshes = 0
addon.SmartDock = {
	RefreshComposerEditBoxBorder = function()
		borderRefreshes = borderRefreshes + 1
	end,
}
changed, enabled = addon:SetEditBoxBorderEnabled(false)
assert(changed and not enabled and settings.dock.editBoxBorder == false,
	"composer input-border setting did not disable")
assert(borderRefreshes == 1, "input-border setting did not refresh the live dock")
changed, enabled = addon:SetEditBoxBorderEnabled(true)
assert(changed and enabled and settings.dock.editBoxBorder == true,
	"typing-field border setting did not re-enable")
assert(settings.dock.composerInputPolishSchema == 2,
	"an explicit typing-field preference was not versioned")

-- The prior rollout saved a boxed typing field as an implicit default. A
-- profile from that rollout must receive the corrected clean baseline exactly
-- once, while a post-schema explicit preference stays intact.
addon.SmartDock = nil
addon.db.profile = {
	smartChat = {
		dock = {
			editBoxBorder = true,
		},
	},
}
settings = addon:GetSmartSettings()
assert(settings.dock.editBoxBorder == false and addon:GetEditBoxBorderSetting() == false,
	"pre-schema boxed composer was not migrated to the clean integrated default")
assert(settings.dock.composerInputPolishSchema == 2,
	"pre-schema composer migration did not persist its revision")

addon.db.profile = {
	smartChat = {
		dock = {
			editBoxBorder = true,
			composerInputPolishSchema = 2,
		},
	},
}
settings = addon:GetSmartSettings()
assert(settings.dock.editBoxBorder == true and addon:GetEditBoxBorderSetting() == true,
	"an explicit post-schema typing-field preference was overwritten")

-- A player who had already used the old hidden-composer control retains that
-- compact layout when their profile gains the explicit module setting.
addon.SmartDock = nil
addon.db.profile = {
	smartChat = {
		dock = {
			showComposer = false,
		},
	},
}
settings = addon:GetSmartSettings()
assert(settings.dock.composerAutoHide == true and settings.dock.showComposer == false,
	"legacy showComposer=false was not migrated to composer auto-hide")

-- The runtime reserves the composer lane only while the shared editor is
-- active.  This is the part that ensures the message display genuinely grows
-- into the reclaimed area instead of simply fading an empty strip.
addon.Theme = {}
addon.Presentation = {}
dofile("Core/SmartDock.lua")

local dock = addon.SmartDock
local actualApplyLayout = dock.ApplyLayout
local actualRefreshComposerVisibility = dock.RefreshComposerVisibility

-- The optional field frame is separately controlled from the route/send
-- controls.  Toggling it should only show or hide that one decorative layer;
-- neither the composer lifecycle nor its geometry is touched.
local field = { shown = true }
function field:Show() self.shown = true end
function field:Hide() self.shown = false end
dock.composerEditBoxBorder = field
assert(dock:RefreshComposerEditBoxBorder() and not field.shown,
	"clean typing-field setting did not hide the optional field frame")
settings.dock.editBoxBorder = true
assert(dock:RefreshComposerEditBoxBorder() and field.shown,
	"typing-field setting did not show the optional field frame")
settings.dock.editBoxBorder = false
dock.composerEditBoxBorder = nil

dock.active = true
dock.built = true
dock.frame = {}
dock.visibleState = true
dock.collapsedState = false
dock.composerInputActive = false
dock.composerSpaceReserved = false
local reflows = 0
local visibilityRefreshes = 0
dock.ApplyLayout = function(self)
	reflows = reflows + 1
	self.composerSpaceReserved = self:ShouldReserveComposerSpace()
	return true
end
dock.RefreshComposerVisibility = function()
	visibilityRefreshes = visibilityRefreshes + 1
end

assert(dock:IsComposerAutoHideEnabled(), "runtime did not read the migrated auto-hide preference")
assert(not dock:ShouldReserveComposerSpace(), "idle auto-hide composer still reserved message space")
dock:BeginComposerInput()
assert(dock.composerInputActive and dock.composerSpaceReserved and reflows == 1,
	"opening chat did not re-reserve the composer lane")
dock:EndComposerInput()
assert(not dock.composerInputActive and not dock.composerSpaceReserved and reflows == 2,
	"closing chat did not reclaim the composer lane")
assert(visibilityRefreshes == 0, "occupancy changes should reflow rather than only fade the composer")

-- State alone is not enough: run the real layout method with a compact frame
-- harness and inspect the actual content anchor.  This proves the display
-- receives the reclaimed 2px bottom inset while idle, then the 26px composer
-- lane while typing, instead of an edit box simply overlaying its last lines.
local function fakeFrame()
	local frame = {
		shown = true,
		resizable = true,
		width = 520,
		height = 250,
		points = {},
	}
	function frame:ClearAllPoints()
		self.points = {}
		self.lastPoint = nil
	end
	function frame:SetPoint(...)
		local point = { ... }
		table.insert(self.points, point)
		self.lastPoint = point
	end
	function frame:SetSize(width, height)
		self.width, self.height = width, height
	end
	function frame:SetWidth(width) self.width = width end
	function frame:SetHeight(height) self.height = height end
	function frame:GetWidth() return self.width end
	function frame:GetHeight() return self.height end
	function frame:SetResizable(value) self.resizable = value end
	function frame:IsResizable() return self.resizable end
	function frame:SetParent(parent) self.parent = parent end
	function frame:GetParent() return self.parent end
	function frame:GetNumPoints() return 0 end
	function frame:GetPoint() return nil end
	function frame:SetFrameStrata(value) self.strata = value end
	function frame:GetFrameStrata() return self.strata or "MEDIUM" end
	function frame:SetFrameLevel(value) self.level = value end
	function frame:GetFrameLevel() return self.level or 1 end
	function frame:GetAlpha() return self.alpha or 1 end
	function frame:IsMouseEnabled() return self.mouseEnabled ~= false end
	function frame:GetName() return self.name or "ComposerAutoHideMock" end
	function frame:HookScript() end
	function frame:Show() self.shown = true end
	function frame:Hide() self.shown = false end
	function frame:IsShown() return self.shown end
	function frame:EnableMouse(value) self.mouseEnabled = value end
	function frame:SetAlpha(value) self.alpha = value end
	function frame:SetLabel(value) self.label = value end
	return frame
end

local frame = fakeFrame()
local content = fakeFrame()
local composer = fakeFrame()
local editBox = fakeFrame()
editBox.shown = false

dock.ApplyLayout = actualApplyLayout
dock.RefreshComposerVisibility = actualRefreshComposerVisibility
dock.frame = frame
dock.header = fakeFrame()
dock.headerIcon = fakeFrame()
dock.title = fakeFrame()
dock.subtitle = fakeFrame()
dock.settingsButton = fakeFrame()
dock.settingsButton.width = 18
dock.hideButton = fakeFrame()
dock.hideButton.width = 18
dock.collapseButton = fakeFrame()
dock.collapseButton.width = 18
dock.newButton = fakeFrame()
dock.newButton.shown = false
dock.rail = fakeFrame()
dock.content = content
dock.railScroll = fakeFrame()
dock.railSettingsButton = nil
dock.display = fakeFrame()
dock.scrollUp = fakeFrame()
dock.scrollDown = fakeFrame()
dock.composer = composer
dock.alertBar = fakeFrame()
dock.resizeHandleList = {}
dock.resizeHandles = {}
dock.railButtons = nil
dock.editBox = editBox
dock.active = true
dock.built = true
dock.visibleState = true
dock.collapsedState = false
dock.composerInputActive = false
dock.composerSpaceReserved = false
dock.headerHover = false
dock.railVisibilityMode = nil
dock.railConfiguredVisibility = nil
dock.pendingVisible = 0
dock.alertActive = false

local function contentBottomOffset()
	local point = content.lastPoint
	assert(point and point[1] == "BOTTOMRIGHT", "content did not receive a bottom layout anchor")
	return point[5]
end

settings.dock.composerAutoHide = true
settings.dock.showComposer = false
assert(dock:ApplyLayout(), "idle auto-hide layout could not apply")
assert(contentBottomOffset() == 2 and dock.composerSpaceReserved == false,
	"idle auto-hide did not reclaim the composer lane from message content")
assert(composer.alpha == 0 and composer.mouseEnabled == false and composer.shown,
	"idle auto-hide parent must stay shown but inert for Blizzard edit activation")

dock:BeginComposerInput()
assert(contentBottomOffset() == 26 and dock.composerSpaceReserved == true,
	"opening the editor did not reserve a non-overlapping composer lane")
assert(composer.alpha == 1 and composer.mouseEnabled == true,
	"opening the editor did not reveal composer chrome")

dock:EndComposerInput()
assert(contentBottomOffset() == 2 and dock.composerSpaceReserved == false,
	"closing the editor did not return reclaimed height to message content")

-- A current explicit opt-out must keep the normal persistent composer and its
-- 26px lane, while an old showComposer=false profile still gets auto-hide.
settings.dock.composerAutoHide = false
settings.dock.showComposer = true
assert(dock:ApplyLayout() and contentBottomOffset() == 26,
	"non-auto-hide composer did not retain its normal reserved lane")
settings.dock.composerAutoHide = nil
settings.dock.showComposer = false
assert(dock:ApplyLayout() and contentBottomOffset() == 2,
	"legacy hidden composer did not use the compact auto-hide layout")

-- Enabling/reloading Smart Dock while the shared editor is already open does
-- not trigger its OnShow hook. AttachEditBox must seed the active state so the
-- very first compact layout reserves the input lane instead of overlapping it.
local attachedEditBox = fakeFrame()
attachedEditBox.name = "ComposerAutoHideAttachedEditBox"
attachedEditBox.parent = fakeFrame()
attachedEditBox.shown = true
_G.ChatFrame1EditBox = attachedEditBox
dock.editBoxSnapshot = nil
dock.editBox = nil
dock.composerInputActive = false
assert(dock:AttachEditBox(), "visible shared editor could not attach")
assert(dock.composerInputActive == true and dock:ShouldReserveComposerSpace(),
	"attaching an already-open editor did not reserve its composer lane")

print("Composer auto-hide mock tests passed")
