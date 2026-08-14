# Security Policy

## Reporting a vulnerability

Please do not open a public issue for a suspected security vulnerability.

Report it privately through GitHub Security Advisories for this repository. Include:

- the affected file, command, or workflow;
- a concise description of the impact;
- reproduction steps that do not contain credentials or personal data; and
- a suggested mitigation, if known.

If private vulnerability reporting is unavailable, contact the repository owner through a
private GitHub channel and do not include tokens, private keys, cookies, or other secrets.

## Scope

Muximate deliberately does not copy or generate private credentials. Reports involving GitHub,
SSH, cloud, browser, CMUX, or mise integrations should explain which profile boundary was
crossed and whether the issue affects an unknown or uninitialized folder.

Please rotate any credential that may have appeared in a report immediately and redact it from
all further communication.

## Threat model

Muximate is a local, user-owned shell tool. The security boundary is the profile selected for a
folder and the configuration root selected by `MUXIMATE_ROOT` or `XDG_CONFIG_HOME`.

| Asset or boundary | Threat | Control and evidence |
| --- | --- | --- |
| Profile registry, generated mise files, locks, and Git identity files | A symlink, path, or control character redirects a write or generated shell configuration | Absolute-path and control-character validation, symlink refusal, restrictive permissions, ShellCheck, Bats regression tests |
| SSH, GitHub, Git, browser, and CMUX profile separation | Credentials or state cross from one explicit profile into another | Explicit profile lookup, fail-closed commands, no credential copying, end-to-end Bats tests |
| Shell entry points and installer | Command injection, unsafe expansion, or an unvalidated new script | Shell syntax checks and ShellCheck run over every file in `bin/`, plus executable/shebang hooks |
| YAML, JSON, TOML, and GitHub Actions | Malformed configuration, workflow injection, excessive permissions, or mutable action references | YAML/JSON parser hooks, Taplo, actionlint, Zizmor, pinned action SHAs, and Dependabot cooldown |
| Repository history and working tree | Accidental secrets committed in source, tests, or generated files | Gitleaks scans the working tree in pre-commit and CI; private-key detection is also enabled |
| Tool downloads and CI runners | A mutable or unverified development tool executes in the repository | Exact versions in `mise.toml`, generated checksummed/provenance-verified `mise.lock`, least-privilege workflow permissions, and non-persistent checkout credentials |

The current package has no container image, dependency manifest, SBOM, or infrastructure-as-code
surface. Trivy is therefore not enabled as a low-signal generic filesystem scan. If any of those
surfaces are added, add a locked Trivy scan for the specific artifact type and include its new
files in the corresponding parser, format, test, and CI checks.
