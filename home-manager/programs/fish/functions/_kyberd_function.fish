function _kyberd_function --description "SSH to Kyber with zellij desktop session"
  ssh -t ubuntu@(tailscale ip -4 kyber) "zellij attach desktop -c"
end
