;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; To install a package with Doom you must declare them here and run 'doom sync'
;; on the command line, then restart Emacs for the changes to take effect -- or
;; use 'M-x doom/reload'.

(package! nord-theme)

(package! blamer)

(package! org-appear
  :recipe (:host github
           :repo "awth13/org-appear"))

;; So we aren't putting secrets in our public dotfiles,
;; create ~/.authinfo with the following:
;;
;;    machine openai.com login apikey password <token_from_openai>
;;
(package! gptel :recipe (:nonrecursive t))

(package! powerline)

;;(package! llm)
;;ellama, org-ai

;; (package! auto-indent-mode)
