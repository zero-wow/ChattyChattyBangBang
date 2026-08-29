local addon = ChattyChattyBangBang
local Theme = addon.Theme
local Presentation = {}
addon.Presentation = Presentation

local floor = math.floor
local format = string.format
local find = string.find
local gsub = string.gsub
local lower = _G.strlower or string.lower
local max = math.max
local min = math.min
local byte = string.byte
local sub = string.sub
local GetChannelName = _G.GetChannelName
local GetMessageTypeColor = _G.GetMessageTypeColor
local ChatTypeInfo = _G.ChatTypeInfo
local UnitName = _G.UnitName

local function utf8CharacterLength(text, position)
	local first = byte(text, position) or 0
	if first >= 240 then return 4 end
	if first >= 224 then return 3 end
	if first >= 192 then return 2 end
	return 1
end

local function utf8ColumnCount(text)
	text = tostring(text or "")
	local count, cursor = 0, 1
	while cursor <= #text do
		cursor = cursor + utf8CharacterLength(text, cursor)
		count = count + 1
	end
	return count
end

local function utf8Prefix(text, columns)
	text = tostring(text or "")
	columns = math.max(0, math.floor(tonumber(columns) or 0))
	local cursor, count = 1, 0
	while cursor <= #text and count < columns do
		cursor = cursor + utf8CharacterLength(text, cursor)
		count = count + 1
	end
	return sub(text, 1, cursor - 1)
end

local sourceLabels = {
	CHAT_MSG_SAY = "SAY",
	CHAT_MSG_YELL = "YELL",
	CHAT_MSG_EMOTE = "EMOTE",
	CHAT_MSG_TEXT_EMOTE = "EMOTE",
	CHAT_MSG_ADDON = "ADDON",
	CHAT_MSG_WHISPER = "FROM",
	CHAT_MSG_WHISPER_INFORM = "TO",
	CHAT_MSG_BN_WHISPER = "B.NET",
	CHAT_MSG_BN_WHISPER_INFORM = "B.NET TO",
	CHAT_MSG_BN_CONVERSATION = "B.NET",
	CHAT_MSG_AFK = "AFK",
	CHAT_MSG_DND = "DND",
	CHAT_MSG_GUILD = "GUILD",
	CHAT_MSG_GUILD_ACHIEVEMENT = "GUILD",
	CHAT_MSG_OFFICER = "OFFICER",
	CHAT_MSG_PARTY = "PARTY",
	CHAT_MSG_PARTY_LEADER = "PARTY",
	CHAT_MSG_RAID = "RAID",
	CHAT_MSG_RAID_LEADER = "RAID",
	CHAT_MSG_RAID_WARNING = "WARNING",
	CHAT_MSG_BATTLEGROUND = "BATTLE",
	CHAT_MSG_BATTLEGROUND_LEADER = "BATTLE",
	CHAT_MSG_INSTANCE_CHAT = "INSTANCE",
	CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE",
	CHAT_MSG_SYSTEM = "SYSTEM",
	UI_ERROR_MESSAGE = "ERROR",
	CCBB_LOCAL_MESSAGE = "DEBUG",
	CHAT_MSG_LOOT = "LOOT",
	CHAT_MSG_MONEY = "MONEY",
	CHAT_MSG_ACHIEVEMENT = "ACHIEVEMENT",
	CHAT_MSG_BG_SYSTEM_NEUTRAL = "BATTLE",
	CHAT_MSG_BG_SYSTEM_ALLIANCE = "ALLIANCE",
	CHAT_MSG_BG_SYSTEM_HORDE = "HORDE",
	CHAT_MSG_ZONE_UNDER_ATTACK = "DEFENSE",
}

local sourceColors = {
	general = "textMuted",
	sync = "accent",
	conversations = "accent",
	group = "accent",
	groupFinder = "goldBright",
	pvp = "danger",
	trade = "warning",
	guild = "success",
	system = "textMuted",
	loot = "gold",
}

-- These are the eight markers every 3.3.5 client ships with.  ICON_TAG_LIST
-- is preferred at runtime because it includes the player's localized icon
-- aliases (and any client-provided icon synonyms).  The fallback keeps the
-- familiar English shorthand working when that Blizzard table is absent or a
-- third-party chat addon has replaced it with an incomplete version.
local raidMarkerAliases = {
	star = 1,
	circle = 2,
	diamond = 3,
	triangle = 4,
	moon = 5,
	square = 6,
	cross = 7,
	x = 7,
	skull = 8,
	rt1 = 1,
	rt2 = 2,
	rt3 = 3,
	rt4 = 4,
	rt5 = 5,
	rt6 = 6,
	rt7 = 7,
	rt8 = 8,
}

local function getFallbackRaidMarkerIndex(term)
	local index = raidMarkerAliases[term]
	if index then
		return index
	end

	-- RAID_TARGET_n is localized by the client.  This is deliberately a
	-- fallback behind ICON_TAG_LIST; it lets a stripped/custom UI retain the
	-- native localized names without requiring us to maintain translations.
	for markerIndex = 1, 8 do
		local localizedName = _G["RAID_TARGET_" .. markerIndex]
		if type(localizedName) == "string" and lower(localizedName) == term then
			return markerIndex
		end
	end

	return nil
end

