# Chatty Retail configuration control desk: option and copy map

This is the implementation inventory for the Retail `Core/Config.lua` surface. `S` means a control currently present on the Simple desk; `A` means an Advanced-only control; `P` means a planned detailed control whose setting exists but is not yet exposed in the panel. All bindings below are under `profile.smartChat` unless noted. The copy column is the persistent two-part explanation each eventual option row needs: **Chatty does** (mechanism) and **you notice** (visible consequence). Simple and Advanced must edit the same existing key through the existing setter where one is available; switching modes never resets a choice.

Current-stage note: the first Simple control desk implements only its task-front controls. The full existing Advanced pages remain intact while they are replaced section by section. Illustrative transcript lines are labeled examples, not captured chat.

## 1. Take over and access chat

| Mode | Option / binding | Chatty does | You notice / caveat |
| --- | --- | --- | --- |
| S | Use Chatty / `enabled`, `SetSmartChatEnabled` | Starts or stops SmartDock, MessageEngine, and Messenger as a chat surface. | Organized tabs appear when on; native fallback resumes when off. Conflicting chat addons can prevent activation. |
| S | Hide Blizzard chat / `dock.hideNativeChat` | Hides the native frame while SmartDock presents chat, but Chatty can briefly reveal it for restricted lines. | One normal transcript instead of duplicate windows. The temporary fallback and delayed catch-up are best effort, not complete delivery guarantees. |
| S | Best-effort catch-up status / `ChatRecovery:GetStatus()` | Reports restored, waiting, unresolved, and fallback-failure counts. | A missing protected line may be recovered or shown through a temporary native fallback, but neither is guaranteed. Counts are status, not settings. |
| A | Show Chatty dock / `dock.visible` | Shows or hides the Chatty window. | The window disappears/reappears without deleting captured history. |
| A | Collapse Chatty dock / `dock.collapsed` | Reduces the window to compact chrome. | Messages are tucked away until expanded. |
| A | Hide Social button / `dock.hideSocialButton` | Hides Blizzard's small Social/Friends micro button. | Less screen chrome; Friends is still available elsewhere. |
| A | Helper classification tags / `dock.showClassificationTags` | Adds route hints to presented messages. | You see extra topic labels; message routing does not change. |
| A | Dock position and lock / `dock.point,x,y,locked` | Retains the draggable window position and lock state. | Chat stays where placed; locked mode resists accidental movement. |
| A | Window width and height / `dock.width,height` and reset | Resizes SmartDock within guarded bounds. | More/fewer wrapped lines fit; reset restores factory geometry. |
| A | Player class colors / `dock.classColorNames` | Colors Smart Chat sender names by known class, including exact Guild roster matches when the event has no class; unknown Guild senders use one accent. | Guild speakers stand apart from message text; the legacy Player Class Colors module only affects native Blizzard chat. |
| A | Hide realm in names / `dock.hideSenderRealms` | Removes the realm suffix only from visible character sender labels and matching emote/achievement names. | Chat shows shorter names; full sender IDs remain in links, player actions, and history. Off by default for existing profiles. |
| A | Background, border, overall opacity / `dock.transparency.*` and reset | Adjusts separate surface alpha multipliers. | Panel/border soften; overall opacity also fades text and controls. |
| S | Minimap launcher / `launcher.minimap.hide`, `SetMinimapHidden` | Shows a launcher for dock and settings access. | Left click toggles chat; right click opens settings; middle click hides launcher. |
| A | LDB launcher / `Core/Launcher.lua` | Exposes the same launcher to installed LDB displays. | Players with an LDB display can access Chatty there. |
| A | Capture local `/run`, `/script`, `/dump` output / `localCommandOutput.enabled` | Copies only command-scoped native frame prints into Chatty. | Local command results appear in Chatty; ordinary `AddMessage` traffic is not broadly intercepted. |
| A | Local command destination / `localCommandOutput.destination` | Chooses System or the active non-Sync tab as the primary destination. | The output appears where chosen; Sync safely falls back to System. |
| A | Restore after login / `persistHistory`, `SetChatHistoryPersistenceEnabled` | Saves bounded received-chat history by physical source. | Recent allowed lines return after login or reload; retained older lines load in 400-record pages. Held stranger whispers stay separate. Turning this off erases saved history; it cannot recover lines never received. |
| A | Lines saved per source / `historyCapacity` | Sets the per-source history cap. | More/fewer old received lines return; a source consumes no saved space until used. |
| A | Clear history / `ClearChatHistory` | Erases saved/current Chatty transcripts. | Old messages disappear; block/spam rules remain. Destructive and must be confirmed. |

