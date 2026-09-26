-- Run from the addon root: lua Tests/HyperlinkPreview.mock.lua
ChattyChattyBangBang = { Theme = {}, Presentation = {}, MessageEngine = {} }
dofile("Core/ConversationWindows.lua")

local manager = ChattyChattyBangBang.ConversationWindows
local chat, other = {}, {}
local tooltip = { shown = false, owner = nil, links = {} }
function tooltip:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
function tooltip:GetOwner() return self.owner end
function tooltip:IsShown() return self.shown end
function tooltip:SetHyperlink(link)
	if link == "item:999" then error("bad native link") end
	self.links[#self.links + 1] = link
end
function tooltip:Show() self.shown = true end
function tooltip:Hide() self.shown = false; self.hideCount = (self.hideCount or 0) + 1 end
GameTooltip = tooltip

assert(not manager:ShowNativeLinkPreview(chat, "item:123", false))
assert(not tooltip.shown and #tooltip.links == 0, "previews must default to off")
for _, link in ipairs({ "ccbbplayer:2", "ccbburl:https://example.invalid", "quest:123", "item:x", "spell:2|bad" }) do
	assert(not manager:ShowNativeLinkPreview(chat, link, true), "non-native or unsafe link was accepted")
end
assert(manager:ShowNativeLinkPreview(chat, "item:123:0:0", true))
assert(tooltip.shown and tooltip.owner == chat and tooltip.links[1] == "item:123:0:0")
manager:HideNativeLinkPreview(chat)
assert(not tooltip.shown and tooltip.hideCount == 1, "chat-owned preview was not hidden")
assert(manager:ShowNativeLinkPreview(chat, "spell:456", true))
tooltip.owner = other
manager:HideNativeLinkPreview(chat)
assert(tooltip.shown, "leaving chat hid another control's tooltip")
assert(not manager:ShowNativeLinkPreview(chat, "item:123", true), "chat stole another control's tooltip")
tooltip:Hide()
assert(not manager:ShowNativeLinkPreview(chat, "item:999", true), "invalid native link should fail closed")
assert(not tooltip.shown, "failed preview left a tooltip open")

issecretvalue = function(value) return value == "item:888" end
assert(not manager:ShowNativeLinkPreview(chat, "item:888", true), "secret link reached GameTooltip")
print("HyperlinkPreview.mock.lua: PASS")
