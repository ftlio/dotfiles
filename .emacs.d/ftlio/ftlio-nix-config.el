;;; ftlio-nix-config.el --- Personal Nix Config -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Andrew Len

;; Author: Andrew Len <root@andrewlen.com>

;;; Commentary:

;; Nix config. Works best with emacs direnv package when working with flakes
;; for dependencies

;;; Code:

(require 'crafted-ide-config)
(require 'nix-ts-mode)
(require 'direnv)

(direnv-mode)

(crafted-ide-configure-tree-sitter '(nix))
(add-to-list 'auto-mode-alist '("\\.nix\\'" . nix-ts-mode))

(provide 'ftlio-nix-config)
;;; ftlio-nix-config.el ends here
