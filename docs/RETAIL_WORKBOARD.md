# Chatty Retail workboard

This is the source-of-truth checklist for the 100-item Retail audit. It tracks implementation, not a background scan. No `/rl` or log inspection happens unless Zero requests it. The protected 3.3.5 `main` branch is out of scope.

**Status key:** 🔴 Queued · 🟡 In progress · 🟢 Code complete and locally verified · 🟣 Awaiting in-game validation · ⚪ Audit claim invalidated by source recheck · ⚫ Blocked or decision needed.

**Current focus:** fix message loss, stale visibility, and whisper-safety state first. A green item means its code and focused local checks passed; it does **not** mean it was tested inside WoW. Purple is for work that cannot be considered locally complete until Zero validates it in-game.

**Progress:** 94/100 locally verified; 5 in progress; 0 queued; 1 audit claim invalidated. **Retail base version:** 2.26.1 (unchanged).

## Add — missing capabilities

| ID | Status | Feature |
| --- | --- | --- |
| A01 | 🟡 | Known event-registration failures now reveal Blizzard chat and Overview shows tracked coverage; direct add-on output and untracked native notices can still be hidden until A02 or a broader fallback policy is solved. |
| A02 | 🟡 | Senderless Blizzard client notices can now recover by line ID after lockdown; player-authored lines still require a sender. Existing opt-in DebugMessage bridge is safe, but direct third-party AddMessage output still lacks a reliable source; blanket interception risks duplicates. In-game payload behavior remains unverified. |
| A03 | 🟢 | First-class Battle.net Messenger sessions and replies, keyed by account ID; mocked identity, send, and failure paths pass. In-game behavior remains unverified. |
| A04 | 🟢 | Account-ID quarantine retains first contacts before native hiding; only verified friends bypass, unsafe payloads stay visible. In-game behavior remains unverified. |
| A05 | 🟢 | Readable Community chat now routes with stable club/stream source IDs, defaults to General, and preserves saved source choices; focused mocks pass. Lockdown fallback and in-game behavior remain unverified. |
| A06 | 🟢 | Messenger distinguishes local failure, pending send, client echo, and no echo without claiming delivery; failed sends retain the draft. |
| A07 | 🟢 | Messenger pages 200 records at a time, preserving per-tab scroll/drafts/NEW; 450-entry rollover and small-window mocks pass. |
| A08 | 🟢 | New Channels shows passively learned public/Community sources; Add Tab, Ignore, and deletion choices preserve existing views. Focused config/routing mocks pass. |
| A09 | 🟢 | FIND searches retained normal chat by text, sender, source, date, or current tab with bounded paging and a full-message preview; blocked/held private records stay separate. Search and compact-layout mocks pass. |
| A10 | 🟢 | Player HISTORY action opens an exact-sender, all-tab preview in the bounded retained-history drawer without changing tabs; blocked records stay excluded. Search/layout mocks pass. |
| A11 | 🟢 | Up to 100 retained-message bookmarks are saved as sequence references, not text copies; eviction, blocking, and clear remove stale references. Search UI and reload mocks pass. |
| A12 | 🟢 | COPY exposes one selected message; EXPORT exposes up to 20 lines/8 KiB from the filtered current results page as selectable Ctrl+C text. Blocked/held/stale lines are excluded, and page export excludes private chat. Arbitrary multi-select/full archive export are not included. Mocks pass. |
| A13 | 🟢 | Safe plain-text web addresses become copy-only links in displayed chat; saved text and WoW hyperlinks remain unchanged. Narrow-popup and link mocks pass. |
| A14 | 🟢 | Optional item/spell-only hyperlink-hover previews in Smart Chat and Messenger; malformed/custom/secret links are rejected and owner-scoped tooltip hide is tested. In-game hover remains unverified. |
| A15 | 🟢 | Group Finder public messages show a click-only [INVITE] link that rechecks the retained, displayed, unblocked record before using the guarded player-invite path; focused mocks pass. In-game click remains unverified. |
| A16 | 🟢 | Opt-in Messenger draft restore is off by default, limited to 12 recipients and 1,024 bytes per draft, and erased on disable/clear/close; privacy and layout mocks pass. |
| A17 | 🟢 | Opt-in Messenger reply-target restore is off by default; it saves only whisper/Battle.net tab targets and selection, not arbitrary chat types or transcript bodies. Restore/layout mocks pass. |
| A18 | 🟢 | Up/Down recalls 100 non-private Smart Chat sends with draft restoration; Alt+Up/Down remains Blizzard's command-history path. Mocks pass; Blizzard's separate history may retain outgoing whispers. |
| A19 | 🟢 | Chatty's SavedVariables chat log now has per-source/total retention and separate future-save exclusions for WoW and Battle.net private chat. Native /chatlog is global and is never represented as privacy-filtered. Local tests pass; in-game behavior remains unverified. |
| A20 | 🟢 | Each source can inherit the 1,000-line default or use an explicit 100–10,000-line limit (up to 128 overrides); old profiles keep their history, and focused runtime/SavedVariables/UI mocks pass. |
| A21 | 🟢 | Chatty-owned WoW and Battle.net private-history saving can be disabled separately for future lines; older saved copies remain until a scoped two-click clear. Current-session Messenger stays visible; rebuild/reload privacy mocks pass. |
| A22 | 🟢 | Spam Firewall POLICY tab exports only bounded scalar protections; import is strict data text with non-mutating preview, paged changes, explicit Apply, and runtime refresh. It excludes messages, identities, lists, drafts, and free text; mocks pass. |
| A23 | 🟢 | FIND > ALERTS opens a session-only inbox of up to 100 retained-message IDs; blocked/evicted/held lines disappear, list rows omit bodies, and inbox copy/export is disabled. Focused mocks pass; in-game behavior remains unverified. |
| A24 | 🟢 | Advanced Player Actions can link exact character names into bounded history-only groups (32 groups, 8 names each). A player HISTORY click reads those exact names together; ordinary FIND and all block, ignore, trust, and whisper-approval rules stay separate. Mocks pass. |
| A25 | 🟢 | Advanced keyword groups can remain global or target one source/displayed tab; mirrored-view rendering uses the actual tab and legacy flat colors cannot leak scoped highlights. Messenger remains global-only. Mocks pass. |

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
| F19 | 🟢 | Dormant Player Names fallback now guards absent raid/party APIs and roster names; focused mock passes. Still excluded from Retail package. |
| F20 | 🟢 | Dormant Alt Names fallback tolerates absent GuildFrame; focused mock passes. Still excluded from Retail package. |
| F21 | 🟢 | Dormant Chat Tabs fallback restores original noMouseAlpha/alpha instead of using the mistyped field; focused mock passes. Still excluded from Retail package. |
| F22 | 🟢 | Dormant Player Names fallback uses the client level cap instead of 80; focused mock passes. Still excluded from Retail package. |
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
| I05 | 🟢 | Optional aggregate history cap defaults off, applies oldest-global eviction only when chosen, and explains that it can reduce per-source retention; old SavedVariables are not silently pruned. Mocks pass. |
| I06 | 🟢 | Short-lived memory-only social trust cache cuts repeat roster checks, invalidates on roster/profile changes, and fails closed when membership is unverified; whisper mocks pass. |
| I07 | 🟢 | Messenger's 12-tab limit evicts only disposable inactive tabs; drafts, unread, NEW, and unresolved sends stay protected. If all tabs are protected, a bounded notice explains why a new tab was not opened; focused mocks pass. |
| I08 | 🟢 | Engine and SmartDock now share route/Contents membership for displayed lines and unread counts, with blocked/local-ignore/held exclusions. Mirror and exclusion mocks pass. |
| I09 | 🟢 | Semantic Routes offers opt-in BATCH EDIT for Trade/LFG/PvP toggles: staged edits apply with one history reclassification, stale drafts are refused, and failure rolls back routes, membership, and unread state. Single switches and Shift > ANALYZE corrections stay immediate; mocks pass. |
| I10 | 🟢 | Theme/chat-color repaint bursts coalesce to one next-frame redraw; new messages, tab changes, paging, and resize remain synchronous, with combat fallback. Redraw mocks pass. |
| I11 | 🟢 | Periodic global cleanup avoids full sweeps on every line while the observed term keeps exact rolling expiry; focused threshold and sweep-count mocks pass. |
| I12 | 🟢 | The 64 learned sources favor recent use and protect explicit tab choices; persisted recency is sampled, not rewritten per line. Retention mocks pass. |
| I13 | 🟢 | Message Analysis shows original THEN and current NOW routes; a compact capture-route snapshot survives reclassification/reload, while old records honestly show Unknown. Mocks pass. |
| I14 | 🟢 | Optional whole-word/phrase alerts and a draft-aware TRY IT match preview preserve old substring rules and never send/save the sample; alert and layout mocks pass. |
| I15 | 🟢 | Repeated public listings with an item link and explicit gold price are caught independent of English sale words; unpriced links and unlinked price chat remain outside the rule. Mocks pass. |
| I16 | 🟢 | Bounded UTF-8 token discovery flows through accepted color terms and whole-word rendering; common Latin, Greek, and Cyrillic case variants work. Full Unicode casefold/NFC are not claimed. Mocks pass. |
| I17 | 🟢 | Keywords settings explain saved queue/sample versus RAM-only observations, offer saved/session-only queue choice, and separate Clear Queue from confirmed Erase Report Data; accepted color groups are preserved. Mocks pass. |
| I18 | 🟢 | Chat Window history shows retained line/source counts and the current sources' aggregate capacity while explaining new-source growth and variable disk size. UI mocks pass. |
| I19 | 🟢 | Start Here offers safe catch-up/native-chat actions and `/ccbbdiag` gives counts and next steps without storing message bodies; unrecoverable client-withheld text is stated plainly. Mocks pass. |
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
| P07 | 🟡 | Selected labels can expand into proven spare width or show a UTF-8-safe ellipsis/full tooltip with gutters; fixed 20–24px grids still need a broader layout pass. Mocks pass. |
| P08 | 🟢 | `/ccbb tabs [page]` enters settings-tab keyboard navigation directly, with focus/propagation guards and a session-only Advanced view that does not change the saved mode. The prior click-first path remains; 700×500 wide-font and command-dispatch mocks pass. In-game behavior remains unverified. |
| P09 | 🟢 | Start Here has seven clickable numbered steps in a compact two-row map; 700×500 bounds mocks pass. |
| P10 | 🟢 | Start Here preview uses live chat typography/source colors and the chosen message-band treatment; appearance mocks pass. |
| P11 | 🟢 | Wrapped preview lines grow their transcript surface and scrollable page; long-copy mocks pass. |
| P12 | 🟢 | Hints, warnings, and notes grow with their copy instead of clipping; long-copy mocks pass. |
| P13 | 🟢 | Option rows measure toggle labels and explanations, keeping the footer below them; wide-font layout mocks pass. |
| P14 | 🟢 | Simple Start Here rows now lead with outcomes, put details in tooltips, and share repeated history-safety context; compact/wide-font layout mocks pass. |
| P15 | 🟢 | Messenger's Go to Bottom arrow has a 16×18 target in its own 26px right lane; compact-window layout mocks pass. |
| P16 | 🟢 | Sale-ad limits use two measured columns, explicit hours/ads/characters units, and value-unit gutters; config layout mocks pass. |
| P17 | 🟢 | Colorway swatches label their BASE/PANEL/ACCENT/GOLD roles, including wide-font fallback; card mocks pass. |
| P18 | 🟢 | Colorway hover shows the full description and swatch legend; tooltip mocks pass. |
| P19 | 🟢 | Colorway cards use one CURRENT/APPLY state instead of competing selection labels; card mocks pass. |
| P20 | 🟢 | Theme paging uses centered PREVIOUS/NEXT controls, page counts, and opens on the active palette page; geometry mocks pass. |
| P21 | 🟢 | Main chat's invisible scrollbar drag lane is 16px while its themed thumb stays 6px; bounds and theme mocks pass. |
| P22 | 🟢 | Main chat's END action has a 24×20 target and a separate right lane; compact-layout mocks pass. |
| P23 | 🟢 | Messenger's Older/Newer/Latest controls have larger targets and a reserved row that releases when unused; 300×160 layout mocks pass. |
| P24 | 🟢 | Alert text, dismiss target, and reserved row now have explicit border/separation gutters; transient-layout mocks pass. |
| P25 | 🟢 | Messenger tabs, action buttons, pager, close controls, and ACT/ACTIONS toggle have explicit gutters and tooltips; compact-layout mocks pass. |
