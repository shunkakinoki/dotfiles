#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'all tracked shell files'

detect_shell_type() {
  local file="$1"
  local first_line=""

  case "$file" in
  *.fish) printf '%s\n' fish && return 0 ;;
  esac

  IFS= read -r first_line <"$file" || first_line=""
  case "$first_line" in
  '#!'*fish*) printf '%s\n' fish ;;
  '#!'*zsh*) printf '%s\n' zsh ;;
  '#!'*ksh*) printf '%s\n' ksh ;;
  '#!'*bash*) printf '%s\n' bash ;;
  '#!'*sh*) printf '%s\n' sh ;;
  *) printf '%s\n' bash ;;
  esac
}

syntax_check() {
  local shell_type="$1"
  local file="$2"

  case "$shell_type" in
  fish) fish -n "$file" ;;
  zsh) zsh -n "$file" ;;
  ksh) ksh -n "$file" ;;
  sh) sh -n "$file" ;;
  bash | *) bash -n "$file" ;;
  esac
}

Parameters:dynamic
for file in $(git ls-files '*.sh'); do
  %data "$(detect_shell_type "$file")" "$file"
done

for file in $(git ls-files); do
  case "$file" in
  *.sh) continue ;;
  *.fish) continue ;;
  esac

  [ -f "$file" ] || continue

  IFS= read -r first_line <"$file" || first_line=""
  case "$first_line" in
  '#!'*bash* | '#!'*sh* | '#!'*zsh* | '#!'*ksh* | '#!'*fish*)
    %data "$(detect_shell_type "$file")" "$file"
    ;;
  esac
done

for file in $(git ls-files '*.fish'); do
  %data fish "$file"
done
End

It "has valid shell syntax: $2 ($1)"
if ! command -v "$1" >/dev/null 2>&1; then
  Skip "$1 is not installed"
fi
When call syntax_check "$1" "$2"
The status should be success
End

End
