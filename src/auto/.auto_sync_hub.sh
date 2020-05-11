#!/bin/bash

cd ~/dotfiles &&
    git checkout master &&
    git pull &&
    cd ~ ||
    return
