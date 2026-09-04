# The Nix check loads the actual generated functions before this behavior test.
if test (count $argv) -eq 0
    echo 'No fleet hosts supplied to the shortcut check' >&2
    exit 1
end

function ssh
    set -g called ssh $argv
    return $command_status
end

function herdr
    set -g called herdr $argv
    return $command_status
end

function expect_call
    if test (count $called) -ne (count $argv)
        printf 'Wrong argument count for %s\n' "$called" >&2
        exit 1
    end
    for index in (seq (count $argv))
        if test "$called[$index]" != "$argv[$index]"
            printf 'Argument %s: expected <%s>, got <%s>\n' $index "$argv[$index]" "$called[$index]" >&2
            exit 1
        end
    end
end

set -g command_status 0
for host in $argv
    set -l shortcut _{$host}_function
    $shortcut 'printf hello' 'two words'
    expect_call ssh $host 'printf hello' 'two words'

    set shortcut _{$host}d_function
    $shortcut
    expect_call ssh -t $host 'tmux new-session -A -s desktop'

    set shortcut _{$host}h_function
    $shortcut --help 'two words'
    expect_call herdr --remote $host --help 'two words'

    set shortcut _{$host}m_function
    $shortcut
    expect_call ssh -t $host 'tmux new-session -A -s mobile'

    set shortcut _{$host}z_function
    $shortcut
    expect_call ssh -t $host 'zellij attach -c desktop'

    set -g command_status 23
    for suffix in '' d h m z
        set shortcut _{$host}{$suffix}_function
        $shortcut
        if test $status -ne 23
            printf 'Lost command failure status: %s\n' $shortcut >&2
            exit 1
        end
    end
    set -g command_status 0
end

printf 'Verified all five shortcuts for %s fleet hosts\n' (count $argv)
