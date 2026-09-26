-- Run from addon root: lua Tests/ChatRecovery.mock.lua
local secret = {}
local locked, nativeShown, scheduled, fallbackFails = true, false, nil, false
local captures = {}

canaccessvalue = function(value) return value ~= secret end
time = function() return 1700000000 end
C_Timer = { After = function(_, callback) scheduled = callback end }
C_ChatInfo = {
	InChatMessagingLockdown = function() return locked end,
	GetChatLineText = function(id)
		assert(not locked, "recovery read chat during lockdown")
		return id == 42 and "WTS test item" or nil
	end,
	GetChatLineSenderName = function(id) return id == 42 and "Seller-Realm" or nil end,
	GetChatLineSenderGUID = function(id) return id == 42 and "Player-1-SELLER" or nil end,
}
ChattyChattyBangBang = {
	Print = function() end,
	Diagnostics = { db = { session = 7 } },
	SmartDock = { SetNativeSafetyFallback = function(_, active)
		if active and fallbackFails then return false end
		nativeShown = active
		return true
	end },
	MessageEngine = {
		enabled = true,
		CaptureAccessible = function(_, event, epoch, ...)
			captures[#captures + 1] = { event = event, epoch = epoch, args = { ... } }
		end,
	},
}

dofile("Core/ChatRecovery.lua")
local recovery = ChattyChattyBangBang.ChatRecovery
recovery:Queue("CHAT_MSG_CHANNEL", secret, secret, nil, "General", nil,
	nil, nil, 1, "General", nil, 42, secret)
assert(nativeShown and recovery:GetStatus().pending == 1,
	"restricted chat did not open the native safety fallback")
local retryOK, retryReason = recovery:RetryNow()
assert(not retryOK and retryReason == "chat-restricted" and recovery:GetStatus().lockdown,
	"manual recovery must refuse secret chat text during lockdown")
assert(recovery.pending[1].arguments[1] == nil
	and recovery.pending[1].arguments[2] == nil
	and recovery.pending[1].arguments[12] == nil,
	"secret text, sender, or GUID leaked into the recovery queue")
assert(type(scheduled) == "function", "recovery retry was not scheduled")
scheduled()
assert(#captures == 0 and nativeShown, "recovery ran during lockdown")
locked = false
assert(type(scheduled) == "function", "unlock retry was not scheduled")
scheduled()
assert(#captures == 1 and captures[1].event == "CHAT_MSG_CHANNEL"
	and captures[1].epoch == 1700000000, "recovery did not re-enter normal capture")
assert(captures[1].args[1] == "WTS test item"
	and captures[1].args[2] == "Seller-Realm"
	and captures[1].args[11] == 42
	and captures[1].args[12] == "Player-1-SELLER", "recovered record lost routing metadata")
assert(recovery:GetStatus().pending == 0 and recovery:GetStatus().recovered == 1
	and not nativeShown, "native fallback stayed open after successful recovery")
assert(ChattyChattyBangBang.Diagnostics.db.chatRecovery.session == 7
	and ChattyChattyBangBang.Diagnostics.db.chatRecovery.recovered == 1,
	"reload diagnostics lost the catch-up outcome")

fallbackFails = true
recovery:Queue("CHAT_MSG_CHANNEL", secret, secret, nil, "General", nil,
	nil, nil, 1, "General", nil, 42, secret)
assert(recovery:GetStatus().fallbackFailed, "failed safety reveal was not visible")
recovery:Flush()
assert(recovery:GetStatus().pending == 0 and recovery:GetStatus().unresolved == 0
	and not recovery:GetStatus().fallbackFailed,
	"finished catch-up retained a stale fallback failure with no recovery need")
fallbackFails = false

recovery:Queue("CHAT_MSG_WHISPER", secret, secret, nil, nil, nil,
	nil, nil, nil, nil, nil, nil)
assert(recovery:GetStatus().unresolved == 1 and nativeShown,
	"an unidentifiable withheld whisper falsely reported as recovered")
fallbackFails = true
recovery:Queue("CHAT_MSG_WHISPER", secret, secret)
assert(recovery:GetStatus().unresolved == 2 and recovery:GetStatus().fallbackFailed,
	"failed native fallback was not recorded before shutdown")
local showOK, showReason = recovery:TryShowNativeChat()
assert(not showOK and showReason == "native-unavailable"
	and recovery:GetStatus().fallbackFailed,
	"manual safety-view action falsely claimed Blizzard chat was shown")
fallbackFails = false
showOK, showReason = recovery:TryShowNativeChat()
assert(showOK and showReason == "native-shown" and nativeShown
	and not recovery:GetStatus().fallbackFailed,
	"manual safety-view retry did not reveal Blizzard chat and clear the failure")
recovery:Queue("CHAT_MSG_CHANNEL", secret, secret, nil, "General", nil,
	nil, nil, 1, "General", nil, 99, secret)
retryOK = recovery:RetryNow()
assert(retryOK and recovery:GetStatus().pending == 1 and nativeShown,
	"manual catch-up should safely retry a still-unavailable line without hiding Blizzard chat")
local stored = ChattyChattyBangBang.Diagnostics.db.chatRecovery
for key, value in pairs(stored) do
	assert(key ~= "text" and key ~= "sender" and key ~= "arguments"
		and type(value) ~= "table", "recovery diagnostics stored message bodies or raw payloads")
end
recovery:Stop()
assert(not nativeShown, "stopping capture did not release native fallback")
assert(recovery:GetStatus().pending == 0 and recovery:GetStatus().unresolved == 0
	and not recovery:GetStatus().fallbackFailed,
	"stopping capture left a stale unresolved or fallback-failure state")
assert(ChattyChattyBangBang.Diagnostics.db.chatRecovery.unresolved == 0,
	"shutdown diagnostics retained an unresolved line after capture stopped")
retryOK, retryReason = recovery:RetryNow()
showOK, showReason = recovery:TryShowNativeChat()
assert(not retryOK and retryReason == "nothing-waiting"
	and not showOK and showReason == "no-recovery-need" and not nativeShown,
	"manual actions must not turn native chat on without an active recovery need")
print("ChatRecovery mock tests passed")
