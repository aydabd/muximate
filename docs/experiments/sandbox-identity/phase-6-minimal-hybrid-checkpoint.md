# Phase 6: minimal-hybrid architecture and three-agent checkpoint

Date: 2026-08-18
Host timezone: Europe/Stockholm
Docker Sandboxes: 0.38.0, commit `c022b14634c4bea846ca12870d1d5e97d5868b54`
Host image builder: Rancher Desktop Docker Engine 29.1.3, Linux/arm64
Credentials: deliberately invalid sandbox-scoped test values only
Network: explicit per-sandbox deny `**`
Browser: none; `xdg-open` print behavior only

## Result

The minimal hybrid remains the preferred experimental architecture, but it is not ready for
production or real Personal/Work identities.

One small, digest-pinned Dockerfile successfully composed Claude, Codex, and Copilot into one
agent-less shell template. The final sandbox preserved its private clone and all three CLIs across
stop/start, rejected host-source writes, excluded the host SSH agent and shared skills, enforced an
explicit deny-all network rule, and printed URLs with `SBX_NO_DISPLAY=1`.

The decisive lifecycle test failed. `sbx rm` removed the sandbox VM and private clone but left its
three sandbox-scoped secrets in the host secret store. Recreating a sandbox with the same name
silently reattached all three old credentials. Explicit `sbx secret rm <service> --sandbox <name>`
commands were required to remove them.

This is a fail-closed production blocker. Muximate currently does not own sandbox creation,
deletion, or secret lifecycle, and it must not claim that deleting a sandbox deletes its identity.
Do not add real credentials or remove the production wrappers until Docker couples these lifecycle
operations or a separately reviewed Muximate lifecycle design can atomically remove, verify, and
prevent resurrection of scoped credentials.

## Architecture checkpoint

Three options were scored in [architecture-checkpoint.md](architecture-checkpoint.md). The outcome
is:

- full sandbox replacement: rejected for current cmux and Docker Sandbox versions;
- minimal hybrid: retained as the best experimental candidate;
- wrapper-only: retained as the production design and rollback path.

The hybrid remains simpler than the attempted full replacement because it has no URL broker, host
listener, socket protocol, replay protocol, shared bearer token, shell-startup interception, or
automatic browser fallback. Browser selection remains host-side and explicit. The custom image is
a maintenance cost, but its source is small and reviewable. Credential lifecycle is the new hard
blocker, not a reason to revive the rejected broker design.

## Supported-image inspection

Docker's three supported images were tested sequentially under the same disposable sandbox name,
with clone mode, `--no-share-skills`, `SSH_AUTH_SOCK` absent, `SBX_NO_DISPLAY=1`, and an explicit
per-sandbox deny-all rule.

| Image | Present CLI | Other two CLIs | Observed version |
| --- | --- | --- | --- |
| `claude-code-docker` | Claude | absent | 2.1.221 |
| `codex-docker` | Codex | absent | 0.146.0 |
| `copilot-docker` | Copilot | absent | 1.0.78 |

No supported image provided all three tools. Separate long-lived agent sandboxes would fragment
repository and identity state, so that design was rejected.

The installed image histories showed that the upstream images themselves use floating installers:

- Claude: `curl -fsSL https://claude.ai/install.sh | bash`;
- Codex: `npm install -g @openai/codex@latest`;
- Copilot: `curl -fsSL https://gh.io/copilot-install | bash`.

The experiment did not repeat those installers. It treated each observed official image digest as
the immutable source artifact.

## Three-agent template

The prototype is under `prototypes/three-agent-template/`. Its final shell base and three source
stages are pinned to these Linux/arm64 registry digests:

```text
shell:        sha256:c183a8ba03cdb30011c73f555c773c5712b84c6ea066f18409253dcab2cfe799
claude-code:  sha256:7fa049b8d7a0cf10f6a4200148ee475e94fc4fb5ef50dfacc4257699cb9a34bc
codex:        sha256:d52a813951597a7ac700371ef5a8e7351eb7fe79d1788455d9b34813c3a6502e
copilot:      sha256:e21edce87d378167fdd3c021a21e0856eaa37b9ed9b058dbd57140f26ced1430
```

The Dockerfile copies Claude's installed native artifact, Codex's global package including its
Linux/arm64 optional binary, and Copilot's installed native binary. It creates the original Codex
relative launcher symlink. It has no package-manager or installer command and no credential.

The first local build prototype exposed a copied-symlink defect: cross-stage `COPY` dereferenced
Codex's launcher, so its JavaScript resolved dependencies from the wrong directory. Recreating the
relative symlink fixed the issue. The final network-disabled container test passed:

```text
Claude Code 2.1.221
codex-cli 0.146.0
GitHub Copilot CLI 1.0.78
```

The local image ID was `sha256:85ed8e59ceef...`. Its exported tar SHA-256 was
`d5ce0c3b6bbc6d5cdf3b16249cb6ccec7f07b1400ddd1958b0b91e744bfa9a27`. After loading it into
Docker Sandbox's separate image store, the template occupied approximately 2.51 GB and had runtime
image ID `sha256:5184f0832ee9...`.

The final image uses Docker's non-Docker shell base. `docker info` was unavailable inside it. Adding
the private Docker Engine variant would increase image and runtime cost and was not silently added;
that remains a daily-usability decision.

## Credential-free sandbox results

The final sandbox was created from the local unpublished template with:

