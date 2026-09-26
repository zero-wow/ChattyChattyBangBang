-- Run from the addon root with: lua Tests/PolicyTransfer.mock.lua
ChattyChattyBangBang = {}
dofile("Core/PolicyTransfer.lua")
local transfer = ChattyChattyBangBang.PolicyTransfer

local private = "PRIVATE-NAME-AND-MESSAGE-7cb42"
local settings = {
	spam = {
		enabled = false,
		exemptSelf = true,
		duplicate = { enabled = true, window = 12.5, allowedCopies = 2,
			crossChannels = false },
		burst = { enabled = true, window = 6, limit = 6, muteDuration = 15 },
		repeatAds = { enabled = true, window = 86400, maxCopies = 4,
			minimumGap = 3600, minimumLength = 18,
			seen = { [private] = { text = private, sender = private } } },
		escalation = { enabled = true, mutesBeforeBan = 3, strikeWindow = 1800,
			offenders = { [private] = true }, bans = { [private] = true } },
		scopes = { channel = true, ["local"] = true, guild = false,
			group = false, whisper = false, bnet = false },
	},
	history = { { message = private, sender = private } },
	conversations = { savedDrafts = { [private] = private },
		savedReplyTargets = { [private] = private } },
	whisperGuard = { blocked = { [private] = true }, entries = { private } },
	blocks = { rules = { { sender = private, text = private } },
		archive = { entries = { private } } },
	alerts = { rules = { { name = private, terms = { private } } } },
	messageRouteOverrides = { [private] = "trade" },
	keywordColors = { [private] = "gold" },
}

local exported = assert(transfer.Export(settings))
assert(exported == assert(transfer.Export(settings)), "export order changed")
assert(exported:sub(1, 14) == "CCBB-POLICY/1\n", "version header missing")
assert(exported:find("spam.enabled=false", 1, true), "false policy omitted")
assert(exported:find("spam.duplicate.window=12.5", 1, true), "decimal policy lost")
assert(not exported:find(private, 1, true), "private profile content exported")
assert(not exported:find("crossChannels", 1, true), "legacy no-op policy exported")
assert(not exported:find("history", 1, true), "history exported")
assert(not exported:find("sender", 1, true), "sender field exported")

local incoming = table.concat({
	"CCBB-POLICY/1",
	"spam.enabled=true",
	"spam.duplicate.window=4.5",
	"spam.scopes.whisper=true",
	"",
}, "\n")
local preview = assert(transfer.Preview(settings, incoming))
assert(preview.count == 3 and #preview.changes == 3, "preview did not enumerate changes")
assert(preview.changes[1].old == false and preview.changes[1].new == true,
	"preview lost a false original value")
assert(settings.spam.enabled == false, "preview changed settings")
assert(transfer.Apply(settings, preview) == false, "import applied without confirmation")
assert(settings.spam.enabled == false, "unconfirmed import changed settings")

-- Caller-edited preview fields cannot redirect the private validated plan.
preview.changes[1].key = "history"
preview.changes[1].new = private
preview.count = 999
local ok, count = transfer.Apply(settings, preview, "APPLY")
assert(ok and count == 3, "confirmed import failed")
assert(settings.spam.enabled and settings.spam.duplicate.window == 4.5
	and settings.spam.scopes.whisper, "import did not apply allowlisted values")
assert(settings.spam.duplicate.allowedCopies == 2
	and settings.spam.repeatAds.maxCopies == 4,
	"partial import reset current policy defaults")
assert(settings.spam.repeatAds.seen[private].text == private
	and settings.conversations.savedDrafts[private] == private
	and settings.history[1].message == private,
	"import touched private or history data")
assert(transfer.Apply(settings, preview, "APPLY") == false, "preview was reusable")

local stale = assert(transfer.Preview(settings,
	"CCBB-POLICY/1\nspam.enabled=false\n"))
settings.spam.enabled = false
local staleOk, staleReason = transfer.Apply(settings, stale, "APPLY")
assert(not staleOk and staleReason == "stale-preview", "changed setting accepted stale preview")

local function rejected(text)
	local result = transfer.Preview(settings, text)
	assert(result == nil, "unsafe policy text was accepted")
end
rejected("CCBB-POLICY/1\nspam.enabled=true\nspam.enabled=false\n")
rejected("CCBB-POLICY/1\nspam.scopes.whisper=true\nspam.enabled=false\n")
rejected("CCBB-POLICY/1\nhistory=" .. private .. "\n")
rejected("CCBB-POLICY/1\nspam.escalation.bans." .. private .. "=true\n")
rejected("CCBB-POLICY/1\nspam.duplicate.window=999999999\n")
rejected("CCBB-POLICY/1\nspam.burst.limit=1.5\n")
rejected("CCBB-POLICY/1\nspam.enabled=loadstring('bad')\n")
rejected("CCBB-POLICY/1\nspam.enabled=true")
rejected("CCBB-POLICY/2\nspam.enabled=true\n")
rejected("CCBB-POLICY/1\nspam.enabled=true\r")
rejected(string.rep("x", 8193))

local crlf = assert(transfer.Preview(settings,
	"CCBB-POLICY/1\r\nspam.enabled=true\r\n"))
assert(crlf.count == 1, "ordinary Windows line endings were rejected")

local corrupt = { spam = { enabled = false, duplicate = "not-a-table" } }
local corruptPreview = assert(transfer.Preview(corrupt,
	"CCBB-POLICY/1\nspam.enabled=true\nspam.duplicate.window=12\n"))
local corruptOk = transfer.Apply(corrupt, corruptPreview, "APPLY")
assert(corruptOk == false and corrupt.spam.enabled == false,
	"invalid parent table caused a partial apply")

local empty = {}
local emptyPreview = assert(transfer.Preview(empty,
	"CCBB-POLICY/1\nspam.duplicate.enabled=false\n"))
assert(transfer.Apply(empty, emptyPreview, "APPLY"))
assert(empty.spam.duplicate.enabled == false, "absent policy parent was not created")
assert(empty.spam.burst == nil, "unmentioned policy defaults were materialized")

local malformedCurrent = { spam = { enabled = private } }
local sanitized = assert(transfer.Preview(malformedCurrent,
	"CCBB-POLICY/1\nspam.enabled=true\n"))
assert(sanitized.changes[1].old == nil and sanitized.changes[1].invalidCurrent,
	"invalid current value leaked into preview")
assert(transfer.Export(malformedCurrent) == nil,
	"malformed current value was exported")

print("PASS: deterministic, bounded, preview-gated policy transfer excludes private data")
