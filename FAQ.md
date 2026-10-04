# FAQ

## Dock items lost on reboot (macOS)

If you experience your Dock items being lost on every reboot, you might be encountering an issue related to `com.apple.dock.plist` becoming read-only or corrupted. This can sometimes be resolved by running the following commands in your terminal:

```bash
defaults delete com.apple.dock
killall Dock
```

After running these commands, you may need to re-add your desired applications to the Dock. Subsequent reboots should then persist your Dock configuration.

For more details, see [nix-darwin issue #789](https://github.com/LnL7/nix-darwin/issues/789).

## Captive Wi-Fi login detection

The bundled `home-manager/services/neverssl-keepalive` service checks Apple,
Google, and Microsoft HTTP connectivity probes every 30 seconds. It validates
the expected response body or empty `204`, rather than treating any successful
HTTP request as internet access. NeverSSL availability is no longer required.

On macOS, the detector discovers the Wi-Fi interface without relying on the
SSID, and probes through that interface. Redirects, HTTP `511`, or substituted
login pages report `CAPTIVE` and open a browser to the intercepted probe URL.
Browser openings are limited to once per ten minutes per network, including
across temporary connectivity changes. It never switches Wi-Fi off and on.

Timeouts and DNS or server failures report `OFFLINE` without opening a browser.
A validated response reports `ONLINE` unless another probe was intercepted;
some captive networks allow individual probe hosts before login. Linux uses the
same detection and reports the result in the systemd user journal.

For a check without opening a browser or changing the cooldown state, run:

```bash
bash home-manager/services/neverssl-keepalive/keepalive.sh --check
```

On macOS, logs are in `/tmp/neverssl-keepalive.log` and
`/tmp/neverssl-keepalive.error.log`. Detection helps surface manual login; it
does not renew sessions that require accepting terms or submitting credentials.
