#!/bin/bash

cd ~/dotfiles/src/bundle &&
    bundle update &&
    cd ~ ||
    exit
