# Autoload Zsh Comp
autoload -Uz compinit
typeset -i updated_at=$(date +'%j' -r ~/.zcompdump 2>/dev/null || stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null)
if [ $(date +'%j') != $updated_at ]; then
    compinit -i
else
    compinit -C -i
fi
zmodload -i zsh/complist

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

_tmuxinator() {
    local commands projects
    commands=(${(f)"$(tmuxinator commands zsh)"})
    projects=(${(f)"$(tmuxinator completions start)"})

    if (( CURRENT == 2 )); then
        _alternative \
        'commands:: _describe -t commands "tmuxinator subcommands" commands' \
        'projects:: _describe -t projects "tmuxinator projects" projects'
        elif (( CURRENT == 3)); then
        case $words[2] in
            copy|cp|c|debug|delete|rm|open|o|start|s|edit|e)
                _arguments '*:projects:($projects)'
            ;;
        esac
    fi

    return
}

compdef _tmuxinator tmuxinator mux

# Setopt Zsh Options
setopt always_to_end
setopt auto_cd
setopt auto_list
setopt auto_menu
setopt auto_pushd
setopt correct_all
setopt hist_ignore_all_dups
setopt hist_reduce_blanks
setopt inc_append_history
setopt interactive_comments
setopt list_packed
setopt share_history

# Fix for `%` Sign Showing up on First Line
unsetopt PROMPT_SP

# Unset Zsh Commands
unset zle_bracketed_paste

# Improve Autocompletion Style
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:::::' completer _expand _complete _ignored _approximate
zstyle ':completion:*' cache-path ~/.zsh/cache
zstyle ':completion:*' keep-prefix
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' recent-dirs-insert both
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' verbose no
zstyle ':completion:*:cd:*' ignore-parents parent pwd
zstyle ':completion:*:descriptions' format '%BCompleting%b %U%d%u'

# Load Antibody Plugin Manager
source <(antibody init)

# Install Antibody Plugins
antibody bundle b4b4r07/emoji-cli
antibody bundle b4b4r07/enhancd
antibody bundle caarlos0/zsh-git-sync kind:path
antibody bundle chrissicool/zsh-256color
antibody bundle MichaelAquilina/zsh-auto-notify
antibody bundle MichaelAquilina/zsh-you-should-use
antibody bundle mollifier/cd-gitroot
antibody bundle owenstranathan/pipenv.zsh
antibody bundle paulirish/git-open
antibody bundle paulirish/git-recent
antibody bundle peterhurford/git-it-on.zsh
antibody bundle peterhurford/up.zsh
antibody bundle urbainvaes/fzf-marks
antibody bundle wfxr/forgit
antibody bundle zdharma/zsh-diff-so-fancy
antibody bundle zdharma/fast-syntax-highlighting
antibody bundle zsh-users/zsh-autosuggestions
antibody bundle zsh-users/zsh-completions
antibody bundle zsh-users/zsh-history-substring-search
antibody bundle zuxfoucault/colored-man-pages_mod

fpath+=~/dotfiles/src/shell/zsh_functions
autoload b c da drm ds emoji::cli fd fda fdr fe fkill gbr gbrm gobt gobtp goc tm tmk tp ts

# Source Emoji CLI
zle -N emoji::cli
bindkey "^E" emoji::cli

# Source Shell Files
for file in ~/.shell_*; do
    source "$file"
done

source ~/.zshrc.local

# Eval Zsh Packages
eval $(thefuck --alias)
eval "$(direnv hook zsh)"
eval "$(starship init zsh)"
source "$(navi widget zsh)"
source <(npm completion)
