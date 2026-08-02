function _maticd_function --description "SSH to Matic with tmux desktop session"
  ssh -t shunkakinoki@(tailscale ip -4 matic) "tmux new-session -A -s desktop"
end
