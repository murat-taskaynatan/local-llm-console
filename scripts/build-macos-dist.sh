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
HOST_SERVICE_HELPER_SOURCE="$REPO_ROOT/launcher/local-ai-console-host-service"
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
    [ -f "$HOST_SERVICE_HELPER_SOURCE" ] || error "Missing host service helper source: $HOST_SERVICE_HELPER_SOURCE"

    mkdir -p "$helper_dir"
    cp "$CODEX_HELPER_SOURCE" "$helper_dir/local-ai-console-codex"
    cp "$CODEX_CLI_WRAPPER_SOURCE" "$helper_dir/codex-local-desktop-cli"
    cp "$HOST_SERVICE_HELPER_SOURCE" "$helper_dir/local-ai-console-host-service"
    chmod 755 \
        "$helper_dir/local-ai-console-codex" \
        "$helper_dir/codex-local-desktop-cli" \
        "$helper_dir/local-ai-console-host-service"
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
export CODEX_ELECTRON_USER_DATA_PATH="\${CODEX_ELECTRON_USER_DATA_PATH:-\$HOME/Library/Application Support/Local LLM Console}"
export LOCAL_LLM_CONSOLE_DISABLE_UPDATER="\${LOCAL_LLM_CONSOLE_DISABLE_UPDATER:-1}"
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


def ensure_text_contains(
    path: Path,
    needle: str,
    insertion: str,
    *,
    anchor: str = None,
) -> None:
    text = path.read_text()
    if needle in text:
        return
    if anchor is not None:
        if anchor not in text:
            return
        text = text.replace(anchor, f"{anchor}\n{insertion}\n", 1)
    else:
        text = f"{text}\n{insertion}\n"
    path.write_text(text)


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
    "n.app.setName(`Local LLM Console`),n.app.setPath(`userData`,_({appDataPath:n.app.getPath(`appData`),buildFlavor:x,env:process.env}))",
    "n.app.setName(`Local LLM Console`),n.app.setPath(`userData`,process.env.CODEX_ELECTRON_USER_DATA_PATH?.trim()?r.resolve(process.env.CODEX_ELECTRON_USER_DATA_PATH.trim()):r.join(n.app.getPath(`appData`),`Local LLM Console`))",
)
replace_optional(
    bootstrap_bundle,
    "await i.initialize();try{let{runMainAppStartup:e}=await Promise.resolve().then(()=>require(`./main-DCRKtMoS.js`));await e()}",
    "process.env.LOCAL_LLM_CONSOLE_DISABLE_UPDATER===`1`||await i.initialize();try{let{runMainAppStartup:e}=await Promise.resolve().then(()=>require(`./main-DCRKtMoS.js`));await e()}",
)

