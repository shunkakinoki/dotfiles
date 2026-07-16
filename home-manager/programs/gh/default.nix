{ pkgs, ... }:
{
  programs.gh = {
    enable = true;
    extensions = with pkgs; [ gh-markdown-preview gh-stack ];
    settings = {
      editor = "nvim";
      git_protocol = "https";
      prompt = "enabled";
    };
  };
}
