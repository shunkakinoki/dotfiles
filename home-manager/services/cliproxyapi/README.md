# CLIProxyAPI Service Configuration

This directory contains the Nix-based configuration for the cliproxyapi service with S3-backed auth file management.

## Architecture

### Services

1. **cliproxyapi** - Main proxy server on port 8317 (every host)
2. **cliproxyapi-backup-auth** - File watcher that syncs only the auth cache to S3 (kyber)
3. **cliproxyapi-backup** - Wall-clock hourly job that syncs auth files and CPA Manager Plus analytics to S3 (kyber)

### Kyber-only OAuth

OAuth refresh tokens rotate on every refresh, so a copy refreshed on one host
invalidates the copies on every other host. OAuth auth files and the S3 store
live on kyber only. `common.sh` ignores `OBJECTSTORE_*` on every other host, so
their CLIProxyAPI instances never hydrate, push, or refresh the shared auths.

### Scripts

| Script | Purpose |
|--------|---------|
| `hydrate.sh` | Pull S3 → local (runs at activation) |
| `backup.sh auth` | Push auth cache local → S3 (triggered by WatchPaths) |
| `backup.sh full` | Auth cache plus the CPA Manager Plus analytics snapshot (hourly) |
| `start.sh` | Load .env, hydrate auth cache if needed, generate config, start service |
| `wrapper.sh` | Load .env, sync auth cache, exec binary (for CLI usage) |

### Directory Structure

```
~/.cli-proxy-api/
├── config.yaml                    # Generated config
├── config.template.yaml           # Template with placeholders
└── objectstore/
    └── auths/                     # Auth files (S3 is source of truth)

S3 Storage:
├── s3://cliproxyapi/auths/        # Auth storage
├── s3://cliproxyapi/cpa-manager-plus/analytics-backup-HH.tar.gz
│                                     # 24 hourly rollback slots (UTC)
└── s3://cliproxyapi/cpa-manager-plus/analytics-backup.tar.gz
                                      # Latest SQLite snapshot + matching data.key
```

## Data Flow

``` 
S3 auths/ <-> ~/.cli-proxy-api/objectstore/auths
```

### Pre-start guard (service)

`start.sh` hydrates the local auth cache from S3 when it is empty, then re-syncs
back to S3. This avoids the upstream race where a fresh start can delete remote
auth objects if the local cache is empty.

### CLI guard (manual usage)

`wrapper.sh` mirrors the service guard by syncing the local auth cache before
invoking the CLI, so `cliproxyapi --claude-login` can bootstrap without a missing
key error when S3 already has auths.

### Hydrate (on activation/switch)

1. Pull from S3 `auths/` → local

### Backup (auth, on auth-file change)

1. Push local → S3 `auths/`

CLIProxyAPI rewrites auth token files on every refresh, so this path fires many
times per hour. It stays restricted to the kilobyte-scale auth cache.

### Backup (full, each wall-clock hour)

1. Push local → S3 `auths/`
2. Create and integrity-check an online CPA Manager Plus SQLite snapshot
3. Stream the snapshot and its matching `data.key` as a tarball into the UTC
   hour slot, then server-side copy that object to the `latest` archive

The SQLite online backup command is required because the live analytics database
uses WAL mode. Copying only `usage.sqlite` while CPA Manager Plus is running can
produce an incomplete backup. Each run updates the `latest` archive and its UTC
hour slot, retaining up to 24 hourly rollback points without unbounded growth.

The snapshot is as large as the live database. Set `CLIPROXY_BACKUP_STAGING_DIR`
to stage it on a filesystem other than `$TMPDIR`.

### WatchPaths (file watchers)

The `cliproxyapi-backup-auth` service watches this directory:
- `~/.cli-proxy-api/objectstore/auths` - main auth cache

**How it works (kyber systemd):**
- systemd path unit watches the directories
- On change, triggers the `cliproxyapi-backup-auth.service` oneshot
- Uses `PathChanged` directive for file monitoring

When the directory changes, `backup.sh auth` syncs the CLIProxyAPI auth cache to
S3. The analytics snapshot is deliberately excluded: watch-driven runs of the
full backup wrote roughly 9 GB/hour and exhausted the ext4 journal on kyber.

## Environment Variables

Required in `~/dotfiles/.env`:

```bash
# S3-compatible Object Storage
OBJECTSTORE_ENDPOINT="https://....r2.cloudflarestorage.com"
OBJECTSTORE_BUCKET="cliproxyapi"
OBJECTSTORE_ACCESS_KEY="..."
OBJECTSTORE_SECRET_KEY="..."

# Service Config
CLIPROXY_MANAGEMENT_PASSWORD="..."
OPENROUTER_API_KEY="sk-or-v1-..."
OPENAI_API_KEY="sk-..."
QWEN_API_KEY="sk-..."
ALIYUN_TOKEN_PLAN_API_KEY="sk-sp-..."
VERBOO_API_KEY="..."
SURPLUS_API_KEY="..."
COMMANDCODE_API_KEY="..."
OLLAMA_API_KEY="..."
```

For more than one OpenCode Go account behind the same upstream endpoint, set a
comma-separated credential pool. The plural value takes precedence over the
legacy singular value, and empty or duplicate entries are ignored:

```bash
OPENCODE_API_KEYS="first-opencode-api-key,second-opencode-api-key"
```

For more than one Ollama Cloud account, set `OLLAMA_API_KEYS` to a
comma-separated list. `OLLAMA_API_KEY` and `OLLAMA_API_KEYS` are merged into one
pool, and empty or duplicate entries are ignored:

```bash
OLLAMA_API_KEYS="first-ollama-api-key,second-ollama-api-key"
```

CLIProxyAPI selects from these entries using the configured routing strategy.

### Outbound proxies

`CLIPROXY_PROXY_URL` sets the global `proxy-url` and the `proxy_url` of every
auth file on each start. Auth files whose `proxy_url` is `direct` or `none` are
left alone.

On kyber, `kamino-tunnel-{1,2,3}` open SOCKS tunnels to `kamino<N>` on
`127.0.0.1:108<N>`. `kamino-tunnels.json` at the repository root maps
credentials to them and is installed to `~/.config/cliproxyapi/` on kyber only.
`{credential, host, port}` entries give that auth file
`socks5://127.0.0.1:<port>` instead of the global proxy.
`{provider: "ollama-cloud", key_index: <N>, host, port}` entries do the same for
the Nth Ollama Cloud key, counted from 1 in the deduplicated `OLLAMA_API_KEYS`
then `OLLAMA_API_KEY` pool. A switch that changes the mapping restarts the
tunnels and `cliproxyapi`. A tunnel with nothing mapped to it exits without
connecting. The `kamino<N>` SSH host aliases and their host keys must already be
in `~/.ssh/config` and `~/.ssh/known_hosts`.

## Usage

```bash
# Build and activate
make build && make switch

# Check service status
launchctl list | grep cliproxyapi

# View logs
tail -f /tmp/cliproxyapi.log
tail -f /tmp/cliproxyapi-backup.log
tail -f /tmp/cliproxyapi-backup-auth.log

# OAuth login
cliproxyapi --claude-login

# Usage statistics backup/restore happens automatically on start/exit
```

## Dependencies

This configuration includes a local guard to mitigate the upstream race condition
in CLIProxyAPI until the fix in:
https://github.com/router-for-me/CLIProxyAPI/pull/859

## References

- [CLIProxyAPI Documentation](https://help.router-for.me/)
- [Object Storage Config](https://help.router-for.me/configuration/storage/s3)
