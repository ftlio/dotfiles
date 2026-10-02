;;; ftlio-golang-config.el --- Personal Golang Config -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Andrew Len

;; Author: Andrew Len <root@andrewlen.com>

;;; Commentary:

;; Golang config.  Requires crafted-ide-config

;;; Code:

(require 'crafted-ide-config)
;; templ-ts-mode is left to its autoloads, which provide both the mode and the
;; `auto-mode-alist' entry, so nothing loads until a .templ file is opened.

;; Define configuration settings for Eglot only after Eglot has been loaded
(with-eval-after-load 'eglot
  ;; Eglot already maps every Go mode to gopls out of the box.
  (add-to-list 'eglot-server-programs
               '(templ-ts-mode "templ" "lsp"))

  ;; Set workspace configuration for golangci-lint in goplsa
  (setq-default eglot-workspace-configuration
                '((:gopls .
                          ((staticcheck . t)
                           (gofumpt . t))))))

;; Automatically start Eglot for Go.  Go files open in the tree-sitter modes,
;; so these are the hooks that actually fire.
(add-hook 'go-ts-mode-hook #'eglot-ensure)
(add-hook 'go-mod-ts-mode-hook #'eglot-ensure)
(add-hook 'templ-ts-mode-hook #'eglot-ensure)

(eval-after-load 'flycheck
  '(add-hook 'flycheck-mode-hook #'flycheck-golangci-lint-setup))

(with-eval-after-load 'treesit
  ;; Set up tree-sitter for Go
  (crafted-ide-configure-tree-sitter '(go gomod)))

(defun ftlio/is-class-attr ()
  (let ((mynode (treesit-node-parent
                 (treesit-node-parent
                  (treesit-node-at (point))))))
    (and (string= (treesit-node-type mynode) "attribute")
         (string= (treesit-node-text (treesit-node-child mynode 0))
                  "class"))))

(defun ftlio/bounds-of-keyword ()
  (if (or (char-equal (char-before) ?\s)
          (char-equal (char-before) ?\"))
      nil
    (let ((START (save-excursion
                   (re-search-backward "[\s\"\t\n]"
                                       (line-beginning-position)
                                       t)))
          (END (save-excursion
                 (re-search-forward "[\s\"\t\n]"
                                    (line-end-position)
                                    t))))
      (cons (if START
                (1+ START)
              (line-beginning-position))
            (if END
                (1- END)
              (point))))))

(defun ftlio/treesit-prev-sibling-until (NODE PRED)
  "Find previous sibling until PRED is t.

PRED is a function which accept a NODE."
  ;; This is recursion.
  (when NODE
    (let ((sibling (treesit-node-prev-sibling NODE)))
      (when sibling
        (if (funcall PRED sibling)
            sibling
          (drsl/treesit-prev-sibling-until sibling PRED)))))
  )

(defun ftlio/treesit-next-sibling-until (NODE PRED)
  "Find next sibling until PRED is t.

PRED is a function which accept a NODE."
  (when NODE
    (let ((sibling (treesit-node-next-sibling NODE)))
      (when sibling
        (if (funcall PRED sibling)
            sibling
          (drsl/treesit-next-sibling-until sibling PRED))))))

(defcustom ftlio/tailwind-css-keyword-file
  (expand-file-name "dict/tailwind_css_keyword.txt" user-emacs-directory)
  "tailwindcss keyword file path."
  :type 'string)

(defun ftlio/tailwind-css-dict-list (input)
  "Return all words from `ftlio/tailwind-css-keyword-file' matching INPUT."
  (unless (equal input "")
    (let* ((inhibit-message t)
           (message-log-max nil)
           (default-directory
            (if (and (not (file-remote-p default-directory))
                     (file-directory-p default-directory))
                default-directory
              user-emacs-directory))
           (files (mapcar #'expand-file-name
                          (ensure-list
                           ftlio/tailwind-css-keyword-file)))
           (words
            (apply #'process-lines-ignore-status
                   "grep"
                   (concat "-Fh"
                           (and (cape--case-fold-p cape-dict-case-fold) "i")
                           (and cape-dict-limit (format "m%d" cape-dict-limit)))
                   input files)))
      (cons
       (apply-partially
        (if (and cape-dict-limit (length= words cape-dict-limit))
            #'equal #'string-search)
        input)
       (cape--case-replace-list cape-dict-case-replace input words)))))

(defun ftlio/templ-tailwind-cape-dict ()
  (when (ftlio/is-class-attr)
    (pcase-let ((`(,beg . ,end) (ftlio/bounds-of-keyword)))
      `(,beg ,end
             ,(cape--properties-table
               (completion-table-case-fold
                (cape--dynamic-table beg end #'ftlio/tailwind-css-dict-list)
                (not (cape--case-fold-p cape-dict-case-fold)))
               :sort nil ;; Presorted word list (by frequency)
               :category 'cape-dict)
             ,@cape--dict-properties))))

(defvar ftlio/templ-ts-mode-tag-list
  '("a" "abbr" "address" "area" "article" "aside" "audio" "b"
    "base" "bdi" "bdo" "blockquote" "body" "br" "button" "canvas"
    "caption" "cite" "code" "col" "colgroup" "data" "datalist"
    "dd" "del" "details" "dfn" "dialog" "div" "dl" "dt" "em"
    "embed" "fieldset" "figcaption" "figure" "footer" "form" "h1"
    "h2" "h3" "h4" "h5" "h6" "head" "header" "hgroup" "hr" "html"
    "i" "iframe" "img" "input" "ins" "kbd" "label" "legend" "li"
    "link" "main" "map" "mark" "math" "menu" "meta" "meter" "nav"
    "noscript" "object" "ol" "optgroup" "option" "output" "p"
    "picture" "pre" "progress" "q" "rp" "rt" "ruby" "s" "samp"
    "script" "search" "section" "select" "slot" "small" "source"
    "span" "strong" "style" "sub" "summary" "sup" "svg" "table"
    "tbody" "td" "template" "textarea" "tfoot" "th" "thead" "time"
    "title" "tr" "track" "u" "ul" "var" "video" "wbr")
  "HTML tags used for completion.

Steal from `web-mode'.")

(defvar ftlio/templ-ts-mode-attribute-list
  '("accept" "accesskey" "action" "alt" "async" "autocomplete" "autofocus"
    "autoplay" "charset" "checked" "cite" "class" "cols" "colspan" "content"
    "contenteditable" "controls" "coords" "data" "datetime" "default" "defer"
    "dir" "dirname" "disabled" "download" "draggable" "enctype" "for" "form"
    "formaction" "headers" "height" "hidden" "high" "href" "hreflang" "http"
    "id" "ismap" "kind" "label" "lang" "list" "loop" "low" "max" "maxlength"
    "media" "method" "min" "multiple" "muted" "name" "novalidate" "onabort"
    "onafterprint" "onbeforeprint" "onbeforeunload" "onblur" "oncanplay"
    "oncanplaythrough" "onchange" "onclick" "oncontextmenu" "oncopy"
    "oncuechange" "oncut" "ondblclick" "ondrag" "ondragend" "ondragenter"
    "ondragleave" "ondragover" "ondragstart" "ondrop" "ondurationchange"
    "onemptied" "onended" "onerror" "onfocus" "onhashchange" "oninput"
    "oninvalid" "onkeydown" "onkeypress" "onkeyup" "onload" "onloadeddata"
    "onloadedmetadata" "onloadstart" "onmousedown" "onmousemove" "onmouseout"
    "onmouseover" "onmouseup" "onmousewheel" "onoffline" "ononline"
    "onpagehide" "onpageshow" "onpaste" "onpause" "onplay" "onplaying"
    "onpopstate" "onprogress" "onratechange" "onreset" "onresize" "onscroll"
    "onsearch" "onseeked" "onseeking" "onselect" "onstalled" "onstorage"
    "onsubmit" "onsuspend" "ontimeupdate" "ontoggle" "onunload"
    "onvolumechange" "onwaiting" "onwheel" "open" "optimum" "pattern"
    "placeholder" "poster" "preload" "readonly" "rel" "required" "reversed"
    "rows" "rowspan" "sandbox" "scope" "selected" "shape" "size" "sizes"
    "span" "spellcheck" "src" "srcdoc" "srclang" "srcset" "start" "step"
    "style" "tabindex" "target" "title" "translate" "type" "usemap" "value"
    "width" "wrap")
  "HTML attributes used for completion.

Steal from `web-mode'.")

(defun ftlio/templ-ts-mode-completion ()
  "templ-ts-mode completion function.

The built-in treesit is required."
  (cond (;; completing tag name, e.g. <d
         (let ((bounds (or (bounds-of-thing-at-point 'word)
                           (cons (point) (point)))))
           (when (char-equal (char-before (car bounds)) ?\<)
             (list (car bounds)
                   (cdr bounds)
                   ftlio/templ-ts-mode-tag-list
                   :annotation-function (lambda (_) " HTML Tag")
                   :company-kind (lambda (_) 'text)
                   :exclude 'no))))

        (;; completing attribute name, e.g. <div c
         (or (string= (treesit-node-type (treesit-node-at (point)))
                      "attribute_name")
             (string= (treesit-node-type (treesit-node-at (point)))
                      ">"))
         (let ((bounds (bounds-of-thing-at-point 'word)))
           (when bounds
             (list (car bounds)
                   (cdr bounds)
                   ftlio/templ-ts-mode-attribute-list
                   :annotation-function (lambda (_) " HTML Attr")
                   :company-kind (lambda (_) 'text)
                   :exclusive 'no))))
        ))

(defvar ftlio/htmx-attribute-list
  '("hx-get" "hx-post" "hx-on" "hx-push-url" "hx-select" "hx-select-oob"
    "hx-swap" "hx-swap-oob" "hx-target" "hx-trigger" "hx-vals" "hx-boost"
    "hx-confirm" "hx-delete" "hx-disable" "hx-disabled-elt" "hx-disinherit"
    "hx-encoding" "hx-ext" "hx-headers" "hx-history" "hx-history-elt"
    "hx-include" "hx-indicator" "hx-params" "hx-patch" "hx-preserve"
    "hx-prompt" "hx-put" "hx-replace-url" "hx-request" "hx-sync" "hx-validate")

  "Htmx attributes used for completion.")

(defvar ftlio/htmx-swap-keyword-list
  '("innerHTML" "outerHTML" "beforebegin" "afterbegin" "beforeend"
    "afterend" "delete" "none")
  "Keywords for hx-swap.")

(defvar ftlio/htmx-target-keyword-list
  '("this" "closest" "find" "next" "previous")
  "Keywords for hx-target.")

(defun ftlio/get-htmx-value-list (ATTR)
  "Return a list of htmx value.

ATTR is the attribute name.
Only support hx-swap, hx-swap-oob, hx-target."
  (cond ((string-prefix-p "hx-swap" ATTR)
         ftlio/htmx-swap-keyword-list)
        ((string= ATTR "hx-target")
         ftlio/htmx-target-keyword-list)))

(defun ftlio/templ-ts-mode-htmx-completion ()
  "templ-ts-mode completion for htmx.

Built-in treesit is required."
  (cond (;; completion of htmx attr name, e.g. <div hx-swap
         (or (string= (treesit-node-type (treesit-node-at (point)))
                      "attribute_name")
             (string= (treesit-node-type (treesit-node-at (point)))
                      ">"))
         ;; This mess if for the case when a - is typed.
         ;;
         ;; In the case of hx-swap*, where * is the pointer.
         ;;
         ;; Since word only includes swap, but symbol includes from
         ;; hx-swap... to the infinity, so just select the first of
         ;; symbol and last of word. But when a - is type, the
         ;; bounds of word returns nil, so just set it to the
         ;; `point'.
         ;;
         ;; TODO: This is an issue in the syntax table of
         ;; `templ-ts-mode'.
         ;;
         (let ((bounds (ftlio/bounds-of-keyword)))
           (when bounds
             (list (car bounds)
                   (cdr bounds)
                   ftlio/htmx-attribute-list
                   :annotation-function (lambda (_) " htmx attr")
                   :company-kind (lambda (_) 'text)
                   :exclusive 'no)))
         )
        (;; completion of some htmx value, e.g. <div hx-swap="innerHTML"
         (string= (treesit-node-type (treesit-node-parent
                                      (treesit-node-at (point))))
                  "quoted_attribute_value")
         (let ((words (ftlio/get-htmx-value-list
                       (treesit-node-text
                        (treesit-node-prev-sibling
                         (treesit-node-parent (treesit-node-at (point)))
                         t)
                        t)))
               (bounds (or (bounds-of-thing-at-point 'word)
                           (cons (point) (point)))))
           (when words
             (list (car bounds)
                   (cdr bounds)
                   words
                   :annotation-function (lambda (_) " htmx value")
                   :company-kind (lambda (_) 'text)
                   :exclusive 'no)
             ))
         )))

(defun ftlio/templ-ts-mode-insert-slash ()
  "Auto closing tag when inserting slash in `templ-ts-mode'"
  (interactive)
  (if (char-equal (char-before) ?\<)
      (let ((TAG (or (treesit-node-text
                      (treesit-node-child
                       (ftlio/treesit-prev-sibling-until
                        (treesit-node-at (point))
                        (lambda (NODE)
                          (string= (treesit-node-type NODE)
                                   "tag_start")))
                       1)
                      t)

                     (when (or (ftlio/treesit-next-sibling-until
                                (treesit-node-parent (treesit-node-at (point)))
                                (lambda (NODE)
                                  (string= (treesit-node-type NODE)
                                           "tag_end")))
                               (string= (treesit-node-type
                                         (treesit-node-parent
                                          (treesit-node-at (point))))
                                        "ERROR"))
                       (treesit-node-text
                        (treesit-node-child
                         (ftlio/treesit-prev-sibling-until
                          (treesit-node-parent (treesit-node-at (point)))
                          (lambda (NODE)
                            (string= (treesit-node-type NODE)
                                     "tag_start")))
                         1)
                        t))
                     )))
        (if TAG
            (progn (insert ?\/
                           TAG
                           ?\>)
                   (treesit-indent))
          (insert ?\/)))
    (insert ?\/)))

;; Deferred: templ-ts-mode-map only exists once the mode is loaded.
(with-eval-after-load 'templ-ts-mode
  (keymap-set templ-ts-mode-map "/" #'ftlio/templ-ts-mode-insert-slash))

(add-hook 'templ-ts-mode-hook
          (lambda ()
            (progn
              (add-to-list 'ftlio/eglot-extra-completion-functions
                           #'ftlio/templ-tailwind-cape-dict)
              (add-to-list 'ftlio/eglot-extra-completion-functions
                           #'ftlio/templ-ts-mode-completion)
              (add-to-list 'ftlio/eglot-extra-completion-functions
                           #'ftlio/templ-ts-mode-htmx-completion))))

(defcustom ftlio/eglot-extra-completion-functions '(cape-file)
  "extra completion functions for eglot"
  :type '(repeat string))

(defun ftlio/eglot-capf ()
  (mapc
   (lambda (FUNCTION)
     (add-to-list 'completion-at-point-functions
                  FUNCTION))
   ftlio/eglot-extra-completion-functions))

(add-hook 'eglot-managed-mode-hook #'ftlio/eglot-capf)

(provide 'ftlio-golang-config)
;;; ftlio-golang-config.el ends here
