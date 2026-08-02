function _maticm_function --description "SSH to Matic with tmux mobile session"
  ssh -t shunkakinoki@(tailscale ip -4 matic) "tmux new-session -A -s mobile"
end
