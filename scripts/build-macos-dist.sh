#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="$(mktemp -d)"
DIST_DIR="${MACOS_DIST_DIR:-$REPO_ROOT/dist/macos}"
DMG_PATH="${1:-$REPO_ROOT/Codex.dmg}"
APP_NAME="Local LLM Console"
ZIP_NAME="Local-LLM-Console-macos-unsigned.zip"
APP_BUNDLE_NAME="${APP_NAME}.app"
APP_BUNDLE_PATH="$DIST_DIR/$APP_BUNDLE_NAME"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
ICON_SOURCE="$REPO_ROOT/assets/local-ai-console-gradient.png"
MODEL_CATALOG_SOURCE="$REPO_ROOT/config/local-model-catalog.json"
WEBVIEW_SOURCE="$REPO_ROOT/webview"
CODEX_STAGE_SCRIPT="$REPO_ROOT/scripts/stage-codex-runtime.sh"
CODEX_HELPER_SOURCE="$REPO_ROOT/launcher/local-ai-console-codex"
CODEX_CLI_WRAPPER_SOURCE="$REPO_ROOT/launcher/codex-local-desktop-cli"
MACOS_LAUNCHER_PATH="Contents/MacOS/Codex"
MACOS_BINARY_PATH="Contents/MacOS/Codex.bin"
CLI_WRAPPER_RELATIVE="Contents/Resources/local-llm-console/bin/codex-local-desktop-cli"
PLIST_PATH="Contents/Info.plist"
ASAR_PATH="Contents/Resources/app.asar"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*" >&2; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT
trap 'error "Failed at line $LINENO (exit code $?)"' ERR

check_deps() {
    local missing=()
    local cmd=""
    for cmd in python3 node npx zip sips iconutil; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if command -v 7zz >/dev/null 2>&1; then
        SEVEN_ZIP_CMD="7zz"
    elif command -v 7z >/dev/null 2>&1; then
        SEVEN_ZIP_CMD="7z"
    else
        missing+=("7z/7zz")
    fi

    if [ "${#missing[@]}" -ne 0 ]; then
        error "Missing dependencies: ${missing[*]}"
    fi
}

extract_dmg() {
    local dmg_path="$1"
    local extract_dir="$WORK_DIR/dmg-extract"
    local seven_log="$WORK_DIR/7z.log"
    local seven_zip_status=0

    mkdir -p "$extract_dir"
    if "$SEVEN_ZIP_CMD" x -y -snl "$dmg_path" -o"$extract_dir" >"$seven_log" 2>&1; then
        :
    else
        seven_zip_status=$?
    fi

    local app_dir=""
    app_dir="$(find "$extract_dir" -maxdepth 3 -name 'Codex.app' -type d | head -n 1)"

    if [ "$seven_zip_status" -ne 0 ]; then
        if [ -n "$app_dir" ]; then
            warn "7z exited with code $seven_zip_status but the app bundle was found; continuing"
        else
            cat "$seven_log" >&2
            error "Failed to extract DMG"
        fi
    fi

    [ -n "$app_dir" ] || error "Could not find Codex.app inside $dmg_path"
    printf '%s\n' "$app_dir"
}

stage_codex_runtime() {
    local app_bundle_path="$1"
    local vendor_dir="$app_bundle_path/Contents/Resources/local-llm-console/vendor"

    [ -x "$CODEX_STAGE_SCRIPT" ] || chmod 755 "$CODEX_STAGE_SCRIPT"
    [ -x "$CODEX_STAGE_SCRIPT" ] || error "Codex staging script not found: $CODEX_STAGE_SCRIPT"

    rm -rf "$vendor_dir"
    mkdir -p "$vendor_dir"
    "$CODEX_STAGE_SCRIPT" --dest "$vendor_dir" darwin-arm64 darwin-x64
}

install_bundled_helpers() {
    local app_bundle_path="$1"
    local helper_dir="$app_bundle_path/Contents/Resources/local-llm-console/bin"

    [ -f "$CODEX_HELPER_SOURCE" ] || error "Missing bundled Codex helper source: $CODEX_HELPER_SOURCE"
    [ -f "$CODEX_CLI_WRAPPER_SOURCE" ] || error "Missing Codex CLI wrapper source: $CODEX_CLI_WRAPPER_SOURCE"

    mkdir -p "$helper_dir"
    cp "$CODEX_HELPER_SOURCE" "$helper_dir/local-ai-console-codex"
    cp "$CODEX_CLI_WRAPPER_SOURCE" "$helper_dir/codex-local-desktop-cli"
    chmod 755 "$helper_dir/local-ai-console-codex" "$helper_dir/codex-local-desktop-cli"
}

