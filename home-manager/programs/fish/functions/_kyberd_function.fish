function _kyberd_function --description "SSH to Kyber with tmux desktop session"
  ssh -t ubuntu@(tailscale ip -4 kyber) "tmux new-session -A -s desktop"
end
