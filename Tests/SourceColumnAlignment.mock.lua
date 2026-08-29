-- Focused no-client harness for the global TIME | CHANNEL | message layout.
-- Run from the addon root with:
--   lua Tests/SourceColumnAlignment.mock.lua

ChattyChattyBangBang = {
	db = {
		profile = {
			smartChat = {},
		},
	},
}

dofile("Core/Settings.lua")

local addon = ChattyChattyBangBang
local settings = addon:GetSmartSettings()
local rebuildCount = 0
addon.SmartDock = {
	frame = true,
	RebuildActiveView = function()
		rebuildCount = rebuildCount + 1
	end,
}
assert(addon:GetViewSourceColumnAlignment("general") == false, "new tabs should retain natural source widths")
assert(addon:GetViewSenderColumnAlignment("general") == false, "new tabs should retain natural sender widths")
assert(addon:GetColumnAlignmentSpacing() == 2, "new profiles should use a compact two-space alignment gutter")
assert(addon:GetSenderColumnAlignmentSpacing() == 2, "new profiles should use a compact two-space [NAME] gutter")
assert(addon:SetColumnAlignmentSpacing(5), "could not update alignment spacing")
assert(settings.dock.columnAlignmentSpacing == 5, "alignment spacing was not persisted")
assert(addon:GetColumnAlignmentSpacing() == 5, "alignment spacing did not normalize")
assert(addon:GetSenderColumnAlignmentSpacing() == 2,
	"new profiles should keep an independently configurable [NAME] gutter")
assert(addon:SetColumnAlignmentSpacing(99) and addon:GetColumnAlignmentSpacing() == 8,
	"alignment spacing did not clamp to a safe maximum")
assert(addon:SetColumnAlignmentSpacing(-3) and addon:GetColumnAlignmentSpacing() == -3
	and settings.dock.columnAlignmentSpacing == -3,
	"negative CHANNEL GAP was rejected or not persisted")
assert(addon:SetColumnAlignmentSpacing(-99) and addon:GetColumnAlignmentSpacing() == -8,
	"negative CHANNEL GAP did not clamp to its safe minimum")
assert(addon:SetColumnAlignmentSpacing(2), "could not restore default alignment spacing")
assert(addon:SetSenderColumnAlignmentSpacing(4), "could not update [NAME] spacing")
assert(settings.dock.senderColumnAlignmentSpacing == 4, "[NAME] spacing was not persisted")
assert(addon:GetSenderColumnAlignmentSpacing() == 4, "[NAME] spacing did not normalize")
assert(addon:SetSenderColumnAlignmentSpacing(99) and addon:GetSenderColumnAlignmentSpacing() == 8,
	"[NAME] spacing did not clamp to a safe maximum")
assert(addon:SetSenderColumnAlignmentSpacing(-4) and addon:GetSenderColumnAlignmentSpacing() == -4
	and settings.dock.senderColumnAlignmentSpacing == -4,
	"negative [NAME] GAP was rejected or not persisted")
assert(addon:SetSenderColumnAlignmentSpacing(-99) and addon:GetSenderColumnAlignmentSpacing() == -8,
	"negative [NAME] GAP did not clamp to its safe minimum")
assert(addon:SetSenderColumnAlignmentSpacing(2), "could not restore default [NAME] spacing")
assert(addon:GetSenderColumnMaxLength() == 14,
	"new profiles did not preserve the historical fourteen-character name cap")
assert(addon:SetSenderColumnMaxLength(9) and addon:GetSenderColumnMaxLength() == 9,
	"configurable sender-name truncation was not persisted")
assert(addon:SetSenderColumnMaxLength(99) and addon:GetSenderColumnMaxLength() == 32,
	"sender-name truncation did not clamp to its safe maximum")
assert(addon:SetSenderColumnMaxLength(0) and addon:GetSenderColumnMaxLength() == 1,
	"sender-name truncation did not preserve one visible name cell")
assert(addon:SetSenderColumnMaxLength(14), "could not restore sender-name truncation default")
assert(addon:GetAlignmentVisibleOnly() == false,
	"visible-only alignment unexpectedly changed the compatibility default")
