#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE_APP_DIR="${CODEX_DESKTOP_BASE_APP_DIR:-$SCRIPT_DIR}"
BASE_START_SCRIPT="${CODEX_DESKTOP_BASE_START_SCRIPT:-$BASE_APP_DIR/start.sh}"
BASE_ELECTRON_PATH="${CODEX_DESKTOP_ELECTRON_PATH:-$BASE_APP_DIR/electron}"
BASE_RESOURCES_DIR="${CODEX_DESKTOP_RESOURCES_DIR:-$BASE_APP_DIR/resources}"
BASE_SHELL_ASAR="${CODEX_DESKTOP_SHELL_ASAR:-$BASE_RESOURCES_DIR/app.asar}"
BASE_SHELL_ASAR_UNPACKED="${BASE_SHELL_ASAR}.unpacked"
BASE_UPSTREAM_SOURCE_ASAR="${CODEX_DESKTOP_UPSTREAM_SOURCE_ASAR:-$BASE_RESOURCES_DIR/upstream.app.asar}"
BASE_UPSTREAM_SOURCE_ASAR_UNPACKED="${BASE_UPSTREAM_SOURCE_ASAR}.unpacked"
BASE_SOURCE_ASAR="${CODEX_DESKTOP_SOURCE_ASAR:-}"
USER_UID="$(id -u)"

export CODEX_HOME="${CODEX_HOME:-$HOME/.codex-local-desktop}"
export CODEX_CLI_PATH="${CODEX_CLI_PATH:-$REPO_ROOT/launcher/codex-local-desktop-cli}"
export CODEX_DESKTOP_APP_NAME="${CODEX_DESKTOP_APP_NAME:-local-ai-console}"
export CODEX_DESKTOP_CLASS="${CODEX_DESKTOP_CLASS:-local-ai-console}"
export CODEX_DESKTOP_APP_ID="${CODEX_DESKTOP_APP_ID:-local-ai-console}"
export CODEX_DESKTOP_DESKTOP_ENTRY="${CODEX_DESKTOP_DESKTOP_ENTRY:-local-ai-console.desktop}"
export CODEX_DESKTOP_ICON_NAME="${CODEX_DESKTOP_ICON_NAME:-local-ai-console-gradient}"
export CHROME_DESKTOP="${CHROME_DESKTOP:-local-ai-console.desktop}"
export CODEX_DESKTOP_EXPECTED_TITLE="${CODEX_DESKTOP_EXPECTED_TITLE:-Local LLM Console}"
export CODEX_DESKTOP_LOCAL_PROFILE_VERSION="v19"
export CODEX_DESKTOP_LOCAL_RUNTIME_VERSION="v16"
export CODEX_DESKTOP_LOCAL_RUNTIME_PATCH_VERSION="v12"
export CODEX_DESKTOP_LOCAL_WEBVIEW_PATCH_VERSION="v19"
export XDG_CONFIG_HOME="$HOME/.config/local-ai-console/xdg-config-${CODEX_DESKTOP_LOCAL_PROFILE_VERSION}"
export XDG_CACHE_HOME="$HOME/.cache/local-ai-console/xdg-cache-${CODEX_DESKTOP_LOCAL_PROFILE_VERSION}"
export XDG_STATE_HOME="$HOME/.local/state/local-ai-console-${CODEX_DESKTOP_LOCAL_PROFILE_VERSION}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${USER_UID}}"
export CODEX_DESKTOP_WEBVIEW_SERVER_SCRIPT="${CODEX_DESKTOP_WEBVIEW_SERVER_SCRIPT:-$REPO_ROOT/launcher/local-ai-console-webview-server.py}"
export LOCAL_LLM_CONSOLE_CONFIG_PATH="${LOCAL_LLM_CONSOLE_CONFIG_PATH:-$CODEX_HOME/config.toml}"
export LOCAL_LLM_CONSOLE_RELAUNCH_COMMAND="${LOCAL_LLM_CONSOLE_RELAUNCH_COMMAND:-$REPO_ROOT/launcher/local-ai-console-launch}"

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" && -S "${XDG_RUNTIME_DIR}/bus" ]]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
fi

if [[ -z "${DISPLAY:-}" ]]; then
    export DISPLAY=":0"
fi

if [[ -z "${XAUTHORITY:-}" ]]; then
    for candidate in \
        "${XDG_RUNTIME_DIR}/gdm/Xauthority" \
        "$HOME/.Xauthority"
    do
        if [[ -f "$candidate" ]]; then
            export XAUTHORITY="$candidate"
            break
        fi
    done
fi

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    exec "$BASE_START_SCRIPT" "$@"
fi

LOCAL_USER_DATA_DIR="${CODEX_DESKTOP_USER_DATA_DIR:-$XDG_CONFIG_HOME/LocalAIConsole}"
LOCAL_WEBVIEW_SOURCE_DIR="${CODEX_DESKTOP_LOCAL_SOURCE_WEBVIEW_DIR:-$REPO_ROOT/webview}"
LOCAL_WEBVIEW_DIR="$XDG_CACHE_HOME/webview-patched-${CODEX_DESKTOP_LOCAL_PROFILE_VERSION}"
LOCAL_WEBVIEW_STAMP="${LOCAL_WEBVIEW_DIR}.stamp"
LOCAL_RUNTIME_ROOT="$XDG_DATA_HOME/local-ai-console/runtime-${CODEX_DESKTOP_LOCAL_RUNTIME_VERSION}"
LOCAL_RUNTIME_APP_DIR="${CODEX_DESKTOP_LOCAL_RUNTIME_APP_DIR:-$LOCAL_RUNTIME_ROOT/app}"
LOCAL_RUNTIME_STAMP="${LOCAL_RUNTIME_ROOT}/source-stamp.txt"
LOCAL_SHELL_ASAR_STAMP="${LOCAL_RUNTIME_ROOT}/shell-asar-stamp.txt"
LOCAL_RUNTIME_ICON_PATH="${CODEX_DESKTOP_WINDOW_ICON_PATH:-$REPO_ROOT/assets/local-ai-console-gradient.png}"
LOCAL_BOOTSTRAP_SOURCE_PATH="${CODEX_DESKTOP_LOCAL_BOOTSTRAP_SOURCE_PATH:-$REPO_ROOT/webview/assets/local-ai-console-bootstrap.js}"
LOCAL_SOURCE_ASAR=""
export CODEX_DESKTOP_POST_LAUNCH_HOOK="${CODEX_DESKTOP_POST_LAUNCH_HOOK:-$SCRIPT_DIR/.codex-linux/local-ai-console-x11-title-fix.sh}"
LOCAL_HOST_SERVICE_HELPER="${CODEX_DESKTOP_LOCAL_HOST_SERVICE_HELPER:-$REPO_ROOT/launcher/local-ai-console-host-service}"
export LOCAL_LLM_CONSOLE_HOST_SERVICE_HELPER="${LOCAL_LLM_CONSOLE_HOST_SERVICE_HELPER:-$LOCAL_HOST_SERVICE_HELPER}"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$LOCAL_USER_DATA_DIR" "$(dirname "$LOCAL_WEBVIEW_DIR")" "$LOCAL_RUNTIME_ROOT" "$BASE_RESOURCES_DIR"

mapfile -t LOCAL_LLM_CONSOLE_LAUNCH_STATE < <(
  python3 - "$LOCAL_LLM_CONSOLE_CONFIG_PATH" <<'PY'
from pathlib import Path
import sys
import tomllib

path = Path(sys.argv[1])
config = {}
if path.is_file():
    with path.open("rb") as handle:
        config = tomllib.load(handle)


def clean_string(value, default=""):
    if not isinstance(value, str):
        return default
    value = value.strip()
    return value or default


mode = clean_string(config.get("local_llm_console_mode"), "local")
if mode not in {"local", "remote"}:
    mode = "local"

print(mode)
PY
)

export LOCAL_LLM_CONSOLE_ACTIVE_MODE="${LOCAL_LLM_CONSOLE_LAUNCH_STATE[0]:-local}"

if [[ -f "$BASE_SHELL_ASAR" && ! -f "$BASE_UPSTREAM_SOURCE_ASAR" ]]; then
    cp -p "$BASE_SHELL_ASAR" "$BASE_UPSTREAM_SOURCE_ASAR"
fi

if [[ -d "$BASE_SHELL_ASAR_UNPACKED" && ! -d "$BASE_UPSTREAM_SOURCE_ASAR_UNPACKED" ]]; then
    cp -a "$BASE_SHELL_ASAR_UNPACKED" "$BASE_UPSTREAM_SOURCE_ASAR_UNPACKED"
fi

if [[ -z "$BASE_SOURCE_ASAR" ]]; then
    if [[ -f "$BASE_UPSTREAM_SOURCE_ASAR" ]]; then
        BASE_SOURCE_ASAR="$BASE_UPSTREAM_SOURCE_ASAR"
    else
        BASE_SOURCE_ASAR="$BASE_SHELL_ASAR"
    fi
fi

LOCAL_SOURCE_ASAR="$BASE_SOURCE_ASAR"

if [[ ! -f "$BASE_START_SCRIPT" ]]; then
    echo "Missing generated base runtime in $BASE_APP_DIR." >&2
    echo "Run ../install.sh from the repo root to build Local LLM Console, or set CODEX_DESKTOP_BASE_APP_DIR." >&2
    exit 1
fi

if [[ ! -f "$LOCAL_SOURCE_ASAR" ]]; then
    echo "Missing base runtime archive: $LOCAL_SOURCE_ASAR" >&2
    echo "Run ../install.sh from the repo root to build Local LLM Console, or set CODEX_DESKTOP_SOURCE_ASAR." >&2
    exit 1
fi

terminate_stale_local_runtime_processes() {
    local current_runtime="$LOCAL_RUNTIME_APP_DIR"
    local stale_pids=()
    local pid=""
    local cmd=""

    while IFS= read -r line; do
        pid="${line%% *}"
        cmd="${line#* }"

        [[ "$cmd" == *"--class=${CODEX_DESKTOP_CLASS}"* ]] || continue
        [[ "$cmd" == *"$XDG_DATA_HOME/local-ai-console/runtime-"*"/app"* ]] || continue
        [[ "$cmd" == *"$current_runtime"* ]] && continue

        stale_pids+=("$pid")
    done < <(pgrep -af "$BASE_ELECTRON_PATH" || true)

    if [[ "${#stale_pids[@]}" -eq 0 ]]; then
        return 0
    fi

    kill "${stale_pids[@]}" >/dev/null 2>&1 || true
    sleep 0.5

    local stubborn_pids=()
    for pid in "${stale_pids[@]}"; do
        if kill -0 "$pid" >/dev/null 2>&1; then
            stubborn_pids+=("$pid")
        fi
    done

    if [[ "${#stubborn_pids[@]}" -gt 0 ]]; then
        kill -9 "${stubborn_pids[@]}" >/dev/null 2>&1 || true
        sleep 0.2
    fi
}

LOCAL_SOURCE_FINGERPRINT="$(stat -c '%Y:%s' "$LOCAL_SOURCE_ASAR")|$(stat -c '%Y:%s' "$SCRIPT_DIR/start-local.sh")|$(stat -c '%Y:%s' "$LOCAL_BOOTSTRAP_SOURCE_PATH")|${CODEX_DESKTOP_LOCAL_RUNTIME_VERSION}|${CODEX_DESKTOP_LOCAL_RUNTIME_PATCH_VERSION}"
LOCAL_RUNTIME_NEEDS_REBUILD=1
if [[ -d "$LOCAL_RUNTIME_APP_DIR" && -f "$LOCAL_RUNTIME_STAMP" ]]; then
    if [[ "$(<"$LOCAL_RUNTIME_STAMP")" == "$LOCAL_SOURCE_FINGERPRINT" ]]; then
        LOCAL_RUNTIME_NEEDS_REBUILD=0
    fi
fi

if [[ "$LOCAL_RUNTIME_NEEDS_REBUILD" -eq 1 ]]; then
    rm -rf "$LOCAL_RUNTIME_APP_DIR"
    npx --yes asar extract "$LOCAL_SOURCE_ASAR" "$LOCAL_RUNTIME_APP_DIR"
    LOCAL_RUNTIME_APP_DIR="$LOCAL_RUNTIME_APP_DIR" LOCAL_RUNTIME_ICON_PATH="$LOCAL_RUNTIME_ICON_PATH" LOCAL_BOOTSTRAP_SOURCE_PATH="$LOCAL_BOOTSTRAP_SOURCE_PATH" python3 - <<'PY'
from pathlib import Path
import json
import os
import re

root = Path(os.environ["LOCAL_RUNTIME_APP_DIR"])


