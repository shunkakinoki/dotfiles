# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Plan: Fix CI failures + `_tsh_function` behavior change

## Context

Two independent changes needed on branch `feat/fish-fishtape-tests` (PR #947):

1. **CI fix** — `shell-test` is failing because three test files source fish functions that call `_fzf_preview_name` (as a fzf `--prompt=` argument), but the test files don't source `_fzf_preview_name.fish` first. Even with a mock `fzf`, fish evaluates command substitutions in arguments _before_ calling the functi...

### Prompt 2

commit and push?

