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
(setq sb-default-variable-font "Iosevka Aile")

(setq sb-default-font "JetbrainsMono Nerd Font")
;;(setq sb-default-variable-font "ETBembo")


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
(setq org-directory "~/Results")
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

    (setq org-tag-alist
          '((:startgroup)
            (:endgroup)
            ;;("" . ?E)
            ("@daily" . ?D)
            ("@weekly" . ?W)
            ("@monthly" . ?M)
            ("@quarterly" . ?Q)
            ("@yearly" . ?Y)
            ("idea" . ?i)
            ("planning" . ?p)
            ("releases" . ?R)
            ("research" . ?r)
            ("shelved" . ?s)
            ("writing" . ?w)))

    ;;((sequence "TODO(t)" "PROJ(p)" "LOOP(r)" "STRT(s)" "WAIT(w)" "HOLD(h)" "IDEA(i)" "|" "DONE(d)" "KILL(k)")
    ;; (sequence "[ ](T)" "[-](S)" "[?](W)" "|" "[X](D)")
    ;; (sequence "|" "OKAY(o)" "YES(y)" "NO(n)"))

    (setq org-todo-keywords (quote ((sequence "TODO(t)" "NEXT(n)" "DOING(D)" "IN-PROGRESS(I)" "|" "DONE(d@/!)")
                                    (sequence "WAITING(w@/!)" "SOMEDAY(s!)" "|" "CANCELLED(c@/!)" "PHONE"))))


    ;;(setq org-todo-keywords
    ;;      '((sequence "TODO(t!)" "NEXT(n)" "SOMD(s)" "WAFO(w)" "|" "DONE(d!)" "CANC(c!)")))


    ;; Note: default is to have "category-keep" in agenda as last item, but I
    ;;       don't like that, so I omit it
    (setq org-agenda-sorting-strategy (quote
                                       ((agenda habit-down time-up scheduled-up deadline-up priority-down)
                                        (todo scheduled-up priority-down)
                                        (tags scheduled-up priority-down)
                                        (search category-keep))))

    (setq org-default-notes-file (concat org-directory "/results.org"))

    (defun my/org-read-file (dir)
      (read-file-name "File name"
                      dir ;; add <year> <month>
                      nil
                      nil))
                      ;;"erewhon.tech/src/content/"

    (defun my/current-content-dir (subdir)
      (format-time-string (concat "~/Projects/erewhon/websites" subdir "/%Y/%m")))

    (defun my/content-dir (site typ)
      (my/org-read-file
       (format-time-string
        (concat  "~/Projects/erewhon/websites/" site "/src/content/" typ "/%Y/%m/_"))))

    (defun my/content-dir-2 (site typ)
      (my/org-read-file
       (format-time-string
        (concat  "~/Projects/erewhon/" site "/content/" typ "/%Y/%m/"))))

    (setq my/org-content-template
        "#+title: %^{Title|New Title}\n#+date: %^{Date|Today}\n#+description: \n#+draft: true\n\n%?")
        ;; "#+title: %^{Title|New Title}\n#+date: %^{Date}t\n#+description: \n#+draft: true\n\n%?"

    (setq org-capture-templates
          '(("t" "Personal todo" entry
             (file+headline +org-capture-todo-file "Inbox")
             "* [ ] %?\n%i\n%a" :prepend t)
            ("n" "Personal notes" entry
             (file+headline +org-capture-notes-file "Inbox")
             "* %u %?\n%i\n%a" :prepend t)
            ("j" "Journal" entry
             (file+olp+datetree +org-capture-journal-file)
             "* %U %?\n%i\n%a" :prepend t)
            ("p" "Templates for projects")
            ("pt" "Project-local todo" entry
             (file+headline +org-capture-project-todo-file "Inbox")
             "* TODO %?\n%i\n%a" :prepend t)
            ("pn" "Project-local notes" entry
             (file+headline +org-capture-project-notes-file "Inbox")
             "* %U %?\n%i\n%a" :prepend t)
            ("pc" "Project-local changelog" entry
             (file+headline +org-capture-project-changelog-file "Unreleased")
             "* %U %?\n%i\n%a" :prepend t)
            ("o" "Centralized templates for projects")
            ("ot" "Project todo" entry #'+org-capture-central-project-todo-file "* TODO %?\n %i\n %a" :heading "Tasks" :prepend nil)
            ("on" "Project notes" entry #'+org-capture-central-project-notes-file "* %U %?\n %i\n %a" :heading "Notes" :prepend t)
            ("oc" "Project changelog" entry
             #'+org-capture-central-project-changelog-file
             "* %U %?\n %i\n %a" :heading "Changelog" :prepend t)
            ;; my custom items
            ("c" "Content (articles, blogs)")
            ;;;;
            ("ce" "Content for Erewhon (erewhon.tech)")
            ("cea" "Article for Erewhon (erewhon.tech)" plain
             (file (lambda ()
                     (my/content-dir-2 "erewhon.tech" "articles")))
             (file "~/Projects/erewhon/websites/content-template.mdx")
             :prepend :unnarrowed)

            ("ceb" "Blog for Erewhon (erewhon.tech)" plain
             (file (lambda ()
                     (my/content-dir-2 "erewhon.tech" "blogs")))
             (file "~/Projects/erewhon/websites/content-template.mdx")
             :prepend :unnarrowed
             )
            ;;;
            ("cs" "Content for SteveDotNet")
            ("csa" "Articles for SteveDotNet" plain
             (file (lambda ()
                     (my/content-dir "steve.net" "articles")))
             (file "~/Projects/erewhon/websites/content-template.mdx")
             :prepend :unnarrowed
             )
            ("csb" "Articles for SteveDotNet" plain
             (file (lambda ()
                     (my/content-dir "steve.net" "blog")))
             (file "~/Projects/erewhon/websites/content-template.mdx")
             :prepend :unnarrowed
             )
;;            ("ce" "Content for Erewhon (erewhon.tech)" plain
;;             (file (lambda () (my/org-read-file "~/Projects/erewhon/websites/")))
;;             "#+title: %^{Title|New Title}\n#+date: %^{Date}t\n#+description: \n#+draft: true\n\n%?"
;;             :prepend :unnarrowed
;;             )
          ))

    ;; c(ontent)
    ;;   e(rewhon) (a.k.a. erewhon.tech)
    ;;   r(andom erewhon) (a.k.a. erewhon.us)
    ;;   s(teve.net)
    ;;   b(ettering)
    ;;   j(w)
    ;;     b(log)
    ;;     a(rticles)

    ;;            ("ce" "Content for Erewhon (erewhon.tech)" plain
    ;;             ;;(file ,(my/org-read-file "~/Projects/erewhon/websites/"))
    ;;             ;;(function my/org-read-file)
    ;;             (file (lambda () (my/org-read-file "~/Projects/erewhon/websites/")))
    ;;             "#+title: %^{Title|New Title}\n#+date: %^{Date}t\n#+description: \n#+draft: true\n\n%?"
    ;;             :prepend :unnarrowed
    ;;             )

    ;; org babel
    ;;(require 'org-tempo)
    ;;(add-to-list 'org-structure-template-alist '("sh" . "src shell"))
    ;;(add-to-list 'org-structure-template-alist '("el" . "src emacs-lisp"))

    ;;
    ;; org-roam related things
    ;;
    ;; References:
    ;; 2022-01-29: https://github.com/jethrokuan/dots/blob/master/.doom.d/config.el#L375



;;;(setq org-roam-directory (file-truename "~/Org/roam" ))
;;;(setq org-roam-dailies-directory (file-truename "~/Org/roam/journal" ))

;;;(add-hook 'after-init-hook 'org-roam-mode)

;;;(org-roam-db-autosync-mode)

    ;;
    ;; Key bindings
    ;;
;;;(map!
;;; :leader
;;; :prefix "n"
;;; :desc "Open note" "f" #'org-roam-node-find
;;; :desc "Insert into ID note" "i" #'org-roam-node-insert
;;; :desc "Backlinks" "l" #'org-roam-buffer-toggle
;;; :desc "Capture a note" "n" #'org-roam-capture
;;; :desc "Journal" "j" #'org-roam-dailies-capture-today
;;; :desc "Journal directory" "J" #'org-roam-dailies-find-directory
;;; :desc "Note graph" "g" #'org-roam-graph)

    ;;(map!
    ;; :leader
    ;; :desc "Capture a note"
    ;; "n n" #'org-roam-capture)


    ;; Let's set up some org-roam capture templates
    ;;(setq org-roam-capture-templates
    ;;      '(("d" "default" plain "%?" :target
    ;;        (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n")
    ;;        :unnarrowed t)))

;;;(setq org-roam-capture-templates
;;;      '(("d" "default" plain "%?" :target
;;;         (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n")
;;;         :unnarrowed t)
;;;        ("e" "private" plain "%?" :target
;;;         (file+head "%<%Y%m%d%H%M%S>-${slug}.org.gpg" "#+title: ${title}\n")
;;;         :unnarrowed t)
;;;        ))

;;;(setq org-roam-dailies-capture-templates
;;;      '(("d" "default" entry
;;;         "* %?"
;;;         :target (file+head "%<%Y-%m-%d>.org"
;;;                            "#+title: journal-%<%Y-%m-%d>\n"))))

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