def replace_once(path: Path, original: str, patched: str, *, error_message: str) -> None:
    text = path.read_text()
    if original not in text:
        print(f"WARN: {error_message}")
        return
    path.write_text(text.replace(original, patched, 1))


def replace_optional(path: Path, original: str, patched: str) -> None:
    text = path.read_text()
    if original not in text:
        return
    path.write_text(text.replace(original, patched, 1))


def rewrite_locale_message(path: Path, key: str, value: str) -> None:
    text = path.read_text()
    pattern = rf'("{re.escape(key)}":`)([^`]*)`'
    patched_text, count = re.subn(pattern, rf"\1{value}`", text)
    if count:
        path.write_text(patched_text)


package_json = root / "package.json"
package_data = json.loads(package_json.read_text())
package_data["name"] = "local-ai-console"
package_data["productName"] = "Local LLM Console"
package_data["description"] = "Local LLM Console"
package_data["desktopName"] = "local-ai-console.desktop"
package_json.write_text(json.dumps(package_data, indent=2) + "\n")

bootstrap_bundle = root / ".vite" / "build" / "bootstrap.js"
replace_optional(
    bootstrap_bundle,
    "t.app.setName(e.Xr(b))",
    "t.app.setName(`Local LLM Console`)",
)
replace_optional(
    bootstrap_bundle,
    "n.app.setName(e.L(x))",
    "n.app.setName(`Local LLM Console`)",
)
replace_optional(
    bootstrap_bundle,
    "n.app.setName(e.L(x)),n.app.setPath(`userData`,_({appDataPath:n.app.getPath(`appData`),buildFlavor:x,env:process.env}))",
    "n.app.setName(`Local LLM Console`),n.app.setPath(`userData`,r.join(n.app.getPath(`appData`),`Local LLM Console`))",
)
replace_optional(
    bootstrap_bundle,
    "message:`${t.app.getName()} failed to start.`",
    "message:`Local LLM Console failed to start.`",
)
replace_optional(
    bootstrap_bundle,
    "if(!await p({appName:t.app.getName(),environment:{arch:process.arch,isPackaged:t.app.isPackaged,platform:process.platform}})){t.app.quit();return}",
    "if(!await p({appName:`Local LLM Console`,environment:{arch:process.arch,isPackaged:t.app.isPackaged,platform:process.platform}})){t.app.quit();return}",
)

main_bundle = next((root / ".vite" / "build").glob("main-*.js"), None)
if main_bundle is None:
    raise SystemExit("Local desktop runtime patch failed: main bundle not found")
