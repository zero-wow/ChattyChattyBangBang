ChattyChattyBangBang = LibStub("AceAddon-3.0"):NewAddon("ChattyChattyBangBang", "AceConsole-3.0", "AceHook-3.0") 	--, "AceHook-3.0", "AceTimer-3.0", "AceConsole-3.0", "AceEvent-3.0", "LibSink-2.0")
local FALLBACK_VERSION = "2.22.0"
local metadataVersion = GetAddOnMetadata and GetAddOnMetadata("ChattyChattyBangBang", "Version")
if type(metadataVersion) ~= "string" or metadataVersion == "" then
	metadataVersion = FALLBACK_VERSION
end
ChattyChattyBangBang.VERSION = metadataVersion
ChattyChattyBangBang.version = metadataVersion -- Compatibility for integrations expecting lowercase.

function ChattyChattyBangBang:GetVersion()
	return self.VERSION
end

local L = LibStub("AceLocale-3.0"):GetLocale("ChattyChattyBangBang")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent

local optFrame

local options = {
	type = "group",
	args = {
		defaultArgs = {
			type = "group",
			name = L["ChattyChattyBangBang"],
			args = {
				aceConfig = {
					type = "execute",
					name = L["Standalone Config"],
					desc = L["Open a standalone config window. You might consider installing |cffffff00BetterBlizzOptions|r to make the Blizzard UI options panel resizable."],
					func = function()
						InterfaceOptionsFrame:Hide()
						AceConfigDialog:SetDefaultSize("ChattyChattyBangBang", 500, 550)
						AceConfigDialog:Open("ChattyChattyBangBang")
					end
				}
			}
		},
		config = {
			type = "execute",
			guiHidden = true,
			name = L["Configure"],
			desc = L["Configure"],
			func = function()
				ChattyChattyBangBang:OpenConfig()
			end
		},
		modules = {
			type = "group",
			name = L["Modules"],
			desc = L["Modules"],
			args = {}
		}		
	}
}

