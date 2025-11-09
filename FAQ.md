# FAQ

## Dock items lost on reboot (macOS)

If you experience your Dock items being lost on every reboot, you might be encountering an issue related to `com.apple.dock.plist` becoming read-only or corrupted. This can sometimes be resolved by running the following commands in your terminal:

```bash
defaults delete com.apple.dock
killall Dock
```

After running these commands, you may need to re-add your desired applications to the Dock. Subsequent reboots should then persist your Dock configuration.

For more details, see [nix-darwin issue #789](https://github.com/LnL7/nix-darwin/issues/789).

## Auto renew neverssl on private wifi

Send a lightweight HTTP GET to `http://neverssl.com` on a short cadence to keep the captive portal session alive.

**Systemd (Linux):** define a `neverssl-keepalive.service` oneshot that runs curl, then pair it with a timer using `OnBootSec=3s` and `OnUnitActiveSec=3s`, finally `systemctl enable --now neverssl-keepalive.timer`.

**Cron or launchd:** schedule the same curl command (`curl -fsS --max-time 10 http://neverssl.com >/dev/null 2>&1 || true`) at your preferred interval.

**NixOS/Home Manager:** use the bundled `home-manager/services/neverssl-keepalive` module to install a 3-second systemd user timer.

If the network still expires sessions, the captive portal may require additional headers, JavaScript heartbeats, or manual sign-ins.