## 2. Tabs, source feeds, and automatic routing

Each tab visibility switch uses `views[id]` and the current `SetViewVisibility` path. Showing/hiding a tab is presentation only; it does not turn MessageEngine capture on/off. Built-ins are created automatically on a fresh profile: all below except Sync are shown by default. Custom tabs are appended when created. `railOrder` changes visual order, not classification.

| Mode | Option / binding | Chatty does | You notice / caveat |
| --- | --- | --- | --- |
| S | General `views.general` | Shows ordinary public/local conversation. | `G` appears; at least one built-in tab is kept visible. |
| S | Sync `views.sync` | Exposes identified add-on protocol traffic. | `SYNC` appears only if enabled; hidden by default to keep human chat quiet. |
| S | Conversations `views.conversations` | Shows whispers and direct replies. | `C`/Chat tab appears; hiding it does not block senders. |
| S | Group `views.group` | Shows party, raid, instance, and warnings. | `GRP` appears. |
| S | Group Finder `views.groupFinder` | Shows matching LFG traffic and its direct source home. | `LFG` appears. |
| S | Guild Invites `views.guildInvites` | Shows GuildRecruitment messages. | `GU INV` appears. |
| S | PVP `views.pvp` | Shows PvP and defense traffic. | `PVP` appears. |
| S | Trade `views.trade` | Shows buying, selling, crafting, services, and Trade channels. | `T` appears; a hidden Trade tab does not make sales safe or erase them. |
| S | Guild `views.guild` | Shows guild/officer chat. | `GU` appears. |
| S | System `views.system` | Shows system messages and local command output. | `SYS` appears. |
| S | Loot `views.loot` | Shows loot, rolls, and money notices. | `LOOT` appears. |
| S | Custom tab `views[customId]` | Shows/hides a saved custom view. | Its tab appears/disappears; saved custom terms remain. |
| A | Drag / UP / DN tab order `railOrder` | Reorders rail presentation. | Tabs move; messages keep their route. |
| A | Tab display name, short key, description `viewOptions[id]` | Changes labels/help text. | Rail text changes, not matching or capture. |
| A | New custom view / `customViews[]` | Saves a named rule with terms and optional source feed. | A new tab appears; maximum 12 custom views. |
| A | Custom terms and rule details / `customViews[].terms` | Adds matching public messages to a view. | Matching lines also appear in the custom tab; term edits can reclassify retained history. |
| A | Delete custom view | Removes that saved rule and tab. | The tab disappears; ordinary source history remains. Confirm destructive action. |
| A | CONTENTS source checkbox / `viewOptions[id].sources[sourceId]` | Adds or excludes a full physical-source feed independent of semantic membership. | All lines from a chosen source can appear in this tab; matching routes can also appear elsewhere. |
| A | General public-source AUTO TOPICS / missing source override | Keeps ordinary public lines in G but excludes Trade-classified sales by default. | A sale can move from G to T even when its broad channel is otherwise a General source. AUTO is not a checked “mirror everything” state. |
| A | General source AUTO HOME / missing override on a normally excluded channel | Keeps that channel in its own normal tab without duplicating it into G. | Checking MIRROR ALL explicitly copies every line into General; the implicit home route is visually unchecked. |
| A | General public-source MIRROR ALL / explicit `sources[sourceId]=true` | Deliberately mirrors the entire channel into G. | Sales can appear in both G and T. Show as an explicit checked override, not an inherited check. |
| A | General public-source HIDDEN / explicit `sources[sourceId]=false` | Excludes the channel's full General feed. | Ordinary lines can leave G; routed memberships may still show in other tabs. Reset Expected restores AUTO. |
| A | Reset Expected CONTENTS / `ResetViewSources` | Removes per-view source overrides. | A tab returns to clean source homes; custom matching/routing rules remain. |
| A | Channel AUTO / SYNC / NORMAL / `sync.sources[sourceId]` | Uses detection, quarantines a full channel in Sync, or forces normal handling. | Protocol-heavy channel traffic changes rail; classification can update retained messages. |
| S | Automatic Trade topic route / `semanticRoutes.trade` | Checks public text for strong transaction evidence. | Recognized sales go to T, not G by default. It is inference, so misses should be auditable. |
| S | Automatic Group Finder topic route / `semanticRoutes.groupFinder` | Checks public text for group-finding evidence. | Matching recruitment lines go to LFG. |
| S | Automatic PVP topic route / `semanticRoutes.pvp` | Checks public text for PvP evidence. | Matching PvP lines go to PVP; direct defense routing remains. |
| A | Semantic rule catalog and thresholds / `GetSemanticRouteCatalog` | Explains executable categories, scores, and evidence. | Players can see why a route qualified without editing hard-coded weights. |
| A | Test a message / `Analyze...` | Runs the classifier against sample text without sending it. | A predicted destination and supporting signals appear. |
| A | Exact route correction / `messageRouteOverrides` | Pins a public message's destination when the player corrects it from Analyze. | Future exact matches use the chosen tab; source feeds can still mirror them. |
| S/A | Route Audit / selected tab, pagination, refresh | Inspects recent records with primary route and source-feed reason. | A player can answer “why is this line in G?” without deleting anything. Audit is read-only. |

