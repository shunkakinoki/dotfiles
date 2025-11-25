{ nixpkgsLib }:
{
  allowUnfree = true;
  allowUnfreePredicate =
    pkg:
    builtins.elem (nixpkgsLib.getName pkg) [
      "claude-code"
      "qwen-code"
      "crush"
    ];
}
