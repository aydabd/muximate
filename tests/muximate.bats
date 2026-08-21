load test_helper

@test "initializes a personal folder with mise disabled" {
  run muximate init personal "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  echo "# evidence: $output"

  run muximate profile "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [ "$output" = personal ]
  echo "# evidence: profile=$output"

  run muximate mise-status "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [ "$output" = disabled ]
  echo "# evidence: mise=$output"
}

@test "initializes a second independent folder" {
  second_project=$(mktemp -d "$TEST_PROJECT/second.XXXXXX")

  run muximate init personal "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  run muximate init work "$second_project"
  [ "$status" -eq 0 ]
  echo "# evidence: first=$(muximate profile "$TEST_PROJECT/project") second=$(muximate profile "$second_project")"
}

@test "platform capability check emits runner evidence" {
  run "$PROJECT_DIR/bin/muximate-platform-check"
  [ "$status" -eq 0 ]
  [[ "$output" == *"evidence: os="* ]]
  [[ "$output" == *"evidence: architecture="* ]]
  [[ "$output" == *"evidence: bash_version="* ]]
  echo "# evidence: $(printf '%s' "$output" | tr '\n' ';')"
}

@test "configures the GitHub profile directory" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null

  run muximate profile-configure personal "$TEST_PROJECT/project/gh" "$TEST_PROJECT/project/.ssh/key"
  [ "$status" -eq 0 ]
  echo "# evidence: $output"

  run muximate gh-config "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_PROJECT/project/gh" ]
  echo "# evidence: gh_config=$output"
}

@test "initializes missing profile-scoped agent guidance privately" {
  run muximate agent-policy-init work
  [ "$status" -eq 0 ]

  claude_policy="$MUXIMATE_ROOT/accounts/work/claude/CLAUDE.md"
  codex_policy="$MUXIMATE_ROOT/accounts/work/codex/AGENTS.md"
  copilot_policy="$MUXIMATE_ROOT/accounts/work/copilot/copilot-instructions.md"
  for policy_file in "$claude_policy" "$codex_policy" "$copilot_policy"; do
    [ -f "$policy_file" ]
    if [ "$(uname -s)" = Darwin ]; then
      policy_mode=$(stat -f '%Lp' "$policy_file")
    else
      policy_mode=$(stat -c '%a' "$policy_file")
    fi
    [ "$policy_mode" = 600 ]
    grep -Fq 'Muximate `work` identity' "$policy_file"
    grep -Fq "muximate cmux-browser-open '<URL>'" "$policy_file"
    grep -Fq 'behavioral guidance, not as a security or isolation boundary' "$policy_file"
  done
  echo "# evidence: created Claude, Codex, and Copilot guidance with mode 600"
}

@test "keeps existing agent guidance and creates only missing files" {
  mkdir -p "$MUXIMATE_ROOT/accounts/personal/claude"
  printf '%s\n' 'user-owned Claude guidance' >"$MUXIMATE_ROOT/accounts/personal/claude/CLAUDE.md"

  run muximate agent-policy-init personal
  [ "$status" -eq 0 ]
  [ "$(cat "$MUXIMATE_ROOT/accounts/personal/claude/CLAUDE.md")" = 'user-owned Claude guidance' ]
  [ -f "$MUXIMATE_ROOT/accounts/personal/codex/AGENTS.md" ]
  [ -f "$MUXIMATE_ROOT/accounts/personal/copilot/copilot-instructions.md" ]
  [[ "$output" == *'Kept existing Claude guidance'* ]]
  echo "# evidence: existing Claude guidance preserved byte-for-byte"
}

@test "rejects an agent guidance symlink before creating any policy" {
  mkdir -p "$MUXIMATE_ROOT/accounts/work/codex"
  ln -s "$TEST_HOME/elsewhere" "$MUXIMATE_ROOT/accounts/work/codex/AGENTS.md"

  run muximate agent-policy-init work
  [ "$status" -ne 0 ]
  [[ "$output" == *'agent guidance must not be a symbolic link'* ]]
  [ ! -e "$MUXIMATE_ROOT/accounts/work/claude/CLAUDE.md" ]
  [ ! -e "$MUXIMATE_ROOT/accounts/work/copilot/copilot-instructions.md" ]
  echo "# evidence: symlink rejected during preflight with no partial policy set"
}

