# NixOS (matic - Framework 13 AMD AI 300)

## Full Disk Encryption (LUKS + TPM2)

The root partition is encrypted with LUKS2. TPM2 auto-unlock is configured so no passphrase is needed on boot.

After a fresh install or kernel update, enroll the TPM2 key:

```bash
sudo systemd-cryptenroll --tpm2-device=auto /dev/nvme0n1p2
```

If the boot chain changes (firmware/kernel update), TPM2 will refuse and fall back to the passphrase. Re-enroll after booting with the passphrase.

## Building and Switching

```bash
make build HOST=matic && make switch HOST=matic
```

Or use `boot` instead of `switch` for major config changes (avoids dbus reload issues):

```bash
sudo nixos-rebuild boot --flake .#matic --impure && sudo reboot
```
