local addon = ChattyChattyBangBang
local Theme = {}
addon.Theme = Theme

Theme.ICON_PATH = "Interface\\AddOns\\ChattyChattyBangBang\\Media\\ChattyChattyBangBang-Icon.tga"

Theme.Colorways = {
	["Obsidian Dawn"] = {
		background = { 0.025, 0.031, 0.047, 0.985 },
		surface = { 0.055, 0.071, 0.102, 0.98 },
		surfaceRaised = { 0.085, 0.112, 0.158, 0.99 },
		inset = { 0.018, 0.024, 0.037, 0.96 },
		border = { 0.62, 0.42, 0.16, 0.88 },
		borderMuted = { 0.17, 0.28, 0.42, 0.92 },
		gold = { 0.88, 0.61, 0.24, 1 },
		goldBright = { 1, 0.80, 0.39, 1 },
		accent = { 0.22, 0.48, 0.78, 1 },
		accentSoft = { 0.11, 0.24, 0.42, 1 },
		text = { 0.91, 0.91, 0.86, 1 },
		textMuted = { 0.56, 0.63, 0.71, 1 },
		success = { 0.30, 0.82, 0.57, 1 },
		warning = { 1, 0.66, 0.25, 1 },
		danger = { 0.90, 0.30, 0.28, 1 },
	},
	["Moonsteel"] = {
		background = { 0.025, 0.037, 0.064, 0.985 },
		surface = { 0.055, 0.082, 0.132, 0.98 },
		surfaceRaised = { 0.10, 0.14, 0.21, 0.99 },
		inset = { 0.018, 0.027, 0.047, 0.96 },
		border = { 0.38, 0.55, 0.72, 0.9 },
		borderMuted = { 0.15, 0.30, 0.49, 0.92 },
		gold = { 0.50, 0.72, 0.94, 1 },
		goldBright = { 0.80, 0.90, 1, 1 },
		accent = { 0.36, 0.64, 0.96, 1 },
		accentSoft = { 0.13, 0.30, 0.52, 1 },
		text = { 0.89, 0.93, 0.98, 1 },
		textMuted = { 0.55, 0.67, 0.79, 1 },
		success = { 0.30, 0.82, 0.67, 1 },
		warning = { 0.95, 0.75, 0.36, 1 },
		danger = { 0.94, 0.38, 0.40, 1 },
	},
	["Ember Ledger"] = {
		background = { 0.048, 0.024, 0.018, 0.985 },
		surface = { 0.10, 0.045, 0.030, 0.98 },
		surfaceRaised = { 0.16, 0.066, 0.037, 0.99 },
		inset = { 0.035, 0.016, 0.012, 0.96 },
		border = { 0.73, 0.30, 0.12, 0.9 },
		borderMuted = { 0.39, 0.12, 0.07, 0.92 },
		gold = { 0.94, 0.49, 0.18, 1 },
		goldBright = { 1, 0.75, 0.36, 1 },
		accent = { 0.83, 0.24, 0.12, 1 },
		accentSoft = { 0.38, 0.08, 0.04, 1 },
		text = { 0.97, 0.89, 0.82, 1 },
		textMuted = { 0.73, 0.55, 0.45, 1 },
		success = { 0.40, 0.83, 0.48, 1 },
		warning = { 1, 0.66, 0.22, 1 },
		danger = { 0.94, 0.29, 0.22, 1 },
	},
	["Verdant Reliquary"] = {
		background = { 0.017, 0.032, 0.026, 0.985 },
		surface = { 0.035, 0.067, 0.052, 0.98 },
		surfaceRaised = { 0.062, 0.105, 0.081, 0.99 },
		inset = { 0.011, 0.023, 0.018, 0.96 },
		border = { 0.55, 0.48, 0.23, 0.9 },
		borderMuted = { 0.10, 0.27, 0.20, 0.92 },
		gold = { 0.75, 0.70, 0.32, 1 },
		goldBright = { 0.94, 0.88, 0.51, 1 },
		accent = { 0.18, 0.62, 0.45, 1 },
		accentSoft = { 0.06, 0.28, 0.19, 1 },
		text = { 0.89, 0.94, 0.86, 1 },
		textMuted = { 0.48, 0.65, 0.56, 1 },
		success = { 0.30, 0.84, 0.52, 1 },
		warning = { 0.95, 0.70, 0.27, 1 },
		danger = { 0.88, 0.31, 0.29, 1 },
	},
	["Amethyst Veil"] = {
		background = { 0.027, 0.020, 0.043, 0.985 },
		surface = { 0.057, 0.040, 0.088, 0.98 },
		surfaceRaised = { 0.096, 0.066, 0.141, 0.99 },
		inset = { 0.018, 0.012, 0.029, 0.96 },
		border = { 0.53, 0.37, 0.72, 0.9 },
		borderMuted = { 0.23, 0.13, 0.38, 0.92 },
		gold = { 0.75, 0.58, 0.96, 1 },
		goldBright = { 0.91, 0.80, 1, 1 },
		accent = { 0.50, 0.34, 0.84, 1 },
		accentSoft = { 0.18, 0.10, 0.36, 1 },
		text = { 0.94, 0.90, 0.99, 1 },
		textMuted = { 0.63, 0.54, 0.75, 1 },
		success = { 0.38, 0.80, 0.62, 1 },
		warning = { 0.98, 0.69, 0.32, 1 },
		danger = { 0.93, 0.33, 0.44, 1 },
	},
	["Frostbound"] = {
		background = { 0.019, 0.028, 0.038, 0.985 },
		surface = { 0.039, 0.058, 0.076, 0.98 },
		surfaceRaised = { 0.070, 0.098, 0.123, 0.99 },
		inset = { 0.012, 0.019, 0.027, 0.96 },
		border = { 0.38, 0.62, 0.72, 0.9 },
		borderMuted = { 0.12, 0.27, 0.33, 0.92 },
		gold = { 0.57, 0.80, 0.85, 1 },
		goldBright = { 0.80, 0.95, 0.97, 1 },
		accent = { 0.27, 0.67, 0.77, 1 },
		accentSoft = { 0.07, 0.28, 0.34, 1 },
		text = { 0.89, 0.96, 0.97, 1 },
		textMuted = { 0.51, 0.68, 0.72, 1 },
		success = { 0.34, 0.84, 0.66, 1 },
		warning = { 0.98, 0.72, 0.33, 1 },
		danger = { 0.91, 0.35, 0.38, 1 },
	},
	["Sable Rose"] = {
		background = { 0.040, 0.022, 0.029, 0.985 },
		surface = { 0.080, 0.036, 0.052, 0.98 },
		surfaceRaised = { 0.125, 0.057, 0.077, 0.99 },
		inset = { 0.028, 0.013, 0.020, 0.96 },
		border = { 0.64, 0.38, 0.42, 0.9 },
		borderMuted = { 0.31, 0.12, 0.19, 0.92 },
		gold = { 0.88, 0.62, 0.50, 1 },
		goldBright = { 0.99, 0.81, 0.68, 1 },
		accent = { 0.70, 0.25, 0.39, 1 },
		accentSoft = { 0.31, 0.06, 0.15, 1 },
		text = { 0.97, 0.90, 0.90, 1 },
		textMuted = { 0.70, 0.53, 0.57, 1 },
		success = { 0.35, 0.80, 0.56, 1 },
		warning = { 0.99, 0.66, 0.28, 1 },
		danger = { 0.93, 0.28, 0.34, 1 },
	},
	["Gilded Ash"] = {
		background = { 0.031, 0.030, 0.027, 0.985 },
		surface = { 0.061, 0.058, 0.050, 0.98 },
		surfaceRaised = { 0.098, 0.091, 0.075, 0.99 },
		inset = { 0.021, 0.019, 0.016, 0.96 },
		border = { 0.61, 0.51, 0.29, 0.9 },
		borderMuted = { 0.25, 0.22, 0.16, 0.92 },
		gold = { 0.85, 0.71, 0.37, 1 },
		goldBright = { 1, 0.87, 0.53, 1 },
		accent = { 0.52, 0.45, 0.27, 1 },
		accentSoft = { 0.20, 0.17, 0.07, 1 },
		text = { 0.94, 0.92, 0.84, 1 },
		textMuted = { 0.65, 0.62, 0.52, 1 },
		success = { 0.39, 0.77, 0.50, 1 },
		warning = { 0.98, 0.69, 0.30, 1 },
		danger = { 0.89, 0.31, 0.27, 1 },
	},
}