install_model_catalog() {
    local app_bundle_path="$1"
    local config_dir="$app_bundle_path/Contents/Resources/local-llm-console/config"

    [ -f "$MODEL_CATALOG_SOURCE" ] || error "Missing model catalog: $MODEL_CATALOG_SOURCE"

    mkdir -p "$config_dir"
    cp "$MODEL_CATALOG_SOURCE" "$config_dir/local-model-catalog.json"
}

install_app_icon() {
    local app_bundle_path="$1"
    local iconset_dir="$WORK_DIR/local-llm-console.iconset"
    local icon_path="$WORK_DIR/local-llm-console.icns"

    rm -rf "$iconset_dir" "$icon_path"
    mkdir -p "$iconset_dir"

    while read -r size filename; do
        sips -z "$size" "$size" "$ICON_SOURCE" --out "$iconset_dir/$filename" >/dev/null
    done <<'EOF'
16 icon_16x16.png
32 icon_16x16@2x.png
32 icon_32x32.png
64 icon_32x32@2x.png
128 icon_128x128.png
256 icon_128x128@2x.png
256 icon_256x256.png
512 icon_256x256@2x.png
512 icon_512x512.png
1024 icon_512x512@2x.png
EOF

    iconutil -c icns "$iconset_dir" -o "$icon_path"
    cp "$icon_path" "$app_bundle_path/Contents/Resources/local-llm-console.icns"
}

write_app_launcher() {
    local launcher_path="$1"
    local binary_path="$2"
    local cli_wrapper_path="$3"

    cat >"$launcher_path" <<EOF
#!/bin/bash
set -euo pipefail

APP_CONTENTS="\$(cd "\$(dirname "\$0")/.." && pwd)"
export CODEX_HOME="\${CODEX_HOME:-\$HOME/.codex-local-desktop}"
export LOCAL_LLM_CONSOLE_CONFIG_PATH="\${LOCAL_LLM_CONSOLE_CONFIG_PATH:-\$CODEX_HOME/config.toml}"
export CODEX_CLI_PATH="\${CODEX_CLI_PATH:-\$APP_CONTENTS/Resources/local-llm-console/bin/codex-local-desktop-cli}"
export CODEX_DESKTOP_RUNTIME_NAME="\${CODEX_DESKTOP_RUNTIME_NAME:-Local LLM Console}"
export PATH="/opt/homebrew/bin:/usr/local/bin:\$PATH"

mkdir -p "\$CODEX_HOME"

exec "\$APP_CONTENTS/MacOS/Codex.bin" "\$@"
EOF

    chmod 755 "$launcher_path"
}

