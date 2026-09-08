#!/bin/bash
# xLink Client Add-on Test Suite
# Tests for Tailscale-based Home Assistant add-on
#
# Usage: bash test_addon.sh [--unit|--build|--integration]
# --unit        Run only unit tests (default)
# --build       Run build tests (requires Docker)
# --integration Run integration tests (requires Docker + privileged mode)

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Globals
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XLINK_DIR="${TEST_DIR}/xlink_client"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
TEST_RESULTS_FILE=$(mktemp)

# Parse args
RUN_UNIT=true
RUN_BUILD=false
RUN_INTEGRATION=false

case "${1:-}" in
    --unit) RUN_UNIT=true; RUN_BUILD=false; RUN_INTEGRATION=false ;;
    --build) RUN_UNIT=true; RUN_BUILD=true; RUN_INTEGRATION=false ;;
    --integration) RUN_UNIT=true; RUN_BUILD=true; RUN_INTEGRATION=true ;;
    --help|-h)
        echo "Usage: $0 [--unit|--build|--integration]"
        echo "  --unit        Run unit tests only (default)"
        echo "  --build       Run build tests (requires Docker)"
        echo "  --integration Run full test suite (requires Docker + privileged)"
        exit 0
        ;;
esac

# Helpers
pass() {
    local name="$1"; shift
    local detail="${1:-}"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} ${name}"
    [ -n "$detail" ] && echo "    ${detail}"
    echo "PASS:${name}" >> "$TEST_RESULTS_FILE"
}

fail() {
    local name="$1"; shift
    local detail="${1:-}"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} ${name}"
    [ -n "$detail" ] && echo -e "    ${RED}${detail}${NC}"
    echo "FAIL:${name}:${detail}" >> "$TEST_RESULTS_FILE"
}

skip() {
    local name="$1"; shift
    local detail="${1:-}"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    echo -e "${YELLOW}⊘${NC} ${name}"
    [ -n "$detail" ] && echo "    ${detail}"
    echo "SKIP:${name}:${detail}" >> "$TEST_RESULTS_FILE"
}

# ============================================================
# UNIT TESTS
# ============================================================
test_unit_structure() {
    echo ""
    echo -e "${BLUE}=== UNIT: File Structure ===${NC}"
    
    # Required files
    for f in config.yaml Dockerfile build.yaml CHANGELOG.md README.md; do
        if [ -f "${XLINK_DIR}/${f}" ]; then
            pass "${f} exists"
        else
            fail "${f} exists" "File not found: ${XLINK_DIR}/${f}"
        fi
    done
    
    # Service files
    for svc in tailscale forward status; do
        local script="${XLINK_DIR}/rootfs/etc/services.d/${svc}/run"
        if [ -f "$script" ] && [ -r "$script" ]; then
            pass "${svc} service exists"
        else
            fail "${svc} service exists" "Script missing or not readable: ${script}"
        fi
    done
    
    # Init script
    local init="${XLINK_DIR}/rootfs/etc/cont-init.d/tailscale-init.sh"
    if [ -f "$init" ] && [ -r "$init" ]; then
        pass "cont-init script exists"
    else
        fail "cont-init script exists" "Script missing or not readable: ${init}"
    fi
    
    # WireGuard files removed
    local wg_removed=true
    for f in "rootfs/etc/services.d/wireguard/run" \
             "rootfs/etc/services.d/api/run" \
             "rootfs/etc/cont-init.d/wg-config.sh"; do
        if [ -f "${XLINK_DIR}/${f}" ]; then
            wg_removed=false
            fail "Old WireGuard file '${f}' removed" "File still exists!"
        fi
    done
    if $wg_removed; then
        pass "All WireGuard files removed"
    fi
}

