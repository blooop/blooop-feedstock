# Changelog

All notable changes to the blooop-feedstock will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-04-12

### Added
- **claude-shim** 0.7.0 - Shim that downloads and runs the official Claude Code CLI
- **devpod** 0.19.4 - Open-source tool for creating reproducible developer environments
- **devpod-prerelease** 0.20.0 - Pre-release version of devpod
- **eaik** 1.2.1 - Toolbox for Efficient Analytical Inverse Kinematics by Subproblem Decomposition
- **envoy** 1.37.0 - Cloud-native high-performance edge/middle/service proxy
- **ethercat-user** 1.6.0 - EtherCAT userspace library
- **forgit** 26.01.0 - Interactive git powered by fzf
- **gripx** 0.0.19 - Grip exchange library
- **iterfzf** 1.9.0.67.0 - Pythonic interface to fzf
- **krill** 0.1.0 - Professional-grade DAG-based process orchestrator for robotics
- **lely-core** 0.1.0 - Lely core CANopen libraries
- **libplaco** 1.0.1 - Placo motion planning library
- **open3d** 0.19.0 - 3D data processing library
- **pkl** 0.31.1 - Configuration as code language from Apple
- **pybullet-planning-eaa** 0.5.1 - PyBullet planning with EAA support
- **ralph-claude-code** 0.10.1 - Autonomous AI development loop for Claude Code
- **ralph-orchestrator** 2.9.2 - Hat-based orchestration framework for AI agents
- **speedtest-go** 1.7.10 - CLI and Go API to test internet speed
- **xatlas** 0.0.11 - Mesh parameterization / atlas generation library
- ROS Jazzy packages: pymoveit2 4.0.0, robot-calibration 0.10.0, robot-calibration-msgs 0.10.0, ros2-joystick-gui 0.0.1, zbar-ros 0.7.0, zbar-ros-interfaces 0.7.0, phantom-touch-control 0.1.0, phantom-touch-description 0.1.0, phantom-touch-msgs 0.1.0, zed-components 5.1.0, zed-wrapper 5.1.0, zed-ros2 5.1.0
- Docker-based testing infrastructure
- Automated release workflow via GitHub Actions
- CLAUDE.md with comprehensive packaging instructions

### Notable History
- **claude-shim** went through several iterations: 0.4.0 (background updates), 0.5.0 (fix first-install hangs), 0.6.0-0.6.2 (official installer, then reverted), 0.7.0 (reverted to 0.5.0 code fixing 0.6.x regression)
- **forgit** plugin required fixes for symlink handling and test commands

[1.0.0]: https://github.com/blooop/blooop-feedstock/releases/tag/v1.0.0