local defaults = {
	profile = {
		smartChat = {
			enabled = true,
		colorway = "Obsidian Dawn",
		-- MessageEngine stores one bounded history ring per physical chat source.
		-- This restores received chat after login or /reload without duplicating a
		-- line merely because it belongs to several Smart Chat views.
		historyCapacity = 1000,
		persistHistory = true,
		historySettingsSchema = 1,
		-- Smart Chat's own text presentation.  A missing font inherits the
		-- player's current ChatFontNormal face; non-empty values are raw
		-- LibSharedMedia font keys resolved by Core/Settings.lua.
		textAppearance = {
			schema = 2,
			size = 0,
			outline = "INHERIT",
			-- ScrollingMessageFrame:SetSpacing uses pixels between rendered lines.
			-- Keep the default compact while allowing a little breathing room.
			spacing = 1,
		},
		dock = {
				point = "BOTTOMLEFT",
				x = 28,
				y = 34,
				width = 520,
				height = 250,
				locked = false,
				hideNativeChat = true,
				hideSocialButton = false,
				activeView = "general",
				railOrientation = "vertical",
				railVisibility = "always",
				visible = true,
				collapsed = false,
				showComposer = true,
				composerAutoHide = false,
				-- Keep the lower composer integrated with the chat surface unless
				-- the player explicitly enables the optional typing-field treatment.
				editBoxBorder = false,
				composerInputPolishSchema = 2,
				showScrollButtons = true,
				compactHeader = true,
				playerActions = {
					autoHide = true,
					autoHideSeconds = 10,
				},
				sourceColumnAlignment = false,
				senderColumnAlignment = false,
				columnAlignmentSpacing = 2,
				senderColumnAlignmentSpacing = 2,
				senderColumnMaxLength = 14,
				alignmentVisibleOnly = false,
				responsiveMetadata = true,
				transparency = {
					backgroundAlpha = 1,
					borderAlpha = 1,
					overallAlpha = 1,
				},
			messageBands = {
					schema = 2,
					enabled = false,
					extent = "full",
					color = { mode = "theme", theme = "surfaceRaised", r = 0.085, g = 0.112, b = 0.158 },
					alpha = 0.50,
			},
			-- Inactive rail-tab unread counts are independently adjustable; this
			-- does not style the active-view NEW marker or the tab labels.
			unreadCountAppearance = {
				schema = 1,
				alpha = 1,
				fontSize = 0, -- inherit GameFontNormalSmall
			},
			sourceColumnAlignmentFontApplied = false,
				-- Title Bar can also be "always" or "hidden"; hover preserves the
				-- compact behavior used by existing profiles.
				headerVisibility = "hover",
				newMessages = {
					enabled = true,
					showCount = true,
					maxCount = 99,
					-- Appearance is deliberately scoped to this one active-view NEW
					-- marker.  It does not restyle rail badges or the rest of the dock.
					appearance = {
						schema = 1,
						-- "header" keeps the original compact slot immediately before
						-- the collapse control.  A player move switches this to "dock"
						-- and saves the point/offsets against the chat frame itself.
						position = { anchor = "header", point = "TOPRIGHT", x = 0, y = 0 },
						alpha = 1,
						scale = 1,
						-- Zero keeps the exact size supplied by the original UI font.
						font = "default",
						fontSize = 0,
						outline = "NONE",
						color = { mode = "theme", theme = "goldBright", r = 1, g = 0.8, b = 0.39, a = 1 },
						background = { mode = "theme", theme = "accentSoft", r = 0.11, g = 0.24, b = 0.42, a = 0.99 },
						border = { mode = "theme", theme = "gold", r = 0.88, g = 0.61, b = 0.24, a = 1 },
					},
				},
				showClassificationTags = false,
				layoutRevision = 0,
			},
			launcher = {
				minimap = {
					hide = false,
					minimapPos = 220,
				},
			},
			conversations = {
				autoOpenWhispers = true,
				deferInCombat = true,
				chromeAutoHide = false,
				titleBarVisibility = "inherit",
				actionVisibility = "inherit",
				composerVisibility = "inherit",
				actionButtonStyle = "text",
				actionStripCollapsed = false,
				actionStripOrientation = "horizontal",
				windowWidth = 360,
				windowHeight = 250,
			},
			views = {
				general = true,
				newcomers = true,
				sync = false,
				conversations = true,
				group = true,
				groupFinder = true,
				guildInvites = true,
				pvp = true,
				trade = true,
				guild = true,
				system = true,
				loot = true,
			},
			railOrder = {
				"general", "newcomers", "sync", "conversations", "group", "groupFinder",
				"guildInvites", "pvp", "trade", "guild", "system", "loot",
			},
			builtInSourceViewsSchema = 2,
			viewSourceMembershipSchema = 1,
			viewOptions = {},
			learnedSources = {},
			messageRouteOverrides = {},
			messageRouteOverrideSchema = 1,
			semanticRoutes = {
				groupFinder = true,
				pvp = true,
				trade = true,
			},
			sync = {
				enabled = true,
				sources = {},
				revision = 0,
			},
			spam = {
				enabled = true,
				exemptSelf = true,
				duplicate = {
					enabled = true,
					window = 12,
					allowedCopies = 1,
					muteAfter = 3,
					minimumLength = 4,
					caseInsensitive = true,
					collapseWhitespace = true,
					stripFormatting = true,
					ignorePunctuation = false,
					crossChannels = true,
				},
				burst = {
					enabled = true,
					window = 6,
					limit = 6,
					muteDuration = 15,
				},
				escalation = {
					enabled = true,
					mutesBeforeBan = 3,
					strikeWindow = 1800,
					offenders = {},
					bans = {},
					nextBanSequence = 0,
				},
				scopes = {
					channel = true,
					["local"] = true,
					guild = false,
					group = false,
					whisper = false,
					bnet = false,
				},
			},
			alerts = {
				enabled = true,
				popout = true,
				sound = false,
				autoHideSeconds = 12,
				rules = {
					{
						id = "alert1",
						name = "YOUR NAME",
						enabled = true,
						terms = { "[PLAYER_NAME]" },
						matchAll = false,
						allSources = true,
						sources = {},
						revealDock = true,
						sound = false,
					},
				},
				sequence = 1,
				revision = 0,
			},
			blocks = {
				enabled = true,
				rules = {},
				sequence = 0,
				revision = 0,
				uiFeedback = {
					coalesce = true,
					window = 1.5,
				},
				archive = {
					schema = 1,
					enabled = true,
					maxEntries = 500,
					retentionDays = 7,
					nextSequence = 1,
					entries = {},
				},
			},
			safety = {
				confirmServerIgnore = true,
				localIgnores = {},
			},
			keywordColors = {
				lfg = "goldBright",
				lfm = "goldBright",
				lf = "goldBright",
				lf1m = "goldBright",
				lf2m = "goldBright",
				lf3m = "goldBright",
				lf4m = "goldBright",
				lf5m = "goldBright",
				lf6m = "goldBright",
				lf1dps = "goldBright",
				need = "gold",
				tank = "accent",
				ot = "accent",
				heal = "success",
				healer = "success",
				dps = "danger",
				ilvl = "gold",
				wts = "warning",
				wtb = "success",
				wtt = "accent",
				deadmines = "goldBright",
				m0 = "goldBright",
				m1 = "goldBright", m2 = "goldBright", m3 = "goldBright", m4 = "goldBright", m5 = "goldBright",
				m6 = "goldBright", m7 = "goldBright", m8 = "goldBright", m9 = "goldBright", m10 = "goldBright",
				m11 = "goldBright", m12 = "goldBright", m13 = "goldBright", m14 = "goldBright", m15 = "goldBright",
				m16 = "goldBright", m17 = "goldBright", m18 = "goldBright", m19 = "goldBright", m20 = "goldBright",
				mythic = "goldBright",
				["mythic+"] = "goldBright",
			},
			-- Kept in the initial SavedVariables schema too: Core/Settings.lua
			-- owns behavior, while this lets a brand-new profile start with the
			-- same grouped color vocabulary before settings are normalized.
			keywordColorGroups = {
				{ id = "groupFinder", label = "GROUP FINDER", color = "goldBright", terms = { "lfg", "lfm", "lf", "lf1m", "lf2m", "lf3m", "lf4m", "lf5m", "lf6m", "lf1dps" } },
				{ id = "tank", label = "TANK / OFF-TANK", color = "accent", terms = { "tank", "tnak", "tanks", "ot", "off tank" } },
				{ id = "healer", label = "HEALER", color = "success", terms = { "heal", "healer", "heals" } },
				{ id = "damage", label = "DAMAGE", color = "danger", terms = { "dps" } },
				{ id = "experienceAura", label = "EXPERIENCE AURA", color = "warning", terms = { "exp aura", "aura" } },
				{ id = "instanceLevels", label = "INSTANCE LEVELS / KEYS", color = "goldBright", terms = {
					{ term = "M0", caseSensitive = true }, { term = "M1", caseSensitive = true }, { term = "M2", caseSensitive = true }, { term = "M3", caseSensitive = true }, { term = "M4", caseSensitive = true }, { term = "M5", caseSensitive = true }, { term = "M6", caseSensitive = true }, { term = "M7", caseSensitive = true }, { term = "M8", caseSensitive = true }, { term = "M9", caseSensitive = true }, { term = "M10", caseSensitive = true }, { term = "M11", caseSensitive = true }, { term = "M12", caseSensitive = true }, { term = "M13", caseSensitive = true }, { term = "M14", caseSensitive = true }, { term = "M15", caseSensitive = true }, { term = "M16", caseSensitive = true }, { term = "M17", caseSensitive = true }, { term = "M18", caseSensitive = true }, { term = "M19", caseSensitive = true }, { term = "M20", caseSensitive = true },
					{ term = "M1+", caseSensitive = true }, { term = "M2+", caseSensitive = true }, { term = "M3+", caseSensitive = true }, { term = "M4+", caseSensitive = true }, { term = "M5+", caseSensitive = true }, { term = "M6+", caseSensitive = true }, { term = "M7+", caseSensitive = true }, { term = "M8+", caseSensitive = true }, { term = "M9+", caseSensitive = true }, { term = "M10+", caseSensitive = true }, { term = "M11+", caseSensitive = true }, { term = "M12+", caseSensitive = true }, { term = "M13+", caseSensitive = true }, { term = "M14+", caseSensitive = true }, { term = "M15+", caseSensitive = true }, { term = "M16+", caseSensitive = true }, { term = "M17+", caseSensitive = true }, { term = "M18+", caseSensitive = true }, { term = "M19+", caseSensitive = true }, { term = "M20+", caseSensitive = true },
					"mythic", "mythic+", "mythic plus", "mythic key", "mythic keys", "keystone", "keystones",
				} },
				{ id = "trade", label = "TRADE", color = "gold", terms = { "need", "ilvl", "wts", "wtb", "wtt" } },
				{ id = "warrior", label = "WARRIOR", color = "class:WARRIOR", terms = { "warrior" } }, { id = "paladin", label = "PALADIN", color = "class:PALADIN", terms = { "paladin", "pally" } },
				{ id = "hunter", label = "HUNTER", color = "class:HUNTER", terms = { "hunter" } }, { id = "rogue", label = "ROGUE", color = "class:ROGUE", terms = { "rogue" } },
				{ id = "priest", label = "PRIEST", color = "class:PRIEST", terms = { "priest" } }, { id = "deathKnight", label = "DEATH KNIGHT", color = "class:DEATHKNIGHT", terms = { "death knight", "deathknight", "dk" } },
				{ id = "shaman", label = "SHAMAN", color = "class:SHAMAN", terms = { "shaman", "shammy" } }, { id = "mage", label = "MAGE", color = "class:MAGE", terms = { "mage" } },
				{ id = "warlock", label = "WARLOCK", color = "class:WARLOCK", terms = { "warlock", "lock" } }, { id = "druid", label = "DRUID", color = "class:DRUID", terms = { "druid", "boomkin" } }, { id = "monk", label = "MONK", color = "class:MONK", terms = { "monk" } },
				{ id = "dungeons", label = "DUNGEONS", color = "goldBright", terms = { "deadmines", "dire maul", "scarlet monastery", "blackrock depths", "lower blackrock spire", "upper blackrock spire", "stratholme", "scholomance", "utgarde keep", "the nexus", "azjol-nerub", "ahn'kahet", "drak'tharon", "gundrak", "halls of lightning", "halls of stone", "culling of stratholme", "trial of the champion", "forge of souls", "pit of saron", "halls of reflection", { term = "RFC", caseSensitive = true }, { term = "SFK", caseSensitive = true }, { term = "BFD", caseSensitive = true }, { term = "RFD", caseSensitive = true }, { term = "ULD", caseSensitive = true }, { term = "ZF", caseSensitive = true }, { term = "MARA", caseSensitive = true }, { term = "BRD", caseSensitive = true }, { term = "LBRS", caseSensitive = true }, { term = "UBRS", caseSensitive = true }, { term = "DMN", caseSensitive = true }, { term = "DME", caseSensitive = true }, { term = "DMW", caseSensitive = true }, { term = "UK", caseSensitive = true }, { term = "AN", caseSensitive = true }, { term = "OK", caseSensitive = true }, { term = "DTK", caseSensitive = true }, { term = "GD", caseSensitive = true }, { term = "HOL", caseSensitive = true }, { term = "HOS", caseSensitive = true }, { term = "COT", caseSensitive = true }, { term = "TOC", caseSensitive = true }, { term = "FOS", caseSensitive = true }, { term = "POS", caseSensitive = true }, { term = "HOR", caseSensitive = true } } },
			},
			keywordColorRevision = 0,
			keywordSuggestions = {
				enabled = true,
				threshold = 5,
				window = 900,
				maxSuggestions = 24,
				dismissed = {},
				queue = {},
				sequence = 0,
			},
			channelTargets = {},
		},
		modules = {
			["Disable Fading"] = false,
			["Chat Autolog"] = false,
			["Automatic Whisper Windows"] = false,
			["Server Positioning"] = false,
		}
	}
}
--[[
	Creating a prototype for a Decorate/UnDecorate function
	Adding these in so after everything is loaded we can post decorate/undecorate the popup frames
--]]
local proto = {
	Decorate = function(self,chatframe) end,
	Popout = function(self,chatframe,srcChatFrame) end,
	TempChatFrames = {},
	AddTempChat = function(self,name) table.insert(self.TempChatFrames,name) end,
	AlwaysDecorate = function(self,chatframe) end,
}

