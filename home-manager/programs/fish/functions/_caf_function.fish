function _caf_function --description "Keep the machine awake lid-closed, screen-lock disabled (caffeinate / systemd-inhibit)"
    set -l pid_file "$HOME/.local/state/caf.pid"

    switch "$argv[1]"
        case on
            mkdir -p (dirname "$pid_file")
            if test (uname) = Darwin
                sudo pmset -a disablesleep 1
                caffeinate -dimsu &
            else
                systemd-inhibit --what=handle-lid-switch:sleep:idle \
                    --who=caf --why=caf --mode=block sleep infinity &
            end
            echo $last_pid >"$pid_file"
            disown
            if command -q noctalia-shell
                noctalia-shell msg idleInhibitor enable 2>/dev/null
            end
            if test (uname) != Darwin
                systemctl --user stop ac-idle-inhibit.service 2>/dev/null
            end
            echo "caf on: awake, screen lock disabled (pid "(cat "$pid_file")")"
        case off
            if test (uname) = Darwin
                sudo pmset -a disablesleep 0
            end
            if test -f "$pid_file"
                kill (cat "$pid_file") 2>/dev/null
                rm -f "$pid_file"
            end
            if command -q noctalia-shell
                noctalia-shell msg idleInhibitor disable 2>/dev/null
            end
            if test (uname) != Darwin
                systemctl --user start ac-idle-inhibit.service 2>/dev/null
            end
            echo "caf off: normal sleep and screen lock restored"
        case status
            if test (uname) = Darwin
                pmset -g | string match -e disablesleep
            else
                systemd-inhibit --list 2>/dev/null | string match -e caf
            end
            if test -f "$pid_file"; and kill -0 (cat "$pid_file") 2>/dev/null
                echo "caf active (pid "(cat "$pid_file")")"
            else
                echo "caf inactive"
            end
        case ''
            # Toggle: active if the keeper pid is alive
            if test -f "$pid_file"; and kill -0 (cat "$pid_file") 2>/dev/null
                _caf_function off
            else
                _caf_function on
            end
        case '*'
            echo "Usage: caf [on|off|status]"
            return 1
    end
end
