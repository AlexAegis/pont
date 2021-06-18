#!/bin/sh

# This particular fallback script would only run if nothing in the order group
# 0 would run. Because neither pacman, nor yay, nor apt is available.
# This file then would contain a platform agnostic way of installation
# usually by compiling something by source. Since compilation can take a long
# time, using prebuild packages is preferred where it's possible.