replace_once(
    main_bundle,
    "function Jy({buildFlavor:n,allowDevtools:i,allowInspectElement:o,allowDebugMenu:s,errorReporter:c,globalState:l,getGlobalStateForHost:u,desktopRoot:d,preloadPath:f,repoRoot:p,isMacOS:m,isWindows:h,isDevMode:g,canHideLastLocalWindowToTray:_,disposables:v})",
    "function Jy({buildFlavor:n,allowDevtools:i,allowInspectElement:o,allowDebugMenu:s,errorReporter:c,globalState:l,getGlobalStateForHost:u,desktopRoot:d,preloadPath:f,repoRoot:p,isMacOS:m,isWindows:h,isDevMode:g,canHideLastLocalWindowToTray:_,disposables:v,disableQuitConfirmationPrompt:Q,quitState:X})",
    error_message="Local desktop runtime patch failed: window services signature snippet not found",
)
replace_once(
    main_bundle,
    "let S=new Ny({desktopRoot:d,iconDirectoryName:fn,getGlobalStateForHost:u,moduleDir:__dirname,preloadPath:f,repoRoot:p,allowDevtools:i,allowInspectElement:o,allowDebugMenu:s,errorReporter:c,canHideLastLocalWindowToTray:_}),C=new A_(S,V)",
    "let S=new Ny({desktopRoot:d,iconDirectoryName:fn,getGlobalStateForHost:u,moduleDir:__dirname,preloadPath:f,repoRoot:p,allowDevtools:i,allowInspectElement:o,allowDebugMenu:s,errorReporter:c,canHideLastLocalWindowToTray:_,disableQuitConfirmationPrompt:Q,quitState:X}),C=new A_(S,V)",
    error_message="Local desktop runtime patch failed: window services Ny options snippet not found",
)
replace_once(
    main_bundle,
    "_&&O.on(`close`,e=>{this.persistPrimaryWindowBounds(O,d);let t=this.getPrimaryWindows(d).some(e=>e!==O);if(process.platform===`win32`&&d===`local`&&!this.isAppQuitting&&this.options.canHideLastLocalWindowToTray?.()===!0&&!t){e.preventDefault(),O.hide();return}if(process.platform===`darwin`&&!this.isAppQuitting&&!t){if(O.isFullScreen()){e.preventDefault(),O.once(`leave-full-screen`,()=>{O.isDestroyed()||O.hide()}),O.setFullScreen(!1);return}e.preventDefault(),O.hide()}});",
    "_&&O.on(`close`,e=>{this.persistPrimaryWindowBounds(O,d);let n=this.getPrimaryWindows(d).some(e=>e!==O);if(process.platform===`win32`&&d===`local`&&!this.isAppQuitting&&this.options.canHideLastLocalWindowToTray?.()===!0&&!n){e.preventDefault(),O.hide();return}if(process.platform!==`darwin`&&process.platform!==`win32`&&d===`local`&&!this.isAppQuitting&&!n&&!this.options.disableQuitConfirmationPrompt&&!this.options.quitState?.canQuitWithoutPrompt()){e.preventDefault();let r=`Local LLM Console`;if(t.dialog.showMessageBoxSync({type:`warning`,buttons:[`Quit`,`Cancel`],defaultId:0,cancelId:1,noLink:!0,title:`Quit ${r}?`,message:``,detail:`Any local threads running on this machine will be interrupted and scheduled automations won't run`})!==0){Promise.resolve().then(()=>{O.isDestroyed()||(O.show(),O.focus())});return}this.options.quitState?.markQuitApproved(),this.markAppQuitting(),Promise.resolve().then(()=>{O.isDestroyed()||O.close()});return}if(process.platform===`darwin`&&!this.isAppQuitting&&!n){if(O.isFullScreen()){e.preventDefault(),O.once(`leave-full-screen`,()=>{O.isDestroyed()||O.hide()}),O.setFullScreen(!1);return}e.preventDefault(),O.hide()}});",
    error_message="Local desktop runtime patch failed: last-window close confirmation snippet not found",
)
replace_optional(
    main_bundle,
    "v&&k.on(`close`,e=>{this.persistPrimaryWindowBounds(k,f);let t=this.getPrimaryWindows(f).some(e=>e!==k);if(process.platform===`win32`&&f===`local`&&!this.isAppQuitting&&this.options.canHideLastLocalWindowToTray?.()===!0&&!t){e.preventDefault(),k.hide();return}if(process.platform===`darwin`&&!this.isAppQuitting&&!t){if(k.isFullScreen()){e.preventDefault(),k.once(`leave-full-screen`,()=>{k.isDestroyed()||k.hide()}),k.setFullScreen(!1);return}e.preventDefault(),k.hide()}});",
    "v&&k.on(`close`,e=>{this.persistPrimaryWindowBounds(k,f);let t=this.getPrimaryWindows(f).some(e=>e!==k);if(process.platform===`win32`&&f===`local`&&!this.isAppQuitting&&this.options.canHideLastLocalWindowToTray?.()===!0&&!t){e.preventDefault(),k.hide();return}if(process.platform!==`darwin`&&process.platform!==`win32`&&f===`local`&&!this.isAppQuitting&&!t&&!this.options.disableQuitConfirmationPrompt&&!this.options.quitState?.canQuitWithoutPrompt()){e.preventDefault();let r=`Local LLM Console`;if(n.dialog.showMessageBoxSync({type:`warning`,buttons:[`Quit`,`Cancel`],defaultId:0,cancelId:1,noLink:!0,title:`Quit ${r}?`,message:``,detail:`Any local threads running on this machine will be interrupted and scheduled automations won't run`})!==0){Promise.resolve().then(()=>{k.isDestroyed()||(k.show(),k.focus())});return}this.options.quitState?.markQuitApproved(),this.markAppQuitting(),Promise.resolve().then(()=>{k.isDestroyed()||k.close()});return}if(process.platform===`darwin`&&!this.isAppQuitting&&!t){if(k.isFullScreen()){e.preventDefault(),k.once(`leave-full-screen`,()=>{k.isDestroyed()||k.hide()}),k.setFullScreen(!1);return}e.preventDefault(),k.hide()}});",
)
replace_once(
    main_bundle,
    "M=Jy({buildFlavor:i,allowDevtools:f,allowInspectElement:p,allowDebugMenu:m,errorReporter:h,globalState:j.globalState,getGlobalStateForHost:j.getGlobalStateForHost,desktopRoot:j.desktopRoot,preloadPath:j.preloadPath,repoRoot:j.repoRoot,isMacOS:w,isWindows:T,isDevMode:E,canHideLastLocalWindowToTray:()=>D,disposables:O})",
    "te=Mg(),M=Jy({buildFlavor:i,allowDevtools:f,allowInspectElement:p,allowDebugMenu:m,errorReporter:h,globalState:j.globalState,getGlobalStateForHost:j.getGlobalStateForHost,desktopRoot:j.desktopRoot,preloadPath:j.preloadPath,repoRoot:j.repoRoot,isMacOS:w,isWindows:T,isDevMode:E,canHideLastLocalWindowToTray:()=>D,disposables:O,disableQuitConfirmationPrompt:process.env.CODEX_ELECTRON_DISABLE_QUIT_CONFIRMATION===`1`,quitState:te})",
    error_message="Local desktop runtime patch failed: startup window services invocation snippet not found",
)
replace_once(
    main_bundle,
    "let te=Mg(),ne=()=>{te.allowQuitTemporarilyForUpdateInstall()};",
    "let ne=()=>{te.allowQuitTemporarilyForUpdateInstall()};",
    error_message="Local desktop runtime patch failed: duplicate quit-state declaration snippet not found",
)
replace_once(
    main_bundle,
    "function dr(){return`Codex Desktop/${t.app.getVersion()} (${process.platform}; ${process.arch})`}",
    "function dr(){return`Local LLM Console/${t.app.getVersion()} (${process.platform}; ${process.arch})`}",
    error_message="Local desktop runtime patch failed: desktop user-agent title snippet not found",
)
replace_once(
    main_bundle,
    "appName:t.app.getName()",
    "appName:`Local LLM Console`",
    error_message="Local desktop runtime patch failed: extension-info app name snippet not found",
)
replace_once(
    main_bundle,
    "throw Error(`Sign in to ChatGPT in Codex Desktop to ${e}.`)",
    "throw Error(`Sign in to Local LLM Console to ${e}.`)",
    error_message="Local desktop runtime patch failed: desktop auth sign-in snippet not found",
)
replace_once(
    main_bundle,
    "function xr(e){return`Sign in to ChatGPT in Codex Desktop to ${e}.`}",
    "function xr(e){return`Sign in to Local LLM Console to ${e}.`}",
    error_message="Local desktop runtime patch failed: desktop auth helper snippet not found",
)
replace_once(
    main_bundle,
    "clientInfo:{name:hn,title:`Codex Desktop`,version:u}",
    "clientInfo:{name:hn,title:`Local LLM Console`,version:u}",
    error_message="Local desktop runtime patch failed: app-server client title snippet not found",
)
replace_once(
    main_bundle,
    "title:i??t.app.getName()",
    "title:`Local LLM Console`",
    error_message="Local desktop runtime patch failed: window title snippet not found",
)
replace_optional(
    main_bundle,
    "title:i??(process.env.CODEX_DESKTOP_RUNTIME_NAME?.trim()||t.app.getName())",
    "title:`Local LLM Console`",
)
replace_once(
    main_bundle,
    "hn=`Codex Desktop`",
    "hn=`Local LLM Console`",
    error_message="Local desktop runtime patch failed: runtime client title constant not found",
)
replace_optional(
    main_bundle,
    "title:`Codex Desktop`",
    "title:`Local LLM Console`",
)
replace_optional(
    main_bundle,
    "<title>Codex</title>",
    "<title>Local LLM Console</title>",
)
replace_optional(
    main_bundle,
    "title:`Codex Debug`",
    "title:`Local LLM Console Debug`",
)
replace_once(
    main_bundle,
    "icon:process.resourcesPath+`/../content/webview/assets/app-D0g8sCle.png`",
    "icon:process.env.CODEX_DESKTOP_WINDOW_ICON_PATH?.trim()||process.resourcesPath+`/../content/webview/assets/app-D0g8sCle.png`",
    error_message="Local desktop runtime patch failed: Linux window icon snippet not found",
)
replace_once(
    main_bundle,
    "webPreferences:T}),k=O.webContents",
    "webPreferences:T});O.setTitle(`Local LLM Console`);O.on(`page-title-updated`,e=>{e.preventDefault(),O.isDestroyed()||O.setTitle(`Local LLM Console`)});let k=O.webContents",
    error_message="Local desktop runtime patch failed: page-title override snippet not found",
)
replace_optional(
    main_bundle,
    "webPreferences:E}),A=k.webContents",
    "webPreferences:E});k.setTitle(`Local LLM Console`);k.on(`page-title-updated`,e=>{e.preventDefault(),k.isDestroyed()||k.setTitle(`Local LLM Console`)});let A=k.webContents",
)
replace_once(
    main_bundle,
    "O.once(`ready-to-show`,()=>{vy().info(`window ready-to-show`,{safe:{hostId:d,windowId:O.id,webContentsId:O.webContents.id,appearance:c,startupElapsedMs:Date.now()-m}})})",
    "O.once(`ready-to-show`,()=>{O.setTitle(`Local LLM Console`),vy().info(`window ready-to-show`,{safe:{hostId:d,windowId:O.id,webContentsId:O.webContents.id,appearance:c,startupElapsedMs:Date.now()-m}})})",
    error_message="Local desktop runtime patch failed: ready-to-show title hook snippet not found",
)
replace_optional(
    main_bundle,
    "k.once(`ready-to-show`,()=>{KC().info(`window ready-to-show`,{safe:{hostId:f,windowId:k.id,webContentsId:k.webContents.id,appearance:l,startupElapsedMs:Date.now()-h}})})",
    "k.once(`ready-to-show`,()=>{k.setTitle(`Local LLM Console`),KC().info(`window ready-to-show`,{safe:{hostId:f,windowId:k.id,webContentsId:k.webContents.id,appearance:l,startupElapsedMs:Date.now()-h}})})",
)
replace_once(
    main_bundle,
    "function Cg(e){let n=t.Menu.buildFromTemplate([{role:`quit`}]);return(Array.isArray(n)?n:n.items)[0]?.label??`Quit ${e}`}",
    "function Cg(e){let n=`Local LLM Console`,r=t.Menu.buildFromTemplate([{role:`quit`}]);return(Array.isArray(r)?r:r.items)[0]?.label?.replace(`Codex Desktop`,n).replace(`Codex`,n)??`Quit ${n}`}",
    error_message="Local desktop runtime patch failed: tray quit label snippet not found",
)
replace_once(
    main_bundle,
    "let o=t.app.getName();if(t.dialog.showMessageBoxSync({type:`warning`,buttons:[`Quit`,`Cancel`],defaultId:0,cancelId:1,noLink:!0,title:`Quit ${o}?`,message:`Quit ${o}?`,detail:`Any local threads running on this machine will be interrupted and scheduled automations won't run`})!==0){a.preventDefault();return}",
    "let E=`Local LLM Console`;if(t.dialog.showMessageBoxSync({type:`warning`,buttons:[`Quit`,`Cancel`],defaultId:0,cancelId:1,noLink:!0,title:`Quit ${E}?`,message:``,detail:`Any local threads running on this machine will be interrupted and scheduled automations won't run`})!==0){a.preventDefault(),Promise.resolve().then(()=>{m||(i.showLastActivePrimaryWindow()||o(`local`))});return}",
    error_message="Local desktop runtime patch failed: quit confirmation title snippet not found",
)
replace_optional(
    main_bundle,
    "n.app.on(`before-quit`,o=>{let s=y_(),c=t.Wn().some(e=>e.status===`ACTIVE`);if(e||i.canQuitWithoutPrompt()||r||!s&&!c){g=!0,a.markAppQuitting();return}let l=n.app.getName();if(n.dialog.showMessageBoxSync({type:`warning`,buttons:[`Quit`,`Cancel`],defaultId:0,cancelId:1,noLink:!0,title:`Quit ${l}?`,message:`Quit ${l}?`,detail:Mb({hasInProgressLocalConversation:s,hasEnabledAutomations:c})})!==0){o.preventDefault();return}i.markQuitApproved(),g=!0,a.markAppQuitting()})",
    "n.app.on(`before-quit`,o=>{let s=y_(),c=t.Wn().some(e=>e.status===`ACTIVE`);if(e||i.canQuitWithoutPrompt()||r||!s&&!c){g=!0,a.markAppQuitting();return}let l=`Local LLM Console`;if(n.dialog.showMessageBoxSync({type:`warning`,buttons:[`Quit`,`Cancel`],defaultId:0,cancelId:1,noLink:!0,title:`Quit ${l}?`,message:``,detail:Mb({hasInProgressLocalConversation:s,hasEnabledAutomations:c}).replaceAll(`Codex`,`Local LLM Console`)})!==0){o.preventDefault();return}i.markQuitApproved(),g=!0,a.markAppQuitting()})",
)
replace_once(
    main_bundle,
    "updateOverlayTitle(e,n){e.window.isDestroyed()||e.window.setTitle(n??t.app.getName())}",
    "updateOverlayTitle(e,n){e.window.isDestroyed()||e.window.setTitle(`Local LLM Console`)}",
    error_message="Local desktop runtime patch failed: overlay title updater snippet not found",
)
replace_once(
    main_bundle,
    "updateTitle(e,t){if(e.window.isDestroyed())return;let n=j_(t);e.window.setTitle(n)}",
    "updateTitle(e,t){if(e.window.isDestroyed())return;e.window.setTitle(`Local LLM Console`)}",
    error_message="Local desktop runtime patch failed: hotkey window title updater snippet not found",
)
replace_once(
    main_bundle,
    "label:`About ${t.app.getName()}`",
    "label:`About Local LLM Console`",
    error_message="Local desktop runtime patch failed: about menu label snippet not found",
)
replace_once(
    main_bundle,
    "let e=t.app.getName();if(typeof t.app.showAboutPanel==`function`)",
    "let e=`Local LLM Console`;if(typeof t.app.showAboutPanel==`function`)",
    error_message="Local desktop runtime patch failed: about panel title snippet not found",
)
replace_once(
    main_bundle,
    "title:t.app.getName(),width:c_,height:l_,appearance:`avatarOverlay`",
    "title:`Local LLM Console`,width:c_,height:l_,appearance:`avatarOverlay`",
    error_message="Local desktop runtime patch failed: avatar overlay title snippet not found",
)
replace_once(
    main_bundle,
    "title:t.app.getName(),width:E_,height:D_,appearance:`controlOverlay`",
    "title:`Local LLM Console`,width:E_,height:D_,appearance:`controlOverlay`",
    error_message="Local desktop runtime patch failed: control overlay title snippet not found",
)
replace_once(
    main_bundle,
    "title:t.app.getName(),width:N_,height:P_,appearance:`hotkeyWindowHome`",
    "title:`Local LLM Console`,width:N_,height:P_,appearance:`hotkeyWindowHome`",
    error_message="Local desktop runtime patch failed: hotkey home title snippet not found",
)
replace_once(
    main_bundle,
    "title:t.app.getName(),width:this.threadSize.width,height:this.threadSize.height,appearance:`hotkeyWindowThread`",
    "title:`Local LLM Console`,width:this.threadSize.width,height:this.threadSize.height,appearance:`hotkeyWindowThread`",
    error_message="Local desktop runtime patch failed: hotkey thread title snippet not found",
)
replace_once(
    main_bundle,
    "title:n.title??t.app.getName(),width:tv,height:nv,appearance:`hud`",
    "title:n.title??`Local LLM Console`,width:tv,height:nv,appearance:`hud`",
    error_message="Local desktop runtime patch failed: hud title snippet not found",
)
replace_once(
    main_bundle,
    "let a=i.kind===`local`?t.app.getName():i.display_name,o=await S.createPrimaryWindow({title:a,hostId:i.id,show:n});",
    "let a=i.kind===`local`?`Local LLM Console`:i.display_name,o=await S.createPrimaryWindow({title:a,hostId:i.id,show:n});",
    error_message="Local desktop runtime patch failed: primary window title selection snippet not found",
)
replace_once(
    main_bundle,
    "function bh(e){let t={id:e.id,display_name:e.displayName,kind:`ssh`,codex_cli_command:e.codexCliCommand,terminal_command:e.terminalCommand,default_workspaces:e.defaultWorkspaces??[],[zr]:{sshAlias:e.sshAlias??null,sshHost:e.sshHost,sshPort:e.sshPort,identity:e.identity,remotePort:e.remotePort??vh}};return e.localPort!=null&&(t.websocket_url=yh(e.localPort)),e.homeDir&&(t.home_dir=e.homeDir),t}function xh(t,n){let r=e.oi({sshAlias:t.sshAlias,sshHost:t.sshHost,sshPort:t.sshPort,identity:t.identity});return bh({id:t.hostId,displayName:`${gh}${t.displayName}`,localPort:n,sshAlias:t.sshAlias??null,sshHost:t.sshHost,sshPort:t.sshPort,identity:t.identity,remotePort:vh,codexCliCommand:[],terminalCommand:[`ssh`,...r],defaultWorkspaces:[]})}function Sh(t){return{id:t.hostId,display_name:t.displayName,kind:e.ri,codex_cli_command:[],terminal_command:[],default_workspaces:[],env_id:t.envId,environment_kind:t.environmentKind,online:t.online,busy:t.busy,os:t.os,arch:t.arch,app_server_version:t.appServerVersion,last_seen_at:t.lastSeenAt}}function Ch(t,n){return e.si(t)?Sh(t):xh(t,n)}",
    "function bh(e){let t={id:e.id,display_name:e.displayName,kind:`ssh`,codex_cli_command:e.codexCliCommand,terminal_command:e.terminalCommand,default_workspaces:e.defaultWorkspaces??[],[zr]:{sshAlias:e.sshAlias??null,sshHost:e.sshHost,sshPort:e.sshPort,identity:e.identity,remotePort:e.remotePort??vh}};return e.localPort!=null&&(t.websocket_url=yh(e.localPort)),e.homeDir&&(t.home_dir=e.homeDir),t}function xh(t,n){let r=e.oi({sshAlias:t.sshAlias,sshHost:t.sshHost,sshPort:t.sshPort,identity:t.identity});return bh({id:t.hostId,displayName:`${gh}${t.displayName}`,localPort:n,sshAlias:t.sshAlias??null,sshHost:t.sshHost,sshPort:t.sshPort,identity:t.identity,remotePort:vh,codexCliCommand:[],terminalCommand:[`ssh`,...r],defaultWorkspaces:[]})}function Sh(t){return{id:t.hostId,display_name:t.displayName,kind:e.ri,codex_cli_command:[],terminal_command:[],default_workspaces:[],env_id:t.envId,environment_kind:t.environmentKind,online:t.online,busy:t.busy,os:t.os,arch:t.arch,app_server_version:t.appServerVersion,last_seen_at:t.lastSeenAt}}function Nh(t){let n=(t.websocketUrl??t.websocket_url??``).trim();return{id:t.hostId,display_name:t.displayName,kind:`brix`,codex_cli_command:[],terminal_command:[],default_workspaces:[],websocket_url:n}}function Ch(t,n){return e.si(t)?Sh(t):t.connectionType===`tailscale-websocket`&&(t.websocketUrl??t.websocket_url??``).trim().length>0?Nh(t):xh(t,n)}",
    error_message="Local desktop runtime patch failed: remote websocket host conversion snippet not found",
)
replace_optional(
    main_bundle,
    "function hy(e){let t={id:e.id,display_name:e.displayName,kind:`ssh`,codex_cli_command:e.codexCliCommand,terminal_command:e.terminalCommand,default_workspaces:e.defaultWorkspaces??[],[Ta]:{sshAlias:e.sshAlias??null,sshHost:e.sshHost,sshPort:e.sshPort,identity:e.identity,remotePort:e.remotePort??py}};return e.localPort!=null&&(t.websocket_url=my(e.localPort)),e.homeDir&&(t.home_dir=e.homeDir),t}function gy(t,n){let r=e.bt({sshAlias:t.sshAlias,sshHost:t.sshHost,sshPort:t.sshPort,identity:t.identity});return hy({id:t.hostId,displayName:`${dy}${t.displayName}`,localPort:n,sshAlias:t.sshAlias??null,sshHost:t.sshHost,sshPort:t.sshPort,identity:t.identity,remotePort:py,codexCliCommand:[],terminalCommand:[`ssh`,...r],defaultWorkspaces:[]})}function _y(t){return{id:t.hostId,display_name:t.displayName,kind:e._t,codex_cli_command:[],terminal_command:[],default_workspaces:[],env_id:t.envId,host_name:t.hostName,environment_kind:t.environmentKind,online:t.online,busy:t.busy,os:t.os,arch:t.arch,app_server_version:t.appServerVersion,last_seen_at:t.lastSeenAt}}function vy(t,n){return e.xt(t)?_y(t):gy(t,n)}",
    "function hy(e){let t={id:e.id,display_name:e.displayName,kind:`ssh`,codex_cli_command:e.codexCliCommand,terminal_command:e.terminalCommand,default_workspaces:e.defaultWorkspaces??[],[Ta]:{sshAlias:e.sshAlias??null,sshHost:e.sshHost,sshPort:e.sshPort,identity:e.identity,remotePort:e.remotePort??py}};return e.localPort!=null&&(t.websocket_url=my(e.localPort)),e.homeDir&&(t.home_dir=e.homeDir),t}function gy(t,n){let r=e.bt({sshAlias:t.sshAlias,sshHost:t.sshHost,sshPort:t.sshPort,identity:t.identity});return hy({id:t.hostId,displayName:`${dy}${t.displayName}`,localPort:n,sshAlias:t.sshAlias??null,sshHost:t.sshHost,sshPort:t.sshPort,identity:t.identity,remotePort:py,codexCliCommand:[],terminalCommand:[`ssh`,...r],defaultWorkspaces:[]})}function _y(t){return{id:t.hostId,display_name:t.displayName,kind:e._t,codex_cli_command:[],terminal_command:[],default_workspaces:[],env_id:t.envId,host_name:t.hostName,environment_kind:t.environmentKind,online:t.online,busy:t.busy,os:t.os,arch:t.arch,app_server_version:t.appServerVersion,last_seen_at:t.lastSeenAt}}function Ny(t){let n=(t.websocketUrl??t.websocket_url??``).trim();return{id:t.hostId,display_name:t.displayName,kind:`ssh`,codex_cli_command:[],terminal_command:[],default_workspaces:[],websocket_url:n,local_llm_console_direct_websocket:!0}}function vy(t,n){return e.xt(t)?_y(t):t.connectionType===`tailscale-websocket`&&(t.websocketUrl??t.websocket_url??``).trim().length>0?Ny(t):gy(t,n)}",
)
replace_optional(
    main_bundle,
    "function Ra(e){if(process.env.CODEX_APP_SERVER_FORCE_CLI===`1`||e.kind!==`ssh`)return null;let t=e.websocket_url??null;if(!t)return null;let n=Ia(e);return n?{websocketUrl:t,sshConnection:{alias:n.sshAlias,host:n.sshHost,port:n.sshPort,identity:n.identity},remotePort:n.remotePort??Ea.remoteAppServerPort}:null}",
    "var LocalLlmConsoleDirectWebsocketTransport=class{kind=`websocket`;constructor(e){this.options=e}supportsReconnect(){return!0}dispose(){}async connect(){let e=new t.yn(this.options.websocketUrl,{perMessageDeflate:!1});return t.vn(e,{onPongTimeout:()=>{e.terminate()}}),new t.bn(e)}};function Ra(e){if(process.env.CODEX_APP_SERVER_FORCE_CLI===`1`||e.kind!==`ssh`)return null;let t=e.websocket_url??null;if(!t)return null;if(e.local_llm_console_direct_websocket===!0)return{websocketUrl:t,direct:!0};let n=Ia(e);return n?{websocketUrl:t,sshConnection:{alias:n.sshAlias,host:n.sshHost,port:n.sshPort,identity:n.identity},remotePort:n.remotePort??Ea.remoteAppServerPort}:null}",
)
replace_optional(
    main_bundle,
    "function zy(n){let r=Ra(n.hostConfig);if(r)return Ly.info(`[ssh-websocket-v0] selected app-server transport`,{safe:{hostId:n.hostConfig.id,websocketUrl:r.websocketUrl}}),new La(r);",
    "function zy(n){let r=Ra(n.hostConfig);if(r)return r.direct?(Ly.info(`[direct-websocket] selected app-server transport`,{safe:{hostId:n.hostConfig.id,websocketUrl:r.websocketUrl}}),new LocalLlmConsoleDirectWebsocketTransport(r)):(Ly.info(`[ssh-websocket-v0] selected app-server transport`,{safe:{hostId:n.hostConfig.id,websocketUrl:r.websocketUrl}}),new La(r));",
)
replace_once(
    main_bundle,
    "r.setToolTip(t.app.getName())",
    "r.setToolTip(`Local LLM Console`)",
    error_message="Local desktop runtime patch failed: tray tooltip snippet not found",
)
replace_once(
    main_bundle,
    "toggleChronicleSidecar,e.A(),t.app.getName())",
    "toggleChronicleSidecar,e.A(),`Local LLM Console`)",
    error_message="Local desktop runtime patch failed: tray app name snippet not found",
)

