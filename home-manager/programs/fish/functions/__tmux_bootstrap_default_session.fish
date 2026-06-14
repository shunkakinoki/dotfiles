function __tmux_bootstrap_default_session --description "Create built-in tmux sessions without tmuxinator"
  set -l session_name $argv[1]
  set -l dotfiles_root ~/dotfiles

  # `new-session -d` boots the server and blocks until the config (plugins) is
  # fully sourced, so the caller's later attach never races a half-initialized
  # server. The window layout that follows is best-effort: a transient failure
  # on a cold/busy server must NOT destroy the session, otherwise `tpo` aborts
  # with no tmux at all ("tmux doesn't start entirely"). As long as the session
  # exists we return success so the caller attaches to whatever was built.

  switch $session_name
    case primary mobile desktop
      tmux new-session -d -s $session_name -n btop
      if test $status -ne 0
        # Lost a race / already exists: treat an existing session as success.
        tmux has-session -t $session_name 2>/dev/null
        return $status
      end

      tmux send-keys -t $session_name:0 btop C-m
      tmux new-window -c $dotfiles_root -t $session_name:1 -n dotfiles
      tmux split-window -c $dotfiles_root -t $session_name:1
      tmux select-layout -t $session_name:1 even-horizontal
      tmux new-window -t $session_name:2 -n $session_name
      tmux select-window -t $session_name:0
      tmux select-pane -t $session_name:0.0
      return 0

    case work
      tmux new-session -d -s work -n editor
      if test $status -ne 0
        tmux has-session -t work 2>/dev/null
        return $status
      end

      tmux send-keys -t work:0 nvim C-m
      tmux new-window -t work:1 -n shell
      tmux new-window -t work:2 -n work
      tmux select-window -t work:0
      tmux select-pane -t work:0.0
      return 0

    case '*'
      echo "Unknown built-in tmux session '$session_name'" >&2
      return 1
  end
end
