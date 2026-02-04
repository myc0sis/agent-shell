;;; agent-shell-nanocode.el --- NanoCode agent configurations -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Alvaro Ramirez

;; Author: Alvaro Ramirez https://xenodium.com
;; URL: https://github.com/xenodium/agent-shell

;; This package is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This package is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This file includes NanoCode-specific configurations.
;;

;;; Code:

(eval-when-compile
  (require 'cl-lib))
(require 'shell-maker)
(require 'acp)

(declare-function agent-shell--indent-string "agent-shell")
(declare-function agent-shell-make-agent-config "agent-shell")
(autoload 'agent-shell-make-agent-config "agent-shell")
(declare-function agent-shell--make-acp-client "agent-shell")
(declare-function agent-shell--dwim "agent-shell")

(cl-defun agent-shell-nanocode-make-authentication (&key api-key none)
  "Create NanoCode authentication configuration.

API-KEY is the NanoGPT API key string or function that returns it.
NONE when non-nil disables API key authentication.

Only one of API-KEY or NONE should be provided, never both."
  (when (and api-key none)
    (error "Cannot specify both :api-key and :none - choose one"))
  (unless (or api-key none)
    (error "Must specify either :api-key or :none"))
  (cond
   (api-key `((:api-key . ,api-key)))
   (none `((:none . t)))))

(defcustom agent-shell-nanocode-authentication
  (agent-shell-nanocode-make-authentication :none t)
  "Configuration for NanoCode authentication.
For API key (string):

  (setq agent-shell-nanocode-authentication
        (agent-shell-nanocode-make-authentication :api-key \"your-key\"))

For API key (function):

  (setq agent-shell-nanocode-authentication
        (agent-shell-nanocode-make-authentication :api-key (lambda () ...)))

For no authentication (when using `nanocode auth login`):

  (setq agent-shell-nanocode-authentication
        (agent-shell-nanocode-make-authentication :none t))"
  :type 'alist
  :group 'agent-shell)

(defcustom agent-shell-nanocode-command
  '("nanocode" "acp")
  "Command and parameters for the NanoCode client.

The first element is the command name, and the rest are command parameters."
  :type '(repeat string)
  :group 'agent-shell)

(defcustom agent-shell-nanocode-environment
  nil
  "Environment variables for the NanoCode client.

This should be a list of environment variables to be used when
starting the NanoCode client process.

Example usage to set custom environment variables:

  (setq agent-shell-nanocode-environment
        (`agent-shell-make-environment-variables'
         \"MY_VAR\" \"some-value\"
         \"MY_OTHER_VAR\" \"another-value\"))"
  :type '(repeat string)
  :group 'agent-shell)

(defun agent-shell-nanocode-make-agent-config ()
  "Create a NanoCode agent configuration.

Returns an agent configuration alist using `agent-shell-make-agent-config'."
  (agent-shell-make-agent-config
   :identifier 'nanocode
   :mode-line-name "NanoCode"
   :buffer-name "NanoCode"
   :shell-prompt "NanoCode> "
   :shell-prompt-regexp "NanoCode> "
   :welcome-function #'agent-shell-nanocode--welcome-message
   :client-maker (lambda (buffer)
                   (agent-shell-nanocode-make-client :buffer buffer))
   :install-instructions "See https://github.com/nanogpt-community/nanocode for installation."))

(defun agent-shell-nanocode-start-agent ()
  "Start an interactive NanoCode agent shell."
  (interactive)
  (agent-shell--dwim :config (agent-shell-nanocode-make-agent-config)
                     :new-shell t))

(cl-defun agent-shell-nanocode-make-client (&key buffer)
  "Create a NanoCode client using BUFFER as context.

Uses `agent-shell-nanocode-authentication' for authentication configuration."
  (unless buffer
    (error "Missing required argument: :buffer"))
  (let ((api-key (agent-shell-nanocode-key)))
    (agent-shell--make-acp-client :command (car agent-shell-nanocode-command)
                                  :command-params (cdr agent-shell-nanocode-command)
                                  :environment-variables (append (cond ((map-elt agent-shell-nanocode-authentication :none)
                                                                        nil)
                                                                       (api-key
                                                                        (list (format "NANOGPT_API_KEY=%s" api-key)))
                                                                       (t
                                                                        (error "Missing NanoCode authentication (see agent-shell-nanocode-authentication)")))
                                                                 agent-shell-nanocode-environment)
                                  :context-buffer buffer)))

(defun agent-shell-nanocode-key ()
  "Get the NanoGPT API key."
  (cond ((stringp (map-elt agent-shell-nanocode-authentication :api-key))
         (map-elt agent-shell-nanocode-authentication :api-key))
        ((functionp (map-elt agent-shell-nanocode-authentication :api-key))
         (condition-case _err
             (funcall (map-elt agent-shell-nanocode-authentication :api-key))
           (error
            (error "API key not found.  Check out `agent-shell-nanocode-authentication'"))))
        (t
         nil)))

(defun agent-shell-nanocode--welcome-message (config)
  "Return NanoCode welcome message using `shell-maker' CONFIG."
  (let ((art (agent-shell--indent-string 4 (agent-shell-nanocode--ascii-art)))
        (message (string-trim-left (shell-maker-welcome-message config) "\n")))
    (concat "\n\n"
            art
            "\n\n"
            message)))

(defun agent-shell-nanocode--ascii-art ()
  "NanoCode ASCII art."
  (let* ((is-dark (eq (frame-parameter nil 'background-mode) 'dark))
         (text "NanoCode"))
    (propertize text 'font-lock-face (if is-dark
                                         '(:foreground "#22c55e" :inherit fixed-pitch)
                                       '(:foreground "#16a34a" :inherit fixed-pitch)))))

(provide 'agent-shell-nanocode)

;;; agent-shell-nanocode.el ends here
