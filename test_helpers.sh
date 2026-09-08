#!/bin/bash
# Test helper functions for xLink Client add-on tests
# This file is sourced by test_addon.sh

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test helper functions

# Assert that two values are equal
assert_eq() {
    local name="$1"
    local expected="$2"
    local actual="$3"
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} ${name}"
        return 0
    else
        echo -e "${RED}✗${NC} ${name}"
        echo "  Expected: ${expected}"
        echo "  Actual:   ${actual}"
        return 1
    fi
}

# Assert that a file exists
assert_file_exists() {
    local name="$1"
    local filepath="$2"
    
    if [[ -f "$filepath" ]]; then
        echo -e "${GREEN}✓${NC} ${name}"
        return 0
    else
        echo -e "${RED}✗${NC} ${name}"
        echo "  File not found: ${filepath}"
        return 1
    fi
}

# Assert that a directory exists
assert_dir_exists() {
    local name="$1"
    local dirpath="$2"
    
    if [[ -d "$dirpath" ]]; then
        echo -e "${GREEN}✓${NC} ${name}"
        return 0
    else
        echo -e "${RED}✗${NC} ${name}"
        echo "  Directory not found: ${dirpath}"
        return 1
    fi
}

# Assert that a string contains a substring
assert_contains() {
    local name="$1"
    local haystack="$2"
    local needle="$3"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}✓${NC} ${name}"
        return 0
    else
        echo -e "${RED}✗${NC} ${name}"
        echo "  Expected to contain: ${needle}"
        return 1
    fi
}

# Assert that a script has valid bash syntax
assert_valid_syntax() {
    local name="$1"
    local scriptpath="$2"
    
    if bash -n "$scriptpath" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} ${name}"
        return 0
    else
        echo -e "${RED}✗${NC} ${name}"
        bash -n "$scriptpath" 2>&1 | head -5
        return 1
    fi
}

# Assert that a script contains a specific command
assert_contains_command() {
    local name="$1"
    local scriptpath="$2"
    local command="$3"
    
    local content
    content=$(cat "$scriptpath")
    
    if [[ "$content" == *"$command"* ]]; then
        echo -e "${GREEN}✓${NC} ${name}"
        return 0
    else
        echo -e "${RED}✗${NC} ${name}"
        echo "  Expected to contain command: ${command}"
        return 1
    fi
}

# Assert that a YAML file has a specific key
assert_yaml_key() {
    local name="$1"
    local yamlfile="$2"
    local key="$3"
    
    if grep -q "^${key}:" "$yamlfile" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} ${name}"
        return 0
    else
        echo -e "${RED}✗${NC} ${name}"
        echo "  Expected key: ${key}"
        return 1
    fi
}

# Assert that a file is executable
assert_executable() {
    local name="$1"
    local filepath="$2"
    
    if [[ -x "$filepath" ]]; then
        echo -e "${GREEN}✓${NC} ${name}"
        return 0
    else
        echo -e "${RED}✗${NC} ${name}"
        echo "  File not executable: ${filepath}"
        return 1
    fi
}

# Assert that a file is NOT executable (should not be)
assert_not_executable() {
    local name="$1"
    local filepath="$2"
    
    if [[ ! -x "$filepath" ]]; then
        echo -e "${GREEN}✓${NC} ${name}"
        return 0
    else
        echo -e "${RED}✗${NC} ${name}"
        echo "  File should not be executable: ${filepath}"
        return 1
    fi
}

# Assert that a file does not contain a specific string
assert_not_contains() {
    local name="$1"
    local filepath="$2"
    local needle="$3"
    
    local content
    content=$(cat "$filepath" 2>/dev/null || echo "")
    
    if [[ "$content" != *"$needle"* ]]; then
        echo -e "${GREEN}✓${NC} ${name}"
        return 0
    else
        echo -e "${RED}✗${NC} ${name}"
        echo "  Should NOT contain: ${needle}"
        return 1
    fi
}

# Create a temporary directory with cleanup trap
setup_temp_dir() {
    local temp_dir
    temp_dir=$(mktemp -d)
    echo "$temp_dir"
}

# Clean up temporary files
cleanup_temp() {
    local temp_dir="$1"
    if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
        rm -rf "$temp_dir"
    fi
}

# Print a section header
print_section() {
    local section="$1"
    echo ""
    echo "=== ${section} ==="
}

# Print test result
print_result() {
    local status="$1"
    local message="$2"
    
    case "$status" in
        PASS)
            echo -e "${GREEN}✓${NC} ${message}"
            ;;
        FAIL)
            echo -e "${RED}✗${NC} ${message}"
            ;;
        SKIP)
            echo -e "${YELLOW}⊘${NC} ${message}"
            ;;
        *)
            echo "${message}"
            ;;
    esac
}

# Mock bashio for testing
# Usage: create_mock_bashio <config_dir>
create_mock_bashio() {
    local config_dir="$1"
    local mock_script="${config_dir}/mock_bashio.sh"
    
    cat > "$mock_script" << 'BASHIO_MOCK'
#!/bin/bash
# Mock bashio functions for testing

bashio::config() {
    local key="$1"
    local file="/tmp/test_config.yaml"
    
    if [[ -f "$file" ]]; then
        # Extract value from YAML
        local value
        value=$(grep "^${key}:" "$file" | sed "s/^${key}:[[:space:]]*//" | tr -d '"' | tr -d "'")
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi
    
    return 1
}

bashio::config.has_value() {
    bashio::config "$1" > /dev/null 2>&1
    return $?
}

bashio::config.get_bool() {
    local key="$1"
    local value
    value=$(bashio::config "$key" 2>/dev/null)
    if [[ "$value" == "true" ]]; then
        echo "true"
        return 0
    fi
    echo "false"
    return 0
}

bashio::log.info() {
    echo "[INFO] $*"
}

bashio::log.warning() {
    echo "[WARNING] $*"
}

bashio::log.error() {
    echo "[ERROR] $*"
}

bashio::exit.nok() {
    echo "FAIL: $*"
    exit 1
}

bashio::var.json() {
    echo '{}'
}
BASHIO_MOCK
    
    chmod +x "$mock_script"
    echo "$mock_script"
}

# Run a script with mocked bashio
# Usage: run_with_mocked_bashio <script> <bashio_mock>
run_with_mocked_bashio() {
    local script="$1"
    local bashio_mock="$2"
    local test_config="${3:-/tmp/test_config.yaml}"
    
    # Create test config
    mkdir -p /tmp
    cat > "$test_config" << 'YAML'
auth_key: "tskey-test123"
login_server: ""
hostname: "test-ha"
accept_dns: false
advertise_routes:
  - "192.168.1.0/24"
advertise_exit_node: false
advertise_tags:
  - "tag:home"
forward: ""
log_level: info
YAML
    
    # Run script with mocked bashio
    (
        export PATH="/tmp:$PATH"
        bash "$script"
    ) 2>&1
}

# Check if docker is available
check_docker() {
    if command -v docker &> /dev/null; then
        echo "true"
    else
        echo "false"
    fi
}

# Get docker version
get_docker_version() {
    docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "unknown"
}
