-- Bounded, selectable-text export of only retained normal-history objects.
-- Run from the Retail addon root: lua Tests/ChatHistoryExport.mock.lua
dofile("Tests/ChatHistory.mock.lua")

local addon = ChattyChattyBangBang
local engine = addon.MessageEngine
local settings = addon:GetSmartSettings()
settings.persistHistory = true
settings.historyCapacity = 100
addon.BlockControl = nil
engine:ClearHistory()

local function add(event, text, sender, channel)
	channel = channel or "General"
	local record = assert(engine:Normalize(event, text, sender, nil, channel,
		nil, nil, nil, 1, channel, nil, 2000 + engine.nextId, "Player-1-EXPORT"))
	return assert(engine:Deliver(record))
end

local public = add("CHAT_MSG_CHANNEL", "Look |cffffaa00|Hitem:123|h[Sword]|h|r\n|Ticon:0|t", "Seller")
local private = add("CHAT_MSG_WHISPER", "private whisper secret", "Friend")
local fakeHeld = { id = 99999, event = "CHAT_MSG_WHISPER", text = "held secret", sender = "Stranger" }
local exported, count, skipped, truncated = engine:ExportRetainedText({ public, private, fakeHeld })
assert(count == 1 and skipped == 2 and not truncated
	and exported:find("[Sword]", 1, true) and exported:find("[icon]", 1, true)
	and not exported:find("|H", 1, true) and not exported:find("private whisper secret", 1, true)
	and not exported:find("held secret", 1, true) and not exported:find("\n", 1, true),
	"default page export leaked private/held text or left unreadable markup")
exported, count = engine:ExportRetainedText({ private }, { includePrivate = true, maxLines = 1 })
assert(count == 1 and exported:find("private whisper secret", 1, true),
	"explicit single-message private copy was unavailable")

addon.BlockControl = {
	ShouldBlock = function(_, record)
		return record == public, "rule", { id = "export-block" }
	end,
	ArchiveRecord = function() end,
}
assert(engine:ReapplyBlockRules() == 1)
exported, count, skipped = engine:ExportRetainedText({ public, private })
assert(count == 0 and skipped == 2 and exported == "",
	"stale blocked search hit or private transcript leaked into export")
addon.BlockControl = nil

engine:ClearHistory()
local page = {}
for index = 1, 21 do page[index] = add("CHAT_MSG_CHANNEL", "line " .. index, "Poster") end
exported, count, skipped, truncated = engine:ExportRetainedText(page)
assert(count == 20 and skipped == 0 and truncated and #exported <= 8192,
	"page export exceeded its 20-line or 8-KiB hard cap")
exported, count, skipped, truncated = engine:ExportRetainedText(page, { maxBytes = 40 })
assert(#exported <= 40 and (truncated or count == 0),
	"custom smaller byte cap was ignored")
local largePage = {}
for index = 1, 20 do
	largePage[index] = add("CHAT_MSG_CHANNEL", string.rep("X", 500), "Poster")
end
exported, count, skipped, truncated = engine:ExportRetainedText(largePage,
	{ maxLines = 9999, maxBytes = 999999 })
assert(#exported <= 8192 and count < 20 and truncated,
	"caller-supplied limits bypassed the 8-KiB export ceiling")

local stale = page[1]
for index = 22, 101 do add("CHAT_MSG_CHANNEL", "line " .. index, "Poster") end
exported, count, skipped = engine:ExportRetainedText({ stale })
assert(count == 0 and skipped == 1 and exported == "",
	"evicted message object could still be exported")

print("Chat history export mock passed")
