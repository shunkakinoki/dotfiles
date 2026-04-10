#!/usr/bin/env bash
exec @xvfbRun@/bin/xvfb-run -a @obsidian@/bin/obsidian "$@"
