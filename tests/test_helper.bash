setup() {
  PROJECT_DIR=$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd -P)
  TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/muximate-test-home.XXXXXX")
  TEST_PROJECT=$(mktemp -d "${TMPDIR:-/tmp}/muximate-test-project.XXXXXX")

  mkdir -p "$TEST_PROJECT/project/gh" "$TEST_PROJECT/project/.ssh"
  : >"$TEST_PROJECT/project/.ssh/key"
  chmod +x "$PROJECT_DIR/tests/fixtures/fake-gh" "$PROJECT_DIR/tests/fixtures/fake-cmux" \
    "$PROJECT_DIR/tests/fixtures/fake-cmux-claude-teams"
  chmod +x "$PROJECT_DIR/tests/fixtures/fake-uname"

  export HOME="$TEST_HOME"
  export XDG_CONFIG_HOME="$TEST_HOME/.config"
  export MUXIMATE_ROOT="$TEST_HOME/.config/muximate"
  export PATH="$TEST_HOME/.config/muximate/bin:$PATH"
  export CMUX_BIN="$PROJECT_DIR/tests/fixtures/fake-cmux"

  # Guard: the suite must never reach a real cmux (it would mint browser profiles).
  case "$CMUX_BIN" in
    "$PROJECT_DIR/tests/fixtures/"*) ;;
    *)
      echo "CMUX_BIN must point at a tests/fixtures stand-in, not: $CMUX_BIN" >&2
      return 1
      ;;
  esac

  "$PROJECT_DIR/bin/muximate-install" >/dev/null
}

use_stateful_cmux() {
  chmod +x "$PROJECT_DIR/tests/fixtures/fake-cmux-profiles"
  export CMUX_BIN="$PROJECT_DIR/tests/fixtures/fake-cmux-profiles"
  export CMUX_TEST_STATE="$TEST_HOME/cmux-state"
  export CMUX_TEST_LOG="$TEST_HOME/cmux.log"
}

reset_cmux_log() { : >"$CMUX_TEST_LOG"; }

# Run a command with the given folder as the working directory.
run_in() {
  run_dir=$1
  shift
  run sh -c 'cd "$1" && shift && exec "$@"' sh "$run_dir" "$@"
}

# Add a profile to the stateful fake without it counting in the log.
seed_jar() {
  for seed_name in "$@"; do "$CMUX_BIN" browser profiles add "$seed_name" >/dev/null; done
  reset_cmux_log
}

jar_names() { "$CMUX_BIN" browser profiles list | awk -F '\t' '{print $1}'; }

count_log() { { grep -c "$1" "$CMUX_TEST_LOG" 2>/dev/null || true; } | head -n 1; }

teardown() {
  rm -rf "$TEST_HOME" "$TEST_PROJECT"
}
