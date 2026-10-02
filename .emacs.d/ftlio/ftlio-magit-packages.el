;;; ftlio-magit-packges.el --- Personal Magit Packages -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Andrew Len

;; Author: Andrew Len <root@andrewlen.com>

;;; Commentary:

;; Magit / VCS related packages.  Crafted Emacs prefers built-ins such as vc, but
;; magit is too dang useful.

;;; Code:
(add-to-list 'package-selected-packages 'magit)
(add-to-list 'package-selected-packages 'magit-diff-flycheck)
(add-to-list 'package-selected-packages 'magit-stats)
(add-to-list 'package-selected-packages 'git-link)

(provide 'ftlio-magit-packages)
;;; ftlio-magit-packages.el ends here
