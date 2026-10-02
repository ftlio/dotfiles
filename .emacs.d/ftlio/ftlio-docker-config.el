;;; ftlio-docker-config.el --- Personal Docker Config -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Andrew Len

;; Author: Andrew Len <root@andrewlen.com>

;;; Commentary:

;; Docker config.  The engine itself is not managed from here: on macOS it
;; runs in a colima VM, started with `colima start', and the docker CLI finds
;; it through its `colima' context.

;;; Code:

;; `docker' is autoloaded, so nothing loads until the first use.
(keymap-global-set "C-c d" #'docker)

(provide 'ftlio-docker-config)
;;; ftlio-docker-config.el ends here
