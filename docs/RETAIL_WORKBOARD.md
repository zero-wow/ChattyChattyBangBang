# Chatty Retail workboard

This is the source-of-truth checklist for the 100-item Retail audit. It tracks implementation, not a background scan. No `/rl` or log inspection happens unless Zero requests it. The protected 3.3.5 `main` branch is out of scope.

**Status key:** 🔴 Queued · 🟡 In progress · 🟢 Code complete and locally verified · 🟣 Awaiting in-game validation · ⚪ Audit claim invalidated by source recheck · ⚫ Blocked or decision needed.

**Current focus:** fix message loss, stale visibility, and whisper-safety state first. A green item means its code and focused local checks passed; it does **not** mean it was tested inside WoW. Purple is for work that cannot be considered locally complete until Zero validates it in-game.

**Progress:** 57/100 locally verified; 1 audit claim invalidated. **Retail base version:** 2.26.1 (unchanged).

## Add — missing capabilities

| ID | Status | Feature |
| --- | --- | --- |
| A01 | 🟡 | Known event-registration failures now reveal Blizzard chat and Overview shows tracked coverage; direct add-on output and untracked native notices can still be hidden until A02 or a broader fallback policy is solved. |
| A02 | 🟡 | Feasibility review: existing opt-in DebugMessage bridge is safe; blanket ChatFrame:AddMessage interception also sees normal chat and risks duplicates. Scoped adapter design pending. |
| A03 | 🟢 | First-class Battle.net Messenger sessions and replies, keyed by account ID; mocked identity, send, and failure paths pass. In-game behavior remains unverified. |
| A04 | 🟢 | Account-ID quarantine retains first contacts before native hiding; only verified friends bypass, unsafe payloads stay visible. In-game behavior remains unverified. |
| A05 | 🟢 | Readable Community chat now routes with stable club/stream source IDs, defaults to General, and preserves saved source choices; focused mocks pass. Lockdown fallback and in-game behavior remain unverified. |
| A06 | 🟢 | Messenger distinguishes local failure, pending send, client echo, and no echo without claiming delivery; failed sends retain the draft. |
| A07 | 🟢 | Messenger pages 200 records at a time, preserving per-tab scroll/drafts/NEW; 450-entry rollover and small-window mocks pass. |
| A08 | 🟢 | New Channels shows passively learned public/Community sources; Add Tab, Ignore, and deletion choices preserve existing views. Focused config/routing mocks pass. |
| A09 | 🟢 | FIND searches retained normal chat by text, sender, source, date, or current tab with bounded paging and a full-message preview; blocked/held private records stay separate. Search and compact-layout mocks pass. |
| A10 | 🔴 | Sender-history view from player actions. |
| A11 | 🔴 | Bookmarks for retained messages. |
| A12 | 🔴 | Copy one message and bounded transcript selection/export. |
| A13 | 🟢 | Safe plain-text web addresses become copy-only links in displayed chat; saved text and WoW hyperlinks remain unchanged. Narrow-popup and link mocks pass. |
| A14 | 🔴 | Optional hyperlink-hover previews in Smart Chat and Messenger. |
| A15 | 🔴 | Invite-link actions in message text. |
| A16 | 🔴 | Optional persistent unsent Messenger drafts. |
| A17 | 🔴 | Optional persistent per-tab composer routes. |
| A18 | 🔴 | Smart Chat send/command history recall. |
| A19 | 🔴 | Chat logging controls with private-channel exclusions. |
| A20 | 🔴 | Different history limits per source. |
| A21 | 🔴 | Privacy-specific whisper/Battle.net retention. |
| A22 | 🔴 | Safe import/export of non-sensitive policies. |
| A23 | 🔴 | Alert inbox linked to retained messages. |
| A24 | 🔴 | User-entered alt-name associations. |
| A25 | 🔴 | Advanced scoped highlight rules. |

## Fix — incorrect behavior and safety risks

