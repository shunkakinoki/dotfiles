{ config, ... }:
{
  # Template config - the service wrapper injects secrets and writes to config.yaml
  home.file.".cli-proxy-api/config.template.yaml" = {
    source = ./config.template.yaml;
    force = true;
  };
  # Example config - required by cliproxyapi's object-backed config bootstrap
  home.file.".cli-proxy-api/config.example.yaml" = {
    source = ./config.template.yaml;
    force = true;
  };
}