-- The original gallery was deliberately restrained, but it accidentally
-- implied that Obsidian Dawn was an arcane palette.  It is not: it is the
-- blue-black and old-gold default.  Keep it as the dependable first choice,
-- then give the player a much wider dark-first set with genuinely different
-- atmospheres instead of a stack of nearly identical light skins.
Theme.Colorways["Arcane Constellation"] = {
	background = { 0.018, 0.011, 0.041, 0.985 },
	surface = { 0.045, 0.027, 0.090, 0.98 },
	surfaceRaised = { 0.086, 0.052, 0.156, 0.99 },
	inset = { 0.010, 0.006, 0.025, 0.96 },
	border = { 0.56, 0.30, 0.86, 0.90 },
	borderMuted = { 0.22, 0.09, 0.46, 0.92 },
	gold = { 0.74, 0.51, 0.98, 1 },
	goldBright = { 0.91, 0.78, 1.00, 1 },
	accent = { 0.37, 0.74, 1.00, 1 },
	accentSoft = { 0.10, 0.20, 0.48, 1 },
	text = { 0.95, 0.92, 1.00, 1 },
	textMuted = { 0.64, 0.57, 0.80, 1 },
	success = { 0.38, 0.83, 0.67, 1 },
	warning = { 0.98, 0.68, 0.35, 1 },
	danger = { 0.96, 0.29, 0.52, 1 },
}

Theme.Colorways["Voidfire"] = {
	background = { 0.025, 0.010, 0.025, 0.985 },
	surface = { 0.061, 0.020, 0.059, 0.98 },
	surfaceRaised = { 0.116, 0.040, 0.103, 0.99 },
	inset = { 0.016, 0.004, 0.017, 0.96 },
	border = { 0.74, 0.18, 0.55, 0.90 },
	borderMuted = { 0.34, 0.05, 0.24, 0.92 },
	gold = { 0.96, 0.39, 0.69, 1 },
	goldBright = { 1.00, 0.72, 0.88, 1 },
	accent = { 0.74, 0.14, 0.84, 1 },
	accentSoft = { 0.31, 0.035, 0.38, 1 },
	text = { 0.99, 0.91, 0.97, 1 },
	textMuted = { 0.74, 0.48, 0.66, 1 },
	success = { 0.34, 0.79, 0.60, 1 },
	warning = { 1.00, 0.58, 0.28, 1 },
	danger = { 1.00, 0.24, 0.39, 1 },
}

Theme.Colorways["Stormforged"] = {
	background = { 0.020, 0.027, 0.039, 0.985 },
	surface = { 0.046, 0.061, 0.086, 0.98 },
	surfaceRaised = { 0.081, 0.108, 0.147, 0.99 },
	inset = { 0.012, 0.017, 0.026, 0.96 },
	border = { 0.37, 0.58, 0.77, 0.90 },
	borderMuted = { 0.13, 0.28, 0.42, 0.92 },
	gold = { 0.56, 0.78, 0.98, 1 },
	goldBright = { 0.84, 0.93, 1.00, 1 },
	accent = { 0.25, 0.68, 1.00, 1 },
	accentSoft = { 0.06, 0.25, 0.47, 1 },
	text = { 0.91, 0.95, 1.00, 1 },
	textMuted = { 0.54, 0.66, 0.77, 1 },
	success = { 0.33, 0.84, 0.69, 1 },
	warning = { 0.99, 0.75, 0.34, 1 },
	danger = { 0.95, 0.35, 0.39, 1 },
}

Theme.Colorways["Deepwater"] = {
	background = { 0.008, 0.028, 0.036, 0.985 },
	surface = { 0.014, 0.061, 0.073, 0.98 },
	surfaceRaised = { 0.026, 0.105, 0.119, 0.99 },
	inset = { 0.004, 0.017, 0.022, 0.96 },
	border = { 0.19, 0.58, 0.62, 0.90 },
	borderMuted = { 0.035, 0.27, 0.30, 0.92 },
	gold = { 0.36, 0.82, 0.82, 1 },
	goldBright = { 0.66, 0.97, 0.94, 1 },
	accent = { 0.10, 0.70, 0.76, 1 },
	accentSoft = { 0.015, 0.31, 0.36, 1 },
	text = { 0.86, 0.97, 0.96, 1 },
	textMuted = { 0.42, 0.67, 0.69, 1 },
	success = { 0.23, 0.84, 0.61, 1 },
	warning = { 0.99, 0.73, 0.33, 1 },
	danger = { 0.93, 0.34, 0.37, 1 },
}

Theme.Colorways["Jade Eclipse"] = {
	background = { 0.010, 0.027, 0.022, 0.985 },
	surface = { 0.023, 0.058, 0.045, 0.98 },
	surfaceRaised = { 0.044, 0.097, 0.074, 0.99 },
	inset = { 0.006, 0.017, 0.013, 0.96 },
	border = { 0.30, 0.61, 0.43, 0.90 },
	borderMuted = { 0.07, 0.28, 0.19, 0.92 },
	gold = { 0.49, 0.83, 0.61, 1 },
	goldBright = { 0.76, 0.97, 0.78, 1 },
	accent = { 0.16, 0.72, 0.43, 1 },
	accentSoft = { 0.026, 0.30, 0.16, 1 },
	text = { 0.89, 0.97, 0.89, 1 },
	textMuted = { 0.48, 0.68, 0.53, 1 },
	success = { 0.27, 0.85, 0.54, 1 },
	warning = { 0.96, 0.76, 0.32, 1 },
	danger = { 0.91, 0.34, 0.34, 1 },
}

Theme.Colorways["Crimson Covenant"] = {
	background = { 0.031, 0.012, 0.015, 0.985 },
	surface = { 0.071, 0.022, 0.030, 0.98 },
	surfaceRaised = { 0.120, 0.041, 0.052, 0.99 },
	inset = { 0.020, 0.006, 0.009, 0.96 },
	border = { 0.72, 0.22, 0.28, 0.90 },
	borderMuted = { 0.34, 0.06, 0.10, 0.92 },
	gold = { 0.95, 0.45, 0.41, 1 },
	goldBright = { 1.00, 0.73, 0.65, 1 },
	accent = { 0.88, 0.17, 0.23, 1 },
	accentSoft = { 0.38, 0.035, 0.075, 1 },
	text = { 0.99, 0.91, 0.90, 1 },
	textMuted = { 0.72, 0.49, 0.49, 1 },
	success = { 0.32, 0.80, 0.52, 1 },
	warning = { 1.00, 0.66, 0.25, 1 },
	danger = { 1.00, 0.23, 0.28, 1 },
}

Theme.Colorways["Cinderwake"] = {
	background = { 0.030, 0.018, 0.012, 0.985 },
	surface = { 0.067, 0.035, 0.020, 0.98 },
	surfaceRaised = { 0.112, 0.057, 0.028, 0.99 },
	inset = { 0.018, 0.010, 0.005, 0.96 },
	border = { 0.67, 0.38, 0.14, 0.90 },
	borderMuted = { 0.31, 0.15, 0.05, 0.92 },
	gold = { 0.94, 0.60, 0.24, 1 },
	goldBright = { 1.00, 0.82, 0.48, 1 },
	accent = { 0.86, 0.31, 0.10, 1 },
	accentSoft = { 0.36, 0.09, 0.025, 1 },
	text = { 0.98, 0.91, 0.82, 1 },
	textMuted = { 0.72, 0.55, 0.42, 1 },
	success = { 0.39, 0.82, 0.49, 1 },
	warning = { 1.00, 0.70, 0.23, 1 },
	danger = { 0.98, 0.30, 0.20, 1 },
}

Theme.Colorways["Twilight Orchid"] = {
	background = { 0.028, 0.014, 0.040, 0.985 },
	surface = { 0.063, 0.028, 0.083, 0.98 },
	surfaceRaised = { 0.108, 0.049, 0.132, 0.99 },
	inset = { 0.018, 0.007, 0.027, 0.96 },
	border = { 0.71, 0.34, 0.76, 0.90 },
	borderMuted = { 0.34, 0.09, 0.38, 0.92 },
	gold = { 0.94, 0.55, 0.91, 1 },
	goldBright = { 1.00, 0.79, 0.98, 1 },
	accent = { 0.76, 0.25, 0.74, 1 },
	accentSoft = { 0.35, 0.045, 0.37, 1 },
	text = { 0.99, 0.91, 0.99, 1 },
	textMuted = { 0.72, 0.51, 0.72, 1 },
	success = { 0.35, 0.81, 0.60, 1 },
	warning = { 1.00, 0.70, 0.34, 1 },
	danger = { 0.96, 0.30, 0.48, 1 },
}

