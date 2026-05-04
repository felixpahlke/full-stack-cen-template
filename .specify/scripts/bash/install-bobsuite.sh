#!/usr/bin/env bash
#
# BobSuite Turn-Key Installer for macOS
# Follows Rich-style UX patterns from __init__.py
#
# This script automates the installation of BobSuite and its prerequisites on macOS.
# It checks for required tools, installs missing ones via Homebrew, and sets up BobSuite.
#
# Usage:
#   ./install-bobsuite.sh [OPTIONS]
#
# Options:
#   --non-interactive    Skip all prompts (for CI/CD)
#   --verbose           Show detailed output
#   --dry-run           Show what would be done without making changes
#   --help, -h          Show this help message
#
# Prerequisites installed:
#   - Homebrew (if missing)
#   - Python 3.11+ (upgrades to 3.12 if < 3.11)
#   - Git
#   - GitHub CLI (gh)
#   - uv (Python package manager)
#
# Note: Bob-IDE/BobShell cannot be installed automatically and must be installed manually.

set -e  # Exit on error
set -o pipefail  # Catch errors in pipes

# Color codes for Rich-style output
readonly COLOR_RESET='\033[0m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_DIM='\033[2m'
readonly COLOR_BOLD='\033[1m'

# Status symbols (matching __init__.py)
readonly SYMBOL_COMPLETE="${COLOR_GREEN}●${COLOR_RESET}"
readonly SYMBOL_PENDING="${COLOR_DIM}○${COLOR_RESET}"
readonly SYMBOL_PROGRESS="${COLOR_CYAN}○${COLOR_RESET}"
readonly SYMBOL_ERROR="${COLOR_RED}●${COLOR_RESET}"
readonly SYMBOL_WARNING="${COLOR_YELLOW}○${COLOR_RESET}"
readonly SYMBOL_ARROW="${COLOR_CYAN}→${COLOR_RESET}"
readonly SYMBOL_CHECK="${COLOR_GREEN}✓${COLOR_RESET}"
readonly SYMBOL_CROSS="${COLOR_RED}✗${COLOR_RESET}"

# Script options
NON_INTERACTIVE=false
VERBOSE=false
DRY_RUN=false
BOBSUITE_INSTALL_TYPE=""  # "persistent", "onetime", or "skip"

# Installation state tracking (bash 3.2 compatible - no associative arrays)
# Using parallel arrays instead
TOOL_STATUS_KEYS=()
TOOL_STATUS_VALUES=()
TOOL_VERSIONS_KEYS=()
TOOL_VERSIONS_VALUES=()
TOOL_ERRORS_KEYS=()
TOOL_ERRORS_VALUES=()
FAILED_TOOLS=()
INSTALLED_TOOLS=()

# Helper functions for simulating associative arrays
set_status() {
    local key="$1"
    local value="$2"
    local found=false
    
    for i in "${!TOOL_STATUS_KEYS[@]}"; do
        if [[ "${TOOL_STATUS_KEYS[$i]}" == "$key" ]]; then
            TOOL_STATUS_VALUES[$i]="$value"
            found=true
            break
        fi
    done
    
    if [[ "$found" == "false" ]]; then
        TOOL_STATUS_KEYS+=("$key")
        TOOL_STATUS_VALUES+=("$value")
    fi
}

get_status() {
    local key="$1"
    for i in "${!TOOL_STATUS_KEYS[@]}"; do
        if [[ "${TOOL_STATUS_KEYS[$i]}" == "$key" ]]; then
            echo "${TOOL_STATUS_VALUES[$i]}"
            return
        fi
    done
    echo ""
}

set_version() {
    local key="$1"
    local value="$2"
    local found=false
    
    for i in "${!TOOL_VERSIONS_KEYS[@]}"; do
        if [[ "${TOOL_VERSIONS_KEYS[$i]}" == "$key" ]]; then
            TOOL_VERSIONS_VALUES[$i]="$value"
            found=true
            break
        fi
    done
    
    if [[ "$found" == "false" ]]; then
        TOOL_VERSIONS_KEYS+=("$key")
        TOOL_VERSIONS_VALUES+=("$value")
    fi
}

get_version() {
    local key="$1"
    for i in "${!TOOL_VERSIONS_KEYS[@]}"; do
        if [[ "${TOOL_VERSIONS_KEYS[$i]}" == "$key" ]]; then
            echo "${TOOL_VERSIONS_VALUES[$i]}"
            return
        fi
    done
    echo ""
}

set_error() {
    local key="$1"
    local value="$2"
    local found=false
    
    for i in "${!TOOL_ERRORS_KEYS[@]}"; do
        if [[ "${TOOL_ERRORS_KEYS[$i]}" == "$key" ]]; then
            TOOL_ERRORS_VALUES[$i]="$value"
            found=true
            break
        fi
    done
    
    if [[ "$found" == "false" ]]; then
        TOOL_ERRORS_KEYS+=("$key")
        TOOL_ERRORS_VALUES+=("$value")
    fi
}

get_error() {
    local key="$1"
    for i in "${!TOOL_ERRORS_KEYS[@]}"; do
        if [[ "${TOOL_ERRORS_KEYS[$i]}" == "$key" ]]; then
            echo "${TOOL_ERRORS_VALUES[$i]}"
            return
        fi
    done
    echo ""
}

# Minimum required versions
readonly MIN_PYTHON_VERSION="3.11"
readonly TARGET_PYTHON_VERSION="3.12"

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --non-interactive)
                NON_INTERACTIVE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${COLOR_RED}Error:${COLOR_RESET} Unknown option '$1'"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << 'EOF'
