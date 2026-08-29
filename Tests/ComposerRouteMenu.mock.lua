-- Focused no-client contract for the Smart Dock composer route selector.
-- Run from the addon root with: lua Tests/ComposerRouteMenu.mock.lua

local settings = {
	dock = { activeView = "general" },
	channelTargets = {},
}
local headerUpdates = 0
local lastToldTarget
local requestedMessageTypes = {}

GetNumRaidMembers = function() return 0 end
GetNumPartyMembers = function() return 2 end
local activeInstanceType = "none"
IsInInstance = function() return activeInstanceType ~= "none", activeInstanceType end
IsInGuild = function() return true end
GetChannelList = function()
	return 1, "General", 2, "Trade"
end
GetChannelName = function(id)
	if id == 1 then return 1, "General" end
	if id == 2 then return 2, "Trade" end
	return 0, ""
end
ChatEdit_UpdateHeader = function()
	headerUpdates = headerUpdates + 1
end
ChatEdit_SetLastToldTarget = function(target)
	lastToldTarget = target
end
GetMessageTypeColor = function(messageType)
	requestedMessageTypes[#requestedMessageTypes + 1] = messageType
	if messageType == "CHANNEL2" then
		return 0.12, 0.34, 0.56
	elseif messageType == "GUILD" then
		return 0.25, 0.75, 0.25
	end
end

ChattyChattyBangBang = {
	Theme = {},
	Presentation = {},
	GetSmartSettings = function()
		return settings
	end,
}

dofile("Core/SmartDock.lua")

local dock = ChattyChattyBangBang.SmartDock
dock.activeView = "group"

local choices = dock:GetComposerRouteChoices()
local found = {}
for _, choice in ipairs(choices) do
	found[choice.label] = choice
end
assert(found.SAY and found.YELL and found.PARTY and found.GUILD,
	"composer route menu omitted ordinary public/group choices")
assert(found["#GENERAL"] and found["#TRADE"], "composer route menu omitted joined channels")
local r, g, b = dock:GetComposerRouteColor("CHANNEL", 2)
assert(r == 0.12 and g == 0.34 and b == 0.56 and requestedMessageTypes[#requestedMessageTypes] == "CHANNEL2",
	"numbered channel route did not use Blizzard's live channel color")
r, g, b = dock:GetComposerRouteColor("GUILD")
assert(r == 0.25 and g == 0.75 and b == 0.25, "chat type route did not use Blizzard's live chat color")

local attributes = {}
dock.editBox = {
	SetAttribute = function(_, key, value)
		attributes[key] = value
	end,
}

assert(dock:SetComposerRoute("CHANNEL", 2), "could not select a joined channel")
assert(attributes.chatType == "CHANNEL" and attributes.channelTarget == 2 and attributes.tellTarget == nil,
	"channel route left a stale target or wrote the wrong attributes")
assert(headerUpdates == 1, "channel route did not update Blizzard's edit-box header")
assert(dock:GetComposerRoute() == "CHANNEL", "selected channel did not become the active route")

assert(dock:SetComposerRoute("WHISPER", "Tester-Realm"), "could not select a reply target")
assert(attributes.chatType == "WHISPER" and attributes.tellTarget == "Tester-Realm" and attributes.channelTarget == nil,
	"whisper route left a stale channel target or wrote the wrong attributes")
assert(lastToldTarget == "Tester-Realm", "whisper route did not retain Blizzard's last-told target")
assert(dock:GetComposerRouteLabel("CHANNEL", 2) == "#TRADE", "channel route label is not human-readable")
assert(dock:GetComposerRouteLabel("WHISPER", "Tester-Realm") == "REPLY", "whisper route label is not compact")

-- Custom views are ordinary writable tabs. Their useful default is the newest
-- numbered public channel currently visible in that custom filter.
settings.views = {
	general = true,
	newcomers = true,
	groupFinder = true,
	guildInvites = true,
	pvp = true,
	trade = true,
	customNewcomers = true,
	customNoChannel = true,
	customSavedChannel = true,
	sync = true,
}
ChattyChattyBangBang.GetSmartViews = function()
	return {
		{ id = "general", key = "G", label = "General", enabled = true },
		{ id = "newcomers", key = "NC", label = "Newcomers", enabled = true },
		{ id = "groupFinder", key = "LFG", label = "Group Finder", enabled = true },
		{ id = "guildInvites", key = "GU INV", label = "Guild Invites", enabled = true },
		{ id = "pvp", key = "PVP", label = "PVP", enabled = true },
		{ id = "trade", key = "T", label = "Trade", enabled = true },
		{ id = "customNewcomers", key = "NC", label = "Newcomers", custom = true, enabled = true },
		{ id = "customNoChannel", key = "TXT", label = "Text view", custom = true, enabled = true },
		{ id = "customSavedChannel", key = "OLD", label = "Saved channel view", custom = true, enabled = true },
		{ id = "sync", key = "SYNC", label = "Sync", enabled = true },
	}
end
ChattyChattyBangBang.MessageEngine = {
	GetMessages = function(_, viewId)
		if viewId == "customNewcomers" then
			return {
				{ event = "CHAT_MSG_CHANNEL", channelNumber = 1 },
				{ event = "CHAT_MSG_CHANNEL", channelNumber = 2 },
			}
		end
		return { { event = "CHAT_MSG_SYSTEM", channelNumber = 9 } }
	end,
}
dock:RefreshViewDefinitions()
dock.activeView = "customNewcomers"
assert(not dock:IsReadOnlyView(), "custom channel view was incorrectly read only")
local suggestedRoute, suggestedTarget = dock:GetSuggestedComposerRoute()
assert(suggestedRoute == "CHANNEL" and suggestedTarget == 2,
	"custom channel view did not use its latest visible numbered channel")
assert(settings.channelTargets.customNewcomers == 2,
	"custom channel default was not retained as its useful saved fallback")

dock.activeView = "customNoChannel"
suggestedRoute, suggestedTarget = dock:GetSuggestedComposerRoute()
assert(suggestedRoute == "SAY" and suggestedTarget == nil and not dock:IsReadOnlyView(),
	"custom text-only view was not writable with a usable Say fallback")

settings.channelTargets.customSavedChannel = 1
dock.activeView = "customSavedChannel"
suggestedRoute, suggestedTarget = dock:GetSuggestedComposerRoute()
assert(suggestedRoute == "CHANNEL" and suggestedTarget == 1,
	"custom view did not retain a saved numbered-channel fallback")

-- Factual public-source rails retain the numbered channel observed by the
-- engine. They remain writable just like Group Finder and Trade.
settings.channelTargets.newcomers = 2
settings.channelTargets.guildInvites = 1
settings.channelTargets.pvp = 1
dock.activeView = "newcomers"
suggestedRoute, suggestedTarget = dock:GetSuggestedComposerRoute()
assert(suggestedRoute == "CHANNEL" and suggestedTarget == 2 and not dock:IsReadOnlyView(),
	"built-in Newcomers view did not retain a writable numbered-channel target")
dock.activeView = "guildInvites"
suggestedRoute, suggestedTarget = dock:GetSuggestedComposerRoute()
assert(suggestedRoute == "CHANNEL" and suggestedTarget == 1 and not dock:IsReadOnlyView(),
	"built-in Guild Invites view did not retain a writable numbered-channel target")
dock.activeView = "pvp"
suggestedRoute, suggestedTarget = dock:GetSuggestedComposerRoute()
assert(suggestedRoute == "CHANNEL" and suggestedTarget == 1 and not dock:IsReadOnlyView(),
	"PVP view did not retain its latest writable Defense channel target")
activeInstanceType = "pvp"
suggestedRoute, suggestedTarget = dock:GetSuggestedComposerRoute()
assert(suggestedRoute == "BATTLEGROUND" and suggestedTarget == nil,
	"PVP view did not prefer Battleground chat while inside a battleground")
activeInstanceType = "none"

-- The manual route is session-local per view. Switching tabs must not discard
-- Newcomers' channel choice or leak it into General.
dock.title = { SetText = function() end }
dock.subtitle = { SetText = function() end, Hide = function() end }
dock.RefreshRailState = function() end
dock.UpdateComposerState = function() end
dock.HidePlayerActions = function() end
dock.ApplySmartChatTextAppearance = function() end
dock.RebuildActiveView = function() end
dock.unread = {}
dock.activeView = "customNewcomers"
assert(dock:SetComposerRoute("CHANNEL", 2), "custom view could not set its channel route")
dock:SelectView("general")
assert(dock:SetComposerRoute("YELL"), "general tab could not set its own route")
dock:SelectView("customNewcomers")
local restoredRoute, restoredTarget = dock:GetComposerRoute()
assert(restoredRoute == "CHANNEL" and restoredTarget == 2,
	"switching tabs discarded the custom view's manual composer route")
assert(dock:IsReadOnlyView("system") == false and dock:IsReadOnlyView("loot") == false
	and dock:IsReadOnlyView("sync") == true,
	"only protocol Sync should remain read only")

dock.IsReadOnlyView = function() return true end
assert(not dock:SetComposerRoute("SAY"), "read-only views accepted a composer route")

print("Composer route-menu mock tests passed")
