{ pkgs, lib }:
let
  fishModule = import ../home-manager/programs/fish {
    inherit pkgs lib;
    config.home = {
      username = "fish-startup-test";
      homeDirectory = "/homeless-shelter";
    };
  };
  nixPathInit =
    pkgs.writeText "00-nix-path.fish"
      fishModule.xdg.configFile."fish/conf.d/00-nix-path.fish".text;
in
{
  fish-ssh-startup = pkgs.runCommand "fish-ssh-startup" { } ''
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export TERM=xterm
    mkdir -p "$XDG_CONFIG_HOME/fish/conf.d" "$HOME/.nix-profile"
    ln -s ${pkgs.grc}/bin "$HOME/.nix-profile/bin"
    cp ${nixPathInit} "$XDG_CONFIG_HOME/fish/conf.d/00-nix-path.fish"
    # Exercise the real plugin that previously printed its missing-grc warning.
    cat > "$XDG_CONFIG_HOME/fish/conf.d/plugin-grc.fish" <<'FISH'
    set -g fish_function_path ${pkgs.fishPlugins.grc.src}/functions $fish_function_path
    source ${pkgs.fishPlugins.grc.src}/conf.d/grc.fish
    FISH

    expected="$(${pkgs.coreutils}/bin/uname -s)
    $(${pkgs.coreutils}/bin/uname -m)"
    # No Nix profile paths or saved Fish universal variables in the environment.
    for mode in --no-config noninteractive --login --interactive; do
      flags="$mode"
      if [ "$mode" = noninteractive ]; then flags=""; fi
      PATH=${pkgs.coreutils}/bin ${pkgs.fish}/bin/fish $flags \
        -c 'uname -s; uname -m' > actual 2> errors
      test "$(cat actual)" = "$expected"
      test ! -s errors
    done
    PATH=${pkgs.coreutils}/bin ${pkgs.fish}/bin/fish \
      -c 'command -q grc; and functions -q ls'
    touch "$out"
  '';
}
