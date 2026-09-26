-- Policy-only transfer. This file intentionally has no serializer, Lua loader,
-- or access to chat records, identities, blocklists, or arbitrary profile keys.
local addon = ChattyChattyBangBang
local Transfer = {}
addon.PolicyTransfer = Transfer

local HEADER = "CCBB-POLICY/1"
local MAX_BYTES = 8192
local specifications = {
	{ "spam.enabled", "boolean" },
	{ "spam.exemptSelf", "boolean" },
	{ "spam.duplicate.enabled", "boolean" },
	{ "spam.duplicate.window", "number", 0.1, 3600 },
	{ "spam.duplicate.allowedCopies", "integer", 1, 100 },
	{ "spam.duplicate.muteAfter", "integer", 0, 100 },
	{ "spam.duplicate.minimumLength", "integer", 0, 1024 },
	{ "spam.duplicate.caseInsensitive", "boolean" },
	{ "spam.duplicate.collapseWhitespace", "boolean" },
	{ "spam.duplicate.stripFormatting", "boolean" },
	{ "spam.duplicate.ignorePunctuation", "boolean" },
	-- crossChannels is deliberately excluded: the current firewall always uses
	-- cross-channel duplicate matching regardless of the legacy saved switch.
	{ "spam.burst.enabled", "boolean" },
	{ "spam.burst.window", "number", 0.1, 300 },
	{ "spam.burst.limit", "integer", 1, 1000 },
	{ "spam.burst.muteDuration", "number", 0, 3600 },
	{ "spam.repeatAds.enabled", "boolean" },
	{ "spam.repeatAds.window", "integer", 3600, 604800 },
	{ "spam.repeatAds.maxCopies", "integer", 1, 24 },
	{ "spam.repeatAds.minimumGap", "integer", 0, 86400 },
	{ "spam.repeatAds.minimumLength", "integer", 12, 128 },
	{ "spam.escalation.enabled", "boolean" },
	{ "spam.escalation.mutesBeforeBan", "integer", 1, 100 },
	{ "spam.escalation.strikeWindow", "integer", 0, 2592000 },
	{ "spam.scopes.channel", "boolean" },
	{ "spam.scopes.local", "boolean" },
	{ "spam.scopes.guild", "boolean" },
	{ "spam.scopes.group", "boolean" },
	{ "spam.scopes.whisper", "boolean" },
	{ "spam.scopes.bnet", "boolean" },
}

local byKey = {}
for index, spec in ipairs(specifications) do
	spec.index = index
	spec.parts = {}
	for part in string.gmatch(spec[1], "[^%.]+") do
		spec.parts[#spec.parts + 1] = part
	end
	byKey[spec[1]] = spec
end

local function read(settings, spec)
	local node = settings
	for _, part in ipairs(spec.parts) do
		if type(node) ~= "table" then return nil end
		node = node[part]
	end
	return node
end

local function valid(spec, value)
	if spec[2] == "boolean" then return type(value) == "boolean" end
	if type(value) ~= "number" or value ~= value
		or value < spec[3] or value > spec[4] then return false end
	return spec[2] ~= "integer" or value == math.floor(value)
end

local function encode(spec, value)
	if not valid(spec, value) then return nil end
	if spec[2] == "boolean" then return value and "true" or "false" end
	if spec[2] == "integer" then return string.format("%.0f", value) end
	-- Firewall windows accept fractional seconds. Twelve decimal places avoid
	-- unstable binary-float tails while preserving more than the UI exposes.
	local result = string.format("%.12f", value)
	result = string.gsub(result, "0+$", "")
	return string.gsub(result, "%.$", "")
end

local function decode(spec, token)
	if spec[2] == "boolean" then
		if token == "true" then return true end
		if token == "false" then return false end
		return nil
	end
	if #token > 24 or (not string.match(token, "^%d+$")
		and not string.match(token, "^%d+%.%d+$")) then return nil end
	local value = tonumber(token)
	if valid(spec, value) then return value end
	return nil
end

local function parse(text)
	if type(text) ~= "string" or #text > MAX_BYTES then return nil, "invalid-size" end
	text = string.gsub(text, "\r\n", "\n")
	if string.find(text, "\r", 1, true) or string.sub(text, -1) ~= "\n" then
		return nil, "invalid-line-ending"
	end
	local first = true
	local lastIndex = 0
	local values = {}
	for line in string.gmatch(text, "([^\n]*)\n") do
		if first then
			if line ~= HEADER then return nil, "invalid-header" end
			first = false
		else
			local key, token = string.match(line, "^([%w%.]+)=([%w%.]+)$")
			local spec = key and byKey[key]
			if not spec or spec.index <= lastIndex then return nil, "invalid-policy-key" end
			local value = decode(spec, token)
			if value == nil then return nil, "invalid-policy-value" end
			values[#values + 1] = { spec = spec, value = value }
			lastIndex = spec.index
		end
	end
	if first then return nil, "invalid-header" end
	return values
end

-- A preview is usable only by this module, with this settings table, while
-- all touched values still match their pre-preview state. The private plan is
-- never taken from caller-editable preview fields.
local pending = setmetatable({}, { __mode = "k" })

function Transfer.Export(settings)
	if type(settings) ~= "table" then return nil, "settings-required" end
	local lines = { HEADER }
	for _, spec in ipairs(specifications) do
		local value = read(settings, spec)
		if value ~= nil then
			local token = encode(spec, value)
			if not token then return nil, "invalid-current-policy" end
			lines[#lines + 1] = spec[1] .. "=" .. token
		end
	end
	local text = table.concat(lines, "\n") .. "\n"
	if #text > MAX_BYTES then return nil, "invalid-size" end
	return text
end

function Transfer.Preview(settings, text)
	if type(settings) ~= "table" then return nil, "settings-required" end
	local values, err = parse(text)
	if not values then return nil, err end
	local preview = { changes = {}, count = 0 }
	local originals = {}
	for index, entry in ipairs(values) do
		local current = read(settings, entry.spec)
		originals[index] = { value = current }
		if current ~= entry.value then
			local old
			if valid(entry.spec, current) then old = current end
			preview.changes[#preview.changes + 1] = {
				key = entry.spec[1], old = old, new = entry.value,
				invalidCurrent = current ~= nil and old == nil,
			}
		end
	end
	preview.count = #preview.changes
	pending[preview] = { settings = settings, values = values, originals = originals }
	return preview
end

function Transfer.Apply(settings, preview, confirmation)
	if confirmation ~= "APPLY" then return false, "confirmation-required" end
	local plan = type(preview) == "table" and pending[preview]
	if not plan or plan.settings ~= settings then return false, "preview-required" end
	for index, entry in ipairs(plan.values) do
		if read(settings, entry.spec) ~= plan.originals[index].value then
			return false, "stale-preview"
		end
		local node = settings
		for partIndex = 1, #entry.spec.parts - 1 do
			if node == nil then break end
			node = node[entry.spec.parts[partIndex]]
			if node ~= nil and type(node) ~= "table" then
				return false, "invalid-current-policy"
			end
		end
	end
	local changed = 0
	for _, entry in ipairs(plan.values) do
		local node = settings
		for partIndex = 1, #entry.spec.parts - 1 do
			local part = entry.spec.parts[partIndex]
			if node[part] == nil then node[part] = {} end
			node = node[part]
		end
		local key = entry.spec.parts[#entry.spec.parts]
		if node[key] ~= entry.value then
			node[key] = entry.value
			changed = changed + 1
		end
	end
	pending[preview] = nil
	return true, changed
end
