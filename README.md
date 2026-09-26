# ChattyChattyBangBang — Retail branch

This `retail` branch is the Retail port of ChattyChattyBangBang. Smart Chat owns
the message surface, tabs, Messenger, routing, history, spam/block review, and
settings. The current TOC targets interface `120100`. The protected `main`
branch is the separate 3.3.5/Ascension project; do not copy files between the
branches without a compatibility review.

This is still an in-progress replacement. Local mocks and package validation
do not prove protected-chat-frame safety, taint behavior, or full event coverage
inside WoW. Track that evidence in the
[manual Retail acceptance matrix](docs/RETAIL_ACCEPTANCE_MATRIX.md).

## Local validation and packaging

Run the [single local test command](docs/RETAIL_TESTING.md) before a handoff:

```powershell
& .\Tools\Run-RetailMocks.ps1
```

For an inspectable package without touching the game install, create a new
temporary directory and stage into it:

```powershell
$reviewRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ccbb-review-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $reviewRoot | Out-Null
& .\Tools\Deploy-ChattyChattyBangBang.ps1 -StageOnly -StageOutputRoot $reviewRoot
```

The addon package is at `$reviewRoot\ChattyChattyBangBang`. Staging checks its
TOC, XML includes, Lua syntax, and app-owned media references. Retail staging
replaces `modules.xml` with an empty manifest and **omits** the dormant legacy
`Modules` directory. Do not install this source checkout directly: it retains
those legacy files for branch history and compatibility work.

The staged `.ccbb-deployment.json` records the Git HEAD, whether the source
tree, runtime inputs, or packaging inputs were dirty, and a fingerprint of the
exact staged content. A dirty package is not identical to its recorded HEAD
commit.

See the [Retail workflow](docs/DUAL_CLIENT_WORKFLOW.md) for live deployment
policy and backup behavior. No local test command reloads WoW or reads game
logs.

## Player data and licenses

Profile data lives in `ChattyChattyBangBangDB`; diagnostics use
`ChattyChattyBangBangDiagnosticsDB`. Embedded libraries under `Libs/` retain
their own copyright and license notices. SavedVariables, logs, caches, and
machine-specific state are not part of the package.