@test "rejects an invalid agent policy profile" {
  run muximate agent-policy-init shared
  [ "$status" -ne 0 ]
  [[ "$output" == *'usage: muximate agent-policy-init personal|work'* ]]
}

@test "enables and disables mise per folder" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null

  run muximate mise enable "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  echo "# evidence: $output"

  run muximate mise-status "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [ "$output" = enabled ]
  echo "# evidence: mise=$output"

  run muximate mise disable "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  echo "# evidence: $output"

  run muximate mise-status "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [ "$output" = disabled ]
  echo "# evidence: mise=$output"
}

@test "doctor reports the disabled folder policy" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null

  run muximate doctor "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [[ "$output" == *"profile: personal"* ]]
  [[ "$output" == *"mise: disabled"* ]]
  [[ "$output" == *"existing system/Homebrew tools unchanged"* ]]
  echo "# evidence: $output"
}

@test "generates environment exports for the active folder" {
  muximate init work "$TEST_PROJECT/project" >/dev/null

  run muximate env "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [[ "$output" == *"export MUXIMATE='work'"* ]]
  [[ "$output" == *"export CMUX_BROWSER_PROFILE='work-"* ]]
  [[ "$output" == *"unset MISE_ENABLED MISE_STATUS MISE_GLOBAL_CONFIG_FILE"* ]]
  [[ "$output" == *"export CLAUDE_CONFIG_DIR='$TEST_HOME/.config/muximate/accounts/work/claude'"* ]]
  [[ "$output" == *"export CODEX_HOME='$TEST_HOME/.config/muximate/accounts/work/codex'"* ]]
  [[ "$output" == *"export COPILOT_HOME='$TEST_HOME/.config/muximate/accounts/work/copilot'"* ]]
  cleanup_line=${output%%$'\n'*}
  for variable in MUXIMATE CMUX_BROWSER_PROFILE CLAUDE_CONFIG_DIR CODEX_HOME COPILOT_HOME \
    ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_OAUTH_TOKEN OPENAI_API_KEY \
    COPILOT_GITHUB_TOKEN GH_CONFIG_DIR GH_TOKEN GITHUB_TOKEN; do
    [[ " $cleanup_line " == *" $variable "* ]]
  done
  echo "# evidence: $(printf '%s' "$output" | tr '\n' ';')"
}

@test "scrubs inherited profile state in an uninitialized non-interactive shell" {
  run sh -c 'export MUXIMATE=personal CMUX_BROWSER_PROFILE=personal-stale \
    CLAUDE_CONFIG_DIR=/stale/claude CODEX_HOME=/stale/codex COPILOT_HOME=/stale/copilot \
    OPENAI_API_KEY=stale GH_TOKEN=stale; \
    eval "$(muximate env "$1" 2>/dev/null || true)"; \
    printf "%s|%s|%s|%s|%s|%s|%s\n" "${MUXIMATE:-}" "${CMUX_BROWSER_PROFILE:-}" \
      "${CLAUDE_CONFIG_DIR:-}" "${CODEX_HOME:-}" "${COPILOT_HOME:-}" \
      "${OPENAI_API_KEY:-}" "${GH_TOKEN:-}"' sh "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [ "$output" = '||||||' ]
  echo "# evidence: inherited identity and token variables cleared"
}

@test "passes the active GitHub config into non-interactive child shells" {
  mkdir -p "$TEST_HOME/.config/gh-work"
  muximate init work "$TEST_PROJECT/project" >/dev/null
  muximate profile-configure work "$TEST_HOME/.config/gh-work" "$TEST_PROJECT/project/.ssh/key" >/dev/null

  run sh -c 'cd "$1" && export GH_TOKEN=wrong-account && export GITHUB_TOKEN=wrong-account && \
    eval "$(muximate env .)" && sh -c '\''printf "GH_CONFIG_DIR=%s\n" "${GH_CONFIG_DIR:-}"; \
    printf "GH_TOKEN=%s\n" "${GH_TOKEN:-}"; printf "GITHUB_TOKEN=%s\n" "${GITHUB_TOKEN:-}"'\'' ' \
    sh "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [[ "$output" == *"GH_CONFIG_DIR=$TEST_HOME/.config/gh-work"* ]]
  printf '%s\n' "$output" | grep -Fxq 'GH_TOKEN='
  printf '%s\n' "$output" | grep -Fxq 'GITHUB_TOKEN='
}

