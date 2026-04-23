{ pkgs, ... }:
{
  home.packages = with pkgs; [
    docker
    docker-compose
    dockerfile-language-server
  ];
}
