#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$(mktemp -d)"
DEST_DIR=""
CODEX_VERSION="${LOCAL_LLM_CONSOLE_CODEX_VERSION:-}"
TARGETS=()

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT
trap 'error "Failed at line $LINENO (exit code $?)"' ERR

usage() {
    cat <<'EOF'
Usage:
  ./scripts/stage-codex-runtime.sh --dest <vendor-dir> [--version <codex-version>] <target>...

Targets:
  linux-x64
  linux-arm64
  darwin-x64
  darwin-arm64
EOF
}

detect_version() {
    if [[ -n "$CODEX_VERSION" ]]; then
        return 0
    fi

    CODEX_VERSION="$(
        node -p "require('/usr/local/lib/node_modules/@openai/codex/package.json').version" 2>/dev/null || true
    )"

    if [[ -z "$CODEX_VERSION" ]]; then
        CODEX_VERSION="$(npm view @openai/codex version 2>/dev/null || true)"
    fi

    [[ -n "$CODEX_VERSION" ]] || error "Unable to determine Codex version. Set LOCAL_LLM_CONSOLE_CODEX_VERSION."
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dest)
                DEST_DIR="${2:-}"
                shift 2
                ;;
            --version)
                CODEX_VERSION="${2:-}"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                TARGETS+=("$1")
                shift
                ;;
        esac
    done
}

target_triple() {
    case "$1" in
        linux-x64) printf '%s\n' 'x86_64-unknown-linux-musl' ;;
        linux-arm64) printf '%s\n' 'aarch64-unknown-linux-musl' ;;
        darwin-x64) printf '%s\n' 'x86_64-apple-darwin' ;;
        darwin-arm64) printf '%s\n' 'aarch64-apple-darwin' ;;
        *)
            error "Unsupported target: $1"
            ;;
    esac
}

package_version_suffix() {
    case "$1" in
        linux-x64) printf '%s\n' 'linux-x64' ;;
        linux-arm64) printf '%s\n' 'linux-arm64' ;;
        darwin-x64) printf '%s\n' 'darwin-x64' ;;
        darwin-arm64) printf '%s\n' 'darwin-arm64' ;;
        *)
            error "Unsupported target: $1"
            ;;
    esac
}

stage_target() {
    local target="$1"
    local suffix=""
    local triple=""
    local tarball_name=""
    local unpack_dir="$WORK_DIR/$target"

    suffix="$(package_version_suffix "$target")"
    triple="$(target_triple "$target")"

    mkdir -p "$unpack_dir"

    info "Fetching Codex runtime ${CODEX_VERSION}-${suffix}"
    tarball_name="$(cd "$WORK_DIR" && npm pack "@openai/codex@${CODEX_VERSION}-${suffix}" | tail -n 1)"
    [[ -n "$tarball_name" && -f "$WORK_DIR/$tarball_name" ]] || error "Failed to download Codex runtime tarball for $target"

    tar -xzf "$WORK_DIR/$tarball_name" -C "$unpack_dir"
    [[ -d "$unpack_dir/package/vendor/$triple" ]] || error "Vendor payload missing for $target"

    mkdir -p "$DEST_DIR"
    rm -rf "$DEST_DIR/$triple"
    cp -a "$unpack_dir/package/vendor/$triple" "$DEST_DIR/"
}

main() {
    parse_args "$@"
    [[ -n "$DEST_DIR" ]] || error "--dest is required"
    [[ "${#TARGETS[@]}" -gt 0 ]] || error "At least one target is required"

    detect_version
    mkdir -p "$DEST_DIR"

    local target=""
    for target in "${TARGETS[@]}"; do
        stage_target "$target"
    done
}

main "$@"
