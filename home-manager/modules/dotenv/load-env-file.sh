# shellcheck shell=sh
# Sourced by bash and zsh; the fish counterpart lives in
# home-manager/programs/fish/functions/_hm_load_env_file.fish. Both only apply
# what print-env-file.sh emits.

_hm_load_env_file() {
  _hm_printer="${HM_PRINT_ENV_FILE:-$HOME/.config/shell/print-env-file.sh}"

  if [ ! -f "$_hm_printer" ]; then
    unset _hm_printer
    return 0
  fi

  while IFS= read -r _hm_assignment; do
    case "$_hm_assignment" in
    *=*) ;;
    *) continue ;;
    esac

    _hm_key="${_hm_assignment%%=*}"
    _hm_value="${_hm_assignment#*=}"
    export "${_hm_key}=${_hm_value}"
  done <<EOF
$(sh "$_hm_printer")
EOF

  unset _hm_printer _hm_assignment _hm_key _hm_value
  return 0
}
