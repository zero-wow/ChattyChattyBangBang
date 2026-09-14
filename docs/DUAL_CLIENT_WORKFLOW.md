# Retail deployment workflow

`D:\Code\Projects\Gaming\WoW\ChattyChattyBangBang` is the only editable
copy. Do not edit the Retail install directly; a manual edit would drift from
GitHub.

Use this command after committing a shared change:

```powershell
& 'D:\Code\Projects\Gaming\WoW\ChattyChattyBangBang\Tools\Deploy-ChattyChattyBangBang.ps1'
```

Retail accepts addon-file changes while it is running. Deploy whenever needed,
then use `/reload` in-game to load the new files. Use `-StageOnly` when you
only want to validate the package without touching the live copy.

It stages a fresh runtime-only copy, writes Retail's TOC interface value, then
replaces the Retail target. If an install already exists, it is moved to the
source tree's ignored `.deploy-backups\Retail` folder before the new copy is
moved in. Backups never stay inside `AddOns`, where Retail would scan them as
additional addons.
The source checkout, tests, packaging tools, editor files, and Git metadata do
not go into a game folder.  GitHub remains the off-machine recovery history.

Retail is the sole supported deployment target. Client differences belong in
`Core/ClientAPI.lua`; retained Ascension-specific behavior stays isolated in
its provider instead of leaking into the portable message and presentation
code.

The current Retail package is an initial compatibility build.  It has modern
addon-management and configuration guards, but its Smart Dock must still be
smoke-tested in Retail for protected-chat-frame taint before it is called fully
Retail-safe.
