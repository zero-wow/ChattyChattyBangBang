-- Focused no-client contract for next-frame presentation redraw batching.
-- Run from the addon root with: lua Tests/SmartDockRedrawCoalescing.mock.lua

local inCombat = false
local created = 0
InCombatLockdown = function() return inCombat end
CreateFrame = function()
	created = created + 1
	local frame = { shown = false }
	function frame:Show() self.shown = true end
	function frame:Hide() self.shown = false end
	function frame:SetScript(name, callback) self[name] = callback end
	return frame
end

local engine = { GetMessages = function() return {} end }
ChattyChattyBangBang = {
	Theme = {}, Presentation = {}, MessageEngine = engine,
	GetSmartSettings = function() return {} end,
}
dofile("Core/SmartDock.lua")
local dock = ChattyChattyBangBang.SmartDock
local originalPreservingRebuild = dock.RebuildActiveViewPreservingScroll
dock.active = true
dock.activeView = "general"
dock.display = { Clear = function() end, ScrollToBottom = function() end }

local repaints = 0
dock.RebuildActiveViewPreservingScroll = function()
	repaints = repaints + 1
end

assert(dock:QueuePresentationRebuild())
assert(dock:QueuePresentationRebuild())
assert(dock:QueuePresentationRebuild())
assert(created == 1 and repaints == 0 and dock.presentationRebuildDriver.shown,
	"rapid palette/color changes were not queued into one frame")
dock.presentationRebuildDriver.OnUpdate(dock.presentationRebuildDriver, 0.016)
assert(repaints == 1 and not dock.presentationRebuildQueued
	and not dock.presentationRebuildDriver.shown,
	"three rapid redraw requests did not produce exactly one repaint")

-- A synchronous full rebuild supersedes a queued presentation repaint. This
-- is the path used by message delivery, tab changes, and committed resize.
local cleared = 0
dock.display.Clear = function() cleared = cleared + 1 end
dock.IsAlignmentVisibleOnly = function() return false end
dock.GetRoundedDisplayPixelWidth = function() return 500 end
dock.HideMessageBlockControls = function() end
dock.ClearDisplayRecordCache = function() end
dock.IsLocallyIgnored = function() return false end
dock.IsRecordAllowedInView = function() return true end
dock.ResetActiveSourceColumnMetrics = function() end
dock.CalculateSenderColumnWidth = function() return nil end
dock.CalculateSenderColumnLongest = function() return 0 end
dock.GetColumnAlignmentSpacing = function() return 1 end
dock.GetSenderColumnAlignmentSpacing = function() return 1 end
dock.ResetActiveMetadataMetrics = function() end
dock.ResolveActiveResponsiveMetadata = function() end
dock.RefreshHangingMessageWrapMode = function() end
dock.RefreshHistoryPager = function() end
dock.RefreshMessageBands = function() end
dock.RefreshMessageScrollbar = function() end
dock.ClearPendingMessages = function() end
dock.UpdateEmptyState = function() end

assert(dock:QueuePresentationRebuild())
dock:RebuildActiveView()
assert(cleared == 1 and not dock.presentationRebuildQueued
	and not dock.presentationRebuildDriver.shown,
	"synchronous redraw failed to supersede a queued repaint")
dock.presentationRebuildDriver.OnUpdate(dock.presentationRebuildDriver, 0.016)
assert(cleared == 1 and repaints == 1,
	"stale queued repaint ran after synchronous redraw")

-- On clients where the driver cannot be created during combat, the ordinary
-- immediate Chatty display path remains available; no frame is created.
dock.presentationRebuildDriver = nil
inCombat = true
assert(not dock:QueuePresentationRebuild() and repaints == 2 and created == 1,
	"combat fallback delayed repaint or created a new frame")
inCombat = false

-- The queued path uses the existing preservation wrapper, so an older-history
-- reader keeps both scroll offset and pending-new-message count after repaint.
local restoredAtBottom, restoredOffset
dock.GetDisplayScrollOffset = function() return 7 end
dock.RestoreDisplayScroll = function(_, atBottom, offset)
	restoredAtBottom, restoredOffset = atBottom, offset
end
dock.RefreshNewMessageIndicator = function() end
dock.RebuildActiveView = function(self) self.pendingVisible = 0 end
dock.pendingVisible = 4
originalPreservingRebuild(dock)
assert(restoredAtBottom == false and restoredOffset == 7 and dock.pendingVisible == 4,
	"presentation rebuild did not preserve older-history scroll and unread state")

print("SmartDock redraw coalescing mock tests passed")