ChattyChattyBangBang:SetDefaultModulePrototype(proto)
ChattyChattyBangBang:SetDefaultModuleState(false)

local optionFrames = {}
local ACD3 = LibStub("AceConfigDialog-3.0")

function ChattyChattyBangBang:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("ChattyChattyBangBangDB", defaults, "Default")
	if self.GetSmartSettings then
		self:GetSmartSettings()
	end

	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("ChattyChattyBangBang", options)
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("ChattyChattyBangBangModules", options.args.modules)
	optFrame = ACD3:AddToBlizOptions("ChattyChattyBangBang", nil, nil, "defaultArgs")
	
	for k, v in self:IterateModules() do
		local moduleName = k
		options.args.modules.args[moduleName:gsub(" ", "_")] = {
			type = "group",
			name = (v.modName or moduleName),
			args = nil
		}
		local t
		if v.GetOptions then
			t = v:GetOptions()
			t.settingsHeader = {
				type = "header",
				name = L["Settings"],
				order = 12
			}		
		end
		t = t or {}
		t.toggle = {
			type = "toggle", 
			name = v.toggleLabel or (L["Enable "] .. (v.modName or moduleName)), 
			width = "double",
			desc = v.Info and v:Info() or (L["Enable "] .. (v.modName or moduleName)), 
			order = 11,
			get = function()
				return ChattyChattyBangBang.db.profile.modules[moduleName] ~= false or false
			end,
			set = function(info, v)
				local active = ChattyChattyBangBang:SetLegacyModulePreference(moduleName, v)
				if v and active then
					ChattyChattyBangBang:Print(L["Enabled"], moduleName, L["Module"])
				elseif v then
					ChattyChattyBangBang:Print(moduleName .. " is saved for native fallback; it remains dormant while another chat system owns presentation.")
				else
					ChattyChattyBangBang:Print(L["Disabled"], moduleName, L["Module"])
				end
			end
		}
		t.header = {
			type = "header",
			name = v.modName or moduleName,
			order = 9
		}
		if v.Info then
			t.description = {
				type = "description",
				name = v:Info() .. "\n\n",
				order = 10
			}
		end
		options.args.modules.args[moduleName:gsub(" ", "_")].args = t
	end	
	
	local moduleList = {}
	local moduleNames = {}
	for k, v in pairs(options.args.modules.args) do
		moduleList[v.name] = k
		tinsert(moduleNames, v.name)
	end
	table.sort(moduleNames)
	for _, name in ipairs(moduleNames) do
		ACD3:AddToBlizOptions("ChattyChattyBangBangModules", name, "ChattyChattyBangBang", moduleList[name])
	end
	
	self:RegisterChatCommand("ChattyChattyBangBang", "OpenConfig")
	
	self.db.RegisterCallback(self, "OnProfileChanged", "SetUpdateConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "SetUpdateConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "SetUpdateConfig")
	
	self:AddMenuHook(self, {
		text = L["ChattyChattyBangBang Settings"],
		func = function()
			ChattyChattyBangBang:OpenConfig()
		end,
		notCheckable = 1
	})
	self:InstallRootHooks()

	if self.Launcher then
		self.Launcher:Initialize()
	end