@test "keeps provider homes and Codex auth storage isolated by profile" {
  second_project=$(mktemp -d "$TEST_PROJECT/second.XXXXXX")
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  muximate init work "$second_project" >/dev/null

  [ -d "$MUXIMATE_ROOT/accounts/personal/claude" ]
  [ -d "$MUXIMATE_ROOT/accounts/work/claude" ]
  [ "$MUXIMATE_ROOT/accounts/personal/claude" != "$MUXIMATE_ROOT/accounts/work/claude" ]
  [ "$(cat "$MUXIMATE_ROOT/accounts/personal/codex/config.toml")" = 'cli_auth_credentials_store = "file"' ]
  [ "$(cat "$MUXIMATE_ROOT/accounts/work/codex/config.toml")" = 'cli_auth_credentials_store = "file"' ]
  [ "$(ls -ld "$MUXIMATE_ROOT/accounts/personal" | awk '{print substr($1, 1, 10)}')" = drwx------ ]
}

@test "claude-teams launcher applies the active profile before cmux" {
  muximate init work "$TEST_PROJECT/project" >/dev/null

  run sh -c 'cd "$1" && CMUX_BIN="$2/tests/fixtures/fake-cmux-claude-teams" \
    CMUX_TEST_LOG="$3" muximate claude-teams --model sonnet' \
    sh "$TEST_PROJECT/project" "$PROJECT_DIR" "$TEST_HOME/cmux-teams.log"
  [ "$status" -eq 0 ]
  grep -Fxq 'command=claude-teams' "$TEST_HOME/cmux-teams.log"
  grep -Fxq "pwd=$(cd "$TEST_PROJECT/project" && pwd -P)" "$TEST_HOME/cmux-teams.log"
  grep -Fxq 'MUXIMATE=work' "$TEST_HOME/cmux-teams.log"
  grep -Fxq "CLAUDE_CONFIG_DIR=$MUXIMATE_ROOT/accounts/work/claude" "$TEST_HOME/cmux-teams.log"
  grep -Fxq "CODEX_HOME=$MUXIMATE_ROOT/accounts/work/codex" "$TEST_HOME/cmux-teams.log"
  grep -Fxq 'ANTHROPIC_API_KEY=' "$TEST_HOME/cmux-teams.log"
  grep -Fxq 'OPENAI_API_KEY=' "$TEST_HOME/cmux-teams.log"
  grep -Fxq 'GH_TOKEN=' "$TEST_HOME/cmux-teams.log"
  grep -Fxq 'arg=--model' "$TEST_HOME/cmux-teams.log"
  grep -Fxq 'arg=sonnet' "$TEST_HOME/cmux-teams.log"
}

@test "codex-teams launcher applies the active profile before cmux" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null

  run sh -c 'cd "$1" && CMUX_BIN="$2/tests/fixtures/fake-cmux-claude-teams" \
    CMUX_TEST_LOG="$3" muximate codex-teams --model gpt-5-codex' \
    sh "$TEST_PROJECT/project" "$PROJECT_DIR" "$TEST_HOME/cmux-codex-teams.log"
  [ "$status" -eq 0 ]
  grep -Fxq 'command=codex-teams' "$TEST_HOME/cmux-codex-teams.log"
  grep -Fxq "pwd=$(cd "$TEST_PROJECT/project" && pwd -P)" "$TEST_HOME/cmux-codex-teams.log"
  grep -Fxq 'MUXIMATE=personal' "$TEST_HOME/cmux-codex-teams.log"
  grep -Fxq "CODEX_HOME=$MUXIMATE_ROOT/accounts/personal/codex" "$TEST_HOME/cmux-codex-teams.log"
  grep -Fxq 'OPENAI_API_KEY=' "$TEST_HOME/cmux-codex-teams.log"
  grep -Fxq 'arg=--model' "$TEST_HOME/cmux-codex-teams.log"
  grep -Fxq 'arg=gpt-5-codex' "$TEST_HOME/cmux-codex-teams.log"
}

