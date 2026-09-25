local addon = ChattyChattyBangBang
local Recovery = {}
addon.ChatRecovery = Recovery

-- Retail keeps event line IDs readable during messaging lockdown, but does
-- not promise how long their text remains available. This is a best-effort
-- catch-up queue, never a substitute for the temporary Blizzard-chat fallback.
local MAX_PENDING = 512
local MAX_ATTEMPTS = 30
local RETRY_SECONDS = 2
local unpackValues = unpack or table.unpack

local function accessible(value)
	if _G.canaccessvalue then return _G.canaccessvalue(value) end
	if _G.issecretvalue then return not _G.issecretvalue(value) end
	return true
end

local function safeArgument(index, ...)
	local value = select(index, ...)
	return accessible(value) and value or nil
end

local function inLockdown()
	local api = _G.C_ChatInfo
	if api and type(api.InChatMessagingLockdown) == "function" then
		local ok, result = pcall(api.InChatMessagingLockdown)
		if ok then return result == true end
	end
	return false
end

local function revealNative()
	local dock = addon.SmartDock
	if dock and type(dock.SetNativeSafetyFallback) == "function" then
		local ok, result = pcall(dock.SetNativeSafetyFallback, dock, true)
		return ok and result ~= false
	end
	return false
end

local function mayReleaseNative(self)
	if #self.pending > 0 or self.unresolved > 0 or inLockdown() then return end
	local dock = addon.SmartDock
	if dock and type(dock.SetNativeSafetyFallback) == "function" then
		pcall(dock.SetNativeSafetyFallback, dock, false)
	end
end

local function needsSender(event)
	return event ~= "CHAT_MSG_SYSTEM" and event ~= "CHAT_MSG_LOOT"
		and event ~= "CHAT_MSG_MONEY" and event ~= "CHAT_MSG_ZONE_UNDER_ATTACK"
		and string.find(event, "^CHAT_MSG_BG_SYSTEM_") == nil
end

local function lookup(getter, lineId)
	if type(getter) ~= "function" then return nil end
	local ok, value = pcall(getter, lineId)
	if not ok or not accessible(value) then return nil end
	return value
end

function Recovery:UpdateDiagnostics()
	local db = addon.Diagnostics and addon.Diagnostics.db
	if type(db) ~= "table" then return end
	db.chatRecovery = {
		session = db.session, pending = #(self.pending or {}),
		recovered = self.recovered or 0, unresolved = self.unresolved or 0,
		fallbackFailed = self.fallbackFailed == true,
		time = time and time() or 0,
	}
end

function Recovery:Schedule()
	if self.timerPending or not _G.C_Timer or type(_G.C_Timer.After) ~= "function" then return end
	self.timerPending = true
	_G.C_Timer.After(RETRY_SECONDS, function()
		self.timerPending = false
		self:Flush()
	end)
end

function Recovery:Queue(event, ...)
	if type(event) ~= "string" or not string.find(event, "^CHAT_MSG_")
		or event == "CHAT_MSG_ADDON" then return false end
	self.pending = self.pending or {}
	self.keys = self.keys or {}
	self.unresolved = self.unresolved or 0
	local lineId = safeArgument(11, ...)
	if type(lineId) ~= "number" or lineId <= 0 then
		self.unresolved = self.unresolved + 1
	else
		local key = event .. ":" .. tostring(lineId)
		if not self.keys[key] then
			local item = {
				event = event, lineId = lineId, epoch = time and time() or 0,
				arguments = {
					[3] = safeArgument(3, ...), [4] = safeArgument(4, ...),
					[5] = safeArgument(5, ...), [6] = safeArgument(6, ...),
					[8] = safeArgument(8, ...), [9] = safeArgument(9, ...),
					[12] = safeArgument(12, ...), [13] = safeArgument(13, ...),
					[14] = safeArgument(14, ...),
				},
				attempts = 0,
			}
			if #self.pending >= MAX_PENDING then
				local removed = table.remove(self.pending, 1)
				self.keys[removed.event .. ":" .. tostring(removed.lineId)] = nil
				self.unresolved = self.unresolved + 1
			end
			self.pending[#self.pending + 1] = item
			self.keys[key] = true
		end
	end
	if not revealNative() then self.fallbackFailed = true end
	if not self.noticeShown then
		self.noticeShown = true
		if addon.Print then
			addon:Print("Retail is temporarily withholding some chat lines from addons. Blizzard chat is shown while Chatty tries to fill them in.")
		end
	end
	if #self.pending > 0 then self:Schedule() end
	self:UpdateDiagnostics()
	return true
end

function Recovery:Flush()
	self.pending = self.pending or {}
	self.keys = self.keys or {}
	self.unresolved = self.unresolved or 0
	if self.fallbackFailed and (#self.pending > 0 or self.unresolved > 0)
		and revealNative() then
		self.fallbackFailed = false
	end
	if #self.pending == 0 then mayReleaseNative(self); self:UpdateDiagnostics(); return end
	if inLockdown() then self:Schedule(); self:UpdateDiagnostics(); return end
	local api = _G.C_ChatInfo
	local engine = addon.MessageEngine
	if not api or not engine or not engine.enabled
		or type(engine.CaptureAccessible) ~= "function" then
		self:Schedule()
		self:UpdateDiagnostics()
		return
	end
	for index = #self.pending, 1, -1 do
		local item = self.pending[index]
		item.attempts = item.attempts + 1
		local text = lookup(api.GetChatLineText, item.lineId)
		local sender = lookup(api.GetChatLineSenderName, item.lineId)
		if type(text) == "string" and (not needsSender(item.event)
			or (type(sender) == "string" and sender ~= "")) then
			local args = item.arguments
			args[1], args[2], args[11] = text, sender, item.lineId
			args[12] = lookup(api.GetChatLineSenderGUID, item.lineId) or args[12]
			local ok = pcall(engine.CaptureAccessible, engine, item.event,
				item.epoch, unpackValues(args, 1, 14))
			if ok then
				self.recovered = (self.recovered or 0) + 1
				self.keys[item.event .. ":" .. tostring(item.lineId)] = nil
				table.remove(self.pending, index)
			else
				item.attempts = MAX_ATTEMPTS
			end
		end
		if item.attempts >= MAX_ATTEMPTS and self.pending[index] == item then
			self.unresolved = self.unresolved + 1
			self.keys[item.event .. ":" .. tostring(item.lineId)] = nil
			table.remove(self.pending, index)
		end
	end
	if #self.pending > 0 then self:Schedule() else mayReleaseNative(self) end
	self:UpdateDiagnostics()
end

function Recovery:GetStatus()
	return { pending = #(self.pending or {}), recovered = self.recovered or 0,
		unresolved = self.unresolved or 0, fallbackFailed = self.fallbackFailed == true }
end

function Recovery:Stop()
	self.pending = {}
	self.keys = {}
	local dock = addon.SmartDock
	if dock and type(dock.SetNativeSafetyFallback) == "function" then
		pcall(dock.SetNativeSafetyFallback, dock, false)
	end
	self:UpdateDiagnostics()
end
