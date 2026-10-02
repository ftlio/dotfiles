;;; ftlio-docs-config.el --- Personal Documents Config -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Andrew Len

;; Author: Andrew Len <root@andrewlen.com>

;;; Commentary:

;; Documents config.  While LSP is deferred to for many docs, so far we use devdocs to bridge some gaps

;;; Code:
(require 'devdocs)

(global-set-key (kbd "C-h D") 'devdocs-lookup)

(defun ftlio/install-docs-if-not-present (doc-name)
  "Install DOC-NAME using devdocs if it is not already installed."
  (let ((doc-dir (expand-file-name doc-name devdocs-data-dir)))
    (unless (file-directory-p doc-dir)
      (devdocs-install doc-name))))

;; List of docs to install
(let ((docs '("nix" "terraform" "gnu_make" "bash" "git" "go" "htmx")))
  (dolist (doc docs)
    (ftlio/install-docs-if-not-present doc)))

(provide 'ftlio-docs-config)
;;; ftlio-docs-config.el ends here
