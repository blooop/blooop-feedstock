# Claude Code Agent Instructions

This is a conda feedstock repository for the `blooop` channel hosted on prefix.dev.

## You Are a Pixi & Conda Packaging Expert

When the user provides a GitHub repository URL, you will:
1. Analyze the repository to determine the package type and build strategy
2. Create a rattler-build recipe.yaml file
3. Build and test the package locally
4. Commit and push the changes to publish to the blooop channel

### Quick Start: Adding a Package

**User provides:** `https://github.com/owner/repo`

**You automatically:**
1. Fetch the repository metadata and latest release information
2. Determine package type (binary release, Python package, compiled source, etc.)
3. Create `recipes/{package-name}/recipe.yaml` with proper configuration
4. Build the package locally using `pixi run` tasks
5. Test the package installation and basic functionality
6. Commit and push to trigger channel publication

## Automated Package Addition Workflow

### Step 1: Analyze the GitHub Repository

When given a repo URL like `https://github.com/owner/repo`, use WebFetch and WebSearch to:

- Check for GitHub Releases (binary artifacts)
- Identify the project type (Python/PyPI, Go binary, Rust crate, npm package, etc.)
- Find the latest version and download URLs
- Extract license information from the repository
- Read the README for package description and homepage
- Determine supported platforms (Linux, macOS, Windows) and architectures (x86_64, aarch64, arm64)

**Detection Rules:**
- **Binary Release Package:** GitHub Releases with platform-specific binaries (e.g., `app-linux-amd64`, `app-darwin-arm64`)
- **Python Package:** `setup.py`, `pyproject.toml`, or available on PyPI
- **Go Binary:** `go.mod` file, often provides cross-platform binaries
- **Rust Binary:** `Cargo.toml` file, check for GitHub Releases
- **npm Package:** `package.json`, available on npmjs.com
- **Generic Source Build:** `Makefile`, `CMakeLists.txt`, or build scripts

### Step 2: Create the Recipe

Create `recipes/{package-name}/recipe.yaml` following the rattler-build schema (2026 spec).

**Binary Release Template:**
```yaml
schema_version: 1

package:
  name: package-name
  version: "X.Y.Z"

source:
  - url: https://github.com/owner/repo/releases/download/vX.Y.Z/binary-linux-amd64  # [linux and x86_64]
    sha256: <hash>  # [linux and x86_64]
  - url: https://github.com/owner/repo/releases/download/vX.Y.Z/binary-linux-arm64  # [linux and aarch64]
    sha256: <hash>  # [linux and aarch64]
  - url: https://github.com/owner/repo/releases/download/vX.Y.Z/binary-darwin-amd64  # [osx and x86_64]
    sha256: <hash>  # [osx and x86_64]
  - url: https://github.com/owner/repo/releases/download/vX.Y.Z/binary-darwin-arm64  # [osx and arm64]
    sha256: <hash>  # [osx and arm64]
  - url: https://github.com/owner/repo/releases/download/vX.Y.Z/binary-windows-amd64.exe  # [win]
    sha256: <hash>  # [win]

build:
  number: 0
  script:
    - if: unix
      then:
        - mkdir -p "$PREFIX/bin"
        - |
          case "${target_platform:-}" in
            linux-64)      SRC_FILE="binary-linux-amd64" ;;
            linux-aarch64) SRC_FILE="binary-linux-arm64" ;;
            osx-64)        SRC_FILE="binary-darwin-amd64" ;;
            osx-arm64)     SRC_FILE="binary-darwin-arm64" ;;
            *) echo "Unsupported target_platform: ${target_platform:-unknown}" && exit 1 ;;
          esac
          install -Dm755 "$SRC_DIR/$SRC_FILE" "$PREFIX/bin/package-name"
    - if: win
      then:
        - if not exist %PREFIX%\Library\bin mkdir %PREFIX%\Library\bin
        - copy %SRC_DIR%\binary-windows-amd64.exe %PREFIX%\Library\bin\package-name.exe

tests:
  - script:
      - if: unix
        then:
          - which package-name
          - test -x $PREFIX/bin/package-name
          - package-name --version || package-name --help
      - if: win
        then:
          - where package-name
          - package-name --version

about:
  homepage: https://github.com/owner/repo
  license: LICENSE-TYPE
  license_family: LICENSE_FAMILY
  summary: Brief one-line description
  description: |
    Detailed multi-line description of the package.
    Include key features and use cases.
  documentation: https://docs.example.com
  repository: https://github.com/owner/repo

extra:
  recipe-maintainers:
    - blooop
```

