local addon = ChattyChattyBangBang

-- Keep modern-client differences in one small boundary.  Feature code should
-- call this table instead of branching on a particular expansion or server.
local ClientAPI = {}
addon.ClientAPI = ClientAPI

local projectId = _G.WOW_PROJECT_ID
local tocVersion
if _G.GetBuildInfo then
	local _, _, _, value = _G.GetBuildInfo()
	tocVersion = tonumber(value)
end
ClientAPI.isRetail = (projectId ~= nil and projectId == _G.WOW_PROJECT_MAINLINE)
	or (tocVersion ~= nil and tocVersion >= 100000)

function ClientAPI:IsRetail()
	return self.isRetail
end

function ClientAPI:IsAddOnLoaded(name)
	if type(name) ~= "string" or name == "" then
		return false
	end
	if _G.C_AddOns and type(_G.C_AddOns.IsAddOnLoaded) == "function" then
		return _G.C_AddOns.IsAddOnLoaded(name) and true or false
	end
	return _G.IsAddOnLoaded and _G.IsAddOnLoaded(name) and true or false
end

function ClientAPI:GetNumAddOns()
	if _G.C_AddOns and type(_G.C_AddOns.GetNumAddOns) == "function" then
		return _G.C_AddOns.GetNumAddOns() or 0
	end
	return _G.GetNumAddOns and _G.GetNumAddOns() or 0
end

function ClientAPI:GetAddOnInfo(index)
	if _G.C_AddOns and type(_G.C_AddOns.GetAddOnInfo) == "function" then
		local addonName = _G.C_AddOns.GetAddOnName and _G.C_AddOns.GetAddOnName(index) or index
		local name, title, notes = _G.C_AddOns.GetAddOnInfo(addonName)
		if name then
			local enabled = _G.C_AddOns.GetAddOnEnableState
				and _G.C_AddOns.GetAddOnEnableState(name)
			return name, title, notes, enabled
		end
	end
	if _G.GetAddOnInfo then
		return _G.GetAddOnInfo(index)
	end
	return nil
end

function ClientAPI:SetFrameResizeBounds(frame, minWidth, minHeight, maxWidth, maxHeight)
	if type(frame.SetResizeBounds) == "function" then
		frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
		return true
	end
	if type(frame.SetMinResize) == "function" and type(frame.SetMaxResize) == "function" then
		frame:SetMinResize(minWidth, minHeight)
		frame:SetMaxResize(maxWidth, maxHeight)
		return true
	end
	return false
end

function ClientAPI:DisableAddOn(name)
	if _G.C_AddOns and type(_G.C_AddOns.DisableAddOn) == "function" then
		return _G.C_AddOns.DisableAddOn(name)
	end
	if _G.DisableAddOn then
		return _G.DisableAddOn(name)
	end
end

function ClientAPI:SaveAddOns()
	if _G.C_AddOns and type(_G.C_AddOns.SaveAddOns) == "function" then
		return _G.C_AddOns.SaveAddOns()
	end
	if _G.SaveAddOns then
		return _G.SaveAddOns()
	end
end

function ClientAPI:GetHomeGroupChatType()
	-- Retail can have a home party and an instance group at the same time.
	-- Query the home category explicitly so the route never points at the
	-- other group just because it happens to be a raid.
	local homeCategory = self.isRetail and _G.LE_PARTY_CATEGORY_HOME or nil
	if _G.IsInRaid and _G.IsInRaid(homeCategory) then
		return "RAID"
	end
	if _G.IsInGroup and _G.IsInGroup(homeCategory) then
		return "PARTY"
	end
	-- Wrath keeps its member-count APIs; those counts cannot distinguish a
	-- Retail home group from an instance group.
	if not self.isRetail and _G.GetNumRaidMembers and (_G.GetNumRaidMembers() or 0) > 0 then
		return "RAID"
	end
	if not self.isRetail and _G.GetNumPartyMembers and (_G.GetNumPartyMembers() or 0) > 0 then
		return "PARTY"
	end
	return nil
end

function ClientAPI:GetGroupChatType()
	if self.isRetail then
		-- Location is not group membership: a premade party inside a dungeon
		-- still uses PARTY/RAID. Only a real instance-category group uses this
		-- Retail chat type (including queued battlegrounds and arenas).
		if _G.LE_PARTY_CATEGORY_INSTANCE ~= nil and _G.IsInGroup
			and _G.IsInGroup(_G.LE_PARTY_CATEGORY_INSTANCE) then
			return "INSTANCE_CHAT"
		end
	else
		local inInstance, instanceType
		if _G.IsInInstance then
			inInstance, instanceType = _G.IsInInstance()
		end
		if inInstance and (instanceType == "pvp" or instanceType == "arena") then
			return "BATTLEGROUND"
		end
	end
	return self:GetHomeGroupChatType()
end

function ClientAPI:OpenConfiguration(aceConfigDialog, addonName, width, height)
	-- The custom configuration is expansion-neutral.  Opening it directly also
	-- avoids deprecated InterfaceOptionsFrame globals on current Retail.
	if aceConfigDialog then
		aceConfigDialog:SetDefaultSize(addonName, width, height)
		aceConfigDialog:Open(addonName)
		return true
	end
	return false
end
