#    _______/\\\\\_______/\\\\\\\\\\\\_____/\\\\\\\\\\\\\___
#     _____/\\\///\\\____\/\\\////////\\\__\/\\\/////////\\\_
#      ___/\\\/__\///\\\__\/\\\______\//\\\_\/\\\_______\/\\\_
#       __/\\\______\//\\\_\/\\\_______\/\\\_\/\\\\\\\\\\\\\/__
#        _\/\\\_______\/\\\_\/\\\_______\/\\\_\/\\\/////////____
#         _\//\\\______/\\\__\/\\\_______\/\\\_\/\\\_____________
#          __\///\\\__/\\\____\/\\\_______/\\\__\/\\\_____________
#           ____\///\\\\\/_____\/\\\\\\\\\\\\/___\/\\\_____________
#            ______\/////_______\////////////_____\///______________ v0.1

#!/bin/bash

set -euo pipefail

# ─── curl | bash compatibility ────────────────────────────────────────────────
if [[ ! -t 0 ]]; then
  if [[ -e /dev/tty ]]; then
    exec </dev/tty
  else
    echo "[ERROR] /dev/tty unavailable. Run directly: bash <(curl -fsSL <url>)" >&2
    exit 1
  fi
fi

# ─── Colors & Formatting ──────────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';  YELLOW='\033[1;33m'
BLUE='\033[0;34m';   CYAN='\033[0;36m';  BOLD='\033[1m'; RESET='\033[0m'

# ─── Utility Helpers ──────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# Print a styled section header
header() {
  local title="$1"
  local width=50
  echo -e "\n${BOLD}${BLUE}$(printf '─%.0s' $(seq 1 $width))${RESET}"
  echo -e "${BOLD}${BLUE}  $title${RESET}"
  echo -e "${BOLD}${BLUE}$(printf '─%.0s' $(seq 1 $width))${RESET}\n"
}

# ─── Prompt Helpers ───────────────────────────────────────────────────────────

# Ask for a non-empty text value; re-prompts until satisfied
# Usage: prompt_text "Label" [default_value]
prompt_text() {
  local label="$1"
  local default="${2:-}"
  local value=""
  while [[ -z "$value" ]]; do
    if [[ -n "$default" ]]; then
      read -rp "$(echo -e "${BOLD}${label}${RESET} [${default}]: ")" value
      value="${value:-$default}"
    else
      read -rp "$(echo -e "${BOLD}${label}${RESET}: ")" value
    fi
    [[ -z "$value" ]] && warn "Value cannot be empty. Please try again."
  done
  echo "$value"
}

# Ask a yes/no question; returns 0 for yes, 1 for no
# Usage: confirm "Are you sure?" && do_something
confirm() {
  local question="$1"
  while true; do
    read -rp "$(echo -e "${YELLOW}${question}${RESET} [y/N]: ")" yn
    case "${yn,,}" in
      y|yes) return 0 ;;
      n|no|"") return 1 ;;
      *) warn "Please answer y or n." ;;
    esac
  done
}

