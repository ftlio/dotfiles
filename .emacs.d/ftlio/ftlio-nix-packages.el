;;; ftlio-golang-config.el --- Personal Nix Packages -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Andrew Len

;; Author: Andrew Len <root@andrewlen.com>

;;; Commentary:

;; Install realted nix packages

;;; Code:

(add-to-list 'package-selected-packages 'nix-buffer)
(add-to-list 'package-selected-packages 'nix-env-install)
(add-to-list 'package-selected-packages 'nix-sandbox)
(add-to-list 'package-selected-packages 'nix-ts-mode)
(add-to-list 'package-selected-packages 'nix-update)
(add-to-list 'package-selected-packages 'nixpkgs-fmt)
(add-to-list 'package-selected-packages 'direnv)

(provide 'ftlio-nix-packages)
;;; ftlio-nix-packages.el ends here