assert(addon:SetAlignmentVisibleOnly(true) and addon:GetAlignmentVisibleOnly() == true,
	"visible-only alignment was not persisted")
assert(addon:SetAlignmentVisibleOnly(false), "could not restore buffer-wide alignment scope")

-- The former single GAP setting must seed both lanes on upgrade rather than
-- silently resetting the new [NAME] gutter to its default.
addon.db.profile.smartChat = { dock = { columnAlignmentSpacing = 5 } }
settings = addon:GetSmartSettings()
assert(addon:GetColumnAlignmentSpacing() == 5 and addon:GetSenderColumnAlignmentSpacing() == 5,
	"legacy shared GAP did not seed both channel and [NAME] gutters")
assert(settings.dock.senderColumnAlignmentSpacing == 5,
	"legacy shared GAP migration was not persisted")
addon.db.profile.smartChat = { dock = {} }
settings = addon:GetSmartSettings()
rebuildCount = 0
assert(addon:SetViewSourceColumnAlignment("general", true), "could not enable source-column alignment")
assert(addon:GetViewSourceColumnAlignment("general") == true, "alignment state did not persist")
assert(settings.dock.sourceColumnAlignment == true, "alignment state was not stored as an all-tabs display preference")
assert(addon:GetViewSourceColumnAlignment("trade") == true, "alignment did not immediately apply to another tab")
assert(rebuildCount == 1, "enabling alignment did not immediately redraw the active chat buffer")
assert(settings.textAppearance.font == "SourceCodePro (Regular)",
	"first source-column alignment opt-in did not choose the fixed-width default")
assert(settings.dock.sourceColumnAlignmentFontApplied == true,
	"fixed-width alignment selection was not marked as applied")
assert(addon:SetViewSourceColumnAlignment("general", false), "could not disable source-column alignment")
assert(settings.dock.sourceColumnAlignment == false, "disabling alignment did not persist")
assert(addon:GetViewSourceColumnAlignment("general") == false, "alignment state did not disable")
assert(rebuildCount == 2, "disabling alignment did not immediately redraw the active chat buffer")
assert(addon:SetViewSourceColumnAlignment("general", true), "could not re-enable source-column alignment")
assert(addon:GetViewSourceColumnAlignment("trade") == true, "alignment did not remain global after re-enable")
assert(addon:SetViewSenderColumnAlignment("general", true), "could not enable sender-column alignment")
assert(addon:GetViewSenderColumnAlignment("general") == true, "sender alignment state did not persist")
assert(settings.dock.senderColumnAlignment == true, "sender alignment was not stored as an all-tabs display preference")
assert(addon:GetViewSenderColumnAlignment("trade") == true, "sender alignment did not immediately apply to another tab")
assert(rebuildCount == 4, "enabling sender alignment did not immediately redraw the active chat buffer")
assert(addon:SetViewSenderColumnAlignment("general", false), "could not disable sender-column alignment")
assert(settings.dock.senderColumnAlignment == false, "disabling sender alignment did not persist")
assert(addon:GetViewSenderColumnAlignment("trade") == false, "sender alignment state did not disable globally")
assert(rebuildCount == 5, "disabling sender alignment did not redraw the active chat buffer")

-- A deliberate later return to inherited native chat type must stick; the
-- one-time alignment helper may not silently choose Source Code Pro again.
assert(addon:SetSmartChatTextAppearance("global", { font = false }),
	"could not restore inherited chat font after alignment")
settings = addon:GetSmartSettings()
assert(settings.textAppearance.font == nil,
	"alignment migration overwrote a later inherited-font choice")

-- A profile saved by the initial per-tab control promotes its explicit opt-in
-- to the new all-tabs preference on first settings normalization.
addon.db.profile.smartChat = {
	dock = {},
	viewOptions = { general = { alignSources = true } },
}
settings = addon:GetSmartSettings()
assert(settings.dock.sourceColumnAlignment == true,
	"legacy per-tab alignment did not migrate to the all-tabs preference")
