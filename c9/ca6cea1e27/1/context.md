# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Plan: Pane Content Storage — Best Approach

## Context

The current pane snapshot approach has three problems:

1. **Opaque filenames** — files named `3.txt`, `7.txt` by numeric pane ID, which resets on server restart and is unreadable
2. **No stale cleanup** — files for closed panes accumulate forever; old IDs from previous server sessions leave ghost files
3. **Shallow scrollback** — `tmux capture-pane -S -` is bounded by `history-limit`, which defaults to o...

### Prompt 2

yea set it to 0

### Prompt 3

fix make shell-test and shell-lint

### Prompt 4

so take me through on the directory and format aand the contexnts of pane and how they would be stored again?

### Prompt 5

hmm but how does it store the full history doesn't it overwrite!

### Prompt 6

create PR

