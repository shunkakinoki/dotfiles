function _hm_load_env_file --description 'Load environment variables from .env'
  # Parsing lives in home-manager/modules/dotenv/print-env-file.sh so fish, bash
  # and zsh cannot disagree about what a .env line means.
  set -l printer $HM_PRINT_ENV_FILE
  if test -z "$printer"
    set printer $HOME/.config/shell/print-env-file.sh
  end

  if not test -f $printer
    return 0
  end

  sh $printer | while read -l assignment
    set -l parts (string split -m1 '=' -- $assignment)
    if test (count $parts) -eq 2
      set -gx $parts[1] $parts[2]
    end
  end

  return 0
end
