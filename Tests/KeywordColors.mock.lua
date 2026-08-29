-- Focused no-client harness for Smart Chat keyword color defaults and the
-- public settings API. Run from the addon root with:
--   lua Tests/KeywordColors.mock.lua

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
assert(settings.keywordColorGroupSchema == 3, "new profile did not record grouped-color migration schema")
assert(settings.keywordColors.lf == "goldBright", "LF default color missing")
assert(settings.keywordColors.lf1dps == "goldBright", "LF1DPS default color missing")
assert(settings.keywordColors.lf1 == "goldBright", "LF1 default color missing")
assert(settings.keywordColors["lf#"] == "goldBright", "LF# shorthand default color missing")
assert(settings.keywordColors.pds == "danger", "PDS DPS-typo color missing")
assert(settings.keywordColors.ot == "accent", "OT default role color missing")
assert(settings.keywordColors.ilvl == "gold", "iLvL default requirement color missing")

local options = addon:GetKeywordColorOptions()
assert(#options == 7 and options[1].id == "goldBright", "keyword color choices are not exposed")
local groups = addon:GetKeywordColorGroups()
assert(groups[1].id == "groupFinder" and groups[2].id == "tank", "ordered keyword color groups are not exposed")
assert(addon:SetKeywordColorGroup("tank", "warning"), "group setter rejected a palette color")
assert(settings.keywordColors.tank == "warning" and settings.keywordColors.tnak == "warning", "group setter did not update every tank spelling")
assert(addon:SetKeywordColorGroup("tank", "accent"), "group setter could not restore tank color")
assert(addon:SetKeywordColor("LF1DPS", "danger"), "public keyword color setter rejected a valid choice")
assert(settings.keywordColors.lf1dps == "danger", "keyword setter did not normalize the key")
assert(not addon:SetKeywordColor("LF1DPS", "not-a-palette-token"), "invalid keyword color was accepted")
assert(addon:ResetKeywordColors(), "keyword color reset failed")
assert(settings.keywordColors.lf1dps == "goldBright", "keyword color reset lost its default")

addon.Theme = {
	GetPalette = function()
		return {
			goldBright = { 1, 0.8, 0.39, 1 },
			gold = { 0.88, 0.61, 0.24, 1 },
			accent = { 0.22, 0.48, 0.78, 1 },
			success = { 0.30, 0.82, 0.57, 1 },
			warning = { 1, 0.66, 0.25, 1 },
			danger = { 0.90, 0.30, 0.28, 1 },
			text = { 0.91, 0.91, 0.86, 1 },
		}
	end,
	GetColor = function(self, name)
		local color = self:GetPalette()[name] or self:GetPalette().text
		return color[1], color[2], color[3], color[4]
	end,
}

RAID_CLASS_COLORS = {
	MAGE = { r = 0.25, g = 0.78, b = 0.92 },
}

dofile("Core/Presentation.lua")
local colored = addon.Presentation:ColorizePlainText("LF1DPS LF LF1 LF12 PDS OT iLvL CLF1DPS EXP AURA AURA tnak Mage RFC rfc M1 m1 an")
assert(string.find(colored, "|cffffcc63LF1DPS|r", 1, true), "LF1DPS was not colorized")
assert(string.find(colored, "|cffffcc63LF|r", 1, true), "LF was not colorized")
assert(string.find(colored, "|cffffcc63LF1|r", 1, true), "LF1 was not colorized")
assert(string.find(colored, "|cffffcc63LF12|r", 1, true), "LF# numeric shorthand was not colorized")
assert(string.find(colored, "|cffe64d47PDS|r", 1, true), "PDS did not share the DPS color")
assert(string.find(colored, "|cff387ac7OT|r", 1, true), "OT was not colorized with the tank accent")
assert(string.find(colored, "|cffe09c3diLvL|r", 1, true), "iLvL was not colorized with the requirement gold")
assert(not string.find(colored, "|cffffcc63CLF1DPS|r", 1, true), "keyword matching colored a substring")
assert(string.find(colored, "|cffffa840EXP AURA|r", 1, true), "EXP AURA was not kept as one colorized phrase")
assert(string.find(colored, "|cffffa840AURA|r", 1, true), "AURA did not share the EXP AURA group color")
assert(string.find(colored, "|cff387ac7tnak|r", 1, true), "tnak did not share the tank color")
assert(string.find(colored, "|cff40c7ebMage|r", 1, true), "class name did not use RAID_CLASS_COLORS")
assert(string.find(colored, "|cffffcc63RFC|r", 1, true), "uppercase dungeon acronym was not colorized")
assert(string.find(colored, "|cffffcc63M1|r", 1, true), "uppercase instance level was not colorized")
assert(not string.find(colored, "|cffffcc63an|r", 1, true), "ordinary lowercase text was treated as a dungeon acronym")
assert(not string.find(colored, "|cffffcc63rfc|r", 1, true), "lowercase acronym bypassed its case-sensitive rule")
assert(not string.find(colored, "|cffffcc63m1|r", 1, true), "lowercase instance level bypassed its case-sensitive rule")
assert(addon:SetKeywordColorGroup("instanceLevels", "danger"), "instance group color update failed")
local recoloredInstance = addon.Presentation:ColorizePlainText("M1 m1")
assert(string.find(recoloredInstance, "|cffe64d47M1|r", 1, true), "keyword-rule cache did not refresh after group color change")
assert(not string.find(recoloredInstance, "|cffe64d47m1|r", 1, true), "case-sensitive instance rule regressed after cache refresh")

local function clone(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in pairs(value) do
		result[key] = clone(child)
	end
	return result
end

local function findGroup(groupList, id)
	for _, group in ipairs(groupList) do
		if group.id == id then
			return group
		end
	end
end

-- AceDB can inject the new group defaults into an older flat profile before
-- Settings loads. That must still carry an intentional old LF color across.
local factoryGroups = clone(settings.keywordColorGroups)

-- A v2.4 profile has the old ordered array with no instanceLevels entry but
-- may already be marked schema 1. Upgrade by ID, never numeric list position.
local v24Groups = clone(factoryGroups)
for index = #v24Groups, 1, -1 do
	if v24Groups[index].id == "instanceLevels" then
		table.remove(v24Groups, index)
	end
end
addon.db.profile.smartChat = {
	keywordColors = {},
	keywordColorGroups = v24Groups,
	keywordColorGroupSchema = 1,
}
local upgradedV24 = addon:GetSmartSettings()
local ids = {}
for _, group in ipairs(upgradedV24.keywordColorGroups) do
	assert(not ids[group.id], "group migration duplicated " .. tostring(group.id))
	ids[group.id] = true
end
assert(ids.instanceLevels and findGroup(upgradedV24.keywordColorGroups, "trade").color == "gold", "v2.4 groups shifted instead of receiving instanceLevels")
assert(findGroup(upgradedV24.keywordColorGroups, "warrior").color == "class:WARRIOR", "v2.4 class group was shifted")
assert(upgradedV24.keywordColorGroupSchema == 3, "v2.4 profile did not receive schema 3")

addon.db.profile.smartChat = {
	keywordColors = { lf = "danger" },
	keywordColorGroups = clone(factoryGroups),
}
local migrated = addon:GetSmartSettings()
assert(findGroup(migrated.keywordColorGroups, "groupFinder").color == "danger", "AceDB-seeded factory group did not migrate old LF color")
assert(migrated.keywordColors.lfg == "danger", "legacy group migration did not apply the shared color")
assert(migrated.keywordColorGroupSchema == 3, "legacy profile did not persist grouped-color migration schema")

-- Once marked, no future hot-path call may re-run the legacy reconciliation.
migrated.keywordColors.lf = "warning"
assert(findGroup(addon:GetSmartSettings().keywordColorGroups, "groupFinder").color == "danger", "marked profile re-ran grouped-color migration")

-- Once a player has touched a group, that newer choice must win even if an old
-- flat map happens to remain in the SavedVariables table.
local explicitGroups = clone(v24Groups)
findGroup(explicitGroups, "groupFinder").color = "success"
addon.db.profile.smartChat = {
	keywordColors = { lf = "danger" },
	keywordColorGroups = explicitGroups,
	keywordColorGroupSchema = 1,
}
local explicit = addon:GetSmartSettings()
assert(findGroup(explicit.keywordColorGroups, "groupFinder").color == "success", "explicit grouped color was overwritten by legacy flat data")
assert(explicit.keywordColorGroupSchema == 3, "explicit grouped profile did not persist migration schema")

local created, personal = addon:CreateKeywordColorGroup("Raid Calls", "success")
assert(created and personal and personal.custom == true, "personal keyword color group could not be created")
assert(addon:AddKeywordColorGroupTerm(personal.id, "world buff"), "personal group could not accept a phrase")
assert(not addon:AddKeywordColorGroupTerm("tank", "world buff"), "a phrase was allowed to belong to two groups")
assert(string.find(addon.Presentation:ColorizePlainText("World Buff"), "|cff4dd191World Buff|r", 1, true),
	"personal group phrase was not colorized")
assert(addon:ResetKeywordColorGroups(), "group reset failed after a personal group was added")
assert(findGroup(addon:GetKeywordColorGroups(), personal.id), "reset unexpectedly deleted a personal color group")
assert(addon:DeleteKeywordColorGroup(personal.id), "personal color group could not be deleted")
assert(not addon:GetKeywordColorGroup(personal.id), "deleted personal group is still exposed")
assert(not addon:DeleteKeywordColorGroup("tank"), "built-in group was deletable")

print("Keyword color mock tests passed")