end

do
	local info = {}
	local menuHooks = {}
	function ChattyChattyBangBang:AddMenuHook(module, hook)
		menuHooks[module] = hook
	end
	
	function ChattyChattyBangBang:RemoveMenuHook(module)
		menuHooks[module] = nil
	end
	
	function ChattyChattyBangBang:FCF_Tab_OnClick(...)
		self.hooks.FCF_Tab_OnClick(...)
		for module, v in pairs(menuHooks) do
			if module == self or not module.IsEnabled or module:IsEnabled() then
				local menu
				if type(v) == "table" then
					menu = v
				else
					menu = module[v](module, ...)
				end
				UIDropDownMenu_AddButton(menu)
			end
		end
	end
end

function ChattyChattyBangBang:InstallRootHooks()
	if not (self.hooks and self.hooks.FCF_Tab_OnClick) then
		self:RawHook("FCF_Tab_OnClick", true)
	end
	if not (self.hooks and self.hooks.FCF_OpenTemporaryWindow) then
		self:RawHook("FCF_OpenTemporaryWindow", true)
	end
end

function ChattyChattyBangBang:RemoveRootHooks()
	if self.hooks and self.hooks.FCF_Tab_OnClick then
		self:Unhook("FCF_Tab_OnClick")
	end
	if self.hooks and self.hooks.FCF_OpenTemporaryWindow then
		self:Unhook("FCF_OpenTemporaryWindow")
	end
