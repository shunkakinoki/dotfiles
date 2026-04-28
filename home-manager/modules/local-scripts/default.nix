_: {
  home.file.".local/scripts/clipboard-copy" = {
    executable = true;
    force = true;
    source = ./clipboard-copy.sh;
  };
  home.file.".local/scripts/clipboard-paste" = {
    executable = true;
    force = true;
    source = ./clipboard-paste.sh;
  };
  home.file.".local/scripts/decafinate" = {
    executable = true;
    force = true;
    source = ./decafinate.sh;
  };
  home.file.".local/scripts/notify-local" = {
    executable = true;
    force = true;
    source = ./notify-local.sh;
  };
  home.file.".local/scripts/pushover-notify" = {
    executable = true;
    force = true;
    source = ./pushover-notify.sh;
  };
  home.file.".local/scripts/slb" = {
    executable = true;
    force = true;
    source = ./slb.sh;
  };
  home.file.".local/scripts/ulb" = {
    executable = true;
    force = true;
    source = ./ulb.sh;
  };
  home.file.".local/scripts/tmux-bridge" = {
    executable = true;
    force = true;
    source = ./tmux-bridge.sh;
  };
}
