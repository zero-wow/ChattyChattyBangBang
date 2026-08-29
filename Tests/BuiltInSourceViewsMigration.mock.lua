-- Focused no-client migration contract for the first built-in public-source
-- views. Run from the addon root with:
--   lua Tests/BuiltInSourceViewsMigration.mock.lua

ChattyChattyBangBang = {
	db = {
		profile = {
			smartChat = {
				views = { custom1 = true, custom2 = true },
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
					custom1 = {
						sources = {
							["channel:ascension"] = false,
							["channel:trade"] = false,
							["channel:guildrecruitment"] = false,
						},
					},
				},
				dock = { activeView = "custom1" },
				channelTargets = { custom1 = 6 },
			},
		},
	},
}

dofile("Core/Settings.lua")

local addon = ChattyChattyBangBang
local settings = addon:GetSmartSettings()
local definitions = addon:GetSmartViews()

assert(settings.builtInSourceViewsSchema == 2, "built-in source-view migration schema was not recorded")
assert(settings.dock.activeView == "newcomers", "active exact NC custom view was not transferred")
assert(settings.channelTargets.newcomers == 6 and settings.channelTargets.custom1 == nil,
	"exact NC composer target was not transferred")
assert(settings.views.newcomers == true and settings.views.custom1 == nil,
	"exact NC visibility was not transferred")
assert(settings.viewOptions.custom1 == nil, "retired exact NC source options were retained")
assert(#settings.customViews == 1 and settings.customViews[1].id == "custom2",
	"migration removed a broader user-authored Newcomers custom view")

local positions, byId = {}, {}
for index = 1, #definitions do
	positions[definitions[index].id] = index
	byId[definitions[index].id] = definitions[index]
end
assert(byId.newcomers and byId.newcomers.key == "NC" and byId.newcomers.label == "NEWCOMERS",
	"built-in Newcomers definition is missing or mislabeled")
assert(byId.guildInvites and byId.guildInvites.key == "GU INV" and byId.guildInvites.label == "GUILD INVITES",
	"built-in Guild Invites definition is missing or mislabeled")
assert(byId.pvp and byId.pvp.key == "PVP" and byId.pvp.label == "PVP",
	"built-in PVP definition is missing or mislabeled")
assert(positions.newcomers == positions.general + 1,
	"migrated Newcomers rail did not remain beside General")
assert(positions.guildInvites == positions.groupFinder + 1,
	"new Guild Invites rail was not inserted beside Group Finder")
assert(positions.pvp == positions.guildInvites + 1,
	"new PVP rail was not inserted beside Guild Invites")
assert(positions.custom2 ~= nil, "broader Newcomers custom rail disappeared from the order")

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

print("Built-in source-view migration mock passed")
