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
  [[ "$output" == *"unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_OAUTH_TOKEN OPENAI_API_KEY COPILOT_GITHUB_TOKEN GH_TOKEN GITHUB_TOKEN"* ]]
  echo "# evidence: $(printf '%s' "$output" | tr '\n' ';')"
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

@test "configures an exact sandbox target without storing credentials" {
  run muximate sandbox-configure personal muximate-personal-test /private/clone/personal
  [ "$status" -eq 0 ]
  [[ "$output" == *"sandbox: muximate-personal-test"* ]]
  [ "$(cat "$MUXIMATE_ROOT/sandboxes.tsv")" = $'personal\tmuximate-personal-test\t/private/clone/personal' ]
  [ "$(ls -l "$MUXIMATE_ROOT/sandboxes.tsv" | awk '{print substr($1, 1, 10)}')" = -rw------- ]
}

@test "rejects unsafe sandbox names and relative clone paths" {
  run muximate sandbox-configure personal 'personal;open-safari' /private/clone/personal
  [ "$status" -ne 0 ]
  [[ "$output" == *"sandbox name may contain only"* ]]

  run muximate sandbox-configure personal muximate-personal-test relative/clone
  [ "$status" -ne 0 ]
  [[ "$output" == *"path must be absolute"* ]]

  run muximate sandbox-configure personal muximate-personal-test /
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing to use the sandbox filesystem root"* ]]
  [ ! -e "$MUXIMATE_ROOT/sandboxes.tsv" ]
}

@test "sandbox workspace rejects a folder profile mismatch before launching tools" {
  muximate init work "$TEST_PROJECT/project" >/dev/null
  muximate sandbox-configure personal muximate-personal-test /private/clone/personal >/dev/null

  run muximate sandbox-workspace personal "$TEST_PROJECT/project"
  [ "$status" -ne 0 ]
  [[ "$output" == *"folder profile is work, not personal"* ]]
}

@test "creates a guarded cmux sandbox workspace for the exact profile" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  muximate sandbox-configure personal muximate-personal-test "/private/clone/personal test" >/dev/null
  browser=$(muximate browser-profile "$TEST_PROJECT/project")
  cmux_log="$TEST_HOME/cmux-sandbox.log"
  sbx_log="$TEST_HOME/sbx.log"

  run env CMUX_BIN="$PROJECT_DIR/tests/fixtures/fake-cmux-sandbox" \
    CMUX_TEST_LOG="$cmux_log" CMUX_TEST_BROWSER_PROFILE="$browser" \
    SBX_BIN="$PROJECT_DIR/tests/fixtures/fake-sbx" SBX_TEST_LOG="$sbx_log" \
    SSH_BIN="$PROJECT_DIR/tests/fixtures/fake-ssh" \
    SSH_AUTH_SOCK=/host/agent.sock GH_TOKEN=host-gh GITHUB_TOKEN=host-github \
    GH_CONFIG_DIR=/host/gh muximate sandbox-workspace personal "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [[ "$output" == *"workspace: workspace:42"* ]]
  [[ "$output" == *"URL policy: Docker host-browser opening disabled"* ]]

  grep -Fxq 'SSH_AUTH_SOCK=unset' "$sbx_log"
  grep -Fxq 'GH_TOKEN=unset' "$sbx_log"
  grep -Fxq 'GITHUB_TOKEN=unset' "$sbx_log"
  grep -Fxq 'GH_CONFIG_DIR=unset' "$sbx_log"
  grep -Fxq 'SBX_NO_TELEMETRY=1' "$sbx_log"
  grep -Fxq 'arg=inspect' "$sbx_log"
  grep -Fxq 'arg=muximate-personal-test' "$sbx_log"

  grep -Fq ' -u SSH_AUTH_SOCK -u GH_TOKEN -u GITHUB_TOKEN -u GH_CONFIG_DIR ' "$cmux_log"
  grep -Fq ' -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u CLAUDE_CODE_OAUTH_TOKEN ' "$cmux_log"
  grep -Fq "'$PROJECT_DIR/tests/fixtures/fake-ssh' -a -o ControlMaster=no -o ControlPersist=no" "$cmux_log"
  grep -Fq "'muximate-personal-test.sbx'" "$cmux_log"
  grep -Fq 'export SBX_NO_DISPLAY=1' "$cmux_log"
  grep -Fq '/private/clone/personal test' "$cmux_log"
  grep -Fxq 'arg=--profile' "$cmux_log"
  grep -Fxq "arg=$browser" "$cmux_log"
  grep -Fxq 'arg=about:blank' "$cmux_log"
  grep -Fxq 'arg=Blue' "$cmux_log"
  grep -Fxq 'arg=workspace:42' "$cmux_log"
}

@test "sandbox workspace fails before cmux when the sandbox is unavailable" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  muximate sandbox-configure personal muximate-personal-test /private/clone/personal >/dev/null
  browser=$(muximate browser-profile "$TEST_PROJECT/project")
  cmux_log="$TEST_HOME/cmux-sandbox.log"

  run env CMUX_BIN="$PROJECT_DIR/tests/fixtures/fake-cmux-sandbox" \
    CMUX_TEST_LOG="$cmux_log" CMUX_TEST_BROWSER_PROFILE="$browser" \
    SBX_BIN="$PROJECT_DIR/tests/fixtures/fake-sbx" SBX_TEST_FAIL=1 \
    SSH_BIN="$PROJECT_DIR/tests/fixtures/fake-ssh" \
    muximate sandbox-workspace personal "$TEST_PROJECT/project"
  [ "$status" -ne 0 ]
  [[ "$output" == *"configured sandbox is unavailable"* ]]
  [ ! -e "$cmux_log" ]
}

@test "sandbox workspace removes partial workspace when browser creation fails" {
  muximate init work "$TEST_PROJECT/project" >/dev/null
  muximate sandbox-configure work muximate-work-test /private/clone/work >/dev/null
  browser=$(muximate browser-profile "$TEST_PROJECT/project")
  cmux_log="$TEST_HOME/cmux-sandbox.log"

  run env CMUX_BIN="$PROJECT_DIR/tests/fixtures/fake-cmux-sandbox" \
    CMUX_TEST_LOG="$cmux_log" CMUX_TEST_BROWSER_PROFILE="$browser" \
    CMUX_TEST_BROWSER_FAIL=1 SBX_BIN="$PROJECT_DIR/tests/fixtures/fake-sbx" \
    SSH_BIN="$PROJECT_DIR/tests/fixtures/fake-ssh" \
    muximate sandbox-workspace work "$TEST_PROJECT/project"
  [ "$status" -ne 0 ]
  [[ "$output" == *"removed workspace:42"* ]]
  grep -Fxq 'arg=close' "$cmux_log"
  grep -Fxq 'arg=workspace:42' "$cmux_log"
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
