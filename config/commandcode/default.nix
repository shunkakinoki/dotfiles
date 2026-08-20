{
  config,
  ...
}:
{
  # Command Code (https://commandcode.ai) user settings live in
  # ~/.commandcode/settings.json. Auth is stored separately at
  # ~/.commandcode/auth.json after `cmd login` and must not be managed here.
  home.file.".commandcode/settings.json" = {
    source = ./settings.json;
    force = true;
  };
}
