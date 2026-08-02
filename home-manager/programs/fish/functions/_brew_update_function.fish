function _brew_update_function --description "Update Homebrew"
  brew update && brew upgrade && brew cleanup
end