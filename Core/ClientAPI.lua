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
		local info = _G.C_AddOns.GetAddOnInfo(index)
		if type(info) == "table" then
			return info.name, info.title, info.notes, info.enabled
		end
	end
	if _G.GetAddOnInfo then
		return _G.GetAddOnInfo(index)
	end
	return nil
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

function ClientAPI:GetGroupChatType()
	local inInstance, instanceType
	if _G.IsInInstance then
		inInstance, instanceType = _G.IsInInstance()
	end
	if inInstance and (instanceType == "pvp" or instanceType == "arena") then
		return "BATTLEGROUND"
	end
	-- Retail exposes group state through these predicates. Wrath keeps its
	-- member-count APIs, which remain the fallback below.
	if _G.IsInRaid and _G.IsInRaid() then
		return "RAID"
	end
	if _G.IsInGroup and _G.IsInGroup() then
		return "PARTY"
	end
	if _G.GetNumRaidMembers and (_G.GetNumRaidMembers() or 0) > 0 then
		return "RAID"
	end
	if _G.GetNumPartyMembers and (_G.GetNumPartyMembers() or 0) > 0 then
		return "PARTY"
	end
	return nil
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