**Note on asset naming:** The `binary-*-*` filenames above are placeholders. Real projects use varied naming conventions:
- **Go projects:** `projectname_Linux_x86_64.tar.gz`, `projectname_Darwin_arm64.tar.gz`
- **Rust projects:** `projectname-v1.0.0-x86_64-unknown-linux-gnu.tar.gz`, `projectname-v1.0.0-aarch64-apple-darwin.tar.gz`
- **Generic:** `projectname-linux-amd64`, `projectname-darwin-arm64.exe`

Adapt the `source` URLs and the `case` statement in the build script to match the actual asset names from the GitHub release.

**Python Package Template:**
```yaml
schema_version: 1

package:
  name: package-name
  version: "X.Y.Z"

source:
  - url: https://pypi.io/packages/source/p/package-name/package-name-X.Y.Z.tar.gz
    sha256: <hash>

build:
  number: 0
  script: pip install . -v --no-deps --no-build-isolation

requirements:
  host:
    - python >=3.8
    - pip
    - setuptools  # or hatchling, poetry-core, etc.
  run:
    - python >=3.8
    # Add runtime dependencies here

tests:
  - python:
      imports:
        - package_name
  - script:
      - package-name --help  # if provides CLI

about:
  homepage: https://github.com/owner/repo
  license: LICENSE-TYPE
  license_family: LICENSE_FAMILY
  summary: Brief description
  description: |
    Detailed description
  repository: https://github.com/owner/repo

extra:
  recipe-maintainers:
    - blooop
```

### Step 3: Calculate SHA256 Hashes

For each download URL, calculate the SHA256 hash:

```bash
curl -L <url> | sha256sum
```

Or use Python:
```python
import hashlib
import urllib.request

url = "https://github.com/..."
with urllib.request.urlopen(url) as response:
    sha256_hash = hashlib.sha256(response.read()).hexdigest()
    print(sha256_hash)
```

### Step 4: Build the Package Locally

```bash
# Syntax validation first
pixi run lint-recipes

# Build for all platforms (or specific platform)
rattler-build build --recipe recipes/package-name/recipe.yaml --output-dir output

# Build for specific platform
rattler-build build --recipe recipes/package-name/recipe.yaml --target-platform linux-64 --output-dir output
```

### Step 5: Test the Package

```bash
# Run recipe tests
rattler-build test --recipe recipes/package-name/recipe.yaml

# Or manually install and test
pixi run test-package-name  # if custom test task exists
```

### Step 5b: Verify Installation in Docker Container

After building the package, verify it installs correctly in a clean Docker environment. This catches issues that local testing might miss (missing dependencies, path problems, etc.).

**Quick test with locally built package:**
```bash
# Build the package first
rattler-build build --recipe recipes/package-name/recipe.yaml --output-dir output

# Test installation in fresh container using local output channel
docker run --rm \
  -v $(pwd)/output:/channel:ro \
  ghcr.io/prefix-dev/pixi:latest \
  bash -c "pixi global install --channel /channel --channel conda-forge package-name && package-name --version"
```

**Interactive debugging in container:**
```bash
docker run --rm -it \
  -v $(pwd)/output:/channel:ro \
  ghcr.io/prefix-dev/pixi:latest \
  bash

# Inside container, manually test:
# pixi global install --channel /channel --channel conda-forge package-name
# which package-name
# package-name --help
```

### Step 6: Commit and Push

```bash
git add recipes/package-name/
git commit -m "Add package-name X.Y.Z

- Added recipe for package-name
- Supports platforms: linux-64, osx-64, osx-arm64, linux-aarch64, win-64
- Source: https://github.com/owner/repo"

git push -u origin claude/add-package-name
```

**Branch naming:** Use a descriptive branch name like `claude/add-{package-name}` or `feature/{package-name}`. The example above uses a simple pattern; adjust to match the repository's branching conventions.

### Step 7: Publishing to prefix.dev

Once pushed, packages in the `output/` directory can be uploaded to the blooop channel:

```bash
# Upload to prefix.dev (requires authentication)
rattler-build upload prefix -c blooop output/*.conda
```

