-- Messenger's 200-line viewport must page through the engine's larger history.
-- Run from the addon root: lua Tests/ConversationHistoryPaging.mock.lua
dofile("Tests/ConversationWindowsLayout.mock.lua")

local addon = ChattyChattyBangBang
local manager = addon.ConversationWindows
local engine = addon.MessageEngine
local settings = addon:GetSmartSettings()
local function expect(value, message)
	if not value then error(message, 2) end
end

manager:ResetForProfile()
manager:SetEnabled(true)
settings.conversations.autoOpenWhispers = false
settings.conversations.deferInCombat = false
engine.messages = {}
for index = 1, 425 do
	engine.messages[#engine.messages + 1] = {
		id = index, event = "CHAT_MSG_WHISPER", sender = "Archive",
		direction = "incoming", text = "history " .. index,
	}
end
local archive = manager:AcquireSession("Archive")
local other = manager:AcquireSession("Other")
manager:SelectSession(archive.playerKey)
local shell = manager:GetShell()
shell:Show()
local display = shell.display
display.visibleLineCapacity = 4
display.scrollMaximum = 240 -- wrapped lines extend beyond the 200 records
shell:RenderSession(archive)
expect(archive.historyPage == 1 and archive.historyPageCount == 3
	and archive.renderedCount == 200 and archive.renderedIds[425]
	and not archive.renderedIds[225] and shell.historyPrevious:IsShown()
	and shell.historyLabel:GetText() == "1/3",
	"newest archive page or concise pager label is wrong")

shell.frame:SetSize(300, 160)
shell:ApplyChromeLayout(true)
local top = display.points[1]
local right = display.points[2]
local pagerPoint = shell.historyPrevious.points[1]
local railPoint = shell.messageScrollbar.points[1]
expect(top and top[1] == "TOPLEFT" and top[4] == 4 and top[5] == -26
	and right and right[4] == -26 and railPoint and railPoint[5] == -26
	and pagerPoint and pagerPoint[4] == 4 and pagerPoint[5] == -3
	and shell.historyPrevious.labelValue == "OLDER"
	and shell.historyNext.labelValue == "NEWER"
	and shell.historyNext:GetWidth() >= 42 and shell.newButton.labelValue == "LATEST",
	"minimum Messenger did not reserve a border gutter, pager row, and scroll lane")

display.currentScroll = 33
shell.historyPrevious.scripts.OnClick()
expect(archive.historyPage == 2 and archive.renderedCount == 200
	and archive.renderedIds[26] and archive.renderedIds[225]
	and not archive.renderedIds[226] and shell.historyLabel:GetText() == "2/3",
	"older page did not reveal the next 200 distinct records")
display.currentScroll = 73
shell.historyPrevious.scripts.OnClick()
expect(archive.historyPage == 3 and archive.renderedCount == 25
	and archive.renderedIds[1] and archive.renderedIds[25]
	and not archive.renderedIds[26] and shell.historyLabel:GetText() == "3/3",
	"oldest partial page was lost")
expect(not shell:ChangeHistoryPage(1), "oldest-page control stepped beyond the archive")

shell.historyNext.scripts.OnClick()
expect(archive.historyPage == 2 and display.currentScroll == 73,
	"returning to page two lost its wrapped-line reading offset")
shell.historyNext.scripts.OnClick()
expect(archive.historyPage == 1 and display.currentScroll == 33,
	"returning to newest page lost its reading offset")

shell.historyPrevious.scripts.OnClick()
display.currentScroll = 61
shell.editBox:SetText("unsent archive draft")
shell.editBox.scripts.OnTextChanged(shell.editBox)
local incomingOther = { id = 426, event = "CHAT_MSG_WHISPER", sender = "Other",
	direction = "incoming", text = "unread elsewhere" }
