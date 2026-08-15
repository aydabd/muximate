load test_helper

@test "Darwin gh-login selects the active personal cmux browser profile" {
  mkdir -p "$TEST_HOME/.config/gh-personal"
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  muximate profile-configure personal "$TEST_HOME/.config/gh-personal" "$TEST_PROJECT/project/.ssh/key" >/dev/null
  (cd "$TEST_PROJECT/project" && env GH_TEST_LOG="$TEST_HOME/gh.log" CMUX_TEST_LOG="$TEST_HOME/cmux.log" \
    GH_LOGIN_TEST_MODE=1 GH_LOGIN_GH_BIN="$PROJECT_DIR/tests/fixtures/fake-gh" \
    UNAME_BIN="$PROJECT_DIR/tests/fixtures/fake-uname" FAKE_UNAME_SYSTEM=Darwin \
    CMUX_BIN="$PROJECT_DIR/tests/fixtures/fake-cmux" gh-login personal)

  [ "$(sed -n 's/^GH_CONFIG_DIR=//p' "$TEST_HOME/gh.log")" = "$TEST_HOME/.config/gh-personal" ]
  [ "$(sed -n 's/^CMUX_BROWSER_PROFILE=//p' "$TEST_HOME/gh.log")" = "$(muximate browser-profile "$TEST_PROJECT/project")" ]
  [ "$(sed -n '1p' "$TEST_HOME/cmux.log")" = browser ]
  [ "$(sed -n '2p' "$TEST_HOME/cmux.log")" = open ]
  [ "$(sed -n '4p' "$TEST_HOME/cmux.log")" = --profile ]
  [ "$(sed -n '5p' "$TEST_HOME/cmux.log")" = "$(muximate browser-profile "$TEST_PROJECT/project")" ]
}

@test "Darwin gh-login preserves work profile isolation" {
  work_project=$(mktemp -d "$TEST_PROJECT/work.XXXXXX")
  mkdir -p "$TEST_HOME/.config/gh-work" "$TEST_HOME/.config/gh-personal" "$work_project/.ssh"
  : >"$work_project/.ssh/key"
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  muximate init work "$work_project" >/dev/null
  muximate profile-configure personal "$TEST_HOME/.config/gh-personal" "$TEST_PROJECT/project/.ssh/key" >/dev/null
  muximate profile-configure work "$TEST_HOME/.config/gh-work" "$work_project/.ssh/key" >/dev/null
  (cd "$work_project" && env GH_TEST_LOG="$TEST_HOME/gh.log" CMUX_TEST_LOG="$TEST_HOME/cmux.log" \
    GH_LOGIN_TEST_MODE=1 GH_LOGIN_GH_BIN="$PROJECT_DIR/tests/fixtures/fake-gh" \
    UNAME_BIN="$PROJECT_DIR/tests/fixtures/fake-uname" FAKE_UNAME_SYSTEM=Darwin \
    CMUX_BIN="$PROJECT_DIR/tests/fixtures/fake-cmux" gh-login work)

  [ "$(sed -n 's/^GH_CONFIG_DIR=//p' "$TEST_HOME/gh.log")" = "$TEST_HOME/.config/gh-work" ]
  [ "$(sed -n 's/^CMUX_BROWSER_PROFILE=//p' "$TEST_HOME/gh.log")" = "$(muximate browser-profile "$work_project")" ]
  run sh -c 'cd "$1" && env GH_LOGIN_TEST_MODE=1 GH_LOGIN_GH_BIN="$2/tests/fixtures/fake-gh" \
    UNAME_BIN="$2/tests/fixtures/fake-uname" FAKE_UNAME_SYSTEM=Darwin \
    CMUX_BIN="$2/tests/fixtures/fake-cmux" gh-login personal' sh "$work_project" "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"folder profile is work"* ]]
}

@test "Darwin gh-login rejects a missing cmux browser command" {
  mkdir -p "$TEST_HOME/.config/gh-personal"
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  muximate profile-configure personal "$TEST_HOME/.config/gh-personal" "$TEST_PROJECT/project/.ssh/key" >/dev/null

  run sh -c 'cd "$1" && env GH_LOGIN_TEST_MODE=1 GH_LOGIN_GH_BIN="$2/tests/fixtures/fake-gh" \
    UNAME_BIN="$2/tests/fixtures/fake-uname" FAKE_UNAME_SYSTEM=Darwin \
    CMUX_BIN="$3" gh-login personal' sh "$TEST_PROJECT/project" "$PROJECT_DIR" "$TEST_HOME/missing-cmux"
  [ "$status" -ne 0 ]
  [[ "$output" == *"cmux browser command is missing"* ]]
}

@test "Darwin gh-login rejects stale legacy browser paths" {
  mkdir -p "$TEST_HOME/.config/gh-personal"
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  muximate profile-configure personal "$TEST_HOME/.config/gh-personal" "$TEST_PROJECT/project/.ssh/key" >/dev/null
  printf '%s\n' 'browser: /Users/example/.config/gh-directory-profiles-staged/bin/gh-browser-personal' >"$TEST_HOME/.config/gh-personal/config.yml"

  run sh -c 'cd "$1" && env GH_LOGIN_TEST_MODE=1 GH_LOGIN_GH_BIN="$2/tests/fixtures/fake-gh" \
    UNAME_BIN="$2/tests/fixtures/fake-uname" FAKE_UNAME_SYSTEM=Darwin \
    CMUX_BIN="$3" gh-login personal' sh "$TEST_PROJECT/project" "$PROJECT_DIR" "$PROJECT_DIR/tests/fixtures/fake-cmux"
  [ "$status" -ne 0 ]
  [[ "$output" == *"stale browser path"* ]]
}

@test "Darwin gh-login explains a stale macOS Keychain account" {
  mkdir -p "$TEST_HOME/.config/gh-personal"
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  muximate profile-configure personal "$TEST_HOME/.config/gh-personal" "$TEST_PROJECT/project/.ssh/key" >/dev/null
  printf '%s\n' 'github.com:' '    users:' '        aydabd:' '    user: aydabd' >"$TEST_HOME/.config/gh-personal/hosts.yml"

  run sh -c 'cd "$1" && env SECURITY_BIN="$2/tests/fixtures/fake-security" \
    GH_LOGIN_TEST_MODE=1 GH_LOGIN_GH_BIN="$2/tests/fixtures/fake-gh" \
    UNAME_BIN="$2/tests/fixtures/fake-uname" FAKE_UNAME_SYSTEM=Darwin \
    CMUX_BIN="$2/tests/fixtures/fake-cmux" gh-login personal' sh "$TEST_PROJECT/project" "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Keychain has GitHub CLI account old-account"* ]]
  [[ "$output" == *"security delete-generic-password -s 'gh:github.com' -a 'old-account'"* ]]
  [[ "$output" == *"then rerun: gh-login personal"* ]]
}

@test "Linux gh-login rejects unsupported platforms" {
  mkdir -p "$TEST_HOME/.config/gh-personal"
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  muximate profile-configure personal "$TEST_HOME/.config/gh-personal" "$TEST_PROJECT/project/.ssh/key" >/dev/null

  run sh -c 'cd "$1" && env GH_LOGIN_TEST_MODE=1 GH_LOGIN_GH_BIN="$2/tests/fixtures/fake-gh" \
    UNAME_BIN="$2/tests/fixtures/fake-uname" FAKE_UNAME_SYSTEM=Linux \
    CMUX_BIN="$2/tests/fixtures/fake-cmux" gh-login personal' sh "$TEST_PROJECT/project" "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"supported only on macOS"* ]]
}
