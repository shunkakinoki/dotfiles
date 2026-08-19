# CLIProxyAPI Service Configuration

This directory contains the Nix-based configuration for the cliproxyapi service with S3-backed auth file management.

## Architecture

### Services

1. **cliproxyapi** - Main proxy server on port 8317
2. **cliproxyapi-backup** - File watcher and wall-clock hourly job that syncs auth files and CPA Manager Plus analytics to S3

### Scripts

| Script | Purpose |
|--------|---------|
| `hydrate.sh` | Pull S3 → local → CCS (runs at activation) |
| `backup.sh` | Push local → S3 → CCS (triggered by WatchPaths) |
| `start.sh` | Load .env, hydrate auth cache if needed, generate config, start service |
| `wrapper.sh` | Load .env, sync auth cache, exec binary (for CLI usage) |

### Directory Structure

```
~/.cli-proxy-api/
├── config.yaml                    # Generated config
├── config.template.yaml           # Template with placeholders
└── objectstore/
    └── auths/                     # Auth files (S3 is source of truth)

~/.ccs/cliproxy/auth/              # CCS auth directory (synced from local)

S3 Storage:
├── s3://cliproxyapi/auths/        # Auth storage
├── s3://cliproxyapi/cpa-manager-plus/analytics-backup-HH.tar.gz
│                                     # 24 hourly rollback slots (UTC)
└── s3://cliproxyapi/cpa-manager-plus/analytics-backup.tar.gz
                                      # Latest SQLite snapshot + matching data.key
```

## Data Flow

``` 
S3 auths/ -> ~/.cli-proxy-api/objectstore/auths -> ~/.ccs/cliproxy/auth
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
2. Copy local → CCS auth dir

### Backup (on auth-file change and each wall-clock hour)

1. Push local → S3 `auths/`
2. Copy local → CCS auth dir
3. Create and integrity-check an online CPA Manager Plus SQLite snapshot
4. Archive the snapshot with its matching `data.key` and upload it to S3

The SQLite online backup command is required because the live analytics database
uses WAL mode. Copying only `usage.sqlite` while CPA Manager Plus is running can
produce an incomplete backup. Each run updates the `latest` archive and its UTC
hour slot, retaining up to 24 hourly rollback points without unbounded growth.

### WatchPaths (file watchers)

The `cliproxyapi-backup` service watches these directories:
- `~/.cli-proxy-api/objectstore/auths` - main auth cache
- `~/.ccs/cliproxy/auth` - CCS auth directory

**How it works (macOS launchd):**
- launchd monitors the directories for any file changes
- When a file is created, modified, or deleted, launchd triggers `backup.sh`
- Changes are detected within ~1 second

**How it works (Linux systemd):**
- systemd path unit watches the directories
- On change, triggers the `cliproxyapi-backup.service` oneshot
- Uses `PathChanged` directive for file monitoring

**Why both directories?**
- `objectstore/auths`: cliproxyapi writes OAuth tokens here after login
- `ccs/cliproxy/auth`: CCS CLI may create tokens here independently

When either directory changes, `backup.sh` syncs everything to S3 and keeps both local directories in sync.

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
```

For more than one OpenCode Go account behind the same upstream endpoint, set a
comma-separated credential pool. The plural value takes precedence over the
legacy singular value, and empty or duplicate entries are ignored:

```bash
OPENCODE_API_KEYS="first-opencode-api-key,second-opencode-api-key"
```

CLIProxyAPI selects from these entries using the configured routing strategy.

## Usage

```bash
# Build and activate
make build && make switch

# Check service status
launchctl list | grep cliproxyapi

# View logs
tail -f /tmp/cliproxyapi.log
tail -f /tmp/cliproxyapi-backup.log

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