patch_runtime_asar() {
    local app_bundle_path="$1"
    local asar_extract_dir="$WORK_DIR/app-asar"

    rm -rf "$asar_extract_dir"
    npx --yes asar extract "$app_bundle_path/$ASAR_PATH" "$asar_extract_dir"

    rm -rf "$asar_extract_dir/webview"
    cp -a "$WEBVIEW_SOURCE" "$asar_extract_dir/webview"
    cp -f "$ICON_SOURCE" "$asar_extract_dir/webview/assets/local-ai-console-gradient.png"
    cp -f "$ICON_SOURCE" "$asar_extract_dir/webview/assets/app-D0g8sCle.png"

    APP_ASAR_EXTRACT_DIR="$asar_extract_dir" python3 - <<'PY'
from pathlib import Path
import json
import os
import re

root = Path(os.environ["APP_ASAR_EXTRACT_DIR"])


def replace_once(path: Path, original: str, patched: str, *, error_message: str) -> None:
    text = path.read_text()
    if original not in text:
        raise SystemExit(error_message)
    path.write_text(text.replace(original, patched, 1))


def replace_optional(path: Path, original: str, patched: str) -> None:
    text = path.read_text()
    if original not in text:
        return
    path.write_text(text.replace(original, patched, 1))


package_json = root / "package.json"
package_data = json.loads(package_json.read_text())
package_data["name"] = "local-llm-console"
package_data["productName"] = "Local LLM Console"
package_data["description"] = "Local LLM Console"
package_json.write_text(json.dumps(package_data, indent=2) + "\n")

bootstrap_bundle = root / ".vite" / "build" / "bootstrap.js"
replace_optional(
    bootstrap_bundle,
    "t.app.setName(e.Xr(b))",
    "t.app.setName(`Local LLM Console`)",
)
replace_optional(
    bootstrap_bundle,
    "message:`${t.app.getName()} failed to start.`",
    "message:`Local LLM Console failed to start.`",
)
replace_optional(
    bootstrap_bundle,
    "appName:t.app.getName()",
    "appName:`Local LLM Console`",
)

main_bundle = next((root / ".vite" / "build").glob("main-*.js"), None)
if main_bundle is None:
    raise SystemExit("macOS dist patch failed: main bundle not found")
replace_optional(
    main_bundle,
    "function dr(){return`Codex Desktop/${t.app.getVersion()} (${process.platform}; ${process.arch})`}",
    "function dr(){return`Local LLM Console/${t.app.getVersion()} (${process.platform}; ${process.arch})`}",
)
replace_optional(
    main_bundle,
    "throw Error(`Sign in to ChatGPT in Codex Desktop to ${e}.`)",
    "throw Error(`Sign in to Local LLM Console to ${e}.`)",
)
replace_optional(
    main_bundle,
    "function xr(e){return`Sign in to ChatGPT in Codex Desktop to ${e}.`}",
    "function xr(e){return`Sign in to Local LLM Console to ${e}.`}",
)
replace_optional(
    main_bundle,
    "clientInfo:{name:hn,title:`Codex Desktop`,version:u}",
    "clientInfo:{name:hn,title:`Local LLM Console`,version:u}",
)
replace_optional(
    main_bundle,
    "title:i??t.app.getName()",
    "title:`Local LLM Console`",
)
replace_optional(
    main_bundle,
    "hn=`Codex Desktop`",
    "hn=`Local LLM Console`",
)
replace_optional(
    main_bundle,
    "r.setToolTip(t.app.getName())",
    "r.setToolTip(`Local LLM Console`)",
)
replace_optional(
    main_bundle,
    "label:`About ${t.app.getName()}`",
    "label:`About Local LLM Console`",
)
replace_optional(
    main_bundle,
    "let e=t.app.getName();if(typeof t.app.showAboutPanel==`function`)",
    "let e=`Local LLM Console`;if(typeof t.app.showAboutPanel==`function`)",
)
replace_optional(
    main_bundle,
    "function Cg(e){let n=t.Menu.buildFromTemplate([{role:`quit`}]);return(Array.isArray(n)?n:n.items)[0]?.label??`Quit ${e}`}",
    "function Cg(e){let n=`Local LLM Console`,r=t.Menu.buildFromTemplate([{role:`quit`}]);return(Array.isArray(r)?r:r.items)[0]?.label?.replace(`Codex Desktop`,n).replace(`Codex`,n)??`Quit ${n}`}",
)
replace_optional(
    main_bundle,
    "let o=t.app.getName();if(t.dialog.showMessageBoxSync({type:`warning`,buttons:[`Quit`,`Cancel`],defaultId:0,cancelId:1,noLink:!0,title:`Quit ${o}?`,message:`Quit ${o}?`,detail:`Any local threads running on this machine will be interrupted and scheduled automations won't run`})!==0){a.preventDefault();return}",
    "let o=`Local LLM Console`;if(t.dialog.showMessageBoxSync({type:`warning`,buttons:[`Quit`,`Cancel`],defaultId:0,cancelId:1,noLink:!0,title:`Quit ${o}?`,message:``,detail:`Any local threads running on this machine will be interrupted and scheduled automations won't run`})!==0){a.preventDefault();return}",
)
replace_optional(
    main_bundle,
    "let a=i.kind===`local`?t.app.getName():i.display_name,o=await S.createPrimaryWindow({title:a,hostId:i.id,show:n});",
    "let a=i.kind===`local`?`Local LLM Console`:i.display_name,o=await S.createPrimaryWindow({title:a,hostId:i.id,show:n});",
)
replace_optional(
    main_bundle,
    "function bh(e){let t={id:e.id,display_name:e.displayName,kind:`ssh`,codex_cli_command:e.codexCliCommand,terminal_command:e.terminalCommand,default_workspaces:e.defaultWorkspaces??[],[zr]:{sshAlias:e.sshAlias??null,sshHost:e.sshHost,sshPort:e.sshPort,identity:e.identity,remotePort:e.remotePort??vh}};return e.localPort!=null&&(t.websocket_url=yh(e.localPort)),e.homeDir&&(t.home_dir=e.homeDir),t}function xh(t,n){let r=e.oi({sshAlias:t.sshAlias,sshHost:t.sshHost,sshPort:t.sshPort,identity:t.identity});return bh({id:t.hostId,displayName:`${gh}${t.displayName}`,localPort:n,sshAlias:t.sshAlias??null,sshHost:t.sshHost,sshPort:t.sshPort,identity:t.identity,remotePort:vh,codexCliCommand:[],terminalCommand:[`ssh`,...r],defaultWorkspaces:[]})}function Sh(t){return{id:t.hostId,display_name:t.displayName,kind:e.ri,codex_cli_command:[],terminal_command:[],default_workspaces:[],env_id:t.envId,environment_kind:t.environmentKind,online:t.online,busy:t.busy,os:t.os,arch:t.arch,app_server_version:t.appServerVersion,last_seen_at:t.lastSeenAt}}function Ch(t,n){return e.si(t)?Sh(t):xh(t,n)}",
    "function bh(e){let t={id:e.id,display_name:e.displayName,kind:`ssh`,codex_cli_command:e.codexCliCommand,terminal_command:e.terminalCommand,default_workspaces:e.defaultWorkspaces??[],[zr]:{sshAlias:e.sshAlias??null,sshHost:e.sshHost,sshPort:e.sshPort,identity:e.identity,remotePort:e.remotePort??vh}};return e.localPort!=null&&(t.websocket_url=yh(e.localPort)),e.homeDir&&(t.home_dir=e.homeDir),t}function xh(t,n){let r=e.oi({sshAlias:t.sshAlias,sshHost:t.sshHost,sshPort:t.sshPort,identity:t.identity});return bh({id:t.hostId,displayName:`${gh}${t.displayName}`,localPort:n,sshAlias:t.sshAlias??null,sshHost:t.sshHost,sshPort:t.sshPort,identity:t.identity,remotePort:vh,codexCliCommand:[],terminalCommand:[`ssh`,...r],defaultWorkspaces:[]})}function Sh(t){return{id:t.hostId,display_name:t.displayName,kind:e.ri,codex_cli_command:[],terminal_command:[],default_workspaces:[],env_id:t.envId,environment_kind:t.environmentKind,online:t.online,busy:t.busy,os:t.os,arch:t.arch,app_server_version:t.appServerVersion,last_seen_at:t.lastSeenAt}}function Nh(t){let n=(t.websocketUrl??t.websocket_url??``).trim();return{id:t.hostId,display_name:t.displayName,kind:`brix`,codex_cli_command:[],terminal_command:[],default_workspaces:[],websocket_url:n}}function Ch(t,n){return e.si(t)?Sh(t):t.connectionType===`tailscale-websocket`&&(t.websocketUrl??t.websocket_url??``).trim().length>0?Nh(t):xh(t,n)}",
)

runtime_webview_index = root / "webview" / "index.html"
replace_optional(
    runtime_webview_index,
    "<title>Codex</title>",
    "<title>Local LLM Console</title>",
)
PY

    rm -f "$app_bundle_path/$ASAR_PATH"
    npx --yes asar pack "$asar_extract_dir" "$app_bundle_path/$ASAR_PATH"
}

