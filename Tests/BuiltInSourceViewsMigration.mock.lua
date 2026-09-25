-- Focused no-client migration contract for surviving built-in source views
-- and retirement of the Retail-only Newcomers rail. Run from the addon root:
--   lua Tests/BuiltInSourceViewsMigration.mock.lua

ChattyChattyBangBang = {
	db = {
		profile = {
			smartChat = {
				views = { custom1 = true, custom2 = true, newcomers = true },
				railOrder = { "general", "custom1", "groupFinder", "trade", "custom2" },
				customViewSequence = 2,
				customViewRevision = 7,
				customViews = {
					{
						id = "custom1",
						key = "NC",
						label = "NEWCOMERS",
						description = "Newcomers Channel",
						terms = { "newcomers" },
						enabled = true,
						custom = true,
					},
					{
						id = "custom2",
						key = "NC2",
						label = "NEWCOMERS PLUS",
						terms = { "newcomers", "welcome" },
						enabled = true,
						custom = true,
					},
				},
				viewOptions = {
					newcomers = { label = "Old built-in NC" },
					custom1 = {
						sources = {
							["channel:ascension"] = false,
							["channel:trade"] = false,
							["channel:guildrecruitment"] = false,
						},
					},
				},
				dock = { activeView = "newcomers" },
				channelTargets = { custom1 = 6, newcomers = 7 },
				messageRouteOverrides = { ["old routing"] = "newcomers" },
				messageRouteOverrideSchema = 2,
			},
		},
	},
}

dofile("Core/Settings.lua")

local addon = ChattyChattyBangBang
local settings = addon:GetSmartSettings()
local definitions = addon:GetSmartViews()

assert(settings.builtInSourceViewsSchema == 2, "built-in source-view migration schema was not recorded")
assert(settings.retiredNewcomersViewSchema == 1, "Retail Newcomers retirement was not recorded")
assert(settings.dock.activeView == "general", "active retired NC rail was not reset to General")
assert(settings.channelTargets.newcomers == nil and settings.channelTargets.custom1 == 6,
	"retirement removed a custom composer target or kept the built-in target")
assert(settings.views.newcomers == nil and settings.views.custom1 == true,
	"retirement removed custom visibility or kept built-in visibility")
assert(settings.viewOptions.newcomers == nil and settings.viewOptions.custom1 ~= nil,
	"retirement removed custom options or kept built-in options")
assert(#settings.customViews == 2 and settings.customViews[1].id == "custom1"
	and settings.customViews[2].id == "custom2",
	"retirement removed a user-authored custom view")
assert(settings.messageRouteOverrides["old routing"] == nil,
	"retired Newcomers route override survived migration")

local positions, byId = {}, {}
for index = 1, #definitions do
	positions[definitions[index].id] = index
	byId[definitions[index].id] = definitions[index]
end
assert(not byId.newcomers and positions.newcomers == nil,
	"retired built-in Newcomers rail was resurrected")
assert(byId.guildInvites and byId.guildInvites.key == "GU INV" and byId.guildInvites.label == "GUILD INVITES",
	"built-in Guild Invites definition is missing or mislabeled")
assert(byId.pvp and byId.pvp.key == "PVP" and byId.pvp.label == "PVP",
	"built-in PVP definition is missing or mislabeled")
assert(positions.guildInvites == positions.groupFinder + 1,
	"new Guild Invites rail was not inserted beside Group Finder")
assert(positions.pvp == positions.guildInvites + 1,
	"new PVP rail was not inserted beside Guild Invites")
assert(positions.custom1 ~= nil and positions.custom2 ~= nil,
	"user-created custom rails disappeared from the order")

-- Upgrading a schema-1 profile must anchor only the new PVP rail. Existing
-- built-ins and custom rails retain their saved relative order.
addon.db.profile.smartChat = {
	builtInSourceViewsSchema = 1,
	views = { custom2 = true },
	railOrder = { "trade", "custom2", "groupFinder", "guildInvites", "general", "loot" },
	customViewSequence = 2,
	customViewRevision = 8,
	customViews = {
		{ id = "custom2", key = "X", label = "MY VIEW", terms = { "mine" }, enabled = true, custom = true },
	},
}
settings = addon:GetSmartSettings()
definitions = addon:GetSmartViews()
positions = {}
for index = 1, #definitions do positions[definitions[index].id] = index end
assert(settings.builtInSourceViewsSchema == 2, "schema-1 profile did not advance to the PVP schema")
assert(positions.trade == 1 and positions.custom2 == 2 and positions.groupFinder == 3
	and positions.guildInvites == 4 and positions.pvp == 5 and positions.general == 6
	and positions.general < positions.loot,
	"PVP migration disturbed an existing/custom rail order instead of using its anchor: "
		.. table.concat(settings.railOrder, ","))
assert(settings.views.pvp == true, "PVP did not default visible during migration")

-- An already-upgraded profile can still carry the retired built-in in saved
-- state. Its one-time cleanup must not depend on rerunning the old migration.
addon.db.profile.smartChat = {
	builtInSourceViewsSchema = 2,
	views = { newcomers = false },
	railOrder = { "trade", "newcomers", "general" },
	viewOptions = { newcomers = { label = "Legacy" } },
	channelTargets = { newcomers = 5 },
	dock = { activeView = "newcomers" },
}
settings = addon:GetSmartSettings()
definitions = addon:GetSmartViews()
assert(settings.views.newcomers == nil and settings.viewOptions.newcomers == nil
	and settings.channelTargets.newcomers == nil and settings.dock.activeView == "general",
	"upgraded profile retained stale NC settings")
for index = 1, #definitions do
	assert(definitions[index].id ~= "newcomers", "upgraded profile restored the NC tab")
end

print("Built-in source-view migration mock passed")
