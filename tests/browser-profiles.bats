load test_helper

HEX=0123456789abcdef
HEX2=fedcba9876543210

init_folder() {
  muximate init "$1" "$2" >/dev/null
  reset_cmux_log
}

folder_jar() { muximate browser-profile "$1"; }

# ---- guard ----------------------------------------------------------------

@test "suite guard: CMUX_BIN points at a fixture, never the real cmux" {
  case "$CMUX_BIN" in "$PROJECT_DIR/tests/fixtures/"*) ;; *) false ;; esac
}

# ---- A. open under an identity --------------------------------------------

@test "open without --identity keeps the legacy argv and issues no profile calls" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  jar=$(folder_jar "$TEST_PROJECT/project")
  run_in "$TEST_PROJECT/project" muximate cmux-browser-open https://example.com
  [ "$status" -eq 0 ]
  [ "$(cat "$CMUX_TEST_LOG")" = "browser open https://example.com --profile $jar" ]
}

@test "open with --identity uses <folder jar>--<slug> and creates it once" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  jar=$(folder_jar "$TEST_PROJECT/project")
  run_in "$TEST_PROJECT/project" muximate cmux-browser-open --identity admin https://example.com
  [ "$status" -eq 0 ]
  grep -Fxq "browser open https://example.com --profile $jar--admin" "$CMUX_TEST_LOG"
  [ "$(count_log "^browser profiles add ")" -eq 1 ]
  grep -Fxq "browser profiles add $jar--admin" "$CMUX_TEST_LOG"

  run_in "$TEST_PROJECT/project" muximate cmux-browser-open --identity admin https://example.com/second
  [ "$status" -eq 0 ]
  [ "$(count_log "^browser profiles add ")" -eq 1 ]
}

@test "the flag may follow the URL" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  jar=$(folder_jar "$TEST_PROJECT/project")
  run_in "$TEST_PROJECT/project" muximate cmux-browser-open https://example.com --identity admin
  [ "$status" -eq 0 ]
  grep -Fxq "browser open https://example.com --profile $jar--admin" "$CMUX_TEST_LOG"
}

@test "invalid identity slugs are refused before cmux is touched" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  long=$(printf 'a%.0s' $(seq 1 33))
  for slug in A -x '' "$long" 'a b' 'a/../b' 'é' '../work' '--force'; do
    run_in "$TEST_PROJECT/project" muximate cmux-browser-open --identity "$slug" https://example.com
    [ "$status" -eq 2 ]
    [[ "$output" == *'identity'* ]]
  done
  [ ! -s "$CMUX_TEST_LOG" ]
}

@test "a slug with a double dash is valid and kept whole" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  jar=$(folder_jar "$TEST_PROJECT/project")
  run_in "$TEST_PROJECT/project" muximate cmux-browser-open --identity a--b https://example.com
  [ "$status" -eq 0 ]
  grep -Fxq "browser open https://example.com --profile $jar--a--b" "$CMUX_TEST_LOG"
}

@test "URL validation still applies with --identity" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  run_in "$TEST_PROJECT/project" muximate cmux-browser-open --identity admin 'javascript:alert(1)'
  [ "$status" -eq 2 ]
  run_in "$TEST_PROJECT/project" muximate cmux-browser-open --identity admin 'https://user:pw@example.com'
  [ "$status" -eq 2 ]
  [[ "$output" != *pw@* ]]
  [ ! -s "$CMUX_TEST_LOG" ]
}

@test "usage errors: repeated or dangling --identity" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  run_in "$TEST_PROJECT/project" muximate cmux-browser-open --identity https://example.com
  [ "$status" -eq 2 ]
  run_in "$TEST_PROJECT/project" muximate cmux-browser-open --identity a --identity b https://example.com
  [ "$status" -eq 2 ]
  [ ! -s "$CMUX_TEST_LOG" ]
}