@test "generates a cmux workspace config that keeps profile guards" {
  mkdir -p "$TEST_HOME/.config/gh-work"
  muximate init work "$TEST_PROJECT/project" >/dev/null
  muximate profile-configure work "$TEST_HOME/.config/gh-work" "$TEST_PROJECT/project/.ssh/key" >/dev/null

  run muximate cmux-config "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"name": "Muximate work"'* ]]
  [[ "$output" == *'"GH_CONFIG_DIR": "'$TEST_HOME'/.config/gh-work"'* ]]
  [[ "$output" == *'"CLAUDE_CONFIG_DIR": "'$MUXIMATE_ROOT'/accounts/work/claude"'* ]]
  [[ "$output" == *'"CODEX_HOME": "'$MUXIMATE_ROOT'/accounts/work/codex"'* ]]
  [[ "$output" == *'"command": "muximate claude-teams"'* ]]
  [[ "$output" == *'"command": "muximate codex-teams"'* ]]
  [[ "$output" == *'"command": "muximate cmux-browser-open https://github.com"'* ]]
}

@test "profile browser command passes the isolated cmux browser profile" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null

  run sh -c 'cd "$1" && CMUX_BIN="$2/tests/fixtures/fake-cmux" \
    CMUX_TEST_LOG="$3" muximate cmux-browser-open https://github.com' \
    sh "$TEST_PROJECT/project" "$PROJECT_DIR" "$TEST_HOME/cmux-browser.log"
  [ "$status" -eq 0 ]
  [ "$(sed -n '1p' "$TEST_HOME/cmux-browser.log")" = browser ]
  [ "$(sed -n '2p' "$TEST_HOME/cmux-browser.log")" = open ]
  [ "$(sed -n '3p' "$TEST_HOME/cmux-browser.log")" = https://github.com ]
  [ "$(sed -n '4p' "$TEST_HOME/cmux-browser.log")" = --profile ]
  [ "$(sed -n '5p' "$TEST_HOME/cmux-browser.log")" = "$(muximate browser-profile "$TEST_PROJECT/project")" ]
}

@test "open executable routes one URL through the active cmux browser profile" {
  muximate init work "$TEST_PROJECT/project" >/dev/null
  url='https://example.com/path?q=$(touch%20never)&x=;'

  run sh -c 'cd "$1" && CMUX_TEST_LOG="$2" open "$3"' \
    sh "$TEST_PROJECT/project" "$TEST_HOME/open-browser.log" "$url"
  [ "$status" -eq 0 ]
  [ "$(sed -n '1p' "$TEST_HOME/open-browser.log")" = browser ]
  [ "$(sed -n '2p' "$TEST_HOME/open-browser.log")" = open ]
  [ "$(sed -n '3p' "$TEST_HOME/open-browser.log")" = "$url" ]
  [ "$(sed -n '4p' "$TEST_HOME/open-browser.log")" = --profile ]
  [ "$(sed -n '5p' "$TEST_HOME/open-browser.log")" = "$(muximate browser-profile "$TEST_PROJECT/project")" ]
}

@test "open executable prints the URL when cmux routing fails" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null

  run sh -c 'cd "$1" && CMUX_BIN=/nonexistent open https://example.com/failure' \
    sh "$TEST_PROJECT/project"
  [ "$status" -ne 0 ]
  [[ "$output" == *'https://example.com/failure'* ]]
  [[ "$output" == *'cmux command is missing or not executable'* ]]
}

@test "browser commands reject non-HTTP URLs and profiled open options" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null

  run sh -c 'cd "$1" && muximate cmux-browser-open "javascript:alert(1)"' \
    sh "$TEST_PROJECT/project"
  [ "$status" -ne 0 ]
  [[ "$output" == *'browser URL must use HTTP or HTTPS'* ]]

  run sh -c 'cd "$1" && open -a Safari https://example.com' sh "$TEST_PROJECT/project"
  [ "$status" -ne 0 ]
  [[ "$output" == *'profiled folders allow only one HTTP or HTTPS URL'* ]]
}