| ID | Status | Fix |
| --- | --- | --- |
| F01 | ⚪ | Prior nil-icon claim invalidated: current NEW helper does not access an icon; behavioral regression test added. |
| F02 | 🟢 | Clear History ID reuse can hide new whispers in open Messenger. |
| F03 | 🟢 | Retroactively blocked whispers remain in open Messenger. |
| F04 | 🟢 | Retroactive blocks leave unread/NEW counts overstated. |
| F05 | 🟢 | Failed whisper-filter setup incorrectly leaves guard enabled. |
| F06 | 🟢 | Approving held whispers may discard uncaptured text. |
| F07 | 🟢 | Recovery shutdown leaves stale unresolved state. |
| F08 | 🟢 | Partial spam-filter registration can misreport full protection. |
| F09 | 🟢 | Messenger's 201st message jumps reader to bottom and clears NEW. |
| F10 | 🟢 | Repair Retail Add Friend action; in-game click verification remains. |
| F11 | 🟢 | Repair Retail Server Ignore dispatch and keep Messenger open on local failure; in-game verification remains. |
| F12 | 🟢 | Repair Retail Invite action; in-game click verification remains. |
| F13 | 🟢 | Use Retail Messenger send API with legacy fallback; in-game send verification remains. |
| F14 | 🟢 | Use SoundKit alert sound and fallback on failure; in-game audio verification remains. |
| F15 | 🟢 | PvP composer uses Retail INSTANCE_CHAT when in an instance group; in-game verification remains. |
| F16 | 🟢 | Detect instance groups and accept INSTANCE_CHAT composer route; in-game verification remains. |
| F17 | 🟢 | Clear History leaves SmartDock unread/NEW markers. |
| F18 | 🟢 | Request Retail guild roster and trust only explicit membership; first-load/cross-realm check remains. |
| F19 | 🔴 | Guard legacy Player Names raid/party API use if fallback enabled. |
| F20 | 🔴 | Guard absent GuildFrame in legacy Alt Names fallback. |
| F21 | 🔴 | Correct Chat Tabs noMouseAlpha restoration if fallback enabled. |
| F22 | 🔴 | Remove hard-coded level-80 limit in Player Names fallback. |
| F23 | 🟢 | Modules status must honor each Smart Chat feature toggle. |
| F24 | 🟢 | Do not call unavailable native fallback “ready.” |
| F25 | 🟡 | Added channel-notice capture plus guarded localized status, ping, Battle.net toast, and channel-notice formatting with focused fixtures; other synthetic native output and in-game payload behavior remain to audit. |

## Improve — reliability, scale, and workflow

| ID | Status | Improvement |
| --- | --- | --- |
| I01 | 🟢 | Per-line rendering reuses prepared settings while the public getter keeps its normalization contract; profile-swap and direct-edit mocks pass. |
| I02 | 🟢 | Blocked archive full-prunes on first use, expiry, bounds change, or explicit review rather than each blocked line; mocks pass. |
| I03 | 🟢 | Messenger queries bounded 200-record pages from a per-partner rank index instead of scanning the full transcript; frozen-page and source-cap mocks pass. |
| I04 | 🟢 | Per-partner history index updates on append, eviction, retroblock, and reclassification; Contents exclusions and reroutes retain view-membership parity in focused mocks. |
| I05 | 🔴 | Add an aggregate history budget across sources. |
| I06 | 🟢 | Short-lived memory-only social trust cache cuts repeat roster checks, invalidates on roster/profile changes, and fails closed when membership is unverified; whisper mocks pass. |
| I07 | 🟢 | Messenger's 12-tab limit evicts only disposable inactive tabs; drafts, unread, NEW, and unresolved sends stay protected. If all tabs are protected, a bounded notice explains why a new tab was not opened; focused mocks pass. |
| I08 | 🔴 | Unify message visibility and unread-count membership logic. |
| I09 | 🔴 | Batch route edits before retained-history reclassification. |
| I10 | 🔴 | Coalesce rapid full-display redraws. |
| I11 | 🟢 | Periodic global cleanup avoids full sweeps on every line while the observed term keeps exact rolling expiry; focused threshold and sweep-count mocks pass. |
| I12 | 🟢 | The 64 learned sources favor recent use and protect explicit tab choices; persisted recency is sampled, not rewritten per line. Retention mocks pass. |
| I13 | 🔴 | Preserve route-decision provenance: “then” versus “now.” |
| I14 | 🔴 | Add precise alert matching and a match preview. |
| I15 | 🔴 | Adapt repeated-ad vocabulary beyond English openings. |
| I16 | 🔴 | Make keyword discovery Unicode/language aware. |
| I17 | 🔴 | Clarify and control suggestion-data retention scopes. |
| I18 | 🔴 | Explain total history footprint beside per-source capacity. |
| I19 | 🔴 | Make recovery status actionable without persisting message bodies. |
| I20 | 🟢 | Manual Retail acceptance matrix added; every in-game row remains Not run. |
| I21 | 🟢 | One documented local test command and coverage inventory; full local runner passes. |
| I22 | 🟢 | Staged TOC/XML/Lua/media references validated, with negative fixtures. |
| I23 | 🟢 | Package manifest records dirty-tree provenance and a content hash. |
| I24 | 🟢 | Dormant legacy modules excluded from Retail packages. |
| I25 | 🟢 | Retail README and dual-client workflow docs updated. |

