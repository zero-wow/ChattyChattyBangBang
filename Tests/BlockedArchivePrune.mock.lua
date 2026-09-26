-- Blocked-line bursts must not resanitize the whole archive per line, while
-- retention still expires at its exact wall-clock boundary.
-- Run from addon root: lua Tests/BlockedArchivePrune.mock.lua

local now = 1700000000
local settings = { blocks = { enabled = true, rules = {} } }
time = function() return now end
ChattyChattyBangBang = {
	GetSmartSettings = function() return settings end,
}

dofile("Core/BlockControl.lua")
local blocks = ChattyChattyBangBang.BlockControl
local rule = { id = "burst-rule", name = "Burst rule" }
local function archive(index)
	return blocks:ArchiveRecord({
		text = "line-" .. index,
		normalized = "line-" .. index,
		sender = "Sender",
		sourceId = "channel:trade",
		event = "CHAT_MSG_CHANNEL",
		epoch = now,
		timestamp = "12:00",
	}, "rule", rule)
end

assert(archive(1), "first blocked line did not enter the archive")
local entries = settings.blocks.archive.entries
for index = 2, 20 do
	now = now + 1
	assert(archive(index), "blocked burst line was not archived")
	assert(settings.blocks.archive.entries == entries,
		"archive was fully rebuilt for a blocked line before any expiry")
end
assert(#entries == 20, "blocked burst lost retained lines")

-- A full pass becomes necessary exactly when the earliest retained row ages
-- out. The next write must remove it even if nobody opened review first.
now = 1700000000 + (7 * 86400) + 1
assert(archive(21), "post-expiry blocked line was not archived")
assert(settings.blocks.archive.entries ~= entries,
	"archive did not prune when the first row reached its expiry")
local reviewed = ChattyChattyBangBang:GetBlockedMessageArchive()
assert(#reviewed == 20 and reviewed[#reviewed].text == "line-2",
	"expiry removed the wrong archive rows or retained an expired line")

print("Blocked archive prune mock passed")
