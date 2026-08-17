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
