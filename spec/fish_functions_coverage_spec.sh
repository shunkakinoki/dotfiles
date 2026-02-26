#!/usr/bin/env bash
# shellcheck disable=SC2148,SC2329

Describe 'fish function test coverage'

Parameters:dynamic
for file in $(git ls-files 'home-manager/programs/fish/functions/*.fish'); do
  fname=$(basename "$file" .fish)
  %data "$fname" "$file"
done
End

It "has a fishtape test file: $1"
The path "spec/fish/${1}_test.fish" should be exist
End

End
