-- Focused no-client contract for legacy modules that must remain dormant while
-- Smart Chat owns the native ChatFrameN presentation.
-- Run from the addon root with: lua Tests/LegacyModuleIsolation.mock.lua

local modules = {}
local unpack = unpack or table.unpack
local actions = {
	raw = {},
	secure = {},
	created = 0,
	clamps = {},
}

local function makeFrame(name)
	local frame = {
		name = name,
		shown = true,
		scripts = {},
		clamp = { -35, 35, 26, -50 },
	}
	function frame:GetName()
		return self.name
	end
	function frame:GetScript(script)
		return self.scripts[script]
	end
	function frame:SetScript(script, handler)
		self.scripts[script] = handler
	end
	function frame:IsShown()
		return self.shown
	end
	function frame:Show()
		self.shown = true
	end
	function frame:Hide()
		self.shown = false
	end
	function frame:GetClampRectInsets()
		return unpack(self.clamp)
	end
	function frame:SetClampRectInsets(left, right, top, bottom)
		self.clamp = { left, right, top, bottom }
		actions.clamps[#actions.clamps + 1] = { self, left, right, top, bottom }
	end
	function frame:IsMovable()
		return false
	end
	function frame:GetCurrentScroll()
		return 0
	end
	function frame:ScrollToBottom()
		self.scrolledToBottom = true
	end
	return frame
end

local function makeButton(parent)
	local button = makeFrame(nil)
	button.parent = parent
	function button:GetParent()
		return self.parent
	end
	function button:SetNormalTexture() end
	function button:SetPushedTexture() end
	function button:SetDisabledTexture() end
	function button:SetHighlightTexture() end
	function button:SetWidth() end
	function button:SetHeight() end
	function button:SetPoint() end
	function button:LockHighlight() end
	function button:UnlockHighlight() end
	return button
end

function CreateFrame(_, _, parent)
	actions.created = actions.created + 1
	return makeButton(parent)
end

local messages = {}
ChatFrame1 = makeFrame("ChatFrame1")
function ChatFrame1:AddMessage(text, ...)
	messages[#messages + 1] = { text = text, args = { ... } }
end
ChatFrame1.downButton = { original = true }
ChatFrame1ButtonFrame = makeFrame("ChatFrame1ButtonFrame")
ChatFrameMenuButton = makeFrame("ChatFrameMenuButton")
FriendsMicroButton = makeFrame("FriendsMicroButton")
COMBATLOG = ChatFrame1
NUM_CHAT_WINDOWS = 1
GUILD_MOTD_TEMPLATE = "Guild Message of the Day: %s"
strmatch = string.match

local locale = setmetatable({}, { __index = function(_, key) return key end })
function LibStub(name)
	if name == "AceLocale-3.0" then
		return { GetLocale = function() return locale end }
	end
	return nil
end

ChattyChattyBangBang = {
	db = {
		RegisterNamespace = function()
			return { profile = {} }
		end,
	},
}

function ChattyChattyBangBang:NewModule(name)
	local mod = {
		moduleName = name,
		enabled = false,
		hooks = {},
		TempChatFrames = {},
	}
	function mod:IsEnabled()
		return self.enabled
	end
	function mod:RawHook(target, method)
		actions.raw[#actions.raw + 1] = { target, method }
		self.hooks[target] = self.hooks[target] or {}
		self.hooks[target][method] = target[method]
	end
	function mod:SecureHook(method)
		actions.secure[#actions.secure + 1] = method
	end
	function mod:Hook(target, method)
		self:RawHook(target, method)
	end
	function mod:IsHooked(target, method)
		return self.hooks[target] and self.hooks[target][method] ~= nil
	end
	function mod:Unhook(target, method)
		if self.hooks[target] then
			self.hooks[target][method] = nil
		end
	end
	function mod:UnhookAll()
		self.hooks = {}
	end
	modules[name] = mod
	return mod
end

dofile("Modules/DelayGMOTD.lua")
dofile("Modules/Buttons.lua")

local delay = modules["Delay Guild MOTD"]
local buttons = modules["Disable Buttons"]
assert(delay and buttons, "legacy modules did not register")
assert(#actions.raw == 0 and #actions.secure == 0 and #actions.clamps == 0 and actions.created == 0,
	"loading modules.xml still touched native chat")

buttons:OnInitialize()
local buttonOptions = buttons:GetOptions()
buttonOptions.bottomButton.set(nil, true)
buttonOptions.bottomButton.set(nil, false)
assert(#actions.raw == 0 and #actions.secure == 0 and #actions.clamps == 0 and actions.created == 0,
	"a dormant Buttons preference woke native chat")

delay.enabled = true
delay:OnEnable()
assert(#actions.raw == 1 and actions.raw[1][1] == ChatFrame1 and actions.raw[1][2] == "AddMessage",
	"Delay Guild MOTD did not install its hook only on enable")
delay:AddMessage(ChatFrame1, "Guild Message of the Day: Safe restore")
assert(#messages == 0, "delayed MOTD was displayed before the timer finished")
delay.enabled = false
delay:OnDisable()
assert(messages[1] and messages[1].text == "Guild Message of the Day: Safe restore",
	"disabling Delay Guild MOTD lost a pending MOTD")

local originalDownButton = ChatFrame1.downButton
buttons.enabled = true
buttons:OnEnable()
assert(#actions.secure == 1 and actions.secure[1] == "FCF_RestorePositionAndDimensions",
	"Buttons installed its native restore hook outside its enable lifecycle")
assert(#actions.clamps > 0 and ChatFrame1.clamp[1] == 0 and ChatFrame1.clamp[2] == 0,
	"Buttons did not apply its native fallback inset changes on enable")
assert(ChatFrame1.downButton ~= originalDownButton, "Buttons did not install its native fallback scroll control")
buttons:EnsureBottomButton(ChatFrame1)
buttons.enabled = false
buttons:OnDisable()
assert(ChatFrame1.clamp[1] == -35 and ChatFrame1.clamp[2] == 35 and ChatFrame1.clamp[3] == 26 and ChatFrame1.clamp[4] == -50,
	"Buttons did not restore the original clamp insets")
assert(ChatFrame1.downButton == originalDownButton,
	"Buttons did not restore the prior scroll-control reference")

print("Legacy module isolation mock passed")