assert(settings.textAppearance.font == "SourceCodePro (Regular)",
	"legacy aligned layout did not receive the fixed-width default")

-- The [NAME] lane is independently useful, and its first opt-in must select
-- the same known fixed-width default even when the source lane remains off.
addon.db.profile.smartChat = { dock = {} }
settings = addon:GetSmartSettings()
assert(settings.dock.senderColumnAlignment == false, "sender alignment default did not normalize")
assert(addon:SetViewSenderColumnAlignment("general", true), "sender-only alignment could not be enabled")
assert(settings.dock.sourceColumnAlignment == false and settings.dock.senderColumnAlignment == true,
	"sender-only alignment unexpectedly changed the source preference")
assert(settings.textAppearance.font == "SourceCodePro (Regular)",
	"sender-only alignment did not select the fixed-width default")

addon.Theme = {
	GetPalette = function()
		return {
			text = { 0.91, 0.91, 0.86, 1 },
			textMuted = { 0.56, 0.63, 0.71, 1 },
			warning = { 1, 0.66, 0.25, 1 },
			borderMuted = { 0.23, 0.34, 0.49, 1 },
		}
	end,
	GetColor = function(self, name)
		local color = self:GetPalette()[name] or self:GetPalette().text
		return color[1], color[2], color[3], color[4]
	end,
}

dofile("Core/Presentation.lua")

local record = {
	id = 1,
	timestamp = "12:34",
	event = "CHAT_MSG_CHANNEL",
	channel = "Trade",
	text = "Selling a very fine item.",
}
local natural = addon.Presentation:Format(record)
local aligned = addon.Presentation:Format(record, 10)
assert(not string.find(natural, "TRADE     |r", 1, true), "natural mode unexpectedly pads the source")
assert(string.find(aligned, "TRADE     |r", 1, true), "aligned mode did not pad the source before the second divider")

-- Zone chat exposes its generic channel category and its actual place in one
-- string. The source lane should retain the useful location, while non-zone
-- qualified channel names keep their semantic prefix unchanged.
assert(addon.Presentation:GetSource({
	event = "CHAT_MSG_CHANNEL",
	channel = "2. Zone - Stormwind",
}) == "STORMWIND", "zone display label did not retain the place name")
assert(addon.Presentation:GetSource({
	event = "CHAT_MSG_CHANNEL",
	channel = "Zone - Pale Reach",
}) == "PALE REACH", "multiword zone display label was not preserved")
assert(addon.Presentation:GetSource({
	event = "CHAT_MSG_CHANNEL",
	channel = "Trade - City",
}) == "TRADE - CITY", "non-zone channel label lost its meaningful prefix")

-- One long historical source must not make the active lane huge. SmartDock
-- caps a tab-local lane at fourteen characters; Presentation keeps the divider
-- aligned by abbreviating only that outlier rather than pushing every line over.
local longSource = {
	id = 2,
	timestamp = "12:34",
	event = "CHAT_MSG_CHANNEL",
	channel = "LookingForGroup",
	text = "A compact channel lane is easier to scan.",
}
local capped = addon.Presentation:Format(longSource, 14)
assert(string.find(capped, "LOOKINGFO...  |r", 1, true),
	"a capped source lane did not abbreviate a long source label")
assert(not string.find(capped, "LOOKINGFORGROUP", 1, true),
	"a long source label escaped the compact alignment lane")

-- A tab-local lane gives a short System source exactly two trailing cells when
-- System is that tab's longest source; another tab can independently fit a
-- longer current source without wasting that space here.
local systemRecord = {
	id = 3,
	timestamp = "12:34",
	event = "CHAT_MSG_SYSTEM",
	text = "system feedback",
}
local systemAligned = addon.Presentation:Format(systemRecord, 8)
assert(string.find(systemAligned, "SYSTEM  |r", 1, true),
	"System did not receive the compact two-character trailing gutter")
assert(not string.find(systemAligned, "SYSTEM      |r", 1, true),
	"System retained the obsolete fixed twelve-character gutter")