@test "open executable delegates non-URL usage only outside profile scope" {
  fake_open="$TEST_HOME/fake-system-open"
  printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$@" >"$SYSTEM_OPEN_LOG"' >"$fake_open"
  chmod 700 "$fake_open"

  run sh -c 'cd "$1" && MUXIMATE_SYSTEM_OPEN_BIN="$2" SYSTEM_OPEN_LOG="$3" open notes.txt' \
    sh "$TEST_PROJECT/project" "$fake_open" "$TEST_HOME/system-open.log"
  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_HOME/system-open.log")" = notes.txt ]

  rm "$TEST_HOME/system-open.log"
  run sh -c 'cd "$1" && MUXIMATE_SYSTEM_OPEN_BIN="$2" SYSTEM_OPEN_LOG="$3" open https://example.com' \
    sh "$TEST_PROJECT/project" "$fake_open" "$TEST_HOME/system-open.log"
  [ "$status" -ne 0 ]
  [[ "$output" == *'https://example.com'* ]]
  [ ! -e "$TEST_HOME/system-open.log" ]
}

@test "applies and removes a baseline profile" {
  muximate baseline work "$TEST_PROJECT" >/dev/null

  run muximate profile "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [ "$output" = work ]
  echo "# evidence: baseline_profile=$output"

  run muximate baseline disable "$TEST_PROJECT"
  [ "$status" -eq 0 ]
  echo "# evidence: $output"

  run muximate profile "$TEST_PROJECT/project"
  [ "$status" -ne 0 ]
  echo "# evidence: baseline removal rejected lookup"
}

@test "generates SSH and Git identity configuration" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  muximate profile-configure personal "$TEST_PROJECT/project/gh" "$TEST_PROJECT/project/.ssh/key" >/dev/null

  run muximate ssh-config personal
  [ "$status" -eq 0 ]
  [[ "$output" == *"Match host github.com exec"* ]]
  [[ "$output" == *"IdentityFile \"$TEST_PROJECT/project/.ssh/key\""* ]]
  echo "# evidence: ssh_config contains profile match and owned key"

  run muximate git-configure personal "Example User" user@example.com "$TEST_PROJECT/project/.ssh/key"
  [ "$status" -eq 0 ]
  git_file="$MUXIMATE_ROOT/git/personal.gitconfig"
  [ -r "$git_file" ]
  grep -Fq "name = Example User" "$git_file"
  grep -Fq "email = user@example.com" "$git_file"
  echo "# evidence: git_config=$git_file"
}

@test "enables and disables a project mise configuration" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null

  run muximate project-mise enable "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [ -r "$TEST_PROJECT/project/mise.toml" ]
  echo "# evidence: $output"

  run muximate project-mise disable "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [ -r "$TEST_PROJECT/project/mise.toml.disabled" ]
  [ ! -e "$TEST_PROJECT/project/mise.toml" ]
  echo "# evidence: $output"
}

@test "disables a folder profile and fails closed afterward" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null

  run muximate disable "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  echo "# evidence: $output"

  run muximate status "$TEST_PROJECT/project"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not initialized or covered"* ]]
  echo "# evidence: disabled folder rejected status lookup"
}

@test "rejects floating tool versions before invoking mise" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null

  run muximate tool-set "$TEST_PROJECT/project" shellcheck@latest
  [ "$status" -ne 0 ]
  [[ "$output" == *"exact semantic versions"* ]]
  echo "# evidence: $output"
}

@test "rejects mutable tool refs before invoking mise" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null

  run muximate tool-set "$TEST_PROJECT/project" shellcheck@main
  [ "$status" -ne 0 ]
  [[ "$output" == *"exact semantic versions"* ]]
  echo "# evidence: mutable branch ref rejected"
}

@test "rejects control characters in generated Git identity" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null

  run muximate git-configure personal $'Injected\n[credential]\nhelper = evil' user@example.com "$TEST_PROJECT/project/.ssh/key"
  [ "$status" -ne 0 ]
  [[ "$output" == *"forbidden control character"* ]]
  [ ! -e "$MUXIMATE_ROOT/git/personal.gitconfig" ]
  echo "# evidence: newline-bearing identity rejected before file creation"
}

@test "rejects control characters in profile paths" {
  run muximate profile-configure personal $'/tmp/gh\nconfig' "$TEST_PROJECT/project/.ssh/key"
  [ "$status" -ne 0 ]
  [[ "$output" == *"forbidden control character"* ]]
  echo "# evidence: newline-bearing GitHub config path rejected"
}
