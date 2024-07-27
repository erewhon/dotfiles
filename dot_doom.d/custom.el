(put 'narrow-to-region 'disabled nil)
(put 'downcase-region 'disabled nil)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(tab-bar ((t (:inherit mode-line))))
 '(tab-bar-close-button-show nil)
 '(tab-bar-mode t)
 '(tab-bar-tab ((t (:inherit mode-line :foreground "white"))))
 '(tab-bar-tab-inactive ((t (:inherit mode-line-inactive :foreground "black"))))
 '(tab-bar-tab-name-format-function 'modern-tab-bar--tab-bar-name-format))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(tab-bar ((t (:inherit JetBrainsMono\ Nerd\ Font :background "#3b4252" :foreground "#e5e9f0"
                :box (:line-width (12 . 8) :color nil :style flat-button)))))
 '(tab-bar-tab ((t (:inherit tab-bar :box (:line-width (1 . 1) :style released-button)))))
 '(tab-bar-tab-inactive ((t (:inherit tab-bar-tab :background "#4c566a" :foreground "#3b4252")))))
