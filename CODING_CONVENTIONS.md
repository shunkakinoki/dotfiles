# Coding Conventions

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
