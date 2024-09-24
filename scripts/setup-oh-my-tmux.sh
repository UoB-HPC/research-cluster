#!/bin/bash

set -eu

cd

if [ -d ".tmux" ]; then rm -rf .tmux; fi
git clone https://github.com/gpakosz/.tmux.git
ln -s -f .tmux/.tmux.conf .
cp .tmux/.tmux.conf.local .
