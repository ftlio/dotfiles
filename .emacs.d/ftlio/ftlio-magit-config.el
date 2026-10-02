;;; ftlio-magit-config.el --- Personal Magit Config -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Andrew Len

;; Author: Andrew Len <root@andrewlen.com>

;;; Commentary:

;; Magit config.  Crafted Emacs prefers built-ins such as vc, but magit is too
;; dang useful.

;;; Code:

(require 'magit)
(require 'git-link)

(when (require 'magit nil :noerror)
  (global-set-key "\C-xg" 'magit-status)
  (setq vc-display-status nil))

;; (defun ftlio/git-link-main-branch ()
;;   "Get link to line of code using main branch."
;;   (interactive)
;;   (let ((git-link-default-branch "main")
;;         (current-prefix-arg nil))
;;     (call-interactively 'git-link)))

;; (defun ftlio/git-link-for-branch (arg)
;;   "Call git-link to copy a git link for the current branch.
;; If called with ARG, use the 'main' branch instead."
;;   (interactive "P")
;;   (if arg
;;       (jpl/git-link-master-branch)
;;     (call-interactively 'git-link)))

;; (defun ftlio/git-link--current-line-text ()
;;   "Get a link to the current line."
;;   (buffer-substring
;;      (save-excursion (beginning-of-line-text) (point))
;;      (line-end-position)))

;; (defun ftlio/git-link--region-text ()
;;   "Get a link to the selected region."
;;   (buffer-substring (region-beginning) (region-end)))

(provide 'ftlio-magit-config)
;;; ftlio-magit-config.el ends here
