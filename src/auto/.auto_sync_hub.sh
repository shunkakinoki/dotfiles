#!/bin/bash

cd ~/dotfiles &&
    git checkout main &&
    git pull &&
    cd ~ ||
    exit
