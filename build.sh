#!/bin/bash
set -e

if [ $# -eq 1 ] && [ $1 == "debug" ]
then
    CMAKE_BUILD_TYPE="-DCMAKE_BUILD_TYPE=Debug"
    BUILD_TYPE="DEBUG"
else
    CMAKE_BUILD_TYPE="-DCMAKE_BUILD_TYPE=Release"
    BUILD_TYPE="RELEASE"
fi
echo -e "\nStarting \033[1;32m$BUILD_TYPE\033[0m build.\n"

mkdir -p build
cd build
cmake .. $CMAKE_BUILD_TYPE
make
cp src/athena ../

echo -e "\nBuild finished \033[1;32msuccessfully.\033[0m\n"
