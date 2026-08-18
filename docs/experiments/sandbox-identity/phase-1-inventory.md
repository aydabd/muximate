# Phase 1: inventory and feasibility baseline

Date: 2026-08-18
Host timezone: Europe/Stockholm
Experiment state: inventory only; no sandbox was created and no credential was accessed or copied.

## Executive finding

The host meets Docker Sandboxes' documented macOS requirements. The standalone `sbx` 0.38.0 CLI was
installed after the initial inventory, but its required Docker sign-in was cancelled at the user's
request. No sandbox was created. Docker Desktop is not required by current Docker documentation. The
installed `docker` command is provided by Rancher Desktop and does not include a `docker sandbox`
subcommand; it is not the current entry point for this experiment.

Docker Sandboxes remains the leading Phase 2 candidate because its documented microVM, clone,
credential-proxy, private-Docker-engine, and network-policy boundaries directly address most CLI
security goals. That is a documentation-based hypothesis, not test evidence from this machine.

cmux 0.64.22 exposes the primitives needed for a plausible integration: remote SSH workspaces,
explicit identity selection, `--no-forward-agent`, reconnect/disconnect, workspace environment
inspection, and named browser profiles. Docker Sandbox SSH is documented as generally available in
0.37.0 and later, but it has not been tested with cmux here. Browser isolation is wholly unproven.

Do not merge, revise, supersede, or close PR #31 based on this inventory alone.

## Repository and PR baseline

- Repository checkout: `aydabd/muximate`.
- Worktree at start: clean.
- Checked-out branch: `agent/cmux-profile-config` at `90c7393`.
- Comparison base: `origin/main` at `e14f143`.
- PR #31: open, draft, mergeable, two commits, three changed files, 136 additions, zero deletions.
- Changed files: `README.md`, `bin/muximate`, and `tests/muximate.bats`.
- Review state: the only PR comment is an automated draft-review skip; there is no substantive review.

PR #31 generates `.cmux/cmux.json`, exports profile-specific GitHub and agent homes, launches Claude
and Codex Teams through Muximate commands, and selects a named cmux browser profile. It therefore
implements a wrapper-and-environment boundary. The sandbox experiment is testing whether that
responsibility can move to the selected workspace instead.

No branch, commit, PR metadata, PR comment, or production file was modified during inventory.

## Host inventory

| Item | Observed value |
| --- | --- |
| OS | macOS 26.2, build 25C56 |
| Kernel | Darwin 25.2.0, arm64 |
| Hardware | MacBook Pro, Mac15,7 |
| SoC | Apple M3 Pro |
| CPU | 12 cores: 6 performance and 6 efficiency |
| Memory | 36 GB |
| Docker application | Rancher Desktop present; Docker Desktop absent |
| Docker context | `rancher-desktop` |

The current execution environment could not access Rancher Desktop's Docker socket. This does not
affect `sbx` feasibility because current Docker documentation says `sbx` does not require Docker
Desktop or Docker Engine.

## Installed tool inventory

| Tool | Version or state |
| --- | --- |
| cmux | 0.64.22 (102), commit `ddd4a01bc` |
| Git | 2.50.1 (Apple Git-155) |
| GitHub CLI | 2.97.0 |
| OpenSSH | 10.0p2, LibreSSL 3.3.6 |
| Docker CLI | 29.6.2-rd, build `ede120b` |
| Docker Compose | 5.3.1 |
| Claude Code | 2.1.231 |
| Codex CLI | 0.147.0 |
| Copilot CLI | 1.0.45 |
| `sbx` | 0.38.0, commit `c022b14634c4bea846ca12870d1d5e97d5868b54` |
| nono | not installed |
| Lima (`limactl`) | not installed |
| Tart | not installed |
| Apple `container` | not installed |
| Dev Container CLI | not installed |

