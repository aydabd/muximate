load test_helper

has() { printf '%s\n' "$output" | grep -qF -- "$1"; }

setup_gh_wrapper() {
  mkdir -p "$TEST_HOME/.config/gh-personal"
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  muximate profile-configure personal "$TEST_HOME/.config/gh-personal" "$TEST_PROJECT/project/.ssh/key" >/dev/null
  muximate mise enable "$TEST_PROJECT/project" >/dev/null
  printf '%s\n' '[tools]' 'gh = "2.0.0"' >"$(muximate mise-config "$TEST_PROJECT/project")"
  export MISE_BIN="$PROJECT_DIR/tests/fixtures/fake-mise-gh"
  export FAKE_REAL_GH="$PROJECT_DIR/tests/fixtures/fake-real-gh"
  export GH_TEST_LOG="$TEST_HOME/gh.log"
  mkdir -p "$TEST_PROJECT/neutral"
}

@test "gh wrapper records its own stable path as GH_PATH" {
  setup_gh_wrapper

  run_in "$TEST_PROJECT/project" gh auth setup-git
  [ "$status" -eq 0 ]
  grep -qx "GH_PATH=$MUXIMATE_ROOT/bin/gh" "$GH_TEST_LOG"
  echo "# evidence: $(cat "$GH_TEST_LOG")"
}

@test "gh wrapper serves git-credential from a neutral folder via MUXIMATE_PATH" {
  setup_gh_wrapper
  expected_config=$(muximate gh-config "$TEST_PROJECT/project")

  MUXIMATE_PATH="$TEST_PROJECT/project" GH_CONFIG_DIR=/poisoned \
    run_in "$TEST_PROJECT/neutral" gh auth git-credential get
  [ "$status" -eq 0 ]
  grep -qx "GH_CONFIG_DIR=$expected_config" "$GH_TEST_LOG"
  grep -qx 'ARGS=auth git-credential get' "$GH_TEST_LOG"
  echo "# evidence: $(cat "$GH_TEST_LOG")"
}

@test "gh wrapper still rejects other commands from a neutral folder" {
  setup_gh_wrapper

  MUXIMATE_PATH="$TEST_PROJECT/project" run_in "$TEST_PROJECT/neutral" gh auth status
  [ "$status" -eq 2 ]
  has 'folder is not initialized'
  [ ! -e "$GH_TEST_LOG" ]
  echo "# evidence: $output"
}

@test "gh wrapper rejects git-credential from a neutral folder without MUXIMATE_PATH" {
  setup_gh_wrapper

  run_in "$TEST_PROJECT/neutral" env -u MUXIMATE_PATH gh auth git-credential get
  [ "$status" -eq 2 ]
  [ ! -e "$GH_TEST_LOG" ]
  echo "# evidence: $output"
}

@test "doctor fails when a git credential helper path does not exist" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  export GIT_CONFIG_GLOBAL="$TEST_HOME/.gitconfig"
  git config --global credential.https://github.com.helper ''
  git config --global --add credential.https://github.com.helper \
    "!$TEST_HOME/gone/bin/gh auth git-credential"

  run muximate doctor "$TEST_PROJECT/project"
  [ "$status" -eq 1 ]
  has "credential_helper: missing $TEST_HOME/gone/bin/gh (credential.https://github.com.helper)"
  has 'hint: run: git config --global --unset-all credential.https://github.com.helper'
  echo "# evidence: $output"
}

@test "doctor accepts existing git credential helpers" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  export GIT_CONFIG_GLOBAL="$TEST_HOME/.gitconfig"
  git config --global credential.https://github.com.helper ''
  git config --global --add credential.https://github.com.helper \
    "!$MUXIMATE_ROOT/bin/gh auth git-credential"

  run muximate doctor "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  has 'credential_helpers: ok'
  echo "# evidence: $output"
}
