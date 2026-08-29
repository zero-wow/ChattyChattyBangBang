-- This used to be a free-standing load-time hook.  Smart Chat owns the native
-- frames, so keep the old native-only behavior behind the legacy-module
-- lifecycle instead.
local mod = ChattyChattyBangBang:NewModule("Delay Guild MOTD", "AceHook-3.0")

mod.modName = "Delay Guild MOTD"

local strmatch = strmatch
local unpack = unpack or table.unpack
local DELAY_SECONDS = 2.5

local function buildPattern(template)
	if type(template) ~= "string" or template == "" then
		return nil
	end
	return template:
		gsub("[-%%+*.()%[%]]", "%%%1"):
		gsub("%%%%s", "(.+)")
end

function mod:Info()
	return "Delays the guild message of the day briefly in native chat."
end

function mod:EnsureDelayFrame()
	if self.delayFrame then
		return self.delayFrame
	end

	local frame = CreateFrame("Frame")
	frame:Hide()
	frame:SetScript("OnUpdate", function(_, elapsed)
		mod:OnDelayUpdate(elapsed)
	end)
	self.delayFrame = frame
	return frame
end

function mod:FlushDelayedMessage()
	local data = self.gmotdData
	local chatFrame = self.chatFrame
	self.gmotdData = nil
	if data and chatFrame and chatFrame.AddMessage then
		-- FinishDelay unhooks first, so this is the original AddMessage method.
		chatFrame:AddMessage(unpack(data))
	end
end

function mod:FinishDelay(flush)
	if self.delayFrame then
		self.delayFrame:Hide()
	end
	self:UnhookAll()
	if flush then
		self:FlushDelayedMessage()
	else
		self.gmotdData = nil
	end
	self.pattern = nil
	self.remaining = nil
	self.chatFrame = nil
end

function mod:OnDelayUpdate(elapsed)
	if not self.remaining then
		return
	end
	self.remaining = self.remaining - (elapsed or 0)
	if self.remaining <= 0 then
		self:FinishDelay(true)
	end
end

function mod:AddMessage(chatFrame, text, ...)
	if self.pattern and text and strmatch(text, self.pattern) then
		self.gmotdData = { text, ... }
		-- Keep the MOTD out of native chat until the short delay finishes, but
		-- leave every other message on Blizzard's original path immediately.
		self:UnhookAll()
		return
	end

	local hooks = self.hooks and self.hooks[chatFrame]
	local original = hooks and hooks.AddMessage
	if original then
		return original(chatFrame, text, ...)
	end
end

function mod:OnEnable()
	self:FinishDelay(false)
	self.pattern = buildPattern(_G.GUILD_MOTD_TEMPLATE)
	self.chatFrame = _G.ChatFrame1
	if not self.pattern or not self.chatFrame or type(self.chatFrame.AddMessage) ~= "function" then
		self.pattern = nil
		self.chatFrame = nil
		return
	end

	self.remaining = DELAY_SECONDS
	self:RawHook(self.chatFrame, "AddMessage", true)
	self:EnsureDelayFrame():Show()
end

function mod:OnDisable()
	-- Do not lose an MOTD if Smart Chat is enabled while the native delay is
	-- pending.  The game event already happened; this only restores its native
	-- display path before the hook is removed.
	self:FinishDelay(true)
end
