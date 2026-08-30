local addon = ChattyChattyBangBang

-- Version the one deliberate visual-default correction separately from the
-- dock layout itself.  The first implementation seeded a boxed composer into
-- every profile, even though Smart Chat's intended baseline is one continuous
-- chat surface.  A player can still opt into the field treatment below.
local COMPOSER_INPUT_POLISH_SCHEMA = 2
local CHAT_HISTORY_SETTINGS_SCHEMA = 1
local CHAT_HISTORY_DEFAULT_LINES_PER_SOURCE = 1000
local CHAT_HISTORY_MIN_LINES_PER_SOURCE = 100
local CHAT_HISTORY_MAX_LINES_PER_SOURCE = 10000
local PLAYER_ACTION_AUTO_HIDE_DEFAULT_SECONDS = 10
local PLAYER_ACTION_AUTO_HIDE_MIN_SECONDS = 1
local PLAYER_ACTION_AUTO_HIDE_MAX_SECONDS = 120
-- Schema 2 replaces the first saturated accent stripe with the neutral raised
-- surface used by ordinary table zebra rows.  The schema lets us repair only
-- the exact factory style while leaving deliberate colors/opacity untouched.
local MESSAGE_BAND_STYLE_SCHEMA = 2
-- Rail unread counts are independent from the active-view NEW marker.  Zero
-- font size deliberately means inherit the compact rail FontObject, retaining
-- existing tab geometry until a player explicitly asks for a larger count.
local RAIL_UNREAD_COUNT_APPEARANCE_SCHEMA = 1
local RAIL_UNREAD_COUNT_FONT_SIZE_MIN = 8
local RAIL_UNREAD_COUNT_FONT_SIZE_MAX = 16
local BUILT_IN_SOURCE_VIEWS_SCHEMA = 2
-- CONTENTS used to be an exclusion-only filter whose checked state was never
-- saved. Schema 1 turns it into an additive, per-view source feed with clean
-- factual homes while keeping semantic/custom routing as a second membership
-- path. Keep this separate from built-in rail migrations so PVP is not moved
-- again in profiles that already chose a custom tab order.
local VIEW_SOURCE_MEMBERSHIP_SCHEMA = 1
local MESSENGER_APPEARANCE_SCHEMA = 1

local messengerVisibilityAliases = {
	inherit = "inherit",
	default = "inherit",
	always = "always",
	show = "always",
	shown = "always",
	auto = "auto",
	hover = "auto",
	mouseover = "auto",
	click = "click",
	onclick = "click",
	collapsed = "collapsed",
	compact = "collapsed",
	hidden = "hidden",
	hide = "hidden",
}

local function normalizeMessengerVisibilityMode(value)
	if type(value) == "boolean" then
		return value and "always" or "hidden"
	end
	local key = type(value) == "string"
		and string.gsub(string.lower(tostring(value)), "[%s_%-]", "")
	return messengerVisibilityAliases[key] or "inherit"
end

