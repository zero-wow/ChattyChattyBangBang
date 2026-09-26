-- Focused no-client contract for the in-dock retained-history search drawer.
-- Run from the Retail addon root: lua Tests/SmartDockSearchDrawer.mock.lua

ChattyChattyBangBang = {
	Theme = {},
	Presentation = {},
	GetSmartSettings = function() return { dock = { showScrollButtons = true } } end,
}
dofile("Core/SmartDock.lua")
local addon = ChattyChattyBangBang
local dock = addon.SmartDock

local function widget(width, height, shown)
	local value = { width = width or 300, height = height or 78, shown = shown, points = {} }
	function value:ClearAllPoints() self.points = {} end
	function value:SetPoint(...) self.points[#self.points + 1] = { ... } end
	function value:SetHeight(nextHeight) self.height = nextHeight end
	function value:GetHeight() return self.height end
	function value:GetWidth() return self.width end
	function value:IsShown() return self.shown == true end
	function value:Show() self.shown = true end
	function value:Hide() self.shown = false end
	function value:SetText(text) self.text = text end
	function value:SetLabel(text) self.text = text end
	function value:GetText() return self.text or "" end
	function value:Clear() self.messages = {} end
	function value:AddMessage(text) self.messages[#self.messages + 1] = text end
	function value:ScrollToTop() self.scrollToTop = true end
	return value
end

local function point(value, name)
	for _, anchor in ipairs(value.points) do
		if anchor[1] == name then return anchor end
	end
	return nil
end

dock.searchOpen = true
assert(dock:GetSearchDrawerHeight(78, 4, 4) == 70,
	"360x160 dock must fit the entire search surface inside its 78px content lane")
assert(dock:GetSearchDrawerHeight(300, 4, 4) == 132,
	"large docks must cap search height instead of consuming the whole message viewport")
assert(dock:GetSearchDrawerHeight(78, 46, 4) == 0,
	"search must defer when a notice leaves too little room")

dock.content = widget(300, 78, true)
dock.header = widget(360, 24, true)
dock.display = widget(300, 78, true)
function dock.display:GetCurrentScroll() return self.scroll or 0 end
function dock.display:AtBottom() return (self.scroll or 0) == 0 end
function dock.display:ScrollToBottom() self.scroll = 0 end
function dock.display:SetScrollOffset(value) self.scroll = value end
dock.emptyState = widget(300, 20, true)
dock.searchDrawer = widget(292, 70, false)
dock.searchContentTrigger = widget(42, 18, false)
dock.messageScrollbar = widget(16, 40, false)
dock.scrollToBottomButton = widget(24, 20, false)
dock.HideMessageBands = function() end
dock.HideMessageActionHighlight = function() end
dock.HandleDisplayViewportChanged = function() end
dock.RefreshMessageScrollbar = function() end
assert(dock:RefreshTransientMessageLayout(), "search layout could not reserve the message lane")
assert(dock.searchDrawer:IsShown() and dock.searchDrawer:GetHeight() == 70,
	"minimum-size search drawer was clipped or lost")
assert(point(dock.searchDrawer, "TOPLEFT")[4] == 4
	and point(dock.searchDrawer, "TOPLEFT")[5] == -4
	and point(dock.searchDrawer, "TOPRIGHT")[4] == -4,
	"search drawer must retain four-pixel left/top/right border gutters")
assert(not dock.display:IsShown() and not dock.messageScrollbar:IsShown(),
	"minimum-size search drawer must suppress chat and its thumb, not overlap them")
assert(not dock.searchContentTrigger:IsShown(),
	"a visible title bar should not duplicate FIND inside the message surface")

dock.searchOpen = false
assert(dock:RefreshTransientMessageLayout(), "search close did not refresh the message lane")
assert(not dock.searchDrawer:IsShown() and dock.display:IsShown()
	and point(dock.display, "TOPLEFT")[5] == -4,
	"closing search must restore the exact normal chat inset")
dock.header:Hide()
assert(dock:RefreshTransientMessageLayout(), "hidden title fallback did not refresh")
assert(dock.searchContentTrigger:IsShown() and point(dock.display, "TOPLEFT")[5] == -26,
	"headerless FIND target must reserve a real top strip instead of covering messages")
dock.searchOpen = true
assert(dock:RefreshTransientMessageLayout(), "headerless search could not open")
assert(dock.searchDrawer:IsShown() and not dock.searchContentTrigger:IsShown(),
	"headerless FIND target overlapped the open search drawer")
dock.alertBar = widget(300, 40, true)
dock.alertActive = true
assert(dock:RefreshTransientMessageLayout(), "alert/search compact state could not reflow")
assert(not dock.searchDrawer:IsShown() and dock.searchContentTrigger:IsShown(),
	"search must defer under a minimum-size alert while leaving a close target")
assert(point(dock.searchContentTrigger, "TOPLEFT")[5] == -44,
	"hidden-title FIND/close target crossed the alert surface instead of moving below it")
dock.alertActive = false
dock.alertBar:Hide()
assert(dock:RefreshTransientMessageLayout() and dock.searchDrawer:IsShown(),
	"dismissed alert did not restore the deferred search drawer")

-- Model the rendering controls, then prove filters and bounded cursor paging
-- without using any in-game state or mutating the active chat view.
dock.searchTitle = widget()
dock.searchFilterButton = widget()
dock.searchBackButton = widget()
dock.searchOlderButton = widget()
dock.searchNewerButton = widget()
dock.searchQueryRow = widget()
dock.searchFilterRows = widget()
dock.searchResultButton = widget()
dock.searchResultButtons = { dock.searchResultButton, widget(), widget(), widget() }
dock.searchPreview = widget()
dock.searchPreviewMeta = widget()
dock.searchTabOnlyButton = widget()
dock.searchTextEdit = widget(); dock.searchTextEdit.text = "keystone"
dock.searchSenderEdit = widget(); dock.searchSenderEdit.text = "mira"
dock.searchSourceEdit = widget(); dock.searchSourceEdit.text = "trade"
dock.searchDateEdit = widget(); dock.searchDateEdit.text = "2026-09-25"
dock.activeView = "general"
dock.searchCurrentTabOnly = true
local records = {}
for index = 1, 21 do
	records[index] = {
		id = index, timestamp = "12:34", sourceLabel = "Trade", sender = "Mira",
		text = "Keystone invitation " .. index, view = "trade",
	}
end
local lastQuery
addon.MessageEngine = {
	SearchHistory = function(_, query)
		lastQuery = query
		local first = query.cursor and query.cursor.next or 1
		local page = {}
		for index = first, math.min(#records, first + query.limit - 1) do
			page[#page + 1] = records[index]
		end
		local nextIndex = first + #page
		return { records = page, hasMore = nextIndex <= #records,
			nextCursor = nextIndex <= #records and { next = nextIndex } or nil }
	end,
}
assert(dock:RunSearch() and lastQuery.text == "keystone"
	and lastQuery.sender == "mira" and lastQuery.source == "trade"
	and lastQuery.date == "2026-09-25" and lastQuery.viewId == "general"
	and lastQuery.limit == 20,
	"search did not pass the complete bounded filter set to retained history")
assert(dock.searchResultButton.text:find("Keystone invitation 1", 1, true)
	and dock.activeView == "general",
	"search should present results without changing the active chat tab")
dock.searchDrawer.height = 132
dock:RefreshSearchDrawer()
assert(dock.searchResultButtons[4]:IsShown()
	and dock.searchResultButtons[4].text:find("Keystone invitation 4", 1, true),
	"tall search drawer left blank space instead of exposing a bounded result list")
dock.searchDrawer.height = 70
dock:RefreshSearchDrawer()
assert(not dock.searchResultButtons[2]:IsShown() and not dock.searchResultButtons[4]:IsShown(),
	"minimum-height drawer left result controls outside its bottom border")
for _ = 1, 20 do assert(dock:StepSearchResult(1), "older result was unavailable") end
assert(dock.searchResult.records[1] == records[21] and dock.searchResultIndex == 1
	and #dock.searchPageStack == 1,
	"older paging lost the bounded backend cursor or earlier page")
assert(dock:StepSearchResult(-1) and dock.searchResultIndex == 20
	and dock.searchResult.records[20] == records[20],
	"newer paging did not restore the previous result page")
dock.searchSelectedRecord = dock.searchResult.records[dock.searchResultIndex]
dock:RefreshSearchDrawer()
assert(dock.searchPreview:IsShown() and dock.searchPreviewMeta.text == "Preview only · chat tab unchanged"
	and dock.searchPreview.messages[1]:find("12:34  Trade · Mira", 1, true)
	and dock.searchPreview.messages[1]:find("Keystone invitation 20", 1, true),
	"selected result did not expose full text, source/time, and honest preview behavior")
assert(dock.activeView == "general", "preview changed the normal chat tab")

addon.MessageEngine.byId = {}
for _, record in ipairs(records) do addon.MessageEngine.byId[record.id] = record end
addon.MessageEngine.historyGeneration = 1
dock.searchGeneration = 1
addon.MessageEngine.byId[dock.searchSelectedRecord.id] = nil
addon.MessageEngine.SearchHistory = function()
	return { records = { records[1] }, hasMore = false }
end
assert(dock:RefreshSearchAfterHistoryMutation() and dock.searchSelectedRecord == nil
	and dock.searchResult.records[1] == records[1],
	"removed or blocked history remained visible in a retained search preview")

-- Wide-font labels may consume more than their nominal 37px slot. The live
-- layout measures the actual font and moves the query field while retaining
-- room for the GO target at the 300px minimum content width.
dock.searchQueryLabel = widget()
dock.searchQueryLabel.GetStringWidth = function() return 64 end
dock.searchQueryRow = widget(284, 20)
dock.searchTextEdit = widget(100, 20)
dock.searchGoButton = widget(32, 20)
dock:RefreshSearchDrawerLayout(4, 70)
assert(point(dock.searchTextEdit, "LEFT")[4] == 71
	and point(dock.searchTextEdit, "RIGHT")[4] == -4,
	"wide-font fallback lets the TEXT label collide with the input or GO button")

-- All selectable search states have a four-pixel border gutter in the 70px
-- drawer. A hidden title never strands the user: if an alert defers the drawer,
-- the same FIND control becomes its close path below that notice.
local source = assert(io.open("Core/SmartDock.lua", "rb"))
local layout = source:read("*a")
source:close()
assert(layout:find('resultButton:SetPoint("TOPLEFT", drawer, "TOPLEFT", 4, -49)', 1, true)
	and layout:find('resultButton:SetPoint("TOPRIGHT", drawer, "TOPRIGHT", -4, -49)', 1, true)
	and layout:find('filterRows:SetPoint("TOPLEFT", drawer, "TOPLEFT", 4, -25)', 1, true)
	and layout:find('dateEdit:SetPoint("TOPLEFT", filterRows, "TOPLEFT", 37, -23)', 1, true),
	"compact search result/filter anchors were changed without reviewing minimum bounds")
assert(49 + 18 <= 70 - 3 and 25 + 23 + 19 <= 70 - 3,
	"result or date filter would cross the minimum drawer's bottom border")

print("SmartDock retained-history search drawer mock passed")
