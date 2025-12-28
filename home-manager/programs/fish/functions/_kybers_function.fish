function _kybers_function --description "SSH to Kyber server via Tailscale with zellij"
  ssh -t ubuntu@(tailscale ip -4 kyber) "zellij attach main -c"
end
