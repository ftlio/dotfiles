#!/usr/bin/env bash
#
# Read by interactive shells, and by login shells via .bash_profile.
#
# Layout matters.  Bash only sources this file for interactive shells, but a
# *login* shell reaches it through .bash_profile even when non-interactive
# (`bash -lc ...`).  So this file is in two halves:
#
#   1. Environment -- runs in every shell that reads this file at all.
#   2. Interactive -- prompt, completion, aliases; skipped past the guard.
#
# Anything a program needs to inherit (PATH, EDITOR, credentials) belongs in
# part 1.  Anything that only makes sense at a prompt belongs in part 2.

# ---------------------------------------------------------------------------
# 1. Environment -- every shell
# ---------------------------------------------------------------------------

# Machine-local values and secrets, kept out of version control.
[[ -f "$HOME/.bashrc.local" ]] && source "$HOME/.bashrc.local"

# Platform-specific settings live in ~/.bashrc.<platform> (.bashrc.darwin,
# .bashrc.linux, ...).  Sourced here, in the environment half, so each can set
# PATH; anything interactive in them carries its own guard.
case $OSTYPE in
  darwin*) platform=darwin ;;
  linux*)  platform=linux ;;
  *)       platform= ;;
esac
[[ -n $platform && -f "$HOME/.bashrc.$platform" ]] && source "$HOME/.bashrc.$platform"
unset platform

export PATH="$HOME/.local/bin:$PATH"

export NVM_DIR="$HOME/.nvm"

# GnuPG needs to know which terminal to prompt on.  Guarded, because `tty'
# prints "not a tty" and fails in shells with no terminal attached (a script,
# or the shell exec-path-from-shell runs to import the environment) -- setting
# GPG_TTY to that string is worse than leaving it unset.
[[ -t 0 ]] && export GPG_TTY=$(tty)

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='emacs'
fi

# ---------------------------------------------------------------------------
# 2. Interactive only
# ---------------------------------------------------------------------------

case $- in
  *i*) ;;
    *) return;;
esac

# ble.sh -- attached at the end of this file, after oh-my-bash has loaded.
[[ -f "$HOME/.local/share/blesh/ble.sh" ]] &&
  source "$HOME/.local/share/blesh/ble.sh" --noattach

# Path to your oh-my-bash installation.
export OSH="$HOME/.oh-my-bash"

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-bash is loaded.
OSH_THEME="font"

# If you set OSH_THEME to "random", you can ignore themes you don't like.
# OMB_THEME_RANDOM_IGNORED=("powerbash10k" "wanelo")

# Uncomment the following line to use case-sensitive completion.
# OMB_CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# OMB_HYPHEN_SENSITIVE="false"

# Disable bi-weekly auto-update checks: oh-my-bash is pinned and installed by
# nix (see home.nix), so there is no checkout to update.
DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_OSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you don't want the repository to be considered dirty
# if there are untracked files.
# SCM_GIT_DISABLE_UNTRACKED_DIRTY="true"

# Uncomment the following line if you want to completely ignore the presence
# of untracked files in the repository.
# SCM_GIT_IGNORE_UNTRACKED="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.  One of the following values can
# be used to specify the timestamp format.
# * 'mm/dd/yyyy'     # mm/dd/yyyy + time
# * 'dd.mm.yyyy'     # dd.mm.yyyy + time
# * 'yyyy-mm-dd'     # yyyy-mm-dd + time
# * '[mm/dd/yyyy]'   # [mm/dd/yyyy] + [time] with colors
# * '[dd.mm.yyyy]'   # [dd.mm.yyyy] + [time] with colors
# * '[yyyy-mm-dd]'   # [yyyy-mm-dd] + [time] with colors
# If not set, the default value is 'yyyy-mm-dd'.
# HIST_STAMPS='yyyy-mm-dd'

# Uncomment the following line if you do not want OMB to overwrite the existing
# aliases by the default OMB aliases defined in lib/*.sh
# OMB_DEFAULT_ALIASES="check"

# Would you like to use another custom folder than $OSH/custom?
# OSH_CUSTOM=/path/to/new-custom-folder

# To disable the uses of "sudo" by oh-my-bash, please set "false" to
# this variable.  The default behavior for the empty value is "true".
OMB_USE_SUDO=true

# To enable/disable display of Python virtualenv and condaenv
# OMB_PROMPT_SHOW_PYTHON_VENV=true  # enable
# OMB_PROMPT_SHOW_PYTHON_VENV=false # disable

# Which completions would you like to load? (completions can be found in ~/.oh-my-bash/completions/*)
# Custom completions may be added to ~/.oh-my-bash/custom/completions/
# Example format: completions=(ssh git bundler gem pip pip3)
# Add wisely, as too many completions slow down shell startup.
completions=(
 git
 composer
 ssh
)

# Which aliases would you like to load? (aliases can be found in ~/.oh-my-bash/aliases/*)
# Custom aliases may be added to ~/.oh-my-bash/custom/aliases/
# Example format: aliases=(vagrant composer git-avh)
# Add wisely, as too many aliases slow down shell startup.
aliases=(
 general
)

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-bash/plugins/*)
# Custom plugins may be added to ~/.oh-my-bash/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
 git
 bashmarks
 battery
)

source "$OSH"/oh-my-bash.sh

# ble.sh does not load without a terminal, hence the guard.
if [[ ${BLE_VERSION-} ]]; then
  ble-attach
  bleopt complete_menu_style=align-nowrap
fi

command -v direnv >/dev/null && eval "$(direnv hook bash)"

[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
