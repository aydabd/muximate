.PHONY: check lint lint-fix format-check config-check test syntax shellcheck actionlint security gitleaks zizmor pre-commit

check: format-check config-check shellcheck syntax actionlint security test

lint: pre-commit

lint-fix: pre-commit

pre-commit:
	mise exec --locked -- pre-commit run

format-check:
	./bin/muximate-format-check

config-check:
	mise exec --locked -- pre-commit run check-yaml --all-files
	mise exec --locked -- pre-commit run check-json --all-files
	mise exec --locked -- taplo format --check mise.toml

syntax:
	@for script in bin/*; do sh -n "$$script"; done
	bash -n bin/gh
	@if command -v zsh >/dev/null 2>&1; then zsh -n zsh/muximate.zsh; fi

shellcheck:
	mise exec --locked -- shellcheck -S error bin/*

actionlint:
	mise exec --locked -- actionlint

security: gitleaks zizmor

gitleaks:
	mise exec --locked -- gitleaks dir --redact --no-banner .

zizmor:
	mise exec --locked -- zizmor --pedantic .github/workflows .github/dependabot.yml .pre-commit-config.yaml

test:
	mise exec --locked -- bin/muximate-bats tests
