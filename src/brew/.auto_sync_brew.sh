brew update
brew upgrade
brew cask upgrade

cd ~/dotfiles/src/brew

brew bundle dump --force

# if git status | grep -q Brewfile; then
#     git add Brewfile
#     sh -c "git checkout -b auto-sync && git commit -m \":factory: (homebrew) [automated] sync packages\" && git publish && hub pull-request \"Auto Sync Brewfile\""
#     2>&1 > /dev/null
# fi

cd ~
