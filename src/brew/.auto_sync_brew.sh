#!/bin/bash

brew update
brew upgrade
brew cask upgrade

cd ~/dotfiles/src/brew &&
    brew bundle dump --force &&
    cd ~ ||
    return
