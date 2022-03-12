;;; config.el --- Rational Emacs configuration -*- lexical-binding: t; -*-
;;
;;; Commentary:
;;
;;  Rational Emacs configuration
;;
;;; Code:
(require 'rational-defaults)
(require 'rational-screencast)
(require 'rational-ui)
(require 'rational-editing)
(require 'rational-evil)
(require 'rational-completion)
(require 'rational-windows)

;; Set further font and theme customizations
(custom-set-variables
   '(rational-ui-default-font
     '(:font "JetBrains Mono" :weight 'light :height 185)))

(load-theme 'doom-nord-light t)
;;(load-theme 'doom-one-light t)

(message "Ready!")

;;; config.el ends here
