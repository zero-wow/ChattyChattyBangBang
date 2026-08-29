-- Blizzard chat-color bridge.
--
-- Smart Dock owns the chat surface, but the player's existing Blizzard chat
-- colors remain the right source of truth for where a message came from.  This
-- service deliberately edits that native color table through ChangeChatColor
-- instead of creating a second, competing SavedVariables color system.
local addon = ChattyChattyBangBang

local ChangeChatColor = _G.ChangeChatColor
local ChatTypeInfo = _G.ChatTypeInfo
local GetChannelList = _G.GetChannelList
local GetChannelName = _G.GetChannelName
local GetMessageTypeColor = _G.GetMessageTypeColor
local floor = math.floor

local ChatColors = {}
addon.ChatColors = ChatColors

-- These are the human-chat sources Smart Dock currently captures and labels.
-- Keep the list intentionally scoped to visible Chatty traffic: combat-log and
-- NPC color groups remain Blizzard's domain and would add noise to this panel.
local staticDefinitions = {
	{ id = "say", label = "SAY", colorType = "SAY", group = "LOCAL" },
	{ id = "yell", label = "YELL", colorType = "YELL", group = "LOCAL" },
	{ id = "emote", label = "EMOTES", colorType = "EMOTE", group = "LOCAL" },
	{ id = "whisper", label = "WHISPERS", colorType = "WHISPER", group = "DIRECT" },
	{ id = "whisperInform", label = "WHISPERS SENT", colorType = "WHISPER_INFORM", group = "DIRECT" },
	{ id = "bnetWhisper", label = "BATTLE.NET WHISPERS", colorType = "BN_WHISPER", group = "DIRECT" },
	{ id = "bnetWhisperInform", label = "BATTLE.NET SENT", colorType = "BN_WHISPER_INFORM", group = "DIRECT" },
	{ id = "bnetConversation", label = "BATTLE.NET CONVERSATIONS", colorType = "BN_CONVERSATION", group = "DIRECT" },
	{ id = "afk", label = "AFK REPLIES", colorType = "AFK", group = "DIRECT" },
	{ id = "dnd", label = "DND REPLIES", colorType = "DND", group = "DIRECT" },
	{ id = "guild", label = "GUILD", colorType = "GUILD", group = "COMMUNITIES" },
	{ id = "officer", label = "OFFICER", colorType = "OFFICER", group = "COMMUNITIES" },
	{ id = "party", label = "PARTY", colorType = "PARTY", group = "GROUP" },
	{ id = "partyLeader", label = "PARTY LEADER", colorType = "PARTY_LEADER", group = "GROUP" },
	{ id = "raid", label = "RAID", colorType = "RAID", group = "GROUP" },
	{ id = "raidLeader", label = "RAID LEADER", colorType = "RAID_LEADER", group = "GROUP" },
	{ id = "raidWarning", label = "RAID WARNING", colorType = "RAID_WARNING", group = "GROUP" },
	{ id = "battleground", label = "BATTLEGROUND", colorType = "BATTLEGROUND", group = "PVP" },
	{ id = "battlegroundLeader", label = "BATTLEGROUND LEADER", colorType = "BATTLEGROUND_LEADER", group = "PVP" },
	{ id = "instance", label = "INSTANCE", colorType = "INSTANCE_CHAT", group = "GROUP" },
	{ id = "instanceLeader", label = "INSTANCE LEADER", colorType = "INSTANCE_CHAT_LEADER", group = "GROUP" },
	{ id = "system", label = "SYSTEM", colorType = "SYSTEM", group = "SYSTEM" },
	{ id = "errors", label = "ERRORS", colorType = "ERRORS", group = "SYSTEM" },
	{ id = "loot", label = "LOOT", colorType = "LOOT", group = "SYSTEM" },
	{ id = "money", label = "MONEY", colorType = "MONEY", group = "SYSTEM" },
	{ id = "achievement", label = "ACHIEVEMENTS", colorType = "ACHIEVEMENT", group = "SYSTEM" },
	{ id = "bgNeutral", label = "PVP / DEFENSE NOTICES", colorType = "BG_SYSTEM_NEUTRAL", group = "PVP" },
	{ id = "bgAlliance", label = "ALLIANCE NOTICES", colorType = "BG_SYSTEM_ALLIANCE", group = "PVP" },
	{ id = "bgHorde", label = "HORDE NOTICES", colorType = "BG_SYSTEM_HORDE", group = "PVP" },
	{ id = "channels", label = "OTHER CHANNELS", colorType = "CHANNEL", group = "CHANNELS" },
}

