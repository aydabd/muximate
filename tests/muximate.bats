setup() {
  PROJECT_DIR=$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd -P)
  TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/muximate-test-home.XXXXXX")
  TEST_PROJECT=$(mktemp -d "${TMPDIR:-/tmp}/muximate-test-project.XXXXXX")

  mkdir -p "$TEST_PROJECT/project/gh" "$TEST_PROJECT/project/.ssh"
  : >"$TEST_PROJECT/project/.ssh/key"

  export HOME="$TEST_HOME"
  export MUXIMATE_ROOT="$TEST_HOME/.config/muximate"
  export PATH="$TEST_HOME/.config/muximate/bin:$PATH"

  "$PROJECT_DIR/bin/muximate-install" >/dev/null
}

teardown() {
  rm -rf "$TEST_HOME" "$TEST_PROJECT"
}

@test "initializes a personal folder with mise disabled" {
  run muximate init personal "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]

  run muximate profile "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [ "$output" = personal ]

  run muximate mise-status "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [ "$output" = disabled ]
}

@test "configures the GitHub profile directory" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null

  run muximate profile-configure personal "$TEST_PROJECT/project/gh" "$TEST_PROJECT/project/.ssh/key"
  [ "$status" -eq 0 ]

  run muximate gh-config "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_PROJECT/project/gh" ]
}

@test "enables and disables mise per folder" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null

  run muximate mise enable "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]

  run muximate mise-status "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [ "$output" = enabled ]

  run muximate mise disable "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]

  run muximate mise-status "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [ "$output" = disabled ]
}

@test "doctor reports the disabled folder policy" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null

  run muximate doctor "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [[ "$output" == *"profile: personal"* ]]
  [[ "$output" == *"mise: disabled"* ]]
  [[ "$output" == *"existing system/Homebrew tools unchanged"* ]]
}
