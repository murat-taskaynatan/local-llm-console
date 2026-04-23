# Local LLM Console

Local LLM Console is a standalone Linux desktop app for local LLMs with a Codex Desktop-derived UI and a self-bootstrapping install flow.

This repository includes the Local LLM Console launchers, patched webview, desktop integration files, icon assets, an X11 title fix, a local model catalog, and the scripts needed to generate `codex-app/` locally from upstream assets.

## What This Repo Is

- A Codex Desktop app fork layer for local models
- A portable copy of the Local LLM Console launchers and UI patches
- A local-model catalog and desktop launcher/icon bundle
- A self-bootstrapping installer that generates the Linux app locally

## What This Repo Is Not

- Not an OpenAI-hosted Codex cloud client

## Included

- `codex-app/start-local.sh`
  Local launcher that rebuilds and runs the Local LLM Console runtime against the generated local app runtime
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
- `install.sh`
  Standalone installer that builds `codex-app/` locally
- `scripts/`
  Builder support scripts used by the installer
- `webview/`
  The patched Local LLM Console webview snapshot

## Usage

Install dependencies if needed:

```bash
bash scripts/install-deps.sh
```

Build the app:

```bash
./install.sh
```

Launch it:

```bash
./launcher/local-ai-console-launch
```

If you already have a local `Codex.dmg`, you can point the installer at it:

```bash
./install.sh /path/to/Codex.dmg
```

## Optional Local Setup

Put the launcher on your `PATH`:

```bash
ln -sf "$PWD/launcher/local-ai-console-launch" ~/.local/bin/local-ai-console-launch
ln -sf "$PWD/launcher/codex-local-desktop-cli" ~/.local/bin/codex-local-desktop-cli
```

Install the desktop file:

```bash
cp desktop/local-ai-console.desktop ~/.local/share/applications/
```

The desktop file expects `local-ai-console-launch` to be available on `PATH`, and it assumes you have already run `./install.sh`.

## Models

The included local model catalog is configured for local Ollama models.

The generated app uses the local CLI wrapper for Ollama:

```bash
codex --disable plugins -c 'model_provider="ollama"'
```

## Notes

- This repo intentionally contains the Local LLM Console layer plus the builder needed to generate its own local app runtime.
- It builds its own `codex-app/` locally instead of requiring a preinstalled base app.
- The regular cloud Codex Desktop app is out of scope here.
