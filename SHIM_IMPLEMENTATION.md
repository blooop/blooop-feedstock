# Claude Code Shim Implementation

## Overview

The `claude-code` package has been updated to use a **shim-based distribution method** instead of redistributing the binary directly. This approach:

✅ **Complies with licensing** - Does not redistribute Anthropic's proprietary binary
✅ **Provides seamless UX** - Downloads binary automatically on first use
✅ **Supports all platforms** - Linux, macOS, Windows (x64 and ARM64)
✅ **Environment-isolated** - Installs within conda/pixi environment

## How It Works

### Package Contents

The conda package contains:
- A lightweight shim script (`bin/claude-code`) - ~4KB
- Runtime dependencies (bash, curl, tar, unzip)
- Metadata and documentation

### First Run Behavior

When a user runs `claude-code` for the first time:

```bash
$ claude-code --version
🔍 Claude Code not found. Downloading official installer...
📥 Downloading from: https://storage.googleapis.com/.../2.0.61/claude-linux-x64.tar.gz
📦 Installing to: ~/.pixi/envs/default/opt/claude-code
✅ Claude Code 2.0.61 installed successfully!

Claude Code 2.0.61
```

### Subsequent Runs

The shim detects the existing binary and executes it transparently:

```bash
$ claude-code --help
# Runs real Claude Code immediately, no download
```

## File Structure

```
recipes/claude-code/
├── recipe.yaml           # Conda package recipe
├── claude-shim.sh        # Shim installer script
└── README.md             # User documentation
```

## Key Changes from Previous Implementation

### Before (Dummy Package)
```yaml
build:
  script:
    - echo "#!/bin/bash" > $PREFIX/bin/claude-code
    - echo "echo 'Claude Code - Demo'" >> $PREFIX/bin/claude-code
```

### After (Shim Package)
```yaml
source:
  - path: claude-shim.sh

build:
  script:
    - cp $SRC_DIR/claude-shim.sh $PREFIX/bin/claude-code
    - chmod +x $PREFIX/bin/claude-code

requirements:
  run:
    - bash
    - curl
    - tar
    - unzip
```

## Download URLs

The shim downloads from Anthropic's official distribution:

```
Base: https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/

Platforms:
- linux-x64:      {BASE}/{VERSION}/claude-linux-x64.tar.gz
- linux-arm64:    {BASE}/{VERSION}/claude-linux-arm64.tar.gz
- darwin-x64:     {BASE}/{VERSION}/claude-darwin-x64.tar.gz
- darwin-arm64:   {BASE}/{VERSION}/claude-darwin-arm64.tar.gz
- win32-x64:      {BASE}/{VERSION}/claude-win32-x64.zip
```

## Installation Location

The real Claude Code binary is installed to:
```
$CONDA_PREFIX/opt/claude-code/bin/claude
```

This location:
- Is inside the conda/pixi environment (isolated)
- Persists across shell sessions
- Is removed when the environment is deleted
- Supports multiple versions in different environments

## Platform Detection

The shim automatically detects:
- Operating system (Linux, macOS, Windows)
- Architecture (x86_64, ARM64)
- Appropriate archive format (.tar.gz vs .zip)

## Error Handling

The shim handles:
- Missing download tools (curl/wget)
- Network failures
- Unsupported platforms
- Failed extractions
- Missing binaries after installation

## Testing

The package includes tests that verify:
- ✅ Shim script is executable
- ✅ Command is in PATH
- ✅ Dependencies are installed

Tests do NOT execute the shim (would trigger download in CI).

## Updating Claude Code

To update to a new version:

1. The automated workflow detects new versions
2. Updates `recipe.yaml` version field
3. Rebuilds package with new version
4. Publishes to prefix.dev

Users update via:
```bash
pixi update claude-code
```

On next run, the shim will download the new version.

## Advantages

1. **Legal Compliance**: No binary redistribution
2. **Small Package**: ~6KB instead of ~100MB
3. **Always Official**: Downloads directly from Anthropic
4. **Multi-platform**: Single recipe works everywhere
5. **Version Sync**: Package version matches Claude Code version
6. **Transparent**: Users don't notice the shim after first run

## Workflow Compatibility

The existing release workflow (`release-workflow.yml`) works unchanged:
- Detects new Claude Code versions
- Runs update script
- Builds packages for all platforms
- Uploads to prefix.dev channel

The only difference is the package size (~6KB vs ~100MB).

## License Compliance

The package metadata clearly states:
```yaml
about:
  license: LicenseRef-Proprietary
  summary: Claude AI coding assistant installer shim
  description: |
    This package provides a shim that downloads and installs the official
    Claude Code desktop application from Anthropic on first run. This
    package does NOT redistribute the Claude Code binary to comply with
    licensing requirements.
```

## User Documentation

See `recipes/claude-code/README.md` for user-facing documentation including:
- Installation instructions
- First-run behavior
- Troubleshooting
- Update process
- Platform support
