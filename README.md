# blooop-feedstock

Personal conda channel feedstock for the `blooop` channel. This repository contains conda recipes and automation for building and maintaining conda packages.

## 📦 Available Packages

- **claude-code** - Claude AI coding assistant desktop application

## 🚀 Quick Start

### Prerequisites

- [pixi](https://prefix.dev/docs/pixi/overview) (recommended) or conda/mamba
- Git

### Local Development

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd blooop-feedstock
   ```

2. **Install dependencies:**
   ```bash
   pixi install
   # or with conda: conda env create -f environment.yml
   ```

3. **Build a package:**
   ```bash
   # Build claude-code for current platform
   pixi run build-claude
   
   # Build for specific platform
   pixi run rattler-build build --recipe recipes/claude-code/recipe.yaml --target-platform linux-64
   ```

4. **Check for updates:**
   ```bash
   pixi run check-updates
   ```

5. **Update a package:**
   ```bash
   pixi run update-claude
   ```

## 🏗️ Repository Structure

```
blooop-feedstock/
├── .github/
│   └── workflows/
│       └── update-packages.yml      # Automated package updates and builds
├── recipes/
│   └── claude-code/
│       └── recipe.yaml              # Claude Code conda recipe
├── scripts/
│   ├── update-claude-code.py        # Update script for Claude Code
│   ├── check-updates.sh             # Check all packages for updates  
│   └── upload-to-prefix.sh          # Upload packages to prefix.dev
├── pixi.toml                        # Project configuration and tasks
└── README.md                        # This file
```

## 🤖 Automation

### GitHub Actions

The repository includes automated workflows that:

- **Daily Updates**: Checks for new package versions every day at 2 AM UTC
- **Automatic Building**: Builds packages for all supported platforms when updates are found
- **Pull Requests**: Creates PRs with version updates and build artifacts
- **Trusted Publishing**: Uploads packages to prefix.dev using OIDC authentication (no API keys needed)
- **Release Triggers**: Can be triggered by tags, releases, or manual dispatch

### Supported Platforms

- `linux-64` (Linux x86_64)
- `linux-aarch64` (Linux ARM64)  
- `osx-64` (macOS x86_64)
- `osx-arm64` (macOS ARM64/Apple Silicon)
- `win-64` (Windows x86_64)

### Manual Triggers

You can manually trigger package updates:

1. **Via GitHub Actions UI:**
   - Go to Actions → "Release Workflow" 
   - Click "Run workflow"
   - Optionally specify a single package to update

2. **Via Local Scripts:**
   ```bash
   # Check for updates
   pixi run check-updates
   
   # Update specific package
   pixi run update-claude
   
   # Build and test locally
   pixi run build-claude
   ```

## 📋 Available Tasks

Use `pixi run <task>` to execute these tasks:

| Task | Description |
|------|-------------|
| `build-claude` | Build claude-code package |
| `build-all` | Build all packages |
| `update-claude` | Update claude-code recipe to latest version |
| `check-updates` | Check all packages for available updates |
| `test-claude` | Test claude-code package |
| `clean` | Remove build outputs |
| `lint-recipes` | Validate recipe YAML files |

## 🔧 Configuration

### Trusted Publishing

This repository uses **trusted publishing** with OIDC authentication for secure uploads to prefix.dev. No API keys or GitHub environments are required.

### Configuration

The workflow is configured to match your trusted publisher setup:
- Repository: `blooop/blooop-feedstock`
- Workflow: `release-workflow.yml`
- No environment restrictions

### GitHub Repository Setup

The trusted publisher is already configured correctly:

✅ Repository: `blooop/blooop-feedstock`  
✅ Workflow: `release-workflow.yml`  
✅ No environment restrictions  

The workflow is ready to use!

## 📚 Adding New Packages

To add a new package to the feedstock:

1. **Create the recipe directory:**
   ```bash
   mkdir -p recipes/my-package
   ```

2. **Create the recipe file:**
   ```yaml
   # recipes/my-package/recipe.yaml
   schema_version: 1
   
   package:
     name: my-package
     version: "1.0.0"
   
   source:
     url: https://example.com/my-package-1.0.0.tar.gz
     sha256: abc123...
   
   # ... rest of recipe
   ```

3. **Create an update script:**
   ```python
   # scripts/update-my-package.py
   # Copy and modify scripts/update-claude-code.py
   ```

4. **Update the GitHub workflow:**
   Add update checking logic for your package in `.github/workflows/update-packages.yml`

5. **Add pixi tasks:**
   ```toml
   # Add to pixi.toml [tasks] section
   build-my-package = "rattler-build build --recipe recipes/my-package/recipe.yaml --output-dir output"
   update-my-package = "python scripts/update-my-package.py"
   ```

6. **Update the check script:**
   Add your package to `scripts/check-updates.sh`

## 🌐 Installing Packages

### From the conda channel

Once packages are uploaded to prefix.dev:

```bash
# Add the channel
conda config --add channels https://prefix.dev/channels/blooop

# Install packages
conda install claude-code

# Or with pixi
pixi add --channel https://prefix.dev/channels/blooop claude-code
```

### From local builds

```bash
# Install from local build
conda install ./output/linux-64/claude-code-*.conda
```

## 🐛 Troubleshooting

### Build Issues

1. **Missing dependencies:**
   ```bash
   pixi install  # Reinstall dependencies
   ```

2. **Platform not supported:**
   Some packages may not build for all platforms. Check the recipe's platform selectors.

3. **Checksum mismatches:**
   Update the recipe with correct checksums:
   ```bash
   pixi run update-claude  # Updates checksums automatically
   ```

### Upload Issues

1. **Authentication errors:**
   - Verify your `PREFIX_API_KEY` is correct
   - Check that your prefix.dev account has upload permissions

2. **Channel not found:**
   - Ensure the channel exists on prefix.dev
   - Verify the channel name in scripts

### Update Issues

1. **Network timeouts:**
   - Check internet connectivity
   - Upstream services may be temporarily unavailable

2. **Version parsing errors:**
   - Check that upstream version formats haven't changed
   - Update parsing logic in update scripts if needed

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add or update packages following the established patterns
4. Test builds locally
5. Submit a pull request

## 📄 License

This feedstock repository is licensed under the MIT License. Individual packages may have their own licenses - see each recipe for details.

## 🔗 Links

- [prefix.dev Channel](https://prefix.dev/channels/blooop)
- [rattler-build Documentation](https://prefix-dev.github.io/rattler-build/)
- [pixi Documentation](https://prefix.dev/docs/pixi)
- [conda-forge Documentation](https://conda-forge.org/docs/)
