{ pkgs, ... }:
{
  home.packages = with pkgs; [
    opentofu
    # terraform # builds from source for 45+ minutes on a loaded host; re-enable once the cache serves it
    terraform-ls
  ];
}
