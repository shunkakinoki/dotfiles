#!/usr/bin/env bash
exec @xvfbRun@/bin/xvfb-run -a -s "-screen 0 1280x1024x24" @obsidian@/bin/obsidian --no-sandbox --disable-gpu --disable-features=FontationsFontIndexer --remote-debugging-port=9222 --vault @homeDir@/ghq/github.com/shunkakinoki/wiki "$@"