BobSuite Turn-Key Installer for macOS

Usage:
  ./install-bobsuite.sh [OPTIONS]

Options:
  --non-interactive    Skip all prompts (for CI/CD)
  --verbose           Show detailed output
  --dry-run           Show what would be done without making changes
  --help, -h          Show this help message

Interactive Mode:
  By default, the script will show an interactive menu after displaying
  the summary of required changes. Use arrow keys (↑/↓) to navigate
  between YES and NO options, then press Enter to confirm.
  
  If the script appears to pause after "These changes are required for
  BobSuite to function", it's waiting for your input via arrow keys.

This script will:
  1. Check for Homebrew and offer to install if missing
  2. Check for required prerequisites and their versions
  3. Show a summary of required changes
  4. Prompt for confirmation (unless --non-interactive)
  5. Install/upgrade missing or outdated tools
  6. Configure GitHub CLI for github.ibm.com
  7. Install BobSuite via uv
  8. Verify installation with 'bobsuite check'

Prerequisites installed:
  - Homebrew (package manager)
  - Python 3.11+ (upgrades to 3.12 if < 3.11)
  - Git (version control)
  - GitHub CLI (gh)
  - uv (Python package manager)

Note: Bob-IDE/BobShell must be installed manually from:
      https://pages.github.ibm.com/code-assistant/bob-docs/

EOF
}

# Print functions with Rich-style formatting
print_banner() {
    echo -e "${COLOR_CYAN}╭─ BobSuite Installation ─────────────────────────────────────────╮${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│${COLOR_RESET}                                                                  ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_BOLD}Welcome to the BobSuite All-in-One Installer${COLOR_RESET}                  ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│${COLOR_RESET}  Platform: macOS $(sw_vers -productVersion) ($(uname -m))                                   ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│${COLOR_RESET}                                                                  ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_DIM}Please be patient - installation may take up to 30 minutes${COLOR_RESET}      ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│${COLOR_RESET}                                                                  ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}╰──────────────────────────────────────────────────────────────────╯${COLOR_RESET}"
    echo ""
}

print_section() {
    echo -e "\n${COLOR_BOLD}$1${COLOR_RESET}"
}

print_step() {
    local symbol="$1"
    local label="$2"
    local detail="${3:-}"
    
    if [[ -n "$detail" ]]; then
        echo -e "  $symbol ${COLOR_RESET}$label${COLOR_RESET} ${COLOR_DIM}($detail)${COLOR_RESET}"
    else
        echo -e "  $symbol ${COLOR_RESET}$label${COLOR_RESET}"
    fi
}