runtime_webview_index = root / "webview" / "index.html"
replace_once(
    runtime_webview_index,
    "<title>Codex</title>",
    "<title>Local LLM Console</title>",
    error_message="Local desktop runtime patch failed: runtime webview title snippet not found",
)

runtime_index_bundle = next((root / "webview" / "assets").glob("index-*.js"), None)
if runtime_index_bundle is None:
    raise SystemExit("Local desktop runtime patch failed: runtime index bundle not found")

replace_optional(
    runtime_index_bundle,
    '"read-config":n9((e,t)=>e.readConfig(t)),"read-config-for-host":i9((e,{hostId:t,...n})=>e.sendRequest(`config/read`,n)),"refresh-remote-connection":async(e,{hostId:t})=>{',
    '"read-config":n9((e,t)=>e.readConfig(t)),"read-config-for-host":i9((e,{hostId:t,...n})=>e.sendRequest(`config/read`,n)),"refresh-remote-connections":async()=>Qe(`refresh-remote-connections`,{params:{}}),"refresh-remote-control-connections":async()=>Qe(`refresh-remote-control-connections`,{params:{}}),"save-codex-managed-remote-ssh-connections":async(e,t)=>Qe(`save-codex-managed-remote-ssh-connections`,{params:t??{}}),"set-remote-connection-auto-connect":async(e,t)=>Qe(`set-remote-connection-auto-connect`,{params:t??{}}),"refresh-remote-connection":async(e,{hostId:t})=>{',
)

runtime_local_models_bundle = next((root / "webview" / "assets").glob("local-models-settings-*.js"), None)
if runtime_local_models_bundle is None:
    raise SystemExit("Local desktop runtime patch failed: runtime local-models settings bundle not found")

replace_optional(
    runtime_local_models_bundle,
    """async function loadManagedRemoteSessionConnections() {
  let e = await sendLocalLlmConsoleRequest(`refresh-remote-connections`);
  return (e?.remoteConnections ?? []).filter((e) => e?.source === $);
}

function mergeManagedRemoteSessionConnections(e, t) {
  return [...e.filter((e) => e.hostId !== t.hostId && e.connectionType !== ee), t];
}""",
    """async function loadManagedRemoteSessionConnections() {
  let e = await sendLocalLlmConsoleRequest(`refresh-remote-connections`);
  let t = e?.remoteConnections;
  return (Array.isArray(t) ? t : []).filter((e) => e?.source === $);
}

function mergeManagedRemoteSessionConnections(e, t) {
  let n = Array.isArray(e) ? e : [];
  return [...n.filter((e) => e.hostId !== t.hostId && e.connectionType !== ee), t];
}""",
)

replace_optional(
    runtime_local_models_bundle,
    """async function applyLocalLlmConsoleHostService(e = `reload`) {
  let t = await fetch(`/__local-llm-console/host-service`, {
      method: `POST`,
      headers: { "Content-Type": `application/json` },
      body: JSON.stringify({ action: e }),
    }),
    n = null;
  try {
    n = await t.json();
  } catch {}
  if (!t.ok)
    throw new Error(
      typeof (n == null ? void 0 : n.error) == `string` && n.error.trim().length > 0
        ? n.error
        : `Unable to apply host settings immediately.`,
    );
  return n;
}""",
    """async function applyLocalLlmConsoleHostService(e = `reload`) {
  let t;
  try {
    t = await fetch(`/__local-llm-console/host-service`, {
      method: `POST`,
      headers: { "Content-Type": `application/json` },
      body: JSON.stringify({ action: e }),
    });
  } catch (t) {
    if (
      typeof window !== `undefined` &&
      (window.location.protocol === `file:` || window.location.protocol === `app:`)
    )
      return { ok: !0, skipped: !0, action: e };
    throw t;
  }
  let n = null;
  try {
    n = await t.json();
  } catch {}
  if (!t.ok)
    throw new Error(
      typeof (n == null ? void 0 : n.error) == `string` && n.error.trim().length > 0
        ? n.error
        : `Unable to apply host settings immediately.`,
    );
  return n;
}""",
)

replace_once(
    runtime_index_bundle,
    "(0,$.jsx)(oK,{}),R?.type===`cloud`?null:(0,$.jsx)(lK,{conversationId:K,hostId:te},K??`new-conversation`),(0,$.jsx)(_K,{conversationId:K})",
    "(0,$.jsx)(oK,{}),(0,$.jsx)(_K,{conversationId:K})",
    error_message="Local desktop runtime patch failed: memories slash command snippet not found",
)
replace_once(
    runtime_index_bundle,
    "xt&&(0,$.jsx)(gK,{conversationId:K,hostId:q.hostId}),",
    "",
    error_message="Local desktop runtime patch failed: personality slash command snippet not found",
)
replace_once(
    runtime_index_bundle,
    "Fn||st?(0,$.jsx)(RG,{cwd:On,roots:Mi,hostId:sr}):null,",
    "",
    error_message="Local desktop runtime patch failed: skills slash command group snippet not found",
)
replace_once(
    runtime_index_bundle,
    "De=n??(0,$.jsx)(yh,{tooltipContent:(0,$.jsx)(Y,{id:`codex.header.settingsTooltip`,defaultMessage:`Settings`,description:`Tooltip text for opening settings`}),children:(0,$.jsx)(xp,{color:`ghost`,size:`icon`,children:(0,$.jsx)(Zm,{className:`icon-xs`})})})",
    "De=n??(0,$.jsx)(yh,{tooltipContent:(0,$.jsx)(Y,{id:`codex.header.settingsTooltip`,defaultMessage:`Settings`,description:`Tooltip text for opening settings`}),children:(0,$.jsx)(xp,{color:`ghost`,size:`icon`,onClick:()=>{a(!1),o(`/settings/general-settings`,{state:W})},children:(0,$.jsx)(Zm,{className:`icon-xs`})})})",
    error_message="Local desktop runtime patch failed: settings header trigger snippet not found",
)
replace_once(
    runtime_index_bundle,
    "function uw(){let e=(0,Q.c)(23),{authMethod:t,planAtLogin:n}=$f(),{data:r}=Xi(),{data:i}=Ji(),a=t===`chatgpt`,o;",
    "function uw(){let e=(0,Q.c)(23),{authMethod:t,planAtLogin:n}=$f(),{data:r}=Xi(),{data:i}=Ji(),a=t===`chatgpt`,o,N=d();",
    error_message="Local desktop runtime patch failed: settings footer function snippet not found",
)
replace_once(
    runtime_index_bundle,
    ",d=s?.plan??n,f=r?.accounts,p;e[2]!==i||e[3]!==t||e[4]!==d||e[5]!==f?(p=ow({authMethod:t,plan:d,currentAccount:i,accounts:f}),e[2]=i,e[3]=t,e[4]=d,e[5]=f,e[6]=p):p=e[6];",
    ",P=s?.plan??n,f=r?.accounts,p;e[2]!==i||e[3]!==t||e[4]!==P||e[5]!==f?(p=ow({authMethod:t,plan:P,currentAccount:i,accounts:f}),e[2]=i,e[3]=t,e[4]=P,e[5]=f,e[6]=p):p=e[6];",
    error_message="Local desktop runtime patch failed: settings footer plan snippet not found",
)
replace_once(
    runtime_index_bundle,
    "children:(0,$.jsx)(sw,{triggerButton:(0,$.jsx)(Ky,{icon:b,label:x,onClick:dw,trailing:S,iconClassName:`icon-sm`})})",
    "children:(0,$.jsx)(Ky,{icon:b,label:x,onClick:()=>{N(`/settings/general-settings`)},trailing:S,iconClassName:`icon-sm`})",
    error_message="Local desktop runtime patch failed: settings footer dropdown snippet not found",
)
replace_once(
    runtime_index_bundle,
    "Ue=(0,$.jsxs)(dh,{open:i,onOpenChange:a,contentWidth:Ee,triggerButton:De,children:[Oe,He]})",
    "Ue=(0,$.jsx)(`div`,{className:`contents`,children:De})",
    error_message="Local desktop runtime patch failed: settings header dropdown snippet not found",
)
replace_once(
    runtime_index_bundle,
    "Ne=()=>{a(!1),E.dispatchMessage(`show-settings`,{section:Tg})}",
    "Ne=()=>{a(!1),o(`/settings/general-settings`,{state:W})}",
    error_message="Local desktop runtime patch failed: extension settings action snippet not found",
)
replace_once(
    runtime_index_bundle,
    "(0,$.jsx)(lh.Item,{LeftIcon:xa,RightIcon:im,href:He,children:(0,$.jsx)(Y,{id:`composer.mode.remote.connectToCloud`,defaultMessage:`Connect Codex web`,description:`Menu item to connect Codex Cloud`})}),(0,$.jsx)(lh.Item,{LeftIcon:VI,className:`cursor-not-allowed`,disabled:!0,tooltipText:y.formatMessage({id:`composer.mode.remote.connectToCloudDisabledTooltip`,defaultMessage:`Set up an environment via Codex web to enable sending tasks to the cloud`,description:`Tooltip for disabled send to cloud item when Cloud is not connected`}),children:(0,$.jsx)(`span`,{className:`truncate`,children:(0,$.jsx)(Y,{id:`composer.mode.remote.sendToCloud`,defaultMessage:`Send to cloud`,description:`Disabled label when Codex Cloud is not connected`})})})",
    "(0,$.jsx)(lh.Item,{LeftIcon:ih,disabled:typeof window!=`undefined`&&window.__isLocalLLMConsoleRemoteConnected?!window.__isLocalLLMConsoleRemoteConnected():!0,onClick:()=>{p(!1),_(!1),typeof window!=`undefined`&&window.__handleLocalLLMConsoleRemotePicker&&window.__handleLocalLLMConsoleRemotePicker()},tooltipText:typeof window!=`undefined`&&window.__isLocalLLMConsoleRemoteConnected&&!window.__isLocalLLMConsoleRemoteConnected()?y.formatMessage({id:`composer.mode.remote.workOnHostDisabledTooltip`,defaultMessage:`Connect to a remote host first.`,description:`Tooltip for disabled remote host entry in the composer mode dropdown`}):y.formatMessage({id:`composer.mode.remote.workOnHostTooltip`,defaultMessage:`Use the configured remote host for this session, or open Configuration if it is not set up yet.`,description:`Tooltip for the remote host entry in the composer mode dropdown`}),children:(0,$.jsx)(Y,{id:`composer.mode.remote.workOnHost`,defaultMessage:`Work on remote host`,description:`Menu item to use the configured remote host`})})",
    error_message="Local desktop runtime patch failed: remote host composer menu snippet not found",
)

