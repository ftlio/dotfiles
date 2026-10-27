;;; ftlio-term-config.el --- Terminal in Emacs -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Andrew Len

;; Author: Andrew Len <root@andrewlen.com>

;;; Commentary:

;; vterm: a real terminal (libvterm) in a buffer, for full-screen programs
;; that eshell and term handle badly.  It comes from nix with its module
;; already compiled (lisp/vterm, see home.nix) rather than from an archive,
;; so it is absent on machines not managed by nix.  The shell side (prompt
;; tracking, so the buffer follows `cd') is set up in .bashrc.
;;
;;   C-c t     a vterm (C-u C-c t for another one)
;;   C-x p t   a vterm at the current project's root
;;   C-c C-t   inside vterm: copy mode, to select and copy; RET copies

;;; Code:

(let ((dir (expand-file-name "lisp/vterm" user-emacs-directory)))
  (when (file-directory-p dir)
    (add-to-list 'load-path dir)
    (load "vterm-autoloads" nil :nomessage)))

(setopt vterm-max-scrollback 10000)

(defun ftlio/project-vterm ()
  "Open a vterm at the root of the current project, one per project."
  (interactive)
  (let* ((project (project-current t))
         (default-directory (project-root project))
         (vterm-buffer-name (format "*vterm %s*" (project-name project))))
    (vterm)))

(when (fboundp 'vterm)
  (keymap-global-set "C-c t" #'vterm)
  (keymap-set project-prefix-map "t" #'ftlio/project-vterm))

(provide 'ftlio-term-config)
;;; ftlio-term-config.el ends here