## 3. Repetition, floods, and local bans

Current defaults protect public channels and local Say/Yell/Emote; guild, group, whispers, and Battle.net are **not** protected by the Spam Firewall until selected. A first abusive whisper can still be shown even with whisper repeat/flood checks on. The firewall is not a promise of zero toxicity.

| Mode | Option / binding | Chatty does | You notice / caveat |
| --- | --- | --- | --- |
| S | Spam Firewall / `spam.enabled` | Gates duplicate, burst, and escalation rules. | Matching traffic is hidden in selected chats; saved bans/rules remain when off. |
| S | Hide identical repeats / `spam.duplicate.enabled` | Compares normalized messages from one sender across protected chats. | First allowed copy stays; later matching copies disappear. Different text may still show. |
| S | Quiet repeated sale ads / `spam.repeatAds.enabled` | Limits one seller's same public sale ad to four times per rolling day, at least one hour apart. | Over-posted public ads disappear; ordinary chat and whispers are unaffected by this rule. |
| S | Rapid sender flood / `spam.burst.enabled` | Times messages from one sender inside a short window. | A fast stream of different lines is muted temporarily. |
| A | Protected public channels / `spam.scopes.channel` | Includes public channel chat in firewall checks. | Channel adverts are eligible for repeat/flood suppression. |
| A | Protected local chat / `spam.scopes.local` | Includes Say, Yell, and Emote. | Nearby spam is eligible for suppression. |
| S | Protected whispers / `spam.scopes.whisper` | Includes private whispers in repeat/flood checks. | Repeated/rapid whispers can disappear; first abuse may still arrive. Off by default today. |
| A | Protected guild/officer / `spam.scopes.guild` | Includes guild channels. | Repeated guild posts can be filtered; off by default to avoid hiding coordination. |
| A | Protected party/raid/BG / `spam.scopes.group` | Includes group chat. | Group spam can be filtered; off by default. |
| A | Protected Battle.net / `spam.scopes.bnet` | Includes Battle.net private chat. | BNet repeats/floods can be filtered; off by default. |
| A | Duplicate window / `spam.duplicate.window` | Sets seconds during which a copy counts. | Longer windows catch spaced ads; shorter windows forgive repeats sooner. |
| A | Copies allowed / `spam.duplicate.allowedCopies` | Sets visible copies before suppression. | Raising it allows more repeated ads through. |
| A | Minimum message length / `spam.duplicate.minimumLength` | Excludes short strings from duplicate matching. | Tiny legitimate replies are less likely to be hidden. |
| A | Repeats to timed mute / `spam.duplicate.muteAfter` | Escalates repeated suppressed copies into a timed mute. | Zero means hide-only; higher values allow more repeats before mute. |
| A | Sale-ad rolling window / `spam.repeatAds.window` | Sets how long the public seller/ad allowance is counted, in hours. | Longer windows catch more repeated ads across a session/day. |
| A | Sale-ad maximum copies / `spam.repeatAds.maxCopies` | Caps allowed appearances from one seller for the same public ad. | Raising it lets more copies through; reaching the cap moves matching visible copies to Blocked Messages. |
| A | Sale-ad minimum gap / `spam.repeatAds.minimumGap` | Requires time between allowed copies, in hours. | Ads repeated too soon are hidden without clearing earlier visible copies. |
| A | Sale-ad minimum length / `spam.repeatAds.minimumLength` | Exempts short public lines from ad tracking. | Very short legitimate chat is not treated as a sale-ad campaign. |
| A | Case-insensitive match / `spam.duplicate.caseInsensitive` | Ignores letter case when comparing. | Case-changed copies still count as duplicates. |
| A | Collapse spaces / `spam.duplicate.collapseWhitespace` | Normalizes whitespace. | Spaced-out copies still count. |
| A | Strip formatting / `spam.duplicate.stripFormatting` | Compares visible content without link/color noise. | Formatting changes alone do not reset the repeat counter. |
| A | Ignore punctuation / `spam.duplicate.ignorePunctuation` | Removes punctuation during comparison. | Punctuation-edited copies may count; false positives can rise. |
| A | Exempt your own messages / `spam.exemptSelf` | Skips your outgoing lines. | Your own repeated posts remain visible to you. |
| A | Match across protected chats / `spam.duplicate.crossChannels` | Shares sender duplicate history across protected sources. | Moving an advert between G, Trade, and Say does not reset suppression; currently enforced on by migration. |
| A | Burst window / `spam.burst.window` | Counts messages inside the chosen seconds. | Longer windows catch slower floods. |
| A | Burst limit / `spam.burst.limit` | Sets how many posts trigger a mute. | Higher limits tolerate faster normal chat. |
| A | Burst mute duration / `spam.burst.muteDuration` | Sets temporary mute seconds. | A noisy sender stays quiet for that interval. |
| A | Automatic ban escalation / `spam.escalation.enabled` | Turns repeated timed mutes into a persistent local ban. | Habitual offenders disappear from Chatty; this does not alter WoW Ignore. |
| A | Mutes to ban / `spam.escalation.mutesBeforeBan` | Sets strike count for an auto-ban. | Lower values ban locally sooner. |
| A | Strike window / `spam.escalation.strikeWindow` | Limits how long strikes count. | Old behavior eventually stops contributing; zero retains strikes indefinitely. |
| A | Manual ban player / `spam.escalation.bans` | Adds a local sender ban with evidence. | Their messages stop showing in Chatty, not in other addons/WoW chat. |
| A | Ban report / evidence / unban | Shows retained reason and removes a local ban on request. | Players can review and reverse a ban. |
| A | Clear strikes, bans, stats, recent memory | Clears selected firewall state. | Respective evidence/counters disappear; each destructive scope must be explicit. |

