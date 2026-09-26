-- Visual/control contract for Chat Window > Input history limits.
-- Run from addon root: lua Tests/ChatHistoryLimitsConfig.mock.lua
dofile("Tests/NewMessageIndicatorConfig.mock.lua")

local addon = ChattyChattyBangBang
local config = addon.CustomConfig
local settings = addon:GetSmartSettings()
settings.historyCapacity = 1000
settings.historyTotalCapacity = nil
settings.historySourceLimits = {}
local definitions = {}
for index = 1, 13 do
	definitions[index] = {
		sourceId = string.format("channel:source%02d", index),
		sourceLabel = string.format("Source %02d", index),
	}
end
addon.MessageEngine = {
	GetHistoryStats = function() return { lines = 187, sources = 3 } end,
	GetSourceDefinitions = function() return definitions end,
}
function addon:GetChatHistorySettings()
	return {
		enabled = true, linesPerSource = settings.historyCapacity,
		aggregateCapacity = settings.historyTotalCapacity,
		suggestedAggregateCapacity = 50000,
	}
end
function addon:SetChatHistoryAggregateCapacity(value)
	settings.historyTotalCapacity = value
	return true, value
end
function addon:GetChatHistorySourceLimit(sourceId)
	local selected = settings.historySourceLimits[sourceId]
	return selected or settings.historyCapacity, selected ~= nil
end
function addon:SetChatHistorySourceLimit(sourceId, value)
	settings.historySourceLimits[sourceId] = value
	return true, value or settings.historyCapacity, value ~= nil
end

config:SetDockSection("layout")
config:SetDockLayoutCategory("input")
config:RefreshDockPage()
assert(config.dockHistoryAggregateToggle:IsShown()
	and config.dockHistoryAggregateEdit:IsShown()
	and config.dockHistorySourcesButton:IsShown(),
	"Input did not expose total and per-source controls")
assert(config.dockHistoryAggregateToggle.point[4] + config.dockHistoryAggregateToggle.width
	+ 8 <= config.dockHistoryAggregateEdit.point[4],
	"total-cap toggle and number field lost their visible gutter")
assert(not config.dockHistoryAggregateToggle.value
	and settings.historyTotalCapacity == nil,
	"new profiles silently enabled a total history cap")

config.dockHistoryAggregateEdit:SetText("24000")
config.dockHistoryAggregateEdit.scripts.OnEditFocusLost(config.dockHistoryAggregateEdit)
assert(settings.historyTotalCapacity == nil and config.dockHistoryAggregateDraft == 24000,
	"editing a disabled total cap silently pruned history")
config.dockHistoryAggregateToggle:SetValue(true)
assert(settings.historyTotalCapacity == 24000
	and config.dockHistoryFootprint:GetText():find("Total cap: 24000", 1, true),
	"explicit total-cap opt-in did not show its actual policy")
config.dockHistoryAggregateToggle:SetValue(false)
assert(settings.historyTotalCapacity == nil, "turning off the total cap did not restore unlimited behavior")

config.dockHistorySourcesButton.scripts.OnClick(config.dockHistorySourcesButton)
assert(config.dockHistorySourcePageOpen and not config.dockHistoryToggle:IsShown()
	and config.dockHistorySourceRows[1].edit:IsShown(),
	"source limits did not open as a separate, bounded Input inspector")
assert(config.dockHistorySourceRows[1].sourceId == "channel:source01"
	and config.dockHistorySourcePager:GetText():find("1 / 3", 1, true),
	"source list did not paginate known physical sources")
local row = config.dockHistorySourceRows[1]
assert(row.label.point[4] + row.label.width + 8 <= row.edit.point[4]
	and row.edit.point[4] + row.edit.width + 8 <= row.inherit.point[4],
	"source label, field, and inheritance control lost their gutters")
local last = config.dockHistorySourceRows[6]
assert(-last.edit.point[5] + last.edit.height + 12 < -config.dockHistorySourcePrev.point[5]
	and -config.dockHistorySourcePrev.point[5] + config.dockHistorySourcePrev.height + 12
		< -config.dockStatus.point[5],
	"source rows or pager overlap the status line")

row.edit:SetText("2500")
row.edit.scripts.OnEditFocusLost(row.edit)
assert(settings.historySourceLimits["channel:source01"] == 2500
	and row.inherit.text:GetText() == "INHERIT",
	"one-source override did not save or expose its non-default state")
row.inherit.scripts.OnClick(row.inherit)
assert(settings.historySourceLimits["channel:source01"] == nil
	and row.inherit.text:GetText() == "DEFAULT",
	"source override could not return to inheritance")
config.dockHistorySourceNext.scripts.OnClick(config.dockHistorySourceNext)
assert(config.dockHistorySourceRows[1].sourceId == "channel:source07"
	and config.dockHistorySourcePager:GetText():find("2 / 3", 1, true),
	"source pager did not advance")
config.dockHistorySourceControls[2].scripts.OnClick(config.dockHistorySourceControls[2])
assert(not config.dockHistorySourcePageOpen and config.dockHistoryToggle:IsShown(),
	"Back did not restore the main Input inspector")

print("Chat history limit config mock passed")
