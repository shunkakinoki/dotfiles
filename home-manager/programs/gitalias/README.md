# GitAlias Nix Module

This module automatically fetches and generates GitAlias shell aliases at Nix build time.

## How It Works

1. **Fetch**: Downloads `gitalias.txt` from GitHub using `pkgs.fetchurl`
2. **Parse**: Generator scripts extract alias definitions from git config format
3. **Filter**: Complex aliases (shell functions, color codes, etc.) are removed
4. **Generate**: Converts to shell-specific format (bash aliases, zsh aliases, fish abbreviations)
5. **Embed**: String interpolation injects aliases directly into shell init files

## Files

- `default.nix` - Main Nix module that orchestrates generation
- Generator scripts use `pkgs.writeShellScript` for parsing logic

## Integration

The module is imported by shell configuration files:

```nix
let
  gitalias = import ../gitalias { inherit pkgs; };
in
{
  programs.bash.bashrcExtra = ''
    ${gitalias.bash}
  '';
}
```

## Hash Update

⚠️ **IMPORTANT**: The first time you build, you need to update the SHA256 hash for the GitAlias fetch.

1. Set the hash to all zeros (as it currently is)
2. Run `make build`
3. Nix will fail and show you the correct hash
4. Update the `sha256` in `default.nix` with the correct value
5. Run `make build` again

Example error message:
```
hash mismatch in fixed-output derivation '/nix/store/...':
  specified: sha256:0000000000000000000000000000000000000000000000000000
    got:    sha256:1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t1u2v3w4x5y6z
```

Copy the "got" hash and update `default.nix`.

## Updating GitAlias

When GitAlias is updated upstream:

1. Update the hash in `default.nix` following the process above
2. Rebuild: `make build`
3. Test in a new shell

## Output

The module exports an attribute set:

```nix
{
  bash = "alias ga='git add'\nalias gaa='git add --all'\n...";
  zsh = "alias ga='git add'\nalias gaa='git add --all'\n...";
  fish = "abbr -a ga 'git add'\nabbr -a gaa 'git add --all'\n...";
}
```

## Alias Count

- Bash: ~136 aliases
- Zsh: ~142 aliases
- Fish: ~151 abbreviations

All aliases are prefixed with 'g' to avoid conflicts.
