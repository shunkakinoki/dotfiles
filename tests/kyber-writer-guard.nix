{ pkgs }:
{
  kyber-writer-guard = pkgs.runCommand "kyber-writer-guard" { nativeBuildInputs = [ pkgs.bash ]; } ''
    mkdir -p bin
    cp ${../named-hosts/kyber/beads-linear-complete-ssh-guard.sh} bin/beads-linear-complete-ssh-guard
    chmod +x bin/beads-linear-complete-ssh-guard
    cat > bin/beads-linear-complete <<'EOF'
    #!/usr/bin/env bash
    printf '%s\n' "$1" "$2"
    cat
    EOF
    chmod +x bin/beads-linear-complete

    printf 'evidence\n' | SSH_ORIGINAL_COMMAND='beads-linear-complete org/repo bead-123' bin/beads-linear-complete-ssh-guard > actual
    printf 'org/repo\nbead-123\nevidence\n' > expected
    cmp actual expected

    if SSH_ORIGINAL_COMMAND='beads-linear-complete org/repo bead-123; whoami' bin/beads-linear-complete-ssh-guard > rejected 2>&1; then
      exit 1
    fi
    if SSH_ORIGINAL_COMMAND= bin/beads-linear-complete-ssh-guard > rejected 2>&1; then
      exit 1
    fi
    touch "$out"
  '';
}