@test "baseline folders derive identity jars from the baseline jar" {
  use_stateful_cmux
  muximate baseline work "$TEST_PROJECT" >/dev/null
  reset_cmux_log
  jar=$(folder_jar "$TEST_PROJECT/project")
  [[ "$jar" == work-baseline-* ]]
  run_in "$TEST_PROJECT/project" muximate cmux-browser-open --identity admin https://example.com
  [ "$status" -eq 0 ]
  grep -Fxq "browser open https://example.com --profile $jar--admin" "$CMUX_TEST_LOG"
}

# ---- B. no crossing between profiles --------------------------------------

@test "a slug resembling another profile stays inside the caller namespace" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  jar=$(folder_jar "$TEST_PROJECT/project")
  run_in "$TEST_PROJECT/project" muximate cmux-browser-open --identity "work-$HEX" https://example.com
  [ "$status" -eq 0 ]
  grep -Fxq "browser open https://example.com --profile $jar--work-$HEX" "$CMUX_TEST_LOG"
  ! grep -q -- '--profile work' "$CMUX_TEST_LOG"
}

@test "CMUX_BROWSER_PROFILE never selects the jar for cmux-browser-open" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  jar=$(folder_jar "$TEST_PROJECT/project")
  run_in "$TEST_PROJECT/project" env CMUX_BROWSER_PROFILE="work-$HEX" \
    muximate cmux-browser-open https://example.com
  [ "$status" -eq 0 ]
  [ "$(cat "$CMUX_TEST_LOG")" = "browser open https://example.com --profile $jar" ]
}

@test "CMUX_BROWSER_PROFILE never selects the jar for the BROWSER adapter" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  jar=$(folder_jar "$TEST_PROJECT/project")
  run_in "$TEST_PROJECT/project" env CMUX_BROWSER_PROFILE="work-$HEX" \
    UNAME_BIN="$PROJECT_DIR/tests/fixtures/fake-uname" FAKE_UNAME_SYSTEM=Darwin \
    "$MUXIMATE_ROOT/bin/muximate-cmux-browser" https://example.com
  [ "$status" -eq 0 ]
  [ "$(cat "$CMUX_TEST_LOG")" = "browser open https://example.com --profile $jar" ]
}

@test "the BROWSER adapter refuses a crafted registry row" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  craft_registry_jar "work-$HEX"
  run_in "$TEST_PROJECT/project" env \
    UNAME_BIN="$PROJECT_DIR/tests/fixtures/fake-uname" FAKE_UNAME_SYSTEM=Darwin \
    "$MUXIMATE_ROOT/bin/muximate-cmux-browser" https://example.com
  [ "$status" -ne 0 ]
  [ ! -s "$CMUX_TEST_LOG" ]
}

@test "gh-login ignores a poisoned CMUX_BROWSER_PROFILE" {
  use_stateful_cmux
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  mkdir -p "$TEST_HOME/.config/gh-personal"
  muximate profile-configure personal "$TEST_HOME/.config/gh-personal" "$TEST_PROJECT/project/.ssh/key" >/dev/null
  run_in "$TEST_PROJECT/project" env GH_LOGIN_TEST_MODE=1 GH_LOGIN_GH_BIN="$PROJECT_DIR/tests/fixtures/fake-gh" \
    UNAME_BIN="$PROJECT_DIR/tests/fixtures/fake-uname" FAKE_UNAME_SYSTEM=Darwin \
    CMUX_BROWSER_PROFILE="work-$HEX" GH_TEST_LOG="$TEST_HOME/gh.log" gh-login personal
  [ "$status" -eq 0 ]
  [ "$(sed -n 's/^CMUX_BROWSER_PROFILE=//p' "$TEST_HOME/gh.log")" = "$(folder_jar "$TEST_PROJECT/project")" ]
}

craft_registry_jar() {
  tmp="$TEST_HOME/registry.crafted"
  awk -F '\t' -v OFS='\t' -v j="$1" '{$4 = j} {print}' "$MUXIMATE_ROOT/registry.tsv" >"$tmp"
  mv "$tmp" "$MUXIMATE_ROOT/registry.tsv"
}