end

function ChattyChattyBangBang:FCF_OpenTemporaryWindow(chatType, chatTarget, sourceChatFrame, selectWindow)
	local frame = self.hooks.FCF_OpenTemporaryWindow(chatType, chatTarget, sourceChatFrame, selectWindow)
	if frame and self.SmartDock and self.SmartDock.SuppressTemporaryChatFrame then
		self.SmartDock:SuppressTemporaryChatFrame(frame)
	end
	if frame and self.legacyFallbackActive then
		for k, v in self:IterateModules() do
			if not frame.isDecorated then
				v:AddTempChat(frame:GetName())
			end
			if v:IsEnabled() and not frame.isDecorated then
				v:Decorate(frame)
			end
			if v:IsEnabled() then
				v:Popout(frame,sourceChatFrame or DEFAULT_CHAT_FRAME)
			end
			v:AlwaysDecorate(frame)
		end
		frame.isDecorated = true
	end
	FCFDock_ForceReanchoring(GENERAL_CHAT_DOCK)
	return frame
end

function ChattyChattyBangBang:OpenConfig(input)
	if self.IsEnabled and not self:IsEnabled() then
		return
	end
	if self.CustomConfig then
		self.CustomConfig:Open()
		return
	end

	if input == "config" or not InterfaceOptionsFrame:IsResizable() then
		options.args.defaultArgs.guiHidden = true
		InterfaceOptionsFrame:Hide()
		AceConfigDialog:SetDefaultSize("ChattyChattyBangBang", 500, 550)
		AceConfigDialog:Open("ChattyChattyBangBang")
	else
		InterfaceOptionsFrame_OpenToCategory(ChattyChattyBangBang.lastConfig)
		options.args.defaultArgs.guiHidden = false
		InterfaceOptionsFrame_OpenToCategory(optFrame)
	end