## Package Type Detection Guide

### Binary Releases (Most Common)
**Indicators:**
- GitHub Releases with downloadable binaries
- Naming patterns: `*-linux-amd64`, `*-darwin-arm64`, `*-windows-*.exe`
- Often from Go, Rust, or C/C++ projects

**Strategy:** Direct binary installation (see the devpod recipe example)

### Python Packages
**Indicators:**
- `setup.py`, `pyproject.toml`, `setup.cfg`
- Available on PyPI
- Python source code

**Strategy:** Use pip install in build script, specify dependencies in requirements

### Shim Scripts
**Indicators:**
- Upstream binary frequently updates
- Need auto-update functionality
- Docker caching support desired

**Strategy:** Create installer shim like claude-shim (see recipes/claude-shim/)

### Source Builds
**Indicators:**
- `Makefile`, `CMakeLists.txt`, `configure` script
- Requires compilation
- No pre-built binaries available

**Strategy:** Build from source with proper compiler dependencies

## 2026 Best Practices

### Recipe Structure (rattler-build format)

- **Always use `schema_version: 1`** at the top of recipe.yaml
- **Selectors use `# [condition]` syntax**: `# [linux and x86_64]`, `# [osx]`, `# [win]`
- **Conditional build scripts**: Use `if/then` blocks for platform-specific steps
- **Security**: Never include secrets in recipes (they're bundled in the package)
- **License families**: Use standard SPDX identifiers and families (MIT, APACHE, BSD, etc.)

### Platform Support Priority

1. **linux-64** (x86_64) - Most common
2. **osx-arm64** (Apple Silicon) - Growing adoption
3. **osx-64** (Intel Mac) - Still widely used
4. **linux-aarch64** (ARM64 Linux) - Cloud/edge computing
5. **win-64** - Windows support

Declare in `pixi.toml` platforms array.

### Testing Strategy

1. **Syntax check**: `bash -n script.sh` for shell scripts
2. **Build test**: Verify binary/module is accessible
3. **Version check**: Run `--version` or `--help` to confirm functionality
4. **Import test**: For Python packages, verify imports work
5. **Docker test**: Use Docker for real-world installation validation:
   - **Local package test**: Mount `output/` directory as a local channel
   - **Published package test**: Run `pixi run test-docker` after publishing
   - **Interactive debugging**: Run container with shell access to troubleshoot

**Docker Testing Examples:**

```bash
# Test local .conda package before publishing
docker run --rm \
  -v $(pwd)/output:/channel:ro \
  ghcr.io/prefix-dev/pixi:latest \
  bash -c "pixi global install --channel /channel --channel conda-forge package-name && package-name --version"

# Test from live channel after publishing
docker run --rm \
  ghcr.io/prefix-dev/pixi:latest \
  bash -c "apt-get update -qq && apt-get install -y -qq curl ca-certificates >/dev/null 2>&1 && \
           pixi global install --channel https://prefix.dev/blooop package-name && \
           which package-name && \
           package-name --version"

# Run full test suite (tests all packages in channel)
pixi run test-docker
```

### Rattler-Build (2026)

Rattler-build is the modern, fast conda package builder written in Rust.

**Key features:**
- Uses `recipe.yaml` format (YAML-based, not Jinja2)
- Significantly faster than conda-build
- Better error messages and validation
- Built on the rattler library (same as pixi)
- Native support for cross-platform builds

**Differences from conda-build:**
- No Jinja2 templating (use YAML conditionals instead)
- Selectors use `# [condition]` not `{{ selector }}`
- More structured build script sections with `if/then` blocks

## Key Files

- `recipes/{package-name}/recipe.yaml` - Package recipe files (rattler-build format)
- `recipes/claude-shim/claude-shim.sh` - Main shim script example (uses `latest` channel)
- `recipes/claude-code/claude-shim.sh` - Alternative shim example (uses `stable` channel)
- `pixi.toml` - Workspace configuration and build tasks
- `output/` - Built package artifacts (*.conda files)
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

### Adding Docker Tests for New Packages

When adding a new package, extend the Docker test suite to include it:

```bash
# Add to tests/test-install.sh:

# Test: Install package-name
log_info "Checking if package-name is available..."
if curl -sf "${CHANNEL}/linux-64/repodata.json" 2>/dev/null | grep -q '"package-name-'; then
    log_info "Installing package-name package..."
    ((TESTS_RUN++))
    if pixi global install --channel "$CHANNEL" package-name 2>&1; then
        log_pass "package-name installation"
        run_test "package-name binary exists" "which package-name"
        run_test "package-name version check" "package-name --version"
    else
        log_fail "package-name installation"
    fi
else
    log_info "Skipping package-name test (package not in channel)"
fi
```

## Publishing and CI Verification Workflow

**Critical principle:** Maximize local testing BEFORE publishing to the channel. Once published, packages are immediately available to users.

### Pre-Publish Checklist (All Local)

Before pushing to trigger publication, ensure ALL of these pass:

1. Recipe syntax validates: `pixi run lint-recipes`
2. Package builds successfully: `rattler-build build --recipe recipes/package-name/recipe.yaml --output-dir output`
3. Recipe tests pass: `rattler-build test --recipe recipes/package-name/recipe.yaml`
4. Binary/module works locally: `package-name --version`
5. **Docker installation test passes** (clean environment verification):
   ```bash
   docker run --rm \
     -v $(pwd)/output:/channel:ro \
     ghcr.io/prefix-dev/pixi:latest \
     bash -c "pixi global install --channel /channel --channel conda-forge package-name && package-name --version"
   ```

### Post-Publish Verification via GitHub Actions

After pushing and the package is published to prefix.dev:

1. **Monitor the GitHub Actions workflow** for the release/publish job to complete successfully
2. **Verify the package appears in channel repodata:**
   ```bash
   curl -sf "https://prefix.dev/blooop/linux-64/repodata.json" | grep '"package-name-'
   ```
3. **Run the full Docker test suite** to verify all packages still install correctly:
   ```bash
   pixi run test-docker
   ```
4. **Test installation from the live channel:**
   ```bash
   docker run --rm \
     ghcr.io/prefix-dev/pixi:latest \
     bash -c "apt-get update -qq && apt-get install -y -qq curl ca-certificates >/dev/null 2>&1 && \
              pixi global install --channel https://prefix.dev/blooop package-name && \
              package-name --version"
   ```

### Why This Order Matters

| Stage | What It Catches | Recovery Cost |
|-------|-----------------|---------------|
| Local build | Recipe errors, missing files | Low - just edit |
| Local test | Binary issues, wrong paths | Low - rebuild |
| Docker local | Missing deps, env assumptions | Medium - may need recipe changes |
| **PUBLISH HAPPENS HERE** | | |
| GitHub Actions | CI-specific issues | High - users may be affected |
| Docker from channel | Channel/publication issues | High - need new release |

**Always prefer catching issues in the "Low cost" stages before publishing.**

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

## Expert Knowledge Base

### Conda Ecosystem 2026

**Key Tools:**
- **pixi** - Modern package manager and project manager built on the conda ecosystem
- **rattler** - Rust library powering pixi and rattler-build
- **rattler-build** - Fast conda package builder (replaces conda-build)
- **prefix.dev** - Fast package index and private channel hosting

**Package Formats:**
- `.conda` - Modern compressed conda package format (preferred)
- `.tar.bz2` - Legacy conda package format

### Common GitHub Release Patterns

**Go Projects:**
```
projectname_Linux_x86_64.tar.gz
projectname_Darwin_arm64.tar.gz
projectname_Windows_x86_64.zip
```

**Rust Projects:**
```
projectname-v1.0.0-x86_64-unknown-linux-gnu.tar.gz
projectname-v1.0.0-x86_64-apple-darwin.tar.gz
projectname-v1.0.0-aarch64-apple-darwin.tar.gz
```

**Generic Binary Releases:**
```
projectname-linux-amd64
projectname-linux-arm64
projectname-darwin-amd64
projectname-darwin-arm64
projectname-windows-amd64.exe
```

### License Families Reference

| License | Family |
|---------|--------|
| MIT | MIT |
| Apache-2.0 | APACHE |
| GPL-3.0, GPL-2.0 | GPL |
| BSD-3-Clause, BSD-2-Clause | BSD |
| MPL-2.0 | MOZILLA |
| ISC | ISC |
| LGPL-3.0 | LGPL |
| Proprietary | Proprietary |

### Platform Architecture Mapping

| Conda Platform | OS | Arch | Common Names |
|----------------|-----|------|--------------|
| linux-64 | Linux | x86_64 | amd64, x86_64 |
| linux-aarch64 | Linux | ARM64 | arm64, aarch64 |
| osx-64 | macOS | x86_64 | darwin-amd64, intel |
| osx-arm64 | macOS | ARM64 | darwin-arm64, apple silicon |
| win-64 | Windows | x86_64 | windows-amd64, win64 |

### Debugging Build Failures

**Common Issues:**

1. **SHA256 mismatch**: Download URL changed or file corrupted
   - Re-download and recalculate hash
   - Check if release was updated

2. **Missing binary for platform**: Not all platforms supported
   - Remove unsupported platforms from recipe
   - Update `pixi.toml` platforms list

3. **Binary not executable**: Permissions not set
   - Use `install -Dm755` instead of `cp`
   - Ensure `chmod +x` in build script

4. **Wrong binary selected**: Platform detection failed
   - Check `target_platform` variable usage
   - Verify case statement covers all platforms

5. **Import error (Python)**: Missing dependencies
   - Add to `requirements.run` section
   - Check PyPI package metadata for deps

6. **Version command fails**: Binary requires dependencies
   - Add runtime requirements (e.g., `libstdc++`, `glibc`)
   - Or make version test optional (see devpod recipe)

### Quick Reference: Common Tasks

```bash
# Create new recipe directory
mkdir -p recipes/package-name

# Validate recipe syntax
pixi run lint-recipes

# Build package (auto-detects platform)
rattler-build build --recipe recipes/package-name/recipe.yaml --output-dir output

# Build for specific platform
rattler-build build --recipe recipes/package-name/recipe.yaml \
  --target-platform linux-64 --output-dir output

# Test recipe
rattler-build test --recipe recipes/package-name/recipe.yaml

# Clean build outputs
pixi run clean

# Run Docker integration tests
pixi run test-docker

# Calculate SHA256 for URL
curl -L <url> | sha256sum
```

### Package Naming Conventions

- Use **lowercase** for package names
- Use **hyphens** for separators (not underscores)
- Keep names **short** and **descriptive**
- Match **upstream project name** when possible
- Examples: `claude-shim`, `devpod`, `my-tool`

### Version Management

- Use **semantic versioning**: `MAJOR.MINOR.PATCH`
- For recipes: update both `package.version` and source URLs
- Build number: starts at 0, increment for recipe-only changes
- Version in quotes: `version: "1.0.0"` (YAML requires quotes for numeric-looking versions)

## Repository Structure

```
blooop-feedstock/
├── recipes/
│   ├── package-1/
│   │   ├── recipe.yaml
│   │   └── additional-files...
│   ├── package-2/
│   │   └── recipe.yaml
│   └── claude-shim/
│       ├── recipe.yaml
│       ├── claude-shim.sh
│       ├── cld.sh
│       └── cldr.sh
├── output/
│   └── *.conda (built packages)
├── tests/
│   ├── Dockerfile
│   └── test-install.sh
├── scripts/
│   ├── check-updates.sh
│   └── run-docker-tests.sh
├── pixi.toml
├── pixi.lock
└── CLAUDE.md
```

## Additional Resources (2026)

### Official Documentation
- **Pixi Documentation**: https://pixi.sh/latest/
- **Rattler-build Configuration**: http://rattler.build/dev/config/
- **Conda-forge Feedstocks**: https://conda-forge.org/docs/maintainer/understanding_conda_forge/feedstocks/
- **Conda-build Recipes**: https://docs.conda.io/projects/conda-build/en/stable/concepts/recipe.html
- **Meta.yaml Definition**: https://docs.conda.io/projects/conda-build/en/latest/resources/define-metadata.html
- **Prefix.dev**: https://prefix.dev/

### GitHub Repositories
- **Pixi**: https://github.com/prefix-dev/pixi
- **Rattler**: https://github.com/conda/rattler
- **Rattler-build**: https://github.com/prefix-dev/rattler-build
- **Conda-build**: https://github.com/conda/conda-build

### Best Practices
- Never include secrets in recipe files (they're bundled in packages)
- Test cross-platform builds before publishing
- Use self-healing patterns for cached binaries (see claude-shim)
- Document package behavior in `about.description`
- Add proper license information (required by most channels)

### Example Workflow: Adding `ripgrep`

**User provides:** `https://github.com/BurntSushi/ripgrep`

**Agent workflow:**
1. WebFetch the repository to check releases
2. Find latest release: v14.1.0
3. Identify as binary release (Rust project with pre-built binaries)
4. Extract download URLs for all platforms:
   - `ripgrep-14.1.0-x86_64-unknown-linux-musl.tar.gz`
   - `ripgrep-14.1.0-aarch64-unknown-linux-gnu.tar.gz`
   - `ripgrep-14.1.0-x86_64-apple-darwin.tar.gz`
   - `ripgrep-14.1.0-aarch64-apple-darwin.tar.gz`
   - `ripgrep-14.1.0-x86_64-pc-windows-msvc.zip`
5. Calculate SHA256 for each URL
6. Create `recipes/ripgrep/recipe.yaml` with binary installation
7. Build: `rattler-build build --recipe recipes/ripgrep/recipe.yaml --output-dir output`
8. Test locally: Verify `rg --version` works
9. **Test in Docker** (clean environment verification):
   ```bash
   docker run --rm -v $(pwd)/output:/channel:ro ghcr.io/prefix-dev/pixi:latest \
     bash -c "pixi global install --channel /channel --channel conda-forge ripgrep && rg --version"
   ```
10. Commit: "Add ripgrep 14.1.0"
11. Push to trigger publication
12. **Monitor GitHub Actions** for successful build/publish
13. **Run full Docker test suite** after package appears in channel:
    ```bash
    pixi run test-docker
    ```
14. **Add test to test-install.sh** for ongoing CI verification

## Tips for Success

1. **Always read the repository README** - Contains critical information about the project
2. **Check existing feedstocks** - Look at conda-forge for similar packages
3. **Start simple** - Get basic installation working before adding features
4. **Test thoroughly** - Use Docker tests to catch installation issues
5. **Document decisions** - Add comments in recipe explaining non-obvious choices
6. **Version carefully** - Ensure version strings match upstream exactly
7. **Handle errors gracefully** - Make tests robust (see devpod non-native binary handling)
8. **Always update README.md** - Add new packages to the "Available Packages" section with upstream project links

### README.md Package Entry Format

When adding a new package, add an entry to the "Available Packages" section in `README.md` following this format:

```markdown
- **package-name** - Brief description (from [owner/repo](https://github.com/owner/repo))
```

Example entries:
```markdown
- **claude-shim** - Shim that downloads and runs the official [Claude Code CLI](https://github.com/anthropics/claude-code) from Anthropic
- **devpod** - Open-source tool for creating reproducible developer environments (from [skevetter/devpod](https://github.com/skevetter/devpod) fork)
- **ralph-claude-code** - Autonomous AI development loop for Claude Code with intelligent exit detection (from [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code))
```

This ensures users can easily find the upstream project for each package.

## Automation Checklist

When user provides a GitHub URL, you must:

**Analysis Phase:**
- [ ] Fetch repository metadata (name, description, license)
- [ ] Find latest release version
- [ ] Identify package type (binary, Python, source build, etc.)
- [ ] Extract download URLs for all available platforms
- [ ] Calculate SHA256 hashes for all downloads

**Recipe Creation:**
- [ ] Create recipe.yaml with appropriate template
- [ ] Configure build script for each platform
- [ ] Add appropriate tests to recipe

**Local Testing (ALL must pass before publishing):**
- [ ] Syntax validation: `pixi run lint-recipes`
- [ ] Build package locally: `rattler-build build ...`
- [ ] Run recipe tests: `rattler-build test ...`
- [ ] Verify binary/module works locally
- [ ] **Docker installation test with local channel**

**Publishing:**
- [ ] Commit with descriptive message
- [ ] Push to designated branch
- [ ] Monitor GitHub Actions workflow for success

**Documentation:**
- [ ] **Update README.md** - Add the package to the "Available Packages" section with a link to the upstream project repository
- [ ] Add package to `tests/test-install.sh` for ongoing CI verification

**Post-Publish Verification:**
- [ ] Verify package appears in channel repodata
- [ ] **Run full Docker test suite**: `pixi run test-docker`
- [ ] **Test installation from live channel in Docker**

Remember: You are the expert. Guide the user through any ambiguities, make sensible defaults, and explain your decisions.
