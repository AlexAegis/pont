#!/bin/sh

# When installing with yay/paru you shoud never use sudo. Always put this
# in a non root privileged script.
# Alternatively you can use this to sudo back if necessary:
# ${SUDO_USER:+sudo -u $SUDO_USER} paru ...
paru -Syu --needed --noconfirm PACKAGE
