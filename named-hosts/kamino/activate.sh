#!/usr/bin/env bash
# Small activation phases keep identity checks before the write boundary.
set -euo pipefail

case "${1:?activation phase required}" in
check)
  name="${2:?name required}"
  identity="${3:?identity file required}"
  if [ "$(id -u)" != 0 ] || [ "$(cat /proc/1/comm)" != systemd ]; then
    echo "Kamino requires root on a systemd Linux machine." >&2
    exit 1
  fi
  if [ -f "$identity" ] && [ "$(cat "$identity")" != "$name" ]; then
    echo "Refusing to rename an installed Kamino machine." >&2
    exit 1
  fi
  ;;
prepare)
  mkdir -p /etc/sudoers.d
  ;;
root-nodiscard)
  # Online discard issues a TRIM on every delete, so worktree and scratch-tree
  # churn stalls the root disk; the distro's periodic fstrim reclaims the same
  # blocks in batches instead.
  fstab="${2:?fstab file required}"
  root_line='^[^#[:space:]]+[[:space:]]+/[[:space:]]'
  if grep -Eq "$root_line.*[[:space:],]discard([,[:space:]]|$)" "$fstab"; then
    updated=$(sed -E "\\%$root_line% s/([[:space:],])discard([,[:space:]]|$)/\1nodiscard\2/" "$fstab")
    printf '%s\n' "$updated" >"$fstab"
    echo "Set nodiscard on the root filesystem in $fstab."
  fi
  if findmnt -no OPTIONS / | tr , '\n' | grep -qx discard; then
    mount -o remount,nodiscard /
    echo "Remounted the root filesystem with nodiscard."
  fi
  ;;
trim-schedule)
  hourly="${2:?hourly trim path required}"
  service_dropin="${3:?fstrim service drop-in required}"
  timer_dropin="${4:?fstrim timer drop-in required}"
  idle_script="${5:?trim pressure condition required}"
  # Keep the file for package ownership, but run-parts must no longer execute it.
  if [ -f "$hourly" ]; then chmod a-x "$hourly"; fi
  mkdir -p "$(dirname "$service_dropin")" "$(dirname "$timer_dropin")"
  service_changed=false
  service_content=$(printf '[Service]\nNice=19\nIOSchedulingClass=idle\nIOWeight=1\nExecCondition=/bin/bash %s\n' "$idle_script")
  if [ ! -f "$service_dropin" ] || [ "$(cat "$service_dropin")" != "$service_content" ]; then
    printf '%s\n' "$service_content" >"$service_dropin"
    service_changed=true
  fi
  # An offline worker does not run catch-up trim when its fleet work resumes.
  timer_content=$'[Timer]\nOnCalendar=\nOnCalendar=weekly\nRandomizedDelaySec=6h\nFixedRandomDelay=true\nPersistent=false'
  timer_changed=false
  if [ ! -f "$timer_dropin" ] || [ "$(cat "$timer_dropin")" != "$timer_content" ]; then
    printf '%s\n' "$timer_content" >"$timer_dropin"
    timer_changed=true
  fi
  if "$service_changed" || "$timer_changed"; then systemctl daemon-reload; fi
  systemctl enable fstrim.timer
  # Preserve an already scheduled randomized deadline across routine activation.
  if "$timer_changed"; then systemctl restart fstrim.timer; else systemctl start fstrim.timer; fi
  ;;
