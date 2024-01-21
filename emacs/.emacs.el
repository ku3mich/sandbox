;;; package --- Summary
;;; Commentary:
;;; Code:

(require 'package)
(require 'speedbar)

(add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/"))

(package-initialize)

(require 'company-tern)
(require 'js2-mode)

(setq inhibit-startup-screen t)
(tool-bar-mode -1)

(setq-default header-line-format mode-line-format)
(setq-default mode-line-format nil)

(setq-default indent-tabs-mode nil)

(add-hook 'after-init-hook (lambda ()
							 (global-company-mode)
							 (add-to-list 'company-backends 'company-tern)
							 (show-paren-mode)
							 (global-flycheck-mode)
							 (load-theme 'tango-dark)
							 (setq js2-basic-offset 2)  
							 (setq js2-bounce-indent-p t)
							 (setq js2-mode-show-parse-errors nil)
							 (setq js2-mode-show-strict-warnings nil)
							 ))

(add-to-list 'auto-mode-alist '("\\.js\\'" . js2-mode))
(add-to-list 'interpreter-mode-alist '("node" . js2-mode))

(add-hook 'js2-mode-hook (lambda ()
						   (tern-mode)
						   (company-mode)
						   ))

(setq make-backup-files nil)
(setq-default tab-width 4)


(custom-set-variables
 '(speedbar-show-unknown-files t)
 )

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(speedbar-show-unknown-files t)
 '(custom-safe-themes
   (quote
	("5dd70fe6b64f3278d5b9ad3ff8f709b5e15cd153b0377d840c5281c352e8ccce" "67b11ee5d10f1b5f7638035d1a38f77bca5797b5f5b21d16a20b5f0452cbeb46" default)))
 '(package-selected-packages
   (quote
	(theme-looper popup less-css-mode js2-refactor flycheck company-web company-tern color-theme-twilight color-theme-sanityinc-solarized color-theme-library borland-blue-theme blackboard-theme auto-package-update))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )


(global-unset-key (kbd "C-e"))

(global-set-key (kbd "C-e s")
                (lambda ()
                  (interactive)
                  (sr-speedbar-toggle)
                  (speedbar-refresh)
                  ))

(global-set-key (kbd "C-e d")
				(lambda ()
				  (interactive)
				  (indent-region (point-min) (point-max))))

(provide '.emacs)
;;;
