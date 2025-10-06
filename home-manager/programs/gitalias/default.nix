{ pkgs, ... }:
let
  # Fetch GitAlias from GitHub
  gitaliasSource = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/GitAlias/gitalias/main/gitalias.txt";
    sha256 = "0000000000000000000000000000000000000000000000000000";
  };

  # Generator script that converts GitAlias to shell aliases
  generateBashAliases = pkgs.writeShellScript "generate-bash-aliases" ''
    ${pkgs.gnugrep}/bin/grep -E '^\s*[a-zA-Z0-9_-]+\s*=' "$1" | while IFS= read -r line; do
      [[ "$line" =~ ^[[:space:]]*# ]] && continue

      alias_name=$(echo "$line" | ${pkgs.gawk}/bin/awk -F'=' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')
      alias_cmd=$(echo "$line" | ${pkgs.gnused}/bin/sed -E 's/^[^=]+=\s*//' | ${pkgs.gnused}/bin/sed -E 's/^\s+//')

      [[ -z "$alias_name" || -z "$alias_cmd" ]] && continue

      # Skip complex aliases
      if [[ "$alias_cmd" =~ \\$ ]] || [[ "$alias_cmd" =~ %C ]] || [[ "$alias_cmd" =~ ^! ]] || \
         [[ "$alias_cmd" =~ GIT_ ]] || [[ "$alias_cmd" =~ \![[:space:]] ]] || \
         [[ "$alias_cmd" =~ ![a-z] ]] || [[ "$alias_cmd" =~ @\{ ]] || \
         [[ "$alias_cmd" =~ \"-[a-z] ]] || [[ "$alias_cmd" =~ \\\' ]] || \
         [[ "$alias_cmd" =~ \"! ]]; then
        continue
      fi

      alias_cmd="''${alias_cmd//\'/\'\\\'\'}"
      echo "alias g''${alias_name}='git ''${alias_cmd}'"
    done
  '';

  generateZshAliases = generateBashAliases; # Same logic for zsh

  generateFishAbbrs = pkgs.writeShellScript "generate-fish-abbrs" ''
    ${pkgs.gnugrep}/bin/grep -E '^\s*[a-zA-Z0-9_-]+\s*=' "$1" | while IFS= read -r line; do
      [[ "$line" =~ ^[[:space:]]*# ]] && continue

      alias_name=$(echo "$line" | ${pkgs.gawk}/bin/awk -F'=' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')
      alias_cmd=$(echo "$line" | ${pkgs.gnused}/bin/sed -E 's/^[^=]+=\s*//' | ${pkgs.gnused}/bin/sed -E 's/^\s+//')

      [[ -z "$alias_name" || -z "$alias_cmd" ]] && continue

      # Skip complex aliases
      if [[ "$alias_cmd" =~ \\$ ]] || [[ "$alias_cmd" =~ %C ]] || [[ "$alias_cmd" =~ ^! ]] || \
         [[ "$alias_cmd" =~ GIT_ ]] || [[ "$alias_cmd" =~ \![[:space:]] ]] || \
         [[ "$alias_cmd" =~ ![a-z] ]] || [[ "$alias_cmd" =~ @\{ ]] || \
         [[ "$alias_cmd" =~ \\\' ]] || [[ "$alias_cmd" =~ \"! ]]; then
        continue
      fi

      alias_cmd="''${alias_cmd//\'/\\\\\'}"
      echo "abbr -a g''${alias_name} 'git ''${alias_cmd}'"
    done
  '';

  # Generate the alias files at build time
  bashAliases = pkgs.runCommand "gitalias-bash" { } ''
    ${generateBashAliases} ${gitaliasSource} > $out
  '';

  zshAliases = pkgs.runCommand "gitalias-zsh" { } ''
    ${generateZshAliases} ${gitaliasSource} > $out
  '';

  fishAbbrs = pkgs.runCommand "gitalias-fish" { } ''
    ${generateFishAbbrs} ${gitaliasSource} > $out
  '';
in
{
  bash = builtins.readFile bashAliases;
  zsh = builtins.readFile zshAliases;
  fish = builtins.readFile fishAbbrs;
}
