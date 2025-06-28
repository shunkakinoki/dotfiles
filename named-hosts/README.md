# 🖥️ Named Hosts

This directory contains the Nix configurations for each of my named devices. Each subdirectory corresponds to a specific host, encapsulating its unique setup, including secrets.

---

## 📂 Directory Structure

The `named-hosts/` directory is organized with one directory per host:

```plaintext
named-hosts/
└── galactica/         # Configuration for the host 'galactica'
    ├── default.nix    # Main Nix configuration for this host
    └── secrets.nix    # Secret definitions for agenix
```

---

## 🛠️ Provisioning New Devices with Agenix

To add a new device to this configuration, follow these steps:

1.  **Create Host Directory**:
    -   Create a new directory under `named-hosts/` with the new device's hostname.
        ```bash
        mkdir named-hosts/new-host
        ```

2.  **Create Host Configuration**:
    -   Create a `default.nix` inside the new directory. You can copy an existing one as a template.
    -   Ensure the `default.nix` imports the `agenix` module and points to its own local `secrets.nix` file.
        ```nix
        # named-hosts/new-host/default.nix
        { ... }: {
          imports = [ inputs.agenix.nixosModules.default ];
          age.secrets = import ./secrets.nix;
          # ... other configurations
        }
        ```

3.  **Define Secrets Access**:
    -   Create a `secrets.nix` file in the new host's directory.
    -   In this file, define *who* (which public keys) can decrypt the secrets for this host. You can use the host's own public key (`config.system.ssh.hostKeys.root.publicKey`) or a user's public SSH/age key.
        ```nix
        # named-hosts/new-host/secrets.nix
        {
          "my-secret.age".publicKeys = [
            "ssh-ed25519 AAAA..." # User's public key
          ];
        }
        ```

4.  **Update `flake.nix`**:
    -   Add the new host to the appropriate section in `flake.nix` (e.g., `darwinConfigurations`).

5.  **Encrypt Secrets**:
    -   To create a new secret, use the `agenix -e` command. For example, to create `my-secret.age`:
        ```bash
        EDITOR=vim agenix -e named-hosts/new-host/my-secret.age
        ```
    -   Agenix will use the corresponding `secrets.nix` to determine the recipients.

6.  **Rekey Secrets (if needed)**:
    -   If you add a new public key to `secrets.nix`, you must rekey existing secrets so the new identity can decrypt them.
        ```bash
        agenix --rekey -f named-hosts/new-host/secrets.nix
        ```

7.  **Rebuild System**:
    -   On the new device, build the system from the repository. Secrets will be automatically decrypted and available in `/run/agenix/`.
        ```bash
        nix run nix-darwin -- switch --flake .#new-host
        ```

8.  **(Optional) Configure User SSH Key**:
    -   Generate a new user SSH key and copy it to `secrets/publicKeys/$USER_$HOSTNAME.pub` to enable passwordless logins to other hosts. 
