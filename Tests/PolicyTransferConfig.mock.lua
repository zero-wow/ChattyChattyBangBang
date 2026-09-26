-- Run from the addon root with: lua Tests/PolicyTransferConfig.mock.lua
-- Reuse the Spam page's complete lightweight frame and Theme host.
dofile("Tests/SpamConfigLayout.mock.lua")
dofile("Core/PolicyTransfer.lua")

local addon = ChattyChattyBangBang
local config = addon.CustomConfig
local settings = addon:GetSmartSettings()
local private = "PRIVATE-SENDER-AND-MESSAGE-46af"
settings.history = { { sender = private, message = private } }
settings.spam.repeatAds.seen = { [private] = { message = private } }
settings.spam.escalation.bans = { [private] = true }

config.spamFilterSubButtons.policy.scripts.OnClick()
assert(config.spamFilterMode == "policy" and config.spamFilterSubPanes.policy:IsShown()
	and not config.spamFilterSubPanes.ads:IsShown(),
	"POLICY did not replace other Spam Firewall subpanes")
local policyPane = config.spamFilterSubPanes.policy
assert(policyPane.width == 636 and policyPane.height == 300,
	"policy workspace exceeded the fixed Spam subpane")
assert(config.spamPolicyMode == "export" and config.spamPolicyExportPane:IsShown()
	and not config.spamPolicyImportPane:IsShown(),
	"POLICY did not open on export")
local export = config.spamPolicyExport
assert(export.parent == config.spamPolicyExportPane and export.width == 620
	and export.point[4] == 8 and export.point[5] == -25,
	"export copy surface lacks an eight-pixel gutter")
assert(export:GetText():find("CCBB-POLICY/1\n", 1, true)
	and not export:GetText():find(private, 1, true),
	"export UI omitted policy header or exposed private data")
function export:HighlightText() self.highlighted = true end
config.spamPolicySelectAll.scripts.OnClick()
assert(export.focused and export.highlighted, "export text cannot be selected for copying")

config.spamPolicyImportModeButton.scripts.OnClick()
assert(config.spamPolicyMode == "import" and config.spamPolicyImportPane:IsShown()
	and not config.spamPolicyExportPane:IsShown(),
	"IMPORT did not replace export")
local input = config.spamPolicyImport
assert(input.width == 620 and input.height == 65 and input.point[4] == 8,
	"import paste surface lacks a bounded eight-pixel gutter")
assert(config.spamPolicyApply.mouseEnabled == false,
	"Apply was clickable before preview")

local text = table.concat({
	"CCBB-POLICY/1",
	"spam.enabled=false",
	"spam.exemptSelf=false",
	"spam.duplicate.enabled=true",
	"spam.duplicate.window=10",
	"spam.burst.limit=8",
	"spam.scopes.channel=true",
	"",
}, "\n")
local previousEnabled = settings.spam.enabled
input:SetText(text)
input.scripts.OnTextChanged()
config.spamPolicyPreviewButton.scripts.OnClick()
assert(config.spamPolicyPreview and config.spamPolicyPreview.count == 6,
	"preview did not list the six changed policy fields")
assert(settings.spam.enabled == previousEnabled,
	"preview changed settings before explicit Apply")
assert(config.spamPolicyApply.mouseEnabled == true
	and config.spamPolicyPreviewCount:GetText():find("PAGE 1 OF 2", 1, true),
	"review pager or Apply activation is incorrect")
assert(config.spamPolicyRows[1]:GetText():find("spam.enabled", 1, true),
	"readable preview row is missing its field name")
config.spamPolicyNext.scripts.OnClick()
assert(config.spamPolicyPage == 2
	and config.spamPolicyRows[3]:GetText():find("spam.scopes.channel", 1, true),
	"preview paging hid later changed fields")
assert(config.spamPolicyRows[3].point[5] == -153
	and config.spamPolicyApply.point[5] == -171
	and 100 + 171 + config.spamPolicyApply.height <= 300 - 8,
	"preview rows or Apply overlap the policy pane bottom gutter")

input:SetText("CCBB-POLICY/1\nhistory=" .. private .. "\n")
input.scripts.OnTextChanged()
assert(config.spamPolicyPreview == nil and config.spamPolicyApply.mouseEnabled == false,
	"editing pasted text did not invalidate the preview")
config.spamPolicyPreviewButton.scripts.OnClick()
assert(config.spamPolicyPreview == nil and settings.spam.enabled == previousEnabled,
	"unknown private-data key was accepted")

local refreshes = 0
addon.SpamControl.RefreshSettings = function()
	refreshes = refreshes + 1
	return true
end
input:SetText(text)
input.scripts.OnTextChanged()
config.spamPolicyPreviewButton.scripts.OnClick()
config.spamPolicyApply.scripts.OnClick()
assert(settings.spam.enabled == false and settings.spam.exemptSelf == false
	and settings.spam.duplicate.enabled == true and settings.spam.duplicate.window == 10
	and settings.spam.burst.limit == 8 and settings.spam.scopes.channel == true,
	"explicit Apply did not change all previewed fields")
assert(settings.history[1].message == private
	and settings.spam.repeatAds.seen[private].message == private
	and settings.spam.escalation.bans[private],
	"policy import touched private or retained data")
assert(refreshes == 1 and config.spamMasterToggle.checked == false
	and config.spamDuplicateToggle.checked == true
	and config.spamNumberEdits.duplicateWindow:GetText() == "10"
	and config.spamScopeToggles.channel.checked == true,
	"runtime or visible Spam controls did not refresh after Apply")
assert(config.spamPolicyPreview == nil and config.spamPolicyApply.mouseEnabled == false,
	"applied preview remained reusable")

input:SetText("CCBB-POLICY/1\nspam.enabled=true\n")
input.scripts.OnTextChanged()
config.spamPolicyPreviewButton.scripts.OnClick()
settings.spam.enabled = true
config.spamPolicyApply.scripts.OnClick()
assert(config.spamPolicyPreview == nil
	and config.spamPolicyNotice:GetText():find("PREVIEW AGAIN", 1, true)
	and refreshes == 1,
	"stale preview applied or refreshed runtime")

input:SetText("CCBB-POLICY/1\nspam.enabled=false\n")
input.scripts.OnTextChanged()
config.spamPolicyPreviewButton.scripts.OnClick()
config.spamBansButton.scripts.OnClick()
assert(config.spamPolicyPreview == nil and config.spamPolicyApply.mouseEnabled == false,
	"leaving POLICY retained an actionable import preview")

config.spamFiltersButton.scripts.OnClick()
config.spamFilterSubButtons.policy.scripts.OnClick()
config.spamPolicyImportModeButton.scripts.OnClick()
input:SetText("CCBB-POLICY/1\nspam.enabled=false\n")
input.scripts.OnTextChanged()
config.spamPolicyPreviewButton.scripts.OnClick()
addon.SpamControl.RefreshSettings = nil
config.spamPolicyApply.scripts.OnClick()
assert(settings.spam.enabled == false and config.spamMasterToggle.checked == false
	and config.spamPolicyNotice:GetText():find("SAVED / FIREWALL REFRESH UNAVAILABLE", 1, true),
	"failed runtime refresh hid a saved setting or left controls stale")

print("PASS: Spam Policy UI copy, preview, paging, Apply, stale-state, and privacy flow")
