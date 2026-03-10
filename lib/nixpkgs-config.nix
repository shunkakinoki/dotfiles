{ nixpkgsLib }:
{
  allowUnfree = true;
  allowUnfreePredicate =
    pkg:
    builtins.elem (nixpkgsLib.getName pkg) [
      "1password"
      "claude-code"
      "clickup"
      "crush"
      "qwen-code"
      "slack"
      "vscode"
    ];
  joypixels.acceptLicense = true;
}