onboarding_login_bundle = root / "webview" / "assets" / "onboarding-login-content-4SqV_wbF.js"
replace_optional(
    onboarding_login_bundle,
    "let L=a?null:(0,T.jsx)(v,{color:`secondary`,className:`w-full justify-center py-2.5`,onClick:()=>{typeof window<`u`&&typeof window.__continueLocalLLMConsoleWithoutChatGPT==`function`?window.__continueLocalLLMConsoleWithoutChatGPT():window.location.assign(`/`)},children:(0,T.jsx)(p,{id:`electron.onboarding.login.localOnly`,defaultMessage:`Continue without ChatGPT`,description:`Button label to continue into Local LLM Console without ChatGPT sign-in`})});",
    "let L=(0,T.jsx)(v,{color:`secondary`,className:`w-full justify-center py-2.5`,onClick:()=>{typeof window<`u`&&typeof window.__continueLocalLLMConsoleWithoutChatGPT==`function`?window.__continueLocalLLMConsoleWithoutChatGPT():window.location.assign(`/`)},children:(0,T.jsx)(p,{id:`electron.onboarding.login.localOnly`,defaultMessage:`Continue without ChatGPT`,description:`Button label to continue into Local LLM Console without ChatGPT sign-in`})});",
)
app_routes_bundle = root / "webview" / "assets" / "index-CxBol07n.js"
replace_optional(
    app_routes_bundle,
    "if(!t.authMethod&&t.requiresAuth&&!l)return`login`;",
    "if(!t.authMethod&&t.requiresAuth&&!l){}",
)
replace_optional(
    app_routes_bundle,
    "if(!t.authMethod&&t.requiresAuth&&!l)return`app`;",
    "if(!t.authMethod&&t.requiresAuth&&!l){}",
)
replace_optional(
    app_routes_bundle,
    "if(o||l)return`app`;",
    "if(o)return`app`;",
)
replace_optional(
    app_routes_bundle,
    "if(t.isLoading)return null;",
    "if(t.isLoading)return`app`;",
)
replace_optional(
    app_routes_bundle,
    "function Cpe(){let e=(0,Q.c)(24),t=wf(),n=x(),r=$f(),",
    "function Cpe(){let e=(0,Q.c)(24),t=wf();if(t===`electron`)return (0,$.jsx)(p,{});let n=x(),r=$f(),",
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
    "se=async e=>{if(T){if(O=e,!e){Uw();return}await oe()}};",
    "se=async e=>{};",
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

runtime_webview_index = root / "webview" / "index.html"
replace_optional(
    runtime_webview_index,
    "<title>Codex</title>",
    "<title>Local LLM Console</title>",
)
replace_optional(
    runtime_webview_index,
    '    <script src="./assets/local-ai-console-bootstrap.js?v=20260424c"></script>',
    '    <script src="./assets/local-llm-console-tokens-per-second.js?v=20260425a"></script>\n    <script src="./assets/local-ai-console-bootstrap.js?v=20260424c"></script>',
)

runtime_index_bundle = next((root / "webview" / "assets").glob("index-*.js"), None)
if runtime_index_bundle is None:
    raise SystemExit("macOS dist patch failed: runtime index bundle not found")
replace_optional(
    runtime_index_bundle,
    '"read-config":n9((e,t)=>e.readConfig(t)),"read-config-for-host":i9((e,{hostId:t,...n})=>e.sendRequest(`config/read`,n)),"refresh-remote-connection":async(e,{hostId:t})=>{',
    '"read-config":n9((e,t)=>e.readConfig(t)),"read-config-for-host":i9((e,{hostId:t,...n})=>e.sendRequest(`config/read`,n)),"refresh-remote-connections":async()=>Qe(`refresh-remote-connections`,{params:{}}),"refresh-remote-control-connections":async()=>Qe(`refresh-remote-control-connections`,{params:{}}),"save-codex-managed-remote-ssh-connections":async(e,t)=>Qe(`save-codex-managed-remote-ssh-connections`,{params:t??{}}),"set-remote-connection-auto-connect":async(e,t)=>Qe(`set-remote-connection-auto-connect`,{params:t??{}}),"refresh-remote-connection":async(e,{hostId:t})=>{',
)
replace_optional(
    runtime_index_bundle,
    "p=()=>{let e=Iye(t,{getActiveConversationId:()=>u(),getIsWindowFocused:()=>r.current,getTurnMode:()=>i,getPermissionsEnabled:()=>a,getQuestionsEnabled:()=>o});return()=>{e()}},m=[u,t,a,o,i,r]",
    "p=()=>()=>{},m=[u,t,a,o,i,r]",
)
replace_optional(
    runtime_index_bundle,
    "function $T(){let e=(0,Q.c)(3),{authMethod:t,requiresAuth:n,isLoading:r}=$f();if(r){let t;return e[0]===Symbol.for(`react.memo_cache_sentinel`)?(t=(0,$.jsx)($.Fragment,{}),e[0]=t):t=e[0],t}if(t||!n){",
    "function $T(){let e=(0,Q.c)(3),{authMethod:t,requiresAuth:n,isLoading:r}=$f();if(wf()===`electron`||r||t||!n){",
)

runtime_font_settings_bundle = next((root / "webview" / "assets").glob("font-settings-*.js"), None)
if runtime_font_settings_bundle is None:
    raise SystemExit("macOS dist patch failed: runtime font-settings bundle not found")
replace_optional(
    runtime_font_settings_bundle,
    'import{f as E}from"./config-queries-jUrDLWnn.js";',
    'import{f as E,y as LocalConfigQuery}from"./config-queries-jUrDLWnn.js";',
)
font_text = runtime_font_settings_bundle.read_text()
font_anchor_prefix = "var Re=100,ze=[`models`,`list`];"
font_anchor = font_anchor_prefix + "function Be(e,t,n=Re){return[...ze,e,t??`no-auth`,n]}"
font_helpers_full = (
    font_anchor
    + "function LocalRemoteEnabled(e){return e?.local_llm_console_provider===`remote`||e?.model_provider===`local_llm_console_remote`||e?.oss_provider===`local_llm_console_remote`}"
    + "function LocalRemoteReasoningEffort(e){return Ne.includes(e)?e:Me}"
    + "function LocalRemoteBaseUrl(e){let t=typeof e?.local_llm_console_remote_provider_base_url==`string`?e.local_llm_console_remote_provider_base_url.trim():``,n=e?.model_providers?.local_llm_console_remote?.base_url;return t.length>0?t:typeof n==`string`?n.trim():``}"
    + "function LocalRemoteModelsUrl(e){let t=LocalRemoteBaseUrl(e);if(t.length===0)return null;try{let n=new URL(t);return n.pathname=n.pathname.replace(/\\/+$/u,``),n.pathname.endsWith(`/models`)||(n.pathname=n.pathname.endsWith(`/v1`)?`${n.pathname}/models`:`${n.pathname}/v1/models`),n.search=``,n.hash=``,n.toString()}catch{return null}}"
    + "function LocalRemoteSavedModel(e){let t=typeof e?.model==`string`?e.model.trim():``;return t.length>0?t:`gpt-oss:120b`}"
    + "function LocalRemoteModelNames(e){let t=[],n=e?.data??e?.models??e;if(Array.isArray(n))for(let e of n){let n=typeof e==`string`?e:typeof e?.id==`string`?e.id:typeof e?.model==`string`?e.model:typeof e?.name==`string`?e.name:``;n=n.trim(),n.length>0&&t.push(n)}return[...new Set(t)]}"
    + "async function LocalRemoteFetchCatalog(e){let t=LocalRemoteModelsUrl(e);if(t==null)return{localRemoteCatalog:!0,models:[],error:`Remote endpoint URL is missing.`};try{let n=await dh.getInstance().get(t,{accept:`application/json`}),r=LocalRemoteModelNames(n.body);return{localRemoteCatalog:!0,models:r,error:r.length===0?`Remote endpoint returned no models.`:null}}catch(t){let n=e?.local_llm_console_remote_model_ids??e?.local_llm_console_remote_models??e?.model_providers?.local_llm_console_remote?.models,r=LocalRemoteModelNames(n),i=LocalRemoteSavedModel(e),a=[`qwen3.5:9.7b`,`qwen3.5:122b`,`gpt-oss:120b`];return{localRemoteCatalog:!0,models:[...new Set([i,...r,...a])],error:null}}}"
    + "function LocalRemoteEfforts(e){let t=LocalRemoteReasoningEffort(e?.model_reasoning_effort);return{defaultReasoningEffort:t,supportedReasoningEfforts:Ne.map(e=>({reasoningEffort:e,description:`${e} effort`}))}}"
    + "function LocalRemoteCatalogRecord(e,t,n){let r=LocalRemoteEfforts(t);return{model:e,displayName:e,description:`Remote endpoint model.`,...r,isDefault:n,hidden:!1}}"
    + "function LocalRemoteUnavailableRecord(e,t,n){let r=LocalRemoteEfforts(e);return{model:LocalRemoteSavedModel(e),displayName:t,description:n,...r,isDefault:!0,hidden:!1,disabled:!0,localRemoteUnavailable:!0}}"
    + "function LocalRemoteModelList(e,t){if(!LocalRemoteEnabled(e))return null;if(t?.localRemoteCatalog===!0){if(t.error)return{modelsByType:{models:[LocalRemoteUnavailableRecord(e,`Cannot reach remote endpoint`,t.error)]},defaultModel:null};let n=Array.isArray(t.models)?t.models:[];if(n.length===0)return{modelsByType:{models:[LocalRemoteUnavailableRecord(e,`No remote model available`, `Remote endpoint returned no models.`)]},defaultModel:null};let r=LocalRemoteSavedModel(e),i=n.map(t=>LocalRemoteCatalogRecord(t,e,t===r)),a=i.find(e=>e.model===r)??i[0]??null;return{modelsByType:{models:i},defaultModel:a}}return null}"
)
font_provider_only = (
    "function LocalProviderKind(e){let t=typeof e?.local_llm_console_provider==`string`?e.local_llm_console_provider.trim():``,n=typeof e?.model_provider==`string`?e.model_provider.trim():``,r=typeof e?.oss_provider==`string`?e.oss_provider.trim():``,i=t.length>0?t:n.length>0?n:r;return i===`codex`||i===`openai`?`codex`:i===`remote`||i===`local_llm_console_remote`?`remote`:i||`ollama`}"
)
if "function LocalProviderKind" not in font_text:
    if "function LocalRemoteEnabled" in font_text and "function Qe" in font_text:
        # Already partially patched (provider-aware query key helper is present), just ensure LocalProviderKind exists.
        if font_anchor_prefix not in font_text:
            raise SystemExit("macOS dist patch failed: font-settings model list anchor not found")
        font_text = font_text.replace(font_anchor_prefix, font_anchor_prefix + font_provider_only, 1)
    elif font_anchor in font_text:
        # Legacy upstream bundle with no prior font-settings patch.
        if "function LocalRemoteEnabled" in font_text:
            font_text = font_text.replace(font_anchor, font_anchor + font_provider_only, 1)
        else:
            font_text = font_text.replace(font_anchor, font_helpers_full, 1)
    else:
        raise SystemExit("macOS dist patch failed: font-settings model list anchor not found")
# Remove accidental duplicate helper blocks if a prior build injected twice
dup_idx = font_text.find("function LocalRemoteEnabled")
if dup_idx != -1:
    second_dup_idx = font_text.find("function LocalRemoteEnabled", dup_idx + 1)
    if second_dup_idx != -1:
        next_marker = font_text.find("function Ve(e){", second_dup_idx)
        if next_marker != -1:
            font_text = font_text[:second_dup_idx] + font_text[next_marker:]

font_start = font_text.find("function Ve(e){")
font_end = font_text.find("function He(e){", font_start)
if font_start < 0 or font_end < 0:
    raise SystemExit("macOS dist patch failed: font-settings model list function not found")
if "LocalProviderKind(u)" not in font_text[font_start:font_end]:
    patched_font_model_query = (
        "function Ve(e){let t=e?.hostId??s,n=e?.limit??Re,r=g(_),i=O(t),a=i?.authMethod??null,o=i?.isLoading??!1,c=Ie(),{data:l}=LocalConfigQuery({hostId:t}),u=l?.config??l,d=LocalRemoteEnabled(u),p=d?[...ze,t,`remote-endpoint`,LocalProviderKind(u),LocalRemoteModelsUrl(u)??``,LocalRemoteSavedModel(u),u?.model_reasoning_effort??``]:[...ze,t,`${a}:${LocalProviderKind(u)}`,n],m=r.includes(t)&&!o,y=()=>d?LocalRemoteFetchCatalog(u):b(`list-models-for-host`,{hostId:t,includeHidden:!0,cursor:null,limit:n}),x=e=>{let t=LocalRemoteModelList(u,e);if(t)return t;let{data:n}=e,r={models:[]},i=null;return n.forEach(e=>{if(!e.hidden){let n=a===`copilot`?[e.supportedReasoningEfforts.find(He)??{reasoningEffort:`medium`,description:`medium effort`}]:[...e.supportedReasoningEfforts];r.models.push({...e,supportedReasoningEfforts:n}),i=e.isDefault?e:i}}),i??=r.models.find(e=>e.model===c.defaultModel)??null,{modelsByType:r,defaultModel:i}};return h({queryKey:p,enabled:m,staleTime:f.FIVE_MINUTES,queryFn:y,select:x})}"
    )
    font_text = font_text[:font_start] + patched_font_model_query + font_text[font_end:]
runtime_font_settings_bundle.write_text(font_text)

statsig_bundle = next((root / "webview" / "assets").glob("statsig-*.js"), None)
if statsig_bundle is None:
    raise SystemExit("macOS dist patch failed: Statsig bundle not found")
replace_optional(
    statsig_bundle,
    "initializeSync(e){return this.loadingStatus===`Uninitialized`?(this._logger.start(),this.updateUserSync(this._user,e))",
    "initializeSync(e){return this.loadingStatus===`Uninitialized`?this.updateUserSync(this._user,e)",
)
replace_optional(
    statsig_bundle,
    "_initializeAsyncImpl(e){return t(this,void 0,void 0,function*(){return n.Storage.isReady()||(yield n.Storage.isReadyResolver()),this._logger.start(),this.updateUserAsync(this._user,e)})}",
    "_initializeAsyncImpl(e){return t(this,void 0,void 0,function*(){return n.Storage.isReady()||(yield n.Storage.isReadyResolver()),this.updateUserAsync(this._user,e)})}",
)
replace_optional(
    statsig_bundle,
    "logEvent(e,t,n){let r=typeof e==`string`?{eventName:e,value:t,metadata:n}:e;this.$emt({name:`log_event_called`,event:r}),this._logger.enqueue(Object.assign(Object.assign({},r),{user:this._user,time:Date.now()}))}",
    "logEvent(e,t,n){}",
)
replace_optional(
    statsig_bundle,
    "_enqueueExposure(e,t,n){if(n?.disableExposureLog===!0){this._logger.incrementNonExposureCount(e);return}this._logger.enqueue(t)}",
    "_enqueueExposure(e,t,n){}",
)
replace_optional(
    statsig_bundle,
    "_checkUserHasIdForEvaluation(e,t,r){e&&((0,n._getUnitIDFromUser)(this._user,e)||n.Log.warn(`The user does not have the required id_type \"${e}\" for ${r} \"${t}\"`))}",
    "_checkUserHasIdForEvaluation(e,t,r){}",
)

runtime_local_models_bundle = next((root / "webview" / "assets").glob("local-models-settings-*.js"), None)
if runtime_local_models_bundle is None:
    raise SystemExit("macOS dist patch failed: runtime local-models settings bundle not found")
replace_optional(
    runtime_local_models_bundle,
    """import { i as q, n as H, t as R } from "./check-md-YtZX6wSV.js";
import { u as u, y as d } from "./config-queries-jUrDLWnn.js";""",
    """import { i as q, n as H, t as R } from "./check-md-YtZX6wSV.js";
import { n as readLocalLlmConsoleFileRequest } from "./vscode-api-D-CkvzxH.js";
import { u as u, y as d } from "./config-queries-jUrDLWnn.js";""",
)
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
ensure_text_contains(
    runtime_local_models_bundle,
    "function invalidateModelCatalogQueries",
    "function invalidateModelCatalogQueries(e) {\n  let t = e ?? getCurrentSessionHostId();\n  hostBus.dispatchMessage(`query-cache-invalidate`, {\n    queryKey: [`config`, `user`],\n  });\n  hostBus.dispatchMessage(`query-cache-invalidate`, {\n    queryKey: [`config`, `user`, t],\n  });\n  hostBus.dispatchMessage(`query-cache-invalidate`, {\n    queryKey: [`models`, `list`],\n  });\n  hostBus.dispatchMessage(`query-cache-invalidate`, {\n    queryKey: [`models`, `list`, t],\n  });\n}\n",
)
ensure_text_contains(
    runtime_local_models_bundle,
    "invalidateModelCatalogQueries(getCurrentSessionHostId());",
    "        invalidateModelCatalogQueries(getCurrentSessionHostId());\n",
    anchor="        E((t) => ({ ...W, launchMode: `local` }));",
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
  if (
    typeof window !== `undefined` &&
    (window.location.protocol === `file:` || window.location.protocol === `app:`)
  )
    return { ok: !0, skipped: !0, action: e };
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
replace_optional(
    runtime_local_models_bundle,
    """async function restartLocalLlmConsoleAppServer(e = {}) {
  let t = isRemoteSessionHostId(v(e.hostId, ``)) ? v(e.hostId, ``) : `local`,
    n = Date.now() + (typeof e.timeoutMs == `number` && e.timeoutMs > 0 ? e.timeoutMs : 15000),
    r = null;
  hostBus.dispatchMessage(`codex-app-server-restart`, { hostId: t });
  await new Promise((e) => window.setTimeout(e, 400));
  for (; Date.now() < n; ) {
    try {
      let n = await sendLocalLlmConsoleRequest(`read-config`, {
          hostId: t,
          includeLayers: !1,
          cwd: null,
        }),
        r = C(n?.config ?? {});
      if (
        (e.provider == null || r.provider === z(e.provider)) &&
        (e.model == null || r.model === K(e.provider ?? r.provider, e.model)) &&
        (e.reasoning == null || r.reasoning === e.reasoning)
      )
        return r;
    } catch (e) {
      r = e;
    }
    await new Promise((e) => window.setTimeout(e, 500));
  }
  throw new Error(
    r instanceof Error && r.message.trim().length > 0
      ? `Timed out restarting the local session: ${r.message}`
      : `Timed out restarting the local session.`,
  );
}""",
    """async function restartLocalLlmConsoleAppServer(e = {}) {
  let t = isRemoteSessionHostId(v(e.hostId, ``)) ? v(e.hostId, ``) : `local`,
    n = Date.now() + (typeof e.timeoutMs == `number` && e.timeoutMs > 0 ? e.timeoutMs : 15000),
    r = null;
  hostBus.dispatchMessage(`codex-app-server-restart`, { hostId: t });
  await new Promise((e) => window.setTimeout(e, 400));
  for (; Date.now() < n; ) {
    try {
      let n = await sendLocalLlmConsoleRequest(`read-config`, {
          hostId: t,
          includeLayers: !1,
          cwd: null,
        }),
        r = C(n?.config ?? {});
      if (
        (e.provider == null || r.provider === z(e.provider)) &&
        (e.model == null || r.model === K(e.provider ?? r.provider, e.model)) &&
        (e.reasoning == null || r.reasoning === e.reasoning)
      )
        return r;
    } catch (e) {
      r = e;
    }
    await new Promise((e) => window.setTimeout(e, 500));
  }
  throw new Error(
    r instanceof Error && r.message.trim().length > 0
      ? `Timed out restarting the local session: ${r.message}`
      : `Timed out restarting the local session.`,
  );
}
""",
)
replace_optional(
    runtime_local_models_bundle,
    """function Q(e) {
  return z(e) === `codex` ? `gpt-5.4` : z(e) === `remote` ? `` : `gpt-oss:120b`;
}""",
    """function Q(e) {
  return z(e) === `codex` ? `gpt-5.4` : `gpt-oss:120b`;
}""",
)
replace_optional(
    runtime_local_models_bundle,
    """function stripWebsocketUrlScheme(e, t = ``) {
  let n = v(e, t);
  return n.replace(/^wss?:\/\//i, ``);
}

function C(e) {""",
    """function stripWebsocketUrlScheme(e, t = ``) {
  let n = v(e, t);
  return n.replace(/^wss?:\/\//i, ``);
}

function C(e) {""",
)
replace_optional(
    runtime_local_models_bundle,
    """    providerBaseUrl: v(
      e?.local_llm_console_remote_provider_base_url,
      e?.model_providers?.[remoteProviderId]?.base_url,
      ``,
    ),""",
    """    providerBaseUrl: v(
      e?.local_llm_console_remote_provider_base_url,
      e?.model_providers?.[remoteProviderId]?.base_url,
      ``,
    ),""",
)
replace_optional(
    runtime_local_models_bundle,
    """    i = u(),
    [rawRemoteProviderBaseUrl, setRawRemoteProviderBaseUrl] = (0, p.useState)(null),
    rawConfig = (0, p.useMemo)(() => {
      if (rawRemoteProviderBaseUrl == null || rawRemoteProviderBaseUrl.length === 0)
        return e?.config;
      return {
        ...(e?.config ?? {}),
        local_llm_console_remote_provider_base_url: rawRemoteProviderBaseUrl,
      };
    }, [e?.config, rawRemoteProviderBaseUrl]),
    t = (0, p.useMemo)(() => C(rawConfig), [
      rawConfig?.local_llm_console_mode,
      rawConfig?.model_provider,
      rawConfig?.oss_provider,
      rawConfig?.model,
      rawConfig?.model_reasoning_effort,
      rawConfig?.model_catalog_json,
      rawConfig?.local_llm_console_remote_provider_base_url,
      rawConfig?.model_providers?.[remoteProviderId]?.base_url,
      rawConfig?.local_llm_console_remote_transport,
      rawConfig?.local_llm_console_remote_url,
      rawConfig?.local_llm_console_remote_auth_token_env,
      rawConfig?.local_llm_console_host_enabled,
      rawConfig?.local_llm_console_host_transport,
      rawConfig?.local_llm_console_host_listen_url,
      rawConfig?.local_llm_console_host_https_port,
    ]),""",
    """    i = u(),
    [rawRemoteProviderBaseUrl, setRawRemoteProviderBaseUrl] = (0, p.useState)(null),
    rawConfig = (0, p.useMemo)(() => {
      if (rawRemoteProviderBaseUrl == null || rawRemoteProviderBaseUrl.length === 0)
        return e?.config;
      return {
        ...(e?.config ?? {}),
        local_llm_console_remote_provider_base_url: rawRemoteProviderBaseUrl,
      };
    }, [e?.config, rawRemoteProviderBaseUrl]),
    t = (0, p.useMemo)(() => C(rawConfig), [
      rawConfig?.local_llm_console_mode,
      rawConfig?.model_provider,
      rawConfig?.oss_provider,
      rawConfig?.model,
      rawConfig?.model_reasoning_effort,
      rawConfig?.model_catalog_json,
      rawConfig?.local_llm_console_remote_provider_base_url,
      rawConfig?.model_providers?.[remoteProviderId]?.base_url,
      rawConfig?.local_llm_console_remote_transport,
      rawConfig?.local_llm_console_remote_url,
      rawConfig?.local_llm_console_remote_auth_token_env,
      rawConfig?.local_llm_console_host_enabled,
      rawConfig?.local_llm_console_host_transport,
      rawConfig?.local_llm_console_host_listen_url,
      rawConfig?.local_llm_console_host_https_port,
    ]),""",
)
replace_optional(
    runtime_local_models_bundle,
    """  (0, p.useEffect)(() => {
    r().catch(() => {});
  }, []);

  (0, p.useEffect)(() => {
    let e = !1,""",
    """  (0, p.useEffect)(() => {
    r().catch(() => {});
  }, []);

  (0, p.useEffect)(() => {
    let e = !1;
    if (se.length === 0) {
      setRawRemoteProviderBaseUrl(null);
      return;
    }
    readLocalLlmConsoleFileRequest(`read-file`, { params: { path: se } })
      .then((t) => {
        if (e) return;
        let n = typeof t?.contents == `string` ? t.contents : ``,
          r = null;
        if (n.length > 0) {
          let t = new RegExp(
              `^\\s*local_llm_console_remote_provider_base_url\\s*=\\s*"((?:\\\\.|[^"\\\\])*)"`,
              `m`,
            ).exec(n),
            i = t?.[1];
          if (i != null)
            try {
              r = JSON.parse(`"${i}"`).trim();
            } catch {
              r = i.trim();
            }
          r != null && r.length === 0 && (r = null);
        }
        setRawRemoteProviderBaseUrl((e) => (e && e.length > 0 ? e : r));
      })
      .catch(() => {
        if (!e) {
          if (se.length > 0) {
            let t = readCachedRemoteProviderBaseUrl(se);
            setRawRemoteProviderBaseUrl((e) => (e && e.length > 0 ? e : t));
            return;
          }
          setRawRemoteProviderBaseUrl(null);
        }
      });
    return () => {
      e = !0;
    };
  }, [se, ce]);

  (0, p.useEffect)(() => {
    let e = !1,""",
)
replace_optional(
    runtime_local_models_bundle,
    """                              provider: n,
                              model: K(n, t.model),
                            };""",
    """                              provider: n,
                              model:
                                n === `codex`
                                  ? (Array.isArray(B(n)) ? B(n).includes(t.model) : !1)
                                    ? t.model
                                    : Q(n)
                                  : z(n) === `remote` &&
                                      (
                                        v(t.model, ``).length === 0 ||
                                        (Array.isArray(B(`codex`))
                                          ? B(`codex`).includes(v(t.model, ``))
                                          : !1)
                                      )
                                    ? Q(n)
                                    : K(n, t.model),
                              providerBaseUrl:
                                z(t.provider) === `remote` || n === `remote`
                                  ? v(
                                      t.providerBaseUrl,
                                      rawRemoteProviderBaseUrlRef.current,
                                      rawRemoteProviderBaseUrl,
                                      ye.providerBaseUrl,
                                      ``,
                                    )
                                  : t.providerBaseUrl,
                            };""",
)
replace_optional(
    runtime_local_models_bundle,
    """                  (0, m.jsx)(c, {
                    label: `Default model`,
                    description:
                      z(w.provider) === `remote`
                        ? `The model ID exposed by the remote OpenAI-compatible endpoint.`
                        : `The model ID used for the selected provider.`,
                    control: (0, m.jsx)(`div`, {
                      className: `w-[28rem] max-w-full`,
                      children:
                        z(w.provider) === `remote`
                          ? (0, m.jsx)(k, {
                              value: w.model,
                              onChange: (e) => {
                                let t = e.target.value;
                                E((e) => ({ ...e, model: t }));
                              },
                              placeholder: `gpt-oss:120b`,
                            })
                          : (0, m.jsx)(F, {
                              key: z(w.provider),
                              ariaLabel: `Default model`,
                              options: le,
                              value: w.model,
                              onChange: (e) => {
                                E((t) => ({ ...t, model: e }));
                              },
                            }),
                    }),
                  }),""",
    """                  z(w.provider) === `remote`
                    ? null
                    : (0, m.jsx)(c, {
                        label: `Default model`,
                        description: `The model ID used for the selected provider.`,
                        control: (0, m.jsx)(`div`, {
                          className: `w-[28rem] max-w-full`,
                          children: (0, m.jsx)(F, {
                            ariaLabel: `Default model`,
                            options: le,
                            value: w.model,
                            onChange: (e) => {
                              E((t) => ({ ...t, model: e }));
                            },
                          }),
                        }),
                      }),""",
)
replace_optional(
    runtime_local_models_bundle,
    """        V = W.hostHttpsPort.trim(),
        I = Number.parseInt(V, 10);
      if (""",
    """        V = W.hostHttpsPort.trim(),
        I = Number.parseInt(V, 10);
      !isRemoteScope &&
        normalizedProvider === `codex` &&
        (o.length === 0 || o.includes(`:`)) &&
        (o = Q(normalizedProvider));
      !isRemoteScope &&
        normalizedProvider === `remote` &&
        (o.length === 0 || (Array.isArray(B(`codex`)) ? B(`codex`).includes(o) : !1)) &&
        (o = Q(normalizedProvider));
      if (""",
)
replace_optional(
    runtime_local_models_bundle,
    "      w.model.trim().length === 0 ||",
    "      (z(w.provider) !== `remote` && w.model.trim().length === 0) ||",
)
replace_optional(
    runtime_local_models_bundle,
    "          o.length === 0 ||",
    "          (normalizedProvider !== `remote` && o.length === 0) ||",
)
replace_optional(
    runtime_local_models_bundle,
    "`Provider, model, reasoning effort, and remote endpoint URL are all required for remote endpoint settings.`",
    "`Provider, reasoning effort, and remote endpoint URL are all required for remote endpoint settings.`",
)
replace_optional(
    runtime_local_models_bundle,
    "`Provider, model, reasoning effort, and remote endpoint URL are all required before saving remote endpoint settings.`",
    "`Provider, reasoning effort, and remote endpoint URL are all required before saving remote endpoint settings.`",
)
replace_optional(
    runtime_local_models_bundle,
    "        providerBaseUrl = v(W.providerBaseUrl, ``),\n        l = `tailscale`,",
    "        providerBaseUrl = v(W.providerBaseUrl, ``),\n        providerApiBaseUrl = providerBaseUrl,\n        l = `tailscale`,",
)
replace_optional(
    runtime_local_models_bundle,
    """        let edits = [
          { keyPath: `local_llm_console_provider`, value: a },
          { keyPath: `model_provider`, value: providerValue },
          { keyPath: `oss_provider`, value: providerValue },
          { keyPath: `model`, value: o },
          { keyPath: `model_reasoning_effort`, value: s },
          {
            keyPath: `local_llm_console_remote_provider_base_url`,
            value: providerBaseUrl,
          },
          {
            keyPath: `model_providers.${remoteProviderId}.base_url`,
            value: providerApiBaseUrl,
          },
          {
            keyPath: `model_providers.${remoteProviderId}.wire_api`,
            value: `responses`,
          },
          { keyPath: `local_llm_console_mode`, value: `local` },
          {
            keyPath: `local_llm_console_remote_transport`,
            value: l,
          },
          { keyPath: `local_llm_console_remote_url`, value: q },
          {
            keyPath: `local_llm_console_remote_auth_token_env`,
            value: H,
          },
          {
            keyPath: `local_llm_console_host_enabled`,
            value: R,
          },
          {
            keyPath: `local_llm_console_host_transport`,
            value: G,
          },
          {
            keyPath: `local_llm_console_host_listen_url`,
            value: Y,
          },
          {
            keyPath: `local_llm_console_host_https_port`,
            value: I,
          },
        ];
        includeCatalogPathEdit &&
          edits.splice(5, 0, { keyPath: `model_catalog_json`, value: c });
        edits.push(
          {
            keyPath: `model_providers.${remoteProviderId}.name`,
            value: `Remote endpoint`,
          },
          {
            keyPath: `model_providers.${remoteProviderId}.base_url`,
            value: providerBaseUrl,
          },
          {
            keyPath: `model_providers.${remoteProviderId}.wire_api`,
            value: `responses`,
          },
        );""",
    """        let edits = [
          { keyPath: `local_llm_console_mode`, value: isRemoteScope ? b(e) : `local` },
          {
            keyPath: `local_llm_console_remote_transport`,
            value: l,
          },
          { keyPath: `local_llm_console_remote_url`, value: q },
          {
            keyPath: `local_llm_console_remote_auth_token_env`,
            value: H,
          },
          {
            keyPath: `local_llm_console_host_enabled`,
            value: R,
          },
          {
            keyPath: `local_llm_console_host_transport`,
            value: G,
          },
          {
            keyPath: `local_llm_console_host_listen_url`,
            value: Y,
          },
          {
            keyPath: `local_llm_console_host_https_port`,
            value: I,
          },
        ];
        if (!isRemoteScope) {
          edits.unshift(
            { keyPath: `local_llm_console_provider`, value: normalizedProvider },
            { keyPath: `model_provider`, value: providerValue },
            { keyPath: `oss_provider`, value: providerValue },
            { keyPath: `model`, value: o },
            { keyPath: `model_reasoning_effort`, value: s },
          );
          includeCatalogPathEdit &&
            edits.splice(5, 0, { keyPath: `model_catalog_json`, value: c });
          if (normalizedProvider === `remote`) {
            edits.push(
              {
                keyPath: `local_llm_console_remote_provider_base_url`,
                value: providerBaseUrl,
              },
              {
                keyPath: `model_providers.${remoteProviderId}.base_url`,
                value: providerApiBaseUrl,
              },
              {
                keyPath: `model_providers.${remoteProviderId}.wire_api`,
                value: `responses`,
              },
              {
                keyPath: `model_providers.${remoteProviderId}.name`,
                value: `Remote endpoint`,
              },
            );
          }
        }""",
)
replace_optional(
    runtime_local_models_bundle,
    """        } catch (e) {
          if (!isLocalLlmConsoleConfigVersionConflict(e)) throw e;
          let t = await r(),
            n = t?.data?.configWriteTarget ?? null,
            a = n?.filePath ?? se ?? null,
            o = n?.expectedVersion ?? null;
          await i.mutateAsync({
            filePath: a,
            expectedVersion: o,
            edits,
          });
        }
        E((t) => ({ ...W, launchMode: `local` }));
        ie({
          currentMode: isRemoteScope ? _e : b(e),
          hasRemoteSettings: q.length > 0,
          remoteUrl: q,
        });
        if (!isRemoteScope) {
          U({
            tone: `success`,
            text: `Saved runtime configuration. Restarting session...`,
          });
          await restartLocalLlmConsoleAppServer({
            hostId: getCurrentSessionHostId(),
            provider: a,
            model: o,
            reasoning: s,
          });
          let e = await r(),
            t = e?.data?.config ?? {},
            n = C(t),
            i = e?.data?.configWriteTarget?.filePath ?? se;
          E({ ...n, catalogPath: deriveLocalCatalogPath(i, n.catalogPath) });
          U({
            tone: `success`,
            text: `Saved runtime configuration.`,
          });
        }""",
    """        } catch (e) {
          if (!isLocalLlmConsoleConfigVersionConflict(e)) throw e;
          let t = await r(),
            n = t?.data?.configWriteTarget ?? null,
            a = n?.filePath ?? se ?? null,
            o = n?.expectedVersion ?? null;
          await i.mutateAsync({
            filePath: a,
            expectedVersion: o,
            edits,
          });
        }
        invalidateModelCatalogQueries(getCurrentSessionHostId());
        E((t) => ({ ...W, launchMode: `local` }));
        ie({
          currentMode: isRemoteScope ? _e : b(e),
          hasRemoteSettings: q.length > 0,
          remoteUrl: q,
        });
        if (!isRemoteScope) {
          U({
            tone: `success`,
            text: `Saved runtime configuration. Restarting session...`,
          });
          await restartLocalLlmConsoleAppServer({
            hostId: getCurrentSessionHostId(),
            provider: a,
            model: o,
            reasoning: s,
          });
          let e = await r(),
            t = e?.data?.config ?? {},
            n = C(t),
            i = e?.data?.configWriteTarget?.filePath ?? se;
          E({ ...n, catalogPath: deriveLocalCatalogPath(i, n.catalogPath) });
          U({
            tone: `success`,
            text: `Saved runtime configuration.`,
          });
        }""",
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

prepare_local_launch() {
    local app_bundle_path="$1"

    xattr -cr "$app_bundle_path" 2>/dev/null || true
    if command -v codesign >/dev/null 2>&1; then
        codesign --force --deep --sign - "$app_bundle_path" >/dev/null 2>&1 || \
            warn "Unable to ad-hoc sign app bundle; macOS may require right-click Open."
    fi
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
    prepare_local_launch "$APP_BUNDLE_PATH"

    info "Creating zip artifact"
    package_zip

    verify_bundle >/dev/null

    info "Created app bundle: $APP_BUNDLE_PATH"
    info "Created zip artifact: $ZIP_PATH"
    warn "This is an unsigned macOS build. Users may need to right-click Open or clear Gatekeeper quarantine on first launch."
}

main "$@"
