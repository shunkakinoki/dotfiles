# CLIProxyAPI Service Configuration

This directory contains the Nix-based configuration for the cliproxyapi service, including automatic auth file backup/recovery and OAuth token management.

## Overview

The cliproxyapi service provides a unified proxy for multiple AI providers (Claude, Codex, Gemini, OpenRouter, etc.) with automatic authentication management and cloud backup.

## Architecture

### Services

1. **cliproxyapi** - Main proxy server running on port 8317
2. **cliproxyapi-backup** - File watcher that syncs auth files to R2 storage

### Directory Structure

```
~/.cli-proxy-api/
├── config.yaml                    # Generated config (from template)
├── config.template.yaml           # Template with placeholders (symlink)
└── objectstore/
    ├── config/
    │   └── config.yaml            # Cloud-synced config
    └── auths/                     # Auth files (cliproxyapi reads from here)
        ├── claude-*.json          # OAuth tokens for Claude
        ├── codex-*.json           # OAuth tokens for Codex
        └── antigravity-*.json     # OAuth tokens for other services

~/dotfiles/objectstore/auths/      # Git-tracked backup (write-only)
~/.ccs/cliproxy/auth/              # CCS auth directory (two-way sync)

R2 Storage (Cloudflare):
├── s3://cliproxyapi/auths/        # Primary cloud storage
├── s3://cliproxyapi/backup/auths/ # Redundant backup
└── s3://cliproxyapi/config/       # Config backup
```

**Important:** When object storage is enabled (via `OBJECTSTORE_ENDPOINT`), cliproxyapi reads auth files directly from `objectstore/auths/`. There is no separate `auths/` directory at the root level.

## Auth File Management

### On Service Start (`start.sh`)

1. Pull auth files from R2 `auths/` → `objectstore/auths/`
2. Pull from R2 `backup/auths/` → `objectstore/auths/` (merge)
3. **Bootstrap:** If objectstore is empty, copy from `dotfiles/objectstore/auths/`

cliproxyapi then reads directly from `objectstore/auths/` (no additional sync needed).

### On File Changes (`backup-auth.sh`)

Triggered by launchd WatchPaths when files change in:
- `~/.cli-proxy-api/objectstore/auths/`
- `~/.ccs/cliproxy/auth/`

**Flow:**
1. Pull from R2 `auths/` → `objectstore/auths/`
2. Pull from R2 `backup/auths/` → `objectstore/auths/`
3. Sync CCS auth files → `objectstore/auths/` (if exists)
4. Push `objectstore/auths/` → R2 `auths/`
5. Push `objectstore/auths/` → R2 `backup/auths/`
6. Sync `objectstore/auths/` → CCS auth dir
7. Sync `objectstore/auths/` → dotfiles (git tracking)

### Data Flow

```
┌──────────────────┐
│   R2 Storage     │
│  ┌────────────┐  │      ┌──────────────────────────────┐
│  │ auths/     │◄─┼──────┤  objectstore/auths/          │
│  └────────────┘  │      │  (cliproxyapi reads here)    │
│  ┌────────────┐  │      │  ┌────────────────────────┐  │
│  │ backup/    │◄─┼──────┤  │ OAuth tokens stored    │  │
│  └────────────┘  │      │  │ - claude-*.json        │  │
└──────────────────┘      │  │ - codex-*.json         │  │
                          │  │ - antigravity-*.json   │  │
                          │  └────────────────────────┘  │
                          └──────────────────────────────┘
                                       │
                                       ├─────► ccs/auth/
                                       └─────► dotfiles/ (git backup)
                                                   │
                                                   └─► Bootstrap only
```

## Key Features

### 1. OAuth Token Support

Auth files in `~/.cli-proxy-api/objectstore/auths/` are automatically used for OAuth-based API calls. This enables:
- `cliproxyapi --claude-login` for web-based authentication
- OAuth tokens (starting with `sk-ant-oat01-`) work with Claude API requests
- No need for manual API keys (starting with `sk-ant-api03-`)
- cliproxyapi reads directly from `objectstore/auths/` when object storage is enabled

### 2. Multi-Location Backup

Auth files are backed up to:
- **R2 Primary:** `s3://cliproxyapi/auths/`
- **R2 Backup:** `s3://cliproxyapi/backup/auths/`
- **Git:** `~/dotfiles/objectstore/auths/` (version controlled)
- **CCS:** `~/.ccs/cliproxy/auth/` (for CCS compatibility)

### 3. Automatic Recovery

If auth files are lost locally, they are automatically recovered from:
1. R2 primary storage
2. R2 backup storage (if primary is missing files)
3. Git-tracked dotfiles (on fresh install)

### 4. No Circular Loops

**Problem Solved:** Previously, `dotfiles/objectstore/auths` was both watched and written to, creating infinite sync loops.

**Solution:**
- Removed dotfiles from WatchPaths
- Dotfiles is now **write-only** (except for bootstrap on service start)
- Only `objectstore/auths` and `ccs/auth` trigger sync events

