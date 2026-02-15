function _kyberm_function --description "SSH to Kyber with tmux mobile session"
  ssh -t ubuntu@(tailscale ip -4 kyber) "tmux new-session -A -s mobile"
end
