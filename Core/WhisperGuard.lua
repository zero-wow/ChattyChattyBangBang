local addon = ChattyChattyBangBang

-- An unsolicited whisper is private correspondence, not ordinary chat spam.
-- Keep its policy and retained review trail separate from SpamControl's flood
-- state and from the normal MessageEngine transcript.
local Guard = {}
addon.WhisperGuard = Guard

local MAX_ENTRIES = 200
local MAX_TEXT = 512
local MAX_TRUSTED = 512
local MAX_BLOCKED = 512
local RETENTION_SECONDS = 7 * 86400
local MAX_SOCIAL_CACHE = 256
local TRUSTED_CACHE_SECONDS = 2
local STRANGER_CACHE_SECONDS = 5

local function epoch()
	return time and (tonumber(time()) or 0) or 0
end

local function socialClock()
	return GetTime and (tonumber(GetTime()) or epoch()) or epoch()
end

local function trim(value, limit)
	local text = type(value) == "string" and value or ""
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	if limit and #text > limit then text = string.sub(text, 1, limit) end
	return text
end

local function normalizedName(value)
	local name = trim(value, 128)
	name = string.match(name, "|Hplayer:([^:|]+)") or name
	name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
	name = string.gsub(name, "|r", "")
	name = string.gsub(name, "^%[", "")
	name = string.gsub(name, "%]$", "")
	name = string.lower(string.gsub(name, "%s+", ""))
	if name == "" then return nil end
	if not string.find(name, "-", 1, true) then
		local realm = GetRealmName and GetRealmName() or nil
		realm = type(realm) == "string" and string.lower(string.gsub(realm, "%s+", "")) or ""
		if realm ~= "" then name = name .. "-" .. realm end
	end
	return name
end

local function bnetId(value)
	if type(value) ~= "number" or value < 1 or value > 9007199254740991
		or value % 1 ~= 0 then return nil end
	return value
end

local function controlKey(value)
	if type(value) == "string" then
		local accountId = string.match(trim(value), "^bn:(%d+)$")
		if accountId then
			accountId = bnetId(tonumber(accountId))
			return accountId and "bn:" .. tostring(accountId) or nil
		end
	end
	return normalizedName(value)
end

local function accessible(value)
	if _G.canaccessvalue then return _G.canaccessvalue(value) end
	if _G.issecretvalue then return not _G.issecretvalue(value) end
	return true
end

local function settings()
	local smart = addon.GetSmartSettings and addon:GetSmartSettings() or nil
	if type(smart) ~= "table" then return nil end
	local guard = smart.whisperGuard
	if type(guard) ~= "table" then
		guard = {}
		smart.whisperGuard = guard
	end
	if guard.enabled == nil then guard.enabled = true end
	if type(guard.trusted) ~= "table" then guard.trusted = {} end
	if type(guard.blocked) ~= "table" then guard.blocked = {} end
	if type(guard.entries) ~= "table" then guard.entries = {} end
	guard.nextId = math.max(1, math.floor(tonumber(guard.nextId) or 1))
	return guard
end

local function prune(guard)
	local entries = guard.entries
	local now = epoch()
	for index = #entries, 1, -1 do
		local entry = entries[index]
		if type(entry) ~= "table" or type(entry.senderKey) ~= "string"
			or type(entry.text) ~= "string" or not tonumber(entry.epoch)
			or (now > 0 and now - tonumber(entry.epoch) > RETENTION_SECONDS) then
			table.remove(entries, index)
		end
	end
	while #entries > MAX_ENTRIES do table.remove(entries, 1) end
	return entries
end

local function boundedTrust(guard, key, kind)
	local trusted = guard.trusted
	local count, oldestKey, oldestAt = 0, nil, nil
	for candidate, data in pairs(trusted) do
		count = count + 1
		local at = type(data) == "table" and tonumber(data.at) or 0
		if not oldestAt or at < oldestAt then oldestAt, oldestKey = at, candidate end
	end
	if not trusted[key] and count >= MAX_TRUSTED and oldestKey then trusted[oldestKey] = nil end
	trusted[key] = { kind = kind, at = epoch() }
end

