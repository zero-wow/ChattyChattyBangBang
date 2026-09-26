# Manual Retail acceptance matrix

Use this only for observations in a real Retail client. Mocks and a valid
stage are prerequisites, not a pass for any row below. Record the client build,
addon package hash from `.ccbb-deployment.json`, test character/profile,
tester, and date before changing a row. Capture concise evidence or a
reproduction note without pasting private chat content. Recheck affected rows
after a fix; do not carry an old pass across changed runtime files.

**Run record:** Client build: _not recorded_ · Package hash: _not recorded_ ·
Profile: _not recorded_ · Tester/date: _not recorded_

Status key: ⬜ Not run · 🟨 In progress · 🟩 Pass · 🟥 Fail · 🚫 Blocked.
Critical rows must pass before calling this a safe replacement. Keep failures
visible until retested. This matrix requires manual actions; no tool should
automate `/reload` or scan game logs for it.

| ID | Critical | Manual scenario and expected result | Status | Evidence / date |
| --- | --- | --- | --- | --- |
| M01 | Yes | Fresh install loads on Retail with Smart Chat visible and usable; no missing-file prompt or duplicate addon copy. | ⬜ | — |
| M02 | Yes | Existing SavedVariables profile migrates without losing views, settings, blocked review, or history. | ⬜ | — |
| M03 | Yes | Say, party, raid, instance, guild, officer, channel, loot, system, and whisper lines each remain visible once in the intended view. | ⬜ | — |
| M04 | Yes | General sale routes to Trade by default; an explicit General mirror shows one canonical line in both views without duplicate history. | ⬜ | — |
| M05 | Yes | Unknown whisper is held discreetly, approved into Messenger once, or blocked without leaking into normal views, alerts, or unread counts. | ⬜ | — |
| M06 | Yes | During chat-messaging lockdown, native Blizzard chat becomes readable before withheld content could be lost; no hidden-only copy. | ⬜ | — |
| M07 | Yes | After lockdown, recoverable line IDs return through normal routing; unrecoverable lines keep a readable native fallback until safe to dismiss. | ⬜ | — |
| M08 | Yes | Composer routes say, party, raid, instance, whisper/reply, and channel messages correctly; send and `/tt` work on Retail. | ⬜ | — |
| M09 | No | Battle.net/direct and third-party chat output remain visible or are explicitly documented as outside capture. | ⬜ | — |
| M10 | Yes | Clear History, retroactive block, and the 201st Messenger message update visible lines and NEW/unread badges without jumping the reader unexpectedly. | ⬜ | — |
| M11 | No | At maximum retained history, Smart Chat and Messenger Older/Newer/Latest paging, wrapping, scrolling, and route changes remain responsive and accurate. | ⬜ | — |
| M12 | Yes | Repeat-ad and burst controls suppress intended public spam without treating normal repeated conversation as an ad; archive review remains available. | ⬜ | — |
| M13 | Yes | Block rules, server/local ignore, approvals, and blocked-message review produce the promised result with no lost only-copy. | ⬜ | — |
| M14 | Yes | Messenger friend, invite, reply, local ignore, server ignore, and send actions use working Retail APIs and show failures honestly. | ⬜ | — |
| M15 | No | Alerts render and play configured sounds without unsupported API errors. | ⬜ | — |
| M16 | Yes | Simple/Advanced settings, Messenger, and Smart Dock fit the smallest supported size in every disclosed state; no overlap, clipping, border hits, or off-panel controls. | ⬜ | — |
| M17 | No | Modules list and inspector update when each Smart feature toggle changes; blocked native fallback never reads as ready. | ⬜ | — |
| M18 | Yes | Combat and protected-frame interactions do not taint chat controls, block input, or prevent native fallback from being revealed. | ⬜ | — |
| M19 | Yes | After a manual in-game `/reload`, settings and retained history return; no duplicate capture, stale fallback, or startup-only error. | ⬜ | — |
| M20 | No | High-traffic play with other common addons remains responsive and readable; test conflict warnings and fallback behavior. | ⬜ | — |
| M21 | Yes | A first-contact Battle.net stranger is held by account ID before normal chat/Messenger; a verified friend bypasses review, and approval releases exactly one line. Test same display name on two IDs and an unavailable friend lookup. | ⬜ | — |
| M22 | Yes | Change one source limit and the optional total history cap; only explicitly reduced history is pruned, oldest-first, and the surviving lines match after a manually triggered `/reload`. | ⬜ | — |
| M23 | Yes | Turn off future WoW and Battle.net private-history saving separately; current-session Messenger still shows replies, prior saved lines remain until the scoped two-click clear, and cleared copies stay gone after `/reload`. | ⬜ | — |
| M24 | No | Spam Firewall POLICY export contains no names, message text, drafts, or blocklists; Preview never applies, stale edits refuse Apply, and a confirmed import visibly refreshes the firewall. | ⬜ | — |
| M25 | No | Item/spell hover previews appear only when enabled, hide on leave, and do not override another tooltip; a Group Finder INVITE link acts only on explicit click of a still-visible eligible message. | ⬜ | — |
| M26 | No | FIND > ALERTS shows only current-session retained alerts, drops blocked/evicted entries, and does not offer inbox copy/export. | ⬜ | — |
| M27 | No | A linked alt-name group expands only exact player HISTORY results; ordinary FIND, whisper approval, ignore, and block behavior remain separate. Test accented and realm-qualified names. | ⬜ | — |
| M28 | No | Semantic Routes BATCH EDIT stages Trade/LFG/PvP switches until Apply, Cancel leaves them unchanged, and a successful Apply updates displayed routes and unread badges without duplicated lines. | ⬜ | — |
| M29 | No | At narrow and normal chat widths, alternating backgrounds leave visible top and bottom room around single-line and wrapped entries; bands clip cleanly at viewport edges and do not move text into the scrollbar lane. | ⬜ | — |
| M30 | No | `/ccbb` opens settings without a SetSize Lua error at normal and compact UI sizes; `/ccbb tabs` still enters keyboard navigation. | ⬜ | — |
| M31 | No | In Guild/Officer chat, known player names use class colors, unknown senders remain visibly distinct, achievement notices color only the player and preserve the achievement link, and a narrow chat keeps a shortened player label until the message-only threshold. | ⬜ | — |

The [replacement audit](RETAIL_REPLACEMENT_AUDIT.md) explains the product
invariants behind these checks. The [local test inventory](RETAIL_TESTING.md)
tracks mock coverage separately from client acceptance.
