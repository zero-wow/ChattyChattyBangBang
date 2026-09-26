-- Dormant native-chat fallbacks: execute only the guarded paths without a WoW client.
-- The Retail package must continue to omit modules.xml and these modules.

local modules = {}
local locale = setmetatable({}, { __index = function(_, key) return key end })

function LibStub(name)
	if name == "AceLocale-3.0" then return { GetLocale = function() return locale end } end
	if name == "AceTab-3.0" then return {} end
end

ChattyChattyBangBang = {}
function ChattyChattyBangBang:NewModule(name)
	local mod = { TempChatFrames = {}, hooks = {}, events = {} }
	function mod:RegisterEvent(event) self.events[event] = true end
	function mod:HookScript() end
	function mod:IsHooked() return false end
	modules[name] = mod
	return mod
end

-- F19 and F22: Retail group APIs and a client-reported level cap.
CLASS_SORT_ORDER = { "MAGE" }
LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage" }
table.invert = function(values)
	local inverted = {}
	for key, value in pairs(values) do inverted[value] = key end
	return inverted
end
wipe = function(values) for key in pairs(values) do values[key] = nil end end
strbyte = string.byte
sqrt = math.sqrt
tinsert, tremove = table.insert, table.remove
unpack = unpack or table.unpack
UNKNOWN = "Unknown"
RAID_CLASS_COLORS = { MAGE = { r = 0.2, g = 0.5, b = 1 } }
NUM_CHAT_WINDOWS = 0
IsInGuild = function() return false end

local inRaid = false
IsInRaid = function() return inRaid end
GetNumGroupMembers = function() return 2 end
GetNumSubgroupMembers = function() return 1 end
GetNumRaidMembers = nil
GetNumPartyMembers = nil
GetRaidRosterInfo = function(index)
	if index == 1 then return "Raider", nil, nil, 85, nil, "MAGE" end
end
UnitName = function(unit)
	if unit == "player" then return "Me" end
	if unit == "party1" then return "PartyMate" end
end
UnitClass = function(unit)
	if unit == "party1" then return "Mage", "MAGE" end
end
UnitLevel = function(unit) if unit == "party1" then return 87 end end

dofile("Modules/PlayerNames.lua")
local names = modules["Player Class Colors"]
assert(names, "Player Names fallback did not register")
names.db = {
	realm = { names = {} },
	profile = {
		leftBracket = "[", rightBracket = "]", separator = ":",
		nameColoring = "NONE", useTabComplete = false, saveParty = true,
		includeLevel = true, excludeMaxLevel = true,
	},
}
names:OnEnable()
assert(names.events.GROUP_ROSTER_UPDATE and not names.events.RAID_ROSTER_UPDATE,
	"modern group roster event was not selected when legacy count APIs are absent")
assert(names.db.realm.names.PartyMate and names.db.realm.names.PartyMate.level == 87,
	"modern party count did not populate a party member")
inRaid = true
names:GROUP_ROSTER_UPDATE("GROUP_ROSTER_UPDATE")
assert(names.db.realm.names.Raider and names.db.realm.names.Raider.level == 85,
	"modern raid count did not populate a raid member")

local maxLevel = 90
GetMaxPlayerLevel = function() return maxLevel end
local frame = {}
names.hooks[frame] = { AddMessage = function(_, message) return message end }
local function displayedName(name, level)
	names:AddPlayer(name, "MAGE", level, true)
	return names:AddMessage(frame, "|Hplayer:" .. name .. "|h[" .. name .. "]|h says hi")
end
assert(displayedName("Alice", 80):find("Alice:80", 1, true),
	"an old level-80 cap still hides a non-max-level character")
assert(not displayedName("Bob", 90):find("Bob:90", 1, true),
	"the current client max level was not hidden")
GetMaxPlayerLevel = nil
MAX_PLAYER_LEVEL = 70
assert(not displayedName("Cora", 70):find("Cora:70", 1, true),
	"the older client max-level constant was not honored")
MAX_PLAYER_LEVEL = nil
assert(displayedName("Dana", 80):find("Dana:80", 1, true),
	"an unknown cap should not hide arbitrary levels")

-- F20: the Blizzard guild UI is load-on-demand and may not exist.
StaticPopupDialogs = {}
UnitPopupButtons = {}
TEXT = function(value) return value end
ACCEPT, CANCEL = "Accept", "Cancel"
GuildFrame = nil
dofile("Modules/AltNames.lua")
local alts = modules["Alt Linking"]
local guildScans = 0
function alts:ScanGuildNotes() guildScans = guildScans + 1 end
alts:GUILD_ROSTER_UPDATE("GUILD_ROSTER_UPDATE")
alts:GUILD_ROSTER_UPDATE("GUILD_ROSTER_UPDATE")
assert(guildScans == 1, "missing GuildFrame caused a crash or repeated idle scans")
alts:GUILD_ROSTER_UPDATE("GUILD_ROSTER_UPDATE", true)
assert(guildScans == 2, "explicit guild change did not trigger a scan")

-- F21: restore the actual saved fields, including a nil noMouseAlpha.
GameFontNormalSmall = {}
local function texture()
	return {
		SetAlpha = function() end, SetTexture = function() end,
		SetWidth = function() end, SetTexCoord = function() end,
		Hide = function() end, Show = function() end,
	}
end
local tab = {
	noMouseAlpha = 0.6, alpha = 0.7,
	leftSelectedTexture = texture(), rightSelectedTexture = texture(), middleSelectedTexture = texture(),
	leftHighlightTexture = texture(), rightHighlightTexture = texture(), middleHighlightTexture = texture(),
}
function tab:SetHeight(height) self.height = height end
function tab:EnableMouseWheel(enabled) self.mouseWheel = enabled end
function tab:SetAlpha(alpha) self.alpha = alpha end
function tab:GetAlpha() return self.alpha end
function tab:Hide() self.hidden = true end
ChatFrame1, ChatFrame1Tab = {}, tab
ChatFrame1TabLeft, ChatFrame1TabMiddle, ChatFrame1TabRight = texture(), texture(), texture()
NUM_CHAT_WINDOWS = 1
dofile("Modules/ChatTabs.lua")
local tabs = modules.ChatTabs
tabs.db = { profile = { height = 29, tabFlash = true } }
tabs:OnEnable()
assert(tab.noMouseAlpha == 0 and tab.alpha == 0, "fallback tab fade was not applied")
tabs:OnDisable()
assert(tab.noMouseAlpha == 0.6 and tab.alpha == 0.7 and tab.noMousealpha == nil,
	"fallback tab fade was not restored to its original values")
tab.noMouseAlpha, tab.alpha = nil, 0
tabs:OnEnable()
tabs:OnDisable()
assert(tab.noMouseAlpha == nil and tab.alpha == 0,
	"a nil noMouseAlpha or zero alpha was not restored exactly")

print("Legacy fallback guard mock passed")
