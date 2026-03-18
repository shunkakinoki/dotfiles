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

The keyring password must be your **system login password** (the one PAM uses when you log in with password).

### How it works

1. `pam_gnome_keyring.so` starts the keyring daemon during PAM session open (order 12600).
2. For **password login**: PAM forwards the password and the keyring auto-unlocks.
3. For **fingerprint login**: PAM has no password, so the keyring stays locked. Immediately after, `pam_exec.so type=open_session` (order 12610) runs a script that:
   - Decrypts the TPM2 credential via `systemd-creds decrypt` (runs as root, has TPM access)
   - Uses `runuser` to switch to the target user
   - Retries in the background until the keyring control socket is ready
   - Speaks the gnome-keyring **control socket protocol** directly to unlock the daemon
4. The script exits silently if the credential file does not exist.

> **Note:** `gnome-keyring-daemon --unlock` (v48+) ignores `GNOME_KEYRING_CONTROL` and always starts a fresh instance. The PAM script works around this by writing directly to `$XDG_RUNTIME_DIR/keyring/control` using the binary protocol: credentials byte + big-endian `[oplen][op=1][pwlen][password]`, reads `[8][result]`.

### Re-encrypting after keyring password change

If you change your keyring password (via seahorse), re-run the setup command above to update the credential.
