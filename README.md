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
muximate ssh-config personal
muximate mise enable /absolute/project       # optional
```

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
