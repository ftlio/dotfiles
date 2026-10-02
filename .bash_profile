#!/usr/bin/env bash
#
# Read by *login* shells only (Terminal.app, ssh, `bash -l`).
#
# This deliberately does nothing but hand off to .bashrc, so login and
# non-login shells end up identically configured.  Anything placed only here
# would be invisible to non-login shells -- which includes Emacs's `M-x shell',
# whose default `explicit-bash-args' are ("--noediting" "-i"): interactive, but
# not a login shell.  That asymmetry is why environment variables previously
# had to be duplicated here.

[[ -f "$HOME/.bashrc" ]] && source "$HOME/.bashrc"