Theme.Colorways["Ebon Lantern"] = {
	background = { 0.021, 0.020, 0.016, 0.985 },
	surface = { 0.051, 0.046, 0.032, 0.98 },
	surfaceRaised = { 0.086, 0.075, 0.048, 0.99 },
	inset = { 0.012, 0.011, 0.007, 0.96 },
	border = { 0.69, 0.53, 0.19, 0.90 },
	borderMuted = { 0.29, 0.22, 0.07, 0.92 },
	gold = { 0.94, 0.74, 0.29, 1 },
	goldBright = { 1.00, 0.91, 0.57, 1 },
	accent = { 0.85, 0.58, 0.14, 1 },
	accentSoft = { 0.31, 0.20, 0.035, 1 },
	text = { 0.97, 0.93, 0.83, 1 },
	textMuted = { 0.67, 0.60, 0.44, 1 },
	success = { 0.40, 0.79, 0.48, 1 },
	warning = { 1.00, 0.74, 0.25, 1 },
	danger = { 0.92, 0.31, 0.25, 1 },
}

Theme.Colorways["Bloodmoon"] = {
	background = { 0.034, 0.011, 0.019, 0.985 },
	surface = { 0.077, 0.021, 0.041, 0.98 },
	surfaceRaised = { 0.128, 0.040, 0.066, 0.99 },
	inset = { 0.021, 0.005, 0.011, 0.96 },
	border = { 0.73, 0.24, 0.39, 0.90 },
	borderMuted = { 0.35, 0.055, 0.16, 0.92 },
	gold = { 0.96, 0.48, 0.57, 1 },
	goldBright = { 1.00, 0.73, 0.78, 1 },
	accent = { 0.85, 0.17, 0.36, 1 },
	accentSoft = { 0.38, 0.035, 0.14, 1 },
	text = { 1.00, 0.91, 0.93, 1 },
	textMuted = { 0.73, 0.48, 0.55, 1 },
	success = { 0.34, 0.80, 0.53, 1 },
	warning = { 1.00, 0.66, 0.30, 1 },
	danger = { 1.00, 0.22, 0.32, 1 },
}

Theme.Colorways["Astral Tide"] = {
	background = { 0.011, 0.016, 0.043, 0.985 },
	surface = { 0.025, 0.041, 0.089, 0.98 },
	surfaceRaised = { 0.046, 0.077, 0.148, 0.99 },
	inset = { 0.006, 0.009, 0.028, 0.96 },
	border = { 0.24, 0.50, 0.82, 0.90 },
	borderMuted = { 0.055, 0.17, 0.43, 0.92 },
	gold = { 0.42, 0.71, 1.00, 1 },
	goldBright = { 0.74, 0.88, 1.00, 1 },
	accent = { 0.22, 0.72, 0.93, 1 },
	accentSoft = { 0.035, 0.25, 0.49, 1 },
	text = { 0.88, 0.94, 1.00, 1 },
	textMuted = { 0.48, 0.62, 0.80, 1 },
	success = { 0.30, 0.83, 0.69, 1 },
	warning = { 0.97, 0.72, 0.33, 1 },
	danger = { 0.94, 0.32, 0.45, 1 },
}

Theme.Colorways["Blackthorn"] = {
	background = { 0.016, 0.023, 0.014, 0.985 },
	surface = { 0.034, 0.050, 0.027, 0.98 },
	surfaceRaised = { 0.057, 0.083, 0.042, 0.99 },
	inset = { 0.009, 0.013, 0.006, 0.96 },
	border = { 0.51, 0.54, 0.22, 0.90 },
	borderMuted = { 0.18, 0.25, 0.08, 0.92 },
	gold = { 0.76, 0.77, 0.33, 1 },
	goldBright = { 0.94, 0.94, 0.54, 1 },
	accent = { 0.37, 0.67, 0.20, 1 },
	accentSoft = { 0.12, 0.29, 0.055, 1 },
	text = { 0.91, 0.94, 0.84, 1 },
	textMuted = { 0.56, 0.64, 0.44, 1 },
	success = { 0.35, 0.83, 0.46, 1 },
	warning = { 0.97, 0.74, 0.27, 1 },
	danger = { 0.90, 0.32, 0.27, 1 },
}

-- These palettes deliberately keep their chrome quiet.  Their accent is for
-- selection and focus, while the normal one-pixel outline stays close to the
-- surrounding surface instead of turning every panel into a neon rectangle.
Theme.Colorways["Pure Obsidian"] = {
	background = { 0.003, 0.004, 0.005, 0.995 },
	surface = { 0.009, 0.010, 0.012, 0.99 },
	surfaceRaised = { 0.018, 0.019, 0.022, 0.99 },
	inset = { 0.001, 0.002, 0.003, 0.985 },
	border = { 0.065, 0.070, 0.080, 0.92 },
	borderMuted = { 0.038, 0.043, 0.050, 0.96 },
	gold = { 0.76, 0.75, 0.72, 1 },
	goldBright = { 0.90, 0.90, 0.88, 1 },
	accent = { 0.14, 0.15, 0.17, 1 },
	accentSoft = { 0.035, 0.040, 0.048, 1 },
	text = { 0.90, 0.90, 0.88, 1 },
	textMuted = { 0.48, 0.49, 0.51, 1 },
	success = { 0.34, 0.76, 0.57, 1 },
	warning = { 0.91, 0.65, 0.31, 1 },
	danger = { 0.88, 0.31, 0.33, 1 },
}

Theme.Colorways["Blackglass"] = {
	background = { 0.004, 0.005, 0.007, 0.995 },
	surface = { 0.010, 0.012, 0.016, 0.99 },
	surfaceRaised = { 0.019, 0.022, 0.028, 0.99 },
	inset = { 0.002, 0.003, 0.005, 0.985 },
	border = { 0.075, 0.085, 0.100, 0.92 },
	borderMuted = { 0.045, 0.052, 0.064, 0.96 },
	gold = { 0.68, 0.70, 0.73, 1 },
	goldBright = { 0.90, 0.90, 0.91, 1 },
	accent = { 0.20, 0.23, 0.28, 1 },
	accentSoft = { 0.040, 0.052, 0.070, 1 },
	text = { 0.90, 0.90, 0.91, 1 },
	textMuted = { 0.48, 0.50, 0.53, 1 },
	success = { 0.34, 0.76, 0.57, 1 },
	warning = { 0.91, 0.65, 0.31, 1 },
	danger = { 0.88, 0.31, 0.33, 1 },
}

Theme.Colorways["Smoked Bronze"] = {
	background = { 0.009, 0.007, 0.005, 0.995 },
	surface = { 0.020, 0.015, 0.010, 0.99 },
	surfaceRaised = { 0.034, 0.026, 0.017, 0.99 },
	inset = { 0.005, 0.004, 0.003, 0.985 },
	border = { 0.15, 0.105, 0.060, 0.92 },
	borderMuted = { 0.090, 0.065, 0.040, 0.96 },
	gold = { 0.78, 0.58, 0.32, 1 },
	goldBright = { 0.93, 0.75, 0.48, 1 },
	accent = { 0.28, 0.20, 0.11, 1 },
	accentSoft = { 0.075, 0.050, 0.024, 1 },
	text = { 0.93, 0.89, 0.82, 1 },
	textMuted = { 0.57, 0.50, 0.42, 1 },
	success = { 0.39, 0.77, 0.50, 1 },
	warning = { 0.92, 0.65, 0.28, 1 },
	danger = { 0.89, 0.30, 0.24, 1 },
}

Theme.Colorways["Abyssal Teal"] = {
	background = { 0.003, 0.010, 0.011, 0.995 },
	surface = { 0.009, 0.022, 0.024, 0.99 },
	surfaceRaised = { 0.016, 0.036, 0.039, 0.99 },
	inset = { 0.002, 0.006, 0.007, 0.985 },
	border = { 0.060, 0.15, 0.16, 0.92 },
	borderMuted = { 0.035, 0.095, 0.10, 0.96 },
	gold = { 0.47, 0.75, 0.73, 1 },
	goldBright = { 0.77, 0.91, 0.89, 1 },
	accent = { 0.10, 0.30, 0.31, 1 },
	accentSoft = { 0.015, 0.080, 0.085, 1 },
	text = { 0.86, 0.94, 0.93, 1 },
	textMuted = { 0.43, 0.59, 0.58, 1 },
	success = { 0.31, 0.78, 0.59, 1 },
	warning = { 0.88, 0.68, 0.32, 1 },
	danger = { 0.87, 0.31, 0.32, 1 },
}

