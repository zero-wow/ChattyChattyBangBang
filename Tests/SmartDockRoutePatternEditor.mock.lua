-- Focused no-client contract for Shift > ANALYZE > RULE... .
-- Run from the Retail addon root: lua Tests/SmartDockRoutePatternEditor.mock.lua

ChattyChattyBangBang = { Theme = {}, Presentation = {} }
dofile("Core/RoutePatternRules.lua")
dofile("Core/SmartDock.lua")

local addon = ChattyChattyBangBang
local dock = addon.SmartDock
local realEditorLayout = dock.RefreshMessageRoutePatternEditorLayout
local function widget()
	return {
		shown = false,
		SetText = function(self, value) self.text = value end,
		GetText = function(self) return self.text end,
		SetLabel = function(self, value) self.label = value end,
		SetEnabled = function(self, value) self.enabled = value end,
		SetValue = function(self, value) self.checked = value and true or false end,
		Show = function(self) self.shown = true end,
		Hide = function(self) self.shown = false end,
		IsShown = function(self) return self.shown end,
	}
end

local record = {
	event = "CHAT_MSG_CHANNEL", sourceId = "channel:general",
	text = "|cffffd100|Hguild:123|h[Guild: Baby Wipes]|h|r is a new guild, "
		.. "we're 8/8 normal venomous abyss and heroic tidebound. "
		.. "raid is saturday 7pm - 9pm pacific. lf healers and dps, hmu if interested",
}
dock.analysisRecord = record
dock.analysisRouteDestination = "guildInvites"
dock.analysisPanel = widget()
dock.analysisRuleEditor = widget()
dock.analysisRuleDestination = widget()
dock.analysisRuleScope = widget()
dock.analysisRuleInclude = widget()
dock.analysisRuleExclude = widget()
dock.analysisRuleScopeHint = widget()
dock.analysisRulePatternPreview = widget()
dock.analysisRuleMessagePreview = widget()
dock.analysisRuleStatus = widget()
dock.analysisRuleSave = widget()
dock.analysisRuleUndo = widget()
dock.analysisFootnote = widget()
dock.HideDisplayHoverHint = function() end
dock.HideMessageActionHighlight = function() end
dock.RefreshMessageRoutePatternDestinationMenu = function() return true end
dock.RefreshMessageRoutePatternEditorLayout = function() return true end
dock.ScheduleMessageBlockActionRefresh = function() end
dock.ShowMessageAnalysis = function(self, selected)
	self.analysisRecord = selected
	self.analysisPanel:Show()
	self.analysisPatternRuleIndex = 3
	return true
end

addon.SetMessageRoutePatternRule = function() return true, 3 end
addon.GetMessageRoutePatternRules = function() return {} end

assert(dock:ShowMessageRoutePatternEditor(), "RULE editor did not open for a public message")
assert(dock.analysisRuleScope.checked and dock.analysisRuleScopeHint.text:find("channel:general", 1, true),
	"the same public channel was not the default rule scope")
assert(dock.analysisRuleInclude.text == "[Guild:, is a new guild"
	and dock.analysisRuleExclude.text == "",
	"guild-intro suggestion did not leave later LF role text out of the required phrases")
assert(dock.analysisRuleSave.enabled and dock.analysisRuleStatus.text:find("READY", 1, true),
	"matching sample was not previewed as saveable")
assert(dock.analysisRulePatternPreview.text:find("%[guild:", 1, true)
	and dock.analysisRuleMessagePreview.text:find("lf healers and dps", 1, true)
	and dock.analysisRuleMessagePreview.text:find("|cff9ba8b8", 1, true),
	"editor did not expose the generated Lua pattern and ignored role text")

dock.analysisRuleExclude:SetText("lf healers")
local matches, preview = dock:RefreshMessageRoutePatternPreview()
assert(not matches and preview.reason == "excluded" and not dock.analysisRuleSave.enabled,
	"NONE phrase did not veto the selected message before save")
dock.analysisRuleExclude:SetText("")
assert(dock:RefreshMessageRoutePatternPreview(), "removing NONE phrase did not restore the match")
dock.analysisRuleScope:SetValue(false)
assert(dock:GetMessageRoutePatternDraft().sourceId == nil,
	"unchecked source scope still restricted the rule to General")
dock.analysisRuleScope:SetValue(true)
assert(dock:SetMessageRouteOverrideDestination("trade", true)
	and dock:GetMessageRoutePatternDraft().destination == "trade"
	and dock.analysisRuleDestination.label == "TRADE v",
	"the existing route selector did not update the rule destination")
assert(dock:SetMessageRouteOverrideDestination("guildInvites", true))

local savedRecord, savedDraft
addon.SetMessageRoutePatternRule = function(_, selected, draft)
	savedRecord, savedDraft = selected, draft
	dock:HideMessageBlockControls() -- Settings rebuilds synchronously.
	return true, 3
end
local saved, index = dock:SaveMessageRoutePatternRule()
assert(saved and index == 3 and savedRecord == record and savedDraft.destination == "guildInvites"
	and savedDraft.sourceId == "channel:general" and savedDraft.include[1] == "[Guild:"
	and savedDraft.include[2] == "is a new guild" and #savedDraft.exclude == 0,
	"SAVE RULE lost the selected message or the chosen positive/negative scope")
assert(dock.analysisRecord == record and dock.analysisFootnote.text:find("rule #3 saved", 1, true),
	"synchronous rebuild lost the selected message or save confirmation")

local removedIndex
addon.RemoveMessageRoutePatternRule = function(_, requested)
	removedIndex = requested
	dock:HideMessageBlockControls()
	return true
end
assert(dock:UndoMessageRoutePatternRule() and removedIndex == 3
	and dock.analysisRecord == record
	and dock.analysisFootnote.text:find("rule #3 removed", 1, true),
	"UNDO RULE failed to remove the matching permanent rule after a rebuild")

-- The floating editor keeps its complete logical layout at minimum dock size;
-- only its screen scale contracts when the whole game viewport is narrow.
UIParent = { GetWidth = function() return 360 end, GetHeight = function() return 320 end }
function dock.analysisRuleEditor:SetScale(value) self.scale = value end
function dock.analysisRuleEditor:ClearAllPoints() self.points = {} end
function dock.analysisRuleEditor:SetPoint(...) self.points = { ... } end
function dock.analysisRuleEditor:SetSize(width, height) self.width, self.height = width, height end
assert(realEditorLayout(dock)
	and dock.analysisRuleEditor.width == 520 and dock.analysisRuleEditor.height == 400
	and dock.analysisRuleEditor.width * dock.analysisRuleEditor.scale <= 336
	and dock.analysisRuleEditor.height * dock.analysisRuleEditor.scale <= 296
	and dock.analysisRuleEditor.points[1] == "CENTER"
	and dock.analysisRuleEditor.points[2] == UIParent,
	"RULE editor could cross the viewport edge or collapse its controls at minimum dock size")

print("SmartDock permanent route rule editor mock passed")
