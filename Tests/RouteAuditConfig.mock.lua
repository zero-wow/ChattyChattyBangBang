-- Route Audit contract: all retained visible lines are paged newest-first,
-- and a source-fed line is not mistaken for its primary classifier route.
-- Run from the addon root with: lua Tests/RouteAuditConfig.mock.lua

local function control()
	return {
		SetText = function(self, value) self.text = value end,
		Show = function(self) self.shown = true end,
		Hide = function(self) self.shown = false end,
		Enable = function(self) self.enabled = true end,
		Disable = function(self) self.enabled = false end,
	}
end

local records = {}
for index = 1, 29 do
	records[index] = {
		id = index, epoch = 1700000000 + index, text = "Message " .. index,
		sourceId = "channel:trade-services", sourceLabel = "Trade - Services",
		sourceGroup = "trade", view = "trade", views = { trade = true },
	}
end

local settings = {
	historyCapacity = 150,
	viewOptions = { general = { sources = { ["channel:trade-services"] = true } }, },
}
ChattyChattyBangBang = {
	Theme = {},
	GetSmartViews = function() return {
		{ id = "general", label = "General" }, { id = "trade", label = "Trade" },
	} end,
	GetSmartSettings = function() return settings end,
	GetDefaultViewForSource = function() return "trade" end,
	IsRecordIncludedBySource = function(_, viewId, record, selectedSettings)
		assert(selectedSettings == settings)
		return viewId == "general" and selectedSettings.viewOptions.general.sources[record.sourceId] == true
	end,
	AnalyzeRecord = function(_, record)
		return { reasons = { "Trade wording passed the selling threshold." }, view = record.view }
	end,
	MessageEngine = {
		GetMessages = function(_, viewId)
			return viewId == "general" and records or {}
		end,
	},
}
date = function() return "12:00" end

dofile("Core/Config.lua")
local audit = ChattyChattyBangBang.CustomConfig
audit.routeAuditPage = {}
audit.routeAuditViewId = "general"
audit.routeAuditTabName = control()
audit.routeAuditPreviousTab = control()
audit.routeAuditNextTab = control()
audit.routeAuditCount = control()
audit.routeAuditHint = control()
audit.routeAuditPager = control()
audit.routeAuditNewer = control()
audit.routeAuditOlder = control()
audit.routeAuditDetailMessage = control()
audit.routeAuditDetailSource = control()
audit.routeAuditDetailPath = control()
audit.routeAuditDetailReason = control()
audit.routeAuditRows = {}
for index = 1, 12 do
	local row = control()
	row.when, row.message, row.route, row.via = control(), control(), control(), control()
	audit.routeAuditRows[index] = row
end

audit:RefreshRouteAuditPage()
assert(audit.routeAuditCount.text == "29 retained visible lines")
assert(audit.routeAuditHint.text:find("up to 150/source", 1, true))
assert(audit.routeAuditPager.text:find("PAGE 1 / 3", 1, true))
assert(audit.routeAuditRows[1].record == records[29])
assert(audit.routeAuditRows[12].record == records[18])
assert(audit.routeAuditRows[1].route.text == "Trade")
assert(audit.routeAuditRows[1].via.text == "EXPLICIT FEED")

audit.routeAuditPageIndex = 2
audit:RefreshRouteAuditPage(true)
assert(audit.routeAuditRows[1].record == records[17])
assert(audit.routeAuditRows[12].record == records[6])

audit.routeAuditPageIndex = 3
audit:RefreshRouteAuditPage(true)
assert(audit.routeAuditRows[1].record == records[5])
assert(audit.routeAuditRows[5].record == records[1])
assert(audit.routeAuditRows[6].shown == false)
assert(audit.routeAuditOlder.enabled == false)

audit.routeAuditSelectedRecord = records[1]
audit:RefreshRouteAuditPage(true)
assert(audit.routeAuditDetailPath.text:find("PRIMARY  Trade", 1, true))
assert(audit.routeAuditDetailPath.text:find("EXPLICIT FEED", 1, true))
assert(audit.routeAuditDetailPath.text:find("checked in Contents", 1, true))
assert(audit.routeAuditDetailSource.text:find("channel:trade-services", 1, true))
assert(audit.routeAuditDetailSource.text:find("HOME  Trade", 1, true))
assert(audit.routeAuditDetailReason.text:find("selling threshold", 1, true))

settings.viewOptions.general.sources["channel:trade-services"] = nil
ChattyChattyBangBang.IsRecordIncludedBySource = function() return true end
audit:RefreshRouteAuditPage(true)
assert(audit.routeAuditRows[1].via.text == "SOURCE FEED")
assert(audit.routeAuditDetailPath.text:find("DEFAULT SOURCE FEED", 1, true))
assert(not audit.routeAuditDetailPath.text:find("checked in Contents", 1, true))

ChattyChattyBangBang.GetDefaultViewForSource = function() return "general" end
audit:RefreshRouteAuditPage(true)
assert(audit.routeAuditRows[1].via.text == "SOURCE HOME")
assert(audit.routeAuditDetailPath.text:find("SOURCE HOME", 1, true))

records[1].view = "general"
records[1].views = { general = true }
audit:RefreshRouteAuditPage(true)
assert(audit.routeAuditRows[5].via.text == "PRIMARY")
assert(audit.routeAuditDetailPath.text:find("PRIMARY  General", 1, true))

print("Route Audit config mock passed")
