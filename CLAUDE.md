# Claude Code Agent Instructions

This is a conda feedstock repository for the `blooop` channel hosted on prefix.dev.

## Key Files

- `recipes/claude-shim/claude-shim.sh` - Main shim script (uses `latest` channel)
- `recipes/claude-code/claude-shim.sh` - Alternative shim (uses `stable` channel)
- `tests/test-install.sh` - Test script run inside Docker
- `tests/Dockerfile` - Docker image for testing

## Testing Changes Locally

Always test shim script changes using the Docker infrastructure before committing.

### Quick Syntax Check

```bash
bash -n recipes/claude-shim/claude-shim.sh
```

### Run Full Test Suite

Build and run the Docker tests:

```bash
cd tests && docker build -t blooop-test . && docker run --rm blooop-test
```

Or use pixi:

```bash
pixi run test-docker
```

### Test Local Shim Changes Directly

To test modified shim scripts without publishing to the channel, mount them into the container:

```bash
docker run --rm \
  -v $(pwd)/recipes/claude-shim/claude-shim.sh:/test/claude-shim.sh:ro \
  ghcr.io/prefix-dev/pixi:latest \
  bash -c "apt-get update -qq && apt-get install -y -qq curl ca-certificates >/dev/null 2>&1 && bash /test/claude-shim.sh --version"
```

### Test Docker Mount Caching

The shim supports caching downloads in `~/.claude/cache` or `~/.cache/claude-code` for Docker persistence. To test this:

```bash
# Create a cache directory
CACHE_DIR=$(mktemp -d)

# First run - downloads binary
docker run --rm \
  -v $(pwd)/recipes/claude-shim/claude-shim.sh:/test/claude-shim.sh:ro \
  -v "$CACHE_DIR:/root/.cache" \
  ghcr.io/prefix-dev/pixi:latest \
  bash -c "apt-get update -qq && apt-get install -y -qq curl ca-certificates >/dev/null 2>&1 && bash /test/claude-shim.sh --version"

# Second run (new container) - should use cache, much faster
docker run --rm \
  -v $(pwd)/recipes/claude-shim/claude-shim.sh:/test/claude-shim.sh:ro \
  -v "$CACHE_DIR:/root/.cache" \
  ghcr.io/prefix-dev/pixi:latest \
  bash -c "apt-get update -qq && apt-get install -y -qq curl ca-certificates >/dev/null 2>&1 && bash /test/claude-shim.sh --version"

# Verify cache was created
ls -la "$CACHE_DIR/claude-code/"

# Cleanup
sudo rm -rf "$CACHE_DIR"
```

## Shim Cache Directory Priority

The shim selects the installation directory in this order:

1. `~/.claude/cache/claude-code` - if `~/.claude` exists
2. `~/.cache/claude-code` - if `~/.cache` exists
3. `${CONDA_PREFIX}/opt/claude-code` - fallback to conda/pixi environment

This allows Docker users to mount `~/.claude` or `~/.cache` to persist the binary across container runs.

## Building Packages

```bash
pixi run build-shim          # Build claude-shim
pixi run build-all           # Build all packages
```

## Adding Tests

Add new tests to `tests/test-install.sh`. The test framework provides:

- `log_info "message"` - Info output
- `log_pass "test name"` - Mark test passed
- `log_fail "test name"` - Mark test failed
- `run_test "name" "command"` - Run command and log pass/fail

## Troubleshooting

### Bun Help Instead of Claude Code

If running `claude` shows Bun's help output instead of Claude Code:

```
Bun is a fast JavaScript runtime, package manager, bundler, and test runner. (1.3.5+...)
Usage: bun <command> [...flags] [...args]
...
```

This is a known issue where the Claude Code binary (which is bundled with Bun) fails to find its embedded JavaScript code. Common causes:

1. **Corrupted download** - The binary was partially downloaded or corrupted
2. **Permission issues** - The binary can't read its own embedded resources
3. **Wrong platform** - Downloaded binary for wrong architecture (e.g., musl vs glibc)

**Fix:** Delete the cached binary and re-download:

```bash
# Clear the cache
rm -rf ~/.claude/cache/claude-code/
rm -rf ~/.cache/claude-code/

# Re-run claude to trigger fresh download
claude --version
```

### Debug Mode

Run with `DEBUG_SHIM=1` to see diagnostic info:

```bash
DEBUG_SHIM=1 claude --version
```

This shows:
- `HOME` - Verify home directory is correct
- `INSTALL_DIR` - Where the binary is being cached
- `Binary exists: YES/NO` - Whether cache is found

### Multiple Claude Binaries

Check if there are multiple `claude` binaries in PATH:

```bash
type -a claude
which claude
```

Ensure the pixi-installed shim takes precedence.
