-- Run from the addon root: lua Tests/MessengerPersistenceConfig.mock.lua
-- The Messenger page's 652x508 canvas is the minimum reviewed settings area.
local Frame = {}
Frame.__index = Frame
local function frame(parent, width, height)
	return setmetatable({ parent = parent, width = width or 100, height = height or 20,
		shown = true, scripts = {}, textValue = "" }, Frame)
end
function Frame:SetPoint(...) self.point = { ... } end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetAllPoints() end
function Frame:SetSize(w, h) self.width, self.height = w, h end
function Frame:SetWidth(w) self.width = w end
function Frame:SetHeight(h) self.height = h end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:SetJustifyH() end
function Frame:SetJustifyV() end
function Frame:SetMaxLetters() end
function Frame:SetTextColor() end
function Frame:SetText(value) self.textValue = tostring(value or "") end
function Frame:GetText() return self.textValue end
function Frame:GetStringWidth() return #self.textValue * 7 end
function Frame:SetScript(name, callback) self.scripts[name] = callback end
function Frame:HookScript(name, callback) self.scripts[name] = callback end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown end
function Frame:Enable() self.enabled = true end
function Frame:Disable() self.enabled = false end
function Frame:ClearFocus() end
function Frame:SetTooltip(title, body) self.tooltipTitle, self.tooltipBody = title, body end
function Frame:SetTheme() end
function Frame:SetHoverTheme() end
function Frame:SetLabel(label) self:SetText(label) end
function Frame:SetValue(value, silent)
	self.checked = value and true or false
	if not silent and self.OnValueChanged then self.OnValueChanged(self, self.checked) end
end
function Frame:CreateTexture() return frame(self) end
function Frame:CreateFontString() return frame(self) end
function CreateFrame(_, _, parent) return frame(parent) end

UIParent = frame(nil, 700, 500)
GameFontNormalLarge, GameFontNormal, GameFontNormalSmall, GameFontHighlightSmall = {}, {}, {}, {}
local Theme = { texts = {}, frames = {}, textures = {} }
function Theme:GetColor() return 1, 1, 1, 1 end
function Theme:CreateText(parent) return frame(parent) end
function Theme:CreatePanel(parent) return frame(parent) end
function Theme:CreateTightButton(parent, label, height)
	local button = frame(parent, #label * 7 + 14, height)
	button.text = frame(button)
	button:SetText(label)
	return button
end
function Theme:CreateButton(parent, label, width, height)
	local button = frame(parent, width, height)
	button.text = frame(button)
	button:SetText(label)
	return button
end
function Theme:CreateEditBox(parent, width, height) return frame(parent, width, height) end
function Theme:CreateCompactToggle(parent, label, width)
	local toggle = frame(parent, width, 20)
	toggle.label = frame(toggle)
	toggle.label:SetText(label)
	return toggle
end
function Theme:RegisterFrame() end
function Theme:RegisterTexture() end
function Theme:ApplyFrame() end
function Theme:RegisterRefreshCallback() end

ChattyChattyBangBang = { Theme = Theme, db = { profile = { smartChat = {} } } }
local addon = ChattyChattyBangBang
dofile("Core/Settings.lua")
dofile("Core/Config.lua")
local config = addon.CustomConfig
config.pages = {}
config.content = frame(nil, 652, 508)
config:BuildMessengerPage()
config:SetMessengerSection("tabs")

local function bounds(widget)
	assert(widget.parent == config.messengerPage, "Messenger control escaped its settings page")
	local x, y = widget.point[4], -widget.point[5]
	assert(x >= 8 and x + widget.width <= 644,
		"Messenger control has no 8px border gutter at minimum width")
	assert(y >= 8 and y + widget.height <= 500,
		"Messenger control escaped the minimum-height page")
	return y, y + widget.height
end
local draftTop, draftBottom = bounds(config.messengerPersistDraftsToggle)
local targetTop, targetBottom = bounds(config.messengerPersistReplyTargetsToggle)
local clearTop = bounds(config.messengerClearSavedStateButton)
local memoryTitle, memoryDetail
for _, control in ipairs(config.messengerSectionGroups.tabs) do
	if control:GetText() == "AFTER RELOAD — OPTIONAL" then memoryTitle = control end
	if string.find(control:GetText(), "Both start OFF", 1, true) then memoryDetail = control end
end
assert(memoryTitle and memoryDetail, "Messenger reply-memory explanation is missing")
local titleTop, titleBottom = bounds(memoryTitle)
local detailTop, detailBottom = bounds(memoryDetail)
local _, nameDetailBottom = bounds(config.messengerTabNameLengthDetail)
assert(targetTop - draftBottom >= 8 and clearTop - targetBottom >= 8,
	"Messenger remember controls need an explicit vertical gutter")
assert(titleTop - nameDetailBottom >= 8 and draftTop - titleBottom >= 8
	and detailTop - targetBottom >= 8 and clearTop - detailBottom >= 8,
	"Messenger text, toggles, and clear action need visible vertical gutters")
assert(config.messengerPersistDraftsToggle:IsShown()
	and config.messengerPersistReplyTargetsToggle:IsShown()
	and config.messengerClearSavedStateButton:IsShown(),
	"Messenger remember controls are hidden in TABS")
assert(config.messengerPersistDraftsToggle.tooltipBody
	and config.messengerPersistReplyTargetsToggle.tooltipBody
	and config.messengerClearSavedStateButton.tooltipBody,
	"private persistence controls need clear explanatory tooltips")

local stored = addon:GetSmartSettings().conversations
assert(not config.messengerPersistDraftsToggle.checked
	and not config.messengerPersistReplyTargetsToggle.checked,
	"both private persistence toggles must visibly begin off")
config.messengerPersistDraftsToggle:SetValue(true)
config.messengerPersistReplyTargetsToggle:SetValue(true)
assert(stored.persistDrafts and stored.persistReplyTargets
	and config.messengerPersistDraftsToggle.checked
	and config.messengerPersistReplyTargetsToggle.checked,
	"both opt-in controls failed to update and refresh together")
stored.savedDrafts.alice = "private"
stored.savedDraftOrder[1] = "alice"
stored.savedReplyTargets = { order = { "alice" }, items = { alice = { name = "Alice" } } }
config.messengerClearSavedStateButton.scripts.OnClick()
assert(next(stored.savedDrafts) == nil and next(stored.savedReplyTargets) == nil
	and config.messengerClearSavedStateButton:IsShown(),
	"clear action did not erase both stored payloads while preserving the UI")
config.messengerPersistDraftsToggle:SetValue(false)
config.messengerPersistReplyTargetsToggle:SetValue(false)
assert(not stored.persistDrafts and not stored.persistReplyTargets
	and not config.messengerPersistDraftsToggle.checked
	and not config.messengerPersistReplyTargetsToggle.checked,
	"turning private persistence off did not update both visible choices")
config:SetMessengerSection("opening")
assert(not config.messengerPersistDraftsToggle:IsShown()
	and not config.messengerPersistReplyTargetsToggle:IsShown()
	and not config.messengerClearSavedStateButton:IsShown(),
	"TABS controls leaked into another Messenger subpage")

print("MessengerPersistenceConfig.mock.lua: PASS")
