function _maticd_function --description "SSH to Matic with zellij desktop session"
  ssh -t shunkakinoki@(tailscale ip -4 matic) "zellij attach desktop -c"
end