## 4. Private messages and player actions

First-contact protection applies to in-game character whispers (`CHAT_MSG_WHISPER`), not Battle.net conversations, and is separate from popup behavior and repeat/flood filtering. Readable stranger whispers are held out of Messenger by default; approved or socially trusted senders pass. Retail-secret text can be unreadable to addons, and the native whisper filter can be unavailable, so this is best-effort protection rather than a promise that no unwanted whisper can appear.

| Mode | Option / binding | Chatty does | You notice / caveat |
| --- | --- | --- | --- |
| S | Hold stranger in-game whispers / `whisperGuard.enabled`, `WhisperGuard:SetProtectionEnabled` | Holds readable first-contact character whispers from non-friends/non-guildmates outside Messenger. | Held senders have no normal conversation popup or unread tab. Approving a sender replays held lines into regular history exactly once, then permits future whispers; locally blocked senders remain out. Battle.net is separate. |
| S/A | Review held whispers / `WhisperGuard:GetStatus/GetSummaries/HandleCommand("show ID")` | Lists sender names/counts and opens only selected held text in a private dialog. | Review is discreet and never prints held bodies into regular chat; held text is capped and expires. The Advanced Messenger Safety section exposes the same toggle/status/review path. |
| S | Auto-open trusted whispers / `conversations.autoOpenWhispers` | Opens Messenger for trusted/approved incoming whispers. | Turning it off retains an allowed conversation tab/unread count without a popup; held strangers remain separate. |
| S | Defer popup in combat / `conversations.deferInCombat` | Queues automatic Messenger openings until combat ends. | A reply can still open immediately; message capture continues. |
| A | Confirm WoW Ignore / `safety.confirmServerIgnore` | Asks before a server-side Ignore list change. | Misclicks cannot silently add a player to WoW Ignore. |
| A | Tell Target `/tt` / `conversations.tellTargetEnabled` | Opens a conversation with the targeted player. | `/tt` works in Chatty; native fallback preference remains separate. |
| A | Focus reply field for `/r` and `/tt` / `conversations.focusReplyFieldOnCommands` | Moves keyboard focus to Messenger's reply box. | Typing goes into the addressed private reply. |
| A | Messenger tab player-name length / `conversations.tabNameMaxLength` | Truncates names on conversation tabs. | More tabs fit; shortened names retain a marker. |
| A | Shared Messenger chrome auto-hide / `conversations.chromeAutoHide` | Sets default idle policy for inherited regions. | Titles/actions/reply field can recede without changing chat capture. |
| A | Title visibility / `conversations.titleBarVisibility` | Chooses inherit/always/mouseover/click/hidden. | Messenger title uses chosen reveal behavior. |
| A | Action visibility / `conversations.actionVisibility` | Chooses inherit/always/mouseover/click/collapsed/hidden. | Reply, Invite, Friend, Chatty Mute, and Ignore controls reveal accordingly. |
| A | Reply composer visibility / `conversations.composerVisibility` | Chooses inherit/always/mouseover/click/hidden. | Reply box uses chosen behavior; explicit reply temporarily reveals it. |
| A | Action style / `conversations.actionButtonStyle` | Uses text or icons. | Same actions look different; their meaning does not change. |
| A | Action-strip orientation / `conversations.actionStripOrientation` | Places actions horizontal/vertical. | Controls rearrange. |
| A | Remember collapsed actions / `conversations.actionStripCollapsed` | Starts action strip closed. | More room for messages; reveal control remains. |
| A | Messenger opacity / `conversations.appearance.transparency` | Adjusts background, border, text, and total opacity. | Private window can be more/less prominent; fading text can reduce readability. |
| A | Messenger target colors / `conversations.appearance.colors` | Applies inherited or custom color to window/title/tabs/chat/reply/border. | Private window surfaces change, not sender/message meaning. |
| A | Player action menu auto-hide / `dock.playerActions.autoHide` | Closes the context menu after idle delay. | Menu gets out of the way; outside click always closes it. |
| A | Player action timeout / `dock.playerActions.autoHideSeconds` | Sets 1–120 second delay. | Menu stays open longer/shorter. |
| A | Chatty Mute action / `safety.localIgnores` | Locally suppresses that player in Chatty. | Their lines stop here; it does not alter WoW's Ignore list. |
| A | WoW Ignore action | Calls the client/server Ignore action after chosen confirmation. | Player is ignored by WoW, beyond Chatty. This is a distinct action, not an automatic spam ban. |