-- Bright, cheerful accent families layered over the same restrained graphite
-- chassis.  The lively colors belong to selection, focus, and small accents;
-- routine panel borders remain quiet neutral greys.
Theme.Colorways["Obsidian Aurora"] = {
	background = { 0.008, 0.009, 0.011, 0.995 },
	surface = { 0.017, 0.019, 0.022, 0.99 },
	surfaceRaised = { 0.030, 0.033, 0.037, 0.99 },
	inset = { 0.004, 0.005, 0.006, 0.985 },
	border = { 0.105, 0.112, 0.120, 0.92 },
	borderMuted = { 0.060, 0.065, 0.071, 0.96 },
	gold = { 0.39, 0.93, 0.69, 1 },
	goldBright = { 0.70, 1.00, 0.84, 1 },
	accent = { 0.15, 0.86, 0.62, 1 },
	accentSoft = { 0.025, 0.20, 0.13, 1 },
	text = { 0.91, 0.94, 0.92, 1 },
	textMuted = { 0.51, 0.57, 0.54, 1 },
	success = { 0.32, 0.88, 0.56, 1 },
	warning = { 1.00, 0.76, 0.28, 1 },
	danger = { 0.96, 0.35, 0.42, 1 },
}

Theme.Colorways["Obsidian Sunbeam"] = {
	background = { 0.009, 0.010, 0.011, 0.995 },
	surface = { 0.019, 0.020, 0.023, 0.99 },
	surfaceRaised = { 0.033, 0.035, 0.039, 0.99 },
	inset = { 0.005, 0.005, 0.006, 0.985 },
	border = { 0.112, 0.115, 0.120, 0.92 },
	borderMuted = { 0.064, 0.067, 0.071, 0.96 },
	gold = { 1.00, 0.72, 0.20, 1 },
	goldBright = { 1.00, 0.91, 0.55, 1 },
	accent = { 0.97, 0.58, 0.08, 1 },
	accentSoft = { 0.22, 0.105, 0.015, 1 },
	text = { 0.96, 0.93, 0.86, 1 },
	textMuted = { 0.59, 0.57, 0.51, 1 },
	success = { 0.37, 0.84, 0.54, 1 },
	warning = { 1.00, 0.76, 0.22, 1 },
	danger = { 0.96, 0.34, 0.31, 1 },
}

Theme.Colorways["Obsidian Coral"] = {
	background = { 0.008, 0.009, 0.011, 0.995 },
	surface = { 0.018, 0.019, 0.023, 0.99 },
	surfaceRaised = { 0.032, 0.033, 0.039, 0.99 },
	inset = { 0.004, 0.005, 0.007, 0.985 },
	border = { 0.108, 0.112, 0.120, 0.92 },
	borderMuted = { 0.061, 0.065, 0.072, 0.96 },
	gold = { 1.00, 0.50, 0.45, 1 },
	goldBright = { 1.00, 0.76, 0.70, 1 },
	accent = { 0.96, 0.32, 0.31, 1 },
	accentSoft = { 0.22, 0.048, 0.045, 1 },
	text = { 0.96, 0.91, 0.90, 1 },
	textMuted = { 0.59, 0.54, 0.54, 1 },
	success = { 0.33, 0.84, 0.59, 1 },
	warning = { 1.00, 0.72, 0.24, 1 },
	danger = { 1.00, 0.28, 0.33, 1 },
}

Theme.Colorways["Obsidian Skyline"] = {
	background = { 0.007, 0.009, 0.012, 0.995 },
	surface = { 0.016, 0.019, 0.025, 0.99 },
	surfaceRaised = { 0.029, 0.034, 0.043, 0.99 },
	inset = { 0.003, 0.005, 0.008, 0.985 },
	border = { 0.098, 0.108, 0.120, 0.92 },
	borderMuted = { 0.054, 0.062, 0.072, 0.96 },
	gold = { 0.34, 0.74, 1.00, 1 },
	goldBright = { 0.68, 0.88, 1.00, 1 },
	accent = { 0.16, 0.58, 0.98, 1 },
	accentSoft = { 0.020, 0.11, 0.25, 1 },
	text = { 0.90, 0.94, 0.98, 1 },
	textMuted = { 0.50, 0.57, 0.64, 1 },
	success = { 0.30, 0.84, 0.64, 1 },
	warning = { 1.00, 0.75, 0.25, 1 },
	danger = { 0.95, 0.34, 0.41, 1 },
}

Theme.Colorways["Obsidian Lilac"] = {
	background = { 0.009, 0.009, 0.012, 0.995 },
	surface = { 0.020, 0.020, 0.026, 0.99 },
	surfaceRaised = { 0.035, 0.034, 0.045, 0.99 },
	inset = { 0.005, 0.005, 0.008, 0.985 },
	border = { 0.112, 0.110, 0.123, 0.92 },
	borderMuted = { 0.066, 0.064, 0.075, 0.96 },
	gold = { 0.78, 0.54, 1.00, 1 },
	goldBright = { 0.92, 0.79, 1.00, 1 },
	accent = { 0.64, 0.35, 0.96, 1 },
	accentSoft = { 0.115, 0.045, 0.22, 1 },
	text = { 0.94, 0.91, 0.98, 1 },
	textMuted = { 0.57, 0.53, 0.64, 1 },
	success = { 0.35, 0.82, 0.62, 1 },
	warning = { 1.00, 0.73, 0.30, 1 },
	danger = { 0.96, 0.33, 0.50, 1 },
}

Theme.Colorways["Obsidian Citrus"] = {
	background = { 0.008, 0.010, 0.011, 0.995 },
	surface = { 0.018, 0.021, 0.023, 0.99 },
	surfaceRaised = { 0.032, 0.037, 0.040, 0.99 },
	inset = { 0.004, 0.006, 0.007, 0.985 },
	border = { 0.105, 0.114, 0.113, 0.92 },
	borderMuted = { 0.061, 0.067, 0.067, 0.96 },
	gold = { 0.85, 1.00, 0.25, 1 },
	goldBright = { 0.94, 1.00, 0.62, 1 },
	accent = { 0.43, 0.90, 0.50, 1 },
	accentSoft = { 0.055, 0.19, 0.075, 1 },
	text = { 0.92, 0.96, 0.89, 1 },
	textMuted = { 0.54, 0.60, 0.53, 1 },
	success = { 0.38, 0.87, 0.50, 1 },
	warning = { 1.00, 0.78, 0.22, 1 },
	danger = { 0.96, 0.34, 0.35, 1 },
}

Theme.ColorwayAliases = {
	-- Renaming this is a presentation correction, not a preference reset.
	-- Existing SavedVariables and third-party snippets continue to resolve it.
	["Obsidian Arcana"] = "Obsidian Dawn",
}

-- ColorWays is the preferred public spelling.  Keep Colorways as an alias so
-- existing settings UI and third-party snippets do not lose compatibility.
Theme.ColorWays = Theme.Colorways

-- Keep presentation order deliberate rather than relying on Lua's unordered
-- table traversal.  The configuration view can build a compact gallery from
-- this list without hard-coding palette names.
Theme.ColorwayOrder = {
	"Obsidian Dawn",
	"Pure Obsidian",
	"Blackglass",
	"Smoked Bronze",
	"Abyssal Teal",
	"Obsidian Aurora",
	"Obsidian Sunbeam",
	"Obsidian Coral",
	"Obsidian Skyline",
	"Obsidian Lilac",
	"Obsidian Citrus",
	"Arcane Constellation",
	"Moonsteel",
	"Stormforged",
	"Deepwater",
	"Astral Tide",
	"Frostbound",
	"Ember Ledger",
	"Cinderwake",
	"Ebon Lantern",
	"Crimson Covenant",
	"Bloodmoon",
	"Verdant Reliquary",
	"Jade Eclipse",
	"Blackthorn",
	"Amethyst Veil",
	"Twilight Orchid",
	"Sable Rose",
	"Gilded Ash",
	"Voidfire",
}

