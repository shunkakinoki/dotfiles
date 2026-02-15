function _kyberm_function --description "SSH to Kyber with zellij mobile session"
  ssh -t ubuntu@(tailscale ip -4 kyber) "zellij attach mobile -c"
end
