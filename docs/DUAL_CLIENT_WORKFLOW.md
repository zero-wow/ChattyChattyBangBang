# Retail branch deployment workflow

`D:\Code\Projects\Gaming\WoW\ChattyChattyBangBang-Retail` on the `retail`
branch is the editable Retail source. The protected 3.3.5/Ascension `main`
branch is separate. Never edit the installed Retail addon copy directly.

## Safe local sequence

1. Run `& .\Tools\Run-RetailMocks.ps1` in the Retail source root. This runs
   local Lua mocks and a package smoke test in a unique temp directory; it
   neither opens WoW nor scans logs.
2. Stage an inspectable package with `-StageOnly -StageOutputRoot <existing
   temp directory>`. For example:

   ```powershell
   $reviewRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ccbb-review-' + [guid]::NewGuid().ToString('N'))
   New-Item -ItemType Directory -Path $reviewRoot | Out-Null
   & .\Tools\Deploy-ChattyChattyBangBang.ps1 -StageOnly -StageOutputRoot $reviewRoot
   ```

3. Inspect `$reviewRoot\ChattyChattyBangBang` and its
   `.ccbb-deployment.json`. The stage must have no `Modules` directory;
   `modules.xml` must load no legacy scripts. Remove only this known temp
   review directory when it is no longer needed.
4. Record actual in-client results in the
   [manual acceptance matrix](RETAIL_ACCEPTANCE_MATRIX.md). Mocks cannot
   establish that protected frames, combat lockdown, or live chat APIs work.
5. After verified code is committed and pushed according to project policy,
   deploy only when a live install is requested or ready for testing:

   ```powershell
   & .\Tools\Deploy-ChattyChattyBangBang.ps1 -Target Retail
   ```

The deploy script always builds a fresh staged copy and validates TOC paths,
recursive XML `file` references, staged Lua syntax through local `luac`, the
TOC icon, and generated Messenger/Dock icon families **before** it moves any
live install. The current interface value comes from `Packaging\targets.psd1`.
This local validation checks package integrity, not Retail API correctness or
client rendering.

With `-StageOnly`, the script does not require the live AddOns directory. It
never overwrites an existing stage output. Without `-StageOutputRoot`, a
temporary stage is validated and then removed. A live deployment moves the
previous install to the source tree's ignored `.deploy-backups\Retail` folder
outside `AddOns`, then moves the validated stage into
`D:\Games\World of Warcraft\_retail_\Interface\AddOns\ChattyChattyBangBang`.
No backup copy is left inside `AddOns`, where WoW could load it as a second
addon.

The stage manifest records `sourceCommit` as Git HEAD, plus
`sourceTreeDirty`, `runtimeInputsDirty`, `packagingInputsDirty`,
`packageContentSha256`, and
`packagedAtUtc`. If dirty flags are true, the package includes uncommitted
state and must not be described as exactly that commit. The content hash
identifies the staged runtime files, excluding the manifest itself.

In-game `/reload` and log review are manual acceptance activities only; no
deployment or local test script triggers them automatically. Retail is the
only supported deployment target from this branch.
