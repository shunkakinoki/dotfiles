{ ... }:
{
  home.file.".local/bin/clipboard-copy" = {
    executable = true;
    force = true;
    source = ./clipboard-copy.sh;
  };
  home.file.".local/bin/notify-local" = {
    executable = true;
    force = true;
    source = ./notify-local.sh;
  };
}
