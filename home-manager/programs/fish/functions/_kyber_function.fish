function _kyber_function --description "SSH to Kyber server"
  set -l password (security find-generic-password -s "ssh ubuntu@91.242.214.231" -w 2>/dev/null)
  if test -n "$password"
    sshpass -p $password ssh ubuntu@$KYBER_IP_ADDR
  else
    echo "Password not found in Keychain. Run: security add-generic-password -s 'ssh ubuntu@91.242.214.231' -a ubuntu -w"
    ssh ubuntu@$KYBER_IP_ADDR
  end
end
