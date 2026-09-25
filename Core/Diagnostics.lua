-- Loaded before the embedded libraries so an addon load failure can be saved
-- on /reload even when the main addon never reaches OnInitialize.
local diagnostics = {}
_G.ChattyChattyBangBangDiagnostics = diagnostics

local db = _G.ChattyChattyBangBangDiagnosticsDB
if type(db) ~= "table" then
	db = {}
	_G.ChattyChattyBangBangDiagnosticsDB = db
end
db.schema = 1
db.entries = type(db.entries) == "table" and db.entries or {}
db.session = (tonumber(db.session) or 0) + 1
db.startup = { session = db.session, stage = "diagnostics-loaded", status = "loading" }
diagnostics.db = db

local function clipped(value, limit)
	value = tostring(value or "")
	if #value > limit then
		return value:sub(1, limit) .. "..."
	end
	return value
end

local function now()
	return type(_G.time) == "function" and _G.time() or 0
end

function diagnostics:Mark(stage, status)
	db.startup.stage = clipped(stage, 120)
	db.startup.status = status or "loading"
	db.startup.time = now()
end

function diagnostics:Record(kind, message, stack)
	local entry = {
		session = db.session,
		kind = clipped(kind, 64),
		stage = db.startup.stage,
		message = clipped(message, 4096),
		stack = clipped(stack, 8192),
		time = now(),
		count = 1,
	}
	local last = db.entries[#db.entries]
	if last and last.session == entry.session and last.kind == entry.kind
		and last.message == entry.message and last.stack == entry.stack then
		last.count = (last.count or 1) + 1
		last.time = entry.time
	else
		db.entries[#db.entries + 1] = entry
		if #db.entries > 120 then table.remove(db.entries, 1) end
	end
	db.startup.status = "error"
	return entry
end

local function stackTrace()
	if type(_G.debugstack) ~= "function" then return "" end
	local ok, result = pcall(_G.debugstack, 2, 20, 20)
	return ok and type(result) == "string" and result or ""
end

local previousHandler = type(_G.geterrorhandler) == "function" and _G.geterrorhandler() or nil
if type(_G.seterrorhandler) == "function" then
	local function chattyErrorHandler(message)
		local trace = stackTrace()
		if tostring(message):find("ChattyChattyBangBang", 1, true)
			or trace:find("ChattyChattyBangBang", 1, true) then
			diagnostics:Record("lua", message, trace)
		end
		if previousHandler then return previousHandler(message) end
	end
	pcall(_G.seterrorhandler, chattyErrorHandler)
end

local function printStatus(message)
	local chat = _G.DEFAULT_CHAT_FRAME
	if chat and type(chat.AddMessage) == "function" then
		chat:AddMessage("|cff55ccffChatty|r " .. message)
	elseif _G.UIErrorsFrame and type(_G.UIErrorsFrame.AddMessage) == "function" then
		_G.UIErrorsFrame:AddMessage("Chatty " .. message)
	end
end

function diagnostics:PrintStatus()
	local startup = db.startup or {}
	printStatus("session " .. tostring(db.session) .. ": "
		.. tostring(startup.stage or "unknown") .. " (" .. tostring(startup.status or "unknown") .. ")")
	local entry = db.entries[#db.entries]
	if entry then
		printStatus("last " .. tostring(entry.kind) .. ": " .. clipped(entry.message, 260))
	else
		printStatus("no captured Chatty errors")
	end
end

if type(_G.SlashCmdList) == "table" then
	_G.SLASH_CCBB_DIAGNOSTICS1 = "/ccbbdiag"
	_G.SlashCmdList.CCBB_DIAGNOSTICS = function() diagnostics:PrintStatus() end
	_G.SLASH_CCBB_START1 = "/ccbbstart"
	_G.SlashCmdList.CCBB_START = function()
		local addon = _G.ChattyChattyBangBang
		if not addon or type(addon.SetSmartChatEnabled) ~= "function"
			or not addon.IsEnabled or not addon:IsEnabled() then
			printStatus("core has not initialized; use /ccbbdiag to see where it stopped")
			return
		end
		local ok, reason = addon:SetSmartChatEnabled(true)
		if ok then
			diagnostics:Mark("smart-chat-active", "ready")
			printStatus("Smart Chat enabled")
		else
			diagnostics:Record("activation", reason or "unknown failure")
			printStatus("Smart Chat failed: " .. tostring(reason) .. "; use /ccbbdiag")
		end
	end
end
