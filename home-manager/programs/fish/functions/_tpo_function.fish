function _tpo_function --description "Attach to tmux primary session"
  tmux new-session -A -s primary
end