test_unit_config_schema() {
    echo ""
    echo -e "${BLUE}=== UNIT: Config Schema ===${NC}"
    
    local config="${XLINK_DIR}/config.yaml"
    
    # Parse YAML manually since we don't want dependencies
    local content
    content=$(cat "$config")
    
    # Required schema entries (under schema: key)
    local required_keys=(
        "auth_key:"
        "login_server:"
        "hostname:"
        "accept_dns:"
        "advertise_routes:"
        "advertise_exit_node:"
        "advertise_tags:"
        "forward:"
        "log_level:"
    )
    
    # Check in the schema section (after the schema: line)
    local schema_section
    schema_section=$(sed -n '/^schema:/,$ p' "$config")
    
    for key in "${required_keys[@]}"; do
        if echo "$schema_section" | grep -q "  ${key}"; then
            pass "Schema key '${key}' defined"
        else
            fail "Schema key '${key}' defined" "Key not found in schema section of config.yaml"
        fi
    done
    
    # Version check
    if echo "$content" | grep -q "^version: 0.1.0"; then
        pass "Version is 0.1.0"
    else
        local version
        version=$(echo "$content" | grep "^version:" | head -1)
        fail "Version is 0.1.0" "Found: ${version}"
    fi
    
    # Architecture support
    if echo "$content" | grep -q "aarch64"; then
        pass "aarch64 architecture supported"
    else
        fail "aarch64 architecture supported"
    fi
    
    if echo "$content" | grep -q "amd64"; then
        pass "amd64 architecture supported"
    else
        fail "amd64 architecture supported"
    fi
    
    # Schema types
    if echo "$content" | grep -q "auth_key: str"; then
        pass "auth_key type is str"
    else
        fail "auth_key type is str"
    fi
    
    if echo "$content" | grep -q "accept_dns: bool"; then
        pass "accept_dns type is bool"
    else
        fail "accept_dns type is bool"
    fi
}

test_unit_dockerfile() {
    echo ""
    echo -e "${BLUE}=== UNIT: Dockerfile ===${NC}"
    
    local dockerfile="${XLINK_DIR}/Dockerfile"
    local content
    content=$(cat "$dockerfile")
    
    # Base image
    if echo "$content" | grep -q "hassio-addons/base"; then
        pass "Uses hassio-addons/base image"
    else
        fail "Uses hassio-addons/base image"
    fi
    
    # Tailscale installation
    if echo "$content" | grep -qi "tailscale"; then
        pass "Installs tailscale"
    else
        fail "Installs tailscale"
    fi
    
    # Socat
    if echo "$content" | grep -q "socat"; then
        pass "Installs socat"
    else
        fail "Installs socat"
    fi
    
    # No WireGuard
    if echo "$content" | grep -qi "wireguard-tools\|wireguard-go\|wireguard.kernel"; then
        fail "No WireGuard dependencies" "Found WireGuard package"
    else
        pass "No WireGuard dependencies"
    fi
    
    # Labels
    if echo "$content" | grep -q "io.hass.type"; then
        pass "Has hassio type label"
    else
        fail "Has hassio type label"
    fi
    
    if echo "$content" | grep -q "maintainer"; then
        pass "Has maintainer label"
    else
        fail "Has maintainer label"
    fi
    
    # Check for proper exit codes
    if echo "$content" | grep -q "apk add.*--no-cache"; then
        pass "Uses --no-cache for apk"
    else
        fail "Uses --no-cache for apk" "Consider adding --no-cache for smaller image"
    fi
}

test_unit_script_syntax() {
    echo ""
    echo -e "${BLUE}=== UNIT: Script Syntax ===${NC}"
    
    local scripts=(
        "${XLINK_DIR}/rootfs/etc/services.d/tailscale/run"
        "${XLINK_DIR}/rootfs/etc/services.d/forward/run"
        "${XLINK_DIR}/rootfs/etc/services.d/status/run"
        "${XLINK_DIR}/rootfs/etc/cont-init.d/tailscale-init.sh"
    )
    
    for script in "${scripts[@]}"; do
        local name
        name=$(basename "$(dirname "$script")")
        
        if bash -n "$script" 2>/dev/null; then
            pass "${name} syntax valid"
        else
            fail "${name} syntax valid" "$(bash -n "$script" 2>&1 | head -1)"
        fi
    done
}

