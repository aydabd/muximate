# Contributing

## Before opening a change

Keep changes focused and preserve the separation between repository source files and machine-local
profile state. Never commit tokens, private keys, personal GitHub configuration, cloud credentials,
browser data, generated local registries, or machine-specific paths.

Install mise, then run:

```sh
make lint
make check
```

`make lint` runs the mise-managed pre-commit hooks and may fix formatting. `make check` is the
read-only CI-style validation. Shell unit tests are written in Bats under `tests/`.

## Shell changes

- Keep portable command logic in POSIX `sh` where practical.
- Quote paths and variable expansions.
- Fail closed for unknown or uninitialized folders.
- Keep credential operations human-interactive and opt-in.
- Add or update a Bats test for changed behavior.

## Commits

Use a short, descriptive commit subject. The repository pre-commit hook must pass before pushing.
