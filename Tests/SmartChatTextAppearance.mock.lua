-- Focused no-client contract for Smart Chat's global/per-tab LSM typography.
-- Run from the addon root with: lua Tests/SmartChatTextAppearance.mock.lua

local media = {
	fonts = {
		["Mono Test"] = "Interface\\AddOns\\Test\\MonoTest.ttf",
		["Alpha Sans"] = "Interface\\AddOns\\Test\\AlphaSans.ttf",
	},
}

function media:HashTable(kind)
	assert(kind == "font", "unexpected LSM media kind")
	return self.fonts
end

function media:Fetch(kind, key)
	assert(kind == "font", "unexpected LSM fetch kind")
	return self.fonts[key]
end

function media:Register(kind, key, path)
	assert(kind == "font", "unexpected LSM registration kind")
	self.fonts[key] = path
	return true
end

_G.LibStub = function(name, silent)
	if name == "LibSharedMedia-3.0" then
		return media
	end
	if silent then return nil end
	error("missing library: " .. tostring(name))
end

_G.GetAddOnInfo = function(name)
	return name == "SharedMedia" and "SharedMedia" or nil
end

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
local defaultAppearance = addon:GetSmartChatTextAppearance("global")
assert(defaultAppearance.font == nil and defaultAppearance.size == 0 and defaultAppearance.outline == "INHERIT"
	and defaultAppearance.spacing == 1,
	"global Smart Chat text should inherit the current chat font by default")

local options = addon:GetSmartChatTextAppearanceOptions()
assert(options.fonts[1].inherit and options.fonts[1].id == false,
	"font options must begin with the inherited current-chat fallback")
local function findFontOption(key)
	for _, option in ipairs(options.fonts) do
		if option.id == key then return option end
	end
	return nil
end
assert(findFontOption("Alpha Sans") and findFontOption("Mono Test"),
	"existing LSM font keys were not copied into the chooser")
assert(findFontOption("Mono Test").monospaced == true,
	"obvious monospaced LSM keys should be marked for the picker")
assert(findFontOption("JetBrains Mono (Regular)"),
	"Questie-compatible SharedMedia font bootstrap did not add the installed font pack")
assert(media.fonts["JetBrains Mono (Regular)"] == "Interface\\AddOns\\SharedMedia\\Fonts\\JetBrainsMono-Regular.ttf",
	"SharedMedia bootstrap registered the wrong font path")
assert(addon:ResolveSmartChatTextFont("Mono Test") == media.fonts["Mono Test"],
	"Smart Chat did not resolve the raw LSM key through Media:Fetch")
assert(addon:ResolveSmartChatTextFont(nil) == nil,
	"inherited font should leave ChatFontNormal untouched")

-- Ascension can expose an empty/unavailable LSM registry even while the
-- installed SharedMedia font files are present. The chooser and resolver must
-- still use the proven Questie-compatible font pack in that state.
local savedLibStub = _G.LibStub
_G.LibStub = function(_, silent)
	if silent then return nil end
	error("missing library")
end
options = addon:GetSmartChatTextAppearanceOptions()
assert(findFontOption("JetBrains Mono (Regular)"),
	"installed SharedMedia fonts disappeared when the live registry was unavailable")
assert(addon:ResolveSmartChatTextFont("JetBrains Mono (Regular)")
	== "Interface\\AddOns\\SharedMedia\\Fonts\\JetBrainsMono-Regular.ttf",
	"known SharedMedia font did not resolve without the live registry")
_G.LibStub = savedLibStub

-- LSM normally returns its default Friz face for an unknown key unless its
-- noDefault argument is set. Ensure Chatty follows Questie's no-default
-- resolver path so that behavior cannot mask a known local font path.
local savedGetAddOnInfo = _G.GetAddOnInfo
_G.GetAddOnInfo = nil
local fallbackMedia = { fonts = {} }
function fallbackMedia:HashTable(kind)
	assert(kind == "font", "unexpected fallback media hash kind")
	return self.fonts
end
function fallbackMedia:Fetch(kind, key, noDefault)
	assert(kind == "font", "unexpected fallback media kind")
	assert(noDefault == true, "font resolver must request LSM without a default")
	return nil
end
function fallbackMedia:Register(kind, key, path)
	assert(kind == "font", "unexpected fallback media registration kind")
	self.fonts[key] = path
	return true
end
_G.LibStub = function(name, silent)
	if name == "LibSharedMedia-3.0" then return fallbackMedia end
	if silent then return nil end
	error("missing library")
