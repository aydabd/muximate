setup() {
  PROJECT_DIR=$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd -P)
  TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/muximate-test-home.XXXXXX")
  TEST_PROJECT=$(mktemp -d "${TMPDIR:-/tmp}/muximate-test-project.XXXXXX")

  mkdir -p "$TEST_PROJECT/project/gh" "$TEST_PROJECT/project/.ssh"
  : >"$TEST_PROJECT/project/.ssh/key"
  chmod +x "$PROJECT_DIR/tests/fixtures/fake-gh" "$PROJECT_DIR/tests/fixtures/fake-cmux"
  chmod +x "$PROJECT_DIR/tests/fixtures/fake-uname"

  export HOME="$TEST_HOME"
  export XDG_CONFIG_HOME="$TEST_HOME/.config"
  export MUXIMATE_ROOT="$TEST_HOME/.config/muximate"
  export PATH="$TEST_HOME/.config/muximate/bin:$PATH"
  export CMUX_BIN="$PROJECT_DIR/tests/fixtures/fake-cmux"

  "$PROJECT_DIR/bin/muximate-install" >/dev/null
}

teardown() {
  rm -rf "$TEST_HOME" "$TEST_PROJECT"
}