local eventColorTypes = {
	CHAT_MSG_SAY = "SAY",
	CHAT_MSG_YELL = "YELL",
	CHAT_MSG_EMOTE = "EMOTE",
	CHAT_MSG_TEXT_EMOTE = "EMOTE",
	CHAT_MSG_WHISPER = "WHISPER",
	CHAT_MSG_WHISPER_INFORM = "WHISPER_INFORM",
	CHAT_MSG_BN_WHISPER = "BN_WHISPER",
	CHAT_MSG_BN_WHISPER_INFORM = "BN_WHISPER_INFORM",
	CHAT_MSG_BN_CONVERSATION = "BN_CONVERSATION",
	CHAT_MSG_AFK = "AFK",
	CHAT_MSG_DND = "DND",
	CHAT_MSG_GUILD = "GUILD",
	CHAT_MSG_GUILD_ACHIEVEMENT = "GUILD",
	CHAT_MSG_OFFICER = "OFFICER",
	CHAT_MSG_PARTY = "PARTY",
	CHAT_MSG_PARTY_LEADER = "PARTY_LEADER",
	CHAT_MSG_RAID = "RAID",
	CHAT_MSG_RAID_LEADER = "RAID_LEADER",
	CHAT_MSG_RAID_WARNING = "RAID_WARNING",
	CHAT_MSG_BATTLEGROUND = "BATTLEGROUND",
	CHAT_MSG_BATTLEGROUND_LEADER = "BATTLEGROUND_LEADER",
	CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT",
	CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT_LEADER",
	CHAT_MSG_SYSTEM = "SYSTEM",
	UI_ERROR_MESSAGE = "ERRORS",
	CHAT_MSG_LOOT = "LOOT",
	CHAT_MSG_MONEY = "MONEY",
	CHAT_MSG_ACHIEVEMENT = "ACHIEVEMENT",
	CHAT_MSG_BG_SYSTEM_NEUTRAL = "BG_SYSTEM_NEUTRAL",
	CHAT_MSG_BG_SYSTEM_ALLIANCE = "BG_SYSTEM_ALLIANCE",
	CHAT_MSG_BG_SYSTEM_HORDE = "BG_SYSTEM_HORDE",
	CHAT_MSG_ZONE_UNDER_ATTACK = "BG_SYSTEM_NEUTRAL",
}

local function copyDefinition(definition)
	return {
		id = definition.id,
		label = definition.label,
		colorType = definition.colorType,
		group = definition.group,
		channel = definition.channel,
	}
end

local function normalizeChannelName(name)
	name = tostring(name or "")
	name = string.gsub(name, "^%d+%.%s*", "")
	return name
end

local function getColor(colorType)
	if type(colorType) ~= "string" or colorType == "" then
		return nil
	end
	if GetMessageTypeColor then
		local red, green, blue = GetMessageTypeColor(colorType)
		if type(red) == "number" and type(green) == "number" and type(blue) == "number" then
			return red, green, blue
		end
	end
	local color = ChatTypeInfo and ChatTypeInfo[colorType]
	if type(color) == "table" and type(color.r) == "number" and type(color.g) == "number" and type(color.b) == "number" then
		return color.r, color.g, color.b
	end
	return nil
end

local function getChannelColorType(record)
	if type(record) ~= "table" then
		return "CHANNEL"
	end
	local channel = record.channel
	if GetChannelName and type(channel) == "string" and channel ~= "" then
		-- Keep the native function's first return in a local before tonumber:
		-- on some clients it also returns the channel name, which Lua would
		-- otherwise accidentally pass as tonumber's optional base argument.
		local currentNumber = GetChannelName(normalizeChannelName(channel))
		local number = tonumber(currentNumber)
		if number and number > 0 then
			return "CHANNEL" .. tostring(number)
		end
		-- Do not borrow an old numeric slot when a saved channel name is no
		-- longer joined. Slot reuse would recolor historical lines incorrectly.
		return "CHANNEL"
	end
	local number = tonumber(record.channelNumber)
	if number and number > 0 then
		return "CHANNEL" .. tostring(number)
	end
	return "CHANNEL"
