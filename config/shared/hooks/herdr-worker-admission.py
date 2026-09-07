#!/usr/bin/env python3
"""Check local Herdr worker starts without executing the submitted command."""

import json
import re
import shlex
import shutil
import socket
import subprocess
import sys
from pathlib import Path


class AdmissionError(Exception):
    pass


def invocations(command):
    # Non-POSIX lexing retains quotes around punctuation-only arguments. The
    # second pass removes quoting only after command boundaries are known.
    lexer = shlex.shlex(command, posix=False, punctuation_chars=";&|()\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    lexer.commenters = ""
    pending = []
    comment = False
    for token in lexer:
        if comment and "\n" not in token:
            continue
        if token.startswith("#"):
            comment = True
            continue
        comment = False
        if token and all(char in ";&|()\n" for char in token):
            if pending:
                yield shlex.split(" ".join(pending))
                pending = []
        else:
            pending.append(token)
    if pending:
        yield shlex.split(" ".join(pending))


def launch_words(words):
    environment_changed = False
    while words:
        if words[0] in {"command", "exec", "do", "then", "else"}:
            words = words[1:]
        elif re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*=.*", words[0]):
            environment_changed = True
            words = words[1:]
        elif Path(words[0]).name == "env":
            words = words[1:]
            while words and words[0].startswith("-"):
                option, separator, argument = words[0].partition("=")
                words = words[1:]
                if option == "--":
                    break
                if option in {"--help", "--version"}:
                    return [], environment_changed
                environment_changed = True
                if option in {
                    "-i",
                    "--ignore-environment",
                    "-0",
                    "--null",
                    "-v",
                    "--debug",
                }:
                    continue
                if option not in {
                    "-u",
                    "--unset",
                    "-C",
                    "--chdir",
                    "-a",
                    "--argv0",
                    "-S",
                    "--split-string",
                }:
                    raise AdmissionError("unsupported env option in Herdr command")
                if not separator:
                    if not words:
                        raise AdmissionError("incomplete env option")
                    argument, words = words[0], words[1:]
                if option in {"-S", "--split-string"}:
                    words = shlex.split(argument) + words
                    break
        else:
            break
    return words, environment_changed


def starts(command, depth=0, environment_changed=False):
    if depth > 4:
        raise AdmissionError("nested shell launch cannot be verified")
    for words in invocations(command):
        words, changed = launch_words(words)
        if not words:
            environment_changed = environment_changed or changed
            continue
        if words[0] in {"export", "unset"}:
            environment_changed = True
            continue
        changed = changed or environment_changed
        executable = Path(words[0]).name
        if executable in {"bash", "sh", "zsh", "fish"}:
            for index, word in enumerate(words[1:], 1):
                if word in {"-c", "-lc", "-ic"} and index + 1 < len(words):
                    yield from starts(words[index + 1], depth + 1, changed)
                    break
        if executable != "herdr":
            continue
        args = words[1:]
        if args[:2] == ["agent", "start"]:
            if changed:
                raise AdmissionError(
                    "worker start environment must match the admission hook"
                )
            yield args[2:]
        elif "agent" in args:
            index = args.index("agent")
            if args[index : index + 2] == ["agent", "start"]:
                raise AdmissionError(
                    "Herdr connection options need host-local admission"
                )


def probe(args):
    binary = shutil.which("herdr")
    if binary is None:
        raise AdmissionError("Herdr metadata is unavailable")
    try:
        result = subprocess.run(
            [binary, *args],
            capture_output=True,
            text=True,
            timeout=0.8,
            check=True,
        )
        value = json.loads(result.stdout)["result"]
        if not isinstance(value, dict):
            raise ValueError("invalid result")
        return value
    except (OSError, subprocess.SubprocessError, ValueError, KeyError) as error:
        raise AdmissionError("Herdr metadata is unavailable or malformed") from error


def require_worker_worktree(args, read=probe, home=None, host=None):
    name = None
    pane_target = None
    index = 0
    while index < len(args):
        value = args[index]
        if value == "--":
            break
        if value in {"--help", "-h"}:
            return None
        option, separator, argument = value.partition("=")
        if option in {"--pane", "--kind", "--timeout"}:
            if not separator:
                index += 1
                if index >= len(args):
                    raise AdmissionError("worker start has an incomplete option")
                argument = args[index]
            if option == "--pane":
                pane_target = argument
        elif value.startswith("-") or name is not None:
            raise AdmissionError("worker start arguments cannot be verified")
        else:
            name = value
        index += 1
    host = (host or socket.gethostname()).split(".")[0].lower()
    orchestrators = {
        f"{host}_orchestrator",
        f"{host}_co_orchestrator",
        f"{host}_orchestrator_fallback",
        f"{host}_co_orchestrator_fallback",
    }
    if name in orchestrators:
        return None
    if not name or not pane_target or not re.fullmatch(r"w[\w-]+:p[\w-]+", pane_target):
        raise AdmissionError("worker start requires an explicit literal pane")

    pane = read(["pane", "get", pane_target]).get("pane", {})
    workspace_id = pane.get("workspace_id")
    if not isinstance(workspace_id, str):
        raise AdmissionError("worker pane has no workspace identity")
    # Pane aliases can resolve to a different workspace after a native move.
    # Trust the returned workspace identity, never the requested pane prefix.
    workspace = read(["workspace", "get", workspace_id]).get("workspace", {})
    worktree = workspace.get("worktree") or {}
    path = worktree.get("checkout_path")
    repo = worktree.get("repo_name")
    source = worktree.get("repo_root")
    if (
        workspace.get("workspace_id") != workspace_id
        or worktree.get("is_linked_worktree") is not True
        or not all(isinstance(value, str) and value for value in (path, repo, source))
        or repo in {".", ".."}
        or "/" in repo
    ):
        raise AdmissionError("worker requires a linked Herdr worktree")
    try:
        checkout = Path(path).resolve()
        root = (Path(home or Path.home()) / ".herdr" / "worktrees" / repo).resolve()
    except (OSError, RuntimeError) as error:
        raise AdmissionError("worker checkout path cannot be resolved") from error
    if (
        not checkout.is_relative_to(root)
        or checkout == root
        or path != str(checkout)
        or pane.get("cwd") != path
    ):
        raise AdmissionError(
            "worker cwd must match its checkout under the Herdr worktree root"
        )

    worktrees = read(["worktree", "list", "--cwd", source]).get("worktrees")
    if not isinstance(worktrees, list):
        raise AdmissionError("worktree association is unavailable")
    matches = [item for item in worktrees if item.get("path") == path]
    if (
        len(matches) != 1
        or matches[0].get("is_linked_worktree") is not True
        or matches[0].get("open_workspace_id") != workspace_id
    ):
        raise AdmissionError("workspace and worktree association disagree")

    agents = read(["agent", "list"]).get("agents")
    if not isinstance(agents, list):
        raise AdmissionError("worker ownership is unavailable")
    for agent in agents:
        same_pane = agent.get("pane_id") == pane.get("pane_id")
        same_name = agent.get("name") == name
        same_checkout = agent.get("cwd") == path
        if (same_pane or same_name or same_checkout) and not (
            same_pane and same_name and same_checkout
        ):
            # A settled turn retains ownership; renaming a duplicate lane does
            # not release the existing worker's checkout.
            raise AdmissionError("worker name or checkout already has another owner")
    return path


def main(command):
    if "herdr" not in command:
        return 0
    try:
        admitted = set()
        for args in starts(command):
            path = require_worker_worktree(args)
            if path is not None and path in admitted:
                raise AdmissionError(
                    "one command cannot start multiple workers in one checkout"
                )
            if path is not None:
                admitted.add(path)
    except (AdmissionError, ValueError, TypeError, AttributeError) as error:
        print(f"BLOCKED by Herdr worker admission: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) == 2 else ""))
