# How Secrets are Managed with Agenix

This document explains the core concepts behind the `agenix` setup in this repository, including how encryption works and why the configuration is structured the way it is.

---

### The Core Concept: Public-Key Cryptography

Our secret management is built on a fundamental cryptographic principle:

*   **Public Key (like an open padlock):** You can share this with anyone. It can only be used to *lock* a box (encrypt data). In our setup, this is the `ssh-ed25519 AAA...` key stored in `secrets.nix`.
*   **Private Key (the only key that fits):** You must keep this secret. It is the only thing that can *unlock* the box (decrypt data). This is the key that lives in `~/.ssh/id_ed25519` on your machine.

When you run `make encrypt-key-galactica`, `agenix` uses the **public key** from `secrets.nix` to lock up your private key in an encrypted file.

---

### Why Are There Two Separate Configurations?

The `agenix` system uses two different files that serve two distinct purposes at different times:

1.  **`secrets.nix` (The Encryption Rulebook)**
    *   **Purpose:** Defines **WHO** is allowed to decrypt a secret.
    *   **When it's used:** This file is read by the `agenix` command-line tool when you run `make encrypt-key-...` or `make rekey-...`.
    *   **How it works:** It maps a secret's filename to a list of public keys. `agenix` uses these public keys to encrypt the data.

2.  **`default.nix` (The Deployment Manual)**
    *   **Purpose:** Defines **WHAT** secret to deploy during a system build.
    *   **When it's used:** This file is read by the Nix build process when you run `make switch-...`.
    *   **How it works:** It tells the `agenix` Nix module which encrypted file to find, where to place the decrypted contents (in the secure `/run/agenix` directory), and who should own it. This makes the secret available to other parts of your Nix configuration.

The two files are merged in `default.nix` using the `//` operator to give the Nix build process all the information it needs at once.

---

### Solving the "Circular Dependency" Paradox

It seems like a paradox: to deploy your private key, you need to decrypt a file, but to decrypt the file, you already need your private key.

This is a classic bootstrapping problem, and here's how it's solved:

1.  **The Bootstrap Key:** You start with one **unmanaged** private key (`~/.ssh/id_ed25519`) that you create yourself using `ssh-keygen` on your primary development machine. This key exists *before* `agenix` is involved.

2.  **First Encryption:** When you run `make encrypt-key-...` for the first time, `agenix` uses the **public key** in `secrets.nix` to encrypt your bootstrap key. This step doesn't require a private key.

3.  **First Deployment:** When you run `make switch-...` on that same machine, the `agenix` module needs to decrypt the file. It sees that it's locked for your public key, and it finds your **original, unmanaged bootstrap key** in `~/.ssh/id_ed25519` to perform the decryption.

From this point forward, the system is self-sufficient. To set up a new machine, you would temporarily place your private key on it, run the build once to bootstrap the `agenix` system, and then you can remove the key you copied manually. 