end

function addon:GetChatColorTypeForRecord(record)
	if type(record) ~= "table" then
		return nil
	end
	if record.event == "CHAT_MSG_CHANNEL" then
		return getChannelColorType(record)
	end
	return eventColorTypes[record.event]
end

function addon:GetChatColorForRecord(record)
	local colorType = self:GetChatColorTypeForRecord(record)
	if not colorType then
		return nil
	end
	return getColor(colorType)
end

local function appendActiveChannelDefinitions(definitions)
	if not GetChannelList then
		return
	end
	local channels = { GetChannelList() }
	for index = 1, #channels, 2 do
		local number = tonumber(channels[index])
		local name = normalizeChannelName(channels[index + 1])
		if number and number > 0 and name ~= "" then
			table.insert(definitions, {
				id = "channel:" .. tostring(number),
				label = string.upper(name),
				colorType = "CHANNEL" .. tostring(number),
				group = "CHANNELS",
				channel = name,
			})
		end
	end
end

function addon:GetChatColorDefinitions()
	local definitions = {}
	for index = 1, #staticDefinitions do
		local definition = copyDefinition(staticDefinitions[index])
		local red, green, blue = getColor(definition.colorType)
		-- Only offer actual color groups exposed by this client.  Ascension's
		-- WotLK-derived API differs from later clients, so an unavailable retail
		-- group should not become a misleading no-op row in the editor.
		if red then
			definition.r, definition.g, definition.b = red, green, blue
			definitions[#definitions + 1] = definition
		end
	end
	local channelDefinitions = {}
	appendActiveChannelDefinitions(channelDefinitions)
	for index = 1, #channelDefinitions do
		local definition = channelDefinitions[index]
		local red, green, blue = getColor(definition.colorType)
		if red then
			definition.r, definition.g, definition.b = red, green, blue
			definitions[#definitions + 1] = definition
		end
	end
	table.sort(definitions, function(left, right)
		if left.group ~= right.group then
			return left.group < right.group
		end
		return left.label < right.label
	end)
	return definitions
end

function addon:GetChatColorDefinition(id)
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local definitions = self:GetChatColorDefinitions()
	for index = 1, #definitions do
		if definitions[index].id == id then
			return definitions[index]
		end
	end
	return nil
end

local function clampComponent(value)
	value = tonumber(value)
	if not value then
		return nil
	end
	if value < 0 then
		return 0
	elseif value > 1 then
		return 1
	end
	return value
end

function addon:SetChatColor(id, red, green, blue)
	local definition = self:GetChatColorDefinition(id)
	if not definition then
		return false, "not-found"
	end
	red, green, blue = clampComponent(red), clampComponent(green), clampComponent(blue)
	if red == nil or green == nil or blue == nil then
		return false, "invalid-color"
	end

	local applied = false
	if type(ChangeChatColor) == "function" then
		local ok = pcall(ChangeChatColor, definition.colorType, red, green, blue)
		applied = ok
	end
	if not applied and type(ChatTypeInfo) == "table" then
		local color = ChatTypeInfo[definition.colorType]
		if type(color) == "table" then
			color.r, color.g, color.b = red, green, blue
			applied = true
		end
	end
	if not applied then
		return false, "unavailable"
	end

	-- Most clients broadcast UPDATE_CHAT_COLOR, but explicitly repaint too so
	-- the visible Smart Dock updates immediately on forks that do not.
	local dock = self.SmartDock
	if dock and dock.RebuildActiveView then
		dock:RebuildActiveView()
	end
	return true, { r = red, g = green, b = blue, colorType = definition.colorType }
end

function addon:GetChatColorComponentText(red, green, blue)
	return tostring(floor((red or 0) * 255 + 0.5)), tostring(floor((green or 0) * 255 + 0.5)), tostring(floor((blue or 0) * 255 + 0.5))
end
