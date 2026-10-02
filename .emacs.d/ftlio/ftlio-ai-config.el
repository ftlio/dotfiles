;;; ftlio-ai-config.el --- Personal AI Integrations Config -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Andrew Len

;; Author: Andrew Len <root@andrewlen.com>

;;; Commentary:

;; Trying to integrate misc AI tools in the editor, at least where I currently run to
;; the browser where it's not relevant

;;; Code:

(require 'gptel)

(setopt agent-shell-session-strategy 'prompt
        agent-shell-session-restore-verbosity 'first-last
        agent-shell-header-style 'graphical)

;; Keep the agent picker, but land on Claude Code as the default choice.
;; A bare symbol here would skip the prompt entirely; the cons cell preselects.
(setopt agent-shell-preferred-agent-config '(preselect . claude-code))

;; Activity groups are runs of consecutive tool calls and thoughts under one
;; collapsible header, labelled descriptively ("Ran 3 commands, read a file").
;; `latest' expands whichever group the agent is currently working in and
;; collapses it once the agent moves on, so thinking is readable as it streams
;; without the transcript growing unbounded.  Use t to keep every group open.
(setopt agent-shell-activity-group-expand-by-default 'latest)

;; Thought sections within an expanded group are unfolded rather than needing
;; a second RET.
(setopt agent-shell-thought-process-expand-by-default t)

;; Workaround: font-get :size returns 0 for some fonts on macOS,
;; causing agent-shell header text to render at font-size 0 (invisible).
(with-eval-after-load 'agent-shell
  (advice-add 'agent-shell--make-header-model :filter-return
              (lambda (model)
                (when (and model (zerop (or (map-elt model :font-size) 0)))
                  (map-put! model :font-size (frame-char-height)))
                model)))

;; A MAX_THINKING_TOKENS override used to live here, to work around thought
;; blocks arriving empty.  agent-shell now requests summarized thinking itself
;; via :session-meta, so it is no longer needed; use C-c C-t
;; (`agent-shell-set-session-thought-level') to change effort per session.

;;; agent-shell-hq -- managing several shells at once.

;; Not in any archive, so it is tracked here for reproducibility; run
;; M-x package-vc-install-selected-packages on a fresh machine.
(setopt package-vc-selected-packages
        '((agent-shell-hq . "https://github.com/SreenivasVRao/agent-shell-hq")))

;; Two of its three modules are useful here, and both entry points are
;; autoloaded, so nothing needs requiring at startup:
;;
;;   M-x agent-shell-hq-peek   posframe overlay listing every agent-shell
;;                             buffer; n/p previews each one in place, RET
;;                             selects, q restores.  No window rearrangement.
;;   M-x agent-shell-hq-label  retitles the current shell by sending its last
;;                             `agent-shell-hq-label-context-chars' to
;;                             `agent-shell-hq-label-command' -- which is
;;                             claude with haiku by default.
;;
;;   M-x agent-shell-hq-toggle sidebar of shells grouped by project, with
;;                             live preview in the main window.
;;
;; agent-shell-hq-label builds its process without a `:stderr' argument, so
;; Emacs merges the command's standard error into the filter that collects the
;; title -- any warning the CLI prints becomes the buffer name.  Wrap the call
;; so stderr is discarded.  `make-process' appends the prompt as the last
;; argument, which lands as $1 here.
;; The trailing pipeline is a hard cap on the title: the model is asked for
;; 3-5 words below but does not always oblige, and an over-long name is what
;; makes several shells hard to tell apart in the first place.
(setopt agent-shell-hq-label-command
        '("bash" "-c"
          "claude -p --model haiku \"$1\" 2>/dev/null | tr '\\n' ' ' | awk '{NF=(NF>5?5:NF); print}'"
          "hq-label"))

;; Default asks for 8-10 words, which is too long for a buffer name.
(setopt agent-shell-hq-label-prompt
        "Reply with ONLY a terse 3-5 word title for this conversation, \
lowercase, no punctuation:\n\n%s")

;; Note that agent-shell-hq-toggle does `(persp-mode 1)' on first use and
;; never turns it back off -- toggling off only switches perspective.  So one
;; invocation leaves persp-mode running for the session, giving Emacs a second
;; buffer-scoping system alongside tabspaces.  If the two start disagreeing
;; about which buffers exist, `M-x persp-mode' disables it.

;; Reach the hq commands from inside a shell.  `C-c' followed by a plain
;; letter is the space Emacs reserves for users, so nothing agent-shell adds
;; later can collide; `C-c C-<letter>' is the major mode's to claim, and the
;; mnemonic choice there is taken anyway -- C-c C-p is comint-previous-prompt.
(with-eval-after-load 'agent-shell
  (defvar-keymap ftlio/agent-shell-hq-map
    :doc "agent-shell-hq commands, under C-c h in an agent shell."
    "p" #'agent-shell-hq-peek
    "t" #'agent-shell-hq-toggle
    "l" #'agent-shell-hq-label)
  (keymap-set agent-shell-mode-map "C-c h" ftlio/agent-shell-hq-map))

;; Never let persp-mode save an agent-shell buffer.  Its default save function
;; records (name, file-name, major-mode); a shell has no file, so on restore
;; persp calls `get-buffer-create' and then the major mode on an empty buffer.
;; `agent-shell-mode' does not survive that -- it fails with (void-function
;; keymap) during `persp-load-state-from-file', which runs from a timer at
;; startup and so breaks the session before you can intervene.  The saved names
;; also collide with real shells, pushing them to "(1)".  Sessions are resumed
;; through agent-shell's picker, never by restoring a buffer, so there is
;; nothing to lose here.
(with-eval-after-load 'persp-mode
  (add-to-list 'persp-filter-save-buffers-functions
               (lambda (buffer)
                 (eq 'agent-shell-mode
                     (buffer-local-value 'major-mode buffer)))))

;;; Claude backends -- subscription or Bedrock.

;; Generated by the nix config: points agent-shell at the nix-installed ACP
;; binaries and defines M-x agent-backends-claude.  Absent on machines not
;; managed by nix, hence :noerror.
(load (expand-file-name "lisp/agent-backends" user-emacs-directory) :noerror)

(provide 'ftlio-ai-config)

;;; ftlio-ai-config.el ends here