print_substep() {
    local symbol="$1"
    local message="$2"
    echo -e "    $symbol $message"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${COLOR_DIM}[DEBUG] $*${COLOR_RESET}" >&2
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get Python version with timeout (handles broken Python installations)
get_python_version() {
    local python_cmd="$1"
    
    # First check if command exists
    if ! command -v "$python_cmd" >/dev/null 2>&1; then
        echo ""
        return
    fi
    
    # Use a subshell with timeout to handle hanging Python
    local temp_file="/tmp/py_ver_$$_$(date +%s)"
    
    # Run Python version check in background
    (
        "$python_cmd" --version 2>&1 </dev/null | head -1 > "$temp_file" 2>&1
        exit ${PIPESTATUS[0]}
    ) &
    local pid=$!
    
    # Wait up to 3 seconds
    local waited=0
    while [ $waited -lt 30 ]; do
        if ! kill -0 $pid 2>/dev/null; then
            # Process finished
            break
        fi
        sleep 0.1
        waited=$((waited + 1))
    done
    
    # If still running after 3 seconds, kill it
    if kill -0 $pid 2>/dev/null; then
        kill -9 $pid 2>/dev/null
        wait $pid 2>/dev/null
        rm -f "$temp_file"
        log_verbose "$python_cmd timed out (likely broken installation)"
        echo ""
        return
    fi
    
    # Wait for process to finish
    wait $pid 2>/dev/null
    local exit_code=$?
    
    # Read output if available
    local version_output=""
    if [ -f "$temp_file" ]; then
        version_output=$(cat "$temp_file" 2>/dev/null)
        rm -f "$temp_file"
    fi
    
    # If command failed, return empty
    if [ $exit_code -ne 0 ] || [ -z "$version_output" ]; then
        echo ""
        return
    fi
    
    # Extract version number
    local version=$(echo "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    # Return version or empty string
    echo "$version"
}

# Compare version numbers (returns 0 if v1 >= v2, 1 otherwise)
version_ge() {
    local v1="$1"
    local v2="$2"
    
    # Convert versions to comparable format
    local v1_major=$(echo "$v1" | cut -d. -f1)
    local v1_minor=$(echo "$v1" | cut -d. -f2)
    local v2_major=$(echo "$v2" | cut -d. -f1)
    local v2_minor=$(echo "$v2" | cut -d. -f2)
    
    if [[ "$v1_major" -gt "$v2_major" ]]; then
        return 0
    elif [[ "$v1_major" -eq "$v2_major" ]] && [[ "$v1_minor" -ge "$v2_minor" ]]; then
        return 0
    else
        return 1
    fi
}

# Check Homebrew
check_homebrew() {
    print_step "$SYMBOL_PROGRESS" "Homebrew"
    
    if command_exists brew; then
        local brew_version=$(brew --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        set_status "homebrew" "found"
        set_version "homebrew" "$brew_version"
        print_substep "$SYMBOL_CHECK" "found (version $brew_version)"
        return 0
    else
        set_status "homebrew" "missing"
        print_substep "$SYMBOL_CROSS" "not found"
        return 1
    fi
}

# Check Python
check_python() {
    print_step "$SYMBOL_PROGRESS" "Python $MIN_PYTHON_VERSION+"
    
    # Try different Python commands
    for cmd in python3 python3.12 python3.11 python; do
        log_verbose "Checking for $cmd..."
        if command_exists "$cmd"; then
            log_verbose "Found $cmd, getting version..."
            local version=$(get_python_version "$cmd")
            log_verbose "Version check returned: '$version'"
            if [[ -n "$version" ]]; then
                log_verbose "Found $cmd with version $version"
                
                if version_ge "$version" "$MIN_PYTHON_VERSION"; then
                    set_status "python" "found"
                    set_version "python" "$version"
                    print_substep "$SYMBOL_CHECK" "found (version $version)"
                    return 0
                else
                    set_status "python" "outdated"
                    set_version "python" "$version"
                    print_substep "$SYMBOL_WARNING" "found but outdated (version $version < $MIN_PYTHON_VERSION)"
                    return 1
                fi
            else
                log_verbose "$cmd exists but version check failed or timed out"
            fi
        else
            log_verbose "$cmd not found"
        fi
    done
    
    set_status "python" "missing"
    print_substep "$SYMBOL_CROSS" "not found"
    return 1
}

# Check Git
check_git() {
    print_step "$SYMBOL_PROGRESS" "Git"
    
    if command_exists git; then
        local version=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        set_status "git" "found"
        set_version "git" "$version"
        print_substep "$SYMBOL_CHECK" "found (version $version)"
        return 0
    else
        set_status "git" "missing"
        print_substep "$SYMBOL_CROSS" "not found"
        return 1
    fi
}

# Check GitHub CLI
check_gh() {
    print_step "$SYMBOL_PROGRESS" "GitHub CLI"
    
    if command_exists gh; then
        local version=$(gh --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        set_status "gh" "found"
        set_version "gh" "$version"
        print_substep "$SYMBOL_CHECK" "found (version $version)"
        return 0
    else
        set_status "gh" "missing"
        print_substep "$SYMBOL_CROSS" "not found"
        return 1
    fi
}

# Check uv
check_uv() {
    print_step "$SYMBOL_PROGRESS" "uv"
    
    if command_exists uv; then
        local version=$(uv --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        set_status "uv" "found"
        set_version "uv" "$version"
        print_substep "$SYMBOL_CHECK" "found (version $version)"
        return 0
    else
        set_status "uv" "missing"
        print_substep "$SYMBOL_CROSS" "not found"
        return 1
    fi
}

# Check Bob-IDE/BobShell (optional)
# Note: 'bob' command confirms both Bob-IDE and BobShell are installed
check_bob_agents() {
    print_step "$SYMBOL_PROGRESS" "Bob-IDE / BobShell (optional)"
    
    if command_exists bob; then
        print_substep "$SYMBOL_CHECK" "found (bob command available)"
        set_status "bob" "found"
    else
        print_substep "$SYMBOL_WARNING" "not found (manual installation required)"
        set_status "bob" "missing"
    fi
}

# Check all prerequisites
check_prerequisites() {
    print_section "Checking prerequisites"
    
    # Don't exit on check failures - we want to collect all status
    check_homebrew || true
    check_python || true
    check_git || true
    check_gh || true
    check_uv || true
    check_bob_agents || true
    
    echo ""
}

# Show summary of required changes
show_summary() {
    local changes_needed=false
    
    print_section "Summary of required changes"
    
    if [[ "$(get_status homebrew)" == "missing" ]]; then
        print_step "$SYMBOL_ARROW" "Install Homebrew (package manager)"
        changes_needed=true
    fi
    
    if [[ "$(get_status python)" == "missing" ]]; then
        print_step "$SYMBOL_ARROW" "Install Python $TARGET_PYTHON_VERSION"
        changes_needed=true
    elif [[ "$(get_status python)" == "outdated" ]]; then
        print_step "$SYMBOL_ARROW" "Upgrade Python from $(get_version python) to $TARGET_PYTHON_VERSION"
        changes_needed=true
    fi
    
    if [[ "$(get_status git)" == "missing" ]]; then
        print_step "$SYMBOL_ARROW" "Install Git"
        changes_needed=true
    fi
    
    if [[ "$(get_status gh)" == "missing" ]]; then
        print_step "$SYMBOL_ARROW" "Install GitHub CLI"
        changes_needed=true
    fi
    
    if [[ "$(get_status uv)" == "missing" ]]; then
        print_step "$SYMBOL_ARROW" "Install uv (Python package manager)"
        changes_needed=true
    fi
    
    print_step "$SYMBOL_ARROW" "Configure GitHub CLI for github.ibm.com"
    print_step "$SYMBOL_ARROW" "Install BobSuite CLI"
    
    echo ""
    
    if [[ "$(get_status bob)" == "missing" ]]; then
        echo -e "${COLOR_YELLOW}Note:${COLOR_RESET} Bob-IDE/BobShell must be installed manually from:"
        echo -e "      ${COLOR_CYAN}https://pages.github.ibm.com/code-assistant/bob-docs/${COLOR_RESET}"
        echo -e "      ${COLOR_DIM}BobSuite is designed for use with these tools.${COLOR_RESET}"
        echo ""
    fi
    
    if [[ "$changes_needed" == "false" ]] && [[ "$(get_status homebrew)" == "found" ]]; then
        echo -e "${COLOR_GREEN}All prerequisites are already installed!${COLOR_RESET}"
        echo -e "${COLOR_DIM}Will proceed with GitHub CLI configuration and BobSuite installation.${COLOR_RESET}"
        echo ""
    fi
}

# Prompt for confirmation
prompt_confirmation() {
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        log_verbose "Non-interactive mode: proceeding automatically"
        return 0
    fi
    
    echo -e "${COLOR_BOLD}These changes are required for BobSuite to function.${COLOR_RESET}"
    echo ""
    
    # Simple yes/no prompt
    while true; do
        echo -ne "${COLOR_CYAN}Proceed with installation? [Y/n]:${COLOR_RESET} "
        read -r response
        
        # Default to yes if empty
        if [[ -z "$response" ]]; then
            response="y"
        fi
        
        # Convert to lowercase (bash 3.2 compatible)
        response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
        
        case "$response" in
            y|yes)
                echo ""
                return 0
                ;;
            n|no)
                echo ""
                echo -e "${COLOR_YELLOW}Installation cancelled by user${COLOR_RESET}"
                exit 0
                ;;
            *)
                echo -e "${COLOR_RED}Please answer 'y' or 'n'${COLOR_RESET}"
                ;;
        esac
    done
}

# Install Homebrew
install_homebrew() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_substep "$SYMBOL_ARROW" "Would install Homebrew"
        return 0
    fi
    
    print_substep "$SYMBOL_ARROW" "Installing Homebrew..."
    
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        # Add Homebrew to PATH for this session
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f "/usr/local/bin/brew" ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        
        print_substep "$SYMBOL_CHECK" "Homebrew installed successfully"
        INSTALLED_TOOLS+=("homebrew")
        return 0
    else
        print_substep "$SYMBOL_CROSS" "Failed to install Homebrew"
        FAILED_TOOLS+=("homebrew")
        set_error "homebrew" "Installation script failed"
        return 1
    fi
}

# Install or upgrade Python
install_python() {
    if [[ "$DRY_RUN" == "true" ]]; then
        if [[ "$(get_status python)" == "outdated" ]]; then
            print_substep "$SYMBOL_ARROW" "Would upgrade Python to $TARGET_PYTHON_VERSION"
        else
            print_substep "$SYMBOL_ARROW" "Would install Python $TARGET_PYTHON_VERSION"
        fi
        return 0
    fi
    
    if [[ "$(get_status python)" == "outdated" ]]; then
        print_substep "$SYMBOL_ARROW" "Upgrading Python to $TARGET_PYTHON_VERSION..."
    else
        print_substep "$SYMBOL_ARROW" "Installing Python $TARGET_PYTHON_VERSION..."
    fi
    
    if brew install "python@$TARGET_PYTHON_VERSION" 2>&1 | tee /tmp/brew-python.log; then
        print_substep "$SYMBOL_CHECK" "Python $TARGET_PYTHON_VERSION installed successfully"
        INSTALLED_TOOLS+=("python")
        return 0
    else
        print_substep "$SYMBOL_CROSS" "Failed to install Python"
        FAILED_TOOLS+=("python")
        set_error "python" "Homebrew installation failed (see /tmp/brew-python.log)"
        return 1
    fi
}

# Install Git
install_git() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_substep "$SYMBOL_ARROW" "Would install Git"
        return 0
    fi
    
    print_substep "$SYMBOL_ARROW" "Installing Git..."
    
    if brew install git 2>&1 | tee /tmp/brew-git.log; then
        print_substep "$SYMBOL_CHECK" "Git installed successfully"
        INSTALLED_TOOLS+=("git")
        return 0
    else
        print_substep "$SYMBOL_CROSS" "Failed to install Git"
        FAILED_TOOLS+=("git")
        set_error "git" "Homebrew installation failed (see /tmp/brew-git.log)"
        return 1
    fi
}

