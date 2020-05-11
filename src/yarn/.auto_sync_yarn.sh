#!/bin/bash

cd ~/dotfiles/src/yarn &&
    yarn upgrade &&
    cd ~ ||
    return
