# Custom key bindings for Fish shell
# Note: This filename must NOT have an underscore prefix (_) because Fish's
# autoloading mechanism requires the filename to match the function name exactly.
# Fish automatically calls this function after fish_vi_key_bindings is set.
function fish_user_key_bindings
  # Exit vim insert mode with jj (like in Vim)
  bind -M insert jj 'set fish_bind_mode default; commandline -f repaint-mode'

  # Ctrl+V = paste from clipboard (macOS-style via keyd Framework key)
  bind \cv fish_clipboard_paste
  bind -M insert \cv fish_clipboard_paste
end
