;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;;; Built-in keybinds that I want to remember:
;;;
;;; C-x C-j      Dired jump
;;; C-x 8 <ret>  For Emoji!
;;;

;;
;; brew install font-et-book  ;; To install fonts:
;; brew install shellcheck graphviz
;; brew install --cask basictex   -or- brew install --cask mactex

;;
;; Manual build of vterm:
;;
;;     cd ~/.config/doom-emacs/.local/straight/build-28.2/vterm
;;     rm -rf build vterm-module.so
;;     mkdir build
;;     cd build
;;     /opt/homebrew/bin/cmake -DUSE_SYSTEM_LIBVTERM=no ..
;;     make

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!

;; other inspirations:
;; - Emacs from Scratch (https://github.com/daviwil/emacs-from-scratch/)
;; - https://zzamboni.org/post/my-doom-emacs-configuration-with-commentary/#org-visual-settings

(setq user-full-name "Steven Byrnes"
      user-mail-address "steven@byrnes.org")

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
;; (setq doom-font (font-spec :family "monospace" :size 12 :weight 'semi-light)
;;       doom-variable-pitch-font (font-spec :family "sans" :size 13))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
;;(setq doom-theme 'doom-one)

(setq doom-theme 'nord)

;;(setq sb-default-font "Iosevka")
;;(setq sb-default-variable-font "Iosevka Aile")

(setq sb-default-font "JetbrainsMono Nerd Font")
(setq sb-default-variable-font "ETBembo")


;;(setq doom-font (font-spec :family "JetBrainsMono Nerd Font" :size 18)
;;      doom-variable-pitch-font (font-spec :family "ETBembo" :size 18)
;;      doom-big-font (font-spec :family "JetBrainsMono Nerd Font" :size 28))



(set-face-attribute 'default nil :family sb-default-font)
(set-face-attribute 'variable-pitch nil :family sb-default-variable-font)
;;(set-face-attribute 'org-modern-symbol nil :family "Iosevka")

(setq doom-font (font-spec :family sb-default-font :size 18)
      doom-variable-pitch-font (font-spec :family sb-default-variable-font :size 18)
      doom-big-font (font-spec :family sb-default-font :size 28))


;; Add some bling to Doom Dashboard!
(setq fancy-splash-image "~/Documents/Pictures/Emacs/doom-emacs-color.png")


;;; Lisp stuff
;; Had to do it manually: https://github.com/justinbarclay/parinfer-rust-mode
;;(setq parinfer-rust-auto-download t)

;;;
;;; Org-mode and related configuration
;;;
(setq org-src-fontify-natively t)   ;; Syntax highlight source blocks!
(setq org-startup-with-inline-images t)

;;;
;;; Org-mode tweaking
;;;
(add-hook 'org-mode-hook (lambda () (display-line-numbers-mode -1))) ;; Hide line numbers
(add-hook 'org-mode-hook #'mixed-pitch-mode)
(after!
  org
  (progn
    (setq org-hide-emphasis-markers t) ;; Show emphasis without markup characters

    (setq org-agenda-start-with-log-mode t)
    (setq org-log-done 'time)
    ;;(setq org-log-done 'note)
    (setq org-treat-insert-todo-heading-as-state-change t)
    (setq org-log-into-drawer t)
    ;;(setq org-agenda-span 10)
    ;;(setq org-agenda-start-day "-3d")
    (add-to-list 'org-modules 'org-habit t)

    (setq org-todo-keywords (quote ((sequence "TODO(t)" "NEXT(n)" "DOING(D)" "IN-PROGRESS(I)" "|" "DONE(d@/!)")
                                    (sequence "WAITING(w@/!)" "SOMEDAY(s!)" "|" "CANCELLED(c@/!)" "PHONE"))))

    (setq ;;org-startup-indented t
     ;;org-bullets-bullet-list '(" ") ;; no bullets, needs org-bullets package
     org-ellipsis "  " ;; folding symbol
     org-pretty-entities t
     ;;org-hide-emphasis-markers t
     ;; show actually italicized text instead of /italicized text/
     org-agenda-block-separator "")
     ;;org-fontify-whole-heading-line t
     ;;org-fontify-done-headline t
     ;;org-fontify-quote-and-verse-blocks t


    (setq org-image-actual-width nil)

    ;; This determines the style of line numbers in effect. If set to `nil', line
    ;; numbers are disabled. For relative line numbers, set this to `relative'.
    (setq display-line-numbers-type t)))




(add-hook! org-mode :append
           #'visual-line-mode
           #'variable-pitch-mode)                ;; Switch to variable pitch
;;(add-hook! org-mode (electric-indent-local-mode -1))
(add-hook! org-mode :append #'org-appear-mode)  ;; Show emphasis markers when cursor over text

;; org agenda

;; (setq org-agenda-log-mode-items (quote (clock)))

;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.


;;
;; Magit config
;;
(setq magit-revision-show-gravatars '("^Author:     " . "^Commit:     "))

;;
;; Select properties brought over from old elisp.org
;;
(cond
 ((string-equal system-type "darwin") ; Mac OS X
  (progn
   (setq mac-command-modifier 'meta)
   (setq mac-option-modifier 'super)
   (message "Darwin"))))

(set-frame-parameter (selected-frame) 'alpha '(97 . 97))

;;
;; Enhanced window management
;;

;; There is also a mac-right-option-modifier setting. I could change that to
;; Hyper? Would it be possible to change the doom prefix to Hyber?
;;
;; (setq mac-option-key-is-meta t)
;; (setq mac-right-option-modifier nil)

;; set custom keysequences

;; Change cursor blinking.   nil to turn off
(blink-cursor-mode t)
;; Cursor (to make consistent with terminal).  'box is default
(setq-default cursor-type 'bar)

;; todo:
;; - turn on minimap by default
;;

(setq calendar-location-name "Houston, TX")
(setq calendar-latitude 29.7)
(setq calendar-longitude -95.3)

;;;
;;; Overlay git blame
;;;
;;(use-package blamer
;;  :bind (("s-i" . blamer-show-commit-info))
;;  :defer 20
;;  :custom
;;  (blamer-idle-time 0.3)
;;  (blamer-min-offset 70)
;;  :custom-face
;;  (blamer-face ((t :foreground "#7a88cf"
;;                   :background nil
;;                   :height 140
;;                   :italic t
;;  :config
;;  (global-blamer-mode 1))

;;
;; Remember desktop buffers, and save periodically
;;   (we run this near the end so all major modes are properly loaded...)
;;
;; (desktop-save-mode 1)                                     ;; automatically load buffers from last session

;;(setq history-length 50)

;;(add-to-list 'desktop-globals-to-save 'file-name-history) ;; also save file history

;; Things not to include in desktop
;; (delete 'file-name-history desktop-globals-to-save

;; (setq desktop-restore-frames nil)                         ;; Don't save frame and window configuration

;;  (setq desktop-restore-eager 0))                            ;; eagerly restore no buffers; lazy-load all of them

;; todo:
;; - turn on minimap by default
;;

;;
;; Remember desktop buffers, and save periodically
;;   (we run this near the end so all major modes are properly loaded...)
;;
;; (desktop-save-mode 1)                                     ;; automatically load buffers from last session

;;(setq history-length 50)

;;(add-to-list 'desktop-globals-to-save 'file-name-history) ;; also save file history

;; Things not to include in desktop
;; (delete 'file-name-history desktop-globals-to-save

;; (setq desktop-restore-frames nil)                         ;; Don't save frame and window configuration

;;  (setq desktop-restore-eager 0))                            ;; eagerly restore no buffers; lazy-load all of them

(map!
 :leader
 :prefix "o"
 :desc "Open vterm" "v" #'vterm)

(map!
 :leader
 :desc "Navigation left"  "<left>"  #'windmove-left
 :desc "Navigation right" "<right>" #'windmove-right
 :desc "Navigation up"    "<up>"    #'windmove-up
 :desc "Navigation down"  "<down>"  #'windmove-down)

(setq company-idle-delay 1.0)

;;
;; Custom focus mode for writing.  Olivetti mode.
;; todo:
;; - buffer-local variable for the writing mode
;; - (doom/toggle-line-numbers) - nil, t


;;
;; Development-related configuration and keybinding tweaks
;;
(defun custom-reindent-eol()
  (local-set-key (kbd "RET") 'reindent-then-newline-and-indent)
  (local-set-key (kbd ";") (lambda ()
                             (interactive)
                             (insert ";")
                             (reindent-then-newline-and-indent))))

(add-hook 'rjsx-mode-hook 'custom-reindent-eol)


 ;;(add-hook 'gptel-post-stream-hook 'gptel-auto-scroll))
 ;;(add-hook 'gptel-post-response-hook 'gptel-end-of-response)
 
 ;;(gptel-make-ollama "Ollama"
 ;;                :host "localhost:11434"
 ;;                :stream t
 ;;                :models '("llama3:latest")))
 ;;(gptel-make-anthropic "Claude"          ;Any name you want
 ;; :stream t                             ;Streaming responses
 ;; :key "your-api-key")

;;(setq auto-indent-key-for-end-of-line-then-newline "<M-return>")
;;(setq auto-indent-key-for-end-of-line-insert-char-then-newline "<M-S-return>")

;;(use-package auto-indent-mode
;;  ;; :bind (("s-i" . blamer-show-commit-info))
;;  ;;:defer 20
;;  ;;:custom
;;  ;;(blamer-idle-time 0.3)
;;  ;;(blamer-min-offset 70)
;;  :config
;;  (auto-indent-global-mode))

;; Variable font pitch for org mode
(defun sb/set-buffer-variable-pitch ()
  "Set variable pitch for org mode, and change certain faces to fixed pitch."
  (interactive)
  (variable-pitch-mode t)
  (setq line-spacing 3)
  (set-face-attribute 'org-table nil :inherit 'fixed-pitch)
  (set-face-attribute 'org-code nil :inherit 'fixed-pitch)
  (set-face-attribute 'org-block nil :inherit 'fixed-pitch))

;(set-face-attribute 'org-block-background nil :inherit 'fixed-pitch)

;;(add-hook 'org-mode-hook 'sb/set-buffer-variable-pitch)
;;(add-hook 'eww-mode-hook 'set-buffer-variable-pitch)
;;(add-hook 'markdown-mode-hook 'set-buffer-variable-pitch)
;;(add-hook 'Info-mode-hook 'set-buffer-variable-pitch)


;; Disable undo save history (as I've had a few crashes perhaps due to it?)
(after! undo-tree
  (setq undo-tree-auto-save-history nil))

(after! dirvish
  (dirvish-define-preview eza (file)
    "Use `eza' to generate directory preview."
    :require ("eza") ; tell Dirvish to check if we have the executable
    (when (file-directory-p file) ; we only interest in directories here
      `(shell . ("eza" "-al" "--color=always" "--icons"
                 "--group-directories-first" ,file))))

  (add-to-list 'dirvish-preview-dispatchers 'eza))


;; with flair

;; (add-hook 'minibuffer-setup-hook #'vertico-repeat-save)

;; keys: map!, define-key!, ec
;; o

;; lifted from https://github.com/aaronjensen/emacs-modern-tab-bar/
(defcustom modern-tab-bar-tab-name-format-function #'tab-bar-tab-name-format-default
  "Function to format a tab name.
Function gets two arguments, the tab and its number, and should return
the formatted tab name to display in the tab bar."
  :type 'function)


(defcustom modern-tab-bar-tab-horizontal-padding 16
  "Horizontal padding for tabs."
  :type 'natnum)
