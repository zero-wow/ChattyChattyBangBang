-- Focused no-client harness for /run, /script, and /dump output capture.
-- Run from the addon root with: lua Tests/LocalCommandOutput.mock.lua

local now = 100
local received = {}
local nativeMessages = {}
local hookInstallCount = 0
local scriptCalls = 0
local dumpCalls = 0
local unrelatedCalls = 0
unpack = unpack or table.unpack

local settings = {
	enabled = true,
	historyCapacity = 150,
	persistHistory = false,
	learnedSources = {},
	customViewRevision = 0,
	channelTargets = {},
	localCommandOutput = {
		enabled = true,
		destination = "system",
	},
}

ChattyChattyBangBang = {
	GetSmartSettings = function()
		return settings
	end,
	-- Keep the focused harness compatible with a narrow settings accessor while
	-- the SavedVariables table remains the authoritative persisted contract.
	GetLocalCommandOutputSettings = function()
		return settings.localCommandOutput
	end,
	GetSmartViews = function()
		return {}
	end,
	IsRecordAllowedInView = function()
		return true
	end,
	IsRecordIncludedBySource = function(_, viewId, record)
		return viewId == "system" and record
			and record.sourceId == "system:local-debug"
	end,
	Print = function()
		-- Listener failures are not part of this harness.
	end,
	SmartDock = {
		activeView = "trade",
	},
}

GetTime = function()
	return now
end
time = function()
	return 1700000000 + math.floor(now)
end
date = function()
	return "12:00"
end
CreateFrame = function()
	return {
		SetScript = function(self, name, callback)
			self[name] = callback
		end,
		RegisterEvent = function()
			return true
		end,
		UnregisterAllEvents = function()
			return true
		end,
	}
end

DEFAULT_CHAT_FRAME = {
	AddMessage = function(_, text)
		table.insert(nativeMessages, text)
	end,
}

-- WoW 3.3.5 supports the table/method form used to observe AddMessage without
-- replacing or suppressing the native delivery. This mock deliberately keeps
-- every installed post-hook visible so duplicate registration fails loudly.
hooksecurefunc = function(target, methodName, postHook)
	assert(type(target) == "table", "local command capture did not use a frame-scoped hook")
	assert(type(methodName) == "string" and type(postHook) == "function",
		"local command capture used an invalid hooksecurefunc signature")
	local original = assert(target[methodName], "hook target method is missing")
	hookInstallCount = hookInstallCount + 1
	target[methodName] = function(...)
		local results = { original(...) }
		postHook(...)
		return unpack(results)
	end
end

SlashCmdList = {}
SLASH_SCRIPT1 = "/run"
SLASH_SCRIPT2 = "/script"
SLASH_DUMP1 = "/dump"
SLASH_UNRELATED1 = "/unrelated"

SlashCmdList.SCRIPT = function(message)
	scriptCalls = scriptCalls + 1
	DEFAULT_CHAT_FRAME:AddMessage("script: " .. message)
end
SlashCmdList.DUMP = function(message)
	dumpCalls = dumpCalls + 1
	DEFAULT_CHAT_FRAME:AddMessage("dump heading: " .. message)
	DEFAULT_CHAT_FRAME:AddMessage("dump value: 42")
	DEFAULT_CHAT_FRAME:AddMessage("dump value: 42")
end
SlashCmdList.UNRELATED = function(message)
	unrelatedCalls = unrelatedCalls + 1
	DEFAULT_CHAT_FRAME:AddMessage("unrelated: " .. message)
end

-- Wrath caches a resolved slash alias independently from SlashCmdList. Seed
-- that cache with the original handlers to reproduce a command used before
-- Chatty enables its bridge.
local originalScriptHandler = SlashCmdList.SCRIPT
local originalDumpHandler = SlashCmdList.DUMP
hash_SlashCmdList = {
	["/RUN"] = originalScriptHandler,
	["/SCRIPT"] = originalScriptHandler,
	["/DUMP"] = originalDumpHandler,
	["/UNRELATED"] = SlashCmdList.UNRELATED,
}

dofile("Core/MessageEngine.lua")

local engine = ChattyChattyBangBang.MessageEngine
engine:Initialize()
engine:SetEnabled(true)
assert(hash_SlashCmdList["/RUN"] == nil
	and hash_SlashCmdList["/SCRIPT"] == nil
	and hash_SlashCmdList["/DUMP"] == nil,
	"enabling command capture left Wrath's original diagnostic handlers cached")
assert(hash_SlashCmdList["/UNRELATED"] == SlashCmdList.UNRELATED,
	"diagnostic cache invalidation touched an unrelated slash alias")
assert(type(engine.RefreshLocalCommandCapture) == "function",
	"MessageEngine does not expose RefreshLocalCommandCapture")
engine:RegisterListener("local-command-output-test", function(record)
	table.insert(received, record)
end)

