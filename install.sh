#!/usr/bin/env bash
# install.sh — One-line installer for chrome-cdp-skill
# Usage: ./install.sh [options]
#        curl -fsSL https://raw.githubusercontent.com/Jiangwlee/chrome-cdp-skill/main/install.sh | bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO_URL="https://github.com/Jiangwlee/chrome-cdp-skill.git"
RELEASE_API="https://api.github.com/repos/Jiangwlee/chrome-cdp-skill/releases/latest"
DEFAULT_INSTALL_PREFIX="$HOME"
MIN_NODE_VERSION=22
TEMP_DIR=""
SRC_DIR=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
info()  { printf "${GREEN}✓${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}!${NC} %s\n" "$*"; }
error() { printf "${RED}✗${NC} %s\n" "$*" >&2; }
step()  { printf "\n${BLUE}▶${NC} %s\n" "$*"; }

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
cleanup() {
  if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Version comparison
# ---------------------------------------------------------------------------
version_ge() {
  # Returns 0 if $1 >= $2
  [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" == "$2" ]]
}

# ---------------------------------------------------------------------------
# Environment checks
# ---------------------------------------------------------------------------
check_nodejs() {
  if ! command -v node &>/dev/null; then
    error "Node.js not found. Please install Node.js >= $MIN_NODE_VERSION"
    return 1
  fi
  
  local version
  version=$(node --version | sed 's/^v//')
  if ! version_ge "$version" "$MIN_NODE_VERSION"; then
    error "Node.js $version found, but >= $MIN_NODE_VERSION required"
    return 1
  fi
  info "Node.js $version"
}

check_pi_cli() {
  if ! command -v pi &>/dev/null; then
    error "pi CLI not found. Please install: https://github.com/mariozechner/pi"
    cat <<'EOF'

Quick install pi:
  curl -fsSL https://pi.tools/install.sh | bash

Or manually:
  npm install -g @mariozechner/pi

EOF
    return 1
  fi
  
  local version
  version=$(pi --version 2>/dev/null | head -n1 || echo "unknown")
  info "pi CLI $version"
}

check_jq() {
  if ! command -v jq &>/dev/null; then
    warn "jq not found. Some features may be limited."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      echo "  Install: brew install jq"
    elif [[ -f /etc/debian_version ]]; then
      echo "  Install: sudo apt-get install jq"
    elif [[ -f /etc/redhat-release ]]; then
      echo "  Install: sudo yum install jq"
    fi
    return 0  # jq is not strictly required for basic operation
  fi
  info "jq available"
}

detect_chrome_port() {
  local port="${CHROME_DEBUG_PORT:-}"
  
  # If user specified port, use it
  if [[ -n "$port" ]]; then
    if curl -s "http://localhost:$port/json/version" &>/dev/null; then
      info "Chrome remote debugging on port $port"
      return 0
    else
      warn "Chrome not responding on specified port $port"
      return 1
    fi
  fi
  
  # Auto-detect common ports
  for port in 9222 9223 9224; do
    if curl -s "http://localhost:$port/json/version" &>/dev/null; then
      info "Chrome remote debugging detected on port $port"
      export CHROME_DEBUG_PORT="$port"
      return 0
    fi
  done
  
  warn "Chrome remote debugging not detected"
  echo ""
  echo "To enable remote debugging, start Chrome with:"
  echo "  Google Chrome:    --remote-debugging-port=9222"
  echo "  Chromium:         --remote-debugging-port=9222"
  echo "  Brave:            --remote-debugging-port=9222"
  echo "  Microsoft Edge:   --remote-debugging-port=9222"
  echo ""
  echo "Or set CHROME_DEBUG_PORT environment variable."
  return 1
}

# ---------------------------------------------------------------------------
# Download source
# ---------------------------------------------------------------------------
download_stable() {
  step "Downloading latest stable release..."
  
  if ! command -v curl &>/dev/null; then
    error "curl is required but not installed"
    return 1
  fi
  
  local tarball_url
  if command -v jq &>/dev/null; then
    tarball_url=$(curl -fsSL "$RELEASE_API" | jq -r '.tarball_url')
  else
    # Fallback without jq
    tarball_url=$(curl -fsSL "$RELEASE_API" | grep -o '"tarball_url": "[^"]*"' | cut -d'"' -f4)
  fi
  
  if [[ -z "$tarball_url" || "$tarball_url" == "null" ]]; then
    error "Failed to get release tarball URL"
    return 1
  fi
  
  local tar_file="$TEMP_DIR/release.tar.gz"
  curl -fsSL -o "$tar_file" "$tarball_url"
  
  mkdir -p "$TEMP_DIR/src"
  tar -xzf "$tar_file" -C "$TEMP_DIR/src" --strip-components=1
  SRC_DIR="$TEMP_DIR/src"
  info "Downloaded stable release"
}

clone_repo() {
  step "Cloning repository..."
  
  if ! command -v git &>/dev/null; then
    error "git is required. Install git or use --stable flag"
    return 1
  fi
  
  SRC_DIR="$TEMP_DIR/chrome-cdp-skill"
  git clone --depth 1 "$REPO_URL" "$SRC_DIR"
  info "Cloned $REPO_URL"
}

# ---------------------------------------------------------------------------
# Installation
# ---------------------------------------------------------------------------
run_install() {
  local copy_mode="${1:-false}"
  local force_mode="${2:-false}"
  local prefix="${3:-$DEFAULT_INSTALL_PREFIX}"
  
  step "Installing chrome-cdp-skill..."
  
  if [[ "$copy_mode" == true ]]; then
    warn "Copy mode: files will be copied (not symlinked). Updates require re-running install."
    # TODO: Implement copy mode in pi-cdp or handle here
    # For now, fall through to pi-cdp which uses symlinks
  fi
  
  # Run pi-cdp install
  local install_args=""
  [[ "$force_mode" == true ]] && install_args="--force"
  
  # pi-cdp uses hardcoded paths based on REPO_ROOT, so we need to run from SRC_DIR
  (cd "$SRC_DIR" && ./bin/pi-cdp install $install_args)
  
  info "Installation complete"
}

run_uninstall() {
  step "Uninstalling chrome-cdp-skill..."
  
  # If we have a local pi-cdp, use it; otherwise assume standard paths
  if [[ -n "${SRC_DIR:-}" && -f "$SRC_DIR/bin/pi-cdp" ]]; then
    (cd "$SRC_DIR" && ./bin/pi-cdp remove)
  elif command -v pi-cdp &>/dev/null; then
    pi-cdp remove
  else
    # Manual cleanup
    warn "pi-cdp not found, performing manual cleanup..."
    rm -rf "$HOME/.agents/skills/chrome-cdp"
    
    for agent in link-reader web-researcher stock-analyst wps-assistant taoguba-researcher; do
      rm -f "$HOME/.pi/agent/agents/$agent.md"
    done
    
    for wrapper in pi-read-link pi-research pi-stock-report pi-wps pi-taoguba-research pi-watch; do
      rm -f "$HOME/.local/bin/$wrapper"
    done
  fi
  
  info "Uninstall complete"
}

# ---------------------------------------------------------------------------
# Post-install
# ---------------------------------------------------------------------------
post_install() {
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  
  # Check if ~/.local/bin is in PATH
  if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    warn "~/.local/bin is not in your PATH"
    echo ""
    echo "Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
    echo ""
    echo '  export PATH="$HOME/.local/bin:$PATH"'
    echo ""
  fi
  
  echo "Quick start:"
  echo ""
  echo "  pi-stock-report                    # 淘股吧市场简报"
  echo "  pi-taoguba-research '情绪周期'      # 淘股吧深度研究"
  echo "  pi-research 'AI agents'            # X/Reddit 多轮研究"
  echo ""
  echo "Prerequisites:"
  echo "  • Chrome/Chromium with --remote-debugging-port=9222"
  echo "  • For Taoguba: login at https://www.tgb.cn"
  echo ""
  echo "═══════════════════════════════════════════════════════════"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --stable          Download latest release instead of git clone
  --copy            Copy files instead of symlinking (not yet implemented)
  --force           Overwrite existing installation
  --uninstall       Remove chrome-cdp-skill
  --check           Only check environment, don't install
  --prefix=<path>   Custom installation prefix (default: ~)
  --help            Show this help

Environment variables:
  CHROME_DEBUG_PORT    Chrome remote debugging port (default: auto-detect)
  SKIP_CHROME_CHECK    Set to 1 to skip Chrome detection

Examples:
  ./install.sh                          # Default git clone install
  ./install.sh --stable                 # Install latest release
  ./install.sh --force                  # Reinstall/overwrite
  ./install.sh --check                  # Verify prerequisites
  ./install.sh --uninstall              # Remove
EOF
}

main() {
  local stable_mode=false
  local copy_mode=false
  local force_mode=false
  local uninstall_mode=false
  local check_only=false
  local prefix="$DEFAULT_INSTALL_PREFIX"
  
  # Parse arguments
  for arg in "$@"; do
    case "$arg" in
      --stable) stable_mode=true ;;
      --copy) copy_mode=true ;;
      --force) force_mode=true ;;
      --uninstall) uninstall_mode=true ;;
      --check) check_only=true ;;
      --prefix=*) prefix="${arg#*=}" ;;
      --help|-h) usage; exit 0 ;;
      *) error "Unknown option: $arg"; usage; exit 1 ;;
    esac
  done
  
  # Handle uninstall
  if [[ "$uninstall_mode" == true ]]; then
    run_uninstall
    exit 0
  fi
  
  # Environment checks
  step "Checking environment..."
  check_nodejs || exit 1
  check_pi_cli || exit 1
  check_jq
  
  if [[ "${SKIP_CHROME_CHECK:-}" != "1" ]]; then
    detect_chrome_port || true  # Non-fatal
  fi
  
  if [[ "$check_only" == true ]]; then
    echo ""
    info "Environment check complete"
    exit 0
  fi
  
  # Prepare temp directory
  TEMP_DIR=$(mktemp -d)
  
  # Download/clone source
  if [[ "$stable_mode" == true ]]; then
    download_stable || exit 1
  else
    clone_repo || exit 1
  fi
  
  # Run installation
  run_install "$copy_mode" "$force_mode" "$prefix"
  
  # Post-install info
  post_install
}

main "$@"
