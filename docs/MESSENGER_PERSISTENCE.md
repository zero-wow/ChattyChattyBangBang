# Messenger reply memory (Retail)

Messenger → Tabs contains two independent, default-off choices:

- **Remember unsent replies** keeps only text still in the reply field. It is saved in the current WoW profile under `smartChat.conversations.savedDrafts`, keyed by recipient. The live composer accepts 255 characters; storage is capped at 1,024 bytes per draft and 12 recipients. A saved draft returns when that recipient's tab is opened again. This is private text stored on disk in WoW SavedVariables.
- **Remember reply tabs** keeps at most 12 recipient identities, their tab order, and the selected reply target in `savedReplyTargets`. It restores those tabs after a UI reload without opening the Messenger window. It stores no message or draft body. Unsent text requires the separate choice above.

Turning either choice off immediately erases its stored payload but leaves currently open tabs and text visible. Closing a recipient tab deletes that recipient's saved draft and reply target. **Clear saved replies + tabs** erases both stored payloads; with a choice still enabled, subsequent typing or tab changes can save new state. These choices do not alter chat history, message routing, or stranger-whisper quarantine. SavedVariables are written by WoW at its normal save/reload boundary; no automatic `/rl` or log scan is involved.

Settings API: `addon:GetMessengerSettings()` reports `persistDrafts` and `persistReplyTargets`; `addon:SetMessengerDraftPersistenceEnabled(boolean)` and `addon:SetMessengerReplyTargetPersistenceEnabled(boolean)` change them; `addon:ClearMessengerSavedState()` clears both payloads. The setters reject non-booleans, return `success, value`, and apply to the live Messenger. Old profiles opt out and discard any stray saved payload rather than importing unknown whisper text.
