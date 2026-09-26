-- Focused no-client contract for one clickable message-type dot per logical entry.
-- Run from the Retail addon root: lua Tests/SmartDockMessageTypeDots.mock.lua

local settings = { dock = { messageTypeDots = true } }
local analyzeCalls = 0
local reportedRecord, reportedExpected
ChattyChattyBangBang = {
	Theme = {},
	GetSmartSettings = function() return settings end,
	MessageEngine = {
		AnalyzeRecord = function(_, record)
			analyzeCalls = analyzeCalls + 1
			return { semantic = record.semantic }
		end,
	},
	ReportMessageRoute = function(_, record, expected)
		reportedRecord, reportedExpected = record, expected
		return true, { id = 7 }
	end,
}

local created = {}
CreateFrame = function(kind, _, parent)
	assert(kind == "Button" and parent, "dot must be a button in the content gutter")
	local button = { scripts = {}, shown = false }
	function button:SetFrameLevel(level) self.level = level end
	function button:RegisterForClicks(...) self.clicks = { ... } end
	function button:CreateTexture(_, layer)
		assert(layer == "ARTWORK", "dot texture must render above its button")
		local texture = {}
		function texture:SetTexture(path) self.path = path end
		function texture:SetPoint(...) self.point = { ... } end
		function texture:SetSize(width, height) self.width, self.height = width, height end
		function texture:SetVertexColor(...) self.color = { ... } end
		self.texture = texture
		return texture
	end
	function button:SetScript(name, callback) self.scripts[name] = callback end
	function button:SetSize(width, height) self.width, self.height = width, height end
	function button:ClearAllPoints() self.point = nil end
	function button:SetPoint(...) self.point = { ... } end
	function button:Show() self.shown = true end
	function button:Hide() self.shown = false end
	created[#created + 1] = button
	return button
end

dofile("Core/SmartDock.lua")
local dock = ChattyChattyBangBang.SmartDock
local display = {
	width = 300, height = 50, scroll = 0, shown = true,
	GetWidth = function(self) return self.width end,
	GetHeight = function(self) return self.height end,
	GetFont = function() return "Fonts\\FRIZQT__.TTF", 10 end,
	GetSpacing = function() return 0 end,
	GetCurrentScroll = function(self) return self.scroll end,
	GetFrameLevel = function() return 10 end,
	IsShown = function(self) return self.shown end,
}
dock.content = {}
dock.display = display
dock.displayMeasurementWidth = 300 -- Supplied line spans mirror AddMessage payloads.
local first = { id = 1, event = "CHAT_MSG_SAY", category = "chat" }
local wrapped = { id = 2, event = "CHAT_MSG_PARTY", category = "group" }
local third = { id = 3, event = "CHAT_MSG_CHANNEL", category = "trade" }
dock.displayRecords = {
	{ record = first, gapRows = 0, contentLines = 1, lines = 1 },
	{ record = wrapped, gapRows = 1, contentLines = 2, lines = 3 },
	{ record = third, gapRows = 0, contentLines = 1, lines = 1 },
}

assert(dock:RefreshMessageTypeDots() and dock.messageTypeDotVisibleCount == 3,
	"one dot was not drawn for each visible logical record")
assert(#created == 3 and created[1].messageRecord == first
	and created[2].messageRecord == wrapped and created[3].messageRecord == third,
	"wrapped or gap-spaced records were duplicated or mapped to the wrong dot")
assert(created[1].point[5] == 0 and created[2].point[5] == -20
	and created[3].point[5] == -40,
	"dots did not align with first content rows after wrap and entry gaps")
assert(created[1].clicks[1] == "LeftButtonUp"
	and created[1].texture.path:find("message-orb.tga", 1, true),
	"dot lacks the expected clickable orb texture")

local clicked
dock.ShowMessageAnalysis = function(_, record) clicked = record; return true end
created[2].scripts.OnClick(created[2])
assert(clicked == wrapped, "click did not open analysis for its own logical entry")

display.height = 20
display.scroll = 0 -- Lines 4-5; the wrapped record's first content line (3) is clipped.
assert(dock:RefreshMessageTypeDots() and dock.messageTypeDotVisibleCount == 1
	and created[1].messageRecord == third and not created[2].shown,
	"a clipped continuation incorrectly gained a second dot")
display.height = 10
display.scroll = 3 -- Only line 2, the transparent gap before record 2.
assert(dock:RefreshMessageTypeDots() and dock.messageTypeDotVisibleCount == 0,
	"a blank entry-gap row gained a dot")
display.height = 50
display.scroll = 0

local label, sayR = dock:GetMessageTypeDotStyle(first)
assert(label == "Say" and sayR > 0, "say message did not get its own dot style")
local partyLabel, partyR = dock:GetMessageTypeDotStyle(wrapped)
assert(partyLabel == "Party" and partyR ~= sayR,
	"party messages lost their separate event color")
local addonLabel = dock:GetMessageTypeDotStyle({ event = "CHAT_MSG_ADDON", category = "system" })
assert(addonLabel == "Add-on message", "add-on traffic was painted as generic System")
local tradeLabel = dock:GetMessageTypeDotStyle(third)
assert(tradeLabel == "Trade", "classified advertisement did not get the Trade cue")
local sale = {
	event = "CHAT_MSG_CHANNEL", category = "general",
	semantic = { scores = { trade = 4 }, threshold = { trade = 5 } },
}
local saleLabel = dock:GetMessageTypeDotStyle(sale)
assert(saleLabel == "Possible sale - review route",
	"near-threshold unclassified sale lacked a cautious review cue")
local lowScoreSaleLabel = dock:GetMessageTypeDotStyle({
	event = "CHAT_MSG_CHANNEL", category = "general", text = "Selling mounts today",
	semantic = { scores = { trade = 1 }, threshold = { trade = 5 } },
})
assert(lowScoreSaleLabel == "Possible sale - review route",
	"an obvious sale cue below the route threshold did not get a review marker")
dock:GetMessageTypeDotStyle(sale)
assert(analyzeCalls == 2, "dot refresh repeatedly analyzed the same unchanged record")
local publicLabel = dock:GetMessageTypeDotStyle({
	event = "CHAT_MSG_CHANNEL", category = "general",
	semantic = { scores = { trade = 0 }, threshold = { trade = 5 } },
})
assert(publicLabel == "Public channel", "ordinary public chat was mislabeled as an ad")

local many, geometry = {}, {
	lineHeight = 8, displayHeight = 130 * 8, topInset = 0,
	firstVisibleLine = 1, lastVisibleLine = 130,
}
for index = 1, 130 do
	many[index] = { record = { id = index, event = "CHAT_MSG_SAY" }, contentFirstLine = index }
end
assert(dock:RefreshMessageTypeDots(many, geometry) and dock.messageTypeDotVisibleCount == 128
	and #created == 128 and dock:AcquireMessageTypeDot(129) == nil,
	"visible dot pool exceeded its strict bound")

settings.dock.messageTypeDots = false
assert(dock:RefreshMessageTypeDots(many, geometry) == false
	and dock.messageTypeDotVisibleCount == 0 and not created[1].shown,
	"disabled dots left active hit targets")
settings.dock.messageTypeDots = true

dock.analysisRecord = third
dock.analysisReportExpectedRoute = "groupFinder"
local footnote = {}
function footnote:SetText(value) self.value = value end
dock.analysisFootnote = footnote
local saved, report = dock:ReportSelectedMessageRoute()
assert(saved == true and report.id == 7 and reportedRecord == third
	and reportedExpected == "groupFinder" and footnote.value:find("Review 7 saved", 1, true),
	"REPORT did not pass the selected record and expected route to the saved queue")

print("Smart Dock message-type dots mock passed")
