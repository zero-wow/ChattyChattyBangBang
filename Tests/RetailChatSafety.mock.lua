-- Run from the addon root with: lua Tests/RetailChatSafety.mock.lua
local activated = 0
local lastToldTarget
ChatFrameUtil = {
	ActivateChat = function() activated = activated + 1 end,
	SetLastToldTarget = function(name, chatType)
		lastToldTarget = { name, chatType }
	end,
}
ChattyChattyBangBang = {
	Theme = {},
	Presentation = {},
	ClientAPI = { IsRetail = function() return true end },
}
dofile("Core/SmartDock.lua")
local dock = ChattyChattyBangBang.SmartDock
dock.IsReadOnlyView = function() return false end
local actualApplyComposerRoute = dock.ApplyComposerRoute
dock.ApplyComposerRoute = function() return true end
dock.editBox = {}
dock:ActivateComposer()
assert(activated == 1, "Retail composer did not use ChatFrameUtil.ActivateChat")
dock.ApplyComposerRoute = actualApplyComposerRoute

local route, target = "WHISPER", "RetailFriend"
local box = {
	SetChatType = function(self, value) self.chatType = value end,
	GetChatType = function(self) return self.chatType end,
	SetTellTarget = function(self, value) self.tellTarget = value end,
	GetTellTarget = function(self) return self.tellTarget end,
	UpdateHeader = function(self) self.headerUpdated = true end,
}
dock.editBox = box
dock.GetComposerRoute = function() return route, target end
dock.HideNativeComposerChrome = function() end
assert(dock:ApplyComposerRoute(), "Retail composer route did not apply")
assert(box.chatType == "WHISPER" and box.tellTarget == "RetailFriend"
	and box.headerUpdated and lastToldTarget and lastToldTarget[2] == "WHISPER",
	"Retail composer did not use current edit-box methods")
assert(dock:CaptureComposerRouteFromEditBox(), "Retail route could not be read back")

local native = { shown = true, alpha = 1, mouse = true, strata = "LOW" }
function native:IsShown() return self.shown end
function native:GetAlpha() return self.alpha end
function native:IsMouseEnabled() return self.mouse end
function native:SetAlpha(value) self.alpha = value end
function native:EnableMouse(value) self.mouse = value end
function native:Hide() self.shown = false end
function native:Show() self.shown = true end
function native:HookScript() end
function native:GetFrameStrata() return self.strata end
function native:SetFrameStrata(value) self.strata = value end
ChatFrame1 = native
NUM_CHAT_WINDOWS = 1
local settings = { dock = { hideNativeChat = true } }
ChattyChattyBangBang.GetSmartSettings = function() return settings end
dock.active = true
local shown = true
dock.frame = { IsShown = function() return shown end }
dock.visibleState = true
dock:HideNativeChat()
assert(dock.nativeSnapshot and not native.shown,
	"explicit Retail preference did not hide Blizzard chat")
dock.visibleState = false
dock:SyncNativeChatVisibility()
assert(native.shown and dock.nativeSnapshot == nil,
	"hiding Smart Dock must restore Blizzard chat")
dock.visibleState = true
settings.dock.hideNativeChat = false
dock:SyncNativeChatVisibility()
assert(native.shown, "turning off native-chat hiding did not keep Blizzard chat visible")
settings.dock.hideNativeChat = true
dock:SyncNativeChatVisibility()
assert(not native.shown, "turning native-chat hiding back on did not apply")
dock:SetNativeSafetyFallback(true)
assert(native.shown and native.strata == "HIGH" and dock.nativeSnapshot == nil,
	"restricted Retail chat did not reveal Blizzard's safety fallback")
dock:SyncNativeChatVisibility()
assert(native.shown, "ordinary visibility sync hid the active safety fallback")
dock:SetNativeSafetyFallback(false)
assert(not native.shown and native.strata == "LOW" and dock.nativeSnapshot,
	"successful catch-up did not restore the player's hide-native preference")
dock:SetCaptureCoverageFallback(true)
assert(native.shown and native.strata == "HIGH" and settings.dock.hideNativeChat,
	"capture-registration gap did not reveal native chat without changing preference")
dock:SetNativeSafetyFallback(true)
dock:SetCaptureCoverageFallback(false)
assert(native.shown and native.strata == "HIGH" and dock.nativeSnapshot == nil,
	"ending capture fallback cleared a still-active recovery fallback")
dock:SetNativeSafetyFallback(false)
assert(not native.shown and native.strata == "LOW" and dock.nativeSnapshot,
	"ending both fallbacks did not restore the hide-native preference")
dock:SetCaptureCoverageFallback(true)
dock:SetNativeSafetyFallback(true)
dock:SetNativeSafetyFallback(false)
assert(native.shown and native.strata == "HIGH" and dock.nativeSnapshot == nil,
	"ending recovery cleared a still-active capture fallback")
dock:SetCaptureCoverageFallback(false)
assert(not native.shown and native.strata == "LOW" and dock.nativeSnapshot,
	"ending capture fallback did not restore the hide-native preference")
shown = false
dock:SyncNativeChatVisibility()
assert(native.shown, "a hidden Smart Dock left Blizzard chat hidden")
dock:SuppressTemporaryChatFrame({})
assert(dock.nativeSnapshot == nil, "hidden Smart Dock suppressed temporary chat")

shown = true
dock:SyncNativeChatVisibility()
assert(dock.nativeSnapshot and not native.shown, "retry setup did not hide native chat")
local normalShow = native.Show
native.Show = function() error("protected while locked down") end
assert(dock:SetNativeSafetyFallback(true) == false
	and dock.nativeFallbackActivationFailed and dock.nativeSnapshot,
	"a protected-frame failure must retain a retryable snapshot")
native.Show = normalShow
assert(dock:SetNativeSafetyFallback(true) == true and native.shown
	and dock.nativeSnapshot == nil and not dock.nativeFallbackActivationFailed,
	"native safety fallback did not retry after the protected-frame failure")
dock:SetNativeSafetyFallback(false)

print("Retail chat safety mock tests passed")