Theme.ColorwayInfo = {
	["Obsidian Dawn"] = {
		description = "Blue-black stone and restrained old gold.",
	},
	["Pure Obsidian"] = {
		description = "Monochrome black with nearly invisible graphite chrome.",
	},
	["Blackglass"] = {
		description = "Cool neutral charcoal with restrained steel-grey focus.",
	},
	["Smoked Bronze"] = {
		description = "Near-black bronze with a quiet, warm selection edge.",
	},
	["Abyssal Teal"] = {
		description = "Near-black teal with submerged, low-key contrast.",
	},
	["Obsidian Aurora"] = {
		description = "Quiet graphite with a fresh aurora-mint edge.",
	},
	["Obsidian Sunbeam"] = {
		description = "Quiet graphite with warm sunlit amber focus.",
	},
	["Obsidian Coral"] = {
		description = "Quiet graphite with a playful coral-pink edge.",
	},
	["Obsidian Skyline"] = {
		description = "Quiet graphite with clear electric-sky blue focus.",
	},
	["Obsidian Lilac"] = {
		description = "Quiet graphite with soft spring-lilac light.",
	},
	["Obsidian Citrus"] = {
		description = "Quiet graphite with lively citrus and teal highlights.",
	},
	["Arcane Constellation"] = {
		description = "Deep violet, star-cyan, and real spellglow.",
	},
	["Moonsteel"] = {
		description = "Cool lunar navy with polished steel-blue light.",
	},
	["Stormforged"] = {
		description = "Gunmetal blue with an electric storm edge.",
	},
	["Deepwater"] = {
		description = "Abyssal teal with cold underwater light.",
	},
	["Astral Tide"] = {
		description = "Midnight indigo swept with starlit cyan.",
	},
	["Ember Ledger"] = {
		description = "Dark cinder red with a measured molten glow.",
	},
	["Cinderwake"] = {
		description = "Coal black, copper, and a bright ember line.",
	},
	["Ebon Lantern"] = {
		description = "Near-black iron warmed by lantern gold.",
	},
	["Crimson Covenant"] = {
		description = "Deep blackened red with a decisive crimson edge.",
	},
	["Bloodmoon"] = {
		description = "Wine-dark shadows and a sharp moonlit rose.",
	},
	["Verdant Reliquary"] = {
		description = "Deep forest green, oxidized brass, and quiet jade.",
	},
	["Jade Eclipse"] = {
		description = "Charcoal jade with a living emerald highlight.",
	},
	["Blackthorn"] = {
		description = "Deep moss and brass beneath thorn-black shade.",
	},
	["Amethyst Veil"] = {
		description = "Ink-black violet with an understated amethyst edge.",
	},
	["Twilight Orchid"] = {
		description = "Smoky orchid and magenta with a velvet glow.",
	},
	["Frostbound"] = {
		description = "Charcoal blue with icy silver highlights.",
	},
	["Sable Rose"] = {
		description = "Smoky charcoal, oxblood, and muted rose-gold.",
	},
	["Gilded Ash"] = {
		description = "Neutral blackstone with burnished antique gold.",
	},
	["Voidfire"] = {
		description = "Black plum, violet flame, and hot magenta light.",
	},
}

function Theme:ResolveColorwayName(name)
	name = self.ColorwayAliases[name] or name
	if self.Colorways[name] then
		return name
	end
	return "Obsidian Dawn"
end

function Theme:GetColorwayNames()
	local names = {}
	for index = 1, #self.ColorwayOrder do
		names[index] = self.ColorwayOrder[index]
	end
	return names
end

function Theme:GetColorwayInfo(name)
	return self.ColorwayInfo[self:ResolveColorwayName(name)]
end

local backdrop = {
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Buttons\\WHITE8x8",
	tile = false,
	edgeSize = 1,
	insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- A frame without an edge is still a real surface: it simply lets spacing,
-- type, and a focused control carry the hierarchy.  The settings window uses
-- this for ordinary controls so an entire page does not turn into a wall of
-- equally loud rectangles.  Keep this as a named border value rather than a
-- special nil so registrations survive a palette refresh.
local flatBackdrop = {
	bgFile = "Interface\\Buttons\\WHITE8x8",
	tile = false,
}
Theme.NO_BORDER = "none"

Theme.frames = {}
Theme.texts = {}
Theme.textures = {}
Theme.callbacks = {}
Theme.tightButtons = {}
Theme.scrollBars = {}

local SCROLLBAR_TEXTURE = [[Interface\Buttons\WHITE8x8]]

-- Button labels need a little more room than their reported glyph width.
-- Older clients can round scaled font metrics differently while painting, and
-- an outline or shadow may reach past the value returned by GetStringWidth().
-- Keep the FontString four pixels away from each edge and give auto-sized
-- controls one additional pixel of slack per side.
Theme.BUTTON_TEXT_INSET = 4
Theme.TIGHT_BUTTON_PADDING = 10
Theme.TEXT_MEASURE_WIDTH = 4096

-- Chatty's settings window is a working console, not a roomy character-sheet.
-- Keep the small controls intentionally dense and use the actual workspace,
-- selected rows, and editable fields for hierarchy instead of extra chrome.
Theme.Metrics = {
	buttonHeight = 22,
	tightButtonHeight = 20,
	compactToggleHeight = 20,
	editBoxHeight = 22,
}

function Theme:GetPalette()
	local settings = addon.GetSmartSettings and addon:GetSmartSettings()
	local name = self:ResolveColorwayName(settings and settings.colorway or nil)
	return self.Colorways[name]
end

function Theme:GetColor(name)
	local color = self:GetPalette()[name] or self:GetPalette().text
	return color[1], color[2], color[3], color[4]
end

function Theme:ApplyFrame(frame, fillName, borderName)
	if not frame then
		return
	end

	local palette = self:GetPalette()
	local fill = palette[fillName or "surface"] or palette.surface
	local wantsBorder = borderName ~= self.NO_BORDER and borderName ~= "transparent"
	local border = palette[borderName or "borderMuted"] or palette.borderMuted
	local registered = self.frames[frame]
	local fillAlpha = registered and tonumber(registered.fillAlpha) or 1
	local borderAlpha = registered and tonumber(registered.borderAlpha) or 1
	fillAlpha = math.max(0, math.min(1, fillAlpha))
	borderAlpha = math.max(0, math.min(1, borderAlpha))
	frame:SetBackdrop(wantsBorder and backdrop or flatBackdrop)
	frame:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] * fillAlpha)
	if wantsBorder then
		frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] * borderAlpha)
	else
		frame:SetBackdropBorderColor(0, 0, 0, 0)
	end
end

function Theme:RegisterFrame(frame, fillName, borderName)
	local previous = self.frames[frame]
	self.frames[frame] = {
		fill = fillName,
		border = borderName,
		fillAlpha = previous and previous.fillAlpha or 1,
		borderAlpha = previous and previous.borderAlpha or 1,
	}
	self:ApplyFrame(frame, fillName, borderName)
	return frame
end

-- Per-frame opacity multipliers let SmartDock fade its chrome without fading
-- message text. They are retained in the theme registry, so changing Colorways
-- or hovering a themed control cannot accidentally restore opaque surfaces.
function Theme:SetFrameOpacity(frame, fillAlpha, borderAlpha)
	if not frame then return end
	local style = self.frames[frame]
	if not style then
		style = { fill = "surface", border = "borderMuted" }
		self.frames[frame] = style
	end
	style.fillAlpha = math.max(0, math.min(1, tonumber(fillAlpha) or 1))
	style.borderAlpha = math.max(0, math.min(1, tonumber(borderAlpha) or 1))
	self:ApplyFrame(frame, style.fill, style.border)
end

function Theme:RegisterText(fontString, colorName)
	self.texts[fontString] = colorName or "text"
	local r, g, b, a = self:GetColor(colorName or "text")
	fontString:SetTextColor(r, g, b, a)
	return fontString
end

function Theme:RegisterTexture(texture, colorName)
	self.textures[texture] = colorName or "text"
	local r, g, b, a = self:GetColor(colorName or "text")
	texture:SetVertexColor(r, g, b, a)
	return texture
end

function Theme:RegisterRefreshCallback(callback)
	table.insert(self.callbacks, callback)
end

local function hideScrollBarRegion(region)
	if not region then return end
	if region.Hide then region:Hide() end
	if region.SetAlpha then region:SetAlpha(0) end
	if region.EnableMouse then region:EnableMouse(false) end
end

local function resolveNamedScrollBarRegion(scrollBar, suffix)
	if not scrollBar or not scrollBar.GetName then return nil end
	local name = scrollBar:GetName()
	return name and _G[name .. suffix] or nil
end