The host shell had an SSH agent socket. It did not have `GH_TOKEN`, `GITHUB_TOKEN`, `GH_CONFIG_DIR`,
`CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `COPILOT_HOME`, or `DOCKER_HOST` set during inventory. Stale-host
variable tests must deliberately set disposable invalid values later.

## cmux capability inventory

The installed cmux CLI reports support for:

- `cmux ssh <destination>` with `--identity`, `--forward-agent`, and `--no-forward-agent`;
- remote workspace reconnect and disconnect;
- SSH session listing, attachment, and cleanup;
- workspace creation with a fixed name, working directory, command, and JSON layout;
- masked workspace environment inspection;
- browser surfaces with named or UUID browser profiles;
- browser cookie, local storage, session storage, state, and profile operations.

These are capability observations only. Phase 5 must prove that restored workspaces retain the exact
sandbox target and fail closed on target mismatch. Phase 6 must prove that named browser profiles do
not share cookies or storage; the CLI surface by itself is not an isolation guarantee.

## Docker Sandboxes documentation baseline

The current installation guide requires macOS 14 or later and Apple silicon. It explicitly states
that Docker Desktop and Docker Engine are not required. The documented macOS installation is:

```sh
brew trust docker/tap
brew install docker/tap/sbx
sbx login
```

The latest stable release documented during inventory is 0.38.0, dated 2026-08-06.

Docker documents that no paid license or per-seat fee is required, including for commercial use,
but a free Docker account and sign-in are mandatory. There is no documented anonymous or offline
execution mode. The attempted device login was cancelled, so Phase 2 cannot use Docker Sandboxes
unless the user chooses to create or use a free Docker account.

Relevant documented properties:

- every sandbox uses a separate microVM kernel, filesystem, network, and private Docker Engine;
- host files outside explicit mounts, the host Docker daemon, host localhost, and direct
  sandbox-to-sandbox networking are blocked;
- network policy is deny-by-default, although the default allowlist may contain broad domains and
  must be inspected and reduced;
- direct mode mounts the host working tree read-write and is not a repository safety boundary;
- clone mode gives the agent a private clone and a read-only host-repository mount;
- clone mode still exposes every file under the host repository, including untracked and ignored
  files such as `.env`, for reading;
- supported built-in environments include Claude Code, Codex, Copilot, and an agent-less shell;
- service credentials can remain host-side and be injected by a proxy;
- sandbox-scoped secrets are supported and should be used for Personal/Work testing;
- the current 0.38.0 syntax makes service secrets global by default and uses `--sandbox` for sandbox
  scope; older positional and `--global` forms are deprecated;
- SSH integration for external apps is marked generally available for 0.37.0 or later;
- `sbx setup ssh` installs a `Host *.sbx` ProxyCommand block that disables host identities and the
  host identity agent for the incoming connection;
- SSH client environment variables are ignored, so host credential variables should not cross that
  connection boundary;
- supported-agent shared skills are mounted read-write by default unless `--no-share-skills` is used;
- deletion with `sbx rm` removes the VM's private state, while host workspace files and the shared
  skills store are separate concerns.

Important unresolved SSH distinction: the managed incoming `*.sbx` connection disables the host
identity agent, but Docker's credential documentation says an existing host SSH agent can be
forwarded into sandboxes for outbound Git and signing. Phase 4 must determine the exact creation and
runtime controls needed to prevent one shared host agent from crossing Personal and Work identities.

Primary documentation:

- <https://docs.docker.com/ai/sandboxes/install/>
- <https://docs.docker.com/ai/sandboxes/integrations/>
- <https://docs.docker.com/ai/sandboxes/security/isolation/>
- <https://docs.docker.com/ai/sandboxes/security/credentials/>
- <https://docs.docker.com/ai/sandboxes/security/defaults/>
- <https://docs.docker.com/ai/sandboxes/usage/>
- <https://docs.docker.com/ai/sandboxes/release-notes/>

## Candidate comparison at inventory stage

| Candidate | Identity-boundary fit | Host availability | Main unresolved issue |
| --- | --- | --- | --- |
| Docker Sandboxes | High on documented CLI controls | Not installed; host meets prerequisites | Must prove credentials, SSH, cmux, and browser behavior |
| nono | Defense-in-depth process boundary | Not installed | Runs in the host identity; does not inherently provide a separate HOME, installed system, or browser identity |
| Lima | High when configured as a mount-free VM | Not installed | Requires explicit provisioning, network policy, credentials, lifecycle, and browser design |
| Tart | High for full macOS/Linux VMs | Not installed | Large images and greater lifecycle/resource cost; browser UX still needs integration work |
| Apple Container | Strong per-container VM isolation | Not installed; host OS and hardware qualify | General container primitive, not an identity/credential/cmux product; pre-1.0 |
| Dev Containers | Medium; implementation-dependent | CLI not installed | Often shares a host daemon and mounted repository; not a full identity boundary by default |
| Full macOS VM | Potentially highest, including browser | Not configured | Highest setup, disk, memory, update, and UX cost |

nono documents irrevocable Seatbelt/Landlock filesystem and network restrictions inherited by child
processes. That is valuable containment, but it is a process sandbox running against host paths and
binaries selected at launch. Without separately constructing HOME, PATH, credential stores, and a
browser context, it does not by itself satisfy the proposed workspace identity model.

Lima's default host-home mount is read-only, so a security experiment must use `--mount-none` or
`--plain`; plain mode also disables SSH-agent forwarding. Tart supports full macOS or Linux VMs,
ordinary SSH, and explicit read-only or read-write directory mounts, but published base images are
large. Apple Container runs each Linux container in a lightweight VM and is supported on this host's
macOS 26 and Apple silicon, but it supplies lower-level building blocks rather than the tested agent,
credential-proxy, and policy workflow offered by Docker Sandboxes.

## Phase 2 gate and safe setup shape

Phase 2 is blocked by the required Docker sign-in, not by a known hardware incompatibility. The
installed CLI version, local help, and secret syntax have been captured. Do not create sandboxes
unless the user explicitly chooses to use a free Docker account and completes sign-in.

The first test should use two local, credential-free, clone-mode shell sandboxes created from two
non-sensitive test repositories. Use `--no-share-skills` so the sandboxes do not join the default
cross-sandbox shared-skill trust boundary. Do not enable clipboard image access, host mounts beyond
the required read-only source mount, SSH-agent forwarding, MCP servers, global secrets, or real
provider accounts.

Before credentials, record and compare at minimum:

```sh
id
uname -a
echo "$HOME"
printf '%s\n' "$PATH"
env | sort
command -v gh git ssh claude codex copilot
git config --global --list --show-origin
find "$HOME" -maxdepth 2 -print
ps aux
mount
docker context show
```

Then run explicit negative tests for the other sandbox's marker file, unrelated host files, host
processes, the host Docker socket, direct sandbox-to-sandbox traffic, and unallowlisted network
destinations. Only after those pass should disposable sandbox-scoped credentials be introduced.

## Decisions deferred

- Whether one persistent shell sandbox can safely host all three agent CLIs.
- Whether built-in per-agent sandboxes or a custom shell/template is the correct daily environment.
- Whether outbound SSH agent forwarding can be fully disabled or independently scoped.
- Whether cmux restore can bind a workspace immutably to one `.sbx` hostname.
- Whether cmux named browser profiles prevent cookie and storage mixing across restore and switching.
- Whether clone mode's read-only source exposure is acceptable for repositories containing ignored
  sensitive files.
- Performance and resource overhead.
- Production architecture, migration, removable Muximate code, and PR #31 disposition.