local function boundedBlock(guard, key)
	local blocked = guard.blocked
	local count, oldestKey, oldestAt = 0, nil, nil
	for candidate, at in pairs(blocked) do
		count = count + 1
		at = tonumber(at) or 0
		if not oldestAt or at < oldestAt then oldestAt, oldestKey = at, candidate end
	end
	if not blocked[key] and count >= MAX_BLOCKED and oldestKey then blocked[oldestKey] = nil end
	blocked[key] = epoch()
end

local function isFriend(name, guid)
	-- Retail IsFriend takes a GUID, not a character name. Use the roster's
	-- explicit name field when the event has no usable GUID.
	if type(guid) == "string" and guid ~= "" and _G.C_FriendList
		and type(_G.C_FriendList.IsFriend) == "function" then
		local ok, result = pcall(_G.C_FriendList.IsFriend, guid)
		if ok and result == true then return true, true end
	end
	if _G.C_FriendList and type(_G.C_FriendList.GetNumFriends) == "function"
		and type(_G.C_FriendList.GetFriendInfoByIndex) == "function" then
		local ok, count = pcall(_G.C_FriendList.GetNumFriends)
		if ok and type(count) == "number" and count >= 0 then
			local target = normalizedName(name)
			local complete = count <= 500
			for index = 1, math.min(count, 500) do
				local success, info = pcall(_G.C_FriendList.GetFriendInfoByIndex, index)
				local candidate = success and type(info) == "table" and normalizedName(info.name)
				if candidate and candidate == target then
					return true, true
				end
				if not candidate then complete = false end
			end
			if complete then return false, true end
		end
	end
	if type(_G.GetNumFriends) == "function" and type(_G.GetFriendInfo) == "function" then
		local ok, count = pcall(_G.GetNumFriends)
		if ok and type(count) == "number" and count >= 0 then
			local target = normalizedName(name)
			local complete = count <= 500
			for index = 1, math.min(count, 500) do
				local success, info = pcall(_G.GetFriendInfo, index)
				local candidate = type(info) == "table" and info.name or info
				candidate = success and normalizedName(candidate)
				if candidate and candidate == target then return true, true end
				if not candidate then complete = false end
			end
			if complete then return false, true end
		end
	end
	return false, false
end

local function inGuild()
	if type(_G.IsInGuild) ~= "function" then return false end
	local ok, result = pcall(_G.IsInGuild)
	return ok and result and true or false
end

local function requestGuildRoster(self)
	local guildInfo = _G.C_GuildInfo
	local request = guildInfo and guildInfo.GuildRoster
	if type(request) ~= "function" then request = _G.GuildRoster end
	if type(request) ~= "function" then return end
	local now = GetTime and tonumber(GetTime()) or epoch()
	if self.guildRosterRequestAt and now >= self.guildRosterRequestAt
		and now - self.guildRosterRequestAt < 10 then return end
	if pcall(request) then self.guildRosterRequestAt = now end
end

local function isGuildmate(self, name)
	if not inGuild() then return false, true end
	requestGuildRoster(self)
	local guildInfo = _G.C_GuildInfo
	if guildInfo and type(guildInfo.MemberExistsByName) == "function" then
		local ok, exists = pcall(guildInfo.MemberExistsByName, name)
		-- An unavailable or still-loading roster is not proof of membership.
		return ok and exists == true,
			ok and type(exists) == "boolean" and (exists == true or self.guildRosterSeen == true)
	end
	-- Older clients expose only the indexed guild roster globals.
	if type(_G.GetNumGuildMembers) ~= "function" or type(_G.GetGuildRosterInfo) ~= "function" then
		return false, false
	end
	local target = normalizedName(name)
	local ok, count = pcall(_G.GetNumGuildMembers)
	if not ok or type(count) ~= "number" or count < 0 then return false, false end
	local complete = count > 0 and count <= 1000
	for index = 1, math.min(count, 1000) do
		local success, candidate = pcall(_G.GetGuildRosterInfo, index)
		candidate = success and normalizedName(candidate)
		if candidate and candidate == target then return true, true end
		if not candidate then complete = false end
	end
	return false, complete and self.guildRosterSeen == true
end

