# Phase 5b: direct-process inspection and URL-broker prototype

Date: 2026-08-18
Host timezone: Europe/Stockholm
cmux: 0.64.22 (102), commit `ddd4a01bc`
Credentials: none
External network during runtime probes: unused
Browser and sandbox resources: none created

## Result

cmux 0.64.22 does not expose a usable direct-process terminal primitive for the local-workspace
pilot. Its public terminal creation commands have no command-vector argument. The lower-level
Ghostty `direct:` prefix did not survive either cmux layout dispatch or the app socket's
`surface.create.initial_command` path. Both paths involved a host shell, and the layout path left an
interactive host prompt. There is also no enforceable per-workspace policy that disables ordinary
terminal creation.

The direct-process candidate therefore failed. It does not close the pilot's interruptible
host-shell window or later-pane escape.

A restricted URL-broker prototype was built as the next preferred fallback. Six local tests with a
fake cmux executable passed. The prototype binds one exact workspace/profile pair, requires a
private bearer token, accepts only structurally valid HTTP and HTTPS URLs, invokes fake cmux with an
argument vector, rejects identity mismatches, and returns or prints the URL on failure. It has no
macOS `open` or Safari fallback.

The broker is not production-ready. It has not crossed the Docker Sandbox microVM boundary, invoked
real cmux, opened a real browser, handled OAuth, or been integrated with `xdg-open`. Host reachability,
token provisioning, sandbox network policy, socket authorization, lifecycle, and replay protection
remain unresolved.

## Read-only cmux capability inspection

The installed CLI, its offline documentation pointers, the running app's advertised capabilities,
and the exact public `v0.64.22` source were inspected. The source tag was resolved with:

```sh
cmux --version
cmux --help
cmux docs api
cmux docs settings
cmux docs shortcuts
cmux config paths
cmux --json capabilities
gh release view v0.64.22 --repo manaflow-ai/cmux \
  --json tagName,targetCommitish,publishedAt,url,name
git clone --depth 1 --branch v0.64.22 \
  https://github.com/manaflow-ai/cmux.git \
  /private/tmp/muximate-cmux-source.OyywWi/cmux
```

Important findings:

- `new-pane` and `new-surface` accept a terminal type but no command or argv option.
- Layout `surfaces[].command` is dispatched as text to an already started shell.
- The running app advertises `surface.create` and `terminal.create`. `surface.create` accepts a text
  `initial_command`; `terminal.create` is the mobile terminal path and ignores command parameters.
- Ghostty configuration recognizes a `direct:` prefix. cmux's source preserves that distinction
  when Ghostty owns the application-level default command, but the cmux per-surface string does not
  provide that parsed direct-command representation.
- The repository also contains a separate `cmux-tui` protocol whose `create-terminal.argv` is
  direct. The running macOS app does not advertise that protocol's `workspace-registry-v1`
  capability or its `create-terminal` command, so it is not an available primitive for this pilot.
- Project configuration can replace visible surface-tab buttons and some shortcuts, but no schema
  entry denies terminal creation for one workspace. Menu, keyboard, CLI, socket, and restore paths
  would still need one authoritative policy.

Primary upstream references inspected:

- <https://github.com/manaflow-ai/cmux/tree/v0.64.22>
- <https://raw.githubusercontent.com/manaflow-ai/cmux/v0.64.22/docs/cli-contract.md>
- <https://raw.githubusercontent.com/manaflow-ai/cmux/v0.64.22/web/data/cmux.schema.json>

## Disposable direct-process probes

One unfocused, credential-free workspace was created with two layout terminals:

```sh
cmux workspace create \
  --name 'Muximate · DIRECT PROBE' \
  --description 'Disposable direct-process probe; no sandbox, browser, network, or credentials' \
  --cwd /private/tmp \
  --layout '{"direction":"horizontal","split":0.5,"children":[{"pane":{"surfaces":[{"type":"terminal","name":"direct probe 1","command":"direct:/bin/sleep 120","focus":true}]}},{"pane":{"surfaces":[{"type":"terminal","name":"direct probe 2","command":"direct:/bin/sleep 120"}]}}]}' \
  --focus false
```

cmux returned `workspace:18`, with `surface:66` and `surface:67`. Both screens showed the literal
command followed by:

```text
zsh: no such file or directory: direct:/bin/sleep
```

Both then exposed host zsh prompts. Process inspection reported `/bin/zsh` as each surface's root
process. Result: fail.

The same workspace then received two `surface.create` socket calls with exact UUID targets. The
relevant request fields were:

```json
{
  "type": "terminal",
  "initial_command": "direct:/bin/sleep 120",
  "focus": false
}
```

and:

```json
{
  "type": "terminal",
  "initial_command": "direct:/usr/bin/printf direct-marker > /private/tmp/muximate-cmux-direct-escape.log",
  "focus": false
}
```

cmux created `surface:68` and `surface:69`. The first screen reported that Ghostty attempted:

```text
/usr/bin/login -flp r04285 /bin/bash --noprofile --norc -c exec -l direct:/bin/sleep 120
```

