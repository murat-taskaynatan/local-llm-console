# Local LLM Console

Local LLM Console is a local-model-focused Codex Desktop fork layer for Linux.

This repository is not the full upstream Electron app. It is the extracted Local LLM Console customization layer: local launchers, a patched local webview, desktop integration files, icon assets, an X11 title fix, and a local model catalog for Ollama-backed local models.

## What This Repo Is

- A Codex Desktop app fork layer for local models
- A portable copy of the Local LLM Console launchers and UI patches
- A local-model catalog and desktop launcher/icon bundle

## What This Repo Is Not

- Not the full upstream `codex-desktop-linux` source tree
- Not a standalone Electron distribution by itself
- Not an OpenAI-hosted Codex cloud client

Local LLM Console still expects a base Codex Desktop installation. This repo supplies the local-model overlay that sits on top of that base app.

## Included

- `codex-app/start-local.sh`
  Local launcher that rebuilds and runs the Local LLM Console runtime against an installed Codex Desktop base app
- `codex-app/.codex-linux/local-ai-console-x11-title-fix.sh`
  X11 window-title fix for the branded local app window
- `launcher/codex-local-desktop-cli`
  Local Codex CLI wrapper configured for Ollama
- `launcher/local-ai-console-launch`
  User-facing launcher entry point
- `desktop/local-ai-console.desktop`
  Desktop entry template
- `assets/local-ai-console-gradient.png`
  Local app icon
- `config/local-model-catalog.json`
  Local model catalog used by the app
- `webview/`
  The patched Local LLM Console webview snapshot

## Usage

You need an installed Codex Desktop base app.

Two workable layouts:

1. Overlay-in-place
   Copy the contents of `codex-app/` into an existing Codex Desktop `codex-app/` directory and use the repo launchers.
2. External overlay
   Keep this repo separate and point it at the base app with:

```bash
export CODEX_DESKTOP_BASE_APP_DIR=/path/to/codex-app
local-ai-console-launch
```

If your packaged runtime archive is not at `"$CODEX_DESKTOP_BASE_APP_DIR/resources/app.asar"`, also set:

```bash
export CODEX_DESKTOP_SOURCE_ASAR=/path/to/app.asar
```

## Recommended Local Setup

Put the repo launcher on your `PATH`:

```bash
ln -sf "$PWD/launcher/local-ai-console-launch" ~/.local/bin/local-ai-console-launch
ln -sf "$PWD/launcher/codex-local-desktop-cli" ~/.local/bin/codex-local-desktop-cli
```

Then install the desktop file:

```bash
cp desktop/local-ai-console.desktop ~/.local/share/applications/
```

The desktop file expects `local-ai-console-launch` to be available on `PATH`.

## Models

The included local model catalog is configured for local Ollama models.

The CLI wrapper uses Ollama:

```bash
codex --disable plugins -c 'model_provider="ollama"'
```

## Notes

- This repo intentionally contains only the Local LLM Console layer.
- It is maintained as a separate repo rather than inside `codex-desktop-linux`.
- The regular cloud Codex Desktop app is out of scope here.
