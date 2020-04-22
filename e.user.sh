#!/bin/sh

# Dot itself reads this file before doing anything with the module
# to load necessary environment variables.

# shellcheck disable=SC1091
. "./XDG_CONFIG_HOME.dot/environment.d/90-dot.conf"
