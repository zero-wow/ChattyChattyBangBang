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

local function epoch()
	return time and (tonumber(time()) or 0) or 0
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
		if ok and result == true then return true end
	end
	if _G.C_FriendList and type(_G.C_FriendList.GetNumFriends) == "function"
		and type(_G.C_FriendList.GetFriendInfoByIndex) == "function" then
		local ok, count = pcall(_G.C_FriendList.GetNumFriends)
		if ok then
			local target = normalizedName(name)
			for index = 1, math.min(tonumber(count) or 0, 500) do
				local success, info = pcall(_G.C_FriendList.GetFriendInfoByIndex, index)
				if success and type(info) == "table" and normalizedName(info.name) == target then
					return true
				end
			end
		end
	end
	if type(_G.GetNumFriends) == "function" and type(_G.GetFriendInfo) == "function" then
		local ok, count = pcall(_G.GetNumFriends)
		if ok then
			local target = normalizedName(name)
			for index = 1, math.min(tonumber(count) or 0, 500) do
				local success, info = pcall(_G.GetFriendInfo, index)
				local candidate = type(info) == "table" and info.name or info
				if success and normalizedName(candidate) == target then return true end
			end
		end
	end
	return false
end

local function isGuildmate(name)
	if not _G.IsInGuild or not _G.IsInGuild() then return false end
	if type(_G.GetNumGuildMembers) ~= "function" or type(_G.GetGuildRosterInfo) ~= "function" then
		return false
	end
	local target = normalizedName(name)
	local ok, count = pcall(_G.GetNumGuildMembers)
	if not ok then return false end
	for index = 1, math.min(tonumber(count) or 0, 1000) do
		local success, candidate = pcall(_G.GetGuildRosterInfo, index)
		if success and normalizedName(candidate) == target then return true end
	end
	return false
end

local function remember(guard, message, sender, key)
	local entries = prune(guard)
	entries[#entries + 1] = {
		id = guard.nextId,
		epoch = epoch(),
		sender = trim(sender, 128),
		senderKey = key,
		text = trim(message, MAX_TEXT),
	}
	guard.nextId = guard.nextId + 1
	if #entries > MAX_ENTRIES then table.remove(entries, 1) end
end

local function shouldHoldIncoming(self, message, sender, guid)
	local guard = settings()
	if not guard or guard.enabled == false then return false end
	local key = normalizedName(sender)
	if not key or type(message) ~= "string" then return false end
	if guard.blocked[key] then return true, "blocked", key end
	if guard.trusted[key] then return false end
	local ok, trustedSocial = pcall(function()
		return isFriend(sender, guid) or isGuildmate(sender)
	end)
	if ok and trustedSocial then return false end
	return true, "quarantine", key
end

function Guard:ShouldBlockEngineEvent(event, ...)
	if not self.enabled then return false end
	local message, sender, _, _, _, _, _, _, _, _, _, guid = ...
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
	-- MessageEngine. It only reads policy; the engine alone archives one copy.
	-- If any Retail argument is secret, leave native delivery alone and surface
	-- the degraded state from MessageEngine's guarded capture path.
	for index = 1, select("#", ...) do
		if not accessible(select(index, ...)) then return false, ... end
	end
	if event == "CHAT_MSG_WHISPER" then
		local message, sender, _, _, _, _, _, _, _, _, _, guid = ...
		if shouldHoldIncoming(self, message, sender, guid) then return true end
	end
	return false, ...
end

function Guard:MarkUnreadable()
	self.unreadable = (self.unreadable or 0) + 1
end

function Guard:SetEnabled(enabled)
	local shouldEnable = enabled and true or false
	if shouldEnable == self.enabled then return true end
	if shouldEnable then
		self.enabled = true
		if type(_G.ChatFrame_AddMessageEventFilter) ~= "function" then
			self.nativeFilterActive = false
			return false
		end
		self.filter = self.filter or function(...) return Guard:Filter(...) end
		local firstOk, firstResult = pcall(_G.ChatFrame_AddMessageEventFilter, "CHAT_MSG_WHISPER", self.filter)
		if not firstOk or firstResult == false then
			if type(_G.ChatFrame_RemoveMessageEventFilter) == "function" then
				pcall(_G.ChatFrame_RemoveMessageEventFilter, "CHAT_MSG_WHISPER", self.filter)
			end
			self.nativeFilterActive = false
			return false
		end
		self.nativeFilterActive = true
		self:ReleaseApproved()
		return true
	end
	if self.filter and type(_G.ChatFrame_RemoveMessageEventFilter) == "function" then
		pcall(_G.ChatFrame_RemoveMessageEventFilter, "CHAT_MSG_WHISPER", self.filter)
	end
	self.enabled = false
	self.nativeFilterActive = false
	return true
end

function Guard:Initialize()
	settings()
	self.unreadable = 0
	return true
end

function Guard:ResetForProfile()
	settings()
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
				senderKey = entry.senderKey, text = entry.text }
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
			local ok = pcall(engine.CaptureAccessible, engine, "CHAT_MSG_WHISPER",
				entry.epoch, entry.text, entry.sender)
			if ok then
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
	local key = normalizedName(name)
	local guard = settings()
	if not key or not guard then return false end
	guard.blocked[key] = nil
	boundedTrust(guard, key, "approved")
	return true, self:ReleaseApproved()
end

function Guard:BlockSender(name)
	local key = normalizedName(name)
	local guard = settings()
	if not key or not guard then return false end
	guard.trusted[key] = nil
	boundedBlock(guard, key)
	return true
end

function Guard:UnblockSender(name)
	local key = normalizedName(name)
	local guard = settings()
	if not key or not guard or not guard.blocked[key] then return false end
	guard.blocked[key] = nil
	return true
end

function Guard:UnapproveSender(name)
	local key = normalizedName(name)
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
		filterActive = self.nativeFilterActive == true }
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
		local summaries = self:GetSummaries()
		for index = 1, math.min(#summaries, 20) do
			local summary = summaries[index]
			statusText(summary.sender .. " — " .. tostring(summary.count)
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
		_G.StaticPopup_Show("CCBB_WHISPER_REVIEW", entry.sender .. " wrote:\n\n" .. entry.text)
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
