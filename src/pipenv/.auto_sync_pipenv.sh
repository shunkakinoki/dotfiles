#!/bin/bash

cd ~/dotfiles/src/pipenv &&
    pipenv update &&
    cd ~ ||
    return