local defaults = {
	enabled = true,
	colorway = "Obsidian Dawn",
	-- Received chat is retained once per physical source (never once per view),
	-- then restored in its original cross-source order after login or /reload.
	-- The upper bound is intentionally generous and lazy: a source consumes no
	-- SavedVariables space until it actually receives a line.
	historyCapacity = CHAT_HISTORY_DEFAULT_LINES_PER_SOURCE,
	persistHistory = true,
	historySettingsSchema = CHAT_HISTORY_SETTINGS_SCHEMA,
	-- This is intentionally Smart Chat presentation state, not the legacy
	-- ChatFont module's native-frame profile.  An absent font inherits the
	-- current ChatFontNormal face/size/flags; a selected value is the raw
	-- LibSharedMedia font key resolved at render time.
	textAppearance = {
		schema = 2,
		size = 0,
		outline = "INHERIT",
		-- ScrollingMessageFrame:SetSpacing is pixel padding between rendered
		-- lines. 0 keeps lines tight; 8 is deliberately the compact safe cap.
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
		-- The compact Social/Friends micro button is unrelated to message
		-- capture, so make it an explicit Chat Window preference instead of
		-- burying it in the dormant legacy Buttons module.
		hideSocialButton = false,
		activeView = "general",
		railOrientation = "vertical",
		railVisibility = "always",
		visible = true,
		collapsed = false,
		showComposer = true,
		-- Leave the composer visible for existing layouts.  Players who prefer a
		-- completely message-first dock can opt into the idle-only composer
		-- below; Enter, slash, and reply still reveal the shared edit box.
		composerAutoHide = false,
		-- This is Chatty's own optional typing-field treatment, not the legacy
		-- native-frame Edit Box Polish hook.  The default leaves the shared
		-- Blizzard editor integrated into one clean chat surface; enabling it
		-- adds a raised background and border only behind the typing field.
		editBoxBorder = false,
		composerInputPolishSchema = COMPOSER_INPUT_POLISH_SCHEMA,
		showScrollButtons = true,
		compactHeader = true,
		-- Player-name actions are a temporary context surface.  Clicking outside
		-- always dismisses it; this preference controls the independent safety-net
		-- timer for players who leave it open without making a selection.
		playerActions = {
			autoHide = true,
			autoHideSeconds = PLAYER_ACTION_AUTO_HIDE_DEFAULT_SECONDS,
		},
		-- One display preference for every Smart Chat tab.  The dock redraws its
		-- current buffer when this changes; no chat event is replayed or sent.
		sourceColumnAlignment = false,
		-- Signed gaps keep alignment adjustable without ever overlapping text.
		-- Positive values add cells; negative values compact and safely truncate
		-- the lane before the next hard boundary.
		columnAlignmentSpacing = 2,
		-- The [PLAYER] lane can be kept denser than the channel lane. Existing
		-- profiles without this field inherit columnAlignmentSpacing below, so a
		-- player's prior single GAP choice continues to seed both lanes.
		senderColumnAlignmentSpacing = 2,
		senderColumnMaxLength = 14,
		-- Only logical messages currently visible on screen decide the live
		-- channel/name widths when this opt-in is enabled.
		alignmentVisibleOnly = false,
		-- Keep the visible message body in a stable lane after [PLAYER]. This is
		-- independent of the source lane so a player can choose either compact
		-- aid; turning both on gives a complete TIME | SOURCE | [NAME] | message
		-- layout across every Smart Chat tab.
		senderColumnAlignment = false,
		-- Keep aligned metadata readable as the dock narrows. Runtime presentation
		-- sheds the timestamp, then channel, then player lane without changing the
		-- player's saved alignment choices; disabling this locks the full leader.
		responsiveMetadata = true,
		-- Independent chrome multipliers let a player soften the panel and border
		-- without fading message text. overallAlpha intentionally affects the whole
		-- SmartDock tree, including text and controls.
		transparency = {
			backgroundAlpha = 1,
			borderAlpha = 1,
			overallAlpha = 1,
		},
		-- Alternation belongs to logical messages, not visual lines: every wrapped
		-- continuation receives the same bounded background band.
		messageBands = {
			schema = MESSAGE_BAND_STYLE_SCHEMA,
			enabled = false,
			extent = "full",
			color = { mode = "theme", theme = "surfaceRaised", r = 0.085, g = 0.112, b = 0.158 },
			alpha = 0.50,
		},
		-- This affects only the numeric unread badge on inactive Smart Chat rail
		-- tabs; it never changes the tab key, the message font, or NEW marker.
		unreadCountAppearance = {
			schema = RAIL_UNREAD_COUNT_APPEARANCE_SCHEMA,
			alpha = 1,
			-- 0 = inherit GameFontNormalSmall's current size.
			fontSize = 0,
		},
		-- The first opt-in to aligned columns selects a proven fixed-width face.
		-- Once applied, this marker preserves an explicit later choice of
		-- INHERIT CURRENT CHAT FONT instead of repeatedly overriding it.
		sourceColumnAlignmentFontApplied = false,
		-- "hover" keeps the title bar out of the way until the player moves
		-- over the dock. "always" keeps its controls visible, while "hidden"
		-- gives the message surface every available pixel when expanded.
		headerVisibility = "hover",
		-- The active-view NEW control only matters while the player is reading
		-- history. Keep its behavior compact and presentation-only: it never
		-- changes what is captured, stored, or considered unread on another rail.
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
		-- INHERIT follows this one Messenger-wide chrome preference. Individual
		-- regions may instead be pinned on, shown on hover or click, or removed
		-- completely without changing whisper capture.
		chromeAutoHide = false,
		titleBarVisibility = "inherit",
		actionVisibility = "inherit",
		composerVisibility = "inherit",
		-- Kept as a small, explicit preference so Messenger can switch its
		-- contextual actions without rebuilding any stored conversation data.
		actionButtonStyle = "text",
		actionStripCollapsed = false,
		actionStripOrientation = "horizontal",
		appearance = {
			schema = MESSENGER_APPEARANCE_SCHEMA,
			transparency = {
				backgroundAlpha = 1,
				borderAlpha = 1,
				textAlpha = 1,
				overallAlpha = 1,
			},
			colors = {
				window = { mode = "inherit" },
				title = { mode = "inherit" },
				tabs = { mode = "inherit" },
				chat = { mode = "inherit" },
				reply = { mode = "inherit" },
				border = { mode = "inherit" },
			},
		},
		windowWidth = 360,
		windowHeight = 250,
	},
	views = {
		general = true,
		newcomers = true,
		-- Protocol traffic is deliberately quiet by default.  The Sync rail is
		-- still available from Organized Views / Rails & Sources whenever a
		-- player wants to inspect it.
		sync = false,
		conversations = true,
		-- Party, raid, and instance chat have their own human
		-- conversation rail.  It stays available even while the player is solo.
		group = true,
		groupFinder = true,
		guildInvites = true,
		pvp = true,
		trade = true,
		guild = true,
		system = true,
		loot = true,
	},
	-- Visual tab order only.  It is intentionally independent from customViews:
	-- moving a rail must never alter its classifier terms or message routing.
	railOrder = {
		"general", "newcomers", "sync", "conversations", "group", "groupFinder",
		"guildInvites", "pvp", "trade", "guild", "system", "loot",
	},
	builtInSourceViewsSchema = BUILT_IN_SOURCE_VIEWS_SCHEMA,
	viewSourceMembershipSchema = VIEW_SOURCE_MEMBERSHIP_SCHEMA,
	-- Per-view presentation and source visibility overrides.  A missing value
	-- always means "use the built-in/default source home" so the table stays
	-- small. Explicit true mirrors a non-default source into a view; false hides
	-- a default feed from that view.
	viewOptions = {},
	learnedSources = {},
	-- Exact public-channel routing corrections made from Shift > ANALYZE. Keys
	-- are lower-cased, whitespace-collapsed public message text; this is never
	-- consulted for whispers, Battle.net, local UI feedback, or add-on traffic.
	messageRouteOverrides = {},
	messageRouteOverrideSchema = 1,
	-- Per-category inference only affects text classified from public channels.
	-- Exact route corrections and purpose-built channel routes keep working.
	semanticRoutes = {
		groupFinder = true,
		pvp = true,
		trade = true,
	},
	-- Sync routing is intentionally source based and tri-state.  A missing
	-- source uses the conservative built-in detector, true forces a channel
	-- into Sync, and false keeps that channel on the human rails even when it
	-- resembles a known protocol feed.
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
			-- Three suppressed copies is enough to identify an actual repeat
			-- flood while still leaving one accidental resend as hide-only.
			-- Zero disables timed duplicate mutes without disabling filtering.
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
			-- Zero keeps strikes for the lifetime of the profile.  Any other
			-- value is a wall-clock window so reloads cannot extend a strike.
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
		-- A useful first rule that follows the player across character swaps.
		-- AlertEngine resolves [PLAYER_NAME] only at match time.
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
	-- Message Blocks are local presentation rules (not sender moderation).
	-- The UI-feedback coalescer keeps rapid repeated cooldown/action failures
	-- from overwhelming the System rail while preserving distinct errors.
	blocks = {
		enabled = true,
		rules = {},
		sequence = 0,
		revision = 0,
		uiFeedback = {
			coalesce = true,
			window = 1.5,
		},
		-- Manual Message Blocks quarantine their matches outside the normal chat
		-- transcript.  This bounded review trail is deliberately independent from
		-- Spam Firewall evidence and from received-chat history persistence.
		archive = {
			schema = 1,
			enabled = true,
			maxEntries = 500,
			retentionDays = 7,
			nextSequence = 1,
			entries = {},
		},
	},
	customViews = {},
	customViewSequence = 0,
	customViewRevision = 0,
	safety = {
		confirmServerIgnore = true,
		localIgnores = {},
	},
	keywordColors = {
		lfg = "goldBright",
		lfm = "goldBright",
		-- Short group-finder variants are deliberately separate terms: the
		-- renderer colors whole tokens, so LF must not be inferred from LFG.
		lf = "goldBright",
		lf1 = "goldBright",
		["lf#"] = "goldBright",
		lf1m = "goldBright",
		lf2m = "goldBright",
		lf3m = "goldBright",
		lf4m = "goldBright",
		lf5m = "goldBright",
		lf6m = "goldBright",
		lf1dps = "goldBright",
		need = "gold",
		tank = "accent",
		-- OT is the conventional off-tank shorthand, so it shares Tank's role
		-- color instead of borrowing the red DPS/failure color.
		ot = "accent",
		heal = "success",
		healer = "success",
		dps = "danger",
		-- PDS is a common transposition of DPS in fast group chat. Keep it in
		-- the same semantic group so one color choice fixes both spellings.
		pds = "danger",
		-- Item-level requirements are recruitment requirements, not warnings.
		-- Gold keeps them distinct from role requests while retaining a clear
		-- high-visibility neutral meaning in every ColorWays palette.
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
	-- A color group is the single source of truth for related terms.  The
	-- materialized keywordColors table above remains for saved-profile/API
	-- compatibility; presentation reads these groups first so changing one
	-- group updates every listed word and phrase together.
	keywordColorGroups = {
		{ id = "groupFinder", label = "GROUP FINDER", color = "goldBright", terms = { "lfg", "lfm", "lf", "lf1", { term = "LF#", numericSuffix = true }, "lf1m", "lf2m", "lf3m", "lf4m", "lf5m", "lf6m", "lf1dps" } },
		{ id = "tank", label = "TANK / OFF-TANK", color = "accent", terms = { "tank", "tnak", "tanks", "ot", "off tank" } },
		{ id = "healer", label = "HEALER", color = "success", terms = { "heal", "healer", "heals" } },
		{ id = "damage", label = "DAMAGE", color = "danger", terms = { "dps", "pds" } },
		{ id = "experienceAura", label = "EXPERIENCE AURA", color = "warning", terms = { "exp aura", "aura" } },
		-- Exact, case-sensitive M-level forms prevent ordinary lowercase text
		-- from becoming a false match while preserving the familiar key notation.
		{ id = "instanceLevels", label = "INSTANCE LEVELS / KEYS", color = "goldBright", terms = {
			{ term = "M0", caseSensitive = true }, { term = "M1", caseSensitive = true }, { term = "M2", caseSensitive = true }, { term = "M3", caseSensitive = true }, { term = "M4", caseSensitive = true }, { term = "M5", caseSensitive = true },
			{ term = "M6", caseSensitive = true }, { term = "M7", caseSensitive = true }, { term = "M8", caseSensitive = true }, { term = "M9", caseSensitive = true }, { term = "M10", caseSensitive = true },
			{ term = "M11", caseSensitive = true }, { term = "M12", caseSensitive = true }, { term = "M13", caseSensitive = true }, { term = "M14", caseSensitive = true }, { term = "M15", caseSensitive = true },
			{ term = "M16", caseSensitive = true }, { term = "M17", caseSensitive = true }, { term = "M18", caseSensitive = true }, { term = "M19", caseSensitive = true }, { term = "M20", caseSensitive = true },
			{ term = "M1+", caseSensitive = true }, { term = "M2+", caseSensitive = true }, { term = "M3+", caseSensitive = true }, { term = "M4+", caseSensitive = true }, { term = "M5+", caseSensitive = true },
			{ term = "M6+", caseSensitive = true }, { term = "M7+", caseSensitive = true }, { term = "M8+", caseSensitive = true }, { term = "M9+", caseSensitive = true }, { term = "M10+", caseSensitive = true },
			{ term = "M11+", caseSensitive = true }, { term = "M12+", caseSensitive = true }, { term = "M13+", caseSensitive = true }, { term = "M14+", caseSensitive = true }, { term = "M15+", caseSensitive = true },
			{ term = "M16+", caseSensitive = true }, { term = "M17+", caseSensitive = true }, { term = "M18+", caseSensitive = true }, { term = "M19+", caseSensitive = true }, { term = "M20+", caseSensitive = true },
			"mythic", "mythic+", "mythic plus", "mythic key", "mythic keys", "keystone", "keystones",
		} },
		{ id = "trade", label = "TRADE", color = "gold", terms = { "need", "ilvl", "wts", "wtb", "wtt" } },
		{ id = "warrior", label = "WARRIOR", color = "class:WARRIOR", terms = { "warrior" } },
		{ id = "paladin", label = "PALADIN", color = "class:PALADIN", terms = { "paladin", "pally" } },
		{ id = "hunter", label = "HUNTER", color = "class:HUNTER", terms = { "hunter" } },
		{ id = "rogue", label = "ROGUE", color = "class:ROGUE", terms = { "rogue" } },
		{ id = "priest", label = "PRIEST", color = "class:PRIEST", terms = { "priest" } },
		{ id = "deathKnight", label = "DEATH KNIGHT", color = "class:DEATHKNIGHT", terms = { "death knight", "deathknight", "dk" } },
		{ id = "shaman", label = "SHAMAN", color = "class:SHAMAN", terms = { "shaman", "shammy" } },
		{ id = "mage", label = "MAGE", color = "class:MAGE", terms = { "mage" } },
		{ id = "warlock", label = "WARLOCK", color = "class:WARLOCK", terms = { "warlock", "lock" } },
		{ id = "druid", label = "DRUID", color = "class:DRUID", terms = { "druid", "boomkin" } },
		-- Ascension can expose later-expansion class identities even on its
		-- Wrath client; use their canonical class colors when the client knows
		-- them and a stable fallback when it does not.
		{ id = "monk", label = "MONK", color = "class:MONK", terms = { "monk" } },
		{ id = "dungeons", label = "DUNGEONS", color = "goldBright", terms = {
			"deadmines", "dire maul", "scarlet monastery", "blackrock depths", "lower blackrock spire", "upper blackrock spire",
			"stratholme", "scholomance", "utgarde keep", "the nexus", "azjol-nerub", "ahn'kahet", "drak'tharon",
			"gundrak", "halls of lightning", "halls of stone", "culling of stratholme", "trial of the champion", "forge of souls", "pit of saron", "halls of reflection",
			{ term = "RFC", caseSensitive = true }, { term = "SFK", caseSensitive = true }, { term = "BFD", caseSensitive = true }, { term = "RFD", caseSensitive = true },
			{ term = "ULD", caseSensitive = true }, { term = "ZF", caseSensitive = true }, { term = "MARA", caseSensitive = true }, { term = "BRD", caseSensitive = true },
			{ term = "LBRS", caseSensitive = true }, { term = "UBRS", caseSensitive = true }, { term = "DMN", caseSensitive = true }, { term = "DME", caseSensitive = true }, { term = "DMW", caseSensitive = true },
			{ term = "UK", caseSensitive = true }, { term = "AN", caseSensitive = true }, { term = "OK", caseSensitive = true }, { term = "DTK", caseSensitive = true }, { term = "GD", caseSensitive = true },
			{ term = "HOL", caseSensitive = true }, { term = "HOS", caseSensitive = true }, { term = "COT", caseSensitive = true }, { term = "TOC", caseSensitive = true },
			{ term = "FOS", caseSensitive = true }, { term = "POS", caseSensitive = true }, { term = "HOR", caseSensitive = true },
		} },
	},
	keywordColorRevision = 0,
	-- Suggestions are review-only.  The persisted queue is deliberately tiny;
	-- the detailed counting ledger exists only for the current play session.
	keywordSuggestions = {
		enabled = true,
		threshold = 5,
		window = 900,
		maxSuggestions = 24,
		dismissed = {},
		queue = {},
		sequence = 0,
	},
	channelTargets = {
		groupFinder = nil,
		trade = nil,
	},
}

local function copy(value)
	if type(value) ~= "table" then
		return value
	end

	local result = {}
	for key, child in pairs(value) do
		result[key] = copy(child)
	end
	return result
end

local function applyDefaults(target, source)
	for key, defaultValue in pairs(source) do
		if target[key] == nil then
			target[key] = copy(defaultValue)
		elseif type(target[key]) == "table" and type(defaultValue) == "table" then
			applyDefaults(target[key], defaultValue)
		end
	end
end

-- Profiles from before grouped colors stored each word independently.  When a
-- player had changed one of those old words, carry that deliberate choice into
-- its whole new group rather than replacing it with today's default.
local function tablesMatch(left, right)
	if type(left) ~= type(right) then
		return false
	end
	if type(left) ~= "table" then
		return left == right
	end
	for key, value in pairs(left) do
		if not tablesMatch(value, right[key]) then
			return false
		end
	end
	for key in pairs(right) do
		if left[key] == nil then
			return false
		end
	end
	return true
end

local function isFactoryKeywordGroup(group)
	if type(group) ~= "table" then
		return false
	end
	for _, defaultGroup in ipairs(defaults.keywordColorGroups) do
		if group.id == defaultGroup.id then
			return tablesMatch(group, defaultGroup)
		end
	end
	return false
end

-- Deliberately not part of either defaults table. AceDB merges defaults before
-- Settings gets a chance to inspect an old profile, so a defaulted marker
-- would falsely claim the old flat color map had already been reconciled.
local KEYWORD_COLOR_GROUP_SCHEMA = 3

local function keywordTermKey(termSpec)
	local term = type(termSpec) == "table" and termSpec.term or termSpec
	if type(term) ~= "string" then
		return nil
	end
	local caseSensitive = type(termSpec) == "table" and termSpec.caseSensitive == true
	local numericSuffix = type(termSpec) == "table" and termSpec.numericSuffix == true
	return string.lower(term) .. (caseSensitive and "\031case" or "\031plain")
		.. (numericSuffix and "\031number" or "")
end

-- `keywordColorGroups` is an ordered array, so generic recursive defaults
-- merge it by numeric slot and can shift every following group after a new
-- built-in is inserted. Rebuild by stable group ID for schema upgrades instead
-- and preserve a player's color, label, order within terms, and custom terms.
local function mergeKeywordColorGroupsById(previousGroups)
	local previousById = {}
	local previousOrder = {}
	for _, group in ipairs(type(previousGroups) == "table" and previousGroups or {}) do
		if type(group) == "table" and type(group.id) == "string" and group.id ~= "" and not previousById[group.id] then
			previousById[group.id] = group
			table.insert(previousOrder, group.id)
		end
	end

	local merged = {}
	local used = {}
	for _, defaultGroup in ipairs(defaults.keywordColorGroups) do
		local existing = previousById[defaultGroup.id]
		local result = existing and copy(existing) or copy(defaultGroup)
		if existing then
			for key, value in pairs(defaultGroup) do
				if key ~= "terms" and result[key] == nil then
					result[key] = copy(value)
				end
			end
			result.terms = type(result.terms) == "table" and result.terms or {}
			local seenTerms = {}
			for _, termSpec in ipairs(result.terms) do
				local key = keywordTermKey(termSpec)
				if key then seenTerms[key] = true end
			end
			for _, termSpec in ipairs(defaultGroup.terms or {}) do
				local key = keywordTermKey(termSpec)
				if key and not seenTerms[key] then
					table.insert(result.terms, copy(termSpec))
					seenTerms[key] = true
				end
			end
		end
		table.insert(merged, result)
		used[defaultGroup.id] = true
	end
	-- Retain hand-authored/unknown groups instead of destroying profile data.
	for _, id in ipairs(previousOrder) do
		if not used[id] then
			table.insert(merged, copy(previousById[id]))
		end
	end
	return merged
end

local function migrateLegacyKeywordColors(settings, legacyColors)
	if type(legacyColors) ~= "table" or type(settings.keywordColorGroups) ~= "table" then
		return
	end
	for _, group in ipairs(settings.keywordColorGroups) do
		-- AceDB can pre-seed the newly-added default group table before this
		-- code runs. An exact factory group is therefore still eligible for
		-- migration; any actual group edit (including vocabulary edits) wins.
		if isFactoryKeywordGroup(group) then
			for _, termSpec in ipairs(group.terms or {}) do
				local term = type(termSpec) == "table" and termSpec.term or termSpec
				local key = type(term) == "string" and string.lower(term) or nil
				local prior = key and legacyColors[key]
				if prior and prior ~= defaults.keywordColors[key] then
					group.color = prior
					for _, groupedTermSpec in ipairs(group.terms or {}) do
						local groupedTerm = type(groupedTermSpec) == "table" and groupedTermSpec.term or groupedTermSpec
						if type(groupedTerm) == "string" then
							settings.keywordColors[string.lower(groupedTerm)] = prior
						end
					end
					break
				end
			end
		end
	end
end

addon.SmartViews = {
	-- These are presentation defaults only.  A player-entered rail name/key is
	-- deliberately preserved exactly as typed; RESET returns to this concise,
	-- scan-friendly uppercase baseline.
	{ id = "general", key = "G", label = "GENERAL", description = "World, zone, local, and channel traffic." },
	{ id = "newcomers", key = "NC", label = "NEWCOMERS", description = "Newcomers channel conversation that is not better identified as Group Finder or Trade." },
	{ id = "sync", key = "SYNC", label = "SYNC", description = "Addon protocol traffic and marked sync channels." },
	{ id = "conversations", key = "C", label = "CHAT", description = "Whispers, replies, and direct player chat." },
	{ id = "group", key = "GRP", label = "GROUP", description = "Party, raid, instance, and raid-warning chat." },
	{ id = "groupFinder", key = "LFG", label = "GROUP FINDER", description = "Looking-for-group, role, dungeon, and raid messages." },
	{ id = "guildInvites", key = "GU INV", label = "GUILD INVITES", description = "Guild recruitment and invitation messages from the GuildRecruitment channel." },
	{ id = "pvp", key = "PVP", label = "PVP", description = "World defense alerts, battleground notices, and player-versus-player conversation." },
	{ id = "trade", key = "T", label = "TRADE", description = "Buying, selling, crafting, and service messages." },
	{ id = "guild", key = "GU", label = "GUILD", description = "Guild and officer chat, ready for the future Guild Hub." },
	{ id = "system", key = "SYS", label = "SYSTEM", description = "System notices, achievements, and status messages." },
	{ id = "loot", key = "LOOT", label = "LOOT", description = "Loot, rolls, and item notifications." },
}

local MAX_CUSTOM_VIEWS = 12
local MAX_CUSTOM_TERMS = 48
local MAX_TERM_LENGTH = 80
local MAX_SYNC_SOURCE_OVERRIDES = 64
local SYNC_SETTINGS_SCHEMA = 1
local builtInViewIds = {}
for index = 1, #addon.SmartViews do
	builtInViewIds[addon.SmartViews[index].id] = true
end

-- Every physical source has one calm, factual home. Routing rules may add an
-- additional topic view, but they never have to steal the line from this home:
-- an Ascension-channel LFG advert can therefore stay in GENERAL and also show
-- in GROUP FINDER. Custom views deliberately have no inherited source feeds.
local sourceHomeViewById = {
	["local:say"] = "general",
	["local:yell"] = "general",
	["local:emote"] = "general",
	["local:text-emote"] = "general",
	["addon:alcver"] = "sync",
	["conversation:whisper"] = "conversations",
	["conversation:bnet-whisper"] = "conversations",
	["conversation:bnet-conversation"] = "conversations",
	["conversation:afk"] = "conversations",
	["conversation:dnd"] = "conversations",
	["guild:guild"] = "guild",
	["guild:achievement"] = "guild",
	["guild:officer"] = "guild",
	["group:party"] = "group",
	["group:raid"] = "group",
	["group:raid-warning"] = "group",
	["group:instance"] = "group",
	["group:battleground"] = "pvp",
	["system:battleground"] = "pvp",
	["system:under-attack"] = "pvp",
	["system:addon-feedback"] = "system",
	["system:message"] = "system",
	["system:ui-error"] = "system",
	["system:local-debug"] = "system",
	["system:achievement"] = "system",
	["loot:loot"] = "loot",
	["loot:money"] = "loot",
	["channel:newcomers"] = "newcomers",
	["channel:guildrecruitment"] = "guildInvites",
	["channel:guild-recruitment"] = "guildInvites",
	["channel:lookingforgroup"] = "groupFinder",
	["channel:looking-for-group"] = "groupFinder",
	["channel:lfg"] = "groupFinder",
	["channel:trade"] = "trade",
	["channel:defense"] = "pvp",
	["channel:defence"] = "pvp",
	["channel:localdefense"] = "pvp",
	["channel:local-defense"] = "pvp",
	["channel:localdefence"] = "pvp",
	["channel:local-defence"] = "pvp",
	["channel:worlddefense"] = "pvp",
	["channel:world-defense"] = "pvp",
	["channel:worlddefence"] = "pvp",
	["channel:world-defence"] = "pvp",
}

local sourceHomeViewByGroup = {
	["local"] = "general",
	channels = "general",
	conversations = "conversations",
	sync = "sync",
	guild = "guild",
	group = "group",
	pvp = "pvp",
	system = "system",
	loot = "loot",
	other = "general",
}

local function inferSourceGroup(sourceId, sourceGroup)
	if type(sourceGroup) == "string" and sourceGroup ~= "" then
		return sourceGroup
	end
	local prefix = type(sourceId) == "string" and string.match(sourceId, "^([^:]+):") or nil
	if prefix == "channel" then return "channels" end
	if prefix == "conversation" then return "conversations" end
	if prefix == "addon" then return "sync" end
	if sourceHomeViewByGroup[prefix] then return prefix end
	return "other"
end

local function getDefaultSourceHome(settings, sourceId, sourceGroup)
	sourceId = type(sourceId) == "string" and string.lower(sourceId) or ""
	if sourceId == "" then return nil end

	-- A whole public channel explicitly marked SYNC belongs factually in Sync.
	-- NORMAL restores its ordinary source home. ALCsync follows the global
	-- automatic detector unless that source or detector is explicitly disabled.
	if string.find(sourceId, "channel:", 1, true) == 1 then
		local sync = type(settings) == "table" and settings.sync or nil
		local modes = type(sync) == "table" and sync.sources or nil
		local mode = type(modes) == "table" and modes[sourceId] or nil
		if mode == true then return "sync" end
		if sourceId == "channel:alcsync" then
			if mode ~= false and (not sync or sync.enabled ~= false) then
				return "sync"
			end
			return "general"
		end
	end

	return sourceHomeViewById[sourceId]
		or sourceHomeViewByGroup[inferSourceGroup(sourceId, sourceGroup)]
		or "general"
end

local function isDefaultSourceEnabled(settings, viewId, sourceId, sourceGroup)
	return builtInViewIds[viewId] == true
		and getDefaultSourceHome(settings, sourceId, sourceGroup) == viewId
end

local function isSourceFeedLocked(settings, viewId, sourceId, sourceGroup)
	local home = getDefaultSourceHome(settings, sourceId, sourceGroup)
	-- Sync is a protocol quarantine, not an ordinary presentation tab. A source
	-- may move into or out of it through the adjacent AUTO/SYNC/NORMAL control,
	-- but the per-tab feed checkbox must never promise an impossible mirror.
	return (home == "sync") ~= (viewId == "sync")
end

local function trim(value, maximumLength)
	if type(value) ~= "string" then
		return ""
	end
	value = string.gsub(value, "^%s+", "")
	value = string.gsub(value, "%s+$", "")
	if maximumLength and string.len(value) > maximumLength then
		value = string.sub(value, 1, maximumLength)
	end
	return value
end

-- The unread marker is a small independent piece of dock chrome, so keep its
-- vocabulary deliberately stable.  Runtime and Config only need these IDs;
-- labels live here too so a future compact inspector does not need to guess at
-- supported values or duplicate a migration list.
local NEW_MESSAGE_INDICATOR_ANCHORS = {
	header = true,
	dock = true,
}
local NEW_MESSAGE_INDICATOR_APPEARANCE_SCHEMA = 1

local NEW_MESSAGE_INDICATOR_POINTS = {
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

local NEW_MESSAGE_INDICATOR_FONTS = {
	default = true,
	chat = true,
	system = true,
	number = true,
}

-- Smart Chat text uses LibSharedMedia keys and an exact installed-SharedMedia
-- fallback map. An absent key inherits whatever ChatFontNormal resolves to.
local SMART_CHAT_TEXT_APPEARANCE_SCHEMA = 2
local SOURCE_COLUMN_ALIGNMENT_DEFAULT_FONT = "SourceCodePro (Regular)"
local SMART_CHAT_TEXT_OUTLINES = {
	INHERIT = true,
	NONE = true,
	OUTLINE = true,
	THICKOUTLINE = true,
}

local SMART_CHAT_TEXT_APPEARANCE_OPTIONS = {
	fonts = {
		{ id = false, label = "INHERIT CURRENT CHAT FONT", inherit = true },
	},
	outlines = {
		{ id = "INHERIT", label = "INHERIT CHAT FONT" },
		{ id = "NONE", label = "NONE" },
		{ id = "OUTLINE", label = "OUTLINE" },
		{ id = "THICKOUTLINE", label = "THICK OUTLINE" },
	},
	size = {
		minimum = 8,
		maximum = 32,
		inherit = 0,
	},
	-- Wrath's ScrollingMessageFrame:SetSpacing takes pixels. Keep this a
	-- small non-negative integer range: no overlap/negative line advance, and
	-- no needlessly tall chat rows at ordinary font sizes.
	spacing = {
		minimum = 0,
		maximum = 8,
		default = 1,
	},
}

-- Questie-335 deliberately registers this local font pack itself instead of
-- assuming its normal addon load happened first. Ascension can load optional
-- addons in an order where SharedMedia's Core.lua has not run yet; the pack is
-- still installed and its fonts are still valid LibSharedMedia entries. Use
-- the same small bootstrap so Chatty's picker always sees the user's font
-- pack, while preserving every other font any addon registered normally.
local SHARED_MEDIA_FONT_ROOT = "Interface\\AddOns\\SharedMedia\\Fonts\\"
local SHARED_MEDIA_FONT_PACK = {
	{ "SourceCodePro (Regular)", "SourceCodePro-Regular.ttf" },
	{ "SourceCodePro (Bold)", "SourceCodePro-Bold.ttf" },
	{ "Source Code Pro (Regular)", "SourceCodePro-Regular.ttf" },
	{ "Source Code Pro (Bold)", "SourceCodePro-Bold.ttf" },
	{ "JetBrains Mono (Regular)", "JetBrainsMono-Regular.ttf" },
	{ "JetBrains Mono (Medium)", "JetBrainsMono-Medium.ttf" },
	{ "JetBrains Mono (Bold)", "JetBrainsMono-Bold.ttf" },
	{ "IBM Plex Mono (Regular)", "IBMPlexMono-Regular.ttf" },
	{ "IBM Plex Mono (Medium)", "IBMPlexMono-Medium.ttf" },
	{ "IBM Plex Mono (Bold)", "IBMPlexMono-Bold.ttf" },
	{ "Hack (Regular)", "Hack-Regular.ttf" },
	{ "Hack (Bold)", "Hack-Bold.ttf" },
	{ "Fira Mono (Regular)", "FiraMono-Regular.ttf" },
	{ "Fira Mono (Bold)", "FiraMono-Bold.ttf" },
	{ "Fira Code (Regular)", "FiraCode-Regular.ttf" },
	{ "Fira Code (Medium)", "FiraCode-Medium.ttf" },
	{ "Fira Code (Bold)", "FiraCode-Bold.ttf" },
	{ "Cascadia Mono (Regular)", "CascadiaMono-Regular.ttf" },
	{ "Cascadia Mono (SemiBold)", "CascadiaMono-SemiBold.ttf" },
	{ "Cascadia Mono (Bold)", "CascadiaMono-Bold.ttf" },
	{ "Cascadia Mono NF (Bold)", "CascadiaMonoNF-Bold.ttf" },
	{ "Cascadia Mono PL (Bold)", "CascadiaMonoPL-Bold.ttf" },
	{ "Iosevka Term (Regular)", "IosevkaTerm-Regular.ttf" },
	{ "Iosevka Term (Medium)", "IosevkaTerm-Medium.ttf" },
	{ "Iosevka Term (Bold)", "IosevkaTerm-Bold.ttf" },
	{ "Victor Mono (Regular)", "VictorMono-Regular.ttf" },
	{ "Cascadia Code (Bold)", "CascadiaCode-Bold.ttf" },
	{ "Cascadia Code (SemiBold)", "CascadiaCode-SemiBold.ttf" },
	{ "Cascadia Code NF (Bold)", "CascadiaCodeNF-Bold.ttf" },
	{ "Cascadia Code NF (SemiBold)", "CascadiaCodeNF-SemiBold.ttf" },
	{ "Cascadia Code PL (Bold)", "CascadiaCodePL-Bold.ttf" },
	{ "Cascadia Code PL (SemiBold)", "CascadiaCodePL-SemiBold.ttf" },
}

-- Do not make the chooser depend on the runtime registry being populated.
-- Ascension occasionally reports an empty LibSharedMedia table even though
-- the SharedMedia addon and these files are installed. This is the same pack
-- Questie's TrackerFonts module owns, indexed here as a reliable fallback.
local SHARED_MEDIA_KNOWN_FONT_PATHS = {}
for _, font in ipairs(SHARED_MEDIA_FONT_PACK) do
	SHARED_MEDIA_KNOWN_FONT_PATHS[font[1]] = SHARED_MEDIA_FONT_ROOT .. font[2]
end
local sharedMediaFontPackBootstrapped = setmetatable({}, { __mode = "k" })

local NEW_MESSAGE_INDICATOR_OUTLINES = {
	NONE = true,
	OUTLINE = true,
	THICKOUTLINE = true,
}

-- These names intentionally track the public Theme palette roles rather than
-- a single ColorWays palette.  A theme color follows ColorWays changes; a
-- custom RGBA swatch stays personal to this marker alone.
local NEW_MESSAGE_INDICATOR_THEME_COLORS = {
	background = true,
	surface = true,
	surfaceRaised = true,
	inset = true,
	border = true,
	borderMuted = true,
	gold = true,
	goldBright = true,
	accent = true,
	accentSoft = true,
	text = true,
	textMuted = true,
	success = true,
	warning = true,
	danger = true,
}

local NEW_MESSAGE_INDICATOR_THEME_COLOR_ALIASES = {}
for colorName in pairs(NEW_MESSAGE_INDICATOR_THEME_COLORS) do
	NEW_MESSAGE_INDICATOR_THEME_COLOR_ALIASES[string.lower(colorName)] = colorName
end

local NEW_MESSAGE_INDICATOR_APPEARANCE_OPTIONS = {
	positions = {
		{ id = "header", label = "HEADER CONTROLS" },
		{ id = "TOPLEFT", label = "TOP LEFT" },
		{ id = "TOP", label = "TOP" },
		{ id = "TOPRIGHT", label = "TOP RIGHT" },
		{ id = "LEFT", label = "LEFT" },
		{ id = "CENTER", label = "CENTER" },
		{ id = "RIGHT", label = "RIGHT" },
		{ id = "BOTTOMLEFT", label = "BOTTOM LEFT" },
		{ id = "BOTTOM", label = "BOTTOM" },
		{ id = "BOTTOMRIGHT", label = "BOTTOM RIGHT" },
	},
	fonts = {
		{ id = "default", label = "DEFAULT UI" },
		{ id = "chat", label = "CHAT FONT" },
		{ id = "system", label = "SYSTEM" },
		{ id = "number", label = "NUMERIC" },
	},
	outlines = {
		{ id = "NONE", label = "NONE" },
		{ id = "OUTLINE", label = "OUTLINE" },
		{ id = "THICKOUTLINE", label = "THICK" },
	},
	themeColors = {
		{ id = "goldBright", label = "GOLD" },
		{ id = "gold", label = "WARM GOLD" },
		{ id = "accent", label = "ACCENT" },
		{ id = "text", label = "TEXT" },
		{ id = "success", label = "SUCCESS" },
		{ id = "warning", label = "WARNING" },
		{ id = "danger", label = "DANGER" },
	},
}

local function clampNewMessageIndicatorNumber(value, fallback, minimum, maximum, integer)
	value = tonumber(value)
	if value == nil then
		value = fallback
	end
	if integer then
		value = math.floor(value + 0.5)
	end
	if value < minimum then
		return minimum
	elseif value > maximum then
		return maximum
	end
	return value
end

local function normalizeNewMessageIndicatorPosition(position)
	local fallback = defaults.dock.newMessages.appearance.position
	if type(position) ~= "table" then
		position = copy(fallback)
	end

	local anchor = string.lower(trim(position.anchor, 16))
	if not NEW_MESSAGE_INDICATOR_ANCHORS[anchor] then
		anchor = fallback.anchor
	end
	local point = string.upper(trim(position.point, 16))
	if not NEW_MESSAGE_INDICATOR_POINTS[point] then
		point = fallback.point
	end
	position.anchor = anchor
	position.point = point
	-- Bound arbitrary SavedVariables edits without making a player fight a
	-- deliberate free placement on a large screen or unusually sized dock.
	position.x = clampNewMessageIndicatorNumber(position.x, fallback.x, -4000, 4000, true)
	position.y = clampNewMessageIndicatorNumber(position.y, fallback.y, -4000, 4000, true)
	return position
end

local function normalizeNewMessageIndicatorFont(font)
	font = trim(font, 160)
	local builtIn = string.lower(font)
	if NEW_MESSAGE_INDICATOR_FONTS[builtIn] then
		return builtIn
	end
	-- LibSharedMedia is optional, but Chatty already declares it as an optional
	-- dependency.  Preserve a selected LSM key even if the library is absent at
	-- login; SmartDock can safely fall back and use it once available.
	if string.find(font, "^lsm:[^%c]+$") then
		return font
	end
	return defaults.dock.newMessages.appearance.font
end

local function normalizeNewMessageIndicatorOutline(outline)
	outline = string.upper(trim(outline, 24))
	if outline == "" then
		outline = "NONE"
	elseif outline == "THICK" then
		outline = "THICKOUTLINE"
	end
	if not NEW_MESSAGE_INDICATOR_OUTLINES[outline] then
		outline = defaults.dock.newMessages.appearance.outline
	end
	return outline
end

-- Keep the LibSharedMedia boundary in Settings.  Config only receives a
-- stable snapshot of selectable keys, while SmartDock can ask the same public
-- resolver for the actual path when it applies a font.  LSM is optional in a
-- stripped install, so the inherited ChatFontNormal fallback always remains
-- available and no missing library can prevent chat from rendering.
local function getSharedMedia()
	-- Ascension's UI sandbox normally exposes LibStub through _G, but use the
	-- direct global as a resilient fallback for stripped/embedded environments.
	-- This is still the one shared registry - never a Chatty font list.
	local libStub = (_G and _G.LibStub) or LibStub
	if type(libStub) ~= "function" then
		return nil
	end
	local ok, media = pcall(libStub, "LibSharedMedia-3.0", true)
	if not ok or type(media) ~= "table" then
		return nil
	end
	return media
end

local function bootstrapSharedMediaFontPack(media)
	if not media or sharedMediaFontPackBootstrapped[media] or type(media.Register) ~= "function" then
		return
	end
	for _, font in ipairs(SHARED_MEDIA_FONT_PACK) do
		-- Registration is idempotent. A proven local font file is more reliable
		-- than Ascension's optional-addon metadata gate.
		pcall(media.Register, media, "font", font[1], SHARED_MEDIA_FONT_ROOT .. font[2])
	end
	sharedMediaFontPackBootstrapped[media] = true
end

local function normalizeSmartChatTextFont(font)
	if font == nil then
		return nil, true
	end
	font = trim(font, 160)
	if font == "" or string.lower(font) == "default" then
		-- `default` was used by the initial unreleased implementation.  Treat it
		-- as the current-chat inherited value rather than preserving a parallel
		-- identifier in SavedVariables.
		return nil, true
	end
	local lsmName = string.match(font, "^[Ll][Ss][Mm]:(.*)$")
	if lsmName then
		lsmName = trim(lsmName, 156)
		if lsmName ~= "" and not string.find(lsmName, "%c") then
			-- Read-migrate the short-lived wrapper form, but persist the canonical
			-- raw LSM key used by Chatter/Questie and by Media:Fetch.
			return lsmName, true
		end
		return nil, false
	end
	if not string.find(font, "%c") then
		-- Preserve the registered key exactly: Media:Fetch("font", key) is
		-- keyed by this label, not by a filesystem path or an addon-local alias.
		return font, true
	end
	return nil, false
end

local function normalizeSmartChatTextSize(size)
	size = tonumber(size)
	if size == nil then
		return nil
	end
	size = math.floor(size + 0.5)
	if size == 0 then
		return 0
	end
	if size < SMART_CHAT_TEXT_APPEARANCE_OPTIONS.size.minimum
		or size > SMART_CHAT_TEXT_APPEARANCE_OPTIONS.size.maximum then
		return nil
	end
	return size
end

local function normalizeSmartChatTextSpacing(spacing)
	spacing = tonumber(spacing)
	if spacing == nil then
		return nil
	end
	-- This is a pixel count, not a slider value. Reject a hand-edited decimal
	-- rather than silently changing 1.5 into two pixels behind the player's
	-- back; the UI and public API both promise whole numbers.
	if spacing ~= math.floor(spacing) then
		return nil
	end
	if spacing < SMART_CHAT_TEXT_APPEARANCE_OPTIONS.spacing.minimum
		or spacing > SMART_CHAT_TEXT_APPEARANCE_OPTIONS.spacing.maximum then
		return nil
	end
	return spacing
end

local function normalizeSmartChatTextOutline(outline)
	outline = string.upper(trim(outline, 24))
	if outline == "THICK" then
		outline = "THICKOUTLINE"
	end
	if SMART_CHAT_TEXT_OUTLINES[outline] then
		return outline
	end
	return nil
end

local function normalizeSmartChatTextAppearance(appearance)
	local fallback = defaults.textAppearance
	if type(appearance) ~= "table" then
		appearance = {}
	end
	appearance.font = normalizeSmartChatTextFont(appearance.font)
	if appearance.font == nil then
		appearance.font = fallback.font
	end
	appearance.size = normalizeSmartChatTextSize(appearance.size)
	if appearance.size == nil then
		appearance.size = fallback.size
	end
	appearance.outline = normalizeSmartChatTextOutline(appearance.outline) or fallback.outline
	appearance.spacing = normalizeSmartChatTextSpacing(appearance.spacing)
	if appearance.spacing == nil then
		appearance.spacing = fallback.spacing
	end
	appearance.schema = SMART_CHAT_TEXT_APPEARANCE_SCHEMA
	return appearance
end

-- Exact text columns need a fixed-width face. Either alignment control is an
-- explicit player opt-in, so select Source Code Pro only on the first opt-in
-- and never overwrite a later deliberate font or INHERIT choice. The existing
-- persistence marker intentionally stays named after the original source
-- lane; changing it would discard a player's one-time opt-in history.
local function ensureColumnAlignmentFont(settings)
	local dock = type(settings) == "table" and settings.dock
	if type(dock) ~= "table"
		or (dock.sourceColumnAlignment ~= true and dock.senderColumnAlignment ~= true)
		or dock.sourceColumnAlignmentFontApplied == true then
		return false
	end
	dock.sourceColumnAlignmentFontApplied = true
	local appearance = normalizeSmartChatTextAppearance(settings.textAppearance)
	if appearance.font ~= nil then
		settings.textAppearance = appearance
		return false
	end
	appearance.font = SOURCE_COLUMN_ALIGNMENT_DEFAULT_FONT
	settings.textAppearance = appearance
	return true
end

-- A view stores only the properties it actually overrides.  This is what lets
-- a GLOBAL change flow into every inherited tab without overwriting a player's
-- deliberate per-tab choice.
local function normalizeSmartChatTextAppearanceOverride(appearance)
	if type(appearance) ~= "table" then
		return nil
	end
	local normalized = {}
	if appearance.font ~= nil then
		local font, valid = normalizeSmartChatTextFont(appearance.font)
		if valid and font ~= nil then
			normalized.font = font
		end
	end
	if appearance.size ~= nil then
		normalized.size = normalizeSmartChatTextSize(appearance.size)
	end
	if appearance.outline ~= nil then
		normalized.outline = normalizeSmartChatTextOutline(appearance.outline)
	end
	if appearance.spacing ~= nil then
		normalized.spacing = normalizeSmartChatTextSpacing(appearance.spacing)
	end
	if next(normalized) == nil then
		return nil
	end
	return normalized
end

local function smartChatTextFontLooksMonospaced(name)
	local lower = string.lower(tostring(name or ""))
	return string.find(lower, "mono", 1, true) ~= nil
		or string.find(lower, "code", 1, true) ~= nil
		or string.find(lower, "console", 1, true) ~= nil
		or string.find(lower, "fixed", 1, true) ~= nil
		or string.find(lower, "terminus", 1, true) ~= nil
end

local function getSmartChatTextAppearanceOptions()
	local options = copy(SMART_CHAT_TEXT_APPEARANCE_OPTIONS)
	-- Seed from the installed SharedMedia pack first. This means the picker
	-- cannot regress to a misleading "NO REGISTERED FONTS" state merely because
	-- Ascension exposes an empty or delayed LibSharedMedia registry.
	local fontPaths = copy(SHARED_MEDIA_KNOWN_FONT_PATHS)
	local media = getSharedMedia()
	if media then
		bootstrapSharedMediaFontPack(media)
		if type(media.HashTable) == "function" then
			local ok, fonts = pcall(media.HashTable, media, "font")
			if ok and type(fonts) == "table" then
				for name, path in pairs(fonts) do
					if type(name) == "string" and trim(name, 156) ~= ""
						and type(path) == "string" and path ~= "" then
						fontPaths[name] = path
					end
				end
			end
		end
	end
	local names = {}
	for name in pairs(fontPaths) do
		if type(name) == "string" and trim(name, 156) ~= "" then
			table.insert(names, name)
		end
	end
	table.sort(names, function(left, right)
		return string.lower(left) < string.lower(right)
	end)
	for index = 1, #names do
		local name = names[index]
		local monospaced = smartChatTextFontLooksMonospaced(name)
		table.insert(options.fonts, {
			id = name,
			-- Keep the registered SharedMedia name intact. The picker renders every
			-- row in its actual face, so a redundant LSM/MONO prefix and forced
			-- uppercase only make the choice list harder to read.
			label = name,
			lsmKey = name,
			path = fontPaths[name],
			monospaced = monospaced,
		})
	end
	return options
end

local function normalizeNewMessageIndicatorColor(color, fallback)
	if type(color) ~= "table" then
		color = copy(fallback)
	end
	local mode = string.lower(trim(color.mode, 16))
	if mode == "" and (color.r ~= nil or color.g ~= nil or color.b ~= nil or color.a ~= nil) then
		mode = "custom"
	end
	if mode ~= "custom" and mode ~= "theme" then
		mode = fallback.mode
	end
	local theme = NEW_MESSAGE_INDICATOR_THEME_COLOR_ALIASES[string.lower(trim(color.theme, 40))]
	if not theme then
		theme = fallback.theme
	end
	color.mode = mode
	color.theme = theme
	color.r = clampNewMessageIndicatorNumber(color.r, fallback.r, 0, 1)
	color.g = clampNewMessageIndicatorNumber(color.g, fallback.g, 0, 1)
	color.b = clampNewMessageIndicatorNumber(color.b, fallback.b, 0, 1)
	color.a = clampNewMessageIndicatorNumber(color.a, fallback.a, 0, 1)
	return color
end

local function isNormalizedNewMessageIndicatorColor(color)
	return type(color) == "table"
		and (color.mode == "theme" or color.mode == "custom")
		and NEW_MESSAGE_INDICATOR_THEME_COLORS[color.theme] == true
		and type(color.r) == "number" and color.r >= 0 and color.r <= 1
		and type(color.g) == "number" and color.g >= 0 and color.g <= 1
		and type(color.b) == "number" and color.b >= 0 and color.b <= 1
		and type(color.a) == "number" and color.a >= 0 and color.a <= 1
end

local function isNormalizedNewMessageIndicatorAppearance(appearance)
	if type(appearance) ~= "table" or appearance.schema ~= NEW_MESSAGE_INDICATOR_APPEARANCE_SCHEMA then
		return false
	end
	local position = appearance.position
	if type(position) ~= "table" or not NEW_MESSAGE_INDICATOR_ANCHORS[position.anchor]
		or not NEW_MESSAGE_INDICATOR_POINTS[position.point]
		or type(position.x) ~= "number" or type(position.y) ~= "number"
		or math.floor(position.x) ~= position.x or math.floor(position.y) ~= position.y
		or position.x < -4000 or position.x > 4000 or position.y < -4000 or position.y > 4000 then
		return false
	end
	if type(appearance.alpha) ~= "number" or appearance.alpha < 0 or appearance.alpha > 1
		or type(appearance.scale) ~= "number" or appearance.scale < 0.5 or appearance.scale > 2
		or type(appearance.font) ~= "string"
		or (not NEW_MESSAGE_INDICATOR_FONTS[appearance.font] and not string.find(appearance.font, "^lsm:[^%c]+$"))
		or type(appearance.fontSize) ~= "number"
		or math.floor(appearance.fontSize) ~= appearance.fontSize
		or (appearance.fontSize ~= 0 and (appearance.fontSize < 8 or appearance.fontSize > 32))
		or not NEW_MESSAGE_INDICATOR_OUTLINES[appearance.outline] then
		return false
	end
	return isNormalizedNewMessageIndicatorColor(appearance.color)
		and isNormalizedNewMessageIndicatorColor(appearance.background)
		and isNormalizedNewMessageIndicatorColor(appearance.border)
end

local function normalizeNewMessageIndicatorAppearance(indicator)
	if type(indicator) ~= "table" then
		return nil
	end
	local fallback = defaults.dock.newMessages.appearance
	local appearance = indicator.appearance
	if type(appearance) ~= "table" then
		appearance = copy(fallback)
		indicator.appearance = appearance
	end
	if isNormalizedNewMessageIndicatorAppearance(appearance) then
		return appearance
	end
	appearance.position = normalizeNewMessageIndicatorPosition(appearance.position)
	appearance.alpha = clampNewMessageIndicatorNumber(appearance.alpha, fallback.alpha, 0, 1)
	appearance.scale = clampNewMessageIndicatorNumber(appearance.scale, fallback.scale, 0.5, 2)
	appearance.font = normalizeNewMessageIndicatorFont(appearance.font)
	-- Zero means use the original FontObject's exact size.  It is important for
	-- old layouts: adding the feature must not make their compact marker larger.
	appearance.fontSize = clampNewMessageIndicatorNumber(appearance.fontSize, fallback.fontSize, 0, 32, true)
	if appearance.fontSize > 0 and appearance.fontSize < 8 then
		appearance.fontSize = 8
	end
	appearance.outline = normalizeNewMessageIndicatorOutline(appearance.outline)
	appearance.color = normalizeNewMessageIndicatorColor(appearance.color, fallback.color)
	appearance.background = normalizeNewMessageIndicatorColor(appearance.background, fallback.background)
	appearance.border = normalizeNewMessageIndicatorColor(appearance.border, fallback.border)
	appearance.schema = NEW_MESSAGE_INDICATOR_APPEARANCE_SCHEMA
	return appearance
end

-- Keep source identity construction in lockstep with MessageEngine's channel
-- source IDs.  The settings-side copy is deliberately tiny so SpamControl can
-- ask the public detector before MessageEngine has normalized a line.
local function getChannelSourceId(channelName, channelBaseName)
	local label = trim(channelBaseName or channelName, 80)
	label = string.gsub(label, "^%d+%.%s*", "")
	local baseLabel = string.match(label, "^(.-)%s+%-%s+.+$")
	if baseLabel then
		label = trim(baseLabel, 80)
	end
	if label == "" then
		return nil
	end

	local token = string.lower(label)
	token = string.gsub(token, "^%d+%.%s*", "")
	token = string.gsub(token, "[^%w]+", "-")
	token = string.gsub(token, "%-+", "-")
	token = string.gsub(token, "^%-+", "")
	token = string.gsub(token, "%-+$", "")
	if token == "" then
		return nil
	end
	return "channel:" .. string.sub(token, 1, 64)
end

local function normalizeSyncSourceId(sourceId)
	sourceId = string.lower(trim(sourceId, 96))
	if string.find(sourceId, "^channel:[%w][%w%-]*$") == nil then
		return nil
	end
	return sourceId
end

local function syncSourceMapsEqual(left, right)
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	for sourceId, mode in pairs(left) do
		if right[sourceId] ~= mode then
			return false
		end
	end
	for sourceId, mode in pairs(right) do
		if left[sourceId] ~= mode then
			return false
		end
	end
	return true
end

local function normalizeSyncSettings(settings)
	local sync = settings.sync
	if type(sync) ~= "table" then
		sync = {}
		settings.sync = sync
	end
	-- Settings migration runs from GetSmartSettings.  Once this small subtree is
	-- canonical, leave it alone: the sync detector is intentionally usable from
	-- the chat-filter hot path and must never sort SavedVariables on each line.
	if sync.schema == SYNC_SETTINGS_SCHEMA
		and (sync.enabled == true or sync.enabled == false)
		and type(sync.sources) == "table"
		and type(sync.revision) == "number" then
		return sync
	end

	local changed = false
	if sync.enabled ~= true and sync.enabled ~= false then
		sync.enabled = true
		changed = true
	end

	local revision = math.max(0, math.floor(tonumber(sync.revision) or 0))
	if sync.revision ~= revision then
		sync.revision = revision
		changed = true
	end

	local rawSources = type(sync.sources) == "table" and sync.sources or {}
	local sourceIds = {}
	for sourceId in pairs(rawSources) do
		if type(sourceId) == "string" then
			table.insert(sourceIds, sourceId)
		end
	end
	table.sort(sourceIds)

	local normalized = {}
	local accepted = 0
	for index = 1, #sourceIds do
		local sourceId = normalizeSyncSourceId(sourceIds[index])
		local mode = rawSources[sourceIds[index]]
		if sourceId and (mode == true or mode == false) and normalized[sourceId] == nil then
			if accepted >= MAX_SYNC_SOURCE_OVERRIDES then
				break
			end
			normalized[sourceId] = mode
			accepted = accepted + 1
		end
	end
	if not syncSourceMapsEqual(rawSources, normalized) then
		sync.sources = normalized
		changed = true
	elseif sync.sources ~= rawSources then
		sync.sources = rawSources
	end

	if changed then
		sync.revision = revision + 1
	end
	sync.schema = SYNC_SETTINGS_SCHEMA
	return sync
end

local function refreshSyncRoutingCache(owner, settings, force)
	local sync = normalizeSyncSettings(settings)
	local revision = math.max(0, math.floor(tonumber(sync.revision) or 0))
	local existing = owner._syncRoutingCache
	if not force and existing and existing.settings == settings and existing.sync == sync
		and existing.revision == revision then
		return existing
	end

	local sources = {}
	for sourceId, mode in pairs(sync.sources) do
		if mode == true or mode == false then
			sources[sourceId] = mode
		end
	end
	local cache = {
		settings = settings,
		sync = sync,
		revision = revision,
		enabled = sync.enabled ~= false,
		sources = sources,
	}
	owner._syncRoutingCache = cache
	return cache
end

-- This is the read-only routing snapshot used by MessageEngine and
-- SpamControl.  Profile switches and setter calls replace it; routine chat
-- lines only compare a couple of table references and read an O(1) map.
function addon:GetSyncRoutingCache()
	local profile = self.db and self.db.profile
	local settings = profile and profile.smartChat
	local sync = type(settings) == "table" and settings.sync or nil
	local cache = self._syncRoutingCache
	if cache and cache.settings == settings and cache.sync == sync
		and type(sync) == "table"
		and cache.revision == sync.revision then
		return cache
	end
	settings = self:GetSmartSettings()
	return refreshSyncRoutingCache(self, settings)
end

local function isAutomaticSyncPayload(text)
	-- AscensionLogsCompanion's public-channel version check is intentionally the
	-- only automatic payload rule.  Anchoring it prevents normal player chat
	-- mentioning ALCver from silently disappearing into the Sync rail.
	if type(text) ~= "string" or string.len(text) > 96 then
		return false
	end
	return string.match(string.lower(text), "^alcver:version:%d+$") ~= nil
end

-- Public because SpamControl sees CHAT_MSG_CHANNEL before MessageEngine does.
-- It has no side effects and returns a reason plus the stable channel source
-- ID for callers that need to explain or cache the decision.
function addon:IsSyncProtocolMessage(event, text, channelName, channelBaseName)
	if event ~= "CHAT_MSG_CHANNEL" then
		return false, nil, nil
	end
	local sourceId = getChannelSourceId(channelName, channelBaseName)
	if not sourceId then
		return false, nil, nil
	end

	local cache = self:GetSyncRoutingCache()
	local override = cache.sources[sourceId]
	if override == true then
		return true, "source", sourceId
	elseif override == false then
		return false, "source-normal", sourceId
	end
	if not cache.enabled then
		return false, nil, sourceId
	end
	if sourceId == "channel:alcsync" then
		return true, "alcsync", sourceId
	end
	if isAutomaticSyncPayload(text) then
		return true, "alcver", sourceId
	end
	return false, nil, sourceId
end

local function normalizeTerms(value)
	local candidates = {}
	if type(value) == "string" then
		for term in string.gmatch(value, "([^,]+)") do
			table.insert(candidates, term)
		end
	elseif type(value) == "table" then
		for index = 1, #value do
			table.insert(candidates, value[index])
		end

		-- Accept set-style term tables too, while keeping array order intact.
		local setTerms = {}
		for term, enabled in pairs(value) do
			if type(term) == "string" and enabled then
				table.insert(setTerms, term)
			end
		end
		table.sort(setTerms)
		for index = 1, #setTerms do
			table.insert(candidates, setTerms[index])
		end
	end

	local terms = {}
	local seen = {}
	for index = 1, #candidates do
		if #terms >= MAX_CUSTOM_TERMS then
			break
		end
		local term = string.lower(trim(candidates[index], MAX_TERM_LENGTH))
		if term ~= "" and not seen[term] then
			seen[term] = true
			table.insert(terms, term)
		end
	end
	return terms
end

local function isSafeCustomViewId(id)
	return type(id) == "string"
		and string.len(id) <= 32
		and string.find(id, "^[%a][%w_%-]*$") ~= nil
		and not builtInViewIds[id]
end

local function defaultKey(label, index)
	local key = string.upper(string.gsub(label or "", "%s+", ""))
	key = trim(key, 6)
	if key == "" then
		key = "V" .. tostring(index)
	end
	return key
end

local function sanitizeCustomView(source, id, index)
	source = type(source) == "table" and source or {}
	local label = trim(source.label, 40)
	if label == "" then
		label = "Custom View " .. tostring(index)
	end
	local key = trim(source.key, 6)
	if key == "" then
		key = defaultKey(label, index)
	end
	return {
		id = id,
		key = key,
		label = label,
		description = trim(source.description, 160),
		terms = normalizeTerms(source.terms),
		enabled = source.enabled ~= false,
		custom = true,
	}
end

local customViewFields = {
	id = true,
	key = true,
	label = true,
	description = true,
	terms = true,
	enabled = true,
	custom = true,
}

local function customViewEqual(left, right)
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	for key in pairs(left) do
		if not customViewFields[key] then
			return false
		end
	end
	if left.id ~= right.id or left.key ~= right.key or left.label ~= right.label
		or left.description ~= right.description or left.enabled ~= right.enabled
		or left.custom ~= right.custom then
		return false
	end
	if type(left.terms) ~= "table" or #left.terms ~= #right.terms then
		return false
	end
	for index = 1, #right.terms do
		if left.terms[index] ~= right.terms[index] then
			return false
		end
	end
	return true
end

local function customViewListsEqual(left, right)
	if type(left) ~= "table" or #left ~= #right then
		return false
	end
	for key in pairs(left) do
		if type(key) ~= "number" or key < 1 or key > #right or key ~= math.floor(key) then
			return false
		end
	end
	for index = 1, #right do
		if not customViewEqual(left[index], right[index]) then
			return false
		end
	end
	return true
end

local function normalizeStoredCustomViews(settings)
	local source = type(settings.customViews) == "table" and settings.customViews or {}
	local sourceIndexes = {}
	for key, value in pairs(source) do
		if type(key) == "number" and key >= 1 and key == math.floor(key) and type(value) == "table" then
			table.insert(sourceIndexes, key)
		end
	end
	table.sort(sourceIndexes)

	local sequence = math.max(0, math.floor(tonumber(settings.customViewSequence) or 0))
	local usedIds = {}
	for id in pairs(builtInViewIds) do
		usedIds[id] = true
	end
	local views = {}
	for sourceIndex = 1, #sourceIndexes do
		if #views >= MAX_CUSTOM_VIEWS then
			break
		end
		local raw = source[sourceIndexes[sourceIndex]]
		local id = raw.id
		if not isSafeCustomViewId(id) or usedIds[id] then
			repeat
				sequence = sequence + 1
				id = "custom" .. tostring(sequence)
			until not usedIds[id]
		else
			local number = string.match(id, "^custom(%d+)$")
			if number then
				sequence = math.max(sequence, tonumber(number) or 0)
			end
		end
		usedIds[id] = true
		table.insert(views, sanitizeCustomView(raw, id, #views + 1))
	end

	local changed = not customViewListsEqual(source, views)
	settings.customViews = views
	settings.customViewSequence = sequence
	settings.customViewRevision = math.max(0, math.floor(tonumber(settings.customViewRevision) or 0))
	if changed then
		settings.customViewRevision = settings.customViewRevision + 1
	end
	return views, changed
end

-- Convert only the exact one-source custom Newcomers lens that predates the
-- built-in view. Broader term rules and locally styled custom views remain
-- untouched, so this migration cannot swallow a player's unrelated work.
local function migrateExactNewcomersCustomView(settings)
	local customViews = normalizeStoredCustomViews(settings)
	local viewOptions = type(settings.viewOptions) == "table" and settings.viewOptions or {}
	for index = 1, #customViews do
		local view = customViews[index]
		local options = viewOptions[view.id]
		local sources = type(options) == "table" and options.sources or nil
		local exactPresentation = string.lower(trim(view.label, 40)) == "newcomers"
			and string.upper(trim(view.key, 6)) == "NC"
		local exactTerms = type(view.terms) == "table" and #view.terms == 1
			and string.lower(trim(view.terms[1], MAX_TERM_LENGTH)) == "newcomers"
		local sourceIsolated = type(sources) == "table" and next(sources) ~= nil
			and sources["channel:newcomers"] ~= false
		if sourceIsolated then
			for sourceId, enabled in pairs(sources) do
				if sourceId ~= "channel:newcomers" and enabled ~= false then
					sourceIsolated = false
					break
				end
			end
		end
		local sourceOptionsOnly = type(options) == "table"
		if sourceOptionsOnly then
			for key in pairs(options) do
				if key ~= "sources" then
					sourceOptionsOnly = false
					break
				end
			end
		end

		if exactPresentation and exactTerms and sourceIsolated and sourceOptionsOnly then
			local customId = view.id
			local wasEnabled = view.enabled ~= false
				and (type(settings.views) ~= "table" or settings.views[customId] ~= false)
			table.remove(customViews, index)
			settings.customViews = customViews
			settings.customViewRevision = math.max(0,
				math.floor(tonumber(settings.customViewRevision) or 0)) + 1
			settings.views = type(settings.views) == "table" and settings.views or {}
			settings.views[customId] = nil
			settings.views.newcomers = wasEnabled
			viewOptions[customId] = nil

			if type(settings.railOrder) == "table" then
				for railIndex, viewId in pairs(settings.railOrder) do
					if type(railIndex) == "number" and viewId == customId then
						settings.railOrder[railIndex] = "newcomers"
					end
				end
			end
			if type(settings.dock) == "table" and settings.dock.activeView == customId then
				settings.dock.activeView = "newcomers"
			end
			if type(settings.channelTargets) == "table" then
				local target = tonumber(settings.channelTargets[customId])
				if target and target > 0 then
					settings.channelTargets.newcomers = math.floor(target)
				end
				settings.channelTargets[customId] = nil
			end
			return true
		end
	end
	return false
end

-- applyDefaults fills missing numeric array slots, which can make a newly
-- introduced rail look as though it was deliberately present in an old custom
-- order. Remove only this release's injected defaults before normalization so
-- the anchor rules can place them intentionally. An exact NC conversion keeps
-- its replaced slot because that location was already the player's choice.
local function prepareBuiltInSourceViewRailMigration(settings, keepMigratedNewcomers)
	local source = type(settings.railOrder) == "table" and settings.railOrder or {}
	local maximumIndex = #source
	for key in pairs(source) do
		if type(key) == "number" and key >= 1 and key == math.floor(key) then
			maximumIndex = math.max(maximumIndex, key)
		end
	end
	local clean = {}
	for index = 1, maximumIndex do
		local viewId = source[index]
		if type(viewId) == "string" and viewId ~= "guildInvites"
			and (keepMigratedNewcomers or viewId ~= "newcomers") then
			table.insert(clean, viewId)
		end
	end
	settings.railOrder = clean
end

-- Schema 2 introduces PVP after Guild Invites. AceDB/applyDefaults can expose
-- the new numeric default inside an older custom array before normalization;
-- remove only that newly injected ID so the anchor insertion below decides its
-- location without disturbing any rail the player already arranged.
local function preparePvpViewRailMigration(settings)
	local source = type(settings.railOrder) == "table" and settings.railOrder or {}
	local maximumIndex = #source
	for key in pairs(source) do
		if type(key) == "number" and key >= 1 and key == math.floor(key) then
			maximumIndex = math.max(maximumIndex, key)
		end
	end
	local clean = {}
	for index = 1, maximumIndex do
		local viewId = source[index]
		if type(viewId) == "string" and viewId ~= "pvp" then
			table.insert(clean, viewId)
		end
	end
	settings.railOrder = clean
end

local function notifyCustomViewChange(owner, settings)
	settings.customViewRevision = math.max(0, math.floor(tonumber(settings.customViewRevision) or 0)) + 1
	if owner.MessageEngine and owner.MessageEngine.ReclassifyAll then
		owner.MessageEngine:ReclassifyAll()
	end
end

local function railOrderEqual(left, right)
	if type(left) ~= "table" or #left ~= #right then
		return false
	end
	for key in pairs(left) do
		if type(key) ~= "number" or key < 1 or key > #right or key ~= math.floor(key) then
			return false
		end
	end
	for index = 1, #right do
		if left[index] ~= right[index] then
			return false
		end
	end
	return true
end

-- Canonicalize the display order in one place.  Saved IDs that no longer
-- exist (deleted custom rails), duplicates, and hand-edited junk are removed;
-- newly introduced built-ins/custom rails are appended in their natural order.
-- This remains visual state only: it must not touch customViews or trigger a
-- message reclassification.
local function normalizeRailOrder(settings, customViews)
	customViews = customViews or normalizeStoredCustomViews(settings)
	local known = {}
	for index = 1, #addon.SmartViews do
		known[addon.SmartViews[index].id] = true
	end
	for index = 1, #customViews do
		known[customViews[index].id] = true
	end

	local raw = type(settings.railOrder) == "table" and settings.railOrder or {}
	local order, seen = {}, {}
	local function add(viewId)
		if type(viewId) == "string" and known[viewId] and not seen[viewId] then
			seen[viewId] = true
			table.insert(order, viewId)
		end
	end
	-- Old SavedVariables can retain sparse numeric indexes. Derive their real
	-- high-water mark, then read every slot in order. Indexing (rather than only
	-- iterating raw keys) deliberately preserves AceDB defaults exposed through
	-- the table metatable for holes in an older saved order.
	local maximumIndex = #raw
	for key in pairs(raw) do
		if type(key) == "number" and key >= 1 and key == math.floor(key) then
			maximumIndex = math.max(maximumIndex, key)
		end
	end
	for index = 1, maximumIndex do
		add(raw[index])
	end

	-- A newly introduced factual-channel view belongs beside its conceptual
	-- anchor in an existing custom order. Already-present IDs are never moved.
	local function insertAfter(viewId, anchorId)
		if seen[viewId] or not known[viewId] then return end
		for index = 1, #order do
			if order[index] == anchorId then
				table.insert(order, index + 1, viewId)
				seen[viewId] = true
				return
			end
		end
	end
	insertAfter("newcomers", "general")
	insertAfter("guildInvites", "groupFinder")
	insertAfter("pvp", "guildInvites")
	for index = 1, #addon.SmartViews do
		add(addon.SmartViews[index].id)
	end
	for index = 1, #customViews do
		add(customViews[index].id)
	end
	if not railOrderEqual(raw, order) then
		settings.railOrder = order
	end
	return order
end

local function getViewOptions(settings, viewId, create)
	if type(settings.viewOptions) ~= "table" then
		if not create then
			return nil
		end
		settings.viewOptions = {}
	end

	local options = settings.viewOptions[viewId]
	if type(options) ~= "table" then
		if not create then
			return nil
		end
		options = {}
		settings.viewOptions[viewId] = options
	end
	return options
end

local function hasViewOptions(options)
	if type(options) ~= "table" then
		return false
	end
	if trim(options.label, 40) ~= "" or trim(options.key, 6) ~= ""
		or trim(options.description, 120) ~= "" then
		return true
	end
	if options.alignSources == true then
		return true
	end
	if type(options.textAppearance) == "table" and next(options.textAppearance) ~= nil then
		return true
	end
	return type(options.sources) == "table" and next(options.sources) ~= nil
end

local function removeEmptyViewOptions(settings, viewId)
	if type(settings.viewOptions) ~= "table" then
		return
	end
	local options = settings.viewOptions[viewId]
	if type(options) == "table" and not hasViewOptions(options) then
		settings.viewOptions[viewId] = nil
	end
end

local migrationStaticSourceIds = {
	"local:say", "local:yell", "local:emote", "local:text-emote",
	"addon:alcver", "system:addon-feedback",
	"conversation:whisper", "conversation:bnet-whisper", "conversation:bnet-conversation",
	"conversation:afk", "conversation:dnd",
	"guild:guild", "guild:achievement", "guild:officer",
	"group:party", "group:raid", "group:raid-warning", "group:battleground", "group:instance",
	"system:message", "system:ui-error", "system:local-debug", "system:achievement",
	"system:battleground", "system:under-attack", "loot:loot", "loot:money",
	-- The old checkbox erased a checked value, so keep the common learned
	-- channels in the migration vocabulary even when the learned-source cache
	-- was pruned before logout. This lets a restrictive custom allowlist recover
	-- its few remaining checked rows without guessing from message text.
	"channel:general", "channel:ascension", "channel:zone", "channel:newcomers",
	"channel:guildrecruitment", "channel:lookingforgroup", "channel:trade",
	"channel:defense", "channel:defence",
	"channel:localdefense", "channel:local-defence", "channel:localdefence", "channel:local-defence",
	"channel:worlddefense", "channel:world-defense", "channel:worlddefence", "channel:world-defence",
}

-- Old builds stored only unchecked rows (`false`); checking a row erased it.
-- Adopt the new clean source homes without turning every old nil into an
-- explicit feed. Preserve real hides, prune only redundant built-in values,
-- and recover a narrowly selected custom allowlist when the old profile has
-- enough false rows to identify its one-to-four remaining checked sources.
local function migrateViewSourceMembership(settings)
	local optionsByView = type(settings.viewOptions) == "table" and settings.viewOptions or {}
	local customViews = normalizeStoredCustomViews(settings)
	local customById = {}
	for index = 1, #customViews do
		customById[customViews[index].id] = true
	end

	local known, knownIds = {}, {}
	local function addKnown(sourceId)
		if type(sourceId) == "string" and sourceId ~= "" and not known[sourceId] then
			known[sourceId] = true
			table.insert(knownIds, sourceId)
		end
	end
	for index = 1, #migrationStaticSourceIds do addKnown(migrationStaticSourceIds[index]) end
	for sourceId in pairs(type(settings.learnedSources) == "table" and settings.learnedSources or {}) do
		addKnown(sourceId)
	end
	for _, options in pairs(optionsByView) do
		if type(options) == "table" and type(options.sources) == "table" then
			for sourceId in pairs(options.sources) do addKnown(sourceId) end
		end
	end
	table.sort(knownIds)

	for viewId, options in pairs(optionsByView) do
		local sources = type(options) == "table" and options.sources or nil
		if sources then
			local falseCount, trueCount = 0, 0
			for sourceId, value in pairs(sources) do
				if value ~= true and value ~= false then
					sources[sourceId] = nil
			elseif value then
					trueCount = trueCount + 1
				else
					falseCount = falseCount + 1
				end
			end

			if builtInViewIds[viewId] then
				for sourceId, value in pairs(sources) do
					-- A legacy false is still meaningful under the new model: it is a
					-- hard exclusion even when this source is not the tab's default
					-- feed, so a semantic/custom route cannot add it back. Only a
					-- redundant positive value for the factual home can be discarded.
					if value == true and isDefaultSourceEnabled(settings, viewId, sourceId) then
						sources[sourceId] = nil
					end
				end
			elseif customById[viewId] and trueCount == 0 and falseCount >= 4 then
				local selected = {}
				for index = 1, #knownIds do
					local sourceId = knownIds[index]
					if sources[sourceId] ~= false then table.insert(selected, sourceId) end
				end
				if #selected >= 1 and #selected <= 4 and falseCount >= (#selected * 2) then
					for index = 1, #selected do sources[selected[index]] = true end
				end
			end

			if next(sources) == nil then options.sources = nil end
			removeEmptyViewOptions(settings, viewId)
		end
	end
	settings.viewSourceMembershipSchema = VIEW_SOURCE_MEMBERSHIP_SCHEMA
end

local function findSmartView(owner, viewId)
	if type(viewId) ~= "string" or viewId == "" then
		return nil
	end
	local views = owner:GetSmartViews()
	for index = 1, #views do
		if views[index].id == viewId then
			return views[index]
		end
	end
	return nil
end

local function refreshSmartDock(owner, refreshViews)
	local dock = owner.SmartDock
	if not dock or not dock.frame then
		return
	end
	if refreshViews and dock.RefreshViews then
		dock:RefreshViews()
	end
	if refreshViews and dock.active and dock.GetActiveDefinition then
		local definition = dock:GetActiveDefinition()
		if definition and dock.title then
			dock.title:SetText(definition.label)
		end
		if definition and dock.subtitle then
			dock.subtitle:SetText(definition.description)
		end
	end
	-- Rebuild without SelectView: selecting the already-active view would erase
	-- a legitimate unread count whenever an unrelated rail is edited.
	if dock.RebuildActiveView then
		dock:RebuildActiveView()
	end
end

-- Typography is presentation-only. Prefer the focused live hook when the
-- dock provides it, but keep the existing rebuild fallback so a profile can
-- be edited safely during a mixed-version reload.
local function refreshSmartChatTextAppearance(owner)
	local dock = owner.SmartDock
	if not dock then
		return
	end
	if dock.RefreshSmartChatTextAppearance then
		dock:RefreshSmartChatTextAppearance()
	elseif dock.RefreshMessageFont then
		dock:RefreshMessageFont()
	elseif dock.RebuildActiveView then
		dock:RebuildActiveView()
	end
end

local function clearSmartDockUnread(owner, viewId)
	local dock = owner.SmartDock
	if not dock or type(dock.unread) ~= "table" then
		return
	end
	if viewId then
		dock.unread[viewId] = 0
	else
		for unreadViewId in pairs(dock.unread) do
			dock.unread[unreadViewId] = 0
		end
	end
	if dock.RefreshRailState then
		dock:RefreshRailState()
	end
end

function addon:GetSmartViews()
	local settings = self:GetSmartSettings()
	local customViews = normalizeStoredCustomViews(settings)
	local definitionsById = {}
	for index = 1, #self.SmartViews do
		local definition = copy(self.SmartViews[index])
		local options = getViewOptions(settings, definition.id, false)
		if options then
			local label = trim(options.label, 40)
			local key = trim(options.key, 6)
			local description = trim(options.description, 120)
			if label ~= "" then
				definition.label = label
			end
			if key ~= "" then
				definition.key = key
			end
			if description ~= "" then
				definition.description = description
			end
		end
		definition.custom = false
		definition.enabled = not settings.views or settings.views[definition.id] ~= false
		definitionsById[definition.id] = definition
	end
	for index = 1, #customViews do
		local definition = copy(customViews[index])
		definitionsById[definition.id] = definition
	end

	local result = {}
	local order = normalizeRailOrder(settings, customViews)
	for index = 1, #order do
		local definition = definitionsById[order[index]]
		if definition then
			table.insert(result, definition)
		end
	end
	return result
end

-- Public presentation-only reorder APIs.  These are intentionally separate
-- from custom-view CRUD so moving a tab is cheap and cannot perturb its
-- routing rule, source overrides, or persisted message membership.
function addon:MoveSmartViewToIndex(viewId, targetIndex)
	viewId = trim(viewId, 32)
	if viewId == "" then
		return false, "invalid-view"
	end
	local settings = self:GetSmartSettings()
	local customViews = normalizeStoredCustomViews(settings)
	local order = normalizeRailOrder(settings, customViews)
	local currentIndex
	for index = 1, #order do
		if order[index] == viewId then
			currentIndex = index
			break
		end
	end
	if not currentIndex then
		return false, "not-found"
	end

	targetIndex = math.floor(tonumber(targetIndex) or currentIndex)
	targetIndex = math.max(1, math.min(#order, targetIndex))
	if targetIndex == currentIndex then
		return true, currentIndex
	end
	table.remove(order, currentIndex)
	table.insert(order, targetIndex, viewId)
	settings.railOrder = order
	refreshSmartDock(self, true)
	return true, targetIndex
end

function addon:MoveSmartView(viewId, delta)
	local settings = self:GetSmartSettings()
	local customViews = normalizeStoredCustomViews(settings)
	local order = normalizeRailOrder(settings, customViews)
	local currentIndex
	for index = 1, #order do
		if order[index] == viewId then
			currentIndex = index
			break
		end
	end
	if not currentIndex then
		return false, "not-found"
	end
	local targetIndex = currentIndex + math.floor(tonumber(delta) or 0)
	return self:MoveSmartViewToIndex(viewId, targetIndex)
end

function addon:UpdateViewPresentation(viewId, label, key, description)
	local definition = findSmartView(self, viewId)
	if not definition then
		return nil, "not-found"
	end
	if definition.custom then
		local data = {}
		if label ~= nil then
			data.label = label
		end
		if key ~= nil then
			data.key = key
		end
		if description ~= nil then
			data.description = trim(description, 160)
		end
		local updated, reason = self:UpdateCustomView(viewId, data)
		if updated then
			refreshSmartDock(self, true)
		end
		return updated, reason
	end

	local settings = self:GetSmartSettings()
	local options = getViewOptions(settings, viewId, true)
	local nextLabel = trim(label, 40)
	local nextKey = trim(key, 6)
	options.label = nextLabel ~= "" and nextLabel or nil
	options.key = nextKey ~= "" and nextKey or nil
	-- Description was added after the original three-argument API. An omitted
	-- fourth argument must preserve an existing override so older callers that
	-- only rename a rail cannot erase information saved by the full editor.
	if description ~= nil then
		local nextDescription = trim(description, 120)
		options.description = nextDescription ~= "" and nextDescription or nil
	end
	removeEmptyViewOptions(settings, viewId)
	refreshSmartDock(self, true)
	return findSmartView(self, viewId)
end

function addon:ResetViewPresentation(viewId)
	local definition = findSmartView(self, viewId)
	if not definition then
		return false, "not-found"
	end
	if definition.custom then
		return false, "custom"
	end

	local settings = self:GetSmartSettings()
	local options = getViewOptions(settings, viewId, false)
	if options then
		options.label = nil
		options.key = nil
		-- This API backs the Rails & Sources "RESET NAME" action. Preserve the
		-- separately edited Organized Views description; users can clear that
		-- override explicitly by saving a blank description in its editor.
		removeEmptyViewOptions(settings, viewId)
	end
	refreshSmartDock(self, true)
	return true
end

-- Smart Chat typography is deliberately separate from the dormant native
-- ChatFont module.  The global record is the default for every tab; each view
-- may store only the fields it deliberately overrides.  Consumers receive
-- copies so they cannot accidentally mutate SavedVariables during rendering.
function addon:GetSmartChatTextAppearance(viewId)
	local settings = self:GetSmartSettings()
	local global = normalizeSmartChatTextAppearance(settings.textAppearance)
	settings.textAppearance = global
	if viewId == nil or viewId == "" or viewId == "global" then
		return copy(global)
	end
	if not findSmartView(self, viewId) then
		return nil, "not-found"
	end
	local appearance = copy(global)
	local options = getViewOptions(settings, viewId, false)
	local override = options and normalizeSmartChatTextAppearanceOverride(options.textAppearance)
	if options then
		options.textAppearance = override
	end
	if override then
		if override.font ~= nil then appearance.font = override.font end
		if override.size ~= nil then appearance.size = override.size end
		if override.outline ~= nil then appearance.outline = override.outline end
		if override.spacing ~= nil then appearance.spacing = override.spacing end
	end
	return appearance
end

-- Useful to the compact Views & Tabs inspector: this distinguishes a tab that
-- merely resolves to the same values from one that has a real local override.
function addon:GetSmartChatTextAppearanceOverride(viewId)
	if type(viewId) ~= "string" or viewId == "" or viewId == "global" then
		return nil
	end
	if not findSmartView(self, viewId) then
		return nil, "not-found"
	end
	local settings = self:GetSmartSettings()
	local options = getViewOptions(settings, viewId, false)
	local override = options and normalizeSmartChatTextAppearanceOverride(options.textAppearance)
	if options then
		options.textAppearance = override
	end
	return override and copy(override) or nil
end

function addon:GetSmartChatTextAppearanceOptions()
	return getSmartChatTextAppearanceOptions()
end

-- Resolve an optional raw LSM key. Returning nil intentionally means callers
-- should leave their current ChatFontNormal face alone. Known SharedMedia
-- faces retain a verified path fallback when Ascension's registry is absent;
-- arbitrary user strings are never treated as paths.
function addon:ResolveSmartChatTextFont(font)
	local key, valid = normalizeSmartChatTextFont(font)
	if not valid or key == nil then
		return nil
	end
	local media = getSharedMedia()
	if media then
		bootstrapSharedMediaFontPack(media)
		if type(media.Fetch) == "function" then
			-- Match Questie's resolver: noDefault prevents LSM from returning the
			-- generic Friz fallback for an absent key and masking our verified
			-- SharedMedia font-path fallback below.
			local ok, path = pcall(media.Fetch, media, "font", key, true)
			if ok and type(path) == "string" and path ~= "" then
				return path
			end
		end
	end
	return SHARED_MEDIA_KNOWN_FONT_PATHS[key]
end

local function normalizeSmartChatTextAppearancePatch(patch)
	if type(patch) ~= "table" then
		return nil, "invalid-patch"
	end
	local normalized = {}
	local changed = false
	if patch.font ~= nil then
		local font, valid = normalizeSmartChatTextFont(patch.font)
		if not valid then
			return nil, "invalid-font"
		end
		normalized.font = font
		changed = true
	end
	if patch.size ~= nil then
		local size = normalizeSmartChatTextSize(patch.size)
		if size == nil then
			return nil, "invalid-size"
		end
		normalized.size = size
		changed = true
	end
	if patch.outline ~= nil then
		local outline = normalizeSmartChatTextOutline(patch.outline)
		if outline == nil then
			return nil, "invalid-outline"
		end
		normalized.outline = outline
		changed = true
	end
	if patch.spacing ~= nil then
		local spacing = normalizeSmartChatTextSpacing(patch.spacing)
		if spacing == nil then
			return nil, "invalid-spacing"
		end
		normalized.spacing = spacing
		changed = true
	end
	if not changed then
		return nil, "invalid-patch"
	end
	return normalized
end

function addon:SetSmartChatTextAppearance(viewId, patch)
	if type(viewId) ~= "string" or viewId == "" then
		return false, "invalid-view"
	end
	local normalized, reason = normalizeSmartChatTextAppearancePatch(patch)
	if not normalized then
		return false, reason
	end

	local settings = self:GetSmartSettings()
	if viewId == "global" then
		local global = normalizeSmartChatTextAppearance(settings.textAppearance)
		if normalized.font ~= nil or patch.font ~= nil then global.font = normalized.font end
		if normalized.size ~= nil then global.size = normalized.size end
		if normalized.outline ~= nil then global.outline = normalized.outline end
		if normalized.spacing ~= nil then global.spacing = normalized.spacing end
		global.schema = SMART_CHAT_TEXT_APPEARANCE_SCHEMA
		settings.textAppearance = global
	else
		if not findSmartView(self, viewId) then
			return false, "not-found"
		end
		local options = getViewOptions(settings, viewId, true)
		local override = normalizeSmartChatTextAppearanceOverride(options.textAppearance) or {}
		-- A nil normalized font is an intentional "inherit current ChatFont" for
		-- global settings.  Per-view absence instead means inherit GLOBAL, so
		-- remove that one local field and keep any other local fields intact.
		if patch.font ~= nil then override.font = normalized.font end
		if normalized.size ~= nil then override.size = normalized.size end
		if normalized.outline ~= nil then override.outline = normalized.outline end
		if normalized.spacing ~= nil then override.spacing = normalized.spacing end
		options.textAppearance = normalizeSmartChatTextAppearanceOverride(override)
		removeEmptyViewOptions(settings, viewId)
	end
	refreshSmartChatTextAppearance(self)
	return true, self:GetSmartChatTextAppearance(viewId)
end

function addon:ResetSmartChatTextAppearance(viewId)
	if type(viewId) ~= "string" or viewId == "" then
		return false, "invalid-view"
	end
	local settings = self:GetSmartSettings()
	if viewId == "global" then
		settings.textAppearance = copy(defaults.textAppearance)
	else
		if not findSmartView(self, viewId) then
			return false, "not-found"
		end
		local options = getViewOptions(settings, viewId, false)
		if options then
			options.textAppearance = nil
			removeEmptyViewOptions(settings, viewId)
		end
	end
	refreshSmartChatTextAppearance(self)
	return true, self:GetSmartChatTextAppearance(viewId)
end

-- Compact global aliases make the common all-tabs case easy for integrations
-- and preserve the originally announced public surface.
function addon:GetSmartChatFontSettings()
	return self:GetSmartChatTextAppearance("global")
end

function addon:GetSmartChatFontOptions()
	return self:GetSmartChatTextAppearanceOptions()
end

function addon:SetSmartChatFont(font)
	return self:SetSmartChatTextAppearance("global", { font = font })
end

function addon:SetSmartChatFontSize(size)
	return self:SetSmartChatTextAppearance("global", { size = size })
end

function addon:SetSmartChatFontOutline(outline)
	return self:SetSmartChatTextAppearance("global", { outline = outline })
end

	-- Source-column alignment is a global display-only preference. It never
	-- changes routing, capture, or saved text: SmartDock rebuilds the active
	-- buffer immediately and formats every other tab when it is selected.
--
-- `viewId` stays in this public signature so older callers continue to work;
-- it is validated but no longer makes the display inconsistent between tabs.
function addon:GetViewSourceColumnAlignment(viewId)
	if not findSmartView(self, viewId) then
		return false, "not-found"
	end
	local settings = self:GetSmartSettings()
	if type(settings.dock) == "table" and settings.dock.sourceColumnAlignment ~= nil then
		return settings.dock.sourceColumnAlignment == true
	end
	-- Compatibility for a profile saved by the short-lived per-tab version.
	local options = getViewOptions(settings, viewId, false)
	return options and options.alignSources == true or false
end

function addon:SetViewSourceColumnAlignment(viewId, enabled)
	if not findSmartView(self, viewId) then
		return false, "not-found"
	end
	local settings = self:GetSmartSettings()
	settings.dock.sourceColumnAlignment = enabled and true or false
	local selectedFixedFont = enabled and ensureColumnAlignmentFont(settings) or false
	if selectedFixedFont then
		-- Applying the font also rebuilds the active buffer, now with both the
		-- fixed-width face and the newly enabled source lane in place.
		refreshSmartChatTextAppearance(self)
	else
		refreshSmartDock(self, false)
	end
	return true, enabled and true or false, selectedFixedFont
end

-- The channel gutter retains the original public name for compatibility. It is
-- display-only and clamped here so hand-edited SavedVariables cannot produce a
-- comically wide chat surface.
function addon:GetColumnAlignmentSpacing()
	local settings = self:GetSmartSettings()
	local dock = type(settings.dock) == "table" and settings.dock or nil
	return math.max(-8, math.min(8, math.floor(tonumber(dock and dock.columnAlignmentSpacing) or 2)))
end

function addon:GetSourceColumnAlignmentSpacing()
	return self:GetColumnAlignmentSpacing()
end

function addon:SetColumnAlignmentSpacing(value)
	local numeric = tonumber(value)
	if not numeric then
		return false, "invalid-spacing"
	end
	local spacing = numeric >= 0 and math.floor(numeric + 0.5) or math.ceil(numeric - 0.5)
	spacing = math.max(-8, math.min(8, spacing))
	local settings = self:GetSmartSettings()
	settings.dock.columnAlignmentSpacing = spacing
	if self.SmartDock and type(self.SmartDock.RefreshColumnAlignmentPresentation) == "function" then
		self.SmartDock:RefreshColumnAlignmentPresentation()
	else
		refreshSmartDock(self, false)
	end
	return true, spacing
end

function addon:SetSourceColumnAlignmentSpacing(value)
	return self:SetColumnAlignmentSpacing(value)
end

-- Newer profiles may choose a different gutter after [PLAYER]. An absent
-- value is deliberately the old channel GAP, which migrates every existing
-- profile without changing its current visual layout.
function addon:GetSenderColumnAlignmentSpacing()
	local settings = self:GetSmartSettings()
	local dock = type(settings.dock) == "table" and settings.dock or nil
	local inherited = dock and dock.columnAlignmentSpacing or 2
	return math.max(-8, math.min(8, math.floor(tonumber(dock and dock.senderColumnAlignmentSpacing) or inherited or 2)))
end

function addon:SetSenderColumnAlignmentSpacing(value)
	local numeric = tonumber(value)
	if not numeric then
		return false, "invalid-spacing"
	end
	local spacing = numeric >= 0 and math.floor(numeric + 0.5) or math.ceil(numeric - 0.5)
	spacing = math.max(-8, math.min(8, spacing))
	local settings = self:GetSmartSettings()
	settings.dock.senderColumnAlignmentSpacing = spacing
	if self.SmartDock and type(self.SmartDock.RefreshColumnAlignmentPresentation) == "function" then
		self.SmartDock:RefreshColumnAlignmentPresentation()
	else
		refreshSmartDock(self, false)
	end
	return true, spacing
end

function addon:GetSenderColumnMaxLength()
	local settings = self:GetSmartSettings()
	local dock = type(settings.dock) == "table" and settings.dock or nil
	return math.max(1, math.min(32, math.floor(tonumber(dock and dock.senderColumnMaxLength) or 14)))
end

function addon:SetSenderColumnMaxLength(value)
	local numeric = tonumber(value)
	if not numeric then return false, "invalid-length" end
	local length = math.max(1, math.min(32, math.floor(numeric + 0.5)))
	local settings = self:GetSmartSettings()
	settings.dock.senderColumnMaxLength = length
	if self.SmartDock and type(self.SmartDock.RefreshColumnAlignmentPresentation) == "function" then
		self.SmartDock:RefreshColumnAlignmentPresentation()
	else
		refreshSmartDock(self, false)
	end
	return true, length
end

function addon:GetAlignmentVisibleOnly()
	local settings = self:GetSmartSettings()
	return type(settings.dock) == "table" and settings.dock.alignmentVisibleOnly == true
end

function addon:SetAlignmentVisibleOnly(enabled)
	local settings = self:GetSmartSettings()
	settings.dock.alignmentVisibleOnly = enabled and true or false
	if self.SmartDock and type(self.SmartDock.RefreshColumnAlignmentPresentation) == "function" then
		self.SmartDock:RefreshColumnAlignmentPresentation()
	else
		refreshSmartDock(self, false)
	end
	return true, settings.dock.alignmentVisibleOnly
end

-- Sender-column alignment is another global presentation preference. It pads
-- only the rendered [PLAYER] label, never the stored sender identity or chat
-- text. Keeping it separately configurable lets compact layouts use natural
-- source widths while still lining up a run of messages from different names.
function addon:GetViewSenderColumnAlignment(viewId)
	if not findSmartView(self, viewId) then
		return false, "not-found"
	end
	local settings = self:GetSmartSettings()
	return type(settings.dock) == "table" and settings.dock.senderColumnAlignment == true
end

function addon:SetViewSenderColumnAlignment(viewId, enabled)
	if not findSmartView(self, viewId) then
		return false, "not-found"
	end
	local settings = self:GetSmartSettings()
	settings.dock.senderColumnAlignment = enabled and true or false
	local selectedFixedFont = enabled and ensureColumnAlignmentFont(settings) or false
	if selectedFixedFont then
		-- Refresh the face and the freshly enabled name lane together so the
		-- first visible line uses the same fixed-width metrics as every later one.
		refreshSmartChatTextAppearance(self)
	else
		refreshSmartDock(self, false)
	end
	return true, enabled and true or false, selectedFixedFont
end

function addon:GetDefaultViewForSource(sourceId, sourceGroup)
	return getDefaultSourceHome(self:GetSmartSettings(), sourceId, sourceGroup)
end

-- CONTENTS is an additive factual-source feed. The classifier/custom rules
-- remain independent, so a record may be visible through either path without
-- being copied in memory or SavedVariables. Explicit false remains a hard
-- per-view exclusion for backward compatibility. Protocol records stay in
-- Sync even when their carrier channel normally has a human source home.
function addon:IsRecordIncludedBySource(viewId, record, settings)
	if type(viewId) ~= "string" or viewId == "" or type(record) ~= "table" then
		return false
	end
	if type(record.sourceId) ~= "string" or record.sourceId == "" then
		if self.MessageEngine and self.MessageEngine.EnsureSource then
			self.MessageEngine:EnsureSource(record)
		end
	end
	local sourceId = record.sourceId
	if type(sourceId) ~= "string" or sourceId == "" then return false end
	local syncRecord = record.isSync == true or sourceId == "addon:alcver"
	if syncRecord ~= (viewId == "sync") then return false end

	settings = settings or self:GetSmartSettings()
	local options = getViewOptions(settings, viewId, false)
	local override
	if options and type(options.sources) == "table" then
		override = options.sources[sourceId]
	end
	if override ~= nil then return override == true end
	return isDefaultSourceEnabled(settings, viewId, sourceId, record.sourceGroup)
end

function addon:IsRecordSourceIncludedInView(viewId, record, settings)
	return self:IsRecordIncludedBySource(viewId, record, settings)
end

function addon:SetViewSourceEnabled(viewId, sourceId, value)
	if not findSmartView(self, viewId) then
		return false, "not-found"
	end
	sourceId = trim(sourceId, 96)
	if sourceId == "" then
		return false, "invalid-source"
	end

	local settings = self:GetSmartSettings()
	if value == true and isSourceFeedLocked(settings, viewId, sourceId) then
		return false, "sync-quarantined"
	end
	local options = getViewOptions(settings, viewId, true)
	if type(options.sources) ~= "table" then
		options.sources = {}
	end
	local defaultEnabled = isDefaultSourceEnabled(settings, viewId, sourceId)
	-- Store only deviations from the clean factual home. A checked non-default
	-- source is a real positive feed and therefore must persist as true.
	if value == nil or (value == true) == defaultEnabled then
		options.sources[sourceId] = nil
	else
		options.sources[sourceId] = value == true
	end
	if next(options.sources) == nil then
		options.sources = nil
	end
	removeEmptyViewOptions(settings, viewId)
	clearSmartDockUnread(self, viewId)
	refreshSmartDock(self, false)
	return true
end

function addon:ResetViewSources(viewId)
	if not findSmartView(self, viewId) then
		return false, "not-found"
	end
	local settings = self:GetSmartSettings()
	local options = getViewOptions(settings, viewId, false)
	if options then
		options.sources = nil
		removeEmptyViewOptions(settings, viewId)
	end
	clearSmartDockUnread(self, viewId)
	refreshSmartDock(self, false)
	return true
end

-- SYNC controls are deliberately source-level rather than view-level.  That
-- makes a noisy protocol channel disappear from every human rail at once,
-- instead of asking the player to turn it off in General, Trade, and so on.
function addon:IsSourceSyncEligible(sourceId)
	return normalizeSyncSourceId(sourceId) ~= nil
end

function addon:GetSourceSyncOverride(sourceId)
	sourceId = normalizeSyncSourceId(sourceId)
	if not sourceId then
		return nil
	end
	return self:GetSyncRoutingCache().sources[sourceId]
end

function addon:GetSourceSyncMode(sourceId)
	return self:GetSourceSyncOverride(sourceId)
end

function addon:GetSyncSourceOverride(sourceId)
	return self:GetSourceSyncOverride(sourceId)
end

function addon:GetSyncSourceMode(sourceId)
	return self:GetSourceSyncOverride(sourceId)
end

function addon:SetSourceSyncOverride(sourceId, value)
	sourceId = normalizeSyncSourceId(sourceId)
	if not sourceId then
		return false, "ineligible-source"
	end
	if value ~= nil and value ~= true and value ~= false then
		return false, "invalid-mode"
	end

	local sync = normalizeSyncSettings(self:GetSmartSettings())
	local previous = sync.sources[sourceId]
	if previous == value then
		return true, previous
	end

	if value == nil then
		sync.sources[sourceId] = nil
	else
		local count = 0
		for _ in pairs(sync.sources) do
			count = count + 1
		end
		if previous == nil and count >= MAX_SYNC_SOURCE_OVERRIDES then
			return false, "limit"
		end
		sync.sources[sourceId] = value
	end
	sync.revision = math.max(0, math.floor(tonumber(sync.revision) or 0)) + 1
	refreshSyncRoutingCache(self, self:GetSmartSettings(), true)

	local engine = self.MessageEngine
	if engine and engine.InvalidateSyncClassifier then
		engine:InvalidateSyncClassifier()
	end
	if engine and engine.ReclassifyAll then
		engine:ReclassifyAll()
	end
	-- Reclassification can move every retained line between Sync and its human
	-- source home. Old inactive badges no longer describe either destination.
	clearSmartDockUnread(self)
	refreshSmartDock(self, false)
	return true, value
end

function addon:SetSourceSyncMode(sourceId, value)
	return self:SetSourceSyncOverride(sourceId, value)
end

function addon:SetSyncSourceOverride(sourceId, value)
	return self:SetSourceSyncOverride(sourceId, value)
end

function addon:SetSyncSourceMode(sourceId, value)
	return self:SetSourceSyncOverride(sourceId, value)
end

function addon:GetSyncSourceEnabled(sourceId)
	return self:GetSourceSyncOverride(sourceId)
end

function addon:SetSyncSourceEnabled(sourceId, value)
	return self:SetSourceSyncOverride(sourceId, value)
end

function addon:IsRecordAllowedInView(viewId, record, settings)
	if type(record) ~= "table" then
		return false
	end
	if type(viewId) ~= "string" or viewId == "" then
		return true
	end
	if type(record.sourceId) ~= "string" or record.sourceId == "" then
		if self.MessageEngine and self.MessageEngine.EnsureSource then
			self.MessageEngine:EnsureSource(record)
		end
	end
	local sourceId = record.sourceId
	if type(sourceId) ~= "string" or sourceId == "" then
		return true
	end

	settings = settings or self:GetSmartSettings()
	local options = getViewOptions(settings, viewId, false)
	if options and type(options.sources) == "table" and options.sources[sourceId] == false then
		return false
	end
	local syncRecord = record.isSync == true or sourceId == "addon:alcver"
	if syncRecord then return viewId == "sync" end
	if viewId == "sync" then return false end
	-- False is the only exclusion. Nil now means "use the clean home/default"
	-- and true is an additive source feed handled by IsRecordIncludedBySource.
	return true
end

function addon:GetViewSourceDefinitions(viewId)
	if not findSmartView(self, viewId) then
		return {}
	end
	local settings = self:GetSmartSettings()
	local options = getViewOptions(settings, viewId, false)
	local sources = options and options.sources
	local definitions = {}
	if self.MessageEngine and self.MessageEngine.GetSourceDefinitions then
		definitions = self.MessageEngine:GetSourceDefinitions()
	end

	local seen = {}
	for index = 1, #definitions do
		local definition = definitions[index]
		local sourceId = definition.sourceId or definition.id
		-- Do not use `and ... or nil` here: Lua treats a deliberately saved
		-- `false` (the source is hidden in this rail) as the fallback. That made
		-- the Message Sources X redraw as checked immediately after a valid
		-- disable, even though the live filter had correctly applied it.
		local sourceOverride
		if type(sources) == "table" then
			sourceOverride = sources[sourceId]
		end
		definition.sourceId = sourceId
		definition.id = sourceId
		definition.sourceGroup = definition.sourceGroup or definition.group or "other"
		definition.group = definition.sourceGroup
		definition.sourceLabel = definition.sourceLabel or definition.label or sourceId
		definition.label = definition.sourceLabel
		definition.override = sourceOverride
		definition.defaultEnabled = isDefaultSourceEnabled(
			settings, viewId, sourceId, definition.sourceGroup)
		definition.feedLocked = isSourceFeedLocked(
			settings, viewId, sourceId, definition.sourceGroup)
		definition.feedLockReason = definition.feedLocked and "sync-only" or nil
		if definition.feedLocked then
			definition.enabled = false
		elseif definition.override ~= nil then
			definition.enabled = definition.override == true
		else
			definition.enabled = definition.defaultEnabled
		end
		definition.syncEligible = self:IsSourceSyncEligible(sourceId)
		definition.syncOverride = self:GetSourceSyncOverride(sourceId)
		definition.syncMode = definition.syncOverride
		seen[sourceId] = true
	end
	if type(sources) == "table" then
		for sourceId in pairs(sources) do
			if not seen[sourceId] then
				local feedLocked = isSourceFeedLocked(settings, viewId, sourceId, "other")
				table.insert(definitions, {
					id = sourceId,
					sourceId = sourceId,
					group = "other",
					sourceGroup = "other",
					label = sourceId,
					sourceLabel = sourceId,
					override = sources[sourceId],
					defaultEnabled = isDefaultSourceEnabled(settings, viewId, sourceId, "other"),
					feedLocked = feedLocked,
					feedLockReason = feedLocked and "sync-only" or nil,
					enabled = not feedLocked and (sources[sourceId] == true
						or (sources[sourceId] == nil
							and isDefaultSourceEnabled(settings, viewId, sourceId, "other"))),
					syncEligible = self:IsSourceSyncEligible(sourceId),
					syncOverride = self:GetSourceSyncOverride(sourceId),
					syncMode = self:GetSourceSyncOverride(sourceId),
				})
				seen[sourceId] = true
			end
		end
	end
	-- An overridden source can outlive the learned source cache (for example
	-- after a server-side channel rename).  Keep it visible so the player can
	-- always return it to AUTO instead of being stranded with a hidden rule.
	local sync = self:GetSyncRoutingCache()
	for sourceId, mode in pairs(sync.sources) do
		if not seen[sourceId] then
			local sourceOverride
			if type(sources) == "table" then
				sourceOverride = sources[sourceId]
			end
			local feedLocked = isSourceFeedLocked(settings, viewId, sourceId, "channels")
			table.insert(definitions, {
				id = sourceId,
				sourceId = sourceId,
				group = "channels",
				sourceGroup = "channels",
				label = string.gsub(sourceId, "^channel:", ""),
				sourceLabel = string.gsub(sourceId, "^channel:", ""),
				override = sourceOverride,
				defaultEnabled = isDefaultSourceEnabled(settings, viewId, sourceId, "channels"),
				feedLocked = feedLocked,
				feedLockReason = feedLocked and "sync-only" or nil,
				enabled = not feedLocked and (sourceOverride == true
					or (sourceOverride == nil
						and isDefaultSourceEnabled(settings, viewId, sourceId, "channels"))),
				syncEligible = true,
				syncOverride = mode,
				syncMode = mode,
			})
		end
	end
	table.sort(definitions, function(left, right)
		local leftGroup = left.sourceGroup or ""
		local rightGroup = right.sourceGroup or ""
		if leftGroup ~= rightGroup then
			return leftGroup < rightGroup
		end
		return (left.sourceLabel or left.sourceId or "") < (right.sourceLabel or right.sourceId or "")
	end)
	return definitions
end

function addon:CreateCustomView(data)
	local settings = self:GetSmartSettings()
	local customViews = normalizeStoredCustomViews(settings)
	if #customViews >= MAX_CUSTOM_VIEWS then
		return nil, "limit"
	end

	local usedIds = {}
	for id in pairs(builtInViewIds) do
		usedIds[id] = true
	end
	for index = 1, #customViews do
		usedIds[customViews[index].id] = true
	end
	local id
	repeat
		settings.customViewSequence = settings.customViewSequence + 1
		id = "custom" .. tostring(settings.customViewSequence)
	until not usedIds[id]

	local view = sanitizeCustomView(data, id, #customViews + 1)
	table.insert(customViews, view)
	settings.views[id] = view.enabled ~= false
	-- Keep a new custom rail at the end of the presentation sequence without
	-- disturbing the customViews array (which retains creation/rule ownership).
	normalizeRailOrder(settings, customViews)
	notifyCustomViewChange(self, settings)
	return copy(view)
end

function addon:UpdateCustomView(id, data)
	local settings = self:GetSmartSettings()
	local customViews = normalizeStoredCustomViews(settings)
	for index = 1, #customViews do
		local existing = customViews[index]
		if existing.id == id then
			data = type(data) == "table" and data or {}
			local enabled = existing.enabled
			if data.enabled ~= nil then
				enabled = data.enabled and true or false
			end
			local merged = {
				label = data.label ~= nil and data.label or existing.label,
				key = data.key ~= nil and data.key or existing.key,
				description = data.description ~= nil and data.description or existing.description,
				terms = data.terms ~= nil and data.terms or existing.terms,
				enabled = enabled,
			}
			local updated = sanitizeCustomView(merged, existing.id, index)
			if not customViewEqual(existing, updated) then
				customViews[index] = updated
				notifyCustomViewChange(self, settings)
			end
			-- Keep the visibility mirror authoritative even when a prior build or
			-- manual SavedVariables edit left it out of sync with an otherwise
			-- unchanged custom definition.
			if data.enabled ~= nil then
				settings.views[id] = updated.enabled ~= false
			end
			return copy(updated)
		end
	end
	return nil, "not-found"
end

function addon:DeleteCustomView(id)
	local settings = self:GetSmartSettings()
	local customViews = normalizeStoredCustomViews(settings)
	for index = 1, #customViews do
		if customViews[index].id == id then
			table.remove(customViews, index)
			settings.views[id] = nil
			if type(settings.viewOptions) == "table" then
				settings.viewOptions[id] = nil
			end
			normalizeRailOrder(settings, customViews)
			notifyCustomViewChange(self, settings)
			return true
		end
	end
	return false, "not-found"
end

local railVisibilityAliases = {
	always = "always",
	show = "always",
	shown = "always",
	visible = "always",
	on = "always",
	mouseover = "mouseover",
	onmouseover = "mouseover",
	mouse = "mouseover",
	hover = "mouseover",
	onhover = "mouseover",
	framehover = "mouseover",
	framemouseover = "mouseover",
	click = "click",
	onclick = "click",
	auto = "click",
	autohide = "click",
	toggle = "click",
	hidden = "hidden",
	hide = "hidden",
	off = "hidden",
	never = "hidden",
	none = "hidden",
}

local headerVisibilityAliases = {
	always = "always",
	show = "always",
	shown = "always",
	visible = "always",
	on = "always",
	["true"] = "always",
	["1"] = "always",
	hover = "hover",
	onhover = "hover",
	mouseover = "hover",
	onmouseover = "hover",
	mouse = "hover",
	auto = "hover",
	autohide = "hover",
	contextual = "hover",
	default = "hover",
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
	elseif value == false or value == nil then
		return "hover"
	elseif type(value) == "string" then
		local compact = string.gsub(string.lower(value), "[%s_%-]", "")
		return headerVisibilityAliases[compact] or "hover"
	end
	return "hover"
end

-- Keep the small block subtree well-formed before the hot-path BlockControl
-- reads it. Detailed rule sanitation lives with that engine; this migration is
-- intentionally limited to persistent shape and safe UI-feedback bounds.
local function normalizeBlockSettings(settings)
	local blocks = settings.blocks
	if type(blocks) ~= "table" then
		blocks = copy(defaults.blocks)
		settings.blocks = blocks
	end
	if blocks.enabled == nil then
		blocks.enabled = true
	else
		blocks.enabled = blocks.enabled and true or false
	end
	if type(blocks.rules) ~= "table" then
		blocks.rules = {}
	end
	blocks.sequence = math.max(0, math.floor(tonumber(blocks.sequence) or 0))
	blocks.revision = math.max(0, math.floor(tonumber(blocks.revision) or 0))
	if type(blocks.uiFeedback) ~= "table" then
		blocks.uiFeedback = copy(defaults.blocks.uiFeedback)
	end
	local uiFeedback = blocks.uiFeedback
	if uiFeedback.coalesce == nil then
		uiFeedback.coalesce = true
	else
		uiFeedback.coalesce = uiFeedback.coalesce and true or false
	end
	local window = tonumber(uiFeedback.window)
	if window == nil then
		window = defaults.blocks.uiFeedback.window
	end
	if window < 0.25 then
		window = 0.25
	elseif window > 10 then
		window = 10
	end
	uiFeedback.window = window
	if type(blocks.archive) ~= "table" then
		blocks.archive = copy(defaults.blocks.archive)
	end
	local archive = blocks.archive
	archive.schema = 1
	archive.enabled = archive.enabled ~= false
	archive.maxEntries = math.max(25, math.min(1000,
		math.floor((tonumber(archive.maxEntries) or defaults.blocks.archive.maxEntries) + 0.5)))
	archive.retentionDays = math.max(1, math.min(90,
		math.floor((tonumber(archive.retentionDays) or defaults.blocks.archive.retentionDays) + 0.5)))
	archive.nextSequence = math.max(1, math.floor(tonumber(archive.nextSequence) or 1))
	if type(archive.entries) ~= "table" then archive.entries = {} end
	return blocks
end

local MESSAGE_ROUTE_OVERRIDE_LIMIT = 64
local MESSAGE_ROUTE_OVERRIDE_SCHEMA = 2
-- These are the built-in destinations that can safely receive a public-channel
-- line as its primary route.  Private/social rails (CHAT, GROUP, GUILD) keep
-- their meaning, and SYNC remains reserved for protocol traffic.  Custom views
-- continue to receive their own term-based membership rather than becoming a
-- brittle primary classifier target.
local messageRouteOverrideDestinations = {
	{ id = "general", label = "GENERAL" },
	{ id = "newcomers", label = "NEWCOMERS" },
	{ id = "groupFinder", label = "GROUP FINDER" },
	{ id = "guildInvites", label = "GUILD INVITES" },
	{ id = "pvp", label = "PVP" },
	{ id = "trade", label = "TRADE" },
	{ id = "system", label = "SYSTEM" },
	{ id = "loot", label = "LOOT" },
}
local messageRouteOverrideCategories = {}
for index = 1, #messageRouteOverrideDestinations do
	messageRouteOverrideCategories[messageRouteOverrideDestinations[index].id] = true
end

-- Public UI data for Shift > ANALYZE.  Return fresh rows so callers cannot
-- mutate the validation table that protects SavedVariables and classification.
function addon:GetMessageRouteOverrideDestinations()
	local destinations = {}
	for index = 1, #messageRouteOverrideDestinations do
		local destination = messageRouteOverrideDestinations[index]
		table.insert(destinations, { id = destination.id, label = destination.label })
	end
	return destinations
end

local function normalizeMessageRouteOverrideText(value)
	if type(value) ~= "string" then
		return nil
	end
	value = string.lower(value)
	value = string.gsub(value, "%s+", " ")
	value = trim(value, 180)
	if value == "" then
		return nil
	end
	return value
end

local function normalizeMessageRouteOverrides(settings)
	local stored = type(settings.messageRouteOverrides) == "table" and settings.messageRouteOverrides or {}
	if settings.messageRouteOverrideSchema == MESSAGE_ROUTE_OVERRIDE_SCHEMA then
		return stored
	end
	local keys = {}
	for key, category in pairs(stored) do
		local normalized = normalizeMessageRouteOverrideText(key)
		if normalized and messageRouteOverrideCategories[category] then
			table.insert(keys, normalized)
		end
	end
	table.sort(keys)
	local normalized = {}
	for index = 1, math.min(#keys, MESSAGE_ROUTE_OVERRIDE_LIMIT) do
		local key = keys[index]
		-- A normalized duplicate is equivalent, so the deterministic first key
		-- wins. The original table cannot carry private records because setters
		-- below only accept CHAT_MSG_CHANNEL.
		if normalized[key] == nil then
			local category = stored[key]
			if not messageRouteOverrideCategories[category] then
				for rawKey, rawCategory in pairs(stored) do
					if normalizeMessageRouteOverrideText(rawKey) == key and messageRouteOverrideCategories[rawCategory] then
						category = rawCategory
						break
					end
				end
			end
			if messageRouteOverrideCategories[category] then
				normalized[key] = category
			end
		end
	end
	settings.messageRouteOverrides = normalized
	settings.messageRouteOverrideSchema = MESSAGE_ROUTE_OVERRIDE_SCHEMA
	return normalized
end

-- Keep the inactive-rail unread badge small enough to fit inside the dock's
-- narrowest supported rail. This setting intentionally has no font-face,
-- color, or outline options: it remains a themed count rather than becoming a
-- second tab label style surface.
local function normalizeRailUnreadCountAppearance(dock)
	if type(dock) ~= "table" then
		return nil
	end
	local fallback = defaults.dock.unreadCountAppearance
	local appearance = dock.unreadCountAppearance
	if type(appearance) ~= "table" then
		appearance = copy(fallback)
		dock.unreadCountAppearance = appearance
	end
	appearance.alpha = clampNewMessageIndicatorNumber(appearance.alpha, fallback.alpha, 0, 1)
	appearance.fontSize = clampNewMessageIndicatorNumber(appearance.fontSize, fallback.fontSize,
		0, RAIL_UNREAD_COUNT_FONT_SIZE_MAX, true)
	if appearance.fontSize > 0 and appearance.fontSize < RAIL_UNREAD_COUNT_FONT_SIZE_MIN then
		appearance.fontSize = RAIL_UNREAD_COUNT_FONT_SIZE_MIN
	end
	appearance.schema = RAIL_UNREAD_COUNT_APPEARANCE_SCHEMA
	return appearance
end

-- Normalize the tiny active-view NEW indicator subtree here rather than in
-- SmartDock's hot path.  The button's count is transient runtime state; these
-- are presentation preferences only.  A two/three digit cap remains readable
-- in the compact title bar without turning the control into a large badge.
local function normalizeNewMessageIndicatorSettings(dock)
	if type(dock) ~= "table" then
		return nil
	end
	local indicator = dock.newMessages
	if type(indicator) ~= "table" then
		indicator = copy(defaults.dock.newMessages)
		dock.newMessages = indicator
	end
	if indicator.enabled == nil then
		indicator.enabled = true
	else
		indicator.enabled = indicator.enabled and true or false
	end
	if indicator.showCount == nil then
		indicator.showCount = true
	else
		indicator.showCount = indicator.showCount and true or false
	end
	local maxCount = tonumber(indicator.maxCount)
	if maxCount == nil then
		maxCount = defaults.dock.newMessages.maxCount
	end
	maxCount = math.floor(maxCount + 0.5)
	if maxCount < 9 then
		maxCount = 9
	elseif maxCount > 999 then
		maxCount = 999
	end
	indicator.maxCount = maxCount
	normalizeNewMessageIndicatorAppearance(indicator)
	return indicator
end

local function normalizeChatHistoryLinesPerSource(value)
	local lines = tonumber(value)
	if lines == nil then
		lines = CHAT_HISTORY_DEFAULT_LINES_PER_SOURCE
	end
	lines = math.floor(lines + 0.5)
	if lines < CHAT_HISTORY_MIN_LINES_PER_SOURCE then
		lines = CHAT_HISTORY_MIN_LINES_PER_SOURCE
	elseif lines > CHAT_HISTORY_MAX_LINES_PER_SOURCE then
		lines = CHAT_HISTORY_MAX_LINES_PER_SOURCE
	end
	return lines
end

local messageBandExtents = {
	full = true,
	afterTimestamp = true,
	afterChannel = true,
	afterPlayer = true,
}

local messageBandThemeColors = {
	background = true,
	surface = true,
	surfaceRaised = true,
	inset = true,
	border = true,
	borderMuted = true,
	text = true,
	textMuted = true,
	gold = true,
	goldBright = true,
	accent = true,
	accentSoft = true,
	success = true,
	warning = true,
	danger = true,
}

local function normalizeOpacityUnit(value, fallback)
	value = tonumber(value)
	if value == nil then value = tonumber(fallback) or 1 end
	return math.max(0, math.min(1, value))
end

local messengerAppearanceTargets = {
	window = true,
	title = true,
	tabs = true,
	chat = true,
	reply = true,
	border = true,
}

local messengerAppearanceThemeColors = {
	background = true,
	surface = true,
	surfaceRaised = true,
	inset = true,
	border = true,
	borderMuted = true,
	text = true,
	textMuted = true,
	gold = true,
	goldBright = true,
	accent = true,
	accentSoft = true,
	success = true,
	warning = true,
	danger = true,
}

local function normalizeMessengerAppearanceColor(value)
	if type(value) == "string" then
		if value == "inherit" then
			return { mode = "inherit" }
		end
		if messengerAppearanceThemeColors[value] then
			return { mode = "theme", theme = value }
		end
		return { mode = "inherit" }
	end
	value = type(value) == "table" and value or {}
	local mode = type(value.mode) == "string" and string.lower(value.mode) or "inherit"
	if mode == "theme" and messengerAppearanceThemeColors[value.theme] then
		return { mode = "theme", theme = value.theme }
	end
	if mode == "custom" then
		return {
			mode = "custom",
			r = normalizeOpacityUnit(value.r, 1),
			g = normalizeOpacityUnit(value.g, 1),
			b = normalizeOpacityUnit(value.b, 1),
		}
	end
	return { mode = "inherit" }
end

local function normalizeMessengerAppearance(conversations)
	local stored = type(conversations.appearance) == "table" and conversations.appearance or {}
	local transparency = type(stored.transparency) == "table" and stored.transparency or {}
	local fallback = defaults.conversations.appearance
	local fallbackTransparency = fallback.transparency
	local colors = type(stored.colors) == "table" and stored.colors or {}
	local normalized = {
		schema = MESSENGER_APPEARANCE_SCHEMA,
		transparency = {
			backgroundAlpha = normalizeOpacityUnit(transparency.backgroundAlpha, fallbackTransparency.backgroundAlpha),
			borderAlpha = normalizeOpacityUnit(transparency.borderAlpha, fallbackTransparency.borderAlpha),
			textAlpha = normalizeOpacityUnit(transparency.textAlpha, fallbackTransparency.textAlpha),
			overallAlpha = normalizeOpacityUnit(transparency.overallAlpha, fallbackTransparency.overallAlpha),
		},
		colors = {},
	}
	for target in pairs(messengerAppearanceTargets) do
		normalized.colors[target] = normalizeMessengerAppearanceColor(colors[target])
	end
	conversations.appearance = normalized
	return normalized
end

local function normalizeDockTransparency(dock)
	local stored = type(dock.transparency) == "table" and dock.transparency or {}
	local fallback = defaults.dock.transparency
	dock.transparency = {
		backgroundAlpha = normalizeOpacityUnit(stored.backgroundAlpha, fallback.backgroundAlpha),
		borderAlpha = normalizeOpacityUnit(stored.borderAlpha, fallback.borderAlpha),
		overallAlpha = normalizeOpacityUnit(stored.overallAlpha, fallback.overallAlpha),
	}
	return dock.transparency
end

local function normalizePlayerActionAutoHideSeconds(value)
	local seconds = tonumber(value)
	if seconds == nil then
		seconds = PLAYER_ACTION_AUTO_HIDE_DEFAULT_SECONDS
	end
	seconds = math.floor(seconds + 0.5)
	if seconds < PLAYER_ACTION_AUTO_HIDE_MIN_SECONDS then
		seconds = PLAYER_ACTION_AUTO_HIDE_MIN_SECONDS
	elseif seconds > PLAYER_ACTION_AUTO_HIDE_MAX_SECONDS then
		seconds = PLAYER_ACTION_AUTO_HIDE_MAX_SECONDS
	end
	return seconds
end

local function normalizeDockPlayerActions(dock)
	local stored = type(dock.playerActions) == "table" and dock.playerActions or {}
	dock.playerActions = {
		autoHide = stored.autoHide ~= false,
		autoHideSeconds = normalizePlayerActionAutoHideSeconds(stored.autoHideSeconds),
	}
	return dock.playerActions
end

local function normalizeDockMessageBands(dock)
	local stored = type(dock.messageBands) == "table" and dock.messageBands or {}
	local fallback = defaults.dock.messageBands
	local storedColor = type(stored.color) == "table" and stored.color or {}
	local fallbackColor = fallback.color
	local theme = type(stored.color) == "string" and stored.color or storedColor.theme
	local mode = storedColor.mode
	local schema = math.floor(tonumber(stored.schema) or 1)
	local storedAlpha = tonumber(stored.alpha)
	local legacyFactoryStyle = schema < MESSAGE_BAND_STYLE_SCHEMA
		and mode ~= "custom"
		and (theme == nil or theme == "accentSoft")
		and (storedAlpha == nil or math.abs(storedAlpha - 0.16) < 0.0001)
	if legacyFactoryStyle then
		mode = "theme"
		theme = fallbackColor.theme
		storedColor = fallbackColor
		storedAlpha = fallback.alpha
	end
	if mode == "custom" then
		theme = nil
	elseif theme and messageBandThemeColors[theme] then
		mode = "theme"
	else
		theme = nil
		mode = mode == "custom" and "custom" or fallbackColor.mode
		if mode == "theme" then theme = fallbackColor.theme end
	end
	dock.messageBands = {
		schema = MESSAGE_BAND_STYLE_SCHEMA,
		enabled = stored.enabled == true,
		extent = messageBandExtents[stored.extent] and stored.extent or fallback.extent,
		color = {
			mode = mode,
			theme = theme,
			r = normalizeOpacityUnit(storedColor.r, fallbackColor.r),
			g = normalizeOpacityUnit(storedColor.g, fallbackColor.g),
			b = normalizeOpacityUnit(storedColor.b, fallbackColor.b),
		},
		alpha = normalizeOpacityUnit(storedAlpha, fallback.alpha),
	}
	return dock.messageBands
end

local function isLegacyFactoryMessageBandStyle(stored)
	if type(stored) ~= "table"
		or (tonumber(rawget(stored, "schema")) or 1) >= MESSAGE_BAND_STYLE_SCHEMA then
		return false
	end
	local rawColor = rawget(stored, "color")
	local mode = type(rawColor) == "table" and rawget(rawColor, "mode") or nil
	local theme = type(rawColor) == "string" and rawColor
		or (type(rawColor) == "table" and rawget(rawColor, "theme") or nil)
	local alpha = tonumber(rawget(stored, "alpha"))
	return mode ~= "custom"
		and theme == "accentSoft"
		and (alpha == nil or math.abs(alpha - 0.16) < 0.0001)
end

local function migrateSmartSettings(settings)
	-- 2.11 renamed the original blue-and-gold palette to describe what it
	-- actually is.  This is deliberately a migration rather than a reset, so a
	-- player who chose the old name keeps the exact same colors.
	if settings.colorway == "Obsidian Arcana" then
		settings.colorway = "Obsidian Dawn"
	end
	settings.persistHistory = settings.persistHistory ~= false
	settings.historyCapacity = normalizeChatHistoryLinesPerSource(settings.historyCapacity)
	settings.historySettingsSchema = CHAT_HISTORY_SETTINGS_SCHEMA

	local dock = settings.dock
	if type(dock) ~= "table" then
		dock = copy(defaults.dock)
		settings.dock = dock
	end

	local railVisibility = dock.railVisibility
	if railVisibility == true then
		railVisibility = "always"
	elseif railVisibility == false then
		railVisibility = "hidden"
	elseif type(railVisibility) == "string" then
		local compact = string.gsub(string.lower(railVisibility), "[%s_%-]", "")
		railVisibility = railVisibilityAliases[compact]
	end
	if railVisibility ~= "always" and railVisibility ~= "mouseover" and railVisibility ~= "click" and railVisibility ~= "hidden" then
		railVisibility = "always"
	end
	dock.railVisibility = railVisibility
	dock.headerVisibility = normalizeHeaderVisibility(dock.headerVisibility)
	dock.hideSocialButton = dock.hideSocialButton == true
	dock.sourceColumnAlignment = dock.sourceColumnAlignment == true
	dock.senderColumnAlignment = dock.senderColumnAlignment == true
	dock.responsiveMetadata = dock.responsiveMetadata ~= false
	normalizeDockPlayerActions(dock)
	normalizeDockTransparency(dock)
	normalizeDockMessageBands(dock)
	normalizeRailUnreadCountAppearance(dock)
	dock.columnAlignmentSpacing = math.max(-8, math.min(8,
		math.floor(tonumber(dock.columnAlignmentSpacing) or 2)))
	-- Do not silently write this compatibility value during normalization. A
	-- missing sender gap must keep following an older profile's single GAP until
	-- the player explicitly chooses a separate [NAME] GAP.
	if dock.senderColumnAlignmentSpacing ~= nil then
		dock.senderColumnAlignmentSpacing = math.max(-8, math.min(8,
			math.floor(tonumber(dock.senderColumnAlignmentSpacing) or dock.columnAlignmentSpacing)))
	end
	dock.senderColumnMaxLength = math.max(1, math.min(32,
		math.floor(tonumber(dock.senderColumnMaxLength) or 14)))
	dock.alignmentVisibleOnly = dock.alignmentVisibleOnly == true
	dock.sourceColumnAlignmentFontApplied = dock.sourceColumnAlignmentFontApplied == true
	-- composerAutoHide is the canonical preference.  showComposer predates the
	-- explicit module and remains a compatibility mirror for older SmartDock
	-- code or hand-edited SavedVariables.  A pre-module profile that already
	-- hid its composer keeps that choice instead of unexpectedly restoring a
	-- permanent input strip.
	if dock.composerAutoHide == nil then
		dock.composerAutoHide = dock.showComposer == false
	else
		dock.composerAutoHide = dock.composerAutoHide and true or false
	end
	dock.showComposer = not dock.composerAutoHide
	-- The first boxed-composer rollout stored `true` as an implicit default.
	-- Schema 2 deliberately restores the intended integrated treatment once.
	-- From then on SetEditBoxBorderEnabled marks the player's choice, so a
	-- future migration never overwrites an explicit preference.
	local polishSchema = math.max(0, math.floor(tonumber(dock.composerInputPolishSchema) or 0))
	if polishSchema < COMPOSER_INPUT_POLISH_SCHEMA then
		dock.editBoxBorder = false
		dock.composerInputPolishSchema = COMPOSER_INPUT_POLISH_SCHEMA
	else
		dock.editBoxBorder = dock.editBoxBorder == true
	end
	normalizeNewMessageIndicatorSettings(dock)
	settings.textAppearance = normalizeSmartChatTextAppearance(settings.textAppearance)
	ensureColumnAlignmentFont(settings)
	if type(settings.viewOptions) ~= "table" then
		settings.viewOptions = {}
	else
		for _, options in pairs(settings.viewOptions) do
			if type(options) == "table" then
				options.textAppearance = normalizeSmartChatTextAppearanceOverride(options.textAppearance)
			end
		end
	end

	local revision = math.max(0, math.floor(tonumber(dock.layoutRevision) or 0))
	if revision < 1 then
		local width = tonumber(dock.width)
		local height = tonumber(dock.height)
		-- The previous build forced a 650x350 minimum and saved that oversized
		-- geometry. Migrate only that legacy-size neighborhood; deliberately
		-- larger custom layouts remain untouched.
		if width and height and width >= 640 and width <= 700 and height >= 340 and height <= 420 then
			dock.width = 520
			dock.height = 250
		end
		dock.layoutRevision = 1
	end

	local conversations = settings.conversations
	if type(conversations) ~= "table" then
		conversations = copy(defaults.conversations)
		settings.conversations = conversations
	end

	-- Older profiles predate the Messenger action presentation preference.
	-- Normalize anything malformed (and the singular legacy spelling) so the
	-- runtime only has to reason about the two supported styles.
	local actionButtonStyle = conversations.actionButtonStyle
	if type(actionButtonStyle) == "string" then
		actionButtonStyle = string.lower(trim(actionButtonStyle, 24))
		if actionButtonStyle == "icon" then
			actionButtonStyle = "icons"
		end
	end
	if actionButtonStyle ~= "icons" and actionButtonStyle ~= "text" then
		actionButtonStyle = "text"
	end
	conversations.actionButtonStyle = actionButtonStyle
	local actionStripOrientation = type(conversations.actionStripOrientation) == "string"
		and string.lower(trim(conversations.actionStripOrientation, 24)) or "horizontal"
	if actionStripOrientation == "side" or actionStripOrientation == "right" then
		actionStripOrientation = "vertical"
	elseif actionStripOrientation == "top" then
		actionStripOrientation = "horizontal"
	end
	if actionStripOrientation ~= "vertical" then
		actionStripOrientation = "horizontal"
	end
	conversations.actionStripOrientation = actionStripOrientation
	conversations.actionStripCollapsed = conversations.actionStripCollapsed == true
	conversations.autoOpenWhispers = conversations.autoOpenWhispers ~= false
	conversations.deferInCombat = conversations.deferInCombat ~= false
	conversations.chromeAutoHide = conversations.chromeAutoHide == true
	conversations.titleBarVisibility = normalizeMessengerVisibilityMode(conversations.titleBarVisibility)
	conversations.actionVisibility = normalizeMessengerVisibilityMode(conversations.actionVisibility)
	conversations.composerVisibility = normalizeMessengerVisibilityMode(conversations.composerVisibility)
	-- COLLAPSED is meaningful only for the player-action strip. A malformed or
	-- hand-edited use on another region safely returns to that region's shared
	-- INHERIT policy instead of making it disappear unpredictably.
	if conversations.titleBarVisibility == "collapsed" then conversations.titleBarVisibility = "inherit" end
	if conversations.composerVisibility == "collapsed" then conversations.composerVisibility = "inherit" end
	normalizeMessengerAppearance(conversations)

	-- This setting was added after the first Spam Control profile schema.
	-- applyDefaults normally seeds it, but normalize malformed hand-edited
	-- values too so the compact config field and the runtime agree on 0..100.
	local spam = settings.spam
	if type(spam) ~= "table" then
		spam = copy(defaults.spam)
		settings.spam = spam
	end
	local duplicate = spam.duplicate
	if type(duplicate) ~= "table" then
		duplicate = copy(defaults.spam.duplicate)
		spam.duplicate = duplicate
	end
	local muteAfter = tonumber(duplicate.muteAfter)
	if muteAfter == nil then
		muteAfter = defaults.spam.duplicate.muteAfter
	end
	muteAfter = math.floor(muteAfter + 0.5)
	if muteAfter < 0 then
		muteAfter = 0
	elseif muteAfter > 100 then
		muteAfter = 100
	end
	duplicate.muteAfter = muteAfter
	-- Cross-source matching is now part of the firewall's safety contract:
	-- moving the same advert between Trade, General, Say, and other enabled
	-- scopes must never reset that sender's duplicate or mute history.  Retain
	-- the saved key for old profiles, but do not allow a stale false value to
	-- weaken the current behavior.
	duplicate.crossChannels = true

	normalizeBlockSettings(settings)
	normalizeMessageRouteOverrides(settings)
	normalizeSyncSettings(settings)
	-- Keep visual rail order self-healing for old profiles, deleted custom
	-- routes, and built-ins added by a future version.  This has no classifier
	-- side effects and does not touch the customViews ownership array.
	local customViews = normalizeStoredCustomViews(settings)
	normalizeRailOrder(settings, customViews)
end

function addon:GetSmartSettings()
	-- Match Questie's startup path: make the installed SharedMedia pack visible
	-- before SmartDock attaches its live font callback. That avoids one callback
	-- and one complete chat redraw per registered face when the user first opens
	-- the font chooser later.
	bootstrapSharedMediaFontPack(getSharedMedia())
	local profile = self.db and self.db.profile
	if not profile then
		refreshSyncRoutingCache(self, defaults)
		return defaults
	end

	if type(profile.smartChat) ~= "table" then
		profile.smartChat = {}
	end
	local storedBuiltInSourceViewsSchema =
		tonumber(rawget(profile.smartChat, "builtInSourceViewsSchema")) or 0
	local migrateBuiltInSourceViews = storedBuiltInSourceViewsSchema < BUILT_IN_SOURCE_VIEWS_SCHEMA
	local storedViewSourceMembershipSchema =
		tonumber(rawget(profile.smartChat, "viewSourceMembershipSchema")) or 0
	local migrateViewSourceMemberships =
		storedViewSourceMembershipSchema < VIEW_SOURCE_MEMBERSHIP_SCHEMA
	-- AceDB supplies new defaults through a metatable, so use raw values here
	-- before applyDefaults can mask an old explicit showComposer=false choice.
	-- This one-time bridge lets existing compact profiles become the matching
	-- new module setting without treating all historical profiles as opt-in.
	local rawDock = type(profile.smartChat.dock) == "table" and profile.smartChat.dock or nil
	-- Capture the first-release factory stripe before applyDefaults can expose
	-- schema 2 through AceDB's defaults metatable. Only that exact accentSoft
	-- style is corrected; custom and deliberately re-tuned theme rows survive.
	local migrateLegacyMessageBandStyle = isLegacyFactoryMessageBandStyle(
		rawDock and rawget(rawDock, "messageBands"))
	-- Received-history persistence was previously an internal, disabled-by-
	-- default prototype. Promote it exactly once into the real user feature.
	-- No config control existed for that old false value, so it cannot represent
	-- a deliberate player privacy choice. From schema 1 onward, false is always
	-- respected and disabling through the public setter also erases saved text.
	local migrateChatHistorySettings = (tonumber(rawget(profile.smartChat, "historySettingsSchema")) or 0)
		< CHAT_HISTORY_SETTINGS_SCHEMA
	local migrateLegacyHiddenComposer = rawDock
		and rawget(rawDock, "composerAutoHide") == nil
		and rawget(rawDock, "showComposer") == false
	-- See COMPOSER_INPUT_POLISH_SCHEMA.  Capture this before AceDB injects new
	-- defaults so a prior implicit boxed lower bar is corrected exactly once.
	local migrateLegacyComposerInputPolish = rawDock
		and rawget(rawDock, "composerInputPolishSchema") == nil
	-- The original alignment UI had one shared GAP. Capture this before AceDB
	-- applies the new sender default so old profiles faithfully seed both lanes.
	local migrateLegacySenderColumnSpacing = rawDock
		and rawget(rawDock, "senderColumnAlignmentSpacing") == nil
	local legacyColumnAlignmentSpacing = rawDock and rawget(rawDock, "columnAlignmentSpacing") or nil
	-- The first alignment control stored one flag per tab. Preserve an existing
	-- opt-in when consolidating it into the deliberate all-tabs preference.
	local migrateLegacySourceColumnAlignment = rawDock
		and rawget(rawDock, "sourceColumnAlignment") == nil
	local legacySourceColumnAlignment = false
	if migrateLegacySourceColumnAlignment and type(profile.smartChat.viewOptions) == "table" then
		for _, options in pairs(profile.smartChat.viewOptions) do
			if type(options) == "table" and options.alignSources == true then
				legacySourceColumnAlignment = true
				break
			end
		end
	end
	-- AceDB may already have injected keywordColorGroups from its defaults. Do
	-- this compatibility reconciliation exactly once per persisted profile:
	-- Presentation calls GetSmartSettings for every rendered line, so repeatedly
	-- copying and deep-comparing the vocabulary would be needless hot-path work.
	local storedKeywordColorGroupSchema = tonumber(profile.smartChat.keywordColorGroupSchema) or 0
	local needsKeywordColorGroupMigration = storedKeywordColorGroupSchema < KEYWORD_COLOR_GROUP_SCHEMA
	local legacyKeywordColors
	local previousKeywordColorGroups
	if needsKeywordColorGroupMigration and type(profile.smartChat.keywordColors) == "table" then
		legacyKeywordColors = copy(profile.smartChat.keywordColors)
	end
	if needsKeywordColorGroupMigration and type(profile.smartChat.keywordColorGroups) == "table" then
		previousKeywordColorGroups = copy(profile.smartChat.keywordColorGroups)
	end
	applyDefaults(profile.smartChat, defaults)
	if migrateLegacyMessageBandStyle then
		local bands = profile.smartChat.dock.messageBands
		bands.schema = MESSAGE_BAND_STYLE_SCHEMA
		bands.color = copy(defaults.dock.messageBands.color)
		bands.alpha = defaults.dock.messageBands.alpha
	end
	if migrateChatHistorySettings then
		profile.smartChat.persistHistory = true
		profile.smartChat.historyCapacity = CHAT_HISTORY_DEFAULT_LINES_PER_SOURCE
		profile.smartChat.historySettingsSchema = CHAT_HISTORY_SETTINGS_SCHEMA
	end
	if migrateLegacyHiddenComposer then
		profile.smartChat.dock.composerAutoHide = true
	end
	if migrateLegacyComposerInputPolish then
		profile.smartChat.dock.editBoxBorder = false
		profile.smartChat.dock.composerInputPolishSchema = COMPOSER_INPUT_POLISH_SCHEMA
	end
	if migrateLegacySenderColumnSpacing then
		profile.smartChat.dock.senderColumnAlignmentSpacing = math.max(-8, math.min(8,
			math.floor(tonumber(legacyColumnAlignmentSpacing) or 2)))
	end
	if migrateLegacySourceColumnAlignment and legacySourceColumnAlignment then
		profile.smartChat.dock.sourceColumnAlignment = true
	end
	if needsKeywordColorGroupMigration then
		profile.smartChat.keywordColorGroups = mergeKeywordColorGroupsById(previousKeywordColorGroups)
		migrateLegacyKeywordColors(profile.smartChat, legacyKeywordColors)
		profile.smartChat.keywordColorGroupSchema = KEYWORD_COLOR_GROUP_SCHEMA
	end
	if migrateBuiltInSourceViews then
		if storedBuiltInSourceViewsSchema < 1 then
			local migratedNewcomers = migrateExactNewcomersCustomView(profile.smartChat)
			prepareBuiltInSourceViewRailMigration(profile.smartChat, migratedNewcomers)
		end
		preparePvpViewRailMigration(profile.smartChat)
		profile.smartChat.builtInSourceViewsSchema = BUILT_IN_SOURCE_VIEWS_SCHEMA
	end
	if migrateViewSourceMemberships then
		migrateViewSourceMembership(profile.smartChat)
	end
	migrateSmartSettings(profile.smartChat)
	refreshSyncRoutingCache(self, profile.smartChat)
	return profile.smartChat
end

local messengerVisibilityKeys = {
	title = "titleBarVisibility",
	titlebar = "titleBarVisibility",
	actions = "actionVisibility",
	action = "actionVisibility",
	composer = "composerVisibility",
	reply = "composerVisibility",
}

local function refreshMessenger(owner)
	local manager = owner.ConversationWindows
	if manager and type(manager.ApplySettings) == "function" then
		manager:ApplySettings()
	elseif manager and type(manager.RefreshSettings) == "function" then
		manager:RefreshSettings()
	end
end

local function resolveMessengerMode(mode, autoHide)
	mode = normalizeMessengerVisibilityMode(mode)
	if mode == "inherit" then
		return autoHide and "auto" or "always"
	end
	return mode
end

function addon:GetMessengerSettings()
	local settings = self:GetSmartSettings().conversations
	local autoHide = settings.chromeAutoHide == true
	return {
		autoOpenWhispers = settings.autoOpenWhispers ~= false,
		deferInCombat = settings.deferInCombat ~= false,
		chromeAutoHide = autoHide,
		actionButtonStyle = settings.actionButtonStyle == "icons" and "icons" or "text",
		actionStripCollapsed = settings.actionStripCollapsed == true,
		actionStripOrientation = settings.actionStripOrientation == "vertical" and "vertical" or "horizontal",
		titleBarVisibility = settings.titleBarVisibility,
		actionVisibility = settings.actionVisibility,
		composerVisibility = settings.composerVisibility,
		resolvedTitleBarVisibility = resolveMessengerMode(settings.titleBarVisibility, autoHide),
		resolvedActionVisibility = resolveMessengerMode(settings.actionVisibility, autoHide),
		resolvedComposerVisibility = resolveMessengerMode(settings.composerVisibility, autoHide),
		appearance = copy(normalizeMessengerAppearance(settings)),
	}
end

function addon:GetMessengerAppearanceSettings()
	local settings = self:GetSmartSettings().conversations
	return copy(normalizeMessengerAppearance(settings))
end

function addon:SetMessengerPopupWhispersEnabled(enabled)
	local settings = self:GetSmartSettings().conversations
	settings.autoOpenWhispers = enabled and true or false
	refreshMessenger(self)
	return true, settings.autoOpenWhispers
end

function addon:SetMessengerCombatDeferralEnabled(enabled)
	local settings = self:GetSmartSettings().conversations
	settings.deferInCombat = enabled and true or false
	refreshMessenger(self)
	return true, settings.deferInCombat
end


function addon:SetMessengerChromeAutoHideEnabled(enabled)
	local settings = self:GetSmartSettings().conversations
	settings.chromeAutoHide = enabled and true or false
	refreshMessenger(self)
	return true, settings.chromeAutoHide
end


function addon:SetMessengerElementVisibility(element, mode)
	local elementKey = type(element) == "string"
		and messengerVisibilityKeys[string.gsub(string.lower(element), "[%s_%-]", "")]
	if not elementKey then
		return false, "invalid-element"
	end
	local normalized = normalizeMessengerVisibilityMode(mode)
	local raw = type(mode) == "string" and string.gsub(string.lower(mode), "[%s_%-]", "") or nil
	if type(mode) ~= "boolean" and not messengerVisibilityAliases[raw] then
		return false, "invalid-visibility"
	end
	if normalized == "collapsed" and elementKey ~= "actionVisibility" then
		return false, "invalid-visibility"
	end
	local settings = self:GetSmartSettings().conversations
	settings[elementKey] = normalized
	refreshMessenger(self)
	return true, normalized
end


function addon:SetMessengerActionButtonStyle(style)
	style = type(style) == "string" and string.lower(style) or ""
	if style == "icon" then
		style = "icons"
	end
	if style ~= "text" and style ~= "icons" then
		return false, "invalid-style"
	end
	local settings = self:GetSmartSettings().conversations
	settings.actionButtonStyle = style
	refreshMessenger(self)
	return true, style
end

function addon:SetMessengerActionStripCollapsed(collapsed)
	local settings = self:GetSmartSettings().conversations
	settings.actionStripCollapsed = collapsed and true or false
	refreshMessenger(self)
	return true, settings.actionStripCollapsed
end

function addon:SetMessengerActionStripOrientation(orientation)
	orientation = type(orientation) == "string" and string.lower(orientation) or ""
	if orientation == "side" or orientation == "right" then
		orientation = "vertical"
	elseif orientation == "top" then
		orientation = "horizontal"
	end
	if orientation ~= "horizontal" and orientation ~= "vertical" then
		return false, "invalid-orientation"
	end
	local settings = self:GetSmartSettings().conversations
	settings.actionStripOrientation = orientation
	refreshMessenger(self)
	return true, orientation
end

local function setMessengerAppearanceAlpha(owner, key, value)
	value = tonumber(value)
	if value == nil then
		return false, "invalid-opacity"
	end
	local conversations = owner:GetSmartSettings().conversations
	local appearance = normalizeMessengerAppearance(conversations)
	appearance.transparency[key] = normalizeOpacityUnit(value, 1)
	refreshMessenger(owner)
	return true, appearance.transparency[key]
end

function addon:SetMessengerBackgroundAlpha(value)
	return setMessengerAppearanceAlpha(self, "backgroundAlpha", value)
end

function addon:SetMessengerBorderAlpha(value)
	return setMessengerAppearanceAlpha(self, "borderAlpha", value)
end

function addon:SetMessengerTextAlpha(value)
	return setMessengerAppearanceAlpha(self, "textAlpha", value)
end

function addon:SetMessengerOverallAlpha(value)
	return setMessengerAppearanceAlpha(self, "overallAlpha", value)
end

function addon:SetMessengerAppearanceColor(target, value)
	target = type(target) == "string" and string.lower(target) or ""
	if not messengerAppearanceTargets[target] then
		return false, "invalid-target"
	end

	local valid = false
	if type(value) == "string" then
		valid = value == "inherit" or messengerAppearanceThemeColors[value] == true
	elseif type(value) == "table" then
		local mode = type(value.mode) == "string" and string.lower(value.mode) or ""
		if mode == "inherit" then
			valid = true
		elseif mode == "theme" then
			valid = messengerAppearanceThemeColors[value.theme] == true
		elseif mode == "custom" then
			valid = tonumber(value.r) ~= nil and tonumber(value.g) ~= nil and tonumber(value.b) ~= nil
		end
	end
	if not valid then
		return false, "invalid-color"
	end

	local conversations = self:GetSmartSettings().conversations
	local appearance = normalizeMessengerAppearance(conversations)
	appearance.colors[target] = normalizeMessengerAppearanceColor(value)
	refreshMessenger(self)
	return true, copy(appearance.colors[target])
end

function addon:ResetMessengerAppearance()
	local conversations = self:GetSmartSettings().conversations
	conversations.appearance = copy(defaults.conversations.appearance)
	refreshMessenger(self)
	return true, copy(conversations.appearance)
end

-- Received-message history is source-owned rather than view-owned. A line
-- mirrored into GENERAL and a custom view therefore consumes one slot, while
-- busy Trade traffic cannot evict Guild's independent retained history.
function addon:GetChatHistorySettings()
	local settings = self:GetSmartSettings()
	return {
		enabled = settings.persistHistory ~= false,
		linesPerSource = normalizeChatHistoryLinesPerSource(settings.historyCapacity),
		minimumLinesPerSource = CHAT_HISTORY_MIN_LINES_PER_SOURCE,
		maximumLinesPerSource = CHAT_HISTORY_MAX_LINES_PER_SOURCE,
	}
end

function addon:SetChatHistoryPersistenceEnabled(enabled)
	local settings = self:GetSmartSettings()
	settings.persistHistory = enabled and true or false
	settings.historySettingsSchema = CHAT_HISTORY_SETTINGS_SCHEMA
	local engine = self.MessageEngine
	if settings.persistHistory then
		if engine and type(engine.RebuildPersistence) == "function" then
			engine:RebuildPersistence()
		end
	else
		-- Disabling persistence is also a privacy action: do not leave a stale
		-- plaintext transcript waiting in SavedVariables for a later login.
		if engine and type(engine.ClearPersistentHistory) == "function" then
			engine:ClearPersistentHistory()
		else
			settings.history = nil
		end
	end
	return true, settings.persistHistory
end

function addon:SetChatHistoryLinesPerSource(value)
	if tonumber(value) == nil then
		return false, "invalid-lines"
	end
	local settings = self:GetSmartSettings()
	local lines = normalizeChatHistoryLinesPerSource(value)
	settings.historyCapacity = lines
	settings.historySettingsSchema = CHAT_HISTORY_SETTINGS_SCHEMA
	local engine = self.MessageEngine
	if engine and type(engine.SetHistoryLinesPerSource) == "function" then
		engine:SetHistoryLinesPerSource(lines)
	end
	return true, lines
end

function addon:ClearChatHistory()
	local settings = self:GetSmartSettings()
	settings.history = nil
	local engine = self.MessageEngine
	if engine and type(engine.ClearHistory) == "function" then
		engine:ClearHistory()
	elseif self.SmartDock and type(self.SmartDock.RebuildActiveView) == "function" then
		self.SmartDock:RebuildActiveView()
	end
	return true
end

local function refreshResponsiveMetadata(owner)
	local dock = owner.SmartDock
	if dock and type(dock.RefreshResponsiveMetadata) == "function" then
		dock:RefreshResponsiveMetadata()
	end
end

function addon:GetResponsiveMetadata()
	local settings = self:GetSmartSettings()
	return not settings.dock or settings.dock.responsiveMetadata ~= false
end

function addon:SetResponsiveMetadata(enabled)
	local settings = self:GetSmartSettings()
	settings.dock.responsiveMetadata = enabled and true or false
	refreshResponsiveMetadata(self)
	return true, settings.dock.responsiveMetadata
end

local function refreshSmartChatTransparency(owner)
	local dock = owner.SmartDock
	if dock and type(dock.RefreshTransparency) == "function" then
		dock:RefreshTransparency()
	end
end

function addon:GetSmartChatWindowTransparency()
	local settings = self:GetSmartSettings()
	return copy(normalizeDockTransparency(settings.dock))
end

local function setSmartChatWindowAlpha(owner, key, value)
	if tonumber(value) == nil then
		return false, "invalid-alpha"
	end
	local settings = owner:GetSmartSettings()
	local transparency = normalizeDockTransparency(settings.dock)
	transparency[key] = normalizeOpacityUnit(value, 1)
	refreshSmartChatTransparency(owner)
	return true, transparency[key]
end

function addon:SetSmartChatWindowBackgroundAlpha(value)
	return setSmartChatWindowAlpha(self, "backgroundAlpha", value)
end

function addon:SetSmartChatWindowBorderAlpha(value)
	return setSmartChatWindowAlpha(self, "borderAlpha", value)
end

function addon:SetSmartChatWindowOverallAlpha(value)
	return setSmartChatWindowAlpha(self, "overallAlpha", value)
end

function addon:ResetSmartChatWindowTransparency()
	local settings = self:GetSmartSettings()
	settings.dock.transparency = copy(defaults.dock.transparency)
	refreshSmartChatTransparency(self)
	return true, copy(settings.dock.transparency)
end

local function refreshSmartChatMessageBands(owner)
	local dock = owner.SmartDock
	if dock and type(dock.RefreshMessageBands) == "function" then
		dock:RefreshMessageBands()
	end
end

function addon:GetSmartChatMessageBandSettings()
	local settings = self:GetSmartSettings()
	return copy(normalizeDockMessageBands(settings.dock))
end

function addon:SetSmartChatMessageBandsEnabled(enabled)
	local settings = self:GetSmartSettings()
	local bands = normalizeDockMessageBands(settings.dock)
	bands.enabled = enabled and true or false
	refreshSmartChatMessageBands(self)
	return true, bands.enabled
end

function addon:SetSmartChatMessageBandExtent(extent)
	if not messageBandExtents[extent] then
		return false, "invalid-extent"
	end
	local settings = self:GetSmartSettings()
	local bands = normalizeDockMessageBands(settings.dock)
	bands.extent = extent
	refreshSmartChatMessageBands(self)
	return true, bands.extent
end

function addon:SetSmartChatMessageBandColor(r, g, b, themeName)
	local useTheme = type(themeName) == "string" and messageBandThemeColors[themeName]
	if not useTheme and (tonumber(r) == nil or tonumber(g) == nil or tonumber(b) == nil) then
		return false, "invalid-color"
	end
	local settings = self:GetSmartSettings()
	local bands = normalizeDockMessageBands(settings.dock)
	local fallback = defaults.dock.messageBands.color
	bands.color = {
		mode = useTheme and "theme" or "custom",
		theme = useTheme and themeName or nil,
		r = normalizeOpacityUnit(r, fallback.r),
		g = normalizeOpacityUnit(g, fallback.g),
		b = normalizeOpacityUnit(b, fallback.b),
	}
	refreshSmartChatMessageBands(self)
	return true, copy(bands.color)
end

function addon:SetSmartChatMessageBandAlpha(value)
	if tonumber(value) == nil then
		return false, "invalid-alpha"
	end
	local settings = self:GetSmartSettings()
	local bands = normalizeDockMessageBands(settings.dock)
	bands.alpha = normalizeOpacityUnit(value, defaults.dock.messageBands.alpha)
	refreshSmartChatMessageBands(self)
	return true, bands.alpha
end

function addon:ResetSmartChatMessageBands()
	local settings = self:GetSmartSettings()
	settings.dock.messageBands = copy(defaults.dock.messageBands)
	refreshSmartChatMessageBands(self)
	return true, copy(settings.dock.messageBands)
end

-- Narrow manual routing corrections from Smart Dock's Shift > ANALYZE panel.
-- They apply only to an exact normalized public channel phrase (case-insensitive
-- with collapsed whitespace) and are purposely not a global classifier editor.
function addon:GetMessageRouteOverride(record)
	if type(record) ~= "table" or record.event ~= "CHAT_MSG_CHANNEL" then
		return nil
	end
	local key = normalizeMessageRouteOverrideText(record.normalized or record.text)
	if not key then
		return nil
	end
	local category = normalizeMessageRouteOverrides(self:GetSmartSettings())[key]
	return messageRouteOverrideCategories[category] and category or nil
end

local function refreshMessageRouteOverridePresentation(owner)
	if owner.MessageEngine and type(owner.MessageEngine.ReclassifyAll) == "function" then
		owner.MessageEngine:ReclassifyAll()
	end
	if owner.SmartDock and type(owner.SmartDock.RebuildActiveView) == "function" then
		owner.SmartDock:RebuildActiveView()
	end
end

function addon:SetMessageRouteOverride(record, category)
	if type(record) ~= "table" or record.event ~= "CHAT_MSG_CHANNEL" then
		return false, "public-channel-only"
	end
	if not messageRouteOverrideCategories[category] then
		return false, "invalid-category"
	end
	local key = normalizeMessageRouteOverrideText(record.normalized or record.text)
	if not key then
		return false, "empty"
	end
	local overrides = normalizeMessageRouteOverrides(self:GetSmartSettings())
	if overrides[key] == nil then
		local count = 0
		for _ in pairs(overrides) do count = count + 1 end
		if count >= MESSAGE_ROUTE_OVERRIDE_LIMIT then
			return false, "limit"
		end
	end
	overrides[key] = category
	refreshMessageRouteOverridePresentation(self)
	return true, category
end

function addon:RemoveMessageRouteOverride(record)
	if type(record) ~= "table" or record.event ~= "CHAT_MSG_CHANNEL" then
		return false, "public-channel-only"
	end
	local key = normalizeMessageRouteOverrideText(record.normalized or record.text)
	if not key then
		return false, "empty"
	end
	local overrides = normalizeMessageRouteOverrides(self:GetSmartSettings())
	if overrides[key] == nil then
		return false, "missing"
	end
	overrides[key] = nil
	refreshMessageRouteOverridePresentation(self)
	return true
end

local semanticRouteIds = { groupFinder = true, pvp = true, trade = true }

function addon:GetSemanticRouteEnabled(routeId)
	if not semanticRouteIds[routeId] then
		return nil, "invalid-route"
	end
	local settings = self:GetSmartSettings()
	if type(settings.semanticRoutes) ~= "table" then
		settings.semanticRoutes = {}
	end
	-- Missing is deliberately enabled for old SavedVariables and future route IDs.
	return settings.semanticRoutes[routeId] ~= false
end

function addon:SetSemanticRouteEnabled(routeId, enabled)
	if not semanticRouteIds[routeId] then
		return false, "invalid-route"
	end
	if type(enabled) ~= "boolean" then
		return false, "boolean-required"
	end
	local settings = self:GetSmartSettings()
	if type(settings.semanticRoutes) ~= "table" then
		settings.semanticRoutes = {}
	end
	settings.semanticRoutes[routeId] = enabled
	refreshMessageRouteOverridePresentation(self)
	return true, enabled
end

local function refreshNewMessageIndicator(owner)
	local dock = owner.SmartDock
	if dock and dock.RefreshNewMessageIndicator then
		dock:RefreshNewMessageIndicator()
	end
end

local function refreshRailUnreadCountAppearance(owner)
	local dock = owner.SmartDock
	if dock and type(dock.RefreshUnreadCountAppearance) == "function" then
		dock:RefreshUnreadCountAppearance()
	elseif dock and type(dock.RefreshRailState) == "function" then
		dock:RefreshRailState()
	end
end

-- Public appearance settings for inactive Smart Chat rail unread counts. The
-- returned table also documents the UI bounds: zero font size inherits the
-- rail's FontObject; otherwise values are constrained to 8..16px.
function addon:GetRailUnreadCountAppearanceSettings()
	local settings = self:GetSmartSettings()
	local appearance = normalizeRailUnreadCountAppearance(settings.dock)
	local exported = copy(appearance)
	exported.minimumFontSize = RAIL_UNREAD_COUNT_FONT_SIZE_MIN
	exported.maximumFontSize = RAIL_UNREAD_COUNT_FONT_SIZE_MAX
	return exported
end

function addon:SetRailUnreadCountAlpha(alpha)
	if tonumber(alpha) == nil then
		return false, "invalid-alpha"
	end
	local settings = self:GetSmartSettings()
	local appearance = normalizeRailUnreadCountAppearance(settings.dock)
	appearance.alpha = clampNewMessageIndicatorNumber(alpha, appearance.alpha, 0, 1)
	refreshRailUnreadCountAppearance(self)
	return true, appearance.alpha
end

function addon:SetRailUnreadCountFontSize(fontSize)
	if tonumber(fontSize) == nil then
		return false, "invalid-font-size"
	end
	local settings = self:GetSmartSettings()
	local appearance = normalizeRailUnreadCountAppearance(settings.dock)
	appearance.fontSize = clampNewMessageIndicatorNumber(fontSize, appearance.fontSize,
		0, RAIL_UNREAD_COUNT_FONT_SIZE_MAX, true)
	if appearance.fontSize > 0 and appearance.fontSize < RAIL_UNREAD_COUNT_FONT_SIZE_MIN then
		appearance.fontSize = RAIL_UNREAD_COUNT_FONT_SIZE_MIN
	end
	refreshRailUnreadCountAppearance(self)
	return true, appearance.fontSize
end

function addon:SetRailUnreadCountAppearance(patch)
	if type(patch) ~= "table" then
		return false, "invalid-appearance"
	end
	if patch.alpha ~= nil and tonumber(patch.alpha) == nil then
		return false, "invalid-alpha"
	end
	if patch.fontSize ~= nil and tonumber(patch.fontSize) == nil then
		return false, "invalid-font-size"
	end
	local settings = self:GetSmartSettings()
	local appearance = normalizeRailUnreadCountAppearance(settings.dock)
	if patch.alpha ~= nil then
		appearance.alpha = clampNewMessageIndicatorNumber(patch.alpha, appearance.alpha, 0, 1)
	end
	if patch.fontSize ~= nil then
		appearance.fontSize = clampNewMessageIndicatorNumber(patch.fontSize, appearance.fontSize,
			0, RAIL_UNREAD_COUNT_FONT_SIZE_MAX, true)
		if appearance.fontSize > 0 and appearance.fontSize < RAIL_UNREAD_COUNT_FONT_SIZE_MIN then
			appearance.fontSize = RAIL_UNREAD_COUNT_FONT_SIZE_MIN
		end
	end
	refreshRailUnreadCountAppearance(self)
	return true, copy(appearance)
end

function addon:ResetRailUnreadCountAppearance()
	local settings = self:GetSmartSettings()
	settings.dock.unreadCountAppearance = copy(defaults.dock.unreadCountAppearance)
	refreshRailUnreadCountAppearance(self)
	return true
end

-- Public presentation settings for the active rail's NEW control.  Return a
-- copy so callers use the narrow setters below instead of accidentally
-- replacing the SavedVariables subtree with a malformed value.
function addon:GetNewMessageIndicatorSettings()
	local settings = self:GetSmartSettings()
	return copy(normalizeNewMessageIndicatorSettings(settings.dock))
end

-- Appearance controls are intentionally separate from the marker's behaviour
-- controls above.  A player can reset its look without losing their choice to
-- show the count or their count cap, and no consumer receives the live
-- SavedVariables table by accident.
function addon:GetNewMessageIndicatorAppearanceSettings()
	local settings = self:GetSmartSettings()
	local indicator = normalizeNewMessageIndicatorSettings(settings.dock)
	return copy(normalizeNewMessageIndicatorAppearance(indicator))
end

function addon:GetNewMessageIndicatorAppearanceOptions()
	return copy(NEW_MESSAGE_INDICATOR_APPEARANCE_OPTIONS)
end

local function getNewMessageIndicatorAppearanceForWrite(owner)
	local settings = owner:GetSmartSettings()
	local indicator = normalizeNewMessageIndicatorSettings(settings.dock)
	return indicator, normalizeNewMessageIndicatorAppearance(indicator)
end

local function isNewMessageIndicatorNumber(value)
	return value == nil or tonumber(value) ~= nil
end

local function normalizeNewMessageIndicatorPoint(point)
	point = string.upper(trim(point, 16))
	if NEW_MESSAGE_INDICATOR_POINTS[point] then
		return point
	end
	return nil
end

local function normalizeNewMessageIndicatorAnchor(anchor)
	anchor = string.lower(trim(anchor, 16))
	if NEW_MESSAGE_INDICATOR_ANCHORS[anchor] then
		return anchor
	end
	return nil
end

local NEW_MESSAGE_INDICATOR_PRESET_OFFSETS = {
	TOPLEFT = { x = 4, y = -4 },
	TOP = { x = 0, y = -4 },
	TOPRIGHT = { x = -4, y = -4 },
	LEFT = { x = 4, y = 0 },
	CENTER = { x = 0, y = 0 },
	RIGHT = { x = -4, y = 0 },
	BOTTOMLEFT = { x = 4, y = 4 },
	BOTTOM = { x = 0, y = 4 },
	BOTTOMRIGHT = { x = -4, y = 4 },
}

-- `position` may be a compact preset ID ("header", "TOPLEFT", etc.) or a
-- complete/partial table.  Shift-drag uses the table form so the exact free
-- point and offsets survive a reload without exposing raw SavedVariables.
local function makeNewMessageIndicatorPosition(current, position, x, y, point)
	local nextPosition = copy(current)
	local switchedToDockPreset = false
	if type(position) == "table" then
		if position.anchor ~= nil then
			local anchor = normalizeNewMessageIndicatorAnchor(position.anchor)
			if not anchor then
				return nil, "invalid-anchor"
			end
			if anchor == "dock" and current.anchor ~= "dock"
				and position.x == nil and position.y == nil and x == nil and y == nil then
				switchedToDockPreset = true
			end
			nextPosition.anchor = anchor
		end
		if position.point ~= nil then
			local nextPoint = normalizeNewMessageIndicatorPoint(position.point)
			if not nextPoint then
				return nil, "invalid-point"
			end
			nextPosition.point = nextPoint
		end
		if position.x ~= nil then
			if not isNewMessageIndicatorNumber(position.x) then
				return nil, "invalid-x"
			end
			nextPosition.x = position.x
		end
		if position.y ~= nil then
			if not isNewMessageIndicatorNumber(position.y) then
				return nil, "invalid-y"
			end
			nextPosition.y = position.y
		end
	elseif type(position) == "string" then
		local anchor = normalizeNewMessageIndicatorAnchor(position)
		local nextPoint = normalizeNewMessageIndicatorPoint(position)
		if anchor == "header" then
			nextPosition.anchor = "header"
		elseif anchor == "dock" then
			nextPosition.anchor = "dock"
			if point ~= nil then
				nextPoint = normalizeNewMessageIndicatorPoint(point)
				if not nextPoint then
					return nil, "invalid-point"
				end
			end
			if current.anchor ~= "dock" and x == nil and y == nil then
				switchedToDockPreset = true
			end
		elseif nextPoint then
			nextPosition.anchor = "dock"
			nextPosition.point = nextPoint
			switchedToDockPreset = x == nil and y == nil
		else
			return nil, "invalid-position"
		end
		if nextPoint then
			nextPosition.point = nextPoint
		end
	else
		return nil, "invalid-position"
	end

	if x ~= nil then
		if not isNewMessageIndicatorNumber(x) then
			return nil, "invalid-x"
		end
		nextPosition.x = x
	end
	if y ~= nil then
		if not isNewMessageIndicatorNumber(y) then
			return nil, "invalid-y"
		end
		nextPosition.y = y
	end
	if switchedToDockPreset then
		local offset = NEW_MESSAGE_INDICATOR_PRESET_OFFSETS[nextPosition.point]
		if offset then
			nextPosition.x = offset.x
			nextPosition.y = offset.y
		end
	end
	return normalizeNewMessageIndicatorPosition(nextPosition)
end

local function makeNewMessageIndicatorColor(value, fallback)
	local candidate
	if type(value) == "string" then
		local theme = string.gsub(trim(value, 48), "^[Tt][Hh][Ee][Mm][Ee]:", "")
		theme = NEW_MESSAGE_INDICATOR_THEME_COLOR_ALIASES[string.lower(theme)]
		if not theme then
			return nil, "invalid-color"
		end
		candidate = copy(fallback)
		candidate.mode = "theme"
		candidate.theme = theme
	elseif type(value) == "table" then
		candidate = copy(value)
		if candidate.mode == nil and (candidate.r ~= nil or candidate.g ~= nil or candidate.b ~= nil or candidate.a ~= nil) then
			candidate.mode = "custom"
		end
		local requestedMode = candidate.mode and string.lower(trim(candidate.mode, 16)) or nil
		if requestedMode ~= nil and requestedMode ~= "theme" and requestedMode ~= "custom" then
			return nil, "invalid-color-mode"
		end
		if requestedMode == "theme" then
			local theme = NEW_MESSAGE_INDICATOR_THEME_COLOR_ALIASES[string.lower(trim(candidate.theme, 40))]
			if not theme then
				return nil, "invalid-theme-color"
			end
			candidate.theme = theme
		end
		for _, channel in ipairs({ "r", "g", "b", "a" }) do
			if candidate[channel] ~= nil and tonumber(candidate[channel]) == nil then
				return nil, "invalid-color"
			end
		end
	else
		return nil, "invalid-color"
	end
	return normalizeNewMessageIndicatorColor(candidate, fallback)
end

function addon:SetNewMessageIndicatorPosition(position, x, y, point)
	local _, appearance = getNewMessageIndicatorAppearanceForWrite(self)
	local nextPosition, reason = makeNewMessageIndicatorPosition(appearance.position, position, x, y, point)
	if not nextPosition then
		return false, reason
	end
	appearance.position = nextPosition
	refreshNewMessageIndicator(self)
	return true, copy(nextPosition)
end

function addon:SetNewMessageIndicatorFont(font)
	if type(font) ~= "string" then
		return false, "invalid-font"
	end
	local normalized = normalizeNewMessageIndicatorFont(font)
	local raw = trim(font, 160)
	if normalized == defaults.dock.newMessages.appearance.font
		and string.lower(raw) ~= "default" then
		return false, "invalid-font"
	end
	local _, appearance = getNewMessageIndicatorAppearanceForWrite(self)
	appearance.font = normalized
	refreshNewMessageIndicator(self)
	return true, appearance.font
end

function addon:SetNewMessageIndicatorFontSize(fontSize)
	if tonumber(fontSize) == nil then
		return false, "invalid-font-size"
	end
	local _, appearance = getNewMessageIndicatorAppearanceForWrite(self)
	appearance.fontSize = clampNewMessageIndicatorNumber(fontSize, appearance.fontSize, 0, 32, true)
	if appearance.fontSize > 0 and appearance.fontSize < 8 then
		appearance.fontSize = 8
	end
	refreshNewMessageIndicator(self)
	return true, appearance.fontSize
end

function addon:SetNewMessageIndicatorAlpha(alpha)
	if tonumber(alpha) == nil then
		return false, "invalid-alpha"
	end
	local _, appearance = getNewMessageIndicatorAppearanceForWrite(self)
	appearance.alpha = clampNewMessageIndicatorNumber(alpha, appearance.alpha, 0, 1)
	refreshNewMessageIndicator(self)
	return true, appearance.alpha
end

function addon:SetNewMessageIndicatorScale(scale)
	if tonumber(scale) == nil then
		return false, "invalid-scale"
	end
	local _, appearance = getNewMessageIndicatorAppearanceForWrite(self)
	appearance.scale = clampNewMessageIndicatorNumber(scale, appearance.scale, 0.5, 2)
	refreshNewMessageIndicator(self)
	return true, appearance.scale
end

function addon:SetNewMessageIndicatorOutline(outline)
	if type(outline) ~= "string" then
		return false, "invalid-outline"
	end
	local normalized = normalizeNewMessageIndicatorOutline(outline)
	local raw = string.upper(trim(outline, 24))
	if raw == "" then raw = "NONE" end
	if raw == "THICK" then raw = "THICKOUTLINE" end
	if normalized ~= raw then
		return false, "invalid-outline"
	end
	local _, appearance = getNewMessageIndicatorAppearanceForWrite(self)
	appearance.outline = normalized
	refreshNewMessageIndicator(self)
	return true, appearance.outline
end

function addon:SetNewMessageIndicatorColor(color)
	local _, appearance = getNewMessageIndicatorAppearanceForWrite(self)
	local nextColor, reason = makeNewMessageIndicatorColor(color, appearance.color)
	if not nextColor then
		return false, reason
	end
	appearance.color = nextColor
	refreshNewMessageIndicator(self)
	return true, copy(nextColor)
end

function addon:SetNewMessageIndicatorBackgroundColor(color)
	local _, appearance = getNewMessageIndicatorAppearanceForWrite(self)
	local nextColor, reason = makeNewMessageIndicatorColor(color, appearance.background)
	if not nextColor then
		return false, reason
	end
	appearance.background = nextColor
	refreshNewMessageIndicator(self)
	return true, copy(nextColor)
end

function addon:SetNewMessageIndicatorBorderColor(color)
	local _, appearance = getNewMessageIndicatorAppearanceForWrite(self)
	local nextColor, reason = makeNewMessageIndicatorColor(color, appearance.border)
	if not nextColor then
		return false, reason
	end
	appearance.border = nextColor
	refreshNewMessageIndicator(self)
	return true, copy(nextColor)
end

-- Compact config controls can commit one coherent visual edit rather than
-- producing a frame refresh for every RGBA channel.  Unknown keys are ignored
-- on purpose so future UI revisions remain backwards-compatible.
function addon:SetNewMessageIndicatorAppearance(patch)
	if type(patch) ~= "table" then
		return false, "invalid-appearance"
	end
	local _, appearance = getNewMessageIndicatorAppearanceForWrite(self)
	local nextAppearance = copy(appearance)
	local changed = false
	if patch.position ~= nil then
		local nextPosition, reason = makeNewMessageIndicatorPosition(nextAppearance.position, patch.position)
		if not nextPosition then return false, reason end
		nextAppearance.position = nextPosition
		changed = true
	end
	if patch.alpha ~= nil then
		if tonumber(patch.alpha) == nil then return false, "invalid-alpha" end
		nextAppearance.alpha = patch.alpha
		changed = true
	end
	if patch.scale ~= nil then
		if tonumber(patch.scale) == nil then return false, "invalid-scale" end
		nextAppearance.scale = patch.scale
		changed = true
	end
	if patch.font ~= nil then
		if type(patch.font) ~= "string" then return false, "invalid-font" end
		local normalized = normalizeNewMessageIndicatorFont(patch.font)
		if normalized == defaults.dock.newMessages.appearance.font and string.lower(trim(patch.font, 160)) ~= "default" then
			return false, "invalid-font"
		end
		nextAppearance.font = normalized
		changed = true
	end
	if patch.fontSize ~= nil then
		if tonumber(patch.fontSize) == nil then return false, "invalid-font-size" end
		nextAppearance.fontSize = patch.fontSize
		changed = true
	end
	if patch.outline ~= nil then
		if type(patch.outline) ~= "string" then return false, "invalid-outline" end
		local outline = normalizeNewMessageIndicatorOutline(patch.outline)
		local raw = string.upper(trim(patch.outline, 24))
		if raw == "" then raw = "NONE" end
		if raw == "THICK" then raw = "THICKOUTLINE" end
		if outline ~= raw then return false, "invalid-outline" end
		nextAppearance.outline = outline
		changed = true
	end
	for _, key in ipairs({ "color", "background", "border" }) do
		if patch[key] ~= nil then
			local nextColor, reason = makeNewMessageIndicatorColor(patch[key], nextAppearance[key])
			if not nextColor then return false, reason end
			nextAppearance[key] = nextColor
			changed = true
		end
	end
	if not changed then
		return false, "empty-appearance"
	end
	-- Reuse the migration normalizer as the one canonical bounds check before
	-- persisting the patch.
	local indicator, normalizedAppearance = getNewMessageIndicatorAppearanceForWrite(self)
	indicator.appearance = nextAppearance
	normalizedAppearance = normalizeNewMessageIndicatorAppearance(indicator)
	refreshNewMessageIndicator(self)
	return true, copy(normalizedAppearance)
end

function addon:ResetNewMessageIndicatorAppearance()
	local indicator = getNewMessageIndicatorAppearanceForWrite(self)
	indicator.appearance = copy(defaults.dock.newMessages.appearance)
	refreshNewMessageIndicator(self)
	return true, copy(indicator.appearance)
end

-- Preview state is deliberately transient.  It gives the Config placement
-- mode a real marker to drag even when the player currently has no unread
-- lines, but it never changes unread state or ends up in SavedVariables.
function addon:SetNewMessageIndicatorPreviewActive(active)
	local dock = self.SmartDock
	if dock and dock.SetNewMessageIndicatorPreviewActive then
		dock:SetNewMessageIndicatorPreviewActive(active and true or false)
		return true
	end
	return false, "unavailable"
end

function addon:SetNewMessageIndicatorEnabled(enabled)
	local settings = self:GetSmartSettings()
	local indicator = normalizeNewMessageIndicatorSettings(settings.dock)
	indicator.enabled = enabled and true or false
	refreshNewMessageIndicator(self)
	return true
end

function addon:SetNewMessageIndicatorShowCount(showCount)
	local settings = self:GetSmartSettings()
	local indicator = normalizeNewMessageIndicatorSettings(settings.dock)
	indicator.showCount = showCount and true or false
	refreshNewMessageIndicator(self)
	return true
end

function addon:SetNewMessageIndicatorMaxCount(maxCount)
	maxCount = tonumber(maxCount)
	if maxCount == nil then
		return false, "invalid-count"
	end
	local settings = self:GetSmartSettings()
	local indicator = normalizeNewMessageIndicatorSettings(settings.dock)
	indicator.maxCount = math.floor(maxCount + 0.5)
	normalizeNewMessageIndicatorSettings(settings.dock)
	refreshNewMessageIndicator(self)
	return true, indicator.maxCount
end

function addon:ResetNewMessageIndicatorSettings()
	local settings = self:GetSmartSettings()
	settings.dock.newMessages = copy(defaults.dock.newMessages)
	refreshNewMessageIndicator(self)
	return true
end

local function refreshPlayerActionDismissal(owner)
	local dock = owner.SmartDock
	if dock and type(dock.RefreshPlayerActionDismissal) == "function" then
		dock:RefreshPlayerActionDismissal()
	end
end

function addon:GetPlayerActionMenuSettings()
	local settings = self:GetSmartSettings()
	local playerActions = normalizeDockPlayerActions(settings.dock)
	return {
		autoHide = playerActions.autoHide,
		autoHideSeconds = playerActions.autoHideSeconds,
		minimumAutoHideSeconds = PLAYER_ACTION_AUTO_HIDE_MIN_SECONDS,
		maximumAutoHideSeconds = PLAYER_ACTION_AUTO_HIDE_MAX_SECONDS,
	}
end

function addon:SetPlayerActionMenuAutoHideEnabled(enabled)
	local settings = self:GetSmartSettings()
	local playerActions = normalizeDockPlayerActions(settings.dock)
	playerActions.autoHide = enabled and true or false
	refreshPlayerActionDismissal(self)
	return true, playerActions.autoHide
end

function addon:SetPlayerActionMenuAutoHideSeconds(seconds)
	seconds = tonumber(seconds)
	if seconds == nil then
		return false, "invalid-seconds"
	end
	local settings = self:GetSmartSettings()
	local playerActions = normalizeDockPlayerActions(settings.dock)
	playerActions.autoHideSeconds = normalizePlayerActionAutoHideSeconds(seconds)
	refreshPlayerActionDismissal(self)
	return true, playerActions.autoHideSeconds
end

-- Bottom-composer presentation is intentionally a narrow setting rather than
-- a generic frame hide.  The dock keeps the shared Blizzard edit box alive so
-- all normal activation paths (Enter, slash commands, reply shortcuts, and
-- ChatFrame_OpenChat) can temporarily reveal it.
function addon:GetComposerAutoHideSetting()
	local settings = self:GetSmartSettings()
	local dock = settings.dock or {}
	if dock.composerAutoHide == nil then
		return dock.showComposer == false
	end
	return dock.composerAutoHide == true
end

-- Short alias for integrations that only need the current state.
function addon:GetComposerAutoHide()
	return self:GetComposerAutoHideSetting()
end

function addon:SetComposerAutoHide(enabled)
	local settings = self:GetSmartSettings()
	local dock = settings.dock
	if type(dock) ~= "table" then
		dock = copy(defaults.dock)
		settings.dock = dock
	end
	local value = enabled and true or false
	dock.composerAutoHide = value
	-- Preserve the older public shape as a mirror until every dependent local
	-- module has moved to the explicit name.
	dock.showComposer = not value

	local smartDock = self.SmartDock
	if smartDock then
		if smartDock.ApplyLayout then
			smartDock:ApplyLayout()
		end
		if smartDock.RefreshComposerVisibility then
			smartDock:RefreshComposerVisibility()
		end
	end
	return true, value
end

function addon:GetEditBoxBorderSetting()
	local settings = self:GetSmartSettings()
	local dock = settings.dock or {}
	return dock.editBoxBorder == true
end

function addon:SetEditBoxBorderEnabled(enabled)
	local settings = self:GetSmartSettings()
	local dock = settings.dock
	if type(dock) ~= "table" then
		dock = copy(defaults.dock)
		settings.dock = dock
	end
	dock.editBoxBorder = enabled and true or false
	dock.composerInputPolishSchema = COMPOSER_INPUT_POLISH_SCHEMA
	local smartDock = self.SmartDock
	if smartDock and smartDock.RefreshComposerEditBoxBorder then
		smartDock:RefreshComposerEditBoxBorder()
	end
	return true, dock.editBoxBorder
end

-- Keep keyword choices semantic rather than exposing arbitrary palette
-- internals in the settings UI.  Each choice exists in every bundled
-- ColorWays palette, so a saved selection remains valid when a player swaps
-- themes or moves the profile to another supported server.
local keywordColorOptions = {
	{ id = "goldBright", label = "GOLD BRIGHT" },
	{ id = "gold", label = "GOLD" },
	{ id = "accent", label = "ACCENT" },
	{ id = "success", label = "SUCCESS" },
	{ id = "warning", label = "WARNING" },
	{ id = "danger", label = "DANGER" },
	{ id = "text", label = "NEUTRAL" },
}

local keywordColorOptionById = {}
for index = 1, #keywordColorOptions do
	keywordColorOptionById[keywordColorOptions[index].id] = true
end

function addon:GetKeywordColorOptions()
	return copy(keywordColorOptions)
end

function addon:GetKeywordColorDefaults()
	return copy(defaults.keywordColors)
end

-- Ordered groups drive the compact editor: one row is a concept (for example
-- TANK / OFF-TANK), with its vocabulary displayed as help text rather than a
-- separate border, selector, and reset button for every spelling.
function addon:GetKeywordColorGroups()
	local settings = self:GetSmartSettings()
	if type(settings.keywordColorGroups) ~= "table" then
		settings.keywordColorGroups = copy(defaults.keywordColorGroups)
	end
	local groups = copy(settings.keywordColorGroups)
	for index = 1, #groups do
		for _, defaultGroup in ipairs(defaults.keywordColorGroups) do
			if groups[index].id == defaultGroup.id then
				groups[index].defaultColor = defaultGroup.color
				break
			end
		end
	end
	return groups
end

function addon:GetKeywordColorGroup(groupId)
	groupId = trim(groupId, 40)
	for _, group in ipairs(self:GetKeywordColorGroups()) do
		if group.id == groupId then
			return group
		end
	end
	return nil
end

local function isKeywordColorSpec(colorSpec)
	if keywordColorOptionById[colorSpec] then
		return true
	end
	-- Class specifications intentionally remain symbolic. Presentation resolves
	-- them through RAID_CLASS_COLORS at render time, so they track the client
	-- palette instead of embedding a stale RGB triple in SavedVariables.
	return type(colorSpec) == "string" and string.match(colorSpec, "^class:[A-Z]+$") ~= nil
end

local function applyKeywordGroupColor(settings, group, colorSpec)
	group.color = colorSpec
	if type(settings.keywordColors) ~= "table" then
		settings.keywordColors = copy(defaults.keywordColors)
	end
	for _, termSpec in ipairs(group.terms or {}) do
		local term = type(termSpec) == "table" and termSpec.term or termSpec
		if type(term) == "string" then
			settings.keywordColors[string.lower(term)] = colorSpec
		end
	end
end

local function touchKeywordColorVocabulary(settings)
	settings.keywordColorRevision = math.max(0, math.floor(tonumber(settings.keywordColorRevision) or 0)) + 1
	return settings.keywordColorRevision
end

local MAX_KEYWORD_COLOR_GROUPS = 48
local MAX_KEYWORD_COLOR_GROUP_TERMS = 128

local function getMutableKeywordColorGroups(settings)
	if type(settings.keywordColorGroups) ~= "table" then
		settings.keywordColorGroups = copy(defaults.keywordColorGroups)
	end
	return settings.keywordColorGroups
end

local function getKeywordColorGroupById(groups, groupId)
	for index, group in ipairs(groups or {}) do
		if type(group) == "table" and group.id == groupId then
			return group, index
		end
	end
	return nil
end

local function normalizeKeywordColorGroupLabel(label)
	label = trim(label, 32)
	label = string.gsub(label, "%s+", " ")
	if not string.match(label, "^[%a%d][%a%d%'%+%-%&/ ]*$") then
		return ""
	end
	return label
end

local function customKeywordColorGroupId(groups, label)
	local stem = string.lower(label)
	stem = string.gsub(stem, "[^%a%d]+", "-")
	stem = string.gsub(stem, "^-+", "")
	stem = string.gsub(stem, "-+$", "")
	stem = trim(stem, 28)
	if stem == "" then
		stem = "group"
	end
	local base = "custom-" .. stem
	local candidate = base
	local suffix = 2
	while getKeywordColorGroupById(groups, candidate) do
		local suffixText = "-" .. tostring(suffix)
		candidate = string.sub(base, 1, 40 - #suffixText) .. suffixText
		suffix = suffix + 1
	end
	return candidate
end

local function findKeywordColorTermOwner(groups, normalizedTerm)
	for _, group in ipairs(groups or {}) do
		for _, termSpec in ipairs((type(group) == "table" and group.terms) or {}) do
			local existing = type(termSpec) == "table" and termSpec.term or termSpec
			if type(existing) == "string" and string.lower(existing) == normalizedTerm then
				return group
			end
		end
	end
	return nil
end

function addon:GetKeywordColorVocabularyRevision()
	local settings = self:GetSmartSettings()
	return math.max(0, math.floor(tonumber(settings.keywordColorRevision) or 0))
end

function addon:SetKeywordColorGroup(groupId, colorSpec)
	groupId = trim(groupId, 40)
	colorSpec = trim(colorSpec, 40)
	if groupId == "" then
		return false, "invalid-group"
	end
	if not isKeywordColorSpec(colorSpec) then
		return false, "invalid-color"
	end
	local settings = self:GetSmartSettings()
	for _, group in ipairs(getMutableKeywordColorGroups(settings)) do
		if group.id == groupId then
			applyKeywordGroupColor(settings, group, colorSpec)
			touchKeywordColorVocabulary(settings)
			return true
		end
	end
	return false, "unknown-group"
end

function addon:ResetKeywordColorGroups()
	local settings = self:GetSmartSettings()
	-- A reset restores the curated vocabulary and colors, but a player-created
	-- group is their work and should not disappear behind a deceptively broad
	-- reset button. Custom groups keep their initial/default color and terms.
	local customGroups = {}
	for _, group in ipairs(getMutableKeywordColorGroups(settings)) do
		if group.custom == true then
			table.insert(customGroups, copy(group))
		end
	end
	settings.keywordColorGroups = copy(defaults.keywordColorGroups)
	settings.keywordColors = copy(defaults.keywordColors)
	for _, group in ipairs(customGroups) do
		table.insert(settings.keywordColorGroups, group)
		applyKeywordGroupColor(settings, group, group.color or group.defaultColor or "text")
	end
	touchKeywordColorVocabulary(settings)
	return true
end

-- Make a personal semantic group without turning Keyword Highlights into a
-- pile of disconnected one-word controls. The group starts empty, receives a
-- color immediately, and can then collect words or phrases in the editor.
function addon:CreateKeywordColorGroup(label, colorSpec)
	label = normalizeKeywordColorGroupLabel(label)
	colorSpec = trim(colorSpec, 40)
	if label == "" then
		return false, "invalid-label"
	end
	if not isKeywordColorSpec(colorSpec) then
		return false, "invalid-color"
	end
	local settings = self:GetSmartSettings()
	local groups = getMutableKeywordColorGroups(settings)
	if #groups >= MAX_KEYWORD_COLOR_GROUPS then
		return false, "group-limit"
	end
	local normalizedLabel = string.lower(label)
	for _, group in ipairs(groups) do
		if type(group.label) == "string" and string.lower(group.label) == normalizedLabel then
			return false, "duplicate-label"
		end
	end
	local group = {
		id = customKeywordColorGroupId(groups, label),
		label = label,
		color = colorSpec,
		defaultColor = colorSpec,
		terms = {},
		custom = true,
	}
	table.insert(groups, group)
	touchKeywordColorVocabulary(settings)
	return true, copy(group)
end

function addon:DeleteKeywordColorGroup(groupId)
	groupId = trim(groupId, 40)
	local settings = self:GetSmartSettings()
	local groups = getMutableKeywordColorGroups(settings)
	local group, index = getKeywordColorGroupById(groups, groupId)
	if not group then
		return false, "unknown-group"
	end
	if group.custom ~= true then
		return false, "built-in-group"
	end
	settings.keywordColors = settings.keywordColors or copy(defaults.keywordColors)
	for _, termSpec in ipairs(group.terms or {}) do
		local term = type(termSpec) == "table" and termSpec.term or termSpec
		if type(term) == "string" then
			-- False is a deliberate compatibility sentinel: Presentation's legacy
			-- flat map will not resurrect a removed custom word after the group is
			-- gone, while the next explicit add can replace it normally.
			settings.keywordColors[string.lower(term)] = false
		end
	end
	table.remove(groups, index)
	touchKeywordColorVocabulary(settings)
	return true
end

-- Add a reviewed suggestion (or a direct user term) without creating a second
-- one-word color control.  Group terms are case-insensitive by default; the
-- built-in acronym forms retain their explicit caseSensitive tables.
function addon:AddKeywordColorGroupTerm(groupId, term, caseSensitive)
	groupId = trim(groupId, 40)
	term = trim(term, 40)
	if groupId == "" or term == "" then
		return false, "invalid-term"
	end
	if not string.match(term, "^[%a%d][%a%d%'%+%- ]*$") then
		return false, "invalid-term"
	end
	local settings = self:GetSmartSettings()
	local groups = getMutableKeywordColorGroups(settings)
	for _, group in ipairs(groups) do
		if group.id == groupId then
			local normalized = string.lower(term)
			local owner = findKeywordColorTermOwner(groups, normalized)
			if owner then
				if owner.id == group.id then
					return true, "already-present"
				end
				return false, "already-in-group", owner.id
			end
			if #(group.terms or {}) >= MAX_KEYWORD_COLOR_GROUP_TERMS then
				return false, "group-full"
			end
			group.terms = group.terms or {}
			table.insert(group.terms, caseSensitive == true and { term = term, caseSensitive = true } or term)
			settings.keywordColors = settings.keywordColors or copy(defaults.keywordColors)
			settings.keywordColors[normalized] = group.color
			touchKeywordColorVocabulary(settings)
			return true
		end
	end
	return false, "unknown-group"
end

function addon:SetKeywordColor(keyword, colorName)
	keyword = string.lower(trim(keyword, 40))
	colorName = trim(colorName, 40)
	if keyword == "" then
		return false, "invalid-keyword"
	end
	if not isKeywordColorSpec(colorName) then
		return false, "invalid-color"
	end
	local settings = self:GetSmartSettings()
	if type(settings.keywordColors) ~= "table" then
		settings.keywordColors = copy(defaults.keywordColors)
	end
	-- Preserve the old one-word API, but promote a known group term to its
	-- shared group.  That keeps legacy callers and the new UI in agreement.
	if type(settings.keywordColorGroups) ~= "table" then
		settings.keywordColorGroups = copy(defaults.keywordColorGroups)
	end
	for _, group in ipairs(settings.keywordColorGroups) do
		for _, termSpec in ipairs(group.terms or {}) do
			local term = type(termSpec) == "table" and termSpec.term or termSpec
			if type(term) == "string" and string.lower(term) == keyword then
				applyKeywordGroupColor(settings, group, colorName)
				touchKeywordColorVocabulary(settings)
				return true
			end
		end
	end
	settings.keywordColors[keyword] = colorName
	touchKeywordColorVocabulary(settings)
	return true
end

function addon:ResetKeywordColors()
	return self:ResetKeywordColorGroups()
end

function addon:ApplyLegacyModuleState(enabled)
	local allApplied = true
	for moduleName, module in self:IterateModules() do
		local shouldEnable = enabled and self.db.profile.modules[moduleName] ~= false
		if shouldEnable and not module:IsEnabled() then
			local ok, err = pcall(module.Enable, module)
			if not ok then
				allApplied = false
				self:Print("Could not enable legacy module " .. moduleName .. ": " .. tostring(err))
			end
		elseif not shouldEnable and module:IsEnabled() then
			local ok, err = pcall(module.Disable, module)
			if not ok then
				allApplied = false
				self:Print("Could not disable legacy module " .. moduleName .. ": " .. tostring(err))
			end
		end
		if module:IsEnabled() ~= shouldEnable then
			allApplied = false
		end
	end
	self.legacyFallbackActive = enabled and allApplied or false
	return allApplied
end

function addon:HasDuplicateChatterLoaded()
	return IsAddOnLoaded and IsAddOnLoaded("Chatter") and true or false
end

function addon:CanRunLegacyFallback()
	if self:HasDuplicateChatterLoaded() then
		return false
	end
	if self.Compatibility then
		local conflicts = self.Compatibility:GetEnabledChatAddonConflicts()
		if #conflicts > 0 then
			return false
		end
	end
	return true
end

function addon:ApplyNativeFallbackState()
	-- The copied Chatter modules remain useful when Smart Chat is off.  The one
	-- exception is another enabled chat addon: running both copies would install
	-- overlapping hooks and can corrupt the native chat path.
	return self:ApplyLegacyModuleState(self:CanRunLegacyFallback())
end

function addon:SetLegacyModulePreference(moduleName, enabled)
	local shouldEnable = enabled and true or false
	self.db.profile.modules[moduleName] = shouldEnable
	local module = self:GetModule(moduleName, true)
	if not module then
		return false
	end

	local shouldRun = shouldEnable and not self:GetSmartSettings().enabled and self:CanRunLegacyFallback()
	if shouldRun and not module:IsEnabled() then
		local ok, err = pcall(module.Enable, module)
		if not ok then
			self:Print("Could not enable legacy module " .. moduleName .. ": " .. tostring(err))
			return false
		end
	elseif not shouldRun and module:IsEnabled() then
		local ok, err = pcall(module.Disable, module)
		if not ok then
			self:Print("Could not disable legacy module " .. moduleName .. ": " .. tostring(err))
			return false
		end
	end
	return module:IsEnabled()
end

function addon:HandleDeferredSmartDockFailure()
	local settings = self:GetSmartSettings()
	settings.enabled = false
	if self.SmartDock then
		self.SmartDock:SetEnabled(false)
	end
	if self.MessageEngine then
		self.MessageEngine:SetEnabled(false)
	end
	if self.ConversationWindows then
		self.ConversationWindows:SetEnabled(false)
	end
	self:ApplyNativeFallbackState()
	if self.CustomConfig and self.CustomConfig.RefreshHomeState then
		self.CustomConfig:RefreshHomeState()
	end
end

function addon:SetSmartChatEnabled(enabled, bypassConflicts)
	local settings = self:GetSmartSettings()
	local shouldEnable = enabled and true or false

	if shouldEnable and not bypassConflicts and self.Compatibility then
		local conflicts = self.Compatibility:GetEnabledChatAddonConflicts()
		if #conflicts > 0 then
			settings.enabled = false
			self:ApplyNativeFallbackState()
			if self.MessageEngine then
				self.MessageEngine:SetEnabled(false)
			end
			if self.ConversationWindows then
				self.ConversationWindows:SetEnabled(false)
			end
			if self.SmartDock then
				self.SmartDock:SetEnabled(false)
			end
			if self.CustomConfig then
				self.CustomConfig:Open()
				self.CustomConfig:ShowConflictDialog(conflicts)
			end
			return false, "conflict"
		end
	end

	settings.enabled = shouldEnable
	if not shouldEnable then
		if self.SmartDock then
			self.SmartDock:SetEnabled(false)
		end
		if self.MessageEngine then
			self.MessageEngine:SetEnabled(false)
		end
		if self.ConversationWindows then
			self.ConversationWindows:SetEnabled(false)
		end
		self:ApplyNativeFallbackState()
		return true
	end

	-- Smart Dock owns presentation.  Copied Chatter modules target ChatFrameN and
	-- must remain dormant while those native frames are hidden.
	if not self:ApplyLegacyModuleState(false) then
		settings.enabled = false
		self:ApplyNativeFallbackState()
		if self.MessageEngine then
			self.MessageEngine:SetEnabled(false)
		end
		if self.ConversationWindows then
			self.ConversationWindows:SetEnabled(false)
		end
		return false, "legacy"
	end
	local dockReady = not self.SmartDock or self.SmartDock:SetEnabled(true)
	local dockDeferred = self.SmartDock and self.SmartDock.pendingEnabled
	if not dockReady and not dockDeferred then
		settings.enabled = false
		self:ApplyNativeFallbackState()
		if self.MessageEngine then
			self.MessageEngine:SetEnabled(false)
		end
		if self.ConversationWindows then
			self.ConversationWindows:SetEnabled(false)
		end
		return false, "dock"
	end

	if self.MessageEngine then
		self.MessageEngine:SetEnabled(true)
	end
	if self.ConversationWindows and not self.ConversationWindows:SetEnabled(true) then
		settings.enabled = false
		if self.SmartDock then
			self.SmartDock:SetEnabled(false)
		end
		if self.MessageEngine then
			self.MessageEngine:SetEnabled(false)
		end
		self:ApplyNativeFallbackState()
		return false, "conversations"
	end
	return true
end

function addon:SetColorway(name)
	local settings = self:GetSmartSettings()
	if self.Theme and self.Theme.ResolveColorwayName then
		settings.colorway = self.Theme:ResolveColorwayName(name)
	else
		settings.colorway = name
	end
	if self.Theme then
		self.Theme:Refresh()
	end
	return settings.colorway
end

function addon:SetMinimapHidden(hidden)
	local settings = self:GetSmartSettings()
	settings.launcher.minimap.hide = hidden and true or false
	if self.Launcher then
		self.Launcher:RefreshMinimap()
	end
end
