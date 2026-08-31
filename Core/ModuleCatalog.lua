-- Smart Chat compatibility catalog.
--
-- The bundled Chatter modules edit ChatFrameN directly.  Smart Chat owns a
-- separate presentation surface, so this catalog is deliberately descriptive:
-- it must never be used as permission to enable a legacy module while Smart
-- Chat is active.  The custom configuration can use these APIs to present
-- honest status and route a player to the feature that replaces it.
local addon = ChattyChattyBangBang

local COMPATIBILITY = {
	SMART_NATIVE = "smart-native",
	NATIVE_FALLBACK = "native-fallback-only",
	NEEDS_ADAPTER = "needs-adapter",
}

local catalog = {
	-- These are real Smart Chat features.  Their copied Chatter counterparts
	-- remain disabled because they would alter the hidden native frames.
	{ id = "chat-tabs", label = "Chat Tabs", legacyName = "ChatTabs", compatibility = COMPATIBILITY.SMART_NATIVE, configPage = "views", summary = "Message Views supplies Smart Chat's tabs, routing, order, and visibility." },
	{ id = "scrollback", label = "Scrollback & History", navLabel = "Chat History", legacyName = "Scrollback", compatibility = COMPATIBILITY.SMART_NATIVE, configPage = "dock", summary = "Smart Chat retains a separate bounded history for every source and can restore it after login or /reload." },
	{ id = "automatic-whisper-windows", label = "Automatic Whisper Windows", navLabel = "Whisper Windows", legacyName = "Automatic Whisper Windows", compatibility = COMPATIBILITY.SMART_NATIVE, configPage = "conversations", summary = "Smart Chat opens and groups whisper conversations in Messenger windows." },
	{ id = "all-edge-resizing", label = "All Edge Resizing", navLabel = "Edge Resizing", legacyName = "All Edge resizing", compatibility = COMPATIBILITY.SMART_NATIVE, configPage = "dock", summary = "Smart Chat has its own edge and corner resize handles." },
	{ id = "disable-buttons", label = "Disable Buttons", navLabel = "Chat Controls", legacyName = "Disable Buttons", compatibility = COMPATIBILITY.SMART_NATIVE, configPage = "dock", summary = "Smart Chat controls its own compact header and scroll controls." },
	{ id = "composer-auto-hide", label = "Auto-Hide Composer", navLabel = "Auto-Hide Input", legacyName = "Auto-Hide Composer", compatibility = COMPATIBILITY.SMART_NATIVE, configPage = "dock", smartSetting = "composerAutoHide", summary = "Hides the bottom composer while idle. Enter, slash, and reply reveal it temporarily while chat fills the released space." },
	{ id = "edit-box-border", label = "Typing Field Border", navLabel = "Input Border", legacyName = "Edit Box Polish", compatibility = COMPATIBILITY.SMART_NATIVE, configPage = "dock", smartSetting = "editBoxBorder", summary = "Adds or removes the optional background and border behind Chatty's typing field. The old native edit-box layout hooks remain off." },
	{ id = "disable-fading", label = "Disable Fading", legacyName = "Disable Fading", compatibility = COMPATIBILITY.SMART_NATIVE, configPage = "dock", summary = "Smart Chat messages are owned by the dock rather than native-frame fading." },
	{ id = "channel-colors", label = "Channel Colors", legacyName = "Channel Colors", compatibility = COMPATIBILITY.SMART_NATIVE, configPage = "dock", summary = "Smart Chat reads and edits the client's chat-source colors from Chat Window > Chat Colors." },
	{ id = "chat-font", label = "Chat Font", navLabel = "Message Font", legacyName = "Chat Font", compatibility = COMPATIBILITY.SMART_NATIVE, configPage = "views", summary = "Views & Tabs provides SharedMedia font, size, and outline controls globally and per tab; the copied native-frame module stays dormant." },

	-- These still work only when Smart Chat is off and the native fallback can
	-- safely own ChatFrameN.  Keep them in the catalog so their saved choices
	-- and Ace options remain discoverable without pretending they are active.
	{ id = "channel-names", label = "Channel Names", legacyName = "Channel Names", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Native-frame channel label formatter." },
	{ id = "player-class-colors", label = "Player Class Colors", navLabel = "Player Colors", legacyName = "Player Class Colors", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Native-frame player-name coloring." },
	{ id = "sticky-channels", label = "Sticky Channels", legacyName = "Sticky Channels", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Native chat edit-box channel persistence." },
	{ id = "url-copy", label = "URL Copy", legacyName = "URL Copy", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Native chat URL click and copy behavior." },
	{ id = "chat-copy", label = "Chat Copy", legacyName = "Chat Copy", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Native chat-frame copy window." },
	{ id = "timestamps", label = "Timestamps", legacyName = "Timestamps", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Native chat timestamp formatter." },
	{ id = "invite-links", label = "Invite Links", legacyName = "Invite Links", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Native chat invite-link behavior." },
	{ id = "tell-target", label = "Tell Target (/tt)", legacyName = "Tell Target (/tt)", compatibility = COMPATIBILITY.SMART_NATIVE, configPage = "conversations", configSection = "opening", smartSetting = "tellTargetEnabled", summary = "Chatty's /tt command opens your current player target in Messenger; its reply-field focus behavior is shared with /r." },
	{ id = "highlights", label = "Highlights", legacyName = "Highlights", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Native global-filter highlights. Not replayed by Smart Chat." },
	{ id = "justify-text", label = "Justify Text", legacyName = "Justify Text", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Native chat-frame text alignment." },
	{ id = "chat-autolog", label = "Chat Autolog", legacyName = "Chat Autolog", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Native chat log automation." },
	{ id = "alt-linking", label = "Alt Linking", legacyName = "Alt Linking", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Native player-name alt lookup links." },
	{ id = "tiny-chat", label = "Tiny Chat", legacyName = "Tiny Chat", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Native-frame compact layout." },
	{ id = "group-say", label = "Group Say (/gr)", legacyName = "Group Say (/gr)", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Native edit-box /gr command." },
	{ id = "link-hover", label = "Link Hover", legacyName = "Link Hover", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Native chat-link hover behavior." },
	{ id = "editbox-history", label = "Editbox History", legacyName = "Editbox History", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Native edit-box command history." },
	{ id = "delay-guild-motd", label = "Delay Guild MOTD", navLabel = "Guild MOTD Delay", legacyName = "Delay Guild MOTD", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Delays native guild-MOTD output only." },
	{ id = "bnet", label = "BNet", legacyName = "BNet", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Native Battle.net chat integration." },
	{ id = "server-positioning", label = "Server Positioning", navLabel = "Server Position", legacyName = "Server Positioning", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Server-saved native chat-frame positions." },
	{ id = "borders-background", label = "Borders / Background", navLabel = "Chat Background", legacyName = "Borders/Background", compatibility = COMPATIBILITY.NATIVE_FALLBACK, summary = "Native chat-frame borders and background." },

	-- These features should eventually be implemented against MessageEngine,
	-- SmartDock, or the shared composer.  They are catalogued now so the UI can
	-- explain the limitation rather than offering a broken enable switch.
	{ id = "mousewheel-scroll", label = "Mousewheel Scroll", navLabel = "Mousewheel", legacyName = "Mousewheel Scroll", compatibility = COMPATIBILITY.NEEDS_ADAPTER, summary = "Needs a SmartDock scrolling adapter; native version remains fallback-only." },
}

local byId = {}
for index = 1, #catalog do
	local entry = catalog[index]
	entry.legacyModuleName = entry.legacyName
	if entry.compatibility == COMPATIBILITY.SMART_NATIVE then
		entry.category = "Chat Features"
		entry.status = "smart"
		entry.statusLabel = "RUNS IN CHATTY"
	elseif entry.compatibility == COMPATIBILITY.NEEDS_ADAPTER then
		entry.category = "Legacy Compatibility"
		entry.status = "adapter"
		entry.statusLabel = "NOT YET AVAILABLE"
	else
		entry.category = "Legacy Compatibility"
		entry.status = "native"
		entry.statusLabel = "RUNS ONLY WITH NATIVE FALLBACK"
	end
	byId[entry.id] = entry
	byId[entry.legacyName] = entry
end

local function copyEntry(entry)
	if not entry then
		return nil
	end
	local result = {}
	for key, value in pairs(entry) do
		result[key] = value
	end
	return result
end

local function smartChatEnabled(owner)
	return owner.GetSmartSettings and owner:GetSmartSettings().enabled and true or false
end

function addon:GetModuleCompatibilityKinds()
	return {
		smartNative = COMPATIBILITY.SMART_NATIVE,
		nativeFallbackOnly = COMPATIBILITY.NATIVE_FALLBACK,
		needsAdapter = COMPATIBILITY.NEEDS_ADAPTER,
	}
end

function addon:GetModuleCatalog()
	local result = {}
	for index = 1, #catalog do
		-- The list is deliberately a set of sanitized, mutable copies.  It
		-- contains both the stable UI status (smart/native/adapter) and the
		-- current enabled/preference state needed to draw a compact module list.
		result[index] = self:GetModuleCatalogStatus(catalog[index].id)
	end
	return result
end

function addon:GetModuleCatalogEntry(id)
	return copyEntry(byId[id])
end

-- Dynamic status contract for the Modules UI:
--   runtime = "smart-active", "native-active", "native-ready", or
--             "needs-adapter".  compatibility remains one of the immutable
-- constants returned by GetModuleCompatibilityKinds().
function addon:GetModuleCatalogStatus(id)
	local entry = byId[id]
	if not entry then
		return nil, "unknown-module"
	end

	local result = copyEntry(entry)
	local smartEnabled = smartChatEnabled(self)
	local preferenceEnabled = true
	if self.db and self.db.profile and self.db.profile.modules then
		preferenceEnabled = self.db.profile.modules[entry.legacyName] ~= false
	end
	result.smartChatEnabled = smartEnabled
	result.preferenceEnabled = preferenceEnabled
	result.canConfigureLegacy = self.GetModule and self:GetModule(entry.legacyName, true) ~= nil or false

	if entry.compatibility == COMPATIBILITY.SMART_NATIVE then
		result.runtime = smartEnabled and "smart-active" or "smart-disabled"
		result.active = smartEnabled
		result.enabled = smartEnabled
		result.enableControl = "smart-settings"
	elseif entry.compatibility == COMPATIBILITY.NEEDS_ADAPTER then
		local canRun = self.CanRunLegacyFallback and self:CanRunLegacyFallback() or false
		local module = self.GetModule and self:GetModule(entry.legacyName, true)
		local active = not smartEnabled and canRun and module and module.IsEnabled and module:IsEnabled() or false
		result.runtime = smartEnabled and "needs-adapter" or (active and "native-active" or "native-ready")
		result.active = active and true or false
		result.enabled = preferenceEnabled
		result.nativeFallbackAvailable = not smartEnabled and canRun
		result.enableControl = "native-fallback"
	else
		local canRun = self.CanRunLegacyFallback and self:CanRunLegacyFallback() or false
		local module = self.GetModule and self:GetModule(entry.legacyName, true)
		local active = not smartEnabled and canRun and module and module.IsEnabled and module:IsEnabled() or false
		result.runtime = active and "native-active" or "native-ready"
		result.active = active and true or false
		result.enabled = preferenceEnabled
		result.nativeFallbackAvailable = not smartEnabled and canRun
		result.enableControl = "native-fallback"
	end
	return result
end

-- Legacy option tables are retained for the Blizzard/Ace fallback panel only.
-- Smart Chat callers must use the catalog's configPage or their own Smart
-- settings rather than executing native-frame option callbacks.
function addon:GetModuleCatalogLegacyOptions(id)
	local entry = byId[id]
	if not entry or not self.GetModule then
		return nil
	end
	local module = self:GetModule(entry.legacyName, true)
	if module and module.GetOptions then
		return module:GetOptions()
	end
	return nil
end

-- Saves a native-module preference through the existing guarded pathway.  A
-- true return means the preference was saved; it intentionally does not mean
-- the native module is running while Smart Chat owns presentation.
function addon:SetModuleCatalogPreference(id, enabled)
	local entry = byId[id]
	if not entry then
		return false, "unknown-module"
	end
	if entry.compatibility == COMPATIBILITY.SMART_NATIVE then
		return false, "managed-by-smart-chat"
	end
	if not self.SetLegacyModulePreference then
		return false, "legacy-preferences-unavailable"
	end
	self:SetLegacyModulePreference(entry.legacyName, enabled and true or false)
	return true, self:GetModuleCatalogStatus(entry.id)
end