runtime_vscode_bundle = next((root / "webview" / "assets").glob("vscode-api-*.js"), None)
if runtime_vscode_bundle is None:
    raise SystemExit("Local desktop runtime patch failed: runtime vscode-api bundle not found")

replace_once(
    runtime_vscode_bundle,
    "function Lf(e){let t=[`ssh`,...Af({sshAlias:e.sshAlias,sshHost:e.sshHost,sshPort:e.sshPort,identity:e.identity})];return{id:e.hostId,display_name:e.displayName,kind:`ssh`,codex_cli_command:[],terminal_command:t}}",
    "function Lf(e){if(e.connectionType===`tailscale-websocket`&&(e.websocketUrl??e.websocket_url??``).trim().length>0)return{id:e.hostId,display_name:e.displayName,kind:`brix`,codex_cli_command:[],terminal_command:[],websocket_url:(e.websocketUrl??e.websocket_url??``).trim()};let t=[`ssh`,...Af({sshAlias:e.sshAlias,sshHost:e.sshHost,sshPort:e.sshPort,identity:e.identity})];return{id:e.hostId,display_name:e.displayName,kind:`ssh`,codex_cli_command:[],terminal_command:t}}",
    error_message="Local desktop runtime patch failed: runtime renderer remote host conversion snippet not found",
)

workspace_root_drop_handler_bundle = next((root / ".vite" / "build").glob("workspace-root-drop-handler-*.js"), None)
if workspace_root_drop_handler_bundle is not None:
    replace_optional(
        workspace_root_drop_handler_bundle,
        "shouldPoll(){return this.getStaticDisabledReason()==null}",
        "shouldPoll(){return!1}",
    )
    replace_optional(
        workspace_root_drop_handler_bundle,
        "async pollIfDue(){if(this.getStaticDisabledReason()!=null)return;",
        "async pollIfDue(){return;",
    )

runtime_webview_text = runtime_webview_index.read_text()
runtime_settings_script_hash = "sha256-E2isW5LIwE3Wbjd98bmFq8L3MGT0cyYcsqNRWufMnbA="
runtime_bootstrap_script_tag = '    <script src="./assets/local-ai-console-bootstrap.js"></script>\n'
runtime_settings_script = """    <script>
      (() => {
        window.__openLocalSettings = (section = `general-settings`) => {
          const nextSection = typeof section === `string` && section.trim().length > 0 ? section.trim() : `general-settings`;
          const nextPath = `/settings/${nextSection}`;
          if (window.location.pathname === nextPath) return;
          window.history.pushState({}, ``, nextPath);
          window.dispatchEvent(new PopStateEvent(`popstate`));
        };
      })();
    </script>
"""
runtime_settings_csp_original = "script-src &#39;self&#39; &#39;sha256-Z2/iFzh9VMlVkEOar1f/oSHWwQk3ve1qk/C2WdsC4Xk=&#39; &#39;wasm-unsafe-eval&#39;"
runtime_settings_csp_patched = f"script-src &#39;self&#39; &#39;sha256-Z2/iFzh9VMlVkEOar1f/oSHWwQk3ve1qk/C2WdsC4Xk=&#39; &#39;{runtime_settings_script_hash}&#39; &#39;wasm-unsafe-eval&#39;"
runtime_startup_logo_original = """      .startup-loader__logo {
        position: relative;
        width: 56px;
        height: 56px;
        opacity: 0;
        animation: startup-codex-logo-fade-in 180ms ease-out 60ms forwards;
      }
"""
runtime_startup_logo_patched = """      .startup-loader__logo {
        display: block;
        width: 56px;
        height: 56px;
        object-fit: contain;
        overflow: hidden;
        border-radius: 22%;
        opacity: 0;
        animation: startup-codex-logo-fade-in 180ms ease-out 60ms forwards;
      }
"""
runtime_startup_markup_original = """      <div class="startup-loader" aria-hidden="true">
        <div class="startup-loader__logo">
          <svg
            class="startup-loader__base"
            viewBox="0 0 500 500"
            fill="currentColor"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              d="M330.34 313.62h-67.84c-7.65 0-13.85-6.2-13.85-13.85s6.2-13.85 13.85-13.85h67.84c7.65 0 13.85 6.2 13.85 13.85s-6.2 13.85-13.85 13.85Z"
            />
            <path
              d="M169.65 313.38c-2.36 0-4.74-.6-6.93-1.87-6.62-3.83-8.88-12.31-5.05-18.93l23.78-41.08-23.91-43.21c-3.7-6.69-1.28-15.12 5.41-18.82 6.69-3.71 15.12-1.28 18.82 5.41l31.51 56.94-31.64 54.65c-2.57 4.43-7.22 6.91-12 6.91Z"
            />
            <path
              d="M144.61 144.5c1.42-41.82 35.79-75.27 77.95-75.25 27.89.02 52.35 14.68 66.11 36.71 10.93-5.82 23.41-9.12 36.65-9.11 43.05.02 77.94 34.94 77.91 78 0 13.24-3.32 25.72-9.16 36.64 22.02 13.79 36.66 38.26 36.64 66.15-.02 42.16-33.52 76.48-75.34 77.86-1.42 41.82-35.78 75.28-77.94 75.25-27.89-.02-52.35-14.68-66.11-36.72-10.93 5.82-23.4 9.13-36.65 9.12-43.05-.02-77.94-34.94-77.91-78 0-13.24 3.32-25.72 9.16-36.64-22.02-13.79-36.65-38.26-36.64-66.15.02-42.16 33.51-76.48 75.33-77.86ZM297.77 71.99c-19.24-19.26-45.83-31.17-75.2-31.19-49.23-.03-90.67 33.39-102.84 78.79-45.41 12.12-78.87 53.52-78.9 102.76-.02 29.37 11.87 55.97 31.1 75.23-2.35 8.79-3.62 18.03-3.63 27.56-.03 58.77 47.58 106.44 106.35 106.47 9.53 0 18.77-1.25 27.55-3.6 19.24 19.26 45.84 31.18 75.21 31.2 49.24.03 90.67-33.39 102.84-78.8 45.42-12.11 78.88-53.51 78.91-102.75.02-29.37-11.87-55.98-31.11-75.24 2.35-8.78 3.62-18.02 3.63-27.55.03-58.77-47.58-106.44-106.35-106.47-9.53 0-18.77 1.25-27.56 3.59Z"
            />
          </svg>
          <div class="startup-loader__overlay"></div>
        </div>
      </div>"""
runtime_startup_markup_patched = """      <div class="startup-loader" aria-hidden="true">
        <img class="startup-loader__logo" src="./assets/local-ai-console-gradient.png" alt="" />
      </div>"""

if "src=\"./assets/local-ai-console-gradient.png\"" not in runtime_webview_text:
    if runtime_startup_logo_original not in runtime_webview_text:
        raise SystemExit("Local desktop runtime patch failed: runtime startup logo style snippet not found")
    runtime_webview_text = runtime_webview_text.replace(
        runtime_startup_logo_original,
        runtime_startup_logo_patched,
        1,
    )
    if runtime_startup_markup_original not in runtime_webview_text:
        raise SystemExit("Local desktop runtime patch failed: runtime startup logo markup snippet not found")
    runtime_webview_text = runtime_webview_text.replace(
        runtime_startup_markup_original,
        runtime_startup_markup_patched,
        1,
    )

if "./assets/local-ai-console-bootstrap.js" not in runtime_webview_text:
    if "</body>" not in runtime_webview_text:
        raise SystemExit("Local desktop runtime patch failed: runtime webview body end snippet not found")
    runtime_webview_text = runtime_webview_text.replace(
        "</body>",
        f"{runtime_bootstrap_script_tag}</body>",
        1,
    )

if runtime_settings_script_hash not in runtime_webview_text:
    if runtime_settings_csp_original in runtime_webview_text:
        runtime_webview_text = runtime_webview_text.replace(
            runtime_settings_csp_original,
            runtime_settings_csp_patched,
            1,
        )
    if runtime_settings_script not in runtime_webview_text:
        if "</body>" not in runtime_webview_text:
            raise SystemExit("Local desktop runtime patch failed: runtime webview body end snippet not found")
        runtime_webview_text = runtime_webview_text.replace(
            "</body>",
            f"{runtime_settings_script}</body>",
            1,
        )

runtime_webview_index.write_text(runtime_webview_text)

runtime_webview_assets = root / "webview" / "assets"
runtime_icon_source = Path(os.environ["LOCAL_RUNTIME_ICON_PATH"])
runtime_bootstrap_source = Path(os.environ["LOCAL_BOOTSTRAP_SOURCE_PATH"])
runtime_icon_target = runtime_webview_assets / "local-ai-console-gradient.png"
if runtime_icon_source.exists():
    runtime_icon_target.write_bytes(runtime_icon_source.read_bytes())
    packaged_runtime_icon_target = runtime_webview_assets / "app-D0g8sCle.png"
    packaged_runtime_icon_target.write_bytes(runtime_icon_source.read_bytes())
if runtime_bootstrap_source.exists():
    (runtime_webview_assets / "local-ai-console-bootstrap.js").write_bytes(runtime_bootstrap_source.read_bytes())

runtime_loading_bundle = next(runtime_webview_assets.glob("loading-page-*.js"), None)
if runtime_loading_bundle is None:
    raise SystemExit("Local desktop runtime patch failed: runtime loading-page bundle not found")

runtime_loading_text = runtime_loading_bundle.read_text()
if "/assets/local-ai-console-gradient.png" not in runtime_loading_text:
    function_start = runtime_loading_text.find("function f(e){")
    function_end = runtime_loading_text.find("}function p(e){", function_start)
    if function_start == -1 or function_end == -1:
        raise SystemExit("Local desktop runtime patch failed: runtime loading-page logo snippet not found")
    runtime_loading_text = (
        runtime_loading_text[:function_start]
        + "function f(e){let{className:t}=e;return(0,c.jsx)(`div`,{\"aria-hidden\":`true`,className:i(`relative inline-flex shrink-0 items-center justify-center overflow-hidden rounded-[22%]`,t),children:(0,c.jsx)(`img`,{src:`/assets/local-ai-console-gradient.png`,alt:``,className:`size-full object-contain`})})}"
        + runtime_loading_text[function_end:]
    )
    runtime_loading_bundle.write_text(runtime_loading_text)