@test "a registry row naming another profile's jar is refused everywhere" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  seed_jar "work-$HEX"
  for bad in "work-$HEX" "personal-nothex" "personal-${HEX}x" "personal-baseline-${HEX}-extra" "personal-$HEX--admin"; do
    craft_registry_jar "$bad"
    for cmd in "cmux-browser-open https://example.com" "env" "status" "doctor" "browser-profiles list" "browser-profiles prune --force"; do
      # shellcheck disable=SC2086
      run_in "$TEST_PROJECT/project" muximate $cmd
      [ "$status" -ne 0 ]
    done
  done
  [ ! -s "$CMUX_TEST_LOG" ]
}

@test "folders with spaces and double dashes get well-formed jars" {
  use_stateful_cmux
  odd="$TEST_PROJECT/my--odd dir"
  mkdir -p "$odd"
  init_folder work "$odd"
  jar=$(folder_jar "$odd")
  [[ "$jar" =~ ^work-[0-9a-f]{16}$ ]]
  run_in "$odd" muximate cmux-browser-open --identity admin https://example.com
  [ "$status" -eq 0 ]
  grep -Fxq "browser open https://example.com --profile $jar--admin" "$CMUX_TEST_LOG"
}

@test "a symlinked folder resolves to the real folder's own profile" {
  use_stateful_cmux
  init_folder work "$TEST_PROJECT/project"
  mkdir -p "$TEST_PROJECT/personal"
  init_folder personal "$TEST_PROJECT/personal"
  ln -s "$TEST_PROJECT/project" "$TEST_PROJECT/personal/link"
  work_jar=$(folder_jar "$TEST_PROJECT/project")
  run_in "$TEST_PROJECT/personal/link" muximate cmux-browser-open https://example.com
  [ "$status" -eq 0 ]
  [ "$(cat "$CMUX_TEST_LOG")" = "browser open https://example.com --profile $work_jar" ]
}

@test "a folder nested under the other profile's baseline never gets the caller's jar" {
  use_stateful_cmux
  mkdir -p "$TEST_PROJECT/personal"
  init_folder personal "$TEST_PROJECT/personal"
  muximate baseline work "$TEST_PROJECT/project" >/dev/null
  mkdir -p "$TEST_PROJECT/project/nested"
  run_in "$TEST_PROJECT/project/nested" muximate cmux-browser-open https://example.com
  [ "$status" -eq 0 ]
  grep -q -- '--profile work-baseline-' "$CMUX_TEST_LOG"
  ! grep -q -- '--profile personal' "$CMUX_TEST_LOG"
}

seed_both_profiles() {
  mkdir -p "$TEST_PROJECT/personal"
  init_folder personal "$TEST_PROJECT/personal"
  init_folder work "$TEST_PROJECT/project"
  seed_jar "personal-$HEX" "personal-$HEX2--old" "work-$HEX" "work-baseline-$HEX2" "work-$HEX--admin"
}

@test "list, clear and prune from a work shell never see personal jars (and vice versa)" {
  use_stateful_cmux
  seed_both_profiles
  work_jar=$(folder_jar "$TEST_PROJECT/project")
  personal_jar=$(folder_jar "$TEST_PROJECT/personal")

  run_in "$TEST_PROJECT/project" muximate browser-profiles list
  [ "$status" -eq 0 ]
  [[ "$output" != *personal* ]]
  [[ "$output" == *"$work_jar"* ]]

  run_in "$TEST_PROJECT/personal" muximate browser-profiles list
  [ "$status" -eq 0 ]
  [[ "$output" != *work* ]]

  run_in "$TEST_PROJECT/project" muximate browser-profiles prune --force
  [ "$status" -eq 0 ]
  jar_names | grep -Fxq "personal-$HEX"
  jar_names | grep -Fxq "personal-$HEX2--old"
  jar_names | grep -Fxq "$personal_jar"
  ! jar_names | grep -Fxq "work-baseline-$HEX2"

  run_in "$TEST_PROJECT/personal" muximate browser-profiles prune --force
  [ "$status" -eq 0 ]
  jar_names | grep -Fxq "work-$HEX--admin" || jar_names | grep -Fxq "$work_jar"
  ! jar_names | grep -Fxq "personal-$HEX"
  ! grep -q 'clear --all' "$CMUX_TEST_LOG"
}

