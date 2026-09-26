-- Run from the Retail addon root: lua Tests/PresentationURLCopy.mock.lua

ChattyChattyBangBang = {}
local addon = ChattyChattyBangBang
addon.Theme = {
	GetPalette = function() return { accent = { 0.3, 0.6, 1 } } end,
	GetColor = function() return 0.3, 0.6, 1, 1 end,
}
addon.GetSmartSettings = function()
	return { keywordColorGroups = {}, keywordColors = {}, dock = {} }
end

dofile("Core/Presentation.lua")
local presentation = addon.Presentation
local original = "See https://example.com/deal?item=42, then |cffaabbcc|Hitem:123|h[Moon Sword]|h|r"
local rendered = presentation:ColorizeMessage(original)
assert(rendered:find("|Hccbburl:https://example.com/deal?item=42|hhttps://example.com/deal?item=42|h", 1, true),
	"plain HTTPS address was not offered as a copy-only link")
assert(rendered:find("|cffaabbcc|Hitem:123|h[Moon Sword]|h|r", 1, true),
	"native WoW hyperlink was rewritten")
assert(original:find("https://example.com/deal?item=42,", 1, true),
	"rendering changed the input chat record")
assert(not rendered:find("|Hccbburl:https://example.com/deal?item=42,|h", 1, true),
	"trailing sentence punctuation became part of the URL")

local other = presentation:ColorizeMessage("Visit WWW.Example.Org/path. Use http://foo.bar/a next")
assert(other:find("|Hccbburl:WWW.Example.Org/path|h", 1, true), "www address was missed")
assert(other:find("|Hccbburl:http://foo.bar/a|h", 1, true), "second address was missed")
assert(presentation:ColorizeMessage("(https://example.com/wiki/Test_(album))")
	:find("|Hccbburl:https://example.com/wiki/Test_(album)|h", 1, true),
	"balanced URL parentheses were discarded with sentence punctuation")
assert(not presentation:ColorizeMessage("ftp://example.com"):find("|Hccbburl:", 1, true),
	"unsupported protocol was made clickable")
assert(not presentation:ColorizeMessage("evilhttps://example.com"):find("|Hccbburl:", 1, true),
	"address embedded in another word was made clickable")
assert(not presentation:ColorizeMessage("https://name@example.com"):find("|Hccbburl:", 1, true),
	"userinfo address was accepted")
assert(not presentation:ColorizeMessage("https://example.com/" .. string.rep("a", 510)):find("|Hccbburl:", 1, true),
	"unbounded address was accepted")
assert(not presentation:ColorizeMessage("https://example.com/é"):find("|Hccbburl:", 1, true),
	"non-ASCII payload was injected into a WoW hyperlink")
local longLink = presentation:ColorizeMessage("https://example.com/some/very/long/path")
local wrapped, breakCount = presentation:WrapRenderedMessage(longLink, 0, 18)
assert(breakCount > 0 and wrapped:find("|Hccbburl:https://example.com/some/very/long/path|h", 1, true),
	"narrow wrapping broke the URL hyperlink payload")

local copied
local realShowURLCopy = presentation.ShowURLCopy
presentation.ShowURLCopy = function(_, url) copied = url; return true end
assert(presentation:HandleCopyURLHyperlink("ccbburl:https://example.com/a") and copied == "https://example.com/a",
	"copy-only link was not handled")
copied = nil
assert(presentation:HandleCopyURLHyperlink("ccbburl:javascript://example.com") and copied == nil,
	"invalid Chatty link escaped to Blizzard or opened")
assert(not presentation:HandleCopyURLHyperlink("item:123"), "native item link was swallowed")

-- The chooser is a selectable, edit-resistant copy field with a visible
-- gutter at the smallest width used by this mock; it never calls an opener.
local function frame()
	local value = { points = {}, scripts = {}, shown = false }
	function value:SetPoint(...) self.points[#self.points + 1] = { ... } end
	function value:SetHeight(height) self.height = height end
	function value:SetWidth(width) self.width = width end
	function value:SetFrameStrata(strata) self.strata = strata end
	function value:EnableMouse(enabled) self.mouse = enabled end
	function value:SetClampedToScreen(enabled) self.clamped = enabled end
	function value:SetScript(script, handler) self.scripts[script] = handler end
	function value:SetText(text) self.text = text end
	function value:GetText() return self.text end
	function value:SetMaxLetters(count) self.maxLetters = count end
	function value:SetJustifyH(justify) self.justify = justify end
	function value:SetWordWrap(enabled) self.wordWrap = enabled end
	function value:GetWidth() return self.width end
	function value:SetFocus() self.focused = true end
	function value:ClearFocus() self.focused = false end
	function value:HighlightText() self.highlighted = true end
	function value:Show() self.shown = true end
	function value:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
	return value
end
local panel
addon.Theme.CreatePanel = function() panel = frame(); return panel end
addon.Theme.CreateText = function() return frame() end
addon.Theme.CreateButton = function() return frame() end
addon.Theme.CreateEditBox = function() return frame() end
_G.CreateFrame = function() return frame() end
_G.UIParent = { GetWidth = function() return 220 end }
presentation.ShowURLCopy = realShowURLCopy
assert(presentation:ShowURLCopy("https://example.com/copy"), "copy field did not open")
assert(panel.shown and panel.width == 188 and panel.clamped,
	"copy field escaped a 220px viewport's 16px side gutters")
assert(panel.title.text == "COPY URL" and panel.hint.text:find("No auto-open.", 1, true),
	"compact copy field did not shorten its title and hint")
assert(panel.title.points[2][2] and panel.title.points[2][4] == -8,
	"copy title lacks a reserved gutter before the close button")
assert(panel.editBox.points[1][4] == 12 and panel.editBox.points[2][4] == -12,
	"copy field is touching its border")
assert(panel.editBox.text == "https://example.com/copy" and panel.editBox.highlighted,
	"URL was not selected for Ctrl+C")
panel.editBox:SetText("changed")
panel.editBox.scripts.OnTextChanged(panel.editBox, true)
assert(panel.editBox.text == "https://example.com/copy",
	"copy field permitted editing its original URL")
panel.editBox.scripts.OnEscapePressed(panel.editBox)
assert(not panel.shown and not panel.editBox.focused, "Escape did not dismiss the copy field")
_G.UIParent.GetWidth = function() return 640 end
assert(presentation:ShowURLCopy("https://example.com/next") and panel.width == 460,
	"copy field did not expand within a wider viewport")
assert(panel.title.text == "COPY WEB ADDRESS" and not panel.hint.text:find("\n", 1, true),
	"wide copy field retained compact text unnecessarily")
print("Presentation URL copy mock passed")
