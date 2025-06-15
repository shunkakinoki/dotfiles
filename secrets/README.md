# Managing Secrets with agenix

This directory contains secrets managed by [agenix](https://github.com/ryantm/agenix), which uses `age` for encryption.

## Prerequisites

Ensure you are in the development environment, which provides the necessary tools:

```sh
nix develop
```

## How It Works

The core of the secret management is the `secrets.nix` file in this directory. It defines which public keys (recipients) can decrypt which secret files. `agenix` uses this file to know who to encrypt for when creating or editing secrets.

The secrets themselves are `.age` files, which are encrypted versions of the original content.

## Generating a Key

You can use your existing SSH key or generate a new one. `agenix` supports `ed25519` SSH keys.

To generate a new key:

```sh
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_new
```

Your public key will be in `~/.ssh/id_ed25519_new.pub`.

## Adding a New Recipient (User or System)

To grant a new user or system access to secrets:

1.  Get their `ed25519` public key.
2.  Open `secrets/secrets.nix`.
3.  Add the public key to the appropriate list (`users` or `systems`). For example:

    ```nix
    let
      user1 = "ssh-ed25519 ...";
      new_user = "ssh-ed25519 ..."; # Add the new key here
      users = [
        user1
        new_user
      ];
      # ...
    ```

## Creating and Editing Secrets

To create a new secret or edit an existing one, you'll use `agenix`. `agenix` will automatically find your SSH private keys (e.g., from `~/.ssh/id_ed25519`) to decrypt files for editing.

1.  **Define recipients for the secret:** Before creating a secret file, you must first define its recipients in `secrets/secrets.nix`. For a new secret `my-secret.age`:

    ```nix
    {
      # ... other secrets
      "my-secret.age".publicKeys = users; # Or a specific list of keys
    }
    ```
    For nested secrets, use the path relative to the `secrets` directory:
    ```nix
    {
      # ...
      "ssh/id_ed25519.age".publicKeys = users ++ systems;
    }
    ```

2.  **Edit the secret:** Run `agenix` with the path to the secret. This will open your `$EDITOR` with the decrypted content.

    ```sh
    agenix --edit secrets/ssh/id_ed25519.age
    ```

    If the file doesn't exist, `agenix` will create it. When you save and close the editor, `agenix` will encrypt the content and save it.

## Rekeying Secrets

If a recipient's key is compromised or they should no longer have access, you must:

1.  Remove their public key from `secrets/secrets.nix`.
2.  Rekey all secrets they had access to using `agenix --rekey` or `agenix -r`. This will re-encrypt all secrets defined in `secrets.nix` with their updated recipient lists.

    ```sh
    agenix --rekey
    ``` 