end

do
	local timer, t, pending = nil, 0, false
	local function update(_, elapsed)
		t = t + (elapsed or arg1 or 0)
		if t > 0.5 then
			timer:SetScript("OnUpdate", nil)
			pending = false
			if not ChattyChattyBangBang.IsEnabled or ChattyChattyBangBang:IsEnabled() then
				ChattyChattyBangBang:UpdateConfig()
			end
		end
	end
	function ChattyChattyBangBang:SetUpdateConfig()
		if self.IsEnabled and not self:IsEnabled() then
			return
		end
		t = 0
		pending = true
		timer = timer or CreateFrame("Frame", nil, UIParent)
		timer:SetScript("OnUpdate", update)
	end
	function ChattyChattyBangBang:CancelUpdateConfig()
		pending = false
		t = 0
		if timer then
			timer:SetScript("OnUpdate", nil)
		end
	end
end

function ChattyChattyBangBang:UpdateConfig()
	if self.SmartDock and self.SmartDock.PrepareForProfileChange then
		self.SmartDock:PrepareForProfileChange()
	end
	if self.ConversationWindows and self.ConversationWindows.ResetForProfile then
		self.ConversationWindows:ResetForProfile()
	end
	if self.SpamControl and self.SpamControl.ResetForProfile then
		self.SpamControl:ResetForProfile()
	end
	if self.BlockControl and self.BlockControl.ResetForProfile then
		self.BlockControl:ResetForProfile()
	end
	if self.MessageEngine and self.MessageEngine.ResetForProfile then
		self.MessageEngine:ResetForProfile()
	end
	if self.KeywordSuggestions and self.KeywordSuggestions.ResetForProfile then
		self.KeywordSuggestions:ResetForProfile()
	end
	if self.AlertEngine and self.AlertEngine.ResetForProfile then
		self.AlertEngine:ResetForProfile()
	end
	local settings = self:GetSmartSettings()
	if self.SpamControl then
		self.SpamControl:SetEnabled(settings.spam and settings.spam.enabled)
	end
	if self.BlockControl then
		self.BlockControl:SetEnabled(settings.blocks and settings.blocks.enabled)
	end
	if self.AlertEngine then
		self.AlertEngine:SetEnabled(settings.alerts and settings.alerts.enabled)
	end
	if self.Theme then
		self.Theme:Refresh()
	end
	if self.SmartDock and self.SmartDock.ApplyProfile then
		self.SmartDock:ApplyProfile()
	end
	if self.Launcher and self.Launcher.ApplyProfile then
		self.Launcher:ApplyProfile()
	end
	self:SetSmartChatEnabled(settings.enabled)
	if self.CustomConfig and self.CustomConfig.ReloadProfile then
		-- Rebuild/refresh after activation so Control Center reports the final
		-- dock state instead of the temporary deactivated profile-transition state.
		self.CustomConfig:ReloadProfile()
	end
