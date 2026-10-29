---
name: mac-cleanup
description: Scan this Mac for caches, logs, and leftover app data that are safe to remove, report sizes and risk level for each item, and only delete what the user explicitly approves. Use when the user asks to free up disk space, find caches/logs to clear, or clean up their Mac.
---

# Mac Cleanup Scan

## Overview

Find reclaimable disk space on macOS across a fixed checklist of caches, logs, and
leftover app data. This skill is **scan-and-report first, delete-only-on-approval**.

Hard rules:
1. Never delete anything on the first pass. Always run the Scan Phase, present a
   report with sizes and risk tiers, and stop.
2. Only run the Cleanup Phase for items the user explicitly approves. "Clean up the
   safe stuff" approves every `SAFE` item. `CAUTION` and `HIGH RISK` items must be
   approved by name — never batch-approve them implicitly.
3. Re-verify sizes after cleanup and report space actually freed (`du -sh` before/after
   each path, `df -h /` before/after overall).
4. If a path doesn't exist on this machine, skip it silently in the report (don't list
   it as 0 B clutter).

## Risk Tiers

- **SAFE** — Pure cache/log data that regenerates automatically with no data loss.
  Safe to delete in a batch once the user says go.
- **CAUTION** — Regenerates or is reconfigurable, but causes a visible side effect
  (re-login to sites, re-index, re-download, re-sync). Fine to do, but call out the
  side effect and get a yes for that specific item.
- **HIGH RISK** — May contain real user data (messages, media, history) that is not
  guaranteed to be recoverable from elsewhere. Never delete without the user naming
  this exact item after seeing the size. Prefer listing contents over blind `rm -rf`.

## Scan Phase — commands to run (read-only)

Run all of these with `du -sh <path> 2>/dev/null` (skip missing paths) and collect
into one report table: Path | Size | Tier | What it is.

### SAFE

| Path | What it is |
|---|---|
| `~/Library/Caches/*` (per subfolder, sorted by size) | General app/system caches |
| `~/Library/Caches/net.whatsapp.WhatsApp/org.sparkle-project.Sparkle` | WhatsApp's downloaded auto-updater packages |
| `~/Library/Caches/Google/Chrome` | Chrome browser cache |
| `~/Library/Caches/GeoServices`, `~/Library/Caches/com.apple.helpd` | Apple system caches |
| `~/.npm` | npm package cache (`npm cache clean --force` to clear) |
| `~/Library/Application Support/Claude/vm_bundles/` | Claude Code's internal runtime cache — regenerates what it needs, can grow silently to several GB |
| `~/Library/Application Support/Google/Chrome/OptGuideOnDeviceClassifierModel` | |
| `~/Library/Application Support/Google/Chrome/OptGuideOnDeviceModel` | Chrome's on-device Gemini Nano AI model — downloaded silently, ~4GB when fully materialized |
| `~/Library/Application Support/Google/Chrome/optimization_guide_model_store` | |
| `~/Library/Application Support/Google/Chrome/Profile */optimization_guide_hint_cache_store` and `Default/optimization_guide_hint_cache_store` | Chrome per-profile hint cache tied to the on-device model |
| `~/Library/Group Containers/UBF8T346G9.OneDriveStandaloneSuite/FileProviderLogs` | OneDrive file-provider debug logs only (not synced file data) |
| `~/Library/Logs/*` | User-level app/system logs |
| `~/.zsh_sessions/*` | Terminal session-restore state files |
| `~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Logs` | WhatsApp app's own debug logs (not chat data) |
| `find ~/Library/Photos -iname "Syndication.photoslibrary"` | Photos widget/syndication cache used by other apps to show photos — regenerates |
| Ghost app leftovers: for each of `Firefox`, `Opera`, `Windsurf` (and any other app name the user names), check `ls /Applications/<App>.app`; if missing, flag `~/Library/Application Support/<App>` as a ghost-app leftover | Data from apps no longer installed |
| `~/.codex/cache` | Codex CLI cache |
| `~/.cache/*` (per subfolder, sorted by size) | Generic XDG-style cache dir used by various CLI tools |
| `~/.anydesk/thumbnails` | AnyDesk remote-session thumbnail cache |
| `~/.copilot/logs` | GitHub Copilot CLI logs |
| `~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Library/Cache` | WhatsApp app's internal cache (not chat/media data) |
| `~/Library/Application Support/Google/GoogleUpdater` | Google Updater's own cache/downloaded installer cache — redownloads as needed |
| `~/Library/Application Support/Google/Chrome/extensions_crx_cache` | Chrome's cache of downloaded `.crx` extension installers — redownloads on next install/update |
| `~/Library/Application Support/Google/Chrome/component_crx_cache` | Chrome's cache of downloaded component updater packages (e.g. Widevine, root cert lists) — redownloads |
| `~/Library/Application Support/Google/Chrome/*/Service Worker/CacheStorage` (Default and every `Profile *`) | Chrome per-profile Service Worker `CacheStorage` (website offline/PWA caches) |
| `~/Library/Application Support/Google/Chrome/*/Service Worker/ScriptCache` (Default and every `Profile *`) | Chrome per-profile Service Worker script bytecode cache |
| `~/Library/Application Support/Google/Chrome/*/GPUCache` (Default and every `Profile *`) | Chrome per-profile GPU shader cache |
| `~/Library/Application Support/Code/CachedData` | VS Code's compiled-JS/bytecode cache |
| `~/Library/Application Support/Code/logs` | VS Code logs |
| `~/Library/Application Support/Notion/Partitions/notion/Cache/Cache_Data` | Notion (Electron) HTTP cache |
| `~/Library/Application Support/Notion/Partitions/notion/Service Worker/CacheStorage` | Notion Service Worker cache |
| `~/Library/Application Support/Notion/Partitions/notion/Service Worker/ScriptCache` | Notion Service Worker script bytecode cache |
| `~/Library/Application Support/Notion/Partitions/notion/Code Cache` | Notion V8 JS code cache |
| `~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Message/Media` | Local WhatsApp message/media store | May contain media (photos/videos/voice notes) not re-downloadable if since deleted on the sending device or expired (view-once/status) |
| `~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/statusDB` | WhatsApp Status (stories) cache/DB | Local-only status content may not be recoverable once cleared |
| `~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/stickers` | Custom/downloaded sticker packs | Re-downloadable in most cases, but custom-made stickers may not be |
| `~/Music` | User's Music library (Music.app media, GarageBand projects, etc.) | Personal media/original recordings — not a cache, not guaranteed to exist elsewhere; list contents, never batch-delete |
| `~/Movies` | User's Movies library (iMovie projects, screen recordings, home videos, etc.) | Personal media — not a cache, not guaranteed to exist elsewhere; list contents, never batch-delete |

