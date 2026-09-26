-- Run from the addon root: lua Tests/ConversationPersistence.mock.lua
dofile("Tests/ConversationWindowsLayout.mock.lua")

local addon = ChattyChattyBangBang
local manager = addon.ConversationWindows
local settings = addon:GetSmartSettings().conversations
local function expect(value, message)
	if not value then error(message, 2) end
end

manager:ResetForProfile()
settings.persistDrafts = true
settings.persistReplyTargets = true
settings.savedDrafts = {}
settings.savedDraftOrder = {}
settings.savedReplyTargets = {}
manager:SetEnabled(true)

local alice = manager:AcquireSession("Alice")
local bob = manager:AcquireSession("Bob")
local bnet = manager:AcquireSession("SameDisplay", 517)
local shell = manager:SelectSession(alice.playerKey)
shell.editBox:SetText("unsent private message")
shell.editBox.scripts.OnTextChanged(shell.editBox)
expect(settings.savedDrafts.alice == "unsent private message"
	and #settings.savedDraftOrder == 1,
	"typed text was not saved only when draft storage was opted in")
manager:SelectSession(bob.playerKey)
manager:SelectSession(bnet.playerKey)
expect(#settings.savedReplyTargets.order == 3
	and settings.savedReplyTargets.activeKey == "bnet:517"
	and settings.savedReplyTargets.items["bnet:517"].bnetAccountID == 517,
	"tab order, active recipient, or Battle.net account target was not saved")
expect(settings.savedReplyTargets.items.alice.name == "Alice"
	and settings.savedReplyTargets.items.alice.text == nil,
	"reply-target storage must contain identity, never whisper bodies")

manager:ResetForProfile()
manager:SetEnabled(true)
expect(#manager.tabOrder == 3 and manager.tabOrder[1] == "alice"
	and manager.tabOrder[2] == "bob" and manager.tabOrder[3] == "bnet:517"
	and manager.shell.playerKey == "bnet:517",
	"saved reply tabs and selected recipient did not restore after a simulated reload")
expect(manager.sessionsByKey.alice.draft == "unsent private message"
	and manager.sessionsByKey.bob.draft == "",
	"only the correct recipient's unsent reply should restore")
manager:SelectSession("alice")
expect(manager.shell.editBox:GetText() == "unsent private message",
	"restored private draft did not populate its own composer")

manager:RemoveSession("alice")
expect(settings.savedDrafts.alice == nil
	and settings.savedReplyTargets.items.alice == nil,
	"closing a conversation must forget its saved draft and reply target")

-- Malformed/over-limit SavedVariables should be pruned before they can grow
-- memory or create unintended Messenger tabs. There is no migration from any
-- older whisper body field: only the explicit opt-in payload is considered.
manager:ResetForProfile()
settings.savedDrafts = { bad = string.rep("x", 1025), orphan = "must not survive" }
settings.savedDraftOrder = { "bad" }
settings.savedReplyTargets = { order = {}, items = {}, activeKey = "fake" }
for index = 1, 14 do
	local key = "saved" .. index
	settings.savedReplyTargets.order[index] = key
	settings.savedReplyTargets.items[key] = { name = "Saved" .. index }
end
settings.savedReplyTargets.items.saved3 = { name = "WrongPerson" }
manager:SetEnabled(true)
expect(next(settings.savedDrafts) == nil and #settings.savedDraftOrder == 0,
	"invalid or orphaned private drafts were not pruned")
expect(#manager.tabOrder == 12 and #settings.savedReplyTargets.order == 12
	and not manager.sessionsByKey.saved3 and settings.savedReplyTargets.activeKey == "saved1",
	"saved reply targets exceeded the 12-tab cap or accepted a mismatched identity")

settings.persistDrafts = false
settings.persistReplyTargets = false
settings.savedDrafts = {}
settings.savedDraftOrder = {}
settings.savedReplyTargets = {}
manager:ResetForProfile()
manager:SetEnabled(true)
local private = manager:AcquireSession("Private")
manager:SelectSession(private.playerKey)
manager.shell.editBox:SetText("memory only")
manager.shell.editBox.scripts.OnTextChanged(manager.shell.editBox)
expect(private.draft == "memory only" and next(settings.savedDrafts) == nil
	and next(settings.savedReplyTargets) == nil,
	"default-off preferences must keep live text in memory without writing SavedVariables")

print("ConversationPersistence.mock.lua: PASS")
