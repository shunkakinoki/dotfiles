function _vpn_function --description "Connect/disconnect Tailscale exit node through kyber"
  set -l kyber_host kyber

  switch "$argv[1]"
    case on
      tailscale set --exit-node=$kyber_host
      and echo "VPN connected through kyber"
    case off
      tailscale set --exit-node=
      and echo "VPN disconnected"
    case status
      tailscale status
    case ''
      # Toggle: if exit node is set, turn off; otherwise turn on
      set -l current (tailscale status --json 2>/dev/null | jq -r '.ExitNodeStatus.ID // empty')
      if test -n "$current"
        tailscale set --exit-node=
        and echo "VPN disconnected"
      else
        tailscale set --exit-node=$kyber_host
        and echo "VPN connected through kyber"
      end
    case '*'
      echo "Usage: vpn [on|off|status]"
      return 1
  end
end