## 5. Message blocks and retained evidence

| Mode | Option / binding | Chatty does | You notice / caveat |
| --- | --- | --- | --- |
| A | Block rules master / `blocks.enabled` | Gates saved text/player/source rules. | Matches are hidden from normal tabs; rules remain saved if off. |
| S/A | Review blocked messages / `blocks.archive.entries` | Lists bounded Block Rule matches and Spam Firewall drops, with their reason. | You can inspect why a line disappeared without turning the protection off. Archive off means future drops are not retained as plaintext. |
| A | Rule name / `blocks.rules[].name` | Labels a saved block. | Easier to recognize/edit; matching unchanged. |
| A | Rule enabled / `blocks.rules[].enabled` | Turns one block on/off. | Its matching text is hidden or restored without deleting the rule. |
| A | Rule text / `blocks.rules[].text` | Defines the expression to match. | Lines containing/matching that text can be blocked. |
| A | Contains vs exact / rule match mode | Sets substring vs full-message equality. | Contains is broader; exact reduces accidental matches. |
| A | Match case / rule case flag | Treats uppercase/lowercase as meaningful. | Exact capitalization can be required. |
| A | Any player vs saved sender / sender keys | Scopes rule to everyone or one identity. | A sender-specific quick block does not automatically silence others. |
| A | All sources vs selected sources / `blocks.rules[].sources` | Limits physical chat sources. | Matching text hides only in chosen feeds. |
| A | All message types vs selected events / `blocks.rules[].events` | Limits event families. | Matching text in other event types remains. |
| A | Create/save/delete rule | Updates the saved rule list. | Rules change immediately; deletion needs clear confirmation. |
| A | Combine repeated UI feedback / `blocks.uiFeedback.coalesce` | Coalesces identical cooldown/action failures. | System tab does not fill with the same short error. |
| A | UI feedback window / `blocks.uiFeedback.window` | Sets the repeat interval. | Wider interval combines more rapid repeats. |
| A | Keep blocked archive / `blocks.archive.enabled` | Retains bounded blocked evidence. | Hidden matches can be reviewed; disabling stops saving future evidence. |
| A | Archive retention days / `blocks.archive.retentionDays` | Expires old entries. | Older blocked text disappears automatically. |
| A | Archive capacity / `blocks.archive.maxEntries` | Caps stored entries. | Oldest evidence rolls off when full. |
| A | Clear blocked archive | Erases saved rule-match and spam-drop text plus times. | Review list empties; block rules and separate spam statistics remain. Destructive. |