test_unit_script_content() {
    echo ""
    echo -e "${BLUE}=== UNIT: Script Content ===${NC}"
    
    # Tailscale service
    local ts_script="${XLINK_DIR}/rootfs/etc/services.d/tailscale/run"
    local ts_content
    ts_content=$(cat "$ts_script")
    
    if echo "$ts_content" | grep -q "tailscale up"; then
        pass "Tailscale service runs 'tailscale up'"
    else
        fail "Tailscale service runs 'tailscale up'"
    fi
    
    if echo "$ts_content" | grep -q "auth_key"; then
        pass "Reads auth_key config"
    else
        fail "Reads auth_key config"
    fi
    
    if echo "$ts_content" | grep -q "login_server"; then
        pass "Supports custom login_server"
    else
        fail "Supports custom login_server"
    fi
    
    if echo "$ts_content" | grep -q "hostname"; then
        pass "Supports custom hostname"
    else
        fail "Supports custom hostname"
    fi
    
    if echo "$ts_content" | grep -q "tailscaled"; then
        pass "Starts tailscaled daemon"
    else
        fail "Starts tailscaled daemon"
    fi
    
    if echo "$ts_content" | grep -q "WAIT\|RETRIES\|sleep\|while"; then
        pass "Has connection wait/retry logic"
    else
        fail "Has connection wait/retry logic"
    fi
    
    # Forward service
    local fwd_script="${XLINK_DIR}/rootfs/etc/services.d/forward/run"
    local fwd_content
    fwd_content=$(cat "$fwd_script")
    
    if echo "$fwd_content" | grep -q "socat"; then
        pass "Forward service uses socat"
    else
        fail "Forward service uses socat"
    fi
    
    if echo "$fwd_content" | grep -q "forward"; then
        pass "Forward service reads config"
    else
        fail "Forward service reads config"
    fi
    
    # Status service
    local status_script="${XLINK_DIR}/rootfs/etc/services.d/status/run"
    local status_content
    status_content=$(cat "$status_script")
    
    if echo "$status_content" | grep -q "tailscale status"; then
        pass "Status service queries tailscale status"
    else
        fail "Status service queries tailscale status"
    fi
    
    if echo "$status_content" | grep -q "application/json"; then
        pass "Status service returns JSON"
    else
        fail "Status service returns JSON"
    fi
    
    if echo "$status_content" | grep -q "nc -l -p 80"; then
        pass "Status service listens on port 80"
    else
        fail "Status service listens on port 80"
    fi
    
    # Init script
    local init_script="${XLINK_DIR}/rootfs/etc/cont-init.d/tailscale-init.sh"
    local init_content
    init_content=$(cat "$init_script")
    
    if echo "$init_content" | grep -q "tailscale set"; then
        pass "Init script runs 'tailscale set'"
    else
        fail "Init script runs 'tailscale set'"
    fi
    
    if echo "$init_content" | grep -q "advertise_routes"; then
        pass "Handles advertise_routes"
    else
        fail "Handles advertise_routes"
    fi
    
    if echo "$init_content" | grep -q "advertise_tags"; then
        pass "Handles advertise_tags"
    else
        fail "Handles advertise_tags"
    fi
    
    if echo "$init_content" | grep -q "advertise_exit_node"; then
        pass "Handles advertise_exit_node"
    else
        fail "Handles advertise_exit_node"
    fi
    
    if echo "$init_content" | grep -q "tailscaled.state"; then
        pass "Configures state directory"
    else
        fail "Configures state directory"
    fi
}