# Install GitHub CLI
install_gh() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_substep "$SYMBOL_ARROW" "Would install GitHub CLI"
        return 0
    fi
    
    print_substep "$SYMBOL_ARROW" "Installing GitHub CLI..."
    
    if brew install gh 2>&1 | tee /tmp/brew-gh.log; then
        print_substep "$SYMBOL_CHECK" "GitHub CLI installed successfully"
        INSTALLED_TOOLS+=("gh")
        return 0
    else
        print_substep "$SYMBOL_CROSS" "Failed to install GitHub CLI"
        FAILED_TOOLS+=("gh")
        set_error "gh" "Homebrew installation failed (see /tmp/brew-gh.log)"
        return 1
    fi
}

# Install uv
install_uv() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_substep "$SYMBOL_ARROW" "Would install uv"
        return 0
    fi
    
    print_substep "$SYMBOL_ARROW" "Installing uv..."
    
    if brew install uv 2>&1 | tee /tmp/brew-uv.log; then
        print_substep "$SYMBOL_CHECK" "uv installed successfully"
        INSTALLED_TOOLS+=("uv")
        return 0
    else
        print_substep "$SYMBOL_CROSS" "Failed to install uv"
        FAILED_TOOLS+=("uv")
        set_error "uv" "Homebrew installation failed (see /tmp/brew-uv.log)"
        return 1
    fi
}

