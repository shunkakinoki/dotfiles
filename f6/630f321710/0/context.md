# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Plan: Reconfigure tmuxinator session layouts

## Context

Update the three tmuxinator configs (`primary`, `mobile`, `desktop`) used by
`tpo`/`tmo`/`tdo` to have a consistent layout:
- Window 0: `btop` (system monitor)
- Window 1: `dotfiles` — 1:1 vertical split (two equal shell panes), cwd `~/dotfiles`
- Remove the `bun run dev` server window

## Changes

**Files to modify:**
- `config/tmuxinator/tmuxinator/primary.yml`
- `config/tmuxinator/tmuxinator/mobile.y...

### Prompt 2

ok commit and push