@test "clear is scoped to the current folder's identity jar" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  jar=$(folder_jar "$TEST_PROJECT/project")
  seed_jar "$jar--admin" "work-$HEX--admin"
  run_in "$TEST_PROJECT/project" muximate browser-profiles clear --identity admin --force
  [ "$status" -eq 0 ]
  grep -Fxq "browser profiles clear $jar--admin" "$CMUX_TEST_LOG"
  [ "$(count_log "clear")" -eq 1 ]
  [ "$(cat "$CMUX_TEST_STATE.cleared")" = "$jar--admin" ]
}

# ---- C. concurrency --------------------------------------------------------

@test "two folders of one profile resolve to two different default jars" {
  use_stateful_cmux
  mkdir -p "$TEST_PROJECT/second"
  init_folder personal "$TEST_PROJECT/project"
  init_folder personal "$TEST_PROJECT/second"
  run_in "$TEST_PROJECT/project" muximate cmux-browser-open https://example.com
  run_in "$TEST_PROJECT/second" muximate cmux-browser-open https://example.com
  [ "$(sed -n 1p "$CMUX_TEST_LOG" | awk '{print $NF}')" != "$(sed -n 2p "$CMUX_TEST_LOG" | awk '{print $NF}')" ]
}

@test "same folder: default shared, identities separate, no extra add (serial and parallel)" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  jar=$(folder_jar "$TEST_PROJECT/project")
  for round in 1 2; do
    (cd "$TEST_PROJECT/project" && muximate cmux-browser-open --identity a https://example.com/a) 3>&- &
    (cd "$TEST_PROJECT/project" && muximate cmux-browser-open --identity a https://example.com/a2) 3>&- &
    (cd "$TEST_PROJECT/project" && muximate cmux-browser-open --identity b https://example.com/b) 3>&- &
    (cd "$TEST_PROJECT/project" && muximate cmux-browser-open https://example.com/d) 3>&- &
    wait
  done
  [ "$(count_log "^browser profiles add $jar--a\$")" -eq 1 ]
  [ "$(count_log "^browser profiles add $jar--b\$")" -eq 1 ]
  [ "$(count_log "^browser profiles add ")" -eq 2 ]
  grep -Fq -- "--profile $jar--a" "$CMUX_TEST_LOG"
  grep -Fq -- "--profile $jar--b" "$CMUX_TEST_LOG"
  grep -Eq -- "--profile $jar\$" "$CMUX_TEST_LOG"
}

# ---- D. list ---------------------------------------------------------------

@test "list classifies every kind and hides UUIDs" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  jar=$(folder_jar "$TEST_PROJECT/project")
  mkdir -p "$TEST_PROJECT/baseline-root"
  muximate baseline personal "$TEST_PROJECT/baseline-root" >/dev/null
  base_jar=$(folder_jar "$TEST_PROJECT/baseline-root")
  seed_jar "$jar--admin" "personal-$HEX2--gone" "personal-$HEX" "personal-baseline-$HEX2" \
    personal-baseline-aydabd personal "work-$HEX"
  "$CMUX_BIN" browser open https://x --profile "$jar" >/dev/null

  run_in "$TEST_PROJECT/project" muximate browser-profiles list
  [ "$status" -eq 0 ]
  tab=$(printf '\t')
  folder=$(cd "$TEST_PROJECT/project" && pwd -P)
  basef=$(cd "$TEST_PROJECT/baseline-root" && pwd -P)
  [[ "$output" == *"$jar${tab}folder-default${tab}$folder${tab}(last used)"* ]]
  [[ "$output" == *"$jar--admin${tab}identity${tab}$folder${tab}-"* ]]
  [[ "$output" == *"$base_jar${tab}folder-default${tab}$basef${tab}-"* ]]
  [[ "$output" == *"personal-$HEX2--gone${tab}orphan${tab}-${tab}-"* ]]
  [[ "$output" == *"personal-$HEX${tab}orphan${tab}-${tab}-"* ]]
  [[ "$output" == *"personal-baseline-$HEX2${tab}legacy-baseline${tab}-${tab}-"* ]]
  [[ "$output" == *"personal-baseline-aydabd${tab}unmanaged${tab}-${tab}-"* ]]
  [[ "$output" == *"personal${tab}unmanaged${tab}-${tab}-"* ]]
  [[ "$output" != *work* ]]
  [[ "$output" != *Default* ]]
  [[ ! "$output" =~ [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4} ]]
}

@test "list --all adds read-only not-yours rows" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  seed_jar "work-$HEX"
  run_in "$TEST_PROJECT/project" muximate browser-profiles list --all
  [ "$status" -eq 0 ]
  tab=$(printf '\t')
  [[ "$output" == *"work-$HEX${tab}not-yours${tab}-${tab}-"* ]]
  [[ "$output" == *"Default${tab}not-yours${tab}-${tab}(default)"* ]]
  [[ ! "$output" =~ [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4} ]]
}

@test "list degrades clearly when cmux is unavailable" {
  muximate init personal "$TEST_PROJECT/project" >/dev/null
  run_in "$TEST_PROJECT/project" env CMUX_BIN=/nonexistent muximate browser-profiles list
  [ "$status" -ne 0 ]
  [[ "$output" == *'cmux command is missing or not executable'* ]]
}

# ---- E. cleanup ------------------------------------------------------------

@test "clear without --force prints what it would do and exits non-zero" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  jar=$(folder_jar "$TEST_PROJECT/project")
  seed_jar "$jar--admin"
  run_in "$TEST_PROJECT/project" muximate browser-profiles clear --identity admin
  [ "$status" -ne 0 ]
  [[ "$output" == *"$jar--admin"* ]]
  [ ! -e "$CMUX_TEST_STATE.cleared" ]
}

