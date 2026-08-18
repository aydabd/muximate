# Phase 5c: narrow sandbox-to-host URL-broker transport

Date: 2026-08-18
Host timezone: Europe/Stockholm
Docker Sandboxes: 0.38.0, commit `c022b14634c4bea846ca12870d1d5e97d5868b54`
Template: `docker/sandbox-templates:shell-docker`
Mode: one disposable clone-mode shell sandbox with shared skills disabled
Credentials: one ephemeral broker token; no account, service, GitHub, AI, or SSH credential
Network baseline: global `default-deny-all`
Browser and cmux: fake cmux only; no browser or real cmux invocation

## Result

The narrow transport candidate failed without weakening the boundary. Docker Sandbox 0.38.0 can
allow one exact `host.docker.internal:<port>` endpoint for one sandbox while retaining default-deny
for other destinations. However, a broker bound to host loopback was not reachable through that
endpoint. Binding the same broker to the exact host-only VM bridge address also failed. In both
cases TCP connected to Docker's synthetic host gateway and then returned an empty HTTP response;
the request never reached the broker or fake cmux.

The next conventional listener candidate would have been `0.0.0.0`, which includes the active LAN
interface. It was not attempted. No global policy was reset or widened, no second sandbox was
created, and no real cmux, browser, macOS `open`, Docker browser bridge, Safari, account, or external
credential was used.

Therefore a narrowly bound sandbox-to-host URL-broker transport is not feasible with the tested
0.38.0 mechanisms. The local broker contract remains useful evidence, but cross-microVM transport,
caller authentication, replay protection, token rotation, and real browser routing remain
unproven. PR #32 must remain experimental.

## Read-only capability and state inspection

The exact CLI and state commands were:

```sh
sbx version
sbx --help
sbx policy --help
sbx policy ls --help
sbx policy allow network --help
sbx policy deny network --help
sbx policy check network --help
sbx policy log --help
sbx ports --help
sbx cp --help
sbx daemon --help
sbx create --help
sbx exec --help
sbx setup --help

env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 sbx daemon status --json
env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 sbx ls --json
env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 sbx policy ls --json
env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 sbx policy ls --wide
env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 sbx policy profile ls
```

The daemon was initially stopped and no sandboxes existed. `sbx ls` started the daemon, so every
subsequent daemon and sandbox command explicitly removed `SSH_AUTH_SOCK`. The policy contained the
non-editable filesystem allow defaults and the non-editable global network `default-deny-all` rule.
There was no remote-governance profile.

Read-only policy checks rejected all of these before a sandbox-scoped allow existed:

```sh
sbx policy check network --json --verbose 127.0.0.1:43127
sbx policy check network --json --verbose gateway.docker.internal:43127
sbx policy check network --json --verbose host.docker.internal:43127
sbx policy check network --json --verbose 192.0.2.1:43127
```

Each returned `allowed: false` and `No matching allow rule (default deny)`. `sbx ports` only
publishes a sandbox service to host loopback; it does not publish a host service into a sandbox.
`sbx cp` can copy a unique token into one sandbox without using a global Sandbox secret, but it is
provisioning rather than transport.

The installed client documents `host.docker.internal:<port>` as the route to a service on the Mac.
It also contains the separate profile-unaware `gateway.docker.internal:3128/_sbx/browser-open`
bridge. The browser bridge was not called.

## Disposable setup

An empty, credential-free Git repository with a fake invalid identity was initialized under
`/private/tmp/muximate-url-broker-phase5c/source`. The daemon had already been started with
`SSH_AUTH_SOCK` absent. The only sandbox was created with:

```sh
env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 SBX_NO_DISPLAY=1 \
  sbx create --clone --no-share-skills \
  --name muximate-url-broker-test shell \
  /private/tmp/muximate-url-broker-phase5c/source
```

Inspection showed the private shell sandbox, its read-only clone source mount, no user credential,
no SSH agent, and only the expected internal `mcpgateway` control-plane secret. The shell template
also contributed an unexpected sandbox-scoped allow for `openrouter.ai`. Before any request, that
domain was explicitly denied for this sandbox and the policy authorizer confirmed an explicit deny.

The host prototype used fake identifiers:

```text
workspace: 55555555-5555-4555-8555-555555555555
profile: muximate-phase5c-fake-profile
```