-- Scrollbars are deliberately quieter than ordinary controls.  The eight-pixel
-- interaction lane has no painted rail or arrow caps; only a six-pixel thumb is
-- visible, using the current Colorway's accent and gold hover colors.
function Theme:ApplyScrollBar(scrollBar)
	local style = scrollBar and self.scrollBars[scrollBar]
	if not style then return end

	if scrollBar.SetWidth then scrollBar:SetWidth(style.width or 8) end
	if scrollBar.SetOrientation then scrollBar:SetOrientation(style.orientation or "VERTICAL") end

	local thumb = style.thumb
		or (scrollBar.GetThumbTexture and scrollBar:GetThumbTexture())
		or resolveNamedScrollBarRegion(scrollBar, "ThumbTexture")
	style.thumb = thumb
	if thumb then
		if thumb.SetTexture then thumb:SetTexture(SCROLLBAR_TEXTURE) end
		if thumb.SetWidth then thumb:SetWidth(style.thumbWidth or 6) end
		if thumb.SetHeight then thumb:SetHeight(style.thumbHeight or 28) end
		local colorName = style.hovered and "goldBright" or "accent"
		local r, g, b, a = self:GetColor(colorName)
		if thumb.SetVertexColor then thumb:SetVertexColor(r, g, b, a) end
		if style.thumbVisible == false then
			hideScrollBarRegion(thumb)
		else
			if thumb.SetAlpha then thumb:SetAlpha(a or 1) end
			if thumb.Show then thumb:Show() end
		end
	end

	-- Wrath's UIPanelScrollFrameTemplate paints several separate rail pieces.
	-- Hide every known piece idempotently; callers retain all native scrolling,
	-- range, and value behavior.
	local hidden = style.hiddenRegions or {}
	for index = 1, #hidden do hideScrollBarRegion(hidden[index]) end
	for _, suffix in ipairs({
		"ScrollUpButton", "ScrollDownButton", "Background",
		"Top", "Middle", "Bottom",
	}) do
		hideScrollBarRegion(resolveNamedScrollBarRegion(scrollBar, suffix))
	end
end

function Theme:SetScrollBarThumbVisible(scrollBar, visible)
	local style = scrollBar and self.scrollBars[scrollBar]
	if not style then return end
	style.thumbVisible = visible and true or false
	self:ApplyScrollBar(scrollBar)
end

function Theme:SetScrollBarThumbSize(scrollBar, width, height)
	local style = scrollBar and self.scrollBars[scrollBar]
	if not style then return end
	style.thumbWidth = math.max(2, tonumber(width) or style.thumbWidth or 6)
	style.thumbHeight = math.max(8, tonumber(height) or style.thumbHeight or 28)
	self:ApplyScrollBar(scrollBar)
end

function Theme:SkinScrollBar(scrollBar, options)
	if not scrollBar then return nil end
	options = options or {}
	local style = self.scrollBars[scrollBar] or {}
	style.width = tonumber(options.width) or style.width or 8
	style.thumbWidth = tonumber(options.thumbWidth) or style.thumbWidth or 6
	style.thumbHeight = tonumber(options.thumbHeight) or style.thumbHeight or 28
	style.orientation = options.orientation or style.orientation or "VERTICAL"
	style.thumbVisible = options.thumbVisible ~= false
	style.hiddenRegions = style.hiddenRegions or {}
	for _, region in ipairs(options.hiddenRegions or {}) do
		table.insert(style.hiddenRegions, region)
	end

	if not style.thumb and scrollBar.SetThumbTexture then
		scrollBar:SetThumbTexture(SCROLLBAR_TEXTURE)
		style.thumb = scrollBar.GetThumbTexture and scrollBar:GetThumbTexture() or nil
	end
	style.thumb = style.thumb or options.thumb
	self.scrollBars[scrollBar] = style

	if not scrollBar._themeScrollBarBound and scrollBar.HookScript then
		scrollBar._themeScrollBarBound = true
		scrollBar:HookScript("OnEnter", function(self)
			local current = Theme.scrollBars[self]
			if current then current.hovered = true end
			Theme:ApplyScrollBar(self)
		end)
		scrollBar:HookScript("OnLeave", function(self)
			local current = Theme.scrollBars[self]
			if current then current.hovered = false end
			Theme:ApplyScrollBar(self)
		end)
		scrollBar:HookScript("OnMouseDown", function(self)
			local current = Theme.scrollBars[self]
			if current then current.hovered = true end
			Theme:ApplyScrollBar(self)
		end)
		scrollBar:HookScript("OnMouseUp", function(self)
			local current = Theme.scrollBars[self]
			if current then current.hovered = self.IsMouseOver and self:IsMouseOver() or false end
			Theme:ApplyScrollBar(self)
		end)
	end

	self:ApplyScrollBar(scrollBar)
	return scrollBar
end

function Theme:CreateSlimScrollbar(parent)
	local scrollBar = CreateFrame("Slider", nil, parent)
	scrollBar:SetOrientation("VERTICAL")
	scrollBar:SetWidth(8)
	scrollBar:SetMinMaxValues(0, 0)
	scrollBar:SetValueStep(1)
	self:SkinScrollBar(scrollBar, {
		width = 8,
		thumbWidth = 6,
		thumbHeight = 28,
		orientation = "VERTICAL",
	})
	return scrollBar
end

function Theme:SkinScrollFrame(scrollFrame, options)
	if not scrollFrame then return nil end
	options = options or {}
	local scrollBar = options.scrollBar
	if not scrollBar and scrollFrame.GetName then
		local name = scrollFrame:GetName()
		scrollBar = name and _G[name .. "ScrollBar"] or nil
	end
	return self:SkinScrollBar(scrollBar, options)
end

function Theme:Refresh()
	for frame, style in pairs(self.frames) do
		if frame then
			self:ApplyFrame(frame, style.fill, style.border)
		end
	end

	for fontString, colorName in pairs(self.texts) do
		if fontString then
			local r, g, b, a = self:GetColor(colorName)
			fontString:SetTextColor(r, g, b, a)
		end
	end


	for texture, colorName in pairs(self.textures) do
		if texture then
			local r, g, b, a = self:GetColor(colorName)
			texture:SetVertexColor(r, g, b, a)
		end
	end

	for scrollBar in pairs(self.scrollBars) do
		if scrollBar then self:ApplyScrollBar(scrollBar) end
	end

	-- Font objects may be replaced by another addon after Chatty constructed
	-- its settings frame. Re-measure text-sized controls whenever the theme is
	-- refreshed so their geometry follows the font that is actually rendered.
	for button in pairs(self.tightButtons) do
		if button and button.RefreshTextFit then
			button:RefreshTextFit()
		end
	end

	for _, callback in ipairs(self.callbacks) do
		callback()
	end
end

function Theme:CreatePanel(parent, fillName, borderName)
	local frame = CreateFrame("Frame", nil, parent)
	self:RegisterFrame(frame, fillName or "surface", borderName or "borderMuted")
	return frame
end

-- A convenience for builders that want grouping through a subtle surface
-- change instead of another outlined card.
function Theme:CreateQuietPanel(parent, fillName)
	return self:CreatePanel(parent, fillName or "surface", self.NO_BORDER)
end

function Theme:CreateText(parent, fontObject, colorName)
	local text = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontNormal")
	self:RegisterText(text, colorName or "text")
	return text
end

