#!/bin/bash
set -e

git stash
git checkout master
git pull --all
git stash pop

git submodule update --init

cd build/
cmake .. -DCMAKE_BUILD_TYPE=Release -DUSE_PCH=OFF -DBUILD_APPS=ON
#cmake .. -DCMAKE_BUILD_TYPE=Debug -DUSE_PCH=OFF -DBUILD_ALL=ON
make -j8
