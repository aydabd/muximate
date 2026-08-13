# Generic Oh My Zsh adapter for muximate.
# It does not install tools, modify credentials, or overwrite .zshrc.

autoload -U add-zsh-hook

_muximate_prioritize_wrappers() {
  local item
  local -a keep
  for item in $path; do
    case "$item" in
      "$HOME/.config/muximate/bin"|"$HOME/.config/muximate-gh/bin") ;;
      *) keep+=("$item");;
    esac
  done
  path=("$HOME/.config/muximate/bin" "$HOME/.config/muximate-gh/bin" "${keep[@]}")
}

_muximate_apply() {
  if [[ -x "$HOME/.config/muximate/bin/muximate" ]]; then
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
