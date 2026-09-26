-- Alert inbox UI privacy and retained-record refresh. Run: lua Tests/SmartDockAlertInbox.mock.lua

local private = {
	id = 7, timestamp = "12:34", sourceLabel = "Whisper", sender = "Friend",
	text = "private ping body", alerts = { alert1 = true },
}
local engine = { byId = { [7] = private }, historyGeneration = 1 }
function engine:SearchHistory() error("alert inbox used normal text search") end
local inbox = {}
function inbox:GetInboxRecords()
	return engine.byId[7] == private and not private.blockedByBlockControl
		and { private } or {}
end
function inbox:IsInboxRecord(record)
	return record == private and engine.byId[7] == private
		and not private.blockedByBlockControl
end
ChattyChattyBangBang = {
	Theme = {}, Presentation = {}, MessageEngine = engine, AlertEngine = inbox,
}
dofile("Core/SmartDock.lua")
local dock = ChattyChattyBangBang.SmartDock
local function widget()
	local value = { shown = false }
	function value:ClearAllPoints() end
	function value:SetPoint() end
	function value:SetText(text) self.text = text end
	function value:SetLabel(text) self.text = text end
	function value:Show() self.shown = true end
	function value:Hide() self.shown = false end
	function value:GetHeight() return 70 end
	function value:Clear() self.message = nil end
	function value:AddMessage(text) self.message = text end
	function value:ScrollToTop() end
	return value
end
dock.searchOpen = true
dock.searchAlertMode = true
dock.searchDrawer = widget()
dock.searchTitle = widget()
dock.searchBackButton = widget()
dock.searchCloseButton = widget()
dock.searchQueryRow = widget()
dock.searchQueryLabel = widget()
dock.searchTextEdit = widget()
dock.searchGoButton = widget()
dock.searchExportButton = widget()
dock.searchAlertButton = widget()
dock.searchResultButton = widget()
dock.searchResultButtons = { dock.searchResultButton }
dock.searchPreview = widget()
dock.searchPreviewMeta = widget()

assert(dock:RunSearch() and dock.searchResult.records[1] == private,
	"inbox did not use the retained alert IDs")
assert(not dock.searchResultButton.text:find("private ping body", 1, true)
	and dock.searchResultButton.text:find("alert match", 1, true),
	"inbox list leaked private message text")
assert(not dock.searchExportButton.shown and dock.searchAlertButton.shown,
	"inbox did not hide bulk export or provide a return to FIND")
dock.searchSelectedRecord = private
dock:RefreshSearchDrawer()
assert(dock.searchPreview.shown and dock.searchPreview.message:find("private ping body", 1, true),
	"deliberate selection did not review the retained message")
assert(dock:CopySelectedSearchMessage() == false and dock:ExportSearchResultPage() == false,
	"inbox exposed a private-message copy path")
engine.byId[7] = nil
assert(dock:RefreshAlertInbox() and dock.searchSelectedRecord == nil
	and #dock.searchResult.records == 0 and not dock.searchPreview.shown,
	"evicted alert remained in the review surface")

print("SmartDock alert inbox mock passed")
