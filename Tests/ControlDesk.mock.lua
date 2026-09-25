-- Focused no-client contract for Chatty's Simple control desk. The established
-- Message Views mock supplies the existing Theme and WoW frame stand-ins.
dofile("Tests/MessageViewsConfig.mock.lua")

local addon = ChattyChattyBangBang
local config = addon.CustomConfig
local settings = addon:GetSmartSettings()
settings.enabled = true
settings.dock.hideNativeChat = true
settings.dock.newMessages = { enabled = true }
settings.dock.messageBands = { enabled = false }
settings.dock.responsiveMetadata = true
settings.semanticRoutes = { trade = true, groupFinder = true, pvp = true }
settings.spam = {
	enabled = true,
	repeatAds = { enabled = true },
	duplicate = { enabled = true },
	burst = { enabled = true },
	scopes = { whisper = false },
}
settings.alerts = { enabled = true, popout = true, sound = false }
settings.safety = { confirmServerIgnore = true }
settings.whisperGuard = { enabled = true }
local guardCommand
addon.WhisperGuard = {
	GetStatus = function() return { enabled = settings.whisperGuard.enabled, entries = 1, filterActive = true } end,
	GetSummaries = function() return { { sender = "Stranger-Realm", count = 1, lastId = 7 } } end,
	SetProtectionEnabled = function(_, value) settings.whisperGuard.enabled = value return true end,
	HandleCommand = function(_, command) guardCommand = command return true end,
}

function addon:SetSmartChatEnabled(value) settings.enabled = value return true end
function addon:SetSemanticRouteEnabled(route, value)
	settings.semanticRoutes[route] = value
	return true
end
function addon:SetResponsiveMetadata(value) settings.dock.responsiveMetadata = value return true end
function addon:SetNewMessageIndicatorEnabled(value) settings.dock.newMessages.enabled = value return true end
function addon:SetSmartChatMessageBandsEnabled(value) settings.dock.messageBands.enabled = value return true end
addon.ChatRecovery = {
	GetStatus = function() return { recovered = 2, pending = 1, unresolved = 3, fallbackFailed = 0 } end,
}
local setupCompleted = false
function addon:IsConfigSetupCompleted() return setupCompleted end
function addon:SetConfigSetupCompleted(value) setupCompleted = value; return true, value end

assert(config:SetMode("simple") and config.activePage == "desk",
	"Simple mode did not open the control desk")
assert(config.navigationButtons.desk:IsShown() and not config.navigationButtons.spam:IsShown(),
	"Simple navigation did not hide detailed pages")
assert(config.modeButton.text:GetText() == "ADVANCED SETTINGS",
	"the complete editor is not discoverable from Simple mode")
assert(config.deskPreviewFirst:GetText():find("%[G%]", 1),
	"the desk lost its transcript-style preview")
assert(config.deskNote:GetText():find("2 restored / 1 waiting / 3 unresolved", 1, true)
	and config.deskNote:GetText():find("Blizzard chat briefly appears", 1, true)
	and config.deskNote:GetText():find("cannot be restored", 1, true),
	"native catch-up status or no-guarantee caveat was not visible on Start Here")
local lastRow = config.deskRows[4]
assert(lastRow.point[5] == -372 and lastRow.height == 64
	and lastRow.toggle.point[5] <= -8 and lastRow.does.point[5] <= -32
	and lastRow.notices.point[5] <= -47
	and (-lastRow.point[5] + lastRow.height) <= 450,
	"Simple rows cross the reserved footer or fail their reviewed 8px-gutter bounds")

config:ShowPage("deskTabs")
assert(config.deskTask == "deskTabs" and config.deskRows[1].option,
	"the Choose Tabs task did not load built-in tabs")
local firstTab = config.deskRows[1]
local firstId = addon:GetSmartViews()[1].id
firstTab.toggle:SetValue(false)
assert(settings.views[firstId] == false,
	"a Simple tab switch did not update the existing view setting")

config:ShowPage("deskSpam")
assert(config.deskRows[2].toggle.checked == true,
	"the repeat-sale-ad protection was not presented as enabled")
config.deskRows[2].toggle:SetValue(false)
assert(settings.spam.repeatAds.enabled == false,
	"the Simple repeat-sale-ad switch did not update its existing setting")
assert(config.deskPreviewFirst:GetText():find("Sale-ad rule is off", 1, true),
	"disabling sale-ad control did not update its independent preview")
assert(config.deskPreviewSecond:GetText():find("duplicate rule", 1, true),
	"duplicate protection was incorrectly tied to sale-ad protection")
assert(config.deskReviewButton:IsShown() and config.deskReviewButton.text:GetText() == "REVIEW BLOCKED",
	"Simple spam review did not offer the unified blocked archive")

config:ShowPage("deskPrivate")
assert(config.deskRows[1].toggle.checked == true and config.deskPreviewFirst:GetText():find("1 held", 1, true),
	"default-on stranger protection or held count was not presented")
config.deskRows[1].toggle:SetValue(false)
assert(settings.whisperGuard.enabled == false
	and config.deskPreviewFirst:GetText():find("protection is off", 1, true),
	"Simple stranger protection did not use the guard setter or update its preview")
config.deskRows[1].toggle:SetValue(true)
assert(config.deskRows[4].toggle.checked == false,
	"the default whisper spam scope was misrepresented as protected")
config.deskRows[4].toggle:SetValue(true)
assert(settings.spam.scopes.whisper == true
	and config.deskRows[4].toggle.checked == true,
	"whisper-scope change did not update the Simple control")

