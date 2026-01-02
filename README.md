# blooop-feedstock

Personal conda channel feedstock for the `blooop` channel. This repository contains conda recipes and automation for building and maintaining conda packages.

## 📦 Available Packages

- **claude-code** - Claude AI coding assistant desktop application
- **devpod** - Open-source tool for creating reproducible developer environments (from [skevetter/devpod](https://github.com/skevetter/devpod) fork)

### 🚀 Quick Install

```bash
# Install packages globally with pixi
pixi global install --channel https://prefix.dev/channels/blooop claude-code
pixi global install --channel https://prefix.dev/channels/blooop devpod
```

**Channel:** https://prefix.dev/channels/blooop

## 🛠️ Development Guide

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

   # Build devpod for current platform
   rattler-build build --recipe recipes/devpod/recipe.yaml

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
│   ├── claude-code/
│   │   └── recipe.yaml              # Claude Code conda recipe
│   └── devpod/
│       └── recipe.yaml              # DevPod conda recipe (from skevetter fork)
├── scripts/
│   ├── update-claude-code.py        # Update script for Claude Code
│   ├── check-updates.sh             # Check all packages for updates
│   └── upload-to-prefix.sh          # Upload packages to prefix.dev
├── pixi.toml                        # Project configuration and tasks
└── README.md                        # This file
```

## 🤖 Automation

Automated workflows handle daily package updates, building for all platforms, and publishing to prefix.dev using OIDC trusted publishing.

**Supported Platforms:** `linux-64`, `linux-aarch64`, `osx-64`, `osx-arm64`, `win-64`

**Manual Triggers:** Run workflow from GitHub Actions UI or use `pixi run check-updates` / `pixi run update-claude` locally.

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

Uses OIDC trusted publishing for secure uploads to prefix.dev (no API keys needed). Configured for `blooop/blooop-feedstock` repository with `release-workflow.yml`.

## 📚 Adding New Packages

1. Create recipe in `recipes/my-package/recipe.yaml`
2. Create update script in `scripts/update-my-package.py` (copy from existing scripts)
3. Add pixi tasks to `pixi.toml`
4. Update `.github/workflows/update-packages.yml` and `scripts/check-updates.sh`

## 🌐 Installing Packages

```bash
# From channel
pixi global install --channel https://prefix.dev/channels/blooop claude-code

# Or add to a project
pixi add --channel https://prefix.dev/channels/blooop claude-code

# From local build
pixi global install ./output/linux-64/claude-code-*.conda
```

## 🐛 Troubleshooting

- **Build issues:** Run `pixi install` to reinstall dependencies, or `pixi run update-claude` to update checksums
- **Upload issues:** Verify trusted publishing is configured correctly on prefix.dev
- **Update issues:** Check network connectivity and upstream version formats

## 🤝 Contributing

Fork the repository, create a feature branch, test locally, and submit a pull request.

## 📄 License

This feedstock repository is licensed under the MIT License. Individual packages may have their own licenses - see each recipe for details.