# Ask the user to pick from a numbered list
# Usage: pick_from_list "Prompt" "opt1" "opt2" "opt3"
#        result="${PICK_RESULT}"
PICK_RESULT=""
pick_from_list() {
  local prompt="$1"; shift
  local options=("$@")
  local choice
  PS3="$(echo -e "${BOLD}${prompt}${RESET} [1-${#options[@]}]: ")"
  select choice in "${options[@]}"; do
    if [[ -n "$choice" ]]; then
      PICK_RESULT="$choice"
      return 0
    else
      warn "Invalid selection. Please choose a number between 1 and ${#options[@]}."
    fi
  done
}

# ─── Cleanup & Signals ────────────────────────────────────────────────────────
cleanup() {
  echo -e "\n${YELLOW}Interrupted. Cleaning up...${RESET}"
  rm -rf /tmp/config_blob 2>/dev/null || true
  exit 1
}

cleanup_debug() {
  # echo -e "\n${YELLOW}Interrupted. Cleaning up...${RESET}"
  echo "rm -rf /tmp/config_blob 2>/dev/null || true"
  exit 1
}

trap cleanup INT TERM

# ─── Helper Functions ─────────────────────────────────────────────────────────
check_local_dependencies() {
  local deps=(curl)
  for cmd in "${deps[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
      error "Required command '$cmd' not found. Please install it and try again."
      exit 1
    fi
  done
}


# ─── Action Placeholders ──────────────────────────────────────────────────────

config_install() {
  info "Installing configuration..."
  info "Checking local dependencies..."
    check_local_dependencies

  info "About to fetch from: $1 in 3 seconds. Press Ctrl+C to cancel."
  sleep 3

  info "Fetching from URL: $1"
  curl -fsSL "$1" -o /tmp/config_blob

}

config_make() {
  info "Generating configuration..."
}

# ─── Usage / Help ─────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
$(echo -e "${BOLD}Usage:${RESET}")
  $(basename "$0") [COMMAND] [OPTIONS]

$(echo -e "${BOLD}Commands:${RESET}")
  --install  <url>     Download and install from the given URL
  --make               Generate a new configuration interactively
  --help, -h           Show this help message

$(echo -e "${BOLD}No arguments:${RESET}")
  Launches the interactive menu.

$(echo -e "${BOLD}Examples:${RESET}")
  $(basename "$0") --install https://example.com/config_blob
  $(basename "$0") --make
  bash <(curl -fsSL https://example.com/$(basename "$0"))
EOF
}

# ─── Argument-driven actions ──────────────────────────────────────────────────

# These are the non-interactive counterparts to the menu actions.
# Add your real logic here; the menu functions call these too.

cmd_install() {
  local url="$1"
  [[ -z "$url" ]] && { error "--install requires a URL."; usage; exit 1; }
  config_install $url
}

cmd_configure_kv() {
  local kv="$1"
  [[ "$kv" != *=* ]] && { error "--configure expects key=value (e.g. timeout=30)"; exit 1; }
  local key="${kv%%=*}"
  local value="${kv#*=}"
  info "Setting $key → $value"
  # TODO: write to config file
  success "Config updated: $key=$value"
}

# ─── Argument Parser ──────────────────────────────────────────────────────────
parse_args() {
  # No arguments → drop into the interactive menu
  [[ $# -eq 0 ]] && { main_menu; return; }

  while [[ $# -gt 0 ]]; do
    case "$1" in

      --install)
        shift
        cmd_install "${1:-}"
        exit 0
        ;;
      --install=*)                          # --install=<url> form
        cmd_install "${1#*=}"
        exit 0
        ;;

      --make)
        action_list
        exit 0
        ;;

      -h|--help)
        usage
        exit 0
        ;;

      --*)
        error "Unknown option: $1"
        usage
        exit 1
        ;;

      *)
        error "Unexpected argument: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

# ─── Main Menu & Actions ─────────────────────────────────────────────────────
main_menu() {
  while true; do
    header "Main Menu"
    echo -e "  ${GREEN}1)${RESET} Install Config"
    echo -e "  ${GREEN}2)${RESET} Generate Config"
    echo -e "  ${RED}0)${RESET} Exit\n"

    read -rp "$(echo -e "${BOLD}Choose an option [0-5]:${RESET} ")" choice

    case "$choice" in
      1) config_install ;;
      2) config_make ;;
      0) success "Goodbye!"; exit 0 ;;
      *) error "Unknown option: '$choice'. Please enter a number between 0 and 5." ;;
    esac

    echo ""
    read -rp "$(echo -e "${CYAN}Press Enter to return to the main menu...${RESET}")" _
  done
}

# ─── Entry Point ──────────────────────────────────────────────────────────────
main() {
  # Optional: accept a direct CLI argument to skip the menu for instant installation
#  if [[ "${1:-}" == "--install" ]]; then
#    config_install
#    exit 0
#  fi

  clear
  echo -e "${BOLD}"

  echo "  ____  ___  ___ ";
  echo " / __ \\/ _ \\/ _ \\";
  echo "/ /_/ / // / ___/";
  echo "\\____/____/_/    Open Dotfile Protocol v.0.1";

  echo -e "${RESET}"

  parse_args "$@"   # ← replaces the old if/else block
}

main "$@"
