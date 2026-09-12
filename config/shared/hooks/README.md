# Shared agent GitHub guardrails

`block-git-push.sh` and `block-gh-settings.sh` are shared `PreToolUse` hooks for Codex, Claude Code, Cursor, GitHub Copilot, Grok, and Devin. They accept the command from each client's supported JSON shape:

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

## Herdr worker starts

The shared security hook admits local `herdr agent start` commands only after
reading the target pane, workspace, linked worktree, and existing agent owners.
A worker needs an explicit pane, consistent metadata and cwd under
`~/.herdr/worktrees/<repo>/`, and no other owner of its name or checkout.
Settled agents retain ownership. Missing, malformed, or timed-out metadata
blocks the command before the submitted launch executes. Multiple starts in
one command cannot share a checkout. Environment-changing prefixes are refused
for worker starts because probes must inspect the same Herdr server as the launch.

The local host's canonical main/co-orchestrator names, including their named
fallback seats, remain available in the root workspace. Read-only commands,
help, and hold prompts are unaffected. OpenCode has its own lowercase `bash`
matcher pointing at this shared hook; its Claude-hook adapter does not match
Claude's uppercase `Bash` entries. The helper evaluates command text and uses
only read-only Herdr probes; it never launches, moves, or stops an agent.

This is admission for local shell starts through supported hooks. It does not
prove task or PR ownership and is not a native Herdr server policy. Direct API
calls, unhooked remote execution, and other unsupported launch paths still
need their authoritative lifecycle controls.

## Security boundary

These hooks provide fast feedback and prevent common mistakes. They run with the same user permissions as the agent and can be bypassed, disabled, or avoided through an unsupported tool path. Restricted GitHub credentials and server-side branch rulesets are the authoritative controls; do not grant an agent an administrator credential because these hooks are installed.

# Traces agent hook guard

`traces-agent-hook.sh <event> --agent <id>` wraps `traces hook agent` for Codex,
Claude Code, Cursor, GitHub Copilot, Grok, Devin, Antigravity, Pi, Hermes, and
OpenClaw; the Pi, Hermes, and OpenClaw adapters spawn it directly and pass
the binary they resolved as `TRACES_BIN`.

On Kyber, the managed `traces-agent-uploads` helper writes hook requests into
`~/.local/state/traces-agent-uploads` with private directory/file permissions
(0700/0600). It preserves the resolved binary, working directory, arguments,
stdin payload, and trace configuration environment overrides. Environment values
are passed outside process arguments. Registration precedes the latest pending
progress event, followed
by `session-end`. Progress events for the same session, agent, and working
directory coalesce; a final event is retained behind an in-flight upload instead
of canceling it or bypassing the concurrency limit.

One drainer holds an OS file lock through the entire hook invocation. A single
transient `traces-agent-upload.service` uses `ExitType=cgroup`, so the slot stays
occupied until the upstream hook's detached uploader also exits. The
`traces-uploads.slice` budget is 5 MB/s reads, 2 MB/s writes, 100 read IOPS, and
50 write IOPS on the root filesystem, plus one CPU, 2 GiB memory high, 4 GiB
memory maximum, and 128 tasks. It is separate from agent and coordinator services.

Each upload has a 15-minute deadline. Failed launches and timeouts retain the
request with a bounded retry delay; a one-minute timer recovers missed wakeups
and retries even after the last hook event. Pending requests survive service
restarts. Requests whose working directories have been removed stay queued for
operator resolution. Before a final hook, the queue retains its resolved trace ID from
`traces-active.json`; if that hook removes the registration and then times out,
the retry uses `traces share --trace-id` for that same trace. Stopping the drainer
also stops its upload unit. Completion means the
hook and its children exited; the upstream hook's best-effort remote delivery
does not provide an upload acknowledgement through its exit status. Visibility,
destination rules, and authentication remain owned by `traces`.

On other hosts, the existing process guard remains in use. The traces hook
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
