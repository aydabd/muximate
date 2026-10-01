# muximate

Explicit, fail-closed folder profiles for GitHub, SSH, Git identity, CMUX, Claude Code, Codex,
Copilot CLI, and optional mise tools.
The executable is the source of truth:

```sh
bin/muximate help
bin/muximate setup
bin/muximate doctor /absolute/project
```

This package is shell-neutral: the core commands use POSIX `sh`. The Oh My Zsh adapter in `zsh/`
is optional. The package never copies private keys, GitHub credentials, AWS credentials, GPG keys,
or a user’s existing Git/SSH/Oh My Zsh configuration.

Configuration is stored under `${MUXIMATE_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/muximate}`.
Set `MUXIMATE_ROOT` to place the complete muximate configuration and state tree elsewhere; set
`XDG_CONFIG_HOME` to change the default parent directory. Generated mise files and locks remain
inside that root, so the same layout works across macOS, Linux, Windows Git Bash, and different
architectures.

## Checks

Install mise, then run:

```sh
make lint
```

Mise installs the pinned ShellCheck, Bats, actionlint, Gitleaks, Taplo, Zizmor, and pre-commit
versions from `mise.toml` and `mise.lock`;
no system-wide installation of these tools is required. One pre-commit configuration automatically
removes trailing whitespace, normalizes final newlines, validates YAML/JSON/TOML, checks script
shebangs, lints Markdown with markdownlint, runs ShellCheck on every script, audits workflows with actionlint and Zizmor, scans for
secrets with Gitleaks, and runs the Bats suite. GitHub Actions also runs CodeQL against workflow
source and verifies `Signed-off-by` trailers on every pull request commit. `make lint` runs this
complete configuration, while
`make lint-fix` is the explicit fix-oriented alias. `make check` is read-only for CI and runs the
same validation categories without auto-fixing files.

Shell unit tests use Bats and run through the pinned mise toolchain:

```sh
make test
```

GitHub Actions runs the full Bats end-to-end suite on Linux and macOS runners. Windows runs a
native Git Bash smoke suite because the locked Bats package currently has no Windows artifact.
Each runner first executes `bin/muximate-platform-check` and prints evidence for its operating
system, architecture, shell, core utilities, and tool versions. CI disables mise auto-install and
invokes tools with `mise exec --locked`, so an unavailable platform artifact fails at the explicit
capability check instead of being silently assumed.
Locally, the full suite can be run with `CMUX_BIN=/nonexistent bin/muximate-bats tests`; tools are
supplied by the pinned mise environment. `act` can simulate the Linux workflow locally, while
macOS and Windows coverage requires their respective GitHub-hosted runners.

## Releases

Releases use Conventional Commits and Release Please with two deployment environments:

- `development`: Release Please maintains a release pull request and creates semantic
  `vMAJOR.MINOR.PATCH-dev.N` prereleases after that pull request is merged.
- `production`: run the manual `Promote Release` workflow. Select a development prerelease tag,
  or leave the ref blank to select the newest `vMAJOR.MINOR.PATCH-dev.N` release. The workflow
  publishes a preview summary, requires one production approval before publishing, and promotes
  the exact prerelease commit to
  a final `vMAJOR.MINOR.PATCH` tag and published GitHub release. It also opens a metadata PR to
  synchronize `version.txt` and `.release-please-manifest.json` to the stable version; merge that PR
  through the normal signed-commit branch protections.

The promotion workflow refuses non-`-dev.N` prerelease tags, drafts, missing prereleases, an already
existing production tag, non-`main` runs, and commits not reachable from `main`. Configure both
GitHub environments to allow deployments only from `main`; require at least one reviewer for
`production`, enable “prevent self-review”, and do not store credentials in either environment
unless a future deployment step explicitly requires them.

Verify a downloaded release archive with:

```sh
sha256sum -c SHA256SUMS
gh attestation verify muximate-v1.1.1.tar.gz -R aydabd/muximate
```