local SOCIAL_API_FIELDS = {
	"friendList", "isFriend", "friendCount", "friendInfo", "legacyFriendCount",
	"legacyFriendInfo", "guildInfo", "isInGuild", "guildMember", "guildCount", "guildRosterInfo",
}

local function socialApis()
	local friends, guild = _G.C_FriendList, _G.C_GuildInfo
	return {
		friendList = friends, isFriend = friends and friends.IsFriend,
		friendCount = friends and friends.GetNumFriends,
		friendInfo = friends and friends.GetFriendInfoByIndex,
		legacyFriendCount = _G.GetNumFriends, legacyFriendInfo = _G.GetFriendInfo,
		guildInfo = guild, isInGuild = _G.IsInGuild,
		guildMember = guild and guild.MemberExistsByName,
		guildCount = _G.GetNumGuildMembers, guildRosterInfo = _G.GetGuildRosterInfo,
	}
end

local function sameSocialApis(left, right)
	if not left or not right then return false end
	for _, field in ipairs(SOCIAL_API_FIELDS) do
		if left[field] ~= right[field] then return false end
	end
	return true
end

function Guard:InvalidateSocialCache()
	self.socialCache = {}
	self.socialCacheCount = 0
	self.socialCacheOrder = {}
	self.socialCacheCursor = 0
	self.socialCacheApis = nil
end

local function cachedSocialTrust(self, name, guid, key)
	local apis = socialApis()
	if not sameSocialApis(self.socialCacheApis, apis) then
		self:InvalidateSocialCache()
		self.socialCacheApis = apis
	end
	local cache = self.socialCache
	local cacheKey = key .. "\001" .. (type(guid) == "string" and guid or "")
	local now = socialClock()
	local entry = cache[cacheKey]
	if entry then
		local ttl = entry.trusted and TRUSTED_CACHE_SECONDS or STRANGER_CACHE_SECONDS
		if now >= entry.at and now - entry.at < ttl
			and (entry.kind ~= "guild" or inGuild()) then
			return entry.trusted
		end
		cache[cacheKey] = nil
		self.socialCacheCount = self.socialCacheCount - 1
	end
	local friend, friendReady = isFriend(name, guid)
	local guild, guildReady = false, false
	if not friend then guild, guildReady = isGuildmate(self, name) end
	local trusted = friend or guild
	-- Never cache a negative decision made from an unavailable or partial
	-- roster. Positive entries are short-lived and roster events invalidate them.
	if trusted or (friendReady and guildReady) then
		local slot = self.socialCacheCursor % MAX_SOCIAL_CACHE + 1
		local displaced = self.socialCacheOrder[slot]
		if displaced and cache[displaced] and cache[displaced].slot == slot then
			cache[displaced] = nil
			self.socialCacheCount = self.socialCacheCount - 1
		end
		self.socialCacheCursor = slot
		self.socialCacheOrder[slot] = cacheKey
		cache[cacheKey] = { trusted = trusted and true or false,
			kind = friend and "friend" or (guild and "guild" or nil),
			at = now, slot = slot }
		self.socialCacheCount = self.socialCacheCount + 1
	end
	return trusted
end