end

function ChattyChattyBangBang:OnEnable()
	self:InstallRootHooks()
	if self.Launcher then
		self.Launcher:Initialize()
	end
	if not self.db.profile.welcomeMessaged then
		self:Print(L["Welcome to ChattyChattyBangBang! Type /ChattyChattyBangBang to configure."])
		self.db.profile.welcomeMessaged = true
	end
	if self.SpamControl then
		self.SpamControl:Initialize()
		self.SpamControl:SetEnabled(self:GetSmartSettings().spam.enabled)
	end
	if self.BlockControl then
		self.BlockControl:Initialize()
		self.BlockControl:SetEnabled(self:GetSmartSettings().blocks.enabled)
	end
	if self.MessageEngine then
		self.MessageEngine:Initialize()
	end
	if self.KeywordSuggestions then
		self.KeywordSuggestions:Initialize()
	end
	if self.AlertEngine then
		self.AlertEngine:Initialize()
		self.AlertEngine:SetEnabled(self:GetSmartSettings().alerts.enabled)
	end
	if self.ConversationWindows then
		self.ConversationWindows:Initialize()
	end
	if self.SmartDock then
		self.SmartDock:Initialize()
	end
	self:SetSmartChatEnabled(self:GetSmartSettings().enabled)
	
	if not options.args.Profiles then
 		options.args.Profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
		self.lastConfig = ACD3:AddToBlizOptions("ChattyChattyBangBang", L["Profiles"], "ChattyChattyBangBang", "Profiles")
	end
end

function ChattyChattyBangBang:OnDisable()
	self:CancelUpdateConfig()
	if self.SpamControl then
		self.SpamControl:SetEnabled(false)
	end
	if self.BlockControl then
		self.BlockControl:SetEnabled(false)
	end
	if self.SmartDock then
		self.SmartDock:SetEnabled(false)
	end
	if self.MessageEngine then
		self.MessageEngine:SetEnabled(false)
	end
	if self.AlertEngine then
		self.AlertEngine:SetEnabled(false)
	end
	if self.ConversationWindows then
		self.ConversationWindows:SetEnabled(false)
	end
	if self.ApplyLegacyModuleState then
		self:ApplyLegacyModuleState(false)
	end
	if self.CustomConfig and self.CustomConfig.Shutdown then
		self.CustomConfig:Shutdown()
	end
	if self.Launcher and self.Launcher.Shutdown then
		self.Launcher:Shutdown()
	end
	self:RemoveRootHooks()
end
