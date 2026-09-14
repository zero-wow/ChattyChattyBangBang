# Dual-client workflow

`C:\Users\zero\source\ChattyChattyBangBang` is the only editable copy.  Do
not edit either client install directly: the Ascension launcher can replace its
own files, and a manual retail edit would drift from GitHub.

Use this command after committing a shared change:

```powershell
& 'C:\Users\zero\source\ChattyChattyBangBang\Tools\Deploy-ChattyChattyBangBang.ps1'
```

It stages a fresh runtime-only copy for both clients, writes the target's TOC
interface value, then replaces each target.  If an install already exists, it
is renamed to a timestamped sibling backup before the new copy is moved in.
The source checkout, tests, packaging tools, editor files, and Git metadata do
not go into a game folder.  GitHub remains the off-machine recovery history.

Retail and Ascension share features by default.  Client differences belong in
`Core/ClientAPI.lua`; Ascension-only behavior remains in its provider instead
of leaking into the portable message and presentation code.

The current Retail package is an initial compatibility build.  It has modern
addon-management and configuration guards, but its Smart Dock must still be
smoke-tested in Retail for protected-chat-frame taint before it is called fully
Retail-safe.