local function remember(guard, message, sender, key, event, accountId, lineId)
	local entries = prune(guard)
	local now = epoch()
	local text = event == "CHAT_MSG_BN_WHISPER" and message or trim(message, MAX_TEXT)
	if #text > MAX_TEXT then return false end
	if event == "CHAT_MSG_BN_WHISPER" then
		for _, entry in ipairs(entries) do
			if entry.event == event and entry.senderKey == key and entry.lineId == lineId
				and entry.text == text
				and math.abs(now - (tonumber(entry.epoch) or 0)) <= 5 then
				return true
			end
		end
	end
	local entry = {
		id = guard.nextId,
		epoch = now,
		sender = trim(sender, 128),
		senderKey = key,
		text = text,
	}
	if event == "CHAT_MSG_BN_WHISPER" then
		entry.event = event
		entry.bnetAccountId = accountId
		entry.lineId = lineId
	end
	entries[#entries + 1] = entry
	guard.nextId = guard.nextId + 1
	if #entries > MAX_ENTRIES then table.remove(entries, 1) end
	return true
end

local function shouldHoldIncoming(self, message, sender, guid)
	local guard = settings()
	if not guard or guard.enabled == false then return false end
	local key = normalizedName(sender)
	if not key or type(message) ~= "string" then return false end
	if guard.blocked[key] then return true, "blocked", key end
	if guard.trusted[key] then return false end
	local ok, trustedSocial = pcall(cachedSocialTrust, self, sender, guid, key)
	if ok and trustedSocial then return false end
	return true, "quarantine", key
end

local function bnetFriendStatus(accountId)
	local battleNet = _G.C_BattleNet
	local lookup = battleNet and battleNet.GetAccountInfoByID
	if type(lookup) == "function" then
		local ok, isFriend = pcall(function()
			local info = lookup(accountId)
			if not accessible(info) or type(info) ~= "table" then return nil end
			local returnedId, friend = info.bnetAccountID, info.isFriend
			if not accessible(returnedId) or not accessible(friend)
				or bnetId(returnedId) ~= accountId or type(friend) ~= "boolean" then
				return nil
			end
			return friend
		end)
		if ok then return isFriend end
		return nil
	end
	-- Older clients return the account ID and isFriend as results 1 and 13.
	-- Never infer friendship from the display name or an unverified result.
	local legacy = _G.BNGetFriendInfoByID
	if type(legacy) ~= "function" then return nil end
	local ok, isFriend = pcall(function()
		local info = { legacy(accountId) }
		local returnedId, friend = info[1], info[13]
		if not accessible(returnedId) or not accessible(friend)
			or bnetId(returnedId) ~= accountId or type(friend) ~= "boolean" then
			return nil
		end
		return friend
	end)
	if ok then return isFriend end
	return nil
end

local function shouldHoldBnet(self, message, sender, accountId, lineId)
	if not self.bnetFilterActive then return false end
	local guard = settings()
	if not guard or guard.enabled == false or type(message) ~= "string"
		or #message > MAX_TEXT
		or type(sender) ~= "string" or sender == "" then return false end
	accountId = bnetId(accountId)
	if not accountId or type(lineId) ~= "number" or lineId < 1
		or lineId % 1 ~= 0 then return false end
	local key = "bn:" .. tostring(accountId)
	if guard.blocked[key] then return true, "blocked", key, accountId end
	if guard.trusted[key] then return false end
	-- Only a positively identified friend bypasses first-contact review.
	-- Missing or restricted roster data is not proof of friendship.
	if bnetFriendStatus(accountId) == true then return false end
	return true, "quarantine", key, accountId
end

function Guard:ShouldBlockEngineEvent(event, ...)
	if not self.enabled then return false end
	local message, sender, _, _, _, _, _, _, _, _, _, guid = ...
	if event == "CHAT_MSG_BN_WHISPER_INFORM" then
		local accountId = bnetId(select(13, ...))
		local guard = settings()
		if accountId and guard then boundedTrust(guard, "bn:" .. tostring(accountId), "outgoing") end
		return false
	end
	if event == "CHAT_MSG_BN_WHISPER" then
		local lineId, accountId = select(11, ...), select(13, ...)
		local hold, reason, key, validatedId = shouldHoldBnet(self, message, sender, accountId, lineId)
		if hold and reason == "quarantine" then
			local ok, stored = pcall(remember, settings(), message, sender, key, event, validatedId, lineId)
			if not ok or not stored then return false end
		end
		return hold
	end
	if event == "CHAT_MSG_WHISPER_INFORM" then
		local key = normalizedName(sender)
		local guard = settings()
		if key and guard then boundedTrust(guard, key, "outgoing") end
		return false
	end
	if event ~= "CHAT_MSG_WHISPER" then return false end
	local hold, reason, key = shouldHoldIncoming(self, message, sender, guid)
	if hold and reason == "quarantine" then remember(settings(), message, sender, key) end
	return hold
end

function Guard:Filter(frame, event, ...)
	if not self.enabled then return false, ... end
	-- A ChatFrame filter fans out across multiple frames and can run before
	-- MessageEngine. Battle.net first contacts are archived here before hiding:
	-- the engine may receive later secret arguments that this filter never sees.
	-- If a visible argument is secret, leave native delivery alone.
	for index = 1, select("#", ...) do
		if not accessible(select(index, ...)) then return false, ... end
	end
	if event == "CHAT_MSG_WHISPER" then
		local message, sender, _, _, _, _, _, _, _, _, _, guid = ...
		if shouldHoldIncoming(self, message, sender, guid) then return true end
	elseif event == "CHAT_MSG_BN_WHISPER" then
		local message, sender = ...
		local lineId, accountId = select(11, ...), select(13, ...)
		local hold, reason, key, validatedId = shouldHoldBnet(self, message, sender, accountId, lineId)
		if hold then
			if reason == "blocked" then return true end
			local ok, stored = pcall(remember, settings(), message, sender, key,
				event, validatedId, lineId)
			if ok and stored then return true end
		end
	end
	return false, ...
end

function Guard:MarkUnreadable()
	self.unreadable = (self.unreadable or 0) + 1
end

local function messageFilterAPI()
	local util = _G.ChatFrameUtil
	if util and type(util.AddMessageEventFilter) == "function" then
		return util.AddMessageEventFilter, util.RemoveMessageEventFilter
	end
	return _G.ChatFrame_AddMessageEventFilter, _G.ChatFrame_RemoveMessageEventFilter
end

function Guard:SetEnabled(enabled)
	local shouldEnable = enabled and true or false
	if shouldEnable == self.enabled then return true end
	self:InvalidateSocialCache()
	if shouldEnable then
		local addFilter, removeFilter = messageFilterAPI()
		if type(addFilter) ~= "function" then
			self.enabled = false
			self.nativeFilterActive = false
			self.bnetFilterActive = false
			return false
		end
		self.filter = self.filter or function(...) return Guard:Filter(...) end
		local firstOk, firstResult = pcall(addFilter, "CHAT_MSG_WHISPER", self.filter)
		if not firstOk or firstResult == false then
			if type(removeFilter) == "function" then
				pcall(removeFilter, "CHAT_MSG_WHISPER", self.filter)
			end
			self.enabled = false
			self.nativeFilterActive = false
			self.bnetFilterActive = false
			return false
		end
		self.removeFilter = removeFilter
		self.enabled = true
		self.nativeFilterActive = true
		local bnetOk, bnetResult = pcall(addFilter, "CHAT_MSG_BN_WHISPER", self.filter)
		self.bnetFilterActive = bnetOk and bnetResult ~= false
		if not self.bnetFilterActive and type(removeFilter) == "function" then
			pcall(removeFilter, "CHAT_MSG_BN_WHISPER", self.filter)
		end
		self:ReleaseApproved()
		return true
	end
	local removeFilter = self.removeFilter
	if type(removeFilter) ~= "function" then
		local _, fallbackRemove = messageFilterAPI()
		removeFilter = fallbackRemove
	end
	if self.filter and type(removeFilter) == "function" then
		pcall(removeFilter, "CHAT_MSG_WHISPER", self.filter)
		pcall(removeFilter, "CHAT_MSG_BN_WHISPER", self.filter)
	end
	self.enabled = false
	self.nativeFilterActive = false
	self.bnetFilterActive = false
	return true
end

function Guard:Initialize()
	settings()
	self.unreadable = 0
	self:InvalidateSocialCache()
	self.guildRosterSeen = false
	if type(_G.CreateFrame) == "function" and not self.socialEventFrame then
		local ok, frame = pcall(_G.CreateFrame, "Frame")
		if ok and frame and type(frame.SetScript) == "function"
			and type(frame.RegisterEvent) == "function" then
			frame:SetScript("OnEvent", function(_, event)
				Guard:InvalidateSocialCache()
				if event == "GUILD_ROSTER_UPDATE" then
					Guard.guildRosterSeen = true
				elseif event == "PLAYER_GUILD_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
					Guard.guildRosterSeen = false
				end
				if event == "PLAYER_GUILD_UPDATE" and inGuild() then
					requestGuildRoster(Guard)
				end
			end)
			for _, event in ipairs({ "FRIENDLIST_UPDATE", "GUILD_ROSTER_UPDATE",
			"PLAYER_GUILD_UPDATE", "PLAYER_ENTERING_WORLD" }) do
				pcall(frame.RegisterEvent, frame, event)
			end
			self.socialEventFrame = frame
		end
	end
	if inGuild() then requestGuildRoster(self) end
	return true
end

function Guard:ResetForProfile()
	settings()
	self:InvalidateSocialCache()
	self.guildRosterSeen = false
	self.guildRosterRequestAt = nil
	return true
end

function Guard:GetSummaries()
	local guard = settings()
	if not guard then return {} end
	local result, byKey = {}, {}
	for _, entry in ipairs(prune(guard)) do
		local summary = byKey[entry.senderKey]
		if not summary then
			summary = { sender = entry.sender, senderKey = entry.senderKey, count = 0, lastId = entry.id }
			byKey[entry.senderKey] = summary
			result[#result + 1] = summary
		end
		summary.count = summary.count + 1
		summary.lastId = entry.id
	end
	table.sort(result, function(left, right) return left.lastId > right.lastId end)
	return result
end

function Guard:GetEntry(id)
	local guard = settings()
	if not guard then return nil end
	id = tonumber(id)
	for _, entry in ipairs(prune(guard)) do
		if entry.id == id then
			return { id = entry.id, epoch = entry.epoch, sender = entry.sender,
				senderKey = entry.senderKey, text = entry.text, event = entry.event,
				bnetAccountId = entry.bnetAccountId, lineId = entry.lineId }
		end
	end
	return nil
end

-- Approving a correspondent releases the held first contact as well as
-- allowing future whispers. Re-enter the ordinary capture path so spam,
-- routing, history, alerts, and Messenger all make their usual decisions.
function Guard:ReleaseApproved()
	local guard = settings()
	local engine = addon.MessageEngine
	if not guard or not engine or not engine.enabled
		or type(engine.CaptureAccessible) ~= "function" then return 0 end
	local kept, released = {}, 0
	for _, entry in ipairs(prune(guard)) do
		if guard.trusted[entry.senderKey] then
			local ok, delivered
			if entry.event == "CHAT_MSG_BN_WHISPER" and bnetId(entry.bnetAccountId) then
				-- The original account ID is arg13, not the non-unique display name.
				local args = { entry.text, entry.sender }
				args[11], args[13] = entry.lineId, entry.bnetAccountId
				ok, delivered = pcall(engine.CaptureAccessible, engine, entry.event,
					entry.epoch, unpack(args, 1, 13))
			elseif not entry.event or entry.event == "CHAT_MSG_WHISPER" then
				ok, delivered = pcall(engine.CaptureAccessible, engine, "CHAT_MSG_WHISPER",
					entry.epoch, entry.text, entry.sender)
			end
			-- A completed call may still decline the record; keep it for review.
			if ok and delivered then
				released = released + 1
			else
				kept[#kept + 1] = entry
			end
		else
			kept[#kept + 1] = entry
		end
	end
	guard.entries = kept
	return released
end

function Guard:ApproveSender(name)
	local key = controlKey(name)
	local guard = settings()
	if not key or not guard then return false end
	guard.blocked[key] = nil
	boundedTrust(guard, key, "approved")
	return true, self:ReleaseApproved()
end

function Guard:BlockSender(name)
	local key = controlKey(name)
	local guard = settings()
	if not key or not guard then return false end
	guard.trusted[key] = nil
	boundedBlock(guard, key)
	return true
end

function Guard:UnblockSender(name)
	local key = controlKey(name)
	local guard = settings()
	if not key or not guard or not guard.blocked[key] then return false end
	guard.blocked[key] = nil
	return true
end

function Guard:UnapproveSender(name)
	local key = controlKey(name)
	local guard = settings()
	if not key or not guard or not guard.trusted[key] then return false end
	guard.trusted[key] = nil
	return true
end

function Guard:ClearQuarantine()
	local guard = settings()
	if not guard then return 0 end
	local removed = #guard.entries
	guard.entries = {}
	return removed
end

function Guard:SetProtectionEnabled(enabled)
	local guard = settings()
	if not guard then return false end
	guard.enabled = enabled and true or false
	return true
end

function Guard:GetStatus()
	local guard = settings()
	return { enabled = guard and guard.enabled ~= false or false,
		entries = guard and #prune(guard) or 0, unreadable = self.unreadable or 0,
		filterActive = self.nativeFilterActive == true,
		bnetFilterActive = self.bnetFilterActive == true }
end

local function statusText(text)
	if addon.Print then addon:Print(text) end
end

-- Temporary command surface until the dedicated Whisper Safety panel is
-- available. Listing never prints held message text into any chat transcript;
-- SHOW is a deliberate private modal reveal.
function Guard:HandleCommand(input)
	input = trim(input, 180)
	local verb, argument = string.match(input, "^(%S+)%s*(.-)%s*$")
	verb = string.lower(verb or "list")
	if verb == "list" or verb == "status" then
		local state = self:GetStatus()
		statusText("Whisper quarantine: " .. tostring(state.entries) .. " held, "
			.. (state.enabled and "ON" or "OFF") .. ". Unreadable Retail payloads: "
			.. tostring(state.unreadable) .. ".")
		if self.enabled and not state.filterActive then
			statusText("WARNING: native chat whisper filter is unavailable; native chat may show these messages.")
		end
		if self.enabled and not state.bnetFilterActive then
			statusText("Battle.net whisper quarantine is unavailable; those messages remain in native chat.")
		end
		local summaries = self:GetSummaries()
		for index = 1, math.min(#summaries, 20) do
			local summary = summaries[index]
			local label = summary.sender
			if string.sub(summary.senderKey, 1, 3) == "bn:" then
				label = label .. " (" .. summary.senderKey .. ")"
			end
			statusText(label .. " — " .. tostring(summary.count)
				.. " held. Latest ID " .. tostring(summary.lastId) .. ".")
		end
		if #summaries > 20 then statusText(tostring(#summaries - 20) .. " more senders not listed.") end
		statusText("/ccbbw show ID | approve NAME | block NAME | unblock NAME | unapprove NAME | on | off | clear confirm")
		return true
	elseif verb == "show" then
		local entry = self:GetEntry(argument)
		if not entry then statusText("No held whisper with that ID."); return false end
		if not _G.StaticPopupDialogs or not _G.StaticPopup_Show then
			statusText("Private review dialog is unavailable; held text was not printed to chat.")
			return false
		end
		_G.StaticPopupDialogs.CCBB_WHISPER_REVIEW = _G.StaticPopupDialogs.CCBB_WHISPER_REVIEW or {
			text = "%s", button1 = "CLOSE", timeout = 0, whileDead = true,
			hideOnEscape = true, preferredIndex = 3,
		}
		local senderLabel = entry.sender
		if entry.event == "CHAT_MSG_BN_WHISPER" then
			senderLabel = senderLabel .. " (" .. entry.senderKey .. ")"
		end
		_G.StaticPopup_Show("CCBB_WHISPER_REVIEW", senderLabel .. " wrote:\n\n" .. entry.text)
		return true
	elseif verb == "approve" and argument ~= "" then
		local ok, released = self:ApproveSender(argument)
		statusText(ok and "Whispers from " .. argument .. " are approved; "
			.. tostring(released or 0) .. " held message(s) moved into normal chat history."
			or "A valid player name is required.")
		return ok
	elseif verb == "block" and argument ~= "" then
		local ok = self:BlockSender(argument)
		statusText(ok and "Whispers from " .. argument .. " are locally blocked; held messages remain private."
			or "A valid player name is required.")
		return ok
	elseif verb == "unblock" and argument ~= "" then
		local ok = self:UnblockSender(argument)
		statusText(ok and "Whisper block removed for " .. argument .. "." or "No matching local whisper block.")
		return ok
	elseif verb == "unapprove" and argument ~= "" then
		local ok = self:UnapproveSender(argument)
		statusText(ok and "Whisper approval removed for " .. argument .. "." or "No matching approval.")
		return ok
	elseif verb == "on" or verb == "off" then
		self:SetProtectionEnabled(verb == "on")
		statusText("Whisper quarantine " .. (verb == "on" and "enabled." or "disabled."))
		return true
	elseif verb == "clear" and argument == "confirm" then
		statusText(tostring(self:ClearQuarantine()) .. " held whisper messages erased.")
		return true
	end
	statusText("Use /ccbbw list for private whisper controls. SHOW opens held text only when requested.")
	return false
end
