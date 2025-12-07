# Claude Code Shim Package

This conda/pixi package provides a **shim installer** for Claude Code, Anthropic's AI-powered coding assistant.

## Important Legal Note

⚠️ **This package does NOT redistribute the Claude Code binary.**

To comply with Anthropic's licensing terms, this package contains only a lightweight shim script that:
1. Downloads the official Claude Code installer from Anthropic's servers on first run
2. Installs it within your conda/pixi environment
3. Executes the real binary with your commands

## How It Works

### Installation

Install via pixi or conda:

```bash
pixi add claude-code
# or
conda install -c blooop claude-code
```

### First Run

On first execution, the shim will:

```bash
$ claude-code --version
🔍 Claude Code not found. Downloading official installer...
📥 Downloading from: https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/2.0.61/claude-linux-x64.tar.gz
📦 Installing to: /path/to/your/env/opt/claude-code
✅ Claude Code 2.0.61 installed successfully!

Claude Code 2.0.61
```

### Subsequent Runs

Once installed, the shim detects the existing binary and executes it directly:

```bash
$ claude-code --help
# Runs the real Claude Code binary transparently
```

## Platform Support

The shim automatically detects your platform and downloads the appropriate binary:

- **Linux**: `linux-x64`, `linux-arm64`
- **macOS**: `darwin-x64`, `darwin-arm64`
- **Windows**: `win32-x64`

## Installation Location

The real Claude Code binary is installed to:
```
$CONDA_PREFIX/opt/claude-code/bin/claude
```

This keeps it isolated within your environment and allows multiple environments with different versions.

## Requirements

Runtime dependencies (automatically installed):
- `bash` (Unix only)
- `curl` or `wget` (for downloading)
- `tar` (Unix) or `unzip` (Windows) for extraction

## Updating

To update Claude Code:

1. Update the shim package to a new version:
   ```bash
   pixi update claude-code
   ```

2. Remove the cached binary to force a fresh download:
   ```bash
   rm -rf $CONDA_PREFIX/opt/claude-code
   ```

3. Run `claude-code` again to download the new version

## Troubleshooting

### Download Fails

If the download fails:
- Check your internet connection
- Verify Anthropic's servers are accessible
- Check if the version exists at the download URL

### Binary Not Found After Installation

If installation succeeds but the binary isn't found:
- Check `$CONDA_PREFIX/opt/claude-code/bin/` exists
- Verify the binary is executable: `chmod +x $CONDA_PREFIX/opt/claude-code/bin/claude`

### Permission Issues

If you encounter permission errors:
- Ensure you have write access to `$CONDA_PREFIX`
- Try running in a fresh environment

## License

This shim package is provided as-is. The Claude Code application itself is proprietary software from Anthropic and subject to their terms of service.

## Maintainer

- blooop (https://github.com/blooop)
