# Phase 5a: workspace-scoped host-shell guard probe

Date: 2026-08-18
Host timezone: Europe/Stockholm
cmux: 0.64.22 (102), commit `ddd4a01bc`
Credentials: none
Network: unused
Sandbox and browser resources: none created

## Question and result

Could a cmux workspace environment set `ZDOTDIR` to a private directory whose `.zshenv` immediately
replaces every terminal shell with a guarded process? If so, the same startup hook might also cover
ordinary new terminal panes without relying on cmux's layout-command dispatch.

No. The probe failed. cmux retained and reported the workspace's `ZDOTDIR`,
`MUXIMATE_GUARD_PROBE`, and `MUXIMATE_GUARD_EVIDENCE` values, but the `.zshenv` did not run during
terminal startup. The two layout terminals and a subsequently added ordinary terminal remained host
shells. The ordinary terminal accepted a fixed command and wrote `unguarded-host-shell` to the host
probe file.

This negative result does not prove that every cmux integration technique is unsafe. It rules out
workspace-scoped `ZDOTDIR` as a fail-closed guard in cmux 0.64.22. PR #32 must continue to describe
its `exec ssh` layout as interruptible and experimental.

## Probe

The temporary `.zshenv` contained only:

```zsh
if [[ "${MUXIMATE_GUARD_PROBE:-}" == "1" ]]; then
  builtin trap '' INT QUIT TSTP
  builtin umask 077
  builtin print -r -- "guard-exec pid=$$ ppid=$PPID" >>"${MUXIMATE_GUARD_EVIDENCE:?}"
  exec /bin/sleep 30
fi
```

It was syntax-checked with:

```sh
zsh -n docs/experiments/sandbox-identity/prototypes/cmux-zdotdir-guard/.zshenv
```

The unfocused disposable workspace was then created with two terminal surfaces:

```sh
cmux workspace create \
  --name 'Muximate · GUARD PROBE' \
  --description 'Disposable ZDOTDIR startup guard; no sandbox or credentials' \
  --cwd /private/tmp \
  --env ZDOTDIR=/Users/r04285/git/aydabd/muximate/docs/experiments/sandbox-identity/prototypes/cmux-zdotdir-guard \
  --env MUXIMATE_GUARD_PROBE=1 \
  --env MUXIMATE_GUARD_EVIDENCE=/private/tmp/muximate-cmux-guard-probe-evidence.log \
  --layout '{"direction":"horizontal","split":0.5,"children":[{"pane":{"surfaces":[{"type":"terminal","name":"guard probe 1","focus":true}]}},{"pane":{"surfaces":[{"type":"terminal","name":"guard probe 2"}]}}]}' \
  --focus false
```

cmux returned `workspace:17`. The expected evidence file was absent, so an ordinary terminal was
added and the masked workspace environment and surface health were inspected:

```sh
cmux new-pane --type terminal --direction down --workspace workspace:17 --focus false
cmux workspace env workspace:17 --mask
cmux surface-health --workspace workspace:17
```

cmux returned `surface:65 pane:32 workspace:17`. The masked environment listed all three probe
variables, and surface health listed all three terminals. The ordinary pane visibly had a host-shell
prompt. The following fixed, non-sensitive marker command was sent to prove that the prompt was
active:

```sh
cmux send --surface surface:65 \
  "printf 'unguarded-host-shell\\n' > /private/tmp/muximate-cmux-guard-probe-evidence.log\\n"
sed -n '1,10p' /private/tmp/muximate-cmux-guard-probe-evidence.log
```

The read returned exactly `unguarded-host-shell`. It did not return the guard's `guard-exec` marker.

## Security implication

Workspace environment variables are available to an eventual terminal shell, but this probe shows
that `ZDOTDIR` cannot be relied on to control that shell's startup. It neither removes the initial
interruptible host-shell dispatch window nor guards later terminal panes. A viable fail-closed
solution needs a cmux primitive that launches a process directly, an enforceable terminal policy, or
an upstream change whose interrupt behavior can be tested adversarially.

The existing `exec ssh`, credential-variable sanitization, disabled agent forwarding, and disabled
SSH multiplexing remain defense in depth. They do not make the workspace fully fail-closed.

## Cleanup

The exact cleanup commands were:

```sh
cmux workspace close workspace:17
rm /private/tmp/muximate-cmux-guard-probe-evidence.log
```

The temporary `.zshenv` was removed from the worktree after evidence capture. No sandbox, browser
profile, repository fixture, token, key, cookie, or network-policy change was created by this probe.
