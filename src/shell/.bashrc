# Source Shell Files
for file in ~/.shell_*; do
  source "$file"
done

eval "$(starship init bash)"
