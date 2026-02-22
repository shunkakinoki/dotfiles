# Session Context

## User Prompts

### Prompt 1

hi

### Prompt 2

hi

### Prompt 3

claude code has worktree + tmux support now 
Boris Cherny
@bcherny
·
23h
Introducing: built-in git worktree support for Claude Code 

Now, agents can run in parallel without interfering with one other. Each agent gets its own worktree and can work independently.

The Claude Code Desktop app has had built-in support for worktrees for a while, and now
Show more
Boris Cherny
@bcherny
·
23h
1/ Use claude --worktree for isolation

To run Claude Code in its own git worktree, just start it with the -...

### Prompt 4

yes but w/ worktree?

### Prompt 5

WorktreeCreate
When you run claude --worktree or a subagent uses isolation: "worktree", Claude Code creates an isolated working copy using git worktree. If you configure a WorktreeCreate hook, it replaces the default git behavior, letting you use a different version control system like SVN, Perforce, or Mercurial.
The hook must print the absolute path to the created worktree directory on stdout. Claude Code uses this path as the working directory for the isolated session.
This example creates an...

### Prompt 6

[Request interrupted by user]

### Prompt 7

/worktrunk
command

### Prompt 8

Base directory for this skill: /Users/shunkakinoki/.claude/plugins/cache/worktrunk/worktrunk/aebc07520b9c/skills/worktrunk

<!-- worktrunk-skill-version: 0.9.3 -->

# Worktrunk

Help users work with Worktrunk, a CLI tool for managing git worktrees.

## Available Documentation

Reference files are synced from [worktrunk.dev](https://worktrunk.dev) documentation:

- **reference/config.md**: User and project configuration (LLM, hooks, command defaults)
- **reference/hook.md**: Hook types, timing, a...

### Prompt 9

ok; but modify @config/claude/

### Prompt 10

does it use worktrun's native features such as copying files?

### Prompt 11

how to configure worktrunk to copy certain directories

### Prompt 12

no; ok let's configure ./config/wt to how to do this w/ nixos