@test "clear refuses the folder default unless --default is given" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  jar=$(folder_jar "$TEST_PROJECT/project")
  run_in "$TEST_PROJECT/project" muximate browser-profiles clear --force
  [ "$status" -ne 0 ]
  [ ! -e "$CMUX_TEST_STATE.cleared" ]
  run_in "$TEST_PROJECT/project" muximate browser-profiles clear --default --force
  [ "$status" -eq 0 ]
  [ "$(cat "$CMUX_TEST_STATE.cleared")" = "$jar" ]
}

@test "clear rejects bad slugs, missing jars, and never emits --all" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  run_in "$TEST_PROJECT/project" muximate browser-profiles clear --identity --all --force
  [ "$status" -eq 2 ]
  run_in "$TEST_PROJECT/project" muximate browser-profiles clear --identity nothere --force
  [ "$status" -ne 0 ]
  ! grep -q -- '--all' "$CMUX_TEST_LOG"
  [ ! -e "$CMUX_TEST_STATE.cleared" ]
}

@test "prune dry run lists orphans and deletes nothing; --force deletes exactly those" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  jar=$(folder_jar "$TEST_PROJECT/project")
  seed_jar "$jar--admin" "personal-$HEX" "personal-$HEX2--gone" "personal-baseline-$HEX2" \
    personal-baseline-aydabd personal "work-$HEX" "work-baseline-$HEX2"
  before=$(jar_names | sort)
  reset_cmux_log

  run_in "$TEST_PROJECT/project" muximate browser-profiles prune
  [ "$status" -eq 0 ]
  [[ "$output" == *"personal-$HEX"* ]]
  [[ "$output" == *"personal-$HEX2--gone"* ]]
  [[ "$output" == *"personal-baseline-$HEX2"* ]]
  [[ "$output" == *'deleted: 0'* ]]
  [[ "$output" == *'kept:'* ]]
  [ "$(jar_names | sort)" = "$before" ]
  [ "$(count_log "profiles delete")" -eq 0 ]

  run_in "$TEST_PROJECT/project" muximate browser-profiles prune --force
  [ "$status" -eq 0 ]
  [[ "$output" == *'deleted: 3'* ]]
  after=$(jar_names)
  for keep in Default "$jar" "$jar--admin" personal-baseline-aydabd personal "work-$HEX" "work-baseline-$HEX2"; do
    printf '%s\n' "$after" | grep -Fxq "$keep"
  done
  for gone in "personal-$HEX" "personal-$HEX2--gone" "personal-baseline-$HEX2"; do
    ! printf '%s\n' "$after" | grep -Fxq "$gone"
  done
  ! grep -q -- '--all' "$CMUX_TEST_LOG"
}