for asset_bundle in runtime_webview_assets.glob("*.js"):
    rewrite_locale_message(asset_bundle, "threadOverlay.defaultTitle", "Local LLM Console")
    rewrite_locale_message(asset_bundle, "hotkeyWindow.defaultTitle", "Local LLM Console")
    rewrite_locale_message(asset_bundle, "appHeader.installUpdate.confirmTitle", "Update Local LLM Console now?")
    rewrite_locale_message(asset_bundle, "appHeader.installUpdate.confirmSubtitle", "Local LLM Console will quit to install the update, interrupting any local threads running on this machine.")
    rewrite_locale_message(asset_bundle, "appUpdate.installProgress.subtitle", "Local LLM Console will restart when installation finishes.")
    rewrite_locale_message(asset_bundle, "appUpdate.recovery.updateCodex", "Update Local LLM Console")
    rewrite_locale_message(asset_bundle, "codex.announcementModalStory.title", "")
    rewrite_locale_message(asset_bundle, "codex.announcementModalStory.body", "")
    rewrite_locale_message(asset_bundle, "codex.announcementModalStory.primary", "")
    rewrite_locale_message(asset_bundle, "codex.announcementModalStory.dismiss", "")
PY
    printf '%s' "$LOCAL_SOURCE_FINGERPRINT" > "$LOCAL_RUNTIME_STAMP"
fi

LOCAL_SHELL_ASAR_NEEDS_REBUILD=1
if [[ -f "$BASE_SHELL_ASAR" && -f "$LOCAL_SHELL_ASAR_STAMP" ]]; then
    if [[ "$(<"$LOCAL_SHELL_ASAR_STAMP")" == "$LOCAL_SOURCE_FINGERPRINT" ]]; then
        LOCAL_SHELL_ASAR_NEEDS_REBUILD=0
    fi
fi

if [[ "$LOCAL_SHELL_ASAR_NEEDS_REBUILD" -eq 1 ]]; then
    TMP_SHELL_ASAR="${BASE_SHELL_ASAR}.tmp.$$"
    rm -f "$TMP_SHELL_ASAR"
    npx --yes asar pack "$LOCAL_RUNTIME_APP_DIR" "$TMP_SHELL_ASAR"
    mv "$TMP_SHELL_ASAR" "$BASE_SHELL_ASAR"
    printf '%s' "$LOCAL_SOURCE_FINGERPRINT" > "$LOCAL_SHELL_ASAR_STAMP"
fi

export CODEX_DESKTOP_RUNTIME_NAME="${CODEX_DESKTOP_RUNTIME_NAME:-Local LLM Console}"
export CODEX_DESKTOP_WINDOW_ICON_PATH="$LOCAL_RUNTIME_ICON_PATH"
export CODEX_DESKTOP_ELECTRON_APP_PATH="$LOCAL_RUNTIME_APP_DIR"
export CODEX_ELECTRON_USER_DATA_PATH="${CODEX_ELECTRON_USER_DATA_PATH:-$LOCAL_USER_DATA_DIR}"
terminate_stale_local_runtime_processes
if [[ -x "$LOCAL_HOST_SERVICE_HELPER" ]]; then
    "$LOCAL_HOST_SERVICE_HELPER" >/dev/null 2>&1 || true
fi

SOURCE_WEBVIEW_DIR="$LOCAL_WEBVIEW_SOURCE_DIR"
export CODEX_DESKTOP_WEBVIEW_DIR="$LOCAL_WEBVIEW_DIR"
LOCAL_WEBVIEW_SOURCE_FINGERPRINT="$({
    find "$LOCAL_WEBVIEW_SOURCE_DIR" -type f -printf '%P:%s:%T@\n' | LC_ALL=C sort
    printf 'launcher:%s\n' "$(stat -c '%Y:%s' "$SCRIPT_DIR/start-local.sh")"
    printf 'patch-version:%s\n' "$CODEX_DESKTOP_LOCAL_WEBVIEW_PATCH_VERSION"
} | sha256sum | awk '{print $1}')"
LOCAL_WEBVIEW_NEEDS_REBUILD=1
if [[ -d "$LOCAL_WEBVIEW_DIR" && -f "$LOCAL_WEBVIEW_STAMP" ]]; then
    if [[ "$(<"$LOCAL_WEBVIEW_STAMP")" == "$LOCAL_WEBVIEW_SOURCE_FINGERPRINT" ]]; then
        LOCAL_WEBVIEW_NEEDS_REBUILD=0
    fi
fi

if [[ "$LOCAL_WEBVIEW_NEEDS_REBUILD" -eq 1 ]]; then
SOURCE_WEBVIEW_DIR="$SOURCE_WEBVIEW_DIR" LOCAL_WEBVIEW_DIR="$LOCAL_WEBVIEW_DIR" python3 - <<'PY'
from pathlib import Path
import os
import re
import shutil
import sys
import tempfile

source = Path(os.environ["SOURCE_WEBVIEW_DIR"])
target = Path(os.environ["LOCAL_WEBVIEW_DIR"])
staging = Path(tempfile.mkdtemp(prefix=f"{target.name}-", dir=str(target.parent)))
shutil.rmtree(staging, ignore_errors=True)
shutil.copytree(source, staging)
shutil.rmtree(target, ignore_errors=True)
staging.replace(target)


def patch_bundle(path: Path, replacements: list[tuple[str, str]], *, error_message: str) -> None:
    text = path.read_text()
    changed = False
    for original, patched in replacements:
        if original not in text:
            continue
        text = text.replace(original, patched, 1)
        changed = True
    if changed:
        path.write_text(text)


def patch_text_file(path: Path, replacements: list[tuple[str, str]], *, error_message: str) -> None:
    text = path.read_text()
    changed = False
    for original, patched in replacements:
        if original not in text:
            continue
        text = text.replace(original, patched, 1)
        changed = True
    if changed:
        path.write_text(text)


def rewrite_default_messages(path: Path, transform) -> None:
    text = path.read_text()
    changed = False

    def replace(match):
        nonlocal changed
        original = match.group(1)
        patched = transform(original)
        if patched != original:
            changed = True
            return f"defaultMessage:`{patched}`"
        return match.group(0)

    patched_text = re.sub(r"defaultMessage:`([^`]*)`", replace, text)
    if changed:
        path.write_text(patched_text)


def rewrite_locale_message(path: Path, key: str, value: str) -> None:
    text = path.read_text()
    pattern = rf'("{re.escape(key)}":`)([^`]*)`'
    patched_text, count = re.subn(pattern, rf"\1{value}`", text)
    if count:
        path.write_text(patched_text)


index_html = target / "index.html"
patch_text_file(
    index_html,
    [
        ("<title>Codex</title>", "<title>Local LLM Console</title>"),
    ],
    error_message="Local desktop webview patch failed: expected index.html branding snippet not found",
)

runtime_settings_script_hash = "sha256-E2isW5LIwE3Wbjd98bmFq8L3MGT0cyYcsqNRWufMnbA="
runtime_bootstrap_script_tag = '    <script src="./assets/local-ai-console-bootstrap.js"></script>\n'
runtime_settings_script = """    <script>
      (() => {
        window.__openLocalSettings = (section = `general-settings`) => {
          const nextSection = typeof section === `string` && section.trim().length > 0 ? section.trim() : `general-settings`;
          const nextPath = `/settings/${nextSection}`;
          if (window.location.pathname === nextPath) return;
          window.history.pushState({}, ``, nextPath);
          window.dispatchEvent(new PopStateEvent(`popstate`));
        };
      })();
    </script>
"""
runtime_settings_csp_original = "script-src &#39;self&#39; &#39;sha256-Z2/iFzh9VMlVkEOar1f/oSHWwQk3ve1qk/C2WdsC4Xk=&#39; &#39;wasm-unsafe-eval&#39;"
runtime_settings_csp_patched = f"script-src &#39;self&#39; &#39;sha256-Z2/iFzh9VMlVkEOar1f/oSHWwQk3ve1qk/C2WdsC4Xk=&#39; &#39;{runtime_settings_script_hash}&#39; &#39;wasm-unsafe-eval&#39;"

index_html_text = index_html.read_text()
legacy_settings_script_hash = "sha256-5k4JkxIm3KiM/KmfRx8pzEyLPiwx6uNO7fSyWH5bOsI="
if runtime_settings_script_hash not in index_html_text:
    if legacy_settings_script_hash in index_html_text:
        index_html_text = index_html_text.replace(
            legacy_settings_script_hash,
            runtime_settings_script_hash,
        )
    elif runtime_settings_csp_original in index_html_text:
        index_html_text = index_html_text.replace(
            runtime_settings_csp_original,
            runtime_settings_csp_patched,
            1,
        )
    else:
        raise SystemExit("Local desktop webview patch failed: settings CSP snippet not found")

if "window.__openLocalSettings" not in index_html_text:
    if runtime_bootstrap_script_tag in index_html_text:
        index_html_text = index_html_text.replace(
            runtime_bootstrap_script_tag,
            f"{runtime_settings_script}{runtime_bootstrap_script_tag}",
            1,
        )
    elif "</body>" in index_html_text:
        index_html_text = index_html_text.replace(
            "</body>",
            f"{runtime_settings_script}</body>",
            1,
        )
    else:
        raise SystemExit("Local desktop webview patch failed: index.html body end snippet not found")

index_html.write_text(index_html_text)

settings_shared = next((target / "assets").glob("settings-shared-*.js"), None)
if settings_shared is None:
    raise SystemExit("Local desktop webview patch failed: settings-shared bundle not found")

patch_text_file(
    settings_shared,
    [
        (
            "return (0, u.jsxs)(`div`, {\n"
            "    children: [\n"
            "      (0, u.jsx)(t, {\n"
            "        id: `settings.section.mcp-settings.subtitle`,\n"
            "        defaultMessage: `Connect external tools and data sources. `,\n"
            "        description: `Subtitle for MCP settings section`,\n"
            "      }),\n"
            "      (0, u.jsx)(`a`, {\n"
            "        className: `inline-flex items-center gap-1 text-base text-token-text-link-foreground`,\n"
            "        href: s,\n"
            "        target: `_blank`,\n"
            "        rel: `noreferrer`,\n"
            "        children: (0, u.jsx)(t, {\n"
            "          id: `settings.section.mcp-settings.learnMore`,\n"
            "          defaultMessage: `Learn more.`,\n"
            "          description: `Label for MCP docs link`,\n"
            "        }),\n"
            "      }),\n"
            "    ],\n"
            "  });",
            "return (0, u.jsx)(`div`, {\n"
            "    children: (0, u.jsx)(t, {\n"
            "      id: `settings.section.mcp-settings.subtitle`,\n"
            "      defaultMessage: `Connect external tools and data sources.`,\n"
            "      description: `Subtitle for MCP settings section`,\n"
            "    }),\n"
            "  });",
        ),
    ],
    error_message="Local desktop webview patch failed: MCP settings learn-more block not found",
)

agent_settings = next((target / "assets").glob("agent-settings-*.js"), None)
if agent_settings is None:
    raise SystemExit("Local desktop webview patch failed: agent-settings bundle not found")

