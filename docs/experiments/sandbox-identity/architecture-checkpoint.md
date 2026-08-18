# Minimal hybrid architecture checkpoint

Date: 2026-08-18
Decision state: credential-free phase passed; lifecycle safety failed
Production state: not approved

## Decision

Continue with a minimal hybrid boundary, but stop extending the automatic URL-broker and host-shell
guard experiments.

Docker Sandbox is the proposed boundary for repository state, processes, Git and GitHub identity,
AI-agent credentials, and outbound network policy. Muximate remains the host-side boundary for
selecting the exact sandbox, launching the visible cmux workspace, retaining the Personal/Work
label, and selecting the exact cmux browser profile. `SBX_NO_DISPLAY=1` remains mandatory. A URL
must print for explicit handling rather than silently falling back to the macOS default browser.

This is not a decision to replace the existing production wrappers. The final credential-free
usability phase proved that one small, repeatable Dockerfile can provide all three CLIs without a
new host bridge, broker, shared secret, shell interception, or global network exception. It also
found that sandbox deletion leaves scoped secrets behind and name reuse silently resurrects them.
Continue experimental design work, but do not test real identities until lifecycle safety passes.

## Boundaries

| Sandbox owns | Muximate and the host own |
| --- | --- |
| Private clone and sandbox filesystem | Exact Personal/Work sandbox selection |
| Agent processes and child processes | Guarded cmux workspace launch |
| Git and GitHub identity | Visible workspace identity and warnings |
| Claude, Codex, and Copilot credentials | Exact cmux browser-profile selection |
| Outbound network allowlist | Explicit handling of printed URLs |
| Sandbox lifecycle state | Production wrappers until every gate passes |

The cmux workspace is a usability shell around this design, not the security boundary. Its initial
host-shell dispatch remains interruptible, and an ordinary later terminal pane remains a host-shell
escape. The browser runs on the host in a named cmux profile; it is not inside the sandbox.

## Option comparison

Scores use 1 for poor and 5 for strong. Security is scored against observed behavior, not intended
future capability. Complexity scores favor fewer moving parts.

| Criterion | Full sandbox replacement | Minimal hybrid | Existing wrappers only |
| --- | ---: | ---: | ---: |
| Observed security | 2 | 4 | 2 |
| Implementation simplicity | 1 | 3 | 5 |
| Daily usability | 2 | 4 | 5 |
| Failure visibility | 2 | 5 | 3 |
| Recovery and rollback | 2 | 4 | 5 |
| Maintenance burden | 1 | 3 | 5 |
| Current feasibility | Fail | Conditional pass | Pass |

### Full sandbox replacement

Rejected for the current product versions. It would require compensating for cmux's host-shell
dispatch and later-pane escape, Docker's profile-unaware browser bridge, and the absence of an
acceptable narrow sandbox-to-host URL route. The tested direct-process, shell-startup guard, and
URL-transport candidates all failed. Adding more interception or broker layers would make the
design harder to reason about without closing the boundary.

### Minimal hybrid

Conditionally accepted. It gains the microVM's strongest demonstrated properties while leaving
browser selection in the existing host component that already understands profiles. Manual URL
handling is a deliberate security boundary: failure prints a recoverable value and cannot silently
open Safari or the wrong cmux profile.

The hybrid remains worthwhile only if the agent environment is one repeatable unit. Separate
long-lived sandboxes for Claude, Codex, and Copilot would fragment repository state and identity.
Installing three tools interactively on every sandbox would add drift and weaken recovery. A custom
template may be acceptable if its source, pinned versions, network needs, update procedure, and
rebuild process stay small and reviewable.

### Existing wrappers only

Retain as the production fallback. This is the simplest and most usable current design, and PR #31
still improves explicit browser-profile selection. It does not provide the sandbox's demonstrated
filesystem, process, private-clone, private-Docker, lifecycle, or network boundaries. Environment
and per-command wrappers are defense in depth, not isolation from a compromised agent process.

## Complexity budget

The hybrid may add:

- one sandbox per Personal/Work identity;
- one reproducible agent image or template containing all three CLIs;
- one guarded Muximate workspace launcher;
- one exact sandbox-scoped credential and network configuration per identity;
- one explicit host browser-profile action for printed URLs.

The hybrid may not add:

- an HTTP, TCP, or Unix-socket URL broker maintained by Muximate;
- a wildcard or LAN-facing host listener;
- shared/global Sandbox secrets for Personal and Work;
- a shared host SSH agent;
- workspace shell-startup interception;
- automatic fallback to `open`, Safari, or Docker's browser bridge;
- multiple sandboxes merely to obtain the three agent CLIs;
- unpinned runtime installation as the normal startup path.

If the next phase needs any prohibited item, stop and retain the wrapper-only production design.

## Final credential-free gate

Before any disposable service credential is considered, one clone-mode sandbox must prove:

1. Claude, Codex, and Copilot commands exist in the same private environment.
2. Their versions and installation source are recorded and reproducible.
3. No host agent, provider token, provider home, GitHub token, or real account crosses the boundary.
4. Child processes inherit the sandbox identity rather than host identity variables.
5. Network policy contains only reviewed destinations and remains deny-by-default.
6. Stop/start preserves the private clone and tool environment.
7. Sandbox deletion removes the private clone and agent state.
8. URL attempts with `SBX_NO_DISPLAY=1` print rather than invoke the host browser bridge.
9. Setup, normal launch, failure, recovery, update, and deletion remain understandable to a user.

The credential-free gate passed. A test with deliberately invalid sandbox-scoped values then found
that `sbx rm` leaves those secrets behind and a new sandbox with the same name inherits them. Real
identity testing is therefore blocked. Passing the credential-free gate does not justify real
Personal/Work migration, removal of wrappers, or automatic browser routing.

## Current recommendation

The hybrid is safer than wrappers alone for untrusted CLI agents and much simpler than the attempted
full replacement. The digest-pinned three-agent template stayed within the complexity budget, but
credential lifecycle did not pass. Keep the hybrid experimental, keep the existing wrappers as the
production design, and require an upstream or separately reviewed lifecycle solution before any real
credential test.
