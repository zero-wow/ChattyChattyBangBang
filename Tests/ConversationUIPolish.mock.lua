-- Messenger control clarity and smallest-shell bounds across chrome states.
-- Run from the addon root: lua Tests/ConversationUIPolish.mock.lua
dofile("Tests/ConversationWindowsLayout.mock.lua")

local addon = ChattyChattyBangBang
local manager = addon.ConversationWindows
local engine = addon.MessageEngine
local settings = addon:GetSmartSettings().conversations
local function expect(value, message)
	if not value then error(message, 2) end
end

manager:ResetForProfile()
manager:SetEnabled(true)
settings.autoOpenWhispers = false
settings.deferInCombat = false
engine.messages = {}
for index = 1, 205 do
	engine.messages[index] = { id = index, event = "CHAT_MSG_WHISPER",
		sender = "Polish", direction = "incoming", text = "line " .. index }
end
local session = manager:AcquireSession("Polish")
local shell = manager:SelectSession(session.playerKey)
shell:Show()
shell.frame:SetSize(300, 160)
shell.tabStrip:SetWidth(296)

local function checkPagerBounds(label)
	local state = shell.visibilityState
	local sideInset = state.actions and not state.actionsCollapsed
		and state.actionOrientation == "vertical" and ((shell.actionWidth or 0) + 3) or 0
	local contentWidth = 300 - 4 - sideInset
	local leftEdge = 4 + shell.historyPrevious:GetWidth() + 4
		+ shell.historyLabel:GetWidth() + 4 + shell.historyNext:GetWidth()
	local latestLeft = contentWidth - 28 - shell.newButton:GetWidth()
	local displayTop, displayRight = shell.display.points[1], shell.display.points[2]
	local scrollbarTop, scrollbarBottom = shell.messageScrollbar.points[1], shell.messageScrollbar.points[2]
	local bottomPoint = shell.scrollToBottomButton.points[1]
	expect(leftEdge + 6 <= latestLeft and shell.newButton:IsShown()
		and displayTop[5] == -26 and displayRight[4] == -26
		and scrollbarTop[5] == -26 and scrollbarBottom[5] == 26
		and bottomPoint[4] == -3 and bottomPoint[5] == 4
		and shell.scrollToBottomButton:GetWidth() == 16
		and shell.scrollToBottomButton:GetHeight() == 18
		and 26 - (3 + 16) >= 6,
		label .. ": pager, text, rail, and bottom hit target overlap at 300x160")
	expect(shell.tabAvailableWidth >= 40 and session.tab.labelMeasuredWidth <= session.tab.labelAvailableWidth,
		label .. ": tab label overlaps its action controls")
end

for _, titleMode in ipairs({ "always", "hidden" }) do
	for _, orientation in ipairs({ "horizontal", "vertical" }) do
		for _, collapsed in ipairs({ false, true }) do
			for _, composerMode in ipairs({ "always", "hidden" }) do
				settings.titleBarVisibility = titleMode
				settings.actionVisibility = "always"
				settings.actionStripOrientation = orientation
				settings.actionStripCollapsed = collapsed
				settings.composerVisibility = composerMode
				shell:ApplyChromeLayout(true)
				local label = titleMode .. "/" .. orientation .. "/"
					.. tostring(collapsed) .. "/" .. composerMode
				checkPagerBounds(label)
				expect(string.find(shell.actionToggle.labelValue, "ACT", 1, true)
					and shell.actionToggle.tooltipTitle == "Player actions",
					label .. ": action toggle lacks a visible label or help text")
			end
		end
	end
end
expect(shell.historyPrevious.labelValue == "OLDER" and shell.historyNext.labelValue == "NEWER"
	and shell.newButton.labelValue == "LATEST"
	and shell.historyPrevious.tooltipTitle == "Older whispers"
	and shell.historyNext.tooltipTitle == "Newer whispers",
	"normal-width history controls did not use clear labels")
expect(shell.scrollToBottomGlyph:GetText() == "↓"
	and shell.scrollToBottomButton._tooltipText == "Go to bottom (latest whisper)",
	"enlarged bottom control lacks its directional glyph or plain-language tooltip")

-- Wide live font metrics force compact history arrows without reducing their
-- hit targets below 26px or allowing the latest action to collide with them.
settings.actionStripCollapsed = false
settings.actionStripOrientation = "vertical"
settings.titleBarVisibility = "hidden"
settings.composerVisibility = "always"
shell.historyPrevious.text.glyphWidth = 12
shell.historyNext.text.glyphWidth = 12
shell.newButton.text.glyphWidth = 12
session.pendingVisible = 120
shell:UpdateNewButton()
shell:ApplyChromeLayout(true)
checkPagerBounds("wide-font/vertical-actions/NEW")
expect(shell.historyPrevious.labelValue == "<" and shell.historyPrevious:GetWidth() == 26
	and shell.historyNext.labelValue == ">" and shell.historyNext:GetWidth() == 26
	and shell.newButton.labelValue == "LATEST"
	and shell.newButton.tooltipBody == "120 new messages",
	"wide-font fallback did not keep compact arrows and an exact NEW tooltip")

shell.historyPrevious.text.glyphWidth = 6
shell.historyNext.text.glyphWidth = 6
shell.newButton.text.glyphWidth = 6
session.pendingVisible = 0
shell:UpdateNewButton()
shell:ApplyChromeLayout(true)
expect(shell.historyPrevious.labelValue == "OLDER" and shell.historyNext.labelValue == "NEWER",
	"roomy labels did not return after compact-font pressure ended")

-- The top control row must release its height when neither pages nor NEW
-- remain, and claim it again for a one-page incoming update.
engine.messages = { engine.messages[205] }
shell:RenderSession(session)
expect(session.historyPageCount == 1 and not shell.historyPrevious:IsShown()
	and not shell.newButton:IsShown() and shell.display.points[1][5] == -4,
	"single-page idle state retained an unnecessary control strip")
session.pendingVisible = 3
shell:UpdateNewButton()
expect(shell.newButton:IsShown() and shell.newButton.labelValue == "3 NEW"
	and shell.display.points[1][5] == -26,
	"one-page NEW control overlays message text instead of reserving a row")
session.pendingVisible = 0
shell:UpdateNewButton()
expect(not shell.newButton:IsShown() and shell.display.points[1][5] == -4,
	"one-page control strip did not release its reserved height")

engine.messages = {}
manager:RefreshAfterHistoryMutation(true)
for index = 1, 200 do
	engine.messages[index] = { id = 1000 + index, event = "CHAT_MSG_WHISPER",
		sender = "Polish", direction = "incoming", text = "threshold " .. index }
end
shell:RenderSession(session)
local nextRecord = { id = 1201, event = "CHAT_MSG_WHISPER", sender = "Polish",
	direction = "incoming", text = "threshold 201" }
engine.messages[201] = nextRecord
shell:AddRecord(nextRecord, true)
expect(session.historyPageCount == 2 and session.pendingVisible == 0
	and shell.newButton:IsShown() and shell.newButton.labelValue == "LATEST"
	and shell.display.points[1][5] == -26,
	"201st live line did not reveal Latest without requiring a pending NEW marker")

print("ConversationUIPolish.mock.lua: PASS")
