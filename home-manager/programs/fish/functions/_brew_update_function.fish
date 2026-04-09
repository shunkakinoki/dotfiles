function _brew_update --description "Update Homebrew"
  brew update && brew upgrade && brew cleanup
end