# Policy transfer core (A22)

`Core/PolicyTransfer.lua` defines a deliberately narrow `CCBB-POLICY/1` text
format. Its only payload is the fixed, ordered list of Spam Firewall switches,
scopes, and bounded numeric thresholds. Every line is `key=value`, terminated
by `\n` (Windows `\r\n` is also accepted). The whole import is capped at
8 KiB. Unknown, duplicate, out-of-order, malformed, and out-of-range entries
are rejected. It is data text, never Lua or an arbitrary table serializer.

The format excludes message/history bodies, sender or recipient identities,
whisper-guard trust/block lists, Spam Firewall offender/ban evidence and
repeat-ad ledgers, Message Block rules and archives, alert terms, keyword
terms, route overrides, custom views, drafts, credentials, and all other
free-text profile content. The old `spam.duplicate.crossChannels` flag is
excluded because runtime duplicate matching is always cross-channel.

The module's pure API is:

```lua
local transfer = ChattyChattyBangBang.PolicyTransfer
local text, err = transfer.Export(settings)
local preview, err = transfer.Preview(settings, pastedText)
local ok, changedOrError = transfer.Apply(settings, preview, "APPLY")
```

`Preview` does not mutate settings. Its `changes` array contains only allowlisted
keys and typed scalar old/new values for a confirmation UI. Invalid current
values are labeled rather than copied into the preview. `Apply` requires the
specific preview object, the same settings table, explicit confirmation, and
unchanged pre-preview values. It validates every destination before writing,
then changes only fields present in the import. Missing fields and every
non-policy setting keep their current values/defaults. A preview is consumed
after successful apply.

The Retail TOC loads the module after `Core/Settings.lua`. Spam Firewall's
POLICY subtab has separate export and import views. Export provides selectable
text; import provides a bounded paste field, changed-field preview with paging,
and a separate Apply button that remains unavailable before a valid preview.
Config obtains the active table from `addon:GetSmartSettings()` at preview and
again at Apply; the transfer module rejects a profile switch or stale touched
value. After Apply, Config refreshes visible firewall controls and calls
`addon.SpamControl:RefreshSettings()` when available. It warns if runtime
refresh fails after settings were saved. Pasting or previewing never applies.

Focused local checks: `lua Tests/PolicyTransfer.mock.lua` and
`lua Tests/PolicyTransferConfig.mock.lua`. This is not a claim of WoW client
testing.
