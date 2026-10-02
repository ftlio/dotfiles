;;; init --- Init  -*- lexical-binding: t -*-
;;; Commentary:

;; Using Crafted Emacs in ~/.config/

(server-start)

;; Enable the debugger on error
(setq debug-on-error t)

;;; Code:
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (and custom-file
           (file-exists-p custom-file))
  (load custom-file nil :nomessage))

;; exec-path-from-shell is set up by crafted-ide-config, which also imports
;; GOPATH, SSH_AUTH_SOCK and friends and handles the daemon case.

(defgroup ftlio nil
  "Customization group for ftlio settings."
  :group 'applications)

;; Load Crafted Emacs
(load "~/.config/crafted-emacs/modules/crafted-init-config")

;; Include clustom modules based on Craft Emacs
(add-to-list 'load-path (expand-file-name "ftlio/" user-emacs-directory))

;; Load downloaded packges that weren't available in package repos
(add-to-list 'load-path (expand-file-name "other-packages/" user-emacs-directory))

;; Portable preferences, split out of custom.el so they can be tracked.
;; Early, because it sets `package-archive-priorities'.
(require 'ftlio-defaults-config)

;; Crafted modules - packages
(require 'crafted-completion-packages)
(require 'crafted-ide-packages)
(require 'crafted-lisp-packages)
(require 'crafted-org-packages)
(require 'crafted-ui-packages)
(require 'crafted-workspaces-packages)
(require 'crafted-writing-packages)

;; ftlio modules - packages
(require 'ftlio-golang-packages)
(require 'ftlio-elixir-packages)
(require 'ftlio-nix-packages)
(require 'ftlio-magit-packages)
(require 'ftlio-docs-packages)
(require 'ftlio-ai-packages)

;;; Misc packages
(add-to-list 'package-selected-packages 'ef-themes)
(add-to-list 'package-selected-packages 'wgrep)
(add-to-list 'package-selected-packages 'dired-subtree)
;; Used but not declared by any module, so `package-autoremove' would offer to
;; delete them: hydra/dumb-jump back crafted-defaults-config's dumb-jump hydra.
;; (exec-path-from-shell is declared by crafted-ide-packages.)
(add-to-list 'package-selected-packages 'dumb-jump)
(add-to-list 'package-selected-packages 'hydra)

;; Emacs 31 has native tty child frames, so corfu-terminal is redundant and
;; corfu warns when both are present.  Overridden here rather than patching
;; crafted-completion-packages, so that checkout stays pristine.
(when (version<= "31" emacs-version)
  (setq package-selected-packages
        (delq 'corfu-terminal package-selected-packages)))

(package-install-selected-packages :noconfirm)

;; Deferred: dired-mode-map only exists once dired is loaded.
(with-eval-after-load 'dired
  (bind-key "<tab>" #'dired-subtree-toggle dired-mode-map)
  (bind-key "<backtab>" #'dired-subtree-cycle dired-mode-map))

;;; Emacs 31 compatibility shims

;; Emacs 31.1 (bug#81561) wrapped speedbar-set-timer's body in
;; (with-current-buffer speedbar-buffer ...), which errors when speedbar has
;; never been opened and speedbar-buffer is still nil.
(with-eval-after-load 'speedbar
  (advice-add 'speedbar-set-timer :around
              (lambda (orig timeout)
                (if (buffer-live-p speedbar-buffer)
                    (funcall orig timeout)
                  (speedbar-set-mode-line-format)))))

;; Emacs 31.1 turned js--treesit-indent-rules from a defvar into a defun.
;; templ-ts-mode 0.3 still reads it as a variable at load time; upstream has
;; been dormant since 2025-02, so restore the variable it expects.
(with-eval-after-load 'js
  (when (and (fboundp 'js--treesit-indent-rules)
             (not (boundp 'js--treesit-indent-rules)))
    (defvar js--treesit-indent-rules (js--treesit-indent-rules))))

;; Crafted modules - config
(require 'crafted-defaults-config)
(require 'crafted-completion-config)
(require 'crafted-ide-config)
(require 'crafted-lisp-config)
(require 'crafted-org-config)
(require 'crafted-osx-config)
(require 'crafted-speedbar-config)
(require 'crafted-startup-config)
(require 'crafted-ui-config)
(require 'crafted-updates-config)
(require 'crafted-workspaces-config)
(require 'crafted-writing-config)

;; ftlio modules - packages
(require 'ftlio-golang-config)
(require 'ftlio-elixir-config)
(require 'ftlio-nix-config)
(require 'ftlio-magit-config)
(require 'ftlio-docs-config)
(require 'ftlio-ai-config)

;; Configure ef-themes
;; Load first: since 2.0.0 the ef-themes derive from the modus-themes, and these
;; two names are defvaralias'd to their modus-themes counterparts at load time.
;; Setting them beforehand assigns the plain variables, which the alias then
;; discards with an "Overwriting value of ... by aliasing to ..." warning.
(mapc #'disable-theme custom-enabled-themes)
(require 'ef-themes)
(setq ef-themes-mixed-fonts t
      ef-themes-variable-pitch-ui t)
(load-theme 'ef-rosa :no-confirm)

;; Must come after the theme.  crafted-speedbar-config sets this with
;; `customize-set-variable', whose :set assigns the value and then calls
;; `speedbar-toggle-updates', landing on nil.  That also registers the variable
;; with the `user' theme, so enabling/disabling a theme re-fires the same :set --
;; a plain `setq' before `load-theme' would be undone again.  (The Emacs 31 crash
;; on that path is handled by the `speedbar-set-timer' advice above.)
(setq speedbar-update-flag t)

;; Misc GUI config
(tool-bar-mode 0)
(setq visible-bell t)
(setq ring-bell-function 'ignore)
(add-hook 'speedbar-mode-hook (lambda () (other-frame 0)))

;; Terraform
(require 'terraform-ts-mode)

;; Fill Column
;; (add-hook 'prog-mode-hook #'display-fill-column-indicator-mode)
(add-hook 'prog-mode-hook #'column-number-mode)
(setopt display-fill-column-indicator-column 110)

;; Persistent undo
(setq undo-tree-auto-save-history t)
(setq undo-tree-history-directory-alist '(("." . "~/.emacs.d/undo")))

;; Misc Treesitter
(with-eval-after-load 'treesit
  ;; Set up tree-sitter for Go
  (crafted-ide-configure-tree-sitter '(javascript)))

;; GNU ls, wherever it was installed (Homebrew or nix).
(when-let* (((eq system-type 'darwin))
            (gls (executable-find "gls")))
  (setq insert-directory-program gls))

;; Per-machine settings generated by the nix config.  Absent on machines not
;; managed by nix, hence :noerror.
(load (expand-file-name "lisp/host-local" user-emacs-directory) :noerror)

;;; init.el ends here
