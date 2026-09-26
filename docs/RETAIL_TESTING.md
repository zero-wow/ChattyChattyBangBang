# Local Retail test command and coverage inventory

From the `ChattyChattyBangBang-Retail` source root, run one command:

```powershell
& .\Tools\Run-RetailMocks.ps1
```

The runner discovers every `Tests/*.mock.lua` file, runs each with local
`lua`, then runs `Tests/DeployPackage.mock.ps1`. The package test stages into a
unique temporary directory with `-StageOnly`, validates the staged TOC/XML/Lua
and known media families, checks provenance and legacy-module omission, and
removes only its own temp directory. The runner fails if any test fails. Use
`& .\Tools\Run-RetailMocks.ps1 -List` for the exact current file inventory;
discovery keeps the command current as new mocks are added.

| Coverage area | Representative local tests | What remains manual |
| --- | --- | --- |
| Intake, routing, history, recovery | `RetailCaptureCoverage`, `RetailChatSafety`, `ChatRecovery`, `MessageRouteMove`, `ChatHistory`, `SmartDockHistoryPaging` | Live Retail event payloads, line-ID retention, lockdown, high-traffic behavior. |
| Privacy, spam, blocks, alerts | `WhisperGuard`, `RepeatAds`, `RepeatAdRetroPurge`, `BlockControl`, `BlockedMessageArchive`, `Alerts` | Native filter ordering, combat restrictions, actual sound and social actions. |
| Messenger and Smart Dock | `ConversationWindowsLayout`, `MessengerSettings`, `SmartDockResize`, `SmartDockWrapSafety`, `NewMessageIndicator` | Real frame layering, clipping, controls and hit targets at supported sizes. |
| Settings, views, compatibility | `ControlDesk`, `MessageViewsConfig`, `ModulesConfigLayout`, `ModuleCatalog`, `ClientAPI`, `CompatibilitySocialActions` | Profile migration and enabled-addon conflicts inside a live client. |
| Package integrity | `DeployPackage.mock.ps1` plus `Tools/Test-RetailPackage.ps1` | In-game loading, API availability, taint and interaction with other addons. |

Local `lua`/`luac` are no-client checks; this machine currently uses Lua 5.4.
They cannot certify WoW's Lua runtime, Retail APIs, protected frames, or that
every dynamically computed texture path will resolve. The staged validator
checks the TOC icon and the Messenger/Dock asset families currently assembled
by code. For actual acceptance, record observations in the
[manual matrix](RETAIL_ACCEPTANCE_MATRIX.md). No local test or packaging script
issues `/reload`, launches WoW, or scans game logs.
