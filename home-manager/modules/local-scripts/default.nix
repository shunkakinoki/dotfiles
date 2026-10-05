_: {
  home.file.".local/scripts/clipboard-copy" = {
    executable = true;
    source = ./clipboard-copy.sh;
  };
  home.file.".local/scripts/clipboard-copy-image" = {
    executable = true;
    source = ./clipboard-copy-image.sh;
  };
  home.file.".local/scripts/clipboard-copy-file" = {
    executable = true;
    source = ./clipboard-copy-file.sh;
  };
  home.file.".local/scripts/clipboard-paste" = {
    executable = true;
    source = ./clipboard-paste.sh;
  };
  home.file.".local/scripts/decafinate" = {
    executable = true;
    source = ./decafinate.sh;
  };
  home.file.".local/scripts/notify-local" = {
    executable = true;
    source = ./notify-local.sh;
  };
  home.file.".local/scripts/pushover-notify" = {
    executable = true;
    source = ./pushover-notify.sh;
  };
  home.file.".local/scripts/tmux-bridge" = {
    executable = true;
    source = ./tmux-bridge.sh;
  };
}