addon.Theme = addon.Theme or {}
dofile("Core/SmartDock.lua")
local dock = addon.SmartDock
dock.activeView = "system"
settings.dock.sourceColumnAlignment = true
assert(dock:CalculateSourceColumnWidth({ systemRecord, {
	id = 4,
	timestamp = "12:34",
	event = "UI_ERROR_MESSAGE",
	text = "error feedback",
} }) == 8,
	"System view did not use longest source plus the two-character gutter")
assert(dock:CalculateSourceColumnWidth({ record, {
	id = 5,
	timestamp = "12:34",
	event = "CHAT_MSG_CHANNEL",
	channel = "Newcomers",
	text = "channel feedback",
} }) == 11,
	"channel view did not size its lane from its own longest active source")
assert(dock:CalculateSourceColumnWidth({ longSource }) == 14,
	"outlier source did not respect the tab-local maximum cap")
assert(addon:SetColumnAlignmentSpacing(4), "could not update source lane gutter")
assert(dock:CalculateSourceColumnWidth({ systemRecord }) == 10,
	"source lane did not use the player-selected four-character gutter")
assert(addon:SetColumnAlignmentSpacing(1), "could not select a one-character source gutter")
assert(dock:CalculateSourceColumnWidth({ systemRecord }) == 7,
	"one-character source gutter did not produce longest plus one")

local function stripChatMarkup(text)
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	text = string.gsub(text, "|r", "")
	text = string.gsub(text, "|H.-|h", "")
	text = string.gsub(text, "|h", "")
	return text
end

-- CHANNEL GAP is now exact at zero: the divider itself remains a hard visual
-- boundary, while positive values add literal cells and negative values compact
-- the label without ever moving one rendered cell over another.
local exactOneGap = stripChatMarkup(addon.Presentation:Format(systemRecord,
	dock:CalculateSourceColumnWidth({ systemRecord })))
assert(string.find(exactOneGap, "SYSTEM | system feedback", 1, true),
	"a one-character CHANNEL GAP did not place the divider exactly one cell after the longest source")
assert(not string.find(exactOneGap, "SYSTEM  | system feedback", 1, true),
	"aligned source divider added an extra implicit space")
assert(addon:SetColumnAlignmentSpacing(0), "could not select a zero-character source gutter")
assert(dock:CalculateSourceColumnWidth({ systemRecord }) == 6,
	"CHANNEL GAP 0 retained an unwanted implicit cell")
local exactZeroGap = stripChatMarkup(addon.Presentation:Format(systemRecord,
	dock:CalculateSourceColumnWidth({ systemRecord })))
assert(string.find(exactZeroGap, "SYSTEM| system feedback", 1, true),
	"CHANNEL GAP 0 did not place the divider directly after the label")
assert(not string.find(exactZeroGap, "SYSTEM | system feedback", 1, true),
	"CHANNEL GAP 0 retained a hidden source-lane space")
assert(addon:SetColumnAlignmentSpacing(-3), "could not select a negative source-lane compaction")
assert(dock:CalculateSourceColumnWidth({ systemRecord }) == 3,
	"CHANNEL GAP -3 did not remove exactly three source-label cells")
local compactSource = stripChatMarkup(addon.Presentation:Format(systemRecord,
	dock:CalculateSourceColumnWidth({ systemRecord })))
assert(string.find(compactSource, "SYS| system feedback", 1, true)
	and not string.find(compactSource, "SYSTEM", 1, true),
	"negative CHANNEL GAP did not truncate safely against the visible divider")
assert(addon:SetColumnAlignmentSpacing(-8)
	and dock:CalculateSourceColumnWidth({ systemRecord }) == 1,
	"maximum negative CHANNEL GAP removed the final safe source-label cell")
local minimumSource = stripChatMarkup(addon.Presentation:Format(systemRecord,
	dock:CalculateSourceColumnWidth({ systemRecord })))
assert(string.find(minimumSource, "S| system feedback", 1, true),
	"maximum source compaction overlapped or removed the divider boundary")
assert(addon:SetColumnAlignmentSpacing(0), "could not restore zero source gap for scope diagnostics")

