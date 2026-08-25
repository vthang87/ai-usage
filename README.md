# AI Usage

Menu bar app for macOS that shows **Codex** and **Cursor** usage on this machine — percent used, reset time, and online/offline. No AI Usage server, no account for this app.

The menu bar title is the highest usage percent. Click it for a compact breakdown; open the Dashboard for the full view. Small and Medium widgets sit on the desktop.

[Latest release](https://github.com/vthang87/ai-usage/releases/latest) · macOS 14+

## What it shows

| Source | Windows |
| --- | --- |
| **Codex** | 5 Hour and Weekly rate limits from the Codex CLI |
| **Cursor** | Cursor Models and Other Models for the current billing period |

Each row includes usage %, time until reset, and whether that tool is reachable.

Refresh is automatic (default **5 minutes**, 1–15 in Settings), at launch, after wake, and when you press Refresh. Keep the app in the menu bar; quitting stops collection.

## Install

1. Download `AI-Usage-*.dmg` from [Releases](https://github.com/vthang87/ai-usage/releases/latest).
2. Open the disk image and drag **AI Usage** into Applications.
3. First launch: **right-click → Open** (ad-hoc signed, not notarized). Gatekeeper will warn once.
4. Leave it running in the menu bar.

Later versions: use **Install** in the menu bar (or Settings). The app downloads the release DMG, replaces itself, and relaunches. The first copy into `/Applications` may ask for an admin password; later in-app updates should not. First launch of an ad-hoc build can still need **right-click → Open**.

### Widgets

Right-click the desktop → **Edit Widgets** → add **AI Usage** (Small or Medium).

The host app writes a snapshot the widget can read. If a widget shows “No data”, open the menu bar popover and press **Refresh**.

## Requirements

- macOS 14 or later
- [Codex CLI](https://github.com/openai/codex) (`codex` on `PATH`, or `/opt/homebrew/bin/codex`)
- [Cursor](https://cursor.com) installed and signed in, with the `agent` / `cursor-agent` CLI available (typically `~/.local/bin`)

The app is a menu bar extra (no Dock icon). Universal binary: Apple Silicon and Intel.

## How it works

```text
Codex CLI (app-server JSON-RPC)
Cursor (local token → Cursor usage API)
        │
        ▼
   Menu bar app (collector)
        │
        ├── snapshot.json
        ▼
   Menu bar / Dashboard / Widget
```

- **Codex** — runs `codex app-server --stdio` and reads `account/rateLimits/read`. Fully local.
- **Cursor** — uses the login already on this Mac (`agent status` and/or Cursor’s local state database), then calls Cursor’s dashboard usage API. This app does not store your password.
- **Widget** — sandboxed; it only reads the snapshot the host app writes. No network from the widget.

## Build from source

You need [Xcode](https://developer.apple.com/xcode/) and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
make install   # Release build → /Applications, then launch
make dmg       # dist/AI-Usage-<version>.dmg
make test      # parser tests
make open      # generate the Xcode project and open it
```

Signing is ad-hoc (`codesign --sign -`). A paid Apple Developer ID is only required for notarization or the App Store.

## Release

Pushing a `v*` tag (for example `v0.0.3`) runs GitHub Actions on **macOS 26 / Xcode 26**: parser tests, Release build, DMG, then attaches `AI-Usage-<version>.dmg` to the GitHub Release.

The tag must match `MARKETING_VERSION` in `project.yml` (`v0.0.3` ↔ `0.0.3`).

```bash
# bump MARKETING_VERSION / CURRENT_PROJECT_VERSION in project.yml, then:
git tag v0.0.3
git push origin master v0.0.3
```

Manual run (build only, no GitHub Release): **Actions → Release → Run workflow**.

## Out of scope (for now)

History, charts, and other tools (Claude, Gemini, Copilot).
