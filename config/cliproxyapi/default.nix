{ config, ... }:
{
  # Template config - the service wrapper injects secrets and writes to config.yaml
  home.file.".cli-proxy-api/config.template.yaml" = {
    source = config.lib.file.mkOutOfStoreSymlink ./config.yaml;
  };
}
