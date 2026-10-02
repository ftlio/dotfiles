;;; early-init --- Early Init  -*- lexical-binding: t -*-

(load "~/.config/crafted-emacs/modules/crafted-early-init-config")

;; Emacs 31 warns about every loaded file that lacks a `lexical-binding'
;; cookie.  Some packages' generated autoloads (sly, sly-quicklisp) have none
;; and cannot be fixed from here, so keep the warning out of the way: it is
;; still logged to *Warnings*, but no longer pops the buffer up at startup.
;; Set here because packages are activated before init.el runs.
(setq warning-suppress-types '((files missing-lexbind-cookie)))
