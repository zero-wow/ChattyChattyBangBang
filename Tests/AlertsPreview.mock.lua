-- Focused dry-run and boundary coverage. Run: lua Tests/AlertsPreview.mock.lua

function UnitName(unit) return unit == "player" and "Ann" or nil end
function UnitGUID(unit) return unit == "player" and "Player-Me" or nil end
function GetTime() return 42 end

ChattyChattyBangBang = {
	db = { profile = { smartChat = {} } },
	MessageEngine = { RegisterListener = function() end },
	SmartDock = { OnAlert = function(self) self.calls = (self.calls or 0) + 1 end },
}

dofile("Core/Settings.lua")
dofile("Core/Alerts.lua")
local addon = ChattyChattyBangBang
local engine = addon.AlertEngine
engine:Initialize()

local rule = addon:CreateAlertRule({
	name = "Precise", terms = { "ann", "need a tank" }, matchAll = false,
	wholeTerms = true, allSources = false, sources = { ["channel:general"] = true },
})
assert(rule and rule.wholeTerms == true, "precision setting was not stored")
local before = engine:GetStats().matches
local function preview(text, source, draft)
	return addon:PreviewAlertRule(rule.id, text, source or "channel:general", draft)
end

local partial = preview("happy anniversary")
assert(not partial.matched and partial.reason:find("inside another word", 1, true),
	"whole-word preview accepted a partial-word hit or hid the reason")
assert(preview("hello, Ann!").matched, "whole-word preview missed punctuation boundary")
assert(preview("We need a tank tonight").matched, "whole-phrase preview missed ordered words")
assert(not preview("We need a tanker tonight").matched, "whole-phrase preview accepted a longer word")
assert(not preview("I can't help", nil, { terms = { "can" } }).matched,
	"apostrophe split a contraction into a false word boundary")
assert(not preview("Ann is here", "channel:trade").matched,
	"preview ignored the selected-source restriction")

local draft = { terms = { "heal" }, matchAll = false, wholeTerms = true }
assert(preview("We need a healer", nil, draft).matched == false,
	"unsaved draft matched inside a longer word")
assert(preview("We need a heal", nil, draft).matched,
	"unsaved draft did not use the current editor terms")
local saved = addon:GetAlertRules()
assert(saved[#saved].terms[1] == "ann" and saved[#saved].wholeTerms,
	"preview persisted draft terms or changed the saved precision choice")

assert(not preview("ann", "channel:general", { matchAll = true }).matched,
	"MATCH ALL preview accepted a missing phrase")
assert(preview("ann, we need a tank", "channel:general", { matchAll = true }).matched,
	"MATCH ALL preview failed when both terms were present")
assert(preview("anniversary", "channel:general", { wholeTerms = false }).matched,
	"legacy substring matching no longer works when precision is off")

addon:GetSmartSettings().alerts.enabled = false
assert(preview("ann").reason == "Alerts are off globally.", "preview hid the global pause reason")
addon:GetSmartSettings().alerts.enabled = true
assert(preview("ann", nil, { enabled = false }).reason == "This alert rule is paused.",
	"preview hid the rule pause reason")

assert(engine:GetStats().matches == before and not addon.SmartDock.calls,
	"preview caused live alert counters or dock side effects")
assert(preview("").matched == false, "empty sample produced a match")

-- Runtime and preview must agree about the precise boundaries. Disable the
-- separate legacy default name rule so it cannot mask this rule's result.
addon:UpdateAlertRule("alert1", { enabled = false })
engine:RefreshRules(true)
assert(not engine:ProcessRecord({ sourceId = "channel:general", sender = "Elsewhere",
	guid = "Player-Other", direction = "incoming", text = "happy anniversary" }),
	"live matcher accepted a partial-word hit rejected by preview")
assert(engine:ProcessRecord({ sourceId = "channel:general", sender = "Elsewhere",
	guid = "Player-Other", direction = "incoming", text = "Hello, Ann!" }),
	"live matcher missed a whole-word hit shown by preview")

print("Alert precision and preview mock passed")
