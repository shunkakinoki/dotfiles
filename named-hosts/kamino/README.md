# Kamino operations

The [installation and fleet runbook](../../README.md#kamino-fleet) owns the
generated namespace, bootstrap command, SSH access and verification commands.
The same root profile serves `kamino` and every numbered machine. Separate
machines need separate Tailscale and SSH state; names are not a load balancer.

## Offline validation

Run from the reviewed dotfiles checkout without activating a remote profile:

```sh
nix eval --impure --raw .#homeConfigurations.kamino100.config.home.username
# root
nix eval --impure --raw .#homeConfigurations.kamino100.config.home.homeDirectory
# /root
nix eval --impure --raw .#checks.x86_64-linux.eval-home-kamino100.drvPath
python3 -m unittest discover -s tests -p 'test_kamino*.py'
shellspec spec/install_spec.sh spec/make_build_host_resolution_spec.sh spec/ssh_config_spec.sh
```

The evaluation checks cover root identity, common tools/configs, SSH aliases,
upgrade targeting and absence of Kyber-only services. Linux CI builds the parent
and hundredth generated profile. Evaluation is not a successful Linux build;
neither is live activation proof.

## Reviewed revision and first activation

Use the provider console or supplied IP first. Keep console access and an
existing SSH session open until a second connection works over Tailscale.
Verify the root SSH host-key fingerprint through the console. Provision the
intended public authorized key without replacing existing keys.

The curl installer tracks main. To test a reviewed but unmerged revision, clone
the repository into `/root/dotfiles`, check out that revision, and run:

```sh
HOST=kamino1 make build
HOST=kamino1 make nix-switch
```

Run switch only after build succeeds, on the intended root/systemd Linux machine.
For an existing checkout, preserve its local changes and untracked dotenv.
Fresh minimal Ubuntu also needs `dbus-user-session`; the installer bootstraps it.
Activation sets the hostname, enables root lingering, starts the user manager
and applies the named service configuration. It configures Tailscale without
interactive enrollment; a fresh node still needs authentication.

MagicDNS must be enabled in the tailnet and client access rules must permit TCP
22. Server-side `--accept-dns=false` does not prevent publishing the node name.
The profile uses OpenSSH over Tailscale, not Tailscale SSH. Root on the parent VPS
controls the whole VPS, not an isolated worker.

## Runtime and persistence proof

Alongside `kamino-fleet verify kamino1`, check on the target:

```sh
XDG_RUNTIME_DIR=/run/user/0 systemctl --user show herdr-server -p ActiveState -p SubState -p MainPID
home-manager generations
readlink -f /root/dotfiles/result
```

Expect an active/running Herdr unit and nonzero PID. Compare the activated
generation with the built result. Attach interactively with Herdr, tmux and
Zellij to test real sessions. Later, with permission to restart that machine,
verify its Tailscale device ID and SSH host key remain unchanged and services
return healthy. Do not infer restart persistence from source configuration.

## Environment and recovery

Herdr reads optional `/root/dotfiles/.env` at service start using systemd's
`EnvironmentFile`. Use systemd-compatible assignments, not shell commands or
`export` statements. This change neither copies credentials nor alters
hydration. Missing credentials may prevent authenticated AI-worker operations,
even when the multiplexer itself works. Never display the file or service
environment as verification.

A deliberate Herdr service restart interrupts its active sessions. Keep console
access and the previous Home Manager generation for recovery. Home Manager
rollback does not undo hostname/lingering or system files installed by activation
hooks; review those and the Tailscale units separately. No new SSH daemon,
firewall policy, VPS or container runtime is provisioned here.
