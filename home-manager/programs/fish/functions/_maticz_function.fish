function _maticz_function --description "SSH to Matic with zellij desktop session"
  ssh -t shunkakinoki@(tailscale ip -4 matic) "zellij attach -c desktop"
end