### CAUTION

| Path / Action | What it is | Side effect |
|---|---|---|
| `defaults read com.google.drivefs CacheMaxSizeBytes` then `defaults write com.google.drivefs CacheMaxSizeBytes -int 10737418240` (10GB cap, adjust as desired) plus checking `~/Library/CloudStorage/GoogleDrive-*` size | Google Drive for Desktop materializes cloud-only files locally with no cap by default | Requires Google Drive app restart; caps future growth, doesn't shrink existing files instantly |
| `~/.claude/projects/**/*.jsonl` — list with `find ~/.claude/projects -name "*.jsonl" -exec du -h {} \; \| sort -rh \| head -20` | Saved Claude Code conversation transcripts, one JSONL per session, 8-12MB+ for heavy sessions | Deleting a session file permanently removes that conversation's history/resumability — list candidates, let the user pick which to delete rather than deleting all |
| Extension version cleanup — for each extension ID dir under `~/Library/Application Support/Google/Chrome/Default/Extensions`, list version subfolders with `ls`, keep only the highest version number, list the rest for the user before deleting | Chrome keeps old version folders after an extension auto-updates instead of removing them | An old version folder can still be the one actively loaded if Chrome hasn't restarted since updating, or if the extension was rolled back — quit Chrome first and confirm the kept version matches what's enabled in `chrome://extensions` before deleting siblings |

### HIGH RISK — list contents, do not delete without item-by-item confirmation



## Report Format

Present one table per tier, largest-first within each tier, plus a total. Example:

```
SAFE (safe to clear in one batch)
  1.7 GB  ~/Library/Caches/net.whatsapp.WhatsApp/...Sparkle
  ...
  Subtotal: X GB

CAUTION (confirm each by name)
  ...

HIGH RISK (confirm each by name, contents listed not just size)
  ...

Estimated total reclaimable: X GB
Current free space: X GB free of Y GB (df -h /)
```

Then stop and wait for the user's go-ahead.

## Cleanup Phase — only after explicit approval

For each approved item, run the deletion (`rm -rf <path>/*` to empty a cache dir while
keeping the dir itself, `rm -rf <path>` for a leaf file/bundle, `npm cache clean --force`
for npm). For paths with a `*` wildcard (e.g. Chrome's per-profile Service Worker/GPU
caches), expand and clean each matching profile dir individually. For HIGH RISK items,
`ls` the contents first and have the user reconfirm even after tier-level approval.

For the extension version cleanup: quit Chrome, list version subfolders per extension ID,
confirm the highest version number with the user (cross-check against `chrome://extensions`
if there's any doubt), then `rm -rf` only the older version subfolders — never the
extension ID folder itself or the kept version.

After cleanup:
1. Re-run `du -sh` on every cleaned path to confirm it shrank/is empty.
2. Run `du -sh ~/Library/Caches` (or the relevant parent) to show the new total.
3. Run `df -h /` before/after and report GB freed.
4. Note which apps (Chrome, WhatsApp) will silently regenerate their cache on next
   launch — no action needed from the user.

## Notes

- Sizes above are illustrative categories, not fixed numbers — always measure fresh
  with `du -sh` each run; these folders grow and shrink over time.
- If Chrome or WhatsApp is running when clearing their caches, it's generally safe to
  proceed without quitting them first, but mention it as an option for a cleaner clear.
- Skip any path that returns "No such file or directory" — not every item applies to
  every machine/setup.