-- The live lane follows the same newest-400 records that RebuildActiveView
-- renders. Name the exact source driving it, then release that width when the
-- driver ages out instead of leaving a stale historical gutter indefinitely.
local historicalRecords = { longSource }
for index = 2, 400 do
	historicalRecords[index] = systemRecord
end
dock:ResetActiveSourceColumnMetrics(historicalRecords)
assert(dock.activeSourceColumnDriver == "LOOKINGFORGROUP"
	and dock.activeSourceColumnLongest == 15 and dock.activeSourceColumnWidth == 14,
	"active source metrics did not identify the historical width-driving label")
local historicalDiagnostic = dock:GetColumnAlignmentDiagnostics()
assert(string.find(historicalDiagnostic, "LOOKINGFORGROUP 15+GAP 0=14", 1, true)
	and string.find(historicalDiagnostic, "BUFFER 400", 1, true),
	"Shift diagnostic did not explain the source label, effective gap, and record scope")
local widthChanged, releasedWidth = dock:TrackActiveSourceColumnLabel("SYSTEM")
assert(widthChanged and releasedWidth == 6 and dock.activeSourceColumnDriver == "SYSTEM",
	"an expired historical source continued to hold the active lane open")
assert(#dock.activeSourceColumnSamples == 400 and dock.activeColumnRecordCount == 400,
	"source metric window drifted from the rendered 400-record buffer")
assert(addon:SetColumnAlignmentSpacing(2), "could not restore source lane gutter")

-- A fixed sender lane must make the message body begin in the same character
-- cell for a short normal player name and a safely abbreviated outlier.
local shortSender = {
	id = 3,
	timestamp = "12:34",
	event = "CHAT_MSG_CHANNEL",
	channel = "Trade",
	sender = "Ari",
	text = "short sender message",
}
local longSender = {
	id = 4,
	timestamp = "12:34",
	event = "CHAT_MSG_CHANNEL",
	channel = "Trade",
	sender = "VeryLongCharacterName",
	text = "long sender message",
}
local fixedShort = stripChatMarkup(addon.Presentation:Format(shortSender, 12, 16))
local fixedLong = stripChatMarkup(addon.Presentation:Format(longSender, 12, 16))
local shortStart = assert(string.find(fixedShort, shortSender.text, 1, true), "short sender message was not rendered")
local longStart = assert(string.find(fixedLong, longSender.text, 1, true), "long sender message was not rendered")
assert(shortStart == longStart, "fixed sender lane did not align message starts")
assert(string.find(fixedLong, "[VeryLongCha...]", 1, true),
	"long sender label did not abbreviate inside visible brackets")
local utf8Sender = stripChatMarkup(addon.Presentation:Format({
	id = 41,
	timestamp = "12:34",
	event = "CHAT_MSG_CHANNEL",
	channel = "Trade",
	sender = "Александра",
	text = "utf8 sender message",
}, 12, 7, 0))
assert(string.find(utf8Sender, "[Ал...]", 1, true),
	"configured sender truncation split or byte-counted a UTF-8 player name")
local spacedSender = stripChatMarkup(addon.Presentation:Format(shortSender, 12, 16, 4))
assert(string.find(spacedSender, shortSender.text, 1, true) == shortStart + 2,
	"sender lane did not honor the configured spacing")
local compactShort = stripChatMarkup(addon.Presentation:Format(shortSender, 12, 16, -4))
local compactLong = stripChatMarkup(addon.Presentation:Format(longSender, 12, 16, -4))
assert(string.find(compactShort, shortSender.text, 1, true)
	== string.find(compactLong, longSender.text, 1, true),
	"negative [NAME] GAP stopped aligning short and truncated names")
assert(string.find(compactLong, "[VeryLon...]", 1, true),
	"negative [NAME] GAP did not compact safely inside square brackets")
settings.dock.senderColumnAlignment = true
assert(addon:SetSenderColumnMaxLength(9)
	and dock:CalculateSenderColumnWidth({ shortSender, longSender }) == 11,
	"NAME MAX did not set the fixed sender lane to max name cells plus brackets")
assert(addon:SetSenderColumnMaxLength(14), "could not restore NAME MAX default")

