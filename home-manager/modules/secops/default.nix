{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  # imports = [ inputs.agenix.homeManagerModules.default ];

  options.programs.secops.enable = lib.mkEnableOption "manage ssh secrets";

  config = lib.mkIf config.programs.secops.enable {
    age.secrets.sshPrivateKey.file = ../../secrets/ssh/id_ed25519.age;
    home.file.".ssh/id_ed25519" = {
      source = config.age.secrets.sshPrivateKey.path;
      mode = "600";
    };
  };
}
