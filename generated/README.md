# Generated hook artifacts

This directory contains checked-in hook outputs consumed by Home Manager.
Do not edit files under `generated/hooks` directly.

Run:

```sh
make generate
```

The command refreshes the Moshi adapters and JSON hook settings from the
installed `moshi-hook` package and renders the native OpenClaw/Hermes Traces
adapters from their templates in `config/`. Review the resulting diff before
committing it.
