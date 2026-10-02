;;; ftlio-ai-packages.el --- Personal AI Integrations Packages -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Andrew Len

;; Author: Andrew Len <root@andrewlen.com>

;;; Commentary:

;; Trying to integrate misc AI tools in the editor, at least where I currently run to
;; the browser where it's not relevant

;;; Code:

(add-to-list 'package-selected-packages 'gptel)
(add-to-list 'package-selected-packages 'agent-shell)
;; Search, browse and resume the transcripts agent-shell writes to
;; <project>/.agent-shell/transcripts/.
(add-to-list 'package-selected-packages 'agent-recall)

;; Needed by agent-shell-hq-peek.  The agent-shell-hq umbrella file declares
;; persp-mode but not posframe, so package-vc-install will not pull it in.
(add-to-list 'package-selected-packages 'posframe)

(provide 'ftlio-ai-packages)
;;; ftlio-ai-packages.el ends here
