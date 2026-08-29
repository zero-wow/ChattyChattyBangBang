-- Focused no-client contract for the dark-first theme gallery and its
-- compatibility rename. Run from the addon root with:
--   lua Tests/Themes.mock.lua

ChattyChattyBangBang = {
	db = {
		profile = {
			smartChat = {
				-- This is a real persisted pre-2.11 value. It must keep the same
				-- palette rather than resetting the player's preference.
				colorway = "Obsidian Arcana",
			},
		},
	},
}

dofile("Core/Settings.lua")
dofile("Core/Theme.lua")

local addon = ChattyChattyBangBang
local Theme = addon.Theme
local settings = addon:GetSmartSettings()

assert(settings.colorway == "Obsidian Dawn", "legacy Obsidian Arcana setting did not migrate")
assert(Theme:ResolveColorwayName("Obsidian Arcana") == "Obsidian Dawn", "legacy palette alias did not resolve")
assert(Theme:GetPalette() == Theme.Colorways["Obsidian Dawn"], "migrated palette did not remain active")
assert(Theme:GetColorwayInfo("Obsidian Arcana").description == Theme:GetColorwayInfo("Obsidian Dawn").description,
	"legacy palette description did not resolve")
assert(Theme.NO_BORDER == "none", "quiet frame registrations need a stable no-border token")

local names = Theme:GetColorwayNames()
assert(#names == 30, "theme gallery should contain thirty deliberate dark palettes")
assert(names[1] == "Obsidian Dawn", "Obsidian Dawn should remain the default first choice")
assert(names[2] == "Pure Obsidian", "restrained monochrome palette should follow the default")
assert(names[5] == "Abyssal Teal", "restrained teal palette should remain in the dark-first set")
assert(names[6] == "Obsidian Aurora", "cheerful graphite accent set should follow the restrained dark set")
assert(names[12] == "Arcane Constellation", "real arcane palette should follow the graphite accent set")

local requiredTokens = {
	"background", "surface", "surfaceRaised", "inset", "border", "borderMuted",
	"gold", "goldBright", "accent", "accentSoft", "text", "textMuted",
	"success", "warning", "danger",
}
local seen = {}
for _, name in ipairs(names) do
	assert(not seen[name], "theme order contains a duplicate: " .. tostring(name))
	seen[name] = true
	local palette = Theme.Colorways[name]
	assert(type(palette) == "table", "theme order references a missing palette: " .. tostring(name))
	assert(type(Theme:GetColorwayInfo(name)) == "table", "theme is missing its gallery description: " .. tostring(name))
	for _, token in ipairs(requiredTokens) do
		local color = palette[token]
		assert(type(color) == "table" and #color == 4, name .. " is missing " .. token)
		for channel = 1, 4 do
			assert(type(color[channel]) == "number" and color[channel] >= 0 and color[channel] <= 1,
				name .. " has an invalid " .. token .. " channel")
		end
	end
end

for _, name in ipairs({ "Pure Obsidian", "Blackglass", "Smoked Bronze", "Abyssal Teal" }) do
	local palette = Theme.Colorways[name]
	assert(palette.border[1] <= 0.15 and palette.border[2] <= 0.15 and palette.border[3] <= 0.16,
		name .. " border should remain low-chroma and subdued")
	assert(palette.borderMuted[1] <= palette.border[1] and palette.borderMuted[2] <= palette.border[2]
		and palette.borderMuted[3] <= palette.border[3], name .. " muted border should stay quieter than its border")
	assert(palette.accent[1] <= 0.30 and palette.accent[2] <= 0.30 and palette.accent[3] <= 0.31,
		name .. " accent should remain restrained rather than becoming universal neon chrome")
end

for _, name in ipairs({
	"Obsidian Aurora", "Obsidian Sunbeam", "Obsidian Coral",
	"Obsidian Skyline", "Obsidian Lilac", "Obsidian Citrus",
}) do
	local palette = Theme.Colorways[name]
	assert(math.abs(palette.background[1] - palette.background[2]) <= 0.004
		and math.abs(palette.background[2] - palette.background[3]) <= 0.004,
		name .. " background should remain neutral graphite")
	assert(math.abs(palette.surface[1] - palette.surface[2]) <= 0.004
		and math.abs(palette.surface[2] - palette.surface[3]) <= 0.007,
		name .. " surface should remain neutral graphite")
	assert(palette.border[1] <= 0.12 and palette.border[2] <= 0.12 and palette.border[3] <= 0.13,
		name .. " border should stay restrained rather than inheriting its accent")
	assert(palette.accent[1] >= 0.15 or palette.accent[2] >= 0.35 or palette.accent[3] >= 0.35,
		name .. " needs a visible cheerful accent")
end

assert(addon:SetColorway("Obsidian Arcana") == "Obsidian Dawn", "setting a legacy name should preserve the corrected palette")
assert(addon:SetColorway("Arcane Constellation") == "Arcane Constellation", "new arcane palette could not be selected")
assert(addon:SetColorway("not a real palette") == "Obsidian Dawn", "invalid palette did not safely fall back to the default")

print("Themes mock tests passed")
