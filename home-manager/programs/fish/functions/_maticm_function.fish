function _maticm_function --description "SSH to Matic with zellij mobile session"
  ssh -t shunkakinoki@(tailscale ip -4 matic) "zellij attach mobile -c"
end
