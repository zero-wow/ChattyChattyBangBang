local mod = ChattyChattyBangBang:NewModule("Disable Buttons", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("ChattyChattyBangBang")
local unpack = unpack or table.unpack

mod.modName = L["Disable Buttons"]

local function hide(self)
	if not self.override then
		self:Hide()
	end
	self.override = nil
end

local options = {
	bottomButton = {
		type = "toggle",
		name = L["Show bottom when scrolled"],
		desc = L["Show bottom button when scrolled up"],
		width = "double",
		get = function()
			return mod.db.profile.scrollReminder
		end,
		set = function(info, v)
			mod.db.profile.scrollReminder = v
			-- Saving an option while Smart Chat owns presentation must not wake a
			-- dormant legacy module or hook native frames.
			if mod:IsEnabled() then
				if v then
					mod:EnableBottomButton()
				else
					mod:DisableBottomButton()
				end
			end
		end,
	}
}

local defaults = { profile = {} }
local clickFunc = function(self) self:GetParent():ScrollToBottom() end

function mod:OnInitialize()
	self.db = ChattyChattyBangBang.db:RegisterNamespace("Buttons", defaults)
	self.frameStates = {}
	self.controlStates = {}
end

function mod:RememberFrameState(frame)
	local state = self.frameStates[frame]
	if state then
		return state
	end

	state = {}
	if frame.GetClampRectInsets then
		state.clampInsets = { frame:GetClampRectInsets() }
	end
	self.frameStates[frame] = state
	return state
end

function mod:EnsureBottomButton(frame)
	if not frame then
		return nil
	end

	local state = self:RememberFrameState(frame)
	local button = frame.ChattyChattyBangBangDownButton
	if not button then
		button = CreateFrame("Button", nil, frame)
		button:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollEnd-Up]])
		button:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollEnd-Down]])
		button:SetDisabledTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollEnd-Disabled]])
		button:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]])
		button:SetWidth(20)
		button:SetHeight(20)
		button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
		button:SetScript("OnClick", clickFunc)
		button:Hide()
		frame.ChattyChattyBangBangDownButton = button
	end
	if not state.hasOriginalDownButton then
		state.originalDownButton = frame.downButton
		state.hasOriginalDownButton = true
	end
	state.bottomButton = button
	frame.downButton = button
	return button
end

function mod:HideControl(control)
	if not control then
		return
	end

	local state = self.controlStates[control]
	if not state then
		state = {
			onShow = control:GetScript("OnShow"),
			shown = control:IsShown(),
		}
		self.controlStates[control] = state
	end
	control:Hide()
	control:SetScript("OnShow", hide)
end

function mod:RestoreControl(control)
	if not control then
		return
	end
	local state = self.controlStates[control]
	if not state then
		return
	end
	control:SetScript("OnShow", state.onShow)
	if state.shown then
		control:Show()
	else
		control:Hide()
	end
	self.controlStates[control] = nil
end

function mod:HideButtonFrame(frame, state)
	local buttonFrame = _G[frame:GetName() .. "ButtonFrame"]
	if not buttonFrame then
		return
	end

	if not state.buttonFrame then
		state.buttonFrame = {
			frame = buttonFrame,
			onShow = buttonFrame:GetScript("OnShow"),
			shown = buttonFrame:IsShown(),
		}
	end
	buttonFrame:Hide()
	buttonFrame:SetScript("OnShow", hide)
end

function mod:Decorate(frame)
	if not self:IsEnabled() or not frame then
		return
	end
	self:EnsureBottomButton(frame)
	self:ApplyFrameChanges(frame)
	if self.db.profile.scrollReminder then
		self:ApplyBottomButton(frame)
	end
end

function mod:FCF_RestorePositionAndDimensions(chatFrame)
	if self:IsEnabled() and chatFrame then
		self:ApplyFrameChanges(chatFrame)
	end
end

function mod:ApplyFrameChanges(frame)
	if not self:IsEnabled() or not frame then
		return
	end
	local state = self:RememberFrameState(frame)
	if frame.SetClampRectInsets then
		frame:SetClampRectInsets(0, 0, 0, 0)
	end
	self:HideButtonFrame(frame, state)
end

function mod:RestoreFrameChanges(frame)
	if not frame then
		return
	end
	local state = self.frameStates[frame]
	if not state then
		return
	end

	-- Let Blizzard put a movable chat frame back in a valid position first;
	-- then restore the exact inset values that existed before this module ran.
	if frame.IsMovable and frame:IsMovable() and FCF_RestorePositionAndDimensions then
		FCF_RestorePositionAndDimensions(frame)
	end
	if state.clampInsets and frame.SetClampRectInsets then
		frame:SetClampRectInsets(unpack(state.clampInsets))
	end
	if state.buttonFrame then
		local buttonFrame = state.buttonFrame.frame
		buttonFrame:SetScript("OnShow", state.buttonFrame.onShow)
		if state.buttonFrame.shown then
			buttonFrame:Show()
		else
			buttonFrame:Hide()
		end
	end
	if state.bottomButton then
		state.bottomButton:Hide()
	end
	frame.downButton = state.originalDownButton
	self.frameStates[frame] = nil
