# `galactica` Host Configuration

This document outlines how to manage the Nix configuration and secrets for the `galactica` host using the provided `Makefile`.

---

### GPG Configuration

1.  Generate or import your GPG key for `shunkakinoki@gmail.com`.
2.  Run `make switch-galactica` to apply the configuration.

---

### Building and Activating

To build the complete system configuration for this host and activate it, run the following command:

```bash
make switch-galactica
```

This command will build the `darwinConfiguration` defined in `flake.nix` for `galactica` and apply it to the system.

---

### Managing Secrets with Agenix

This host's secrets are managed by `agenix`. The rules for who can decrypt which secrets are defined in `secrets.nix`.

#### Encrypting a New Key

To encrypt a new secret (like an SSH key) for this host, use the `encrypt-key-galactica` target. You must have the corresponding private key on the machine where you run this command.

```bash
# Example: Encrypting your primary SSH key
make encrypt-key-galactica KEY_FILE=~/.ssh/id_ed25519

# Example: Encrypting your GPG private key
gpg --export-secret-keys --armor shunkakinoki@gmail.com > /tmp/gpg
make encrypt-key-galactica KEY_FILE=/tmp/gpg
```

This command will:

1. Read the contents of the specified key file.
2. Encrypt it for the SSH public keys defined in `secrets.nix`.
3. Save the result to `named-hosts/galactica/keys/<filename>.age`.

**Note**: The `publicKeys` in `secrets.nix` are SSH public keys, not GPG public keys. Agenix uses SSH keys for age encryption/decryption - your SSH private key decrypts the age-encrypted file containing your GPG private key.

#### Verifying a Secret

To decrypt a file and view its contents for verification, use the `decrypt-key-galactica` target:

```bash
# Decrypts keys/id_ed25519.age and prints to terminal
make decrypt-key-galactica KEY_FILE=id_ed25519
```

_Note: You only need to provide the base name of the key file, not the full path or `.age` extension._

#### Restoring the Kamino CI key

`keys/kamino_ci_ed25519.age` holds the passphrase-free key galactica presents to
the Kamino workers. `CRABBOX_SSH_KEY` points at `~/.ssh/kamino_ci_ed25519`, so a
rebuilt galactica needs that file back before delegated CI works again.

galactica cannot decrypt it on its own: its only agenix identity is
passphrase-protected and activation runs non-interactively. Restore it from a
machine that holds a usable identity (kyber or matic):

```bash
rage -d -i ~/.ssh/id_ed25519 \
  named-hosts/galactica/keys/kamino_ci_ed25519.age \
  -o /tmp/kamino_ci_ed25519
scp /tmp/kamino_ci_ed25519 galactica:.ssh/kamino_ci_ed25519
ssh galactica 'chmod 600 ~/.ssh/kamino_ci_ed25519'
rm /tmp/kamino_ci_ed25519
```

The restored key must fingerprint as `galactica-ci` in
`named-hosts/pubkeys.nix`:
`SHA256:Amp8g6UxTAnoFOIYS5jrW+gKtfKtxxgstFZ2NMunW7o`. That entry is what the
workers authorize, so a freshly generated key would be rejected.

#### Rekeying Secrets

If you ever change `secrets.nix` to add a new person or machine, you must "rekey" the secrets so they can also decrypt them.

```bash
make rekey-galactica
```

This will re-encrypt all secrets in this directory according to the latest rules in `secrets.nix`.
