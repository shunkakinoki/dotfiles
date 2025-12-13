#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'all tracked shell files'

syntax_check() {
  local file="$1"
  local first_line=""

  IFS= read -r first_line <"$file" || first_line=""

  case "$first_line" in
  '#!'*bash*) bash -n "$file" ;;
  '#!'*sh*) sh -n "$file" ;;
  *) bash -n "$file" ;;
  esac
}

Parameters:dynamic
for file in $(git ls-files '*.sh'); do
  %data "$file"
done

for file in $(git ls-files); do
  case "$file" in
  *.sh) continue ;;
  esac

  [ -f "$file" ] || continue

  IFS= read -r first_line <"$file" || first_line=""
  case "$first_line" in
  '#!'*bash* | '#!'*sh*)
    %data "$file"
    ;;
  esac
done
End

It "has valid shell syntax: $1"
When call syntax_check "$1"
The status should be success
End

End