It used one newly generated 64-hex-character token in a mode-0600 file and a fake cmux executable
that only appended its argv vector to a disposable log. The broker was first bound to loopback on
ephemeral port `55392`.

```sh
python3 docs/experiments/sandbox-identity/prototypes/url-broker/url_broker.py \
  create-token /private/tmp/muximate-url-broker-phase5c/caller.token

python3 docs/experiments/sandbox-identity/prototypes/url-broker/url_broker.py serve \
  --workspace 55555555-5555-4555-8555-555555555555 \
  --profile muximate-phase5c-fake-profile \
  --token-file /private/tmp/muximate-url-broker-phase5c/caller.token \
  --cmux /private/tmp/muximate-url-broker-phase5c/fake-cmux \
  --listen 127.0.0.1 --port 0 \
  --ready-file /private/tmp/muximate-url-broker-phase5c/ready.json
```

## Exact scoped policy behavior

The first exact rule was added with:

```sh
sbx policy allow network \
  --sandbox muximate-url-broker-test \
  host.docker.internal:55392
```

The same sandbox-scoped policy check changed from `allowed: false` to `allowed: true` for that exact
host and port. `example.com:443` remained denied. After the loopback probe, that exact rule was
removed before the second one was added:

```sh
sbx policy rm network \
  --sandbox muximate-url-broker-test \
  --id f0ae7f88-54ea-48c7-8aaf-300d309a2104

sbx policy allow network \
  --sandbox muximate-url-broker-test \
  host.docker.internal:55618
```

The policy mechanism therefore can express one sandbox, one host name, and one port without
changing the global default-deny rule. Policy expression passed; usable narrow host transport did
not.

## Transport probes

### Loopback-only listener

The unmodified prototype listened only on `127.0.0.1:55392`. A host-side GET to `/open` returned
HTTP 501, proving the broker was healthy and loopback-only. From the sandbox, the same request to
`host.docker.internal:55392` established TCP and then failed with `Empty reply from server`. The
valid broker client printed its URL and exited nonzero. The fake-cmux log was never created.

Token provisioning initially failed closed for a separate reason. `sbx cp` preserved host UID 501,
while the sandbox caller was UID 1000, so the client rejected the token ownership and printed the
URL. After an explicit in-sandbox `chown 1000:1000`, the token was mode 0600 and readable by the
caller. The transport still failed. Production provisioning would need to set both ownership and
mode deliberately.

```sh
env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 \
  sbx cp docs/experiments/sandbox-identity/prototypes/url-broker/url_broker.py \
  muximate-url-broker-test:/home/agent/url_broker.py

env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 \
  sbx cp /private/tmp/muximate-url-broker-phase5c/caller.token \
  muximate-url-broker-test:/home/agent/.muximate-url-broker.token

env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 \
  sbx exec -u root muximate-url-broker-test \
  chown 1000:1000 /home/agent/.muximate-url-broker.token

env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 \
  sbx exec -e SBX_NO_DISPLAY=1 muximate-url-broker-test \
  python3 /home/agent/url_broker.py request \
  --endpoint http://host.docker.internal:55392 \
  --workspace 55555555-5555-4555-8555-555555555555 \
  --profile muximate-phase5c-fake-profile \
  --token-file /home/agent/.muximate-url-broker.token \
  'https://example.invalid/phase5c?value=one'
```

Every sandbox request process set `SBX_NO_DISPLAY=1` explicitly. It was unset in the sandbox's
resting environment, so a future integration would need a durable fail-closed launcher rather than
depending on the host creation environment to propagate it.

### Exact host-only bridge listener

Host interface inspection showed:

```text
LAN:       en0, 192.168.1.30
host-only: bridge100, 192.168.64.1/24
```

A disposable copy of the broker was changed only to permit an exact
`--listen 192.168.64.1`. It listened on `192.168.64.1:55618`; `netstat` confirmed that it did not
bind loopback, wildcard, or the LAN address. Inside the sandbox, `host.docker.internal` resolved to
IPv6 `fe80::1` and IPv4 `169.254.1.1`. IPv6 failed immediately because it lacked a scope. IPv4 TCP
connected, the HTTP request was sent, and Docker's gateway again returned an empty response. The
broker and fake cmux received nothing.

