load test_helper

# Use a real jq, never a version-manager shim that would read the swapped HOME.
use_real_jq() {
  mkdir -p "$TEST_HOME/jq-bin"
  for candidate in $(which -a jq 2>/dev/null); do
    case "$candidate" in */shims/*) continue ;; esac
    ln -sf "$candidate" "$TEST_HOME/jq-bin/jq"
    break
  done
  [ -e "$TEST_HOME/jq-bin/jq" ] || skip "jq is not installed"
  export PATH="$TEST_HOME/jq-bin:$PATH"
}

shared_fixture() {
  use_real_jq
  SHARED="$MUXIMATE_ROOT/shared"
  WORK="$MUXIMATE_ROOT/accounts/work"
  PERSONAL="$MUXIMATE_ROOT/accounts/personal"
  mkdir -p "$SHARED/claude" "$SHARED/codex" "$SHARED/copilot/hooks" "$WORK/claude"
  cat >"$SHARED/claude/settings.json" <<'EOF'
{
  "hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "tokf hook handle"}]}]},
  "enabledPlugins": {"caveman@caveman": true},
  "statusLine": {"type": "command", "command": "shared-status"}
}
EOF
  printf '%s\n' '{"enabledPlugins": {"caveman@caveman": false, "work-only@corp": true}, "theme": "dark"}' \
    >"$WORK/claude/settings.json"
  printf '%s\n' '# Shared guidance' '- prefer sem over reading whole files' >"$SHARED/AGENTS.md"
  printf '%s\n' '[[hooks.PostToolUse]]' 'matcher = "Edit"' '' '[[hooks.PostToolUse.hooks]]' \
    'type = "command"' 'command = "semgrep-check"' >"$SHARED/codex/config.toml"
  printf '%s\n' '{"version": 1, "hooks": {"postToolUse": [{"type": "command", "bash": "semgrep-check"}]}}' \
    >"$SHARED/copilot/hooks/security.json"
}

@test "applies the shared layer to Claude, Codex, and Copilot in both profiles" {
  shared_fixture

  run muximate agent-shared-sync all
  [ "$status" -eq 0 ]
  for profile_root in "$WORK" "$PERSONAL"; do
    jq -e '.hooks.PreToolUse[0].hooks[0].command == "tokf hook handle"' "$profile_root/claude/settings.json"
    grep -Fxq "@$SHARED/AGENTS.md" "$profile_root/claude/CLAUDE.md"
    ! grep -Fq 'prefer sem' "$profile_root/claude/CLAUDE.md"
    grep -Fq 'prefer sem' "$profile_root/codex/AGENTS.md"
    [ ! -e "$profile_root/copilot/copilot-instructions.md" ]
    grep -Fq 'command = "semgrep-check"' "$profile_root/codex/config.toml"
    [ -f "$profile_root/copilot/hooks/muximate-shared-security.json" ]
  done
  head -n 1 "$WORK/codex/config.toml" | grep -Fq 'cli_auth_credentials_store = "file"'
  echo "# evidence: Claude imports the one AGENTS.md, Codex gets the only copy"
}

@test "env points Copilot at the shared AGENTS.md only when it exists" {
  muximate init work "$TEST_PROJECT/project" >/dev/null

  run muximate env "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [[ "$output" != *'export COPILOT_CUSTOM_INSTRUCTIONS_DIRS'* ]]
  [[ "$output" == *'unset '*' COPILOT_CUSTOM_INSTRUCTIONS_DIRS '* ]]

  mkdir -p "$MUXIMATE_ROOT/shared"
  printf '%s\n' '# Shared guidance' >"$MUXIMATE_ROOT/shared/AGENTS.md"
  run muximate env "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [[ "$output" == *"export COPILOT_CUSTOM_INSTRUCTIONS_DIRS='$MUXIMATE_ROOT/shared'"* ]]
}

@test "profile values win and profile-only plugins stay in their profile" {
  shared_fixture

  run muximate agent-shared-sync all
  [ "$status" -eq 0 ]
  [[ "$output" == *'work: profile keeps its own Claude value for enabledPlugins.caveman@caveman'* ]]
  jq -e '.enabledPlugins == {"caveman@caveman": false, "work-only@corp": true}' "$WORK/claude/settings.json"
  jq -e '.enabledPlugins == {"caveman@caveman": true}' "$PERSONAL/claude/settings.json"
  ! grep -Fq 'work-only@corp' "$PERSONAL/claude/settings.json"
  echo "# evidence: work opt-out and work-only plugin never reached personal"
}

@test "a second sync changes nothing and the check reports in sync" {
  shared_fixture
  muximate agent-shared-sync all >/dev/null
  before=$(cat "$WORK/claude/settings.json" "$WORK/codex/config.toml" "$WORK/claude/CLAUDE.md")

  run muximate agent-shared-sync all
  [ "$status" -eq 0 ]
  [[ "$output" != *'updated:'* ]]
  [ "$(cat "$WORK/claude/settings.json" "$WORK/codex/config.toml" "$WORK/claude/CLAUDE.md")" = "$before" ]
  [ "$(grep -c 'BEGIN muximate shared' "$WORK/codex/config.toml")" -eq 1 ]

  run muximate agent-shared-sync --check all
  [ "$status" -eq 0 ]
  [[ "$output" == *'shared agent layer: in sync'* ]]
}

@test "the check reports drift without writing" {
  shared_fixture

  run muximate agent-shared-sync --check work
  [ "$status" -ne 0 ]
  [[ "$output" == *'out of date'* ]]
  jq -e '. == {"enabledPlugins": {"caveman@caveman": false, "work-only@corp": true}, "theme": "dark"}' \
    "$WORK/claude/settings.json"
  [ ! -e "$WORK/codex/AGENTS.md" ]
}

@test "removing shared entries removes only what the sync added" {
  shared_fixture
  muximate agent-shared-sync all >/dev/null
  rm "$SHARED/claude/settings.json" "$SHARED/codex/config.toml" "$SHARED/copilot/hooks/security.json"
  rm "$SHARED/AGENTS.md"

  run muximate agent-shared-sync work
  [ "$status" -eq 0 ]
  jq -e '. == {"enabledPlugins": {"caveman@caveman": false, "work-only@corp": true}, "theme": "dark"}' \
    "$WORK/claude/settings.json"
  [ ! -e "$WORK/claude/.muximate-shared-settings.json" ]
  [ ! -e "$WORK/copilot/hooks/muximate-shared-security.json" ]
  ! grep -Fq 'muximate shared' "$WORK/codex/config.toml"
  ! grep -Fq 'muximate shared' "$WORK/claude/CLAUDE.md"
  ! grep -Fq 'muximate shared' "$WORK/codex/AGENTS.md"
  echo "# evidence: profile settings restored exactly after shared removal"
}

@test "keeps profile hooks that match nothing in the shared layer" {
  shared_fixture
  printf '%s\n' '{"hooks": {"PreToolUse": [{"matcher": "Read", "hooks": [{"type": "command", "command": "work-hook"}]}]}}' \
    >"$WORK/claude/settings.json"
  muximate agent-shared-sync work >/dev/null
  jq -e '.hooks.PreToolUse | length == 2' "$WORK/claude/settings.json"
  rm "$SHARED/claude/settings.json"

  muximate agent-shared-sync work >/dev/null
  jq -e '.hooks.PreToolUse == [{"matcher": "Read", "hooks": [{"type": "command", "command": "work-hook"}]}]' \
    "$WORK/claude/settings.json"
}

@test "rejects shared settings that configure credentials or environment" {
  shared_fixture
  for bad in '{"env": {"X": "1"}}' '{"apiKeyHelper": "x"}' '{"forceLoginMethod": "claudeai"}' \
    '{"mcpServers": {"x": {"headers": {"A": "b"}}}}'; do
    printf '%s\n' "$bad" >"$SHARED/claude/settings.json"
    run muximate agent-shared-sync work
    [ "$status" -ne 0 ]
    [[ "$output" == *'must not configure credentials, login, or env'* ]]
  done
  [ ! -e "$WORK/claude/.muximate-shared-settings.json" ]
  [ ! -e "$WORK/codex/AGENTS.md" ]
  echo "# evidence: credential-like shared keys fail before any profile write"
}

@test "rejects shared Codex config with top-level keys or credential tables" {
  shared_fixture
  printf '%s\n' 'model = "x"' >"$SHARED/codex/config.toml"
  run muximate agent-shared-sync work
  [ "$status" -ne 0 ]
  [[ "$output" == *'[tables] only'* ]]

  printf '%s\n' '[mcp_servers.x.env]' 'A = "b"' >"$SHARED/codex/config.toml"
  run muximate agent-shared-sync work
  [ "$status" -ne 0 ]
  [[ "$output" == *'must not configure credentials, login, or env'* ]]

  printf '%s\n' '[mcp_servers.x]' 'bearer_token_env_var = "T"' >"$SHARED/codex/config.toml"
  run muximate agent-shared-sync work
  [ "$status" -ne 0 ]
}

@test "rejects a Codex table defined by both the shared layer and the profile" {
  shared_fixture
  printf '%s\n' '[mcp_servers.sem]' 'command = "sem"' >"$SHARED/codex/config.toml"
  mkdir -p "$WORK/codex"
  printf '%s\n' 'cli_auth_credentials_store = "file"' '[mcp_servers.sem]' 'command = "other"' >"$WORK/codex/config.toml"

  run muximate agent-shared-sync work
  [ "$status" -ne 0 ]
  [[ "$output" == *'both define [mcp_servers.sem]'* ]]
  ! grep -Fq 'muximate shared' "$WORK/codex/config.toml"
}

@test "rejects symbolic links in the shared layer and profile targets" {
  shared_fixture
  mv "$SHARED/AGENTS.md" "$TEST_HOME/real.md"
  ln -s "$TEST_HOME/real.md" "$SHARED/AGENTS.md"
  run muximate agent-shared-sync work
  [ "$status" -ne 0 ]
  [[ "$output" == *'shared agent file must not be a symbolic link'* ]]

  rm "$SHARED/AGENTS.md"
  mkdir -p "$WORK/codex"
  ln -s "$TEST_HOME/elsewhere" "$WORK/codex/AGENTS.md"
  run muximate agent-shared-sync work
  [ "$status" -ne 0 ]
  [[ "$output" == *'profile agent file must not be a symbolic link'* ]]
  [ ! -e "$TEST_HOME/elsewhere" ]
}

@test "rejects an invalid shared sync profile" {
  run muximate agent-shared-sync shared
  [ "$status" -ne 0 ]
  [[ "$output" == *'usage: muximate agent-shared-sync [--check] personal|work|all'* ]]
}

@test "doctor reports the shared layer state" {
  shared_fixture
  muximate init work "$TEST_PROJECT/project" >/dev/null

  run muximate doctor "$TEST_PROJECT/project"
  [ "$status" -eq 0 ]
  [[ "$output" == *'agent_shared_layer: out of date'* ]]

  muximate agent-shared-sync work >/dev/null
  run muximate doctor "$TEST_PROJECT/project"
  [[ "$output" == *'agent_shared_layer: in sync'* ]]
}

@test "profile AGENTS.md reaches only its own profile, after the shared one" {
  shared_fixture
  mkdir -p "$WORK/agents"
  printf '%s\n' '- work-only rule' >"$WORK/agents/AGENTS.md"

  run muximate agent-shared-sync all
  [ "$status" -eq 0 ]
  [ "$(grep '^@' "$WORK/claude/CLAUDE.md")" = "$(printf '@%s\n@%s' "$SHARED/AGENTS.md" "$WORK/agents/AGENTS.md")" ]
  [ "$(grep '^@' "$PERSONAL/claude/CLAUDE.md")" = "@$SHARED/AGENTS.md" ]
  grep -Fq 'work-only rule' "$WORK/codex/AGENTS.md"
  ! grep -Fq 'work-only rule' "$PERSONAL/codex/AGENTS.md"
  shared_line=$(grep -n 'prefer sem' "$WORK/codex/AGENTS.md" | cut -d: -f1)
  work_line=$(grep -n 'work-only rule' "$WORK/codex/AGENTS.md" | cut -d: -f1)
  [ "$shared_line" -lt "$work_line" ]
  echo "# evidence: work instructions never reached personal"
}

@test "profile AGENTS.md works without a shared AGENTS.md and is removed with it" {
  use_real_jq
  mkdir -p "$MUXIMATE_ROOT/accounts/personal/agents"
  printf '%s\n' '- personal-only rule' >"$MUXIMATE_ROOT/accounts/personal/agents/AGENTS.md"

  run muximate agent-shared-sync personal
  [ "$status" -eq 0 ]
  grep -Fxq "@$MUXIMATE_ROOT/accounts/personal/agents/AGENTS.md" "$MUXIMATE_ROOT/accounts/personal/claude/CLAUDE.md"
  grep -Fq 'personal-only rule' "$MUXIMATE_ROOT/accounts/personal/codex/AGENTS.md"

  rm "$MUXIMATE_ROOT/accounts/personal/agents/AGENTS.md"
  run muximate agent-shared-sync personal
  [ "$status" -eq 0 ]
  ! grep -Fq 'muximate shared' "$MUXIMATE_ROOT/accounts/personal/claude/CLAUDE.md"
  ! grep -Fq 'personal-only rule' "$MUXIMATE_ROOT/accounts/personal/codex/AGENTS.md"
}

@test "env gives Copilot the shared and the active profile's AGENTS.md only" {
  muximate init work "$TEST_PROJECT/project" >/dev/null
  mkdir -p "$TEST_PROJECT/other"
  muximate init personal "$TEST_PROJECT/other" >/dev/null
  mkdir -p "$MUXIMATE_ROOT/shared" "$MUXIMATE_ROOT/accounts/work/agents"
  printf '%s\n' '# Shared' >"$MUXIMATE_ROOT/shared/AGENTS.md"
  printf '%s\n' '# Work' >"$MUXIMATE_ROOT/accounts/work/agents/AGENTS.md"

  run muximate env "$TEST_PROJECT/project"
  [[ "$output" == *"export COPILOT_CUSTOM_INSTRUCTIONS_DIRS='$MUXIMATE_ROOT/shared,$MUXIMATE_ROOT/accounts/work/agents'"* ]]
  run muximate env "$TEST_PROJECT/other"
  [[ "$output" == *"export COPILOT_CUSTOM_INSTRUCTIONS_DIRS='$MUXIMATE_ROOT/shared'"* ]]
}

@test "rejects a symbolic link as the profile agents directory or file" {
  shared_fixture
  mkdir -p "$TEST_HOME/elsewhere"
  ln -s "$TEST_HOME/elsewhere" "$WORK/agents"
  run muximate agent-shared-sync work
  [ "$status" -ne 0 ]
  [[ "$output" == *'profile agents directory must not be a symbolic link'* ]]

  rm "$WORK/agents"
  mkdir -p "$WORK/agents"
  ln -s "$TEST_HOME/elsewhere/x.md" "$WORK/agents/AGENTS.md"
  run muximate agent-shared-sync work
  [ "$status" -ne 0 ]
  [[ "$output" == *'must not be a symbolic link'* ]]
}
