# Shared agent GitHub guardrails

`block-git-push.sh` and `block-gh-settings.sh` are shared `PreToolUse` hooks for Codex, Claude Code, Cursor, GitHub Copilot, and Grok. They accept the command from each client's supported JSON shape:

- `.tool.input.command`
- `.tool_input.command`
- `.toolArgs.command`
- `.toolInput.command`
- `.command`

Both hooks exit `0` when a command may proceed and exit `2` with a `BLOCKED by ...` diagnostic when it must stop.

## Protected operations

The push hook blocks explicit and implicit updates or deletions of `main`, `master`, and the cached remote default branch. It resolves upstream and push configuration, bulk pushes, force variants, and Git aliases without executing alias bodies. Direct pushes remain allowed for `shunkakinoki/wiki` and `shunkakinoki/gthq`.

The settings hook blocks repository control-plane mutations through settings-oriented `gh` commands, REST or GraphQL API calls, and common direct HTTP clients. Read-only API calls and ordinary pull request, issue, review, and comment operations remain available.

## Security boundary

These hooks provide fast feedback and prevent common mistakes. They run with the same user permissions as the agent and can be bypassed, disabled, or avoided through an unsupported tool path. Restricted GitHub credentials and server-side branch rulesets are the authoritative controls; do not grant an agent an administrator credential because these hooks are installed.
