cmake_minimum_required(VERSION 2.8)
cmake_policy(VERSION 2.8)

project(Athena)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)
add_subdirectory(src)
