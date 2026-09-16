# Dotfiles

## Installation

See [PREREQUISITES.md](./PREREQUISITES.md) for private credentials and managed CLI requirements.

```bash
 curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/main/install.sh | sh
```

To pin a named host (skips hostname auto-detection):

```bash
 curl -fsSL https://raw.githubusercontent.com/shunkakinoki/dotfiles/main/install.sh | HOST={NAMED_HOST_HERE} sh
```

For troubleshooting and frequently asked questions, see [FAQ.md](./FAQ.md).

For default and fallback model assignments per harness, see [MODELS.md](./MODELS.md).

For Kamino setup and verification, see the [host runbook](named-hosts/kamino/README.md).

For the Beads SQL authority and its activation checks, see [BEADS.md](./BEADS.md).

## Intentional Python runtime exceptions

Repository tooling and tests use Nix, POSIX shell, or Bash. A small set of
Python files remains because another runtime owns the interface or because the
implementation uses a protocol that is safer to keep explicit:

- Hermes' generated Traces plugin is loaded as a Python module by Hermes.
- The Traces upload queue keeps serialized state, file locking, coalescing, and
  service lifecycle semantics in one process.
- The Herdr admission hook is a security-sensitive command and metadata parser.
- The Matic GNOME Keyring helper speaks the daemon's binary control-socket
  protocol and validates the target UID before sending credentials.

These exceptions are covered by the Python CI lane; new repository-only
tooling should be implemented and tested in shell or Nix instead.

## Credits

See [REFERENCES.md](./REFERENCES.md) for more information.
