# Phase 5: cmux attachment and initial browser test

Date: 2026-08-18
cmux: 0.64.22 (102)
Docker Sandboxes: 0.38.0
Credentials: no GitHub or agent credential configured
Browser identities: neutral `Personal-Test` and `Work-Test` markers only

## Result

A local cmux workspace provided the requested visible layout during the test: two terminal panes that
replaced their host shells with SSH into one persistent sandbox, plus an embedded browser pane using
a named cmux profile. The Personal-Test and Work-Test layouts differed only in their sandbox name,
private clone path, visible labels, and browser profile.

This is the current usability candidate, not a production-ready result. A native cmux remote SSH
workspace cannot create a browser pane with a named profile in cmux 0.64.22. Native remote attach
also needs SSH multiplexing disabled and sometimes retries. The local-workspace workaround preserves
the embedded browser, but every new terminal pane must be created through an atomic guarded launcher
or it can briefly expose a host shell.

Automatic URL routing remained a separate question after the layout test. An explicitly created cmux
browser pane stays in cmux, but OAuth flows, `xdg-open`, agent-generated links, and clicked terminal
links can use different routing paths.

The subsequent read-only routing probe failed this requirement for `xdg-open`. The sandbox shell had
no `BROWSER` or `CMUX_*` environment and no `xdg-settings` command. Its Docker-provided
`/usr/local/bin/xdg-open` posts HTTP and HTTPS URLs to:

```text
http://gateway.docker.internal:3128/_sbx/browser-open
```

That endpoint delegates to the host browser and carries no cmux workspace or profile identity. The
helper prints a URL instead only when `SBX_NO_DISPLAY` is set, but the tested cmux SSH session had
`SBX_NO_DISPLAY=unset`. Therefore an application calling `xdg-open` can escape to the macOS default
browser, matching the observed Safari behavior. No URL was opened during this probe.

## SSH setup and direct attachment

`sbx setup ssh` added the Docker-managed `Host *.sbx` block to the host SSH configuration. Important
properties include:

```text
ProxyCommand /opt/homebrew/bin/sbx ssh proxy %n
IdentityAgent none
IdentityFile /dev/null
IdentitiesOnly yes
ControlMaster no
```

Direct SSH attachment succeeded for both sandboxes. Single observations were 1.88 seconds for
Personal-Test and 1.79 seconds for Work-Test. Host fake GitHub variables and the host SSH agent did
not cross the SSH boundary. A direct shell starts at `/home/agent/workspace`, so each launcher must
explicitly change to its private clone path.

## Native cmux remote-workspace test

The initial form failed:

```sh
cmux ssh muximate-personal-test.sbx --no-forward-agent
```

Verbose SSH evidence showed that cmux overrode Docker's `ControlMaster no` setting with multiplexing.
The following workaround attached successfully after one or two automatic retries:

```sh
cmux ssh muximate-personal-test.sbx \
  --no-forward-agent \
  --ssh-option ControlMaster=no \
  --ssh-option ControlPersist=no
```

Creating another terminal pane inside a connected remote workspace correctly targeted the same
sandbox. Disconnect and reconnect preserved the Personal/Work target, but required retries and reset
the working directory to `/home/agent/workspace`.

The decisive browser limitation was returned directly by cmux:

```text
Browser profiles cannot be selected when creating a browser pane in a remote workspace
```

Therefore a native cmux remote workspace does not currently satisfy the requested combined terminal
and isolated-host-browser layout.

## Local cmux workspace workaround

The working local layout uses a normal cmux workspace. Each terminal surface's initial command is the
equivalent of:

```sh
exec ssh -a \
  -o ControlMaster=no \
  -o ControlPersist=no \
  -tt muximate-personal-test.sbx \
  "cd /private/tmp/muximate-sandbox-identity/personal-test && exec bash -l"
```

Work-Test substitutes only its Work sandbox and clone path. `exec` is security-relevant: when the
remote shell exits, no parent host shell remains. This was tested on one Personal-Test pane. cmux
removed the terminal surface, and `surface-health` showed no replacement host surface. The pane was
then recreated and reattached for continued testing.

The two test layouts contained:

| Workspace | Terminal 1 | Terminal 2 | Browser profile |
| --- | --- | --- | --- |
| `Personal-Test · SANDBOX` | `muximate-personal-test` | `muximate-personal-test` | `muximate-personal-test-browser` |
| `Work-Test · SANDBOX` | `muximate-work-test` | `muximate-work-test` | `muximate-work-test-browser` |

Personal was visibly blue and Work was orange. Both had descriptions naming their exact sandbox and
browser profile. The Personal workspace was selected at the end of the test for human inspection.

The same identity probe ran in all four terminal panes:

| Probe | Personal-Test | Work-Test |
| --- | --- | --- |
| Hostname | `muximate-personal-test` | `muximate-work-test` |
| HOME | `/home/agent` | `/home/agent` |
| SSH agent socket | unset | unset |
| Git email | `personal-test@invalid.example` | `work-test@invalid.example` |
| Working directory | Personal private clone | Work private clone |

An ordinary `cmux new-pane --type terminal` in this local workspace creates a host shell. Production
must therefore provide a guarded pane command that creates and attaches the terminal atomically, or
disable the ordinary new-terminal action in these workspaces. A visible label alone is insufficient
for the fail-closed requirement.

## Initial browser-profile isolation

Two new, neutral cmux profiles were used. No existing Personal or Work browser profile was read or
modified:

```text
muximate-personal-test-browser
muximate-work-test-browser
```

On `https://example.com`, each surface received a distinct non-sensitive marker in a cookie,
localStorage, and sessionStorage. Immediate reads returned only the selected profile's marker:

| State | Personal browser | Work browser |
| --- | --- | --- |
| Cookie | `Personal-Test` | `Work-Test` |
| localStorage | `Personal-Test` | `Work-Test` |
| sessionStorage | `Personal-Test` | `Work-Test` |

The surfaces were reopened using the same named profiles. Cookie and localStorage retained only the
correct marker; sessionStorage reset to `null`, as expected for a new browsing session. This passes
the first live and reopen separation test for these neutral profiles.

It does not yet prove separation across cmux application restart, full session restore, browser
crashes, authentication redirects, downloads, service workers, caches, or profile deletion. It also
does not prove that clicked terminal links are routed to the matching cmux profile. The `xdg-open`
path was tested separately and failed because it targets Docker's host-browser bridge.

## Cleanup

After evidence capture, the four disposable cmux workspaces, two neutral browser profiles, two named
Docker Sandboxes, and `/tmp/muximate-sandbox-identity` fixtures were removed. Sandbox-private clone
state and neutral test cookies were intentionally discarded and are not recoverable.

The installed `sbx` binary, global deny-all sandbox network policy, and Docker-managed `Host *.sbx`
SSH configuration remain as host prerequisites for later experiments. No production Muximate state
or real browser profile was removed.

## Next gates

1. Determine how OAuth, agent-generated URLs, and terminal link clicks are routed. `xdg-open` is now
   known to target Docker's host-browser bridge.
2. Prototype a per-workspace URL broker or equivalent guarded adapter. It must hard-code one cmux
   workspace/profile pair, accept only safe URL schemes, authenticate its sandbox caller, and fail by
   printing the URL rather than silently falling back to Safari.
3. Restart and restore cmux, then repeat sandbox-target and browser-marker checks.
4. Prototype an atomic guarded new-pane action without modifying production behavior.
5. Add disposable GitHub credentials only after two revocable test identities are available.
6. Install or build a sandbox template containing Claude, Codex, and Copilot before testing agent
   account state and child processes.
