.PHONY: check lint lint-fix format-check test syntax shellcheck actionlint pre-commit

check: format-check shellcheck syntax actionlint test

lint: pre-commit

lint-fix: pre-commit

pre-commit:
	mise exec --locked -- pre-commit run

format-check:
	./bin/muximate-format-check

syntax:
	sh -n bin/muximate
	sh -n bin/muximate-operations
	sh -n bin/muximate-install
	sh -n bin/gh-login
	@if command -v zsh >/dev/null 2>&1; then zsh -n zsh/muximate.zsh; fi

shellcheck:
	mise exec --locked -- shellcheck -s sh -S error bin/*

actionlint:
	mise exec --locked -- actionlint

test:
	mise exec --locked -- bin/muximate-bats tests