engine.messages[#engine.messages + 1] = incomingOther
manager:OnMessage(incomingOther)
expect(other.unread == 1, "other tab did not register an unread whisper")
manager:SelectSession(other.playerKey)
manager:SelectSession(archive.playerKey)
expect(archive.historyPage == 2 and display.currentScroll == 61
	and shell.editBox:GetText() == "unsent archive draft" and other.unread == 0,
	"tab switch lost archive page, reading offset, or draft")

local newArchive = { id = 427, event = "CHAT_MSG_WHISPER", sender = "Archive",
	direction = "incoming", text = "new archive line" }
engine.messages[#engine.messages + 1] = newArchive
local before = display:GetNumMessages()
manager:OnMessage(newArchive)
expect(archive.historyPage == 2 and display:GetNumMessages() == before
	and display.currentScroll == 61 and archive.pendingVisible == 1
	and shell.newButton:IsShown(),
	"new whisper replaced an older page, moved the reader, or lost NEW")
settings.conversations.actionStripOrientation = "vertical"
settings.conversations.actionVisibility = "always"
settings.conversations.actionStripCollapsed = false
shell:ApplyChromeLayout(true)
local sideInset = (shell.actionWidth or 0) + 3
local contentWidth = 300 - 4 - sideInset
local pagerRight = 4 + 20 + 4 + 40 + 4 + 20
local newLeft = contentWidth - 20 - shell.newButton:GetWidth()
expect(shell.content.points[2][4] == -2 - sideInset and newLeft - pagerRight >= 8,
	"minimum vertical-action layout overlaps pager and NEW or escapes its content gutter")
display.currentScroll = 0
display.scripts.OnMouseWheel(display, -1)
shell.messageScrollbar:SetValue(shell.messageScrollbar.maximum or 0)
expect(archive.pendingVisible == 1 and shell.newButton:IsShown(),
	"bottom of an older page incorrectly cleared NEW")
shell.historyNext.scripts.OnClick()
expect(archive.historyPage == 1 and archive.renderedIds[425]
	and archive.renderedIds[226] and not archive.renderedIds[427]
	and archive.pendingVisible == 1 and shell.newButton:IsShown(),
	"new arrival shifted snapshot boundaries and skipped a line between pages")
local secondArchive = { id = 428, event = "CHAT_MSG_WHISPER", sender = "Archive",
	direction = "incoming", text = "another new line" }
engine.messages[#engine.messages + 1] = secondArchive
manager:OnMessage(secondArchive)
expect(archive.pendingVisible == 2 and archive.renderedIds[226]
	and not archive.renderedIds[428] and display:GetNumMessages() == 200,
	"live arrival broke the frozen page boundary before NEW was clicked")
display.currentScroll = 0
display.scripts.OnMouseWheel(display, -1)
shell.messageScrollbar:SetValue(shell.messageScrollbar.maximum or 0)
expect(archive.pendingVisible == 2 and shell.newButton:IsShown(),
	"bottom of the snapshot's newest page incorrectly cleared NEW")
shell.newButton.scripts.OnClick()
expect(archive.historyPage == 1 and archive.pendingVisible == 0
	and archive.renderedIds[427] and archive.renderedIds[428]
	and shell.newButton:IsShown() and shell.newButton.labelValue == "LATEST"
	and display.currentScroll == 0,
	"NEW did not jump to the latest page and clear its marker")

shell.historyPrevious.scripts.OnClick()
display.currentScroll = 61
shell:Hide()
shell:Show()
expect(archive.historyPage == 2 and display.currentScroll == 61,
	"closing and reopening Messenger lost its per-session older-page position")

engine.messages = {}
display.scrollMaximum = 0
manager:RefreshAfterHistoryMutation(true)
expect(archive.historyPage == 1 and archive.historyPageCount == 1
	and not shell.historyPrevious:IsShown() and display.points[1][5] == -4
	and archive.pendingVisible == 0,
	"Clear History left a stale archive page, pager gutter, or NEW marker")

for index = 1, 205 do
	engine.messages[#engine.messages + 1] = {
		id = 500 + index, event = "CHAT_MSG_BN_WHISPER", isBNet = true,
		bnetAccountId = "517", sender = "SharedName", direction = "incoming",
		text = "BNet history " .. index,
	}
end
engine.messages[#engine.messages + 1] = {
	id = 999, event = "CHAT_MSG_BN_WHISPER", isBNet = true,
	bnetAccountId = "518", sender = "SharedName", direction = "incoming",
	text = "different account",
}
local bnet = manager:AcquireSession("SharedName", 517)
manager:SelectSession(bnet.playerKey)
expect(bnet.historyPageCount == 2 and bnet.renderedCount == 200
	and not bnet.renderedIds[999],
	"Battle.net paging merged same-name account histories")
shell.historyPrevious.scripts.OnClick()
expect(bnet.historyPage == 2 and bnet.renderedCount == 5
	and bnet.renderedIds[501] and not bnet.renderedIds[999],
	"Battle.net oldest page did not retain its account-only records")

-- A 450-line source cap evicts well before the next 200-line boundary. Live
-- counts must follow retained records, not grow to a phantom fourth page.
manager:ResetForProfile()
manager:SetEnabled(true)
engine.messages = {}
for index = 1, 450 do
	engine.messages[index] = {
		id = 1000 + index, event = "CHAT_MSG_WHISPER", sender = "Capacity",
		direction = "incoming", text = "capacity " .. index,
	}
end
local capacity = manager:AcquireSession("Capacity")
manager:SelectSession(capacity.playerKey)
shell = manager:GetShell()
display = shell.display
shell:Show()
expect(capacity.historyTotal == 450 and capacity.historyPageCount == 3,
	"450-line fixture did not initialize three retained pages")
for index = 451, 580 do
	table.remove(engine.messages, 1)
	local record = {
		id = 1000 + index, event = "CHAT_MSG_WHISPER", sender = "Capacity",
		direction = "incoming", text = "capacity " .. index,
	}
	engine.messages[#engine.messages + 1] = record
	manager:OnMessage(record)
	expect(capacity.historyTotal == 450 and capacity.historyPageCount == 3,
		"450-line rollover drifted the retained history count or page count")
end
shell:ChangeHistoryPage(1)
shell:ChangeHistoryPage(1)
expect(capacity.historyPage == 3 and capacity.renderedCount == 50
	and capacity.renderedIds[1131] and capacity.renderedIds[1180]
	and not capacity.renderedIds[1130] and not capacity.renderedIds[1181],
	"oldest page did not match the 450 actually retained records")
display.currentScroll = 17
local second = manager:AcquireSession("Second")
manager:SelectSession(second.playerKey)
expect(capacity.pageOffsets[3] == 17,
	"tab switch failed to save the previous page offset before rendering another session")

print("ConversationHistoryPaging.mock.lua: PASS")
