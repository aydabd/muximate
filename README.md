# muximate

Explicit, fail-closed folder profiles for GitHub, SSH, Git identity, CMUX, and optional mise tools.
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
  `vMAJOR.MINOR.PATCH-development.N` prereleases after that pull request is merged.
- `production`: run the manual `Promote Release` workflow. Select a development prerelease tag,
  or leave the ref blank to select the newest one. The protected production environment then
  promotes the exact prerelease commit to a final `vMAJOR.MINOR.PATCH` tag and published GitHub
  release.

The promotion workflow refuses non-development tags, drafts, missing prereleases, and an already
existing production tag. Configure required reviewers and other protections on the `development`
and `production` GitHub environments before using this process for users.

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
