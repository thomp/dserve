;;; dserve.el --- Serve files via dired -*- lexical-binding: t -*-

;; Copyright (C) 2016 David Thompson
;; Author: David Thompson
;; Version: 0.1
;; Keywords: dired, HTTP, serve, file
;; URL: https://github.com/thomp/************************

;;; Commentary:

;; This package provides a way to serve files via HTTP
;; using dired-mode to select the files to be served.

;; To enable, add `dserve-mode' to `dired-mode-hook'.  For
;; convenience, the command `dserve-enable' will do this for
;; you.

;;; Code:

(require 'elnode)
(require 'seq)

(defvar dserve--alpha-chars
  (mapcar #'(lambda (x) x)
	  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"))

(defvar dserve--request-ok-p-fn
  ;; this is intended to serves onl as an example; ensure this
  ;; acts in the manner *you* desire it to
  #'(lambda (httpcon)
      (let ((request-host (elnode-http-header httpcon "Host")))
	(string= (seq-subseq request-host 0 7)
		 "192.168")))
  "Either NIL or a funcallable object. If non-NIL, the funcallable object can be used to filter requests (e.g., to restrict responses to computers on a particular network). It should return NIL if a request should be denied.")

(defvar dserve--file-map
  nil
  "Describes the files being served by dserve. Currently implemented as an alist where each key is a (hopefully) unique (relative to the set of keys in this alist) string and each value is a cons where the car represents an absolute path to a file and the cdr represents the time the file was added.")

(defvar dserve--index-page-template
  "<html>\n <head>\n  <title>%s</title>\n </head>\n <body>\n  <h1>%s</h1>\n  <div>%s</div>\n </body>\n</html>\n")

(defvar dserve--index-file-template
  "<a href='%s'>%s</a> %s <br/>\n")

(defvar dserve--numeric-chars
  (mapcar #'(lambda (x) x)
	  "0123456789"))

(defvar dserve--port
  8345
  "The HTTP server port")


(defvar dserve--alphanumeric-chars
  (append dserve--alpha-chars dserve--numeric-chars))


;; provide a list describing any available external interfaces
(defun dserve--external-interfaces () 
  (let ((accum nil)
	(ifaces (network-interface-list)))
    (dolist (iface ifaces)
      (let ((ip-vect (cdr iface)))
	(if (not (= 127 (elt ip-vect 0)))
	    (push ip-vect accum))))
    accum))

(defun dserve--handler-maker ()
  (lambda (httpcon)
    (let ((request-ok-p (if dserve--request-ok-p-fn
			    (funcall dserve--request-ok-p-fn httpcon))))
      (if request-ok-p
	  (dserve--handler-proc httpcon) 
	(dbooks-test-handler httpcon "no access")))))

(defun dserve--handler-proc (httpcon)
  "Actual webserver implementation. Do webserving to HTTPCON."
  ;; PATHINFO: browsing to http://192.168.1.241:8234/abc/def/ghi --> '/abc/def/ghi'
  (let ((pathinfo (substring (elnode-http-pathinfo httpcon) 1)))
    ;(message "pathinfo: %s" pathinfo)
    (let ((key-vals (assoc pathinfo dserve--file-map)))
      (message "key-vals: ->%s<-" key-vals) 
      (if key-vals
	  (let ((file-name (first key-vals))) 
	    (elnode-send-file httpcon (second key-vals)))
	(let ((index (dserve--index)))
	  (elnode-http-start httpcon 200 '("Content-type" . "text/html"))
	  (elnode-http-return httpcon index))))))

(defun dserve--index ()
  "Constructs index document. "
  ;; list of absolute paths
  (let ((title "dserve"))
    (format
     dserve--index-page-template
     title
     title
     (loop for key-vals in dserve--file-map
           concat 
	   (format
	    dserve--index-file-template
	    (first key-vals)
	    (second key-vals)
	    (third key-vals)
	    )))))

;; either return NIL (if elnode-init-host is fine as is) or return [vector? string?] of desired IP
(defun dserve--interactively-set-elnode-host ()
  ;; elnode-init-host defaults to 'localhost' but it's likely, if user is using dserve, that user would prefer to expose server and serve devices in the 'outside world'
  ;; expose server or serve as localhost?
  (let ((host-ip-string
	 (if (string= elnode-init-host "localhost")
	     (let ((external-ifaces-ips (dserve--external-interfaces)))
	       (if external-ifaces-ips 
		   (let ((iface-collection (mapcar #'(lambda (iface-ip)
						       (dserve--ip-vect-to-string (seq-subseq iface-ip 0 4)))
						   external-ifaces-ips)))
		     (let ((iface-ip
			    ;; confirm interest in external ip
			    (if nil ;(= (length iface-collection) 1)
				(if (y-or-n-p (format "An external IP is available -- use %s?" (first iface-collection)))
				    (first iface-collection))
			      (completing-read "Select an interface " iface-collection
					       nil
					       'confirm
					       (first iface-collection)
					       t
					       (first iface-collection)))))
		       iface-ip)))))))
    (if host-ip-string
	(setf elnode-init-host host-ip-string))))

;; IP-VECT has the form [127 0 0 1]
(defun dserve--ip-vect-to-string (ip-vect)
  (mapconcat #'(lambda (x) (int-to-string x)) ip-vect "."))

(defun dserve--random-chars (n)
  (let* ((set dserve--alphanumeric-chars)
	 (set-length (length set)))
    (with-temp-buffer
      (let ((standard-output (current-buffer)))
	(dotimes (x n)
	  (insert-char (nth (random set-length) set) 1)))
      (buffer-string))))

(defun dserve--start-server (&optional port) 
  (let ((docroot "/home/thomp/books/"))
    (let ((webserver-proc (dserve--handler-maker))
	  (host elnode-init-host)
	  (port (or port 8234))) 
      (elnode-start webserver-proc
		    :port port
		    :host host))))


(defun dserve-add-files ()
  (interactive)
  (let ((dir (dired-current-directory))
	(file-names (dired-get-marked-files t current-prefix-arg)))
    (dolist (file-name file-names)
      (let ((key (dserve--random-chars 30)))
	(message "Serving %s at %s" file-name key)
	(push (cons key
		    (list (concatenate 'string dir file-name)
			  (current-time-string)	;(current-time)
			  ))
	      dserve--file-map)))))

(defun dserve-clear ()
  "Empty dserve--file-map."
  (interactive)
  (setq dserve--file-map nil))

(defun dserve-start ()
  (interactive)
  (dserve--interactively-set-elnode-host)
  (dserve--start-server dserve--port)
  (message "Serving at %s on port %s" elnode-init-host dserve--port))

(defun dserve-stop ()
  (interactive)
  (elnode-stop dserve--port)
  (message "Server should be stopped; confirm with (list-elnode-servers)"))

(defun dserve-where-serving ()
  "Describe, via message, the URL where server can be accessed."
  (interactive)
  ;; FIXME: what if not serving yet? how to test?
  (message "Serving at %s on port %s" elnode-init-host dserve--port))

(defvar dserve-mode-map (make-sparse-keymap)
  "Keymap for `dserve-mode'.")

;; C-h k   -> type in key combination and find out what it's bound to

;; could use f5 f6 f7
(define-key dserve-mode-map (kbd "s-s a") 'dserve-add-files)
(define-key dserve-mode-map (kbd "s-s c") 'dserve-clear)
(define-key dserve-mode-map (kbd "s-s s") 'dserve-start)
(define-key dserve-mode-map (kbd "s-s x") 'dserve-stop)
(define-key dserve-mode-map (kbd "s-s u") 'dserve-where-serving)

;;;###autoload
(define-minor-mode dserve-mode
  "Add commands to serve files."
  :lighter " Serve")

;;;###autoload
(defun dserve-enable ()
  "Ensure that `dserve-mode' will be enabled in `dired-mode'."
  (interactive)
  (add-hook 'dired-mode-hook 'dserve-mode))

(provide 'dserve)
;;; dserve.el ends here
