#!/usr/bin/env bash
exec @xvfbRun@/bin/xvfb-run -a @obsidian@/bin/obsidian --no-sandbox --disable-gpu --vault @homeDir@/ghq/github.com/shunkakinoki/wiki "$@"