The attestation verifies that GitHub Actions built the archive from this repository. The checksum
verifies the downloaded bytes; both checks are required before installation.

## Install

Run the installer explicitly:

```sh
bin/muximate-install
```

It installs the command and generic adapters under the user’s config directory. It does not enable
mise, alter global Git/SSH settings, install packages, or authenticate GitHub.

After installation:

```sh
muximate setup
muximate init personal /absolute/personal-root
muximate profile-configure personal /path/to/gh-config /path/to/private-ssh-key
muximate git-configure personal "Your Name" you@example.com /path/to/signing-key.pub
muximate agent-policy-init personal
muximate ssh-config personal
muximate mise enable /absolute/project       # optional
```

`muximate env` also exports `AWS_CONFIG_FILE` when `aws-config.<profile>` exists under the Muximate
root (like `kubeconfig.<profile>` for `KUBECONFIG`), and `BROWSER` pointing at
`muximate-cmux-browser` so CLI login flows open in the profile's cmux browser. Both are scrubbed
when switching to a profile that has none.

Update mise tools with explicit, separate scopes:

```sh
muximate tool-update --profile [--bump] [folder] [tool...]   # profile tools and the profile mise.lock
muximate tool-update --project [--bump] [folder] [tool...]   # the project's own mise.toml and mise.lock
```

Both scopes upgrade unlocked and then re-write the lockfile, so later `tool-install` runs stay
`--locked`. `--profile` never reads a project `mise.toml`; `--project` ignores the profile config.

Review generated SSH/Git output. Create or import SSH/GPG keys and upload public keys through the
provider’s normal human workflow. Run `gh-login personal` only from a matching initialized folder
and an interactive terminal.

Generated registries, lockfiles, credentials, and personal shell files stay outside this repository.

## AI account isolation

After `eval "$(muximate env /absolute/project)"` (or through the optional zsh adapter), Muximate
sets profile-local homes for Claude Code (`CLAUDE_CONFIG_DIR`), Codex (`CODEX_HOME`), and Copilot
CLI (`COPILOT_HOME`). It also removes inherited Anthropic, OpenAI, and Copilot/GitHub token
variables so a token from another shell cannot silently override the active profile. Codex is
configured to keep each profile's login in its own `auth.json`. Authenticate each profile from a
matching initialized folder; Muximate never copies credentials.

Claude Code OAuth credentials on macOS may be stored in the shared system Keychain by Claude
Code itself. For strict separation of Claude accounts, use separate provider-side login/keychain
entries or an account-specific API-key helper; the profile directory and inherited-token boundary
alone cannot partition a provider-global Keychain.

Run `muximate agent-policy-init personal|work` once for each desired profile to create missing
user-scoped instructions for Claude Code, Codex, and Copilot CLI. The command writes only inside
that profile's provider homes, uses private file permissions, rejects symbolic-link targets, and
never replaces existing guidance. Repository-owned project instructions remain unchanged.

The generated guidance tells agents to send HTTP/HTTPS URLs through
`muximate cmux-browser-open '<URL>'`, and to print the URL and stop if routing fails instead of
falling back to the system browser. Agent instructions are behavioral guidance, not a security
boundary: the profile wrappers, environment isolation, and cmux browser selection remain the
enforced operational path.

Muximate also installs a profile-aware `open` executable. When Muximate's bin directory precedes
the system paths, an initialized folder accepts exactly one HTTP/HTTPS URL and routes it to the
selected cmux browser profile. It refuses other arguments and never falls back to Safari. In an
uninitialized folder, URLs fail closed while non-URL usage delegates to `/usr/bin/open`; use
`/usr/bin/open` explicitly when intentionally opening a local file from a profiled folder. Absolute
`/usr/bin/open` calls and native application APIs cannot be intercepted, so agent guidance remains
necessary.

