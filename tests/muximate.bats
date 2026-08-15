setup() {
  PROJECT_DIR=$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd -P)
  TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/muximate-test-home.XXXXXX")
  TEST_PROJECT=$(mktemp -d "${TMPDIR:-/tmp}/muximate-test-project.XXXXXX")

  mkdir -p "$TEST_PROJECT/project/gh" "$TEST_PROJECT/project/.ssh"
  : >"$TEST_PROJECT/project/.ssh/key"
  chmod +x "$PROJECT_DIR/tests/fixtures/fake-gh" "$PROJECT_DIR/tests/fixtures/fake-cmux"

  export HOME="$TEST_HOME"
  export MUXIMATE_ROOT="$TEST_HOME/.config/muximate"
  export PATH="$TEST_HOME/.config/muximate/bin:$PATH"
  export CMUX_BIN="$PROJECT_DIR/tests/fixtures/fake-cmux"

  "$PROJECT_DIR/bin/muximate-install" >/dev/null
}

@test "gh-login selects the active personal cmux browser profile" {
  mkdir -p "$TEST_HOME/.config/gh-personal"
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  muximate profile-configure personal "$TEST_HOME/.config/gh-personal" "$TEST_PROJECT/project/.ssh/key" >/dev/null
  (cd "$TEST_PROJECT/project" && env GH_TEST_LOG="$TEST_HOME/gh.log" CMUX_TEST_LOG="$TEST_HOME/cmux.log" \
    GH_LOGIN_TEST_MODE=1 GH_LOGIN_GH_BIN="$PROJECT_DIR/tests/fixtures/fake-gh" \
    CMUX_BIN="$PROJECT_DIR/tests/fixtures/fake-cmux" gh-login personal)

  [ "$(sed -n 's/^GH_CONFIG_DIR=//p' "$TEST_HOME/gh.log")" = "$TEST_HOME/.config/gh-personal" ]
  [ "$(sed -n 's/^CMUX_BROWSER_PROFILE=//p' "$TEST_HOME/gh.log")" = "$(muximate browser-profile "$TEST_PROJECT/project")" ]
  [ "$(sed -n '1p' "$TEST_HOME/cmux.log")" = browser ]
  [ "$(sed -n '2p' "$TEST_HOME/cmux.log")" = open ]
  [ "$(sed -n '4p' "$TEST_HOME/cmux.log")" = --profile ]
  [ "$(sed -n '5p' "$TEST_HOME/cmux.log")" = "$(muximate browser-profile "$TEST_PROJECT/project")" ]
}

@test "gh-login preserves work profile isolation" {
  work_project=$(mktemp -d "$TEST_PROJECT/work.XXXXXX")
  mkdir -p "$TEST_HOME/.config/gh-work" "$TEST_HOME/.config/gh-personal" "$work_project/.ssh"
  : >"$work_project/.ssh/key"
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  muximate init work "$work_project" >/dev/null
  muximate profile-configure personal "$TEST_HOME/.config/gh-personal" "$TEST_PROJECT/project/.ssh/key" >/dev/null
  muximate profile-configure work "$TEST_HOME/.config/gh-work" "$work_project/.ssh/key" >/dev/null
  (cd "$work_project" && env GH_TEST_LOG="$TEST_HOME/gh.log" CMUX_TEST_LOG="$TEST_HOME/cmux.log" \
    GH_LOGIN_TEST_MODE=1 GH_LOGIN_GH_BIN="$PROJECT_DIR/tests/fixtures/fake-gh" \
    CMUX_BIN="$PROJECT_DIR/tests/fixtures/fake-cmux" gh-login work)

  [ "$(sed -n 's/^GH_CONFIG_DIR=//p' "$TEST_HOME/gh.log")" = "$TEST_HOME/.config/gh-work" ]
  [ "$(sed -n 's/^CMUX_BROWSER_PROFILE=//p' "$TEST_HOME/gh.log")" = "$(muximate browser-profile "$work_project")" ]
  run sh -c 'cd "$1" && env GH_LOGIN_TEST_MODE=1 GH_LOGIN_GH_BIN="$2/tests/fixtures/fake-gh" \
    CMUX_BIN="$2/tests/fixtures/fake-cmux" gh-login personal' sh "$work_project" "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"folder profile is work"* ]]
}

