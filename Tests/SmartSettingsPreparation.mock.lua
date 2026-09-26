-- Render reads reuse a prepared live profile; the public getter still normalizes.
-- Run from addon root: lua Tests/SmartSettingsPreparation.mock.lua

ChattyChattyBangBang = {
	db = { profile = { smartChat = {
		viewOptions = { general = { textAppearance = { size = 14 } } },
	} } },
}

dofile("Core/Settings.lua")
local addon = ChattyChattyBangBang
local first = addon:GetPreparedSmartSettings()
local override = first.viewOptions.general.textAppearance
assert(override.size == 14, "initial profile typography was not prepared")

for _ = 1, 30 do
	assert(addon:GetPreparedSmartSettings() == first, "prepared settings identity changed on read")
	assert(first.viewOptions.general.textAppearance == override,
		"render read normalized and replaced a SavedVariables override")
end

-- A normal getter call must still repair direct mutations made by Config.
first.viewOptions.general.textAppearance = { font = "lsm:Mono Test", size = 15 }
assert(addon:GetSmartSettings().viewOptions.general.textAppearance.font == "Mono Test",
	"public getter did not normalize a directly mutated override")
assert(addon:GetPreparedSmartSettings().viewOptions.general.textAppearance.font == "Mono Test",
	"prepared reader did not see a direct settings change")

local exported = addon:GetSmartChatTextAppearance("general")
exported.size = 23
assert(first.viewOptions.general.textAppearance.size == 15,
	"typography getter leaked its SavedVariables table")

-- AceDB profile replacement keeps the addon object but installs a new
-- smartChat table. That new table must get the same one-time migrations.
addon.db.profile.smartChat = {
	dock = { showComposer = false },
	viewOptions = { general = { textAppearance = { font = "lsm:Mono Test", size = 15 } } },
}
local second = addon:GetPreparedSmartSettings()
assert(second ~= first and second.dock.composerAutoHide == true,
	"new profile did not run the legacy hidden-composer migration")
assert(second.viewOptions.general.textAppearance.font == "Mono Test",
	"new profile did not normalize its typography override")

-- The two per-line Presentation sites use the prepared reader, not the full
-- getter, yet remain attached to live settings changed by Config.
local fullGetter = addon.GetSmartSettings
local fullReads = 0
addon.GetSmartSettings = function(self)
	fullReads = fullReads + 1
	return fullGetter(self)
end
dofile("Core/Presentation.lua")
local presentation = addon.Presentation
presentation.Color = function(_, value) return value end
local record = { text = "join", tags = { ["intent:recruiting"] = true } }
second.dock.showClassificationTags = true
assert(presentation:GetTagText(record) == "  LFM", "classification tag was not rendered")
assert(presentation:ColorizePlainText("xyzz") == "xyzz", "plain text render changed")
assert(fullReads == 0, "per-line render ran full settings normalization")
second.dock.showClassificationTags = false
assert(presentation:GetTagText(record) == "", "render missed a direct settings change")
assert(fullReads == 0, "per-line render normalized after a direct settings change")

addon.db.profile = { smartChat = { dock = { showComposer = false } } }
local third = addon:GetPreparedSmartSettings()
assert(third ~= second and third.dock.composerAutoHide == true,
	"switched profile did not receive migration")
assert(fullReads == 1, "switched profile was not prepared exactly once")
assert(addon:GetPreparedSmartSettings() == third and fullReads == 1,
	"switched profile was prepared repeatedly on render")

print("Smart settings preparation mock passed")
