# Retail replacement audit

Real-client results belong in the [manual Retail acceptance matrix](RETAIL_ACCEPTANCE_MATRIX.md);
the [local test inventory](RETAIL_TESTING.md) is separate evidence and does not
mark any in-game scenario as passed.

Chatty's product contract is stronger than a chat reskin: every readable line
needs one canonical record, a reasoned destination, an explicit visibility
policy for each tab, a review path for held/blocked content, and a safe fallback
when Retail does not expose enough information. Settings must describe those
effects in player language. `ChattyChattyBangBangDB` is a bounded SavedVariables
table, not an independent database that can restore events the addon never saw.

## Current pipeline and gaps

| Stage | Current behavior | Gap against the replacement promise |
| --- | --- | --- |
| Intake | `MessageEngine:Capture` watches an explicit event list and a narrow local-command bridge; known secret Retail events are queued for line-ID recovery after lockdown. | Unrecoverable secret lines, direct third-party `ChatFrame:AddMessage` output, and events outside the list are not captured. A hidden native frame can conceal them. |
| Safety | `WhisperGuard` holds readable unsolicited character whispers and account-ID Battle.net first contacts in private review; `SpamControl` handles bursts/duplicates and a bounded day-scale public-ad ledger; `BlockControl` archives blocked-rule and firewall drops for review. A daily ad-cap breach purges matching retained normal/saved Chatty copies into Blocked Messages. | Secret whisper text cannot be judged during lockdown. Direct third-party chat-frame output is outside this guard. Already-displayed native or third-party lines and records evicted from Chatty history cannot be erased retroactively. Native filters and review UI still need client validation. |
| Routing | A physical record gets one primary classifier category, optional custom memberships, and independent factual-source feeds. Route Audit explains retained records. Major built-in tabs are provisioned on a fresh profile. | Primary route and source feed used to disagree visibly (a sale in General also appeared in G). Trade-only default plus explicit mirror now has a regression test, but live intake, reload, manual override, unread counts, and every tab need one shared visibility contract. Newly learned niche channels do not yet receive their own suggested tab automatically. |
| Retention | `MessageEngine` keeps 100–10,000 entries per physical source (1,000 by default) in SavedVariables, supports explicit source overrides and an optional total cap, and can stop saving future WoW/Battle.net private lines without hiding the current session. SmartDock offers bounded 400-record Older/Newer/Latest pages. | Real-client paging, wrapped-line hit mapping, privacy controls, and redraw cost still need validation. Retention is finite and cannot cover offline/server loss. |
| Controls | Existing specialist settings remain available; a new Simple desk uses the same canonical settings, with short action/effect copy and an Advanced switch. | Real-client panel bounds, disclosure states, and legibility still need visual validation. The option inventory explicitly marks settings that are planned rather than live. |

## Non-negotiable invariants

1. Do not hide the only readable copy of a chat line. During restricted payloads,
   temporarily reveal native chat; attempt bounded line-ID recovery only after
   lockdown, and keep the fallback visible if recovery fails.
2. One captured message is stored once. Its primary route, custom matches,
   explicit source mirrors, blocks, and unread counts are views over that record.
   A clear sale in General belongs only in Trade by default; an explicit General
   mirror may show the same record in both tabs.
3. A held stranger whisper is not a normal transcript, alert, or Messenger tab
   until approved. Review is discreet and the retained copy is bounded.
4. Repeated public advertisements are controlled across minutes and hours,
   not just a 12-second duplicate window. Ordinary conversation is not treated
   as an advertisement merely because text repeats.
5. Simple and Advanced must operate the same setting. Every Simple control
   explains what Chatty does and what the player will notice; no second policy
   layer should silently override an Advanced choice.

## Architecture to keep building toward

Treat tabs as **queries over one canonical message ledger**, not containers
that physically own or move copies. The stable processing order should be:

`client event -> accessibility/fallback -> identity + privacy gate -> spam/block
decision -> normalization -> primary semantic route + explicit mirrors -> one
bounded record -> paged tab queries and unread/alert consumers`.

Each decision should carry a compact reason so Route Audit and blocked review
can explain it without rerunning a potentially changed classifier. A policy
change can then re-evaluate the retained ledger once, rebuild SavedVariables
from survivors, and update all visible tabs and unread counts together. This
replaces the confusing mental model of manually "moving" a line from one tab
to another. Native-frame visibility is a capability/fallback state layered
around this pipeline, not just a cosmetic hide switch.

## Proof required before calling this a full replacement

- In a real Retail client, compare Chatty with visible Blizzard chat in ordinary
  play, chat-messaging lockdown, high traffic, combat, and after `/reload`.
- Verify whether `C_ChatInfo.GetChatLineText` and sender lookups can retrieve an
  event's nonsecret line ID after lockdown, how long lines survive, and whether
  they survive `/reload`. Blizzard's UI itself passes an event line ID to that
  getter, but published metadata does not promise retention.
- Confirm a restricted native frame can be safely revealed above Smart Dock;
  mocks cannot prove WoW's combat/taint behavior or real frame layering.
- Page through the oldest retained lines at the 10,000-per-source setting;
  test memory, redraw cost, route changes, and removal of blocked records.
- Validate fresh-install setup, existing-profile migration, smallest supported
  panel size, every disclosed state, visible gutters, and both config modes.

The recovery API evidence is in Blizzard UI extracts:
<https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua>
and generated chat API metadata:
<https://github.com/BigWigsMods/WoWUI/blob/live/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua>.
