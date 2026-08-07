function _ssxe_function --description "Run a Fish command once on local, Kyber, and Matic"
  if test (count $argv) -eq 0
    echo "Usage: ssxe <command> [arguments...]" >&2
    return 2
  end

  # Escape each argument before joining it into the Fish source passed to every
  # target. This keeps arguments containing spaces or shell metacharacters intact.
  set -l command (string join ' ' (string escape -- $argv))
  set -l failed 0

  echo "==> local"
  command fish -lc "$command"
  or begin
    echo "==> local failed" >&2
    set failed 1
  end

  echo "==> kyber"
  command ssh kyber fish -lc "$command"
  or begin
    echo "==> kyber failed" >&2
    set failed 1
  end

  echo "==> matic"
  command tailscale ssh shunkakinoki@matic fish -lc "$command"
  or begin
    echo "==> matic failed" >&2
    set failed 1
  end

  return $failed
end
