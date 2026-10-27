;;; ftlio-ai-packages.el --- Personal AI Integrations Packages -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Andrew Len

;; Author: Andrew Len <root@andrewlen.com>

;;; Commentary:

;; Trying to integrate misc AI tools in the editor, at least where I currently run to
;; the browser where it's not relevant

;;; Code:

(add-to-list 'package-selected-packages 'gptel)
(add-to-list 'package-selected-packages 'agent-shell)

;; Not in any archive, so installed from git by
;; `package-vc-install-selected-packages' in init.el (which also pulls in
;; its archive dependencies, such as persp-mode).
;; A bare string here would be read as a version, not a URL.
(setopt package-vc-selected-packages
        '((agent-shell-hq :url "https://github.com/SreenivasVRao/agent-shell-hq")))

;; Needed by agent-shell-hq-peek.  The agent-shell-hq umbrella file declares
;; persp-mode but not posframe, so package-vc-install will not pull it in.
(add-to-list 'package-selected-packages 'posframe)

(provide 'ftlio-ai-packages)
;;; ftlio-ai-packages.el ends here