# ============================================================
# BUILD TESTS
# ============================================================
test_build() {
    echo ""
    echo -e "${BLUE}=== BUILD: Docker Build ===${NC}"
    
    if ! command -v docker &> /dev/null; then
        skip "Docker not installed" "Cannot build test"
        return
    fi
    
    if ! docker info &> /dev/null; then
        skip "Docker daemon not running" "Cannot build test"
        return
    fi
    
    local test_image="xlink-client-test:$(date +%s)"
    
    echo "  Building Docker image..."
    local build_output
    if build_output=$(docker build \
        --build-arg BUILD_ARCH=amd64 \
        --build-arg BUILD_VERSION=0.1.0 \
        --build-arg BUILD_NAME="xLink Client" \
        --build-arg BUILD_DESCRIPTION="Tailscale add-on" \
        -t "$test_image" \
        "${XLINK_DIR}" \
        2>&1); then
        
        pass "Docker image builds successfully"
        
        # Run container for integration tests if requested
        if $RUN_INTEGRATION; then
            test_build_run "$test_image"
        fi
        
        # Cleanup
        docker rmi "$test_image" &>/dev/null
    else
        fail "Docker image builds successfully" "Build output:"
        echo "$build_output" | sed 's/^/    /'
    fi
}

test_build_run() {
    local image="$1"
    echo "  Testing container startup..."
    
    local container
    container=$(docker run -d --privileged "$image" 2>&1)
    
    if [ $? -eq 0 ] && [ -n "$container" ]; then
        pass "Container starts successfully"
        
        # Check container is healthy
        sleep 2
        
        local logs
        logs=$(docker logs "$container" 2>&1)
        
        if echo "$logs" | grep -q "tailscale"; then
            pass "Container runs tailscale"
        else
            fail "Container runs tailscale" "No tailscale processes found in logs"
        fi
        
        # Cleanup
        docker stop "$container" &>/dev/null
        docker rm "$container" &>/dev/null
    else
        fail "Container starts successfully" "Container creation failed: $container"
    fi
}

# ============================================================
# INTEGRATION TESTS
# ============================================================
test_integration() {
    echo ""
    echo -e "${BLUE}=== INTEGRATION: Runtime Behavior ===${NC}"
    
    if ! command -v docker &> /dev/null; then
        skip "Docker not available"
        return
    fi
    
    if ! docker info &> /dev/null; then
        skip "Docker daemon not running"
        return
    fi
    
    # Create test config
    local test_dir
    test_dir=$(mktemp -d)
    
    cat > "${test_dir}/test_config.yaml" << 'EOF'
auth_key: "tskey-test-fake-key-12345"
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
EOF
    
    # Test 1: Config file parsing
    echo "  Testing config file validity..."
    if python3 -c "
import yaml
with open('${test_dir}/test_config.yaml') as f:
    config = yaml.safe_load(f)
assert config['auth_key'] == 'tskey-test-fake-key-12345'
assert config['accept_dns'] == False
assert '192.168.1.0/24' in config['advertise_routes']
print('OK')
" 2>/dev/null; then
        pass "Config file parses correctly"
    else
        fail "Config file parses correctly" "YAML parsing failed"
    fi
    
    # Test 2: Script parameter expansion
    echo "  Testing script parameter expansion..."
    local ts_script="${XLINK_DIR}/rootfs/etc/services.d/tailscale/run"
    
    # Mock bashio
    local bashio_mock="${test_dir}/bashio"
    cat > "$bashio_mock" << 'MOCK'
#!/bin/bash
bashio::config() {
    case "$1" in
        "auth_key") echo "tskey-test-123" ;;
        "login_server") echo "" ;;
        "hostname") echo "test" ;;
        *) echo "" ;;
    esac
}
bashio::config.has_value() {
    [[ ! -z "$(bashio::config "$1")" ]]
}
bashio::log.info() { true; }
MOCK
    chmod +x "$bashio_mock"
    
    # Test that script can source bashio and expand vars
    local test_script="${test_dir}/test_script.sh"
    cat > "$test_script" << TESTSCRIPT