## 6. Alerts

| Mode | Option / binding | Chatty does | You notice / caveat |
| --- | --- | --- | --- |
| S | Alerts master / `alerts.enabled` | Gates all saved alert rules. | Notifications stop/start; rules stay saved. |
| S | Reveal chat for alerts / `alerts.popout` | Allows rule matches to reveal the dock. | Important lines can bring chat into view. |
| S | Sound for every alert / `alerts.sound` | Overrides individual rule sound off. | Every matching rule plays sound; leave off for rule-by-rule choice. |
| A | Auto-hide revealed chat / `alerts.autoHideSeconds` | Sets how long an alert reveal remains. | Revealed chat recedes after the chosen delay. |
| A | Rule name / `alerts.rules[].name` | Names an alert. | Easier to identify; no route change. |
| A | Rule enabled / `alerts.rules[].enabled` | Gates one alert. | That notification stops/starts without deletion. |
| A | Rule terms / `alerts.rules[].terms` | Defines words or phrases to watch. | Matching received messages trigger the rule. |
| A | Match all terms / `alerts.rules[].matchAll` | Requires every term instead of any. | Fewer, more specific notifications. |
| A | Add my name | Inserts `[PLAYER_NAME]` dynamic term. | Mentions follow the current character name without hand editing. |
| A | Rule reveal / `alerts.rules[].revealDock` | Asks one rule to reveal chat. | Works only if global reveal is allowed. |
| A | Rule sound / `alerts.rules[].sound` | Plays sound for one rule. | Global sound-for-all can override it. |
| A | All or selected sources / `alerts.rules[].allSources,sources` | Scopes a rule to physical sources. | Same word elsewhere can remain quiet. |
| A | Create/save/delete rule, reset stats | Manages rule list and counters. | Notifications/stats update; destructive actions should name their scope. |

