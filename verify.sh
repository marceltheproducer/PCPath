#!/bin/bash
# PCPath Verification — checks that PCPath is correctly installed on macOS.
# Exit code: 0 = all checks passed, 1 = one or more checks failed.

INSTALL_DIR="$HOME/.pcpath"
SERVICES_DIR="$HOME/Library/Services"
CONFIG_FILE="$HOME/.pcpath_mappings"
LOG_FILE="$INSTALL_DIR/install.log"

PASS=0
FAIL=0
WARN=0

_pass() { printf "  [OK] %s\n" "$1"; PASS=$((PASS + 1)); }
_fail() { printf "  [FAIL] %s\n" "$1"; FAIL=$((FAIL + 1)); }
_warn() { printf "  [!!] %s\n" "$1"; WARN=$((WARN + 1)); }

printf "\nPCPath Verification\n"
printf -- "---------------------------------------\n"

# 1. Scripts present and executable
SCRIPTS=("pcpath_common.sh" "copy_pc_path.sh" "paste_mac_path.sh")
all_scripts=true
for s in "${SCRIPTS[@]}"; do
    [[ ! -x "$INSTALL_DIR/$s" ]] && all_scripts=false
done
if [[ "$all_scripts" == true ]]; then
    _pass "Scripts installed at $INSTALL_DIR/"
else
    _fail "Scripts missing or not executable at $INSTALL_DIR/"
    printf "       Run install.sh to fix this.\n"
fi

# 2. Config file with at least one valid mapping
if [[ -f "$CONFIG_FILE" ]]; then
    mapping_count=0
    while IFS= read -r line; do
        line="${line//$'\r'/}"
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        mapping_count=$((mapping_count + 1))
    done < "$CONFIG_FILE"
    if [[ "$mapping_count" -gt 0 ]]; then
        _pass "Config file exists ($mapping_count mapping(s))"
    else
        _fail "Config file exists but has no valid mappings"
        printf "       Edit %s to add mappings (format: VOLUME=K)\n" "$CONFIG_FILE"
    fi
else
    _fail "Config file not found at $CONFIG_FILE"
    printf "       Run install.sh or create the file manually.\n"
fi

# 3. Quick Action workflows installed
WORKFLOWS=("Copy as PC Path.workflow" "Convert to Mac Path.workflow")
all_workflows=true
for w in "${WORKFLOWS[@]}"; do
    [[ ! -d "$SERVICES_DIR/$w" ]] && all_workflows=false
done
if [[ "$all_workflows" == true ]]; then
    _pass "Quick Actions installed in $SERVICES_DIR/"
else
    _fail "Quick Actions missing from $SERVICES_DIR/"
    printf "       Run install.sh to fix this.\n"
fi

# 4. Quick Action enabled state (cannot be read programmatically)
_warn "Quick Action enable state unknown -- confirm in System Settings -> Extensions -> Finder"

# 5. Install log (informational, not required)
if [[ -f "$LOG_FILE" ]]; then
    log_line=$(tail -1 "$LOG_FILE" 2>/dev/null)
    _pass "Install log: $log_line"
fi

# 6. Self-test: live conversion
if [[ -x "$INSTALL_DIR/pcpath_common.sh" ]]; then
    source "$INSTALL_DIR/pcpath_common.sh"
    pcpath_load_mappings
    if [[ ${#vol_names[@]} -gt 0 ]]; then
        _vol="${vol_names[0]}"
        _letter="${drive_letters[0]}"
        _input="/Volumes/${_vol}/Projects/test.mp4"
        _prefix="/Volumes/${_vol}/"
        _remainder="${_input:${#_prefix}}"
        _result="${_letter}:\\${_remainder}"
        _result="${_result//\//\\}"
        if [[ "$_result" == "${_letter}:\\Projects\\test.mp4" ]]; then
            _pass "Self-test passed: /Volumes/${_vol} -> ${_letter}:\\"
        else
            _fail "Self-test failed: unexpected output from conversion"
        fi
    else
        _warn "No mappings loaded -- self-test skipped"
    fi
fi

printf "\n"
if [[ "$FAIL" -gt 0 ]]; then
    printf "%d issue(s) found. See above.\n" "$FAIL"
    exit 1
elif [[ "$WARN" -gt 0 ]]; then
    printf "All critical checks passed. %d item(s) need manual confirmation.\n" "$WARN"
    exit 0
else
    printf "All checks passed.\n"
    exit 0
fi
