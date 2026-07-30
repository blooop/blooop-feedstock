# blooop-feedstock

Personal conda channel feedstock for the `blooop` channel. This repository contains conda recipes and automation for building and maintaining conda packages.

## 📦 Available Packages

- **claude-shim** - Shim that downloads and runs the official [Claude Code CLI](https://github.com/anthropics/claude-code) from Anthropic
- **codex-shim** - Bootstrap installer for OpenAI's [Codex CLI](https://github.com/openai/codex) (exposes the `codex` command); installs the latest official Codex on first run so `codex update` and other native features work
- **devpod** - Open-source tool for creating reproducible developer environments (from [skevetter/devpod](https://github.com/skevetter/devpod) fork)
- **eaik** - Toolbox for Efficient Analytical Inverse Kinematics by Subproblem Decomposition (from [OstermD/EAIK](https://github.com/OstermD/EAIK))
- **forgit** - A utility tool powered by fzf for using git interactively (from [wfxr/forgit](https://github.com/wfxr/forgit))
- **isd** - Interactive systemd TUI for managing systemd units with fuzzy search and live previews (from [kainctl/isd](https://github.com/kainctl/isd))
- **kitty-bin** - Fast, feature-rich, GPU-based terminal emulator, repackaged from the official Linux binary (from [kovidgoyal/kitty](https://github.com/kovidgoyal/kitty)) — named `kitty-bin` to avoid colliding with conda-forge's much older source-built `kitty`; still provides the `kitty` and `kitten` commands. Linux only, needs glibc 2.35+ and a graphical session
- **krill** - Professional-grade DAG-based process orchestrator for robotics systems (from [Zero-Robotics/krill](https://github.com/Zero-Robotics/krill))
- **opencode-shim** - Bootstrap installer for [opencode](https://github.com/anomalyco/opencode), the open source AI coding agent (exposes the `opencode` command); installs the latest official opencode on first run so `opencode upgrade` and other native features work
- **pi** - AI agent toolkit — coding agent CLI with 20+ LLM provider support, TUI & web UI libraries (from [badlogic/pi-mono](https://github.com/badlogic/pi-mono))
- **pkl** - A configuration as code language with rich validation and tooling (from [apple/pkl](https://github.com/apple/pkl))
- **speedtest-go** - CLI and Go API to test internet speed using speedtest.net (from [showwin/speedtest-go](https://github.com/showwin/speedtest-go))
- **uhk-agent** - Configuration application for the Ultimate Hacking Keyboard (from [UltimateHackingKeyboard/agent](https://github.com/UltimateHackingKeyboard/agent))
- **zjsh** - A sesh-like zellij launcher for projects, sessions, and zoxide paths (from [saweima12/zjsh](https://github.com/saweima12/zjsh))

### 🚀 Quick Install

```bash
# Install packages globally with pixi
pixi global install --channel https://prefix.dev/blooop claude-shim
pixi global install --channel https://prefix.dev/blooop --channel conda-forge codex-shim
pixi global install --channel https://prefix.dev/blooop devpod
pixi global install --channel https://prefix.dev/blooop --channel conda-forge eaik
pixi global install --channel https://prefix.dev/blooop --channel conda-forge forgit
pixi global install --channel https://prefix.dev/blooop --channel conda-forge isd
pixi global install --channel https://prefix.dev/blooop --channel conda-forge kitty-bin
pixi global install --channel https://prefix.dev/blooop --channel conda-forge krill
pixi global install --channel https://prefix.dev/blooop --channel conda-forge opencode-shim
pixi global install --channel https://prefix.dev/blooop pi
pixi global install --channel https://prefix.dev/blooop pkl
pixi global install --channel https://prefix.dev/blooop speedtest-go
pixi global install --channel https://prefix.dev/blooop uhk-agent
pixi global install --channel https://prefix.dev/blooop zjsh
```

**Channel:** [https://prefix.dev/channels/blooop](https://prefix.dev/channels/blooop)

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
   # Build claude-shim for current platform
   pixi run build-shim

   # Build devpod for current platform
   rattler-build build --recipe recipes/devpod/recipe.yaml

   # Build for specific platform
   pixi run rattler-build build --recipe recipes/claude-shim/recipe.yaml --target-platform linux-64
   ```

4. **Check for updates:**
   ```bash
   pixi run check-updates
   ```

## 🏗️ Repository Structure

```
blooop-feedstock/
├── .github/
│   └── workflows/
│       ├── release-workflow.yml     # Automated package updates and builds
│       └── test-install.yml         # Docker-based installation tests
├── recipes/
│   ├── claude-shim/
│   │   └── recipe.yaml              # Claude shim conda recipe
│   └── devpod/
│       └── recipe.yaml              # DevPod conda recipe (from skevetter fork)
├── scripts/
│   ├── check-updates.sh             # Check all packages for updates
│   ├── upload-to-prefix.sh          # Upload packages to prefix.dev
│   └── run-docker-tests.sh          # Run Docker-based installation tests locally
├── tests/
│   ├── Dockerfile                   # Test container based on pixi-docker
│   └── test-install.sh              # Installation verification test script
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
| `build-shim` | Build claude-shim package |
| `build-pi` | Build pi package |
| `update-pi` | Update pi recipe to latest upstream release |
| `build-all` | Build all packages |
| `check-updates` | Check all packages for available updates |
| `test-shim` | Test claude-shim package |
| `test-docker` | Run Docker-based installation tests |
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
pixi global install --channel https://prefix.dev/blooop claude-shim

# Or add to a project
pixi add --channel https://prefix.dev/blooop claude-shim

# From local build
pixi global install ./output/linux-64/claude-shim-*.conda
```

## 🐛 Troubleshooting

- **Build issues:** Run `pixi install` to reinstall dependencies
- **Upload issues:** Verify trusted publishing is configured correctly on prefix.dev
- **Update issues:** Check network connectivity and upstream version formats

## 🤝 Contributing

Fork the repository, create a feature branch, test locally, and submit a pull request.

## 📄 License

This feedstock repository is licensed under the MIT License. Individual packages may have their own licenses - see each recipe for details.