patch_info_plist() {
    local app_bundle_path="$1"

    APP_BUNDLE_PATH="$app_bundle_path" python3 - <<'PY'
from pathlib import Path
import hashlib
import os
import plistlib

app_bundle = Path(os.environ["APP_BUNDLE_PATH"])
plist_path = app_bundle / "Contents" / "Info.plist"
asar_path = app_bundle / "Contents" / "Resources" / "app.asar"

with plist_path.open("rb") as handle:
    plist = plistlib.load(handle)

asar_bytes = asar_path.read_bytes()
header_size = int.from_bytes(asar_bytes[12:16], byteorder="little")
asar_header = asar_bytes[16:16 + header_size]
asar_hash = hashlib.sha256(asar_header).hexdigest()
plist["CFBundleDisplayName"] = "Local LLM Console"
# Electron derives the macOS helper bundle names from CFBundleName. The
# upstream helper apps are still named "Codex Helper*.app", so keep the
# internal bundle name aligned with those helpers while using DisplayName for
# the visible app name.
plist["CFBundleName"] = "Codex"
plist["CFBundleIdentifier"] = "com.murat-taskaynatan.local-llm-console"
plist["CFBundleIconFile"] = "local-llm-console.icns"
plist["CFBundleIconName"] = "local-llm-console"
plist["CFBundleGetInfoString"] = "Local LLM Console"
plist["LSApplicationCategoryType"] = "public.app-category.developer-tools"
plist["ElectronAsarIntegrity"] = {
    "Resources/app.asar": {
        "algorithm": "SHA256",
        "hash": asar_hash,
    }
}

with plist_path.open("wb") as handle:
    plistlib.dump(plist, handle, sort_keys=False)
PY
}

