(use-package helm
  :config
  (setq
   helm-split-window-inside-p t
   helm-locate-command "locate %s -e -A --regex %s"
   helm-mode-fuzzy-match t
   helm-locate-fuzzy-match nil)
  (helm-autoresize-mode 1)
  (setq helm-autoresize-min-height 20
        helm-autoresize-max-height 40)
  (helm-fuzzier-mode 1)
  (helm-mode 1)
  :bind
  (("C-x b"   . helm-mini)
   ("C-x C-b" . helm-buffers-list)
   ("C-x C-m" . helm-M-x)
   ("M-y"     . helm-show-kill-ring)
   ("M-s s"   . helm-rg)
   ("C-x C-f" . helm-projectile-find-file)
   ("C-x h"   . helm-find-files)
   ("C-x p /" . helm-projectile-rg)
   ("C-x p p" . helm-projectile-switch-project)
   ("C-x /"   . helm-locate)
   ("C-x C-d" . helm-projectile-find-dir))
  )

(use-package projectile
  :after helm
  :config
  (setq
   projectile-completion-system 'helm
   projectile-enable-caching t
   projectile-file-exists-remote-cache-expire (* 10 60)
   projectile-cache-file (expand-file-name "projectile.cache" (substitute-in-file-name "$HOME/.cache/emacs"))
   projectile-known-projects-file (expand-file-name "projectile-bookmarks.eld" (substitute-in-file-name "$HOME/.cache/emacs")))
  (projectile-mode)
  (use-package helm-projectile
    :config
    (helm-projectile-on)))
