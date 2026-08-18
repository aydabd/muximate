# Phase 2: minimal Docker Sandboxes

Date: 2026-08-18
Docker Sandboxes: 0.38.0, commit `c022b14634c4bea846ca12870d1d5e97d5868b54`
Template: `docker/sandbox-templates:shell-docker`
Mode: clone, persistent, no shared skills
Credentials: no GitHub, agent, registry, or custom secret configured
Network: global `deny-all`
Host SSH agent: removed from the daemon and sandbox creation environment

## Result

The minimal CLI isolation hypothesis passed its first credential-free test. The two microVMs had
separate filesystems, processes, Git configuration, private clones, and private Docker Engines. They
could not see each other's source path, the Muximate host checkout, or the host Keychain path. Their
read-only source mounts rejected writes. Removing and recreating the VMs removed their private state.

This is not production evidence yet. GitHub and agent accounts, outbound SSH, cmux SSH attachment,
browser isolation, broader adversarial tests, and representative performance remain untested.

## Safe setup

Two credential-free Git repositories were created under `/tmp/muximate-sandbox-identity` with fake
Git identities and no remotes. The sandboxes were created with:

```sh
env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 \
  sbx create --clone --no-share-skills \
  --name muximate-personal-test shell /path/to/personal-test

env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 \
  sbx create --clone --no-share-skills \
  --name muximate-work-test shell /path/to/work-test
```

The `--no-share-skills` flag works in 0.38.0 even though `sbx create --help` and `sbx run --help` do
not list it. `sbx skills --help` documents the flag. Treat this help mismatch as a usability defect.

The daemon initially inherited the host's `SSH_AUTH_SOCK`, causing `/run/ssh-agent.sock` to appear in
both VMs. `ssh-add -L` returned exit status 1, so no identities were available, but the socket still
violated the experiment's fail-closed rule. Both disposable VMs were removed, the daemon was stopped,
and it was restarted with `SSH_AUTH_SOCK` unset before recreating the VMs. The recreated VMs have no
`SSH_AUTH_SOCK`.

## Isolation results

| Guarantee | Personal-Test | Work-Test | Result |
| --- | --- | --- | --- |
| Correct fixture | `Personal-Test` | `Work-Test` | Pass |
| HOME | `/home/agent` in private VM | `/home/agent` in private VM | Pass; same pathname, different filesystem |
| Other sandbox source path | absent | absent | Pass |
| Muximate host checkout | absent | absent | Pass |
| Host Keychain path | absent | absent | Pass |
| Host source mount | `/run/sandbox/source`, read-only | same | Pass |
| Source write attempt | rejected | rejected | Pass |
| Processes | VM-local process set | VM-local process set | Pass |
| Docker server | private 29.7.1 | private 29.7.1 | Pass |
| Host Docker daemon | not selected or mounted | not selected or mounted | Pass |
| Git identity | `Personal-Test` fixture identity | `Work-Test` fixture identity | Pass |
| Host `GITHUB_TOKEN` | absent | absent | Pass |
| Host `GH_CONFIG_DIR` | absent | absent | Pass |
| Host `SSH_AUTH_SOCK` after recreation | absent | absent | Pass |
| Shared skills | explicitly disabled | explicitly disabled | Pass by configuration; mount absent in probe |
| External HTTPS under deny-all | HTTP 403 from policy proxy | HTTP 403 from policy proxy | Pass |

Process listings contained only VM/container processes such as `tini`, `git-daemon`, the private
`dockerd`, and private `containerd`; no host or peer-sandbox processes appeared. Both VMs used Linux
7.0.12 on arm64.

The local policy display includes non-editable `filesystem:read allow **` and
`filesystem:write allow **` rules. In this test those rules did not grant arbitrary host access: only
the selected source appeared, and it appeared read-only in clone mode. This must still be included in
future mount-escape tests.

## Clone-mode safety and lifecycle

Inside each first-generation VM, the experiment:

- wrote a private HOME marker;
- added and committed `sandbox-only.txt` in the private clone;
- installed an executable `.git/hooks/pre-commit` in the private clone;
- stopped and restarted the VM;
- verified all three items persisted after restart.

Neither host fixture repository gained `sandbox-only.txt` or the hook, and both host working trees
remained clean. The advertised `sandbox-<name>` host Git remotes did not appear in `git remote -v`, so
fetch-back behavior is unresolved and must be tested before relying on it.

The two VMs were then explicitly removed. The private markers, commits, and hooks disappeared after
recreation, confirming private-state cleanup. The discarded test commits were intentionally not
recoverable.

## Environment and credential behavior

The host invocation deliberately set these disposable stale values:

```text
GH_TOKEN=wrong-test-token
GITHUB_TOKEN=wrong-test-token
GH_CONFIG_DIR=/wrong/path
```

Inside both VMs:

- `GITHUB_TOKEN` and `GH_CONFIG_DIR` were absent;
- `GH_TOKEN` was present but did not equal the fake host value;
- the generated value had the shape of a 40-character proxy placeholder;
- `gh auth status` reported the placeholder as an invalid active `GH_TOKEN`;
- `sbx secret ls` reported no stored secrets;
- `sbx inspect` reported authentication as not configured.

This passes the stale-host-value test but reveals a UX issue: a credential-free sandbox looks to `gh`
as though an invalid environment token is set rather than as though no account exists. Phase 3 must
verify that a sandbox-scoped GitHub secret replaces this with the correct account and that removing
the secret returns to a fail-closed state.

`sbx inspect` reports an uploaded internal `mcpgateway` secret and a configured MCP gateway even when
no user MCP server is selected. `sbx mcp ls` reported no registered servers. This appears to be
internal control-plane authentication, but it remains a host-mediated channel and should stay in the
threat model.

The template also runs a `clipboard-bridge` process, while `clipboard.imagePaste=false`. No clipboard
read was attempted. The setting is fail-closed according to local configuration, but clipboard
isolation remains unproven.

## Performance observations

These are single observations, not statistically useful benchmarks:

| Operation | Observed time |
| --- | --- |
| First creation including image pull | approximately 40 seconds |
| Cached second creation | 3.75 seconds |
| Cached recreation, Personal-Test | 4.74 seconds |
| Cached recreation, Work-Test | 3.70 seconds |
| Stop to command execution, Personal-Test | 1.04 seconds |
| Stop to command execution, Work-Test | 0.97 seconds |

The default allocation was 12 CPUs and 18 GiB memory per sandbox. Resource-use measurements and
multi-sandbox contention are still required; allocation is not the same as actual consumption.

## Installed tools in the shell template

Present: `gh`, `git`, `ssh`, `docker`, and `npm`.
Absent: `claude`, `codex`, and `copilot`.

Therefore the built-in shell template does not yet satisfy the goal that all three agent commands
work natively in one selected workspace. Phase 5 must compare a custom shell template or kit against
separate built-in agent sandboxes.

## Next gates

1. Set up `*.sbx` SSH and attach from cmux without agent forwarding.
2. Prove cmux reconnect and workspace restoration preserve the exact sandbox hostname.
3. Obtain two disposable, revocable GitHub test tokens and apply them only with `--sandbox`.
4. Allowlist only the GitHub endpoints required for credential tests.
5. Test HTTPS Git operations before considering outbound SSH.
6. Keep browser isolation explicitly unproven until cookie and storage tests pass.
