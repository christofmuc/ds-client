rem After cloning recursively, we must bootstrap the vcpkg package manager
third_party\vcpkg\bootstrap-vcpkg.bat

rem Build Makefile 
cmake -S . -B build -G "Visual Studio 15 2017 Win64"
