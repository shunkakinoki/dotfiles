# matic

Setup and operational notes for the `matic` NixOS host.

---

## GNOME Keyring Auto-Unlock via TPM2

The system unlocks the GNOME Keyring automatically at login — including when using fingerprint auth — by storing the keyring password as a `systemd-creds` credential encrypted with the machine's TPM2 + host key. The credential can only be decrypted on this machine.

### One-time setup

After first running `make switch`, create the credential (requires sudo for TPM access):

```bash
sudo bash -c 'mkdir -p /etc/credstore.encrypted && \
  systemd-ask-password "Keyring password:" | \
  systemd-creds encrypt --name=gnome-keyring --with-key=tpm2+host \
  - /etc/credstore.encrypted/gnome-keyring.cred'
```

Then restart the service:

```bash
sudo systemctl restart gnome-keyring-unlock.service
```

### How it works

1. `services.gnome.gnome-keyring.enable` starts the keyring daemon at login via PAM.
2. `security.pam.services.greetd.enableGnomeKeyring` auto-unlocks for password logins.
3. `systemd.services.gnome-keyring-unlock` runs as a **system service** with `User=skakinoki` so the system manager handles TPM decryption. It then speaks the gnome-keyring **control socket protocol** directly to unlock the running daemon — covering fingerprint logins where PAM has no password to forward.
4. The service skips silently if the credential file does not exist yet.

> **Note:** `gnome-keyring-daemon --unlock` (v48+) ignores `GNOME_KEYRING_CONTROL` and always starts a fresh instance. The service works around this by writing directly to `$XDG_RUNTIME_DIR/keyring/control` using the binary protocol: credentials byte + big-endian `[oplen][op=1][pwlen][password]`, reads `[8][result]`.
>
> **Note:** The credential must be at `/etc/credstore.encrypted/gnome-keyring.cred` (not `~/.config`). User-level systemd services cannot access TPM/host keys — only the system manager can.

### Re-encrypting after keyring password change

If you change your keyring password (via seahorse), re-run the setup command above to update the credential.