# Install all missing prerequisites
install_prerequisites() {
    print_section "Installing prerequisites"
    
    # Install Homebrew if needed
    if [[ "$(get_status homebrew)" == "missing" ]]; then
        print_step "$SYMBOL_PROGRESS" "Homebrew"
        install_homebrew
    fi
    
    # Install Python if needed
    if [[ "$(get_status python)" == "missing" ]] || [[ "$(get_status python)" == "outdated" ]]; then
        print_step "$SYMBOL_PROGRESS" "Python $TARGET_PYTHON_VERSION"
        install_python
    fi
    
    # Install Git if needed
    if [[ "$(get_status git)" == "missing" ]]; then
        print_step "$SYMBOL_PROGRESS" "Git"
        install_git
    fi
    
    # Install GitHub CLI if needed
    if [[ "$(get_status gh)" == "missing" ]]; then
        print_step "$SYMBOL_PROGRESS" "GitHub CLI"
        install_gh
    fi
    
    # Install uv if needed
    if [[ "$(get_status uv)" == "missing" ]]; then
        print_step "$SYMBOL_PROGRESS" "uv"
        install_uv
    fi
    
    echo ""
}

# Configure GitHub CLI
configure_gh() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_section "Configuring GitHub CLI"
        print_step "$SYMBOL_ARROW" "Would configure GitHub CLI for github.ibm.com"
        echo ""
        return 0
    fi
    
    print_section "Configuring GitHub CLI"
    print_step "$SYMBOL_PROGRESS" "Authentication for github.ibm.com"
    
    # Check if already authenticated
    if gh auth status --hostname github.ibm.com >/dev/null 2>&1; then
        print_substep "$SYMBOL_CHECK" "Already authenticated"
        echo ""
        return 0
    fi
    
    print_substep "$SYMBOL_ARROW" "Opening browser for authentication..."
    echo ""
    
    if gh auth login --hostname github.ibm.com --web; then
        print_substep "$SYMBOL_CHECK" "Successfully authenticated"
        echo ""
        return 0
    else
        print_substep "$SYMBOL_CROSS" "Authentication failed"
        FAILED_TOOLS+=("gh-auth")
        set_error "gh-auth" "GitHub CLI authentication failed"
        echo ""
        return 1
    fi
}