```sh
ifconfig
route -n get 169.254.1.1
dscacheutil -q host -a name host.docker.internal
netstat -anv -p tcp

python3 /private/tmp/muximate-url-broker-phase5c/url_broker_host_interface.py serve \
  --workspace 55555555-5555-4555-8555-555555555555 \
  --profile muximate-phase5c-fake-profile \
  --token-file /private/tmp/muximate-url-broker-phase5c/caller.token \
  --cmux /private/tmp/muximate-url-broker-phase5c/fake-cmux \
  --listen 192.168.64.1 --port 0 \
  --ready-file /private/tmp/muximate-url-broker-phase5c/ready-host-interface.json

env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 \
  sbx exec -e SBX_NO_DISPLAY=1 muximate-url-broker-test \
  curl --noproxy '*' --max-time 5 -v \
  http://host.docker.internal:55618/open
```

This result does not prove that a wildcard listener would fail. It establishes that the two narrow
host binds tested here are insufficient. A wildcard or LAN bind would broaden host exposure and was
forbidden by the experiment rules.

## Tests not run after the transport gate failed

The following cross-microVM cases were intentionally not run because no request reached the
broker:

- missing, malformed, and wrong tokens;
- wrong workspace and profile;
- invalid schemes, user information, control characters, invalid ports, and oversized requests;
- shell metacharacters as one fake-cmux argv value;
- replay and token rotation;
- fake-cmux failure through the microVM path;
- an unrelated host process or second disposable sandbox.

The existing local fake-cmux contract suite still covers its prior 6/6 cases. It must not be
mistaken for cross-microVM caller-authentication evidence.

## Security implications

- An exact sandbox-scoped host-and-port allow can coexist with default-deny for other destinations.
- The shell template's unexpected `openrouter.ai` allow means policy must be inspected after each
  sandbox creation; selecting a credential-free shell does not guarantee that the broker is its only
  allowed destination.
- `sbx cp` avoids a shared/global secret but preserves host ownership. Correct in-sandbox ownership
  is required before the prototype's token check can pass.
- A bearer token authenticates possession, not host process identity. Same-user host processes are
  not isolated by mode 0600 alone.
- Neither an exact loopback bind nor the observed host-only VM bridge provided a working inbound
  route from this sandbox. Binding broadly merely to make routing work would violate the boundary.
- No conclusion can be drawn about replay, rotation, or isolation from a second sandbox because the
  transport gate failed first.

## Cleanup

The broker processes were interrupted and exited cleanly. The exact sandbox was removed with:

```sh
env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 \
  sbx rm --force muximate-url-broker-test
```

Removal discarded the private clone, copied client, ephemeral token, and sandbox state. The
subsequent `sbx ls --json` returned an empty list. `sbx policy ls --wide` showed that the
sandbox-scoped endpoint allow and `openrouter.ai` deny had both disappeared; only the original
global defaults remained.
The daemon was returned to its original stopped state, and
`/private/tmp/muximate-url-broker-phase5c` was removed. No disposable runtime resource remains.

```sh
env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 sbx ls --json
env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 sbx policy ls --wide
env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 sbx daemon stop
env -u SSH_AUTH_SOCK SBX_NO_TELEMETRY=1 sbx daemon status --json
rm -rf /private/tmp/muximate-url-broker-phase5c
```

## Remaining blocker

Docker Sandbox needs a documented host-service relay that can target one host-loopback listener, or
an authenticated per-sandbox Unix-socket/forwarding primitive, without requiring a wildcard or LAN
listener. Until such a primitive exists and passes caller-isolation tests, keep `SBX_NO_DISPLAY=1`,
print URLs for manual handling, retain the existing production profile wrappers, and do not route a
real browser or cmux workspace through this prototype.

## Repository validation

- Focused guarded sandbox-workspace Bats: 1/1 passed.
- Full Bats: 32/32 passed.
- URL-broker unit tests: the managed shell first failed 0/6 during setup because it could not bind
  loopback (`PermissionError: [Errno 1] Operation not permitted`); the same suite with local
  loopback permission passed 6/6 in 3.042 seconds.
- Format check, YAML, JSON, Markdown lint, commit lint, ShellCheck, shfmt, shell syntax, actionlint,
  gitleaks, and zizmor: passed.
- The all-files pre-commit run passed every hook except Taplo. Its Bats hook also passed.
- Pinned Taplo: reproduced the known macOS `system-configuration` NULL-object panic, exit 101. This
  is a separate host/tool failure; no TOML file changed in this phase.