function Theme:CreateButton(parent, text, width, height, emphasis)
	local button = CreateFrame("Button", nil, parent)
	button:SetWidth(width or 120)
	button:SetHeight(height or self.Metrics.buttonHeight)
	button.text = self:CreateText(button, "GameFontNormalSmall", emphasis and "goldBright" or "text")
	button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	button._themeFullLabel = tostring(text or "Button")
	button.text:SetText(button._themeFullLabel)
	button.text:SetJustifyH("CENTER")
	-- A button is a single-line control. On clients that expose only the older
	-- wrapping API, SetNonSpaceWrap(false) still prevents a long unbroken label
	-- from splitting; SetWordWrap(false) also keeps labels containing spaces on
	-- one line when that API is available.
	if button.text.SetWordWrap then
		pcall(button.text.SetWordWrap, button.text, false)
	end
	if button.text.SetNonSpaceWrap then
		pcall(button.text.SetNonSpaceWrap, button.text, false)
	end
	-- Ordinary actions stay visually quiet until the user reaches for them.
	-- A primary/destructive caller still opts into a strong state through the
	-- existing emphasis argument or SetTheme(), so this does not hide intent.
	button._themeFill = emphasis and "accentSoft" or "surface"
	button._themeBorder = emphasis and "gold" or self.NO_BORDER
	button._themeText = emphasis and "goldBright" or "text"
	button._themeHoverFill = "surfaceRaised"
	button._themeHoverBorder = emphasis and "goldBright" or "accent"
	button._themeHoverText = emphasis and "goldBright" or "gold"
	button._themePressedFill = emphasis and "accentSoft" or "accentSoft"
	button._themePressedBorder = emphasis and "goldBright" or "accent"
	button._themePressedText = emphasis and "goldBright" or "goldBright"
	self:RegisterFrame(button, button._themeFill, button._themeBorder)

	local function measureIntrinsicText(self)
		local label = tostring(self._themeFullLabel or "")
		if label == "" then
			return 0
		end

		-- GetStringWidth() is client-dependent when the FontString already has a
		-- narrow width: some 3.3.5 builds report the clipped region rather than
		-- the unbounded glyph run. Temporarily open the region, measure using the
		-- exact live FontString/font object, then restore its previous constraint.
		local previousWidth = self.text.GetWidth and self.text:GetWidth() or nil
		self.text:SetWidth(Theme.TEXT_MEASURE_WIDTH)
		local ok, measured = pcall(self.text.GetStringWidth, self.text)
		if previousWidth then
			self.text:SetWidth(previousWidth)
		end
		measured = ok and tonumber(measured) or nil
		if measured and measured > 0 then
			return measured
		end

		-- This deliberately overestimates non-ASCII byte strings. A little extra
		-- space is safer than letting an unusual localized label touch a border.
		local fontSize = 10
		if self.text.GetFont then
			local _, size = self.text:GetFont()
			fontSize = tonumber(size) or fontSize
		end
		return string.len(label) * fontSize * 0.65
	end

	local function fitText(self)
		-- Fixed-width controls must reserve breathing room for their label.  A
		-- constrained FontString also prevents one long localized label from
		-- painting into its neighbour when a config page is dense.
		local available = math.max(1, self:GetWidth() - (Theme.BUTTON_TEXT_INSET * 2))
		self.text:SetWidth(available)
		if self.text.SetHeight and self.GetHeight then
			self.text:SetHeight(math.max(1, self:GetHeight() - 2))
		end
		self._themeTextAvailableWidth = available
		self._themeIntrinsicTextWidth = measureIntrinsicText(self)
		self._themeLabelClipped = self._themeIntrinsicTextWidth > (available + 0.25)
	end
	fitText(button)
	button:SetScript("OnSizeChanged", function(self)
		-- A caller that changes a Tight button's width after construction owns a
		-- deliberate cap (several dense inspectors rely on this). Do not undo it
		-- on the next Show/Refresh; continue constraining the label safely.
		if self._themeTightAutoFit and not self._themeApplyingTextFit and self._themeLastAutoFitWidth then
			local currentWidth = tonumber(self:GetWidth()) or 0
			if math.abs(currentWidth - self._themeLastAutoFitWidth) > 0.01 then
				self._themeTightAutoFit = false
				self._themeExplicitWidth = true
			end
		end
		fitText(self)
	end)

	function button:SetTextAutoFit(enabled)
		self._themeTightAutoFit = enabled and true or false
		self._themeExplicitWidth = not self._themeTightAutoFit
		if self._themeTightAutoFit and self.RefreshTextFit then
			self:RefreshTextFit()
		else
			fitText(self)
		end
	end

	function button:RefreshTextFit()
		local measured = measureIntrinsicText(self)
		self._themeIntrinsicTextWidth = measured
		if self._themeTightAutoFit then
			local minimum = tonumber(self._themeTightMinimumWidth) or tonumber(self:GetHeight()) or 1
			local desired = math.max(minimum, math.ceil(measured) + Theme.TIGHT_BUTTON_PADDING)
			self._themeApplyingTextFit = true
			self:SetWidth(desired)
			self._themeApplyingTextFit = false
			self._themeLastAutoFitWidth = desired
		end
		fitText(self)
	end

	function button:SetTheme(fillName, borderName, textName)
		self._themeFill = fillName or self._themeFill
		self._themeBorder = borderName or self._themeBorder
		self._themeText = textName or self._themeText
		if Theme.frames[self] then
			Theme.frames[self].fill = self._themeFill
			Theme.frames[self].border = self._themeBorder
		end
		Theme:ApplyFrame(self, self._themeFill, self._themeBorder)
		local r, g, b, a = Theme:GetColor(self._themeText)
		self.text:SetTextColor(r, g, b, a)
	end

	-- Use this when a row needs a different hover treatment than a normal
	-- action.  It keeps interaction feedback direct without baking accent
	-- borders into every resting control.
	function button:SetHoverTheme(fillName, borderName, textName)
		self._themeHoverFill = fillName or self._themeHoverFill
		self._themeHoverBorder = borderName or self._themeHoverBorder
		self._themeHoverText = textName or self._themeHoverText
	end

	-- Config builders can attach concise, local help without each one having
	-- to duplicate GameTooltip plumbing.  Title-only tooltips are intentionally
	-- supported for compact icon controls.
	function button:SetTooltip(title, body)
		self._themeTooltipTitle = title
		self._themeTooltipBody = body
	end

	local function showTooltip(self)
		if not GameTooltip then
			return
		end
		local title = self._themeTooltipTitle
		local body = self._themeTooltipBody
		if (not title or title == "") and self._themeLabelClipped then
			title = self._themeFullLabel
		end
		if not title or title == "" then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 1, 1, true)
		if body and body ~= "" then
			GameTooltip:AddLine(body, 0.72, 0.76, 0.84, true)
		end
		if self._themeLabelClipped and self._themeFullLabel ~= "" and title ~= self._themeFullLabel then
			GameTooltip:AddLine("Label: " .. self._themeFullLabel, 0.82, 0.84, 0.90, true)
		end
		GameTooltip:Show()
	end

	local function restoreVisual(self)
		local hovering = self._themeHovered
		Theme:ApplyFrame(self,
			hovering and self._themeHoverFill or self._themeFill,
			hovering and self._themeHoverBorder or self._themeBorder)
		local r, g, b, a = Theme:GetColor(hovering and self._themeHoverText or self._themeText)
		self.text:SetTextColor(r, g, b, a)
	end

	button:SetScript("OnEnter", function(self)
		self._themeHovered = true
		restoreVisual(self)
		showTooltip(self)
	end)
	button:SetScript("OnLeave", function(self)
		self._themeHovered = false
		restoreVisual(self)
		if GameTooltip and (not GameTooltip.GetOwner or GameTooltip:GetOwner() == self) then
			GameTooltip:Hide()
		end
	end)
	button:SetScript("OnMouseDown", function(self)
		Theme:ApplyFrame(self, self._themePressedFill, self._themePressedBorder)
		local r, g, b, a = Theme:GetColor(self._themePressedText)
		self.text:SetTextColor(r, g, b, a)
	end)
	button:SetScript("OnMouseUp", function(self)
		restoreVisual(self)
	end)

	function button:SetLabel(label)
		self._themeFullLabel = tostring(label or "")
		self.text:SetText(self._themeFullLabel)
		if self._themeTightAutoFit then
			self:RefreshTextFit()
		else
			fitText(self)
		end
	end

	return button
end

-- Keep a selected row obvious without putting a bright outline around every
-- sibling.  The two-pixel leading edge is intentionally shared with the
-- selected border color; it is a quick visual anchor in long option lists.
function Theme:SetQuietRowState(button, selected)
	if not button or not button.SetTheme then
		return
	end

	if not button._themeSelectionEdge then
		local edge = button:CreateTexture(nil, "OVERLAY")
		edge:SetTexture("Interface\\Buttons\\WHITE8x8")
		edge:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -1)
		edge:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 1)
		edge:SetWidth(2)
		self:RegisterTexture(edge, "gold")
		button._themeSelectionEdge = edge
	end

	if selected then
		button:SetTheme("accentSoft", "gold", "goldBright")
		button:SetHoverTheme("accentSoft", "goldBright", "goldBright")
		button._themeSelectionEdge:Show()
	else
		button:SetTheme("surface", self.NO_BORDER, "text")
		button:SetHoverTheme("surfaceRaised", "accent", "gold")
		button._themeSelectionEdge:Hide()
	end
end

-- Builders use roles instead of open-coding a mix of fills and borders.  It
-- makes intent reviewable: ordinary controls are quiet, list choices gain a
-- selected edge, and only primary or destructive actions start highlighted.
function Theme:SetButtonRole(button, role, selected)
	if not button or not button.SetTheme then
		return
	end

	role = role or "quiet"
	if role == "row" or role == "choice" then
		self:SetQuietRowState(button, selected and true or false)
	elseif role == "primary" then
		button:SetTheme("accentSoft", "gold", "goldBright")
		button:SetHoverTheme("accentSoft", "goldBright", "goldBright")
	elseif role == "danger" then
		button:SetTheme("surface", "danger", "danger")
		button:SetHoverTheme("surfaceRaised", "danger", "text")
	else
		button:SetTheme("surface", self.NO_BORDER, "text")
		button:SetHoverTheme("surfaceRaised", "accent", "gold")
	end
end

