_: {
  home.file.".local/scripts/clipboard-copy" = {
    executable = true;
    force = true;
    source = ./clipboard-copy.sh;
  };
  home.file.".local/scripts/notify-local" = {
    executable = true;
    force = true;
    source = ./notify-local.sh;
  };
}