patch_text_file(
    agent_settings,
    [
        (
            "defaultMessage:`Configure approval policy and sandbox settings <a>Learn more</a>`",
            "defaultMessage:`Configure approval policy and sandbox settings`",
        ),
        (
            "defaultMessage:`Restart Codex after editing to apply changes`",
            "defaultMessage:`Restart Local LLM Console after editing to apply changes`",
        ),
        (
            "i?(0,q.jsxs)(L,{className:`gap-2`,children:[(0,q.jsx)(L.Header,{title:(0,q.jsx)(g,{id:`settings.agent.importSettings.sectionTitle`,defaultMessage:`Import external agent config`,description:`Heading for the inline external agent config import section`}),subtitle:(0,q.jsx)(g,{id:`settings.agent.importSettings.sectionSubtitle`,defaultMessage:`Detect and import migratable settings from another agent`,description:`Subtitle for the inline external agent config import section`})}),(0,q.jsx)(L.Content,{children:(0,q.jsx)(Se,{children:oe?(0,q.jsx)(B,{label:(0,q.jsx)(g,{id:`settings.agent.importSettings.loadingLabel`,defaultMessage:`Checking for imports`,description:`Label shown while home-scoped external config migration items are loading`}),description:(0,q.jsx)(g,{id:`settings.agent.importSettings.detectingDescription`,defaultMessage:`Checking for compatible external settings, AGENTS.md, and skills`,description:`Description shown while home-scoped external config migration items are loading`}),control:(0,q.jsx)(O,{className:`h-4 w-4`})}):f.length===0?(0,q.jsx)(y,{title:(0,q.jsx)(g,{id:`settings.agent.importSettings.emptyLabel`,defaultMessage:`No imports found`,description:`Label shown when no home-scoped external config migration items are available`}),description:(0,q.jsx)(g,{id:`settings.agent.importSettings.emptyDescription`,defaultMessage:`No external settings were found. You're all caught up!`,description:`Description for the import settings row when no home-scoped external config items are available`})}):(0,q.jsxs)(q.Fragment,{children:[f.map(e=>(0,q.jsx)(B,{label:Ae(r,e),description:e.description,control:(0,q.jsx)(k,{className:`h-4 w-4 rounded-[3px]`,checked:ne[Ke(e)]??!1,disabled:ie.isPending,onCheckedChange:t=>{u(n=>({...n,[Ke(e)]:t}))}})},Ke(e))),(0,q.jsx)(B,{label:(0,q.jsx)(g,{id:`settings.agent.importSettings.summaryLabel`,defaultMessage:`{count} selected`,description:`Summary label for selected home-scoped external config migration items`,values:{count:p.length}}),description:(0,q.jsx)(g,{id:`settings.agent.importSettings.summaryDescription`,defaultMessage:`Import selected config`,description:`Summary description for the inline external agent config import section`}),control:(0,q.jsx)(ge,{color:`secondary`,size:`toolbar`,loading:ie.isPending,disabled:p.length===0,onClick:()=>{ie.mutateAsync(p)},children:(0,q.jsx)(g,{id:`settings.agent.importSettings.applySelected`,defaultMessage:`Apply selected`,description:`Button label to apply selected home-scoped external config migration items`})})})]})})})]}):null",
            "",
        ),
        (
            "}),actions:(0,q.jsxs)(ge,{color:`ghost`,size:`toolbar`,disabled:R?.filePath==null,onClick:()=>{R?.filePath!=null&&x({path:R.filePath,cwd:R.workspaceRoot==null?null:d(R.workspaceRoot),hostId:e,target:Te?.preferredTarget,openFile:le.mutate})},children:[(0,q.jsx)(g,{id:`settings.agent.configuration.scope.open`,defaultMessage:`Open config.toml`,description:`Button label to open the selected config file`}),(0,q.jsx)(F,{className:`icon-2xs`})]})",
            "})",
        ),
        (
            "defaultMessage:`Codex dependencies look healthy`",
            "defaultMessage:`Workspace dependencies look healthy`",
        ),
        (
            "defaultMessage:`Codex dependencies may need repair. Send /feedback if this keeps happening`",
            "defaultMessage:`Workspace dependencies may need repair. Send /feedback if this keeps happening`",
        ),
        (
            "defaultMessage:`Couldn’t diagnose Codex dependencies`",
            "defaultMessage:`Couldn’t diagnose workspace dependencies`",
        ),
        (
            "defaultMessage:`Codex dependencies were reinstalled`",
            "defaultMessage:`Workspace dependencies were reinstalled`",
        ),
        (
            "defaultMessage:`Codex dependency download canceled`",
            "defaultMessage:`Workspace dependency download canceled`",
        ),
        (
            "defaultMessage:`Couldn’t reinstall Codex dependencies`",
            "defaultMessage:`Couldn’t reinstall workspace dependencies`",
        ),
        (
            "defaultMessage:`No Codex dependency download is running`",
            "defaultMessage:`No workspace dependency download is running`",
        ),
        (
            "defaultMessage:`Canceling Codex dependency download`",
            "defaultMessage:`Canceling workspace dependency download`",
        ),
        (
            "defaultMessage:`Couldn’t cancel Codex dependency download`",
            "defaultMessage:`Couldn’t cancel workspace dependency download`",
        ),
        (
            "defaultMessage:`Codex dependencies`",
            "defaultMessage:`Workspace dependencies`",
        ),
        (
            "defaultMessage:`Allow Codex to install and expose bundled Node.js and Python tools`",
            "defaultMessage:`Allow the app to install and expose bundled Node.js and Python tools`",
        ),
        (
            "defaultMessage:`Enable Codex dependencies`",
            "defaultMessage:`Enable workspace dependencies`",
        ),
        (
            "defaultMessage:`Diagnose issues in Codex Workspace`",
            "defaultMessage:`Diagnose issues in the local workspace`",
        ),
        (
            "defaultMessage:`Choose when Codex asks for approval`",
            "defaultMessage:`Choose when the app asks for approval`",
        ),
        (
            "defaultMessage:`Choose how much Codex can do when running commands`",
            "defaultMessage:`Choose how much the app can do when running commands`",
        ),
    ],
    error_message="Local desktop webview patch failed: agent-settings branding snippet not found",
)

general_settings_files = list((target / "assets").glob("general-settings-*.js"))
if not general_settings_files:
    raise SystemExit("Local desktop webview patch failed: general-settings bundle not found")

for general_settings in general_settings_files:
    general_settings_text = general_settings.read_text()
    if "Codex" not in general_settings_text:
        continue
    patch_text_file(
        general_settings,
        [
            (
                "defaultMessage:`Set when Codex alerts you that it's finished`",
                "defaultMessage:`Set when the app alerts you that it's finished`",
            ),
            (
                "defaultMessage:`Codex browser control`",
                "defaultMessage:`Browser control`",
            ),
            (
                "defaultMessage:`Allow Codex to control the in-app browser for browser tasks. Restart Codex after changing this setting.`",
                "defaultMessage:`Allow the app to control the in-app browser for browser tasks. Restart Local LLM Console after changing this setting.`",
            ),
            (
                "defaultMessage:`Allows other signed-in Codex clients to connect to this computer`",
                "defaultMessage:`Allows other signed-in clients to connect to this computer`",
            ),
            (
                "defaultMessage:`Enable the plugins experience in Codex.`",
                "defaultMessage:`Enable the plugins experience in the app.`",
            ),
            (
                "defaultMessage:`Restart Codex to apply experimental feature changes`",
                "defaultMessage:`Restart Local LLM Console to apply experimental feature changes`",
            ),
            (
                "defaultMessage:`Keep Codex in the macOS menu bar when the main window is closed`",
                "defaultMessage:`Keep the app in the macOS menu bar when the main window is closed`",
            ),
            (
                "defaultMessage:`Show Codex in the menu bar`",
                "defaultMessage:`Show the app in the menu bar`",
            ),
            (
                "defaultMessage:`Restart Codex to apply this change. The agent is still running in {currentEnvironment}.`",
                "defaultMessage:`Restart Local LLM Console to apply this change. The agent is still running in {currentEnvironment}.`",
            ),
            (
                "defaultMessage:`Codex can't run in {distributionName} because /usr/bin/bash is missing`",
                "defaultMessage:`The app can't run in {distributionName} because /usr/bin/bash is missing`",
            ),
            (
                "defaultMessage:`Queue follow-ups while Codex runs or steer the current run. Press {invertFollowUpShortcutLabel} to do the opposite for one message`",
                "defaultMessage:`Queue follow-ups while the app runs or steer the current run. Press {invertFollowUpShortcutLabel} to do the opposite for one message`",
            ),
            (
                "defaultMessage:`Adjust the base size used for the Codex UI`",
                "defaultMessage:`Adjust the base size used for the UI`",
            ),
            (
                "defaultMessage:`Keep your computer awake while Codex is running a chat`",
                "defaultMessage:`Keep your computer awake while the app is running a chat`",
            ),
        ],
        error_message="Local desktop webview patch failed: general-settings branding snippet not found",
    )

local_environments = next((target / "assets").glob("local-environments-settings-page-*.js"), None)
if local_environments is None:
    raise SystemExit("Local desktop webview patch failed: local-environments settings bundle not found")

patch_text_file(
    local_environments,
    [
        (
            "defaultMessage:`Local environments tell Codex how to set up worktrees for a project. {learnMore}`",
            "defaultMessage:`Local environments define how to set up worktrees for a project.`",
        ),
        (
            "defaultMessage:`Learn more.`",
            "defaultMessage:``",
        ),
    ],
    error_message="Local desktop webview patch failed: local-environments branding snippet not found",
)

skills_page = next((target / "assets").glob("skills-page-*.js"), None)
if skills_page is None:
    raise SystemExit("Local desktop webview patch failed: skills page bundle not found")

patch_text_file(
    skills_page,
    [
        (
            "defaultMessage:`This conversation is running in Codex Cloud.`",
            "defaultMessage:`This conversation is running in the cloud.`",
        ),
        (
            "defaultMessage:`Give Codex superpowers. <link>Learn more</link>`",
            "defaultMessage:`Reusable workflows for local models.`",
        ),
    ],
    error_message="Local desktop webview patch failed: skills page branding snippet not found",
)

index_bundle = next((target / "assets").glob("index-*.js"), None)
if index_bundle is None:
    raise SystemExit("Local desktop webview patch failed: index bundle not found")