-- Records with no sender (system feedback, loot, and local UI errors) must
-- retain their natural no-name layout instead of inheriting a blank sender gap.
local noSender = stripChatMarkup(addon.Presentation:Format({
	id = 5,
	timestamp = "12:34",
	event = "CHAT_MSG_CHANNEL",
	channel = "Trade",
	text = "senderless feedback",
}, 12, 16))
assert(string.find(noSender, " | senderless feedback", 1, true),
	"senderless record inherited a blank sender column")

-- Exact hanging wrap is presentation-only: one logical message remains one
-- rendered string, but every explicit continuation receives the same number
-- of fixed-width cells as the visible TIME | SOURCE | [PLAYER] leader.
local wrappingRecord = {
	id = 6,
	timestamp = "12:34",
	event = "CHAT_MSG_CHANNEL",
	channel = "Trade",
	sender = "Ari",
	text = "alpha beta gamma delta",
}
local wrappingLeader = addon.Presentation:FormatParts(wrappingRecord, 12, 16, 2)
local leaderColumns = addon.Presentation:GetRenderedColumnCount(wrappingLeader)
local wrapped, reportedLeaderColumns, exactContinuationColumns, renderedBreaks, exactBreaks = addon.Presentation:FormatWrapped(
	wrappingRecord, 12, 16, 2, leaderColumns + 16)
assert(reportedLeaderColumns == leaderColumns, "wrapped renderer reported the wrong leader width")
assert(exactContinuationColumns == leaderColumns and exactBreaks < 3 and renderedBreaks == exactBreaks,
	"a short message unnecessarily abandoned its exact hanging lane")
local continuation = "\n" .. string.rep(" ", leaderColumns)
assert(string.find(wrapped, continuation, 1, true),
	"continuation did not begin directly beneath the first message character")
assert(not string.find(wrapped, "\nalpha", 1, true),
	"continuation escaped back to the left edge")

local systemWrapRecord = {
	id = 8,
	timestamp = "12:34",
	event = "CHAT_MSG_SYSTEM",
	text = "The system announcement wraps once.",
}
local systemWrapLeader = addon.Presentation:FormatParts(systemWrapRecord, 8)
local systemLeaderColumns = addon.Presentation:GetRenderedColumnCount(systemWrapLeader)
local systemWrapped = addon.Presentation:FormatWrapped(systemWrapRecord, 8, nil, nil, systemLeaderColumns + 18)
assert(string.find(systemWrapped, "\n" .. string.rep(" ", systemLeaderColumns), 1, true),
	"senderless System continuation did not align beneath its own message start")

-- A long message in a narrow dock must not be squeezed into a tiny leader-wide
-- column for a dozen lines. The adaptive budget begins from the actual usable
-- message width; retain the aligned first line, then use the compact two-cell
-- continuation inset only when doing so materially shortens the predicted
-- result.
local narrowRecord = {
	id = 9,
	timestamp = "12:34",
	event = "CHAT_MSG_CHANNEL",
	channel = "Trade",
	sender = "Ari",
	text = "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen",
}
local narrowLeader = addon.Presentation:FormatParts(narrowRecord, 12, 16, 2)
local narrowLeaderColumns = addon.Presentation:GetRenderedColumnCount(narrowLeader)
local narrowWrapped, _, narrowContinuationColumns, narrowRenderedBreaks, narrowExactBreaks,
	narrowBudget, narrowCompactBreaks =
	addon.Presentation:FormatWrapped(narrowRecord, 12, 16, 2, narrowLeaderColumns + 8)
assert(narrowBudget == 6, "narrow text lane did not retain the six-wrap baseline")
assert(narrowExactBreaks >= narrowBudget, "narrow-message fixture did not reach its adaptive limit")
assert(narrowContinuationColumns == 2, "long narrow message did not select the compact continuation inset")
assert(narrowRenderedBreaks < narrowExactBreaks, "compact continuation did not reduce excessive wrapping")
assert(narrowCompactBreaks == narrowRenderedBreaks,
	"adaptive decision did not report the compact layout it selected")
