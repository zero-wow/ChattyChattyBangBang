-- Run from the Retail addon root with: lua Tests/CompatibilitySocialActions.mock.lua
ChattyChattyBangBang = {}
dofile("Core/Compatibility.lua")
local compatibility = ChattyChattyBangBang.Compatibility
local calls = {}

local function record(label, result)
	return function(...)
		assert(select("#", ...) == 1, label .. " received the wrong argument count")
		local name = ...
		assert(name == "Target-Realm", label .. " received the wrong player name")
		calls[#calls + 1] = label
		return result
	end
end

C_PartyInfo = { InviteUnit = record("retail invite") }
C_FriendList = {
	AddFriend = record("retail friend"),
	AddIgnore = record("retail ignore", false),
}
InviteUnit = record("legacy invite")
AddFriend = record("legacy friend")
AddIgnore = record("legacy ignore")
compatibility:InvitePlayer("Target-Realm")
compatibility:AddFriend("Target-Realm")
assert(compatibility:AddServerIgnore("Target-Realm") == false,
	"an explicit Retail ignore rejection was reported as dispatched")
assert(table.concat(calls, ",") == "retail invite,retail friend,retail ignore",
	"Retail social actions did not prefer the namespaced APIs exactly once")
C_FriendList.AddIgnore = record("retail ignore accepted", true)
assert(compatibility:AddServerIgnore("Target-Realm") == true,
	"a successful Retail ignore call was not reported as dispatched")
C_FriendList.AddIgnore = function()
	error("ignore API failed")
end
assert(compatibility:AddServerIgnore("Target-Realm") == false
	and calls[#calls] == "retail ignore accepted",
	"a throwing Retail ignore call was reported as dispatched or retried through legacy")

calls = {}
C_PartyInfo = nil
C_FriendList = {}
compatibility:InvitePlayer("Target-Realm")
compatibility:AddFriend("Target-Realm")
assert(compatibility:AddServerIgnore("Target-Realm") == true,
	"a legacy ignore call with no return value was reported as failed")
assert(table.concat(calls, ",") == "legacy invite,legacy friend,legacy ignore",
	"legacy social actions did not work without Retail APIs")
AddIgnore = record("legacy ignore rejected", false)
assert(compatibility:AddServerIgnore("Target-Realm") == false,
	"an explicit legacy ignore rejection was reported as dispatched")
AddIgnore = function() error("legacy ignore API failed") end
assert(compatibility:AddServerIgnore("Target-Realm") == false,
	"a throwing legacy ignore call was reported as dispatched")

calls = {}
compatibility:InvitePlayer("")
compatibility:AddFriend(nil)
assert(compatibility:AddServerIgnore({}) == false,
	"invalid ignore target was reported as dispatched")
assert(#calls == 0, "invalid player names reached a social API")
InviteUnit, AddFriend, AddIgnore = nil, nil, nil
compatibility:InvitePlayer("Target-Realm")
compatibility:AddFriend("Target-Realm")
assert(compatibility:AddServerIgnore("Target-Realm") == false,
	"missing ignore API was reported as dispatched")
assert(#calls == 0, "missing social APIs did not fail safely")

print("Compatibility social-action mock tests passed")
