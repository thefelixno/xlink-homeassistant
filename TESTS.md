# Test Suite for xLink Client Add-on

This document describes the test suite for the xLink Client Home Assistant add-on (Tailscale version).

## Running Tests

From the repository root:

```bash
bash test_addon.sh
```

The test script is executable and provides colored output with a detailed summary.

## Test Coverage

The test suite includes **63 tests** organized into **7 categories**:

### 1. Add-on Structure Tests (12 tests)
Validates the file structure of the add-on:
- ✅ All required files exist (config.yaml, Dockerfile, build.yaml, CHANGELOG.md)
- ✅ All service files present (tailscale, forward, status)
- ✅ Init script present (tailscale-init.sh)
- ✅ Old WireGuard files removed

### 2. Configuration Schema Tests (11 tests)
Validates the configuration file schema:
- ✅ All required config keys exist (auth_key, login_server, hostname, accept_dns)
- ✅ All optional config keys exist (advertise_routes, advertise_exit_node, advertise_tags, forward)
- ✅ Version is 0.1.0
- ✅ Supports both aarch64 and amd64 architectures

### 3. Dockerfile Tests (8 tests)
Validates the Dockerfile:
- ✅ Uses hassio-addons/base image
- ✅ Installs tailscale binary
- ✅ Installs socat for port forwarding
- ✅ No wireguard-tools dependency
- ✅ No wireguard-go dependency
- ✅ No go build dependencies
- ✅ Maintainer label present
- ✅ hassio type label present

### 4. Script Syntax Tests (4 tests)
Validates bash syntax for all scripts:
- ✅ tailscale service script syntax valid
- ✅ forward service script syntax valid
- ✅ status service script syntax valid
- ✅ cont-init script syntax valid

### 5. Script Content Tests (14 tests)
Validates key functionality in scripts:
- ✅ tailscale service handles authentication
- ✅ tailscale service supports login_server option
- ✅ tailscale service supports hostname option
- ✅ tailscale service starts tailscaled daemon
- ✅ Forward service uses socat
- ✅ Forward service reads forward config
- ✅ Status service queries tailscale status
- ✅ Status service returns JSON
- ✅ Status service listens on port 80
- ✅ Init script runs tailscale set
- ✅ Init script handles advertise_routes
- ✅ Init script handles advertise_tags
- ✅ Init script handles advertise_exit_node

### 6. Script Execution Flow Tests (5 tests)
Validates logic flow and state management:
- ✅ Handles advertise_routes config
- ✅ Handles auth_key configuration
- ✅ Creates tailscale state directory
- ✅ Starts tailscaled with state file
- ✅ Has connection wait logic

### 7. Integration Tests (4 tests)
Validates executable permissions:
- ✅ tailscale service is executable
- ✅ forward service is executable
- ✅ status service is executable
- ✅ Init script is executable

### 8. Metadata Tests (5 tests)
Validates project metadata:
- ✅ CHANGELOG has version 0.1.0
- ✅ CHANGELOG mentions Tailscale
- ✅ CHANGELOG mentions WireGuard migration
- ✅ Repository config has correct name
- ✅ Repository config has maintainer

## Test Design Principles

1. **No runtime dependencies**: Tests don't require Tailscale or Home Assistant to be installed
2. **Fast execution**: All tests complete in < 2 seconds
3. **Clear output**: Color-coded pass/fail indicators with detailed error messages
4. **Comprehensive**: Tests cover file structure, configuration, scripts, and metadata
5. **Deterministic**: Tests produce consistent results across runs

## Continuous Integration

A GitHub Actions workflow is provided in `.github/workflows/test.yml` that:
- Runs on push to `xlink_client/` directory
- Runs on pull requests affecting test files
- Executes the test suite
- Validates Dockerfile build (if Docker is available)
- Validates YAML configuration

## Adding New Tests

To add new tests:

1. Create a new test function in `test_addon.sh`
2. Use the helper functions (`assert_eq`, `assert_true`, `assert_contains`, etc.)
3. Call your test function in the main section at the end of the file
4. Run `bash test_addon.sh` to verify your tests

Example:
```bash
test_new_feature() {
    echo ""
    echo "=== Testing New Feature ==="
    
    local file="${TEST_DIR}/xlink_client/path/to/file"
    assert_file_exists "New feature file exists" "$file"
    assert_contains "New feature content" "$(cat "$file")" "important-string"
}

# Call at end of file
test_new_feature
```

## Troubleshooting

If tests fail:

1. **Missing files**: Check that all add-on files are present in `xlink_client/`
2. **Syntax errors**: Run `bash -n <script>` to check individual scripts
3. **Configuration issues**: Validate YAML with `python3 -c "import yaml; yaml.safe_load(open('config.yaml'))"`
4. **Permission issues**: Run `chmod +x` on service scripts

## Test File Structure

```
xlink-homeassistant/
├── test_addon.sh          # Main test runner
├── test_helpers.sh        # Helper functions
├── xlink_client/          # Add-on files being tested
│   ├── config.yaml
│   ├── Dockerfile
│   ├── build.yaml
│   ├── CHANGELOG.md
│   └── rootfs/
│       ├── etc/
│       │   ├── cont-init.d/
│       │   │   └── tailscale-init.sh
│       │   └── services.d/
│       │       ├── tailscale/
│       │       ├── forward/
│       │       └── status/
└── .github/
    └── workflows/
        └── test.yml       # CI workflow
```

## License

MIT License - Felix Nölte <mail@felixnoelte.de>
