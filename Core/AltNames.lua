-- User-entered character associations are a history-reading aid only. Never
-- use this table for sender identity, trust, whispers, ignore, or block rules.
local addon = ChattyChattyBangBang
local AltNames = {}
addon.AltNames = AltNames

local MAX_GROUPS, MAX_NAMES, MAX_NAME_BYTES = 32, 8, 80
local MAX_NAME_CHARACTERS = 32
local MAX_GROUP_ID = 1000000

local function asciiLower(value)
	return (value:gsub("[A-Z]", string.lower))
end

local function nameKey(value)
	if type(value) ~= "string" then return nil end
	value = value:match("^%s*(.-)%s*$")
	if value == "" or #value > MAX_NAME_BYTES or value:find("[|#<>{}%[%]\\/]", 1)
		or value:find("[%c]", 1) or value:find("^%-") or value:find("%-$") then
		return nil
	end
	-- Realm spelling is exact. Spaces are accepted only inside a qualified
	-- realm (e.g. Name-Twisting Nether), never as a fuzzy short-name match.
	local realmStart = value:find("-", 1, true)
	local characters, index = 0, 1
	while index <= #value do
		local byte = value:byte(index)
		if byte < 128 then
			local letter = (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)
			local realmCharacter = realmStart and index > realmStart
			local digit = byte >= 48 and byte <= 57
			if not (letter or (realmCharacter and digit) or byte == 45 or byte == 39
				or (byte == 32 and realmCharacter and index < #value
					and value:byte(index - 1) ~= 32 and value:byte(index - 1) ~= 45
					and value:byte(index + 1) ~= 32 and value:byte(index + 1) ~= 45)) then return nil end
			index = index + 1
		else
			-- Strict UTF-8 scalar validation; Lua 5.1 cannot case-fold it.
			local length = byte >= 194 and byte <= 223 and 2
				or byte >= 224 and byte <= 239 and 3
				or byte >= 240 and byte <= 244 and 4 or nil
			if not length or index + length - 1 > #value then return nil end
			local second = value:byte(index + 1)
			if second < 128 or second > 191
				or byte == 224 and second < 160 or byte == 237 and second > 159
				or byte == 240 and second < 144 or byte == 244 and second > 143 then return nil end
			for offset = 2, length - 1 do
				local continuation = value:byte(index + offset)
				if continuation < 128 or continuation > 191 then return nil end
			end
			index = index + length
		end
		characters = characters + 1
	end
	if characters < 2 or characters > MAX_NAME_CHARACTERS then return nil end
	return asciiLower(value), value
end

local function getStore()
	local settings = addon.GetSmartSettings and addon:GetSmartSettings()
	if type(settings) ~= "table" then return nil end
	local stored = settings.altNameGroups
	if type(stored) ~= "table" then
		stored = { schema = 1, nextId = 1, groups = {} }
		settings.altNameGroups = stored
	end
	if type(stored.groups) ~= "table" then stored.groups = {} end
	local clean, used, usedIds, highest = {}, {}, {}, 0
	for index = 1, math.min(#stored.groups, MAX_GROUPS) do
		local group = stored.groups[index]
		if type(group) == "table" and type(group.names) == "table" then
			local id = tonumber(group.id)
			if id and id == id and id ~= math.huge and id ~= -math.huge
				and id == math.floor(id) and id >= 1 and id <= MAX_GROUP_ID
				and not usedIds[id] then
				local names = {}
				for member = 1, math.min(#group.names, MAX_NAMES) do
					local key, display = nameKey(group.names[member])
					if key and not used[key] then
						used[key] = true
						names[#names + 1] = display
					end
				end
				if #names >= 2 then
					clean[#clean + 1] = { id = id, names = names }
					usedIds[id] = true
					if id > highest then highest = id end
				else
					for _, name in ipairs(names) do used[asciiLower(name)] = nil end
				end
			end
		end
	end
	stored.schema = 1
	stored.groups = clean
	local nextId = tonumber(stored.nextId)
	if not nextId or nextId ~= nextId or nextId == math.huge or nextId == -math.huge
		or nextId < 1 or nextId > MAX_GROUP_ID then nextId = highest + 1 end
	stored.nextId = math.floor(nextId)
	if stored.nextId > MAX_GROUP_ID then stored.nextId = 1 end
	return stored
end

local function findName(groups, key)
	for _, group in ipairs(groups) do
		for _, name in ipairs(group.names) do
			if asciiLower(name) == key then return group end
		end
	end
	return nil
end

function AltNames:GetGroups()
	local store = getStore()
	local result = {}
	if not store then return result end
	for _, group in ipairs(store.groups) do
		local names = {}
		for index, name in ipairs(group.names) do names[index] = name end
		result[#result + 1] = { id = group.id, names = names }
	end
	return result
end

function AltNames:Link(nameA, nameB)
	local keyA, displayA = nameKey(nameA)
	local keyB, displayB = nameKey(nameB)
	if not keyA or not keyB or keyA == keyB then return false, "Enter two different character names." end
	local store = getStore()
	if not store then return false, "Settings are not ready." end
	local first = findName(store.groups, keyA)
	local second = findName(store.groups, keyB)
	if first and second then
		if first == second then return false, "Those names are already linked." end
		return false, "Names belong to different groups. Unlink one first."
	end
	local group = first or second
	if group then
		if #group.names >= MAX_NAMES then return false, "A group can hold up to 8 names." end
		group.names[#group.names + 1] = first and displayB or displayA
	else
		if #store.groups >= MAX_GROUPS then return false, "You can save up to 32 groups." end
		local usedIds = {}
		for _, existing in ipairs(store.groups) do usedIds[existing.id] = true end
		local id = store.nextId
		while usedIds[id] do id = id == MAX_GROUP_ID and 1 or id + 1 end
		group = { id = id, names = { displayA, displayB } }
		store.nextId = id == MAX_GROUP_ID and 1 or id + 1
		store.groups[#store.groups + 1] = group
	end
	return true, group.id
end

function AltNames:Unlink(name)
	local key = nameKey(name)
	if not key then return false, "Enter a valid character name." end
	local store = getStore()
	if not store then return false, "Settings are not ready." end
	for index, group in ipairs(store.groups) do
		for member, display in ipairs(group.names) do
			if asciiLower(display) == key then
				table.remove(group.names, member)
				if #group.names < 2 then table.remove(store.groups, index) end
				return true
			end
		end
	end
	return false, "That name is not linked."
end

function AltNames:RemoveGroup(id)
	local store = getStore()
	if not store then return false end
	for index, group in ipairs(store.groups) do
		if group.id == id then table.remove(store.groups, index); return true end
	end
	return false
end

function AltNames:GetHistorySenderNames(name)
	local key, display = nameKey(name)
	if not key then return nil end
	local store = getStore()
	local group = store and findName(store.groups, key)
	if not group then return { display } end
	local names = {}
	for index, member in ipairs(group.names) do names[index] = member end
	return names
end