# Prompt for BobSuite installation type
prompt_bobsuite_install_type() {
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        log_verbose "Non-interactive mode: using persistent install"
        BOBSUITE_INSTALL_TYPE="persistent"
        return 0
    fi
    
    echo -e "${COLOR_BOLD}BobSuite Installation Options${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_CYAN}[1]${COLOR_RESET} ${COLOR_BOLD}Persistent Install${COLOR_RESET}"
    echo -e "      Installs BobSuite globally using 'uv tool install'"
    echo -e "      ${COLOR_DIM}Use 'bobsuite' command from anywhere${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_CYAN}[2]${COLOR_RESET} ${COLOR_BOLD}One-Time Usage${COLOR_RESET}"
    echo -e "      Run BobSuite without installing using 'uvx'"
    echo -e "      ${COLOR_DIM}No persistent installation, run on-demand${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_CYAN}[3]${COLOR_RESET} ${COLOR_BOLD}Skip BobSuite Installation${COLOR_RESET}"
    echo -e "      Only install prerequisites (Homebrew, Python, Git, gh, uv)"
    echo -e "      ${COLOR_DIM}Install BobSuite manually later${COLOR_RESET}"
    echo ""
    
    while true; do
        echo -ne "${COLOR_CYAN}Select installation type [1-3]:${COLOR_RESET} "
        read -r choice
        
        case "$choice" in
            1)
                BOBSUITE_INSTALL_TYPE="persistent"
                echo ""
                return 0
                ;;
            2)
                BOBSUITE_INSTALL_TYPE="onetime"
                echo ""
                return 0
                ;;
            3)
                BOBSUITE_INSTALL_TYPE="skip"
                echo ""
                return 0
                ;;
            *)
                echo -e "${COLOR_RED}Invalid choice. Please enter 1, 2, or 3.${COLOR_RESET}"
                ;;
        esac
    done
}

