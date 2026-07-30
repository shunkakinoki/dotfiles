{ pkgs, ... }:
{
  home.packages = with pkgs; [
    beamPackages.elixir_1_19
    beamPackages.elixir-ls
    beamPackages.erlang
  ];
}
