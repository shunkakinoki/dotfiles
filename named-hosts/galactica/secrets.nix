{
  # "my-secret.age".publicKeys = [
  #   config.users.users.shunkakinoki.ssh.publicKey
  #   config.system.ssh.hostKeys.root.publicKey
  # ];

  "id_ed25519.age".publicKeys = [
    # TODO: Replace with your public SSH key from `cat ~/.ssh/id_ed25519.pub`
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA... your_email@domain.com"
  ];
} 