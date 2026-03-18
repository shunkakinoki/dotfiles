# matic

Setup and operational notes for the `matic` NixOS host.

---

## GNOME Keyring Auto-Unlock via TPM2

The system unlocks the GNOME Keyring automatically at login — including when using fingerprint auth — by storing the keyring password as a `systemd-creds` credential encrypted with the machine's TPM2 + host key. The credential can only be decrypted on this machine.

### One-time setup

After first running `make switch`, create the credential:

```bash
mkdir -p ~/.config/credstore.encrypted
systemd-ask-password "Keyring password:" | systemd-creds encrypt \
  --name=gnome-keyring --with-key=tpm2+host \
  - ~/.config/credstore.encrypted/gnome-keyring.cred
```

Then restart the service:

```bash
systemctl --user restart gnome-keyring-unlock.service
```

### How it works

1. `services.gnome.gnome-keyring.enable` starts the keyring daemon at login.
2. `security.pam.services.greetd.enableGnomeKeyring` hooks into PAM (works for password login).
3. `systemd.user.services.gnome-keyring-unlock` decrypts the TPM2-bound credential and pipes it to `gnome-keyring-daemon --unlock` — this handles fingerprint login where PAM has no password to forward.
4. The service skips silently if the credential file does not exist yet.

### Re-encrypting after keyring password change

If you change your keyring password (via seahorse), re-run the setup command above to update the credential.
