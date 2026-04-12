#!/usr/bin/env bash
# Remove hm-backup files from ~/.codex
find ~/.codex -name "*.hm-backup*" -delete 2>/dev/null || true