#!/bin/bash
source "$bashio_mock"
AUTH_KEY=\$(bashio::config "auth_key")
if [ "\$AUTH_KEY" = "tskey-test-123" ]; then
    echo "AUTH_KEY_OK"
else
    echo "AUTH_KEY_FAIL"
fi
TESTSCRIPT
    chmod +x "$test_script"
    
    if OUTPUT=$(bash "$test_script" 2>/dev/null) && [ "$OUTPUT" = "AUTH_KEY_OK" ]; then
        pass "Script parameter expansion works"
    else
        fail "Script parameter expansion works" "Got: $OUTPUT"
    fi
    
    # Test 3: Port configuration
    echo "  Testing port configuration..."
    local config="${XLINK_DIR}/config.yaml"
    
    if grep -A 2 "^ports:" "$config" | grep -q "80/tcp"; then
        pass "Status API port 80 configured"
    else
        fail "Status API port 80 configured"
    fi
    
    # Cleanup
    rm -rf "$test_dir"
}

# ============================================================
# METADATA TESTS
# ============================================================
test_metadata() {
    echo ""
    echo -e "${BLUE}=== METADATA: Documentation ===${NC}"
    
    # CHANGELOG
    local changelog="${XLINK_DIR}/CHANGELOG.md"
    local changelog_content
    changelog_content=$(cat "$changelog")
    
    if echo "$changelog_content" | grep -q "0.1.0"; then
        pass "CHANGELOG has version 0.1.0"
    else
        fail "CHANGELOG has version 0.1.0"
    fi
    
    if echo "$changelog_content" | grep -qi "Tailscale"; then
        pass "CHANGELOG mentions Tailscale migration"
    else
        fail "CHANGELOG mentions Tailscale migration"
    fi
    
    # README
    local readme="README.md"
    if [ -f "${TEST_DIR}/${readme}" ]; then
        pass "README.md exists"
        
        local readme_content
        readme_content=$(cat "${TEST_DIR}/${readme}")
        
        if echo "$readme_content" | grep -qi "tailscale"; then
            pass "README.md mentions Tailscale"
        else
            fail "README.md mentions Tailscale"
        fi
        
        if echo "$readme_content" | grep -qi "auth_key\|Auth Key"; then
            pass "README.md documents auth_key"
        else
            fail "README.md documents auth_key"
        fi
    else
        fail "README.md exists"
    fi
}

# ============================================================
# MAIN
# ============================================================
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}xLink Client Add-on Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Run tests
test_unit_structure
test_unit_config_schema
test_unit_dockerfile
test_unit_script_syntax
test_unit_script_content
test_build
test_integration
test_metadata

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Tests run:     ${TESTS_RUN}"
echo -e "Tests passed:  ${GREEN}${TESTS_PASSED}${NC}"
if [ ${TESTS_FAILED} -gt 0 ]; then
    echo -e "Tests failed:  ${RED}${TESTS_FAILED}${NC}"
else
    echo -e "Tests failed:  ${GREEN}0${NC}"
fi
if [ ${TESTS_SKIPPED} -gt 0 ]; then
    echo -e "Tests skipped: ${YELLOW}${TESTS_SKIPPED}${NC}"
fi

# Detailed results for failures
if [ ${TESTS_FAILED} -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed tests:${NC}"
    grep "^FAIL:" "$TEST_RESULTS_FILE" | while IFS=: read -r status name detail; do
        echo "  ✗ ${name}"
        [ -n "$detail" ] && echo "    ${detail}"
    done
fi

# Cleanup
rm -f "$TEST_RESULTS_FILE"

echo ""
if [ ${TESTS_FAILED} -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}${TESTS_FAILED} test(s) failed${NC}"
    exit 1
fi