## 7. Readability and appearance

| Mode | Option / binding | Chatty does | You notice / caveat |
| --- | --- | --- | --- |
| A | Theme colorway / `colorway`, `SetColorway` | Applies one existing dark palette to Chatty frames. | All Chatty surfaces recolor live; text meaning stays the same. |
| A | Global text size / `textAppearance.size` | Sets the message font size when not overridden per tab. | Chat grows/shrinks; narrow docks may wrap more. |
| S | Responsive metadata / `dock.responsiveMetadata` | Hides less-essential labels as width shrinks. | Message body keeps room on small windows. |
| S | NEW marker / `dock.newMessages.enabled` | Marks unseen arrivals while reading scrollback. | You can return to the latest line without losing your spot. |
| S | Alternating message bands / `dock.messageBands.enabled` | Adds faint zebra shading per logical message. | Wrapped lines are easier to trace; routing is unchanged. |
| A | Rail visibility / `dock.railVisibility` | Shows tabs always, on hover, on click, or hidden. | Navigation chrome appears according to chosen mode; hidden can make switching harder. |
| A | Rail direction / `dock.railOrientation` | Places tabs vertical or horizontal. | Tab rail moves around the transcript. |
| A | Title visibility / `dock.headerVisibility` | Shows header always/on hover/hidden. | Header controls take more/less room. |
| A | Hide input when idle / `dock.composerAutoHide` | Temporarily hides typing field until Enter/slash/reply. | More space for messages while not typing. |
| A | Typing field border / `dock.editBoxBorder` | Adds an optional raised field surface. | Input looks more separate; no send behavior changes. |
| A | Slim scrollbar / `dock.showScrollButtons` | Shows compact scroll controls. | Easier pointer navigation through history. |
| A | Compact title / `dock.compactHeader` | Reduces header chrome. | More room for transcript. |
| A | Global font / `textAppearance.font` | Chooses inherited chat font or SharedMedia face. | All tabs change unless locally overridden. |
| A | Global outline / `textAppearance.outline` | Changes glyph outline. | Text contrast and perceived weight change. |
| A | Line spacing / `textAppearance.spacing` | Adds pixel space between rendered lines. | Dense chat breathes more; long transcripts use more height. |
| A | Entry gap rows / `textAppearance.entryGapRows` | Inserts blank rows between logical messages. | Individual speakers are easier to distinguish; fewer fit onscreen. |
| A | This-tab font/size/outline/spacing/gap / `viewOptions[id].textAppearance` | Overrides global text only for selected tab. | That tab looks different; reset restores global inheritance. |
| A | Align channel labels / `dock.sourceColumnAlignment` | Uses a fixed-width source lane. | Message bodies begin at a stable column. |
| A | Channel gap / `dock.columnAlignmentSpacing` | Adjusts signed space after source lane. | Aligned transcript becomes tighter/looser. |
| A | Align player names / `dock.senderColumnAlignment` | Uses a fixed-width sender lane. | Body starts after a stable `[NAME]` column. |
| A | Player gap / `dock.senderColumnAlignmentSpacing` | Adjusts signed space after sender lane. | Names and body become tighter/looser without overlap. |
| A | Player name max length / `dock.senderColumnMaxLength` | Truncates overly long sender labels in aligned view. | Narrow tabs preserve message text. |
| A | Visible-only alignment / `dock.alignmentVisibleOnly` | Calculates widths from currently visible logical messages. | Columns adapt while scrolling instead of remembering old wider names. |
| A | Message band extent / `dock.messageBands.extent` | Chooses full or content-lane shading. | Alternating bands cover different widths. |
| A | Bands under scrollbar / `dock.messageBands.extendUnderScrollbar` | Extends stripes beneath scroll lane. | Shading reaches the right edge. |
| A | Band color and alpha / `dock.messageBands.color,alpha` | Changes band tint/strength. | More/less prominent alternating rows; reset restores theme default. |
| A | NEW marker count/cap / `dock.newMessages.showCount,maxCount` | Shows bounded unseen count. | `NEW 7` or `NEW 99+` appears as configured. |
| A | NEW marker position / `dock.newMessages.appearance.position` | Saves marker anchor/drag offset. | Marker moves without changing message order. |
| A | NEW marker font, size, outline, scale, opacity | Styles only the active-view marker. | Its legibility changes; rail unread badges stay separate. |
| A | NEW marker text/background/border colors | Styles marker contrast. | Marker stands out more/less; reset and preview are non-destructive. |
| A | Inactive-tab count size/opacity / `dock.unreadCountAppearance` | Styles unread numbers on inactive tabs. | Tab badges change, not the active NEW marker. |
| A | Client chat-source colors / `Core/ChatColors.lua` | Edits channel/type colors through client color APIs. | Source labels change hue; routing stays the same. |
| A | Keyword color groups / `keywordColorGroups[]` | Colors matched word families in transcript text. | Terms such as WTS, tank, or class names stand out; this is highlight, not routing. |
| A | Group terms/case/color, built-in reset, custom create/delete | Edits the group vocabulary and tint. | Matching highlights change; deleting a custom group removes its color rule. |
| A | Keyword suggestion tracking / `keywordSuggestions.enabled` | Observes candidate words for review only. | A review queue can grow; no new highlight is added automatically. |
| A | Suggestion threshold/review/add/dismiss/clear | Tunes, reviews, and manages candidate queue. | Only explicitly accepted suggestions become highlight terms. Clear removes queued suggestions. |