## Browser profiles and identities

cmux browser profiles are the only cookie jars; Muximate adds deterministic names, scoping,
validation, listing, and explicit cleanup. Each registered folder (or baseline) owns one default
jar, and you can open extra named identities of the same folder, for example a regular and an
administrative account at one identity provider:

```sh
muximate cmux-browser-open 'https://example.com'                    # the folder's default jar
muximate cmux-browser-open --identity admin 'https://example.com'   # <default jar>--admin
```

A slug must match `[a-z0-9][a-z0-9-]{0,31}`. A missing identity jar is created once, only after
its name passes the caller's namespace check. The jar always comes from the folder's registry
row; `CMUX_BROWSER_PROFILE` and other environment variables never select it, and a row whose jar
does not start with its own profile name is refused by every command.

| Pattern | Created by | May be deleted by |
| --- | --- | --- |
| `<profile>-<16hex>` | `init` | `prune` only when orphan; human |
| `<profile>-baseline-<16hex>` | `baseline` | `prune` only when no baseline row references it; human |
| `<profile>-<16hex>--<slug>` | `cmux-browser-open --identity` | `clear` (empty), `prune` only when orphan; human |
| anything else | not muximate | never by muximate |

Inspect and clean up, always scoped to the current folder's profile (`personal` or `work`):

```sh
muximate browser-profiles list [--all]
muximate browser-profiles clear --identity <slug> [--force]   # empty one identity jar, keep it
muximate browser-profiles clear --default [--force]           # empty the folder default jar
muximate browser-profiles prune [--force]                     # dry run unless --force
```

`list` prints `name`, `kind`, `folder-path-or--`, and cmux's `(last used)`/`(default)` marker,
tab-separated and without UUIDs. Kinds are `folder-default`, `identity`, `legacy-baseline` and
`orphan` (unreferenced by any registry or baseline row), `unmanaged` (your own names under the
profile prefix, never touched), and, with `--all`, read-only `not-yours` rows. `clear` and
`prune` print what they would do and change nothing without `--force`; `clear` exits non-zero
then. `prune` deletes only `orphan` and `legacy-baseline` jars of the current profile and never
the jar cmux marks `(last used)` or `(default)`. Nothing runs `profiles clear --all`. Run `prune`
once from a `personal` folder and once from a `work` folder, reviewing the dry run first.
`muximate doctor` reports `cmux_folder_profile` and `orphan_profiles`.

Agent contract (also written into generated guidance): use only
`muximate cmux-browser-open [--identity <slug>] '<URL>'` and `muximate browser-profiles list`;
never call `cmux`, `open`, or a browser directly; name a slug after the identity, not the task;
if a login page shows an account you did not intend, stop and use a fresh slug instead of logging
out; never run `clear` or `prune` unless the human asked; on failure print the URL and stop.
Existing guidance files are never rewritten: to refresh one, move or delete the generated file
and re-run `muximate agent-policy-init <profile>` (a hint is printed when an old file lacks the
`## Browser` section).

## cmux workspace integration

Muximate can generate a project-local cmux command configuration while leaving workspace layout and
agent orchestration to cmux:

```sh
mkdir -p /absolute/project/.cmux
muximate cmux-config /absolute/project > /absolute/project/.cmux/cmux.json
```

The generated command sets the selected profile's GitHub and AI homes, starts both Claude Teams
and Codex Teams through Muximate's profile guard, and provides a browser action that opens cmux's
profile-specific browser session. It contains paths and profile names only; credentials remain in
Muximate's account directories and GitHub configuration. Use the generated command/workspace for
that project rather than launching raw `claude`, `codex`, or browser commands, which can bypass
the guard.

cmux owns the workspace, panes, and agent orchestration; Muximate owns the profile boundary. This
keeps the two responsibilities separate while allowing personal and work projects to use different
GitHub, AI, SSH, Git, and browser accounts.