local firstNarrowBreak = assert(string.find(narrowWrapped, "\n", 1, true), "adaptive message did not wrap")
local afterNarrowBreak = string.sub(narrowWrapped, firstNarrowBreak + 1)
assert(string.sub(afterNarrowBreak, 1, 2) == "  " and string.sub(afterNarrowBreak, 3, 3) ~= " ",
	"adaptive continuation did not begin at the short original-style inset")

-- The exact-wrap allowance grows with the live text lane instead of using a
-- fixed six-break cliff. A typical 24-cell lane keeps the six-wrap baseline,
-- while a spacious lane can raise the fallback threshold to twelve.
local mediumBudget, mediumContent = addon.Presentation:GetAdaptiveHangingWrapBudget(
	narrowLeaderColumns, narrowLeaderColumns + 24)
local wideBudget, wideContent = addon.Presentation:GetAdaptiveHangingWrapBudget(
	narrowLeaderColumns, narrowLeaderColumns + 80)
assert(mediumContent == 24 and mediumBudget == 6,
	"typical text width did not retain the six-break alignment allowance")
assert(wideContent == 80 and wideBudget == 12,
	"wide text lane did not expand the exact-wrap allowance")
local beforeGrowth = addon.Presentation:GetAdaptiveHangingWrapBudget(
	narrowLeaderColumns, narrowLeaderColumns + 31)
local afterGrowth = addon.Presentation:GetAdaptiveHangingWrapBudget(
	narrowLeaderColumns, narrowLeaderColumns + 32)
assert(beforeGrowth == 6 and afterGrowth == 7,
	"adaptive allowance did not grow at the first eight-cell width boundary")

-- Even above its line budget, a message with deliberate newlines should stay
-- exactly aligned when a compact inset cannot materially reduce its height.
local explicitLines = {}
for index = 1, 8 do explicitLines[index] = "line" .. index end
local explicitRecord = {
	id = 10,
	timestamp = "12:34",
	event = "CHAT_MSG_CHANNEL",
	channel = "Trade",
	sender = "Ari",
	text = table.concat(explicitLines, "\n"),
}
local explicitWrapped, explicitLeaderColumns, explicitContinuationColumns,
	explicitRenderedBreaks, explicitExactBreaks, explicitBudget, explicitCompactBreaks =
	addon.Presentation:FormatWrapped(explicitRecord, 12, 16, 2, narrowLeaderColumns + 24)
assert(explicitExactBreaks >= explicitBudget,
	"explicit-line fixture did not reach the adaptive limit")
assert(explicitCompactBreaks == explicitExactBreaks,
	"compact prediction unexpectedly changed deliberate line breaks")
assert(explicitContinuationColumns == explicitLeaderColumns
	and explicitRenderedBreaks == explicitExactBreaks,
	"alignment was abandoned even though compacting could not shorten the message")
assert(string.find(explicitWrapped, "\n" .. string.rep(" ", explicitLeaderColumns), 1, true),
	"explicit continuation did not remain in the exact message lane")

-- WoW links stay byte-for-byte intact and are moved only as an atomic token;
-- ScrollingMessageFrame therefore retains the original click target.
local itemLink = "|Hitem:12345:0:0:0|h[Ancient Sword]|h"
local linkedRecord = {
	id = 7,
	timestamp = "12:34",
	event = "CHAT_MSG_CHANNEL",
	channel = "Trade",
	sender = "Ari",
	text = "alpha beta " .. itemLink .. " gamma delta epsilon",
}
local linkedLeader = addon.Presentation:FormatParts(linkedRecord, 12, 16, 2)
local linkedColumns = addon.Presentation:GetRenderedColumnCount(linkedLeader)
local linkedWrapped = addon.Presentation:FormatWrapped(linkedRecord, 12, 16, 2, linkedColumns + 24)
assert(string.find(linkedWrapped, itemLink, 1, true), "hanging wrap split or rewrote an item hyperlink")
assert(select(2, string.gsub(linkedWrapped, "|Hitem:12345:0:0:0|h", "")) == 1,
	"hanging wrap duplicated a hyperlink header")

print("Source-column alignment mock: PASS")