# Install BobSuite
install_bobsuite() {
    # Check if user chose to skip
    if [[ "$BOBSUITE_INSTALL_TYPE" == "skip" ]]; then
        print_section "Skipping BobSuite installation"
        print_step "$SYMBOL_ARROW" "BobSuite installation skipped by user"
        echo ""
        return 0
    fi
    
    # Check if user chose one-time usage
    if [[ "$BOBSUITE_INSTALL_TYPE" == "onetime" ]]; then
        print_section "BobSuite One-Time Usage"
        print_step "$SYMBOL_CHECK" "Prerequisites installed for one-time usage"
        echo ""
        return 0
    fi
    
    # Persistent install
    if [[ "$DRY_RUN" == "true" ]]; then
        print_section "Installing BobSuite"
        print_step "$SYMBOL_ARROW" "Would install BobSuite CLI via uv"
        echo ""
        return 0
    fi
    
    print_section "Installing BobSuite"
    print_step "$SYMBOL_PROGRESS" "Installing via uv"
    
    print_substep "$SYMBOL_ARROW" "Running: uv tool install bobsuite-cli --from git+https://github.ibm.com/PixelPaladins/bobsuite.git"
    
    if uv tool install bobsuite-cli --from git+https://github.ibm.com/PixelPaladins/bobsuite.git 2>&1 | tee /tmp/uv-install.log; then
        print_substep "$SYMBOL_CHECK" "BobSuite CLI installed successfully"
        INSTALLED_TOOLS+=("bobsuite")
        echo ""
        return 0
    else
        print_substep "$SYMBOL_CROSS" "Failed to install BobSuite"
        FAILED_TOOLS+=("bobsuite")
        set_error "bobsuite" "uv installation failed (see /tmp/uv-install.log)"
        echo ""
        return 1
    fi
}

# Verify installation
verify_installation() {
    # Skip verification for one-time usage or skip installation
    if [[ "$BOBSUITE_INSTALL_TYPE" == "onetime" ]] || [[ "$BOBSUITE_INSTALL_TYPE" == "skip" ]]; then
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_section "Verifying installation"
        print_step "$SYMBOL_ARROW" "Would run 'bobsuite check' to verify installation"
        echo ""
        return 0
    fi
    
    print_section "Verifying installation"
    print_step "$SYMBOL_PROGRESS" "Running bobsuite check"
    echo ""
    
    if command_exists bobsuite; then
        bobsuite check
        return 0
    else
        print_substep "$SYMBOL_CROSS" "bobsuite command not found in PATH"
        echo -e "${COLOR_YELLOW}Note:${COLOR_RESET} You may need to restart your terminal or run:"
        echo -e "      ${COLOR_CYAN}source ~/.zshrc${COLOR_RESET}  (or ~/.bash_profile)"
        echo ""
        return 1
    fi
}

# Show installation summary
show_installation_summary() {
    print_section "Installation Summary"
    
    if [[ ${#INSTALLED_TOOLS[@]} -gt 0 ]]; then
        echo -e "${COLOR_GREEN}Successfully installed:${COLOR_RESET}"
        for tool in "${INSTALLED_TOOLS[@]}"; do
            print_step "$SYMBOL_CHECK" "$tool"
        done
        echo ""
    fi
    
    if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
        echo -e "${COLOR_RED}Failed installations:${COLOR_RESET}"
        for tool in "${FAILED_TOOLS[@]}"; do
            local error="$(get_error "$tool")"
            if [[ -z "$error" ]]; then
                error="Unknown error"
            fi
            print_step "$SYMBOL_CROSS" "$tool" "$error"
        done
        echo ""
        return 1
    fi
    
    return 0
}

# Offer retry for failed installations
offer_retry() {
    if [[ ${#FAILED_TOOLS[@]} -eq 0 ]]; then
        return 0
    fi
    
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        return 1
    fi
    
    echo -e "${COLOR_YELLOW}Some installations failed.${COLOR_RESET}"
    echo ""
    
    local options=("YES - Retry failed installations" "NO  - Exit without retrying")
    local choice=$(show_menu "Would you like to retry?" "${options[@]}")
    
    echo ""  # Add spacing after menu
    
    if [[ "$choice" == "0" ]]; then
        # Clear failed tools and retry
        local tools_to_retry=("${FAILED_TOOLS[@]}")
        FAILED_TOOLS=()
        
        for tool in "${tools_to_retry[@]}"; do
            case "$tool" in
                homebrew)
                    print_step "$SYMBOL_PROGRESS" "Retrying Homebrew installation"
                    install_homebrew
                    ;;
                python)
                    print_step "$SYMBOL_PROGRESS" "Retrying Python installation"
                    install_python
                    ;;
                git)
                    print_step "$SYMBOL_PROGRESS" "Retrying Git installation"
                    install_git
                    ;;
                gh)
                    print_step "$SYMBOL_PROGRESS" "Retrying GitHub CLI installation"
                    install_gh
                    ;;
                uv)
                    print_step "$SYMBOL_PROGRESS" "Retrying uv installation"
                    install_uv
                    ;;
                gh-auth)
                    print_step "$SYMBOL_PROGRESS" "Retrying GitHub CLI authentication"
                    configure_gh
                    ;;
                bobsuite)
                    print_step "$SYMBOL_PROGRESS" "Retrying BobSuite installation"
                    install_bobsuite
                    ;;
            esac
        done
        
        echo ""
        show_installation_summary
        
        # Recursive retry if still have failures
        if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
            offer_retry
        fi
    fi
}

