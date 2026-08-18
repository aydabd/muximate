# Experimental sandbox workspace pilot

This pilot implements only the behavior supported by the recorded Phase 2 and Phase 5 evidence. It
does not replace Muximate's existing profile wrappers and does not change PR #31.

## Scope

Two commands are added:

```text
muximate sandbox-configure personal|work sandbox-name absolute-clone-path
muximate sandbox-workspace personal|work [folder]
```

`sandbox-configure` records one exact sandbox name and private clone path per profile in
`$MUXIMATE_ROOT/sandboxes.tsv`. The file is mode 0600 and contains no credential. Reconfiguring a
profile replaces only that profile's record.

`sandbox-workspace` requires an initialized Muximate folder whose profile matches the requested
profile. It then:

1. verifies that `cmux`, `sbx`, and `ssh` are executable;
2. runs `sbx inspect` with host `SSH_AUTH_SOCK`, `GH_TOKEN`, `GITHUB_TOKEN`, and `GH_CONFIG_DIR`
   removed from the inspection process;
3. verifies that the folder's exact named cmux browser profile exists;
4. creates a local cmux workspace with two terminal panes targeting only `<sandbox>.sbx`;
5. removes inherited GitHub, SSH-agent, Anthropic, OpenAI, and Copilot variables from the SSH client
   process, then disables SSH agent forwarding and SSH multiplexing;
6. changes to the configured private clone and replaces the remote process with its login shell;
7. sets `SBX_NO_DISPLAY=1` remotely so Docker's `xdg-open` prints URLs instead of invoking the host
   default browser;
8. creates an `about:blank` browser pane with the exact folder browser profile;
9. applies a visible Personal/Work description and color, then selects the workspace.

If browser creation or final workspace selection fails, the pilot closes the partially created cmux
workspace.

## Prerequisites

Use only disposable accounts and test repositories. Docker Sandbox, cmux, and SSH setup remain
explicit user-owned steps. A representative credential-free clone-mode setup is:

```sh
env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 \
  sbx create --clone --no-share-skills \
  --name muximate-personal-test shell /absolute/personal-test-source

sbx setup ssh
muximate init personal /absolute/personal-test-source
muximate sandbox-configure \
  personal muximate-personal-test /absolute/personal-test-source
muximate sandbox-workspace personal /absolute/personal-test-source
```

Before creation, configure and verify the intended sandbox network policy. Do not use global Docker
Sandbox secrets, copy real credentials, or forward a shared host SSH agent. If the sbx daemon is not
already running, start it with `SSH_AUTH_SOCK` absent; Phase 2 found that a daemon can otherwise pass
the socket into subsequently created sandboxes.

Repeat with distinct Work names, source, clone, browser profile, test identity, and sandbox-scoped
credentials. Never point both profiles at the same sandbox.

## Security properties covered by tests

The Bats suite verifies that:

- unsafe sandbox names, relative clone paths, and `/` clone paths are rejected;
- a folder/profile mismatch fails before sbx or cmux launch;
- stale host GitHub variables and `SSH_AUTH_SOCK` are absent from the sbx inspection process;
- host GitHub, SSH-agent, Anthropic, OpenAI, and Copilot variables are removed before SSH starts;
- SSH uses `-a`, `ControlMaster=no`, and `ControlPersist=no`;
- the remote shell has `SBX_NO_DISPLAY=1`;
- the configured sandbox hostname, clone path, and browser profile are used;
- the browser starts at `about:blank`, avoiding an unsolicited request;
- browser-creation failure removes the partial workspace.

These are deterministic command-construction tests. They supplement but do not replace the live
microVM and cmux evidence in the other files in this directory.

## Known limitations and production blockers

- cmux 0.64.22 sends a layout surface's command into a newly created host login shell. The pilot uses
  `exec ssh`, so no host prompt remains after SSH exits, but there is still a short, potentially
  interruptible host-shell dispatch window.
- `SBX_NO_DISPLAY=1` prevents Safari escape by printing URLs. It does not route them automatically to
  the embedded Personal or Work browser profile.
- A plain cmux new-terminal action still creates a host terminal. Users must not add unguarded panes
  to an experimental sandbox workspace.
- Muximate does not create, remove, update, back up, or recover the configured sandbox.
- Muximate does not configure Docker Sandbox network policy or credentials.
- The default shell template does not contain Claude, Codex, or Copilot.
- SSH setup, cmux restart/restore, agent child processes, GitHub/SSH identities, and authenticated
  browser flows need more live testing.
- Browser-profile isolation remains host-side cmux isolation, not browser execution inside the
  microVM.

Do not use this pilot as the production Personal/Work identity boundary until the production gates
in the experiment README pass.