local function getIconMarkup(index)
	local iconList = _G.ICON_LIST
	local icon = type(iconList) == "table" and iconList[index]
	if type(icon) == "string" and icon ~= "" then
		-- Blizzard's 3.3.5 ICON_LIST entries are texture prefixes ending in
		-- a colon; WIM and the default chat frame finish them with "0|t".
		-- Accommodate a full texture string too, since a skin addon may supply
		-- one of those instead.
		if find(icon, "|t", 1, true) then
			return icon
		end
		if find(icon, "|T", 1, true) then
			return icon .. "0|t"
		end
	end

	if type(index) == "number" and index >= 1 and index <= 8 then
		return format("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:0|t", index)
	end
	return nil
end

local function replaceFallbackIconExpressions(text)
	return gsub(text, "(%b{})", function(tag)
		local term = lower(sub(tag, 2, -2))
		local iconTagList = _G.ICON_TAG_LIST
		local index = type(iconTagList) == "table" and iconTagList[term]
		if type(index) == "number" then
			local icon = getIconMarkup(index)
			if icon then
				return icon
			end
		end
		-- Do not let a malformed client/skin icon table suppress the known
		-- fallback shorthand.  A valid custom icon entry above still wins.
		index = getFallbackRaidMarkerIndex(term)
		if index then
			return getIconMarkup(index)
		end
		return tag
	end)
end