local function assertLocalRecord(record, text, view)
	assert(record and record.event == "CCBB_LOCAL_MESSAGE",
		"command output did not use the explicit local-feedback event")
	assert(record.text == text, "command output text changed during capture")
	assert(record.sourceId == "system:local-debug" and record.sourceGroup == "system",
		"command output did not retain the independently configurable local-debug source")
	assert(record.view == view and record.views and record.views[view],
		"command output did not route to the configured destination")
end

-- Initialize/enable installs one observer and wraps the shared /run + /script
-- handler once. Explicit refreshes must not stack either layer.
engine:RefreshLocalCommandCapture()
local wrappedScript = SlashCmdList.SCRIPT
local wrappedDump = SlashCmdList.DUMP
engine:RefreshLocalCommandCapture()
engine:RefreshLocalCommandCapture()
assert(hookInstallCount == 1, "repeated refresh stacked DEFAULT_CHAT_FRAME hooks")
assert(SlashCmdList.SCRIPT == wrappedScript and SlashCmdList.DUMP == wrappedDump,
	"repeated refresh rewrapped an unchanged slash handler")
hash_SlashCmdList["/RUN"] = SlashCmdList.SCRIPT
hash_SlashCmdList["/SCRIPT"] = SlashCmdList.SCRIPT
hash_SlashCmdList["/DUMP"] = SlashCmdList.DUMP
assert(hash_SlashCmdList["/RUN"] == wrappedScript
	and hash_SlashCmdList["/SCRIPT"] == wrappedScript
	and hash_SlashCmdList["/DUMP"] == wrappedDump
	and wrappedScript ~= originalScriptHandler and wrappedDump ~= originalDumpHandler,
	"Wrath's diagnostic aliases did not recache to the installed wrappers")

hash_SlashCmdList["/RUN"]("one")
assert(scriptCalls == 1 and #nativeMessages == 1,
	"/run no longer reached its original handler and native chat frame")
