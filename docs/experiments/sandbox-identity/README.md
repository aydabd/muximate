# Sandbox identity boundary experiment

This directory holds evidence for evaluating whether a real sandbox can replace Muximate's
per-command profile wrappers as the Personal/Work identity boundary.

The experiment is intentionally separate from production implementation. It must not contain real
tokens, private keys, cookies, browser data, generated profile registries, or other credentials.

## Status

- Phase 1 inventory: complete on 2026-08-18.
- Phase 2 minimal Docker Sandboxes: complete without service credentials on 2026-08-18.
- SSH and cmux: partially tested on 2026-08-18; the local-workspace SSH layout is the current
  usability candidate, while native cmux remote workspaces have reconnect and browser limitations.
- Host-shell dispatch guard: a workspace-scoped `ZDOTDIR` startup-guard prototype failed on
  2026-08-18; cmux retained the environment but still exposed host shells, including in a newly
  added terminal pane.
- Direct-process inspection: cmux layout commands and `surface.create.initial_command` did not
  expose Ghostty's lower-level direct-command mode; both paths involved host shells, and cmux has no
  enforceable per-workspace terminal policy.
- URL broker: a loopback-only, fake-cmux prototype passed 6/6 local contract tests for exact
  workspace/profile binding, caller authentication, HTTP(S)-only validation, and fail-by-printing;
  sandbox-to-host transport and real-cmux/browser integration remain unproven.
- Browser: live and reopen cookie/storage separation passed for two neutral cmux profiles; automatic
  URL routing from sandbox applications remains unproven.
- Disposable cmux workspaces, neutral browser profiles, sandboxes, and `/tmp` fixtures: removed after
  evidence capture on 2026-08-18.
- Credential, representative performance, restore, and adversarial tests: not started or incomplete.
- Production recommendation and PR #31 disposition: deferred until the relevant tests pass.

See [phase-1-inventory.md](phase-1-inventory.md) for the evidence and next gate.
See [phase-2-minimal-sandboxes.md](phase-2-minimal-sandboxes.md) for the first executed isolation
results.
See [phase-5-cmux-and-browser.md](phase-5-cmux-and-browser.md) for SSH attachment, cmux layout, and
initial browser-profile results.
See [phase-5a-host-shell-guard.md](phase-5a-host-shell-guard.md) for the failed workspace-scoped
shell-startup guard probe.
See [phase-5b-direct-process-and-url-broker.md](phase-5b-direct-process-and-url-broker.md) for the
failed direct-process probes and the restricted fake-cmux URL-broker prototype.
See [implementation-pilot.md](implementation-pilot.md) for the deliberately limited implementation
built from those findings.
