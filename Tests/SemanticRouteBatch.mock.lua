-- Batch semantic route edits must produce one final retained-history sort.
-- Run from addon root: lua Tests/SemanticRouteBatch.mock.lua
dofile("Tests/MessageRouteMove.mock.lua")

local addon = ChattyChattyBangBang
local settings = addon:GetSmartSettings()
local engine = addon.MessageEngine
local records = engine:GetMessages("trade")
local ad = assert(records[#records], "trade fixture missing")
local history = settings.history
local reclassifications, redraws = 0, 0
local originalReclassify = engine.ReclassifyAll
engine.ReclassifyAll = function(self)
	reclassifications = reclassifications + 1
	return originalReclassify(self)
end
addon.SmartDock = {
	unread = { general = 1, trade = 1, groupFinder = 0, pvp = 0 },
	activeView = "system", pendingVisible = 0,
	RebuildActiveView = function() redraws = redraws + 1 end,
}

assert(not addon:ApplySemanticRouteChanges({ trade = false, missing = true })
	and not addon:ApplySemanticRouteChanges({ trade = "false" })
	and settings.semanticRoutes.trade ~= false
	and reclassifications == 0 and redraws == 0,
	"invalid batch partially changed SavedVariables or reclassified history")

local ok, changed = addon:ApplySemanticRouteChanges({ trade = false, pvp = false })
assert(ok and changed == 2 and reclassifications == 1 and redraws == 1,
	"two explicit switches caused more than one retained-history sort/redraw")
assert(settings.semanticRoutes.trade == false and settings.semanticRoutes.pvp == false
	and ad.view == "general" and #engine:GetMessages("trade") == 0
	and engine:GetMessages("general")[3] == ad,
	"batch did not apply the final route policy to retained history")
assert(addon.SmartDock.unread.general == 1 and addon.SmartDock.unread.trade == 0,
	"batch unread mismatch: General " .. tostring(addon.SmartDock.unread.general)
		.. ", Trade " .. tostring(addon.SmartDock.unread.trade))
assert(settings.history == history and engine.count == 3,
	"batch rewrote stored message bodies instead of derived membership")

ok, changed = addon:ApplySemanticRouteChanges({ trade = false, pvp = false })
assert(ok and changed == 0 and reclassifications == 1 and redraws == 1,
	"no-op batch needlessly reclassified history")
assert(addon:SetSemanticRouteEnabled("trade", true)
	and reclassifications == 2 and redraws == 2
	and ad.view == "trade" and engine:GetMessages("general")[3] == ad,
	"single-edit behavior lost immediate routing or explicit General mirror")
assert(addon.SmartDock.unread.general == 1 and addon.SmartDock.unread.trade == 0,
	"single edit created a false unread badge for an old routed line")

-- Failure after a partial retained-history pass must restore both the saved
-- route map and all derived memberships; the retry remains available.
local previousMap = settings.semanticRoutes
addon.SmartDock.unread.trade = 1
addon.SmartDock.activeView = "general"
addon.SmartDock.pendingVisible = 1
local failOnce = true
engine.ReclassifyAll = function(self)
	reclassifications = reclassifications + 1
	local result = originalReclassify(self)
	if failOnce then
		failOnce = false
		error("synthetic reclassification failure")
	end
	return result
end
ok = addon:ApplySemanticRouteChanges({ trade = false, groupFinder = false })
assert(not ok and settings.semanticRoutes == previousMap
	and settings.semanticRoutes.trade ~= false
	and settings.semanticRoutes.groupFinder ~= false
	and ad.view == "trade" and engine:GetMessages("trade")[1] == ad,
	"failed batch did not roll back settings and retained memberships")
assert(addon.SmartDock.unread.general == 1 and addon.SmartDock.unread.trade == 1
	and addon.SmartDock.pendingVisible == 1,
	"failed batch changed unread badges or the active NEW marker")

local redrawFail = true
addon.SmartDock.RebuildActiveView = function()
	if redrawFail then
		redrawFail = false
		error("synthetic redraw failure")
	end
	redraws = redraws + 1
end
previousMap = settings.semanticRoutes
ok = addon:ApplySemanticRouteChanges({ pvp = true })
assert(not ok and settings.semanticRoutes == previousMap
	and settings.semanticRoutes.pvp == false and ad.view == "trade"
	and addon.SmartDock.unread.general == 1 and addon.SmartDock.unread.trade == 1
	and addon.SmartDock.pendingVisible == 1,
	"redraw failure changed route settings, memberships, or unread state")

engine:ClearHistory()
ok, changed = addon:ApplySemanticRouteChanges({ groupFinder = false })
assert(ok and changed == 1 and engine.count == 0
	and settings.semanticRoutes.groupFinder == false,
	"empty-history profile could not apply a batch safely")

print("Semantic route batch mock passed")
