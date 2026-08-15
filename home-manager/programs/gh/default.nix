{ pkgs, ... }:
{
  programs.gh = {
    enable = true;
    extensions = with pkgs; [
      gh-markdown-preview
      gh-signoff
      gh-stack
    ];
    settings = {
      editor = "nvim";
      git_protocol = "https";
      prompt = "enabled";
    };
  };
}
