local addon = ChattyChattyBangBang
local Launcher = {}
addon.Launcher = Launcher

local launcherName = "ChattyChattyBangBang"

local function toggleDock()
	local dock = addon.SmartDock
	if dock and dock.IsActive and dock:IsActive() then
		dock:ToggleVisibility()
		return
	end
	local settings = addon:GetSmartSettings()
	if dock and settings.enabled then
		dock:SetVisible(true, true)
		dock:SetEnabled(true)
		return
	end
	addon:OpenConfig()
end

local function handleLauncherClick(button)
	if button == "RightButton" then
		addon:OpenConfig()
	elseif button == "MiddleButton" then
		addon:SetMinimapHidden(true)
	else
		toggleDock()
	end
end

local function showTooltip(owner)
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	GameTooltip:AddLine("ChattyChattyBangBang")
	GameTooltip:AddLine("Intelligent chat control center", 0.56, 0.63, 0.71)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Left-click: Show / hide chat dock", 0.88, 0.61, 0.24)
	GameTooltip:AddLine("Right-click: Open settings", 0.88, 0.61, 0.24)
	GameTooltip:AddLine("Middle-click: Hide minimap button", 0.88, 0.61, 0.24)
	GameTooltip:Show()
end

function Launcher:BuildBroker()
	if not self.active then
		return false
	end
	local libStub = _G.LibStub
	local ldb = libStub and libStub("LibDataBroker-1.1", true)
	local icon = libStub and libStub("LibDBIcon-1.0", true)
	if not ldb or not icon then
		return false
	end

	self.broker = ldb:GetDataObjectByName(launcherName) or ldb:NewDataObject(launcherName, {
		type = "launcher",
		text = "ChattyChattyBangBang",
		icon = addon.Theme.ICON_PATH,
		OnClick = function(_, button)
			if not Launcher.active then
				return
			end
			handleLauncherClick(button)
		end,
		OnTooltipShow = function(tooltip)
			if not Launcher.active then
				return
			end
			tooltip:AddLine("ChattyChattyBangBang")
			tooltip:AddLine("Intelligent chat control center", 0.56, 0.63, 0.71)
			tooltip:AddLine(" ")
			tooltip:AddLine("Left-click: Show / hide chat dock", 0.88, 0.61, 0.24)
			tooltip:AddLine("Right-click: Open settings", 0.88, 0.61, 0.24)
			tooltip:AddLine("Middle-click: Hide minimap button", 0.88, 0.61, 0.24)
		end,
	})

	self.icon = icon
	local settings = addon:GetSmartSettings()
	if not icon:IsRegistered(launcherName) then
		icon:Register(launcherName, self.broker, settings.launcher.minimap)
	else
		icon:Refresh(launcherName, settings.launcher.minimap)
	end

	if self.fallback then
		self.fallback:Hide()
	end
	self:RefreshMinimap()
	return true
end

function Launcher:UpdateFallbackPosition()
	if not self.fallback then
		return
	end

	local settings = addon:GetSmartSettings()
	local angle = math.rad(settings.launcher.minimap.minimapPos or 220)
	local radius = 82
	self.fallback:ClearAllPoints()
	self.fallback:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function Launcher:BuildFallback()
	if self.fallback then
		return
	end

	local parent = _G.MinimapCluster or Minimap
	local button = CreateFrame("Button", "ChattyChattyBangBangMinimapButton", parent)
	button:SetWidth(32)
	button:SetHeight(32)
	button:SetFrameStrata("MEDIUM")
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	button:RegisterForDrag("LeftButton")

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints(button)
	button.icon:SetTexture(addon.Theme.ICON_PATH)

	button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
	button.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	button.highlight:SetBlendMode("ADD")
	button.highlight:SetAllPoints(button)

	button:SetScript("OnClick", function(_, buttonName)
		if not Launcher.active then
			return
		end
		handleLauncherClick(buttonName)
	end)
	button:SetScript("OnEnter", function(self)
		showTooltip(self)
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local cursorX, cursorY = GetCursorPosition()
			local scale = UIParent:GetEffectiveScale()
			cursorX = cursorX / scale
			cursorY = cursorY / scale
			local centerX, centerY = Minimap:GetCenter()
			if not centerX or not centerY then
				return
			end
			local angle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX))
			addon:GetSmartSettings().launcher.minimap.minimapPos = angle
			Launcher:UpdateFallbackPosition()
		end)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)

	self.fallback = button
	self:UpdateFallbackPosition()
end

function Launcher:RefreshMinimap()
	local settings = addon:GetSmartSettings()
	if self.icon then
		if not self.active or settings.launcher.minimap.hide then
			self.icon:Hide(launcherName)
		else
			self.icon:Show(launcherName)
		end
	elseif self.fallback then
		if not self.active or settings.launcher.minimap.hide then
			self.fallback:Hide()
		else
			self.fallback:Show()
		end
	end
end

function Launcher:ApplyProfile()
	local settings = addon:GetSmartSettings()
	if self.icon and self.icon.IsRegistered and self.icon:IsRegistered(launcherName) then
		pcall(self.icon.Refresh, self.icon, launcherName, settings.launcher.minimap)
	end
	self:UpdateFallbackPosition()
	self:RefreshMinimap()
end

function Launcher:Initialize()
	self.active = true
	if not self.initialized then
		self.initialized = true
		self.eventFrame = CreateFrame("Frame")
		self.eventFrame:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_LOGIN" then
				Launcher.eventFrame:UnregisterEvent("PLAYER_LOGIN")
				if Launcher.active and not Launcher:BuildBroker() then
					Launcher:BuildFallback()
					Launcher:RefreshMinimap()
				end
			end
		end)
	end

	if IsLoggedIn and IsLoggedIn() then
		self.eventFrame:UnregisterEvent("PLAYER_LOGIN")
		if not self:BuildBroker() then
			self:BuildFallback()
			self:RefreshMinimap()
		end
	else
		self.eventFrame:RegisterEvent("PLAYER_LOGIN")
	end
end

function Launcher:Shutdown()
	self.active = false
	if self.eventFrame then
		self.eventFrame:UnregisterAllEvents()
	end
	if self.fallback then
		self.fallback:SetScript("OnUpdate", nil)
		self.fallback:Hide()
	end
	if self.icon then
		pcall(self.icon.Hide, self.icon, launcherName)
	end
	if GameTooltip and GameTooltip:IsShown() then
		GameTooltip:Hide()
	end
end
