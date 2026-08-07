function _ssxe_function --description "Run a one-time command locally, on Kyber, and on Matic"
  if test (count $argv) -eq 0
    echo "Usage: ssxe <command> [args...]" >&2
    return 2
  end

  set -l command (string join ' ' -- $argv)
  set -l result 0

  echo "==> local"
  sh -c "$command"; or set result 1

  echo "==> kyber"
  printf '%s\n' "$command" | ssh kyber sh -s; or set result 1

  echo "==> matic"
  printf '%s\n' "$command" | tailscale ssh shunkakinoki@matic sh -s; or set result 1

  return $result
end
