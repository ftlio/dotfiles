;;; ftlio-golang-packages.el --- Required Golang Packages -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Andrew Len

;; Author: Andrew Len <root@andrewlen.com>

;;; Commentary:

;; Packages required for running my Golang IDE.

;;; Code:

;; Go uses the built-in go-ts-mode / go-mod-ts-mode.
(add-to-list 'package-selected-packages 'flycheck-golangci-lint)
(add-to-list 'package-selected-packages 'templ-ts-mode)

(provide 'ftlio-golang-packages)
;;; ftlio-golang-packages.el ends here