(setq org-agenda-files '("~/Results/05_Daily.org"
                         "~/Results/04_Weekly.org"
                         "~/Results/03_Monthy.org"
                         "~/Results/02_Quarterly.org"
                         "~/Results/01_Yearly.org"))
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
(winner-mode 1)

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
;;                   :italic t)))
;;   :config
;;   (global-blamer-mode 1))

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
(defun sb/toggle-writing-mode ()
  "Stuff."
  (interactive)
  ;;(doom/toggle-line-numbers) ;; toggle between nil and t, otherwise manually C-c t l
  (olivetti-mode 'toggle))

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

(use-package! gptel
 :config
 (global-set-key (kbd "C-c RET") 'gptel-send)
 (setq! gptel-model "gpt-4o-mini")
 (setq! gptel-api-key "sk-blah")
 (add-hook 'gptel-post-stream-hook 'gptel-auto-scroll)
 (add-hook 'gptel-post-response-hook 'gptel-end-of-response)
 (gptel-make-ollama "Ollama"
                 :host "localhost:11434"
                 :stream t
                 :models '("llama3:latest")))

 ;;(gptel-make-anthropic "Claude"          ;Any name you want
 ;; :stream t                             ;Streaming responses
 ;; :key "your-api-key")
;; gpt-4-1106-preview - new gpt 4 turbo

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

;; (use-package! tabspaces
;;   :custom
;;   (tabspaces-use-filtered-buffers-as-default t)
;;   (tabspaces-default-tab "Default")
;;   (tabspaces-remove-to-default t)
;;   (tabspaces-include-buffers '("*scratch*"))
;;   ;;(tabspaces-initialize-project-with-todo t)
;;   ;;(tabspaces-todo-file-name "project-todo.org")
;;   ;; sessions
;;   ;;(tabspaces-session t)
;;   ;;(tabspaces-session-auto-restore t)
;;   )

;; lifted from https://github.com/aaronjensen/emacs-modern-tab-bar/
(defcustom modern-tab-bar-tab-name-format-function #'tab-bar-tab-name-format-default
  "Function to format a tab name.
Function gets two arguments, the tab and its number, and should return
the formatted tab name to display in the tab bar."
  :type 'function)


(defcustom modern-tab-bar-tab-horizontal-padding 16
  "Horizontal padding for tabs."
  :type 'natnum)

(defun modern-tab-bar--tab-bar-name-format (tab i)
  "Adds padding to both sides of tab names."
  (concat
   (propertize " " 'display `((space :width (,modern-tab-bar-tab-horizontal-padding)))
               'face (funcall tab-bar-tab-face-function tab))
   (funcall modern-tab-bar-tab-name-format-function tab i)
   (propertize " " 'display `((space :width (,modern-tab-bar-tab-horizontal-padding)))
               'face (funcall tab-bar-tab-face-function tab))))

(after! tabspaces
    (progn
        (setq tabspaces-use-filtered-buffers-as-default t)
        (setq tabspaces-default-tab "Default")
        (setq tabspaces-remove-to-default t)
        (setq tabspaces-include-buffers '("*scratch*"))
        (setq tabspaces-session t)
        (setq tabspaces-session-auto-restore t)
        (tabspaces-mode 1)

        ;;(require 'powerline)

        ;;(set-face-attribute 'tabbar-default nil
        ;;                    :background "#2e3440"
        ;;                    :foreground "white"
        ;;                    :distant-foreground "#2e3440"
        ;;                    ;;:family "Helvetica Neue"
        ;;                    :box nil)
        ;;(defvar my/tabbar-height 20)
        ;;(defvar my/tabbar-left (powerline-wave-right 'tab-bar nil my/tabbar-height))
        ;;(defvar my/tabbar-right (powerline-wave-left nil 'tab-bar my/tabbar-height))
        ;;(defun my/tabbar-tab-label-function (tab)
        ;;  (powerline-render (list my/tabbar-left
        ;;                          (format " %s  " (car tab))
        ;;                          my/tabbar-right)))

        (setq tab-bar-tab-name-format-function #'modern-tab-bar--tab-bar-name-format)))
        ;;(setq tab-bar-format #'my/tabbar-tab-label-function)
        ;;(setq tabbar-tab-label-function #'my/tabbar-tab-label-function)
        ;;(setq tab-bar-tab-name-format-function #'my/tabbar-tab-label-function)


;;(after! tabspaces
;;  (progn
;;    (tabspaces-mode 1)
;;;;
;;    (setq tabspaces-use-filtered-buffers-as-default t)
;;    (setq tabspaces-default-tab "Default")
;;    (setq tabspaces-remove-to-default t)
;;    (setq tabspaces-include-buffers '("*scratch*"))))