prepare_bundle() {
    local source_app="$1"

    mkdir -p "$DIST_DIR"
    rm -rf "$APP_BUNDLE_PATH" "$ZIP_PATH"
    cp -a "$source_app" "$APP_BUNDLE_PATH"

    mv "$APP_BUNDLE_PATH/$MACOS_LAUNCHER_PATH" "$APP_BUNDLE_PATH/$MACOS_BINARY_PATH"
    install_app_icon "$APP_BUNDLE_PATH"
    install_bundled_helpers "$APP_BUNDLE_PATH"
    install_model_catalog "$APP_BUNDLE_PATH"
    stage_codex_runtime "$APP_BUNDLE_PATH"
    write_app_launcher "$APP_BUNDLE_PATH/$MACOS_LAUNCHER_PATH" "$MACOS_BINARY_PATH" "$CLI_WRAPPER_RELATIVE"

    patch_runtime_asar "$APP_BUNDLE_PATH"
    patch_info_plist "$APP_BUNDLE_PATH"

    rm -rf "$APP_BUNDLE_PATH/Contents/_CodeSignature"
}

package_zip() {
    (
        cd "$DIST_DIR"
        zip -qry "$ZIP_NAME" "$APP_BUNDLE_NAME"
    )
}

verify_bundle() {
    APP_BUNDLE_PATH="$APP_BUNDLE_PATH" python3 - <<'PY'
from pathlib import Path
import plistlib

app_bundle = Path(Path(Path(__import__("os").environ["APP_BUNDLE_PATH"])))
plist_path = app_bundle / "Contents" / "Info.plist"
launcher_path = app_bundle / "Contents" / "MacOS" / "Codex"
cli_wrapper_path = app_bundle / "Contents" / "Resources" / "local-llm-console" / "bin" / "codex-local-desktop-cli"
codex_helper_path = app_bundle / "Contents" / "Resources" / "local-llm-console" / "bin" / "local-ai-console-codex"
vendor_dir = app_bundle / "Contents" / "Resources" / "local-llm-console" / "vendor"
model_catalog_path = app_bundle / "Contents" / "Resources" / "local-llm-console" / "config" / "local-model-catalog.json"

with plist_path.open("rb") as handle:
    plist = plistlib.load(handle)

assert plist["CFBundleDisplayName"] == "Local LLM Console"
assert plist["CFBundleIdentifier"] == "com.murat-taskaynatan.local-llm-console"
assert launcher_path.is_file()
assert cli_wrapper_path.is_file()
assert codex_helper_path.is_file()
assert vendor_dir.is_dir()
assert model_catalog_path.is_file()
print("verified")
PY
}

main() {
    [ -f "$DMG_PATH" ] || error "DMG not found: $DMG_PATH"
    [ -d "$WEBVIEW_SOURCE" ] || error "Missing patched webview directory: $WEBVIEW_SOURCE"
    [ -f "$ICON_SOURCE" ] || error "Missing icon: $ICON_SOURCE"
    [ -f "$MODEL_CATALOG_SOURCE" ] || error "Missing model catalog: $MODEL_CATALOG_SOURCE"

    check_deps

    info "Extracting upstream macOS app bundle from $DMG_PATH"
    local extracted_app=""
    extracted_app="$(extract_dmg "$DMG_PATH")"

    info "Preparing Local LLM Console app bundle"
    prepare_bundle "$extracted_app"

    info "Creating zip artifact"
    package_zip

    verify_bundle >/dev/null

    info "Created app bundle: $APP_BUNDLE_PATH"
    info "Created zip artifact: $ZIP_PATH"
    warn "This is an unsigned macOS build. Users may need to right-click Open or clear Gatekeeper quarantine on first launch."
}

main "$@"
