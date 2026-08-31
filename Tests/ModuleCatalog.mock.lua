-- Focused no-client contract for Smart Chat's module compatibility registry.
-- Run from the addon root with: lua Tests/ModuleCatalog.mock.lua
ChattyChattyBangBang = {
	db = { profile = { smartChat = { enabled = true }, modules = {} } },
	modules = {},
}

function ChattyChattyBangBang:GetSmartSettings()
	return self.db.profile.smartChat
end

function ChattyChattyBangBang:GetModule(name)
	return self.modules[name]
end

function ChattyChattyBangBang:CanRunLegacyFallback()
	return true
end

function ChattyChattyBangBang:SetLegacyModulePreference(name, enabled)
	self.db.profile.modules[name] = enabled and true or false
	local module = self.modules[name]
	if module then
		module.enabled = false -- Smart Chat keeps all legacy modules dormant.
	end
	return false
end

dofile("Core/ModuleCatalog.lua")

local addon = ChattyChattyBangBang
local kinds = addon:GetModuleCompatibilityKinds()
assert(kinds.smartNative == "smart-native")
assert(kinds.nativeFallbackOnly == "native-fallback-only")
assert(kinds.needsAdapter == "needs-adapter")

local list = addon:GetModuleCatalog()
assert(#list == 31, "catalog should describe every loaded bundled Chatter module and Smart-only replacements")
assert(list[1].id and list[1].label and list[1].category and list[1].status and list[1].summary,
	"catalog list omitted the UI contract fields")
assert(list[1].category == "Chat Features" and list[1].statusLabel == "RUNS IN CHATTY",
	"catalog omitted the Chatty feature metadata")
assert(list[1].legacyModuleName and list[1].enabled ~= nil and list[1].preferenceEnabled ~= nil,
	"catalog list omitted the module preference state")
list[1].label = "mutated"
assert(addon:GetModuleCatalog()[1].label ~= "mutated", "catalog getter leaked its internal table")

local tabs = assert(addon:GetModuleCatalogStatus("chat-tabs"))
assert(tabs.compatibility == kinds.smartNative and tabs.runtime == "smart-active" and tabs.active,
	"Chat Tabs should be represented by Smart Chat while it is active")
assert(tabs.enableControl == "smart-settings")
assert(not addon:SetModuleCatalogPreference("chat-tabs", false), "Smart-native module accepted a legacy enable toggle")

local composer = assert(addon:GetModuleCatalogStatus("composer-auto-hide"))
assert(composer.status == "smart" and composer.configPage == "dock" and composer.smartSetting == "composerAutoHide",
	"idle composer auto-hide was not exposed as a Smart Chat built-in module")
assert(composer.label == "Auto-Hide Composer" and composer.navLabel == "Auto-Hide Input",
	"catalog did not preserve the full feature name beside its compact navigation label")

local inputBorder = assert(addon:GetModuleCatalogStatus("edit-box-border"))
assert(inputBorder.status == "smart" and inputBorder.configPage == "dock" and inputBorder.smartSetting == "editBoxBorder",
	"composer input-border adaptation was not exposed as a Smart Chat built-in module")
assert(addon:GetModuleCatalogStatus("Edit Box Polish").id == "edit-box-border",
	"legacy Edit Box Polish lookup did not resolve to Chatty's safe adapted control")

local chatFont = assert(addon:GetModuleCatalogStatus("chat-font"))
assert(chatFont.compatibility == kinds.smartNative and chatFont.runtime == "smart-active"
	and chatFont.configPage == "views" and chatFont.navLabel == "Message Font",
	"SharedMedia message-font controls were not represented as a live Chatty feature")

local channelColors = assert(addon:GetModuleCatalogStatus("channel-colors"))
assert(channelColors.compatibility == kinds.smartNative and channelColors.configPage == "dock",
	"editable channel colors did not route to Chat Window > Chat Colors")

local tellTarget = assert(addon:GetModuleCatalogStatus("tell-target"))
assert(tellTarget.compatibility == kinds.smartNative and tellTarget.status == "smart"
	and tellTarget.runtime == "smart-active" and tellTarget.configPage == "conversations"
	and tellTarget.configSection == "opening" and tellTarget.smartSetting == "tellTargetEnabled",
	"Tell Target was not adopted as a configurable Smart Chat feature")
assert(addon:GetModuleCatalogStatus("Tell Target (/tt)").id == "tell-target",
	"legacy Tell Target lookup did not resolve to Chatty's replacement")
assert(not addon:SetModuleCatalogPreference("tell-target", false),
	"Tell Target accepted a legacy fallback toggle after Smart Chat adopted it")

local native = assert(addon:GetModuleCatalogStatus("timestamps"))
assert(native.compatibility == kinds.nativeFallbackOnly and native.runtime == "native-ready" and not native.active,
	"native module was incorrectly reported as running in Smart Chat")
assert(native.category == "Legacy Compatibility" and native.statusLabel == "RUNS ONLY WITH NATIVE FALLBACK",
	"native fallback module omitted its user-facing compatibility metadata")
assert(native.preferenceEnabled, "default native preference should be enabled")
assert(addon:SetModuleCatalogPreference("timestamps", false))
assert(addon.db.profile.modules["Timestamps"] == false, "native preference was not saved")

local adapter = assert(addon:GetModuleCatalogStatus("mousewheel-scroll"))
assert(adapter.compatibility == kinds.needsAdapter and adapter.runtime == "needs-adapter",
	"unported Smart adapter was not reported honestly")
assert(adapter.category == "Legacy Compatibility" and adapter.statusLabel == "NOT YET AVAILABLE",
	"adapter did not expose readable availability metadata")
assert(adapter.label == "Mousewheel Scroll" and adapter.navLabel == "Mousewheel",
	"adapter full label was not preserved beside its compact navigation label")

addon.db.profile.smartChat.enabled = false
addon.modules["Timestamps"] = {
	enabled = true,
	IsEnabled = function(self) return self.enabled end,
}
native = assert(addon:GetModuleCatalogStatus("Timestamps"))
assert(native.runtime == "native-active" and native.active,
	"enabled fallback module was not reported as native-active")

print("Module catalog mock tests passed")