assert(#received == 1, "/run output was missing or captured more than once")
assertLocalRecord(received[1], "script: one", "system")

hash_SlashCmdList["/SCRIPT"]("two")
assert(scriptCalls == 2 and #nativeMessages == 2,
	"/script no longer reached its original handler and native chat frame")
assert(#received == 2, "/script output was missing or captured more than once")
assertLocalRecord(received[2], "script: two", "system")

hash_SlashCmdList["/DUMP"]("player")
assert(dumpCalls == 1 and #nativeMessages == 5,
	"/dump did not preserve all native output lines")
assert(#received == 5, "/dump lines were lost or captured more than once")
assertLocalRecord(received[3], "dump heading: player", "system")
assertLocalRecord(received[4], "dump value: 42", "system")
assertLocalRecord(received[5], "dump value: 42", "system")

-- A broad AddMessage hook would duplicate ordinary chat and other add-ons.
-- Only execution inside one of the three registered diagnostic commands may
-- cross the local-feedback bridge.
SlashCmdList.UNRELATED("hello")
DEFAULT_CHAT_FRAME:AddMessage("ordinary direct output")
assert(unrelatedCalls == 1 and #nativeMessages == 7,
	"unrelated native output was suppressed")
assert(#received == 5,
	"unrelated slash/direct AddMessage output leaked into Smart Chat")

-- The user may disable this bridge while leaving Smart Chat itself enabled.
settings.localCommandOutput.enabled = false
engine:RefreshLocalCommandCapture()
SlashCmdList.SCRIPT("capture disabled")
assert(#nativeMessages == 8 and #received == 5,
	"disabled command capture hid native output or still created a Smart Chat record")

-- Active-tab mode preserves the local-debug source while selecting the dock's
-- current rail as the one primary destination.
settings.localCommandOutput.enabled = true
settings.localCommandOutput.destination = "active"
ChattyChattyBangBang.SmartDock.activeView = "trade"
engine:RefreshLocalCommandCapture()
SlashCmdList.SCRIPT("active destination")
assert(#nativeMessages == 9 and #received == 6,
	"active-tab command output was missing or duplicated")
assertLocalRecord(received[6], "script: active destination", "trade")
assert(not received[6].views.system,
	"active-tab output gained a second generated primary membership")
local activeSystemAppearances = 0
for _, record in ipairs(engine:GetMessages("system")) do
	if record == received[6] then
		activeSystemAppearances = activeSystemAppearances + 1
	end
end
assert(activeSystemAppearances == 1 and received[6].view == "trade",
	"System's additive local-debug source feed lost, duplicated, or reprioritized active-tab output")
engine:ReclassifyAll()
assert(received[6].localCommandView == "trade" and received[6].view == "trade"
	and received[6].views.trade and not received[6].views.system,
	"reclassification forgot the active destination recorded at capture time")

-- Sync is a protocol quarantine, not a destination for human-readable command
-- output. Active-tab mode falls back to System when Sync is selected.
ChattyChattyBangBang.SmartDock.activeView = "sync"
SlashCmdList.SCRIPT("sync fallback")
assert(#nativeMessages == 10 and #received == 7,
	"Sync fallback command output was missing or duplicated")
assertLocalRecord(received[7], "script: sync fallback", "system")
assert(received[7].localCommandView == "system",
	"Sync fallback did not persist the resolved System destination")

-- Disabling Smart Chat must leave the original Blizzard behavior intact and
-- must never accumulate output for a later re-enable.
engine:SetEnabled(false)
SlashCmdList.DUMP("while disabled")
assert(#nativeMessages == 13 and #received == 7,
	"disabled MessageEngine captured command output or suppressed native lines")
engine:SetEnabled(true)
engine:RefreshLocalCommandCapture()
assert(hookInstallCount == 1, "disable/re-enable stacked the AddMessage hook")

-- Another add-on may replace a slash handler after login. Refresh should wrap
-- the new owner exactly once, and an error must unwind the narrow capture
-- scope before any later ordinary AddMessage call.
SlashCmdList.SCRIPT = function(message)
	DEFAULT_CHAT_FRAME:AddMessage("before error: " .. message)
	error("intentional slash failure")
end
engine:RefreshLocalCommandCapture()
assert(hash_SlashCmdList["/RUN"] == nil and hash_SlashCmdList["/SCRIPT"] == nil,
	"handler replacement left Wrath's previous /run or /script wrapper cached")
local wrappedErrorHandler = SlashCmdList.SCRIPT
engine:RefreshLocalCommandCapture()
assert(SlashCmdList.SCRIPT == wrappedErrorHandler,
	"replacement error handler was wrapped more than once")
hash_SlashCmdList["/RUN"] = SlashCmdList.SCRIPT
hash_SlashCmdList["/SCRIPT"] = SlashCmdList.SCRIPT
assert(hash_SlashCmdList["/RUN"] == wrappedErrorHandler
	and hash_SlashCmdList["/SCRIPT"] == wrappedErrorHandler,
	"replacement handler did not recache to its new wrapper")
ChattyChattyBangBang.SmartDock.activeView = "trade"
local ok, failure = pcall(SlashCmdList.SCRIPT, "boom")
assert(not ok and tostring(failure):find("intentional slash failure", 1, true),
	"slash-handler failure was swallowed or changed")
assert(#nativeMessages == 14 and #received == 8,
	"output before a slash-handler error was missing or duplicated")
assertLocalRecord(received[8], "before error: boom", "trade")
DEFAULT_CHAT_FRAME:AddMessage("after error ordinary output")
assert(#nativeMessages == 15 and #received == 8,
	"slash-handler error left command capture active")

-- Settings and delivery are presentation layers around Blizzard's command.
-- Either may fail open, but neither may suppress native /run output or leave
-- the command-only AddMessage scope active afterward.
SlashCmdList.SCRIPT = function(message)
	DEFAULT_CHAT_FRAME:AddMessage("fail-open: " .. message)
end
engine:RefreshLocalCommandCapture()

local realGetLocalCommandOutputSettings = engine.GetLocalCommandOutputSettings
engine.GetLocalCommandOutputSettings = function()
	error("intentional settings failure")
end
ok, failure = pcall(SlashCmdList.SCRIPT, "settings")
assert(ok and failure == nil and #nativeMessages == 16 and #received == 8,
	"throwing command-output settings suppressed native /run output or escaped")
assert(#(engine.localCommandCaptureViews or {}) == 0,
	"throwing command-output settings left the capture scope active")
DEFAULT_CHAT_FRAME:AddMessage("after settings failure")
assert(#nativeMessages == 17 and #received == 8,
	"settings failure leaked capture into later ordinary AddMessage output")
engine.GetLocalCommandOutputSettings = realGetLocalCommandOutputSettings

local realCaptureLocalFeedback = engine.CaptureLocalFeedback
engine.CaptureLocalFeedback = function()
	error("intentional capture failure")
end
ok, failure = pcall(SlashCmdList.SCRIPT, "capture")
assert(ok and failure == nil and #nativeMessages == 18 and #received == 8,
	"throwing local-feedback delivery suppressed native /run output or escaped")
assert(#(engine.localCommandCaptureViews or {}) == 0,
	"throwing local-feedback delivery left the capture scope active")
DEFAULT_CHAT_FRAME:AddMessage("after capture failure")
assert(#nativeMessages == 19 and #received == 8,
	"capture delivery failure leaked into later ordinary AddMessage output")
engine.CaptureLocalFeedback = realCaptureLocalFeedback

-- Restoring both collaborators must immediately restore normal capture; the
-- fail-open path must not permanently disable or poison the wrapper.
SlashCmdList.SCRIPT("recovered")
assert(#nativeMessages == 20 and #received == 9,
	"command output did not recover after transient settings/capture failures")
assertLocalRecord(received[9], "fail-open: recovered", "trade")

print("Local command output mock tests passed")
