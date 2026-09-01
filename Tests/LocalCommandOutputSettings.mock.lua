-- Focused no-client contract for /run, /script, and /dump output settings.
-- Run from the addon root with: lua Tests/LocalCommandOutputSettings.mock.lua

ChattyChattyBangBang = {
	db = {
		profile = {
			smartChat = {},
		},
	},
}

dofile("Core/Settings.lua")

local addon = ChattyChattyBangBang
local smart = addon:GetSmartSettings()
local commandOutput = addon:GetLocalCommandOutputSettings()

assert(type(smart.localCommandOutput) == "table"
	and smart.localCommandOutput.schema == 1
	and smart.localCommandOutput.enabled == true
	and smart.localCommandOutput.destination == "system",
	"new profiles did not receive the enabled schema-1 System default")
assert(commandOutput.schema == 1 and commandOutput.enabled == true
	and commandOutput.destination == "system",
	"public getter did not expose the normalized default")

-- Callers may freely annotate a returned settings snapshot. The live
-- SavedVariables table must remain owned by Settings.
commandOutput.enabled = false
commandOutput.destination = "active"
commandOutput.extra = true
local unchanged = addon:GetLocalCommandOutputSettings()
assert(unchanged.enabled == true and unchanged.destination == "system"
	and unchanged.extra == nil,
	"local command output getter leaked its SavedVariables table")

-- Hand-edited or stale non-table data normalizes to a complete safe default.
smart.localCommandOutput = "broken"
local normalized = addon:GetLocalCommandOutputSettings()
assert(normalized.schema == 1 and normalized.enabled == true
	and normalized.destination == "system"
	and type(smart.localCommandOutput) == "table",
	"malformed non-table command settings were not repaired")

-- Schema is authoritative, only the boolean false disables capture, and an
-- unknown destination cannot redirect diagnostics into an arbitrary rail.
smart.localCommandOutput = {
	schema = 99,
	enabled = "false",
	destination = "general",
	unknown = "discard me",
}
normalized = addon:GetLocalCommandOutputSettings()
assert(normalized.schema == 1 and normalized.enabled == true
	and normalized.destination == "system" and normalized.unknown == nil,
	"malformed fields were not normalized into the schema-1 contract")

smart.localCommandOutput = {
	schema = 0,
	enabled = false,
	destination = " ACTIVE ",
}
normalized = addon:GetLocalCommandOutputSettings()
assert(normalized.schema == 1 and normalized.enabled == false
	and normalized.destination == "active",
	"valid disabled/active preferences were lost during normalization")

-- Destination writes accept only the two documented modes. Case and outside
-- whitespace are presentation details; an invalid write must preserve state.
local ok, value = addon:SetLocalCommandOutputDestination(" SYSTEM ")
assert(ok and value == "system"
	and smart.localCommandOutput.destination == "system",
	"System destination setter did not normalize and persist its value")
ok, value = addon:SetLocalCommandOutputDestination("ACTIVE")
assert(ok and value == "active"
	and smart.localCommandOutput.destination == "active",
	"Active destination setter did not normalize and persist its value")
ok, value = addon:SetLocalCommandOutputDestination("general")
assert(not ok and value == "invalid-destination"
	and smart.localCommandOutput.destination == "active",
	"invalid destination was accepted or changed the saved preference")
ok, value = addon:SetLocalCommandOutputDestination(nil)
assert(not ok and value == "invalid-destination"
	and smart.localCommandOutput.destination == "active",
	"non-string destination was accepted or changed the saved preference")

local refreshes = 0
addon.MessageEngine = {
	RefreshLocalCommandCapture = function()
		refreshes = refreshes + 1
	end,
}

-- Enable writes are deliberately boolean-strict and immediately refresh the
-- live command bridge. Invalid writes neither mutate nor refresh it.
ok, value = addon:SetLocalCommandOutputEnabled("false")
assert(not ok and value == "boolean-required"
	and smart.localCommandOutput.enabled == false and refreshes == 0,
	"non-boolean enable write was accepted, mutated, or refreshed")
ok, value = addon:SetLocalCommandOutputEnabled(true)
assert(ok and value == true and smart.localCommandOutput.enabled == true
	and refreshes == 1,
	"enable setter did not persist and refresh command capture")
ok, value = addon:SetLocalCommandOutputCaptureEnabled(false)
assert(ok and value == false and smart.localCommandOutput.enabled == false
	and refreshes == 2,
	"descriptive enable alias did not persist and refresh command capture")

print("Local command output settings mock tests passed")
