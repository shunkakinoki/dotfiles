# Shared agent GitHub guardrails

`block-git-push.sh` and `block-gh-settings.sh` are shared `PreToolUse` hooks for Codex, Claude Code, Cursor, GitHub Copilot, and Grok. They accept the command from each client's supported JSON shape:

- `.tool.input.command`
- `.tool_input.command`
- `.toolArgs.command`
- `.toolInput.command`
- `.command`

Both hooks exit `0` when a command may proceed and exit `2` with a `BLOCKED by ...` diagnostic when it must stop.

Factory Droid uses the Execute matcher for shell commands and the standard edit
matcher for file writes with these shared guardrails.

## Protected operations

The push hook blocks explicit and implicit updates or deletions of `main`, `master`, and the cached remote default branch. It resolves upstream and push configuration, bulk pushes, force variants, and Git aliases without executing alias bodies. Direct pushes remain allowed for `shunkakinoki/wiki` and `shunkakinoki/gthq`.

The settings hook blocks repository control-plane mutations through settings-oriented `gh` commands, REST or GraphQL API calls, and common direct HTTP clients. It splits the command line into individual invocations and judges each one by its own arguments, so quoted text that merely names a command is not matched. GraphQL is judged by the root mutation fields the document invokes, and a document the hook cannot read is treated as a settings mutation. Read-only API calls and ordinary pull request, issue, review, and comment operations remain available.

## Security boundary

These hooks provide fast feedback and prevent common mistakes. They run with the same user permissions as the agent and can be bypassed, disabled, or avoided through an unsupported tool path. Restricted GitHub credentials and server-side branch rulesets are the authoritative controls; do not grant an agent an administrator credential because these hooks are installed.

# Traces agent hook guard

`traces-agent-hook.sh <event> --agent <id>` wraps `traces hook agent` for Codex,
Claude Code, Cursor, GitHub Copilot, Grok, and Antigravity. The traces hook
starts a detached `traces share --trace-id <session> --source agent_hook`
upload on every `prompt-submitted`, `agent-done`, and `session-end` event and
never checks whether one is already running; each upload rescans the shared
trace store, so a busy lane accumulates dozens of uploads of one trace that
contend with each other for hours. The guard reads the hook payload, lists the
current user's in-flight hook uploads, and then:

- terminates uploads older than `TRACES_HOOK_STALE_UPLOAD_SECONDS` (900);
- skips `prompt-submitted` and `agent-done` while the same trace is already
  uploading or `TRACES_HOOK_MAX_INFLIGHT_UPLOADS` (4) uploads are in flight,
  because the running upload or the final `session-end` upload carries the
  trace anyway;
- for `session-end`, terminates the in-flight upload of the same trace and
  always runs the hook so the final upload wins;
- otherwise forwards the payload to `traces hook agent` unchanged.

It exits `0` in every case, including when `traces` is not installed, and the
hook commands keep a trailing `# traces hook agent` marker so `traces hook
install` recognizes them and does not append a second, unguarded hook.
