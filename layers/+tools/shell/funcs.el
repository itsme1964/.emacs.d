;;; funcs.el --- Shell Layer functions File
;;
;; Copyright (c) 2012-2018 Sylvain Benner & Contributors
;;
;; Author: Sylvain Benner <sylvain.benner@gmail.com>
;; URL: https://github.com/syl20bnr/spacemacs
;;
;; This file is not part of GNU Emacs.
;;
;;; License: GPLv3

(defun spacemacs/projectile-shell-pop ()
  "Open a term buffer at projectile project root."
  (interactive)
  (let ((default-directory (projectile-project-root)))
    (call-interactively 'spacemacs/default-pop-shell)))

(defun spacemacs/disable-hl-line-mode ()
  "Locally disable global-hl-line-mode"
  (interactive)
  (setq-local global-hl-line-mode nil))

(defun spacemacs/init-eshell-xterm-color ()
  "Initialize xterm coloring for eshell"
  (setq-local xterm-color-preserve-properties t)
  (make-local-variable 'eshell-preoutput-filter-functions)
  (add-hook 'eshell-preoutput-filter-functions 'xterm-color-filter)
  (setq-local eshell-output-filter-functions
              (remove 'eshell-handle-ansi-color
                      eshell-output-filter-functions)))

(defun ansi-term-handle-close ()
  "Close current term buffer when `exit' from term buffer."
  (when (ignore-errors (get-buffer-process (current-buffer)))
    (set-process-sentinel (get-buffer-process (current-buffer))
                          (lambda (proc change)
                            (when (string-match "\\(finished\\|exited\\)"
                                                change)
                              (kill-buffer (process-buffer proc))
                              (when (> (count-windows) 1)
                                (delete-window)))))))

(defun spacemacs/default-pop-shell ()
  "Open the default shell in a popup."
  (interactive)
  (let ((shell (case shell-default-shell
                 ('multi-term 'multiterm)
                 ('shell 'inferior-shell)
                 (t shell-default-shell))))
    (call-interactively (intern (format "spacemacs/shell-pop-%S" shell)))))

(defun spacemacs/resize-shell-to-desired-width ()
  (when (and (string= (buffer-name) shell-pop-last-shell-buffer-name)
             (memq shell-pop-window-position '(left right)))
    (enlarge-window-horizontally (- (/ (* (frame-width) shell-default-width)
                                       100)
                                    (window-width)))))

(defmacro make-shell-pop-command (func &optional shell)
  "Create a function to open a shell via the function FUNC.
SHELL is the SHELL function to use (i.e. when FUNC represents a terminal)."
  (let* ((name (symbol-name func)))
    `(defun ,(intern (concat "spacemacs/shell-pop-" name)) (index)
       ,(format (concat "Toggle a popup window with `%S'.\n"
                        "Multiple shells can be opened with a numerical prefix "
                        "argument. Using the universal prefix argument will "
                        "open the shell in the current buffer instead of a "
                        "popup buffer.") func)
       (interactive "P")
       (require 'shell-pop)
       (if (equal '(4) index)
           ;; no popup
           (,func ,shell)
         (shell-pop--set-shell-type
          'shell-pop-shell-type
          (backquote (,name
                      ,(concat "*" name "*")
                      (lambda nil (,func ,shell)))))
         (shell-pop index)
         (spacemacs/resize-shell-to-desired-width)))))

(defun projectile-multi-term-in-root ()
  "Invoke `multi-term' in the project's root."
  (interactive)
  (projectile-with-default-dir (projectile-project-root) (multi-term)))

(defun spacemacs//toggle-shell-auto-completion-based-on-path ()
  "Deactivates automatic completion on remote paths.
Retrieving completions for Eshell blocks Emacs. Over remote
connections the delay is often annoying, so it's better to let
the user activate the completion manually."
  (if (file-remote-p default-directory)
      (setq-local company-idle-delay nil)
    (setq-local company-idle-delay auto-completion-idle-delay)))

(defun spacemacs//eshell-switch-company-frontend ()
  "Sets the company frontend to `company-preview-frontend' in e-shell mode."
  (require 'company)
  (setq-local company-frontends '(company-preview-frontend)))

(defun spacemacs//eshell-auto-end ()
  "Move point to end of current prompt when switching to insert state."
  (when (and (eq major-mode 'eshell-mode)
             ;; Not on last line, we might want to edit within it.
             (not (eq (line-end-position) (point-max))))
    (end-of-buffer)))

(defun spacemacs//protect-eshell-prompt ()
  "Protect Eshell's prompt like Comint's prompts.

E.g. `evil-change-whole-line' won't wipe the prompt. This
is achieved by adding the relevant text properties."
  (let ((inhibit-field-text-motion t))
    (add-text-properties
     (point-at-bol)
     (point)
     '(rear-nonsticky t
                      inhibit-line-move-field-capture t
                      field output
                      read-only t
                      front-sticky (field inhibit-line-move-field-capture)))))

(defun spacemacs//init-eshell ()
  "Stuff to do when enabling eshell."
  (setq pcomplete-cycle-completions nil)
  (if (bound-and-true-p linum-mode) (linum-mode -1))
  (unless shell-enable-smart-eshell
    ;; we don't want auto-jump to prompt when smart eshell is enabled.
    ;; Idea: maybe we could make auto-jump smarter and jump only if
    ;; point is not on a prompt line
    (add-hook 'evil-insert-state-entry-hook
              'spacemacs//eshell-auto-end nil t)
    (add-hook 'evil-hybrid-state-entry-hook
              'spacemacs//eshell-auto-end nil t))
  (when (configuration-layer/package-used-p 'semantic)
    (semantic-mode -1))
  ;; This is an eshell alias
  (defun eshell/clear ()
    (let ((inhibit-read-only t))
      (erase-buffer)))
  ;; This is a key-command
  (defun spacemacs/eshell-clear-keystroke ()
    "Allow for keystrokes to invoke eshell/clear"
    (interactive)
    (eshell/clear)
    (eshell-send-input))
  ;; Caution! this will erase buffer's content at C-l
  (define-key eshell-mode-map (kbd "C-l") 'spacemacs/eshell-clear-keystroke)
  (define-key eshell-mode-map (kbd "C-d") 'eshell-delchar-or-maybe-eof)

  ;; These don't work well in normal state
  ;; due to evil/emacs cursor incompatibility
  (evil-define-key 'insert eshell-mode-map
    (kbd "C-k") 'eshell-previous-matching-input-from-input
    (kbd "C-j") 'eshell-next-matching-input-from-input))

(defun spacemacs/helm-eshell-history ()
  "Correctly revert to insert state after selection."
  (interactive)
  (helm-eshell-history)
  (evil-insert-state))

(defun spacemacs/helm-shell-history ()
  "Correctly revert to insert state after selection."
  (interactive)
  (helm-comint-input-ring)
  (evil-insert-state))

(defun spacemacs/init-helm-eshell ()
  "Initialize helm-eshell."
  ;; this is buggy for now
  ;; (define-key eshell-mode-map (kbd "<tab>") 'helm-esh-pcomplete)
  (spacemacs/set-leader-keys-for-major-mode 'eshell-mode
    "H" 'spacemacs/helm-eshell-history)
  (define-key eshell-mode-map
    (kbd "M-l") 'spacemacs/helm-eshell-history))

(defun term-send-tab ()
  "Send tab in term mode."
  (interactive)
  (term-send-raw-string "\t"))

;; Wrappers for non-standard shell commands
(defun multiterm (&optional ARG)
  "Wrapper to be able to call multi-term from shell-pop"
  (interactive)
  (multi-term))

(defun inferior-shell (&optional ARG)
  "Wrapper to open shell in current window"
  (interactive)
  (switch-to-buffer "*shell*")
  (shell "*shell*"))
