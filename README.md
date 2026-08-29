# ChattyChattyBangBang

ChattyChattyBangBang is a chat replacement for Wrath/Ascension clients. It organizes messages into configurable views, keeps direct conversations accessible, and adds spam controls, alerts, semantic routing, themes, and readability tools.

## Install

1. Copy this directory to `Interface\AddOns\ChattyChattyBangBang`.
2. Enable **ChattyChattyBangBang** at the character-select AddOns screen.
3. Open settings with `/chattychattybangbang`.

The addon targets WoW interface `30300` and stores profile data in `ChattyChattyBangBangDB`.

## Development

- Runtime files are listed in `ChattyChattyBangBang.toc`.
- `Tests/` contains no-client Lua regression mocks for routing, settings, and UI contracts.
- Embedded libraries under `Libs/` retain their own copyright and license notices.

This repository intentionally excludes WoW SavedVariables, local editor state, logs, caches, and machine-specific workflow files.