The second used the same shell wrapper and created the zero-byte redirection target. That file is
direct evidence that shell metacharacters were interpreted. Result: fail. Because neither path was
direct, no claim based on adversarial interrupt resistance is possible.

Read-only evidence commands included:

```sh
cmux --json tree --workspace workspace:18
cmux --json --id-format both list-panes --workspace workspace:18
cmux --json top --processes --workspace workspace:18
cmux --json surface-health --workspace workspace:18
cmux read-screen --surface surface:66 --scrollback --lines 80
cmux read-screen --surface surface:68 --scrollback --lines 40
cmux read-screen --surface surface:69 --scrollback --lines 40
```

## Restricted URL-broker prototype

The disposable prototype lives under
`docs/experiments/sandbox-identity/prototypes/url-broker/`. It has two components in one script:

- `serve`: a loopback-only HTTP broker bound at startup to one workspace UUID and browser profile;
- `request`: a sandbox-caller-shaped client that prints the submitted URL and exits nonzero if
  validation, authentication, transport, or cmux fails.

The broker enforces:

- a caller token read from a current-user-owned regular file with no group/other permissions;
- exclusive mode-0600 token creation and no symlink following when reading tokens;
- a constant-time bearer-token comparison;
- exact request equality with the server's workspace and profile;
- only `http` and `https`, a required hostname, no URL user information, no control characters,
  valid ports, and bounded request/URL sizes;
- a fixed fake-cmux argv shape:

```text
fake-cmux new-pane --type browser --workspace <exact-uuid> --url <one-argv-url> \
  --profile <exact-profile> --focus false
```

The subprocess receives a minimal `PATH`-only environment. It never invokes `open`, uses a shell,
or falls back to another browser. Server responses set `Cache-Control: no-store`.

Validation was:

```sh
python3 -m unittest discover \
  -s docs/experiments/sandbox-identity/prototypes/url-broker \
  -p 'test_*.py' -v
```

The first sandboxed run could not bind loopback and failed 0/5 tests with `PermissionError: [Errno
1] Operation not permitted`. Rerunning with local loopback permission passed 5/5. After token-read
hardening and client fallback coverage, the final run passed 6/6:

```text
Ran 6 tests in 3.043s

OK
```

Covered results:

| Test | Result |
| --- | --- |
| Exact workspace/profile and valid HTTPS URL | Pass; one fake-cmux argv vector |
| Shell metacharacters inside URL | Pass; retained as one argv value |
| Wrong token | Pass; HTTP 401 and no cmux call |
| Wrong workspace | Pass; HTTP 403 and no cmux call |
| Wrong profile | Pass; HTTP 403 and no cmux call |
| `file:`, `javascript:`, and URL user information | Pass; HTTP 400 and URL returned |
| Token creation and permissions | Pass; exclusive creation and mode 0600 |
| Fake cmux failure | Pass; HTTP 502 with URL returned, no fallback |
| Client rejection path | Pass; URL printed and nonzero exit |

## Security implications

The local cmux workspace remains unsuitable as a fail-closed identity boundary. `direct:` is not an
escape hatch for the tested per-surface paths, and configurable buttons are not a security policy.
Initial startup remains interruptible, and ordinary later panes remain host shells.

The URL broker demonstrates a safer routing contract than Docker's profile-unaware browser bridge:
identity is explicit, authenticated, checked twice, and passed to one fixed cmux invocation without
shell evaluation or Safari fallback. However, this is only a local contract test. A real deployment
must not broadly expose the broker to the host network or weaken the sandbox's deny-by-default
policy. It also needs secure, per-sandbox token provisioning and rotation; binding the same token or
listener across Personal and Work would defeat the identity boundary.

## Cleanup

Exact runtime cleanup was:

```sh
cmux workspace close workspace:18
rm -f /private/tmp/muximate-cmux-direct-escape.log
rm -rf /private/tmp/muximate-cmux-source.OyywWi
```

The URL-broker tests used `tempfile.TemporaryDirectory` for fake executables, token files, and logs;
each test removed its directory during teardown. No sandbox, browser profile, account, token, key,
cookie, or external network rule was created. The prototype source and tests remain in the worktree
as explicitly experimental evidence.

## Remaining gates

1. Decide whether upstream cmux should add an argv-based per-surface API plus a workspace terminal
   policy enforced across UI, keyboard, CLI, socket, restore, and mobile entry points.
2. A Phase 5c probe found that an exact sandbox-scoped host/port allow can retain global
   deny-by-default policy, but neither loopback nor the exact host-only VM bridge delivered the
   request to the broker. Find a documented per-sandbox relay that does not require a wildcard or
   LAN listener.
3. Provision a unique disposable broker token into exactly one sandbox without a global Sandbox
   secret, then test theft, replay, rotation, sandbox deletion, and mismatched identity attempts.
4. Replace fake cmux only after the broker can authenticate the sandbox caller and independently
   attest that the target workspace/profile still match.
5. Keep `SBX_NO_DISPLAY=1` until the full broker path passes; failure must continue to print the URL.
