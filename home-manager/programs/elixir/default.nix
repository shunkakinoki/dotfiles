{ pkgs, ... }:
{
  home.packages = with pkgs; [
    beamPackages.elixir_1_19
    elixir-ls
    beamPackages.erlang
  ];
}
