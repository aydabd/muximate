.PHONY: check lint lint-fix format-check test syntax shellcheck pre-commit

PRE_COMMIT_FILES := $(wildcard .gitignore .pre-commit-config.yaml Makefile README.md mise.lock mise.toml bin/* docs/* tests/* zsh/*)

check: format-check shellcheck syntax test

lint: pre-commit

lint-fix: pre-commit

pre-commit:
	mise exec --locked -- pre-commit run --files $(PRE_COMMIT_FILES)

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
