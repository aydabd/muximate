# Generic Oh My Zsh adapter for muximate.
# It does not install tools, modify credentials, or overwrite .zshrc.

autoload -U add-zsh-hook

_MUXIMATE_ROOT="${MUXIMATE_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/muximate}"

# Capture the user's original right prompt once.  Re-sourcing .zshrc must not
# treat muximate's own status segment as the new prompt base.
if ((!${+_MUXIMATE_RPROMPT_BASE_INITIALIZED})); then
  typeset -g _MUXIMATE_RPROMPT_BASE="${RPROMPT:-}"
  typeset -g _MUXIMATE_RPROMPT_BASE_INITIALIZED=1
elif [[ "${_MUXIMATE_RPROMPT_BASE:-}" == *profile:* ]]; then
  # Recover shells that loaded an older adapter, whose base already contains
  # muximate's rendered status segment.
  typeset -g _MUXIMATE_RPROMPT_BASE=""
fi

_muximate_prioritize_wrappers() {
  local item
  local -a keep
  for item in $path; do
    case "$item" in
      "$_MUXIMATE_ROOT/bin") ;;
      *) keep+=("$item") ;;
    esac
  done
  path=("$_MUXIMATE_ROOT/bin" "${keep[@]}")
}

_muximate_apply() {
  if [[ -x "$_MUXIMATE_ROOT/bin/muximate" ]]; then
    unset MUXIMATE MUXIMATE_PATH CMUX_BROWSER_PROFILE MISE_ENABLED MISE_STATUS MISE_GLOBAL_CONFIG_FILE AWS_PROFILE KUBECONFIG MUXIMATE_STATUS
    eval "$(muximate env 2>/dev/null || true)"
    if [[ "${MISE_ENABLED:-0}" != 1 ]]; then
      _muximate_remove_mise 2>/dev/null || true
    elif (($+commands[mise])); then
      eval "$(MISE_SAFE=1 mise hook-env -s zsh 2>/dev/null || true)"
      _muximate_prioritize_mise 2>/dev/null || true
      _muximate_prioritize_wrappers
      rehash 2>/dev/null || true
    fi
  fi
}

_muximate_prompt_status() {
  local profile_status="${MUXIMATE_STATUS:-uninitialized}"
  RPROMPT="${_MUXIMATE_RPROMPT_BASE:-} %F{cyan}[${profile_status}]%f"
}

# Explicitly replace our hooks so sourcing .zshrc remains idempotent even when
# a shell framework reloads custom files.
add-zsh-hook -d chpwd _muximate_apply 2>/dev/null || true
add-zsh-hook -d precmd _muximate_prompt_status 2>/dev/null || true
add-zsh-hook chpwd _muximate_apply
add-zsh-hook precmd _muximate_prompt_status
_muximate_apply