vm-compaction)
  # CI waves madvise huge pages, and with defrag=madvise those faults enter
  # direct compaction that almost never succeeds on these hosts, while
  # proactive compaction adds futile kcompactd scans on top. Faults fall back
  # to small pages instead; enabled=madvise stays so khugepaged still collapses.
  sysctl_conf="${2:?sysctl.d file required}"
  tmpfiles_conf="${3:?tmpfiles.d file required}"
  defrag="${4:?THP defrag file required}"
  sysctl_content=$'vm.compaction_proactiveness = 0\nvm.watermark_boost_factor = 0'
  tmpfiles_content="w $defrag - - - - never"
  if [ ! -f "$sysctl_conf" ] || [ "$(cat "$sysctl_conf")" != "$sysctl_content" ]; then
    printf '%s\n' "$sysctl_content" >"$sysctl_conf"
    echo "Wrote $sysctl_conf."
  fi
  sysctl -q -p "$sysctl_conf"
  if [ ! -f "$tmpfiles_conf" ] || [ "$(cat "$tmpfiles_conf")" != "$tmpfiles_content" ]; then
    printf '%s\n' "$tmpfiles_content" >"$tmpfiles_conf"
    echo "Wrote $tmpfiles_conf."
  fi
  if ! grep -qF '[never]' "$defrag"; then
    printf 'never\n' >"$defrag"
    echo "Set THP defrag to never."
  fi
  ;;
sshd-key-only)
  # sshd keeps the first value it reads, and cloud-init's 50-cloud-init.conf
  # enables passwords, so this drop-in must sort before it.
  dropin="${2:?sshd_config.d file required}"
  content=$'PasswordAuthentication no\nKbdInteractiveAuthentication no'
  if [ ! -f "$dropin" ] || [ "$(cat "$dropin")" != "$content" ]; then
    printf '%s\n' "$content" >"$dropin"
    echo "Wrote $dropin."
  fi
  if ! sshd -t; then
    rm -f "$dropin"
    echo "sshd -t rejected $dropin; removed it." >&2
    exit 1
  fi
  systemctl reload ssh
  ;;
user-manager)
  hostnamectl set-hostname "${2:?name required}"
  loginctl enable-linger root
  systemctl start user@0.service
  ;;
start-herdr)
  systemctl_bin="${2:?systemctl binary required}"
  export XDG_RUNTIME_DIR=/run/user/0
  "$systemctl_bin" --user daemon-reload || true
  "$systemctl_bin" --user enable --now herdr-server.service || true
  ;;
login-shell)
  fish_bin="${2:?fish binary required}"
  shells="${3:?shells file required}"
  # Pointing root at a missing shell would break root logins, so refuse before writing.
  if [ ! -f "$fish_bin" ] || [ ! -x "$fish_bin" ]; then
    echo "Refusing to change root's login shell: $fish_bin is not an executable file." >&2
    exit 1
  fi
  if ! grep -qxF -- "$fish_bin" "$shells"; then
    printf '%s\n' "$fish_bin" >>"$shells"
    echo "Added $fish_bin to $shells."
  fi
  if [ "$(getent passwd root | cut -d: -f7)" != "$fish_bin" ]; then
    chsh -s "$fish_bin" root
    echo "Set root's login shell to $fish_bin."
  fi
  ;;
browser-deps)
  # Playwright's bundled Chromium is linked against the distro's GTK/X11/NSS
  # stack, not Nix, so CI checkouts on these workers need the Ubuntu packages
  # `playwright install-deps chromium` would install. The names are Ubuntu
  # 24.04's t64 variants; other releases are skipped rather than failing.
  os_release="${2:?os-release file required}"
  release=$(
    # shellcheck disable=SC1090
    . "$os_release"
    printf '%s-%s' "${ID:-}" "${VERSION_ID:-}"
  )
  if [ "$release" != ubuntu-24.04 ]; then
    echo "Chromium runtime libraries are declared for ubuntu-24.04, not $release; skipping." >&2
    exit 0
  fi
  packages=(
    fonts-liberation fonts-noto-color-emoji libasound2t64 libatk-bridge2.0-0t64
    libatk1.0-0t64 libatspi2.0-0t64 libcairo2 libcups2t64 libdbus-1-3 libdrm2
    libfontconfig1 libfreetype6 libgbm1 libglib2.0-0t64 libnspr4 libnss3
    libpango-1.0-0 libx11-6 libxcb1 libxcomposite1 libxdamage1 libxext6
    libxfixes3 libxkbcommon0 libxrandr2
  )
  missing=()
  for package in "${packages[@]}"; do
    if [ "$(dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null)" != installed ]; then
      missing+=("$package")
    fi
  done
  [ "${#missing[@]}" -eq 0 ] && exit 0
  # A transient apt failure must not block the unattended dotfiles upgrade;
  # the next activation retries the still-missing packages.
  export DEBIAN_FRONTEND=noninteractive
  if apt-get -o DPkg::Lock::Timeout=300 update -qq &&
    apt-get -o DPkg::Lock::Timeout=300 install -y -qq --no-install-recommends "${missing[@]}"; then
    echo "Installed Chromium runtime libraries: ${missing[*]}"
  else
    echo "Warning: could not install Chromium runtime libraries: ${missing[*]}" >&2
  fi
  ;;
