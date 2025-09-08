{ pkgs }:
{
  fonts = {
    packages = [
      pkgs.fira-code
      # Temporarily commented out due to build issues
      # pkgs.jetbrains-mono
    ];
  };
}