### 5. Object Storage Integration

When `OBJECTSTORE_ENDPOINT` is configured, cliproxyapi uses object-backed storage:
- Auth files stored in `objectstore/auths/` subdirectory
- cliproxyapi reads directly from this location (no separate `auths/` directory)
- Files are automatically synced to/from R2 on startup and file changes
- Local `objectstore/` acts as a cache for cloud storage

## Environment Variables

Required in `~/dotfiles/.env`:

```bash
# Object Storage (Cloudflare R2)
OBJECTSTORE_ENDPOINT="https://....r2.cloudflarestorage.com"
OBJECTSTORE_BUCKET="cliproxyapi"
OBJECTSTORE_ACCESS_KEY="..."
OBJECTSTORE_SECRET_KEY="..."

# Management Password
CLIPROXY_MANAGEMENT_PASSWORD="..."

# API Keys (injected into config)
OPENROUTER_API_KEY="sk-or-v1-..."
ZAI_API_KEY="..."
AMP_UPSTREAM_API_KEY="sgamp_user_..."
```

## Usage

### Initial Setup

```bash
# Build and activate configuration
make build && make switch

# The service starts automatically
# Check status
launchctl list | grep cliproxyapi

# View logs
tail -f /tmp/cliproxyapi.log
tail -f /tmp/cliproxyapi.error.log
tail -f /tmp/cliproxyapi-backup.log
```

### OAuth Login

```bash
# Authenticate with Claude
cliproxyapi --claude-login

# This will:
# 1. Open browser for OAuth
# 2. Save token to objectstore/auths/
# 3. Trigger backup to R2 and dotfiles
# 4. Token is immediately usable (cliproxyapi reads from objectstore/auths/)
```

### Testing

```bash
# Test Claude API with OAuth
curl -X POST http://localhost:8317/v1/messages \
  -H "Content-Type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model":"claude-opus-4-5-20251101","messages":[{"role":"user","content":"test"}],"max_tokens":10}'
```

### Troubleshooting

```bash
# Restart service
make restart-cliproxyapi

# Check auth files (with object storage)
ls -la ~/.cli-proxy-api/objectstore/auths/

# Verify R2 sync
aws s3 ls --endpoint-url="$OBJECTSTORE_ENDPOINT" s3://cliproxyapi/auths/

# Force backup
launchctl start org.nix-community.home.cliproxyapi-backup
```

## Recovery Scenarios

### Scenario 1: Fresh Machine Setup

1. Clone dotfiles: `git clone ... ~/dotfiles`
2. Run: `make install`
3. Service starts and bootstraps from `dotfiles/objectstore/auths/`
4. Auth files uploaded to R2 for cloud backup

### Scenario 2: Auth File Accidentally Deleted from R2

1. Backup location still has the file
2. Next sync pulls from `backup/auths/`
3. File automatically restored to `auths/` and `backup/auths/`

### Scenario 3: Local Machine Crash

1. New machine or service restart
2. `start.sh` pulls from R2 on startup
3. All auth files recovered automatically

### Scenario 4: Need to Roll Back Auth

1. Check git history: `git log -- objectstore/auths/`
2. Restore old version from git
3. Remove `~/.cli-proxy-api/objectstore/auths/`
4. Restart service to bootstrap from dotfiles

## Configuration Files

### `default.nix`
- Defines launchd agents (macOS) or systemd services (Linux)
- Sets up WatchPaths for file monitoring
- Configures environment variables

### `scripts/start.sh`
- Runs on service start
- Pulls auth files from R2
- Bootstraps from dotfiles if needed
- Syncs to OAuth directory
- Starts cliproxyapi binary

### `scripts/backup-auth.sh`
- Runs on file changes (WatchPaths)
- Pulls from R2 first (merge remote changes)
- Syncs from CCS if available
- Pushes to R2 (both locations)
- Syncs to all local locations

### `scripts/backup-and-recover.sh`
- Wrapper script that sources `.env`
- Calls `backup-auth.sh`
- Used by launchd agent

## Notes

- **Auth file naming:** Must match pattern `*-shunkakinoki@gmail.com.json` or `*-shunkakinoki_gmail_com.json`
- **OAuth tokens:** Start with `sk-ant-oat01-` (different from API keys which start with `sk-ant-api03-`)
- **File watchers:** Changes in watched directories trigger within ~1 second
- **Sync is idempotent:** Running multiple times is safe
- **Bootstrap runs once:** Only when objectstore is empty
- **Legacy files:** If you see `.json` files in `~/.cli-proxy-api/` (at root level), these are from before object storage was configured. They can be safely deleted - cliproxyapi only reads from `objectstore/auths/` when object storage is enabled.

## References

- [CLIProxyAPI Documentation](https://help.router-for.me/)
- [Object Storage Config](https://help.router-for.me/configuration/storage/s3)
- [Anthropic OAuth](https://docs.anthropic.com/en/api/oauth)