# Show completion message
show_completion() {
    if [[ ${#FAILED_TOOLS[@]} -eq 0 ]]; then
        echo -e "${COLOR_CYAN}╭─ Installation Complete ──────────────────────────────────────────╮${COLOR_RESET}"
        echo ""
        
        # Different message based on installation type
        if [[ "$BOBSUITE_INSTALL_TYPE" == "skip" ]]; then
            echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} Prerequisites successfully installed!"
        elif [[ "$BOBSUITE_INSTALL_TYPE" == "onetime" ]]; then
            echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} Prerequisites installed for one-time usage!"
        else
            echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} BobSuite successfully installed!"
        fi
        
        echo ""
        
        if [[ "$(get_status bob)" == "missing" ]]; then
            echo -e "  ${COLOR_YELLOW}Next steps:${COLOR_RESET}"
            echo -e "  1. Install Bob-IDE from: https://pages.github.ibm.com/code-assistant/bob-docs/"
            echo -e "  2. Disable \"Question\" capability in agent settings"
            echo -e "  3. Initialize your first project:"
        else
            echo -e "  ${COLOR_YELLOW}Next steps:${COLOR_RESET}"
            echo -e "  1. Disable \"Question\" capability in agent settings"
            echo -e "  2. Initialize your first project:"
        fi
        
        echo ""
        
        # Show appropriate command based on installation type
        if [[ "$BOBSUITE_INSTALL_TYPE" == "onetime" ]]; then
            echo -e "  Run this command to initialize your first project:"
            echo ""
            echo "  uvx --from git+https://github.ibm.com/PixelPaladins/bobsuite.git bobsuite init <PROJECT_NAME>"
            echo ""
        elif [[ "$BOBSUITE_INSTALL_TYPE" == "skip" ]]; then
            echo -e "  ${COLOR_CYAN}Visit the BobSuite documentation for installation instructions:${COLOR_RESET}"
            echo "  http://ibm.biz/bobsuite"
        else
            echo "     bobsuite init <my-project>"
        fi
        
        echo ""
        echo -e "${COLOR_CYAN}╰──────────────────────────────────────────────────────────────────╯${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}╭─ Installation Incomplete ────────────────────────────────────────╮${COLOR_RESET}"
        echo -e "${COLOR_RED}│${COLOR_RESET}                                                                  ${COLOR_RED}│${COLOR_RESET}"
        echo -e "${COLOR_RED}│${COLOR_RESET}  ${COLOR_RED}✗${COLOR_RESET} Some installations failed                                    ${COLOR_RED}│${COLOR_RESET}"
        echo -e "${COLOR_RED}│${COLOR_RESET}                                                                  ${COLOR_RED}│${COLOR_RESET}"
        echo -e "${COLOR_RED}│${COLOR_RESET}  Please review the errors above and try again.                   ${COLOR_RED}│${COLOR_RESET}"
        echo -e "${COLOR_RED}│${COLOR_RESET}  You can re-run this script to retry failed installations.       ${COLOR_RED}│${COLOR_RESET}"
        echo -e "${COLOR_RED}│${COLOR_RESET}                                                                  ${COLOR_RED}│${COLOR_RESET}"
        echo -e "${COLOR_RED}╰──────────────────────────────────────────────────────────────────╯${COLOR_RESET}"
    fi
    
    echo ""
}

# Main installation flow
main() {
    parse_args "$@"
    
    print_banner
    
    # Check prerequisites
    check_prerequisites
    
    # Show summary
    show_summary
    
    # Prompt for confirmation
    prompt_confirmation
    
    # Install prerequisites
    install_prerequisites
    
    # Configure GitHub CLI
    configure_gh
    
    # Prompt for BobSuite installation type
    prompt_bobsuite_install_type
    
    # Install BobSuite
    install_bobsuite
    
    # Verify installation
    verify_installation
    
    # Show summary
    show_installation_summary
    
    # Offer retry if needed
    offer_retry
    
    # Show completion message
    show_completion
    
    # Exit with appropriate code
    if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"


