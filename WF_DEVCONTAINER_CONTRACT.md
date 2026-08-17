# The `wf` devcontainer contract for a consumer repo

Research findings for [blooop/blooop-feedstock#29](https://github.com/blooop/blooop-feedstock/issues/29),
under map [#28](https://github.com/blooop/blooop-feedstock/issues/28).

**What this is for.** `blooop-feedstock` wants `wf` to launch a Claude session inside its own
devcontainer. This file records what the repo must declare to make that happen, and the sharp
edges of the `dl` → devpod path, as citable fact rather than recollection.

**The standard of evidence.** Every claim below is either a citation to a specific upstream
file with the relevant lines quoted, or a command run on this machine with its real output
recorded. Where something could not be verified it is marked **UNVERIFIED** and says why.
Nothing here rests on plausibility.

---

## 0. What was measured against, and a warning about stale checkouts

Versions on this machine, as reported by the tools themselves:

```
$ dl --version
dl 0.0.26
$ devpod version
v0.26.1
$ docker --version
Docker version 29.5.2, build 79eb04c
$ devcontainer --version
0.83.0
$ wf --version
wf 0.17.2
```

**Two local checkouts are stale and must not be read as the installed behavior.** This
mattered — the first pass of this research read the wrong trees:

| checkout | its version | installed version | verdict |
|---|---|---|---|
| `/home/ags/projects/devlaunch` | `0.0.23` (`pyproject.toml:3`) | `dl 0.0.26` | **stale, 3 releases behind** |
| `/home/ags/projects/wayfinder` | `0.14.0` (`Cargo.toml:3`) | `wf 0.17.2` | **stale, 3 minors behind** |

So the sources actually read for this document were:

- **`dl` 0.0.26** — the installed package, at
  `/home/ags/.pixi/envs/wf/lib/python3.14/site-packages/devlaunch/`.
- **`wf` 0.17.2** — `blooop/wayfinder` cloned at tag `v0.17.2` (commit `ddda682`).
- **devpod v0.26.1** — see the next point.

### devpod here is the `skevetter` fork, not loft-sh

This is easy to get wrong and it invalidates any attempt to check devpod behavior against
loft-sh's tree. `loft-sh/devpod` **has no `v0.26.1` tag at all** (`git clone --branch v0.26.1`
against it fails with `Remote branch v0.26.1 not found in upstream origin`).

The installed binary is built from `github.com/skevetter/devpod`:

```
$ strings -a /home/ags/.pixi/envs/wf/bin/devpod | grep -oE "github\.com/(loft-sh|skevetter)/devpod[a-z/-]*" | sort -u | head -3
github.com/skevetter/devpod
github.com/skevetter/devpod/cmd
github.com/skevetter/devpod/cmd/agent
```

and this repo's own recipe says so outright — `recipes/devpod/recipe.yaml:9-10`:

```yaml
  # NOTE: Using skevetter's fork of devpod from https://github.com/skevetter/devpod/releases
  # instead of the official devpod (https://github.com/loft-sh/devpod)
```

All devpod source citations below are to **`skevetter/devpod` at tag `v0.26.1`, commit
`86b6f9f`** ("fix(devcontainer): keep compose metadata label valid JSON (#771)").

---

## 1. The launch precondition: a *default* config, or you run on the host

`wf` decides isolation by the mere existence of a config in one of the two spec **default**
locations. `wayfinder:src/launch.rs:1043-1052`:

```rust
/// The devcontainer configs `wf` looks for — the two locations the
/// devcontainer spec puts a *default* config in.
///
/// A variant-only layout (`.devcontainer/<name>/devcontainer.json` with no
/// default) is deliberately absent: picking among variants would be `wf`
/// choosing a container shape, and `wf` has no basis to choose. Those repos
/// run on the host until someone decides how the variant is named.
const DEVCONTAINER_CONFIGS: [&str; 2] = [".devcontainer/devcontainer.json", ".devcontainer.json"];

/// The container front door, found on PATH like every other tool `wf` uses.
const DEVLAUNCH: &str = "dl";
```

The test is existence only — `wayfinder:src/launch.rs:1103-1107`:

```rust
fn has_devcontainer(checkout: &Path) -> bool {
    DEVCONTAINER_CONFIGS
        .iter()
        .any(|rel| checkout.join(rel).is_file())
}
```

Stated in prose too, `wayfinder:README.md:949-953`:

> A repo whose only configs are **variants**
> (`.devcontainer/<name>/devcontainer.json`, no default) runs on the host:
> choosing among variants would be `wf` picking a container shape, and it has no
> basis to pick. Host access, GPU passthrough and the rest are the repo's
> declarations to make — `wf` injects no `runArgs`.

**Consequences for this repo, and they are the load-bearing ones:**

1. A **default** `.devcontainer/devcontainer.json` is the entire opt-in. Nothing else turns
   isolation on, and there is no `wf` flag or config to set.
2. `wf` **never reads or parses** the file — it only stats it. So the config cannot be wrong
   in a way `wf` will complain about; it can only be wrong in a way *devpod* fails on later.
3. A **variants-only** layout silently runs on the host. Not an error, no warning — so if this
   repo ever moves its config under `.devcontainer/<name>/`, isolation just stops happening.
   That is a real drift risk worth a check.
4. **Isolation degrades to the host rather than refusing**, by design. `src/launch.rs:1057-1061`:
   *"an unusable `dl` **degrades to the host** rather than refusing the launch: a repo may carry
   a `devcontainer.json` for its editor users on a machine that has never heard of `dl`, and
   isolation here is for dependencies, not security (#73)"*. So "it ran on the host" is the
   failure mode to expect, not a crash.

Also: **Claude only.** Codex always runs on the host, so this whole contract is Claude-specific
(`README.md:839-843`, quoted in §2).

---

## 2. RESOLVED: the `~/.claude` mount is the **repo's** declaration, not `dl`'s injection

This is the contradiction the ticket asked to settle. Both statements the ticket quotes are
real, and the README's is loose shorthand.

**The claim.** `wayfinder:README.md:839-840`:

> Codex deliberately stays on the host even for such a checkout. `dl` mounts
> `~/.claude` but not `~/.codex`, ...

**The counter-evidence in the same repo.** `wayfinder:.devcontainer/devcontainer.json:90-92`
declares the mount itself:

```json
  "mounts": [
    "source=${localEnv:HOME}/.claude,target=/home/vscode/.claude,type=bind"
  ],
```

### The resolution, from `dl`'s actual source

**`dl` injects no bind mounts whatsoever.** The whole `devpod up` argv is assembled in exactly
one place, `devlaunch/dl.py:2961-2981` (installed 0.0.26):

```python
    args = ["up", workspace]
    if workspace_id:
        args.extend(["--id", workspace_id])
    args.extend(["--ide", ide if ide else "none"])
    if devcontainer:
        args.extend(["--devcontainer-path", devcontainer])
    identity = workspace_identity or workspace_id
    if identity:
        args.extend(["--init-env", f"DEVLAUNCH_WORKSPACE_ID={identity}"])
    if recreate:
        args.append("--recreate")
    if reset:
        args.append("--reset")
    ctx = get_context_options()
    if ctx.get("DOTFILES_URL"):
        args.extend(["--dotfiles", ctx["DOTFILES_URL"]])
    if ctx.get("DOTFILES_SCRIPT"):
        args.extend(["--dotfiles-script", ctx["DOTFILES_SCRIPT"]])
```

There is no mount flag on that list, and none is added later — the only other contributor is
`gh_auth.up_args()`, which yields `--workspace-env-file` (§4). Corroborated by grep over the
installed package returning nothing for any mount-injection spelling:

```
$ cd /home/ags/.pixi/envs/wf/lib/python3.14/site-packages/devlaunch
$ grep -rn -E '"--mount"|--mount|MOUNT|bind_mount|CLAUDE_CONFIG_DIR|\.claude' --include=*.py . | grep -v "^tools.py"
(no output)
```

**What `dl` actually supplies is two things the README compresses into one phrase**, and the
distinction is the whole answer:

- the **`claude` and `gh` binaries** — *executables*, lent from the host into the container;
- **`GH_TOKEN`** — an *environment variable*.

Neither is the `~/.claude` **credential directory**. `devlaunch/tools.py:1-13` says so directly:

> `gh` and `claude` are not optional extras for the way these workspaces get used:
> `dl` already forwards the host's GitHub login into every container, which is
> worth nothing when the container has no `gh` to spend it, and `aid` exists to
> run `claude` in there. **Both currently arrive only when the repo's own
> devcontainer.json arranges them** -- this repo does, through
> `.devcontainer/claude-code/`, which is why `claude` is present in its workspaces
> and `gh` (a project pixi dependency, reachable only as `pixi run gh`) is not.
>
> **A guarantee that depends on the repo is not a guarantee.**

And `tools.py:15-25` describes the lending mechanism — a tar stream over the ssh channel, not a
mount:

> Where the tools come from is a cost question, and the answer is **the host
> first, the network second**. [...] So a container that lacks them is lent
> the host's own copies through a tar stream over the ssh channel dl already
> holds, which turns the slowest part of a cold launch (minutes of in-container
> downloads) into a local copy.

**Verdict, for a consumer repo: you must declare the `~/.claude` mount yourself.** You do not
get it for free. wayfinder works because wayfinder's own `devcontainer.json` declares it.
The README sentence is true only as "`dl` brings up a container whose own `devcontainer.json`
mounts `~/.claude`", and the very same README section concedes the general rule
(`README.md:847-848`): *"the repo's own config is the entire opt-in"*.

### Three things that travel with that mount

Copying only the `mounts` line is not enough. wayfinder's config pairs it with two more
settings, and its inline comment (`.devcontainer/devcontainer.json:31-45`) explains why:

1. **`containerEnv.CLAUDE_CONFIG_DIR`** (`devcontainer.json:27-29`):
   ```json
     "containerEnv": {
       "CLAUDE_CONFIG_DIR": "/home/vscode/.claude"
     },
   ```
   Because *"`~/.claude.json` carries onboarding and per-project trust and lives \*outside\*
   `~/.claude`, so without that variable a container re-onboards every time."*

2. **Read-write, not read-only.** *"Read-write because a token refresh has to persist; the
   ~7 h access-token life makes any read-only or copied arrangement drift into a re-auth."*

3. **`initializeCommand`** (`devcontainer.json:98`):
   ```json
     "initializeCommand": "mkdir -p \"$HOME/.claude\"",
   ```
   Runs on the **host** before create. *"Bind-mounting a path that does not exist yet makes
   docker create it as a root-owned directory, which then fails confusingly inside the
   container."*

Note the mount **target is the container user's home** (`/home/vscode`), which is coupled to
`"remoteUser": "vscode"` (`devcontainer.json:111`). A repo whose image uses a different
username must change both together — the illegal state here is a target path that does not
match `remoteUser`.

---

## 3. What `wf` hands to `dl` — and the version floor

`wf` execs one thing. `wayfinder:src/launch.rs:1143-1154`:

```rust
pub fn isolated_argv(workspace: &str, agent: &[String]) -> Vec<String> {
    vec![
        DEVLAUNCH.to_string(),
        workspace.to_string(),
        "--".to_string(),
        agent
            .iter()
            .map(|arg| shell_quote(arg))
            .collect::<Vec<_>>()
            .join(" "),
    ]
}
```

Which in practice is (`wayfinder:README.md:834`):

```
dl owner/repo@wayfinder/repo-80 -- 'claude' '--dangerously-skip-permissions' '/wf 67 80 ctx: {"v":1,…}'
```

**No `--devcontainer` flag is ever passed**, so the default config is the only one `wf` can
reach — reinforcing §1. And `wf` injects nothing else; `README.md:845-848`:

> `wf` owns which ticket, which checkout, which skill and which prompt. `dl` owns
> the container [...] `wf` builds no flags, reads no
> `devcontainer.json` and writes none: **the repo's own config is the entire
> opt-in**, and there is nothing to configure on the `wf` side.

**The `dl` 0.0.24 floor is real and enforced in code** in 0.17.2 (it was prose-only in 0.14.0,
which is the sort of thing the stale checkout would have got wrong).
`wayfinder:src/launch.rs:1109-1127`:

```rust
/// The oldest `dl` whose command line this binary actually speaks.
///
/// Raised whenever `wf` starts calling something an older `dl` does not have,
/// and that is not hypothetical: [`prewarm`] fires `dl <workspace> up`, and
/// `up` arrived in devlaunch **0.0.24**.
[...]
pub const DEVLAUNCH_FLOOR: DlVersion = DlVersion(0, 0, 24);
```

Installed `dl 0.0.26` clears it.

---

## 4. Binaries on PATH inside the container, and how `GH_TOKEN` arrives

### `claude` — required for the exec to be anything at all

The command run inside the container is literally `claude --dangerously-skip-permissions
<prompt>`, so a `claude` on the container's PATH is the launch. `dl` will supply it if the
image does not (§2, `tools.py`), so this is the one binary a repo can reasonably omit — but
"reasonably" comes with the caveats in §6.

### `gh` — required for the wayfinder skills to reach the tracker

Every wayfinder skill drives the tracker through `gh`. Heaviest user is
`wayfinder:skills/wf/GITHUB_TRACKER.md`; `skills/wf-tdd/SKILL.md:22` needs
`gh issue edit <n> --repo "$REPO" --add-assignee @me`; `skills/wf/LIFECYCLE.md:25,27` need
`gh pr checks <pr> --watch` and `gh api ...`. Without `gh` inside the container the skills
cannot move a ticket, so `gh` is not optional for this repo's purpose.

### `GH_TOKEN` across devpod's three transports

`dl` forwards the host token — from `GH_TOKEN`, `GITHUB_TOKEN`, or `gh auth token`, whichever
answers first (`gh_auth.py:34-42`). Its module docstring (`gh_auth.py:1-17`) explains why an
env var and not a mount, which doubles as the reason a consumer repo should **not** try to
bind-mount `~/.config/gh`:

> devpod forwards the ssh agent and a git credential helper, but nothing carries
> `gh` authentication, so `gh` starts out logged out in every container [...]
> A devcontainer.json can bind-mount ~/.config/gh, but that only helps the projects that
> opted in, the mount target has to name the container user's home directory, and it hands
> over nothing at all when the host keeps its token in a keyring instead of hosts.yml.
>
> A token in the environment needs no cooperation from the image, the
> devcontainer.json, or the container user [...]

Three transports, one per launch path:

| path | mechanism | source |
|---|---|---|
| `devpod up` (cold / recreate) | `--workspace-env-file <private file>` | `gh_auth.py:157-180` `up_args()` |
| `devpod ssh` (attach, already running) | `--send-env GH_TOKEN`, value from devpod's own env | `gh_auth.py:183-200` `ssh_args_and_env()` |
| OpenSSH (the interactive path `wf` uses) | `-o SendEnv=GH_TOKEN`, value in env | `gh_auth.py:203-214` `openssh_env_names_and_env()` |

The token never sits in argv on any of them — `up_args` uses a file because *"`devpod up` can
run for minutes while an image builds, and its argv is readable by every user on the host for
that whole time"* (`gh_auth.py:161-163`).

**Two sharp edges a consumer repo must plan around:**

1. **A `postCreateCommand` cannot rely on `GH_TOKEN`.** Only the `up` transport puts the token
   in the *workspace env*; the two ssh transports are **per-session**. wayfinder's config states
   this plainly (`.devcontainer/devcontainer.json`, mounts comment): *"the last two are
   per-session, so a postCreateCommand cannot see the token at all on the path that matters"*.
   So: do not put `gh`-authenticated work in `postCreateCommand`.
2. **A running container's token does not refresh.** `gh_auth.py:191-195`: *"it cannot refresh
   one either: a running workspace whose token has been revoked since it started needs
   `dl <ws> restart` to pick up the new one."*

Opt-out is `DEVLAUNCH_NO_GH_TOKEN=1` (`gh_auth.py:42`).

---

## 5. The devpod constraints, re-confirmed here rather than inherited

Both were re-measured against the installed devpod v0.26.1 (skevetter fork) on this machine, as
the ticket required. **Both hold**, with refinements the map should absorb.

### 5a. `build.cacheFrom` is parsed and silently ignored — CONFIRMED

**From source.** devpod does parse it —
`skevetter/devpod:pkg/devcontainer/config/config.go:288`:

```go
	CacheFrom types.StrArray `json:"cacheFrom,omitempty"`
```

and exposes it — `config.go:267-272`:

```go
func (d DockerfileContainer) GetCacheFrom() types.StrArray {
	if d.Build != nil {
		return d.Build.CacheFrom
	}
	return nil
}
```

**But `GetCacheFrom` has zero callers:**

```
$ grep -rn --include=*.go "GetCacheFrom" .
pkg/devcontainer/config/config.go:267:func (d DockerfileContainer) GetCacheFrom() types.StrArray {
```

Only the definition. The **sole** thing that ever populates `buildOptions.CacheFrom` is
devpod's own registry-cache option — `pkg/devcontainer/build/options.go:143-159`:

```go
	// define cache args
	if params.Options.RegistryCache != "" {
		buildOptions.CacheFrom = []string{
			fmt.Sprintf("type=registry,ref=%s", params.Options.RegistryCache),
		}
		[...]
	} else {
		buildOptions.BuildArgs["BUILDKIT_INLINE_CACHE"] = "1"
	}
```

`--cache-from` *does* reach docker (`pkg/driver/docker/build.go:158-166 appendCacheOptions`) —
just never with a value from the repo's config.

**Empirically, on this machine.** A probe devcontainer declaring
`"cacheFrom": "ghcr.io/blooop/does-not-exist:probe"`, run under `devpod up --debug`:

```
debug prepared build options: &{BuildArgs:map[BUILDKIT_INLINE_CACHE:1] ... CacheFrom:[] CacheTo:[] ...}
info  build with docker buildx build
debug running docker buildx build with args: buildx build -f .../Dockerfile --load \
      -t probe-big-be16b:devpod-8e5e38e8... --build-arg BUILDKIT_INLINE_CACHE=1 .../probe-big
```

`CacheFrom:[]` — **empty**, despite the config declaring it — and no `--cache-from` in the real
buildx argv. Instead the `else` branch's `BUILDKIT_INLINE_CACHE=1`. Independently reproduced in
the docker-in-docker probe (§5c), which also shows `CacheFrom:[]`.

**Design consequence.** A repo **cannot** ask for build cache through `devcontainer.json`. The
only lever is devpod's `REGISTRY_CACHE` **context** option
(`pkg/config/context.go:24 ContextOptionRegistryCache = "REGISTRY_CACHE"`), which is
per-machine devpod configuration, not something this repo can carry in-tree. So any "cache the
image build" plan for this map must be either a **prebuilt published image** or a devpod context
setting — writing `cacheFrom` into the config would be a no-op that reads as if it worked,
which is exactly the sort of thing to design out rather than comment.

### 5b. The ~5000-file ceiling is real and fatal — CONFIRMED, but it counts the *build context*

**From source.** `skevetter/devpod:pkg/util/hash/hash.go:17`:

```go
const maxFilesToRead = 5000
```

The hash function itself is *forgiving* — it returns a partial hash plus a warning
(`hash.go:21-24`, `hash.go:119-126`). **Its only caller is not.**
`pkg/devcontainer/config/prebuild.go:53-57`:

```go
	contextHash, err := util.DirectoryHash(params.ContextPath, excludes, includes)
	if err != nil {
		params.Log.Debugf("failed to compute context hash for %s: %v", params.ContextPath, err)
		return "", fmt.Errorf("failed to compute context hash: %w", err)
	}
```

The partial hash is discarded and the build fails. (`DirectoryHash` has exactly this one
non-test caller.)

**Empirically, on this machine.** A probe with 5202 files in the context, `"context": ".."`:

```
$ devpod up ./probe-big --id wfprobebig --ide none --debug
debug devcontainer up: build image: failed to compute context hash: directory hash incomplete:
      exceeded limit of 5000 files (partial hash computed from first 5000 files): read files over limit
fatal run agent command failed: exit status 1: Process exited with status 1
EXIT=1
```

Fatal, exit 1 — matching the source exactly, and matching the error string wayfinder's own
config comment quotes.

**Refinement 1 — it counts the build context, which defaults to `.devcontainer/`, not the repo.**
`pkg/devcontainer/config/config.go:387-410 GetContextPath` resolves relative to the
devcontainer.json's own directory and falls back to that directory:

```go
func GetContextPath(parsedConfig *DevContainerConfig) string {
	configDir := path.Dir(filepath.ToSlash(parsedConfig.Origin))
	[...]
	if context := parsedConfig.GetContext(); context != "" {
		return resolvePath(context)
	}
	if dockerfilePath := parsedConfig.GetDockerfile(); dockerfilePath != "" {
		[...]
		return resolvePath(path.Dir(dockerfilePath))
	}
	return configDir
}
```

So the ceiling only bites if the config widens the context to the repo root with
`"context": ".."`. This is precisely the trade wayfinder recorded and chose against —
`wayfinder:.devcontainer/devcontainer.json:7-16`:

> `context` is this directory, NOT the repo root. The Dockerfile copies nothing
> out of the context — it only downloads pinned binaries — so a repo-root
> context would buy nothing and costs a great deal: devpod hashes the build
> context and gives up past 5000 files, and `target/` alone is far beyond that
> ("failed to compute context hash: exceeded limit of 5000 files"). If a future
> change needs Cargo.toml/Cargo.lock in the image (e.g. baking compiled deps),
> widen this to ".." and add a .dockerignore excluding target/ in the same
> commit.

**Refinement 2 — `.dockerignore` is a real, verified mitigation.** `prebuild.go:41-46` feeds
`.dockerignore` patterns in as excludes. Adding `filler/` to `.dockerignore` in the failing
probe above made the same `devpod up` compute the hash successfully:

```
debug prebuild hash calculated: architecture=amd64, contextHash=h1:YF13jrXIUtHViZpRHAPXlmwkO684+ga19oB7pRMUTR0=,
      finalHash=devpod-8e5e38e8ee5db3d042e6341aea6f674b, excludeCount=2, includeCount=0
```

So the pair "`context: ..` + a `.dockerignore` excluding the heavy dirs" works. It is strictly
more fragile than keeping the context at `.devcontainer/`, because the ignore file and the
directory list must stay in sync — prefer the narrow context unless the image genuinely needs
repo files.

**Refinement 3 — it is a build-path limit only.** The hash is computed in `buildImage`, which a
pure `image:` devcontainer with no features never reaches: `pkg/devcontainer/build.go:85-94`
returns early when `extendedBuildInfo.FeaturesBuildInfo == nil`. An `image:` config **with**
features does go through it (`extendImage` → `buildImage`), but its context is then
`.devcontainer/` and trivially small — as observed in the §5c probe
(`Context:.../probe-dind/.devcontainer`).

**Re-measured file counts on this machine** (`find <path> -type f | wc -l`) — this **corrects
the map**:

| path | files |
|---|---|
| main checkout, total | 9423 |
| `.pixi/` | 6074 |
| `output/` | 3087 |
| `.git/` | 177 |
| `recipes/` | 58 |
| clean worktree, total | 84 |

Map #28's Notes say `.pixi/` and `output/` "exceed on their own". **Only `.pixi/` does** (6074 >
5000); `output/` alone is 3087, under the ceiling. Together they are 9161. The conclusion the
map draws is still right — a repo-root context here would fail today — but the reason is
`.pixi/` specifically, and a `.dockerignore` listing only `output/` would **not** be enough.

### 5c. docker-in-docker: devpod passes through everything it needs — CONFIRMED

This is the hinge for [#30](https://github.com/blooop/blooop-feedstock/issues/30), so it is
stated plainly: **yes on privileged, and no cgroup flag is needed.**

**From source**, devpod's docker driver passes the whole relevant set —
`pkg/driver/docker/docker.go:490-515`:

```go
	b.addPorts().
		addWorkspaceMount(helper).
		addUser().
		addEnv().
		addInit().
		addPrivileged()
	[...]
	b.addCapabilities()
	if err := b.addMounts(); err != nil { ... }
	b.addIDEMount().
		addLabels().
		addGPU().
		addRunArgs().
		addDetached().
		addEntrypoint().
		addImage()
```

with `addPrivilegedArgs` emitting the flag (`docker.go:660-665`) and `addCapabilityArgs`
emitting `--cap-add` / `--security-opt` (`docker.go:667-675`). Those are fed from the merged
config (`pkg/devcontainer/single.go:440,497`: `Privileged: mergedConfig.Privileged`,
`Init: mergedConfig.Init`, `CapAdd`, `SecurityOpt`), and crucially the merge includes
**feature** metadata — `pkg/devcontainer/metadata/metadata.go:62-68`:

```go
		NonComposeBase: config.NonComposeBase{
			Mounts:      feature.Mounts,
			Init:        feature.Init,
			Privileged:  feature.Privileged,
			CapAdd:      feature.CapAdd,
			SecurityOpt: feature.SecurityOpt,
		},
```

So a *feature* can demand privileged, not just the repo's own config.

**Empirically, on this machine.** Probe: an `image:` devcontainer with
`"features": {"ghcr.io/devcontainers/features/docker-in-docker:2": {}}`. devpod's own debug line
shows the real argv:

```
info running docker command: command=docker, args=run --sig-proxy=false \
  --mount type=bind,src=.../probe-dind,dst=/workspaces/wfprobedind -u root \
  -e DEVPOD=true -e REMOTE_CONTAINERS=true ... \
  --privileged --mount type=volume,src=dind-var-lib-docker-default-wf-38f7c,dst=/var/lib/docker ...
```

Both of the feature's demands — `--privileged` and the `/var/lib/docker` volume — are present.
`devpod up` exited 0.

And it actually works. On a fresh `devpod up --recreate`, with **no** manual intervention:

```
$ devpod ssh wfprobedind --command 'ps aux | grep -c "[d]ockerd"; docker info --format "server={{.ServerVersion}}"'
1
server=29.7.2-1

$ docker run --rm alpine:3.20 echo "DIND_WORKS"
DIND_WORKS
```

A real nested container ran. So the feature's `entrypoint`
(`/usr/local/share/docker-init.sh`) is honored too — the `--entrypoint /bin/sh -c echo
Container started` visible in the create argv is only devpod's create-time probe and does not
displace it on the running container.

**cgroups: nothing is passed, and nothing needs to be.**

```
$ grep -rn --include=*.go -iE "cgroup" .
(no output)
```

devpod never emits `--cgroupns` or any cgroup flag. It does not need to: this host is cgroup v2
(`docker info` → `29.5.2 cgroup=systemd/2`), where `--privileged` suffices for the feature's own
`docker-init.sh` to set up its nested hierarchy — demonstrated by the probe working.

---

## 6. The minimal contract, assembled

What `blooop-feedstock` must declare, with why:

| # | Declaration | Why | Source |
|---|---|---|---|
| 1 | **A default `.devcontainer/devcontainer.json`** | The entire opt-in; variants-only runs on the host | §1 |
| 2 | `mounts`: `${localEnv:HOME}/.claude` → container home, **rw** | `dl` injects no mounts; token refresh must persist | §2 |
| 3 | `containerEnv.CLAUDE_CONFIG_DIR` = that target | `~/.claude.json` lives outside `~/.claude`; else re-onboards | §2 |
| 4 | `initializeCommand`: `mkdir -p "$HOME/.claude"` | Else docker creates it root-owned on the host | §2 |
| 5 | `remoteUser` matching the mount target's home | The two are coupled | §2 |
| 6 | `gh` on PATH in the image | Every wayfinder skill drives the tracker through it | §4 |
| 7 | `claude` on PATH — or rely on `dl` lending it | The exec itself | §4, §6 caveat |
| 8 | Keep `build.context` at `.devcontainer/`, or add `.dockerignore` excluding `.pixi/` **and** `output/` | The 5000-file ceiling; `.pixi/` alone is 6074 | §5b |

And what it must **not** do:

- **Do not** write `build.cacheFrom` — silently ignored (§5a).
- **Do not** bind-mount `~/.config/gh` — the host keeps its token in a keyring, so the mount
  carries nothing; `GH_TOKEN` is the mechanism (§4).
- **Do not** put `gh`-authenticated work in `postCreateCommand` — the token is per-session on
  the transport `wf` uses (§4).
- **Do not** copy `"runArgs": ["--network=host"]` — wayfinder deliberately omits it so
  concurrent branch test-runs do not collide on ports
  (`wayfinder:.devcontainer/devcontainer.json:22-26`). This repo runs Docker tests, so port
  collisions between concurrent tickets are a live concern.

### A caveat on relying on `dl` to lend `claude`

`tools.py`'s own header argues *against* depending on it: *"A guarantee that depends on the repo
is not a guarantee"* (`tools.py:11`). Two documented gaps (`tools.py:44-54`): a workspace
**already running** when `dl` reaches it takes the fast-attach path and *"is not topped up"*;
and provisioning is best-effort — *"an install that fails is logged and the session starts
anyway"*. So a repo that bakes `claude` into its image is strictly more reliable than one that
relies on lending. This is a real decision for a later ticket, not settled here.

---

## 7. Corrections this research makes to map #28

Recorded because the map's Notes are what later tickets will read:

1. **Two of the four cited reference files do not exist.** Map #28 Notes lists
   `blooop/wayfinder:.devcontainer/local/devcontainer.json` and
   `blooop/wayfinder:tests/devcontainer_prebuild.rs`. Neither is present at `v0.17.2`:
   ```
   $ ls .devcontainer/
   devcontainer.json  Dockerfile
   $ ls tests/
   common  live_devlaunch.rs  live_discovery.rs  live_fetch.rs
   live_launch_exec.rs  live_streaming_startup.rs  skill_docs.rs
   $ find . -name "*prebuild*" -not -path "./.git/*"
   (no output)
   ```
   There is **one** devcontainer config in wayfinder, not two, so there is no "build-from-source
   variant" and **no two-config drift test to imitate**. Map #28's Principle-3 note ("wayfinder's
   answer was a test holding both files to one set of values") describes something that does not
   exist. The nearest real analogue is `tests/live_devlaunch.rs`, which holds `wf`'s
   `DEVLAUNCH_FLOOR` constant against the pixi `floor` environment's pinned `devlaunch` version
   (`src/launch.rs:1122-1127`) — a *contract* test between a constant and a pin, which is a
   better model for this repo anyway: **if there is only one config, there is no drift to test
   for.** Prefer one config over two-plus-a-test.
2. **`output/` alone does not exceed the ceiling** (3087 < 5000); `.pixi/` does (6074). See §5b.
3. **devpod here is the `skevetter` fork.** Any future re-measurement must use it; loft-sh has
   no `v0.26.1`. See §0.
4. **The `dl` 0.0.24 floor is enforced in code** at `wf` 0.17.2, not merely documented.

---

## 8. What could not be verified

Stated explicitly rather than glossed:

- **UNVERIFIED: a real `dl` bringup of `blooop-feedstock` itself.** No config exists on this
  branch yet, so there was nothing to bring up. The probes used purpose-built minimal
  devcontainers. Map #28 requires a real bringup; that belongs to the build tickets.
- **UNVERIFIED: that `pixi`, `rattler-build`, and `tests/test-install.sh` work inside a
  container.** The dind probe used `mcr.microsoft.com/devcontainers/base:bookworm` and proved
  only that nested docker runs. Whether this repo's actual workloads succeed is #30's to prove.
- **UNVERIFIED: cold-start time / `WF_PREWARM` viability** on this repo — no image to time.
- **UNVERIFIED: behavior under `dl` versions other than 0.0.26**, devpod other than the
  skevetter v0.26.1 fork, or a cgroup v1 host. The dind result specifically depends on cgroup v2
  (`cgroup=systemd/2` here) plus `--privileged`; a cgroup v1 host was not tested.
- **UNVERIFIED: that `GH_TOKEN` actually arrives over each of the three transports.** The
  transports are cited from `dl`'s source, and wayfinder records having probed the `SendEnv` path
  on 2026-08-08 (`.devcontainer/devcontainer.json`: *"Probed on 2026-08-08 against a running
  devpod workspace with fake values [...] they arrive"*), but I did not re-run that probe. `dl`'s
  own tests are noted there as asserting only that the flag is *built*, never that the variable
  *arrives*.
- The probe workspaces (`wfprobebig`, `wfprobebig2`, `wfprobedind`) and the
  `dind-var-lib-docker-default-wf-38f7c` volume were deleted after measuring; `devpod list`
  shows only pre-existing unrelated workspaces.
