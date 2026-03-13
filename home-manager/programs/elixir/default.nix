{ pkgs, ... }:
{
  home.packages = with pkgs; [
    elixir_1_19
    elixir-ls
    erlang
  ];
}