end
options = addon:GetSmartChatTextAppearanceOptions()
assert(findFontOption("JetBrains Mono (Regular)"),
	"known fonts should remain listed with an empty LSM table")
assert(fallbackMedia.fonts["JetBrains Mono (Regular)"]
	== "Interface\\AddOns\\SharedMedia\\Fonts\\JetBrainsMono-Regular.ttf",
	"font bootstrap must not depend on GetAddOnInfo")
assert(addon:ResolveSmartChatTextFont("JetBrains Mono (Regular)")
	== "Interface\\AddOns\\SharedMedia\\Fonts\\JetBrainsMono-Regular.ttf",
	"known SharedMedia path should win when LSM has no registered entry")
_G.LibStub = savedLibStub
_G.GetAddOnInfo = savedGetAddOnInfo

local refreshes = 0
addon.SmartDock = {
	RefreshSmartChatTextAppearance = function()
		refreshes = refreshes + 1
	end,
}

local changed, appearance = addon:SetSmartChatTextAppearance("global", {
	font = "Mono Test",
	size = 14,
	outline = "OUTLINE",
	spacing = 3,
})
assert(changed and appearance.font == "Mono Test" and appearance.size == 14 and appearance.outline == "OUTLINE"
	and appearance.spacing == 3,
	"global Smart Chat text appearance did not save the selected raw LSM key")
assert(settings.textAppearance.font == "Mono Test" and settings.textAppearance.font ~= "lsm:Mono Test",
	"Smart Chat persisted an invented wrapper instead of the raw LSM key")
assert(refreshes == 1, "text appearance change did not request a focused live dock refresh")

changed, appearance = addon:SetSmartChatTextAppearance("general", { size = 17, spacing = 5 })
assert(changed and appearance.font == "Mono Test" and appearance.size == 17 and appearance.outline == "OUTLINE"
	and appearance.spacing == 5,
	"per-tab appearance did not resolve inherited global fields")
assert(settings.viewOptions.general.textAppearance.size == 17
	and settings.viewOptions.general.textAppearance.font == nil
	and settings.viewOptions.general.textAppearance.outline == nil
	and settings.viewOptions.general.textAppearance.spacing == 5,
	"per-tab state should remain a sparse override rather than copying globals")

assert(addon:SetSmartChatTextAppearance("global", { font = "Alpha Sans" }))
appearance = addon:GetSmartChatTextAppearance("general")
assert(appearance.font == "Alpha Sans" and appearance.size == 17 and appearance.spacing == 5,
	"an inherited tab did not follow a later global font change")

assert(addon:ResetSmartChatTextAppearance("general"))
appearance = addon:GetSmartChatTextAppearance("general")
assert(appearance.font == "Alpha Sans" and appearance.size == 14 and appearance.outline == "OUTLINE"
	and appearance.spacing == 3,
	"resetting a tab did not restore all-tab inheritance")
assert(settings.viewOptions.general == nil,
	"an empty per-tab text override should not leave an empty viewOptions record")

assert(addon:SetSmartChatFont("default"))
assert(addon:GetSmartChatFontSettings().font == nil,
	"the global alias did not restore current-chat font inheritance")
assert(not addon:SetSmartChatTextAppearance("global", { size = 5 }),
	"out-of-range font sizes must be rejected")
assert(not addon:SetSmartChatTextAppearance("global", { spacing = 9 }),
	"out-of-range line gaps must be rejected")
assert(not addon:SetSmartChatTextAppearance("global", { spacing = 1.5 }),
	"line gaps must reject decimal pixel values instead of rounding them")
assert(not addon:SetSmartChatTextAppearance("general", { font = "bad\001font" }),
	"control characters must not become LSM font keys")

-- Read-migrate the short-lived wrapper format but save the canonical raw key.
addon.db.profile.smartChat = {
	textAppearance = { font = "lsm:Mono Test", size = 13, outline = "NONE", spacing = 1.5 },
}
settings = addon:GetSmartSettings()
appearance = addon:GetSmartChatTextAppearance("global")
assert(appearance.font == "Mono Test" and settings.textAppearance.font == "Mono Test",
	"legacy lsm:<name> text setting was not normalized to the raw LSM key")
assert(appearance.spacing == 1 and settings.textAppearance.spacing == 1,
	"legacy or decimal line gaps did not normalize to the compact whole-pixel default")

print("Smart Chat text appearance mock: PASS")
