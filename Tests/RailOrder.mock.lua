-- Focused model test for the visual rail-order API.  It intentionally loads
-- Settings without a WoW client: rail movement must remain SavedVariables-only
-- and must not require a live SmartDock or MessageEngine.
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
local views = addon:GetSmartViews()
assert(views[1].id == "general")
assert(views[1].label == "GENERAL")
assert(views[2].id == "newcomers" and views[2].key == "NC")
assert(views[5].id == "group")
assert(views[5].label == "GROUP")
assert(views[6].id == "groupFinder")
assert(views[7].id == "guildInvites" and views[7].key == "GU INV")
assert(views[8].id == "pvp" and views[8].key == "PVP" and views[8].enabled == true)
assert(views[#views].id == "loot")

assert(addon:MoveSmartView("loot", -99))
views = addon:GetSmartViews()
assert(views[1].id == "loot")
assert(settings.railOrder[1] == "loot")

local custom = assert(addon:CreateCustomView({ label = "Mine", key = "M" }))
views = addon:GetSmartViews()
assert(views[#views].id == custom.id)
assert(addon:MoveSmartViewToIndex(custom.id, 2))
views = addon:GetSmartViews()
assert(views[2].id == custom.id)

settings.railOrder = { "loot", "loot", "missing", custom.id }
views = addon:GetSmartViews()
assert(views[1].id == "loot")
assert(views[2].id == custom.id)
assert(#settings.railOrder == #views)

assert(addon:DeleteCustomView(custom.id))
views = addon:GetSmartViews()
for index = 1, #views do
	assert(views[index].id ~= custom.id)
end

-- CONTENTS is tri-state: nil inherits the source's clean built-in home, true
-- adds a full source feed elsewhere, and false hides a source from its home.
-- Definitions must expose those distinctions without losing a saved false.
addon.MessageEngine = {
	GetSourceDefinitions = function()
		return {
			{ id = "channel:trade", sourceId = "channel:trade", label = "Trade", sourceLabel = "Trade", sourceGroup = "channels" },
		}
	end,
}
local sources = addon:GetViewSourceDefinitions("general")
assert(addon:SetViewSourceEnabled("general", "channel:trade", true))
sources = addon:GetViewSourceDefinitions("general")
assert(sources[1].defaultEnabled == false and sources[1].override == true and sources[1].enabled == true,
	"non-home source did not persist as an explicit additive feed")
assert(addon:IsRecordIncludedBySource("general", {
	sourceId = "channel:trade", sourceGroup = "channels",
}), "explicit additive feed did not include its source")
assert(addon:ResetViewSources("general"))
sources = addon:GetViewSourceDefinitions("general")
assert(sources[1].override == nil and sources[1].enabled == false,
	"reset did not restore General's clean source-home defaults")

assert(addon:SetViewSourceEnabled("trade", "channel:trade", false))
sources = addon:GetViewSourceDefinitions("trade")
assert(sources[1].defaultEnabled == true and sources[1].override == false and sources[1].enabled == false,
	"known home source lost its explicit false override")
assert(addon:IsRecordAllowedInView("trade", { sourceId = "channel:trade" }) == false,
	"explicitly hidden home source still passed the rail filter")
assert(addon:ResetViewSources("trade"))
sources = addon:GetViewSourceDefinitions("trade")
assert(sources[1].override == nil and sources[1].enabled == true,
	"reset did not restore the Trade source's inherited home")

-- Shift > ANALYZE may save only an exact normalized public-channel correction.
-- It cannot inspect or retain private text, and changing one immediately asks
-- the live engine/dock to reclassify the bounded history.
local reclassifications, rebuilds = 0, 0
addon.MessageEngine = {
	ReclassifyAll = function() reclassifications = reclassifications + 1 end,
}
addon.SmartDock = {
	RebuildActiveView = function() rebuilds = rebuilds + 1 end,
}
local publicRecord = { event = "CHAT_MSG_CHANNEL", text = "  LF  tank   [Keystone: Test]  " }
assert(addon:SetMessageRouteOverride(publicRecord, "groupFinder"), "could not save public-channel route correction")
assert(addon:GetMessageRouteOverride({ event = "CHAT_MSG_CHANNEL", text = "lf tank [keystone: test]" }) == "groupFinder",
	"route correction did not use exact case-insensitive whitespace-normalized text")
assert(reclassifications == 1 and rebuilds == 1, "route correction did not refresh live history")
local destinations = addon:GetMessageRouteOverrideDestinations()
local canRouteToNewcomers, canRouteToGuildInvites, canRouteToPvp = false, false, false
local canRouteToSystem, canRouteToLoot = false, false
for index = 1, #destinations do
	canRouteToNewcomers = canRouteToNewcomers or destinations[index].id == "newcomers"
	canRouteToGuildInvites = canRouteToGuildInvites or destinations[index].id == "guildInvites"
	canRouteToPvp = canRouteToPvp or destinations[index].id == "pvp"
	canRouteToSystem = canRouteToSystem or destinations[index].id == "system"
	canRouteToLoot = canRouteToLoot or destinations[index].id == "loot"
end
assert(canRouteToNewcomers and canRouteToGuildInvites and canRouteToPvp and canRouteToSystem and canRouteToLoot,
	"route destination menu omitted a built-in public destination")
assert(addon:SetMessageRouteOverride(publicRecord, "pvp"), "could not move a public notice to PVP")
assert(addon:GetMessageRouteOverride(publicRecord) == "pvp" and reclassifications == 2 and rebuilds == 2,
	"PVP route correction did not replace and refresh")
assert(addon:SetMessageRouteOverride(publicRecord, "system"), "could not move public notice to System")
assert(addon:GetMessageRouteOverride(publicRecord) == "system" and reclassifications == 3 and rebuilds == 3,
	"System route correction did not replace and refresh")
assert(not addon:SetMessageRouteOverride({ event = "CHAT_MSG_WHISPER", text = "private" }, "general"),
	"private message was accepted as a route correction")
assert(addon:RemoveMessageRouteOverride(publicRecord), "could not remove exact route correction")
assert(addon:GetMessageRouteOverride(publicRecord) == nil and reclassifications == 4 and rebuilds == 4,
	"route correction removal did not clear and refresh")

-- Semantic inference remains opt-out, and toggling it refreshes bounded live
-- history without changing exact manual route corrections.
assert(addon:GetSemanticRouteEnabled("groupFinder") == true, "Group Finder inference did not default on")
assert(addon:SetSemanticRouteEnabled("groupFinder", false), "could not disable Group Finder inference")
assert(addon:GetSemanticRouteEnabled("groupFinder") == false and reclassifications == 5 and rebuilds == 5,
	"semantic route toggle did not persist and refresh")
assert(addon:SetSemanticRouteEnabled("groupFinder", true), "could not re-enable Group Finder inference")
assert(addon:GetSemanticRouteEnabled("pvp") == true, "PVP inference did not default on")
assert(addon:SetSemanticRouteEnabled("pvp", false), "could not disable PVP inference")
assert(addon:GetSemanticRouteEnabled("pvp") == false and reclassifications == 7 and rebuilds == 7,
	"PVP semantic route toggle did not persist and refresh")
assert(addon:SetSemanticRouteEnabled("pvp", true), "could not re-enable PVP inference")
assert(not addon:SetSemanticRouteEnabled("missing", true), "unknown semantic route was accepted")

print("Rail order settings mock passed")
