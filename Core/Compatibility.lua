local addon = ChattyChattyBangBang
local Compatibility = {}
addon.Compatibility = Compatibility

-- Keep server-specific knowledge here.  The core only depends on Wrath-era APIs.
Compatibility.Providers = {
	wrath = {
		id = "wrath",
		label = "Wrath of the Lich King",
	},
}

Compatibility.ChatAddons = {
	["Chatter"] = true,
	["Prat"] = true,
	["Prat-3.0"] = true,
	["WIM"] = true,
	["WIM-Ascension"] = true,
	["GroupBulletinBoard"] = true,
	["GroupBulletinBoardClassic"] = true,
	["LFG_Bulletin_Board"] = true,
	["LFG-Bulletin-Board"] = true,
	["YABB"] = true,
	["YAB"] = true,
	["YetAnotherBulletinBoard"] = true,
	["BasicChatMods"] = true,
	["PhanxChat"] = true,
	["ChatMOD"] = true,
	["sChat"] = true,
	["Glass"] = true,
	["EllesmereUIChat"] = true,
}

function Compatibility:RegisterProvider(id, provider)
	if not id or type(provider) ~= "table" then
		return
	end
	provider.id = id
	self.Providers[id] = provider
end

function Compatibility:GetProvider()
	if addon.ClientAPI:IsAddOnLoaded("Ascension-Plus") or addon.ClientAPI:IsAddOnLoaded("Ascension-Tools") then
		return self.Providers.ascension or self.Providers.wrath
	end
	return self.Providers.wrath
end

function Compatibility:RegisterChatAddon(addonName)
	if addonName and addonName ~= "" then
		self.ChatAddons[addonName] = true
	end
end

local function isEnabled(enabled)
	return enabled ~= nil and enabled ~= false and enabled ~= 0
end

function Compatibility:GetEnabledChatAddonConflicts()
	local conflicts = {}
	local client = addon.ClientAPI
	if not client then
		return conflicts
	end

	for index = 1, client:GetNumAddOns() do
		local name, title, notes, enabled = client:GetAddOnInfo(index)
		-- Ascension can leave a stale AddOns.txt entry enabled after the backing
		-- folder or TOC has gone away (the old WIM entry is a real example).
		-- An enabled checkbox is not enough to make that add-on a presentation
		-- conflict: only an add-on that actually made it into this UI session can
		-- own chat frames or hooks.  Chat presentation add-ons load at login, so
		-- IsAddOnLoaded is the authoritative safety gate here.
		local loaded = name and client:IsAddOnLoaded(name) or false
		if name and name ~= "ChattyChattyBangBang" and self.ChatAddons[name] and isEnabled(enabled) and loaded then
			table.insert(conflicts, {
				name = name,
				title = title or name,
				notes = notes,
			})
		end
	end

	table.sort(conflicts, function(left, right)
		return left.title < right.title
	end)
	return conflicts
end

function Compatibility:DisableAddonsAndReload(addonNames)
	if type(addonNames) ~= "table" then
		return
	end

	for _, addonName in ipairs(addonNames) do
		if addonName and addonName ~= "ChattyChattyBangBang" then
			pcall(function() addon.ClientAPI:DisableAddOn(addonName) end)
		end
	end

	pcall(function() addon.ClientAPI:SaveAddOns() end)

	if ReloadUI then
		ReloadUI()
	end
end

function Compatibility:InvitePlayer(name)
	if type(name) ~= "string" or name == "" then return end
	if _G.C_PartyInfo and type(_G.C_PartyInfo.InviteUnit) == "function" then
		_G.C_PartyInfo.InviteUnit(name)
	elseif type(_G.InviteUnit) == "function" then
		_G.InviteUnit(name)
	end
end

function Compatibility:AddFriend(name)
	if type(name) ~= "string" or name == "" then return end
	if _G.C_FriendList and type(_G.C_FriendList.AddFriend) == "function" then
		_G.C_FriendList.AddFriend(name)
	elseif type(_G.AddFriend) == "function" then
		_G.AddFriend(name)
	end
end

function Compatibility:AddServerIgnore(name)
	if type(name) ~= "string" or name == "" then return false end
	local ignore = _G.C_FriendList and _G.C_FriendList.AddIgnore
	if type(ignore) ~= "function" then ignore = _G.AddIgnore end
	if type(ignore) ~= "function" then return false end
	local ok, result = pcall(ignore, name)
	-- Dispatch is not server confirmation; legacy AddIgnore can return nil.
	return ok and result ~= false
end
