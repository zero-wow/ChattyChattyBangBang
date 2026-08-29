-- Focused no-client contract for width-aware Smart Chat metadata.
-- Run from the addon root with: lua Tests/SmartDockResponsiveMetadata.mock.lua

local settings = {
	dock = {
		responsiveMetadata = true,
	},
}

ChattyChattyBangBang = {
	GetSmartSettings = function()
		return settings
	end,
	GetViewSourceColumnAlignment = function()
		return true
	end,
	GetViewSenderColumnAlignment = function()
		return true
	end,
	GetColumnAlignmentSpacing = function()
		return 2
	end,
	GetSenderColumnAlignmentSpacing = function()
		return 2
	end,
}

local addon = ChattyChattyBangBang
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
dofile("Core/SmartDock.lua")

local dock = addon.SmartDock
local alignedSpec = {
	enabled = true,
	sourceAlignedWidth = 12,
	senderAlignedWidth = 16,
	senderSpacing = 2,
	naturalSourceWidth = 15,
	naturalSenderWidth = 12,
	timestampWidth = 5,
	hasTimestamp = true,
	hasSource = true,
	hasSender = true,
}

local wide = dock:ResolveResponsiveMetadataLayout(64, alignedSpec)
assert(wide.mode == "WIDE" and wide.bodyColumns == 24,
	"full metadata did not retain the exact 24-cell readable-body boundary")
assert(wide.sourceColumnWidth == 12 and wide.senderColumnWidth == 16 and wide.senderSpacing == 2,
	"wide metadata did not preserve configured alignment widths and gap")

local medium = dock:ResolveResponsiveMetadataLayout(63, alignedSpec)
assert(medium.mode == "MEDIUM" and not medium.showTimestamp
	and medium.showSource and medium.showSender,
	"width below the wide boundary did not drop timestamp metadata first")
assert(medium.senderColumnWidth == 12 and medium.senderSpacing == 1,
	"medium metadata did not compact the fixed sender lane and runtime gap")
local mediumBoundary = dock:ResolveResponsiveMetadataLayout(45, alignedSpec)
assert(mediumBoundary.mode == "MEDIUM" and mediumBoundary.bodyColumns == 18,
	"medium metadata did not retain the exact 18-cell readable-body boundary")

local narrow = dock:ResolveResponsiveMetadataLayout(44, alignedSpec)
assert(narrow.mode == "NARROW" and not narrow.showTimestamp,
	"width below the medium boundary did not enter narrow metadata")
local narrowBoundary = dock:ResolveResponsiveMetadataLayout(26, alignedSpec)
assert(narrowBoundary.mode == "NARROW" and narrowBoundary.bodyColumns == 12,
	"narrow metadata did not retain the exact 12-cell readable-body boundary")
local extreme = dock:ResolveResponsiveMetadataLayout(25, alignedSpec)
assert(extreme.mode == "EXTREME" and not extreme.showTimestamp
	and not extreme.showSource and not extreme.showSender,
	"width below the narrow boundary did not protect a message-only surface")

local lockedSpec = {}
for key, value in pairs(alignedSpec) do lockedSpec[key] = value end
lockedSpec.enabled = false
local locked = dock:ResolveResponsiveMetadataLayout(25, lockedSpec)
assert(locked.mode == "LOCKED" and locked.showTimestamp and locked.showSource and locked.showSender,
	"responsiveMetadata=false did not lock the complete configured metadata row")
assert(locked.sourceColumnWidth == 12 and locked.senderColumnWidth == 16 and locked.senderSpacing == 2,
	"locked mode changed the saved alignment presentation")

-- Senderless SYSTEM/LOOT lines follow the same timestamp/source ladder. They
-- omit only the nonexistent player lane and retain provenance until EXTREME.
local senderlessSpec = {}
for key, value in pairs(alignedSpec) do senderlessSpec[key] = value end
senderlessSpec.hasSender = false
senderlessSpec.naturalSenderWidth = 0
local senderlessWide = dock:ResolveResponsiveMetadataLayout(46, senderlessSpec)
local senderlessMedium = dock:ResolveResponsiveMetadataLayout(32, senderlessSpec)
local senderlessNarrow = dock:ResolveResponsiveMetadataLayout(26, senderlessSpec)
local senderlessExtreme = dock:ResolveResponsiveMetadataLayout(25, senderlessSpec)
assert(senderlessWide.mode == "WIDE" and senderlessWide.bodyColumns == 24,
	"senderless wide row reserved a phantom sender lane")
assert(senderlessMedium.mode == "MEDIUM" and senderlessMedium.bodyColumns == 18,
	"senderless medium row reserved a phantom sender lane")
