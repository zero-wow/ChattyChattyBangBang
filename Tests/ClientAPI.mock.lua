-- No-client contract for the small modern/legacy client API boundary.
-- Run from the addon root with: lua Tests/ClientAPI.mock.lua

ChattyChattyBangBang = {}
_G.WOW_PROJECT_ID = 1
_G.WOW_PROJECT_MAINLINE = 1

local disabled, saved = nil, false
_G.C_AddOns = {
	IsAddOnLoaded = function(name) return name == "Loaded" end,
	GetNumAddOns = function() return 2 end,
	GetAddOnInfo = function(index)
		if index == 1 then return { name = "Loaded", title = "Loaded title", notes = "notes", enabled = true } end
		return { name = "Other", title = "Other title", enabled = false }
	end,
	DisableAddOn = function(name) disabled = name end,
	SaveAddOns = function() saved = true end,
}

dofile("Core/ClientAPI.lua")
local api = ChattyChattyBangBang.ClientAPI
assert(api:IsRetail(), "mainline project id should select Retail")
assert(api:IsAddOnLoaded("Loaded") and not api:IsAddOnLoaded("Other"), "C_AddOns load state was not used")
assert(not api:IsAddOnLoaded(nil), "missing addon names must not reach Retail C_AddOns")
assert(api:GetNumAddOns() == 2, "C_AddOns count was not used")
local name, title, notes, enabled = api:GetAddOnInfo(1)
assert(name == "Loaded" and title == "Loaded title" and notes == "notes" and enabled == true,
	"C_AddOns info table was not normalized")
api:DisableAddOn("Loaded")
api:SaveAddOns()
assert(disabled == "Loaded" and saved, "C_AddOns mutation facade did not run")
_G.IsInInstance = function() return false, nil end
_G.IsInRaid = function() return true end
_G.IsInGroup = function() return true end
assert(api:GetGroupChatType() == "RAID", "Retail raid route was not recognized")
_G.IsInRaid = function() return false end
assert(api:GetGroupChatType() == "PARTY", "Retail party route was not recognized")
_G.IsInInstance = function() return true, "pvp" end
assert(api:GetGroupChatType() == "BATTLEGROUND", "Retail battleground route was not recognized")

_G.C_AddOns = nil
_G.WOW_PROJECT_ID = nil
_G.GetNumAddOns = function() return 1 end
_G.GetAddOnInfo = function() return "Legacy", "Legacy title", "legacy notes", 1 end
_G.IsAddOnLoaded = function(name) return name == "Legacy" end
_G.DisableAddOn = function(name) disabled = "legacy:" .. name end
_G.SaveAddOns = function() saved = "legacy" end
_G.IsInInstance = function() return false, nil end
_G.IsInRaid = nil
_G.IsInGroup = nil
_G.GetNumRaidMembers = function() return 0 end
_G.GetNumPartyMembers = function() return 2 end
assert(api:GetNumAddOns() == 1 and api:IsAddOnLoaded("Legacy"), "legacy addon APIs were not retained")
name, title, notes, enabled = api:GetAddOnInfo(1)
assert(name == "Legacy" and title == "Legacy title" and notes == "legacy notes" and enabled == 1,
	"legacy addon info was not retained")
api:DisableAddOn("Legacy")
api:SaveAddOns()
assert(disabled == "legacy:Legacy" and saved == "legacy", "legacy addon mutations were not retained")
assert(api:GetGroupChatType() == "PARTY", "Wrath party route was not retained")

print("ClientAPI mock tests passed")