config.deskRows[2].toggle:SetValue(false)
assert(settings.conversations.autoOpenWhispers == false
	and config.deskPreviewSecond:GetText():find("without a popup", 1, true),
	"private-message popup setting did not update the preview")
assert(config.deskReviewButton:IsShown()
	and config.deskReviewButton.text:GetText() == "REVIEW HELD WHISPERS",
	"Simple private review action was not clearly labeled")
config.deskReviewButton.scripts.OnClick(config.deskReviewButton)
assert(config.activePage == "messenger" and config.messengerSection == "safety"
	and config.messengerWhisperGuardToggle.checked == true,
	"held-whisper review was not reachable in Advanced Messenger")
local sectionTabsWidth = 30
for _, id in ipairs({ "opening", "tabs", "visibility", "actions", "appearance", "safety" }) do
	sectionTabsWidth = sectionTabsWidth + config.messengerSectionButtons[id].width
end
assert(sectionTabsWidth <= 636 and config.messengerSectionButtons.safety.point[4] == 6,
	"Whisper Safety tab overflowed Messenger's smallest panel bounds")
assert(config.messengerHeldRows[1].point[4] == 8 and config.messengerHeldRows[4].point[5] == -365,
	"held-whisper review rows escaped the section gutters")
config.messengerHeldRows[1].scripts.OnClick(config.messengerHeldRows[1])
assert(guardCommand == "show 7", "held-whisper review did not use the private modal path")

local savedMode = "simple"
function addon:GetConfigMode() return savedMode end
function addon:SetConfigMode(mode) savedMode = mode; return true, mode end
assert(config:SetMode("advanced") and config.navigationButtons.spam:IsShown()
	and not config.navigationButtons.desk:IsShown() and savedMode == "advanced",
	"Advanced mode did not restore the complete existing navigation")
for _, id in ipairs({ "home", "dock", "views", "messenger", "safety", "spam", "blocks",
	"semantic", "routeAudit", "alerts", "colorways", "keywords", "modules", "integrations", "about" }) do
	assert(config.navigationButtons[id]:IsShown(), "Advanced page was lost: " .. id)
end
config:ShowPage("spam")
assert(config.activePage == "spam" and settings.spam.scopes.whisper == true,
	"Advanced settings were inaccessible or a Simple choice was lost")
assert(config:SetMode("simple") and settings.spam.scopes.whisper == true and savedMode == "simple",
	"returning to Simple reset an advanced setting")
config:ShowPage("deskLook")
assert(config.deskNext.text:GetText() == "FINISH SETUP",
	"new-install setup did not offer a Finish action")
config.deskNext.scripts.OnClick(config.deskNext)
assert(setupCompleted and config.deskTask == "desk",
	"Finish did not mark guided setup complete and return to Start Here")

-- The General channel's checked full-feed box means explicit MIRROR ALL now.
-- AUTO TOPICS is visually unchecked even though ordinary General lines remain.
config:ShowPage("views")
config.selectedRailId = "general"
local generalOverride
function addon:GetViewSourceDefinitions(viewId)
	return {
		{ id = "channel:general", label = "General", sourceGroup = "channels",
			defaultEnabled = viewId == "general", override = generalOverride,
			enabled = generalOverride ~= false },
		{ id = "channel:trade", label = "Trade", sourceGroup = "channels",
			defaultEnabled = false, enabled = false },
	}
end
function addon:SetViewSourceEnabled(viewId, sourceId, value)
	assert(viewId == "general" and sourceId == "channel:general")
	generalOverride = value
	return true
end
config:RefreshRailSources()
local generalRow
local tradeRow
for _, row in ipairs(config.railSourceRows) do
	if row.sourceId == "channel:general" then generalRow = row break end
end
for _, row in ipairs(config.railSourceRows) do
	if row.sourceId == "channel:trade" then tradeRow = row break end
end
assert(generalRow and generalRow.label:GetText():find("AUTO TOPICS", 1, true)
	and generalRow.checked == false,
	"implicit topic-aware General feed was presented as MIRROR ALL")
assert(tradeRow and tradeRow.label:GetText():find("AUTO HOME", 1, true)
	and tradeRow.checked == false,
	"Trade's own default feed was falsely presented as ordinary General content")
assert(config:SetRailSourceEnabled("channel:general", true, "General") and generalOverride == true
	and generalRow.label:GetText():find("MIRROR ALL", 1, true) and generalRow.checked,
	"explicit full General mirror was not shown as the checked override")
assert(config:SetRailSourceEnabled("channel:general", false, "General") and generalOverride == nil
	and generalRow.label:GetText():find("AUTO TOPICS", 1, true) and not generalRow.checked,
	"clearing MIRROR ALL did not restore topic-aware AUTO")

local function textField()
	return { SetText = function(self, value) self.value = value end }
end
config.blockedArchiveDetailTitle = textField()
config.blockedArchiveDetailMeta = textField()
config.blockedArchiveDetailText = textField()
config.blockedArchiveDetailRule = textField()
config.blockedArchiveDetailTiming = textField()
config:RefreshBlockedArchiveDetail({ { id = "spam-1", sender = "Seller", text = "WTS item",
	reason = "spam", ruleName = "Spam Firewall: Reposted advertisement" } })
assert(config.blockedArchiveDetailRule.value:find("SPAM FIREWALL", 1, true),
	"automatic spam drops still appeared as a manual Block Rule")

print("Control desk mock passed")
