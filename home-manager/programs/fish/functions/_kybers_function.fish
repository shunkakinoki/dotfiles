function _kybers_function --description "SSH to Kyber server via Tailscale with zellij"
  tailscale ssh ubuntu@kyber zellij attach -c
end
