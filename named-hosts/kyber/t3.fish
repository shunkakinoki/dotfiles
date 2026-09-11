function t3 --description "Run T3 with Kyber's dedicated Tailscale Serve port"
    if test (count $argv) -gt 0; and test "$argv[1]" = pair; and contains -- --tailscale $argv
        set -l has_serve_port false
        for arg in $argv
            if string match -qr '^--tailscale-serve-port(=|$)' -- $arg
                set has_serve_port true
                break
            end
        end

        if not $has_serve_port
            command t3 $argv --tailscale-serve-port 8443
            return $status
        end
    end

    command t3 $argv
end
