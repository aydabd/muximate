.PHONY: check lint lint-fix format-check test syntax shellcheck pre-commit

check: format-check shellcheck syntax test

lint: pre-commit

lint-fix: pre-commit

pre-commit:
	mise exec --locked -- pre-commit run

format-check:
	./bin/muximate-format-check

syntax:
	sh -n bin/muximate
	sh -n bin/muximate-posix-advanced
	sh -n bin/muximate-install
	sh -n bin/gh-login
	@if command -v zsh >/dev/null 2>&1; then zsh -n zsh/muximate.zsh; fi

shellcheck:
	mise exec --locked -- shellcheck -s sh -S error bin/*

test:
	mise exec --locked -- bin/muximate-bats tests
