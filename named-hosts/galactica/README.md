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
```

This command will:
1. Read the contents of `~/.ssh/id_ed25519`.
2. Encrypt it for the public keys defined in `secrets.nix`.
3. Save the result to `named-hosts/galactica/keys/id_ed25519.age`.

#### Verifying a Secret

To decrypt a file and view its contents for verification, use the `decrypt-key-galactica` target:

```bash
# Decrypts keys/id_ed25519.age and prints to terminal
make decrypt-key-galactica KEY_FILE=id_ed25519
```
*Note: You only need to provide the base name of the key file, not the full path or `.age` extension.*

#### Rekeying Secrets

If you ever change `secrets.nix` to add a new person or machine, you must "rekey" the secrets so they can also decrypt them.

```bash
make rekey-galactica
```
This will re-encrypt all secrets in this directory according to the latest rules in `secrets.nix`.