@test "prune never deletes the jar cmux marks last used" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  seed_jar "personal-$HEX"
  "$CMUX_BIN" browser open https://x --profile "personal-$HEX" >/dev/null
  run_in "$TEST_PROJECT/project" muximate browser-profiles prune --force
  [ "$status" -eq 0 ]
  [[ "$output" == *'deleted: 0'* ]]
  jar_names | grep -Fxq "personal-$HEX"
}

@test "running init, open and env repeatedly in one folder never mints extra jars" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  muximate init personal "$TEST_PROJECT/project" >/dev/null 2>&1 || true
  for i in 1 2 3 4 5; do
    run_in "$TEST_PROJECT/project" muximate cmux-browser-open --identity admin https://example.com
    run_in "$TEST_PROJECT/project" muximate env
    run_in "$TEST_PROJECT/project" muximate cmux-config
    run_in "$TEST_PROJECT/project" muximate doctor
  done
  [ "$(count_log "^browser profiles add ")" -eq 1 ]
  [ "$(jar_names | wc -l | tr -d ' ')" -eq 3 ]
}

# ---- G. doctor -------------------------------------------------------------

@test "doctor reports folder jar presence and orphan count" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  jar=$(folder_jar "$TEST_PROJECT/project")
  seed_jar "personal-$HEX" "personal-$HEX2"
  run_in "$TEST_PROJECT/project" muximate doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *'cmux_folder_profile: present'* ]]
  [[ "$output" == *'orphan_profiles: 2'* ]]
  [[ "$output" == *'run: muximate browser-profiles prune'* ]]

  "$CMUX_BIN" browser profiles delete "$jar" >/dev/null
  run_in "$TEST_PROJECT/project" muximate doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *'cmux_folder_profile: missing'* ]]
}

@test "doctor stays successful with no orphans and when cmux is unavailable" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  run_in "$TEST_PROJECT/project" muximate doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *'orphan_profiles: 0'* ]]
  [[ "$output" != *'run: muximate browser-profiles prune'* ]]

  run_in "$TEST_PROJECT/project" env CMUX_BIN=/nonexistent muximate doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *'cmux: unavailable'* ]]
}

# ---- output hygiene --------------------------------------------------------

@test "browser-profiles help text and unknown subcommands" {
  use_stateful_cmux
  init_folder personal "$TEST_PROJECT/project"
  run_in "$TEST_PROJECT/project" muximate browser-profiles bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *'usage: muximate browser-profiles list'* ]]
  [ ! -s "$CMUX_TEST_LOG" ]
  run muximate help
  [[ "$output" == *'--identity'* ]]
  [[ "$output" == *'browser-profiles list'* ]]
}
