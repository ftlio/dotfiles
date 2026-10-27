;;; ftlio-nix-config.el --- Personal Nix Config -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Andrew Len

;; Author: Andrew Len <root@andrewlen.com>

;;; Commentary:

;; Nix config.  A project's `.envrc' (`use flake') reaches Emacs through envrc:
;; each buffer loads its directory's environment once and keeps it.  The
;; direnv package re-ran `direnv export' on every switch to a buffer in another
;; directory, about a second each time into a flake project.  After changing
;; an `.envrc', M-x envrc-reload in a buffer there.

;;; Code:

(require 'crafted-ide-config)
(require 'nix-ts-mode)
(require 'envrc)

(envrc-global-mode)

(crafted-ide-configure-tree-sitter '(nix))
(add-to-list 'auto-mode-alist '("\\.nix\\'" . nix-ts-mode))

(provide 'ftlio-nix-config)
;;; ftlio-nix-config.el ends here