## Polish — appearance and clarity

| ID | Status | Polish |
| --- | --- | --- |
| P01 | 🟢 | Settings keep normal text/control size at 700×500, using a scrollable page and temporary PAGES drawer; compact-layout mocks pass. |
| P02 | 🟢 | Sidebar width follows measured labels and preserves page width, with full-name tooltips; wide-font mocks pass. |
| P03 | 🟢 | A slim colorway scroll cue appears only when sidebar content overflows and tracks its position; viewport mocks pass. |
| P04 | 🟢 | Settings close target is 30×30, with an 8px header inset and a checked minimum physical hit size; layout mocks pass. |
| P05 | 🟡 | Settings shell now has measured sidebar/divider and symmetric page gutters; every dynamic subpage/disclosure state still needs bounds review. |
| P06 | 🟢 | Shared settings-control gap increased to 6px; existing right-gutter and viewport bounds mocks pass. |
| P07 | 🟡 | Fixed-width labels now recheck clipping after font changes and reveal full text in tooltips; safe expansion/wrapping remains. |
| P08 | 🟡 | Selected tabs now have a distinct hover state; keyboard-focus navigation and visible focus remain. |
| P09 | 🟢 | Start Here has seven clickable numbered steps in a compact two-row map; 700×500 bounds mocks pass. |
| P10 | 🟢 | Start Here preview uses live chat typography/source colors and the chosen message-band treatment; appearance mocks pass. |
| P11 | 🟢 | Wrapped preview lines grow their transcript surface and scrollable page; long-copy mocks pass. |
| P12 | 🟢 | Hints, warnings, and notes grow with their copy instead of clipping; long-copy mocks pass. |
| P13 | 🟢 | Option rows measure toggle labels and explanations, keeping the footer below them; wide-font layout mocks pass. |
| P14 | 🔴 | Replace repeated explanatory prefixes with cleaner hierarchy. |
| P15 | 🟢 | Messenger's Go to Bottom arrow has a 16×18 target in its own 26px right lane; compact-window layout mocks pass. |
| P16 | 🔴 | Add units and breathing room to sale-ad numeric settings. |
| P17 | 🔴 | Label each colorway swatch's role. |
| P18 | 🔴 | Reveal full colorway descriptions on hover. |
| P19 | 🔴 | Use one selected-theme indicator, not ACTIVE plus CURRENT. |
| P20 | 🔴 | Enlarge/clarify theme pager controls. |
| P21 | 🟢 | Main chat's invisible scrollbar drag lane is 16px while its themed thumb stays 6px; bounds and theme mocks pass. |
| P22 | 🟢 | Main chat's END action has a 24×20 target and a separate right lane; compact-layout mocks pass. |
| P23 | 🟢 | Messenger's Older/Newer/Latest controls have larger targets and a reserved row that releases when unused; 300×160 layout mocks pass. |
| P24 | 🟢 | Alert text, dismiss target, and reserved row now have explicit border/separation gutters; transient-layout mocks pass. |
| P25 | 🟢 | Messenger tabs, action buttons, pager, close controls, and ACT/ACTIONS toggle have explicit gutters and tooltips; compact-layout mocks pass. |
