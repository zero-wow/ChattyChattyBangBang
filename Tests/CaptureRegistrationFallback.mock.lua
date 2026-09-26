-- Run from addon root: lua Tests/CaptureRegistrationFallback.mock.lua
local settings = {
	enabled = true, historyCapacity = 100, persistHistory = false,
	learnedSources = {}, customViews = {}, customViewRevision = 0,
	channelTargets = {}, dock = { hideNativeChat = true },
}
local registered, fallbackCalls, recoveryStops = {}, {}, 0
local fallbackFails = false
local requiredFailureActive = true
ChattyChattyBangBang = {
	GetSmartSettings = function() return settings end,
	GetSmartViews = function() return {} end,
	Print = function() end,
	SmartDock = { SetCaptureCoverageFallback = function(_, active)
		fallbackCalls[#fallbackCalls + 1] = active
		return not (active and fallbackFails)
	end },
	ChatRecovery = { Stop = function() recoveryStops = recoveryStops + 1 end },
}
GetTime = function() return 1 end
time = function() return 1700000000 end
date = function() return "12:00" end
CreateFrame = function()
	return {
		SetScript = function() end,
		RegisterEvent = function(_, event)
			if event == "CHAT_MSG_BN_CONVERSATION"
				or event == "CHAT_MSG_BATTLEGROUND" then return false end
			if requiredFailureActive and event == "CHAT_MSG_YELL" then error("registration refused") end
			if requiredFailureActive and event == "CHAT_MSG_LOOT" then return false end
			registered[event] = true
			if event == "CHAT_MSG_SAY" then return false end -- Already registered can report false.
			return nil -- Older mocks may not return a success value.
		end,
		IsEventRegistered = function(_, event)
			return (not requiredFailureActive or event ~= "CHAT_MSG_MONEY")
				and registered[event] == true
		end,
		UnregisterAllEvents = function()
			registered = {}
		end,
	}
end

dofile("Core/MessageEngine.lua")
local engine = ChattyChattyBangBang.MessageEngine
engine:Initialize()
engine:SetEnabled(true)
local status = engine:GetCaptureCoverageStatus()
local failed = {}
for _, event in ipairs(status.failedEvents) do failed[event] = true end
assert(status.enabled and status.failedCount == 5
	and status.requiredFailedCount == 3 and status.optionalFailedCount == 2
	and status.registeredCount + status.failedCount == status.totalCount
	and failed.CHAT_MSG_YELL and failed.CHAT_MSG_LOOT and failed.CHAT_MSG_MONEY
	and failed.CHAT_MSG_BN_CONVERSATION and failed.CHAT_MSG_BATTLEGROUND
	and registered.CHAT_MSG_SAY and fallbackCalls[#fallbackCalls] == true,
	"registration failures were ignored or native fallback was not requested")
assert(status.nativeFallbackRequired and not status.nativeFallbackFailed
	and not status.externalOutputCovered
	and string.find(status.externalOutputNote, "Community", 1, true)
	and string.find(status.externalOutputNote, "third-party", 1, true)
	and settings.dock.hideNativeChat,
	"coverage status omitted the direct-output limit or changed saved native-chat preference")
settings.launcher = { minimap = { hide = false } }
ChattyChattyBangBang.Theme = {
	texts = {}, GetColor = function() return 1, 1, 1, 1 end,
}
ChattyChattyBangBang.SmartDock.IsActive = function() return true end
dofile("Core/Config.lua")
local config = ChattyChattyBangBang.CustomConfig
config.homeStatus = {
	SetText = function(self, text) self.text = text end,
	SetTextColor = function() end,
}
config.smartToggle = { SetValue = function() end }
config.minimapToggle = { SetValue = function() end }
config:RefreshHomeState()
assert(string.find(config.homeStatus.text, "CHAT GAP", 1, true)
	and string.find(config.homeStatus.text, "CHAT_MSG_YELL", 1, true)
	and string.find(config.homeStatus.text, "Blizzard chat visible", 1, true),
	"overview did not show the failed event type and native safety surface")
status.failedEvents[1] = "tampered"
assert(engine:GetCaptureCoverageStatus().failedEvents[1] ~= "tampered",
	"caller could mutate internal capture coverage status")
engine:SetEnabled(false)
status = engine:GetCaptureCoverageStatus()
assert(not status.enabled and status.failedCount == 0
	and fallbackCalls[#fallbackCalls] == false and recoveryStops == 1,
	"disabling capture retained a stale registration fallback")
requiredFailureActive = false
engine:SetEnabled(true)
status = engine:GetCaptureCoverageStatus()
assert(status.requiredFailedCount == 0 and status.optionalFailedCount == 2
	and status.failedCount == 2 and not status.nativeFallbackRequired
	and fallbackCalls[#fallbackCalls] == false,
	"missing legacy-only events forced Blizzard chat visible on Retail")
config:RefreshHomeState()
assert(string.find(config.homeStatus.text, "TRACKED CHAT", 1, true),
	"optional compatibility gaps were presented as missing current WoW chat")
engine:SetEnabled(false)
requiredFailureActive = true
fallbackFails = true
engine:SetEnabled(true)
status = engine:GetCaptureCoverageStatus()
assert(status.requiredFailedCount == 3 and status.nativeFallbackFailed,
	"failed native-chat fallback was reported as successful")
engine:SetEnabled(false)
print("Capture registration fallback mock tests passed")
