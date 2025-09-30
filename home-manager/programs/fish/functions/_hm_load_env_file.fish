function _hm_load_env_file --description 'Load environment variables from .env'
  set -l candidate_paths
  if set -q DOTFILES_ENV_FILE
    set -a candidate_paths $DOTFILES_ENV_FILE
  end
  set -a candidate_paths $HOME/dotfiles/.env $HOME/.env

  set -l env_file
  for candidate in $candidate_paths
    if test -f $candidate
      set env_file $candidate
      break
    end
  end

  if test -z "$env_file"
    return
  end

  while read -l line
    set -l trimmed (string trim $line)
    if test -z "$trimmed"
      continue
    end
    if string match -qr '^#' -- $trimmed
      continue
    end

    set trimmed (string replace -r '^export\\s+' '' -- $trimmed)
    set -l parts (string split -m2 '=' -- $trimmed)
    if test (count $parts) -lt 2
      continue
    end

    set -l key (string trim $parts[1])
    set -l value (string trim $parts[2])

    if string match -qr "^'.*'\z" -- $value
      set value (string trim --chars "'" -- $value)
    else if string match -qr '^".*"$' -- $value
      set value (string trim --chars '"' -- $value)
    end

    set -gx $key $value
  end < $env_file
end
