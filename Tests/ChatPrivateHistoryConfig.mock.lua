-- Private-history settings must be understandable and require confirmation.
-- Run from addon root: lua Tests/ChatPrivateHistoryConfig.mock.lua
dofile("Tests/NewMessageIndicatorConfig.mock.lua")

local addon = ChattyChattyBangBang
local config = addon.CustomConfig
local privacy = { saveWhispers = true, saveBattleNet = true }
local saved = { whispers = 4, battleNet = 2 }
local clears = {}
function addon:GetChatHistoryPrivacySettings() return privacy end
function addon:SetChatHistoryPrivateSaveEnabled(kind, enabled)
	privacy[kind == "whispers" and "saveWhispers" or "saveBattleNet"] = enabled
	return true, enabled
end
function addon:ClearSavedPrivateChatHistory(kind)
	clears[#clears + 1] = kind
	local count = saved[kind]
	saved[kind] = 0
	return true, count
end
addon.MessageEngine = {
	GetSavedPrivateHistoryStats = function() return saved end,
	GetHistoryStats = function() return { lines = 6, sources = 2 } end,
	GetSourceDefinitions = function() return {} end,
}

config:SetDockSection("layout")
config:SetDockLayoutCategory("input")
config:RefreshDockPage()
local source = config.dockHistorySourcesButton
local private = config.dockHistoryPrivateButton
local clear = config.dockClearHistoryButton
assert(source:IsShown() and private:IsShown() and clear:IsShown(),
	"private-history navigation is missing from Chat Window > Input")
assert(source.point[4] + source.width + 8 <= private.point[4]
	and private.point[4] + private.width + 8 <= clear.point[4]
	and clear.point[4] + clear.width + 8 <= 644,
	"main history buttons overlap or lose their visible gutters")

private.scripts.OnClick(private)
assert(config.dockHistoryPrivatePageOpen and not config.dockHistoryToggle:IsShown()
	and config.dockHistorySaveWhispersToggle:IsShown()
	and config.dockHistorySaveBattleNetToggle:IsShown()
	and not config.dockHistorySourceRows[1].edit:IsShown(),
	"private-history inspector did not disclose independently")
assert(config.dockHistoryPrivateSummary:GetText():find("4 whispers", 1, true)
	and config.dockHistoryPrivateSummary:GetText():find("2 Battle.net", 1, true),
	"inspector did not show saved-private counts")
assert(config.dockHistorySaveWhispersToggle.value
	and config.dockHistorySaveBattleNetToggle.value,
	"existing profiles did not default to saving private history")

config.dockHistorySaveWhispersToggle:SetValue(false)
assert(privacy.saveWhispers == false and privacy.saveBattleNet == true
	and #clears == 0 and saved.whispers == 4,
	"future-save opt-out erased old saved private history")
local whisperButton = config.dockHistoryPrivateClearButtons.whispers
local bnetButton = config.dockHistoryPrivateClearButtons.battleNet
assert(whisperButton.point[4] + whisperButton.width + 8 <= bnetButton.point[4]
	and bnetButton.point[4] + bnetButton.width + 8 <= 644,
	"private clear buttons overlap or cross the panel gutter")
assert(-bnetButton.point[5] + bnetButton.height + 12 < -config.dockHistoryPrivateSummary.point[5]
	and -config.dockHistoryPrivateSummary.point[5] + config.dockHistoryPrivateSummary.height
		+ 12 < -config.dockStatus.point[5],
	"private clear buttons, summary, or status line overlap")
whisperButton.scripts.OnClick(whisperButton)
assert(#clears == 0 and saved.whispers == 4 and whisperButton.confirming,
	"first clear click acted without confirmation")
whisperButton.scripts.OnClick(whisperButton)
assert(#clears == 1 and clears[1] == "whispers" and saved.whispers == 0
	and saved.battleNet == 2 and not whisperButton.confirming,
	"confirmed whisper clear was not scoped")
bnetButton.scripts.OnClick(bnetButton)
bnetButton.scripts.OnClick(bnetButton)
assert(#clears == 2 and clears[2] == "battleNet" and saved.battleNet == 0,
	"confirmed Battle.net clear failed")

local back = config.dockHistoryPrivateControls[2]
back.scripts.OnClick(back)
assert(not config.dockHistoryPrivatePageOpen and config.dockHistoryToggle:IsShown()
	and not config.dockHistorySaveWhispersToggle:IsShown(),
	"Back did not restore Input controls cleanly")
print("Private chat history config mock passed")
