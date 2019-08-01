#!/bin/bash

set -eux

# connection issue? restart docker

# git stash whatever you need before
git checkout master
git pull devops master
git submodule update --init --recursive

./scripts/deploy/deploy.sh
