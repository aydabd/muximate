# Generic Oh My Zsh adapter for muximate.
# It does not install tools, modify credentials, or overwrite .zshrc.

autoload -U add-zsh-hook

_MUXIMATE_ROOT="${MUXIMATE_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/muximate}"

_muximate_prioritize_wrappers() {
  local item
  local -a keep
  for item in $path; do
    case "$item" in
      "$_MUXIMATE_ROOT/bin"|"$HOME/.config/workspace-profiles/bin"|"$HOME/.config/gh-directory-profiles-staged/bin") ;;
      *) keep+=("$item");;
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
    elif (( $+commands[mise] )); then
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

add-zsh-hook chpwd _muximate_apply
add-zsh-hook precmd _muximate_prompt_status
_muximate_apply
typeset -g _MUXIMATE_RPROMPT_BASE="${RPROMPT:-}"