-- Page and inspector selectors are navigation, not ordinary actions. Give
-- them a shared baseline and let the selected item visually join the content
-- below instead of drawing another boxed button. The underline is deliberately
-- restrained: color supports the label, but never becomes the whole control.
function Theme:SetTabState(button, selected)
	if not button or not button.SetTheme then
		return
	end

	if not button._themeTabTrack then
		local track = button:CreateTexture(nil, "ARTWORK")
		track:SetTexture("Interface\\Buttons\\WHITE8x8")
		track:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
		track:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
		track:SetHeight(1)
		self:RegisterTexture(track, "borderMuted")
		button._themeTabTrack = track

		local underline = button:CreateTexture(nil, "OVERLAY")
		underline:SetTexture("Interface\\Buttons\\WHITE8x8")
		underline:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
		underline:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
		underline:SetHeight(2)
		self:RegisterTexture(underline, "gold")
		button._themeTabUnderline = underline

		if button.HookScript then
			button:HookScript("OnEnter", function(self)
				if not self._themeTabSelected and self._themeTabUnderline then
					Theme.textures[self._themeTabUnderline] = "accent"
					local r, g, b, a = Theme:GetColor("accent")
					self._themeTabUnderline:SetVertexColor(r, g, b, a)
					self._themeTabUnderline:Show()
				end
			end)
			button:HookScript("OnLeave", function(self)
				if not self._themeTabSelected and self._themeTabUnderline then
					self._themeTabUnderline:Hide()
				end
			end)
		end
	end

	button._themeTabSelected = selected and true or false
	button:SetTheme(selected and "surfaceRaised" or "surface", self.NO_BORDER,
		selected and "goldBright" or "textMuted")
	button:SetHoverTheme("surfaceRaised", self.NO_BORDER,
		selected and "goldBright" or "text")
	self.textures[button._themeTabUnderline] = selected and "gold" or "accent"
	local r, g, b, a = self:GetColor(selected and "gold" or "accent")
	button._themeTabUnderline:SetVertexColor(r, g, b, a)
	if selected then
		button._themeTabUnderline:Show()
	elseif not button._themeHovered then
		button._themeTabUnderline:Hide()
	end
end

-- Text-sized control for toolbars and dense inspectors. Live font metrics set
-- its natural width, with the shared edge gutter above; single-glyph controls
-- retain the requested height as their minimum square hit target.
function Theme:CreateTightButton(parent, text, height, emphasis)
	local buttonHeight = height or self.Metrics.tightButtonHeight
	local button = self:CreateButton(parent, text, buttonHeight, buttonHeight, emphasis)
	button._themeTightAutoFit = true
	button._themeExplicitWidth = false
	button._themeTightMinimumWidth = buttonHeight
	self.tightButtons[button] = true
	button:RefreshTextFit()
	if button.HookScript then
		button:HookScript("OnShow", function(self)
			self:RefreshTextFit()
		end)
	end
	return button
end

function Theme:CreateEditBox(parent, width, height, multiline)
	local editBox = CreateFrame("EditBox", nil, parent)
	editBox:SetWidth(width or 180)
	editBox:SetHeight(height or self.Metrics.editBoxHeight)
	editBox:SetAutoFocus(false)
	editBox:SetMultiLine(multiline and true or false)
	editBox:SetFontObject(GameFontHighlightSmall)
	local r, g, b, a = self:GetColor("text")
	editBox:SetTextColor(r, g, b, a)
	if editBox.SetTextInsets then
		editBox:SetTextInsets(2, 2, 1, 1)
	end
	-- An editable field is separated by its recess, not another bright box.
	-- The accent edge appears only while it owns keyboard focus.
	self:RegisterFrame(editBox, "inset", self.NO_BORDER)

	editBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	editBox:SetScript("OnEditFocusGained", function(self)
		Theme:ApplyFrame(self, "inset", "accent")
	end)
	editBox:SetScript("OnEditFocusLost", function(self)
		Theme:ApplyFrame(self, "inset", Theme.NO_BORDER)
	end)
	return editBox
end

local function attachControlTooltip(control)
	function control:SetTooltip(title, body)
		self._themeTooltipTitle = title
		self._themeTooltipBody = body
	end

	function control:ShowTooltip()
		if not self._themeTooltipTitle or not GameTooltip then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self._themeTooltipTitle, 1, 1, 1, true)
		if self._themeTooltipBody and self._themeTooltipBody ~= "" then
			GameTooltip:AddLine(self._themeTooltipBody, 0.72, 0.76, 0.84, true)
		end
		GameTooltip:Show()
	end

	function control:HideTooltip()
		if GameTooltip and (not GameTooltip.GetOwner or GameTooltip:GetOwner() == self) then
			GameTooltip:Hide()
		end
	end
end

function Theme:CreateCompactToggle(parent, label, width)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width or 146, self.Metrics.compactToggleHeight)
	button.checked = false
	attachControlTooltip(button)

	button.box = self:CreatePanel(button, "inset", self.NO_BORDER)
	button.box:SetSize(13, 13)
	button.box:SetPoint("LEFT", button, "LEFT", 2, 0)
	button.mark = self:CreateText(button.box, "GameFontNormalSmall", "goldBright")
	button.mark:SetPoint("CENTER", button.box, "CENTER", 0, 0)

	button.label = self:CreateText(button, "GameFontNormalSmall", "text")
	button.label:SetPoint("LEFT", button.box, "RIGHT", 3, 0)
	button.label:SetPoint("RIGHT", button, "RIGHT", -2, 0)
	button.label:SetJustifyH("LEFT")
	button.label:SetText(label or "Option")

	function button:SetValue(value, silent)
		self.checked = value and true or false
		self.mark:SetText(self.checked and "X" or "")
		local fillName = self.checked and "accentSoft" or "inset"
		local borderName = self.checked and "gold" or Theme.NO_BORDER
		if Theme.frames[self.box] then
			Theme.frames[self.box].fill = fillName
			Theme.frames[self.box].border = borderName
		end
		Theme:ApplyFrame(self.box, fillName, borderName)
		if not silent and self.OnValueChanged then
			self:OnValueChanged(self.checked)
		end
	end

	button:SetScript("OnClick", function(self)
		self:SetValue(not self.checked)
	end)
	button:SetScript("OnEnter", function(self)
		local r, g, b, a = Theme:GetColor("gold")
		self.label:SetTextColor(r, g, b, a)
		self:ShowTooltip()
	end)
	button:SetScript("OnLeave", function(self)
		local r, g, b, a = Theme:GetColor("text")
		self.label:SetTextColor(r, g, b, a)
		self:HideTooltip()
	end)
	button:SetValue(false, true)
	return button
end

function Theme:CreateToggle(parent, label, description)
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(34)
	button:SetWidth(420)
	button.checked = false
	attachControlTooltip(button)

	button.box = self:CreatePanel(button, "inset", self.NO_BORDER)
	button.box:SetWidth(16)
	button.box:SetHeight(16)
	button.box:SetPoint("LEFT", button, "LEFT", 2, 0)
	button.mark = self:CreateText(button.box, "GameFontNormalSmall", "goldBright")
	button.mark:SetPoint("CENTER", button.box, "CENTER", 0, 0)
	button.mark:SetText("")

	button.label = self:CreateText(button, "GameFontNormalSmall", "text")
	button.label:SetPoint("TOPLEFT", button, "TOPLEFT", 22, -3)
	button.label:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -3)
	button.label:SetText(label)
	button.label:SetJustifyH("LEFT")

	button.description = self:CreateText(button, "GameFontHighlightSmall", "textMuted")
	button.description:SetPoint("TOPLEFT", button, "TOPLEFT", 22, -17)
	button.description:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -17)
	button.description:SetJustifyH("LEFT")
	button.description:SetText(description or "")

	function button:SetValue(value, silent)
		self.checked = value and true or false
		self.mark:SetText(self.checked and "X" or "")
		local fillName = self.checked and "accentSoft" or "inset"
		local borderName = self.checked and "gold" or Theme.NO_BORDER
		if Theme.frames[self.box] then
			Theme.frames[self.box].fill = fillName
			Theme.frames[self.box].border = borderName
		end
		Theme:ApplyFrame(self.box, fillName, borderName)
		if not silent and self.OnValueChanged then
			self:OnValueChanged(self.checked)
		end
	end

	button:SetScript("OnClick", function(self)
		self:SetValue(not self.checked)
	end)
	button:SetScript("OnEnter", function(self)
		local r, g, b, a = Theme:GetColor("gold")
		self.label:SetTextColor(r, g, b, a)
		self:ShowTooltip()
	end)
	button:SetScript("OnLeave", function(self)
		local r, g, b, a = Theme:GetColor("text")
		self.label:SetTextColor(r, g, b, a)
		self:HideTooltip()
	end)
	button:SetValue(false, true)
	return button
end
