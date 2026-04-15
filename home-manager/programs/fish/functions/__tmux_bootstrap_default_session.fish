function __tmux_bootstrap_default_session --description "Create built-in tmux sessions without tmuxinator"
  set -l session_name $argv[1]
  set -l dotfiles_root ~/dotfiles

  switch $session_name
    case primary mobile desktop
      tmux new-session -d -s $session_name -n btop
      if test $status -ne 0
        tmux has-session -t $session_name 2>/dev/null
        return $status
      end

      if not begin
        tmux send-keys -t $session_name:0 btop C-m
        and tmux new-window -c $dotfiles_root -t $session_name:1 -n dotfiles
        and tmux split-window -c $dotfiles_root -t $session_name:1
        and tmux select-layout -t $session_name:1 even-horizontal
        and tmux new-window -t $session_name:2 -n $session_name
        and tmux select-window -t $session_name:0
        and tmux select-pane -t $session_name:0.0
      end
        tmux kill-session -t $session_name 2>/dev/null
        return 1
      end

    case work
      tmux new-session -d -s work -n editor
      if test $status -ne 0
        tmux has-session -t work 2>/dev/null
        return $status
      end

      if not begin
        tmux send-keys -t work:0 nvim C-m
        and tmux new-window -t work:1 -n shell
        and tmux new-window -t work:2 -n work
        and tmux select-window -t work:0
        and tmux select-pane -t work:0.0
      end
        tmux kill-session -t work 2>/dev/null
        return 1
      end

    case '*'
      echo "Unknown built-in tmux session '$session_name'" >&2
      return 1
  end
end