patch_text_file(
    index_bundle,
    [
        (
            "(0,$.jsx)(oK,{}),R?.type===`cloud`?null:(0,$.jsx)(lK,{conversationId:K,hostId:te},K??`new-conversation`),(0,$.jsx)(_K,{conversationId:K})",
            "(0,$.jsx)(oK,{}),(0,$.jsx)(_K,{conversationId:K})",
        ),
        (
            "xt&&(0,$.jsx)(gK,{conversationId:K,hostId:q.hostId}),",
            "",
        ),
        (
            "Fn||st?(0,$.jsx)(RG,{cwd:On,roots:Mi,hostId:sr}):null,",
            "",
        ),
        (
            "De=n??(0,$.jsx)(yh,{tooltipContent:(0,$.jsx)(Y,{id:`codex.header.settingsTooltip`,defaultMessage:`Settings`,description:`Tooltip text for opening settings`}),children:(0,$.jsx)(xp,{color:`ghost`,size:`icon`,children:(0,$.jsx)(Zm,{className:`icon-xs`})})})",
            "De=n??(0,$.jsx)(yh,{tooltipContent:(0,$.jsx)(Y,{id:`codex.header.settingsTooltip`,defaultMessage:`Settings`,description:`Tooltip text for opening settings`}),children:(0,$.jsx)(xp,{color:`ghost`,size:`icon`,onClick:()=>{a(!1),o(`/settings/general-settings`,{state:W})},children:(0,$.jsx)(Zm,{className:`icon-xs`})})})",
        ),
        (
            "function uw(){let e=(0,Q.c)(23),{authMethod:t,planAtLogin:n}=$f(),{data:r}=Xi(),{data:i}=Ji(),a=t===`chatgpt`,o;",
            "function uw(){let e=(0,Q.c)(23),{authMethod:t,planAtLogin:n}=$f(),{data:r}=Xi(),{data:i}=Ji(),a=t===`chatgpt`,o,N=d();",
        ),
        (
            ",d=s?.plan??n,f=r?.accounts,p;e[2]!==i||e[3]!==t||e[4]!==d||e[5]!==f?(p=ow({authMethod:t,plan:d,currentAccount:i,accounts:f}),e[2]=i,e[3]=t,e[4]=d,e[5]=f,e[6]=p):p=e[6];",
            ",P=s?.plan??n,f=r?.accounts,p;e[2]!==i||e[3]!==t||e[4]!==P||e[5]!==f?(p=ow({authMethod:t,plan:P,currentAccount:i,accounts:f}),e[2]=i,e[3]=t,e[4]=P,e[5]=f,e[6]=p):p=e[6];",
        ),
        (
            "children:(0,$.jsx)(sw,{triggerButton:(0,$.jsx)(Ky,{icon:b,label:x,onClick:dw,trailing:S,iconClassName:`icon-sm`})})",
            "children:(0,$.jsx)(Ky,{icon:b,label:x,onClick:()=>{N(`/settings/general-settings`)},trailing:S,iconClassName:`icon-sm`})",
        ),
        (
            "Ue=(0,$.jsxs)(dh,{open:i,onOpenChange:a,contentWidth:Ee,triggerButton:De,children:[Oe,He]})",
            "Ue=(0,$.jsx)(`div`,{className:`contents`,children:De})",
        ),
        (
            "Ne=()=>{a(!1),E.dispatchMessage(`show-settings`,{section:Tg})}",
            "Ne=()=>{a(!1),o(`/settings/general-settings`,{state:W})}",
        ),
        (
            "(0,$.jsx)(lh.Item,{LeftIcon:xa,RightIcon:im,href:He,children:(0,$.jsx)(Y,{id:`composer.mode.remote.connectToCloud`,defaultMessage:`Connect Codex web`,description:`Menu item to connect Codex Cloud`})}),(0,$.jsx)(lh.Item,{LeftIcon:VI,className:`cursor-not-allowed`,disabled:!0,tooltipText:y.formatMessage({id:`composer.mode.remote.connectToCloudDisabledTooltip`,defaultMessage:`Set up an environment via Codex web to enable sending tasks to the cloud`,description:`Tooltip for disabled send to cloud item when Cloud is not connected`}),children:(0,$.jsx)(`span`,{className:`truncate`,children:(0,$.jsx)(Y,{id:`composer.mode.remote.sendToCloud`,defaultMessage:`Send to cloud`,description:`Disabled label when Codex Cloud is not connected`})})})",
            "(0,$.jsx)(lh.Item,{LeftIcon:ih,disabled:typeof window!=`undefined`&&window.__isLocalLLMConsoleRemoteConnected?!window.__isLocalLLMConsoleRemoteConnected():!0,onClick:()=>{p(!1),_(!1),typeof window!=`undefined`&&window.__handleLocalLLMConsoleRemotePicker&&window.__handleLocalLLMConsoleRemotePicker()},tooltipText:typeof window!=`undefined`&&window.__isLocalLLMConsoleRemoteConnected&&!window.__isLocalLLMConsoleRemoteConnected()?y.formatMessage({id:`composer.mode.remote.workOnHostDisabledTooltip`,defaultMessage:`Connect to a remote host first.`,description:`Tooltip for disabled remote host entry in the composer mode dropdown`}):y.formatMessage({id:`composer.mode.remote.workOnHostTooltip`,defaultMessage:`Use the configured remote host for this session, or open Configuration if it is not set up yet.`,description:`Tooltip for the remote host entry in the composer mode dropdown`}),children:(0,$.jsx)(Y,{id:`composer.mode.remote.workOnHost`,defaultMessage:`Work on remote host`,description:`Menu item to use the configured remote host`})})",
        ),
        (
            "defaultMessage:`Codex settings`",
            "defaultMessage:`Local LLM Console settings`",
        ),
        (
            "defaultMessage:`Set up an environment via Codex web`",
            "defaultMessage:`Set up an environment on the web`",
        ),
        (
            "defaultMessage:`Connect Codex web`",
            "defaultMessage:`Connect web`",
        ),
        (
            "defaultMessage:`Set up an environment via Codex web to enable sending tasks to the cloud`",
            "defaultMessage:`Set up an environment on the web to enable sending tasks to the cloud`",
        ),
        (
            "defaultMessage:`Connect your favorite apps to Codex`",
            "defaultMessage:`Connect your favorite apps`",
        ),
        (
            "defaultMessage:`Ask Codex anything locally`",
            "defaultMessage:`Ask anything locally`",
        ),
        (
            "defaultMessage:`Ask Codex anything in the cloud`",
            "defaultMessage:`Ask anything in the cloud`",
        ),
        (
            "defaultMessage:`Codex app`",
            "defaultMessage:`Local LLM Console`",
        ),
        (
            "defaultMessage:`Dismiss Codex app banner`",
            "defaultMessage:`Dismiss Local LLM Console banner`",
        ),
        (
            "defaultMessage:`Build faster with the Codex app. Download now or {learnMoreLink}`",
            "defaultMessage:`Local LLM Console is already installed.`",
        ),
        (
            "defaultMessage:`Our latest frontier agentic coding model — smarter, faster, and more capable at general technical work. {link}`",
            "defaultMessage:`Our latest frontier agentic coding model — smarter, faster, and more capable at general technical work.`",
        ),
    ],
    error_message="Local desktop webview patch failed: index branding snippet not found",
)

patch_text_file(
    index_bundle,
    [
        (
            '"read-config":n9((e,t)=>e.readConfig(t)),"read-config-for-host":i9((e,{hostId:t,...n})=>e.sendRequest(`config/read`,n)),"refresh-remote-connection":async(e,{hostId:t})=>{',
            '"read-config":n9((e,t)=>e.readConfig(t)),"read-config-for-host":i9((e,{hostId:t,...n})=>e.sendRequest(`config/read`,n)),"refresh-remote-connections":async()=>Qe(`refresh-remote-connections`,{params:{}}),"refresh-remote-control-connections":async()=>Qe(`refresh-remote-control-connections`,{params:{}}),"save-codex-managed-remote-ssh-connections":async(e,t)=>Qe(`save-codex-managed-remote-ssh-connections`,{params:t??{}}),"set-remote-connection-auto-connect":async(e,t)=>Qe(`set-remote-connection-auto-connect`,{params:t??{}}),"refresh-remote-connection":async(e,{hostId:t})=>{',
        ),
    ],
    error_message="Local desktop webview patch failed: remote connection request handlers snippet not found",
)

local_models_bundle = next((target / "assets").glob("local-models-settings-*.js"), None)
if local_models_bundle is None:
    raise SystemExit("Local desktop webview patch failed: local-models settings bundle not found")

patch_text_file(
    local_models_bundle,
    [
        (
            """async function loadManagedRemoteSessionConnections() {
  let e = await sendLocalLlmConsoleRequest(`refresh-remote-connections`);
  return (e?.remoteConnections ?? []).filter((e) => e?.source === $);
}

function mergeManagedRemoteSessionConnections(e, t) {
  return [...e.filter((e) => e.hostId !== t.hostId && e.connectionType !== ee), t];
}""",
            """async function loadManagedRemoteSessionConnections() {
  let e = await sendLocalLlmConsoleRequest(`refresh-remote-connections`);
  let t = e?.remoteConnections;
  return (Array.isArray(t) ? t : []).filter((e) => e?.source === $);
}

function mergeManagedRemoteSessionConnections(e, t) {
  let n = Array.isArray(e) ? e : [];
  return [...n.filter((e) => e.hostId !== t.hostId && e.connectionType !== ee), t];
}""",
        ),
        (
            """async function applyLocalLlmConsoleHostService(e = `reload`) {
  let t = await fetch(`/__local-llm-console/host-service`, {
      method: `POST`,
      headers: { "Content-Type": `application/json` },
      body: JSON.stringify({ action: e }),
    }),
    n = null;
  try {
    n = await t.json();
  } catch {}
  if (!t.ok)
    throw new Error(
      typeof (n == null ? void 0 : n.error) == `string` && n.error.trim().length > 0
        ? n.error
        : `Unable to apply host settings immediately.`,
    );
  return n;
}""",
            """async function applyLocalLlmConsoleHostService(e = `reload`) {
  let t;
  try {
    t = await fetch(`/__local-llm-console/host-service`, {
      method: `POST`,
      headers: { "Content-Type": `application/json` },
      body: JSON.stringify({ action: e }),
    });
  } catch (t) {
    if (
      typeof window !== `undefined` &&
      (window.location.protocol === `file:` || window.location.protocol === `app:`)
    )
      return { ok: !0, skipped: !0, action: e };
    throw t;
  }
  let n = null;
  try {
    n = await t.json();
  } catch {}
  if (!t.ok)
    throw new Error(
      typeof (n == null ? void 0 : n.error) == `string` && n.error.trim().length > 0
        ? n.error
        : `Unable to apply host settings immediately.`,
    );
  return n;
}""",
        ),
    ],
    error_message="Local desktop webview patch failed: host service helper snippet not found",
)

vscode_bundle = next((target / "assets").glob("vscode-api-*.js"), None)
if vscode_bundle is None:
    raise SystemExit("Local desktop webview patch failed: vscode-api bundle not found")

patch_text_file(
    vscode_bundle,
    [
        (
            "function Lf(e){let t=[`ssh`,...Af({sshAlias:e.sshAlias,sshHost:e.sshHost,sshPort:e.sshPort,identity:e.identity})];return{id:e.hostId,display_name:e.displayName,kind:`ssh`,codex_cli_command:[],terminal_command:t}}",
            "function Lf(e){if(e.connectionType===`tailscale-websocket`&&(e.websocketUrl??e.websocket_url??``).trim().length>0)return{id:e.hostId,display_name:e.displayName,kind:`brix`,codex_cli_command:[],terminal_command:[],websocket_url:(e.websocketUrl??e.websocket_url??``).trim()};let t=[`ssh`,...Af({sshAlias:e.sshAlias,sshHost:e.sshHost,sshPort:e.sshPort,identity:e.identity})];return{id:e.hostId,display_name:e.displayName,kind:`ssh`,codex_cli_command:[],terminal_command:t}}",
        ),
    ],
    error_message="Local desktop webview patch failed: vscode remote host conversion snippet not found",
)


def normalize_local_branding(message: str) -> str:
    if message in {"Learn more", "Learn more."}:
        return ""
    message = re.sub(r"\s*<[^>]+>Learn more</[^>]+>", "", message)
    message = message.replace("{learnMoreLink}", "").replace("  ", " ").strip()
    message = message.replace("GPT-5.3-Codex", "GPT-5.3")
    message = message.replace("CODEX", "LOCAL LLM CONSOLE")
    message = message.replace("Codex", "Local LLM Console")
    return message

for asset_bundle in (target / "assets").glob("*.js"):
    rewrite_default_messages(asset_bundle, normalize_local_branding)
    rewrite_locale_message(asset_bundle, "threadOverlay.defaultTitle", "Local LLM Console")
    rewrite_locale_message(asset_bundle, "hotkeyWindow.defaultTitle", "Local LLM Console")
    rewrite_locale_message(asset_bundle, "appHeader.installUpdate.confirmTitle", "Update Local LLM Console now?")
    rewrite_locale_message(asset_bundle, "appHeader.installUpdate.confirmSubtitle", "Local LLM Console will quit to install the update, interrupting any local threads running on this machine.")
    rewrite_locale_message(asset_bundle, "appUpdate.installProgress.subtitle", "Local LLM Console will restart when installation finishes.")
    rewrite_locale_message(asset_bundle, "appUpdate.recovery.updateCodex", "Update Local LLM Console")
    rewrite_locale_message(asset_bundle, "codex.announcementModalStory.title", "")
    rewrite_locale_message(asset_bundle, "codex.announcementModalStory.body", "")
    rewrite_locale_message(asset_bundle, "codex.announcementModalStory.primary", "")
    rewrite_locale_message(asset_bundle, "codex.announcementModalStory.dismiss", "")

font_bundle = next((target / "assets").glob("font-settings-*.js"), None)
if font_bundle is None:
    raise SystemExit("Local desktop webview patch failed: font-settings bundle not found")

original = (
    "if(l.useHiddenModels?l.availableModels.has(e.model):!e.hidden)"
    "{let t=o===`copilot`?[e.supportedReasoningEfforts.find(He)??"
    "{reasoningEffort:`medium`,description:`medium effort`}]:"
    "[...e.supportedReasoningEfforts];n.models.push({...e,"
    "supportedReasoningEfforts:t}),r=e.isDefault?e:r}}),"
    "r??=n.models.find(e=>e.model===l.defaultModel)??null,"
    "{modelsByType:n,defaultModel:r}}"
)
previous_patched = (
    "if((o==null?!e.hidden:l.useHiddenModels?l.availableModels.has(e.model):!e.hidden))"
    "{let t=o===`copilot`?[e.supportedReasoningEfforts.find(He)??"
    "{reasoningEffort:`medium`,description:`medium effort`}]:"
    "[...e.supportedReasoningEfforts];n.models.push({...e,"
    "supportedReasoningEfforts:t}),r=e.isDefault?e:r}}),"
    "r??=n.models.find(e=>e.model===l.defaultModel)??null,"
    "{modelsByType:n,defaultModel:r}}"
)
patched = (
    "if(!e.hidden)"
    "{let t=o===`copilot`?[e.supportedReasoningEfforts.find(He)??"
    "{reasoningEffort:`medium`,description:`medium effort`}]:"
    "[...e.supportedReasoningEfforts];n.models.push({...e,"
    "supportedReasoningEfforts:t}),r=e.isDefault?e:r}}),"
    "r??=n.models.find(e=>e.model===l.defaultModel)??null,"
    "{modelsByType:n,defaultModel:r}}"
)

patch_bundle(
    font_bundle,
    [
        (original, patched),
        (previous_patched, patched),
    ],
    error_message="Local desktop webview patch failed: expected model filter snippet not found",
)

PY
    printf '%s' "$LOCAL_WEBVIEW_SOURCE_FINGERPRINT" > "$LOCAL_WEBVIEW_STAMP"
fi

exec "$BASE_START_SCRIPT" --user-data-dir="$LOCAL_USER_DATA_DIR" "$@"
