# Autoload Zsh Comp
autoload -Uz compinit
typeset -i updated_at=$(date +'%j' -r ~/.zcompdump 2>/dev/null || stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null)
if [ $(date +'%j') != $updated_at ]; then
    compinit -i
else
    compinit -C -i
fi
zmodload -i zsh/complist

# History Options
HISTFILE=$HOME/.zsh_history
HISTSIZE=100000
SAVEHIST=$HISTSIZE

# Autojump Configuration
[[ -s `brew --prefix`/etc/autojump.sh ]] && . `brew --prefix`/etc/autojump.sh

# Hyper Tab Title Settings
# From: https://github.com/zeit/hyper/issues/1188#issuecomment-332606903
# Override auto-title when static titles are desired ($ title My new title)
title() { export TITLE_OVERRIDDEN=1; echo -en "\e]0;$*\a"}

# Turn off static titles ($ autotitle)
autotitle() { export TITLE_OVERRIDDEN=0 }; autotitle

# Condition checking if title is overridden
overridden() { [[ $TITLE_OVERRIDDEN == 1 ]]; }

# Echo asterisk if git state is dirty
gitDirty() { [[ $(git status 2> /dev/null | grep -o '\w\+' | tail -n1) != ("clean"|"") ]] && echo "*" }

# Show cwd when shell prompts for input.
precmd() {
    if overridden; then return; fi
    pwd=$(pwd) # Store full path as variable
    cwd=${pwd##*/} # Extract current working dir only
    print -Pn "\e]0;$cwd$(gitDirty)\a" # Replace with $pwd to show full path
}

# Prepend command (w/o arguments) to cwd while waiting for command to complete.
preexec() {
    if overridden; then return; fi
    printf "\033]0;%s\a" "${1%% *} | $cwd$(gitDirty)" # Omit construct from $1 to show args
}

# Setopt Zsh Options
setopt auto_cd
setopt auto_list
setopt auto_menu
setopt always_to_end
setopt hist_ignore_all_dups
setopt hist_reduce_blanks
setopt inc_append_history
setopt share_history
setopt correct_all
setopt interactive_comments

# Fix for `%` Sign Showing up on First Line
unsetopt PROMPT_SP

# Unset Zsh Commands
unset zle_bracketed_paste

# Improve Autocompletion Style
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:::::' completer _expand _complete _ignored _approximate

# Load Antibody Plugin Manager
source <(antibody init)

# Install Antibody Plugins
antibody bundle b4b4r07/emoji-cli
antibody bundle b4b4r07/enhancd
antibody bundle chrissicool/zsh-256color
antibody bundle MichaelAquilina/zsh-auto-notify
antibody bundle MichaelAquilina/zsh-you-should-use
antibody bundle mollifier/cd-gitroot
antibody bundle owenstranathan/pipenv.zsh
antibody bundle paulirish/git-open
antibody bundle peterhurford/git-it-on.zsh
antibody bundle zdharma/fast-syntax-highlighting
antibody bundle zsh-users/zsh-autosuggestions
antibody bundle zsh-users/zsh-completions
antibody bundle zsh-users/zsh-history-substring-search

# Source Shell Files
for file in ~/.shell_*; do
    source "$file"
done

# Eval Zsh Packages
eval "$(direnv hook zsh)"
eval "$(starship init zsh)"
source "$(navi widget zsh)"
