-- Focused no-client contract for the persistent Blocked Messages settings.
-- Run from the addon root with: lua Tests/BlockedMessageArchiveSettings.mock.lua

ChattyChattyBangBang = {
	db = {
		profile = {
			smartChat = {
				blocks = {
					archive = {
						enabled = false,
						maxEntries = 3,
						retentionDays = 999,
						nextSequence = -4,
						entries = "corrupt",
					},
				},
			},
		},
	},
}

dofile("Core/Settings.lua")
local addon = ChattyChattyBangBang
local settings = addon:GetSmartSettings()
local archive = settings.blocks.archive
assert(archive.schema == 1 and archive.enabled == false,
	"archive schema normalization overwrote an explicit privacy choice")
assert(archive.maxEntries == 25 and archive.retentionDays == 90
	and archive.nextSequence == 1 and type(archive.entries) == "table",
	"malformed archive bounds/shape were not normalized safely")

addon.db.profile.smartChat = {}
settings = addon:GetSmartSettings()
archive = settings.blocks.archive
assert(archive.schema == 1 and archive.enabled == true
	and archive.maxEntries == 500 and archive.retentionDays == 7
	and archive.nextSequence == 1 and type(archive.entries) == "table",
	"new profiles did not receive bounded blocked-message archive defaults")

print("Blocked message archive settings mock passed")