assert(senderlessNarrow.mode == "NARROW" and senderlessNarrow.bodyColumns == 12,
	"senderless narrow row lost its source too early")
assert(senderlessExtreme.mode == "EXTREME",
	"senderless row did not become message-only at the extreme boundary")

local function stripChatMarkup(text)
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	text = string.gsub(text, "|r", "")
	text = string.gsub(text, "|H.-|h", "")
	text = string.gsub(text, "|h", "")
	return text
end

local playerRecord = {
	id = 1,
	timestamp = "12:34",
	event = "CHAT_MSG_CHANNEL",
	channel = "Trade",
	view = "general",
	sender = "Armageddonu",
	text = "A linked |Hitem:12345:0:0:0|h[Ancient Sword]|h survives.",
}
local systemRecord = {
	id = 2,
	timestamp = "12:34",
	event = "CHAT_MSG_SYSTEM",
	view = "system",
	text = "System provenance remains visible.",
}

dock.activeResponsiveMetadataEnabled = true
dock.activeMetadataMode = "MEDIUM"
local mediumPlayer = stripChatMarkup(addon.Presentation:Format(
	playerRecord, 12, 12, 1, dock:GetResponsiveMetadataForRecord(playerRecord)))
assert(not string.find(mediumPlayer, "12:34", 1, true)
	and string.find(mediumPlayer, "TRADE", 1, true)
	and string.find(mediumPlayer, "[Armaged...]", 1, true),
	"medium formatter did not hide timestamp and keep compact source/sender metadata")

dock.activeMetadataMode = "NARROW"
local narrowPlayer = stripChatMarkup(addon.Presentation:Format(
	playerRecord, 12, 12, 1, dock:GetResponsiveMetadataForRecord(playerRecord)))
assert(not string.find(narrowPlayer, "12:34", 1, true)
	and not string.find(narrowPlayer, "TRADE", 1, true)
	and string.find(narrowPlayer, "[Armaged...]", 1, true),
	"narrow formatter did not reduce a player row to sender plus message")
local narrowSystem = stripChatMarkup(addon.Presentation:Format(
	systemRecord, 8, 12, 1, dock:GetResponsiveMetadataForRecord(systemRecord)))
assert(string.find(narrowSystem, "SYSTEM", 1, true)
	and not string.find(narrowSystem, "12:34", 1, true),
	"senderless narrow row did not retain source provenance without a blank sender lane")

dock.activeMetadataMode = "EXTREME"
local extremePlayer = addon.Presentation:Format(
	playerRecord, nil, nil, 0, dock:GetResponsiveMetadataForRecord(playerRecord))
assert(not string.find(stripChatMarkup(extremePlayer), "12:34", 1, true)
	and not string.find(stripChatMarkup(extremePlayer), "TRADE", 1, true)
	and not string.find(stripChatMarkup(extremePlayer), "Armageddonu", 1, true),
	"extreme formatter retained hidden metadata")
assert(string.find(extremePlayer, "|Hitem:12345:0:0:0|h[Ancient Sword]|h", 1, true),
	"responsive metadata mode damaged an existing item hyperlink")

-- Capacity is measured from the live display and font, so a font/layout change
-- crosses the same cell boundaries without a pixel-specific guess.
local display = {
	width = 641,
	GetWidth = function(self) return self.width end,
}
local measure = {
	SetWidth = function(self, value) self.width = value end,
	SetText = function(self, value) self.text = value end,
	GetStringWidth = function(self) return #(self.text or "") * 10 end,
}
dock.display = display
dock.messageMeasure = measure
assert(dock:GetDisplayColumnCapacity() == 62,
	"live fixed-font capacity did not reserve the two-cell native-wrap safety margin")

addon.MessageEngine = {}
dock.active = true
dock.activeView = "general"
dock.activePresentationPixelWidth = 641
local layoutRebuilds = 0
dock.RebuildActiveViewPreservingScroll = function()
	layoutRebuilds = layoutRebuilds + 1
end
display.width = 631
assert(dock:RefreshDisplayWidthPresentation() and layoutRebuilds == 1,
	"a changed layout width did not immediately rebuild responsive metadata")
assert(not dock:RefreshDisplayWidthPresentation() and layoutRebuilds == 1,
	"an unchanged layout width caused a redundant metadata rebuild")

local beforeSettings = settings.dock.responsiveMetadata
dock:ResolveResponsiveMetadataLayout(25, alignedSpec)
assert(settings.dock.responsiveMetadata == beforeSettings,
	"runtime metadata fallback rewrote the saved responsive toggle")

print("SmartDock responsive metadata mock passed")
