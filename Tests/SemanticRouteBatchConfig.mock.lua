-- Semantic Routes keeps immediate switches until an explicit batch begins.
-- Run from addon root: lua Tests/SemanticRouteBatchConfig.mock.lua
dofile("Tests/MessageViewsConfig.mock.lua")

local addon = ChattyChattyBangBang
local config = addon.CustomConfig
local immediateCalls, batchCalls = 0, 0
local originalSetter = addon.SetSemanticRouteEnabled
function addon:SetSemanticRouteEnabled(routeId, enabled)
	immediateCalls = immediateCalls + 1
	return originalSetter(self, routeId, enabled)
end
function addon:ApplySemanticRouteChanges(changes)
	batchCalls = batchCalls + 1
	local count = 0
	for routeId, enabled in pairs(changes) do
		originalSetter(self, routeId, enabled)
		count = count + 1
	end
	return true, count
end

config:RefreshSemanticRoutesPage()
assert(config.semanticRouteBatchButton:IsShown()
	and not config.semanticRouteApplyButton:IsShown()
	and not config.semanticRouteCancelButton:IsShown(),
	"batch actions were shown without explicit entry")
local work = config.semanticRouteBatchButton.parent
local apply = config.semanticRouteApplyButton
local cancel = config.semanticRouteCancelButton
local lfg = config.semanticRouteToggles.groupFinder
local trade = config.semanticRouteToggles.trade
local pvp = config.semanticRouteToggles.pvp
assert(lfg.point[4] + lfg.width + 8 <= trade.point[4]
	and trade.point[4] + trade.width + 8 <= pvp.point[4]
	and pvp.point[4] + pvp.width + 8 <= work.width - 8,
	"wide-font route switches overlap or cross the panel gutter")
assert(apply.point[4] + apply.width + 8 <= cancel.point[4]
	and cancel.point[4] + cancel.width + 8 <= work.width - 8,
	"batch Apply/Cancel buttons overlap or cross the panel gutter")
assert(-apply.point[5] + apply.height + 8 <= -config.semanticRoutesAvailability.point[5]
	and -config.semanticRoutesTestInput.point[5]
		+ config.semanticRoutesTestInput.height + 8 <= -config.semanticRoutesResult.point[5]
	and work.height >= 352 and -config.semanticRoutesStatus.point[5] >= 10,
	"batch row, analysis controls, or panel status lost their gutters")

config.semanticRouteBatchButton.scripts.OnClick()
assert(config.semanticRouteBatchDraft and apply:IsShown() and cancel:IsShown()
	and not config.semanticRouteBatchButton:IsShown(),
	"Batch Edit did not disclose Apply/Cancel")
config.semanticRouteToggles.groupFinder:SetValue(false)
config.semanticRouteToggles.pvp:SetValue(false)
assert(config.semanticRouteBatchDraft.groupFinder == false
	and config.semanticRouteBatchDraft.pvp == false
	and config.semanticRouteToggles.groupFinder.checked == false
	and addon:GetSemanticRouteEnabled("groupFinder") == true
	and immediateCalls == 0 and batchCalls == 0,
	"staging changed the real route or reset a staged OFF switch")

-- A route changed elsewhere while the page was open. Applying the stale
-- draft must not reverse that external change.
originalSetter(addon, "trade", true)
assert(not config:ApplySemanticRouteBatch()
	and batchCalls == 0 and addon:GetSemanticRouteEnabled("trade") == true
	and config.semanticRouteBatchDraft ~= nil,
	"stale batch silently overwrote a route edited elsewhere")
cancel.scripts.OnClick()
assert(config.semanticRouteBatchDraft == nil
	and config.semanticRouteToggles.groupFinder.checked
	and config.semanticRouteToggles.pvp.checked,
	"Cancel did not restore live route switches")

config.semanticRouteBatchButton.scripts.OnClick()
config.semanticRouteToggles.groupFinder:SetValue(false)
config.semanticRouteToggles.pvp:SetValue(false)
apply.scripts.OnClick()
assert(batchCalls == 1 and immediateCalls == 0
	and addon:GetSemanticRouteEnabled("groupFinder") == false
	and addon:GetSemanticRouteEnabled("pvp") == false
	and config.semanticRouteBatchDraft == nil
	and config.semanticRouteBatchButton:IsShown(),
	"Apply did not submit one batch and return to immediate switches")
config.semanticRouteToggles.trade:SetValue(false)
assert(immediateCalls == 1 and addon:GetSemanticRouteEnabled("trade") == false,
	"single switch no longer applies immediately outside batch mode")

print("Semantic route batch config mock passed")
