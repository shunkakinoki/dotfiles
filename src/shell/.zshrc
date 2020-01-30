# Autoload Zsh Comp
autoload -Uz compinit
typeset -i updated_at=$(date +'%j' -r ~/.zcompdump 2>/dev/null || stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null)
if [ $(date +'%j') != $updated_at ]; then
    compinit -i
else
    compinit -C -i
fi
zmodload -i zsh/complist

# Hyper Tab Title Settings
# From: https://github.com/zeit/hyper/issues/1188#issuecomment-332606903
# Override auto-title when static titles are desired ($ title My new title)
title() { export TITLE_OVERRIDDEN=1; echo -en "\e]0;$*\a"}

# Turn off static titles ($ autotitle)
autotitle() { export TITLE_OVERRIDDEN=0 }; autotitle

# Condition checking if title is overridden
overridden() { [[ $TITLE_OVERRIDDEN == 1 ]]; }

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
setopt prompt_cr
setopt prompt_sp
setopt share_history

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
antibody bundle Aloxaf/fzf-tab
antibody bundle b4b4r07/emoji-cli
antibody bundle b4b4r07/enhancd
antibody bundle caarlos0/zsh-git-sync kind:path
antibody bundle chrissicool/zsh-256color
antibody bundle darvid/zsh-poetry
antibody bundle MichaelAquilina/zsh-auto-notify
antibody bundle MichaelAquilina/zsh-you-should-use
antibody bundle mollifier/cd-gitroot
antibody bundle owenstranathan/pipenv.zsh
antibody bundle paulirish/git-open
antibody bundle paulirish/git-recent
antibody bundle peterhurford/git-it-on.zsh
antibody bundle peterhurford/up.zsh
antibody bundle sobolevn/wakatime-zsh-plugin
antibody bundle urbainvaes/fzf-marks
antibody bundle wfxr/forgit
antibody bundle zdharma/zsh-diff-so-fancy
antibody bundle zdharma/fast-syntax-highlighting
antibody bundle zsh-users/zsh-autosuggestions
antibody bundle zsh-users/zsh-completions
antibody bundle zsh-users/zsh-history-substring-search
antibody bundle zuxfoucault/colored-man-pages_mod

fpath+=~/.zfunc
fpath+=~/dotfiles/src/shell/zsh_functions
autoload b c cdf cda cdp codef da drm ds ef emoji::cli fe fkill gbo gbor ghl gobt gobtp goc tm tmk tp ts


# Vim Keybindings
# From: https://gist.github.com/LukeSmithxyz/e62f26e55ea8b0ed41a65912fbebbe52
bindkey -v
export KEYTIMEOUT=1

function zle-keymap-select {
    if [[ ${KEYMAP} == vicmd ]] ||
    [[ $1 = 'block' ]]; then
        echo -ne '\e[1 q'
    elif [[ ${KEYMAP} == main ]] ||
    [[ ${KEYMAP} == viins ]] ||
    [[ ${KEYMAP} = '' ]] ||
    [[ $1 = 'beam' ]]; then
        echo -ne '\e[5 q'
    fi
}
zle -N zle-keymap-select
zle-line-init() {
    zle -K viins
    echo -ne "\e[5 q"
}
zle -N zle-line-init
echo -ne '\e[5 q'
preexec() { echo -ne '\e[5 q' ;}

# Use vim keys in tab complete menu:
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -v '^?' backward-delete-char

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
