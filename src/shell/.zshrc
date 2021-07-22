# shellcheck disable=SC2148

# Autoload Zsh Completion
autoload -Uz compinit
compinit

# Hyper Tab Title Settings
# From: https://github.com/zeit/hyper/issues/1188#issuecomment-332606903
# Override auto-title when static titles are desired ($ title My new title)
title() {
  export TITLE_OVERRIDDEN=1
  echo -en "\e]0;$*\a"
}

# Turn off static titles ($ autotitle)
autotitle() { export TITLE_OVERRIDDEN=0; }
autotitle

# Condition checking if title is overridden
overridden() { [[ $TITLE_OVERRIDDEN == 1 ]]; }

# Load Antibody Plugin Manager
source <(antibody init)

export NVM_AUTO_USE=true

# Install Antibody Plugins
antibody bundle Aloxaf/fzf-tab
antibody bundle b4b4r07/emoji-cli
antibody bundle b4b4r07/enhancd
antibody bundle buonomo/yarn-completion
antibody bundle caarlos0/zsh-git-sync kind:path
antibody bundle chrissicool/zsh-256color
antibody bundle darvid/zsh-poetry
antibody bundle lukechilds/zsh-better-npm-completion
antibody bundle lukechilds/zsh-nvm
antibody bundle MichaelAquilina/zsh-you-should-use
antibody bundle mollifier/cd-gitroot
antibody bundle paulirish/git-open
antibody bundle paulirish/git-recent
antibody bundle peterhurford/git-it-on.zsh
antibody bundle peterhurford/up.zsh
antibody bundle urbainvaes/fzf-marks
antibody bundle wfxr/forgit
antibody bundle zdharma/fast-syntax-highlighting
antibody bundle zdharma/zsh-diff-so-fancy
antibody bundle zsh-users/zsh-autosuggestions
antibody bundle zsh-users/zsh-completions
antibody bundle zsh-users/zsh-history-substring-search
antibody bundle zuxfoucault/colored-man-pages_mod

if [ -x notify-send ]; then
  antibody bundle MichaelAquilina/zsh-auto-notify
fi

if [ -x pipenv ]; then
  antibody bundle owenstranathan/pipenv.zsh
fi

if [ -x wakatime ]; then
  antibody bundle sobolevn/wakatime-zsh-plugin
fi

fpath+=~/.zfunc
fpath+=~/dotfiles/src/shell/zsh_functions
autoload b c cdf cda cdp coden coder da drm ds ef emoji::cli fe fh fkill gbo gbor ghl gobt gobtp goc icoden icoder tm tmk tp ts

# Source Shell Files
for file in ~/.shell_*; do
  source "$file"
done

source ~/.zshrc.local

# Eval Zsh Packages
eval "$(starship init zsh)"

if [[ -n $ZSH_INIT_COMMAND ]]; then
  echo "Running: $ZSH_INIT_COMMAND"
  eval "$ZSH_INIT_COMMAND"
fi