function Presentation:GetHex(colorName)
	local r, g, b = Theme:GetColor(colorName)
	return format("%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

function Presentation:Color(text, colorName)
	return "|cff" .. self:GetHex(colorName) .. tostring(text or "") .. "|r"
end

function Presentation:ColorSpec(text, colorSpec)
	if type(colorSpec) ~= "string" then
		return tostring(text or "")
	end
	local classToken = string.match(colorSpec, "^class:([A-Z]+)$")
	if classToken then
		local classColor = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[classToken]
		if classColor then
			return self:ColorRGB(text, classColor.r, classColor.g, classColor.b)
		end
		-- Later-expansion class identities are not present in every Ascension
		-- client. Keep them visibly distinct instead of silently dropping color.
		return self:Color(text, "accent")
	end
	if Theme:GetPalette()[colorSpec] then
		return self:Color(text, colorSpec)
	end
	return tostring(text or "")
end

function Presentation:ColorRGB(text, red, green, blue)
	if type(red) ~= "number" or type(green) ~= "number" or type(blue) ~= "number" then
		return tostring(text or "")
	end
	local function component(value)
		return floor(min(1, max(0, value)) * 255 + 0.5)
	end
	return format("|cff%02x%02x%02x%s|r", component(red), component(green), component(blue), tostring(text or ""))
end

local function getCurrentChannelNumber(record)
	-- Resolve by name before using a persisted channel number. Channel slots can
	-- be reassigned after a relog, while the name continues to identify the
	-- channel whose current user-selected color we want.
	local channel = record.channel
	if GetChannelName and type(channel) == "string" and channel ~= "" then
		channel = string.gsub(channel, "^%d+%.%s*", "")
		local currentChannelNumber = GetChannelName(channel)
		local channelNumber = tonumber(currentChannelNumber)
		if channelNumber and channelNumber > 0 then
			return channelNumber
		end
		-- Do not borrow an old numeric slot for a channel we no longer belong
		-- to. Blizzard can reuse the slot for a completely different channel;
		-- GetChannelColor will use the safe generic CHANNEL color instead.
		return nil
	end

	local channelNumber = tonumber(record.channelNumber)
	if channelNumber and channelNumber > 0 then
		return channelNumber
	end
	return nil
end

local function getChatColor(colorType)
	if GetMessageTypeColor then
		local red, green, blue = GetMessageTypeColor(colorType)
		if type(red) == "number" and type(green) == "number" and type(blue) == "number" then
			return red, green, blue
		end
	end
	local color = ChatTypeInfo and ChatTypeInfo[colorType]
	if color and type(color.r) == "number" and type(color.g) == "number" and type(color.b) == "number" then
		return color.r, color.g, color.b
	end
	return nil
end

function Presentation:GetChannelColor(record)
	if type(record) ~= "table" then
		return nil
	end

	-- GetMessageTypeColor / ChatTypeInfo is the same state Blizzard's Chat
	-- settings pane changes (and which Chatter's Channel Colors module keeps
	-- stable by name). Read it at render time so an open dock reflects a color
	-- change immediately instead of baking a theme color into saved messages.
	local channelNumber = getCurrentChannelNumber(record)
	if channelNumber then
		local red, green, blue = getChatColor("CHANNEL" .. channelNumber)
		if red then
			return red, green, blue
		end
	end

	-- A historical line can outlive its channel slot. The generic Blizzard
	-- channel color is still a player-controlled, more faithful fallback than
	-- the dock theme when no live channel mapping remains.
	return getChatColor("CHANNEL")
end

local function keywordBoundary(text, position)
	local character = sub(text, position, position)
	return character == "" or not find(character, "[%a%d]")
end

function Presentation:GetKeywordColorRules(settings)
	local revision = tonumber(settings.keywordColorRevision) or 0
	local cached = self.keywordColorRuleCache
	if cached and cached.settings == settings and cached.revision == revision then
		return cached.rules, cached.caseSensitiveTerms
	end

	local groups = settings.keywordColorGroups or {}
	local rules = {}
	local caseSensitiveTerms = {}

	-- Gather phrases and ordinary tokens together, then prefer the longest
	-- matching term. That makes EXP AURA one colored phrase and prevents its
	-- AURA member from winning prematurely.
	for _, group in ipairs(groups) do
		if type(group) == "table" and type(group.color) == "string" then
			for _, termSpec in ipairs(group.terms or {}) do
				local term = type(termSpec) == "table" and termSpec.term or termSpec
				if type(term) == "string" and term ~= "" then
					local caseSensitive = type(termSpec) == "table" and termSpec.caseSensitive == true
					local numericSuffix = type(termSpec) == "table" and termSpec.numericSuffix == true
					if caseSensitive then
						-- Legacy keywordColors materializes every group term in lowercase
						-- for API compatibility. Do not let that broad fallback undo an
						-- explicit uppercase-only rule such as RFC or M10+.
						caseSensitiveTerms[lower(term)] = true
					end
						table.insert(rules, {
							term = term,
							comparison = lower(term),
							color = group.color,
							caseSensitive = caseSensitive,
							numericSuffix = numericSuffix,
							numericPrefix = numericSuffix and lower(string.gsub(term, "#", "")) or nil,
						})
				end
			end
		end
	end
	table.sort(rules, function(left, right)
		return #left.term > #right.term
	end)
	self.keywordColorRuleCache = {
		settings = settings,
		revision = revision,
		rules = rules,
		caseSensitiveTerms = caseSensitiveTerms,
	}
	return rules, caseSensitiveTerms
end

function Presentation:ColorizePlainText(text)
	local settings = addon:GetSmartSettings()
	local colors = settings.keywordColors or {}
	local rules, caseSensitiveTerms = self:GetKeywordColorRules(settings)

	local loweredText = lower(text)
	local position, length = 1, #text
	local output = {}
	while position <= length do
		local matchedRule, matchedFinish
		if keywordBoundary(text, position - 1) then
			for _, rule in ipairs(rules) do
				local finish
				if rule.numericSuffix then
					-- LF# is intentional UI shorthand for LF followed by one or more
					-- digits (LF1, LF2, LF10, ...), not a literal hash character.
					local numericToken = string.match(sub(loweredText, position), "^" .. (rule.numericPrefix or "") .. "%d+")
					if numericToken then
						finish = position + #numericToken - 1
					end
				else
					finish = position + #rule.term - 1
				end
				if finish and finish <= length and keywordBoundary(text, finish + 1) then
					local candidate = sub(text, position, finish)
					if (rule.numericSuffix and not rule.caseSensitive)
						or (rule.caseSensitive and candidate == rule.term)
						or (not rule.caseSensitive and sub(loweredText, position, finish) == rule.comparison) then
						matchedRule = rule
						matchedFinish = finish
						break
					end
				end
			end
		end
		if matchedRule then
			local finish = matchedFinish or (position + #matchedRule.term - 1)
			table.insert(output, self:ColorSpec(sub(text, position, finish), matchedRule.color))
			position = finish + 1
		else
			local token = string.match(sub(text, position), "^[%a%d][%a%d%+%-']*")
			if token then
				local normalizedToken = lower(token)
				local colorSpec
				if not caseSensitiveTerms[normalizedToken] then
					colorSpec = colors[normalizedToken]
				end
				table.insert(output, colorSpec and self:ColorSpec(token, colorSpec) or token)
				position = position + #token
			else
				table.insert(output, sub(text, position, position))
				position = position + 1
			end
		end
	end
	return table.concat(output)
end

local function nativeUnitName(unit, missing)
	if type(UnitName) == "function" then
		local ok, name = pcall(UnitName, unit)
		if ok and type(name) == "string" and name ~= "" then
			return name
		end
	end
	return missing
end

local function replaceNativeNameSubstitutions(text)
	-- These are chat substitutions, not a general string.format pass.  In
	-- particular, %s intentionally remains untouched: without caller-supplied
	-- arguments it is a Lua format placeholder, not a player/unit token.
	return gsub(text, "%%([tTnNfF])", function(token)
		token = lower(token)
		if token == "f" then
			return nativeUnitName("focus", "<no focus>")
		end
		return nativeUnitName("target", "<no target>")
	end)
end

function Presentation:ReplaceChatExpressions(text)
	-- Blizzard uses both brace expressions ({skull}, {group1}) and percent
	-- substitutions (%t, %n, %f).  The old brace-only gate meant a system line
	-- containing only a native percent substitution never reached the client's
	-- expression resolver.
	if type(text) ~= "string" or text == "" or (not find(text, "{", 1, true) and not find(text, "%", 1, true)) then
		return text
	end

	-- Let the client process its own expressions first.  On clients that
	-- expose this helper it covers Blizzard's full icon/group vocabulary and
	-- honors any expansion-specific forms.  Some 3.3.5-derived clients omit
	-- it, so the known raid marker fallback below remains authoritative for
	-- the common {skull}/{rt8} syntax.
	local replaceNativeExpressions = _G.ChatFrame_ReplaceIconAndGroupExpressions
	if type(replaceNativeExpressions) == "function" then
		local ok, replaced = pcall(replaceNativeExpressions, text)
		if ok and type(replaced) == "string" then
			text = replaced
		end
	end

	text = replaceNativeNameSubstitutions(text)
	return replaceFallbackIconExpressions(text)
end

-- Every generated texture must bypass ColorizePlainText.  Keyword coloring
-- is intentionally allowed to style normal words, but inserting |c...|r
-- into Interface\\TargetingFrame\\... would corrupt the texture escape.  A
-- second pass through ColorizeMessage handles any generated texture tags as
-- opaque markup instead of raw words.
function Presentation:ColorizePlainSegment(text, skipExpressionReplacement)
	if text == "" then
		return ""
	end
	if not skipExpressionReplacement then
		local replaced = self:ReplaceChatExpressions(text)
		if replaced ~= text then
			return self:ColorizeMessage(replaced, true)
		end
	end
	return self:ColorizePlainText(text)
end

local controlSequences = {
	{ token = "|H", kind = "link" },
	{ token = "|T", kind = "texture" },
	{ token = "|A", kind = "atlas" },
	{ token = "|c", kind = "color" },
	{ token = "|r", kind = "reset" },
}

local function findNextControlSequence(text, cursor)
	local earliest
	local kind
	for index = 1, #controlSequences do
		local entry = controlSequences[index]
		local position = find(text, entry.token, cursor, true)
		if position and (not earliest or position < earliest) then
			earliest = position
			kind = entry.kind
		end
	end
	return earliest, kind
end

function Presentation:ColorizeMessage(text, skipExpressionReplacement)
	text = tostring(text or "")
	local result = {}
	local cursor = 1
	local textLength = #text
	while cursor <= textLength do
		local controlStart, controlKind = findNextControlSequence(text, cursor)
		if not controlStart then
			table.insert(result, self:ColorizePlainSegment(sub(text, cursor), skipExpressionReplacement))
			break
		end

		if controlStart > cursor then
			table.insert(result, self:ColorizePlainSegment(sub(text, cursor, controlStart - 1), skipExpressionReplacement))
		end

		if controlKind == "link" then
			local firstLabel = find(text, "|h", controlStart + 2, true)
			local secondLabel = firstLabel and find(text, "|h", firstLabel + 2, true)
			if not secondLabel then
				table.insert(result, sub(text, controlStart))
				break
			end
			table.insert(result, sub(text, controlStart, secondLabel + 1))
			cursor = secondLabel + 2
		elseif controlKind == "texture" or controlKind == "atlas" then
			local closingToken = controlKind == "texture" and "|t" or "|a"
			local closingPosition = find(text, closingToken, controlStart + 2, true)
			if not closingPosition then
				table.insert(result, sub(text, controlStart))
				break
			end
			table.insert(result, sub(text, controlStart, closingPosition + 1))
			cursor = closingPosition + 2
		elseif controlKind == "color" then
			-- A valid WoW color escape is |c followed by eight hex digits.  Keep
			-- the raw markup opaque even when a malformed message is received;
			-- rendering the sender's text unchanged is safer than recoloring it.
			local colorEnd = min(textLength, controlStart + 9)
			table.insert(result, sub(text, controlStart, colorEnd))
			cursor = colorEnd + 1
		else -- reset
			table.insert(result, "|r")
			cursor = controlStart + 2
		end
	end
	return table.concat(result)
end

function Presentation:GetColoredName(record, displayName)
	local originalName = record.sender
	local name = displayName or originalName
	if not name or name == "" then
		return nil
	end
	name = tostring(name)

	local playerNames = addon.GetModule and addon:GetModule("Player Class Colors", true)
	-- Player Class Colors resolves its colour from the original full name. A
	-- fixed lane can abbreviate only the visible label, so avoid asking that
	-- module to hand back the unabridged text in the rare over-width case.
	if (displayName == nil or displayName == originalName)
		and playerNames and playerNames.ColorName and playerNames.db and playerNames:IsEnabled() then
		local ok, coloredName = pcall(playerNames.ColorName, playerNames, name)
		if ok and coloredName then
			return coloredName
		end
	end

	local classColor = record.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[record.class]
	if classColor then
		return format("|cff%02x%02x%02x%s|r", floor(classColor.r * 255), floor(classColor.g * 255), floor(classColor.b * 255), name)
	end
	return self:Color(name, "text")
end

function Presentation:GetSource(record)
	if record.event == "CHAT_MSG_CHANNEL" then
		local channel = record.channel or (record.channelNumber and tostring(record.channelNumber)) or "CHANNEL"
		channel = string.gsub(channel, "^%d+%.%s*", "")
		-- Ascension's zone channel arrives as "Zone - <place>".  The useful
		-- part in a compact source lane is the place, not the generic channel
		-- category, so render "Stormwind" / "Pale Reach" while preserving the
		-- original channel string for routing, saved history, and Blizzard
		-- color lookup.  Do this only for Zone: names such as "Trade - City"
		-- remain untouched because their prefix carries real meaning.
		local zoneName = string.match(channel, "^[Zz][Oo][Nn][Ee]%s*%-%s*(.-)%s*$")
		if zoneName and zoneName ~= "" then
			channel = zoneName
		end
		return string.upper(channel)
	end
	return sourceLabels[record.event] or string.gsub(record.event or "CHAT", "^CHAT_MSG_", "")
end

function Presentation:GetTagText(record)
	local settings = addon:GetSmartSettings()
	if not record.tags or (settings.dock and settings.dock.showClassificationTags == false) then
		return ""
	end

	local tags = {}
	local normalized = record.normalized
	if type(normalized) ~= "string" then
		normalized = string.lower(tostring(record.text or ""))
	end
	local function addInferredTag(label, colorName, evidence)
		-- Classification metadata must not echo a word already present in the
		-- player's message. The original text is preserved and colorized once;
		-- badges appear only when they communicate an inferred shorthand.
		for index = 1, #evidence do
			if string.find(normalized, evidence[index], 1, true) then
				return
			end
		end
		table.insert(tags, self:Color(label, colorName))
	end
	if record.tags["intent:recruiting"] then
		addInferredTag("LFM", "goldBright", { "lfm" })
	elseif record.tags["intent:seeking"] then
		addInferredTag("LFG", "goldBright", { "lfg" })
	elseif record.tags["intent:selling"] then
		addInferredTag("WTS", "warning", { "wts" })
	elseif record.tags["intent:buying"] then
		addInferredTag("WTB", "success", { "wtb" })
	elseif record.tags["intent:trading"] then
		addInferredTag("WTT", "accent", { "wtt" })
	end
	if record.tags["role:tank"] then
		addInferredTag("TANK", "accent", { "tank" })
	end
	if record.tags["role:healer"] then
		addInferredTag("HEAL", "success", { "heal" })
	end
	if record.tags["role:dps"] then
		addInferredTag("DPS", "danger", { "dps" })
	end
	if #tags == 0 then
		return ""
	end
	return "  " .. table.concat(tags, self:Color(" / ", "border"))
end

local function fitAndPadPresentationColumn(text, width, trailingSpacing)
	width = math.max(0, math.floor(tonumber(width) or 0))
	text = tostring(text or "")
	if width <= 0 then
		return text
	end
	-- SmartDock includes any positive CHANNEL GAP inside `width`. Keep those
	-- cells reserved instead of allowing a long/truncated label to consume them.
	-- A negative GAP has already shortened `width` in SmartDock and therefore
	-- renders no literal negative space here; the visible divider remains the
	-- hard boundary that prevents the source and message cells from overlapping.
	trailingSpacing = math.max(0, math.floor(tonumber(trailingSpacing) or 0))
	trailingSpacing = math.min(width, trailingSpacing)
	local contentWidth = math.max(0, width - trailingSpacing)
	local textWidth = utf8ColumnCount(text)
	-- A source lane should make the dividers easy to scan, not let one stale
	-- long channel name push every active message halfway across the dock. The
	-- dock supplies a deliberately modest lane width; long source labels remain
	-- recognizable without defeating the compact layout.
	if textWidth > contentWidth then
		if contentWidth <= 0 then
			text = ""
		elseif contentWidth <= 3 then
			text = utf8Prefix(text, contentWidth)
		else
			text = utf8Prefix(text, contentWidth - 3) .. "..."
		end
		textWidth = contentWidth
	end
	if contentWidth > textWidth then
		text = text .. string.rep(" ", contentWidth - textWidth)
	end
	return text .. string.rep(" ", trailingSpacing)
end

local function getAlignedSourceColumnSpacing()
	local spacing = 2
	if type(addon.GetColumnAlignmentSpacing) == "function" then
		local ok, configured = pcall(addon.GetColumnAlignmentSpacing, addon)
		if ok then
			spacing = math.max(-8, math.min(8, math.floor(tonumber(configured) or 2)))
		end
	end
	return spacing
end

local function getEffectiveSenderColumnWidth(width, spacing)
	width = math.max(0, math.floor(tonumber(width) or 0))
	spacing = math.max(-8, math.min(8, math.floor(tonumber(spacing) or 2)))
	if width <= 0 or spacing >= 0 then
		return width
	end
	-- Negative [NAME] GAP is safe compaction, never a negative render offset.
	-- Keep one name cell plus both brackets so the hyperlink remains visibly
	-- bounded even at the most compact supported value.
	return math.max(3, width + spacing)
end

-- Sender columns include their square brackets in the fixed budget. Keep the
-- closing bracket visible when an unusually long historical/BNet name needs
-- abbreviation; a bare chopped name is much harder to recognize as a player
-- lane. The returned padding belongs outside the hyperlink, so its click
-- target remains exactly the visible player label.
local function fitAndPadSenderName(name, width)
	name = tostring(name or "")
	width = math.max(0, math.floor(tonumber(width) or 0))
	if width <= 0 then
		return name, ""
	end

	-- Two cells are reserved for [ and ]. The dock always provides a sane
	-- width, but the clamp keeps this helper safe for API callers and tests.
	local nameWidth = math.max(1, width - 2)
	local renderedNameWidth = utf8ColumnCount(name)
	if renderedNameWidth > nameWidth then
		if nameWidth <= 3 then
			name = utf8Prefix(name, nameWidth)
		else
			name = utf8Prefix(name, nameWidth - 3) .. "..."
		end
		renderedNameWidth = nameWidth
	end
	local visibleWidth = renderedNameWidth + 2
	local padding = visibleWidth < width and string.rep(" ", width - visibleWidth) or ""
	return name, padding
end

-- The optional source/name widths and name spacing are view-local presentation
-- aids supplied by SmartDock. They deliberately pad only rendered text: chat
-- history, routing, sender links, and saved records remain byte-for-byte
-- untouched.
function Presentation:FormatParts(record, sourceColumnWidth, senderColumnWidth, senderColumnSpacing, metadata)
	metadata = type(metadata) == "table" and metadata or nil
	local timestamp = self:Color(record.timestamp or "", "textMuted")
	local sourceText = self:GetSource(record)
	-- Responsive metadata is presentation-only.  Missing fields never reserve a
	-- blank lane, and the default nil contract preserves every historical caller.
	local showTimestamp = (not metadata or metadata.showTimestamp ~= false)
		and tostring(record.timestamp or "") ~= ""
	local showSource = (not metadata or metadata.showSource ~= false)
		and record.event ~= nil and tostring(sourceText or "") ~= ""
	local showSender = (not metadata or metadata.showSender ~= false)
	local sourceSpacing = sourceColumnWidth and math.max(0, getAlignedSourceColumnSpacing()) or 0
	local formattedSourceText = fitAndPadPresentationColumn(sourceText, sourceColumnWidth, sourceSpacing)
	local source = self:Color(formattedSourceText, sourceColors[record.view] or "textMuted")
	-- The rail tells the player where they are; the source label tells them
	-- where this individual line came from.  Use the player's Blizzard chat
	-- colors for every supported message type, not only channel lines in
	-- General, so mixed tabs remain immediately scannable.
	local red, green, blue
	if addon.GetChatColorForRecord then
		red, green, blue = addon:GetChatColorForRecord(record)
	elseif record.event == "CHAT_MSG_CHANNEL" then
		red, green, blue = self:GetChannelColor(record)
	end
	if red then
		source = self:ColorRGB(formattedSourceText, red, green, blue)
	end
	local message = self:ColorizeMessage(record.text or "")
	local rawSender = record.sender
	local normalizedSenderSpacing = math.max(-8,
		math.min(8, math.floor(tonumber(senderColumnSpacing) or 2)))
	local effectiveSenderWidth = senderColumnWidth
		and getEffectiveSenderColumnWidth(senderColumnWidth, normalizedSenderSpacing) or nil
	local visibleSender, senderPadding
	if rawSender and rawSender ~= "" then
		visibleSender, senderPadding = fitAndPadSenderName(rawSender, effectiveSenderWidth)
	end
	local name = showSender and visibleSender and self:GetColoredName(record, visibleSender) or nil
	-- The source lane already contains its positive CHANNEL GAP. Do not prepend
	-- another implicit space before its trailing divider: GAP 0 is exact and a
	-- negative value compacts the label inside the lane. Natural (unaligned) rows
	-- still receive the familiar one-space divider on both sides.
	local divider = self:Color(" | ", "borderMuted")
	local sourceDivider = self:Color(sourceColumnWidth and "| " or " | ", "borderMuted")

	local leader = ""
	if showTimestamp then
		leader = timestamp
	end
	if showSource then
		if leader ~= "" then
			leader = leader .. divider
		end
		leader = leader .. source .. sourceDivider
	elseif leader ~= "" then
		-- Timestamp-only metadata still needs a readable boundary before the
		-- sender or message that follows it.
		leader = leader .. divider
	end

	if name then
		local playerLink
		if record.isBNet then
			playerLink = "[" .. name .. "]"
		else
			playerLink = "|Hccbbplayer:" .. record.id .. "|h[" .. name .. "]|h"
		end
		-- Negative spacing was consumed by the safe lane compaction above. Only
		-- positive values materialize as cells after the hyperlink/padding.
		local spacing = math.max(0, normalizedSenderSpacing)
		return leader .. playerLink .. (senderPadding or "")
			.. self:GetTagText(record) .. string.rep(" ", spacing), message
	end
	return leader, message
end

function Presentation:Format(record, sourceColumnWidth, senderColumnWidth, senderColumnSpacing, metadata)
	local leader, message = self:FormatParts(record, sourceColumnWidth, senderColumnWidth, senderColumnSpacing, metadata)
	return leader .. message
end

-- Wrath's SetIndentedWordWrap is only a boolean generic-indent switch. It
-- cannot infer Chatty's variable TIME | SOURCE | [PLAYER] leader, so it cannot
-- place a continuation beneath the first message character. Exact aligned
-- views already select a fixed-width SharedMedia face; this renderer therefore
-- wraps in those same character cells and inserts the leader's visible cell
-- count before every continuation. WoW control sequences remain intact.
local function renderedColumnCount(text)
	text = tostring(text or "")
	local count, cursor, length = 0, 1, #text
	while cursor <= length do
		local marker = sub(text, cursor, cursor + 1)
		if marker == "|c" then
			cursor = min(length + 1, cursor + 10)
		elseif marker == "|r" then
			cursor = cursor + 2
		elseif marker == "|H" then
			local firstLabel = find(text, "|h", cursor + 2, true)
			local secondLabel = firstLabel and find(text, "|h", firstLabel + 2, true)
			if secondLabel then
				count = count + renderedColumnCount(sub(text, firstLabel + 2, secondLabel - 1))
				cursor = secondLabel + 2
			else
				count = count + 1
				cursor = cursor + 1
			end
		elseif marker == "|T" or marker == "|A" then
			local closing = marker == "|T" and "|t" or "|a"
			local closeAt = find(text, closing, cursor + 2, true)
			if closeAt then
				-- Raid markers and inline icons occupy approximately one cell in the
				-- fixed-width chat faces Chatty offers for aligned columns.
				count = count + 1
				cursor = closeAt + 2
			else
				count = count + 1
				cursor = cursor + 1
			end
		else
			count = count + 1
			cursor = cursor + utf8CharacterLength(text, cursor)
		end
	end
	return count
end

function Presentation:GetRenderedColumnCount(text)
	return renderedColumnCount(text)
end

local function renderedTokens(text)
	local tokens = {}
	local cursor, length = 1, #text
	local function add(raw, width, kind, details)
		local token = { raw = raw, width = width or 0, kind = kind }
		if details then
			for key, value in pairs(details) do token[key] = value end
		end
		tokens[#tokens + 1] = token
	end

	while cursor <= length do
		local marker = sub(text, cursor, cursor + 1)
		if marker == "|c" then
			local finish = min(length, cursor + 9)
			add(sub(text, cursor, finish), 0, "control")
			cursor = finish + 1
		elseif marker == "|r" then
			add("|r", 0, "control")
			cursor = cursor + 2
		elseif marker == "|H" then
			local firstLabel = find(text, "|h", cursor + 2, true)
			local secondLabel = firstLabel and find(text, "|h", firstLabel + 2, true)
			if secondLabel then
				local raw = sub(text, cursor, secondLabel + 1)
				local label = sub(text, firstLabel + 2, secondLabel - 1)
				add(raw, renderedColumnCount(label), "link", {
					header = sub(text, cursor, firstLabel + 1),
					label = label,
					tail = "|h",
				})
				cursor = secondLabel + 2
			else
				add(sub(text, cursor), renderedColumnCount(sub(text, cursor)), "plain")
				break
			end
		elseif marker == "|T" or marker == "|A" then
			local closing = marker == "|T" and "|t" or "|a"
			local closeAt = find(text, closing, cursor + 2, true)
			if closeAt then
				add(sub(text, cursor, closeAt + 1), 1, "image")
				cursor = closeAt + 2
			else
				add(sub(text, cursor, cursor), 1, "plain")
				cursor = cursor + 1
			end
		else
			local characterLength = utf8CharacterLength(text, cursor)
			local character = sub(text, cursor, cursor + characterLength - 1)
			if character == "\n" then
				add(character, 0, "newline")
			elseif string.match(character, "%s") then
				add(character, 1, "space")
			else
				local start, width = cursor, 0
				while cursor <= length do
					if sub(text, cursor, cursor + 1) == "|c"
						or sub(text, cursor, cursor + 1) == "|r"
						or sub(text, cursor, cursor + 1) == "|H"
						or sub(text, cursor, cursor + 1) == "|T"
						or sub(text, cursor, cursor + 1) == "|A" then
						break
					end
					local size = utf8CharacterLength(text, cursor)
					local value = sub(text, cursor, cursor + size - 1)
					if value == "\n" or string.match(value, "%s") then
						break
					end
					cursor = cursor + size
					width = width + 1
				end
				add(sub(text, start, cursor - 1), width, "plain")
				characterLength = 0
			end
			cursor = cursor + characterLength
		end
	end
	return tokens
end

local closingPunctuation = {
	[","] = true, ["."] = true, [";"] = true, [":"] = true,
	["!"] = true, ["?"] = true, [")"] = true, ["]"] = true,
	["}"] = true, ["%"] = true, ["…"] = true, ["，"] = true,
	["。"] = true, ["！"] = true, ["？"] = true, ["："] = true,
	["；"] = true,
}

local function isClosingPunctuationCharacter(value)
	return closingPunctuation[value] == true
end

local function isClosingPunctuationToken(token)
	if not token or token.kind ~= "plain" or token.width < 1 then return false end
	local cursor = 1
	while cursor <= #token.raw do
		local size = utf8CharacterLength(token.raw, cursor)
		if not isClosingPunctuationCharacter(sub(token.raw, cursor, cursor + size - 1)) then
			return false
		end
		cursor = cursor + size
	end
	return true
end

function Presentation:WrapRenderedMessage(message, leaderColumns, totalColumns, continuationColumns)
	message = tostring(message or "")
	leaderColumns = max(0, floor(tonumber(leaderColumns) or 0))
	totalColumns = max(0, floor(tonumber(totalColumns) or 0))
	continuationColumns = max(0, floor(tonumber(continuationColumns) or leaderColumns))
	local contentColumns = totalColumns - leaderColumns
	if message == "" or contentColumns < 1 then
		return message, 0
	end

	local continuationContentColumns = max(1, totalColumns - continuationColumns)
	local continuation = "\n" .. string.rep(" ", continuationColumns)
	local output = {}
	local lineWidth = 0
	local breakCount = 0
	local function addContinuation()
		output[#output + 1] = continuation
		lineWidth = 0
		contentColumns = continuationContentColumns
		breakCount = breakCount + 1
	end
	local function appendLongPlain(raw)
		local cursor = 1
		local appendedHere = 0
		while cursor <= #raw do
			local size = utf8CharacterLength(raw, cursor)
			local character = sub(raw, cursor, cursor + size - 1)
			if lineWidth >= contentColumns then
				-- Do not strand a closing comma/period/etc. as the sole first glyph
				-- of a manually wrapped URL or other unbroken token. Move the prior
				-- glyph with it when there is room for that two-glyph continuation.
				if appendedHere > 0 and lineWidth > 1 and contentColumns > 1
					and isClosingPunctuationCharacter(character) then
					local previous = table.remove(output)
					lineWidth = lineWidth - 1
					addContinuation()
					output[#output + 1] = previous
					lineWidth = 1
				else
					addContinuation()
				end
			end
			output[#output + 1] = character
			cursor = cursor + size
			lineWidth = lineWidth + 1
			appendedHere = appendedHere + 1
		end
	end
	local function appendLongLink(token)
		local wrappedLabel = Presentation:WrapRenderedMessage(token.label, 0, contentColumns)
		local pieces = {}
		for piece in string.gmatch(wrappedLabel .. "\n", "(.-)\n") do
			pieces[#pieces + 1] = piece
		end
		for index = 1, #pieces do
			if index > 1 then addContinuation() end
			output[#output + 1] = token.header .. pieces[index] .. token.tail
			lineWidth = renderedColumnCount(pieces[index])
		end
	end
	local tokens = renderedTokens(message)
	for tokenIndex, token in ipairs(tokens) do
		-- Keyword coloring can put a zero-width |r boundary between a word and
		-- its comma. Reserve the punctuation with the preceding visible token so
		-- the wrapper breaks before the word rather than orphaning punctuation.
		local protectedTrailingWidth = 0
		if token.width > 0 and token.kind ~= "space" and not isClosingPunctuationToken(token) then
			local nextIndex = tokenIndex + 1
			while tokens[nextIndex] and tokens[nextIndex].width == 0
				and tokens[nextIndex].kind == "control" do
				nextIndex = nextIndex + 1
			end
			if isClosingPunctuationToken(tokens[nextIndex]) then
				protectedTrailingWidth = tokens[nextIndex].width
			end
		end
		if token.kind == "newline" then
			addContinuation()
		elseif token.width == 0 then
			output[#output + 1] = token.raw
		elseif token.kind == "space" then
			if lineWidth > 0 and lineWidth + token.width <= contentColumns then
				output[#output + 1] = token.raw
				lineWidth = lineWidth + token.width
			elseif lineWidth > 0 then
				addContinuation()
			end
		elseif token.kind == "plain" and token.width > contentColumns then
			if lineWidth > 0 then
				addContinuation()
			end
			appendLongPlain(token.raw)
		elseif token.kind == "link" and token.width > contentColumns then
			if lineWidth > 0 then
				addContinuation()
			end
			appendLongLink(token)
		elseif lineWidth > 0
			and lineWidth + token.width + protectedTrailingWidth > contentColumns then
			addContinuation()
			output[#output + 1] = token.raw
			lineWidth = token.width
		else
			output[#output + 1] = token.raw
			lineWidth = lineWidth + token.width
		end
	end
	return table.concat(output), breakCount
end

-- Exact hanging alignment is cheap when the message lane is comfortably wide,
-- but the same indent can leave only a handful of cells in a narrow window.
-- Grow the fallback threshold with the *measured* continuation width. Six
-- remains the narrow-window baseline requested by the player; above twenty-four
-- usable message cells, each additional eight cells permits one more exact wrap
-- up to a sane twelve-wrap ceiling.
function Presentation:GetAdaptiveHangingWrapBudget(leaderColumns, totalColumns)
	leaderColumns = max(0, floor(tonumber(leaderColumns) or 0))
	totalColumns = max(0, floor(tonumber(totalColumns) or 0))
	local continuationContentColumns = max(0, totalColumns - leaderColumns)
	local extraWidth = max(0, continuationContentColumns - 24)
	return min(12, 6 + floor(extraWidth / 8)), continuationContentColumns
end

function Presentation:FormatWrapped(record, sourceColumnWidth, senderColumnWidth, senderColumnSpacing, totalColumns, metadata)
	local leader, message = self:FormatParts(record, sourceColumnWidth, senderColumnWidth, senderColumnSpacing, metadata)
	local leaderColumns = renderedColumnCount(leader)
	local exactMessage, exactBreaks = self:WrapRenderedMessage(message, leaderColumns, totalColumns, leaderColumns)
	local adaptiveBreakBudget = self:GetAdaptiveHangingWrapBudget(leaderColumns, totalColumns)
	-- Do not abandon alignment merely because a message is long. Compare both
	-- predicted layouts and use the compact two-cell continuation only when the
	-- exact result exceeds its width-aware budget *and* compacting saves at least
	-- two lines and one quarter of the rendered height. Explicit line breaks and
	-- other cases where compacting would not truly help therefore remain aligned.
	local continuationColumns = leaderColumns
	local renderedMessage = exactMessage
	local renderedBreaks = exactBreaks
	local compactBreaks
	if exactBreaks >= adaptiveBreakBudget and leaderColumns > 2 then
		local compactMessage
		compactMessage, compactBreaks = self:WrapRenderedMessage(message, leaderColumns, totalColumns, 2)
		local exactLines = exactBreaks + 1
		local compactLines = compactBreaks + 1
		local savedLines = exactLines - compactLines
		if savedLines >= 2 and compactLines * 4 <= exactLines * 3 then
			continuationColumns = 2
			renderedMessage = compactMessage
			renderedBreaks = compactBreaks
		end
	end
	return leader .. renderedMessage, leaderColumns, continuationColumns, renderedBreaks, exactBreaks,
		adaptiveBreakBudget, compactBreaks
end