## 8. Compatibility, tools, and informational pages

| Mode | Option / binding | Chatty does | You notice / caveat |
| --- | --- | --- | --- |
| A | Modules catalog filter/status / `GetModuleCatalog` | Separates Chatty-native, native-fallback-only, and not-yet-adapted features. | Players can tell whether a saved module choice actually runs in Smart Chat. |
| A | Native fallback preference / `profile.modules[name]` | Saves a copied Chatter module choice for native fallback only. | It does **not** enable that module while SmartDock owns chat. |
| A | Smart module shortcut / `SetComposerAutoHide`, `SetEditBoxBorderEnabled`, `SetTellTargetEnabled` | Opens or changes the existing Smart setting owner. | Same live setting, no second copy. |
| A | About | Displays build scope and limits. | No settings change. Retail copy must not claim Wrath/Ascension-only behavior. |

## Mode, setup, and rollout contract

- Simple is the default presentation even for existing profiles. Existing users are **not** auto-opened into a wizard; their hidden Advanced values remain exactly as saved. Advanced is one obvious switch away.
- A genuinely fresh SavedVariables install may open the guided Start Here desk after safe activation; detect freshness before AceDB injects defaults. Keep `configUI.mode` independent from `configUI.setupCompleted`; do not reuse the old welcome-print flag.
- The foundation's chat preview is synthetic and setting-reactive. Never imply it sampled the live transcript. The actual Route Audit is read-only and grounded in retained records.
- Topic routing and physical-source feeds are different. Trade-classified sales leave General by default; explicit `MIRROR ALL` can intentionally duplicate them. A checked box must never represent implicit topic-aware AUTO.
- No copy should promise that all toxic messages are prevented, that Retail-secret stranger text is always readable/held, or that missing client-protected lines are recoverable from SavedVariables. Describe the implemented best-effort guard and fallback honestly.
- Stage 1: inventory and Simple shell with current setters. Stage 2: persisted mode/fresh-install setup metadata and guarded opener. Stage 3: replace each Advanced editor with persistent ELI5 rows, one task group at a time. Stage 4: route/privacy integration, exact runtime QA, minimum-viewport bounds, and Retail in-game validation. Preserve all existing keys and migrations until parity is proven.