end

function mod:RestoreAllFrameChanges()
	local frames = {}
	for frame in pairs(self.frameStates) do
		frames[#frames + 1] = frame
	end
	for index = 1, #frames do
		self:RestoreFrameChanges(frames[index])
	end
end

function mod:OnEnable()
	self:SecureHook("FCF_RestorePositionAndDimensions")
	self:HideControl(ChatFrameMenuButton)
	self:HideControl(FriendsMicroButton)
	for i = 1, NUM_CHAT_WINDOWS do
		local frame = _G["ChatFrame" .. i]
		if frame then
			self:EnsureBottomButton(frame)
			self:ApplyFrameChanges(frame)
		end
	end
	if self.db.profile.scrollReminder then
		self:EnableBottomButton()
	end
	for _, frameName in ipairs(self.TempChatFrames) do
		local frame = _G[frameName]
		if frame then
			self:EnsureBottomButton(frame)
			self:ApplyFrameChanges(frame)
		end
	end
end

function mod:UnDecorate(frame)
	self:RestoreFrameChanges(frame)
end

function mod:OnDisable()
	self:DisableBottomButton()
	self:RestoreAllFrameChanges()
	self:RestoreControl(ChatFrameMenuButton)
	self:RestoreControl(FriendsMicroButton)
	self:UnhookAll()
end

function mod:Info()
	return L["Hides the buttons attached to the chat frame"]
end

function mod:ApplyBottomButton(frame)
	if not self:IsEnabled() or not frame or self:IsHooked(frame, "ScrollUp") then
		return nil
	end
	local button = self:EnsureBottomButton(frame)
	self:Hook(frame, "ScrollUp", true)
	self:Hook(frame, "ScrollToTop", "ScrollUp", true)
	self:Hook(frame, "PageUp", "ScrollUp", true)
	self:Hook(frame, "ScrollDown", true)
	self:Hook(frame, "ScrollToBottom", "ScrollDownForce", true)
	self:Hook(frame, "PageDown", "ScrollDown", true)
	if frame:GetCurrentScroll() ~= 0 then
		button:Show()
	end
	if frame ~= COMBATLOG then
		self:Hook(frame, "AddMessage", true)
	end
end

function mod:EnableBottomButton()
	if not self:IsEnabled() or self.buttonsEnabled then
		return
	end
	self.buttonsEnabled = true
	for i = 1, NUM_CHAT_WINDOWS do
		local frame = _G["ChatFrame" .. i]
		if frame then
			self:ApplyBottomButton(frame)
		end
	end
	for _, frameName in ipairs(self.TempChatFrames) do
		local frame = _G[frameName]
		if frame then
			self:ApplyBottomButton(frame)
		end
	end
end

function mod:UnApplyBottomButton(frame)
	if not frame then
		return
	end
	self:Unhook(frame, "ScrollUp")
	self:Unhook(frame, "ScrollToTop")
	self:Unhook(frame, "PageUp")
	self:Unhook(frame, "ScrollDown")
	self:Unhook(frame, "ScrollToBottom")
	self:Unhook(frame, "PageDown")
	if frame ~= COMBATLOG then
		self:Unhook(frame, "AddMessage")
	end
	local button = frame.ChattyChattyBangBangDownButton
	if button then
		button:Hide()
	end
end

function mod:DisableBottomButton()
	if not self.buttonsEnabled then
		return
	end
	self.buttonsEnabled = false
	for i = 1, NUM_CHAT_WINDOWS do
		self:UnApplyBottomButton(_G["ChatFrame" .. i])
	end
	for _, frameName in ipairs(self.TempChatFrames) do
		self:UnApplyBottomButton(_G[frameName])
	end
end

function mod:ScrollUp(frame)
	local button = frame.ChattyChattyBangBangDownButton
	if button then
		button:Show()
		button:UnlockHighlight()
	end
end

function mod:ScrollDown(frame)
	if frame:GetCurrentScroll() == 0 then
		local button = frame.ChattyChattyBangBangDownButton
		if button then
			button:Hide()
			button:UnlockHighlight()
		end
	end
end

function mod:ScrollDownForce(frame)
	local button = frame.ChattyChattyBangBangDownButton
	if button then
		button:Hide()
		button:UnlockHighlight()
	end
end

function mod:AddMessage(frame, text, ...)
	local button = frame.ChattyChattyBangBangDownButton
	if not button then
		return
	end
	if frame:GetCurrentScroll() > 0 then
		button:Show()
		button:LockHighlight()
	else
		button:Hide()
		button:UnlockHighlight()
	end
end

function mod:GetOptions()
	return options
end
