;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!

;; other inspirations:
;; - Emacs from Scratch (https://github.com/daviwil/emacs-from-scratch/)


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.
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

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/Org/")

(setq org-src-fontify-natively t)   ;; Syntax highlight source blocks!

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

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

(set-face-attribute 'default nil :family "JetBrainsMono Nerd Font")
(set-face-attribute 'default nil :height 140)

(cond
 ((string-equal system-type "darwin") ; Mac OS X
  (progn
   (setq mac-command-modifier 'meta)
   (setq mac-option-modifier 'super)
   (message "Darwin"))))

(set-frame-parameter (selected-frame) 'alpha '(97 . 97))

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

;; org babel
;;(require 'org-tempo)
;;(add-to-list 'org-structure-template-alist '("sh" . "src shell"))
;;(add-to-list 'org-structure-template-alist '("el" . "src emacs-lisp"))

;; make key "n j" go to journal!

;; org-roam related things

;; References:
;; 2022-01-29: https://github.com/jethrokuan/dots/blob/master/.doom.d/config.el#L375

(setq org-roam-directory (file-truename "~/Org/roam" ))
(setq org-roam-dailies-directory (file-truename "~/Org/roam/journal" ))

(add-hook 'after-init-hook 'org-roam-mode)

(org-roam-db-autosync-mode)

;;
;; Key bindings
(map!
 :leader
 :prefix "n"
 :desc "Open note" "f" #'org-roam-node-find
 :desc "Insert into ID note" "i" #'org-roam-node-insert
 :desc "Capture a note" "n" #'org-roam-capture
 :desc "Journal" "j" #'org-roam-dailies-capture-today
 :desc "Journal directory" "J" #'org-roam-dailies-find-directory
 :desc "Note graph" "g" #'org-roam-graph)

;;(map!
;; :leader
;; :desc "Capture a note"
;; "n n" #'org-roam-capture)


;; Let's set up some org-roam capture templates
;;(setq org-roam-capture-templates
;;      '(("d" "default" plain "%?" :target
;;        (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n")
;;        :unnarrowed t)))

(setq org-roam-capture-templates
      '(("d" "default" plain "%?" :target
         (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n")
         :unnarrowed t)
        ("e" "private" plain "%?" :target
         (file+head "%<%Y%m%d%H%M%S>-${slug}.org.gpg" "#+title: ${title}\n")
         :unnarrowed t)
        ))

(setq org-roam-dailies-capture-templates
      '(("d" "default" entry
         "* %?"
         :target (file+head "%<%Y-%m-%d>.org"
                            "#+title: journal-%<%Y-%m-%d>\n"))))

;;  (setq org-roam-capture-templates
;;        (quote (("d" "default" plain (function org-roam--capture-gefffft-point)
;;                 "%?"
;;                 :file-name "%<%Y-%m-%d-%H%M%S>-${slug}"
;;                 :head "#+title: ${title}\n"
;;                 :unnarrowed t)
;;                )))

  ;; And now we set necessary variables for org-roam-dailies
;;  (setq org-roam-dailies-capture-templates
;;        '(("d" "default" entry
;;           #'org-roam-capture--get-point
;;           "* %?"
;;           :file-name "daily/%<%Y-%m-%d>"
;;           :head "#+title: %<%Y-%m-%d>\n\n")))

(setq company-idle-delay 1.0)

;; (add-hook 'minibuffer-setup-hook #'vertico-repeat-save)

;; keys: map!, define-key!, ec
;; o