@test "gh-login rejects a missing cmux browser command" {
  mkdir -p "$TEST_HOME/.config/gh-personal"
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  muximate profile-configure personal "$TEST_HOME/.config/gh-personal" "$TEST_PROJECT/project/.ssh/key" >/dev/null

  run sh -c 'cd "$1" && env GH_LOGIN_TEST_MODE=1 GH_LOGIN_GH_BIN="$2/tests/fixtures/fake-gh" \
    CMUX_BIN="$3" gh-login personal' sh "$TEST_PROJECT/project" "$PROJECT_DIR" "$TEST_HOME/missing-cmux"
  [ "$status" -ne 0 ]
  [[ "$output" == *"cmux browser command is missing"* ]]
}

@test "gh-login rejects stale legacy browser paths" {
  mkdir -p "$TEST_HOME/.config/gh-personal"
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  muximate profile-configure personal "$TEST_HOME/.config/gh-personal" "$TEST_PROJECT/project/.ssh/key" >/dev/null
  printf '%s\n' 'browser: /Users/example/.config/gh-directory-profiles-staged/bin/gh-browser-personal' >"$TEST_HOME/.config/gh-personal/config.yml"

  run sh -c 'cd "$1" && env GH_LOGIN_TEST_MODE=1 GH_LOGIN_GH_BIN="$2/tests/fixtures/fake-gh" \
    CMUX_BIN="$3" gh-login personal' sh "$TEST_PROJECT/project" "$PROJECT_DIR" "$PROJECT_DIR/tests/fixtures/fake-cmux"
  [ "$status" -ne 0 ]
  [[ "$output" == *"stale browser path"* ]]
}

@test "gh-login explains a stale macOS Keychain account" {
  mkdir -p "$TEST_HOME/.config/gh-personal"
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  muximate profile-configure personal "$TEST_HOME/.config/gh-personal" "$TEST_PROJECT/project/.ssh/key" >/dev/null
  printf '%s\n' 'github.com:' '    users:' '        aydabd:' '    user: aydabd' >"$TEST_HOME/.config/gh-personal/hosts.yml"

  run sh -c 'cd "$1" && env SECURITY_BIN="$2/tests/fixtures/fake-security" \
    GH_LOGIN_TEST_MODE=1 GH_LOGIN_GH_BIN="$2/tests/fixtures/fake-gh" \
    CMUX_BIN="$2/tests/fixtures/fake-cmux" gh-login personal' sh "$TEST_PROJECT/project" "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Keychain has GitHub CLI account old-account"* ]]
  [[ "$output" == *"security delete-generic-password -s 'gh:github.com' -a 'old-account'"* ]]
  [[ "$output" == *"then rerun: gh-login personal"* ]]
}

@test "cmux browser adapter derives the active profile non-interactively" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null

  run sh -c 'cd "$1" && env -u CMUX_BROWSER_PROFILE CMUX_BIN="$2/tests/fixtures/fake-cmux" \
    CMUX_TEST_LOG="$3" "$4/.config/muximate/bin/muximate-cmux-browser" \
    https://github.com/login/device' sh "$TEST_PROJECT/project" "$PROJECT_DIR" "$TEST_HOME/cmux.log" "$TEST_HOME"
  [ "$status" -eq 0 ]
  [ "$(sed -n '5p' "$TEST_HOME/cmux.log")" = "$(muximate browser-profile "$TEST_PROJECT/project")" ]
}

teardown() {
  rm -rf "$TEST_HOME" "$TEST_PROJECT"
}

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
  echo "# evidence: $(printf '%s' "$output" | tr '\n' ';')"
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
