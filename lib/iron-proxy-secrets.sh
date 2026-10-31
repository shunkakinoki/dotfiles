secrets_dir="@secretsDir@"
proxy_user="@proxyUser@"
names="@names@"

usage() {
  echo "usage: sudo iron-proxy-secrets [sync|off]" >&2
  exit 2
}

if [ "$(id -u)" -ne 0 ] || [ -z "${SUDO_USER:-}" ]; then
  echo "error: run with sudo from the account logged in to Doppler" >&2
  exit 1
fi

[ -L "$secrets_dir" ] && rm -f "$secrets_dir"
install -d -o root -m 0755 "$secrets_dir"

case "${1:-sync}" in
sync)
  trap 'rm -f "$secrets_dir"/.*.tmp' EXIT
  # Every value is staged before any is committed, so a failed read leaves
  # the previous set intact.
  for name in $names; do
    tmp="$secrets_dir/.$name.tmp"
    # Doppler runs as the user for their login. Command substitution drops
    # the trailing newline, which the proxy would otherwise send verbatim.
    if ! value="$(sudo -u "$SUDO_USER" -H doppler secrets get "$name" --project dotfiles --config prd --plain)"; then
      echo "error: could not read $name from Doppler" >&2
      exit 1
    fi
    if [ -z "$value" ]; then
      echo "error: $name is empty in Doppler" >&2
      exit 1
    fi
    (umask 077 && printf '%s' "$value" >"$tmp")
    chown "root:$proxy_user" "$tmp"
    chmod 0640 "$tmp"
  done
  unset value
  for name in $names; do
    mv -f "$secrets_dir/.$name.tmp" "$secrets_dir/$name"
  done
  # Written last: shells swap in placeholders only once every value is in place.
  printf '%s\n' $names >"$secrets_dir/.swap-keys.tmp"
  chmod 0644 "$secrets_dir/.swap-keys.tmp"
  mv -f "$secrets_dir/.swap-keys.tmp" "$secrets_dir/swap-keys"
  echo "swapping: $names (new shells pick it up)"
  ;;
off)
  rm -f "$secrets_dir/swap-keys"
  for name in $names; do
    rm -f "$secrets_dir/$name"
  done
  echo "swap disabled (new shells get the real values)"
  ;;
*) usage ;;
esac
