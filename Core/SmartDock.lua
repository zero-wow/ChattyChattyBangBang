local addon = ChattyChattyBangBang
local Theme = addon.Theme
local Presentation = addon.Presentation
local Dock = {}
addon.SmartDock = Dock

local readOnlyViews = {
	-- Sync is protocol traffic: deliberately never offer a route that could send
	-- a player-authored line back into it. System, loot, and custom filter views
	-- are ordinary lenses and can safely use the shared chat editor's route menu.
	sync = true,
}

local viewById = {}

local EXPANDED_MIN_WIDTH = 360
local EXPANDED_MIN_HEIGHT = 160
local EXPANDED_MAX_WIDTH = 1050
local EXPANDED_MAX_HEIGHT = 720
local COLLAPSED_WIDTH = 220
local COLLAPSED_HEIGHT = 28
local COMPOSER_INSET = 2
local COMPOSER_HEIGHT = 24
-- The composer begins two pixels inside the outer dock edge.  Reserving its
-- height plus that same inset lets the readable surface meet it exactly,
-- rather than leaving a stray two-pixel strip of frame background between the
-- chat body and the typing lane.
local COMPOSER_RESERVED_HEIGHT = COMPOSER_HEIGHT + COMPOSER_INSET
local COMPOSER_ACTION_GAP = 2
-- The route control is part of the input sentence, not a separate toolbar.
-- Keep it only as wide as its current label needs; the real edit box owns all
-- of the remaining composer lane.
local COMPOSER_ROUTE_MIN_WIDTH = 36
local COMPOSER_ROUTE_MAX_WIDTH = 120
local COMPOSER_ROUTE_WIDTH = 42
local COMPOSER_ROUTE_TEXT_PADDING = 10
local DISPLAY_HINT_DELAY = 0.7
local COMPOSER_ROUTE_MENU_COLUMNS = 2
local COMPOSER_ROUTE_MENU_ROWS = 5
local COMPOSER_ROUTE_MENU_BUTTON_WIDTH = 98
local COMPOSER_ROUTE_MENU_BUTTON_HEIGHT = 18
local COMPOSER_ROUTE_MENU_GAP = 2
local PLAYER_ACTION_BUTTON_HEIGHT = 18
local PLAYER_ACTION_BUTTON_GAP = 2
local PLAYER_ACTION_PANEL_PADDING = 4
local PLAYER_ACTION_PANEL_WIDE_HEIGHT = 46
local PLAYER_ACTION_PANEL_COMPACT_HEIGHT = 66
-- Timed alerts and the player-name action menu are real transient rows, not
-- paint laid over readable chat. Each panel begins two pixels inside content;
-- adding its height plus that two-pixel edge run ahead of the display's normal
-- four-pixel inset leaves a visible four-pixel panel-to-message gutter.
local TRANSIENT_PANEL_RESERVATION = 2
local ALERT_PANEL_HEIGHT = 34
local TRANSIENT_MESSAGE_LINE_HEIGHT_FALLBACK = 12
-- Resize targets deliberately live inside the existing outer border.  Four
-- pixels is enough to be easy to acquire without taking a meaningful slice of
-- the message surface, while four-pixel corners make diagonal resizing
-- discoverable without adding a visual grip or extra chrome.
local RESIZE_EDGE_HIT_THICKNESS = 4
local RESIZE_CORNER_HIT_SIZE = 4
-- The active resize edge is a real visual affordance, not a cursor trick.
-- Two pixels of the palette's accent color stays legible beside the normal
-- one-pixel frame border without adding a permanent grip or extra padding.
local RESIZE_HIGHLIGHT_THICKNESS = 2
local RAIL_SETTINGS_ICON_ROOT = "Interface\\AddOns\\ChattyChattyBangBang\\Media\\Dock\\Settings\\"
-- The rail itself has a 20px usable lane (24px tall with its 2px inset), so
-- let the art occupy that lane instead of surrounding it with a button shell
-- or needless empty pixels.  The invisible button is the same compact 20px
-- hit target in both orientations.
local RAIL_SETTINGS_ICON_SIZE = 20
local RAIL_SETTINGS_HIT_SIZE = 20
-- Reordering the live chat tabs is deliberately a modifier-only gesture.  A
-- short movement threshold means an ordinary Shift-click remains a normal tab
-- selection, while a real Shift-drag has a clear, stable insertion target.
local RAIL_REORDER_DRAG_DISTANCE = 4
local RAIL_REORDER_MARKER_THICKNESS = 2
local RAIL_REORDER_AUTO_SCROLL_EDGE = 10
local RAIL_REORDER_AUTO_SCROLL_SPEED = 150
local RAIL_REORDER_CLICK_SUPPRESS_SECONDS = 0.25
-- Wheel input over a child Button does not reliably bubble to its parent
-- ScrollFrame on Wrath-derived clients. Bind every rail surface to the same
-- axis-aware handler and move by one compact tab-sized step per wheel notch.
local RAIL_MOUSE_WHEEL_STEP = 44
local ALIGNMENT_SETTINGS_FULL_LABEL_MIN_CONTENT_WIDTH = 320
local ALIGNMENT_SETTINGS_LABEL_PADDING = 8
local ALIGNMENT_SETTINGS_CONTROL_GAP = 4
-- The message scroller is intentionally thumb-only.  Its eight-pixel hit lane
-- sits three pixels from both the outer edge and rendered text, so neither the
-- control nor its hit target touches a border or steals a wide chat column.
local MESSAGE_SCROLLBAR_WIDTH = 8
local MESSAGE_SCROLLBAR_THUMB_WIDTH = 6
local MESSAGE_SCROLLBAR_MIN_THUMB_HEIGHT = 18
local MESSAGE_SCROLLBAR_RIGHT_INSET = 3
local MESSAGE_SCROLLBAR_TEXT_GUTTER = 3
local MESSAGE_SCROLLBAR_VERTICAL_INSET = 4
local MESSAGE_SCROLL_TO_BOTTOM_WIDTH = 10
local MESSAGE_SCROLL_TO_BOTTOM_HEIGHT = 16
local MESSAGE_SCROLL_TO_BOTTOM_GAP = 4
local MESSAGE_SCROLLBAR_DISPLAY_INSET = MESSAGE_SCROLLBAR_RIGHT_INSET
	+ math.max(MESSAGE_SCROLLBAR_WIDTH, MESSAGE_SCROLL_TO_BOTTOM_WIDTH)
	+ MESSAGE_SCROLLBAR_TEXT_GUTTER
-- Full-width row shading may paint through the otherwise transparent scrollbar
-- lane, but stops at the backdrop's one-pixel inner inset so the panel border
-- remains crisp. The message viewport and scrollbar hit geometry never move.
local MESSAGE_BAND_PANEL_EDGE_INSET = 1
-- When the title bar is intentionally hidden, the unused portion of the tab
-- rail becomes its quiet replacement grab area.  Use the same small movement
-- threshold as tab reordering so a simple click in the rail never nudges the
-- dock or steals a tab/settings interaction.
local RAIL_MOVE_DRAG_DISTANCE = 4
-- Source-column alignment deliberately follows the active Smart Chat font.  A
-- fixed-pitch face makes the compact TIME | CHANNEL | message layout exact;
-- the typography controls live with the views that use it rather than quietly
-- inheriting a native-frame-only Chatter module.
-- Source alignment belongs to the tab currently being read.  The player picks
-- a compact number of character cells after that tab's longest active source,
-- rather than turning
-- SYSTEM into a twelve-cell blank gutter just because another tab has a long
-- label.  A modest upper bound still prevents one malformed historical label
-- from creating a canyon; Presentation abbreviates only that outlier.
local SOURCE_COLUMN_MAX_CHARACTER_CAP = 14
-- The historical sixteen-cell sender lane held fourteen visible name cells and
-- two brackets. Keep that exact default while allowing the player to choose a
-- smaller/larger truncation ceiling. The bounds are presentation-only and never
-- alter the sender identity used by links, actions, routing, or saved history.
local SENDER_COLUMN_MAX_NAME_DEFAULT = 14
local SENDER_COLUMN_MAX_NAME_MIN = 1
local SENDER_COLUMN_MAX_NAME_MAX = 32
local COLUMN_ALIGNMENT_SPACING_MIN = -8
local COLUMN_ALIGNMENT_SPACING_MAX = 8
-- Responsive metadata protects the actual conversation before preserving
-- decorative alignment.  These thresholds are measured fixed-font cells, not
-- guessed pixels: a full metadata row needs a comfortable 24-cell message
-- lane, the timestamp-free row needs 18, and a sender-only row needs 12.
-- Between the first two stages the aligned name lane contracts from sixteen
-- cells to twelve and its runtime gutter contracts to at most one cell.  The
-- saved alignment toggles and gutter remain untouched, so widening the dock
-- restores the player's exact configured presentation.
local RESPONSIVE_WIDE_MIN_BODY_COLUMNS = 24
local RESPONSIVE_MEDIUM_MIN_BODY_COLUMNS = 18
local RESPONSIVE_NARROW_MIN_BODY_COLUMNS = 12
local RESPONSIVE_COMPACT_SENDER_CHARACTER_CAP = 12
local RESPONSIVE_COMPACT_SENDER_SPACING_CAP = 1
local RESPONSIVE_TIMESTAMP_CHARACTER_FALLBACK = 5
-- ScrollingMessageFrame's drawable line is fractionally narrower than the raw
-- frame width on Wrath-derived clients, and fallback glyphs (notably Cyrillic)
-- need not share Source Code Pro's exact advance. Leave two measured fixed-font
-- cells unused, then validate each generated line against the live hidden
-- FontString before AddMessage so Blizzard never performs a second native wrap.
local MANUAL_WRAP_SAFETY_COLUMNS = 2
local MANUAL_WRAP_PIXEL_SAFETY = 1
local MANUAL_WRAP_VALIDATION_PASSES = 4
-- Alternating message bands are drawn as one texture per visible logical chat
-- entry, never one texture per wrapped line.  Eight-point text inside the
-- dock's 720px maximum height can expose fewer than ninety entries at once;
-- 128 keeps the pool strictly bounded while covering every supported layout.
local MESSAGE_BAND_POOL_LIMIT = 128
-- Shift-hover actions belong to one logical message, even when that message
-- wraps across several rendered rows. Paint one theme-aware selection behind
-- the readable glyphs so the BLOCK / ANALYZE target stays unmistakable without
-- becoming another mouse surface or disturbing chat layout.
local MESSAGE_ACTION_HIGHLIGHT_ALPHA = 0.18
-- ScrollingMessageFrame supports a per-rendered-line pixel gap but has no
-- per-message height API. A logical-entry gap is therefore represented by a
-- transparent, non-empty physical row inside the *same* AddMessage call. Keep
-- the markup here so the renderer, cache, and focused mock share one exact
-- contract. A bare newline is not reliable on old clients because a trailing
-- empty line can be discarded by either the message frame or FontString.
local ENTRY_GAP_SPACER_ROW = "|c00FFFFFF |r\n"
local ENTRY_GAP_ROWS_MIN = 0
local ENTRY_GAP_ROWS_MAX = 2
local MESSAGE_BAND_EXTENTS = {
	full = true,
	afterTimestamp = true,
	afterChannel = true,
	afterPlayer = true,
}
-- The unread marker shares SHIFT as the dock's explicit configuration gesture.
-- Keep the movement threshold tiny enough to feel direct, while a Shift-click
-- still retains the familiar jump-to-newest action.
local NEW_MESSAGE_INDICATOR_DRAG_DISTANCE = 3
local NEW_MESSAGE_INDICATOR_EDGE_INSET = 2
local RAIL_TAB_MIN_WIDTH = 38
local RAIL_TAB_HEIGHT = 20
local RAIL_TAB_TEXT_INSET = 3
local RAIL_UNREAD_COUNT_FONT_SIZE_MIN = 8
local RAIL_UNREAD_COUNT_FONT_SIZE_MAX = 16

-- Keep the resize contract declarative: each segment owns precisely the
-- matching StartSizing direction and only lights that segment of the border.
-- These direction names are supported by the Wrath-era Frame API.
local resizeHandleDefinitions = {
	{ id = "topLeft", direction = "TOPLEFT", horizontal = "TOP", vertical = "LEFT", corner = "TOPLEFT" },
	{ id = "top", direction = "TOP", horizontal = "TOP", edge = "TOP" },
	{ id = "topRight", direction = "TOPRIGHT", horizontal = "TOP", vertical = "RIGHT", corner = "TOPRIGHT" },
	{ id = "left", direction = "LEFT", vertical = "LEFT", edge = "LEFT" },
	{ id = "right", direction = "RIGHT", vertical = "RIGHT", edge = "RIGHT" },
	{ id = "bottomLeft", direction = "BOTTOMLEFT", horizontal = "BOTTOM", vertical = "LEFT", corner = "BOTTOMLEFT" },
	{ id = "bottom", direction = "BOTTOM", horizontal = "BOTTOM", edge = "BOTTOM" },
	{ id = "bottomRight", direction = "BOTTOMRIGHT", horizontal = "BOTTOM", vertical = "RIGHT", corner = "BOTTOMRIGHT" },
}

-- The rail settings control intentionally uses authored normal, hover, and
-- pressed art.  Do not synthesize a faction tint or a hover effect here: the
-- source artwork owns each interaction state, just like the Messenger action
-- icons do.
local railSettingsIconStateSuffixes = {
	normal = "",
	hover = "-hover",
	pressed = "-pressed",
}

local function presentationColumnCount(value)
	value = tostring(value or "")
	if Presentation and type(Presentation.GetRenderedColumnCount) == "function" then
		local ok, count = pcall(Presentation.GetRenderedColumnCount, Presentation, value)
		if ok and tonumber(count) then return math.max(0, math.floor(count)) end
	end
	return #value
end

local function getRailSettingsIconFaction()
	if UnitFactionGroup and UnitFactionGroup("player") == "Horde" then
		return "Horde"
	end
	-- Alliance is the known neutral/login fallback, matching the existing
	-- faction-aware Messenger icon behavior.
	return "Alliance"
end

local function getRailSettingsIconPath(state)
	state = railSettingsIconStateSuffixes[state] and state or "normal"
	return RAIL_SETTINGS_ICON_ROOT
		.. getRailSettingsIconFaction()
		.. "\\config"
		.. railSettingsIconStateSuffixes[state]
		.. ".tga"
end

local function trySetRailSettingsIconTexture(texture, texturePath)
	if not texture or not texturePath then
		return false
	end

	local applied, accepted = pcall(texture.SetTexture, texture, texturePath)
	-- Ascension resolves textures lazily and normalizes its lookup paths while
	-- trying BLP before the supplied TGA.  GetTexture can therefore be nil or
	-- a different-looking path immediately after a successful SetTexture call.
	-- Treat only an actual API failure as unavailable; the staged asset is
	-- already present and the normal text fallback remains in the header.
	return applied and accepted ~= false
end

local function setRailSettingsIconState(button, state)
	if not button or not button.icon then
		return false
	end

	state = railSettingsIconStateSuffixes[state] and state or "normal"
	button.railSettingsIconState = state
	local texture = button.icon
	texture:ClearAllPoints()
	texture:SetSize(RAIL_SETTINGS_ICON_SIZE, RAIL_SETTINGS_ICON_SIZE)
	texture:SetPoint("CENTER", button, "CENTER", 0, 0)

	-- A missing hover/pressed variant can still use the authored normal icon;
	-- only a missing normal image returns to the clearly labeled CFG fallback.
	if trySetRailSettingsIconTexture(texture, getRailSettingsIconPath(state))
		or (state ~= "normal" and trySetRailSettingsIconTexture(texture, getRailSettingsIconPath("normal"))) then
		texture:Show()
		if button.text then
			button.text:Hide()
		end
		return true
	end

	texture:SetTexture(nil)
	texture:Hide()
	if button.text then
		button.text:Show()
	end
	return false
end

local railVisibilityAliases = {
	always = "always",
	show = "always",
	shown = "always",
	visible = "always",
	on = "always",
	click = "click",
	onclick = "click",
	auto = "click",
	autohide = "click",
	toggle = "click",
	mouseover = "mouseover",
	onmouseover = "mouseover",
	hover = "mouseover",
	onhover = "mouseover",
	hidden = "hidden",
	hide = "hidden",
	off = "hidden",
	never = "hidden",
	none = "hidden",
}

local function normalizeRailVisibility(value)
	if value == true then
		return "always"
	elseif value == false then
		return "hidden"
	elseif type(value) == "string" then
		local compact = string.lower(value)
		compact = string.gsub(compact, "[%s_%-]", "")
		return railVisibilityAliases[compact] or "always"
	end
	return "always"
end

-- Title-bar presentation is deliberately independent from the Chat Tabs Rail.
-- A player can keep useful controls visible without forcing the rail to occupy
-- space, show them only on hover, or hide the title bar while expanded.
local headerVisibilityAliases = {
	hover = "hover",
	mouseover = "hover",
	onhover = "hover",
	auto = "hover",
	autohide = "hover",
	contextual = "hover",
	always = "always",
	show = "always",
	shown = "always",
	visible = "always",
	on = "always",
	["true"] = "always",
	["1"] = "always",
	["false"] = "hover",
	["0"] = "hover",
	hidden = "hidden",
	hide = "hidden",
	off = "hidden",
	never = "hidden",
	none = "hidden",
	disabled = "hidden",
	disable = "hidden",
}

local function normalizeHeaderVisibility(value)
	if value == true then
		return "always"
	elseif value == false then
		return "hover"
	elseif type(value) == "string" then
		local compact = string.lower(value)
		compact = string.gsub(compact, "[%s_%-]", "")
		return headerVisibilityAliases[compact] or "hover"
	end
	return "hover"
end

local function getConfiguredRailVisibility()
	local settings = addon:GetSmartSettings()
	settings.dock = settings.dock or {}
	local dockSettings = settings.dock
	local mode = normalizeRailVisibility(dockSettings.railVisibility)
	-- Canonicalize old booleans/aliases and recover invalid profile data in place.
	if dockSettings.railVisibility ~= mode then
		dockSettings.railVisibility = mode
	end
	return mode
end

local function getConfiguredHeaderVisibility()
	local settings = addon:GetSmartSettings()
	settings.dock = settings.dock or {}
	local dockSettings = settings.dock
	local mode = normalizeHeaderVisibility(dockSettings.headerVisibility)
	-- Older profiles did not have a separate title-bar presentation choice.
	-- Their existing hover-only behavior remains the migration default.
	if dockSettings.headerVisibility ~= mode then
		dockSettings.headerVisibility = mode
	end
	return mode
end

local function createTightButton(parent, label, height, emphasis)
	if Theme.CreateTightButton then
		return Theme:CreateTightButton(parent, label, height, emphasis)
	end
	local width = math.max(height or 18, (#tostring(label or "") * 7) + 4)
	return Theme:CreateButton(parent, label, width, height or 18, emphasis)
end

-- The composer is a single continuation of the chat surface, not a toolbar
-- made from three permanently outlined buttons.  Tight buttons retain their
-- normal hover/pressed behavior, but their resting style intentionally blends
-- into the shared lower surface.  SetTheme updates Theme.frames too, so a
-- ColorWays refresh preserves this integration instead of restoring boxes.
local function makeComposerControlIntegrated(button, textColor)
	if not button then
		return
	end
	if button.SetTheme then
		button:SetTheme("inset", "inset", textColor or "textMuted")
	elseif Theme.ApplyFrame then
		Theme:ApplyFrame(button, "inset", "inset")
		if button.text and button.text.SetTextColor and Theme.GetColor then
			local r, g, b, a = Theme:GetColor(textColor or "textMuted")
			button.text:SetTextColor(r, g, b, a)
		end
	end
end

local function setButtonLabel(button, label, minimumWidth)
	label = tostring(label or "")
	if button.SetLabel then
		button:SetLabel(label)
	elseif button.text then
		button.text:SetText(label)
	end
	if button.SetWidth then
		local textWidth = button.text and button.text.GetStringWidth and button.text:GetStringWidth()
		button:SetWidth(math.max(minimumWidth or 18, math.ceil(textWidth or (#label * 6)) + 4))
	end
end

-- The active-view NEW control is intentionally separate from rail badges:
-- it answers one question only--"how many lines arrived below where I am
-- reading?"  Settings migrates this subtree, but keep a defensive fallback so
-- a partial/no-client harness and a hand-edited profile remain harmless.
local function getNewMessageIndicatorOptions(settings)
	local dock = settings and settings.dock
	local indicator = dock and dock.newMessages
	local enabled = not indicator or indicator.enabled ~= false
	local showCount = not indicator or indicator.showCount ~= false
	local maxCount = indicator and tonumber(indicator.maxCount) or 99
	if maxCount == nil then
		maxCount = 99
	end
	maxCount = math.floor(maxCount + 0.5)
	if maxCount < 9 then
		maxCount = 9
	elseif maxCount > 999 then
		maxCount = 999
	end
	return enabled, showCount, maxCount
end

local newMessageIndicatorPoints = {
	TOPLEFT = true,
	TOP = true,
	TOPRIGHT = true,
	LEFT = true,
	BOTTOMLEFT = true,
	BOTTOM = true,
	BOTTOMRIGHT = true,
	CENTER = true,
	RIGHT = true,
}

local function clampNumber(value, minimum, maximum, fallback)
	value = tonumber(value)
	if value == nil then
		value = fallback
	end
	if value < minimum then
		return minimum
	elseif value > maximum then
		return maximum
	end
	return value
end

-- This is deliberately a separate reader from the active-view NEW marker's
-- appearance. The count lives on inactive rail tabs and inherits their
-- FontObject at size zero, so changing it cannot restyle tab keys.
local function getRailUnreadCountAppearance(settings)
	local source = settings and settings.dock and settings.dock.unreadCountAppearance
	if type(source) ~= "table" then
		source = {}
	end
	local size = math.floor(clampNumber(source.fontSize, 0, RAIL_UNREAD_COUNT_FONT_SIZE_MAX, 0) + 0.5)
	if size > 0 and size < RAIL_UNREAD_COUNT_FONT_SIZE_MIN then
		size = RAIL_UNREAD_COUNT_FONT_SIZE_MIN
	end
	return {
		alpha = clampNumber(source.alpha, 0, 1, 1),
		fontSize = size,
	}
end

-- Settings owns migration and canonical SavedVariables values.  SmartDock
-- still reads defensively so an older profile, a partial reload, or a tiny
-- no-client test never turns a presentation preference into a chat failure.
local function getNewMessageIndicatorAppearance(settings)
	local dock = settings and settings.dock
	local indicator = dock and dock.newMessages
	local source = indicator and indicator.appearance
	if type(source) ~= "table" then
		source = {}
	end
	local sourcePosition = source.position
	if type(sourcePosition) ~= "table" then
		sourcePosition = {}
	end

	local function colorOption(key, defaultTheme, defaultR, defaultG, defaultB, defaultA)
		local color = source[key]
		if type(color) ~= "table" then
			color = {}
		end
		local mode = color.mode == "custom" and "custom" or "theme"
		return {
			mode = mode,
			theme = type(color.theme) == "string" and color.theme or defaultTheme,
			r = clampNumber(color.r, 0, 1, defaultR),
			g = clampNumber(color.g, 0, 1, defaultG),
			b = clampNumber(color.b, 0, 1, defaultB),
			a = clampNumber(color.a, 0, 1, defaultA),
		}
	end

	local point = sourcePosition.point
	if not newMessageIndicatorPoints[point] then
		point = "TOPLEFT"
	end
	return {
		position = {
			anchor = sourcePosition.anchor == "dock" and "dock" or "header",
			point = point,
			x = tonumber(sourcePosition.x) or 0,
			y = tonumber(sourcePosition.y) or 0,
		},
		alpha = clampNumber(source.alpha, 0, 1, 1),
		scale = clampNumber(source.scale, 0.5, 2, 1),
		font = type(source.font) == "string" and source.font or "default",
		fontSize = math.floor(clampNumber(source.fontSize, 0, 32, 0) + 0.5),
		outline = source.outline == "THICKOUTLINE" and "THICKOUTLINE"
			or (source.outline == "OUTLINE" and "OUTLINE" or "NONE"),
		color = colorOption("color", "goldBright", 1, 0.8, 0.39, 1),
		background = colorOption("background", "accentSoft", 0.11, 0.24, 0.42, 0.99),
		border = colorOption("border", "gold", 0.88, 0.61, 0.24, 1),
	}
end

local function getFontObjectAttributes(fontObject)
	if not fontObject or type(fontObject.GetFont) ~= "function" then
		return nil, nil, nil
	end
	local ok, path, size, flags = pcall(fontObject.GetFont, fontObject)
	if not ok then
		return nil, nil, nil
	end
	return path, tonumber(size), flags
end

local function stripFontOutline(flags)
	if type(flags) ~= "string" then
		return ""
	end
	flags = string.gsub(flags, "THICKOUTLINE", "")
	flags = string.gsub(flags, "OUTLINE", "")
	flags = string.gsub(flags, ",,", ",")
	flags = string.gsub(flags, "^,+", "")
	flags = string.gsub(flags, ",+$", "")
	return flags
end

local function withFontOutline(flags, outline)
	flags = stripFontOutline(flags)
	if outline == "OUTLINE" or outline == "THICKOUTLINE" then
		if flags ~= "" then
			flags = flags .. "," .. outline
		else
			flags = outline
		end
	end
	return flags ~= "" and flags or nil
end

local newMessageIndicatorAnchorFractions = {
	TOPLEFT = { 0, 1 },
	TOP = { 0.5, 1 },
	TOPRIGHT = { 1, 1 },
	LEFT = { 0, 0.5 },
	CENTER = { 0.5, 0.5 },
	RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 0 },
	BOTTOM = { 0.5, 0 },
	BOTTOMRIGHT = { 1, 0 },
}

-- Kept beside the marker layout helpers because this code runs before the
-- dock's later generic frame helper is declared. Using a local here avoids a
-- silent global lookup on the preview-only path in Lua 5.1.
local function isNewMessageIndicatorFrameShown(frame)
	return frame and frame.IsShown and frame:IsShown()
end

local function getNewMessageIndicatorColor(color)
	if color and color.mode == "theme" and Theme and Theme.GetColor then
		local r, g, b, a = Theme:GetColor(color.theme)
		return r, g, b, a
	end
	return color and color.r or 1, color and color.g or 1, color and color.b or 1, color and color.a or 1
end

local function getNewMessageIndicatorFontObject(fontId)
	if fontId == "chat" then
		return ChatFontNormal
	elseif fontId == "system" then
		return GameFontNormal
	elseif fontId == "number" then
		return NumberFontNormal
	end
	return nil
end

local function getNewMessageIndicatorSharedMediaFont(fontId)
	if type(fontId) ~= "string" or string.sub(fontId, 1, 4) ~= "lsm:" or not LibStub then
		return nil
	end
	local name = string.sub(fontId, 5)
	if name == "" then
		return nil
	end
	local media = LibStub("LibSharedMedia-3.0", true)
	if not media or type(media.Fetch) ~= "function" then
		return nil
	end
	local ok, path = pcall(media.Fetch, media, "font", name, true)
	if ok and type(path) == "string" and path ~= "" then
		return path
	end
	return nil
end

-- Smart Chat owns the text in its dock; it must not depend on the copied
-- Chatter Chat Font module, which only touches Blizzard's native frames while
-- Smart Chat is inactive.  Settings resolves a view's inherited/default
-- appearance, while this small runtime layer applies the resolved font to
-- both the visible ScrollingMessageFrame and its invisible line-measurement
-- twin.  Keeping those two frames in lockstep is what makes wrapping,
-- Shift-hover actions, and fixed-pitch source alignment agree.
local function normalizeSmartChatTextAppearance(appearance)
	appearance = type(appearance) == "table" and appearance or {}
	-- Store/use the real LibSharedMedia key (Questie and Chatter's convention),
	-- never a second Chatty-specific font namespace.  `lsm:` is accepted only
	-- as a migration courtesy for the short-lived implementation draft.
	local font = appearance.font
	if type(font) ~= "string" or font == "" or font == "default" or font == "inherit" then
		font = nil
	elseif string.sub(font, 1, 4) == "lsm:" then
		font = string.sub(font, 5)
	end
	local size = tonumber(appearance.size)
	if size == nil then
		size = tonumber(appearance.fontSize)
	end
	size = math.floor((size or 0) + 0.5)
	if size ~= 0 then
		size = math.max(6, math.min(30, size))
	end
	local outline = appearance.outline
	if outline ~= "NONE" and outline ~= "OUTLINE" and outline ~= "THICKOUTLINE" then
		outline = "INHERIT"
	end
	local spacing = tonumber(appearance.spacing)
	spacing = math.floor((spacing or 1) + 0.5)
	-- Settings enforces 0-8. Mirror that guard here for mixed-version reloads
	-- and manually edited SavedVariables before they reach the native frame.
	spacing = math.max(0, math.min(8, spacing))
	local entryGapRows = tonumber(appearance.entryGapRows)
	entryGapRows = math.floor((entryGapRows or ENTRY_GAP_ROWS_MIN) + 0.5)
	entryGapRows = math.max(ENTRY_GAP_ROWS_MIN, math.min(ENTRY_GAP_ROWS_MAX, entryGapRows))
	return {
		font = font,
		size = size,
		outline = outline,
		spacing = spacing,
		entryGapRows = entryGapRows,
	}
end

local function getSmartChatSharedMediaFont(fontKey)
	if type(fontKey) ~= "string" or fontKey == "" or not LibStub then
		return nil
	end
	local media = LibStub("LibSharedMedia-3.0", true)
	if not media or type(media.Fetch) ~= "function" then
		return nil
	end
	-- Use Questie's no-default form. A default Friz result for a missing key
	-- would otherwise masquerade as the requested fixed-width face.
	local ok, path = pcall(media.Fetch, media, "font", fontKey, true)
	if ok and type(path) == "string" and path ~= "" then
		return path
	end
	return nil
end

function Dock:GetSmartChatTextAppearance(viewId)
	if type(addon.GetSmartChatTextAppearance) == "function" then
		local ok, appearance = pcall(addon.GetSmartChatTextAppearance, addon, viewId or self.activeView)
		if ok and type(appearance) == "table" then
			return normalizeSmartChatTextAppearance(appearance)
		end
	end
	return normalizeSmartChatTextAppearance(nil)
end

function Dock:ApplySmartChatTextAppearance(viewId)
	local display = self.display
	local measure = self.messageMeasure
	if not display or not measure then
		return false
	end

	local appearance = self:GetSmartChatTextAppearance(viewId)
	local defaultPath, defaultSize, defaultFlags = getFontObjectAttributes(ChatFontNormal)
	local fontPath = defaultPath
	if appearance.font then
		if type(addon.ResolveSmartChatTextFont) == "function" then
			local ok, resolved = pcall(addon.ResolveSmartChatTextFont, addon, appearance.font)
			if ok and type(resolved) == "string" and resolved ~= "" then
				fontPath = resolved
			else
				fontPath = defaultPath
			end
		else
			fontPath = getSmartChatSharedMediaFont(appearance.font) or defaultPath
		end
	end
	local fontSize = appearance.size > 0 and appearance.size or defaultSize or 12
	local fontFlags = appearance.outline == "INHERIT"
		and defaultFlags
		or withFontOutline(defaultFlags, appearance.outline)

	local applied = false
	if not appearance.font and appearance.size == 0 and appearance.outline == "INHERIT" then
		local displayOk = display.SetFontObject and pcall(display.SetFontObject, display, ChatFontNormal)
		local measureOk = measure.SetFontObject and pcall(measure.SetFontObject, measure, ChatFontNormal)
		applied = displayOk and measureOk
	elseif fontPath and display.SetFont and measure.SetFont then
		-- WoW can reject a font path by returning false without throwing. Treat
		-- that as a real failure rather than claiming a mono face was applied
		-- while the display silently remains on its previous proportional font.
		local displayCallOk, displayAccepted = pcall(display.SetFont, display, fontPath, fontSize, fontFlags)
		local measureCallOk, measureAccepted = pcall(measure.SetFont, measure, fontPath, fontSize, fontFlags)
		applied = displayCallOk and displayAccepted ~= false
			and measureCallOk and measureAccepted ~= false
	end
	-- ScrollingMessageFrame owns vertical line advance; the measurement string
	-- has no line-spacing API. This is intentionally independent of source or
	-- sender columns, which only change the horizontal formatted text.
	local spacingApplied = false
	if display.SetSpacing then
		local spacingCallOk, spacingAccepted = pcall(display.SetSpacing, display, appearance.spacing)
		spacingApplied = spacingCallOk and spacingAccepted ~= false
		if spacingApplied then
			-- Keep a separate runtime value: the full appearance cache represents
			-- a successful font application and must not claim a rejected face was
			-- installed merely because the independent line gap was accepted.
			self.smartChatTextSpacing = appearance.spacing
		end
	end

	if applied then
		self.smartChatTextAppearance = appearance
		self.displayMeasurementWidth = nil
		self.displayColumnCapacityWidth = nil
		self.displayColumnCapacity = nil
		self.displayColumnCellWidth = nil
		-- The visible typing text belongs to the same Smart Chat surface.  The
		-- shared editor remains Blizzard's input engine, but it must not silently
		-- keep a different face/size from the messages the player is composing.
		local editBox = self.editBox
		if editBox then
			if not appearance.font and appearance.size == 0 and appearance.outline == "INHERIT" then
				if editBox.SetFontObject then
					pcall(editBox.SetFontObject, editBox, ChatFontNormal)
				end
			elseif fontPath and editBox.SetFont then
				pcall(editBox.SetFont, editBox, fontPath, fontSize, fontFlags)
			end
		end
	end
	return applied, spacingApplied
end

-- Blizzard's boolean indent remains useful for natural/proportional views, but
-- it has no configurable indent amount and therefore cannot reach Chatty's
-- message column. Aligned fixed-width views disable it and receive explicit,
-- markup-safe hanging breaks from Presentation instead. The hidden FontString
-- must always mirror the visible ScrollingMessageFrame so Shift-hover lookup
-- counts the same visual lines.
function Dock:ApplyHangingMessageWrap(display, measure, nativeIndentEnabled)
	display = display or self.display
	measure = measure or self.messageMeasure
	if not display then
		return false
	end

	if nativeIndentEnabled == nil then
		nativeIndentEnabled = true
	end
	local displayApplied = false
	if type(display.SetIndentedWordWrap) == "function" then
		local ok = pcall(display.SetIndentedWordWrap, display, nativeIndentEnabled == true)
		displayApplied = ok
	end
	-- URLs, addon identifiers, and malformed spam often have no whitespace.
	-- They should still remain inside the dock rather than escaping its edge.
	if type(display.SetNonSpaceWrap) == "function" then
		pcall(display.SetNonSpaceWrap, display, true)
	end
	if measure then
		if type(measure.SetIndentedWordWrap) == "function" then
			pcall(measure.SetIndentedWordWrap, measure, nativeIndentEnabled == true)
		end
		if type(measure.SetNonSpaceWrap) == "function" then
			pcall(measure.SetNonSpaceWrap, measure, true)
		end
	end
	return displayApplied
end

function Dock:IsExactHangingWrapEnabled(viewId)
	-- Exact wrapping shares the aligned-column contract: those controls select a
	-- fixed-width SharedMedia face, making one visible leader character exactly
	-- one continuation-space cell.
	if (not viewId or viewId == self.activeView) and self.activeColumnLayoutResolved then
		-- Responsive EXTREME rows have no metadata leader at all, while natural
		-- rows need Blizzard's ordinary indent behavior.  Only an effective
		-- runtime fixed lane should select the explicit markup-safe wrapper.
		return self.activeSourceColumnWidth ~= nil or self.activeSenderColumnWidth ~= nil
	end
	return self:IsSourceColumnAlignmentEnabled(viewId) or self:IsSenderColumnAlignmentEnabled(viewId)
end

function Dock:RefreshHangingMessageWrapMode()
	return self:ApplyHangingMessageWrap(self.display, self.messageMeasure,
		not self:IsExactHangingWrapEnabled(self.activeView))
end

function Dock:RefreshSmartChatTextAppearance()
	local fontApplied, spacingApplied = self:ApplySmartChatTextAppearance(self.activeView)
	if not fontApplied and not spacingApplied then
		return false, false
	end
	-- A new face/size can change both line wrapping and the exact column width;
	-- native line spacing also changes viewport geometry, message bands, and
	-- Shift-hover rows. Rebuild either accepted presentation change locally.
	-- Reformat only Chatty's local active buffer; no chat event is sent/replayed.
	if self.active and self.activeView and addon.MessageEngine then
		self:RebuildActiveView()
	end
	-- Preserve the first result as the truthful font status for older callers;
	-- the second result reports the independent native spacing application.
	return fontApplied, spacingApplied
end

function Dock:RestoreDisplayScroll(wasAtBottom, previousScroll)
	local display = self.display
	if not display then return false end
	if wasAtBottom then
		if display.ScrollToBottom then display:ScrollToBottom() end
		return true
	end
	previousScroll = math.max(0, math.floor(tonumber(previousScroll) or 0))
	if previousScroll > 0 and display.ScrollUp then
		for _ = 1, previousScroll do display:ScrollUp() end
	end
	return true
end

-- Re-evaluate signed-gap compaction and both column widths from the logical
-- messages whose measured line spans intersect the viewport. Rebuilding is
-- local presentation work only; preserve the reader's scroll distance and any
-- pending-new-message marker while the visible set settles after rewrapping.
function Dock:RefreshVisibleAlignment()
	if self.visibleAlignmentRefreshInProgress or not self:IsAlignmentVisibleOnly()
		or not (self:IsSourceColumnAlignmentEnabled() or self:IsSenderColumnAlignmentEnabled())
		or not self.active or not self.activeView or not addon.MessageEngine then
		self:RefreshMessageBands()
		return false
	end
	local display = self.display
	if not display then return false end
	local wasAtBottom = not display.AtBottom or display:AtBottom()
	local previousScroll = display.GetCurrentScroll
		and math.max(0, math.floor(tonumber(display:GetCurrentScroll()) or 0)) or 0
	local previousPending = math.max(0, math.floor(tonumber(self.pendingVisible) or 0))
	local rebuilt = false
	self.visibleAlignmentRefreshInProgress = true
	-- Width changes can alter wrapping at a viewport boundary. A short bounded
	-- convergence pass handles that ordinary case without an OnUpdate loop.
	for _ = 1, 5 do
		local scope = self:GetVisibleAlignmentRecords()
		if #scope == 0 then break end
		local signature = self:GetAlignmentScopeSignature(scope)
		if signature == self.activeAlignmentScopeSignature then break end
		self:RebuildActiveView(scope, true)
		self:RestoreDisplayScroll(wasAtBottom, previousScroll)
		if not wasAtBottom then
			self.pendingVisible = previousPending
			self:RefreshNewMessageIndicator()
		end
		rebuilt = true
	end
	self.visibleAlignmentRefreshInProgress = nil
	self:RefreshMessageBands()
	self:UpdateSourceColumnAlignmentControl()
	return rebuilt
end

function Dock:HandleDisplayViewportChanged()
	-- Any scroll/viewport mutation invalidates the cached row anchors. The
	-- existing Shift driver resolves the row again immediately when appropriate.
	self:HideMessageActionHighlight()
	local rebuilt = false
	if self:IsAlignmentVisibleOnly() then
		rebuilt = self:RefreshVisibleAlignment()
	else
		self:RefreshMessageBands()
	end
	self:RefreshMessageScrollbar()
	return rebuilt
end

function Dock:SetMessageScrollbarOffset(value)
	local display = self.display
	local scrollBar = self.messageScrollbar
	if not display or not scrollBar or scrollBar._messageScrollUpdating then return false end
	local maximum = math.max(0, math.floor(tonumber(scrollBar._messageScrollMaximum) or 0))
	local sliderValue = math.max(0, math.min(maximum, math.floor((tonumber(value) or 0) + 0.5)))
	-- A vertical WoW Slider places its minimum at the top and maximum at the
	-- bottom. ScrollingMessageFrame is inverse: offset 0 is the newest/bottom.
	-- Translate at this boundary so dragging down always moves toward newest.
	local scrollOffset = maximum - sliderValue
	local current = display.GetCurrentScroll
		and math.max(0, math.floor((tonumber(display:GetCurrentScroll()) or 0) + 0.5)) or 0
	if scrollOffset ~= current then
		if display.SetScrollOffset then
			display:SetScrollOffset(scrollOffset)
		else
			local step = scrollOffset > current and 1 or -1
			while current ~= scrollOffset do
				if step > 0 and display.ScrollUp then display:ScrollUp()
				elseif step < 0 and display.ScrollDown then display:ScrollDown()
				else break end
				current = current + step
			end
		end
	end
	if scrollOffset == 0 or (display.AtBottom and display:AtBottom()) then
		self:ClearPendingMessages()
	end
	self:HandleDisplayViewportChanged()
	self:ScheduleMessageBlockActionRefresh()
	return true
end

function Dock:ScrollMessageDisplayToBottom()
	if not self.display then return false end
	if self.display.ScrollToBottom then self.display:ScrollToBottom() end
	self:ClearPendingMessages()
	self:HandleDisplayViewportChanged()
	self:ScheduleMessageBlockActionRefresh()
	return true
end

function Dock:RefreshMessageScrollbar()
	local scrollBar = self.messageScrollbar
	local display = self.display
	if not scrollBar or not display then return false end
	if self.transientMessageScrollbarSuppressed then
		scrollBar:Hide()
		if Theme.SetScrollBarThumbVisible then
			Theme:SetScrollBarThumbVisible(scrollBar, false)
		end
		if self.scrollToBottomButton then self.scrollToBottomButton:Hide() end
		return false
	end
	local settings = addon.GetSmartSettings and addon:GetSmartSettings() or nil
	local dockSettings = settings and settings.dock or {}
	local enabled = dockSettings.showScrollButtons ~= false
	if not enabled then
		scrollBar:Hide()
		if self.scrollToBottomButton then self.scrollToBottomButton:Hide() end
		return false
	end

	scrollBar:Show()
	local _, geometry = self:GetVisibleDisplayRecordEntries()
	local totalLines = geometry and math.max(0, tonumber(geometry.totalLines) or 0) or 0
	local capacity = geometry and math.max(1, tonumber(geometry.capacity) or 1) or 1
	local maximum = math.max(0, math.floor(totalLines - capacity))
	local scrollOffset = display.GetCurrentScroll
		and math.max(0, math.floor((tonumber(display:GetCurrentScroll()) or 0) + 0.5)) or 0
	scrollOffset = math.min(maximum, scrollOffset)
	local sliderValue = maximum - scrollOffset

	scrollBar._messageScrollUpdating = true
	scrollBar._messageScrollMaximum = maximum
	if scrollBar.SetMinMaxValues then scrollBar:SetMinMaxValues(0, maximum) end
	if scrollBar.SetValue then scrollBar:SetValue(sliderValue) end
	scrollBar._messageScrollUpdating = nil

	local overflow = maximum > 0
	if scrollBar.EnableMouse then scrollBar:EnableMouse(overflow) end
	if Theme.SetScrollBarThumbVisible then
		Theme:SetScrollBarThumbVisible(scrollBar, overflow)
	end
	if overflow and Theme.SetScrollBarThumbSize then
		local scrollBarHeight = scrollBar.GetHeight and tonumber(scrollBar:GetHeight()) or 0
		local height = math.max(MESSAGE_SCROLLBAR_MIN_THUMB_HEIGHT,
			math.floor(scrollBarHeight * math.min(1, capacity / totalLines) + 0.5))
		Theme:SetScrollBarThumbSize(scrollBar, MESSAGE_SCROLLBAR_THUMB_WIDTH, height)
	end

	local atBottom = scrollOffset == 0 or (display.AtBottom and display:AtBottom())
	if self.scrollToBottomButton then
		if overflow and not atBottom then self.scrollToBottomButton:Show()
		else self.scrollToBottomButton:Hide() end
	end
	return overflow
end

function Dock:RebuildActiveViewPreservingScroll()
	local wasAtBottom = not self.display or not self.display.AtBottom or self.display:AtBottom()
	local previousScroll = self.display and self.display.GetCurrentScroll
		and math.max(0, math.floor(tonumber(self.display:GetCurrentScroll()) or 0)) or 0
	local previousPending = math.max(0, math.floor(tonumber(self.pendingVisible) or 0))
	self:RebuildActiveView(nil, true)
	self:RestoreDisplayScroll(wasAtBottom, previousScroll)
	if not wasAtBottom then
		self.pendingVisible = previousPending
		self:RefreshNewMessageIndicator()
	end
	if self:IsAlignmentVisibleOnly() then
		self:RefreshVisibleAlignment()
	else
		self:RefreshMessageBands()
	end
	self:RefreshMessageScrollbar()
	return true
end

-- Settings setters for signed gaps, name truncation, and visible-only scope can
-- all use this one live refresh contract.
function Dock:RefreshColumnAlignmentPresentation()
	if self.active and self.activeView and addon.MessageEngine then
		self:RebuildActiveViewPreservingScroll()
		return true
	end
	return false
end

-- Settings calls this hook after its persisted boolean changes.  Keeping the
-- hook in SmartDock lets older Settings builds use the raw fallback while the
-- live surface still updates immediately once the public API is added.
function Dock:RefreshResponsiveMetadata()
	if self.active and self.activeView and addon.MessageEngine then
		self:RebuildActiveViewPreservingScroll()
		return true
	end
	return false
end

function Dock:GetWindowTransparency()
	local stored
	if type(addon.GetSmartChatWindowTransparency) == "function" then
		local ok, result = pcall(addon.GetSmartChatWindowTransparency, addon)
		if ok and type(result) == "table" then stored = result end
	end
	if not stored and type(addon.GetSmartSettings) == "function" then
		local ok, settings = pcall(addon.GetSmartSettings, addon)
		local dock = ok and type(settings) == "table" and settings.dock or nil
		stored = type(dock) == "table" and dock.transparency or nil
	end
	stored = type(stored) == "table" and stored or {}
	return {
		backgroundAlpha = clampNumber(stored.backgroundAlpha, 0, 1, 1),
		borderAlpha = clampNumber(stored.borderAlpha, 0, 1, 1),
		overallAlpha = clampNumber(stored.overallAlpha, 0, 1, 1),
	}
end

-- Background and border opacity are applied only to themed chrome frames, so
-- message glyphs remain crisp.  The separate overall multiplier intentionally
-- fades the complete SmartDock tree for players who want that behavior.
function Dock:RefreshTransparency()
	if not self.frame then return false end
	local appearance = self:GetWindowTransparency()
	if type(self.frame.SetAlpha) == "function" then
		self.frame:SetAlpha(appearance.overallAlpha)
	end
	if Theme and type(Theme.SetFrameOpacity) == "function" then
		for _, panel in pairs({
			self.frame,
			self.header,
			self.rail,
			self.content,
			self.composer,
			self.composerEditBoxBorder,
		}) do
			if panel then
				Theme:SetFrameOpacity(panel, appearance.backgroundAlpha, appearance.borderAlpha)
			end
		end
		-- Transient surfaces must stay readable over a deliberately translucent
		-- chat window. They retain the user's WHOLE UI multiplier through the root
		-- frame, but never inherit the background/border transparency intended for
		-- the persistent dock chrome.
		for _, panel in pairs({ self.alertBar, self.playerActions }) do
			if panel then
				Theme:SetFrameOpacity(panel, 1, 1)
			end
		end
	end
	return true, appearance
end

function Dock:RegisterSmartChatTextMediaCallback()
	if self.smartChatTextMediaCallbackRegistered or not LibStub then
		return
	end
	local media = LibStub("LibSharedMedia-3.0", true)
	if not media or type(media.RegisterCallback) ~= "function" then
		return
	end
	local ok = pcall(media.RegisterCallback, media, self, "LibSharedMedia_Registered")
	if ok then
		self.smartChatTextMedia = media
		self.smartChatTextMediaCallbackRegistered = true
	end
end

function Dock:UnregisterSmartChatTextMediaCallback()
	local media = self.smartChatTextMedia
	if self.smartChatTextMediaCallbackRegistered and media and type(media.UnregisterCallback) == "function" then
		pcall(media.UnregisterCallback, media, self, "LibSharedMedia_Registered")
	end
	self.smartChatTextMedia = nil
	self.smartChatTextMediaCallbackRegistered = nil
end

function Dock:LibSharedMedia_Registered(eventOrType, maybeType)
	-- CallbackHandler supplies (eventName, mediaType, key), while lightweight
	-- client-side variants sometimes provide only (mediaType, key). Support both
	-- without assuming a Retail-only callback implementation.
	local mediaType = maybeType or eventOrType
	if mediaType == "font" and self.active then
		self:RefreshSmartChatTextAppearance()
	end
end

function Dock:GetNewMessageIndicatorAppearance(settings)
	return getNewMessageIndicatorAppearance(settings or addon:GetSmartSettings())
end

function Dock:IsNewMessageIndicatorDockAnchored(settings)
	local appearance = self:GetNewMessageIndicatorAppearance(settings)
	return appearance.position.anchor == "dock"
end

function Dock:GetNewMessageIndicatorScaledSize()
	local button = self.newButton
	if not button then
		return 0, 0
	end
	local scale = button.GetScale and tonumber(button:GetScale()) or 1
	if not scale or scale <= 0 then
		scale = 1
	end
	local width = button.GetWidth and tonumber(button:GetWidth()) or 0
	local height = button.GetHeight and tonumber(button:GetHeight()) or 0
	return math.max(0, width * scale), math.max(0, height * scale)
end

-- All free positions are expressed against the same point on the dock and
-- marker. That makes TOP, LEFT, CENTER, and all four corners equally stable
-- through a resize, while this clamp guarantees the painted (scaled) marker
-- cannot end up outside the dock's usable surface.
function Dock:ClampNewMessageIndicatorDockPosition(point, x, y)
	point = newMessageIndicatorPoints[point] and point or "TOPLEFT"
	local frame = self.frame
	if not frame or not frame.GetWidth or not frame.GetHeight then
		return point, math.floor(tonumber(x) or 0), math.floor(tonumber(y) or 0)
	end
	local width = math.max(0, tonumber(frame:GetWidth()) or 0)
	local height = math.max(0, tonumber(frame:GetHeight()) or 0)
	local markerWidth, markerHeight = self:GetNewMessageIndicatorScaledSize()
	local fraction = newMessageIndicatorAnchorFractions[point] or newMessageIndicatorAnchorFractions.TOPLEFT
	local inset = NEW_MESSAGE_INDICATOR_EDGE_INSET
	local minX = inset + (fraction[1] * markerWidth) - (fraction[1] * width)
	local maxX = (width - markerWidth - inset) + (fraction[1] * markerWidth) - (fraction[1] * width)
	local minY = inset + (fraction[2] * markerHeight) - (fraction[2] * height)
	local maxY = (height - markerHeight - inset) + (fraction[2] * markerHeight) - (fraction[2] * height)
	-- Extremely narrow dock dimensions are transient during a resize. Collapse
	-- their range to the middle instead of allowing an inverted clamp range.
	if minX > maxX then
		minX, maxX = (minX + maxX) / 2, (minX + maxX) / 2
	end
	if minY > maxY then
		minY, maxY = (minY + maxY) / 2, (minY + maxY) / 2
	end
	x = clampNumber(x, minX, maxX, 0)
	y = clampNumber(y, minY, maxY, 0)
	local function roundedWithin(value, minimum, maximum)
		local minimumInteger = math.ceil(minimum)
		local maximumInteger = math.floor(maximum)
		if minimumInteger > maximumInteger then
			return math.floor(((minimum + maximum) / 2) + 0.5)
		end
		value = math.floor(value + 0.5)
		return math.max(minimumInteger, math.min(maximumInteger, value))
	end
	return point, roundedWithin(x, minX, maxX), roundedWithin(y, minY, maxY)
end

function Dock:ApplyNewMessageIndicatorPlacement(settings, appearance)
	local button = self.newButton
	if not button or not self.frame or not self.header then
		return false
	end
	appearance = appearance or self:GetNewMessageIndicatorAppearance(settings)
	local position = appearance.position
	local dockAnchored = position.anchor == "dock"
	-- A header-anchored marker normally inherits the header's visibility exactly
	-- as it always did. Preview temporarily lifts only that sample to the dock
	-- so the player can style/place it even when hover-only chrome is hidden.
	local previewOverlay = self:IsNewMessageIndicatorPreviewActive() and not dockAnchored
		and not isNewMessageIndicatorFrameShown(self.header)
	local desiredParent = (dockAnchored or previewOverlay) and self.frame or self.header
	if button.SetParent and desiredParent and (not button.GetParent or button:GetParent() ~= desiredParent) then
		button:SetParent(desiredParent)
	end
	if (dockAnchored or previewOverlay) and button.SetFrameLevel and self.frame.GetFrameLevel then
		-- Above the content and header controls, below the resize affordances.
		button:SetFrameLevel(self.frame:GetFrameLevel() + 12)
	end
	if button.ClearAllPoints then
		button:ClearAllPoints()
	end
	if dockAnchored then
		local point, x, y = self:ClampNewMessageIndicatorDockPosition(position.point, position.x, position.y)
		if button.SetPoint then
			button:SetPoint(point, self.frame, point, x, y)
		end
		self.newMessageIndicatorAppliedPosition = { anchor = "dock", point = point, x = x, y = y }
	else
		-- This is deliberately the original inline title-bar slot. A reset or
		-- an uncustomized profile therefore keeps the exact compact baseline.
		if button.SetPoint and self.collapseButton then
			button:SetPoint("RIGHT", self.collapseButton, "LEFT", -2, 0)
		end
		self.newMessageIndicatorAppliedPosition = { anchor = "header", point = "TOPRIGHT", x = 0, y = 0 }
	end
	return dockAnchored
end

function Dock:ApplyNewMessageIndicatorFont(appearance)
	local button = self.newButton
	local text = button and button.text
	if not text or not text.SetFont then
		return false
	end
	appearance = appearance or self:GetNewMessageIndicatorAppearance()
	local fontId = appearance.font
	local fontObject = getNewMessageIndicatorFontObject(fontId)
	local path, baseSize, baseFlags
	if fontId == "default" then
		path = self.newMessageIndicatorDefaultFontPath
		baseSize = self.newMessageIndicatorDefaultFontSize
		baseFlags = self.newMessageIndicatorDefaultFontFlags
	elseif fontObject then
		path, baseSize, baseFlags = getFontObjectAttributes(fontObject)
	elseif type(fontId) == "string" and string.sub(fontId, 1, 4) == "lsm:" then
		path = getNewMessageIndicatorSharedMediaFont(fontId)
		baseSize = self.newMessageIndicatorDefaultFontSize
		baseFlags = self.newMessageIndicatorDefaultFontFlags
	elseif type(fontId) == "string" and fontId ~= "" then
		-- A raw font path remains a safe advanced fallback for hand-edited
		-- profiles, although normal UI choices use the stable IDs above.
		path = fontId
		baseSize = self.newMessageIndicatorDefaultFontSize
		baseFlags = self.newMessageIndicatorDefaultFontFlags
	end

	-- `default` + zero means inherit the original compact font object exactly.
	-- That preserves existing layouts and avoids turning a passive update into
	-- an unexpected text-size migration.
	if fontId == "default" and appearance.fontSize == 0 and appearance.outline == "NONE"
		and self.newMessageIndicatorDefaultFontObject and text.SetFontObject then
		text:SetFontObject(self.newMessageIndicatorDefaultFontObject)
		return true
	end
	if not path then
		path = self.newMessageIndicatorDefaultFontPath
		baseSize = baseSize or self.newMessageIndicatorDefaultFontSize
		baseFlags = baseFlags or self.newMessageIndicatorDefaultFontFlags
	end
	if not path then
		return false
	end
	local size = appearance.fontSize > 0 and appearance.fontSize or baseSize or 10
	return pcall(text.SetFont, text, path, size, withFontOutline(baseFlags, appearance.outline))
end

function Dock:ApplyNewMessageIndicatorAppearance(settings)
	local button = self.newButton
	if not button then
		return false
	end
	local appearance = self:GetNewMessageIndicatorAppearance(settings)
	local text = button.text
	local textR, textG, textB, textA = getNewMessageIndicatorColor(appearance.color)
	local backgroundR, backgroundG, backgroundB, backgroundA = getNewMessageIndicatorColor(appearance.background)
	local borderR, borderG, borderB, borderA = getNewMessageIndicatorColor(appearance.border)

	-- Keep Theme's registration live for palette-token choices. Custom RGBA
	-- choices deliberately opt out, then this method reapplies them after any
	-- Theme refresh so a colorway change cannot overwrite a user override.
	if Theme.frames then
		if appearance.background.mode == "theme" and appearance.border.mode == "theme" then
			Theme.frames[button] = { fill = appearance.background.theme, border = appearance.border.theme }
		else
			Theme.frames[button] = nil
		end
	end
	if Theme.texts and text then
		Theme.texts[text] = appearance.color.mode == "theme" and appearance.color.theme or nil
	end
	if button.SetBackdropColor then
		button:SetBackdropColor(backgroundR, backgroundG, backgroundB, backgroundA)
	end
	if button.SetBackdropBorderColor then
		button:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
	end
	if text and text.SetTextColor then
		text:SetTextColor(textR, textG, textB, textA)
	end
	if button.SetAlpha then
		button:SetAlpha(appearance.alpha)
	end
	if button.SetScale then
		button:SetScale(appearance.scale)
	end
	self:ApplyNewMessageIndicatorFont(appearance)
	-- The label may have been measured before a new font/size was applied.
	-- Re-measure here so an outline, LSM face, or larger chosen size never
	-- clips a count such as NEW 99+ inside the otherwise compact marker.
	if text and text.GetStringWidth and button.SetWidth then
		local textWidth = tonumber(text:GetStringWidth()) or 0
		button:SetWidth(math.max(18, math.ceil(textWidth) + 4))
	end
	self:ApplyNewMessageIndicatorPlacement(settings, appearance)
	return true
end

function Dock:SetNewMessageIndicatorPreviewActive(active)
	active = active and true or false
	if self.newMessageIndicatorPreviewActive == active then
		return true
	end
	self.newMessageIndicatorPreviewActive = active
	self:RefreshNewMessageIndicator()
	return true
end

function Dock:IsNewMessageIndicatorPreviewActive()
	return self.newMessageIndicatorPreviewActive == true
end

local function getViewDefinitions()
	if addon.GetSmartViews then
		return addon:GetSmartViews()
	end
	return addon.SmartViews
end

local function savePoints(frame)
	local points = {}
	for index = 1, frame:GetNumPoints() do
		points[index] = { frame:GetPoint(index) }
	end
	return points
end

local function restorePoints(frame, points)
	frame:ClearAllPoints()
	for index = 1, #points do
		frame:SetPoint(unpack(points[index]))
	end
end

local function cleanName(name)
	return string.lower(name or "")
end

-- ScrollingMessageFrame intentionally owns its text rendering, so it does not
-- expose a clickable frame for every record.  Keep a tiny parallel index of
-- the records we add to it instead.  That lets the Shift-hover block affordance
-- resolve the line below the cursor without changing normal chat text, links,
-- wheel scrolling, or the composer.
local function getCursorInUiCoordinates()
	if not GetCursorPosition or not UIParent then
		return nil, nil
	end
	local x, y = GetCursorPosition()
	local scale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
	if not scale or scale == 0 then
		scale = 1
	end
	return x / scale, y / scale
end

-- Some frame edge methods are unavailable in the small no-client tests, and
-- a transient hidden rail can report nil geometry during a layout change.
-- Keep drag hit testing defensive so it simply pauses rather than throwing
-- while a profile/layout is being refreshed.
local function getFrameCoordinate(frame, method)
	if not frame or type(frame[method]) ~= "function" then
		return nil
	end
	local ok, value = pcall(frame[method], frame)
	if not ok then
		return nil
	end
	return tonumber(value)
end

local function isShiftDown()
	return IsShiftKeyDown and IsShiftKeyDown() and true or false
end

local playerActionMouseButtons = { "LeftButton", "RightButton", "MiddleButton" }

local function isAnyMouseButtonDown()
	if not IsMouseButtonDown then
		return false
	end
	for index = 1, #playerActionMouseButtons do
		local ok, down = pcall(IsMouseButtonDown, playerActionMouseButtons[index])
		if ok and down then
			return true
		end
	end
	return false
end

local function frameIsShown(frame)
	return frame and frame.IsShown and frame:IsShown()
end

-- Keep every message-surface child inside the same transient viewport. Alerts
-- reserve the top lane; player-name actions reserve the bottom lane. Releasing
-- either lane restores the ordinary four-pixel message inset without rebuilding
-- history or changing the reader's scroll position.
function Dock:RefreshTransientMessageLayout(skipViewportRefresh)
	local content = self.content
	local display = self.display
	if not content or not display then return false end

	local settings = addon.GetSmartSettings and addon:GetSmartSettings() or nil
	local dockSettings = settings and settings.dock or {}
	local showMessageScrollbar = dockSettings.showScrollButtons ~= false
	local topInset = 4
	local bottomInset = 4
	if self.alertActive and frameIsShown(self.alertBar) then
		topInset = topInset + math.max(0, tonumber(self.alertBar:GetHeight()) or ALERT_PANEL_HEIGHT)
			+ TRANSIENT_PANEL_RESERVATION
	end
	if frameIsShown(self.playerActions) then
		bottomInset = bottomInset
			+ math.max(0, tonumber(self.playerActions:GetHeight()) or PLAYER_ACTION_PANEL_WIDE_HEIGHT)
			+ TRANSIENT_PANEL_RESERVATION
	end
	local rightInset = showMessageScrollbar and MESSAGE_SCROLLBAR_DISPLAY_INSET or 4
	local contentHeight = content.GetHeight and tonumber(content:GetHeight()) or 0
	local availableHeight = contentHeight > 0 and math.max(0, contentHeight - topInset - bottomInset) or nil
	local minimumLineHeight = TRANSIENT_MESSAGE_LINE_HEIGHT_FALLBACK
	if display.GetFont then
		local ok, measured = pcall(self.GetDisplayLineHeight, self)
		if ok and tonumber(measured) then
			minimumLineHeight = math.max(1, tonumber(measured))
		end
	end
	local suppressDisplay = availableHeight ~= nil and availableHeight < minimumLineHeight
	local minimumScrollbarHeight = MESSAGE_SCROLL_TO_BOTTOM_HEIGHT + MESSAGE_SCROLL_TO_BOTTOM_GAP
		+ MESSAGE_SCROLLBAR_MIN_THUMB_HEIGHT
	local suppressScrollbar = suppressDisplay
		or (availableHeight ~= nil and availableHeight < minimumScrollbarHeight)
	local wasDisplaySuppressed = self.transientMessageViewportSuppressed == true
	local layoutChanged = self.transientMessageTopInset ~= topInset
		or self.transientMessageBottomInset ~= bottomInset
		or self.transientMessageRightInset ~= rightInset
		or self.transientMessageContentHeight ~= contentHeight
		or wasDisplaySuppressed ~= suppressDisplay
		or self.transientMessageScrollbarSuppressed ~= suppressScrollbar
	local wasAtBottom = not display.AtBottom or display:AtBottom()
	local previousScroll = display.GetCurrentScroll
		and math.max(0, math.floor(tonumber(display:GetCurrentScroll()) or 0)) or 0
	if suppressDisplay and not wasDisplaySuppressed then
		self.transientMessageDisplayWasShown = frameIsShown(display)
		self.transientMessageEmptyWasShown = frameIsShown(self.emptyState)
		self.transientMessageWasAtBottom = wasAtBottom
	elseif not suppressDisplay and wasDisplaySuppressed then
		wasAtBottom = self.transientMessageWasAtBottom ~= false
		-- ScrollingMessageFrame advances a scrolled-up reader's live offset as new
		-- messages arrive. Keep that current post-arrival value; restoring the stale
		-- pre-menu snapshot would jump the reader toward newer text on close.
	end

	self.transientMessageTopInset = topInset
	self.transientMessageBottomInset = bottomInset
	self.transientMessageRightInset = rightInset
	self.transientMessageContentHeight = contentHeight
	self.transientMessageViewportSuppressed = suppressDisplay
	self.transientMessageScrollbarSuppressed = suppressScrollbar

	display:ClearAllPoints()
	display:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -topInset)
	display:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -rightInset, bottomInset)

	if self.emptyState then
		self.emptyState:ClearAllPoints()
		self.emptyState:SetPoint("CENTER", display, "CENTER", 0, 0)
	end
	if self.messageScrollbar then
		self.messageScrollbar:ClearAllPoints()
		self.messageScrollbar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -MESSAGE_SCROLLBAR_RIGHT_INSET,
			-topInset)
		self.messageScrollbar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -MESSAGE_SCROLLBAR_RIGHT_INSET,
			bottomInset + MESSAGE_SCROLL_TO_BOTTOM_HEIGHT + MESSAGE_SCROLL_TO_BOTTOM_GAP)
	end
	if self.scrollToBottomButton then
		self.scrollToBottomButton:ClearAllPoints()
		self.scrollToBottomButton:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT",
			-MESSAGE_SCROLLBAR_RIGHT_INSET, bottomInset)
	end

	if suppressDisplay then
		if display.Hide then display:Hide() end
		if self.emptyState and self.emptyState.Hide then self.emptyState:Hide() end
		self:HideMessageBands()
		self:HideMessageActionHighlight()
	else
		if wasDisplaySuppressed then
			if self.transientMessageDisplayWasShown ~= false and display.Show then display:Show()
			elseif display.Hide then display:Hide() end
			if self.emptyState then
				if self.built and self.activeView and type(self.displayRecords) == "table" then
					-- Messages can arrive while a tiny transient menu temporarily hides
					-- the lane. Recompute from the live cache instead of resurrecting a
					-- stale pre-menu "No messages yet" label over new text.
					self:UpdateEmptyState(#self.displayRecords)
				elseif self.transientMessageEmptyWasShown and self.emptyState.Show then
					self.emptyState:Show()
				elseif self.emptyState.Hide then
					self.emptyState:Hide()
				end
			end
			self.transientMessageDisplayWasShown = nil
			self.transientMessageEmptyWasShown = nil
			self.transientMessageWasAtBottom = nil
		end
	end
	if suppressScrollbar then
		if self.messageScrollbar then
			self.messageScrollbar:Hide()
			if Theme.SetScrollBarThumbVisible then
				Theme:SetScrollBarThumbVisible(self.messageScrollbar, false)
			end
		end
		if self.scrollToBottomButton then self.scrollToBottomButton:Hide() end
	end
	if suppressDisplay then
		return true, topInset, bottomInset, true
	end

	if layoutChanged then
		if wasAtBottom then
			if display.ScrollToBottom then display:ScrollToBottom() end
		elseif display.SetScrollOffset then
			display:SetScrollOffset(previousScroll)
		elseif display.ScrollToBottom and display.ScrollUp then
			display:ScrollToBottom()
			for _ = 1, previousScroll do display:ScrollUp() end
		end
		if skipViewportRefresh then
			-- Resize drags can fire every frame. Keep transient anchors and safety
			-- suppression current, then let EndResize perform the one real wrap/
			-- visible-scope rebuild for the committed geometry.
			self:RefreshMessageScrollbar()
		else
			self:HandleDisplayViewportChanged()
		end
	else
		self:RefreshMessageScrollbar()
	end
	return true, topInset, bottomInset
end

-- GameTooltip is shared with the rest of the UI.  Only dismiss a tooltip when
-- this dock still owns it; a display leave must never eat a tooltip belonging
-- to a link, a rail, or another add-on.
local function hideTooltipForOwner(owner)
	if not GameTooltip or not GameTooltip.Hide then
		return
	end
	if not GameTooltip.GetOwner or GameTooltip:GetOwner() == owner then
		GameTooltip:Hide()
	end
end

local validPoints = {
	TOPLEFT = true,
	TOP = true,
	TOPRIGHT = true,
	LEFT = true,
	CENTER = true,
	RIGHT = true,
	BOTTOMLEFT = true,
	BOTTOM = true,
	BOTTOMRIGHT = true,
}

local function getGeometry()
	local geometry = addon:GetSmartSettings().dock
	local point = validPoints[geometry.point] and geometry.point or "BOTTOMLEFT"
	local x = tonumber(geometry.x) or 28
	local y = tonumber(geometry.y) or 34
	local width = math.max(EXPANDED_MIN_WIDTH, math.min(EXPANDED_MAX_WIDTH, tonumber(geometry.width) or 520))
	local height = math.max(EXPANDED_MIN_HEIGHT, math.min(EXPANDED_MAX_HEIGHT, tonumber(geometry.height) or 250))
	return geometry, point, x, y, width, height
end

local function applyGeometry(frame)
	local geometry, point, x, y, width, height = getGeometry()
	geometry.point = point
	geometry.x = x
	geometry.y = y
	geometry.width = width
	geometry.height = height
	frame:ClearAllPoints()
	frame:SetPoint(point, UIParent, point, x, y)
	frame:SetSize(width, height)
end

function Dock:IsLocallyIgnored(record, settings)
	settings = settings or addon:GetSmartSettings()
	return record.sender and settings.safety.localIgnores[cleanName(record.sender)] == true
end

function Dock:IsRecordAllowedInView(viewId, record, settings)
	if addon.IsRecordAllowedInView then
		return addon:IsRecordAllowedInView(viewId, record, settings) ~= false
	end
	return true
end

function Dock:RecordBelongsToView(viewId, record, settings)
	local engine = addon.MessageEngine
	if engine and type(engine.RecordBelongsToView) == "function" then
		return engine:RecordBelongsToView(record, viewId, settings) == true
	end
	local memberships = record and record.views
	local routed = type(memberships) == "table" and memberships[viewId]
		or (record and not memberships and record.view == viewId)
	if routed and self:IsRecordAllowedInView(viewId, record, settings) then
		return true
	end
	if addon.IsRecordIncludedBySource then
		return addon:IsRecordIncludedBySource(viewId, record, settings) == true
	end
	return false
end

function Dock:GetActiveDefinition()
	if not viewById[self.activeView] then
		self:RefreshViewDefinitions()
	end
	return viewById[self.activeView] or viewById.general
end

function Dock:RefreshViewDefinitions()
	for id in pairs(viewById) do
		viewById[id] = nil
	end
	local definitions = getViewDefinitions()
	for index = 1, #definitions do
		viewById[definitions[index].id] = definitions[index]
	end
	return definitions
end

function Dock:IsReadOnlyView(viewId)
	return readOnlyViews[viewId or self.activeView] == true
end

function Dock:GetRailTabMinimumWidth(settings)
	local appearance = getRailUnreadCountAppearance(settings or addon:GetSmartSettings())
	-- A two-character key plus the widest displayed count (99+) and six pixels
	-- of left/right breathing room. At the inherited ten-point font this is the
	-- historical 38px rail tab; larger chosen text expands without overlap.
	local effectiveSize = appearance.fontSize > 0 and appearance.fontSize or 10
	return math.max(RAIL_TAB_MIN_WIDTH, math.ceil((2 * 6) + (3 * effectiveSize * 0.6) + (RAIL_TAB_TEXT_INSET * 2)))
end

function Dock:ApplyRailUnreadCountAppearance(button, settings)
	local text = button and button.unread
	if not text then
		return false
	end
	local appearance = getRailUnreadCountAppearance(settings or addon:GetSmartSettings())
	if appearance.fontSize == 0 then
		if button.unreadDefaultFontObject and text.SetFontObject then
			text:SetFontObject(button.unreadDefaultFontObject)
		end
	elseif text.SetFont then
		local path = button.unreadDefaultFontPath
		local flags = button.unreadDefaultFontFlags
		if path then
			pcall(text.SetFont, text, path, appearance.fontSize, flags)
		end
	end
	local r, g, b, a = 1, 0.8, 0.39, 1
	if Theme and Theme.GetColor then
		r, g, b, a = Theme:GetColor("goldBright")
	end
	if text.SetTextColor then
		text:SetTextColor(r or 1, g or 0.8, b or 0.39, (a or 1) * appearance.alpha)
	end
	return true
end

function Dock:UpdateRailTabMetrics(button, settings)
	if not button then
		return RAIL_TAB_MIN_WIDTH, RAIL_TAB_HEIGHT
	end
	local minimumWidth = self:GetRailTabMinimumWidth(settings)
	local labelWidth = button.text and button.text.GetStringWidth and tonumber(button.text:GetStringWidth()) or nil
	if not labelWidth then
		labelWidth = #(button.definition and button.definition.key or "") * 6
	end
	local unreadWidth = 0
	if button.unread and button.unread.IsShown and button.unread:IsShown() then
		unreadWidth = button.unread.GetStringWidth and tonumber(button.unread:GetStringWidth()) or 18
	end
	local width = math.max(minimumWidth, math.ceil(labelWidth + unreadWidth + (RAIL_TAB_TEXT_INSET * 3)))
	if button.SetSize then
		button:SetSize(width, RAIL_TAB_HEIGHT)
	elseif button.SetWidth then
		button:SetWidth(width)
	end
	return width, RAIL_TAB_HEIGHT
end

function Dock:RefreshUnreadCountAppearance()
	if not self.railButtons then
		return false
	end
	self:RefreshRailState()
	-- An increased badge size can require a wider vertical rail. Re-apply the
	-- dock geometry once, outside RefreshRailState's hot path, so content never
	-- overlaps or clips at minimum dock dimensions.
	if self.frame and self.built and self.ApplyLayout then
		self:ApplyLayout()
	end
	return true
end

function Dock:ScrollRailByAmount(amount)
	local scroll = self.railScroll
	amount = tonumber(amount) or 0
	if not scroll or amount == 0 then
		return false
	end

	local settings = addon.GetSmartSettings and addon:GetSmartSettings() or nil
	local horizontal = settings and settings.dock and settings.dock.railOrientation == "horizontal"
	local range, current, setter
	if horizontal then
		range = scroll.GetHorizontalScrollRange and scroll:GetHorizontalScrollRange() or 0
		current = scroll.GetHorizontalScroll and scroll:GetHorizontalScroll() or 0
		setter = scroll.SetHorizontalScroll
	else
		range = scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange() or 0
		current = scroll.GetVerticalScroll and scroll:GetVerticalScroll() or 0
		setter = scroll.SetVerticalScroll
	end

	range = math.max(0, tonumber(range) or 0)
	current = math.max(0, math.min(range, tonumber(current) or 0))
	local target = math.max(0, math.min(range, current + amount))
	if not setter or target == current then
		return false, current
	end
	setter(scroll, target)
	return true, target
end

function Dock:HandleRailMouseWheel(delta)
	delta = tonumber(delta) or 0
	if delta == 0 then
		return false
	end
	return self:ScrollRailByAmount(delta > 0 and -RAIL_MOUSE_WHEEL_STEP or RAIL_MOUSE_WHEEL_STEP)
end

function Dock:BindRailMouseWheel(surface)
	if not surface or surface._ccbbRailMouseWheelBound then
		return false
	end
	if not surface.HookScript and not surface.SetScript then
		return false
	end

	surface._ccbbRailMouseWheelBound = true
	if surface.EnableMouseWheel then
		surface:EnableMouseWheel(true)
	end
	local handler = function(_, delta)
		Dock:HandleRailMouseWheel(delta)
	end
	if surface.HookScript then
		surface:HookScript("OnMouseWheel", handler)
	else
		surface:SetScript("OnMouseWheel", handler)
	end
	return true
end

function Dock:BuildRailButton(definition)
	local button = CreateFrame("Button", nil, self.railContent or self.rail)
	button:SetSize(RAIL_TAB_MIN_WIDTH, RAIL_TAB_HEIGHT)
	button.viewId = definition.id
	button.definition = definition
	Theme:RegisterFrame(button, "surface", "borderMuted")

	button.text = Theme:CreateText(button, "GameFontNormalSmall", "textMuted")
	button.text:SetPoint("LEFT", button, "LEFT", RAIL_TAB_TEXT_INSET, 0)
	button.text:SetText(definition.key)

	button.unread = Theme:CreateText(button, "GameFontNormalSmall", "goldBright")
	button.unread:SetPoint("RIGHT", button, "RIGHT", -RAIL_TAB_TEXT_INSET, 0)
	button.unreadDefaultFontObject = GameFontNormalSmall
	button.unreadDefaultFontPath, button.unreadDefaultFontSize, button.unreadDefaultFontFlags = getFontObjectAttributes(button.unread)
	button.unread:Hide()

	button:SetScript("OnClick", function(self)
		if Dock:ShouldSuppressRailTabClick(self.viewId) then
			return
		end
		Dock:SelectView(self.viewId)
		-- The click-reveal rail is a transient picker. Once a destination is
		-- chosen, return the reclaimed space to the conversation immediately.
		Dock:SetRailReveal(false)
	end)
	button:SetScript("OnMouseDown", function(self, mouseButton)
		Dock:HandleRailTabMouseDown(self, mouseButton)
	end)
	button:SetScript("OnMouseUp", function(self, mouseButton)
		Dock:HandleRailTabMouseUp(self, mouseButton)
	end)
	button:SetScript("OnEnter", function(self)
		Theme:ApplyFrame(self, "surfaceRaised", "goldBright")
		if Dock:IsRailTabReordering() then
			return
		end
		if GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine((self.definition and self.definition.label) or self.viewId)
			if self.definition and self.definition.description then
				GameTooltip:AddLine(self.definition.description, 0.56, 0.63, 0.71, true)
			end
			GameTooltip:AddLine("Click: select tab  |  SHIFT-drag: reorder + save", 0.56, 0.63, 0.71)
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
		Dock:RefreshRailState()
	end)
	self:BindHeaderHover(button)
	self:BindRailMouseWheel(button)
	return button
end

function Dock:RefreshRailContentBounds(settings)
	if not self.railContent or not self.railButtons then
		return
	end
	settings = settings or addon:GetSmartSettings()
	local horizontal = settings.dock and settings.dock.railOrientation == "horizontal"
	local totalWidth, totalHeight = 4, 4
	local widestTab = self:GetRailTabMinimumWidth(settings)
	local visible = 0
	for _, definition in ipairs(getViewDefinitions() or {}) do
		local button = self.railButtons[definition.id]
		if button and (not button.IsShown or button:IsShown()) then
			visible = visible + 1
			local width = button.GetWidth and tonumber(button:GetWidth()) or widestTab
			local height = button.GetHeight and tonumber(button:GetHeight()) or RAIL_TAB_HEIGHT
			widestTab = math.max(widestTab, width or 0)
			if horizontal then
				totalWidth = totalWidth + (width or widestTab) + (visible > 1 and 2 or 0)
			else
				totalHeight = totalHeight + (height or RAIL_TAB_HEIGHT) + (visible > 1 and 2 or 0)
			end
		end
	end
	self.railRequiredTabWidth = widestTab
	if horizontal then
		self.railContent:SetWidth(math.max(1, totalWidth))
		self.railContent:SetHeight(RAIL_TAB_HEIGHT)
	else
		self.railContent:SetWidth(widestTab)
		self.railContent:SetHeight(math.max(1, totalHeight))
	end
end

function Dock:RefreshRailState()
	if not self.railButtons then
		return
	end
	local settings = addon:GetSmartSettings()
	local widestTab = self:GetRailTabMinimumWidth(settings)
	for id, button in pairs(self.railButtons) do
		local active = id == self.activeView
		local dragging = id == self.railTabDragViewId
		Theme:ApplyFrame(button,
			dragging and "surfaceRaised" or (active and "accentSoft" or "surface"),
			dragging and "goldBright" or (active and "gold" or "borderMuted"))
		local r, g, b, a = Theme:GetColor(dragging and "goldBright" or (active and "goldBright" or "textMuted"))
		button.text:SetTextColor(r, g, b, a)
		self:ApplyRailUnreadCountAppearance(button, settings)
		local unread = self.unread[id] or 0
		if unread > 0 then
			button.unread:SetText(unread > 99 and "99+" or tostring(unread))
			button.unread:Show()
		else
			button.unread:Hide()
		end
		local buttonWidth = self:UpdateRailTabMetrics(button, settings)
		widestTab = math.max(widestTab, buttonWidth or 0)
	end
	self.railRequiredTabWidth = widestTab
	self:RefreshRailContentBounds(settings)
end

function Dock:GetNewMessageIndicatorLabel(count, settings)
	local _, showCount, maxCount = getNewMessageIndicatorOptions(settings or addon:GetSmartSettings())
	if not showCount then
		return "NEW"
	end
	count = math.max(1, math.floor(tonumber(count) or 1))
	if count > maxCount then
		return "NEW " .. maxCount .. "+"
	end
	return "NEW " .. count
end

-- Keep the active-view indicator as a pure view of transient unread state.
-- Disabling it must not discard pending lines: turning it back on while the
-- player is still reading history should accurately show what arrived.
function Dock:RefreshNewMessageIndicator(updateHeader)
	if not self.newButton then
		return false
	end
	local settings = addon:GetSmartSettings()
	local enabled = getNewMessageIndicatorOptions(settings)
	local pending = math.max(0, math.floor(tonumber(self.pendingVisible) or 0))
	local preview = self:IsNewMessageIndicatorPreviewActive()
	local shouldShow = self.active and not self:IsCollapsed() and ((enabled and pending > 0) or preview)
	if shouldShow then
		-- Preview is strictly visual: it never manufactures or clears unread
		-- state. A small sample count simply makes count/font/color choices
		-- legible before a real message happens to arrive.
		local labelCount = pending > 0 and pending or 3
		setButtonLabel(self.newButton, self:GetNewMessageIndicatorLabel(labelCount, settings), 18)
		self:ApplyNewMessageIndicatorAppearance(settings)
		-- Applying an independent font/size can change GetStringWidth. Measure
		-- once more after the visual override so a wide custom font never clips
		-- NEW 99+ or steals space from the title-bar controls.
		setButtonLabel(self.newButton, self:GetNewMessageIndicatorLabel(labelCount, settings), 18)
		self.newButton:Show()
	else
		-- Reset a temporary preview parent/placement as soon as the sample is
		-- dismissed, even if no unread messages are currently visible.
		self:ApplyNewMessageIndicatorAppearance(settings)
		self.newButton:Hide()
	end
	if updateHeader ~= false and self.UpdateHeaderTextLayout then
		self:UpdateHeaderTextLayout()
	end
	return enabled and pending > 0
end

function Dock:ClearPendingMessages()
	self.pendingVisible = 0
	self:RefreshNewMessageIndicator()
end

function Dock:CanMoveNewMessageIndicator()
	local button = self.newButton
	if not self.active or not self.built or self:IsCollapsed() or not self.frame or not button then
		return false
	end
	if not frameIsShown(self.frame) or not frameIsShown(button) then
		return false
	end
	-- Locked controls frame movement and resizing only. The marker's Shift-drag
	-- is an independent visual preference, just like Shift-drag tab ordering,
	-- and should remain usable in a deliberately locked chat layout.
	if InCombatLockdown and InCombatLockdown() then
		return false
	end
	return true
end

function Dock:EnsureNewMessageIndicatorMoveDriver()
	if self.newMessageIndicatorMoveDriver then
		return self.newMessageIndicatorMoveDriver
	end
	if not CreateFrame then
		return nil
	end
	local driver = CreateFrame("Frame")
	driver:Hide()
	driver:SetScript("OnUpdate", function()
		Dock:UpdateNewMessageIndicatorMove()
	end)
	self.newMessageIndicatorMoveDriver = driver
	return driver
end

function Dock:ApplyNewMessageIndicatorTemporaryDockPosition(point, x, y)
	local button = self.newButton
	if not button or not self.frame then
		return false
	end
	point, x, y = self:ClampNewMessageIndicatorDockPosition(point, x, y)
	if button.SetParent and (not button.GetParent or button:GetParent() ~= self.frame) then
		button:SetParent(self.frame)
	end
	if button.SetFrameLevel and self.frame.GetFrameLevel then
		button:SetFrameLevel(self.frame:GetFrameLevel() + 12)
	end
	if button.ClearAllPoints then
		button:ClearAllPoints()
	end
	if button.SetPoint then
		button:SetPoint(point, self.frame, point, x, y)
	end
	self.newMessageIndicatorAppliedPosition = { anchor = "dock", point = point, x = x, y = y }
	return true, point, x, y
end

function Dock:BeginNewMessageIndicatorMoveCandidate()
	if not isShiftDown() or not self:CanMoveNewMessageIndicator() then
		return false
	end
	local cursorX, cursorY = getCursorInUiCoordinates()
	local button = self.newButton
	local buttonLeft = getFrameCoordinate(button, "GetLeft")
	local buttonTop = getFrameCoordinate(button, "GetTop")
	if cursorX == nil or cursorY == nil or buttonLeft == nil or buttonTop == nil then
		return false
	end
	local driver = self:EnsureNewMessageIndicatorMoveDriver()
	if not driver then
		return false
	end
	self:CancelNewMessageIndicatorMove(false)
	self.newMessageIndicatorMove = {
		cursorX = cursorX,
		cursorY = cursorY,
		grabX = cursorX - buttonLeft,
		grabY = buttonTop - cursorY,
		dragging = false,
	}
	driver:Show()
	return true
end

function Dock:UpdateNewMessageIndicatorMove()
	local move = self.newMessageIndicatorMove
	if not move then
		if self.newMessageIndicatorMoveDriver then
			self.newMessageIndicatorMoveDriver:Hide()
		end
		return false
	end
	-- A marker drag can reparent the button from the title bar to the dock.
	-- In that transition a button-local OnMouseUp is not guaranteed to fire,
	-- so mirror the rail reorder driver's release detection.  Only commit a
	-- real drag while Shift remains down; otherwise restore the saved position.
	if IsMouseButtonDown then
		local ok, down = pcall(IsMouseButtonDown, "LeftButton")
		if ok and down == false then
			if move.dragging and isShiftDown() then
				self:EndNewMessageIndicatorMove()
			else
				self:CancelNewMessageIndicatorMove(move.dragging)
			end
			return false
		end
	end
	if not isShiftDown() or not self:CanMoveNewMessageIndicator() then
		self:CancelNewMessageIndicatorMove(move.dragging)
		return false
	end
	local cursorX, cursorY = getCursorInUiCoordinates()
	if cursorX == nil or cursorY == nil then
		return false
	end
	local deltaX = cursorX - move.cursorX
	local deltaY = cursorY - move.cursorY
	if not move.dragging then
		if (deltaX * deltaX) + (deltaY * deltaY) < (NEW_MESSAGE_INDICATOR_DRAG_DISTANCE * NEW_MESSAGE_INDICATOR_DRAG_DISTANCE) then
			return false
		end
		move.dragging = true
		self.newMessageIndicatorMoving = true
	end
	local frameLeft = getFrameCoordinate(self.frame, "GetLeft")
	local frameTop = getFrameCoordinate(self.frame, "GetTop")
	if frameLeft == nil or frameTop == nil then
		return false
	end
	local x = (cursorX - move.grabX) - frameLeft
	local y = (cursorY + move.grabY) - frameTop
	local applied, point, savedX, savedY = self:ApplyNewMessageIndicatorTemporaryDockPosition("TOPLEFT", x, y)
	if applied then
		move.point = point
		move.x = savedX
		move.y = savedY
	end
	return applied
end

function Dock:SuppressNewMessageIndicatorClick()
	local now = GetTime and GetTime() or 0
	self.newMessageIndicatorSuppressClickUntil = now + RAIL_REORDER_CLICK_SUPPRESS_SECONDS
end

function Dock:ShouldSuppressNewMessageIndicatorClick()
	local untilTime = tonumber(self.newMessageIndicatorSuppressClickUntil)
	if not untilTime then
		return false
	end
	self.newMessageIndicatorSuppressClickUntil = nil
	local now = GetTime and GetTime() or 0
	return now <= untilTime
end

function Dock:CancelNewMessageIndicatorMove(restore)
	local move = self.newMessageIndicatorMove
	local wasDragging = move and move.dragging
	self.newMessageIndicatorMove = nil
	self.newMessageIndicatorMoving = false
	if self.newMessageIndicatorMoveDriver then
		self.newMessageIndicatorMoveDriver:Hide()
	end
	if wasDragging and restore then
		self:SuppressNewMessageIndicatorClick()
		if self.newButton and self.frame then
			self:ApplyNewMessageIndicatorAppearance()
		end
	end
	return wasDragging and true or false
end

function Dock:EndNewMessageIndicatorMove()
	local move = self.newMessageIndicatorMove
	if not move then
		return false
	end
	local wasDragging = move.dragging == true
	self.newMessageIndicatorMove = nil
	self.newMessageIndicatorMoving = false
	if self.newMessageIndicatorMoveDriver then
		self.newMessageIndicatorMoveDriver:Hide()
	end
	if not wasDragging then
		return false
	end
	self:SuppressNewMessageIndicatorClick()
	local position = {
		anchor = "dock",
		point = move.point or "TOPLEFT",
		x = move.x or 0,
		y = move.y or 0,
	}
	local saved = false
	if addon.SetNewMessageIndicatorPosition then
		local ok, accepted = pcall(addon.SetNewMessageIndicatorPosition, addon, position)
		saved = ok and accepted ~= false
	end
	if not saved then
		-- The narrow fallback keeps a hand-loaded older Settings.lua usable. In
		-- normal operation the public setter above owns validation/migration.
		local settings = addon:GetSmartSettings()
		settings.dock = settings.dock or {}
		settings.dock.newMessages = settings.dock.newMessages or {}
		settings.dock.newMessages.appearance = settings.dock.newMessages.appearance or {}
		settings.dock.newMessages.appearance.position = position
		self:RefreshNewMessageIndicator()
	end
	-- Keep an already-open Dock Layout inspector honest: Shift-drag is a real
	-- setting change, so its position summary should become CUSTOM immediately
	-- instead of waiting for the page to be reopened.
	local config = addon.CustomConfig
	if config and type(config.RefreshNewMessageIndicatorAppearance) == "function" then
		pcall(config.RefreshNewMessageIndicatorAppearance, config)
	end
	return true
end

function Dock:RefreshRailSettingsIcon(state)
	return setRailSettingsIconState(self.railSettingsButton, state or "normal")
end

-- Live-tab ordering intentionally uses the same SavedVariables API as the
-- Rails & Sources page.  The dock only decides a visual insertion point; it
-- never mutates railOrder itself or touches a rail's routing/source settings.
function Dock:GetRailTabIndex(viewId, definitions)
	definitions = definitions or getViewDefinitions() or {}
	for index = 1, #definitions do
		if definitions[index].id == viewId then
			return index
		end
	end
	return nil
end

function Dock:GetRailTabMoveIndex(viewId, targetViewId, after)
	if not viewId or not targetViewId or viewId == targetViewId then
		return nil
	end
	local definitions = getViewDefinitions() or {}
	local currentIndex = self:GetRailTabIndex(viewId, definitions)
	local targetIndex = self:GetRailTabIndex(targetViewId, definitions)
	if not currentIndex or not targetIndex then
		return nil
	end

	-- MoveSmartViewToIndex addresses the final list after the source has been
	-- removed. Account for that one-slot shift so a marker always means exactly
	-- what it looks like: before or after the tab beside it.
	if after then
		if currentIndex > targetIndex then
			targetIndex = targetIndex + 1
		end
	elseif currentIndex < targetIndex then
		targetIndex = targetIndex - 1
	end
	targetIndex = math.max(1, math.min(#definitions, targetIndex))
	return targetIndex, currentIndex
end

function Dock:CanReorderRailTabs()
	if not self.active or not self.built or self:IsCollapsed() then
		return false
	end
	if not frameIsShown(self.frame) or not frameIsShown(self.rail) or type(self.railButtons) ~= "table" then
		return false
	end
	-- Do not introduce a new mutable frame interaction during combat. The
	-- buttons are not secure, but this keeps drag configuration aligned with
	-- the dock's conservative resize/activation contract.
	if InCombatLockdown and InCombatLockdown() then
		return false
	end
	return true
end

function Dock:IsRailTabReordering()
	return self.railTabDragViewId ~= nil
end

function Dock:GetVisibleRailTabButtons()
	local tabs = {}
	local definitions = getViewDefinitions() or {}
	for index = 1, #definitions do
		local definition = definitions[index]
		local button = self.railButtons and self.railButtons[definition.id]
		if button and frameIsShown(button) then
			table.insert(tabs, button)
		end
	end
	return tabs
end

function Dock:ClearRailTabDropTarget()
	self.railTabDropTargetId = nil
	self.railTabDropAfter = nil
	if self.railTabReorderMarker then
		self.railTabReorderMarker:Hide()
	end
end

function Dock:ShowRailTabDropMarker(viewId, after)
	local marker = self.railTabReorderMarker
	local target = self.railButtons and self.railButtons[viewId]
	if not marker or not target or not frameIsShown(target) then
		if marker then marker:Hide() end
		return false
	end

	local horizontal = addon:GetSmartSettings().dock.railOrientation == "horizontal"
	marker:ClearAllPoints()
	if horizontal then
		marker:SetWidth(RAIL_REORDER_MARKER_THICKNESS)
		if after then
			marker:SetPoint("TOP", target, "TOPRIGHT", 1, -1)
			marker:SetPoint("BOTTOM", target, "BOTTOMRIGHT", 1, 1)
		else
			marker:SetPoint("TOP", target, "TOPLEFT", -1, -1)
			marker:SetPoint("BOTTOM", target, "BOTTOMLEFT", -1, 1)
		end
	else
		marker:SetHeight(RAIL_REORDER_MARKER_THICKNESS)
		if after then
			marker:SetPoint("LEFT", target, "BOTTOMLEFT", 1, -1)
			marker:SetPoint("RIGHT", target, "BOTTOMRIGHT", -1, -1)
		else
			marker:SetPoint("LEFT", target, "TOPLEFT", 1, 1)
			marker:SetPoint("RIGHT", target, "TOPRIGHT", -1, 1)
		end
	end
	marker:Show()
	return true
end

function Dock:GetRailTabDropTarget(cursorX, cursorY)
	if not self.railTabDragViewId or cursorX == nil or cursorY == nil then
		return nil
	end
	local sourceButton = self.railTabDragButton
	if sourceButton and sourceButton.IsMouseOver and sourceButton:IsMouseOver() then
		-- Dropping back onto the original tab is a deliberate no-op rather than
		-- guessing a neighbouring slot from the source's centre point.
		return nil
	end

	local horizontal = addon:GetSmartSettings().dock.railOrientation == "horizontal"
	local lastButton
	for _, button in ipairs(self:GetVisibleRailTabButtons()) do
		if button.viewId ~= self.railTabDragViewId then
			local centerX, centerY = button:GetCenter()
			local center = horizontal and tonumber(centerX) or tonumber(centerY)
			if center then
				-- UI Y coordinates grow upward while a vertical rail reads from
				-- top to bottom, so the vertical comparison is intentionally
				-- reversed from the horizontal one.
				if (horizontal and cursorX <= center) or ((not horizontal) and cursorY >= center) then
					return button.viewId, false
				end
				lastButton = button
			end
		end
	end
	if lastButton then
		return lastButton.viewId, true
	end
	return nil
end

function Dock:UpdateRailTabDropTarget(cursorX, cursorY)
	local viewId, after = self:GetRailTabDropTarget(cursorX, cursorY)
	if viewId == self.railTabDropTargetId and after == self.railTabDropAfter then
		if viewId then
			self:ShowRailTabDropMarker(viewId, after)
		end
		return viewId, after
	end
	self.railTabDropTargetId = viewId
	self.railTabDropAfter = after
	if viewId then
		self:ShowRailTabDropMarker(viewId, after)
	else
		self:ClearRailTabDropTarget()
	end
	return viewId, after
end

function Dock:AutoScrollRailTabs(elapsed, cursorX, cursorY)
	local scroll = self.railScroll
	if not scroll or cursorX == nil or cursorY == nil then
		return false
	end
	local left = getFrameCoordinate(scroll, "GetLeft")
	local right = getFrameCoordinate(scroll, "GetRight")
	local top = getFrameCoordinate(scroll, "GetTop")
	local bottom = getFrameCoordinate(scroll, "GetBottom")
	if not left or not right or not top or not bottom then
		return false
	end

	local horizontal = addon:GetSmartSettings().dock.railOrientation == "horizontal"
	local direction = 0
	if horizontal then
		if cursorX <= left + RAIL_REORDER_AUTO_SCROLL_EDGE then
			direction = -1
		elseif cursorX >= right - RAIL_REORDER_AUTO_SCROLL_EDGE then
			direction = 1
		end
	else
		if cursorY >= top - RAIL_REORDER_AUTO_SCROLL_EDGE then
			direction = -1
		elseif cursorY <= bottom + RAIL_REORDER_AUTO_SCROLL_EDGE then
			direction = 1
		end
	end
	if direction == 0 then
		return false
	end

	local amount = math.max(1, (tonumber(elapsed) or 0) * RAIL_REORDER_AUTO_SCROLL_SPEED) * direction
	if horizontal and scroll.SetHorizontalScroll then
		local range = scroll.GetHorizontalScrollRange and scroll:GetHorizontalScrollRange() or 0
		local current = scroll.GetHorizontalScroll and scroll:GetHorizontalScroll() or 0
		local nextValue = math.max(0, math.min(tonumber(range) or 0, (tonumber(current) or 0) + amount))
		if nextValue ~= current then
			scroll:SetHorizontalScroll(nextValue)
			return true
		end
	elseif (not horizontal) and scroll.SetVerticalScroll then
		local range = scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange() or 0
		local current = scroll.GetVerticalScroll and scroll:GetVerticalScroll() or 0
		local nextValue = math.max(0, math.min(tonumber(range) or 0, (tonumber(current) or 0) + amount))
		if nextValue ~= current then
			scroll:SetVerticalScroll(nextValue)
			return true
		end
	end
	return false
end

function Dock:EnsureRailTabReorderDriver()
	if self.railTabReorderDriver then
		return self.railTabReorderDriver
	end
	if not CreateFrame then
		return nil
	end
	local driver = CreateFrame("Frame")
	driver:Hide()
	driver:SetScript("OnUpdate", function(_, elapsed)
		Dock:UpdateRailTabReorder(elapsed)
	end)
	self.railTabReorderDriver = driver
	return driver
end

function Dock:BeginRailTabReorder(button, cursorX, cursorY)
	if not button or not button.viewId or not self:CanReorderRailTabs() then
		return false
	end
	self.railTabPress = nil
	self.railTabDragViewId = button.viewId
	self.railTabDragButton = button
	self:CancelHeaderHoverRefresh()
	self:SetHeaderHover(true)
	hideTooltipForOwner(button)
	self:RefreshRailState()
	self:UpdateRailTabDropTarget(cursorX, cursorY)
	return true
end

function Dock:BeginRailTabReorderCandidate(button)
	if not button or not button.viewId or not isShiftDown() or not self:CanReorderRailTabs() then
		return false
	end
	local cursorX, cursorY = getCursorInUiCoordinates()
	if cursorX == nil or cursorY == nil then
		return false
	end
	local driver = self:EnsureRailTabReorderDriver()
	if not driver then
		return false
	end
	self:CancelRailTabReorder(false)
	self.railTabPress = {
		button = button,
		viewId = button.viewId,
		x = cursorX,
		y = cursorY,
	}
	driver:Show()
	return true
end

function Dock:SuppressRailTabClick(viewId)
	local now = GetTime and GetTime() or 0
	self.railTabSuppressClickViewId = viewId
	self.railTabSuppressClickUntil = now + RAIL_REORDER_CLICK_SUPPRESS_SECONDS
end

function Dock:ShouldSuppressRailTabClick(viewId)
	local untilTime = tonumber(self.railTabSuppressClickUntil)
	if not untilTime then
		return false
	end
	local now = GetTime and GetTime() or 0
	if self.railTabSuppressClickViewId and self.railTabSuppressClickViewId ~= viewId then
		if now > untilTime then
			self.railTabSuppressClickUntil = nil
			self.railTabSuppressClickViewId = nil
		end
		return false
	end
	self.railTabSuppressClickUntil = nil
	self.railTabSuppressClickViewId = nil
	return now <= untilTime
end

function Dock:CancelRailTabReorder(suppressClick)
	local dragViewId = self.railTabDragViewId
	local wasDragging = dragViewId ~= nil
	self.railTabPress = nil
	self.railTabDragViewId = nil
	self.railTabDragButton = nil
	self:ClearRailTabDropTarget()
	if self.railTabReorderDriver then
		self.railTabReorderDriver:Hide()
	end
	if suppressClick and wasDragging then
		self:SuppressRailTabClick(dragViewId)
	end
	if self.railButtons then
		self:RefreshRailState()
	end
	if wasDragging and self.active and self.frame and self.built and frameIsShown(self.frame) then
		self:ScheduleHeaderHoverRefresh(0)
	end
	return wasDragging
end

function Dock:FinishRailTabReorder(commit)
	local viewId = self.railTabDragViewId
	local targetViewId = self.railTabDropTargetId
	local after = self.railTabDropAfter
	local targetIndex, currentIndex = self:GetRailTabMoveIndex(viewId, targetViewId, after)
	local wasDragging = self:CancelRailTabReorder(true)
	if not wasDragging or not commit or not targetIndex or targetIndex == currentIndex then
		return false
	end
	if type(addon.MoveSmartViewToIndex) ~= "function" then
		return false
	end
	local ok, moved = pcall(addon.MoveSmartViewToIndex, addon, viewId, targetIndex)
	if ok and moved then
		-- Settings refreshes a live dock itself, but redraw once more defensively
		-- if an integration supplied the API without that callback.
		self:RefreshViews()
		self:RefreshRailState()
		return true
	end
	return false
end

function Dock:UpdateRailTabReorder(elapsed)
	if not self.railTabPress and not self.railTabDragViewId then
		if self.railTabReorderDriver then self.railTabReorderDriver:Hide() end
		return
	end

	if IsMouseButtonDown then
		local ok, down = pcall(IsMouseButtonDown, "LeftButton")
		if ok and down == false then
			if self.railTabDragViewId then
				self:FinishRailTabReorder(isShiftDown())
			else
				self:CancelRailTabReorder(false)
			end
			return
		end
	end
	if not isShiftDown() then
		-- Holding Shift is the configuration activator for this dock. Releasing
		-- it before drop cancels rather than silently moving a tab.
		self:CancelRailTabReorder(self.railTabDragViewId ~= nil)
		return
	end
	if not self:CanReorderRailTabs() then
		self:CancelRailTabReorder(self.railTabDragViewId ~= nil)
		return
	end

	local cursorX, cursorY = getCursorInUiCoordinates()
	if cursorX == nil or cursorY == nil then
		return
	end
	local press = self.railTabPress
	if press then
		local dx = cursorX - press.x
		local dy = cursorY - press.y
		if (dx * dx) + (dy * dy) >= (RAIL_REORDER_DRAG_DISTANCE * RAIL_REORDER_DRAG_DISTANCE) then
			self:BeginRailTabReorder(press.button, cursorX, cursorY)
		end
	end
	if self.railTabDragViewId then
		self:AutoScrollRailTabs(elapsed, cursorX, cursorY)
		self:UpdateRailTabDropTarget(cursorX, cursorY)
	end
end

function Dock:HandleRailTabMouseDown(button, mouseButton)
	if mouseButton == "LeftButton" then
		self:BeginRailTabReorderCandidate(button)
	end
end

function Dock:HandleRailTabMouseUp(_, mouseButton)
	if mouseButton ~= "LeftButton" then
		return
	end
	if self.railTabDragViewId then
		self:FinishRailTabReorder(isShiftDown())
	elseif self.railTabPress then
		-- This was a Shift-click, not a drag. Leave the normal OnClick path
		-- untouched so tab selection behaves exactly as it always has.
		self:CancelRailTabReorder(false)
	end
end

function Dock:RefreshViews()
	if not self.railButtons then
		return
	end
	local settings = addon:GetSmartSettings()
	local definitions = self:RefreshViewDefinitions()
	for _, button in pairs(self.railButtons) do
		button:Hide()
	end
	local previous
	local firstEnabled
	local enabledCount = 0
	local enabledViews = {}
	local railContentWidth = 4
	local railContentHeight = 4
	local widestTab = self:GetRailTabMinimumWidth(settings)
	local orientation = settings.dock.railOrientation == "horizontal" and "horizontal" or "vertical"
	for index = 1, #definitions do
		local definition = definitions[index]
		local button = self.railButtons[definition.id]
		if not button then
			button = self:BuildRailButton(definition)
			self.railButtons[definition.id] = button
		end
		button.viewId = definition.id
		button.definition = definition
		button.text:SetText(definition.key)
		self:ApplyRailUnreadCountAppearance(button, settings)
		local buttonWidth, buttonHeight = self:UpdateRailTabMetrics(button, settings)
		button:ClearAllPoints()
		if settings.views[definition.id] == nil then
			settings.views[definition.id] = true
		end
		local enabled = settings.views[definition.id] and definition.enabled ~= false
		enabledViews[definition.id] = enabled and true or false
		if enabled then
			enabledCount = enabledCount + 1
			firstEnabled = firstEnabled or definition.id
			button:Show()
			if orientation == "horizontal" then
				if previous then
					button:SetPoint("LEFT", previous, "RIGHT", 2, 0)
				else
					button:SetPoint("LEFT", self.railContent or self.rail, "LEFT", 2, 0)
				end
			elseif previous then
				button:SetPoint("TOP", previous, "BOTTOM", 0, -2)
			else
				button:SetPoint("TOP", self.railContent or self.rail, "TOP", 0, -2)
			end
			previous = button
			if orientation == "horizontal" then
				railContentWidth = railContentWidth + buttonWidth + (enabledCount > 1 and 2 or 0)
				widestTab = math.max(widestTab, buttonWidth)
			else
				railContentHeight = railContentHeight + buttonHeight + (enabledCount > 1 and 2 or 0)
				widestTab = math.max(widestTab, buttonWidth)
			end
		else
			button:Hide()
		end
	end
	if not firstEnabled then
		settings.views.general = true
		firstEnabled = "general"
		local button = self.railButtons.general
		button:ClearAllPoints()
		if orientation == "horizontal" then
			button:SetPoint("LEFT", self.railContent or self.rail, "LEFT", 2, 0)
		else
			button:SetPoint("TOP", self.railContent or self.rail, "TOP", 0, -2)
		end
		button:Show()
		enabledCount = 1
	end
	if self.railContent then
		if orientation == "horizontal" then
			self.railContent:SetWidth(math.max(1, railContentWidth))
			self.railContent:SetHeight(RAIL_TAB_HEIGHT)
		else
			self.railContent:SetWidth(widestTab)
			self.railContent:SetHeight(math.max(1, railContentHeight))
		end
	end
	self.railRequiredTabWidth = widestTab

	if not viewById[self.activeView] or not enabledViews[self.activeView] then
		self.activeView = firstEnabled or "general"
	end
	self:RefreshRailState()
end

function Dock:UpdateEmptyState(count)
	if self.transientMessageViewportSuppressed then
		self.emptyState:Hide()
		return
	end
	if count and count > 0 then
		self.emptyState:Hide()
	else
		local definition = self:GetActiveDefinition()
		local label = string.lower(definition.label or "this tab")
		if self.activeView and self.activeView ~= "general" then
			-- A specialized rail is often legitimately quiet immediately after a
			-- reload because history is intentionally session-only by default.
			-- Do not silently override a player's selected route; make the escape
			-- route obvious instead of leaving an empty panel that looks broken.
			self.emptyState:SetText("No " .. label .. " messages yet.\nHover this frame, then choose G / GENERAL.")
		else
			self.emptyState:SetText("No general messages yet.")
		end
		self.emptyState:Show()
	end
end

function Dock:ClearDisplayRecordCache()
	self.displayRecords = {}
	self.displayMeasurementWidth = nil
	self:HideMessageActionHighlight()
	if self.HideMessageBands then
		self:HideMessageBands()
	end
end

function Dock:IsSourceColumnAlignmentEnabled(viewId)
	if type(addon.GetViewSourceColumnAlignment) ~= "function" then
		return false
	end
	local ok, enabled = pcall(addon.GetViewSourceColumnAlignment, addon, viewId or self.activeView)
	return ok and enabled == true
end

function Dock:IsSenderColumnAlignmentEnabled(viewId)
	if type(addon.GetViewSenderColumnAlignment) ~= "function" then
		return false
	end
	local ok, enabled = pcall(addon.GetViewSenderColumnAlignment, addon, viewId or self.activeView)
	return ok and enabled == true
end

function Dock:GetColumnAlignmentSpacing()
	if type(addon.GetColumnAlignmentSpacing) == "function" then
		local ok, spacing = pcall(addon.GetColumnAlignmentSpacing, addon)
		if ok then
			return math.max(COLUMN_ALIGNMENT_SPACING_MIN,
				math.min(COLUMN_ALIGNMENT_SPACING_MAX, math.floor(tonumber(spacing) or 2)))
		end
	end
	local settings = addon.GetSmartSettings and addon:GetSmartSettings() or nil
	local dockSettings = settings and settings.dock
	if type(dockSettings) == "table" and dockSettings.columnAlignmentSpacing ~= nil then
		return math.max(COLUMN_ALIGNMENT_SPACING_MIN, math.min(COLUMN_ALIGNMENT_SPACING_MAX,
			math.floor(tonumber(dockSettings.columnAlignmentSpacing) or 2)))
	end
	return 2
end

function Dock:GetEffectiveSourceColumnAlignmentSpacing()
	-- Literal render spacing cannot be negative. A signed negative setting is
	-- consumed by CalculateSourceColumnWidthForLongest as label compaction.
	return math.max(0, self:GetColumnAlignmentSpacing())
end

function Dock:GetSenderColumnAlignmentSpacing()
	if type(addon.GetSenderColumnAlignmentSpacing) == "function" then
		local ok, spacing = pcall(addon.GetSenderColumnAlignmentSpacing, addon)
		if ok then
			return math.max(COLUMN_ALIGNMENT_SPACING_MIN,
				math.min(COLUMN_ALIGNMENT_SPACING_MAX, math.floor(tonumber(spacing) or 2)))
		end
	end
	local settings = addon.GetSmartSettings and addon:GetSmartSettings() or nil
	local dockSettings = settings and settings.dock
	if type(dockSettings) == "table" and dockSettings.senderColumnAlignmentSpacing ~= nil then
		return math.max(COLUMN_ALIGNMENT_SPACING_MIN, math.min(COLUMN_ALIGNMENT_SPACING_MAX,
			math.floor(tonumber(dockSettings.senderColumnAlignmentSpacing) or 2)))
	end
	-- Addon builds predating the separate [NAME] GAP retain the signed shared
	-- value, including a deliberately compact negative setting.
	return self:GetColumnAlignmentSpacing()
end

function Dock:GetSenderColumnMaxLength()
	if type(addon.GetSenderColumnMaxLength) == "function" then
		local ok, length = pcall(addon.GetSenderColumnMaxLength, addon)
		if ok then
			return math.max(SENDER_COLUMN_MAX_NAME_MIN, math.min(SENDER_COLUMN_MAX_NAME_MAX,
				math.floor(tonumber(length) or SENDER_COLUMN_MAX_NAME_DEFAULT)))
		end
	end
	local settings = addon.GetSmartSettings and addon:GetSmartSettings() or nil
	local dockSettings = settings and settings.dock
	return math.max(SENDER_COLUMN_MAX_NAME_MIN, math.min(SENDER_COLUMN_MAX_NAME_MAX,
		math.floor(tonumber(dockSettings and dockSettings.senderColumnMaxLength)
			or SENDER_COLUMN_MAX_NAME_DEFAULT)))
end

function Dock:IsAlignmentVisibleOnly()
	if type(addon.GetAlignmentVisibleOnly) == "function" then
		local ok, enabled = pcall(addon.GetAlignmentVisibleOnly, addon)
		if ok then return enabled == true end
	end
	local settings = addon.GetSmartSettings and addon:GetSmartSettings() or nil
	local dockSettings = settings and settings.dock
	return type(dockSettings) == "table" and dockSettings.alignmentVisibleOnly == true
end

function Dock:GetEffectiveSenderColumnWidth(width, spacing)
	width = math.max(0, math.floor(tonumber(width) or 0))
	spacing = math.max(COLUMN_ALIGNMENT_SPACING_MIN,
		math.min(COLUMN_ALIGNMENT_SPACING_MAX, math.floor(tonumber(spacing) or 2)))
	if width <= 0 or spacing >= 0 then return width end
	-- Preserve a visible character and both square brackets. Negative GAP then
	-- behaves as truncating compaction, never as a pixel/cell overlap offset.
	return math.max(3, width + spacing)
end

function Dock:CalculateSourceColumnLongest(records)
	local longest, driver = 0, nil
	for _, record in ipairs(records or {}) do
		local source = Presentation:GetSource(record)
		local length = presentationColumnCount(source)
		if length > longest then
			longest = length
			driver = tostring(source)
		end
	end
	return longest, driver
end

function Dock:CalculateSenderColumnLongest(records)
	local longest = 0
	for _, record in ipairs(records or {}) do
		if record.sender and record.sender ~= "" then
			-- Report the visible [NAME] lane, including its square brackets.
			longest = math.max(longest, presentationColumnCount(record.sender) + 2)
		end
	end
	return longest
end

function Dock:CalculateSourceColumnWidth(records)
	if not self:IsSourceColumnAlignmentEnabled() then
		return nil
	end
	-- Keep one stable lane for the current tab's rendered buffer.  SYSTEM then
	-- gets only the player's selected blank cells after it in a System view,
	-- while General can still accommodate ASCENSION/NEWCOMERS without its
	-- dividers wandering.
	local longest = self:CalculateSourceColumnLongest(records)
	if longest <= 0 then
		return nil
	end
	return self:CalculateSourceColumnWidthForLongest(longest)
end

function Dock:CalculateSourceColumnWidthForLongest(longest)
	longest = math.max(0, math.floor(tonumber(longest) or 0))
	if longest <= 0 then
		return nil
	end
	local signedSpacing = self:GetColumnAlignmentSpacing()
	local spacing = math.max(0, signedSpacing)
	local compaction = math.max(0, -signedSpacing)
	-- The fourteen-cell lane cap includes a positive gutter. A negative GAP
	-- instead removes label cells after the ordinary cap has been applied. The
	-- one-cell floor and trailing divider keep the two rendered lanes disjoint.
	local labelCapacity = math.max(1, SOURCE_COLUMN_MAX_CHARACTER_CAP - spacing)
	local labelWidth = math.max(1, math.min(labelCapacity, longest) - compaction)
	return labelWidth + spacing
end

function Dock:ResetActiveSourceColumnMetrics(records)
	local samples = {}
	local longest, driver = 0, nil
	for _, record in ipairs(records or {}) do
		local source = tostring(Presentation:GetSource(record) or "")
		local length = presentationColumnCount(source)
		table.insert(samples, { label = source, length = length })
		if length > longest then
			longest = length
			driver = source
		end
	end
	self.activeSourceColumnSamples = samples
	self.activeColumnRecordCount = #samples
	self.activeSourceColumnLongest = longest
	self.activeSourceColumnDriver = driver
	self.activeSourceColumnCandidateWidth = self:IsSourceColumnAlignmentEnabled()
		and self:CalculateSourceColumnWidthForLongest(longest) or nil
	self.activeSourceColumnWidth = self.activeSourceColumnCandidateWidth
	self.activeColumnLayoutResolved = nil
end

function Dock:TrackActiveSourceColumnLabel(sourceLabel)
	sourceLabel = tostring(sourceLabel or "")
	local length = presentationColumnCount(sourceLabel)
	local previousWidth = self.activeSourceColumnCandidateWidth
	local samples = self.activeSourceColumnSamples
	if type(samples) ~= "table" then
		-- A partially built/test dock has no trustworthy eviction window. Preserve
		-- the historical grow-only behavior rather than shrinking from one sample.
		if length > (tonumber(self.activeSourceColumnLongest) or 0) then
			self.activeSourceColumnLongest = length
			self.activeSourceColumnDriver = sourceLabel
		end
		local required = self:IsSourceColumnAlignmentEnabled()
			and self:CalculateSourceColumnWidthForLongest(length) or nil
		if required and (not previousWidth or required > previousWidth) then
			self.activeSourceColumnWidth = required
		end
		self.activeSourceColumnCandidateWidth = required
		if not self.activeColumnLayoutResolved then
			self.activeSourceColumnWidth = required
		end
		return previousWidth ~= required, required
	end

	-- RebuildActiveView renders at most the newest 400 records. Mirror that
	-- exact window so a long channel seen hundreds of messages ago cannot hold
	-- today's source lane open forever.
	local evicted
	if #samples >= 400 then
		evicted = table.remove(samples, 1)
	end
	table.insert(samples, { label = sourceLabel, length = length })
	self.activeColumnRecordCount = #samples

	local longest = tonumber(self.activeSourceColumnLongest) or 0
	if length > longest then
		longest = length
		self.activeSourceColumnDriver = sourceLabel
	elseif evicted and evicted.length == longest then
		longest = 0
		self.activeSourceColumnDriver = nil
		for _, sample in ipairs(samples) do
			if sample.length > longest then
				longest = sample.length
				self.activeSourceColumnDriver = sample.label
			end
		end
	end
	self.activeSourceColumnLongest = longest
	local required = self:IsSourceColumnAlignmentEnabled()
		and self:CalculateSourceColumnWidthForLongest(longest) or nil
	self.activeSourceColumnCandidateWidth = required
	if not self.activeColumnLayoutResolved then
		self.activeSourceColumnWidth = required
	end
	return previousWidth ~= required, required
end

function Dock:CalculateSenderColumnWidth(records)
	if not self:IsSenderColumnAlignmentEnabled() then
		return nil
	end
	local maximumNameLength = self:GetSenderColumnMaxLength()
	if not self:IsAlignmentVisibleOnly() then
		-- Buffer alignment remains fixed and therefore preserves the historical
		-- stable-lane behavior when the new visible-only option is disabled.
		return maximumNameLength + 2
	end
	local longest = self:CalculateSenderColumnLongest(records)
	if longest <= 0 then return nil end
	return math.min(maximumNameLength, math.max(1, longest - 2)) + 2
end

function Dock:IsResponsiveMetadataEnabled()
	if type(addon.GetResponsiveMetadata) == "function" then
		local ok, enabled = pcall(addon.GetResponsiveMetadata, addon)
		if ok then
			return enabled ~= false
		end
	end
	-- Settings may be older than this runtime.  Missing means on, while an
	-- explicit false already behaves correctly before a migration/API lands.
	local settings = addon.GetSmartSettings and addon:GetSmartSettings() or nil
	local dockSettings = settings and settings.dock
	return not dockSettings or dockSettings.responsiveMetadata ~= false
end

local function responsiveColumnWidth(value)
	value = math.floor(tonumber(value) or 0)
	return value > 0 and value or nil
end

local function responsiveBodyColumns(totalColumns, leaderColumns)
	if not totalColumns then
		return nil
	end
	return math.max(0, totalColumns - leaderColumns)
end

-- This resolver is intentionally data-only so its pixel-to-cell boundaries can
-- be tested without a WoW client.  Source/sender widths are their actual
-- configured aligned widths when non-nil, otherwise the longest natural label
-- in the rendered 400-record window.
function Dock:ResolveResponsiveMetadataLayout(totalColumns, spec)
	spec = type(spec) == "table" and spec or {}
	totalColumns = responsiveColumnWidth(totalColumns)
	local sourceAlignedWidth = responsiveColumnWidth(spec.sourceAlignedWidth)
	local senderAlignedWidth = responsiveColumnWidth(spec.senderAlignedWidth)
	local naturalSourceWidth = responsiveColumnWidth(spec.naturalSourceWidth) or 0
	local naturalSenderWidth = responsiveColumnWidth(spec.naturalSenderWidth) or 0
	local timestampWidth = responsiveColumnWidth(spec.timestampWidth)
		or RESPONSIVE_TIMESTAMP_CHARACTER_FALLBACK
	local configuredSpacing = math.max(COLUMN_ALIGNMENT_SPACING_MIN,
		math.min(COLUMN_ALIGNMENT_SPACING_MAX, math.floor(tonumber(spec.senderSpacing) or 0)))
	local compactSpacing = configuredSpacing < 0 and configuredSpacing
		or math.min(configuredSpacing, RESPONSIVE_COMPACT_SENDER_SPACING_CAP)
	local hasTimestamp = spec.hasTimestamp == true
	local hasSource = spec.hasSource == true
	local hasSender = spec.hasSender == true

	local function sourceCost(alignedWidth)
		if not hasSource then return 0 end
		return (alignedWidth or naturalSourceWidth) + (alignedWidth and 2 or 3)
	end
	local function senderCost(alignedWidth, spacing)
		if not hasSender then return 0 end
		if alignedWidth then
			return self:GetEffectiveSenderColumnWidth(alignedWidth, spacing) + math.max(0, spacing)
		end
		return naturalSenderWidth + math.max(0, spacing)
	end
	local function timestampCost()
		-- The trailing three-cell divider is also the boundary before a source-
		-- less sender or the message body.
		return hasTimestamp and (timestampWidth + 3) or 0
	end
	local function result(mode, showTimestamp, showSource, showSender,
			sourceWidth, senderWidth, spacing, leaderColumns)
		return {
			mode = mode,
			showTimestamp = showTimestamp,
			showSource = showSource,
			showSender = showSender,
			sourceColumnWidth = sourceWidth,
			senderColumnWidth = senderWidth,
			senderSpacing = spacing,
			leaderColumns = leaderColumns,
			bodyColumns = responsiveBodyColumns(totalColumns, leaderColumns),
			totalColumns = totalColumns,
		}
	end

	local wideLeader = timestampCost()
		+ sourceCost(sourceAlignedWidth)
		+ senderCost(senderAlignedWidth, configuredSpacing)
	if spec.enabled == false then
		return result("LOCKED", hasTimestamp, hasSource, hasSender,
			sourceAlignedWidth, senderAlignedWidth, configuredSpacing, wideLeader)
	end
	local wideBody = responsiveBodyColumns(totalColumns, wideLeader)
	if not totalColumns or wideBody >= RESPONSIVE_WIDE_MIN_BODY_COLUMNS then
		return result("WIDE", hasTimestamp, hasSource, hasSender,
			sourceAlignedWidth, senderAlignedWidth, configuredSpacing, wideLeader)
	end

	local compactSenderWidth = senderAlignedWidth
		and math.min(senderAlignedWidth, RESPONSIVE_COMPACT_SENDER_CHARACTER_CAP) or nil
	local mediumLeader = sourceCost(sourceAlignedWidth)
		+ senderCost(compactSenderWidth, compactSpacing)
	local mediumBody = responsiveBodyColumns(totalColumns, mediumLeader)
	if mediumBody >= RESPONSIVE_MEDIUM_MIN_BODY_COLUMNS then
		return result("MEDIUM", false, hasSource, hasSender,
			sourceAlignedWidth, compactSenderWidth, compactSpacing, mediumLeader)
	end

	-- Senderless rows retain their source provenance through the narrow stage;
	-- they become message-only only with the whole surface in EXTREME mode.
	local narrowSourceLeader = sourceCost(sourceAlignedWidth)
	local narrowSenderLeader = senderCost(compactSenderWidth, compactSpacing)
	local narrowLeader = math.max(narrowSourceLeader, narrowSenderLeader)
	local narrowBody = responsiveBodyColumns(totalColumns, narrowLeader)
	if narrowBody >= RESPONSIVE_NARROW_MIN_BODY_COLUMNS then
		return result("NARROW", false, hasSource, hasSender,
			sourceAlignedWidth, compactSenderWidth, compactSpacing, narrowLeader)
	end

	return result("EXTREME", false, false, false, nil, nil, 0, 0)
end

function Dock:ResolveActiveResponsiveMetadata()
	local previousMode = self.activeMetadataMode
	local previousSourceWidth = self.activeSourceColumnWidth
	local previousSenderWidth = self.activeSenderColumnWidth
	local previousSenderSpacing = self.activeSenderColumnAlignmentSpacing
	local totalColumns = self:GetDisplayColumnCapacity()
	local layout = self:ResolveResponsiveMetadataLayout(totalColumns, {
		enabled = self:IsResponsiveMetadataEnabled(),
		sourceAlignedWidth = self.activeSourceColumnCandidateWidth,
		senderAlignedWidth = self.activeSenderColumnCandidateWidth,
		senderSpacing = self.activeSenderColumnConfiguredSpacing,
		naturalSourceWidth = self.activeSourceColumnLongest,
		naturalSenderWidth = self.activeSenderColumnLongest,
		timestampWidth = self.activeTimestampColumnWidth,
		hasTimestamp = self.activeHasTimestamp,
		hasSource = self.activeHasSource,
		hasSender = self.activeHasSender,
	})
	self.activeMetadataMode = layout.mode
	self.activeMetadataBodyColumns = layout.bodyColumns
	self.activeMetadataLeaderColumns = layout.leaderColumns
	self.activeDisplayColumnCapacity = layout.totalColumns
	self.activeSourceColumnWidth = layout.sourceColumnWidth
	self.activeSenderColumnWidth = layout.senderColumnWidth
	self.activeSenderColumnAlignmentSpacing = layout.senderSpacing
	self.activeResponsiveMetadataEnabled = self:IsResponsiveMetadataEnabled()
	self.activeColumnLayoutResolved = totalColumns ~= nil
	return previousMode ~= self.activeMetadataMode
		or previousSourceWidth ~= self.activeSourceColumnWidth
		or previousSenderWidth ~= self.activeSenderColumnWidth
		or previousSenderSpacing ~= self.activeSenderColumnAlignmentSpacing,
		layout
end

function Dock:GetResponsiveMetadataMode()
	return self.activeMetadataMode or "WIDE",
		self.activeMetadataBodyColumns,
		self.activeDisplayColumnCapacity
end

function Dock:GetResponsiveMetadataForRecord(record)
	if not self.activeResponsiveMetadataEnabled or self.activeMetadataMode == "LOCKED" then
		return nil
	end
	local mode = self.activeMetadataMode or "WIDE"
	local hasSender = record and record.sender and record.sender ~= ""
	local hasSource = record and record.event ~= nil
	if mode == "MEDIUM" then
		return { showTimestamp = false, showSource = hasSource, showSender = hasSender }
	elseif mode == "NARROW" then
		-- Preserve SYSTEM/LOOT provenance when there is no player lane to show.
		return {
			showTimestamp = false,
			showSource = not hasSender and hasSource,
			showSender = hasSender and true or false,
		}
	elseif mode == "EXTREME" then
		return { showTimestamp = false, showSource = false, showSender = false }
	end
	return { showTimestamp = true, showSource = hasSource, showSender = hasSender and true or false }
end

function Dock:GetDisplayColumnCapacity()
	local display = self.display
	local measure = self.messageMeasure
	if not display or not measure or type(measure.GetStringWidth) ~= "function" then
		return nil
	end
	local displayWidth = tonumber(display.GetWidth and display:GetWidth()) or 0
	if displayWidth < 1 then
		return nil
	end
	local roundedWidth = math.floor(displayWidth + 0.5)
	if self.displayColumnCapacityWidth == roundedWidth and self.displayColumnCapacity then
		return self.displayColumnCapacity
	end

	-- The aligned-column feature guarantees a fixed-width face. Measure a long
	-- sample to average away subpixel rounding, then leave one physical pixel at
	-- the right edge so ScrollingMessageFrame never performs a second wrap. This
	-- live capacity also drives Presentation's adaptive exact-wrap budget, so a
	-- resized window or a different SharedMedia face changes the decision without
	-- guessing from the configured font size.
	local sample = string.rep("M", 32)
	if measure.SetWidth then measure:SetWidth(10000) end
	measure:SetText(sample)
	local sampleWidth = tonumber(measure:GetStringWidth()) or 0
	if measure.SetWidth then measure:SetWidth(displayWidth) end
	measure:SetText("")
	if sampleWidth <= 0 then
		return nil
	end
	local cellWidth = sampleWidth / 32
	local rawCapacity = math.max(1, math.floor((displayWidth - MANUAL_WRAP_PIXEL_SAFETY) / cellWidth))
	local capacity = math.max(1, rawCapacity - MANUAL_WRAP_SAFETY_COLUMNS)
	self.displayColumnCapacityWidth = roundedWidth
	self.displayColumnCapacity = capacity
	self.displayColumnCellWidth = cellWidth
	return capacity
end

function Dock:GetRoundedDisplayPixelWidth()
	local width = self.display and self.display.GetWidth
		and tonumber(self.display:GetWidth()) or 0
	if width < 1 then
		return nil
	end
	return math.floor(width + 0.5)
end

function Dock:MeasureMaximumDisplayLineWidth(renderedText)
	local measure = self.messageMeasure
	local display = self.display
	if not measure or not display or type(measure.SetText) ~= "function"
		or type(measure.GetStringWidth) ~= "function" then
		return nil
	end
	local displayWidth = tonumber(display.GetWidth and display:GetWidth()) or 0
	if displayWidth < 1 then return nil end
	if type(measure.SetWidth) == "function" then measure:SetWidth(10000) end
	local maximumWidth = 0
	for line in string.gmatch(tostring(renderedText or "") .. "\n", "(.-)\n") do
		measure:SetText(line)
		local width = tonumber(measure:GetStringWidth())
		if not width then
			if type(measure.SetWidth) == "function" then measure:SetWidth(displayWidth) end
			measure:SetText("")
			return nil
		end
		maximumWidth = math.max(maximumWidth, width)
	end
	if type(measure.SetWidth) == "function" then measure:SetWidth(displayWidth) end
	measure:SetText("")
	return maximumWidth
end

function Dock:DoesWrappedTextFitDisplay(renderedText)
	local measuredWidth = self:MeasureMaximumDisplayLineWidth(renderedText)
	local displayWidth = self.display and self.display.GetWidth
		and tonumber(self.display:GetWidth()) or 0
	if not measuredWidth or displayWidth < 1 then return nil, 0 end
	local limit = math.max(1, displayWidth - MANUAL_WRAP_PIXEL_SAFETY)
	return measuredWidth <= limit, math.max(0, measuredWidth - limit)
end

function Dock:RefreshDisplayWidthPresentation()
	local width = self:GetRoundedDisplayPixelWidth()
	if not width then
		return false
	end
	local previousWidth = self.activePresentationPixelWidth
	self.activePresentationPixelWidth = width
	if not previousWidth or previousWidth == width then
		return false
	end
	self.displayColumnCapacityWidth = nil
	self.displayColumnCapacity = nil
	self.displayColumnCellWidth = nil
	if self.active and self.activeView and addon.MessageEngine and not self.resizeDragRegion then
		self:RebuildActiveViewPreservingScroll()
	end
	return true
end

function Dock:FormatDisplayRecord(record)
	local sourceWidth = self.activeSourceColumnWidth
	local senderWidth = self.activeSenderColumnWidth
	local senderSpacing = self.activeSenderColumnAlignmentSpacing
	local metadata = self:GetResponsiveMetadataForRecord(record)
	if self:IsExactHangingWrapEnabled(self.activeView)
		and type(Presentation.FormatWrapped) == "function" then
		local totalColumns = self:GetDisplayColumnCapacity()
		if totalColumns then
			local rendered, leaderColumns = Presentation:FormatWrapped(
				record, sourceWidth, senderWidth, senderSpacing, totalColumns, metadata)
			for _ = 1, MANUAL_WRAP_VALIDATION_PASSES do
				local fits, overflow = self:DoesWrappedTextFitDisplay(rendered)
				if fits == nil or fits then break end
				local cellWidth = tonumber(self.displayColumnCellWidth) or 1
				local reduction = math.max(1, math.ceil((tonumber(overflow) or 0) / cellWidth) + 1)
				local narrower = math.max((tonumber(leaderColumns) or 0) + 1,
					totalColumns - reduction)
				if narrower >= totalColumns then break end
				totalColumns = narrower
				rendered, leaderColumns = Presentation:FormatWrapped(
					record, sourceWidth, senderWidth, senderSpacing, totalColumns, metadata)
			end
			return rendered
		end
	end
	return Presentation:Format(record, sourceWidth, senderWidth, senderSpacing, metadata)
end

function Dock:GetDisplayLineHeight()
	if not self.display then
		return 13
	end
	local _, fontHeight = self.display:GetFont()
	fontHeight = tonumber(fontHeight) or 12
	local spacing = self.display.GetSpacing and tonumber(self.display:GetSpacing()) or 1
	return math.max(1, fontHeight + (spacing or 0))
end

function Dock:MeasureDisplayRecordLines(renderedText)
	local measure = self.messageMeasure
	local display = self.display
	if not measure or not display then
		return 1
	end
	local width = tonumber(display:GetWidth()) or 0
	if width < 1 then
		return 1
	end
	measure:SetWidth(width)
	measure:SetText(renderedText or "")
	local textHeight = tonumber(measure:GetStringHeight()) or 0
	local _, fontHeight = display:GetFont()
	fontHeight = math.max(1, tonumber(fontHeight) or 12)
	-- FontString reports glyph height without ScrollingMessageFrame's inter-line
	-- spacing.  Round rather than ceiling so a one-line glyph-height variance
	-- does not make every record appear to occupy an extra line.
	return math.max(1, math.floor((textHeight / fontHeight) + 0.45))
end

function Dock:GetDisplayRecordGapRows(index)
	-- There is no separator before the first logical message. Every later
	-- record receives its requested rows *before* its text, which avoids a
	-- permanent trailing blank row below the newest message.
	if not index or index <= 1 then
		return 0
	end
	return self:GetSmartChatTextAppearance(self.activeView).entryGapRows or 0
end

function Dock:FormatDisplayRecordForDisplay(renderedText, gapRows)
	gapRows = math.max(ENTRY_GAP_ROWS_MIN, math.min(ENTRY_GAP_ROWS_MAX,
		math.floor(tonumber(gapRows) or 0)))
	if gapRows <= 0 then
		return renderedText
	end
	return string.rep(ENTRY_GAP_SPACER_ROW, gapRows) .. renderedText
end

function Dock:RefreshDisplayRecordMeasurements()
	if not self.display or not self.displayRecords then
		return
	end
	local width = math.floor((tonumber(self.display:GetWidth()) or 0) + 0.5)
	if width < 1 or self.displayMeasurementWidth == width then
		return
	end
	self.displayMeasurementWidth = width
	for index = 1, #self.displayRecords do
		local entry = self.displayRecords[index]
		-- Preserve the rows that were actually encoded into this AddMessage
		-- payload. Once ScrollingMessageFrame evicts its oldest message, the new
		-- first cached entry can still contain its original leading spacer; using
		-- its new table index would make resize-time hit/band geometry one row short.
		entry.gapRows = math.max(ENTRY_GAP_ROWS_MIN, math.min(ENTRY_GAP_ROWS_MAX,
			math.floor(tonumber(entry.gapRows) or 0)))
		entry.contentLines = self:MeasureDisplayRecordLines(self:FormatDisplayRecord(entry.record))
		entry.lines = entry.gapRows + entry.contentLines
	end
end

-- Resolve the viewport against Chatty's logical-record cache, whose `lines`
-- values mirror the exact strings sent to ScrollingMessageFrame. This is the
-- shared source of truth for visible-only alignment: partially clipped wrapped
-- records count as visible, while a recent record outside these line spans does
-- not influence either aligned lane.
function Dock:GetVisibleDisplayRecordEntries()
	local display = self.display
	local records = self.displayRecords
	if not display or type(records) ~= "table" or #records == 0 then
		return {}, nil
	end
	self:RefreshDisplayRecordMeasurements()
	local lineHeight = self:GetDisplayLineHeight()
	local displayHeight = tonumber(display.GetHeight and display:GetHeight()) or 0
	if displayHeight < 1 then return {}, nil end
	local capacity = math.max(1, math.floor(displayHeight / lineHeight))
	local totalLines = 0
	for index = 1, #records do
		totalLines = totalLines + math.max(1, tonumber(records[index].lines) or 1)
	end
	if totalLines < 1 then return {}, nil end

	-- Wrath's GetNumLinesDisplayed reports displayed message entries, not the
	-- number of visual rows consumed by their wraps.  Using it as a row count
	-- shifted overlays downward whenever one message occupied several lines.
	-- The viewport itself is the reliable visual-line budget.
	local visibleLines = math.max(1, math.min(capacity, totalLines))
	local scroll = display.GetCurrentScroll and tonumber(display:GetCurrentScroll()) or 0
	scroll = math.max(0, scroll or 0)
	local lastVisibleLine = math.max(1, math.min(totalLines, totalLines - scroll))
	local firstVisibleLine = math.max(1, lastVisibleLine - visibleLines + 1)
	visibleLines = lastVisibleLine - firstVisibleLine + 1

	local visible = {}
	local logicalCursor = 0
	for index = 1, #records do
		local entry = records[index]
		local entryLines = math.max(1, tonumber(entry.lines) or 1)
		local gapRows = math.max(0, math.min(entryLines - 1, math.floor(tonumber(entry.gapRows) or 0)))
		local entryFirst = logicalCursor + 1
		local entryLast = logicalCursor + entryLines
		local contentFirst = entryFirst + gapRows
		logicalCursor = entryLast
		if entryLast >= firstVisibleLine and entryFirst <= lastVisibleLine then
			table.insert(visible, {
				index = index,
				entry = entry,
				record = entry.record,
			firstLine = entryFirst,
			lastLine = entryLast,
			contentFirstLine = contentFirst,
			contentLastLine = entryLast,
			visibleFirstLine = math.max(entryFirst, firstVisibleLine),
			visibleLastLine = math.min(entryLast, lastVisibleLine),
			visibleContentFirstLine = math.max(contentFirst, firstVisibleLine),
			visibleContentLastLine = math.min(entryLast, lastVisibleLine),
			hasVisibleContent = entryLast >= firstVisibleLine and contentFirst <= lastVisibleLine,
		})
		end
	end
	return visible, {
		lineHeight = lineHeight,
		displayHeight = displayHeight,
		capacity = capacity,
		totalLines = totalLines,
		visibleLines = visibleLines,
		firstVisibleLine = firstVisibleLine,
		lastVisibleLine = lastVisibleLine,
		topInset = math.max(0, displayHeight - capacity * lineHeight)
			+ math.max(0, capacity - visibleLines) * lineHeight,
	}
end

function Dock:GetVisibleAlignmentRecords()
	local entries = self:GetVisibleDisplayRecordEntries()
	local records = {}
	for index = 1, #entries do
		if entries[index].hasVisibleContent and entries[index].record then
			table.insert(records, entries[index].record)
		end
	end
	return records, entries
end

function Dock:GetAlignmentScopeSignature(records)
	local parts = { tostring(#(records or {})) }
	for index, record in ipairs(records or {}) do
		-- Message ids are stable across a local rebuild. The table identity fallback
		-- keeps stripped mocks and synthetic local records just as deterministic.
		parts[#parts + 1] = tostring(record.id or record) .. ":" .. tostring(index)
	end
	return table.concat(parts, "|")
end

local function clampMessageBandUnit(value, fallback)
	value = tonumber(value)
	if value == nil then value = fallback end
	return math.max(0, math.min(1, tonumber(value) or 0))
end

local function normalizeMessageBandExtent(value)
	if MESSAGE_BAND_EXTENTS[value] then
		return value
	end
	local compact = type(value) == "string"
		and string.gsub(string.lower(value), "[^%a]", "") or ""
	local aliases = {
		full = "full",
		whole = "full",
		wholeline = "full",
		aftertimestamp = "afterTimestamp",
		timestamp = "afterTimestamp",
		afterchannel = "afterChannel",
		channel = "afterChannel",
		aftersource = "afterChannel",
		source = "afterChannel",
		afterplayer = "afterPlayer",
		player = "afterPlayer",
		aftersender = "afterPlayer",
		sender = "afterPlayer",
	}
	return aliases[compact] or "full"
end

-- Settings owns persistence and validation; SmartDock accepts the same small
-- shape directly so the renderer remains safe during migrations and in stripped
-- test clients.  A missing subtree is deliberately off, never a surprise style
-- change on an existing profile.
function Dock:GetMessageBandAppearance()
	local stored
	if type(addon.GetSmartChatMessageBandSettings) == "function" then
		local ok, result = pcall(addon.GetSmartChatMessageBandSettings, addon)
		if ok and type(result) == "table" then stored = result end
	end
	if not stored and type(addon.GetSmartSettings) == "function" then
		local ok, settings = pcall(addon.GetSmartSettings, addon)
		local dock = ok and type(settings) == "table" and settings.dock or nil
		stored = type(dock) == "table" and dock.messageBands or nil
	end
	stored = type(stored) == "table" and stored or {}

	local color = type(stored.color) == "table" and stored.color or nil
	local r, g, b = 0.085, 0.112, 0.158
	local themeName = type(stored.color) == "string" and stored.color
		or (color and (color.theme or color.colorway))
	if themeName and Theme and type(Theme.GetColor) == "function" then
		local tr, tg, tb = Theme:GetColor(themeName)
		if tr ~= nil then r, g, b = tr, tg, tb end
	elseif color then
		r = clampMessageBandUnit(color.r, r)
		g = clampMessageBandUnit(color.g, g)
		b = clampMessageBandUnit(color.b, b)
	else
		r = clampMessageBandUnit(stored.r, r)
		g = clampMessageBandUnit(stored.g, g)
		b = clampMessageBandUnit(stored.b, b)
	end

	return {
		enabled = stored.enabled == true,
		extent = normalizeMessageBandExtent(stored.extent),
		extendUnderScrollbar = stored.extendUnderScrollbar == true,
		r = r,
		g = g,
		b = b,
		alpha = clampMessageBandUnit(stored.alpha, color and color.a or 0.50),
	}
end

function Dock:HideMessageBands()
	for _, texture in ipairs(self.messageBandPool or {}) do
		texture:Hide()
	end
	self.messageBandVisibleCount = 0
end

function Dock:HideMessageActionHighlight()
	if self.messageActionHighlight then
		self.messageActionHighlight:Hide()
	end
	self.messageActionHighlightRecord = nil
end

-- Highlight the complete visible content span for the selected logical record.
-- Entry-gap spacer rows deliberately remain unpainted, and partially clipped
-- messages stop at the display edge. The texture is a non-interactive parent
-- region behind ScrollingMessageFrame, so text, links, and the slim scrollbar
-- retain their exact hit geometry.
function Dock:ShowMessageActionHighlight(record)
	local highlight = self.messageActionHighlight
	local display = self.display
	if not highlight or not display or not record or self.transientMessageViewportSuppressed then
		self:HideMessageActionHighlight()
		return false
	end

	local visibleEntries, geometry = self:GetVisibleDisplayRecordEntries()
	if not geometry then
		self:HideMessageActionHighlight()
		return false
	end
	local targetId = record.id
	for index = 1, #visibleEntries do
		local visible = visibleEntries[index]
		local visibleRecord = visible.record
		local sameRecord = visibleRecord == record
			or (targetId ~= nil and visibleRecord and visibleRecord.id ~= nil
				and tostring(visibleRecord.id) == tostring(targetId))
		if sameRecord and visible.hasVisibleContent then
			local top = geometry.topInset
				+ (visible.visibleContentFirstLine - geometry.firstVisibleLine) * geometry.lineHeight
			local bottom = math.min(geometry.displayHeight,
				geometry.topInset
				+ (visible.visibleContentLastLine - geometry.firstVisibleLine + 1) * geometry.lineHeight)
			if bottom > top then
				highlight:ClearAllPoints()
				highlight:SetPoint("TOPLEFT", display, "TOPLEFT", 0, -top)
				highlight:SetPoint("BOTTOMRIGHT", display, "TOPRIGHT", 0, -bottom)
				highlight:Show()
				self.messageActionHighlightRecord = record
				return true
			end
		end
	end

	self:HideMessageActionHighlight()
	return false
end

function Dock:AcquireMessageBand(index)
	if index > MESSAGE_BAND_POOL_LIMIT then
		return nil
	end
	self.messageBandPool = self.messageBandPool or {}
	local texture = self.messageBandPool[index]
	if texture then return texture end
	local host = self.messageBandHost or self.content
	if not host or type(host.CreateTexture) ~= "function" then
		return nil
	end
	-- Parent artwork is rendered behind child frames, leaving ScrollingMessageFrame
	-- hyperlinks, Shift actions, and selection hit testing completely untouched.
	texture = host:CreateTexture(nil, "ARTWORK")
	texture:SetTexture("Interface\\Buttons\\WHITE8x8")
	self.messageBandPool[index] = texture
	return texture
end

function Dock:GetMessageBandPrefix(record, extent)
	if extent == "full" then return "" end
	local metadata = self:GetResponsiveMetadataForRecord(record)
	if extent == "afterTimestamp" then
		-- Control sequences change color, never pixel width. Measuring the visible
		-- timestamp and its divider avoids coupling this simple boundary to theme.
		if (metadata and metadata.showTimestamp == false)
			or tostring(record and record.timestamp or "") == "" then
			return ""
		end
		return tostring(record and record.timestamp or "") .. " | "
	end
	if not Presentation or type(Presentation.FormatParts) ~= "function" then
		return nil
	end
	local sourceWidth = self.activeSourceColumnWidth
	local senderWidth = self.activeSenderColumnWidth
	local senderSpacing = self.activeSenderColumnAlignmentSpacing
	if extent == "afterChannel" then
		local channelOnly = {}
		for key, value in pairs(record or {}) do channelOnly[key] = value end
		channelOnly.sender = nil
		channelOnly.isBNet = nil
		return Presentation:FormatParts(channelOnly, sourceWidth, nil, senderSpacing, metadata)
	end
	return Presentation:FormatParts(record, sourceWidth, senderWidth, senderSpacing, metadata)
end

function Dock:MeasureMessageBandPrefix(record, extent)
	if extent == "full" then return 0 end
	local prefix = self:GetMessageBandPrefix(record, extent)
	local measure = self.messageMeasure
	local display = self.display
	if prefix == nil or not measure or not display
		or type(measure.SetText) ~= "function" or type(measure.GetStringWidth) ~= "function" then
		return nil
	end
	local displayWidth = tonumber(display.GetWidth and display:GetWidth()) or 0
	if type(measure.SetWidth) == "function" then measure:SetWidth(10000) end
	measure:SetText(prefix)
	local width = tonumber(measure:GetStringWidth())
	if type(measure.SetWidth) == "function" then measure:SetWidth(displayWidth) end
	measure:SetText("")
	return width
end

-- Draw only the currently visible alternating entries. One texture spans the
-- entire clipped logical record, so every wrapped continuation shares exactly
-- the same band and scrolling cannot turn a long message into zebra stripes.
function Dock:RefreshMessageBands()
	local appearance = self:GetMessageBandAppearance()
	local display = self.display
	local records = self.displayRecords
	if self.transientMessageViewportSuppressed or not appearance.enabled or appearance.alpha <= 0 or not display
		or type(records) ~= "table" or #records == 0 then
		self:HideMessageBands()
		return false
	end

	local visibleEntries, geometry = self:GetVisibleDisplayRecordEntries()
	local lineHeight = geometry and geometry.lineHeight or self:GetDisplayLineHeight()
	local displayHeight = geometry and geometry.displayHeight
		or tonumber(display.GetHeight and display:GetHeight()) or 0
	local displayWidth = tonumber(display.GetWidth and display:GetWidth()) or 0
	if displayHeight < 1 or displayWidth < 1 or not geometry then
		self:HideMessageBands()
		return false
	end
	local bandRightOffset = 0
	if appearance.extendUnderScrollbar then
		local rightInset = tonumber(self.transientMessageRightInset)
		if rightInset == nil then
			local settings = addon.GetSmartSettings and addon:GetSmartSettings() or nil
			local dockSettings = type(settings) == "table" and settings.dock or nil
			rightInset = type(dockSettings) == "table" and dockSettings.showScrollButtons == false
				and 4 or MESSAGE_SCROLLBAR_DISPLAY_INSET
		end
		bandRightOffset = math.max(0, rightInset - MESSAGE_BAND_PANEL_EDGE_INSET)
	end

	local used = 0
	for visibleIndex = 1, #visibleEntries do
		local visible = visibleEntries[visibleIndex]
		local entry = visible.entry
		local index = visible.index
		local alternating = entry.bandAlternate
		if alternating == nil then alternating = index % 2 == 0 end
		if alternating and visible.hasVisibleContent then
			local startX = self:MeasureMessageBandPrefix(entry.record, appearance.extent)
			if startX and startX < displayWidth and used < MESSAGE_BAND_POOL_LIMIT then
				used = used + 1
				local band = self:AcquireMessageBand(used)
				if band then
					local top = geometry.topInset
						+ (visible.visibleContentFirstLine - geometry.firstVisibleLine) * lineHeight
					local bottom = math.min(displayHeight,
						geometry.topInset
						+ (visible.visibleContentLastLine - geometry.firstVisibleLine + 1) * lineHeight)
					band:ClearAllPoints()
					band:SetPoint("TOPLEFT", display, "TOPLEFT", math.max(0, startX), -top)
					band:SetPoint("BOTTOMRIGHT", display, "TOPRIGHT", bandRightOffset, -bottom)
					band:SetVertexColor(appearance.r, appearance.g, appearance.b, appearance.alpha)
					band:Show()
				end
			end
		end
	end
	for index = used + 1, #(self.messageBandPool or {}) do
		self.messageBandPool[index]:Hide()
	end
	self.messageBandVisibleCount = used
	return true
end

function Dock:TrimDisplayRecordCache()
	local records = self.displayRecords
	if not records or not self.display or not self.display.GetNumMessages then
		return
	end
	local messageCount = tonumber(self.display:GetNumMessages())
	if not messageCount then
		return
	end
	while #records > messageCount do
		table.remove(records, 1)
	end
end

function Dock:AppendDisplayRecord(record)
	if not self.display or not record then
		return
	end
	self.displayRecords = self.displayRecords or {}
	local previous = self.displayRecords[#self.displayRecords]
	local gapRows = self:GetDisplayRecordGapRows(#self.displayRecords + 1)
	local renderedText = self:FormatDisplayRecord(record)
	local contentLines = self:MeasureDisplayRecordLines(renderedText)
	self.display:AddMessage(self:FormatDisplayRecordForDisplay(renderedText, gapRows), 1, 1, 1)
	table.insert(self.displayRecords, {
		record = record,
		gapRows = gapRows,
		contentLines = contentLines,
		lines = gapRows + contentLines,
		-- Alternate against the previous *visible record*, not MessageEngine's
		-- global id: a filtered tab can skip ids but should never show two adjacent
		-- entries with the same zebra state.
		bandAlternate = previous and not previous.bandAlternate or false,
	})
	self:TrimDisplayRecordCache()
	if not self.rebuildingDisplay then
		self:RefreshMessageBands()
		self:RefreshMessageScrollbar()
	end
end

function Dock:GetDisplayRecordAtCursor()
	local display = self.display
	local records = self.displayRecords
	if not display or not records or #records == 0 then
		return nil
	end
	local visibleEntries, geometry = self:GetVisibleDisplayRecordEntries()
	if not geometry or #visibleEntries == 0 then return nil end

	local x, y = getCursorInUiCoordinates()
	local left, right = display:GetLeft(), display:GetRight()
	local top, bottom = display:GetTop(), display:GetBottom()
	if not x or not y or not left or not right or not top or not bottom
		or x < left or x > right or y > top or y < bottom then
		return nil
	end

	local lineHeight = geometry.lineHeight
	local visibleLines = geometry.visibleLines
	local topInset = geometry.topInset
	local lineInViewport = math.floor(((top - y) - topInset) / lineHeight) + 1
	if lineInViewport < 1 or lineInViewport > visibleLines then
		return nil
	end
	local targetLine = geometry.firstVisibleLine + lineInViewport - 1
	if targetLine < geometry.firstVisibleLine or targetLine > geometry.lastVisibleLine then
		return nil
	end

	for index = 1, #visibleEntries do
		local visible = visibleEntries[index]
		if visible.hasVisibleContent
			and targetLine >= visible.visibleContentFirstLine
			and targetLine <= visible.visibleContentLastLine then
			return visible.record, lineInViewport, lineHeight, topInset
		end
	end
	return nil
end

function Dock:GetShiftHoveredRecord()
	-- Player-name hyperlinks already carry their exact MessageEngine id.  Prefer
	-- that path whenever possible, then use the geometry index for the rest of
	-- the line (including local UI errors which intentionally have no sender).
	local geometryRecord, lineInViewport, lineHeight, topInset = self:GetDisplayRecordAtCursor()
	if type(self.hoveredHyperlink) == "string" and addon.MessageEngine then
		local recordId = string.match(self.hoveredHyperlink, "^ccbbplayer:(%d+)$")
		if recordId then
			local record = addon.MessageEngine:GetMessageById(recordId)
			if record then
				return record, lineInViewport, lineHeight, topInset
			end
		end
	end
	return geometryRecord, lineInViewport, lineHeight, topInset
end

function Dock:CanUseMessageBlocks()
	local controller = addon.BlockControl
	if controller and type(controller.IsAvailable) == "function" then
		local ok, available = pcall(controller.IsAvailable, controller)
		if ok then
			return available and true or false
		end
		return false
	end
	return (controller and type(controller.BlockRecord) == "function")
		or type(addon.BlockRecord) == "function"
end

function Dock:CanAnalyzeMessages()
	return type(addon.AnalyzeRecord) == "function"
		or (addon.MessageEngine and type(addon.MessageEngine.AnalyzeRecord) == "function")
end

-- A small delayed launcher teaches the dock's discoverable gestures without
-- adding permanent chrome to the chat surface.  The old automatic tooltip was
-- useful once, but poor reference material: it disappeared as soon as the
-- player tried to absorb it.  The launcher opens a real, compact help menu
-- instead, and still yields immediately to hyperlinks and the Shift block UI.
function Dock:CanShowDisplayHoverHint()
	local display = self.display
	local content = self.content or display
	if not self.active or not display or isShiftDown()
		or self.hoveredHyperlink then
		return false
	end
	if self.chatHelpMenu and self.chatHelpMenu.IsShown and self.chatHelpMenu:IsShown() then
		return false
	end
	if display.IsShown and not display:IsShown() then
		return false
	end
	-- The dock's message frame owns most of the surface, but its narrow inset
	-- and empty-state area are sibling/parent regions on some 3.3.5 builds.
	-- Treat the entire readable chat surface as the hover target so a player
	-- does not have to find one exact pixel to discover the controls.
	local overDisplay = display.IsMouseOver and display:IsMouseOver()
	local overContent = content and content.IsMouseOver and content:IsMouseOver()
	if not overDisplay and not overContent then
		return false
	end
	if frameIsShown(self.blockAction) or frameIsShown(self.blockChoices)
		or frameIsShown(self.analysisAction) or frameIsShown(self.analysisPanel) then
		return false
	end
	if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() then
		local owner = GameTooltip.GetOwner and GameTooltip:GetOwner() or nil
		if owner ~= content then
			return false
		end
	end
	return true
end

function Dock:HideDisplayHoverHint()
	if self.displayHintDriver then
		self.displayHintDriver:Hide()
	end
	if self.displayHintShown and self.chatHelpTrigger then
		self.chatHelpTrigger:Hide()
	end
	self.displayHintShown = false
	self.displayHintOwner = nil
end

function Dock:ShowDisplayHoverHint()
	if not self:CanShowDisplayHoverHint() or not self.chatHelpTrigger then
		return false
	end
	self.chatHelpTrigger:Show()
	self.displayHintShown = true
	self.displayHintOwner = self.chatHelpTrigger
	return true
end

function Dock:EnsureDisplayHoverHintDriver()
	if self.displayHintDriver then
		return self.displayHintDriver
	end
	local driver = CreateFrame("Frame")
	driver:Hide()
	driver.elapsed = 0
	driver:SetScript("OnUpdate", function(_, elapsed)
		if not Dock:CanShowDisplayHoverHint() then
			Dock:HideDisplayHoverHint()
			return
		end
		driver.elapsed = (driver.elapsed or 0) + (elapsed or 0)
		if driver.elapsed >= DISPLAY_HINT_DELAY then
			driver:Hide()
			Dock:ShowDisplayHoverHint()
		end
	end)
	self.displayHintDriver = driver
	return driver
end

function Dock:ScheduleDisplayHoverHint()
	self:HideDisplayHoverHint()
	if not self:CanShowDisplayHoverHint() then
		return
	end
	local driver = self:EnsureDisplayHoverHintDriver()
	driver.elapsed = 0
	driver:Show()
end

-- The help content is deliberately short enough to read in the dock, but it
-- covers every direct gesture Chatty adds.  Keep the wording here instead of
-- relying on a transient GameTooltip so it can be reviewed, themed, and used
-- by a player who is still learning the surface.
function Dock:GetChatHelpPageContent(page)
	page = tonumber(page) or 1
	if page < 1 or page > 2 then
		page = 1
	end
	if page == 1 then
		local blockText
		if self:CanUseMessageBlocks() then
			blockText = "Hold SHIFT over a line, then use BLOCK. Right click offers exact or contains."
		else
			blockText = "Message Blocks are unavailable this session. Reload Chatty before using SHIFT BLOCK."
		end
		return "CHAT HELP: BASICS", {
			{ "TABS", "Click a tab to read it. Mouse wheel scrolls the active chat." },
			{ "WRITE", "Enter, /, or reply opens the input. Click SAY to choose where your message goes." },
			{ "BLOCK", blockText },
			{ "NEW", "Click NEW to jump to newest. SHIFT-drag NEW to move its marker." },
		}
	end
	return "CHAT HELP: ARRANGE", {
		{ "ORDER", "SHIFT-drag a tab to reorder the tab bar and save its place." },
		{ "ALIGN", "Views & Tabs > Global Text has ALIGN CHANNELS and ALIGN NAMES. Hold SHIFT over chat for ALIGN SETTINGS." },
		{ "WINDOW", "Drag the title bar to move. Hover a lit border edge, then drag to resize." },
		{ "SETTINGS", "CFG or the tab-bar settings icon opens Chatty controls and visibility options." },
	}
end

function Dock:RefreshChatHelpMenu()
	local menu = self.chatHelpMenu
	if not menu then
		return false
	end
	self.chatHelpPage = math.max(1, math.min(2, tonumber(self.chatHelpPage) or 1))
	local title, rows = self:GetChatHelpPageContent(self.chatHelpPage)
	if self.chatHelpTitle then
		self.chatHelpTitle:SetText(title)
	end
	for index, row in ipairs(self.chatHelpRows or {}) do
		local content = rows[index]
		if content then
			row.label:SetText(content[1])
			row.detail:SetText(content[2])
			row:Show()
		else
			row:Hide()
		end
	end
	if self.chatHelpPageText then
		self.chatHelpPageText:SetText(tostring(self.chatHelpPage) .. " / 2")
	end
	if self.chatHelpPrevious and self.chatHelpPrevious.SetEnabled then
		self.chatHelpPrevious:SetEnabled(self.chatHelpPage > 1)
	end
	if self.chatHelpNext and self.chatHelpNext.SetEnabled then
		self.chatHelpNext:SetEnabled(self.chatHelpPage < 2)
	end
	return true
end

function Dock:HideChatHelpMenu(scheduleLauncher)
	if self.chatHelpMenu then
		self.chatHelpMenu:Hide()
	end
	if self.chatHelpTrigger then
		self.chatHelpTrigger:Hide()
	end
	if scheduleLauncher and self.active then
		self:ScheduleDisplayHoverHint()
	end
end

function Dock:ShowChatHelpMenu()
	if not self.active or not self.chatHelpMenu then
		return false
	end
	self:HideDisplayHoverHint()
	if self.chatHelpTrigger then
		self.chatHelpTrigger:Show()
	end
	self:RefreshChatHelpMenu()
	self.chatHelpMenu:Show()
	return true
end

function Dock:ToggleChatHelpMenu()
	if self.chatHelpMenu and self.chatHelpMenu.IsShown and self.chatHelpMenu:IsShown() then
		self:HideChatHelpMenu(true)
		return false
	end
	return self:ShowChatHelpMenu()
end

function Dock:IsMessageBlockSurfaceHovered()
	return (self.display and self.display.IsMouseOver and self.display:IsMouseOver())
		or (self.content and self.content.IsMouseOver and self.content:IsMouseOver())
		or (self.blockAction and self.blockAction.IsMouseOver and self.blockAction:IsMouseOver())
		or (self.blockChoices and self.blockChoices.IsMouseOver and self.blockChoices:IsMouseOver())
		or (self.analysisAction and self.analysisAction.IsMouseOver and self.analysisAction:IsMouseOver())
		or (self.analysisPanel and self.analysisPanel.IsMouseOver and self.analysisPanel:IsMouseOver())
		or (self.analysisRouteMenu and self.analysisRouteMenu.IsMouseOver and self.analysisRouteMenu:IsMouseOver())
		or (self.chatHelpTrigger and self.chatHelpTrigger.IsMouseOver and self.chatHelpTrigger:IsMouseOver())
		or (self.chatHelpMenu and self.chatHelpMenu.IsMouseOver and self.chatHelpMenu:IsMouseOver())
		or (self.columnAlignmentSettingsButton and self.columnAlignmentSettingsButton.IsMouseOver
			and self.columnAlignmentSettingsButton:IsMouseOver())
end

function Dock:HideSourceColumnAlignmentControl()
	if self.columnAlignmentSettingsButton then
		self.columnAlignmentSettingsButton:Hide()
	end
end

function Dock:GetColumnAlignmentDiagnostics()
	local sourceSpacing = self:GetColumnAlignmentSpacing()
	local senderSpacing = self:GetSenderColumnAlignmentSpacing()
	local senderMax = self:GetSenderColumnMaxLength()
	local sourceLongest = tonumber(self.activeSourceColumnLongest) or 0
	local sourceWidth = tonumber(self.activeSourceColumnWidth) or 0
	local senderLongest = tonumber(self.activeSenderColumnLongest) or 0
	local senderWidth = tonumber(self.activeSenderColumnWidth) or 0
	local sourceCandidate = tonumber(self.activeSourceColumnCandidateWidth)
		or self:CalculateSourceColumnWidthForLongest(sourceLongest) or 0
	local senderCandidate = senderLongest > 0 and (senderMax + 2) or 0
	local senderEffective = self:GetEffectiveSenderColumnWidth(senderWidth, senderSpacing)
	local senderCandidateEffective = self:GetEffectiveSenderColumnWidth(senderCandidate, senderSpacing)
	local sourceDriver = tostring(self.activeSourceColumnDriver or "-")
	sourceDriver = string.gsub(sourceDriver, "%s+", " ")
	if #sourceDriver > 18 then
		sourceDriver = string.sub(sourceDriver, 1, 15) .. "..."
	end
	local sourceState = self:IsSourceColumnAlignmentEnabled()
		and (sourceDriver .. " " .. sourceLongest .. "+GAP " .. sourceSpacing .. "=" .. sourceWidth)
		or ("OFF " .. sourceDriver .. " " .. sourceLongest .. "+GAP " .. sourceSpacing .. "=" .. sourceCandidate)
	local senderState = self:IsSenderColumnAlignmentEnabled()
		and (senderLongest .. "/MAX " .. senderMax .. " LANE " .. senderEffective
			.. " GAP " .. senderSpacing)
		or ("OFF " .. senderLongest .. "/MAX " .. senderMax .. " LANE "
			.. senderCandidateEffective .. " GAP " .. senderSpacing)
	local mode, bodyColumns, totalColumns = self:GetResponsiveMetadataMode()
	local bodyLabel = bodyColumns == nil and "?" or tostring(bodyColumns)
	local totalLabel = totalColumns == nil and "?" or tostring(totalColumns)
	local scope = self:IsAlignmentVisibleOnly() and "VISIBLE " or "BUFFER "
	return "ALIGN  CH " .. sourceState .. "  " .. scope .. tostring(self.activeColumnRecordCount or 0)
		.. "\nNAME " .. senderState
		.. "\nMETA " .. tostring(mode) .. "  BODY " .. bodyLabel .. "/" .. totalLabel
end

function Dock:UpdateSourceColumnAlignmentControl()
	local button = self.columnAlignmentSettingsButton
	if not button then
		return
	end
	-- The readable chat is a child ScrollingMessageFrame. On Wrath clients the
	-- parent content frame is not guaranteed to report mouse-over while that
	-- child owns the cursor, so treat either surface and the quick-link itself as
	-- the Shift activation zone.
	local overSurface = (self.display and self.display.IsMouseOver and self.display:IsMouseOver())
		or (self.content and self.content.IsMouseOver and self.content:IsMouseOver())
		or (button.IsMouseOver and button:IsMouseOver())
	local visible = self.active and not self:IsCollapsed() and isShiftDown() and overSurface
	if not visible then
		button:Hide()
		return
	end
	local contentWidth = self.content and self.content.GetWidth and tonumber(self.content:GetWidth()) or 0
	local label = contentWidth > 0 and contentWidth < ALIGNMENT_SETTINGS_FULL_LABEL_MIN_CONTENT_WIDTH
		and "ALIGN" or "ALIGN SETTINGS"
	if button.SetLabel then
		button:SetLabel(label)
	elseif button.text then
		button.text:SetText(label)
	end
	if button.RefreshTextFit then
		button:RefreshTextFit()
	elseif button.SetWidth then
		local textWidth = button.text and button.text.GetStringWidth and tonumber(button.text:GetStringWidth())
		button:SetWidth(math.max(18, math.ceil(textWidth or (#label * 6)) + ALIGNMENT_SETTINGS_LABEL_PADDING))
	end
	button:Show()
end

function Dock:OpenGlobalTextAlignmentSettings()
	local config = addon.Config
	if config and type(config.OpenGlobalTextAlignment) == "function" then
		local ok = pcall(config.OpenGlobalTextAlignment, config)
		if ok then return true end
	end
	config = addon.CustomConfig
	if config and type(config.OpenGlobalTextAlignment) == "function" then
		local ok = pcall(config.OpenGlobalTextAlignment, config)
		if ok then return true end
	end
	if type(addon.OpenConfig) == "function" then
		addon:OpenConfig()
		return true
	end
	return false
end

function Dock:SetActiveViewSourceColumnAlignment(enabled)
	if type(addon.SetViewSourceColumnAlignment) ~= "function" or not self.activeView then
		return false
	end
	local ok, updated = pcall(addon.SetViewSourceColumnAlignment, addon, self.activeView, enabled == true)
	if not ok or updated ~= true then
		return false
	end
	self:UpdateSourceColumnAlignmentControl()
	return true
end

function Dock:SetActiveViewSenderColumnAlignment(enabled)
	if type(addon.SetViewSenderColumnAlignment) ~= "function" or not self.activeView then
		return false
	end
	local ok, updated = pcall(addon.SetViewSenderColumnAlignment, addon, self.activeView, enabled == true)
	if not ok or updated ~= true then
		return false
	end
	self:UpdateSourceColumnAlignmentControl()
	return true
end

function Dock:HideMessageBlockControls()
	self:HideMessageActionHighlight()
	if self.blockAction then
		self.blockAction:Hide()
	end
	if self.blockChoices then
		self.blockChoices:Hide()
	end
	if self.analysisAction then
		self.analysisAction:Hide()
	end
	if self.analysisPanel then
		self.analysisPanel:Hide()
	end
	self:HideMessageRouteOverrideMenu()
	self.blockActionRecord = nil
	self.blockChoicesRecord = nil
	self.analysisActionRecord = nil
	self.analysisRecord = nil
end

function Dock:EnsureMessageBlockDriver()
	if self.messageBlockDriver then
		return self.messageBlockDriver
	end
	local driver = CreateFrame("Frame")
	driver:Hide()
	driver.elapsed = 0
	driver:SetScript("OnUpdate", function(_, elapsed)
		driver.elapsed = (driver.elapsed or 0) + (elapsed or 0)
		if driver.elapsed < 0.04 then
			return
		end
		driver.elapsed = 0
		if not Dock.active then
			Dock:HideMessageBlockControls()
			driver:Hide()
			return
		end
		Dock:UpdateMessageBlockAction()
		if not isShiftDown() and not Dock:IsMessageBlockSurfaceHovered()
			and (not Dock.blockChoices or not Dock.blockChoices:IsShown())
			and (not Dock.analysisPanel or not Dock.analysisPanel:IsShown()) then
			driver:Hide()
		end
	end)
	self.messageBlockDriver = driver
	return driver
end

function Dock:ScheduleMessageBlockActionRefresh(defer)
	local driver = self:EnsureMessageBlockDriver()
	driver.elapsed = 0.04
	driver:Show()
	if not defer then
		self:UpdateMessageBlockAction()
	end
end

function Dock:UpdateMessageBlockAction()
	self:UpdateSourceColumnAlignmentControl()
	if isShiftDown() then
		-- The hover help yields before a compact per-line action is positioned.
		-- SHIFT is Chatty's explicit in-frame configuration modifier, so it is
		-- never obscured by a larger read-only help panel.
		self:HideDisplayHoverHint()
		self:HideChatHelpMenu(false)
	end
	if not self.active or not self.display then
		self:HideMessageBlockControls()
		return
	end

	local overDisplay = self.display.IsMouseOver and self.display:IsMouseOver()
	local overAction = self.blockAction and self.blockAction.IsMouseOver and self.blockAction:IsMouseOver()
	local overChoices = self.blockChoices and self.blockChoices.IsMouseOver and self.blockChoices:IsMouseOver()
	local overAnalyze = self.analysisAction and self.analysisAction.IsMouseOver and self.analysisAction:IsMouseOver()
	local overAnalysisPanel = (self.analysisPanel and self.analysisPanel.IsMouseOver and self.analysisPanel:IsMouseOver())
		or (self.analysisRouteMenu and self.analysisRouteMenu.IsMouseOver and self.analysisRouteMenu:IsMouseOver())
	if self.blockChoices and self.blockChoices:IsShown() then
		if not overDisplay and not overAction and not overChoices and not overAnalyze and not overAnalysisPanel and not isShiftDown() then
			self:HideMessageBlockControls()
		end
		return
	end
	if self.analysisPanel and self.analysisPanel:IsShown() then
		if not overDisplay and not overAction and not overChoices and not overAnalyze and not overAnalysisPanel and not isShiftDown() then
			self:HideMessageBlockControls()
		end
		return
	end

	if not isShiftDown() or not overDisplay then
		if not overAction and not overAnalyze then
			self:HideMessageBlockControls()
		end
		return
	end

	local record, lineInViewport, lineHeight, topInset = self:GetShiftHoveredRecord()
	if not record or not lineInViewport then
		self:HideMessageActionHighlight()
		if self.blockAction then self.blockAction:Hide() end
		if self.analysisAction then self.analysisAction:Hide() end
		self.blockActionRecord = nil
		self.analysisActionRecord = nil
		return
	end

	local displayHeight = tonumber(self.display:GetHeight()) or 0
	local actionHeight = tonumber((self.blockAction or self.analysisAction) and (self.blockAction or self.analysisAction):GetHeight()) or 18
	local lineTop = (topInset or 0) + ((lineInViewport - 1) * (lineHeight or self:GetDisplayLineHeight()))
	lineTop = math.max(0, math.min(math.max(0, displayHeight - actionHeight), lineTop))
	local showBlock = self.blockAction and self:CanUseMessageBlocks()
	local showAnalyze = self.analysisAction and self:CanAnalyzeMessages()
	if showBlock or showAnalyze then
		self:ShowMessageActionHighlight(record)
	else
		self:HideMessageActionHighlight()
	end
	if showBlock then
		self.blockAction:ClearAllPoints()
		self.blockAction:SetPoint("TOPRIGHT", self.display, "TOPRIGHT", -1, -lineTop)
		if self.blockAction.SetLabel then
			self.blockAction:SetLabel("BLOCK")
		end
		self.blockActionRecord = record
		self.blockAction:Show()
	elseif self.blockAction then
		self.blockAction:Hide()
		self.blockActionRecord = nil
	end
	if showAnalyze then
		self.analysisAction:ClearAllPoints()
		if showBlock then
			self.analysisAction:SetPoint("TOPRIGHT", self.blockAction, "TOPLEFT", -2, 0)
		else
			self.analysisAction:SetPoint("TOPRIGHT", self.display, "TOPRIGHT", -1, -lineTop)
		end
		self.analysisActionRecord = record
		self.analysisAction:Show()
	elseif self.analysisAction then
		self.analysisAction:Hide()
		self.analysisActionRecord = nil
	end
	self:HideDisplayHoverHint()
end

local function compactAnalysisText(value, maximum)
	value = tostring(value or "")
	maximum = math.max(12, math.floor(tonumber(maximum) or 112))
	if #value > maximum then
		return string.sub(value, 1, maximum - 3) .. "..."
	end
	return value
end

local function setAnalysisRowText(row, value)
	value = tostring(value or "")
	row:SetText(compactAnalysisText(value, 46))
	if row.analysisHit then
		row.analysisHit.analysisFullText = string.sub(value, 1, 1200)
	end
end

function Dock:RefreshMessageAnalysisLayout()
	local panel = self.analysisPanel
	local host = self.frame or self.content
	if not panel or not host then return false end
	local hostWidth = host.GetWidth and tonumber(host:GetWidth()) or 0
	local hostHeight = host.GetHeight and tonumber(host:GetHeight()) or 0
	local width = 356
	local height = 154
	if hostWidth > 0 then
		width = math.max(1, math.min(width, hostWidth - 8))
	end
	if hostHeight > 0 then height = math.max(1, math.min(height, hostHeight - 8)) end
	panel:ClearAllPoints()
	panel:SetPoint("TOPRIGHT", host, "TOPRIGHT", -4, -4)
	panel:SetWidth(width)
	panel:SetHeight(height)
	return true, width, height
end

function Dock:ShowMessageAnalysis(record)
	if not record or not self.analysisPanel then
		return false, "unavailable"
	end
	local invoked, analysis, reason
	if type(addon.AnalyzeRecord) == "function" then
		invoked, analysis, reason = pcall(addon.AnalyzeRecord, addon, record)
	elseif addon.MessageEngine and type(addon.MessageEngine.AnalyzeRecord) == "function" then
		invoked, analysis, reason = pcall(addon.MessageEngine.AnalyzeRecord, addon.MessageEngine, record)
	else
		return false, "unavailable"
	end
	if not invoked or type(analysis) ~= "table" then
		return false, reason or "failed"
	end

	self:HideDisplayHoverHint()
	self.analysisRecord = record
	local source = analysis.sourceLabel or analysis.sourceId or "Unknown source"
	if analysis.channel and analysis.channel ~= "" then
		source = source .. " / " .. analysis.channel
	end
	local signals = #analysis.signals > 0 and table.concat(analysis.signals, ", ") or "No special classifier signals."
	local why = #analysis.reasons > 0 and table.concat(analysis.reasons, " ") or "No stored classifier reason."
	if analysis.blocked then
		why = why .. " Blocked: " .. tostring(analysis.blockReason or "message rule") .. "."
	end
	setAnalysisRowText(self.analysisSource, source)
	setAnalysisRowText(self.analysisRoute, tostring(analysis.category or "general") .. " -> " .. tostring(analysis.view or "general"))
	setAnalysisRowText(self.analysisSignals, signals)
	setAnalysisRowText(self.analysisWhy, why)
	local canOverride = record.event == "CHAT_MSG_CHANNEL"
		and type(addon.SetMessageRouteOverride) == "function"
	if self.analysisRouteControls then
		for _, control in ipairs(self.analysisRouteControls) do
			if canOverride then control:Show() else control:Hide() end
		end
	end
	if canOverride then
		local selected = analysis.routeOverrideCategory or analysis.category
		if not self:SetMessageRouteOverrideDestination(selected, true) then
			self:SetMessageRouteOverrideDestination("general", true)
		end
		self:RefreshMessageRouteOverrideMenu()
	elseif self.analysisRouteMenu then
		self.analysisRouteMenu:Hide()
	end
	if self.analysisRemoveOverride then
		if canOverride and analysis.routeOverrideCategory then
			self.analysisRemoveOverride:Show()
		else
			self.analysisRemoveOverride:Hide()
		end
	end
	if self.analysisFootnote then
		if canOverride then
			self.analysisFootnote:SetText("MOVE saves the primary route; checked source feeds can keep a mirrored copy.")
		else
			self.analysisFootnote:SetText("Read-only: this message type cannot be rerouted.")
		end
	end
	self:RefreshMessageAnalysisLayout()
	self.analysisPanel:Show()
	self:ScheduleMessageBlockActionRefresh()
	return true, analysis
end

local fallbackMessageRouteDestinations = {
	{ id = "general", label = "GENERAL" },
	{ id = "newcomers", label = "NEWCOMERS" },
	{ id = "groupFinder", label = "GROUP FINDER" },
	{ id = "guildInvites", label = "GUILD INVITES" },
	{ id = "pvp", label = "PVP" },
	{ id = "trade", label = "TRADE" },
	{ id = "system", label = "SYSTEM" },
	{ id = "loot", label = "LOOT" },
}

function Dock:GetMessageRouteOverrideDestinations()
	local destinations
	if type(addon.GetMessageRouteOverrideDestinations) == "function" then
		local invoked, value = pcall(addon.GetMessageRouteOverrideDestinations, addon)
		if invoked and type(value) == "table" then
			destinations = value
		end
	end
	destinations = destinations or fallbackMessageRouteDestinations
	local clean, seen = {}, {}
	for index = 1, #destinations do
		local destination = destinations[index]
		if type(destination) == "table" and type(destination.id) == "string"
			and destination.id ~= "" and not seen[destination.id] then
			seen[destination.id] = true
			table.insert(clean, {
				id = destination.id,
				label = tostring(destination.label or destination.id),
			})
		end
	end
	return clean
end

function Dock:GetMessageRouteOverrideDestinationLabel(category)
	for _, destination in ipairs(self:GetMessageRouteOverrideDestinations()) do
		if destination.id == category then
			return destination.label
		end
	end
	return nil
end

function Dock:SetMessageRouteOverrideDestination(category, quiet)
	local label = self:GetMessageRouteOverrideDestinationLabel(category)
	if not label then
		return false
	end
	self.analysisRouteDestination = category
	if self.analysisRouteSelector then
		self.analysisRouteSelector:SetLabel(label .. " v")
	end
	if not quiet and self.analysisFootnote then
		self.analysisFootnote:SetText("Ready to save " .. label .. " as the primary route. Checked source feeds remain visible.")
	end
	return true
end

function Dock:RefreshMessageRouteOverrideMenu()
	local menu = self.analysisRouteMenu
	local destinations = self:GetMessageRouteOverrideDestinations()
	self.analysisRouteDestinations = destinations
	for index, button in ipairs(self.analysisRouteMenuButtons or {}) do
		local destination = destinations[index]
		if destination then
			button.routeDestination = destination
			button:SetLabel(destination.label)
			local selected = destination.id == self.analysisRouteDestination
			button:SetTheme(selected and "accentSoft" or "surfaceRaised", selected and "gold" or "borderMuted", selected and "goldBright" or "text")
			button:Show()
		else
			button.routeDestination = nil
			button:Hide()
		end
	end
	if menu then
		local rows = math.max(1, math.ceil(#destinations / 2))
		menu:SetHeight(8 + (rows * 18) + ((rows - 1) * 2))
	end
	return #destinations > 0
end

function Dock:HideMessageRouteOverrideMenu()
	if self.analysisRouteMenu then
		self.analysisRouteMenu:Hide()
	end
end

function Dock:ToggleMessageRouteOverrideMenu()
	if not self.analysisRecord or not self.analysisRouteMenu then
		return false
	end
	if self.analysisRouteMenu:IsShown() then
		self:HideMessageRouteOverrideMenu()
		return false
	end
	if not self:RefreshMessageRouteOverrideMenu() then
		return false
	end
	self.analysisRouteMenu:ClearAllPoints()
	self.analysisRouteMenu:SetPoint("BOTTOMLEFT", self.analysisRouteSelector, "TOPLEFT", 0, 2)
	self.analysisRouteMenu:Show()
	return true
end

function Dock:SetMessageRouteOverride(category)
	local record = self.analysisRecord
	if not record or type(addon.SetMessageRouteOverride) ~= "function" then
		return false, "unavailable"
	end
	local invoked, applied, reason = pcall(addon.SetMessageRouteOverride, addon, record, category)
	if not invoked or applied ~= true then
		if self.analysisFootnote then
			self.analysisFootnote:SetText("Could not save route: " .. tostring(reason or "failed"))
		end
		return false, reason or "failed"
	end
	return true
end

function Dock:MoveSelectedMessageRouteOverride()
	local category = self.analysisRouteDestination
	local label = self:GetMessageRouteOverrideDestinationLabel(category)
	if not category or not label then
		return false, "invalid-category"
	end
	-- Settings reclassifies and rebuilds synchronously. That rebuild closes the
	-- analysis controls, so retain the record before invoking it.
	local record = self.analysisRecord
	local applied, reason = self:SetMessageRouteOverride(category)
	if not applied then
		return false, reason
	end
	self:HideMessageRouteOverrideMenu()
	-- Re-open the same inspector so its route/evidence immediately reflects the
	-- saved correction even though the current view may no longer contain it.
	if record then self:ShowMessageAnalysis(record) end
	if self.analysisFootnote then
		self.analysisFootnote:SetText("Primary route moved to " .. label .. ". Checked source feeds remain; identical public text follows this route until UNDO.")
	end
	return true
end

function Dock:RemoveMessageRouteOverride()
	local record = self.analysisRecord
	if not record or type(addon.RemoveMessageRouteOverride) ~= "function" then
		return false, "unavailable"
	end
	local invoked, applied, reason = pcall(addon.RemoveMessageRouteOverride, addon, record)
	if not invoked or applied ~= true then
		if self.analysisFootnote then
			self.analysisFootnote:SetText("Could not remove route: " .. tostring(reason or "failed"))
		end
		return false, reason or "failed"
	end
	self:HideMessageRouteOverrideMenu()
	return true
end

function Dock:ApplyMessageBlock(record, mode)
	self:HideDisplayHoverHint()
	if not record or not self:CanUseMessageBlocks() then
		return false, "unavailable"
	end

	local invoked, applied, detail
	if type(addon.BlockRecord) == "function" then
		invoked, applied, detail = pcall(addon.BlockRecord, addon, record, mode)
	elseif addon.BlockControl and type(addon.BlockControl.BlockRecord) == "function" then
		invoked, applied, detail = pcall(addon.BlockControl.BlockRecord, addon.BlockControl, record, mode)
	else
		return false, "unavailable"
	end
	if not invoked or applied ~= true then
		if self.blockAction and self.blockAction.SetLabel then
			self.blockAction:SetLabel("FAILED")
		end
		return false, detail or "failed"
	end

	self:HideMessageBlockControls()
	-- BlockControl refreshes listeners too, but rebuild here is intentionally
	-- idempotent: the blocked line disappears immediately even if a future
	-- controller implementation is used without a dock-refresh callback.
	self:RebuildActiveView()
	return true, detail
end

function Dock:ShowMessageBlockChoices(record)
	self:HideDisplayHoverHint()
	if not self.blockChoices or not record then
		return
	end
	self.blockChoicesRecord = record
	self.blockChoices:ClearAllPoints()
	-- Keep the tiny scope picker inside the chat surface at the top edge too.
	if self.blockAction:GetTop() and self.content:GetTop()
		and self.blockAction:GetTop() + self.blockChoices:GetHeight() + 2 > self.content:GetTop() then
		self.blockChoices:SetPoint("TOPRIGHT", self.blockAction, "BOTTOMRIGHT", 0, -2)
	else
		self.blockChoices:SetPoint("BOTTOMRIGHT", self.blockAction, "TOPRIGHT", 0, 2)
	end
	self.blockChoices:Show()
	self:ScheduleMessageBlockActionRefresh()
end

function Dock:ResetActiveMetadataMetrics(records)
	local hasTimestamp, hasSource, hasSender = false, false, false
	local timestampWidth = 0
	for _, record in ipairs(records or {}) do
		local timestamp = tostring(record.timestamp or "")
		if timestamp ~= "" then
			hasTimestamp = true
			timestampWidth = math.max(timestampWidth, #timestamp)
		end
		if record.event ~= nil and tostring(Presentation:GetSource(record) or "") ~= "" then
			hasSource = true
		end
		if record.sender and record.sender ~= "" then
			hasSender = true
		end
	end
	self.activeHasTimestamp = hasTimestamp
	self.activeHasSource = hasSource
	self.activeHasSender = hasSender
	self.activeTimestampColumnWidth = hasTimestamp
		and math.max(RESPONSIVE_TIMESTAMP_CHARACTER_FALLBACK, timestampWidth) or 0
end

function Dock:RebuildActiveView(alignmentRecords, skipVisibleAlignmentRefresh)
	if not self.display or not addon.MessageEngine then
		return
	end
	local visibleOnly = self:IsAlignmentVisibleOnly()
		and (self:IsSourceColumnAlignmentEnabled() or self:IsSenderColumnAlignmentEnabled())
	-- When a live setting/resize rebuild begins, capture the old viewport before
	-- ClearDisplayRecordCache discards its logical spans. A view switch is never
	-- allowed to borrow the previous tab's visible alignment sample.
	if visibleOnly and type(alignmentRecords) ~= "table"
		and self.displayRecordViewId == self.activeView then
		alignmentRecords = self:GetVisibleAlignmentRecords()
	end
	self.activePresentationPixelWidth = self:GetRoundedDisplayPixelWidth()
	self:HideMessageBlockControls()
	self.display:Clear()
	self:ClearDisplayRecordCache()
	local messages = addon.MessageEngine:GetMessages(self.activeView)
	local settings = addon:GetSmartSettings()
	local startIndex = math.max(1, #messages - 399)
	local visibleRecords = {}
	for index = startIndex, #messages do
		local record = messages[index]
		if not self:IsLocallyIgnored(record, settings) and self:IsRecordAllowedInView(self.activeView, record, settings) then
			table.insert(visibleRecords, record)
		end
	end
	local metricRecords = visibleRecords
	if visibleOnly and type(alignmentRecords) == "table" and #alignmentRecords > 0 then
		metricRecords = alignmentRecords
	end
	self.activeAlignmentScopeSignature = visibleOnly
		and self:GetAlignmentScopeSignature(metricRecords) or nil
	self:ResetActiveSourceColumnMetrics(metricRecords)
	self.activeSenderColumnCandidateWidth = self:CalculateSenderColumnWidth(metricRecords)
	self.activeSenderColumnWidth = self.activeSenderColumnCandidateWidth
	self.activeSenderColumnLongest = self:CalculateSenderColumnLongest(metricRecords)
	self.activeSourceColumnAlignmentSpacing = self:GetColumnAlignmentSpacing()
	self.activeSenderColumnConfiguredSpacing = self:GetSenderColumnAlignmentSpacing()
	self.activeSenderColumnAlignmentSpacing = self.activeSenderColumnConfiguredSpacing
	self:ResetActiveMetadataMetrics(metricRecords)
	self:ResolveActiveResponsiveMetadata()
	self:RefreshHangingMessageWrapMode()
	self.rebuildingDisplay = true
	for _, record in ipairs(visibleRecords) do
		self:AppendDisplayRecord(record)
	end
	self.rebuildingDisplay = false
	self.displayRecordViewId = self.activeView
	self.display:ScrollToBottom()
	self:RefreshMessageBands()
	self:RefreshMessageScrollbar()
	self:ClearPendingMessages()
	self:UpdateEmptyState(#visibleRecords)
	if visibleOnly and not skipVisibleAlignmentRefresh then
		self:RefreshVisibleAlignment()
	end
end

function Dock:SelectView(viewId)
	local settings = addon:GetSmartSettings()
	local definition = viewById[viewId]
	if not definition then
		self:RefreshViewDefinitions()
		definition = viewById[viewId]
	end
	if not definition or definition.enabled == false or not settings.views[viewId] then
		return
	end
	if self.activeView ~= viewId then
		-- A route is a local choice, but it belongs to the tab where it was made.
		-- Save it before switching and restore only the destination tab's choice;
		-- unrelated tabs continue to use their contextual defaults.
		self:RememberComposerRouteOverride(self.activeView, self.composerRouteOverride)
		self.composerRouteOverride = self:GetRememberedComposerRouteOverride(viewId)
		self:HideComposerRouteMenu()
	end
	self.activeView = viewId
	settings.dock.activeView = viewId
	self.unread[viewId] = 0
	local definition = self:GetActiveDefinition()
	self.title:SetText(definition.label)
	self.subtitle:SetText(definition.description)
	self:RefreshRailState()
	self:UpdateComposerState()
	self:HidePlayerActions()
	self:ApplySmartChatTextAppearance(viewId)
	self:RebuildActiveView()
end

function Dock:OnMessage(record)
	if not self.active then
		return
	end
	local settings = addon:GetSmartSettings()
	if self:IsLocallyIgnored(record, settings) then
		return
	end
	if record.view == "conversations" and record.sender and record.direction == "incoming" then
		self.lastConversationTarget = record.sender
		if self.activeView == "conversations" and not self.composerRouteOverride then
			self:UpdateComposerState()
		end
	end

	if self:RecordBelongsToView(self.activeView, record, settings) then
		local wasAtBottom = self.display:AtBottom()
		local visibleOnly = self:IsAlignmentVisibleOnly()
			and (self:IsSourceColumnAlignmentEnabled() or self:IsSenderColumnAlignmentEnabled())
		local requiresColumnRebuild = false
		if visibleOnly then
			-- Append first using the current viewport metrics. An offscreen incoming
			-- record must not widen a scrolled-up reader's visible columns; an at-
			-- bottom record becomes visible and is recomputed from exact line spans.
			self:AppendDisplayRecord(record)
		else
			local sourceLabel = (self:IsResponsiveMetadataEnabled()
				or self:IsSourceColumnAlignmentEnabled()
				or self:IsSenderColumnAlignmentEnabled()) and Presentation:GetSource(record) or nil
			local sourceWidthChanged = false
			if sourceLabel then
				sourceWidthChanged = self:TrackActiveSourceColumnLabel(sourceLabel)
			end
			if record.timestamp and record.timestamp ~= "" then
				self.activeHasTimestamp = true
				self.activeTimestampColumnWidth = math.max(
					tonumber(self.activeTimestampColumnWidth) or RESPONSIVE_TIMESTAMP_CHARACTER_FALLBACK,
					#tostring(record.timestamp), RESPONSIVE_TIMESTAMP_CHARACTER_FALLBACK)
			end
			if record.event ~= nil and tostring(Presentation:GetSource(record) or "") ~= "" then
				self.activeHasSource = true
			end
			if record.sender and record.sender ~= "" then
				self.activeHasSender = true
				self.activeSenderColumnLongest = math.max(tonumber(self.activeSenderColumnLongest) or 0,
					presentationColumnCount(record.sender) + 2)
			end
			local responsiveLayoutChanged = self:ResolveActiveResponsiveMetadata()
			requiresColumnRebuild = sourceWidthChanged or responsiveLayoutChanged
			if requiresColumnRebuild then
				-- Initialize or grow the current tab's lane before a live message is
				-- appended. Rebuilding moves existing lines together, so the divider
				-- remains stable within the tab from the first visible line onward.
				self:RebuildActiveView()
			else
				self:AppendDisplayRecord(record)
			end
		end
		self.emptyState:Hide()
		if wasAtBottom or requiresColumnRebuild then
			self.display:ScrollToBottom()
			self:HandleDisplayViewportChanged()
		else
			self.pendingVisible = (self.pendingVisible or 0) + 1
			self:RefreshNewMessageIndicator()
		end
	end

	for viewId in pairs(self.railButtons or {}) do
		if viewId ~= self.activeView and settings.views[viewId] and self.railButtons[viewId]
			and self:RecordBelongsToView(viewId, record, settings) then
			self.unread[viewId] = (self.unread[viewId] or 0) + 1
		end
	end
	self:RefreshRailState()
end

local composerRouteTypes = {
	SAY = true,
	YELL = true,
	PARTY = true,
	RAID = true,
	BATTLEGROUND = true,
	GUILD = true,
	OFFICER = true,
	WHISPER = true,
	CHANNEL = true,
}

local function compactComposerRouteLabel(value, maximum)
	value = tostring(value or "")
	maximum = math.max(2, math.floor(tonumber(maximum) or 10))
	if #value <= maximum then
		return value
	end
	return string.sub(value, 1, maximum - 1) .. "."
end

local function getComposerChannelName(target)
	if GetChannelName and target ~= nil then
		local ok, first, second = pcall(GetChannelName, tonumber(target) or target)
		if ok then
			if type(second) == "string" and second ~= "" then
				return second
			elseif type(first) == "string" and first ~= "" then
				return first
			end
		end
	end
	return nil
end

function Dock:GetGroupComposerRoute()
	local inInstance, instanceType
	if IsInInstance then
		inInstance, instanceType = IsInInstance()
	end
	if inInstance and (instanceType == "pvp" or instanceType == "arena") then
		return "BATTLEGROUND"
	end
	if GetNumRaidMembers and (tonumber(GetNumRaidMembers()) or 0) > 0 then
		return "RAID"
	end
	if GetNumPartyMembers and (tonumber(GetNumPartyMembers()) or 0) > 0 then
		return "PARTY"
	end
	return nil
end

local function isValidComposerChannelTarget(target)
	target = tonumber(target)
	return target and target > 0 and math.floor(target) or nil
end

function Dock:GetCustomViewComposerChannelTarget(viewId)
	local engine = addon.MessageEngine
	if engine and type(engine.GetMessages) == "function" then
		local messages = engine:GetMessages(viewId)
		-- A custom view can contain several public channels. The most recently
		-- seen one is the most useful default, and only a real channel record is
		-- eligible: a custom text match on a system line must not manufacture a
		-- numbered-channel route.
		for index = #messages, 1, -1 do
			local record = messages[index]
			local channelNumber = record and record.event == "CHAT_MSG_CHANNEL"
				and isValidComposerChannelTarget(record.channelNumber) or nil
			if channelNumber then
				local settings = addon:GetSmartSettings()
				settings.channelTargets = settings.channelTargets or {}
				settings.channelTargets[viewId] = channelNumber
				return channelNumber
			end
		end
	end
	local settings = addon:GetSmartSettings()
	return settings.channelTargets and isValidComposerChannelTarget(settings.channelTargets[viewId]) or nil
end

function Dock:RememberComposerRouteOverride(viewId, override)
	if type(viewId) ~= "string" or viewId == "" then
		return
	end
	self.composerRouteOverrides = self.composerRouteOverrides or {}
	if type(override) ~= "table" or not composerRouteTypes[override.route] then
		self.composerRouteOverrides[viewId] = nil
		return
	end
	local route = override.route
	local target = override.target
	if route == "WHISPER" then
		if type(target) ~= "string" or target == "" then
			self.composerRouteOverrides[viewId] = nil
			return
		end
	elseif route == "CHANNEL" then
		target = isValidComposerChannelTarget(target)
		if not target then
			self.composerRouteOverrides[viewId] = nil
			return
		end
	else
		target = nil
	end
	self.composerRouteOverrides[viewId] = { route = route, target = target }
end

function Dock:GetRememberedComposerRouteOverride(viewId)
	local overrides = self.composerRouteOverrides
	local override = type(overrides) == "table" and overrides[viewId] or nil
	if type(override) == "table" and composerRouteTypes[override.route] then
		return override
	end
	return nil
end

function Dock:GetSuggestedComposerRoute()
	if self.activeView == "conversations" then
		return self.lastConversationTarget and "WHISPER" or nil, self.lastConversationTarget
	elseif self.activeView == "guild" then
		return "GUILD"
	elseif self.activeView == "group" then
		return self:GetGroupComposerRoute()
	elseif self.activeView == "pvp" then
		local groupRoute = self:GetGroupComposerRoute()
		if groupRoute == "BATTLEGROUND" then
			return groupRoute
		end
		local channelNumber = addon:GetSmartSettings().channelTargets[self.activeView]
		return channelNumber and "CHANNEL" or nil, channelNumber
	elseif self.activeView == "newcomers" or self.activeView == "groupFinder"
		or self.activeView == "guildInvites" or self.activeView == "trade" then
		local channelNumber = addon:GetSmartSettings().channelTargets[self.activeView]
		return channelNumber and "CHANNEL" or nil, channelNumber
	elseif self.activeView == "general" then
		return "SAY"
	end
	local definition = self:GetActiveDefinition()
	if definition and definition.custom then
		local channelNumber = self:GetCustomViewComposerChannelTarget(self.activeView)
		if channelNumber then
			return "CHANNEL", channelNumber
		end
		-- A custom text/source view is still an ordinary chat tab. With no
		-- observed numbered channel, make it writable immediately and leave the
		-- selector available for the player to choose a more precise destination.
		return "SAY"
	end
	return nil
end

-- The active view supplies a helpful default, but the bottom-left route
-- control is an explicit player choice. Keep that choice for the current
-- tab/session until the user changes tabs, just like a normal chat-type menu.
function Dock:GetComposerRoute()
	local override = self:GetRememberedComposerRouteOverride(self.activeView) or self.composerRouteOverride
	if type(override) == "table" and composerRouteTypes[override.route] then
		if override.route ~= "WHISPER" or type(override.target) == "string" and override.target ~= "" then
			if override.route ~= "CHANNEL" or (tonumber(override.target) or 0) > 0 then
				return override.route, override.target
			end
		end
	end
	return self:GetSuggestedComposerRoute()
end

function Dock:GetComposerRouteColor(route, target)
	route = type(route) == "string" and string.upper(route) or nil
	if not route then
		return nil
	end

	-- Numbered channel colors are distinct in Blizzard's chat palette. Prefer
	-- that exact entry, then fall back to CHANNEL's current client color. Do not
	-- hard-code a palette here: players and the client own these colors.
	local messageType = route
	if route == "CHANNEL" then
		local number = tonumber(target)
		if number and number > 0 then
			messageType = "CHANNEL" .. tostring(math.floor(number))
		end
	end
	if GetMessageTypeColor then
		local ok, r, g, b = pcall(GetMessageTypeColor, messageType)
		if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
			return r, g, b
		end
		if route == "CHANNEL" and messageType ~= "CHANNEL" then
			ok, r, g, b = pcall(GetMessageTypeColor, "CHANNEL")
			if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
				return r, g, b
			end
		end
	end

	local info = ChatTypeInfo and (ChatTypeInfo[messageType]
		or (route == "CHANNEL" and ChatTypeInfo.CHANNEL)
		or ChatTypeInfo[route])
	if info and type(info.r) == "number" and type(info.g) == "number" and type(info.b) == "number" then
		return info.r, info.g, info.b
	end
	return nil
end

function Dock:ApplyComposerRouteTextColor(button, route, target)
	local text = button and button.text
	if not text or not text.SetTextColor then
		return false
	end
	local r, g, b = self:GetComposerRouteColor(route, target)
	if not r then
		return false
	end
	text:SetTextColor(r, g, b, 1)
	return true
end

function Dock:SetComposerRouteLabel(label, enabled, route, target)
	if not self.composerRoute then
		return
	end
	if self.composerRoute.SetLabel then
		self.composerRoute:SetLabel(label)
	elseif self.composerRoute.SetText then
		self.composerRoute:SetText(label)
	end
	if self.composerRoute.SetEnabled then
		self.composerRoute:SetEnabled(enabled ~= false)
	end
	self.composerRoute.composerRouteKind = route
	self.composerRoute.composerRouteTarget = target
	self:ApplyComposerRouteTextColor(self.composerRoute, route, target)
	-- Anchors on the field follow the route's right edge, so shrinking/growing
	-- this one control immediately gives the released pixels back to typing.
	if self.composerRoute.SetWidth then
		self.composerRoute:SetWidth(self:GetComposerRouteWidth())
	end
end

function Dock:GetComposerRouteLabel(route, target)
	if route == "WHISPER" then
		return "REPLY"
	elseif route == "CHANNEL" then
		local channelName = getComposerChannelName(target) or tostring(target or "")
		-- The route lane itself grows with the dock.  Let a wider dock preserve a
		-- correspondingly wider joined-channel name instead of always truncating
		-- it to the old nine-character placeholder width.
		return "#" .. string.upper(compactComposerRouteLabel(channelName, 14))
	elseif route then
		return tostring(route)
	end
	return "SELECT"
end

function Dock:GetComposerRouteChoices()
	local choices = {}
	local function add(label, route, target)
		if not composerRouteTypes[route] then
			return
		end
		choices[#choices + 1] = {
			label = label,
			route = route,
			target = target,
		}
	end

	add("SAY", "SAY")
	add("YELL", "YELL")
	local groupRoute = self:GetGroupComposerRoute()
	if groupRoute then
		add(groupRoute, groupRoute)
	end
	if IsInGuild and IsInGuild() then
		add("GUILD", "GUILD")
	end
	if type(self.lastConversationTarget) == "string" and self.lastConversationTarget ~= "" then
		add("REPLY", "WHISPER", self.lastConversationTarget)
	end

	if GetChannelList then
		local ok, channels = pcall(function()
			return { GetChannelList() }
		end)
		if ok and type(channels) == "table" then
			for index = 1, #channels, 2 do
				local number = tonumber(channels[index])
				local name = tostring(channels[index + 1] or "")
				if number and number > 0 and name ~= "" then
					add("#" .. string.upper(compactComposerRouteLabel(name, 11)), "CHANNEL", number)
				end
			end
		end
	end
	return choices
end

function Dock:HideComposerRouteMenu()
	if self.composerRouteMenu then
		self.composerRouteMenu:Hide()
	end
end

function Dock:RefreshComposerRouteMenu()
	local menu = self.composerRouteMenu
	if not menu then
		return false
	end
	local choices = self:GetComposerRouteChoices()
	self.composerRouteChoices = choices
	local pageSize = COMPOSER_ROUTE_MENU_COLUMNS * COMPOSER_ROUTE_MENU_ROWS
	local pageCount = math.max(1, math.ceil(#choices / pageSize))
	self.composerRoutePage = math.max(1, math.min(tonumber(self.composerRoutePage) or 1, pageCount))
	local first = ((self.composerRoutePage - 1) * pageSize) + 1
	local selectedRoute, selectedTarget = self:GetComposerRoute()
	local visibleCount = math.min(pageSize, math.max(0, #choices - first + 1))
	for index, button in ipairs(self.composerRouteChoiceButtons or {}) do
		local choice = choices[first + index - 1]
		if choice then
			button.routeChoice = choice
			button:SetLabel(choice.label)
			local selected = choice.route == selectedRoute and tostring(choice.target or "") == tostring(selectedTarget or "")
			button:SetTheme(selected and "accentSoft" or "surfaceRaised", selected and "gold" or "borderMuted", selected and "goldBright" or "text")
			self:ApplyComposerRouteTextColor(button, choice.route, choice.target)
			button:Show()
		else
			button.routeChoice = nil
			button:Hide()
		end
	end
	local showPager = pageCount > 1
	if self.composerRouteMenuPageText then
		self.composerRouteMenuPageText:SetText(tostring(self.composerRoutePage) .. "/" .. tostring(pageCount))
		if showPager then self.composerRouteMenuPageText:Show() else self.composerRouteMenuPageText:Hide() end
	end
	for _, button in ipairs({ self.composerRouteMenuPrevious, self.composerRouteMenuNext }) do
		if button then
			if showPager then button:Show() else button:Hide() end
		end
	end
	if self.composerRouteMenuPrevious and self.composerRouteMenuPrevious.SetEnabled then
		self.composerRouteMenuPrevious:SetEnabled(self.composerRoutePage > 1)
	end
	if self.composerRouteMenuNext and self.composerRouteMenuNext.SetEnabled then
		self.composerRouteMenuNext:SetEnabled(self.composerRoutePage < pageCount)
	end
	local rows = math.max(1, math.ceil(visibleCount / COMPOSER_ROUTE_MENU_COLUMNS))
	local height = 4 + (rows * COMPOSER_ROUTE_MENU_BUTTON_HEIGHT) + ((rows - 1) * COMPOSER_ROUTE_MENU_GAP) + (showPager and 20 or 0)
	menu:SetHeight(height)
	return #choices > 0
end

function Dock:ShowComposerRouteMenu()
	if self:IsReadOnlyView() or not self.composerRouteMenu or not self.composer then
		return false
	end
	if not self:RefreshComposerRouteMenu() then
		return false
	end
	self.composerRouteMenu:ClearAllPoints()
	self.composerRouteMenu:SetPoint("BOTTOMLEFT", self.composer, "TOPLEFT", 0, -2)
	self.composerRouteMenu:Show()
	self:BindHeaderHover(self.composerRouteMenu)
	return true
end

function Dock:ToggleComposerRouteMenu()
	if self.composerRouteMenu and self.composerRouteMenu:IsShown() then
		self:HideComposerRouteMenu()
		return false
	end
	return self:ShowComposerRouteMenu()
end

function Dock:BuildComposerRouteMenu()
	if self.composerRouteMenu or not self.frame or not self.composer then
		return self.composerRouteMenu
	end
	local menu = Theme:CreatePanel(self.frame, "surfaceRaised", "gold")
	menu:SetWidth((COMPOSER_ROUTE_MENU_COLUMNS * COMPOSER_ROUTE_MENU_BUTTON_WIDTH)
		+ ((COMPOSER_ROUTE_MENU_COLUMNS - 1) * COMPOSER_ROUTE_MENU_GAP) + 8)
	menu:SetHeight(1)
	menu:SetFrameStrata(self.frame:GetFrameStrata())
	menu:SetFrameLevel(self.composer:GetFrameLevel() + 12)
	menu:EnableMouse(true)
	menu:Hide()
	self.composerRouteMenu = menu
	self.composerRouteChoiceButtons = {}
	for index = 1, COMPOSER_ROUTE_MENU_COLUMNS * COMPOSER_ROUTE_MENU_ROWS do
		local column = (index - 1) % COMPOSER_ROUTE_MENU_COLUMNS
		local row = math.floor((index - 1) / COMPOSER_ROUTE_MENU_COLUMNS)
		local button = Theme:CreateButton(menu, "", COMPOSER_ROUTE_MENU_BUTTON_WIDTH, COMPOSER_ROUTE_MENU_BUTTON_HEIGHT, false)
		button:SetPoint("TOPLEFT", menu, "TOPLEFT",
			4 + (column * (COMPOSER_ROUTE_MENU_BUTTON_WIDTH + COMPOSER_ROUTE_MENU_GAP)),
			-4 - (row * (COMPOSER_ROUTE_MENU_BUTTON_HEIGHT + COMPOSER_ROUTE_MENU_GAP)))
		button:SetScript("OnClick", function(self)
			local choice = self.routeChoice
			if choice and Dock:SetComposerRoute(choice.route, choice.target) then
				Dock:HideComposerRouteMenu()
			end
		end)
		button:HookScript("OnLeave", function(self)
			local choice = self.routeChoice
			if choice then
				Dock:ApplyComposerRouteTextColor(self, choice.route, choice.target)
			end
		end)
		self:BindHeaderHover(button)
		self.composerRouteChoiceButtons[index] = button
	end
	local pageText = Theme:CreateText(menu, "GameFontHighlightSmall", "textMuted")
	pageText:SetPoint("BOTTOM", menu, "BOTTOM", 0, 3)
	pageText:SetJustifyH("CENTER")
	self.composerRouteMenuPageText = pageText
	local previous = createTightButton(menu, "<", 17, false)
	previous:SetPoint("RIGHT", pageText, "LEFT", -4, 0)
	previous:SetScript("OnClick", function()
		Dock.composerRoutePage = math.max(1, (tonumber(Dock.composerRoutePage) or 1) - 1)
		Dock:RefreshComposerRouteMenu()
	end)
	self:BindHeaderHover(previous)
	self.composerRouteMenuPrevious = previous
	local nextButton = createTightButton(menu, ">", 17, false)
	nextButton:SetPoint("LEFT", pageText, "RIGHT", 4, 0)
	nextButton:SetScript("OnClick", function()
		Dock.composerRoutePage = (tonumber(Dock.composerRoutePage) or 1) + 1
		Dock:RefreshComposerRouteMenu()
	end)
	self:BindHeaderHover(nextButton)
	self.composerRouteMenuNext = nextButton
	self:BindHeaderHover(menu)
	return menu
end

function Dock:SetComposerRoute(route, target)
	route = type(route) == "string" and string.upper(route) or nil
	if self:IsReadOnlyView() or not route or not composerRouteTypes[route] then
		return false
	end
	if route == "WHISPER" then
		if type(target) ~= "string" or target == "" then
			return false
		end
	elseif route == "CHANNEL" then
		target = tonumber(target)
		if not target or target <= 0 then
			return false
		end
	else
		target = nil
	end
	self.composerRouteOverride = { route = route, target = target }
	self:RememberComposerRouteOverride(self.activeView, self.composerRouteOverride)
	if self.editBox then
		self:ApplyComposerRoute()
	end
	self:UpdateComposerState()
	self:RefreshComposerRouteMenu()
	return true
end

function Dock:CaptureComposerRouteFromEditBox()
	if not self.editBox or not self.editBox.GetAttribute then
		return false
	end
	local route = self.editBox:GetAttribute("chatType")
	route = type(route) == "string" and string.upper(route) or nil
	if not route or not composerRouteTypes[route] then
		return false
	end
	local target
	if route == "WHISPER" then
		target = self.editBox:GetAttribute("tellTarget")
		if type(target) ~= "string" or target == "" then
			return false
		end
	elseif route == "CHANNEL" then
		target = tonumber(self.editBox:GetAttribute("channelTarget"))
		if not target or target <= 0 then
			return false
		end
	end
	self.composerRouteOverride = { route = route, target = target }
	self:RememberComposerRouteOverride(self.activeView, self.composerRouteOverride)
	return true
end

function Dock:UpdateComposerState()
	if not self.composerRoute then
		return
	end
	local route, target = self:GetComposerRoute()
	if self:IsReadOnlyView() then
		self:SetComposerRouteLabel("READ ONLY", false, nil, nil)
		self.composerPlaceholder:SetText("This view is a filter lens. Click a player name to start a whisper.")
	elseif route == "WHISPER" then
		self:SetComposerRouteLabel(self:GetComposerRouteLabel(route, target), true, route, target)
		self.composerPlaceholder:SetText("Click here to reply to " .. target)
	elseif route == "CHANNEL" then
		self:SetComposerRouteLabel(self:GetComposerRouteLabel(route, target), true, route, target)
		self.composerPlaceholder:SetText("Click here to write to " .. (getComposerChannelName(target) or "this channel"))
	elseif route then
		self:SetComposerRouteLabel(self:GetComposerRouteLabel(route, target), true, route, target)
		self.composerPlaceholder:SetText("Click here or press Enter to write")
	else
		self:SetComposerRouteLabel("SELECT", true, nil, nil)
		self.composerPlaceholder:SetText("Choose a chat type or click a player name to reply")
	end
	if self.editBox and self.editBox:IsShown() then
		self.composerPlaceholder:Hide()
	else
		self.composerPlaceholder:Show()
	end
end

-- The composer has two independent presentation modes.  `showComposer` is
-- the original always-on chrome preference; `composerAutoHide` is the newer,
-- explicit compact mode.  Keep the legacy false value as an alias so an
-- existing profile that intentionally hid the composer gets the same useful
-- keyboard-reveal behavior instead of suddenly gaining permanent chrome.
function Dock:IsComposerAutoHideEnabled()
	local settings = addon:GetSmartSettings()
	local dockSettings = settings and settings.dock or nil
	if not dockSettings then
		return false
	end
	if dockSettings.composerAutoHide ~= nil then
		return dockSettings.composerAutoHide == true
	end
	return dockSettings.showComposer == false
end

function Dock:IsComposerEditBoxBorderEnabled()
	if addon.GetEditBoxBorderSetting then
		return addon:GetEditBoxBorderSetting() == true
	end
	local settings = addon:GetSmartSettings()
	return settings and settings.dock and settings.dock.editBoxBorder == true or false
end

function Dock:RefreshComposerEditBoxBorder()
	local border = self.composerEditBoxBorder
	if not border then
		return false
	end
	if self:IsComposerEditBoxBorderEnabled() then
		border:Show()
	else
		border:Hide()
	end
	return true
end

function Dock:GetComposerRouteWidth()
	local route = self.composerRoute
	local label = route and route.text
	local measured = label and label.GetStringWidth and tonumber(label:GetStringWidth()) or nil
	if not measured or measured < 1 then
		local labelText = label and label.GetText and label:GetText() or ""
		measured = #tostring(labelText or "") * 7
	end
	return math.max(COMPOSER_ROUTE_MIN_WIDTH,
		math.min(COMPOSER_ROUTE_MAX_WIDTH, math.ceil(measured) + COMPOSER_ROUTE_TEXT_PADDING))
end

function Dock:RefreshComposerLayout()
	local composer = self.composer
	local route = self.composerRoute
	if not composer or not route then
		return
	end
	local routeWidth = self:GetComposerRouteWidth()
	route:SetWidth(routeWidth)

	-- The old accent texture acted as a visual divider between the destination
	-- and typing text. The composer is now a continuous surface, so leave it
	-- hidden rather than wasting either pixels or visual weight on a separator.
	if self.composerRouteAccent then
		self.composerRouteAccent:Hide()
	end

	local send = self.composerSend
	local placeholder = self.composerPlaceholder
	if placeholder then
		placeholder:ClearAllPoints()
		placeholder:SetPoint("LEFT", route, "RIGHT", 3, 0)
		if send then
			placeholder:SetPoint("RIGHT", send, "LEFT", -COMPOSER_ACTION_GAP, 0)
		else
			placeholder:SetPoint("RIGHT", composer, "RIGHT", -22, 0)
		end
	end

	local border = self.composerEditBoxBorder
	if border then
		border:ClearAllPoints()
		border:SetPoint("TOPLEFT", route, "TOPRIGHT", 1, 0)
		if send then
			border:SetPoint("BOTTOMRIGHT", send, "LEFT", -1, 0)
		else
			border:SetPoint("BOTTOMRIGHT", composer, "BOTTOMRIGHT", -22, 0)
		end
	end

	local editBox = self.editBox
	if editBox then
		editBox:ClearAllPoints()
		editBox:SetPoint("LEFT", route, "RIGHT", 3, 0)
		if send then
			editBox:SetPoint("RIGHT", send, "LEFT", -COMPOSER_ACTION_GAP, 0)
		else
			editBox:SetPoint("RIGHT", composer, "RIGHT", -22, 0)
		end
		editBox:SetHeight(20)
	end
	-- A wider route lane can preserve more of a channel name. Refresh its label
	-- after every real layout/resize so the visible route tracks that new room.
	if self.composerPlaceholder then
		self:UpdateComposerState()
	end
end

-- ChatFrame1EditBoxHeader is Blizzard's native route label.  SmartDock owns
-- that job with its own responsive route control, so the shared edit box must
-- contribute only text, caret, selection, and keyboard behavior.
function Dock:HideNativeComposerChrome()
	local editBox = self.editBox
	if not editBox then
		return
	end
	for index = 1, #(self.editBoxTextures or {}) do
		local data = self.editBoxTextures[index]
		if data.texture then
			data.texture:Hide()
		end
	end
	local header = self.editBoxHeader
	if header then
		header:SetAlpha(0)
		header:Hide()
	end
	if editBox.SetTextInsets then
		editBox:SetTextInsets(0, 0, 0, 0)
	end
end

-- `OnShow` normally fires after Blizzard has made the shared edit box visible,
-- but ChatEdit_ActivateChat can reach us through a secure post-hook on clients
-- where an ancestor was previously hidden.  Track that transient explicitly so
-- layout is correct on both paths rather than relying solely on IsShown().
function Dock:IsComposerInputActive()
	if self.composerInputActive == true then
		return true
	end
	return self.editBox and self.editBox.IsShown and self.editBox:IsShown() and true or false
end

function Dock:ShouldReserveComposerSpace()
	return not self:IsComposerAutoHideEnabled() or self:IsComposerInputActive()
end

function Dock:RefreshComposerVisibility()
	if not self.composer then
		return
	end
	if self:IsCollapsed() then
		self.composer:Hide()
		return
	end

	-- Keep the shared Blizzard edit box under a shown parent even when compact
	-- auto-hide is enabled. Enter, slash, reply, and ChatFrame_OpenChat can then
	-- reveal it temporarily instead of opening an invisible edit box beneath a
	-- hidden parent.  ApplyLayout uses this same predicate to give messages the
	-- reclaimed height at rest and reserve the composer lane while typing.
	local reveal = self:ShouldReserveComposerSpace()
	self.composer:Show()
	self.composer:SetAlpha(reveal and 1 or 0)
	if self.composer.EnableMouse then
		self.composer:EnableMouse(reveal and true or false)
	end
end

function Dock:BeginComposerInput()
	if not self.active or not self.frame then
		return
	end
	self.composerInputActive = true
	local wasVisible = self:IsVisible()
	local wasCollapsed = self:IsCollapsed()
	local reappliedLayout = false
	if (not wasVisible or wasCollapsed) and not self.editReveal then
		self.editReveal = {
			wasVisible = wasVisible,
			wasCollapsed = wasCollapsed,
			revision = self.stateRevision or 0,
		}
		-- This is runtime-only. Keyboard chat must remain usable while the dock
		-- is hidden or collapsed, without rewriting the user's saved layout.
		self.visibleState = true
		self.collapsedState = false
		self:SyncDockHoverState()
		self:ApplyLayout()
		self.frame:Show()
		reappliedLayout = true
	end
	-- In auto-hide mode the message surface was using the composer lane.  As
	-- soon as typing begins, reserve that lane again so the real edit box never
	-- overlays the newest chat lines.  The inverse happens in EndComposerInput.
	if not reappliedLayout and self.built
		and self.composerSpaceReserved ~= self:ShouldReserveComposerSpace() then
		self:ApplyLayout()
	else
		self:RefreshComposerVisibility()
	end
end

function Dock:EndComposerInput()
	local pending = self.editReveal
	self.editReveal = nil
	self.composerInputActive = false
	if pending and not self.alertActive and (self.stateRevision or 0) == pending.revision then
		self.visibleState = pending.wasVisible
		self.collapsedState = pending.wasCollapsed
		if not pending.wasVisible or pending.wasCollapsed then
			self.railClickRevealed = false
			self.railMouseoverRevealed = false
		end
		self:ApplyLayout()
		if self.active and self.visibleState then
			self.frame:Show()
		else
			self.frame:Hide()
		end
	elseif self.built and self.composerSpaceReserved ~= self:ShouldReserveComposerSpace() then
		-- Reclaim the composer lane immediately after the actual editor closes.
		-- Keeping this in the normal close path matters even while the dock stays
		-- open; merely fading the parent would leave a blank strip at its bottom.
		self:ApplyLayout()
	else
		self:RefreshComposerVisibility()
	end
end

function Dock:ApplyComposerRoute()
	local route, target = self:GetComposerRoute()
	if not route or not self.editBox then
		return false
	end
	self.editBox:SetAttribute("chatType", route)
	-- ChatFrame1EditBox is shared across every route. Clear a prior whisper or
	-- channel target before applying the new one so selecting SAY/GROUP cannot
	-- retain an invisible stale target from the previous choice.
	self.editBox:SetAttribute("tellTarget", nil)
	self.editBox:SetAttribute("channelTarget", nil)
	if route == "WHISPER" then
		self.editBox:SetAttribute("tellTarget", target)
		if ChatEdit_SetLastToldTarget then
			ChatEdit_SetLastToldTarget(target)
		end
	elseif route == "CHANNEL" then
		self.editBox:SetAttribute("channelTarget", target)
	end
	if ChatEdit_UpdateHeader then
		ChatEdit_UpdateHeader(self.editBox)
	end
	self:HideNativeComposerChrome()
	return true
end

function Dock:ActivateComposer()
	if self:IsReadOnlyView() then
		return
	end
	self.routingComposer = true
	if not self:ApplyComposerRoute() then
		self.routingComposer = false
		return
	end
	if ChatEdit_ActivateChat then
		ChatEdit_ActivateChat(self.editBox)
	else
		self.editBox:Show()
		self.editBox:SetFocus()
	end
	self.routingComposer = false
end

function Dock:AttachEditBox()
	if self.editBoxSnapshot then
		return true
	end
	local editBox = _G.ChatFrame1EditBox
	if not editBox then
		return false
	end

	self.editBoxSnapshot = {
		parent = editBox:GetParent(),
		points = savePoints(editBox),
		width = editBox:GetWidth(),
		height = editBox:GetHeight(),
		strata = editBox:GetFrameStrata(),
		level = editBox:GetFrameLevel(),
		alpha = editBox:GetAlpha(),
		shown = editBox:IsShown(),
		mouseEnabled = editBox.IsMouseEnabled and editBox:IsMouseEnabled(),
	}
	if editBox.GetTextInsets then
		local left, right, top, bottom = editBox:GetTextInsets()
		self.editBoxSnapshot.textInsets = { left = left, right = right, top = top, bottom = bottom }
	end
	if editBox.GetFont then
		local fontPath, fontSize, fontFlags = editBox:GetFont()
		self.editBoxSnapshot.font = { path = fontPath, size = fontSize, flags = fontFlags }
	end
	self.editBox = editBox
	-- Smart Dock can be enabled (or its profile reapplied) while Blizzard's
	-- shared editor is already open. That existing visibility does not fire our
	-- OnShow hook, so seed the transient state before the first ApplyLayout.
	-- Otherwise compact mode could reclaim the composer lane beneath an editor
	-- that is actively accepting text until the next hide/show cycle.
	self.composerInputActive = editBox:IsShown() and true or false
	self:BindHeaderHover(editBox)
	editBox:SetParent(self.composer)
	editBox:SetFrameStrata(self.frame:GetFrameStrata())
	editBox:SetFrameLevel(self.composer:GetFrameLevel() + 4)
	editBox:SetAlpha(1)
	editBox:EnableMouse(true)

	local editName = editBox:GetName()
	self.editBoxTextures = {}
	local suffixes = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }
	for index = 1, #suffixes do
		local texture = _G[editName .. suffixes[index]]
		if texture then
			table.insert(self.editBoxTextures, { texture = texture, shown = texture:IsShown() })
			texture:Hide()
		end
	end
	local nativeHeader = editName and _G[editName .. "Header"]
	if nativeHeader then
		self.editBoxHeader = nativeHeader
		self.editBoxHeaderSnapshot = {
			shown = nativeHeader:IsShown(),
			alpha = nativeHeader:GetAlpha(),
		}
	end
	self:HideNativeComposerChrome()
	self:RefreshComposerLayout()

	if not self.editBoxHooked then
		editBox:HookScript("OnShow", function()
			if Dock.active then
				Dock:HideNativeComposerChrome()
				Dock:BeginComposerInput()
				-- Native slash commands, reply shortcuts, and ChatFrame_OpenChat set
				-- their own route before showing this shared edit box.  Only a click
				-- initiated by our composer is allowed to replace that route.
				if Dock.routingComposer then
					Dock:ApplyComposerRoute()
				else
					Dock:CaptureComposerRouteFromEditBox()
				end
				Dock:UpdateComposerState()
				Dock:RefreshComposerVisibility()
				Dock.composerPlaceholder:Hide()
			end
		end)
		editBox:HookScript("OnHide", function()
			if Dock.active then
				Dock:HideComposerRouteMenu()
				Dock:UpdateComposerState()
				Dock:EndComposerInput()
			end
		end)
		self.editBoxHooked = true
	end
	if not self.chatActivationHooked and hooksecurefunc then
		-- When an ancestor is hidden, showing its child may not emit OnShow.
		-- Secure post-hooks cover Enter, slash, and reply activation paths and
		-- reveal the runtime dock only after Blizzard has established chat state.
		local hooked = pcall(hooksecurefunc, "ChatEdit_ActivateChat", function(activeEditBox)
			if Dock.active and (not activeEditBox or activeEditBox == Dock.editBox) then
				Dock:BeginComposerInput()
				if not Dock.routingComposer then
					Dock:CaptureComposerRouteFromEditBox()
					Dock:UpdateComposerState()
				end
			end
		end)
		if ChatFrame_OpenChat then
			pcall(hooksecurefunc, "ChatFrame_OpenChat", function()
				if Dock.active then
					Dock:BeginComposerInput()
					if not Dock.routingComposer then
						Dock:CaptureComposerRouteFromEditBox()
						Dock:UpdateComposerState()
					end
				end
			end)
		end
		self.chatActivationHooked = hooked and true or false
	end
	if not self.chatHeaderHooked and hooksecurefunc and ChatEdit_UpdateHeader then
		local hooked = pcall(hooksecurefunc, "ChatEdit_UpdateHeader", function(activeEditBox)
			if Dock.active and activeEditBox == Dock.editBox then
				Dock:HideNativeComposerChrome()
			end
		end)
		self.chatHeaderHooked = hooked and true or false
	end
	return true
end

function Dock:RestoreEditBox()
	if not self.editBoxSnapshot or not self.editBox then
		return
	end
	if ChatEdit_DeactivateChat then
		ChatEdit_DeactivateChat(self.editBox)
	end
	self.editBox:SetParent(self.editBoxSnapshot.parent)
	restorePoints(self.editBox, self.editBoxSnapshot.points)
	self.editBox:SetWidth(self.editBoxSnapshot.width)
	self.editBox:SetHeight(self.editBoxSnapshot.height)
	self.editBox:SetFrameStrata(self.editBoxSnapshot.strata)
	self.editBox:SetFrameLevel(self.editBoxSnapshot.level)
	if self.editBoxSnapshot.font and self.editBox.SetFont then
		local font = self.editBoxSnapshot.font
		self.editBox:SetFont(font.path, font.size, font.flags)
	end
	if self.editBoxSnapshot.textInsets and self.editBox.SetTextInsets then
		local insets = self.editBoxSnapshot.textInsets
		self.editBox:SetTextInsets(insets.left or 0, insets.right or 0, insets.top or 0, insets.bottom or 0)
	end
	for index = 1, #(self.editBoxTextures or {}) do
		local data = self.editBoxTextures[index]
		if data.shown then
			data.texture:Show()
		else
			data.texture:Hide()
		end
	end
	if self.editBoxSnapshot.shown then
		self.editBox:Show()
	else
		self.editBox:Hide()
	end
	self.editBox:SetAlpha(self.editBoxSnapshot.alpha)
	if self.editBoxSnapshot.mouseEnabled ~= nil then
		self.editBox:EnableMouse(self.editBoxSnapshot.mouseEnabled)
	end
	if self.editBoxHeader and self.editBoxHeaderSnapshot then
		self.editBoxHeader:SetAlpha(self.editBoxHeaderSnapshot.alpha)
		if self.editBoxHeaderSnapshot.shown then
			self.editBoxHeader:Show()
		else
			self.editBoxHeader:Hide()
		end
	end
	self.editBoxSnapshot = nil
	self.editBoxTextures = nil
	self.editBoxHeader = nil
	self.editBoxHeaderSnapshot = nil
end

function Dock:SuppressNativeFrame(frame)
	if not frame then
		return
	end
	frame:SetAlpha(0)
	if frame.EnableMouse then
		frame:EnableMouse(false)
	end
	self.suppressingNativeFrame = frame
	frame:Hide()
	if self.suppressingNativeFrame == frame then
		self.suppressingNativeFrame = nil
	end
end

function Dock:TrackAndSuppressNativeFrame(frame)
	if not frame or not self.nativeSnapshot then
		return
	end
	local data = self.nativeSnapshotByFrame[frame]
	if not data then
		data = {
			frame = frame,
			shown = frame:IsShown(),
			alpha = frame:GetAlpha(),
			mouseEnabled = frame.IsMouseEnabled and frame:IsMouseEnabled(),
		}
		self.nativeSnapshotByFrame[frame] = data
		table.insert(self.nativeSnapshot, data)
		self.nativeFrameHooks = self.nativeFrameHooks or {}
		if not self.nativeFrameHooks[frame] and frame.HookScript then
			frame:HookScript("OnShow", function(shownFrame)
				if Dock.active and Dock.nativeSnapshot then
					local tracked = Dock.nativeSnapshotByFrame and Dock.nativeSnapshotByFrame[shownFrame]
					if tracked then
						tracked.shown = true
					end
					Dock:SuppressNativeFrame(shownFrame)
				end
			end)
			frame:HookScript("OnHide", function(hiddenFrame)
				if Dock.active and Dock.nativeSnapshot and Dock.suppressingNativeFrame ~= hiddenFrame then
					local tracked = Dock.nativeSnapshotByFrame and Dock.nativeSnapshotByFrame[hiddenFrame]
					if tracked then
						tracked.shown = false
					end
				end
			end)
			self.nativeFrameHooks[frame] = true
		end
	end
	self:SuppressNativeFrame(frame)
end

function Dock:HideNativeChat()
	if self.nativeSnapshot or not addon:GetSmartSettings().dock.hideNativeChat then
		return
	end
	self.nativeSnapshot = {}
	self.nativeSnapshotByFrame = {}
	self.nativeFrameHooks = self.nativeFrameHooks or {}

	for index = 1, (tonumber(NUM_CHAT_WINDOWS) or 0) do
		self:TrackAndSuppressNativeFrame(_G["ChatFrame" .. index])
		self:TrackAndSuppressNativeFrame(_G["ChatFrame" .. index .. "Tab"])
		self:TrackAndSuppressNativeFrame(_G["ChatFrame" .. index .. "ButtonFrame"])
		self:TrackAndSuppressNativeFrame(_G["ChatFrame" .. index .. "ResizeButton"])
	end
	self:TrackAndSuppressNativeFrame(_G.ChatFrameMenuButton)
	self:TrackAndSuppressNativeFrame(_G.ChatFrameChannelButton)
	self:TrackAndSuppressNativeFrame(_G.ChatFrameToggleVoiceDeafenButton)
	self:TrackAndSuppressNativeFrame(_G.ChatFrameToggleVoiceMuteButton)
end

-- The Social/Friends micro button is not part of the native chat frame, so it
-- must not be coupled to hideNativeChat or the legacy Disable Buttons module.
-- Keep its current shown state and only enforce the player's explicit Chat
-- Window preference while Smart Dock is active.
function Dock:ApplySocialButtonVisibility()
	if not self.active then
		return false
	end
	local dockSettings = addon:GetSmartSettings().dock or {}
	if dockSettings.hideSocialButton ~= true then
		self:RestoreSocialButtonVisibility()
		return true
	end
	self.socialButtonStates = self.socialButtonStates or {}
	self.socialButtonHooks = self.socialButtonHooks or {}
	local seen = {}
	for _, button in ipairs({ _G.FriendsMicroButton, _G.SocialsMicroButton }) do
		if button and not seen[button] then
			seen[button] = true
			if not self.socialButtonStates[button] then
				self.socialButtonStates[button] = {
					shown = button.IsShown and button:IsShown() or false,
				}
			end
			if not self.socialButtonHooks[button] and button.HookScript then
				button:HookScript("OnShow", function(frame)
					local settings = addon:GetSmartSettings().dock or {}
					if Dock.active and settings.hideSocialButton == true and frame.Hide then
						frame:Hide()
					end
				end)
				self.socialButtonHooks[button] = true
			end
			if button.Hide then
				button:Hide()
			end
		end
	end
	return true
end

function Dock:RestoreSocialButtonVisibility()
	local states = self.socialButtonStates
	if not states then
		return
	end
	for button, state in pairs(states) do
		if button then
			if state.shown and button.Show then
				button:Show()
			elseif button.Hide then
				button:Hide()
			end
		end
	end
	self.socialButtonStates = nil
end

function Dock:SuppressTemporaryChatFrame(frame)
	if not self.active or not frame or not addon:GetSmartSettings().dock.hideNativeChat then
		return
	end
	if not self.nativeSnapshot then
		self:HideNativeChat()
	end
	self:TrackAndSuppressNativeFrame(frame)
	local name = frame.GetName and frame:GetName()
	if name and name ~= "" then
		self:TrackAndSuppressNativeFrame(_G[name .. "Tab"])
		self:TrackAndSuppressNativeFrame(_G[name .. "ButtonFrame"])
		self:TrackAndSuppressNativeFrame(_G[name .. "ResizeButton"])
	end
end

function Dock:MarkNativeChatFrameClosed(frame)
	if not frame or not self.nativeSnapshotByFrame then
		return
	end
	local function markHidden(target)
		local data = target and self.nativeSnapshotByFrame[target]
		if data then
			data.shown = false
		end
	end
	markHidden(frame)
	local name = frame.GetName and frame:GetName()
	if name and name ~= "" then
		markHidden(_G[name .. "Tab"])
		markHidden(_G[name .. "ButtonFrame"])
		markHidden(_G[name .. "ResizeButton"])
	end
end

function Dock:RestoreNativeChat()
	if not self.nativeSnapshot then
		return
	end
	-- Clear suppression state before showing anything. The permanent OnShow
	-- hooks consult nativeSnapshot; leaving it set during this loop would make
	-- an active Dock immediately hide every frame we are trying to restore.
	local snapshot = self.nativeSnapshot
	self.nativeSnapshot = nil
	self.nativeSnapshotByFrame = nil
	for index = 1, #snapshot do
		local data = snapshot[index]
		data.frame:SetAlpha(data.alpha)
		if data.mouseEnabled ~= nil and data.frame.EnableMouse then
			data.frame:EnableMouse(data.mouseEnabled)
		end
		if data.shown then
			data.frame:Show()
		else
			data.frame:Hide()
		end
	end
end

function Dock:IsVisible()
	if self.visibleState == nil then
		local settings = addon:GetSmartSettings()
		return not settings.dock or settings.dock.visible ~= false
	end
	return self.visibleState ~= false
end

function Dock:IsCollapsed()
	if self.collapsedState == nil then
		local settings = addon:GetSmartSettings()
		return settings.dock and settings.dock.collapsed == true
	end
	return self.collapsedState == true
end

function Dock:MarkManualLayoutChange(persist)
	self.stateRevision = (self.stateRevision or 0) + 1
	if self.alertPending or self.editReveal or self.playerActionAlertRestore then
		if self.alertPending then
			self.alertPending.restoreCancelled = true
		end
		if self.editReveal then
			self.editReveal.restoreCancelled = true
		end
		if self.playerActionAlertRestore then
			self.playerActionAlertRestore.restoreCancelled = true
		end
		-- A manual choice adopts the temporarily revealed runtime surface. This
		-- prevents saved and visible collapse state from drifting apart after an
		-- alert or keyboard-chat reveal deliberately declines to restore its old
		-- snapshot.
		if persist ~= false then
			local dockSettings = addon:GetSmartSettings().dock
			dockSettings.visible = self.visibleState ~= false
			dockSettings.collapsed = self.collapsedState == true
		end
	end
end

function Dock:SetVisible(visible, persist)
	visible = visible and true or false
	self:MarkManualLayoutChange(persist)
	if not visible and self.editBox and self.editBox:IsShown() and ChatEdit_DeactivateChat then
		ChatEdit_DeactivateChat(self.editBox)
	end
	self.visibleState = visible
	local settings = addon:GetSmartSettings()
	if persist ~= false and settings.dock then
		settings.dock.visible = visible
	end
	if not visible and self.railClickRevealed then
		self.railClickRevealed = false
		self.railMouseoverRevealed = false
	end
	if not visible then
		self.railMouseoverRevealed = false
		self:HidePlayerActions()
	end
	if self.frame and self.built then
		-- Reapply before a hidden dock returns so an Always header is present on
		-- its first visible frame, not only after the cursor moves over it.
		self:ApplyLayout()
	end
	if self.frame then
		if self.active and visible then
			self.frame:Show()
		else
			self.frame:Hide()
		end
	end
	if not visible and self.alertPending then
		self:DismissAlert(false)
	end
	return visible
end

function Dock:ToggleVisibility()
	return self:SetVisible(not self:IsVisible(), true)
end

function Dock:SetCollapsed(collapsed, persist)
	collapsed = collapsed and true or false
	self:MarkManualLayoutChange(persist)
	if collapsed and self.editBox and self.editBox:IsShown() and ChatEdit_DeactivateChat then
		ChatEdit_DeactivateChat(self.editBox)
	end
	self.collapsedState = collapsed
	if collapsed then
		self.railClickRevealed = false
		self.railMouseoverRevealed = false
	else
		-- Expanding from the compact header commonly happens while the pointer is
		-- still resting on that header. Re-sync now so mouseover rails do not
		-- require an artificial leave/re-enter before they appear.
		self:SyncDockHoverState()
	end
	local settings = addon:GetSmartSettings()
	if persist ~= false and settings.dock then
		settings.dock.collapsed = collapsed
	end
	self:ApplyLayout()
	if collapsed and self.alertPending then
		self:DismissAlert(false)
	end
	return collapsed
end

function Dock:ToggleCollapsed()
	return self:SetCollapsed(not self:IsCollapsed(), true)
end

function Dock:ResolveRailVisibility(resetTransient)
	local configuredMode = getConfiguredRailVisibility()
	if resetTransient or not self.railVisibilityMode or self.railConfiguredVisibility ~= configuredMode then
		self.railConfiguredVisibility = configuredMode
		self.railVisibilityMode = configuredMode
		self.railClickRevealed = false
		-- Mouseover is a runtime presentation state, never a saved layout
		-- change. Rebuild it from the current dock hover instead of carrying a
		-- stale reveal between profiles, alerts, or activation cycles.
		self.railMouseoverRevealed = configuredMode == "mouseover" and self.headerHover == true or false
	end
	return self.railVisibilityMode
end

function Dock:SetRailVisibility(mode, persist)
	mode = normalizeRailVisibility(mode)
	local configuredMode = getConfiguredRailVisibility()
	if persist ~= false then
		local settings = addon:GetSmartSettings()
		settings.dock.railVisibility = mode
		configuredMode = mode
	end
	self.railConfiguredVisibility = configuredMode
	self.railVisibilityMode = mode
	self.railClickRevealed = false
	self.railMouseoverRevealed = mode == "mouseover" and self.headerHover == true or false
	if self.frame and self.built then
		self:ApplyLayout()
	end
	return mode
end

function Dock:SetRailReveal(revealed)
	if self:ResolveRailVisibility(false) ~= "click" then
		return false
	end
	revealed = revealed and true or false
	if self.railClickRevealed == revealed then
		return revealed
	end
	self.railClickRevealed = revealed
	if self.frame and self.built and not self:IsCollapsed() then
		self:ApplyLayout()
	end
	return revealed
end

function Dock:ToggleRailReveal()
	if self:ResolveRailVisibility(false) ~= "click" or self:IsCollapsed() then
		return false
	end
	return self:SetRailReveal(not self.railClickRevealed)
end

function Dock:RefreshRailVisibility(resetTransient)
	local mode = self:ResolveRailVisibility(resetTransient == true)
	if self.frame and self.built then
		self:ApplyLayout()
	end
	return mode
end

function Dock:GetHeaderVisibility()
	return getConfiguredHeaderVisibility()
end

function Dock:SetHeaderVisibility(mode, persist)
	mode = normalizeHeaderVisibility(mode)
	if persist ~= false then
		local settings = addon:GetSmartSettings()
		settings.dock = settings.dock or {}
		settings.dock.headerVisibility = mode
	else
		-- The config page writes its value before asking the live dock to
		-- refresh. Canonicalize that value here too so runtime and persistence
		-- cannot disagree.
		getConfiguredHeaderVisibility()
	end
	if self.frame and self.built then
		self:ApplyLayout()
	end
	return mode
end

function Dock:RefreshHeaderVisibility()
	local mode = getConfiguredHeaderVisibility()
	if self.frame and self.built then
		self:ApplyLayout()
	end
	return mode
end

-- The dock keeps its outer frame and border visible at all times, but its
-- title/control chrome should not permanently spend vertical space.  Mouse
-- enter/leave events from a parent can fire while moving between children, so
-- the actual hide is deferred a fraction of a second and confirmed against the
-- current mouse focus before the layout changes.
function Dock:IsMouseOverDock()
	local frame = self.frame
	if not frame or (frame.IsShown and not frame:IsShown()) then
		return false
	end

	local focus = GetMouseFocus and GetMouseFocus()
	local depth = 0
	while focus and depth < 32 do
		if focus == frame then
			return true
		end
		if not focus.GetParent then
			break
		end
		local parent = focus:GetParent()
		if not parent or parent == focus then
			break
		end
		focus = parent
		depth = depth + 1
	end

	-- IsMouseOver covers frames which are visually inside the dock but do not
	-- take mouse focus themselves (text, scroll children, and edit-box chrome).
	return frame.IsMouseOver and frame:IsMouseOver() or false
end

function Dock:CancelHeaderHoverRefresh()
	self.headerHoverDelay = nil
	if self.headerHoverDriver then
		self.headerHoverDriver:Hide()
	end
end

-- Some runtime-only flows (alerts and keyboard chat) expand the dock without
-- producing a new frame OnEnter event. Sample the real focus then so a
-- mouseover rail stays truthful even under a stationary cursor. This never
-- writes a SavedVariable; it only refreshes transient presentation state.
function Dock:SyncDockHoverState()
	local hovered = self:IsMouseOverDock()
	self.headerHover = hovered
	if self:ResolveRailVisibility(false) == "mouseover" then
		self.railMouseoverRevealed = hovered
	else
		self.railMouseoverRevealed = false
	end
	return hovered
end

function Dock:SetHeaderHover(hovered)
	hovered = hovered and true or false
	local headerChanged = self.headerHover ~= hovered
	self.headerHover = hovered

	-- The Chat Tabs Rail's mouseover mode shares the same verified dock-surface
	-- hover signal as the header. This avoids brittle per-child enter/leave
	-- bookkeeping and, importantly, keeps the saved rail preference unchanged.
	local railChanged = false
	if self:ResolveRailVisibility(false) == "mouseover" then
		railChanged = self.railMouseoverRevealed ~= hovered
		self.railMouseoverRevealed = hovered
	elseif self.railMouseoverRevealed then
		railChanged = true
		self.railMouseoverRevealed = false
	end

	if (headerChanged or railChanged) and self.frame and self.built then
		self:ApplyLayout()
	end
	return hovered
end

function Dock:ScheduleHeaderHoverRefresh(delay)
	if self.headerDragActive or self.railTabDragViewId then
		return
	end
	if not self.headerHoverDriver then
		local driver = CreateFrame("Frame")
		driver:Hide()
		driver:SetScript("OnUpdate", function(_, elapsed)
			Dock.headerHoverDelay = (Dock.headerHoverDelay or 0) - (elapsed or 0)
			if Dock.headerHoverDelay <= 0 then
				Dock.headerHoverDelay = nil
				driver:Hide()
				Dock:SetHeaderHover(Dock:IsMouseOverDock())
			end
		end)
		self.headerHoverDriver = driver
	end
	self.headerHoverDelay = tonumber(delay) or 0.08
	self.headerHoverDriver:Show()
end

function Dock:BindHeaderHover(surface)
	if not surface or surface._ccbbHeaderHoverBound or not surface.HookScript then
		return
	end
	surface._ccbbHeaderHoverBound = true
	surface:HookScript("OnEnter", function()
		if Dock.active then
			Dock:CancelHeaderHoverRefresh()
			Dock:SetHeaderHover(true)
		end
	end)
	surface:HookScript("OnLeave", function()
		if Dock.active then
			Dock:ScheduleHeaderHoverRefresh()
		end
	end)
end

function Dock:BindDockControlTooltip(button, title, detail)
	if not button or not button.HookScript or button._ccbbControlTooltipBound then
		return
	end
	button._ccbbControlTooltipBound = true
	button:HookScript("OnEnter", function(self)
		Dock:HideDisplayHoverHint()
		if not GameTooltip or not GameTooltip.SetOwner then
			return
		end
		local heading = type(title) == "function" and title(self) or title
		local body = type(detail) == "function" and detail(self) or detail
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(heading or "Chat control", 1, 0.82, 0.26)
		if body and body ~= "" then
			GameTooltip:AddLine(body, 0.56, 0.63, 0.71, true)
		end
		GameTooltip:Show()
	end)
	button:HookScript("OnLeave", function(self)
		hideTooltipForOwner(self)
	end)
end

function Dock:UpdateHeaderTextLayout()
	if not self.frame or not self.title then
		return
	end
	self.title:ClearAllPoints()
	self.title:SetPoint("LEFT", self.headerIcon, "RIGHT", 4, 0)
	if self:IsCollapsed() then
		self.title:SetWidth(118)
		return
	end
	local compactHeader = addon:GetSmartSettings().dock.compactHeader ~= false
	if compactHeader then
		local controlsWidth = 8
		controlsWidth = controlsWidth + (self.settingsButton:GetWidth() or 0)
		controlsWidth = controlsWidth + (self.hideButton:GetWidth() or 0)
		controlsWidth = controlsWidth + (self.collapseButton:GetWidth() or 0)
		if self.newButton:IsShown() and not self:IsNewMessageIndicatorDockAnchored() then
			local scale = self.newButton.GetScale and self.newButton:GetScale() or 1
			controlsWidth = controlsWidth + ((self.newButton:GetWidth() or 0) * (tonumber(scale) or 1)) + 2
		end
		self.title:SetWidth(math.max(40, self.frame:GetWidth() - controlsWidth - 29))
	else
		self.title:SetWidth(108)
		self.subtitle:ClearAllPoints()
		self.subtitle:SetPoint("LEFT", self.title, "RIGHT", 4, 0)
		self.subtitle:SetWidth(math.max(30, self.frame:GetWidth() - 252))
	end
end

function Dock:ApplyLayout()
	if not self.frame or not self.built then
		return false
	end

	local settings = addon:GetSmartSettings()
	local dockSettings = settings.dock or {}
	local collapsed = self:IsCollapsed()
	local orientation = dockSettings.railOrientation == "horizontal" and "horizontal" or "vertical"
	local railVisibility = self:ResolveRailVisibility(false)
	local showRail = railVisibility == "always"
		or (railVisibility == "click" and self.railClickRevealed == true)
		or (railVisibility == "mouseover" and self.railMouseoverRevealed == true)
	local compactHeader = dockSettings.compactHeader ~= false
	local headerHeight = compactHeader and 24 or 28
	local headerVisibility = getConfiguredHeaderVisibility()
	local showHeader = headerVisibility == "always"
		or (headerVisibility == "hover" and self.headerHover == true)
	-- Auto-hide reclaims the composer lane only while no editor is active.  The
	-- parent remains shown at alpha zero (see RefreshComposerVisibility), so
	-- Blizzard can still reveal ChatFrame1EditBox through every native route.
	local reserveComposerSpace = self:ShouldReserveComposerSpace()
	local bottomOffset = reserveComposerSpace and COMPOSER_RESERVED_HEIGHT or COMPOSER_INSET
	self.composerSpaceReserved = not collapsed and reserveComposerSpace or false

	if collapsed then
		self:CancelNewMessageIndicatorMove(false)
		self:HideSourceColumnAlignmentControl()
		self.frame:SetResizable(false)
		self.frame:SetSize(COLLAPSED_WIDTH, COLLAPSED_HEIGHT)
		self.header:ClearAllPoints()
		self.header:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 2, -2)
		self.header:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -2, 2)
		self.header:SetHeight(24)
		-- A collapsed dock is its own compact control surface. Keep its title
		-- handle available even when the expanded dock's Title Bar is hidden, so
		-- there is always an obvious way to expand, close, or open settings.
		self.header:Show()
		self.rail:Hide()
		self.content:Hide()
		self.composer:Hide()
		self:RefreshResizeHandles()
		self.newButton:Hide()
		self.subtitle:Hide()
		self.alertBar:Hide()
		self:HidePlayerActions()
		if self.collapseButton.SetLabel then
			self.collapseButton:SetLabel("+")
		else
			self.collapseButton.text:SetText("+")
		end
		self:UpdateHeaderTextLayout()
		return true
	end

	local _, _, _, _, width, height = getGeometry()
	self.frame:SetResizable(true)
	self.frame:SetSize(width, height)
	self.header:ClearAllPoints()
	self.header:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 2, -2)
	self.header:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -2, -2)
	self.header:SetHeight(headerHeight)
	if showHeader then
		self.header:Show()
	else
		self.header:Hide()
	end

	self.rail:ClearAllPoints()
	self.content:ClearAllPoints()
	if not showRail then
		if showHeader then
			self.content:SetPoint("TOPLEFT", self.header, "BOTTOMLEFT", 0, -2)
		else
			self.content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 2, -2)
		end
		self.content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -2, bottomOffset)
	elseif orientation == "horizontal" then
		if showHeader then
			self.rail:SetPoint("TOPLEFT", self.header, "BOTTOMLEFT", 0, -2)
			self.rail:SetPoint("TOPRIGHT", self.header, "BOTTOMRIGHT", 0, -2)
		else
			self.rail:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 2, -2)
			self.rail:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -2, -2)
		end
		self.rail:SetHeight(24)
		self.content:SetPoint("TOPLEFT", self.rail, "BOTTOMLEFT", 0, -2)
		self.content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -2, bottomOffset)
	else
		if showHeader then
			self.rail:SetPoint("TOPLEFT", self.header, "BOTTOMLEFT", 0, -2)
		else
			self.rail:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 2, -2)
		end
		self.rail:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 2, bottomOffset)
		-- The rail expands only when a player chooses a larger unread-count
		-- font. Its inner scroll lane always remains wide enough for the tab key
		-- and 99+ badge to sit side by side instead of overlapping.
		local requiredTabWidth = self.railRequiredTabWidth or self:GetRailTabMinimumWidth(settings)
		self.rail:SetWidth(math.max(42, requiredTabWidth + 4))
		self.content:SetPoint("TOPLEFT", self.rail, "TOPRIGHT", 2, 0)
		self.content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -2, bottomOffset)
	end
	if showRail then
		self.rail:Show()
	else
		self.rail:Hide()
	end
	self.content:Show()

	self.railScroll:ClearAllPoints()
	local railSettingsButton = self.railSettingsButton
	if railSettingsButton then
		railSettingsButton:ClearAllPoints()
		railSettingsButton:Show()
		if orientation == "horizontal" then
			railSettingsButton:SetPoint("RIGHT", self.rail, "RIGHT", -2, 0)
			self.railScroll:SetPoint("TOPLEFT", self.rail, "TOPLEFT", 2, -2)
			-- Reserve only the icon control plus its two-pixel breathing room.
			-- The tabs themselves keep their full scrollable run up to this edge.
			self.railScroll:SetPoint("BOTTOMRIGHT", self.rail, "BOTTOMRIGHT", -(railSettingsButton:GetWidth() + 4), 2)
		else
			railSettingsButton:SetPoint("BOTTOM", self.rail, "BOTTOM", 0, 2)
			self.railScroll:SetPoint("TOPLEFT", self.rail, "TOPLEFT", 2, -2)
			-- Vertical rails read top-to-bottom, so the visual end is the bottom.
			-- Keep the settings control fixed there while the tab list scrolls above.
			self.railScroll:SetPoint("BOTTOMRIGHT", self.rail, "BOTTOMRIGHT", -2, railSettingsButton:GetHeight() + 4)
		end
	else
		-- Defensive fallback for a partial/older dock build.
		self.railScroll:SetPoint("TOPLEFT", self.rail, "TOPLEFT", 2, -2)
		self.railScroll:SetPoint("BOTTOMRIGHT", self.rail, "BOTTOMRIGHT", -2, 2)
	end
	if orientation == "horizontal" then
		if self.railScroll.SetVerticalScroll then self.railScroll:SetVerticalScroll(0) end
	else
		if self.railScroll.SetHorizontalScroll then self.railScroll:SetHorizontalScroll(0) end
	end

	if self.alertActive then
		self.alertBar:Show()
	else
		self.alertBar:Hide()
	end
	-- Resolve the player menu's one- or two-row height before reserving the
	-- readable chat lane. The shared pass moves display, scrollbar, latest-message
	-- action, and empty-state text together.
	self:RefreshPlayerActionsLayout(true)
	self:RefreshTransientMessageLayout()

	self.composer:ClearAllPoints()
	self.composer:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 2, 2)
	self.composer:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -2, 2)
	self.composer:SetHeight(COMPOSER_HEIGHT)
	self:RefreshComposerLayout()
	self:RefreshComposerVisibility()

	self:RefreshResizeHandles()
	if compactHeader then
		self.subtitle:Hide()
	else
		self.subtitle:Show()
	end
	self:RefreshNewMessageIndicator(false)
	if self.collapseButton.SetLabel then
		self.collapseButton:SetLabel("-")
	else
		self.collapseButton.text:SetText("-")
	end
	self:UpdateHeaderTextLayout()
	self:RefreshViews()
	if self.analysisPanel and frameIsShown(self.analysisPanel) then
		self:RefreshMessageAnalysisLayout()
	end
	self:UpdateSourceColumnAlignmentControl()
	self:RefreshMessageBands()
	self:RefreshDisplayWidthPresentation()
	return true
end

function Dock:StopAlertTimer()
	if self.alertDriver then
		self.alertDriver:SetScript("OnUpdate", nil)
		self.alertDriver:Hide()
	end
	self.alertDeadline = nil
end

function Dock:DismissAlert(restoreState)
	local pending = self.alertPending
	self:StopAlertTimer()
	self.alertPending = nil
	self.alertActive = false
	self.alertRecord = nil
	if self.alertBar then
		self.alertBar:Hide()
	end
	if restoreState and pending and not pending.restoreCancelled then
		local composing = self.editBox and self.editBox:IsShown()
		if composing and (not pending.wasVisible or pending.wasCollapsed) then
			-- The alert may have adopted a keyboard-chat reveal. Do not hide an
			-- edit box that is still active; hand the original state back to the
			-- composer lifecycle and restore it when the message editor closes.
			self.editReveal = {
				wasVisible = pending.wasVisible,
				wasCollapsed = pending.wasCollapsed,
				revision = self.stateRevision or 0,
			}
			self.visibleState = true
			self.collapsedState = false
			self:SyncDockHoverState()
			self:ApplyLayout()
			self.frame:Show()
		else
			self.visibleState = pending.wasVisible
			self.collapsedState = pending.wasCollapsed
			if not pending.wasVisible or pending.wasCollapsed then
				self.railClickRevealed = false
				self.railMouseoverRevealed = false
			end
			self:ApplyLayout()
			if self.frame then
				if self.active and self.visibleState then
					self.frame:Show()
				else
					self.frame:Hide()
				end
			end
		end
	end
	-- DismissAlert(false) deliberately skips the saved visibility restore, but it
	-- must still release the notice lane immediately (accept, replacement alert,
	-- profile reset, and explicit close all use that path).
	self:RefreshTransientMessageLayout()
end

function Dock:AcceptAlert()
	local record = self.alertRecord
	self:DismissAlert(false)
	self:SetVisible(true, true)
	self:SetCollapsed(false, true)
	if record and record.view then
		self:SelectView(record.view)
	end
end

function Dock:OnAlert(record, rule)
	if not self.active or not record or not self.frame then
		return false
	end
	if self.alertPending and self.alertPending.restoreCancelled then
		self:DismissAlert(false)
	end
	-- Automatic alerts and deliberate player actions share the transient message
	-- area. Let the newest alert own that lane instead of stacking two surfaces
	-- over a minimum-height chat window.
	self:HidePlayerActions()
	local editReveal = self.editReveal
	self.editReveal = nil
	if not self.alertPending then
		local restoreVisible
		local restoreCollapsed
		local validEditRestore = editReveal
			and not editReveal.restoreCancelled
			and editReveal.revision == (self.stateRevision or 0)
		if validEditRestore then
			restoreVisible = editReveal.wasVisible
			restoreCollapsed = editReveal.wasCollapsed
		else
			restoreVisible = self:IsVisible()
			restoreCollapsed = self:IsCollapsed()
		end
		self.alertPending = {
			wasVisible = restoreVisible,
			wasCollapsed = restoreCollapsed,
			revision = self.stateRevision or 0,
		}
	end

	self.alertRecord = record
	self.alertActive = true
	local ruleName = (rule and (rule.name or rule.label or rule.word or rule.keyword)) or "WATCH"
	local sender = record.sender or "Unknown"
	local message = record.message or record.text or ""
	self.alertTitle:SetText(tostring(ruleName) .. "  |  " .. tostring(sender))
	local renderedMessage = tostring(message)
	-- Alerts are a compact chat surface too. Reuse the presentation pass so
	-- native raid-target markers such as {skull} render consistently here
	-- without changing the record preserved in message history.
	if Presentation and Presentation.ColorizeMessage then
		local ok, formatted = pcall(Presentation.ColorizeMessage, Presentation, renderedMessage)
		if ok and type(formatted) == "string" then
			renderedMessage = formatted
		end
	end
	self.alertMessage:SetText(renderedMessage)

	-- Reveal only the runtime surface. The saved visible/collapsed preferences
	-- remain untouched and are restored when the alert expires.
	self.visibleState = true
	self.collapsedState = false
	self:SyncDockHoverState()
	self:ApplyLayout()
	self.frame:Show()
	self.alertBar:Show()

	local alerts = addon:GetSmartSettings().alerts or {}
	local delay = tonumber(alerts.autoHideSeconds)
	if delay == nil then delay = 8 end
	if delay > 0 then
		delay = math.min(120, delay)
		self.alertDeadline = (GetTime and GetTime() or 0) + delay
		self.alertDriver:Show()
		self.alertDriver:SetScript("OnUpdate", function()
			if Dock.alertDeadline and GetTime and GetTime() >= Dock.alertDeadline then
				Dock:DismissAlert(true)
			end
		end)
	else
		-- Zero is a deliberate sticky alert: it remains until dismissed or opened.
		self:StopAlertTimer()
	end
	return true
end

function Dock:ResetTransientState()
	self.unread = {}
	self.pendingVisible = 0
	self:CancelNewMessageIndicatorMove(false)
	self.newMessageIndicatorPreviewActive = false
	self.newMessageIndicatorSuppressClickUntil = nil
	self.railClickRevealed = false
	self.railMouseoverRevealed = false
	self:CancelResize()
	self:CancelRailTabReorder(false)
	self:CancelRailMove(false)
	self.railTabSuppressClickUntil = nil
	self.railTabSuppressClickViewId = nil
	self.headerHover = false
	self.headerDragActive = false
	self:CancelHeaderHoverRefresh()
	self:HideChatHelpMenu(false)
	self:HideDisplayHoverHint()
	self.hoveredHyperlink = nil
	self.lastConversationTarget = nil
	self:HidePlayerActions()
	self.ignoreRecord = nil
	self.editReveal = nil
	if self.newButton then
		self.newButton:Hide()
	end
	if self.ignoreConfirm then
		self.ignoreConfirm:Hide()
	end
	if self.display then
		self.display:Clear()
	end
	self:ClearDisplayRecordCache()
	self.activeSourceColumnWidth = nil
	self.activeSourceColumnCandidateWidth = nil
	self.activeSenderColumnWidth = nil
	self.activeSenderColumnCandidateWidth = nil
	self.activeSenderColumnConfiguredSpacing = nil
	self.activeAlignmentScopeSignature = nil
	self.displayRecordViewId = nil
	self.visibleAlignmentRefreshInProgress = nil
	self.activeSourceColumnDriver = nil
	self.activeColumnRecordCount = nil
	self.activeSourceColumnSamples = nil
	self.activeColumnLayoutResolved = nil
	self.activeMetadataMode = nil
	self.activeMetadataBodyColumns = nil
	self.activeMetadataLeaderColumns = nil
	self.activeDisplayColumnCapacity = nil
	self.activeResponsiveMetadataEnabled = nil
	self.activePresentationPixelWidth = nil
	self:HideMessageBlockControls()
	self:HideSourceColumnAlignmentControl()
	self:DismissAlert(false)
end

function Dock:DiscardPartialBuild()
	self:CancelHeaderHoverRefresh()
	self:HideChatHelpMenu(false)
	self:HideDisplayHoverHint()
	self:CancelResize()
	self:CancelRailTabReorder(false)
	self:CancelRailMove(false)
	self:CancelNewMessageIndicatorMove(false)
	self.headerHover = false
	self.headerDragActive = false
	self:RestoreEditBox()
	self:RestoreNativeChat()
	if self.frame then
		self.frame:Hide()
	end
	self.frame = nil
	self.title = nil
	self.subtitle = nil
	self.header = nil
	self.headerIcon = nil
	self.collapseButton = nil
	self.hideButton = nil
	self.settingsButton = nil
	self.rail = nil
	self.railScroll = nil
	self.railContent = nil
	self.railButtons = nil
	self.railTabReorderOverlay = nil
	self.railTabReorderMarker = nil
	self.railSettingsButton = nil
	self.display = nil
	self.messageMeasure = nil
	self.displayRecords = nil
	self.displayMeasurementWidth = nil
	self.messageBandHost = nil
	self.messageBandPool = nil
	self.messageBandVisibleCount = nil
	self.messageActionHighlight = nil
	self.messageActionHighlightRecord = nil
	self.content = nil
	self.messageScrollbar = nil
	self.scrollToBottomButton = nil
	self.scrollToBottomGlyph = nil
	self.transientMessageTopInset = nil
	self.transientMessageBottomInset = nil
	self.transientMessageRightInset = nil
	self.transientMessageContentHeight = nil
	self.transientMessageViewportSuppressed = nil
	self.transientMessageScrollbarSuppressed = nil
	self.transientMessageDisplayWasShown = nil
	self.transientMessageEmptyWasShown = nil
	self.transientMessageWasAtBottom = nil
	self.emptyState = nil
	self.newButton = nil
	self.newMessageIndicatorDefaultFontObject = nil
	self.newMessageIndicatorDefaultFontPath = nil
	self.newMessageIndicatorDefaultFontSize = nil
	self.newMessageIndicatorDefaultFontFlags = nil
	self.composer = nil
	self.composerRoute = nil
	self.composerRouteButton = nil
	self.composerRouteAccent = nil
	self.composerRouteMenu = nil
	self.composerRouteChoiceButtons = nil
	self.composerRouteMenuPageText = nil
	self.composerRouteMenuPrevious = nil
	self.composerRouteMenuNext = nil
	self.composerRouteChoices = nil
	self.composerRoutePage = nil
	self.composerRouteOverride = nil
	self.composerRouteOverrides = nil
	self.composerPlaceholder = nil
	self.composerSend = nil
	self.composerEditBoxBorder = nil
	self.resizeHandles = nil
	self.resizeHandleList = nil
	self.resizeDragRegion = nil
	self.resizeHoverRegion = nil
	self.alertBar = nil
	self.alertTitle = nil
	self.alertMessage = nil
	self.playerActions = nil
	self.playerActionName = nil
	self.playerActionClose = nil
	self.playerActionButtons = nil
	self.playerActionDefinitions = nil
	self.playerActionCompactLayout = nil
	self.playerActionAutoHideRemaining = nil
	self.playerActionMouseWasDown = nil
	self.playerActionAlertRestore = nil
	self.ignoreConfirm = nil
	self.ignoreConfirmText = nil
	self.blockAction = nil
	self.blockChoices = nil
	self.blockActionRecord = nil
	self.blockChoicesRecord = nil
	self.analysisAction = nil
	self.analysisActionRecord = nil
	self.analysisPanel = nil
	self.analysisRecord = nil
	self.analysisSource = nil
	self.analysisRoute = nil
	self.analysisSignals = nil
	self.analysisWhy = nil
	self.analysisFootnote = nil
	self.analysisRouteControls = nil
	self.analysisRouteSelector = nil
	self.analysisRouteMove = nil
	self.analysisRouteMenu = nil
	self.analysisRouteMenuButtons = nil
	self.analysisRouteDestinations = nil
	self.analysisRouteDestination = nil
	self.analysisRemoveOverride = nil
	self.chatHelpTrigger = nil
	self.chatHelpMenu = nil
	self.chatHelpTitle = nil
	self.chatHelpSubtitle = nil
	self.chatHelpRows = nil
	self.chatHelpOpenSettings = nil
	self.chatHelpClose = nil
	self.chatHelpPageText = nil
	self.chatHelpPrevious = nil
	self.chatHelpNext = nil
	self.chatHelpPage = nil
	self.columnAlignmentSettingsButton = nil
	self.activeSourceColumnWidth = nil
	self.activeSourceColumnCandidateWidth = nil
	self.activeSenderColumnWidth = nil
	self.activeSenderColumnCandidateWidth = nil
	self.activeSenderColumnConfiguredSpacing = nil
	self.activeAlignmentScopeSignature = nil
	self.displayRecordViewId = nil
	self.visibleAlignmentRefreshInProgress = nil
	self.activeSourceColumnDriver = nil
	self.activeColumnRecordCount = nil
	self.activeSourceColumnSamples = nil
	self.activeColumnLayoutResolved = nil
	self.activeMetadataMode = nil
	self.activeMetadataBodyColumns = nil
	self.activeMetadataLeaderColumns = nil
	self.activeDisplayColumnCapacity = nil
	self.activeResponsiveMetadataEnabled = nil
	self.activePresentationPixelWidth = nil
	self.editBox = nil
	self.built = false
end

function Dock:PrepareForProfileChange()
	self:Deactivate()
	self:ResetTransientState()
end

function Dock:ApplyProfile()
	local settings = addon:GetSmartSettings()
	self.activeView = settings.dock.activeView or "general"
	self:ResolveRailVisibility(true)
	self:DismissAlert(false)
	self.visibleState = settings.dock.visible ~= false
	self.collapsedState = settings.dock.collapsed == true
	self.composerInputActive = self.editBox and self.editBox.IsShown and self.editBox:IsShown() or false
	if self.frame and not self.built then
		self:DiscardPartialBuild()
	end
	if not self.frame then
		return
	end
	applyGeometry(self.frame)
	self:SyncDockHoverState()
	self:ApplyLayout()
	self:SelectView(self.activeView)
	if self.active then
		if self.visibleState then
			self.frame:Show()
		else
			self.frame:Hide()
		end
		if settings.dock.hideNativeChat then
			self:HideNativeChat()
		else
			self:RestoreNativeChat()
		end
		self:ApplySocialButtonVisibility()
	end
end

function Dock:SaveGeometry()
	local point, _, _, x, y = self.frame:GetPoint(1)
	local settings = addon:GetSmartSettings().dock
	settings.point = point or "BOTTOMLEFT"
	settings.x = math.floor(x or 0)
	settings.y = math.floor(y or 0)
	if not self:IsCollapsed() then
		settings.width = math.max(EXPANDED_MIN_WIDTH, math.min(EXPANDED_MAX_WIDTH, math.floor(self.frame:GetWidth())))
		settings.height = math.max(EXPANDED_MIN_HEIGHT, math.min(EXPANDED_MAX_HEIGHT, math.floor(self.frame:GetHeight())))
	end
end

function Dock:CanResize()
	local frame = self.frame
	if not self.active or not frame or self:IsCollapsed() then
		return false
	end
	if frame.IsShown and not frame:IsShown() then
		return false
	end
	if frame.IsResizable and not frame:IsResizable() then
		return false
	end
	local settings = addon:GetSmartSettings()
	local dockSettings = settings and settings.dock or nil
	if dockSettings and dockSettings.locked then
		return false
	end
	-- Do not begin a free-form frame operation during combat.  The dock itself
	-- has no secure resize behavior, but this keeps its interaction contract in
	-- step with the rest of the combat-safe dock lifecycle.
	if InCombatLockdown and InCombatLockdown() then
		return false
	end
	return true
end

-- A hidden title bar must not make an unlocked dock impossible to move.  This
-- is deliberately narrower than general frame movement: it applies only to
-- the blank part of a visible rail while the expanded title bar is configured
-- Hidden.  The normal title handle continues to own movement in every other
-- presentation.
function Dock:CanMoveFromRail()
	local frame = self.frame
	if not self.active or not self.built or not frame or self:IsCollapsed() then
		return false
	end
	if not frameIsShown(frame) or not frameIsShown(self.rail) then
		return false
	end
	if getConfiguredHeaderVisibility() ~= "hidden" then
		return false
	end
	local dockSettings = addon:GetSmartSettings().dock or {}
	if dockSettings.locked then
		return false
	end
	if InCombatLockdown and InCombatLockdown() then
		return false
	end
	return true
end

function Dock:IsMouseOverRailBackground()
	if not self.rail or (self.rail.IsMouseOver and not self.rail:IsMouseOver()) then
		return false
	end
	local settingsButton = self.railSettingsButton
	if settingsButton and frameIsShown(settingsButton) and settingsButton.IsMouseOver and settingsButton:IsMouseOver() then
		return false
	end
	for _, button in pairs(self.railButtons or {}) do
		if frameIsShown(button) and button.IsMouseOver and button:IsMouseOver() then
			return false
		end
	end
	return true
end

function Dock:EnsureRailMoveDriver()
	if self.railMoveDriver then
		return self.railMoveDriver
	end
	if not CreateFrame then
		return nil
	end
	local driver = CreateFrame("Frame")
	driver:Hide()
	driver:SetScript("OnUpdate", function()
		Dock:UpdateRailMove()
	end)
	self.railMoveDriver = driver
	return driver
end

function Dock:CancelRailMove(saveGeometry)
	local moving = self.railMoveActive == true
	self.railMovePress = nil
	self.railMoveActive = false
	if self.railMoveDriver then
		self.railMoveDriver:Hide()
	end
	if moving and self.frame and self.frame.StopMovingOrSizing then
		self.frame:StopMovingOrSizing()
	end
	if moving and saveGeometry then
		self:SaveGeometry()
	end
	if moving then
		self.headerDragActive = false
		self:ScheduleHeaderHoverRefresh(0)
	end
	return moving
end

function Dock:BeginRailMoveCandidate(mouseButton)
	if mouseButton ~= "LeftButton" or isShiftDown() or not self:CanMoveFromRail() or not self:IsMouseOverRailBackground() then
		return false
	end
	-- A Shift drag on a tab belongs to reordering, and a new press never joins a
	-- pre-existing resize or tab transaction.
	if self.resizeDragRegion or self.railTabPress or self.railTabDragViewId then
		return false
	end
	local cursorX, cursorY = getCursorInUiCoordinates()
	if cursorX == nil or cursorY == nil then
		return false
	end
	local driver = self:EnsureRailMoveDriver()
	if not driver then
		return false
	end
	self:CancelRailMove(false)
	self.railMovePress = { x = cursorX, y = cursorY }
	driver:Show()
	return true
end

function Dock:UpdateRailMove()
	local press = self.railMovePress
	if not press and not self.railMoveActive then
		if self.railMoveDriver then self.railMoveDriver:Hide() end
		return
	end
	if IsMouseButtonDown then
		local ok, down = pcall(IsMouseButtonDown, "LeftButton")
		if ok and down == false then
			self:CancelRailMove(true)
			return
		end
	end
	if not self:CanMoveFromRail() then
		self:CancelRailMove(false)
		return
	end
	if not self.railMoveActive then
		local cursorX, cursorY = getCursorInUiCoordinates()
		if cursorX == nil or cursorY == nil then
			return
		end
		local dx = cursorX - press.x
		local dy = cursorY - press.y
		if (dx * dx) + (dy * dy) < (RAIL_MOVE_DRAG_DISTANCE * RAIL_MOVE_DRAG_DISTANCE) then
			return
		end
		local started = self.frame and self.frame.StartMoving and pcall(self.frame.StartMoving, self.frame)
		if not started then
			self:CancelRailMove(false)
			return
		end
		self.railMovePress = nil
		self.railMoveActive = true
		self.headerDragActive = true
		self:CancelHeaderHoverRefresh()
		self:SetHeaderHover(true)
	end
end

function Dock:HandleRailBackgroundMouseUp(mouseButton)
	if mouseButton == "LeftButton" and (self.railMovePress or self.railMoveActive) then
		self:CancelRailMove(true)
		return true
	end
	return false
end

function Dock:BindRailBackgroundDrag(surface)
	if not surface or surface._ccbbRailMoveBound or not surface.HookScript then
		return
	end
	surface._ccbbRailMoveBound = true
	surface:HookScript("OnMouseDown", function(_, mouseButton)
		Dock:BeginRailMoveCandidate(mouseButton)
	end)
	surface:HookScript("OnMouseUp", function(_, mouseButton)
		Dock:HandleRailBackgroundMouseUp(mouseButton)
	end)
end

function Dock:RefreshResizeHighlights()
	local activeId = nil
	if self:CanResize() then
		activeId = self.resizeDragRegion or self.resizeHoverRegion
	end
	for _, handle in ipairs(self.resizeHandleList or {}) do
		local visible = handle.resizeId == activeId
		for _, texture in ipairs(handle.resizeHighlights or {}) do
			if visible then
				texture:Show()
			else
				texture:Hide()
			end
		end
	end
end

function Dock:RefreshResizeHandles()
	local enabled = self:CanResize()
	if not enabled then
		self.resizeHoverRegion = nil
		if self.resizeDragRegion then
			if self.frame and self.frame.StopMovingOrSizing then
				self.frame:StopMovingOrSizing()
			end
			self.resizeDragRegion = nil
			self.headerDragActive = false
		end
	end
	for _, handle in ipairs(self.resizeHandleList or {}) do
		if enabled then
			handle:Show()
		else
			handle:Hide()
		end
	end
	self:RefreshResizeHighlights()
	return enabled
end

function Dock:SetResizeHover(regionId)
	if self.resizeDragRegion then
		regionId = self.resizeDragRegion
	end
	local handle = regionId and self.resizeHandles and self.resizeHandles[regionId] or nil
	if not handle or not self:CanResize() then
		regionId = nil
		handle = nil
	end
	if self.resizeHoverRegion == regionId then
		return regionId
	end
	self.resizeHoverRegion = regionId
	self:RefreshResizeHighlights()
	return regionId
end

function Dock:BeginResize(regionId)
	local handle = self.resizeHandles and self.resizeHandles[regionId] or nil
	if not handle or not self:CanResize() then
		return false
	end

	self:HideMessageBlockControls()
	self.resizeDragRegion = regionId
	self.resizeHoverRegion = regionId
	self.headerDragActive = true
	self:CancelHeaderHoverRefresh()
	self:SetHeaderHover(true)
	self:RefreshResizeHighlights()
	local started = pcall(self.frame.StartSizing, self.frame, handle.resizeDirection)
	if not started then
		self.resizeDragRegion = nil
		self.headerDragActive = false
		self:SetResizeHover(nil)
		self:ScheduleHeaderHoverRefresh(0)
		return false
	end
	return true
end

function Dock:EndResize(regionId)
	if not self.resizeDragRegion or (regionId and regionId ~= self.resizeDragRegion) then
		return false
	end

	local activeId = self.resizeDragRegion
	if self.frame and self.frame.StopMovingOrSizing then
		self.frame:StopMovingOrSizing()
	end
	self.resizeDragRegion = nil
	self.headerDragActive = false
	self:SaveGeometry()
	-- Explicit hanging breaks depend on the final viewport width. Repaint once
	-- when the drag commits (never on every OnSizeChanged tick), then restore a
	-- reader's approximate scroll distance if they resized while reviewing old
	-- history. At-bottom readers remain at the newest line.
	if self.active and self.activeView and addon.MessageEngine then
		self:RebuildActiveViewPreservingScroll()
	end

	local handle = self.resizeHandles and self.resizeHandles[activeId] or nil
	if handle and handle.IsMouseOver and handle:IsMouseOver() then
		self.resizeHoverRegion = activeId
	else
		self.resizeHoverRegion = nil
	end
	self:RefreshResizeHighlights()
	self:ScheduleHeaderHoverRefresh(0)
	return true
end

function Dock:CancelResize()
	if self.resizeDragRegion and self.frame and self.frame.StopMovingOrSizing then
		self.frame:StopMovingOrSizing()
	end
	self.resizeDragRegion = nil
	self.resizeHoverRegion = nil
	self:RefreshResizeHighlights()
end

local function anchorResizeHandle(handle, definition, frame)
	if definition.corner then
		handle:SetSize(RESIZE_CORNER_HIT_SIZE, RESIZE_CORNER_HIT_SIZE)
		handle:SetPoint(definition.corner, frame, definition.corner, 0, 0)
		return
	end

	if definition.edge == "TOP" then
		handle:SetPoint("TOPLEFT", frame, "TOPLEFT", RESIZE_CORNER_HIT_SIZE, 0)
		handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -RESIZE_CORNER_HIT_SIZE, 0)
		handle:SetHeight(RESIZE_EDGE_HIT_THICKNESS)
	elseif definition.edge == "BOTTOM" then
		handle:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", RESIZE_CORNER_HIT_SIZE, 0)
		handle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -RESIZE_CORNER_HIT_SIZE, 0)
		handle:SetHeight(RESIZE_EDGE_HIT_THICKNESS)
	elseif definition.edge == "LEFT" then
		handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -RESIZE_CORNER_HIT_SIZE)
		handle:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, RESIZE_CORNER_HIT_SIZE)
		handle:SetWidth(RESIZE_EDGE_HIT_THICKNESS)
	elseif definition.edge == "RIGHT" then
		handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -RESIZE_CORNER_HIT_SIZE)
		handle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, RESIZE_CORNER_HIT_SIZE)
		handle:SetWidth(RESIZE_EDGE_HIT_THICKNESS)
	end
end

local function addResizeHighlight(handle, definition)
	local highlights = {}
	local function createHighlight()
		local texture = handle:CreateTexture(nil, "OVERLAY")
		texture:SetTexture("Interface\\Buttons\\WHITE8x8")
		if Theme.RegisterTexture then
			-- Accent is deliberately separate from the normal border color. It is
			-- the only visible confirmation that this exact edge/corner is ready
			-- to drag, and it follows every selected Theme automatically.
			Theme:RegisterTexture(texture, "accent")
		else
			local r, g, b, a = Theme:GetColor("accent")
			texture:SetVertexColor(r, g, b, a)
		end
		texture:Hide()
		table.insert(highlights, texture)
		return texture
	end

	if definition.horizontal then
		local horizontal = createHighlight()
		horizontal:SetHeight(RESIZE_HIGHLIGHT_THICKNESS)
		if definition.horizontal == "TOP" then
			horizontal:SetPoint("TOPLEFT", handle, "TOPLEFT", 0, 0)
			horizontal:SetPoint("TOPRIGHT", handle, "TOPRIGHT", 0, 0)
		else
			horizontal:SetPoint("BOTTOMLEFT", handle, "BOTTOMLEFT", 0, 0)
			horizontal:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", 0, 0)
		end
	end
	if definition.vertical then
		local vertical = createHighlight()
		vertical:SetWidth(RESIZE_HIGHLIGHT_THICKNESS)
		if definition.vertical == "LEFT" then
			vertical:SetPoint("TOPLEFT", handle, "TOPLEFT", 0, 0)
			vertical:SetPoint("BOTTOMLEFT", handle, "BOTTOMLEFT", 0, 0)
		else
			vertical:SetPoint("TOPRIGHT", handle, "TOPRIGHT", 0, 0)
			vertical:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", 0, 0)
		end
	end
	return highlights
end

function Dock:BuildResizeHandles()
	if not self.frame then
		return false
	end
	self.resizeHandles = {}
	self.resizeHandleList = {}
	for _, definition in ipairs(resizeHandleDefinitions) do
		local handle = CreateFrame("Button", nil, self.frame)
		handle.resizeId = definition.id
		handle.resizeDirection = definition.direction
		handle:EnableMouse(true)
		handle:SetFrameLevel(self.frame:GetFrameLevel() + 20)
		anchorResizeHandle(handle, definition, self.frame)
		handle.resizeHighlights = addResizeHighlight(handle, definition)
		handle:SetScript("OnEnter", function(self)
			Dock:SetResizeHover(self.resizeId)
		end)
		handle:SetScript("OnLeave", function(self)
			if Dock.resizeDragRegion ~= self.resizeId then
				Dock:SetResizeHover(nil)
			end
		end)
		handle:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" then
				Dock:BeginResize(self.resizeId)
			end
		end)
		handle:SetScript("OnMouseUp", function(self, button)
			if button == "LeftButton" then
				Dock:EndResize(self.resizeId)
			end
		end)
		self:BindHeaderHover(handle)
		self.resizeHandles[definition.id] = handle
		table.insert(self.resizeHandleList, handle)
	end
	self:RefreshResizeHandles()
	return true
end

function Dock:GetPlayerActionMenuSettings()
	local stored
	if type(addon.GetPlayerActionMenuSettings) == "function" then
		local ok, result = pcall(addon.GetPlayerActionMenuSettings, addon)
		if ok and type(result) == "table" then
			stored = result
		end
	end
	if not stored and type(addon.GetSmartSettings) == "function" then
		local ok, settings = pcall(addon.GetSmartSettings, addon)
		local dockSettings = ok and type(settings) == "table" and settings.dock or nil
		stored = type(dockSettings) == "table" and dockSettings.playerActions or nil
	end
	stored = type(stored) == "table" and stored or {}
	local seconds = tonumber(stored.autoHideSeconds) or 10
	seconds = math.max(1, math.min(120, math.floor(seconds + 0.5)))
	return {
		autoHide = stored.autoHide ~= false,
		autoHideSeconds = seconds,
	}
end

function Dock:HidePlayerActions()
	local wasShown = frameIsShown(self.playerActions)
	local alertRestore = self.playerActionAlertRestore
	self.playerActionAlertRestore = nil
	for _, button in ipairs(self.playerActionButtons or {}) do
		hideTooltipForOwner(button)
	end
	hideTooltipForOwner(self.playerActionClose)
	if self.playerActions then
		self.playerActions:Hide()
	end
	self.actionRecord = nil
	self.playerActionAutoHideRemaining = nil
	self.playerActionMouseWasDown = nil
	if alertRestore then
		-- The menu may have replaced an alert that temporarily revealed a hidden or
		-- collapsed dock. Reuse the alert's proven restoration path when the menu
		-- closes; a manual layout choice marks this snapshot cancelled first.
		self.alertPending = alertRestore
		self:DismissAlert(true)
	elseif wasShown then
		self:RefreshTransientMessageLayout()
	end
end

function Dock:RefreshPlayerActionDismissal()
	if not frameIsShown(self.playerActions) then
		self.playerActionAutoHideRemaining = nil
		self.playerActionMouseWasDown = nil
		return false
	end
	local settings = self:GetPlayerActionMenuSettings()
	self.playerActionAutoHideRemaining = settings.autoHide and settings.autoHideSeconds or nil
	-- Snapshot the opening/configuration click.  Only a later up-to-down edge is
	-- allowed to dismiss, so the hyperlink that showed the menu cannot also eat it.
	self.playerActionMouseWasDown = isAnyMouseButtonDown()
	return true
end

function Dock:UpdatePlayerActionDismissal(elapsed)
	local panel = self.playerActions
	if not frameIsShown(panel) then
		return false
	end

	local mouseDown = isAnyMouseButtonDown()
	local wasDown = self.playerActionMouseWasDown
	if wasDown == nil then
		wasDown = mouseDown
	end
	if mouseDown and not wasDown then
		local inside = panel.IsMouseOver and panel:IsMouseOver()
		if not inside then
			self:HidePlayerActions()
			return false
		end
	end
	self.playerActionMouseWasDown = mouseDown

	if self.playerActionAutoHideRemaining then
		self.playerActionAutoHideRemaining = self.playerActionAutoHideRemaining - (tonumber(elapsed) or 0)
		if self.playerActionAutoHideRemaining <= 0 then
			self:HidePlayerActions()
			return false
		end
	end
	return true
end

function Dock:RefreshPlayerActionsLayout(skipViewportRefresh)
	local panel = self.playerActions
	local buttons = self.playerActionButtons
	if not panel or not buttons or #buttons == 0 then
		return false
	end

	local requiredWidth = PLAYER_ACTION_PANEL_PADDING * 2
	for index = 1, #buttons do
		requiredWidth = requiredWidth + (tonumber(buttons[index]:GetWidth()) or 0)
		if index > 1 then
			requiredWidth = requiredWidth + PLAYER_ACTION_BUTTON_GAP
		end
	end
	local availableWidth = panel.GetWidth and tonumber(panel:GetWidth()) or nil
	if not availableWidth or availableWidth <= 0 then
		availableWidth = self.content and self.content.GetWidth and tonumber(self.content:GetWidth()) or 0
	end
	local compact = availableWidth <= 0 or availableWidth < requiredWidth
	panel:SetHeight(compact and PLAYER_ACTION_PANEL_COMPACT_HEIGHT or PLAYER_ACTION_PANEL_WIDE_HEIGHT)

	for index = 1, #buttons do
		buttons[index]:ClearAllPoints()
	end
	local function anchorRow(firstIndex, lastIndex, bottom)
		local previous
		for index = firstIndex, lastIndex do
			local button = buttons[index]
			if previous then
				button:SetPoint("LEFT", previous, "RIGHT", PLAYER_ACTION_BUTTON_GAP, 0)
			else
				button:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PLAYER_ACTION_PANEL_PADDING, bottom)
			end
			previous = button
		end
	end
	if compact then
		anchorRow(1, math.min(3, #buttons), 24)
		if #buttons > 3 then
			anchorRow(4, #buttons, PLAYER_ACTION_PANEL_PADDING)
		end
	else
		anchorRow(1, #buttons, PLAYER_ACTION_PANEL_PADDING)
	end
	self.playerActionCompactLayout = compact
	if frameIsShown(panel) and not skipViewportRefresh then
		self:RefreshTransientMessageLayout()
	end
	return true, compact, requiredWidth, availableWidth
end

function Dock:SetConversationTarget(record)
	self.lastConversationTarget = record and record.sender or nil
	if self.lastConversationTarget then
		if addon.ConversationWindows and addon.ConversationWindows.enabled then
			local window, reason = addon.ConversationWindows:OpenForPlayer(self.lastConversationTarget)
			if window or reason == "deferred" then
				self:HidePlayerActions()
				return
			end
		end
		self:SelectView("conversations")
		self:ActivateComposer()
	end
end

function Dock:ShowIgnoreConfirmation(record)
	self.ignoreRecord = record
	self.ignoreConfirmText:SetText("Add " .. record.sender .. " to the actual WoW ignore list?")
	self.ignoreConfirm:Show()
end

function Dock:ShowPlayerActions(record)
	if not record or not record.sender then
		return
	end
	-- A deliberate player-name click supersedes an automatic notice. Keeping one
	-- transient lane at a time guarantees useful message height at the supported
	-- minimum dock size and avoids stacked context surfaces.
	if self.alertActive then
		local alertRestore = self.alertPending
		self:DismissAlert(false)
		self.playerActionAlertRestore = alertRestore
	end
	self.actionRecord = record
	self.playerActionName:SetText("PLAYER: " .. record.sender)
	self.playerActions:Show()
	self:RefreshPlayerActionsLayout(true)
	self:RefreshTransientMessageLayout()
	self:RefreshPlayerActionDismissal()
end

function Dock:HandleHyperlink(link, text, button)
	local recordId = string.match(link or "", "^ccbbplayer:(%d+)$")
	if recordId then
		self:ShowPlayerActions(addon.MessageEngine:GetMessageById(recordId))
		return
	end
	if ChatFrame_OnHyperlinkShow then
		ChatFrame_OnHyperlinkShow(self.display, link, text, button)
	elseif SetItemRef then
		SetItemRef(link, text, button)
	end
end

function Dock:BuildPlayerActions()
	local panel = Theme:CreatePanel(self.frame, "surfaceRaised", "gold")
	panel:SetPoint("BOTTOMLEFT", self.content, "BOTTOMLEFT", 2, 2)
	panel:SetPoint("BOTTOMRIGHT", self.content, "BOTTOMRIGHT", -2, 2)
	panel:SetHeight(PLAYER_ACTION_PANEL_WIDE_HEIGHT)
	panel:SetFrameLevel(self.frame:GetFrameLevel() + 20)
	panel:EnableMouse(true)
	panel:Hide()
	panel:SetScript("OnUpdate", function(_, elapsed)
		Dock:UpdatePlayerActionDismissal(elapsed)
	end)
	self.playerActions = panel
	self:BindHeaderHover(panel)

	local close = createTightButton(panel, "X", PLAYER_ACTION_BUTTON_HEIGHT, false)
	close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
	close:SetScript("OnClick", function()
		Dock:HidePlayerActions()
	end)
	self.playerActionClose = close
	self:BindHeaderHover(close)
	self:BindDockControlTooltip(close, "Close player actions", "Close this player menu without running an action.")

	local name = Theme:CreateText(panel, "GameFontNormalSmall", "goldBright")
	name:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, -5)
	name:SetPoint("TOPRIGHT", close, "TOPLEFT", -4, 0)
	name:SetHeight(PLAYER_ACTION_BUTTON_HEIGHT)
	name:SetJustifyH("LEFT")
	if name.SetWordWrap then name:SetWordWrap(false) end
	self.playerActionName = name

	local actions = {
		{
			label = "WHISPER",
			tooltip = "Open this player's Chatty whisper conversation and focus the reply box.",
			action = function(record) Dock:SetConversationTarget(record) end,
		},
		{
			label = "INVITE",
			tooltip = "Invite this player to your group.",
			action = function(record) addon.Compatibility:InvitePlayer(record.sender) end,
		},
		{
			label = "ADD FRIEND",
			tooltip = "Add this player to WoW's Friends list.",
			action = function(record) addon.Compatibility:AddFriend(record.sender) end,
		},
		{
			label = "CHATTY MUTE",
			tooltip = "Hide this player's messages in Chatty only. This does not change WoW Ignore.",
			action = function(record)
			local settings = addon:GetSmartSettings()
			settings.safety.localIgnores = settings.safety.localIgnores or {}
			settings.safety.localIgnores[cleanName(record.sender)] = true
			Dock:RebuildActiveView()
		end,
		},
		{
			label = "WOW IGNORE",
			tooltip = "Add this player to WoW's server-side Ignore list. Confirmation follows when enabled.",
			action = function(record)
			if addon:GetSmartSettings().safety.confirmServerIgnore then
				Dock:ShowIgnoreConfirmation(record)
			else
				addon.Compatibility:AddServerIgnore(record.sender)
			end
		end,
		},
	}
	self.playerActionDefinitions = actions
	self.playerActionButtons = {}
	for index = 1, #actions do
		local action = actions[index]
		local button = createTightButton(panel, action.label, PLAYER_ACTION_BUTTON_HEIGHT, index == 1)
		button:SetScript("OnClick", function()
			local record = Dock.actionRecord
			if not record then return end
			-- These are one-shot context actions. Capture the exact linked record,
			-- close the menu, then dispatch so INVITE/ADD FRIEND cannot linger and a
			-- WoW Ignore confirmation can replace the lower surface cleanly.
			Dock:HidePlayerActions()
			action.action(record)
		end)
		self:BindHeaderHover(button)
		self:BindDockControlTooltip(button, action.label, action.tooltip)
		self.playerActionButtons[index] = button
	end
	self:RefreshPlayerActionsLayout()

	local confirm = Theme:CreatePanel(self.frame, "background", "danger")
	confirm:SetSize(330, 104)
	confirm:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
	confirm:SetFrameLevel(self.frame:GetFrameLevel() + 30)
	confirm:Hide()
	self.ignoreConfirm = confirm
	self:BindHeaderHover(confirm)
	local title = Theme:CreateText(confirm, "GameFontNormalLarge", "danger")
	title:SetPoint("TOPLEFT", confirm, "TOPLEFT", 8, -8)
	title:SetText("WoW Ignore")
	local confirmText = Theme:CreateText(confirm, "GameFontHighlightSmall", "text")
	confirmText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	confirmText:SetWidth(314)
	confirmText:SetJustifyH("LEFT")
	self.ignoreConfirmText = confirmText
	local cancel = createTightButton(confirm, "CANCEL", 20, false)
	cancel:SetPoint("BOTTOMLEFT", confirm, "BOTTOMLEFT", 8, 8)
	cancel:SetScript("OnClick", function()
		Dock.ignoreRecord = nil
		confirm:Hide()
	end)
	self:BindHeaderHover(cancel)
	local ignore = createTightButton(confirm, "ADD TO WOW IGNORE", 20, true)
	ignore:SetPoint("BOTTOMRIGHT", confirm, "BOTTOMRIGHT", -8, 8)
	ignore:SetScript("OnClick", function()
		if Dock.ignoreRecord then
			addon.Compatibility:AddServerIgnore(Dock.ignoreRecord.sender)
		end
		Dock.ignoreRecord = nil
		confirm:Hide()
		Dock:HidePlayerActions()
	end)
	self:BindHeaderHover(ignore)
end

function Dock:BuildMessageBlockControls()
	-- This is deliberately an overlay, not markup inserted into each line.  The
	-- ordinary chat surface stays clean until a player deliberately holds Shift.
	local action = createTightButton(self.content, "BLOCK", 18, true)
	action:SetFrameLevel(self.content:GetFrameLevel() + 18)
	if action.RegisterForClicks then
		action:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	end
	action:Hide()
	action:SetScript("OnClick", function(_, button)
		Dock:HideDisplayHoverHint()
		local record = Dock.blockActionRecord
		if button == "RightButton" then
			Dock:ShowMessageBlockChoices(record)
		else
			Dock:ApplyMessageBlock(record, "exact")
		end
	end)
	action:HookScript("OnEnter", function(self)
		Dock:HideDisplayHoverHint()
		Dock:ScheduleMessageBlockActionRefresh()
		if GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:AddLine("Block this message", 1, 0.82, 0.26)
			GameTooltip:AddLine("Left click: this player + exact text. Right click: choose exact or contains.", 0.56, 0.63, 0.71, true)
			GameTooltip:Show()
		end
	end)
	action:HookScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
		Dock:ScheduleMessageBlockActionRefresh(true)
	end)
	self.blockAction = action
	self:BindHeaderHover(action)

	local analyze = createTightButton(self.content, "ANALYZE", 18, false)
	analyze:SetFrameLevel(self.content:GetFrameLevel() + 18)
	analyze:Hide()
	analyze:SetScript("OnClick", function()
		Dock:ShowMessageAnalysis(Dock.analysisActionRecord)
	end)
	analyze:HookScript("OnEnter", function(self)
		Dock:HideDisplayHoverHint()
		Dock:ScheduleMessageBlockActionRefresh()
		if GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:AddLine("Explain this route", 1, 0.82, 0.26)
			GameTooltip:AddLine("Shows the source, final tab, and LFG/trade signals Chatty matched. It never changes a rule.", 0.56, 0.63, 0.71, true)
			GameTooltip:Show()
		end
	end)
	analyze:HookScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
		Dock:ScheduleMessageBlockActionRefresh(true)
	end)
	self.analysisAction = analyze
	self:BindHeaderHover(analyze)

	local choices = Theme:CreatePanel(self.content, "surfaceRaised", "gold")
	choices:SetHeight(22)
	choices:SetFrameLevel(self.content:GetFrameLevel() + 19)
	choices:Hide()
	self.blockChoices = choices
	self:BindHeaderHover(choices)
	choices:HookScript("OnEnter", function()
		Dock:HideDisplayHoverHint()
		Dock:ScheduleMessageBlockActionRefresh()
	end)
	choices:HookScript("OnLeave", function()
		Dock:ScheduleMessageBlockActionRefresh(true)
	end)

	local exact = createTightButton(choices, "EXACT", 18, true)
	exact:SetPoint("LEFT", choices, "LEFT", 2, 0)
	exact:SetScript("OnClick", function()
		Dock:ApplyMessageBlock(Dock.blockChoicesRecord, "exact")
	end)
	exact:HookScript("OnEnter", function(self)
		if GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine("Exact text", 1, 0.82, 0.26)
			GameTooltip:AddLine("Hide this player's exact message in this source.", 0.56, 0.63, 0.71, true)
			GameTooltip:Show()
		end
	end)
	exact:HookScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)
	self:BindHeaderHover(exact)

	local contains = createTightButton(choices, "CONTAINS", 18, false)
	contains:SetPoint("LEFT", exact, "RIGHT", 2, 0)
	contains:SetScript("OnClick", function()
		Dock:ApplyMessageBlock(Dock.blockChoicesRecord, "contains")
	end)
	contains:HookScript("OnEnter", function(self)
		if GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine("Contains these words", 1, 0.82, 0.26)
			GameTooltip:AddLine("Hide this player's messages here that contain this text.", 0.56, 0.63, 0.71, true)
			GameTooltip:Show()
		end
	end)
	contains:HookScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)
	self:BindHeaderHover(contains)

	local close = createTightButton(choices, "X", 18, false)
	close:SetPoint("LEFT", contains, "RIGHT", 2, 0)
	close:SetScript("OnClick", function()
		Dock:HideMessageBlockControls()
	end)
	self:BindHeaderHover(close)
	choices:SetWidth(2 + exact:GetWidth() + 2 + contains:GetWidth() + 2 + close:GetWidth() + 2)

	local analysisPanel = Theme:CreatePanel(self.content, "surfaceRaised", "gold")
	analysisPanel:SetSize(356, 154)
	analysisPanel:SetFrameLevel(self.content:GetFrameLevel() + 22)
	analysisPanel:EnableMouse(true)
	analysisPanel:Hide()
	self.analysisPanel = analysisPanel
	self:BindHeaderHover(analysisPanel)
	analysisPanel:HookScript("OnEnter", function()
		Dock:HideDisplayHoverHint()
		Dock:ScheduleMessageBlockActionRefresh()
	end)
	analysisPanel:HookScript("OnLeave", function()
		Dock:ScheduleMessageBlockActionRefresh(true)
	end)

	local analysisTitle = Theme:CreateText(analysisPanel, "GameFontNormalSmall", "goldBright")
	analysisTitle:SetPoint("TOPLEFT", analysisPanel, "TOPLEFT", 7, -6)
	analysisTitle:SetText("MESSAGE ANALYSIS")
	local analysisClose = createTightButton(analysisPanel, "CLOSE", 18, false)
	analysisClose:SetPoint("TOPRIGHT", analysisPanel, "TOPRIGHT", -4, -3)
	analysisClose:SetScript("OnClick", function()
		Dock:HideMessageBlockControls()
	end)
	self:BindHeaderHover(analysisClose)

	local function addAnalysisRow(labelText, top)
		local label = Theme:CreateText(analysisPanel, "GameFontNormalSmall", "gold")
		label:SetPoint("TOPLEFT", analysisPanel, "TOPLEFT", 7, top)
		label:SetWidth(54)
		label:SetJustifyH("LEFT")
		label:SetText(labelText)
		local value = Theme:CreateText(analysisPanel, "GameFontHighlightSmall", "text")
		value:SetPoint("TOPLEFT", analysisPanel, "TOPLEFT", 63, top)
		value:SetPoint("RIGHT", analysisPanel, "RIGHT", -7, 0)
		value:SetJustifyH("LEFT")
		if value.SetWordWrap then value:SetWordWrap(false) end
		local hit = CreateFrame("Frame", nil, analysisPanel)
		hit:SetPoint("TOPLEFT", analysisPanel, "TOPLEFT", 63, top)
		hit:SetPoint("RIGHT", analysisPanel, "RIGHT", -7, 0)
		hit:SetHeight(18)
		hit:EnableMouse(true)
		hit.analysisTooltipTitle = labelText
		hit:SetScript("OnEnter", function(self)
			if not GameTooltip then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.analysisTooltipTitle or "Message analysis", 1, 0.82, 0.3, true)
			GameTooltip:AddLine(self.analysisFullText or "", 0.82, 0.84, 0.9, true)
			GameTooltip:Show()
		end)
		hit:SetScript("OnLeave", function(self)
			if GameTooltip and (not GameTooltip.GetOwner or GameTooltip:GetOwner() == self) then GameTooltip:Hide() end
		end)
		self:BindHeaderHover(hit)
		value.analysisHit = hit
		return value
	end
	self.analysisSource = addAnalysisRow("SOURCE", -30)
	self.analysisRoute = addAnalysisRow("ROUTE", -52)
	self.analysisSignals = addAnalysisRow("MATCH", -74)
	self.analysisWhy = addAnalysisRow("WHY", -96)
	local analysisFootnote = Theme:CreateText(analysisPanel, "GameFontHighlightSmall", "textMuted")
	analysisFootnote:SetPoint("BOTTOMLEFT", analysisPanel, "BOTTOMLEFT", 7, 29)
	analysisFootnote:SetText("Exact public text only; case and extra spaces are ignored.")
	self.analysisFootnote = analysisFootnote

	local routeTo = Theme:CreateText(analysisPanel, "GameFontNormalSmall", "gold")
	routeTo:SetPoint("BOTTOMLEFT", analysisPanel, "BOTTOMLEFT", 7, 7)
	routeTo:SetText("TO:")
	local routeSelector = Theme:CreateButton(analysisPanel, "GENERAL v", 148, 18, false)
	routeSelector:SetPoint("LEFT", routeTo, "RIGHT", 3, 0)
	routeSelector:SetScript("OnClick", function()
		Dock:ToggleMessageRouteOverrideMenu()
	end)
	self:BindHeaderHover(routeSelector)
	local moveRoute = createTightButton(analysisPanel, "MOVE", 18, true)
	moveRoute:SetPoint("LEFT", routeSelector, "RIGHT", 2, 0)
	moveRoute:SetScript("OnClick", function()
		Dock:MoveSelectedMessageRouteOverride()
	end)
	self:BindHeaderHover(moveRoute)
	local removeRoute = createTightButton(analysisPanel, "UNDO", 18, false)
	removeRoute:SetPoint("LEFT", moveRoute, "RIGHT", 2, 0)
	removeRoute:SetScript("OnClick", function()
		Dock:RemoveMessageRouteOverride()
	end)
	self:BindHeaderHover(removeRoute)
	self.analysisRouteSelector = routeSelector
	self.analysisRouteMove = moveRoute
	self.analysisRouteControls = { routeTo, routeSelector, moveRoute }
	self.analysisRemoveOverride = removeRoute

	-- A real compact selector keeps exact-message corrections readable.  It
	-- deliberately lists only destinations that make sense for public-channel
	-- traffic; SYNC and private/social tabs retain their protected semantics.
	local routeMenu = Theme:CreatePanel(analysisPanel, "surfaceRaised", "gold")
	routeMenu:SetWidth(292)
	routeMenu:SetHeight(1)
	routeMenu:SetFrameStrata(analysisPanel:GetFrameStrata())
	routeMenu:SetFrameLevel(analysisPanel:GetFrameLevel() + 3)
	routeMenu:EnableMouse(true)
	routeMenu:Hide()
	self.analysisRouteMenu = routeMenu
	self.analysisRouteMenuButtons = {}
	for index = 1, #fallbackMessageRouteDestinations do
		local choice = Theme:CreateButton(routeMenu, "", 140, 18, false)
		local row = math.floor((index - 1) / 2)
		local column = (index - 1) % 2
		choice:SetPoint("TOPLEFT", routeMenu, "TOPLEFT", 4 + (column * 144), -4 - (row * 20))
		choice:SetScript("OnClick", function(button)
			local destination = button.routeDestination
			if destination and Dock:SetMessageRouteOverrideDestination(destination.id) then
				Dock:HideMessageRouteOverrideMenu()
			end
		end)
		self:BindHeaderHover(choice)
		self.analysisRouteMenuButtons[index] = choice
	end
	routeMenu:HookScript("OnEnter", function()
		Dock:HideDisplayHoverHint()
		Dock:ScheduleMessageBlockActionRefresh()
	end)
	routeMenu:HookScript("OnLeave", function()
		Dock:ScheduleMessageBlockActionRefresh(true)
	end)
end

function Dock:BuildSourceColumnAlignmentControl()
	-- SHIFT exposes one named route to the persistent alignment editor. Changing
	-- channel/name alignment from anonymous boxes made global state look local,
	-- so the live surface is now informational and never mutates either setting.
	local button = createTightButton(self.content, "ALIGN SETTINGS", 18, false)
	button:SetFrameLevel(self.content:GetFrameLevel() + 17)
	if self.messageScrollbar then
		button:SetPoint("TOPRIGHT", self.messageScrollbar, "TOPLEFT", -ALIGNMENT_SETTINGS_CONTROL_GAP, 0)
	else
		button:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -ALIGNMENT_SETTINGS_CONTROL_GAP,
			-ALIGNMENT_SETTINGS_CONTROL_GAP)
	end
	button:Hide()
	button:SetScript("OnClick", function()
		Dock:OpenGlobalTextAlignmentSettings()
	end)
	button:HookScript("OnEnter", function()
		Dock:HideDisplayHoverHint()
		Dock:ScheduleMessageBlockActionRefresh()
	end)
	button:HookScript("OnLeave", function()
		Dock:ScheduleMessageBlockActionRefresh(true)
	end)
	self:BindHeaderHover(button)
	self:BindDockControlTooltip(button, "Alignment settings", function()
		return "Open Views & Tabs > Global Text to change ALIGN CHANNELS and ALIGN NAMES.\n\n"
			.. Dock:GetColumnAlignmentDiagnostics()
	end)
	self.columnAlignmentSettingsButton = button
end

function Dock:BuildChatHelpMenu()
	if self.chatHelpTrigger or not self.content then
		return self.chatHelpMenu
	end

	-- The trigger appears only after a short rest over readable chat, replacing
	-- the old forced tooltip. It is intentionally small and in the top-left
	-- corner so it does not compete with the scroll, BLOCK, or SHIFT alignment
	-- settings shortcut on the right side.
	local trigger = createTightButton(self.content, "? HELP", 18, false)
	trigger:SetPoint("TOPLEFT", self.content, "TOPLEFT", 3, -2)
	trigger:SetFrameLevel(self.content:GetFrameLevel() + 20)
	trigger:Hide()
	trigger:SetScript("OnClick", function()
		Dock:ToggleChatHelpMenu()
	end)
	self.chatHelpTrigger = trigger
	self:BindHeaderHover(trigger)
	self:BindDockControlTooltip(trigger, "Chat help", "Open a compact guide to Chatty's tabs, messages, window controls, and SHIFT gestures.")

	local menu = Theme:CreatePanel(self.content, "surfaceRaised", "gold")
	menu:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, -4)
	menu:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -4, -4)
	menu:SetHeight(166)
	menu:SetFrameLevel(self.content:GetFrameLevel() + 24)
	menu:EnableMouse(true)
	menu:Hide()
	self.chatHelpMenu = menu
	self:BindHeaderHover(menu)

	local title = Theme:CreateText(menu, "GameFontNormalSmall", "goldBright")
	title:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -6)
	self.chatHelpTitle = title
	local subtitle = Theme:CreateText(menu, "GameFontHighlightSmall", "textMuted")
	subtitle:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -8, -6)
	subtitle:SetText("HOW TO USE CHATTY")
	self.chatHelpSubtitle = subtitle

	self.chatHelpRows = {}
	for index = 1, 4 do
		local row = CreateFrame("Frame", nil, menu)
		row:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -29 - ((index - 1) * 27))
		row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -8, -29 - ((index - 1) * 27))
		row:SetHeight(25)
		local label = Theme:CreateText(row, "GameFontNormalSmall", "gold")
		label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		label:SetWidth(59)
		label:SetJustifyH("LEFT")
		local detail = Theme:CreateText(row, "GameFontHighlightSmall", "text")
		detail:SetPoint("TOPLEFT", row, "TOPLEFT", 62, 0)
		detail:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		detail:SetJustifyH("LEFT")
		if detail.SetWordWrap then detail:SetWordWrap(true) end
		row.label = label
		row.detail = detail
		self.chatHelpRows[index] = row
	end

	local openSettings = createTightButton(menu, "OPEN SETTINGS", 18, true)
	openSettings:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 6, 4)
	openSettings:SetScript("OnClick", function()
		Dock:HideChatHelpMenu(false)
		addon:OpenConfig()
	end)
	self.chatHelpOpenSettings = openSettings
	self:BindHeaderHover(openSettings)

	local close = createTightButton(menu, "CLOSE", 18, false)
	close:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -6, 4)
	close:SetScript("OnClick", function()
		Dock:HideChatHelpMenu(true)
	end)
	self.chatHelpClose = close
	self:BindHeaderHover(close)

	local pageText = Theme:CreateText(menu, "GameFontHighlightSmall", "textMuted")
	pageText:SetPoint("BOTTOM", menu, "BOTTOM", 0, 7)
	pageText:SetJustifyH("CENTER")
	self.chatHelpPageText = pageText
	local previous = createTightButton(menu, "<", 18, false)
	previous:SetPoint("RIGHT", pageText, "LEFT", -4, 0)
	previous:SetScript("OnClick", function()
		Dock.chatHelpPage = math.max(1, (tonumber(Dock.chatHelpPage) or 1) - 1)
		Dock:RefreshChatHelpMenu()
	end)
	self.chatHelpPrevious = previous
	self:BindHeaderHover(previous)
	local nextButton = createTightButton(menu, ">", 18, false)
	nextButton:SetPoint("LEFT", pageText, "RIGHT", 4, 0)
	nextButton:SetScript("OnClick", function()
		Dock.chatHelpPage = math.min(2, (tonumber(Dock.chatHelpPage) or 1) + 1)
		Dock:RefreshChatHelpMenu()
	end)
	self.chatHelpNext = nextButton
	self:BindHeaderHover(nextButton)

	menu:HookScript("OnShow", function()
		Dock.displayHintShown = false
		Dock.displayHintOwner = nil
		if Dock.chatHelpTrigger then Dock.chatHelpTrigger:Show() end
		Dock:RefreshChatHelpMenu()
	end)
	return menu
end

function Dock:Build()
	if self.frame and self.built then
		return true
	end
	if self.frame then
		self:DiscardPartialBuild()
	end
	local _, _, _, _, width, height = getGeometry()

	local frame = Theme:CreatePanel(UIParent, "background", "border")
	self.frame = frame
	frame:Hide()
	frame:SetSize(width, height)
	applyGeometry(frame)
	frame:SetMinResize(EXPANDED_MIN_WIDTH, EXPANDED_MIN_HEIGHT)
	frame:SetMaxResize(EXPANDED_MAX_WIDTH, EXPANDED_MAX_HEIGHT)
	frame:SetResizable(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:SetFrameStrata("MEDIUM")
	frame:EnableMouse(true)
	frame:SetScript("OnEnter", function()
		if Dock.active then
			Dock:CancelHeaderHoverRefresh()
			Dock:SetHeaderHover(true)
		end
	end)
	frame:SetScript("OnLeave", function()
		if Dock.active then
			Dock:ScheduleHeaderHoverRefresh()
		end
	end)
	frame:SetScript("OnShow", function()
		-- A dock can be shown underneath a stationary cursor (for example from
		-- an alert). Reapply immediately so an Always header returns with the
		-- frame, then check on the next frame so hover-only chrome and the
		-- mouseover Chat Tabs Rail still honor a stationary cursor.
		if Dock.active then
			Dock:SyncDockHoverState()
			Dock:ApplyLayout()
			Dock:ScheduleHeaderHoverRefresh(0)
		end
	end)
	frame:SetScript("OnHide", function()
		Dock:CancelHeaderHoverRefresh()
		Dock:CancelResize()
		Dock:CancelRailTabReorder(false)
		Dock:CancelRailMove(false)
		Dock:CancelNewMessageIndicatorMove(false)
		Dock:HideChatHelpMenu(false)
		Dock:HideDisplayHoverHint()
		Dock:HideMessageBlockControls()
		Dock:HidePlayerActions()
		Dock.headerHover = false
		Dock.railMouseoverRevealed = false
		Dock.headerDragActive = false
		if Dock.header and not Dock:IsCollapsed() then
			Dock.header:Hide()
		end
	end)
	frame:SetScript("OnSizeChanged", function()
		if Dock.built then
			Dock:RefreshComposerLayout()
			-- Player-menu geometry and the shared message lane are separate jobs:
			-- alerts also reserve that lane, even while the player menu is hidden.
			Dock:RefreshPlayerActionsLayout(true)
			Dock:RefreshTransientMessageLayout(Dock.resizeDragRegion ~= nil)
			if Dock.analysisPanel and frameIsShown(Dock.analysisPanel) then
				Dock:RefreshMessageAnalysisLayout()
			end
			Dock:UpdateHeaderTextLayout()
			-- Explicit wrapped text is rebuilt once when a resize commits. Hide the
			-- old geometry during the drag; ordinary layout changes can repaint now.
			if Dock.resizeDragRegion then
				Dock:HideMessageBands()
				Dock:HideMessageActionHighlight()
			else
				-- Width changes rebuild explicit wraps; height-only changes still alter
				-- which logical line spans are visible and therefore must rescope the
				-- optional visible-only alignment immediately.
				if not Dock:RefreshDisplayWidthPresentation() then
					Dock:HandleDisplayViewportChanged()
				end
			end
		end
	end)

	local header = Theme:CreatePanel(frame, "surfaceRaised", "borderMuted")
	header:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
	header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
	header:SetHeight(24)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function()
		if not addon:GetSmartSettings().dock.locked then
			Dock.headerDragActive = true
			Dock:CancelHeaderHoverRefresh()
			Dock:SetHeaderHover(true)
			frame:StartMoving()
		end
	end)
	header:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		Dock.headerDragActive = false
		Dock:ScheduleHeaderHoverRefresh(0)
		Dock:SaveGeometry()
	end)
	self.header = header
	self:BindHeaderHover(header)

	local icon = header:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(Theme.ICON_PATH)
	icon:SetSize(16, 16)
	icon:SetPoint("LEFT", header, "LEFT", 3, 0)
	self.headerIcon = icon

	local title = Theme:CreateText(header, "GameFontNormalSmall", "goldBright")
	title:SetPoint("LEFT", icon, "RIGHT", 4, 0)
	if title.SetWordWrap then title:SetWordWrap(false) end
	self.title = title
	local subtitle = Theme:CreateText(header, "GameFontHighlightSmall", "textMuted")
	subtitle:SetPoint("LEFT", title, "RIGHT", 4, 0)
	subtitle:SetJustifyH("LEFT")
	if subtitle.SetWordWrap then subtitle:SetWordWrap(false) end
	subtitle:Hide()
	self.subtitle = subtitle

	local settingsButton = createTightButton(header, "CFG", 18, false)
	settingsButton:SetPoint("RIGHT", header, "RIGHT", -2, 0)
	settingsButton:SetScript("OnClick", function()
		addon:OpenConfig()
	end)
	self.settingsButton = settingsButton
	self:BindHeaderHover(settingsButton)
	self:BindDockControlTooltip(settingsButton, "Chatty settings", "Open the ChattyChattyBangBang control center.")

	local hideButton = createTightButton(header, "X", 18, false)
	hideButton:SetPoint("RIGHT", settingsButton, "LEFT", -2, 0)
	hideButton:SetScript("OnClick", function()
		Dock:SetVisible(false, true)
	end)
	self.hideButton = hideButton
	self:BindHeaderHover(hideButton)
	self:BindDockControlTooltip(hideButton, "Hide chat dock", "Hide this dock until you show it again from the launcher.")

	local collapseButton = createTightButton(header, "-", 18, false)
	collapseButton:SetPoint("RIGHT", hideButton, "LEFT", -2, 0)
	collapseButton:SetScript("OnClick", function()
		Dock:ToggleCollapsed()
	end)
	self.collapseButton = collapseButton
	self:BindHeaderHover(collapseButton)
	self:BindDockControlTooltip(collapseButton, function()
		return Dock:IsCollapsed() and "Expand chat dock" or "Collapse chat dock"
	end)

	local newButton = createTightButton(header, "NEW", 18, true)
	newButton:SetPoint("RIGHT", collapseButton, "LEFT", -2, 0)
	newButton:SetScript("OnClick", function()
		if Dock:ShouldSuppressNewMessageIndicatorClick() then
			return
		end
		Dock.display:ScrollToBottom()
		Dock:HandleDisplayViewportChanged()
		Dock:ClearPendingMessages()
	end)
	newButton:SetScript("OnMouseDown", function(_, mouseButton)
		if mouseButton == "LeftButton" then
			Dock:BeginNewMessageIndicatorMoveCandidate()
		end
	end)
	newButton:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton ~= "LeftButton" or not Dock.newMessageIndicatorMove then
			return
		end
		if isShiftDown() then
			Dock:UpdateNewMessageIndicatorMove()
			Dock:EndNewMessageIndicatorMove()
		else
			Dock:CancelNewMessageIndicatorMove(true)
		end
	end)
	newButton:Hide()
	self.newButton = newButton
	self.newMessageIndicatorDefaultFontObject = GameFontNormalSmall
	self.newMessageIndicatorDefaultFontPath,
		self.newMessageIndicatorDefaultFontSize,
		self.newMessageIndicatorDefaultFontFlags = getFontObjectAttributes(newButton.text)
	newButton:HookScript("OnEnter", function()
		Dock:ApplyNewMessageIndicatorAppearance()
	end)
	newButton:HookScript("OnLeave", function()
		Dock:ApplyNewMessageIndicatorAppearance()
	end)
	self:BindHeaderHover(newButton)
	self:BindDockControlTooltip(newButton, "Newest messages", "Click: jump to newest. SHIFT-drag: move this marker inside the chat dock.")
	title:SetPoint("RIGHT", newButton, "LEFT", -2, 0)

	local rail = Theme:CreatePanel(frame, "inset", "borderMuted")
	rail:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
	rail:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 28)
	rail:SetWidth(42)
	self.rail = rail
	self:BindHeaderHover(rail)
	self:BindRailBackgroundDrag(rail)
	self:BindRailMouseWheel(rail)
	-- A two-pixel marker is all the drag chrome needs. It lives in a dedicated
	-- non-interactive overlay above the scrolled tab buttons, so it remains
	-- visible at either scroll edge without becoming another hit target.
	local railReorderOverlay = CreateFrame("Frame", nil, rail)
	railReorderOverlay:SetAllPoints(rail)
	railReorderOverlay:EnableMouse(false)
	railReorderOverlay:SetFrameLevel(rail:GetFrameLevel() + 6)
	self.railTabReorderOverlay = railReorderOverlay
	local railReorderMarker = railReorderOverlay:CreateTexture(nil, "OVERLAY")
	railReorderMarker:SetTexture("Interface\\Buttons\\WHITE8x8")
	Theme:RegisterTexture(railReorderMarker, "goldBright")
	railReorderMarker:Hide()
	self.railTabReorderMarker = railReorderMarker
	if rail.HookScript then
		rail:HookScript("OnMouseUp", function(_, mouseButton)
			Dock:HandleRailTabMouseUp(nil, mouseButton)
		end)
	end

	-- The settings action belongs to the Chat Tabs Rail as a trailing control:
	-- right edge in horizontal mode, bottom/end in vertical mode.  It lives
	-- outside the scrolling tab content so it remains reachable when a long
	-- custom rail list scrolls past.
	-- This must stay a naked Button, not a themed action button.  The authored
	-- artwork provides normal/hover/pressed feedback; a Theme button would add
	-- a backdrop and border around it, making the rail end look like a boxed
	-- control instead of a clean settings glyph.
	local railSettingsButton = CreateFrame("Button", nil, rail)
	railSettingsButton:SetSize(RAIL_SETTINGS_HIT_SIZE, RAIL_SETTINGS_HIT_SIZE)
	railSettingsButton:EnableMouse(true)
	railSettingsButton:SetFrameLevel(rail:GetFrameLevel() + 2)
	-- Keep a text-only emergency fallback for a genuinely unavailable texture.
	-- It intentionally has no background or border either.
	railSettingsButton.text = Theme:CreateText(railSettingsButton, "GameFontNormalSmall", "text")
	railSettingsButton.text:SetPoint("CENTER", railSettingsButton, "CENTER", 0, 0)
	railSettingsButton.text:SetText("CFG")
	railSettingsButton.text:Hide()
	railSettingsButton.icon = railSettingsButton:CreateTexture(nil, "ARTWORK")
	railSettingsButton.icon:SetSize(RAIL_SETTINGS_ICON_SIZE, RAIL_SETTINGS_ICON_SIZE)
	railSettingsButton.icon:SetPoint("CENTER", railSettingsButton, "CENTER", 0, 0)
	self.railSettingsButton = railSettingsButton
	self:RefreshRailSettingsIcon("normal")
	railSettingsButton:SetScript("OnClick", function()
		Dock:HideDisplayHoverHint()
		addon:OpenConfig()
	end)
	if railSettingsButton.HookScript then
		railSettingsButton:HookScript("OnEnter", function(self)
			Dock:RefreshRailSettingsIcon("hover")
		end)
		railSettingsButton:HookScript("OnLeave", function(self)
			Dock:RefreshRailSettingsIcon("normal")
		end)
		railSettingsButton:HookScript("OnMouseDown", function(self)
			Dock:RefreshRailSettingsIcon("pressed")
		end)
		railSettingsButton:HookScript("OnMouseUp", function(self)
			if self.IsMouseOver and self:IsMouseOver() then
				Dock:RefreshRailSettingsIcon("hover")
			else
				Dock:RefreshRailSettingsIcon("normal")
			end
		end)
	end
	self:BindHeaderHover(railSettingsButton)
	self:BindDockControlTooltip(railSettingsButton, "Chatty settings", "Open the ChattyChattyBangBang control center.")
	self:BindRailMouseWheel(railSettingsButton)

	local railScroll = CreateFrame("ScrollFrame", nil, rail)
	railScroll:SetPoint("TOPLEFT", rail, "TOPLEFT", 2, -2)
	railScroll:SetPoint("BOTTOMRIGHT", rail, "BOTTOMRIGHT", -2, 2)
	self.railScroll = railScroll
	self:BindHeaderHover(railScroll)
	self:BindRailBackgroundDrag(railScroll)
	self:BindRailMouseWheel(railScroll)
	local railContent = CreateFrame("Frame", nil, railScroll)
	railContent:SetWidth(38)
	railContent:SetHeight(1)
	railScroll:SetScrollChild(railContent)
	self.railContent = railContent
	self:BindHeaderHover(railContent)
	self:BindRailBackgroundDrag(railContent)
	self:BindRailMouseWheel(railContent)
	if railScroll.HookScript then
		railScroll:HookScript("OnMouseUp", function(_, mouseButton)
			Dock:HandleRailTabMouseUp(nil, mouseButton)
		end)
	end
	self.railButtons = {}

	local content = Theme:CreatePanel(frame, "inset", "borderMuted")
	content:SetPoint("TOPLEFT", rail, "TOPRIGHT", 2, 0)
	content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 28)
	content:EnableMouse(true)
	self.content = content
	-- Message-band textures live on the content parent, below the child
	-- ScrollingMessageFrame. They never intercept mouse input or replace chat's
	-- native hyperlink renderer.
	self.messageBandHost = content
	self.messageBandPool = {}
	local messageActionHighlight = content:CreateTexture(nil, "ARTWORK")
	messageActionHighlight:SetTexture("Interface\\Buttons\\WHITE8x8")
	if messageActionHighlight.SetDrawLayer then
		messageActionHighlight:SetDrawLayer("ARTWORK", 2)
	end
	Theme:RegisterTexture(messageActionHighlight, "goldBright")
	if messageActionHighlight.SetAlpha then
		messageActionHighlight:SetAlpha(MESSAGE_ACTION_HIGHLIGHT_ALPHA)
	end
	messageActionHighlight:Hide()
	self.messageActionHighlight = messageActionHighlight
	self:BindHeaderHover(content)
	content:HookScript("OnEnter", function()
		Dock:ScheduleDisplayHoverHint()
		Dock:ScheduleMessageBlockActionRefresh()
	end)
	content:HookScript("OnLeave", function()
		Dock:HideDisplayHoverHint()
		Dock:ScheduleMessageBlockActionRefresh(true)
	end)
	-- Transparent measurement text mirrors the message font and width.  It is
	-- never shown; it only gives the Shift-hover overlay a reliable wrapped-line
	-- index for message records without replacing Blizzard's chat renderer.
	local measure = content:CreateFontString(nil, "BACKGROUND", "ChatFontNormal")
	measure:SetPoint("TOPLEFT", content, "TOPLEFT", -10000, 10000)
	measure:SetWidth(1)
	measure:SetJustifyH("LEFT")
	if measure.SetWordWrap then measure:SetWordWrap(true) end
	if measure.SetNonSpaceWrap then measure:SetNonSpaceWrap(true) end
	if measure.SetAlpha then measure:SetAlpha(0) end
	measure:SetText("")
	self.messageMeasure = measure

	local display = CreateFrame("ScrollingMessageFrame", nil, content)
	display:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -4)
	display:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -18, 4)
	display:SetFontObject(ChatFontNormal)
	display:SetJustifyH("LEFT")
	display:SetFading(false)
	display:SetInsertMode("BOTTOM")
	display:SetMaxLines(500)
	display:SetSpacing(1)
	-- Establish the native fallback after the font exists. RebuildActiveView
	-- switches it off when exact fixed-width aligned wrapping is active.
	self:ApplyHangingMessageWrap(display, measure)
	display:SetHyperlinksEnabled(true)
	display:EnableMouse(true)
	display:EnableMouseWheel(true)
	self:BindHeaderHover(display)
	display:HookScript("OnEnter", function()
		Dock:ScheduleDisplayHoverHint()
		Dock:ScheduleMessageBlockActionRefresh()
	end)
	display:HookScript("OnLeave", function()
		Dock:HideDisplayHoverHint()
		Dock:ScheduleMessageBlockActionRefresh(true)
	end)
	local function handleSurfaceClick(_, button)
		local overHelp = (Dock.chatHelpTrigger and Dock.chatHelpTrigger.IsMouseOver and Dock.chatHelpTrigger:IsMouseOver())
			or (Dock.chatHelpMenu and Dock.chatHelpMenu.IsMouseOver and Dock.chatHelpMenu:IsMouseOver())
		if button == "LeftButton" and not Dock.hoveredHyperlink and not overHelp then
			Dock:ToggleRailReveal()
		end
	end
	content:SetScript("OnMouseUp", handleSurfaceClick)
	display:SetScript("OnMouseUp", handleSurfaceClick)
	display:SetScript("OnMouseWheel", function(_, delta)
		Dock:HideDisplayHoverHint()
		if delta > 0 then
			display:ScrollUp()
		else
			display:ScrollDown()
		end
		Dock:HandleDisplayViewportChanged()
		if display:AtBottom() then
			Dock:ClearPendingMessages()
		end
		Dock:ScheduleMessageBlockActionRefresh()
	end)
	display:SetScript("OnHyperlinkClick", function(_, link, text, button)
		Dock:HideDisplayHoverHint()
		Dock:HandleHyperlink(link, text, button)
	end)
	display:SetScript("OnHyperlinkEnter", function(_, link)
		Dock:HideDisplayHoverHint()
		Dock.hoveredHyperlink = link or true
		Dock:ScheduleMessageBlockActionRefresh()
	end)
	display:SetScript("OnHyperlinkLeave", function()
		Dock.hoveredHyperlink = nil
		Dock:ScheduleMessageBlockActionRefresh()
	end)
	self.display = display
	-- Apply the global/default Smart Chat face immediately. SelectView reapplies
	-- this with a tab-specific override before that tab's history is drawn.
	self:ApplySmartChatTextAppearance()

	local empty = Theme:CreateText(content, "GameFontHighlight", "textMuted")
	empty:SetPoint("CENTER", content, "CENTER", 0, 0)
	empty:SetText("No messages yet.")
	self.emptyState = empty

	local messageScrollbar = Theme:CreateSlimScrollbar(content)
	messageScrollbar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -MESSAGE_SCROLLBAR_RIGHT_INSET,
		-MESSAGE_SCROLLBAR_VERTICAL_INSET)
	messageScrollbar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -MESSAGE_SCROLLBAR_RIGHT_INSET,
		MESSAGE_SCROLLBAR_VERTICAL_INSET + MESSAGE_SCROLL_TO_BOTTOM_HEIGHT + MESSAGE_SCROLL_TO_BOTTOM_GAP)
	messageScrollbar:EnableMouseWheel(true)
	messageScrollbar:SetScript("OnValueChanged", function(_, value)
		Dock:SetMessageScrollbarOffset(value)
	end)
	messageScrollbar:SetScript("OnMouseWheel", function(_, delta)
		if delta > 0 then display:ScrollUp() else display:ScrollDown() end
		Dock:HandleDisplayViewportChanged()
		if display:AtBottom() then Dock:ClearPendingMessages() end
		Dock:ScheduleMessageBlockActionRefresh()
	end)
	self.messageScrollbar = messageScrollbar
	self:BindHeaderHover(messageScrollbar)

	-- Keep the jump affordance inside the dedicated right lane instead of
	-- overlaying a readable or clickable message. The small V is the familiar
	-- scrollbar-end cue; its full meaning is stated in the hover tooltip.
	local scrollToBottom = CreateFrame("Button", nil, content)
	scrollToBottom:SetSize(MESSAGE_SCROLL_TO_BOTTOM_WIDTH, MESSAGE_SCROLL_TO_BOTTOM_HEIGHT)
	scrollToBottom:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -MESSAGE_SCROLLBAR_RIGHT_INSET,
		MESSAGE_SCROLLBAR_VERTICAL_INSET)
	scrollToBottom:SetFrameLevel(content:GetFrameLevel() + 17)
	local scrollToBottomGlyph = Theme:CreateText(scrollToBottom, "GameFontNormalSmall", "accent")
	scrollToBottomGlyph:SetAllPoints(scrollToBottom)
	scrollToBottomGlyph:SetJustifyH("CENTER")
	scrollToBottomGlyph:SetText("V")
	scrollToBottom:HookScript("OnEnter", function()
		Theme:RegisterText(scrollToBottomGlyph, "goldBright")
	end)
	scrollToBottom:HookScript("OnLeave", function()
		Theme:RegisterText(scrollToBottomGlyph, "accent")
	end)
	scrollToBottom:SetScript("OnClick", function()
		Dock:ScrollMessageDisplayToBottom()
	end)
	scrollToBottom:Hide()
	self.scrollToBottomButton = scrollToBottom
	self.scrollToBottomGlyph = scrollToBottomGlyph
	self:BindHeaderHover(scrollToBottom)
	self:BindDockControlTooltip(scrollToBottom, "Go to latest message",
		"Jumps directly to the bottom of this tab and clears its new-message marker.")

	-- Keep the typing lane part of the same dark surface as the message body.
	-- The optional field treatment below is the only element that may add its
	-- own raised background/border, controlled by TYPING FIELD BORDER.
	local composer = Theme:CreatePanel(frame, "inset", "inset")
	composer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
	composer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
	composer:SetHeight(COMPOSER_HEIGHT)
	composer:EnableMouse(true)
	composer:SetScript("OnMouseDown", function()
		-- The route selector and its menu own their own clicks. Do not turn a
		-- harmless chat-type change into an extra edit-box activation or close the
		-- selector underneath the player.
		if Dock.composerRouteButton and Dock.composerRouteButton.IsMouseOver and Dock.composerRouteButton:IsMouseOver() then
			return
		end
		if Dock.composerRouteMenu and Dock.composerRouteMenu.IsMouseOver and Dock.composerRouteMenu:IsMouseOver() then
			return
		end
		Dock:HideComposerRouteMenu()
		Dock:ActivateComposer()
	end)
	self.composer = composer
	self:BindHeaderHover(composer)
	local route = createTightButton(composer, "SAY", 20, false)
	route:SetPoint("LEFT", composer, "LEFT", 3, 0)
	route:SetWidth(COMPOSER_ROUTE_MIN_WIDTH)
	makeComposerControlIntegrated(route, "gold")
	route:SetScript("OnClick", function()
		Dock:ToggleComposerRouteMenu()
	end)
	self.composerRoute = route
	self.composerRouteButton = route
	self:BindHeaderHover(route)
	route:HookScript("OnLeave", function(self)
		Dock:ApplyComposerRouteTextColor(self, self.composerRouteKind, self.composerRouteTarget)
	end)
	self:BindDockControlTooltip(route, "Chat type", "Choose Say, Group, Guild, Reply, or a joined channel. Your choice stays with this tab for this session.")
	local routeAccent = composer:CreateTexture(nil, "ARTWORK")
	routeAccent:SetTexture("Interface\\Buttons\\WHITE8x8")
	routeAccent:SetWidth(1)
	Theme:RegisterTexture(routeAccent, "accent")
	self.composerRouteAccent = routeAccent
	local placeholder = Theme:CreateText(composer, "GameFontHighlightSmall", "textMuted")
	placeholder:SetJustifyH("LEFT")
	self.composerPlaceholder = placeholder
	local send = createTightButton(composer, ">", 18, true)
	-- The old 14px reservation existed solely to clear the resize target. Keep
	-- the send control visually flush (2px inside the composer border) and
	-- relocate that invisible target below it instead.
	send:SetPoint("RIGHT", composer, "RIGHT", -COMPOSER_INSET, 0)
	makeComposerControlIntegrated(send, "gold")
	send:SetScript("OnClick", function()
		Dock:ActivateComposer()
	end)
	self.composerSend = send
	self:BindHeaderHover(send)
	-- The real Blizzard edit box is intentionally textureless inside SmartDock.
	-- This optional, full-height field is the one piece of decorative polish a
	-- player can enable.  Its bounds intentionally extend beyond the editor on
	-- both sides, fixing the old too-small backing panel without boxing SAY or
	-- the send action.
	local editBoxBorder = Theme:CreatePanel(composer, "surface", "borderMuted")
	editBoxBorder:SetFrameLevel(composer:GetFrameLevel() + 2)
	if editBoxBorder.EnableMouse then editBoxBorder:EnableMouse(false) end
	self.composerEditBoxBorder = editBoxBorder
	self:RefreshComposerLayout()
	self:RefreshComposerEditBoxBorder()
	self:BuildComposerRouteMenu()

	local alertBar = Theme:CreatePanel(content, "surfaceRaised", "gold")
	alertBar:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -2)
	alertBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -2, -2)
	alertBar:SetHeight(ALERT_PANEL_HEIGHT)
	alertBar:SetFrameLevel(content:GetFrameLevel() + 12)
	alertBar:EnableMouse(true)
	alertBar:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" then
			Dock:AcceptAlert()
		end
	end)
	alertBar:Hide()
	self.alertBar = alertBar
	self:BindHeaderHover(alertBar)
	local alertTitle = Theme:CreateText(alertBar, "GameFontNormalSmall", "goldBright")
	alertTitle:SetPoint("TOPLEFT", alertBar, "TOPLEFT", 4, -3)
	alertTitle:SetPoint("RIGHT", alertBar, "RIGHT", -24, 0)
	alertTitle:SetJustifyH("LEFT")
	self.alertTitle = alertTitle
	local alertMessage = Theme:CreateText(alertBar, "GameFontHighlightSmall", "text")
	alertMessage:SetPoint("BOTTOMLEFT", alertBar, "BOTTOMLEFT", 4, 3)
	alertMessage:SetPoint("RIGHT", alertBar, "RIGHT", -24, 0)
	alertMessage:SetJustifyH("LEFT")
	if alertMessage.SetWordWrap then alertMessage:SetWordWrap(false) end
	self.alertMessage = alertMessage
	local dismissAlert = createTightButton(alertBar, "X", 18, false)
	dismissAlert:SetPoint("RIGHT", alertBar, "RIGHT", -2, 0)
	dismissAlert:SetScript("OnClick", function()
		Dock:DismissAlert(true)
	end)
	self:BindHeaderHover(dismissAlert)

	-- The dock's border itself is the resize control: four-pixel edge strips
	-- and compact corners choose their matching resize direction, then light
	-- only the segment the cursor is actually over.  There is no permanent nib,
	-- extra padding, or overlay across the chat surface.
	self:BuildResizeHandles()

	self:BuildPlayerActions()
	self:BuildMessageBlockControls()
	self:BuildSourceColumnAlignmentControl()
	self:BuildChatHelpMenu()
	self.built = true
	local dockSettings = addon:GetSmartSettings().dock
	if self.visibleState == nil then self.visibleState = dockSettings.visible ~= false end
	if self.collapsedState == nil then self.collapsedState = dockSettings.collapsed == true end
	self:RefreshTransparency()
	self:ApplyLayout()
	return true
end

function Dock:IsActive()
	return self.active == true
end

function Dock:Activate()
	if self.active then
		return true
	end
	if InCombatLockdown and InCombatLockdown() then
		self.pendingEnabled = true
		self.lifecycle:RegisterEvent("PLAYER_REGEN_ENABLED")
		return false
	end
	self.pendingEnabled = false
	if self.lifecycle then
		self.lifecycle:UnregisterEvent("PLAYER_REGEN_ENABLED")
	end
	local ok, err = pcall(function()
		assert(self:Build(), "could not build Smart Dock")
		assert(self:AttachEditBox(), "ChatFrame1EditBox is unavailable")
		self.active = true
		self:RegisterSmartChatTextMediaCallback()
		local dockSettings = addon:GetSmartSettings().dock
		self.activeView = dockSettings.activeView or "general"
		self.visibleState = dockSettings.visible ~= false
		self.collapsedState = dockSettings.collapsed == true
		self:ApplySmartChatTextAppearance(self.activeView)
		self:ApplyLayout()
		self:RefreshViews()
		self:SelectView(self.activeView)
		if self.visibleState then
			self.frame:Show()
		else
			self.frame:Hide()
		end
		self:HideNativeChat()
		self:ApplySocialButtonVisibility()
	end)
	if not ok then
		self.active = false
		self:UnregisterSmartChatTextMediaCallback()
		self:RestoreEditBox()
		self:RestoreNativeChat()
		if self.frame and not self.built then
			self:DiscardPartialBuild()
		elseif self.frame then
			self.frame:Hide()
		end
		addon:Print("Smart Chat could not start; native chat was restored. " .. tostring(err))
		return false
	end
	return true
end

function Dock:Deactivate()
	self.pendingEnabled = false
	self:UnregisterSmartChatTextMediaCallback()
	if self.lifecycle then
		self.lifecycle:UnregisterEvent("PLAYER_REGEN_ENABLED")
	end
	self:CancelResize()
	self:CancelRailTabReorder(false)
	self:CancelRailMove(false)
	self:CancelNewMessageIndicatorMove(false)
	self.newMessageIndicatorPreviewActive = false
	self.newMessageIndicatorSuppressClickUntil = nil
	self.railTabSuppressClickUntil = nil
	self.railTabSuppressClickViewId = nil
	self.railMovePress = nil
	self.railMoveActive = false
	self.active = false
	self.routingComposer = false
	self.editReveal = nil
	self.composerInputActive = false
	self.railClickRevealed = false
	self.railMouseoverRevealed = false
	self.headerHover = false
	self.headerDragActive = false
	self:CancelHeaderHoverRefresh()
	self:HideComposerRouteMenu()
	self:HideDisplayHoverHint()
	self.hoveredHyperlink = nil
	self:DismissAlert(false)
	self:HideMessageBlockControls()
	self:HideSourceColumnAlignmentControl()
	if self.messageBlockDriver then
		self.messageBlockDriver:Hide()
	end
	local settings = addon:GetSmartSettings()
	self.visibleState = settings.dock.visible ~= false
	self.collapsedState = settings.dock.collapsed == true
	self:HidePlayerActions()
	if self.ignoreConfirm then
		self.ignoreConfirm:Hide()
	end
	if self.frame then
		self.frame:Hide()
	end
	self:RestoreSocialButtonVisibility()
	self:RestoreEditBox()
	self:RestoreNativeChat()
end

function Dock:SetEnabled(enabled)
	if enabled then
		return self:Activate()
	end
	self:Deactivate()
	return true
end

function Dock:Initialize()
	if self.initialized then
		return
	end
	self.initialized = true
	self.unread = {}
	self.pendingVisible = 0
	self.railClickRevealed = false
	self.railMouseoverRevealed = false
	self.railTabPress = nil
	self.railTabDragViewId = nil
	self.railTabDragButton = nil
	self.railTabDropTargetId = nil
	self.railTabDropAfter = nil
	self.railTabSuppressClickUntil = nil
	self.railTabSuppressClickViewId = nil
	self.newMessageIndicatorMove = nil
	self.newMessageIndicatorMoving = false
	self.newMessageIndicatorPreviewActive = false
	self.newMessageIndicatorSuppressClickUntil = nil
	self.headerHover = false
	self.headerDragActive = false
	self.composerInputActive = false
	self.stateRevision = 0
	self.alertDriver = CreateFrame("Frame")
	self.alertDriver:Hide()
	if not self.nativeCloseHooked and hooksecurefunc and FCF_Close then
		local hooked = pcall(hooksecurefunc, "FCF_Close", function(frame)
			Dock:MarkNativeChatFrameClosed(frame)
		end)
		self.nativeCloseHooked = hooked and true or false
	end
	self.lifecycle = CreateFrame("Frame")
	self.lifecycle:SetScript("OnEvent", function(_, event)
		if event == "UPDATE_CHAT_COLOR" then
			-- Presentation resolves colors from Blizzard's live chat-color table.
			-- Repaint the visible history immediately when the player changes one
			-- in the default chat settings instead of waiting for a rail switch.
			if Dock.active and Dock.frame then
				Dock:RebuildActiveView()
			end
			return
		end
		if event == "PLAYER_ENTERING_WORLD" then
			-- UnitFactionGroup is fully reliable here even on clients that loaded
			-- the addon before the player identity was available.  Refresh the
			-- authored rail icon so Horde never inherits the Alliance fallback.
			if Dock.railSettingsButton then
				Dock:RefreshRailSettingsIcon("normal")
			end
			return
		end
		if event == "PLAYER_REGEN_ENABLED" then
			Dock.lifecycle:UnregisterEvent(event)
			if Dock.pendingEnabled then
				Dock.pendingEnabled = false
				if addon.IsEnabled and not addon:IsEnabled() then
					return
				end
				if not addon:GetSmartSettings().enabled then
					return
				end
				local activated = Dock:Activate()
				if not activated and not Dock.pendingEnabled and addon.HandleDeferredSmartDockFailure then
					addon:HandleDeferredSmartDockFailure()
				end
			end
		end
	end)
	self.lifecycle:RegisterEvent("UPDATE_CHAT_COLOR")
	self.lifecycle:RegisterEvent("PLAYER_ENTERING_WORLD")
	addon.MessageEngine:RegisterListener("SmartDock", function(record)
		Dock:OnMessage(record)
	end)
	Theme:RegisterRefreshCallback(function()
		if Dock.frame then
			Dock:RefreshTransparency()
			if Dock.newButton and not Dock.newMessageIndicatorMoving then
				Dock:ApplyNewMessageIndicatorAppearance()
			end
			Dock:RefreshRailState()
			Dock:RebuildActiveView()
		end
	end)
end