tailscale)
  name="${2:?name required}"
  tailscale_bin="${3:?tailscale binary required}"
  shift 3
  "$tailscale_bin" up "$@"
  echo "Tailscale enrollment and preferences applied for $name."
  ;;
t3-connect)
  # Provision T3 Connect for this worker. The background server reconciles the
  # link on start, so install/repair it first. Workers default to publish-only
  # because the relay caps managed tunnels per account; `managed` opts a host
  # into a relay tunnel so clients can sign in with T3 Connect. The first
  # authorization is an operator's interactive device flow; activation only
  # links hosts that already hold a credential.
  t3_bin="${2:-}"
  t3_mode="${3:-publish-only}"
  case "$t3_mode" in
  disabled) link_flags=() ;;
  managed) link_flags=() ;;
  publish-only) link_flags=(--publish-only) ;;
  *)
    echo "Unknown T3 Connect mode: $t3_mode" >&2
    exit 1
    ;;
  esac
  if [ -z "$t3_bin" ]; then
    t3_bin="$(command -v t3 || true)"
  fi
  if [ -z "$t3_bin" ] || [ ! -x "$t3_bin" ]; then
    echo "t3 is not installed; skipping T3 Connect provisioning." >&2
    exit 0
  fi
  # The t3 native binary links libatomic, which Kamino hosts do not ship. Replace
  # rather than append the ambient path: a polluted value would leak Nix
  # libraries built against a newer glibc into the provisioning run.
  if [ -n "${4:-}" ]; then
    export LD_LIBRARY_PATH="$4"
  fi

  if [ "$t3_mode" = disabled ]; then
    "$t3_bin" connect logout || true
    "$t3_bin" service uninstall || true
    echo "T3 Connect disabled and service removed."
    exit 0
  fi

  base="${T3CODE_HOME:-$HOME/.t3}"
  state="$base/runtime/service-state.json"

  # A release that requires launcher protocol 3 cannot be activated by a
  # protocol-2 launcher, and the desktop client hands off exactly such updates.
  # A protocol-3 launcher is only produced by a protocol-3 release, so
  # bootstrapping one needs a nightly CLI rather than the pinned global. After
  # that the service is left alone: the desktop owns version upgrades, and
  # running a protocol-2 `service install` here would downgrade the launcher
  # and break the client's update path again.
  if [ ! -f "$state" ] || ! grep -q '"protocol": 3' "$state"; then
    echo "T3 launcher needs a protocol-3 release; bootstrapping with t3@nightly." >&2
    npx --yes t3@nightly service install ||
      npx --yes t3@nightly service update ||
      echo "Warning: could not install the T3 background service." >&2
  fi

  # Without a credential, `connect link` starts a device flow that blocks the
  # switch until it times out, so leave authorization to the operator.
  if [ ! -f "$base/userdata/secrets/cloud-cli-oauth-token.bin" ]; then
    systemctl --user daemon-reload || true
    systemctl --user enable --now t3code.service || true
    systemctl --user restart t3code.service || true
    echo "T3 Connect not authorized; skipping link. Run t3 connect link --headless ${link_flags[*]} as root in an interactive shell." >&2
    exit 0
  fi

  "$t3_bin" connect link ${link_flags[@]+"${link_flags[@]}"}
  systemctl --user daemon-reload || true
  systemctl --user enable --now t3code.service || true
  systemctl --user restart t3code.service || true
  echo "T3 Connect $t3_mode link requested."
  ;;
*)
  echo "Unknown Kamino activation phase" >&2
  exit 1
  ;;
esac
