;;; ftlio-defaults-config.el --- Portable editor preferences -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Andrew Len

;; Author: Andrew Len <root@andrewlen.com>

;;; Commentary:

;; Settings that used to accumulate in `custom-file'.  They live here so they
;; can be tracked in version control; `custom-file' is left for machine-local
;; values and anything secret.
;;
;; `setopt' rather than `customize-set-variable': it honours a defcustom's :set
;; function just the same, but does not register the value with the `user'
;; theme, so enabling or disabling a theme cannot silently re-apply (and, where
;; the :set is buggy, undo) these.  It also does not force-load the defining
;; package.
;;
;; Loaded early, before the package bootstrap, because
;; `package-archive-priorities' has to be in place before anything installs.

;;; Code:

;;;; Packages
(setopt package-archive-priorities
        '(("gnu" . 99) ("nongnu" . 80) ("stable" . 70) ("melpa" . 0)))

;;;; General editing
(setopt fill-column 110
        tab-width 2
        tab-always-indent 'complete
        kill-do-not-save-duplicates t
        load-prefer-newer t
        sh-basic-offset 1
        js-indent-level 2
        go-ts-mode-indent-offset 2)

;;;; Completion
(setopt completion-styles '(orderless basic)
        completion-category-overrides '((file (styles partial-completion)))
        completion-cycle-threshold 3
        completions-detailed t
        corfu-auto t
        corfu-auto-prefix 2
        corfu-cycle t
        vertico-cycle t)
;; NOTE: custom.el also carried `marginalia-annotators' set to the pre-1.0 list
;; format, which no longer matches the option's type and was silently inert.
;; Dropped rather than migrated; marginalia's default is what was in effect.

;;;; Scrolling
(setopt scroll-conservatively 101
        scroll-margin 0
        scroll-preserve-screen-position t
        fast-but-imprecise-scrolling t
        mouse-wheel-progressive-speed nil)

;;;; Windows, buffers and navigation
(setopt switch-to-buffer-in-dedicated-window 'pop
        switch-to-buffer-obey-display-actions t
        global-auto-revert-non-file-buffers t
        bookmark-save-flag 1
        ibuffer-movement-cycle nil
        ibuffer-old-time 24
        Man-notify-method 'aggressive
        ediff-window-setup-function 'ediff-setup-windows-plain
        eshell-scroll-to-bottom-on-input 'this
        xref-show-definitions-function 'xref-show-definitions-completing-read)

;;;; Dired
(setopt dired-auto-revert-buffer t
        dired-dwim-target t)

;;;; Appearance
(setopt crafted-ui-display-line-numbers t
        text-scale-mode-step 1.1
        global-text-scale-adjust-limits '(10 . 500)
        speedbar-use-images nil
        speedbar-frame-parameters '((name . "speedbar")
                                    (title . "speedbar")
                                    (minibuffer)
                                    (border-width . 2)
                                    (menu-bar-lines . 0)
                                    (tool-bar-lines . 0)
                                    (unsplittable . t)
                                    (left-fringe . 10)))

;;;; Org
(setopt org-hide-emphasis-markers t
        org-link-descriptive t
        org-mouse-1-follows-link t
        org-return-follows-link t
        org-support-shift-select t
        org-modules '(ol-bbdb ol-bibtex org-crypt org-ctags ol-docview ol-doi
                              ol-eww ol-gnus org-habit org-id ol-info
                              org-inlinetask ol-irc ol-mhe ol-rmail ol-w3m
                              ol-eshell org-annotate-file ol-bookmark
                              org-checklist org-choose org-collector
                              ol-elisp-symbol org-eval-light org-eval
                              org-expiry ol-git-link org-invoice org-learn
                              org-mac-iCal org-mac-link org-mairix ol-man
                              ol-mew org-notify org-panel org-registry
                              org-screen org-screenshot org-secretary
                              orgtbl-sqlinsert org-toc org-track org-velocity
                              ol-vm org-wikinodes ol-wl))

;;;; Tooling
;; agent-shell settings live in ftlio-ai-config.el.
(setopt eglot-autoshutdown t
        gptel-model 'gpt-5-mini)

(provide 'ftlio-defaults-config)
;;; ftlio-defaults-config.el ends here
