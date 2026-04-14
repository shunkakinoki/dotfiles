function _kyberd_function --description "SSH to Kyber with zellij desktop session"
  ssh -t -i ~/.ssh/id_ed25519 ubuntu@(tailscale ip -4 kyber) "zellij attach desktop -c"
end