```sh
env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 SBX_NO_DISPLAY=1 \
  sbx create --clone --no-share-skills --deny-network '**' \
  --template docker.io/library/muximate-three-agent:phase6-arm64 \
  --name muximate-hybrid-agent-test shell \
  /private/tmp/muximate-hybrid-agent-test/source
```

Results:

| Gate | Result |
| --- | --- |
| All three CLIs in one sandbox | Pass |
| Host SSH agent and `/run/ssh-agent.sock` absent | Pass |
| Shared skills absent | Pass |
| Host provider and GitHub variables absent before sbx calls | Pass |
| Parent and child identity variables | Pass with Docker proxy sentinels noted below |
| Claude, OpenAI, GitHub, and unrelated HTTPS under deny-all | Pass; explicitly denied |
| Host source mount write | Pass; rejected |
| Private clone commit | Pass; host fixture stayed clean |
| Stop/start persistence | Pass; marker, commit, and all CLIs remained |
| Stop-to-command observation | 1.79 seconds |
| URL behavior before and after restart | Pass; printed URL, no browser opened |
| Private Docker Engine | Fail; intentionally absent from the lighter base |

Even with no user secret configured, the shell sandbox exposed 13-character
`ANTHROPIC_API_KEY` and `OPENAI_API_KEY` values. Shape-only checks identified both as Docker's known
proxy sentinels; they did not equal any host value, and `sbx secret ls` was empty. Child processes
inherited the sentinels. Consumers must not interpret the mere presence of these variables as proof
that a provider account is configured.

The shell agent also contributed an unexpected kit allow for `openrouter.ai`. The explicit local
deny `**` took precedence. Production policy setup must inspect the effective rules after creation,
not assume that selecting `shell` creates an empty allowlist.

## Disposable scoped-secret test

Three deliberately invalid values with recognizable test-only strings were supplied over stdin:

```sh
sbx secret set anthropic --sandbox muximate-hybrid-agent-test
sbx secret set openai --sandbox muximate-hybrid-agent-test
sbx secret set github --sandbox muximate-hybrid-agent-test
```

No global secret existed. The sandbox received proxy placeholders of lengths 13, 13, and 40. Shape
and inequality checks proved the deliberately invalid source values were not present in the VM.
Child processes inherited only those placeholders. Network remained explicitly denied, so no
provider or external endpoint was contacted.

This passed scope and non-exposure plumbing only. It did not test authentication, account identity,
revocation, billing, OAuth, API behavior, or actual provider network allowlists.

## Failed deletion and name-reuse gate

After `sbx rm --force muximate-hybrid-agent-test`:

- `sbx ls --json` returned no sandboxes;
- the private clone and fake commit were gone;
- all three sandbox-scoped secrets still appeared in `sbx secret ls --sandbox
  muximate-hybrid-agent-test`.

A new credential-free `shell-docker` sandbox was then created with the same name. `sbx inspect`
immediately listed uploaded Anthropic, OpenAI, and GitHub secrets, and the VM received all three old
proxy placeholders. Result: fail. Sandbox-name reuse resurrects the previous scoped identity.

The exact cleanup required:

```sh
sbx rm --force muximate-hybrid-agent-test
sbx secret rm anthropic --sandbox muximate-hybrid-agent-test --force
sbx secret rm openai --sandbox muximate-hybrid-agent-test --force
sbx secret rm github --sandbox muximate-hybrid-agent-test --force
```

All sandbox, global, and combined secret listings were empty afterward.

## Cleanup

- Removed the final sandbox, the name-reuse probe, their private clones, and scoped policies.
- Explicitly removed the three orphaned invalid secrets.
- Removed the custom template and the three agent templates added to the sandbox runtime; retained
  only the original `shell-docker` template.
- Removed the unpublished local image, eight official template tags absent at baseline, exported
  tar, anonymous Docker configuration, and disposable Git repository.
- Returned `sandboxd` to its original stopped state.
- Did not remove unrelated Rancher Desktop images, containers, volumes, or broad build cache.
- No real account, browser, cmux workspace, host listener, global Sandbox secret, or SSH agent was
  used.

## Repository validation

Validation after adding this checkpoint and the experimental template:

| Check | Result |
| --- | --- |
| Guarded sandbox-workspace Bats | Pass, 1/1 |
| Full Bats | Pass, 32/32 |
| Existing URL-broker unit tests | Pass, 6/6 |
| Formatting, YAML, and JSON | Pass |
| Markdown lint and commit lint | Pass |
| ShellCheck, shfmt, and shell syntax | Pass |
| actionlint | Pass |
| gitleaks and zizmor | Pass; no findings |
| Pinned Taplo | Host/tool failure, exit 101 |

Taplo reproduced the established macOS `system-configuration` NULL-object panic. It did not report
a repository formatting failure and remains recorded separately from the passing project gates.

## Remaining gates

1. Resolve orphaned sandbox-scoped secret deletion and name-reuse resurrection upstream or through
   a separately reviewed, fail-closed lifecycle owner.
2. Decide whether the 2.51 GB non-Docker image and manual digest-update process are acceptable.
3. Decide whether agents need the larger private-Docker template.
4. Prove actual provider identities only with revocable disposable accounts after lifecycle safety
   passes.
5. Keep browser restart/restore and authenticated browser separation unproven.
6. Retain `SBX_NO_DISPLAY=1`, manual URL handling, production wrappers, and PR #31 browser-profile
   selection.
