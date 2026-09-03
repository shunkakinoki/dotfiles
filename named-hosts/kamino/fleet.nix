{
  count ? 100,
}:
assert builtins.isInt count && count >= 0;
let
  prefix = "kamino";
  tailnet = "tail950b36.ts.net";
  user = "root";
in
{
  inherit prefix count;
  machines = builtins.genList (
    index:
    let
      name = if index == 0 then prefix else "${prefix}${toString index}";
    in
    {
      inherit name user;
      hostname = "${name}.${tailnet}";
    }
  ) (count + 1);
}
