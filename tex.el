;;; tex.el --- Support for TeX documents.

;; Copyright (C) 1985, 1986, 2000,
;;   2001, 2002, 2003, 2004 Free Software Foundation, Inc.
;; Copyright (C) 1987 Lars Peter Fischer
;; Copyright (C) 1991 Kresten Krab Thorup
;; Copyright (C) 1993, 1994, 1996, 1997, 1999 Per Abrahamsen

;; Maintainer: auc-tex@sunsite.dk
;; Keywords: tex

;; This file is part of AUCTeX.

;; AUCTeX is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; AUCTeX is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with AUCTeX; see the file COPYING.  If not, write to the Free
;; Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
;; 02111-1307, USA.

;;; Commentary:

;; This file provides AUCTeX support for plain TeX as well as basic
;; functions used by other AUCTeX modes (e.g. for LaTeX, Texinfo and
;; ConTeXt).

;;; Code:

(when (< emacs-major-version 20)
  (error "AUCTeX requires Emacs 20 or later"))

(require 'custom)
(eval-when-compile
  (require 'cl))
(require 'tex-fold)

(defgroup AUCTeX nil
  "A (La)TeX environment."
  :tag "AUCTeX"
  :link '(custom-manual "(auctex)Top")
  :link '(url-link :tag "Home Page" "http://www.gnu.org/software/auctex/")
  :prefix "TeX-"
  :group 'tex)

(defgroup TeX-file nil
  "Files used by AUCTeX."
  :group 'AUCTeX)

(defgroup TeX-command nil
  "Calling external commands from AUCTeX."
  :group 'AUCTeX)

(defgroup LaTeX nil
  "LaTeX support in AUCTeX."
  :tag "LaTeX"
  :group 'AUCTeX
  :prefix "LaTeX-")

(defgroup TeX-misc nil
  "Various AUCTeX settings."
  :group 'AUCTeX)

;;; Site Customization
;;
;; The following variables are likely to need to be changed for your
;; site.  It is suggested that you do this by *not* changing this
;; file, but instead copy those definitions you need to change to
;; `tex-site.el'.

;; How to print.

(defcustom TeX-print-command "dvips %s -P%p"
  "*Command used to print a file.

First `%p' is expanded to the printer name, then ordinary expansion is
performed as specified in `TeX-expand-list'."
  :group 'TeX-command
  :type 'string)

(defcustom TeX-queue-command "lpq -P%p"
  "*Command used to show the status of a printer queue.

First `%p' is expanded to the printer name, then ordinary expansion is
performed as specified in `TeX-expand-list'."
  :group 'TeX-command
  :type 'string)

(defcustom TeX-mode-hook nil
  "A hook run in TeX mode buffers."
  :type 'hook
  :group 'TeX-misc)

(defcustom AmS-TeX-mode-hook nil
  "A hook run in AmS TeX mode buffers."
  :type 'hook
  :group 'TeX-misc)

;; This is the major configuration variable.  Most sites will only
;; need to change the second string in each entry, which is the name
;; of a command to send to the shell.  If you use other formatters
;; like AMSLaTeX or AMSTeX, you can add those to the list.  See
;; TeX-expand-list for a description of the % escapes

(defcustom TeX-command-list
  ;; Changed to double quotes for Windows afflicted people.
  (list (list "TeX" "tex %S \"\\nonstopmode\\input %t\"" 'TeX-run-TeX nil
	      (list 'plain-tex-mode))
	(list "TeX Interactive" "tex %S %t" 'TeX-run-interactive nil
	      (list 'plain-tex-mode))
	(list "PDFTeX" "pdftex %S \"\\nonstopmode\\input %t\""
	      'TeX-run-TeX nil (list 'plain-tex-mode))
	(list "LaTeX" "%l \"\\nonstopmode\\input{%t}\""
	      'TeX-run-TeX nil (list 'latex-mode 'doctex-mode))
	(list "LaTeX Interactive" "%l \"\\input{%t}\""
	      'TeX-run-interactive nil (list 'latex-mode 'doctex-mode))
	;; Not part of standard TeX.
	(list "PDFLaTeX" "pdflatex %S \"\\nonstopmode\\input{%t}\""
	      'TeX-run-TeX nil (list 'latex-mode 'doctex-mode))
	(list "Makeinfo" "makeinfo %t" 'TeX-run-compile nil
	      (list 'texinfo-mode))
	(list "Makeinfo HTML" "makeinfo --html %t" 'TeX-run-compile nil
	      (list 'texinfo-mode))
	(list "AmSTeX" "amstex %S \"\\nonstopmode\\input %t\""
	      'TeX-run-TeX nil (list 'ams-tex-mode))
	;; support for ConTeXt  --pg
	;; first version of ConTeXt to support nonstopmode: 2003.2.10
	(list "ConTeXt" "texexec --once --nonstop --texutil %t" 'TeX-run-TeX
	      nil (list 'context-mode))
	(list "ConTeXt Interactive" "texexec --once --texutil %t"
	      'TeX-run-interactive t (list 'context-mode))
	(list "ConTeXt Full" "texexec %t" 'TeX-run-interactive nil
	      (list 'context-mode))
	;; --purge %s does not work on unix systems with current texutil
	;; check again october 2003 --pg
	(list "ConTeXt Clean" "texutil --purgeall" 'TeX-run-interactive nil
	      (list 'context-mode))
	(list "BibTeX" "bibtex %s" 'TeX-run-BibTeX nil t)
	(if (or window-system (getenv "DISPLAY"))
	    (list "View" "%V " 'TeX-run-discard t t)
	  (list "View" "dvi2tty -q -w 132 %s " 'TeX-run-command t t))
	(list "Print" "%p %r " 'TeX-run-command t t)
	(list "Queue" "%q" 'TeX-run-background nil t)
	(list "File" "dvips %d -o %f " 'TeX-run-command t t)
	(list "Index" "makeindex %s" 'TeX-run-command nil t)
	;; (list "Check" "chktex -v3 %s" 'TeX-run-compile nil t)
	;; Uncomment the above line and comment out the next line to
	;; use `chktex' instead of `lacheck'.
	(list "Check" "lacheck %s" 'TeX-run-compile nil t)
	(list "Spell" "<ignored>" 'TeX-run-ispell-on-document nil t)
	(list "Other" "" 'TeX-run-command t t))
  "List of commands to execute on the current document.

Each element is a list, whose first element is the name of the command
as it will be presented to the user.

The second element is the string handed to the shell after being
expanded.  The expansion is done using the information found in
`TeX-expand-list'.

The third element is the function which actually start the process.
Several such hooks has been defined:

TeX-run-command: Start up the process and show the output in a
separate buffer.  Check that there is not two commands running for the
same file.  Return the process object.

TeX-run-format: As `TeX-run-command', but assume the output is created
by a TeX macro package.  Return the process object.

TeX-run-TeX: For TeX output.

TeX-run-interactive: Run TeX or LaTeX interactively.

TeX-run-BibTeX: For BibTeX output.

TeX-run-compile: Use `compile' to run the process.

TeX-run-shell: Use `shell-command' to run the process.

TeX-run-discard: Start the process in the background, discarding its
output.

TeX-run-background: Start the process in the background, show output
in other window.

TeX-run-silent: Start the process in the background.

TeX-run-dviout: Special hook for the Japanese dviout previewer for
PC-9801.

To create your own hook, define a function taking three arguments: The
name of the command, the command string, and the name of the file to
process.  It might be useful to use `TeX-run-command' in order to
create an asynchronous process.

If the fourth element is non-nil, the user will get a chance to
modify the expanded string.

The fifth element indicates in which mode(s) the command should be
present in the Command menu.  Use t if it should be active in any
mode.  If it should only be present in some modes, specify a list with
the respective mode names."
  :group 'TeX-command
  :type '(repeat (group (string :tag "Name")
			(string :tag "Command")
			(choice :tag "How"
				:value TeX-run-command
				(function-item TeX-run-command)
				(function-item TeX-run-format)
				(function-item TeX-run-TeX)
				;; leave the following line in
				;; customization? Replaced (but still
				;; available) with TeX-run-TeX --pg
				(function-item TeX-run-LaTeX)
				(function-item TeX-run-interactive)
				(function-item TeX-run-BibTeX)
				(function-item TeX-run-compile)
				(function-item TeX-run-shell)
				(function-item TeX-run-discard)
				(function-item TeX-run-background)
				(function-item TeX-run-silent)
				(function-item TeX-run-dviout)
				(function :tag "Other"))
			(boolean :tag "Prompt")
			(choice :tag "Modes"
				(const :tag "All" t)
				(set (const :tag "Plain TeX" plain-tex-mode)
				     (const :tag "LaTeX" latex-mode)
				     (const :tag "DocTeX" doctex-mode)
				     (const :tag "ConTeXt" context-mode)
				     (const :tag "Texinfo" texinfo-mode)
				     (const :tag "AmSTeX" ams-tex-mode))))))

(defcustom TeX-command-output-list
  '(("\\`pdf[a-z]*tex" "pdf")
; Add the following line if you want to use htlatex (tex4ht)
;    ("\\`htlatex" ("html"))
    ("." "dvi"))
  "List of regexps and file extensions.

Each element is a list, whose first element is a regular expression to
match against the name of the command that will be used to process the TeX
file.

The second element is either a string or a list with a string as element.
If it is a string this is the default file extension that will be expected
for output files that are produced by commands that match the first
element.  The real file extension will be obtained from the logging output
if possible, defaulting to the given string.
If it is a list, the element of the list will be the fixed extension used
without looking at the logging output.
Extensions must be given without the \".\"."

  :group 'TeX-command
  :type '(repeat (group (regexp :tag "Command Regexp")
			(choice (string :tag "Default Extension")
				(group (string :tag "Fixed Extension"))))))

;; You may want to change the default LaTeX version for your site.
(defcustom LaTeX-version "2e"
  "Default LaTeX version.  Currently recognized is \"2\" and \"2e\"."
  :group 'LaTeX
  :type '(radio (const :format "%v\n%h"
		       :doc "\
The executable `latex' is LaTeX version 2."
		       "2")
		(const :format "%v\n%h"
		       :doc "\
The executable `latex' is LaTeX version 2e."
		       "2e")
		(string :tag "Other")))


;; Use different compilation commands depending on style.
;; Only works if parsing is enabled.

(defcustom LaTeX-command-style
  (if (string-equal LaTeX-version "2")
      ;; There is a lot of different LaTeX 2 based formats.
      '(("^latex2e$" "latex2e %S")
	("^foils$" "foiltex")
	("^ams" "amslatex %S")
	("^slides$" "slitex")
	("^plfonts\\|plhb$" "platex %S")
	("." "latex %S"))
    ;; They have all been combined in LaTeX 2e.
    '(("." "latex %S")))
  "List of style options and LaTeX commands.

If the first element (a regular expresion) matches the name of one of
the style files, any occurrence of the string `%l' in a command in
`TeX-command-list' will be replaced with the second element.  The first
match is used, if no match is found the `%l' is replaced with the empty
string."
  :group 'TeX-command
  :type '(repeat (group :value ("" "")
			regexp (string :tag "Style"))))

;; Enter the names of the printers available at your site, or nil if
;; you only have one printer.

(defcustom TeX-printer-list
  '(("Local" "dvips -f %s | lpr" "lpq")
    ("lw") ("ps"))
  "List of available printers.

The first element of each entry is the printer name.

The second element is the command used to print to this
printer.  It defaults to the value of `TeX-print-command'.

The third element is the command used to examine the print queue for
this printer.  It defaults to the value of `TeX-queue-command'.

Any occurrence of `%p' in the second or third element is expanded to
the printer name given in the first element, then ordinary expansion
is performed as specified in `TeX-expand-list'."
  :group 'TeX-command
  :type '(repeat (group (string :tag "Name")
			(option (group :inline t
				       :extra-offset -4
				       (choice :tag "Print"
					       (const :tag "default")
					       (string :format "%v"))
				       (option (choice :tag "Queue"
						       (const :tag "default")
						       (string
							:format "%v"))))))))

;; The name of the most used printer.

(defcustom TeX-printer-default (or (getenv "PRINTER")
				   (and TeX-printer-list
					(car (car TeX-printer-list)))
				   "lw")
  "*Default printer to use with `TeX-command'."
  :group 'TeX-command
  :type 'string)

;; You may want special options to the view command depending on the
;; style options.  Only works if parsing is enabled.

(defcustom TeX-view-style
  `((,(concat
      "^" (regexp-opt '("a4paper" "a4" "a4dutch" "a4wide" "sem-a4")) "$")
     "xdvi %d %dS -paper a4")
    (,(concat "^" (regexp-opt '("a5paper" "a5" "a5comb")) "$")
     "xdvi %d %dS -paper a5")
    ("^b5paper$" "xdvi %d %dS -paper b5")
    ("^letterpaper$" "xdvi %d %dS -paper us")
    ("^legalpaper$" "xdvi %d %dS -paper legal")
    ("^executivepaper$" "xdvi %d %dS -paper 7.25x10.5in")
    ("^landscape$" "xdvi %d %dS -paper a4r -s 0")
    ;; The latest xdvi can show embedded postscript.  If you don't
    ;; have that, uncomment next line.
    ;; ("^epsf$" "ghostview %f")
    ("." "xdvi %d %dS"))
  "List of style options and view options.

If the first element (a regular expresion) matches the name of
one of the style files, any occurrence of the string `%v' in a
command in `TeX-command-list' will be replaced with the second
element.  The first match is used, if no match is found the `%v'
is replaced with the empty string.

As a default, the \"View\" command in `TeX-command-list' is set
to `%V'.  This means that `TeX-output-view-style' will be
consulted before `TeX-view-style'.  Only if no match is found in
`TeX-output-view-style' the settings in `TeX-view-style' will be
considered.  If you want to bypass `TeX-output-view-style', which
is not recommended because it is more powerful than
`TeX-view-style', use `%v' in the \"View\" command."
  :group 'TeX-command
  :type '(repeat (group regexp (string :tag "Command"))))

(defcustom TeX-output-view-style
  `(("^dvi$" "^pstricks$\\|^pst-\\|^psfrag$" "dvips %d -o && gv %f")
    ("^dvi$" ,(concat
	       "^"
	       (regexp-opt '("a4paper" "a4" "a4dutch" "a4wide" "sem-a4"))
	       "$")
     "xdvi %d %dS -paper a4")
    ("^dvi$" (,(concat "^" (regexp-opt '("a5paper" "a5" "a5comb")) "$")
	      "^landscape$")
     "xdvi %d %dS -paper a5r -s 0")
    ("^dvi$" ,(concat "^" (regexp-opt '("a5paper" "a5" "a5comb")) "$")
     "xdvi %d %dS -paper a5")
    ("^dvi$" "^b5paper$" "xdvi %d %dS -paper b5")
    ("^dvi$" ("^landscape$" "^pstricks$\\|^psfrag$")
     "dvips -t landscape %d -o && gv %f")
    ("^dvi$" "^letterpaper$" "xdvi %d %dS -paper us")
    ("^dvi$" "^legalpaper$" "xdvi %d %dS -paper legal")
    ("^dvi$" "^executivepaper$" "xdvi %d %dS -paper 7.25x10.5in")
    ("^dvi$" "^landscape$" "xdvi %d %dS -paper a4r -s 0")
    ("^dvi$" "." "xdvi %d %dS")
    ("^pdf$" "." "xpdf %o")
    ("^html?$" "." "netscape %o"))
  "List of output file extensions and view options.

If the first element (a regular expresion) matches the output
file extension, and the second element (a regular expression)
matches the name of one of the style options, any occurrence of
the string `%V' in a command in `TeX-command-list' will be
replaced with the third element.  The first match is used; if no
match is found the `%V' is replaced with `%v'.  The outcome of `%v'
is determined by the settings in `TeX-view-style' which therefore
serves as a fallback for `TeX-output-view-style'.  The second
element may also be a list of regular expressions, in which case
all the regular expressions must match for the element to apply."
  :group 'TeX-command
  :type '(repeat (group
		  (regexp :tag "Extension")
		  (choice regexp (repeat :tag "List" regexp))
		  (string :tag "Command"))))

;;Same for printing.

(defcustom TeX-print-style '(("^landscape$" "-t landscape"))
  "List of style options and print options.

If the first element (a regular expresion) matches the name of one of
the style files, any occurrence of the string `%r' in a command in
`TeX-command-list' will be replaced with the second element.  The first
match is used, if no match is found the `%r' is replaced with the empty
string."
  :group 'TeX-command
  :type '(repeat (group regexp (string :tag "Command"))))

;; This is the list of expansion for the commands in
;; TeX-command-list.  Not likely to be changed, but you may e.g. want
;; to handle .ps files.

(defcustom TeX-expand-list
  (list (list "%p" 'TeX-printer-query)	;%p must be the first entry
	(list "%q" (lambda ()
		     (TeX-printer-query TeX-queue-command 2)))
	(list "%V" (lambda ()
		     (TeX-output-style-check TeX-output-view-style)))
	(list "%v" (lambda ()
		     (TeX-style-check TeX-view-style)))
	(list "%r" (lambda ()
		     (TeX-style-check TeX-print-style)))
	(list "%l" (lambda ()
		     (TeX-style-check LaTeX-command-style)))
	(list "%S" 'TeX-source-specials-expand-options)
	(list "%dS" 'TeX-source-specials-expand-view-options)
	;; `file' means to call `TeX-master-file'
	(list "%s" 'file nil t)
	(list "%t" 'file 't t)
	(list "%n" 'TeX-current-line)
	(list "%d" 'file "dvi" t)
	(list "%f" 'file "ps" t)
	(list "%o" 'TeX-view-output-file)
	;; for source specials the file name generated for the xdvi
	;; command needs to be relative to the master file, just in
	;; case the file is in a different subdirectory
	(list "%b" 'TeX-current-file-name-master-relative))
  "List of expansion strings for TeX command names.

Each entry is a list with two or more elements.  The first element is
the string to be expanded.  The second element is the name of a
function returning the expanded string when called with the remaining
elements as arguments.  The special value `file' will be expanded to
the name of the file being processed, with an optional extension."
  :group 'TeX-command
  :type '(repeat (group (string :tag "Key")
			(sexp :tag "Expander")
			(repeat :inline t
				:tag "Arguments"
				(sexp :format "%v")))))

;; End of Site Customization.

;;; Import

;;(or (assoc TeX-lisp-directory (mapcar 'list load-path))	;No `member' yet.
;;    (setq load-path (cons TeX-lisp-directory load-path)))

(defvar no-doc
  "This function is part of AUCTeX, but has not yet been loaded.
Full documentation will be available after autoloading the function."
  "Documentation for autoload functions.")

;; This hook will store bibitems when you save a BibTeX buffer.
(add-hook 'bibtex-mode-hook 'BibTeX-auto-store)

(autoload 'BibTeX-auto-store "latex" no-doc t)

(autoload 'LaTeX-math-mode "latex" no-doc t)
(autoload 'japanese-plain-tex-mode "tex-jp" no-doc t)
(autoload 'japanese-latex-mode "tex-jp" no-doc t)
(autoload 'japanese-slitex-mode "tex-jp" no-doc t)
(autoload 'texinfo-mode "tex-info" no-doc t)
(autoload 'latex-mode "latex" no-doc t)

(autoload 'multi-prompt "multi-prompt" no-doc nil)
(autoload 'texmathp "texmathp" no-doc nil)

;;; Portability.

(require 'easymenu)

;;; Documentation for Info-goto-emacs-command-node and similar

(eval-after-load 'info '(progn
			  (add-to-list 'Info-file-list-for-emacs
				       '("TeX" . "AUCTeX"))
			  (add-to-list 'Info-file-list-for-emacs
				       '("LaTeX" . "AUCTeX"))))


;;; Special support for XEmacs

(when (featurep 'xemacs)

  (defun TeX-mark-active ()
    ;; In Lucid (mark) returns nil when not active.
    (if zmacs-regions
	(mark)
      (mark t)))

  (defun TeX-active-mark ()
    (and zmacs-regions (mark)))

  (fset 'TeX-activate-region (symbol-function 'zmacs-activate-region))

  ;; I am aware that this counteracts coding conventions but I am sick
  ;; of it.
  (unless (fboundp 'line-beginning-position)
    (defalias 'line-beginning-position 'point-at-bol))
  (unless (fboundp 'line-end-position)
    (defalias 'line-end-position 'point-at-eol)))

;;; Special support for GNU Emacs

(unless (featurep 'xemacs)

  (defun TeX-mark-active ()
    ;; In FSF 19 mark-active indicates if mark is active.
    mark-active)

  (defun TeX-active-mark ()
    (and transient-mark-mode mark-active))

  (defun TeX-activate-region ()
    nil))

(defconst AUCTeX-version (eval-when-compile
  (let ((name "$Name:  $")
	(rev "$Revision: 5.391 $"))
    (or (when (string-match "\\`[$]Name: *\\(release_\\)?\\([^ ]+\\) *[$]\\'"
			    name)
	  (setq name (match-string 2 name))
	  (while (string-match "_" name)
	    (setq name (replace-match "." t t name)))
	  name)
	(if (string-match "\\`[$]Revision: *\\([^ ]+\\) *[$]\\'" rev)
	    (format "CVS-%s" (match-string 1 rev)))
	"unknown")))
  "AUCTeX version.
If not a regular release, CVS revision of `tex.el'.")

(defconst AUCTeX-date
  (eval-when-compile
    (let ((date "$Date: 2004-07-09 09:33:20 $"))
      (string-match
       "\\`[$]Date: *\\([0-9]+\\)/\\([0-9]+\\)/\\([0-9]+\\)"
       date)
      (format "%s.%s%s" (match-string 1 date) (match-string 2 date)
	      (match-string 3 date))))
  "AUCTeX release date.
In the form of yyyy.mmdd")

(defconst AUC-TeX-version AUCTeX-version
  "Obsolete.  Replaced by `AUCTeX-version'.")

(defconst AUC-TeX-date AUCTeX-date
  "Obsolete.  Replaced by `AUCTeX-date'.")

;;; Buffer

(defgroup TeX-output nil
  "Parsing TeX output."
  :prefix "TeX-"
  :group 'AUCTeX)

(defcustom TeX-display-help t
  "*Non-nil means popup help when stepping thrugh errors with \\[TeX-next-error]."
  :group 'TeX-output
  :type 'boolean)

(defcustom TeX-debug-bad-boxes nil
  "*Non-nil means also find overfull/underfull boxes warnings with \\[TeX-next-error]."
  :group 'TeX-output
  :type 'boolean)

(defvar TeX-source-specials-map
  (let ((map (make-sparse-keymap)))
    ;; (if (featurep 'xemacs)
    ;;	   (define-key map [(control button1)] #'TeX-view-mouse)
    ;;   (define-key map [C-down-mouse-1] #'TeX-view-mouse))
    map)
  "Keymap for `TeX-source-specials' mode.
You could use this for unusual mouse bindings.")

(define-minor-mode TeX-source-specials
  "Minor mode for generating and using LaTeX source specials.

If enabled, an option that inserts source specials into the DVI
file is added to the LaTeX commmand line and the DVI viewer is
called with an appropriate option, so that it shows the the point
in the DVI file corresponding to the point in the Emacs buffer.

See the documention of your viewer, e.g. the section \"SOURCE SPECIALS\" in
xdvi(1) and <URL:http://xdvi.sourceforge.net/inverse-search.html>, for
details."
  ;; FIXME: We'll need doc strings for all other viewers [beside xdvi] as
  ;; well.  Or the respective pointers.  Or just a pointer to the manual
  ;; that explains the details.  [Suggestion by dak]
  ;;
  ;; We should describe emacsclient / gnuclient in the AUCTeX manual and
  ;; only add a reference here.
  :group 'TeX-command
  ;; FIXME: There's nothing about source-specials there yet:
  ;; :link '(custom-manual "(auctex)Viewing")
  :lighter (TeX-mode-p "^")
  :global t
  (set-keymap-parent TeX-mode-map
		     (and TeX-source-specials
			  TeX-source-specials-map)))

(setq minor-mode-map-alist (delq
		       (assq 'TeX-source-specials minor-mode-map-alist)
		       minor-mode-map-alist))

(defcustom TeX-source-specials-tex-flags "-src-specials"
  "Extra flags to pass to TeX commands to generate source specials."
  :type '(choice string (repeat string))
  :group 'TeX-command)

(defcustom TeX-source-specials-places nil
  "List of places where to insert source specials into the DVI file.
If nil, use (La)TeX's defaults."
  :group 'TeX-command
  :type '(list (set :inline t
		    ;; :tag "Options known to work"
		    ;; cr display hbox math par parend vbox
		    (const "cr")
		    (const "display")
		    (const "hbox")
		    (const "math")
		    (const "par")
		    (const "parend")
		    (const "vbox"))
	       (repeat :inline t
		       :tag "Other options"
		       (string))))
;; FIXME: We could also offer the WHERE value list.
;; From latex(1):
;; -src-specials            insert source specials into the DVI file
;; -src-specials=WHERE      insert source specials in certain places of
;;                           the DVI file. WHERE is a comma-separated value
;;                           list: cr display hbox math par parend vbox
;; Anyhow, this variable should be customizable.

(defvar TeX-source-specials-viewer-flags
  "-sourceposition %n:%b"
  "*Extra flags to pass to the dvi viewer commands to use source specials.")

(defun TeX-source-specials-expand-view-options (&optional viewer)
  "Return source specials command line option for viewer command.
The return value depends on the value of `TeX-source-specials'.
If this is nil, an empty string will be returned."
  (if TeX-source-specials
      TeX-source-specials-viewer-flags
    ""))

(defun TeX-source-specials-expand-options ()
  "Return source specials command line option for TeX commands.
The return value depends on the value of `TeX-source-specials'.
If this is nil, an empty string will be returned."
  (if TeX-source-specials
      (concat
       TeX-source-specials-tex-flags
       (if TeX-source-specials-places
	   (concat
	    "="
	    (mapconcat 'identity
		       TeX-source-specials-places
		       ","))))
    ""))

(defgroup TeX-command-name nil
  "Names for external commands in AUCTeX."
  :group 'TeX-command)

(defcustom TeX-command-BibTeX "BibTeX"
  "*The name of the BibTeX entry in `TeX-command-list'."
  :group 'TeX-command-name
  :type 'string)
  (make-variable-buffer-local 'TeX-command-BibTeX)

(defcustom TeX-command-Show "View"
  "*The default command to show (view or print) a TeX file.
Must be the car of an entry in `TeX-command-list'."
  :group 'TeX-command-name
  :type 'string)
  (make-variable-buffer-local 'TeX-command-Show)

(defcustom TeX-command-Print "Print"
  "The name of the Print entry in `TeX-command-Print'."
  :group 'TeX-command-name
  :type 'string)

(defcustom TeX-command-Queue "Queue"
  "The name of the Queue entry in `TeX-command-Queue'."
  :group 'TeX-command-name
  :type 'string)

(autoload 'TeX-region-create "tex-buf" no-doc nil)
(autoload 'TeX-save-document "tex-buf" no-doc t)
(autoload 'TeX-home-buffer "tex-buf" no-doc t)
(autoload 'TeX-pin-region "tex-buf" no-doc t)
(autoload 'TeX-command-region "tex-buf" no-doc t)
(autoload 'TeX-command-buffer "tex-buf" no-doc t)
(autoload 'TeX-command-master "tex-buf" no-doc t)
(autoload 'TeX-command "tex-buf" no-doc nil)
(autoload 'TeX-kill-job "tex-buf" no-doc t)
(autoload 'TeX-recenter-output-buffer "tex-buf" no-doc t)
(autoload 'TeX-next-error "tex-buf" no-doc t)
(autoload 'TeX-toggle-debug-boxes "tex-buf" no-doc t)
(autoload 'TeX-region-file "tex-buf" no-doc nil)
(autoload 'TeX-current-offset "tex-buf" no-doc nil)

(defvar TeX-trailer-start nil
  "Regular expression delimiting start of trailer in a TeX file.")

 (make-variable-buffer-local 'TeX-trailer-start)

(defvar TeX-header-end nil
  "Regular expression delimiting end of header in a TeX file.")

 (make-variable-buffer-local 'TeX-header-end)

(defvar TeX-command-default nil
  "The default command for `TeX-command' in the current major mode.")

 (make-variable-buffer-local 'TeX-command-default)


;;; Master File

(defcustom TeX-one-master "\\.\\(tex\\|dtx\\)$"
  "*Regular expression matching ordinary TeX files.

You should set this variable to match the name of all files, where
automatically adding a file variable with the name of the master file
is a good idea.  When AUCTeX adds the name of the master file as a
file variable, it does not need to ask next time you edit the file.

If you dislike AUCTeX automatically modifying your files, you can set
this variable to \"<none>\"."
  :group 'TeX-command
  :type 'regexp)

(defun TeX-dwim-master ()
  "Find a likely `TeX-master'."
  (let ((dir default-directory))
    (dolist (buf (buffer-list))
      (when (with-current-buffer buf
	      (and (equal dir default-directory)
		   (stringp TeX-master)))
	(return (with-current-buffer buf TeX-master))))))

(defun TeX-master-file-ask ()
  "Ask for master file, set `TeX-master' and add local variables."
  (interactive)
  (if (TeX-local-master-p)
      (error "Master file already set")
    (setq TeX-master
	  (let ((default (TeX-dwim-master)))
	    (or
	     (and (eq 'dwim TeX-master) default)
	     (TeX-strip-extension
	      (condition-case name
		  (read-file-name (format "Master file: (default %s) "
					  (or default "this file"))
				  nil (or default "<default>"))
		(quit "<quit>"))
	      (list TeX-default-extension)
	      'path))))
    (cond ((string-equal TeX-master "<quit>")
	   (setq TeX-master t))
	  ((or (string-equal TeX-master "<default>")
	       (string-equal TeX-master ""))
	   (setq TeX-master t)
	   (TeX-add-local-master))
	  (t
	   (TeX-add-local-master)))))

(defun TeX-master-file (&optional extension nondirectory ask)
  "Set and return the name of the master file for the current document.

If optional argument EXTENSION is non-nil, add that file extension to
the name.  Special value t means use `TeX-default-extension'.

If optional second argument NONDIRECTORY is non-nil, do not include
the directory.

If optional third argument ASK is non-nil, ask the user for the
name of master file if it cannot be determined otherwise.

Currently it will check for the presence of a ``Master:'' line in
the beginning of the file, but that feature will be phased out."
  (interactive)
  (if (eq extension t)
      (setq extension TeX-default-extension))
  (let ((my-name (if (buffer-file-name)
		     (TeX-strip-extension nil (list TeX-default-extension) t)
		   "<none>")))
    (save-excursion
      (save-restriction
	(widen)
	(goto-char (point-min))
	(cond
	 ;; Special value 't means it is own master (a free file).
	 ((equal TeX-master my-name)
	  (setq TeX-master t))

	 ;; For files shared between many documents.
	 ((and (eq 'shared TeX-master) ask)
	  (setq TeX-master
		(TeX-strip-extension
		 (let ((default (or (TeX-dwim-master) "this file")))
		   (read-file-name (format "Master file: (default %s) " default)
				   nil default))
		 (list TeX-default-extension)
		 'path))
	  (if (or (string-equal TeX-master "this file")
		  (string-equal TeX-master ""))
	      (setq TeX-master t)))

	 ;; We might already know the name.
	 ((or (eq TeX-master t) (stringp TeX-master)) TeX-master)

	 ;; Support the ``Master:'' line (under protest!)
	 ((re-search-forward
	   "^%% *[Mm]aster:?[ \t]*\\([^ \t\n]+\\)" 500 t)
	  (setq TeX-master
		(TeX-strip-extension (TeX-match-buffer 1)
				     (list TeX-default-extension)))
	  (if TeX-convert-master
	      (progn
		(beginning-of-line)
		(kill-line 1)
		(TeX-add-local-master))))

	 ;; Ask the user (but add it as a local variable).
	 (ask (TeX-master-file-ask)))))

    (let ((name (if (stringp TeX-master)
		    TeX-master
		  my-name)))

      (if (TeX-match-extension name)
      ;; If it already have an extension...
	  (if (equal extension TeX-default-extension)
	      ;; Use instead of the default extension
	      (setq extension nil)
	    ;; Otherwise drop it.
	    (setq name (TeX-strip-extension name))))

      ;; Remove directory if needed.
      (if nondirectory
	  (setq name (file-name-nondirectory name)))

      (if extension
	  (concat name "." extension)
	name))))

(defun TeX-master-directory ()
  "Directory of master file."
  (file-name-as-directory
   (abbreviate-file-name
    (substitute-in-file-name
     (expand-file-name
      (let ((dir (file-name-directory (TeX-master-file))))
	(if dir (directory-file-name dir) "."))
      (and buffer-file-name
	   (file-name-directory buffer-file-name)))))))

(defcustom TeX-master t
  "*The master file associated with the current buffer.
If the file being edited is actually included from another file, you
can tell AUCTeX the name of the master file by setting this variable.
If there are multiple levels of nesting, specify the top level file.

If this variable is nil, AUCTeX will query you for the name.

If the variable is t, AUCTeX will assume the file is a master file
itself.

If the variable is 'shared, AUCTeX will query for the name, but not
change the file.

If the variable is 'dwim, AUCTeX will try to avoid querying by
attempting to `do what I mean'; and then change the file.

It is suggested that you use the File Variables (see the info node in
the Emacs manual) to set this variable permanently for each file."
  :group 'TeX-command
  :group 'TeX-parse
  :type '(choice (const :tag "Query" nil)
		 (const :tag "This file" t)
		 (const :tag "Shared" shared)
		 (const :tag "Dwim" dwim)
		 (string :format "%v")))

 (make-variable-buffer-local 'TeX-master)

(defvar TeX-convert-master t
  "*If not nil, automatically convert ``Master:'' lines to file variables.
This will be done when AUCTeX first try to use the master file.")

(defun TeX-add-local-master ()
  "Add local variable for `TeX-master'."

  (if (and (buffer-file-name)
	   (string-match TeX-one-master
			 (file-name-nondirectory (buffer-file-name)))
	   (not buffer-read-only))
      (progn
	(goto-char (point-max))
	(if (re-search-backward (concat "^\\([^\n]+\\)Local " "Variables:")
				(- (point-max) 3000) t)
	    (let ((prefix (TeX-match-buffer 1)))
	      (re-search-forward (regexp-quote (concat prefix
							"End:")))
	      (beginning-of-line 1)
	      (insert prefix "TeX-master: " (prin1-to-string TeX-master) "\n"))
	  (newline)
	  (when (eq major-mode 'doctex-mode)
	    (insert "% " TeX-esc "iffalse\n"))
	  (insert "%%% Local " "Variables: \n"
		  "%%% mode: " (substring (symbol-name major-mode) 0 -5)
		  "\n"
		  "%%% TeX-master: " (prin1-to-string TeX-master) "\n"
		  "%%% End: \n")
	  (when (eq major-mode 'doctex-mode)
	    (insert "% " TeX-esc "fi\n"))))))

(defun TeX-local-master-p ()
  "Return t if there is a `TeX-master' entry in the local variables section.
Return nil otherwise."
  (save-excursion
    (goto-char (point-max))
    (if (re-search-backward "^%+ *TeX-master:" nil t)
	t
      nil)))

;;; Style Paths

(setq TeX-lisp-directory (file-name-as-directory TeX-lisp-directory))

(setq TeX-auto-global (file-name-as-directory TeX-auto-global))

(defcustom TeX-style-global (file-name-as-directory
			     (concat TeX-lisp-directory "style"))
  "*Directory containing hand generated TeX information.
Must end with a directory separator.

These correspond to TeX macros shared by all users of a site."
  :group 'TeX-file
  :type 'directory)

(defcustom TeX-auto-local (file-name-as-directory "auto")
  "*Directory containing automatically generated TeX information.
Must end with a directory separator.

This correspond to TeX macros found in the current directory, and must
be relative to that."
  :group 'TeX-file
  :type 'string)

(defcustom TeX-style-local (file-name-as-directory "style")
  "*Directory containing hand generated TeX information.
Must end with a slash.

These correspond to TeX macros found in the current directory, and must
be relative to that."
  :group 'TeX-file
  :type 'string)

(defun TeX-split-string (regexp string)
  "Return a list of strings.
Given REGEXP the STRING is split into sections which in string was
seperated by REGEXP.

Examples:

      (TeX-split-string \"\:\" \"abc:def:ghi\")
	  -> (\"abc\" \"def\" \"ghi\")

      (TeX-split-string \" +\" \"dvips  -Plw -p3 -c4 testfile.dvi\")

	  -> (\"dvips\" \"-Plw\" \"-p3\" \"-c4\" \"testfile.dvi\")

If REGEXP is nil, or \"\", an error will occur."

  (let ((start 0) result match)
    (while (setq match (string-match regexp string start))
      (push (substring string start match) result)
      (setq start (match-end 0)))
    (push (substring string start) result)
    (nreverse result)))

(defun TeX-parse-path (env)
  "Return a list if private TeX directories found in environment variable ENV."
  (let* ((value (getenv env))
	 (entries (and value
		       (TeX-split-string
			(if (string-match ";" value) ";" ":")
			value)))
	 entry
	 answers)
    (while entries
      (setq entry (car entries))
      (setq entries (cdr entries))
      (setq entry (file-name-as-directory
		   (if (string-match "/?/?\\'" entry)
		       (substring entry 0 (match-beginning 0))
		     entry)))
      (or (not (file-name-absolute-p entry))
	  (member entry (append '("/" "\\") TeX-macro-global))
	  (setq answers (cons entry answers))))
    answers))

(defcustom TeX-macro-private (append (TeX-parse-path "TEXINPUTS")
				     (TeX-parse-path "BIBINPUTS"))
  "Directories where you store your personal TeX macros.
Each must end with a directory separator."
  :group 'TeX-file
  :type '(repeat (file :format "%v")))

(defcustom TeX-auto-private (mapcar (lambda (entry)
				      (concat entry TeX-auto-local))
				    TeX-macro-private)
  "List of directories containing automatically generated information.
Must end with a slash.

These correspond to the personal TeX macros."
  :group 'TeX-file
  :type '(repeat (file :format "%v")))

(if (stringp TeX-auto-private)		;Backward compatibility
    (setq TeX-auto-private (list TeX-auto-private)))

(defcustom TeX-style-private (mapcar (lambda (entry)
				       (concat entry
					       TeX-style-local))
				     TeX-macro-private)
  "List of directories containing hand generated information.
Must end with a slash.

These correspond to the personal TeX macros."
  :group 'TeX-file
  :type '(repeat (file :format "%v")))

(if (stringp TeX-style-private)		;Backward compatibility
    (setq TeX-style-private (list TeX-style-private)))

(defcustom TeX-style-path
  (let ((path))
    (mapcar (lambda (file) (if file (setq path (cons file path))))
	    (append (list TeX-auto-global TeX-style-global)
		    TeX-auto-private TeX-style-private
		    (list TeX-auto-local TeX-style-local)))
    path)
  "List of directories to search for AUCTeX style files."
  :group 'TeX-file
  :type '(repeat (file :format "%v")))

(defcustom TeX-check-path
  (append (list "./") TeX-macro-private TeX-macro-global)
  "Directory path to search for dependencies.

If nil, just check the current file.
Used when checking if any files have changed."
  :group 'TeX-file
  :type '(repeat (file :format "%v")))

;;; Style Files

(defvar TeX-style-hook-list nil
  "List of TeX style hooks currently loaded.

Each entry is a list where the first element is the name of the style,
and the remaining elements are hooks to be run when that style is
active.")

(defcustom TeX-byte-compile nil
  "*Not nil means try to byte compile auto files before loading."
  :group 'TeX-parse
  :type 'boolean)

(defun TeX-load-style (style)
  "Search for and load each definition for STYLE in `TeX-style-path'."
  (cond ((assoc style TeX-style-hook-list)) ; We already found it
	((string-match "\\`\\(.+[/\\]\\)\\([^/\\]*\\)\\'" style) ;Complex path
	 (let* ((dir (substring style (match-beginning 1) (match-end 1)))
		(style (substring style (match-beginning 2) (match-end 2)))
		(master-dir (if (stringp TeX-master)
				(file-name-directory
				 (file-relative-name TeX-master))
			      "./"))
		(TeX-style-path (append (list (concat dir TeX-auto-local)
					      (concat master-dir
						      TeX-auto-local)
					      (concat dir TeX-style-local)
					      (concat master-dir
						      TeX-style-local))
					TeX-style-path)))
	   (TeX-load-style style)))
	(t				;Relative path
	 ;; Insert empty list to mark the fact that we have searched.
	 (setq TeX-style-hook-list (cons (list style) TeX-style-hook-list))
	 ;; Now check each element of the path
	 (mapcar (lambda (name)
		   (TeX-load-style-file (concat
					 (file-name-as-directory name)
					 style)))
		 TeX-style-path))))

(defun TeX-load-style-file (file)
  "Load FILE checking for a Lisp extensions."
  (let ((el (concat file ".el"))
	(elc (concat file ".elc")))
    (cond ((file-newer-than-file-p el elc)
	   (if (file-readable-p el)
	       (if (and TeX-byte-compile
			(file-writable-p elc)
			(save-excursion
			  ;; `byte-compile-file' switches buffer in Emacs 20.3.
			  (byte-compile-file el))
			(file-readable-p elc))
		   (load-file elc)
		 (load-file el))))
	  ((file-readable-p elc)
	   (load-file elc))
	  ((file-readable-p el)
	   (load-file el)))))

(defun TeX-add-style-hook (style hook)
  "Give STYLE yet another HOOK to run."
  (let ((entry (assoc style TeX-style-hook-list)))
    (cond ((null entry)
	   ;; New style, add entry.
	   (setq TeX-style-hook-list (cons (list style hook)
					   TeX-style-hook-list)))
	  ((member hook entry)
	   ;; Old style, hook already there, do nothing.
	   nil)
	  (t
	   ;; Old style, new hook.
	   (setcdr entry (cons hook (cdr entry)))))))

(defun TeX-unload-style (style)
  "Forget that we once loaded STYLE."
  (cond ((null (assoc style TeX-style-hook-list)))
	((equal (car (car TeX-style-hook-list)) style)
	 (setq TeX-style-hook-list (cdr TeX-style-hook-list)))
	(t
	 (let ((entry TeX-style-hook-list))
	   (while (not (equal (car (car (cdr entry))) style))
	     (setq entry (cdr entry)))
	   (setcdr entry (cdr (cdr entry)))))))

(defcustom TeX-virgin-style (if (and TeX-auto-global
				     (file-directory-p TeX-auto-global))
				"virtex"
			      "NoVirtexSymbols")
  "Style all documents use."
  :group 'TeX-parse
  :type 'string)

(defvar TeX-active-styles nil
  "List of styles currently active in the document.")

 (make-variable-buffer-local 'TeX-active-styles)

(defun TeX-run-style-hooks (&rest styles)
  "Run the TeX style hooks STYLES."
  (mapcar (lambda (style)
	    (if (TeX-member style TeX-active-styles 'string-equal)
		()			;Avoid recursion.
	      (setq TeX-active-styles
		    (cons style TeX-active-styles))
	      (TeX-load-style style)
	      (if (string-match "\\`\\(.+[/\\]\\)\\([^/\\]*\\)\\'" style)
		  (setq style		; Complex path
			(substring style (match-beginning 2) (match-end 2))))
	      (mapcar 'funcall
		      (cdr-safe (assoc style TeX-style-hook-list)))))
	  styles))

(defcustom TeX-parse-self nil
  "Parse file after loading it if no style hook is found for it."
  :group 'TeX-parse
  :type 'boolean)

(defvar TeX-style-hook-applied-p nil
  "Nil, unless the style specific hooks have been applied.")
 (make-variable-buffer-local 'TeX-style-hook-applied-p)

(defun TeX-update-style (&optional force)
  "Run style specific hooks for the current document.

Only do this if it has not been done before, or if optional argument
FORCE is not nil."

  (if (or (and (boundp 'TeX-auto-update)
	       (eq TeX-auto-update 'BibTeX)) ; Not a real TeX buffer
	  (and (not force) TeX-style-hook-applied-p))
      ()
    (setq TeX-style-hook-applied-p t)
    (message "Applying style hooks...")
    (TeX-run-style-hooks (TeX-strip-extension nil nil t))
    ;; Run parent style hooks if it has a single parent that isn't itself.
    (if (or (not (memq TeX-master '(nil t)))
	    (and (buffer-file-name)
		 (string-match TeX-one-master
			       (file-name-nondirectory (buffer-file-name)))))
	(TeX-run-style-hooks (TeX-master-file)))

    (if (and TeX-parse-self
	     (null (cdr-safe (assoc (TeX-strip-extension nil nil t)
				    TeX-style-hook-list))))
	(TeX-auto-apply))

    (message "Applying style hooks... done")))

(defvar TeX-remove-style-hook nil
  "List of hooks to call when we remove the style specific information.")
 (make-variable-buffer-local 'TeX-remove-style-hook)

(defun TeX-remove-style ()
  "Remove all style specific information."
  (setq TeX-style-hook-applied-p nil)
  (run-hooks 'TeX-remove-style-hooks)
  (setq TeX-active-styles (list TeX-virgin-style)))

(defun TeX-style-list ()
  "Return a list of all styles (subfiles) used by the current document."
  (TeX-update-style)
  TeX-active-styles)

;;; Special Characters

(defvar TeX-esc "\\" "The TeX escape character.")
 (make-variable-buffer-local 'TeX-esc)

(defvar TeX-grop "{" "The TeX group opening character.")
 (make-variable-buffer-local 'TeX-grop)

(defvar TeX-grcl "}" "The TeX group closing character.")
 (make-variable-buffer-local 'TeX-grcl)

;;; Symbols

;; Must be before keymaps.

(defgroup TeX-macro nil
  "Support for TeX macros in AUCTeX."
  :prefix "TeX-"
  :group 'AUCTeX)

(defcustom TeX-complete-word 'ispell-complete-word
  "*Function to call for completing non-macros in `tex-mode'."
  :group 'TeX-macro)

(defvar TeX-complete-list nil
  "List of ways to complete the preceding text.

Each entry is a list with the following elements:

0. Regexp matching the preceding text.
1. A number indicating the subgroup in the regexp containing the text.
2. A function returning an alist of possible completions.
3. Text to append after a succesful completion.

Or alternatively:

0. Regexp matching the preceding text.
1. Function to do the actual completion.")

(defun TeX-complete-symbol ()
  "Perform completion on TeX/LaTeX symbol preceding point."
  (interactive "*")
  (let ((list TeX-complete-list)
	entry)
    (while list
      (setq entry (car list)
	    list (cdr list))
      (if (TeX-looking-at-backward (car entry) 250)
	  (setq list nil)))
    (if (numberp (nth 1 entry))
	(let* ((sub (nth 1 entry))
	       (close (nth 3 entry))
	       (begin (match-beginning sub))
	       (end (match-end sub))
	       (pattern (TeX-match-buffer 0))
	       (symbol (buffer-substring begin end))
	       (list (funcall (nth 2 entry)))
	       (completion (try-completion symbol list)))
	  (cond ((eq completion t)
		 (and close
		      (not (looking-at (regexp-quote close)))
		      (insert close)))
		((null completion)
		 (error "Can't find completion for \"%s\"" pattern))
		((not (string-equal symbol completion))
		 (delete-region begin end)
		 (insert completion)
		 (and close
		      (eq (try-completion completion list) t)
		      (not (looking-at (regexp-quote close)))
		      (insert close)))
		(t
		 (message "Making completion list...")
		 (let ((list (all-completions symbol list nil)))
		   (with-output-to-temp-buffer "*Completions*"
		     (display-completion-list list)))
		 (message "Making completion list...done"))))
      (funcall (nth 1 entry)))))

(defcustom TeX-default-macro "ref"
  "*The default macro when creating new ones with `TeX-insert-macro'."
  :group 'TeX-macro
  :type 'string)

(make-variable-buffer-local 'TeX-default-macro)

(defcustom TeX-insert-braces t
  "*If non-nil, append a empty pair of braces after inserting a macro."
  :group 'TeX-macro
  :type 'boolean)

(defcustom TeX-insert-macro-default-style 'show-optional-args
  "Specifies whether `TeX-insert-macro' will ask for all optional arguments.

If set to the symbol `show-optional-args', `TeX-insert-macro' asks for
optional arguments of TeX marcos.  If set to `mandatory-args-only',
`TeX-insert-macro' asks only for mandatory argument.

When `TeX-insert-macro' is called with \\[universal-argument], it's the other
way round.

Note that for some macros, there are special mechanisms, see e.g.
`LaTeX-includegraphics-options-alist'."
  :group 'TeX-macro
  :type '(choice (const mandatory-args-only)
		 (const show-optional-args)))

(defun TeX-insert-macro (symbol)
  "Insert TeX macro SYMBOL with completion.

AUCTeX knows of some macros and may query for extra arguments, depending on
the value of `TeX-insert-macro-default-style' and whether `TeX-insert-macro'
is called with \\[universal-argument]."
  ;; When called with a prefix (C-u), only ask for mandatory arguments,
  ;; i.e. all optional arguments are skipped.  See `TeX-parse-arguments' for
  ;; details.  Note that this behavior may be changed in favor of a more
  ;; flexible solution in the future, therefore we don't document it at the
  ;; moment.
  (interactive (list (completing-read (concat "Macro (default "
					      TeX-default-macro
					      "): "
					      TeX-esc)
				      (TeX-symbol-list))))
  (cond ((string-equal symbol "")
	 (setq symbol TeX-default-macro))
	((interactive-p)
	 (setq TeX-default-macro symbol)))
  (TeX-parse-macro symbol (cdr-safe (assoc symbol (TeX-symbol-list)))))

(defvar TeX-electric-macro-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map minibuffer-local-completion-map)
    (define-key map " " 'minibuffer-complete-and-exit)
    map))

(defun TeX-electric-macro ()
  "Insert TeX macro with completion.

AUCTeX knows of some macros, and may query for extra arguments.
Space will complete and exit."
  (interactive)
  (cond ((eq (preceding-char) ?\\)
	 (call-interactively 'self-insert-command))
	((eq (preceding-char) ?.)
	 (let ((TeX-default-macro " ")
	       (minibuffer-local-completion-map TeX-electric-macro-map))
	   (call-interactively 'TeX-insert-macro)))
	(t
	 (let ((minibuffer-local-completion-map TeX-electric-macro-map))
	   (call-interactively 'TeX-insert-macro)))))

(defun TeX-parse-macro (symbol args)
  "How to parse TeX macros which takes one or more arguments.

First argument SYMBOL is the name of the macro.

If called with no additional arguments, insert macro with point
inside braces.  Otherwise, each argument of this function should
match an argument to the TeX macro.  What is done depend on the
type of ARGS:

  string: Use the string as a prompt to prompt for the argument.

  number: Insert that many braces, leave point inside the first.

  nil: Insert empty braces.

  t: Insert empty braces, leave point between the braces.

  other symbols: Call the symbol as a function.  You can define
  your own hook, or use one of the predefined argument hooks.  If
  you add new hooks, you can assume that point is placed directly
  after the previous argument, or after the macro name if this is
  the first argument.  Please leave point located efter the
  argument you are inserting.  If you want point to be located
  somewhere else after all hooks have been processed, set the value
  of `exit-mark'.  It will point nowhere, until the argument hook
  set it.  By convention, these hook all start with `TeX-arg-'.

  list: If the car is a string, insert it as a prompt and the next
  element as initial input.  Otherwise, call the car of the list
  with the remaining elements as arguments.

  vector: Optional argument.  If it has more than one element,
  parse it as a list, otherwise parse the only element as above.
  Use square brackets instead of curly braces, and is not inserted
  on empty user input."

  (if (and (TeX-active-mark)
	   (> (point) (mark)))
      (exchange-point-and-mark))
  (insert TeX-esc symbol)
  (let ((exit-mark (make-marker))
	(position (point)))
    (TeX-parse-arguments args)
    (cond ((marker-position exit-mark)
	   (goto-char (marker-position exit-mark))
	   (set-marker exit-mark nil))
	  ((and TeX-insert-braces
		(equal position (point))
		(string-match "[a-zA-Z]+" symbol)
		(not (texmathp)))
	   (insert TeX-grop)
	   (if (TeX-active-mark)
	       (progn
		 (exchange-point-and-mark)
		 (insert TeX-grcl))
	     (insert TeX-grcl)
	     (backward-char))))))

(defun TeX-arg-string (optional &optional prompt initial-input)
  "Prompt for a string.

If OPTIONAL is not nil then the PROMPT will start with ``(Optional) ''.
INITIAL-INPUT is a string to insert before reading input."
  (TeX-argument-insert
   (if (and (not optional) (TeX-active-mark))
       (let ((TeX-argument (buffer-substring (point) (mark))))
	 (delete-region (point) (mark))
	 TeX-argument)
     (read-string (TeX-argument-prompt optional prompt "Text") initial-input))
   optional))

(defun TeX-parse-arguments (args)
  "Parse TeX macro arguments ARGS.

See `TeX-parse-macro' for details."
  (let ((last-optional-rejected nil)
	skip-opt)
    ;; Maybe get rid of all optional arguments.  See `TeX-insert-macro' for
    ;; more comments.  See `TeX-insert-macro-default-style'.
    (when (or (and (eq TeX-insert-macro-default-style 'show-optional)
		   (equal current-prefix-arg '(4)))
	      (and (eq TeX-insert-macro-default-style 'mandatory-only)
		   (null (equal current-prefix-arg '(4)))))
      (while (vectorp (car args))
	(setq args (cdr args))))

    (while args
      (if (vectorp (car args))
	  (if last-optional-rejected
	      ()
	    (let ((< LaTeX-optop)
		  (> LaTeX-optcl))
	      (TeX-parse-argument t (if (equal (length (car args)) 1)
					(aref (car args) 0)
				      (append (car args) nil)))))
	(let ((< TeX-grop)
	      (> TeX-grcl))
	  (setq last-optional-rejected nil)
	  (TeX-parse-argument nil (car args))))
      (setq args (cdr args)))))

(defun TeX-parse-argument (optional arg)
  "Depending on OPTIONAL, insert TeX macro argument ARG in curly braces.
If OPTIONAL is set, only insert if there is anything to insert, and
then use square brackets.

See `TeX-parse-macro' for details."

  (cond ((stringp arg)
	 (TeX-arg-string optional arg))
	((numberp arg)
	 (if (< arg 1)
	     ()
	   (TeX-parse-argument optional t)
	   (while (> arg 1)
	     (TeX-parse-argument optional nil)
	     (setq arg (- arg 1)))))
	((null arg)
	 (insert <)
	 (if (and (not optional) (TeX-active-mark))
	     (exchange-point-and-mark))
	 (insert >))
	((eq arg t)
	 (insert  < )
	 (if (and (not optional) (TeX-active-mark))
	     (exchange-point-and-mark)
	   (set-marker exit-mark (point)))
	 (insert >))
	((symbolp arg)
	 (funcall arg optional))
	((listp arg)
	 (let ((head (car arg))
	       (tail (cdr arg)))
	   (cond ((stringp head)
		  (apply 'TeX-arg-string optional arg))
		 ((symbolp head)
		  (apply head optional tail))
		 (t (error "Unknown list argument type %s"
			   (prin1-to-string head))))))
	(t (error "Unknown argument type %s" (prin1-to-string arg)))))

(defun TeX-argument-insert (name optional &optional prefix)
  "Insert NAME surrounded by curly braces.

If OPTIONAL, only insert it if not empty, and then use square brackets.
If PREFIX is given, insert it before NAME."
  (if (and optional (string-equal name ""))
      (setq last-optional-rejected t)
    (insert <)
    (if prefix
	(insert prefix))
    (if (and (string-equal name "")
	     (null (marker-position exit-mark)))
	(set-marker exit-mark (point))
      (insert name))
    (insert >)))

(defun TeX-argument-prompt (optional prompt default &optional complete)
  "Return a argument prompt.

If OPTIONAL is not nil then the prompt will start with ``(Optional) ''.

PROMPT will be used if not nil, otherwise use DEFAULT.

Unless optional argument COMPLETE is non-nil, ``: '' will be appended."
  (concat (if optional "(Optional) " "")
	  (if prompt prompt default)
	  (if complete "" ": ")))

(defun TeX-string-divide-number-unit (string)
  "Divide number and unit in STRING.
Return the number as car and unit as cdr."
  (if (string-match "[0-9]*\\.?[0-9]+" string)
      (list (substring string 0 (string-match "[^.0-9]" string))
	    (substring string (if (string-match "[^.0-9]" string)
				  (string-match "[^.0-9]" string)
				(length string))))
    (list "" string)))

(defcustom TeX-default-unit-for-image "cm"
  "Default unit when prompting for an image size."
  :group 'TeX-macro
  :type '(choice (const "cm")
		 (const "in")
		 (const "\\linewidth")
		 (string :tag "Other")))

(defun TeX-arg-maybe (symbol list form)
  "Evaluates FORM, if SYMBOL is an element of LIST."
  (when (memq symbol list)
    (eval form)))

;;; The Mode

(defvar TeX-format-list
  '(("JLATEX" japanese-latex-mode
     "\\\\\\(documentstyle\\|documentclass\\)[^%\n]*{\\(j[s-]?\\|t\\)\\(article\\|report\\|book\\|slides\\)")
    ("JTEX" japanese-plain-tex-mode
     "-- string likely in Japanese TeX --")
    ("AMSTEX" ams-tex-mode
     "\\\\document\\b")
    ("CONTEXT" context-mode
     "\\(\\\\\\(starttext\\|starttekst\\)\\|%.*?interface=\\)")
    ("LATEX" latex-mode
     "\\\\\\(begin\\|section\\|chapter\\|documentstyle\\|documentclass\\)\\b")
    ("TEX" plain-tex-mode "."))
  "*List of format packages to consider when choosing a TeX mode.

A list with a entry for each format package available at the site.

Each entry is a list with three elements.

1. The name of the format package.
2. The name of the major mode.
3. A regexp typically matched in the beginning of the file.

When entering `tex-mode', each regexp is tried in turn in order to find
when major mode to enter.")

(defcustom TeX-default-mode 'latex-mode
  "*Mode to enter for a new file when it can't be determined otherwise."
  :group 'TeX-misc
  :type '(radio (function-item latex-mode)
		(function-item plain-tex-mode)
		(function :tag "Other")))

(defcustom TeX-force-default-mode nil
  "*If set to nil, try to infer the mode of the file from its content."
  :group 'TeX-misc
  :type 'boolean)

;; Do not ;;;###autoload because of conflict with standard tex-mode.el.
(defun tex-mode ()
  "Major mode for editing files of input for TeX or LaTeX.
Tries to guess whether this file is for plain TeX or LaTeX.

The algorithm is as follows:

   1) if the file is empty or `TeX-force-default-mode' is not set to nil,
      `TeX-default-mode' is chosen
   2) If \\documentstyle or \\begin{, \\section{, \\part{ or \\chapter{ is
      found, `latex-mode' is selected.
   3) Otherwise, use `plain-tex-mode'"
  (interactive)

  (funcall (if (or (equal (buffer-size) 0)
		   TeX-force-default-mode)
	       TeX-default-mode
	     (save-excursion
	       (goto-char (point-min))
	       (let ((comment-start-skip ;Used by TeX-in-comment
		      (concat
		       "\\(\\(^\\|[^\\\n]\\)\\("
		       (regexp-quote TeX-esc)
		       (regexp-quote TeX-esc)
		       "\\)*\\)\\(%+ *\\)"))
		     (entry TeX-format-list)
		     answer)
		 (while (and entry (not answer))
		   (if (re-search-forward (nth 2 (car entry))
					  10000 t)
		       (if (not (TeX-in-comment))
			   (setq answer (nth 1 (car entry))))
		     (setq entry (cdr entry))))
		 (if answer
		     answer
		   TeX-default-mode))))))

;; Do not ;;;###autoload because of conflict with standard tex-mode.el.
(defun plain-tex-mode ()
  "Major mode for editing files of input for plain TeX.
See info under AUCTeX for documentation.

Special commands:
\\{plain-TeX-mode-map}

Entering `plain-tex-mode' calls the value of `text-mode-hook',
then the value of `TeX-mode-hook', and then the value
of plain-TeX-mode-hook."
  (interactive)
  (plain-TeX-common-initialization)
  (setq mode-name "TeX")
  (setq major-mode 'plain-tex-mode)
  (setq TeX-command-default "TeX")
  (setq TeX-sentinel-default-function 'TeX-TeX-sentinel)
  (run-hooks 'text-mode-hook 'TeX-mode-hook 'plain-TeX-mode-hook))

(autoload 'font-latex-setup "font-latex"
  "Font locking optimized for LaTeX.
Should work with all Emacsen." t)
(autoload 'tex-font-setup "tex-font"
  "Copy of Emacs 21 standard tex-mode font lock support.
This only works with Emacs 21." t)

(defcustom TeX-install-font-lock 'font-latex-setup
  "Function to call to install font lock support.
Choose `ignore' if you don't want AUCTeX to install support for font locking."
  :group 'TeX-misc
  :type '(radio (function-item font-latex-setup)
		(function-item tex-font-setup)
		(function-item ignore)
		(function :tag "Other")))

(defvar TeX-mode-p nil
  "This indicates a TeX mode being active.")
(make-variable-buffer-local 'TeX-mode-p)

(defun VirTeX-common-initialization ()
  "Perform basic initialization."
  (kill-all-local-variables)
  (setq TeX-mode-p t)
  (setq local-abbrev-table text-mode-abbrev-table)
  (setq indent-tabs-mode nil)

  ;; Ispell support
  (make-local-variable 'ispell-parser)
  (setq ispell-parser 'tex)
  (make-local-variable 'ispell-tex-p)
  (setq ispell-tex-p t)

  ;; Desktop support
  (if (boundp 'desktop-locals-to-save)
      (add-to-list 'desktop-locals-to-save 'TeX-master))

  ;; Redefine some standard variables
  (make-local-variable 'paragraph-start)
  (make-local-variable 'paragraph-separate)
  (make-local-variable 'comment-start)
  (setq comment-start "%")
  (make-local-variable 'comment-start-skip)
  (setq comment-start-skip
	(concat
	 "\\(\\(^\\|[^\\\n]\\)\\("
	 (regexp-quote TeX-esc)
	 (regexp-quote TeX-esc)
	 "\\)*\\)\\(" comment-start "+[ \t]*\\)"))
  ;; `comment-padding' is defined here as an integer for compatibility
  ;; reasons because older Emacsen could not cope with a string.
  (make-local-variable 'comment-padding)
  (setq comment-padding 1)
  ;; Removed as commenting in (La)TeX is done with one `%' not two
  ;; (make-local-variable 'comment-add)
  ;; (setq comment-add 1) ;default to `%%' in comment-region
  (make-local-variable 'comment-indent-function)
  (setq comment-indent-function 'TeX-comment-indent)
  (make-local-variable 'comment-multi-line)
  (setq comment-multi-line nil)
  (make-local-variable 'compile-command)
  (if (boundp 'compile-command)
      ()
    (setq compile-command "make"))
  (make-local-variable 'words-include-escapes)
  (setq words-include-escapes nil)

  ;; Make TAB stand out
  ;;  (make-local-variable 'buffer-display-table)
  ;;  (setq buffer-display-table (if standard-display-table
  ;;				 (copy-sequence standard-display-table)
  ;;			       (make-display-table)))
  ;;  (aset buffer-display-table ?\t (apply 'vector (append "<TAB>" nil)))

  ;; Symbol completion.
  (make-local-variable 'TeX-complete-list)
  (setq TeX-complete-list
	(list (list "\\\\\\([a-zA-Z]*\\)"
		    1 'TeX-symbol-list (if TeX-insert-braces "{}"))
	      (list "" TeX-complete-word)))

  (funcall TeX-install-font-lock)

  ;; We want this to be early in the list, so we do not add it before
  ;; we enter TeX mode  the first time.
  (if (boundp 'local-write-file-hooks)
      (add-hook 'local-write-file-hooks 'TeX-safe-auto-write)
    (add-hook 'write-file-hooks 'TeX-safe-auto-write))
  (make-local-variable 'TeX-auto-update)
  (setq TeX-auto-update t)

  ;; Let `TeX-master-file' be called after a new file was opened and
  ;; call `TeX-update-style' on any file opened.  (The addition to the
  ;; hook has to be made here because its local value will be deleted
  ;; by `kill-all-local-variables' if it is added e.g. in `tex-mode'.)
  (if (= emacs-major-version 20)
      (make-local-hook 'find-file-hooks))
  ;; `(TeX-master-file nil nil t)' has to be called *before*
  ;; `TeX-update-style' as the latter will call `TeX-master-file'
  ;; without the `ask' bit set.
  (add-hook 'find-file-hooks (lambda ()
			       ;; Test if we are looking at a new file.
			       (unless (file-exists-p (buffer-file-name))
				 (TeX-master-file nil nil t))
			       (TeX-update-style)) nil t))

(defun plain-TeX-common-initialization ()
  "Common initialization for plain TeX like modes."
  (VirTeX-common-initialization)
  (use-local-map plain-TeX-mode-map)
  (easy-menu-add plain-TeX-mode-command-menu plain-TeX-mode-map)
  (easy-menu-add plain-TeX-mode-menu plain-TeX-mode-map)
  (set-syntax-table TeX-mode-syntax-table)
  (setq paragraph-start
	(concat
	 "\\(^[ \t]*$"
	 "\\|" (regexp-quote TeX-esc) "par\\|"
	 "^[ \t]*"
	 (regexp-quote TeX-esc)
	 "\\("
	 "begin\\|end\\|part\\|chapter\\|"
	 "section\\|subsection\\|subsubsection\\|"
	 "paragraph\\|include\\|includeonly\\|"
	 "tableofcontents\\|appendix\\|label\\|caption\\|"
	 "\\[\\|\\]"			; display math delimitors
	 "\\)"
	 "\\|"
	 "^[ \t]*\\$\\$"		; display math delimitor
	 "\\)" ))
  (setq paragraph-separate
	(concat
	 "\\("
	 (regexp-quote TeX-esc)
	 "par\\|"
	 "^[ \t]*$\\|"
	 "^[ \t]*"
	 (regexp-quote TeX-esc)
	 "\\("
	 "begin\\|end\\|label\\|caption\\|part\\|chapter\\|"
	 "section\\|subsection\\|subsubsection\\|"
	 "paragraph\\|include\\|includeonly\\|"
	 "tableofcontents\\|appendix\\|" (regexp-quote TeX-esc)
	 "\\)"
	 "\\)"))
  (setq TeX-header-end (regexp-quote "%**end of header"))
  (setq TeX-trailer-start (regexp-quote (concat TeX-esc "bye")))
  (TeX-run-style-hooks "TEX"))

;;; Hilighting

(if (boundp 'hilit-patterns-alist)
    (let ((latex-patterns (cdr-safe (assq 'latex-mode hilit-patterns-alist)))
	  (plain-tex-patterns (cdr-safe (assq 'plain-tex-mode
					      hilit-patterns-alist))))
      (if (and latex-patterns plain-tex-patterns)
	  (setq hilit-patterns-alist
		(append (list (cons 'ams-tex-mode plain-tex-patterns))
			hilit-patterns-alist)))))

;;; Parsing

(defgroup TeX-parse nil
  "Parsing TeX files from AUCTeX."
  :group 'AUCTeX)

(defvar TeX-auto-parser '((styles TeX-auto-file TeX-run-style-hooks)))
;; Alist of parsed information.
;; Each entry is a list with the following elements:
;;
;; 0. Name of information type.
;; 1. Name of temporary variable used when parsing.
;; 2. Name of function to add information to add to #3.
;; 3. Name of variable holding buffer local information.
;; 4. Name of variable indicating that #3 has changed.


(defconst TeX-auto-parser-temporary 1)
(defconst TeX-auto-parser-add 2)
(defconst TeX-auto-parser-local 3)
(defconst TeX-auto-parser-change 4)

(defun TeX-auto-add-type (name prefix &optional plural)
  "Add information about NAME to the parser using PREFIX.

Optional third argument PLURAL is the plural form of TYPE.
By default just add an `s'.

This function create a set of variables and functions to maintain a
separate type of information in the parser."
  (let* ((names (or plural (concat name "s")))
	 (tmp (intern (concat prefix "-auto-" name)))
	 (add (intern (concat prefix "-add-" names)))
	 (local (intern (concat prefix "-" name "-list")))
	 (change (intern (concat prefix "-" name "-changed"))))
    (setq TeX-auto-parser
	  (cons (list name tmp add local change) TeX-auto-parser))
    (set local nil)
    (make-variable-buffer-local local)
    (set change nil)
    (make-variable-buffer-local change)
    (fset add `(lambda (&rest entries)
		 ,(concat "Add information about " (upcase name)
			  " to the current buffer.
Generated by `TeX-auto-add-type'.")
		 (TeX-auto-add-information ,name entries)))
    (fset local `(lambda nil
		   ,(concat "List of " names
			    " active in the current buffer.
Generated by `TeX-auto-add-type'.")
		   (TeX-auto-list-information ,name)))
    (add-hook 'TeX-remove-style-hook
	      `(lambda nil (setq ,(symbol-name local) nil)))))

(defun TeX-auto-add-information (name entries)
  "For NAME in `TeX-auto-parser' add ENTRIES."
  (let* ((entry (assoc name TeX-auto-parser))
	 (change (nth TeX-auto-parser-change entry))
	 (change-value (symbol-value change))
	 (local (nth TeX-auto-parser-local entry))
	 (local-value (symbol-value local)))
    (if change-value
	(set local (cons entries local-value))
      (set change t)
      (set local (list entries local-value)))))

(defun TeX-auto-list-information (name)
  "Return information in `TeX-auto-parser' about NAME."
  (TeX-update-style)
  (let* ((entry (assoc name TeX-auto-parser))
	 (change (nth TeX-auto-parser-change entry))
	 (change-value (symbol-value change))
	 (local (nth TeX-auto-parser-local entry)))
    (if (not change-value)
	()
      (set change nil)
      ;; Sort it
      (message "Sorting " name "...")
      (set local
	   (sort (mapcar 'TeX-listify (apply 'append (symbol-value local)))
		 'TeX-car-string-lessp))
      ;; Make it unique
      (message "Removing duplicates...")
      (let ((entry (symbol-value local)))
	(while (and entry (cdr entry))
	  (let ((this (car entry))
		(next (car (cdr entry))))
	    (if (not (string-equal (car this) (car next)))
		(setq entry (cdr entry))
	      ;; We have two equal symbols.  Use the one with
	      ;; most arguments.
	      (if (> (length next) (length this))
		  (setcdr this (cdr next)))
	      (setcdr entry (cdr (cdr entry)))))))
      (message "Removing duplicates... done"))
    (symbol-value local)))

(TeX-auto-add-type "symbol" "TeX")

(defvar TeX-auto-apply-hook nil
  "Hook run when a buffer is parsed and the information is applied.")

(defun TeX-auto-apply ()
  "Parse and apply TeX information in the current buffer."
  (TeX-auto-parse)
  (run-hooks 'TeX-auto-apply-hook)
  (mapcar 'TeX-auto-apply-entry TeX-auto-parser))

(defun TeX-auto-apply-entry (entry)
  "Apply the information in ENTRY in `TeX-auto-parser'."
  (let ((value (symbol-value (nth TeX-auto-parser-temporary entry)))
	(add (nth TeX-auto-parser-add entry)))
    (if value (apply add value))))

(defun TeX-safe-auto-write ()
  "Call `TeX-auto-write' safely."
  (condition-case name
      (and (boundp 'TeX-auto-update)
	   TeX-auto-update
	   (TeX-auto-write))
    (error nil))
  ;; Continue with the other write file hooks.
  nil)

(defcustom TeX-auto-save nil
  "*Automatically save style information when saving the buffer."
  :group 'TeX-parse
  :type 'boolean)

(defcustom TeX-auto-untabify nil
  "*Automatically untabify when saving the buffer."
  :group 'TeX-parse
  :type 'boolean)

(defun TeX-auto-write ()
  "Save all relevant TeX information from the current buffer."
  (if TeX-auto-untabify
      (untabify (point-min) (point-max)))
  (if (and TeX-auto-save TeX-auto-local)
      (let* ((file (expand-file-name
		    (concat
		     (file-name-as-directory TeX-auto-local)
		     (TeX-strip-extension nil TeX-all-extensions t)
		     ".el")
		    (TeX-master-directory)))
	     (dir (file-name-directory file)))
	;; Create auto directory if possible.
	(if (not (file-exists-p dir))
	    (condition-case name
		(make-directory dir)
	      (error nil)))
	(if (file-writable-p file)
	    (save-excursion
	      (TeX-update-style)
	      (TeX-auto-store file))
	  (message "Can't write style information.")))))

(defcustom TeX-macro-default (car-safe TeX-macro-private)
  "*Default directory to search for TeX macros."
  :group 'TeX-file
  :type 'directory)

(defcustom TeX-auto-default (car-safe TeX-auto-private)
  "*Default directory to place automatically generated TeX information."
  :group 'TeX-file
  :type 'directory)

;;;###autoload
(defun TeX-auto-generate (tex auto)
  "Generate style file for TEX and store it in AUTO.
If TEX is a directory, generate style files for all files in the directory."
  (interactive (list (setq TeX-macro-default
			   (expand-file-name (read-file-name
					      "TeX file or directory: "
					      TeX-macro-default
					      TeX-macro-default 'confirm)))
		     (setq TeX-auto-default
			   (expand-file-name (read-file-name
					      "AUTO lisp directory: "
					      TeX-auto-default
					      TeX-auto-default 'confirm)))))
  (cond ((not (file-readable-p tex)))
	((string-match TeX-ignore-file tex))
	((file-directory-p tex)
	 (let ((files (directory-files (expand-file-name tex)))
	       (default-directory (file-name-as-directory
				   (expand-file-name tex)))
	       (TeX-file-recurse (cond ((symbolp TeX-file-recurse)
					TeX-file-recurse)
				       ((zerop TeX-file-recurse)
					nil)
				       ((1- TeX-file-recurse)))))
	   (mapcar (lambda (file)
		     (if (or TeX-file-recurse
			     (not (file-directory-p file)))
			 (TeX-auto-generate file auto)))
		   files)))
	((not (file-newer-than-file-p
	       tex
	       (concat (file-name-as-directory auto)
		       (TeX-strip-extension tex TeX-all-extensions t)
		       ".el"))))
	((TeX-match-extension tex (append TeX-file-extensions
					  BibTeX-file-extensions))
	 (save-excursion
	   (set-buffer (let (enable-local-eval)
			 (find-file-noselect tex)))
	   (message "Parsing %s..." tex)
	   (TeX-auto-store (concat (file-name-as-directory auto)
				   (TeX-strip-extension tex
							TeX-all-extensions
							t)
				   ".el"))
	   (kill-buffer (current-buffer))
	   (message "Parsing %s... done" tex)))))

;;;###autoload
(defun TeX-auto-generate-global ()
  "Create global auto directory for global TeX macro definitions."
  (interactive)
  (unless (file-directory-p TeX-auto-global)
    (make-directory TeX-auto-global))
  (mapcar (lambda (macro) (TeX-auto-generate macro TeX-auto-global))
	  TeX-macro-global)
  (byte-recompile-directory TeX-auto-global 0))

(defun TeX-auto-store (file)
  "Extract information for AUCTeX from current buffer and store it in FILE."
  (TeX-auto-parse)

  (if (member nil (mapcar 'TeX-auto-entry-clear-p TeX-auto-parser))
      (let ((style (TeX-strip-extension nil TeX-all-extensions t)))
	(TeX-unload-style style)
	(save-excursion
	  (set-buffer (generate-new-buffer file))
	  (erase-buffer)
	  (insert "(TeX-add-style-hook \"" style "\"\n"
		  " (lambda ()")
	  (mapcar 'TeX-auto-insert TeX-auto-parser)
	  (insert "))\n\n")
	  (write-region (point-min) (point-max) file nil 'silent)
	  (kill-buffer (current-buffer))))
    (if (file-exists-p (concat file "c"))
	(delete-file (concat file "c")))
    (if (file-exists-p file)
	(delete-file file))))

(defun TeX-auto-entry-clear-p (entry)
  "Check if the temporary for `TeX-auto-parser' entry ENTRY is clear."
  ;; FIXME: This doc-string isn't clear to me.  -- rs
  (null (symbol-value (nth TeX-auto-parser-temporary entry))))

(defun TeX-auto-insert (entry)
  "Insert code to initialize ENTRY from `TeX-auto-parser'."
  (let ((name (symbol-name (nth TeX-auto-parser-add entry)))
	(list (symbol-value (nth TeX-auto-parser-temporary entry))))
    (if (null list)
	()
      (insert "\n    (" name)
      (while list
	(insert "\n     ")
	(if (stringp (car list))
	    (insert (prin1-to-string (car list)))
	  (insert "'" (prin1-to-string (car list))))
	(setq list (cdr list)))
      (insert ")"))))

(defvar TeX-auto-ignore
  '("csname" "filedate" "fileversion" "docdate" "next" "labelitemi"
    "labelitemii" "labelitemiii" "labelitemiv" "labelitemv"
    "labelenumi" "labelenumii" "labelenumiii" "labelenumiv"
    "labelenumv" "theenumi" "theenumii" "theenumiii" "theenumiv"
    "theenumv" "document" "par" "do" "expandafter")
  "List of symbols to ignore when scanning a TeX style file.")

(defun TeX-auto-add-regexp (regexp)
  "Add REGEXP to `TeX-auto-regexp-list' if not already a member."
  (if (symbolp TeX-auto-regexp-list)
      (setq TeX-auto-regexp-list (symbol-value TeX-auto-regexp-list)))
  (or (memq regexp TeX-auto-regexp-list)
      (setq TeX-auto-regexp-list (cons regexp TeX-auto-regexp-list))))

(defvar TeX-auto-empty-regexp-list
  '(("<IMPOSSIBLE>\\(\\'\\`\\)" 1 ignore))
  "List of regular expressions guaranteed to match nothing.")

(defvar plain-TeX-auto-regexp-list
  '(("\\\\def\\\\\\([a-zA-Z]+\\)[^a-zA-Z@]" 1 TeX-auto-symbol-check)
    ("\\\\let\\\\\\([a-zA-Z]+\\)[^a-zA-Z@]" 1 TeX-auto-symbol-check)
    ("\\\\font\\\\\\([a-zA-Z]+\\)[^a-zA-Z@]" 1 TeX-auto-symbol)
    ("\\\\chardef\\\\\\([a-zA-Z]+\\)[^a-zA-Z@]" 1 TeX-auto-symbol)
    ("\\\\new\\(count\\|dimen\\|muskip\\|skip\\)\\\\\\([a-z]+\\)[^a-zA-Z@]"
     2 TeX-auto-symbol)
    ("\\\\newfont{?\\\\\\([a-zA-Z]+\\)}?" 1 TeX-auto-symbol)
    ("\\\\typein\\[\\\\\\([a-zA-Z]+\\)\\]" 1 TeX-auto-symbol)
    ("\\\\input +\\(\\.*[^#%\\\\\\.\n\r]+\\)\\(\\.[^#%\\\\\\.\n\r]+\\)?"
     1 TeX-auto-file)
    ("\\\\mathchardef\\\\\\([a-zA-Z]+\\)[^a-zA-Z@]" 1 TeX-auto-symbol))
  "List of regular expression matching common LaTeX macro definitions.")

(defvar TeX-auto-full-regexp-list plain-TeX-auto-regexp-list
  "Full list of regular expression matching TeX macro definitions.")

(defvar TeX-auto-prepare-hook nil
  "List of hooks to be called before parsing a TeX file.")

(defvar TeX-auto-cleanup-hook nil
  "List of hooks to be called after parsing a TeX file.")

(defcustom TeX-auto-parse-length 999999
  "*Maximal length of TeX file that will be parsed."
  :group 'TeX-parse
  :type 'integer)
  (make-variable-buffer-local 'TeX-auto-parse-length)

(defcustom TeX-auto-x-parse-length 0
  "*Maximum length of TeX file that will be parse additionally.
Use `TeX-auto-x-regexp-list' for parsing the region between
`TeX-auto-parse-length' and this value."
  :group 'TeX-parse
  :type 'integer)
  (make-variable-buffer-local 'TeX-auto-x-parse-length)

(defcustom TeX-auto-x-regexp-list 'LaTeX-auto-label-regexp-list
  "*List of regular expresions used for additional parsing.
See `TeX-auto-x-parse-length'."
  :type '(radio (variable-item TeX-auto-empty-regexp-list)
		(variable-item TeX-auto-full-regexp-list)
		(variable-item plain-TeX-auto-regexp-list)
		(variable-item LaTeX-auto-minimal-regexp-list)
		(variable-item LaTeX-auto-label-regexp-list)
		(variable-item LaTeX-auto-regexp-list)
		(symbol :tag "Other")
		(repeat :tag "Specify"
			(group (regexp :tag "Match")
			       (sexp :tag "Groups")
			       symbol)))
  :group 'TeX-parse)
  (make-variable-buffer-local 'TeX-auto-x-regexp-list)

(defun TeX-auto-parse-region (regexp-list beg end)
  "Parse TeX information according to REGEXP-LIST between BEG and END."
  (if (symbolp regexp-list)
      (setq regexp-list (and (boundp regexp-list) (symbol-value regexp-list))))
   (if regexp-list
       ;; Extract the information.
       (let ((regexp (concat "\\("
			     (mapconcat 'car regexp-list "\\)\\|\\(")
			     "\\)")))
	 (goto-char (if end (min end (point-max)) (point-max)))
	 (while (re-search-backward regexp beg t)
	   (if (TeX-in-comment)
	       ()
	     (let* ((entry (TeX-member nil regexp-list
				       (lambda (a b)
					 (looking-at (nth 0 b)))))
		    (symbol (nth 2 entry))
		    (match (nth 1 entry)))
	       (if (fboundp symbol)
		   (funcall symbol match)
		 (set symbol (cons (if (listp match)
				       (mapcar 'TeX-match-buffer match)
				     (TeX-match-buffer match))
				   (symbol-value symbol))))))))))

(defun TeX-auto-parse ()
  "Parse TeX information in current buffer.

Call the functions in `TeX-auto-prepare-hook' before parsing, and the
functions in `TeX-auto-cleanup-hook' after parsing."

  (let ((case-fold-search nil))

    (mapcar 'TeX-auto-clear-entry TeX-auto-parser)
    (run-hooks 'TeX-auto-prepare-hook)

    (save-excursion
      (and (> TeX-auto-x-parse-length TeX-auto-parse-length)
	   (> (point-max) TeX-auto-parse-length)
	   (TeX-auto-parse-region TeX-auto-x-regexp-list
				  TeX-auto-parse-length
				  TeX-auto-x-parse-length))
      (TeX-auto-parse-region TeX-auto-regexp-list
			     nil TeX-auto-parse-length))

    ;; Cleanup ignored symbols.

    ;; NOTE: This is O(N M) where it could be O(N log N + M log M) if we
    ;; sorted the lists first.
    (while (member (car TeX-auto-symbol) TeX-auto-ignore)
      (setq TeX-auto-symbol (cdr TeX-auto-symbol)))
    (let ((list TeX-auto-symbol))
      (while (and list (cdr list))
	(if (member (car (cdr list)) TeX-auto-ignore)
	    (setcdr list (cdr (cdr list)))
	  (setq list (cdr list)))))

    (run-hooks 'TeX-auto-cleanup-hook)))

(defun TeX-auto-clear-entry (entry)
  "Set the temporary variable in ENTRY to nil."
  (set (nth TeX-auto-parser-temporary entry) nil))

(defvar LaTeX-auto-end-symbol nil)

(defun TeX-auto-symbol-check (match)
  "Add MATCH to TeX-auto-symbols.
Check for potential LaTeX environments."
  (let ((symbol (if (listp match)
		    (mapcar 'TeX-match-buffer match)
		  (TeX-match-buffer match))))
    (if (and (stringp symbol)
	     (string-match "^end\\(.+\\)$" symbol))
	(setq LaTeX-auto-end-symbol
	      (cons (substring symbol (match-beginning 1) (match-end 1))
		    LaTeX-auto-end-symbol))
      (setq TeX-auto-symbol (cons symbol TeX-auto-symbol)))))

;;; Utilities
;;
;; Some of these functions has little to do with TeX, but nonetheless we
;; should use the "TeX-" prefix to avoid name clashes.

(defcustom TeX-auto-regexp-list 'TeX-auto-full-regexp-list
  "*List of regular expressions used for parsing the current file."
  :type '(radio (variable-item TeX-auto-empty-regexp-list)
		(variable-item TeX-auto-full-regexp-list)
		(variable-item plain-TeX-auto-regexp-list)
		(variable-item LaTeX-auto-minimal-regexp-list)
		(variable-item LaTeX-auto-label-regexp-list)
		(variable-item LaTeX-auto-regexp-list)
		(symbol :tag "Other")
		(repeat :tag "Specify"
			(group (regexp :tag "Match")
			       (sexp :tag "Groups")
			       symbol)))
  :group 'TeX-parse)
  (make-variable-buffer-local 'TeX-auto-regexp-list)

(defgroup TeX-file-extension nil
  "File extensions recognized by AUCTeX."
  :group 'TeX-file)

(defcustom TeX-file-extensions '("tex" "sty" "cls" "ltx" "texi" "texinfo" "dtx")
  "*File extensions used by manually generated TeX files."
  :group 'TeX-file-extension
  :type '(repeat (string :format "%v")))

(defcustom TeX-all-extensions '("[^.\n]+")
  "All possible file extensions."
  :group 'TeX-file-extension
  :type '(repeat (regexp :format "%v")))

(defcustom TeX-default-extension "tex"
  "*Default extension for TeX files."
  :group 'TeX-file-extension
  :type 'string)

  (make-variable-buffer-local 'TeX-default-extension)

(defcustom docTeX-default-extension "dtx"
  "*Default extension for docTeX files."
  :group 'TeX-file-extension
  :type 'string)

(defvar TeX-output-extension "dvi"
  "Extension of TeX output file.
This is either a string or a list with
a string as element.  Its value is obtained from `TeX-command-output-list'.
Access to the value should be through the function `TeX-output-extension'.")

  (make-variable-buffer-local 'TeX-output-extension)

(defvar TeX-view-extension "dvi"
  "Extension of TeX output file for viewing.
If nil, the variable `TeX-output-extension' is used.  This variable could be
changed by running File commands, like dvips.  Access to the value should be
through the function `TeX-view-extension'.")

  (make-variable-buffer-local 'TeX-view-extension)

(defcustom BibTeX-file-extensions '("bib")
  "Valid file extensions for BibTeX files."
  :group 'TeX-file-extension
  :type '(repeat (string :format "%v")))

(defcustom BibTeX-style-extensions '("bst")
  "Valid file extensions for BibTeX styles."
  :group 'TeX-file-extension
  :type '(repeat (string :format "%v")))

(defcustom TeX-ignore-file "\\(^\\|[/\\]\\)\\(\\.\\|\\.\\.\\|RCS\\|SCCS\\|CVS\\|babel\\..*\\)$"
  "Regular expression matching file names to ignore.

These files or directories will not be considered when searching for
TeX files in a directory."
  :group 'TeX-parse
  :type 'regexp)

(defcustom TeX-file-recurse t
  "*Whether to search TeX directories recursively.
nil means do not recurse, a positive integer means go that far deep in the
directory hierarchy, t means recurse indefinitely."
  :group 'TeX-parse
  :type '(choice (const :tag "On" t)
		 (const :tag "Off" nil)
		 (integer :tag "Depth" :value 1)))

(defun TeX-match-extension (file &optional extensions)
  "Return non-nil if FILE has one of EXTENSIONS.

If EXTENSIONS is not specified or nil, the value of
`TeX-file-extensions' is used instead."

  (if (null extensions)
      (setq extensions TeX-file-extensions))

  (let ((regexp (concat "\\.\\("
			(mapconcat 'identity extensions "\\|")
			"\\)$"))
	(case-fold-search t))
    (string-match regexp file)))

(defun TeX-strip-extension (&optional string extensions nodir nostrip)
  "Return STRING without any trailing extension in EXTENSIONS.
If NODIR is t, also remove directory part of STRING.
If NODIR is `path', remove directory part of STRING if it is equal to
the current directory, `TeX-macro-private' or `TeX-macro-global'.
If NOSTRIP is set, do not remove extension after all.
STRING defaults to the name of the current buffer.
EXTENSIONS defaults to `TeX-file-extensions'."

  (if (null string)
      (setq string (or (buffer-file-name) "<none>")))

  (if (null extensions)
      (setq extensions TeX-file-extensions))

  (let* ((strip (if (and (not nostrip)
			 (TeX-match-extension string extensions))
		    (substring string 0 (match-beginning 0))
		  string))
	 (dir (expand-file-name (or (file-name-directory strip) "./"))))
    (if (or (eq nodir t)
	    (string-equal dir (expand-file-name "./"))
	    (member dir TeX-macro-global)
	    (member dir TeX-macro-private))
	(file-name-nondirectory strip)
      strip)))

(defcustom TeX-kpathsea-path-delimiter t
  "Path delimiter for kpathsea output.
t means autodetect, nil means kpathsea is disabled."
  :group 'TeX-file
  :type '(choice (const ":")
		 (const ";")
		 (const :tag "Autodetect" t)
		 (const :tag "Off" nil)))

(defcustom TeX-kpathsea-format-alist
  '(("tex" "${TEXINPUTS.latex}" TeX-file-extensions)
    ("bib" "$BIBINPUTS" BibTeX-file-extensions)
    ("bst" "$BSTINPUTS" BibTeX-style-extensions))
  "Formats to search for expansion using kpathsea.
The key of the alist represents the name of the format.  The
first element of the cdr of the alist is string to expand by the
respective kpathsea program and the second element is a list of
file extensions to match."
  :group 'TeX-file
  :type '(alist :key-type string :value-type (group string sexp)))

;; FIXME: Despite the first parameter named `extensions',
;; `TeX-search-files-kpathsea' basically treats this as a format
;; specifier.  Only the first element in the respective list will be
;; used to determine the search paths and file extensions with the
;; help of `TeX-kpathsea-format-alist'.  Out of these differences
;; arises a need to unify the behavior of `TeX-search-files' and
;; `TeX-search-files-kpathsea' and their treatment of parameters.
;; Additionally `TeX-search-files-kpathses' should be made more
;; general to work with other platforms and TeX systems as well.
(defun TeX-search-files-kpathsea (extensions nodir strip)
  "The kpathsea-enabled version of `TeX-search-files'.
Except for DIRECTORIES (a kpathsea string), the arguments for
EXTENSIONS, NODIR and STRIP are explained there."
  (and TeX-kpathsea-path-delimiter
       (catch 'no-kpathsea
	 (let* ((format-spec (assoc (car extensions)
				    TeX-kpathsea-format-alist))
		(dirs (with-output-to-string
			(unless (zerop
				 (call-process
				  "kpsewhich" nil (list standard-output nil)
				  nil
				  (concat
				   "-expand-path="
				   (nth 1 format-spec))))
			 (if (eq TeX-kpathsea-path-delimiter t)
			     (throw 'no-kpathsea
				    (setq kpathsea-path-delimiter nil))
			   (error "kpsewhich error")))))
	       result)
	   (when (eq TeX-kpathsea-path-delimiter t)
	     (setq TeX-kpathsea-path-delimiter
		   (cond ((string-match ";" dirs)
			  ";")
			 ((string-match ":" dirs)
			  ":"))))
	   (unless TeX-kpathsea-path-delimiter
	     (throw 'no-kpathsea nil))
	   (setq dirs (split-string dirs (concat "[\n\r"
						 TeX-kpathsea-path-delimiter
						 "]+")))
	   (setq extensions (concat "\\."
				    (regexp-opt (eval (nth 2 format-spec)) t)
				    "\\'"))
	   (setq result
		 (apply #'append
			(mapcar
			 (lambda(x) (directory-files x
						     (not nodir)
						     extensions))
			 dirs)))
	   (if strip
	       (mapcar (lambda(x)
			 (if (string-match extensions x)
			     (substring x 0 (match-beginning 0))
			   x))
		       result)
	     result)))))

(defun TeX-search-files (&optional directories extensions nodir strip)
  "Return a list of all reachable files in DIRECTORIES ending with EXTENSIONS.
If optional argument NODIR is set, remove directory part.
If optional argument STRIP is set, remove file extension.
If optional argument DIRECTORIES is set, search in those directories.
Otherwise, search in all TeX macro directories.
If optional argument EXTENSIONS is not set, use `TeX-file-extensions'"

  (if (null extensions)
      (setq extensions TeX-file-extensions))

  (or (TeX-search-files-kpathsea extensions nodir strip)
      (if (null directories)
	  (setq directories
		(cons "./" (append TeX-macro-private TeX-macro-global))))

      (let (match
	    (TeX-file-recurse (cond ((symbolp TeX-file-recurse)
				     TeX-file-recurse)
				    ((zerop TeX-file-recurse)
				     nil)
				    ((1- TeX-file-recurse)))))
	(while directories
	  (let* ((directory (car directories))
		 (content (and directory
			       (file-readable-p directory)
			       (file-directory-p directory)
			       (directory-files directory))))

	    (setq directories (cdr directories))

	    (while content
	      (let ((file (concat directory (car content))))

		(setq content (cdr content))
		(cond ((string-match TeX-ignore-file file))
		      ((not (file-readable-p file)))
		      ((file-directory-p file)
		       (if TeX-file-recurse
			   (setq match
				 (append match
					 (TeX-search-files
					  (list (file-name-as-directory file))
					  extensions
					  nodir strip)))))
		      ((TeX-match-extension file extensions)
		       (setq match (cons (TeX-strip-extension file
							      extensions
							      nodir
							      (not strip))
					 match))))))))

	match)))

(defun TeX-car-string-lessp (s1 s2)
  "Compare the cars of S1 and S2 in lexicographic order.
Return t if first is less than second in lexicographic order."
  (string-lessp (car s1) (car s2)))

(defun TeX-listify (elt)
  "Return a newly created list with element ELT.
If ELT already is a list, return ELT."
  (if (listp elt) elt (list elt)))

(defun TeX-member (elt list how)
  "Return the member ELT in LIST.  Comparison done with HOW.
Return nil if ELT is not a member of LIST."
  (while (and list (not (funcall how elt (car list))))
    (setq list (cdr list)))
  (car-safe list))

(defun TeX-assoc (key list)
  "Return non-nil if KEY is `equal' to the car of an element of LIST.
Like assoc, except case insensitive."
  (let ((case-fold-search t))
    (TeX-member key list
		(lambda (a b)
		  (string-match (concat "^" (regexp-quote a) "$")
				(car b))))))

(defun TeX-match-buffer (n)
  "Return the substring corresponding to the N'th match.
See `match-data' for details."
  (if (match-beginning n)
      (let ((str (buffer-substring (match-beginning n) (match-end n))))
	(set-text-properties 0 (length str) nil str)
	(copy-sequence str))
    ""))

(defun TeX-function-p (arg)
  "Return non-nil if ARG is callable as a function."
  (or (and (fboundp 'byte-code-function-p)
	   (byte-code-function-p arg))
      (and (listp arg)
	   (eq (car arg) 'lambda))
      (and (symbolp arg)
	   (fboundp arg))))

(defun TeX-looking-at-backward (regexp &optional limit)
  "Return non-nil if the text before point matches REGEXP.
Optional second argument LIMIT gives a max number of characters
to look backward for."
  (let ((pos (point)))
    (save-excursion
      (and (re-search-backward regexp
			       (if limit (max (point-min) (- (point) limit)))
			       t)
	   (eq (match-end 0) pos)))))

(defun TeX-current-line ()
  "The current line number."
  (format "%d" (1+ (TeX-current-offset))))

(defun TeX-current-file-name-master-relative ()
  "Return current filename, relative to master directory."
  (file-relative-name
   (buffer-file-name)
   (TeX-master-directory)))

;; was in latex.el, needed in context.el --pg
(defun TeX-near-bobp ()
  "Return t iff there's nothing but whitespace between (bob) and (point)."
  (save-excursion
    (skip-chars-backward " \t\n")
    (bobp)))

(defun TeX-arg-literal (optional &rest args)
  "Insert its arguments ARGS into the buffer.
Used for specifying extra syntax for a macro."
  ;; FIXME: What is the purpose of OPTIONAL here?  -- rs
  (apply 'insert args))

;;; Syntax Table

(defvar TeX-mode-syntax-table (make-syntax-table)
  "Syntax table used while in TeX mode.")

 (make-variable-buffer-local 'TeX-mode-syntax-table)

(progn ; Define TeX-mode-syntax-table.
  (modify-syntax-entry (string-to-char TeX-esc)
			   "\\" TeX-mode-syntax-table)
  (modify-syntax-entry ?\f ">"  TeX-mode-syntax-table)
  (modify-syntax-entry ?\n ">"  TeX-mode-syntax-table)
  (modify-syntax-entry (string-to-char TeX-grop)
			   (concat "(" TeX-grcl)
				TeX-mode-syntax-table)
  (modify-syntax-entry (string-to-char TeX-grcl)
			   (concat ")" TeX-grop)
				TeX-mode-syntax-table)
  (modify-syntax-entry ?%  "<"  TeX-mode-syntax-table)
  (modify-syntax-entry ?\" "."  TeX-mode-syntax-table)
  (modify-syntax-entry ?&  "."  TeX-mode-syntax-table)
  (modify-syntax-entry ?_  "."  TeX-mode-syntax-table)
  (modify-syntax-entry ?@  "_"  TeX-mode-syntax-table)
  (modify-syntax-entry ?~  " "  TeX-mode-syntax-table)
  (modify-syntax-entry ?$  "$"  TeX-mode-syntax-table)
  (modify-syntax-entry ?'  "w"  TeX-mode-syntax-table))

;;; Menu Support

(defvar TeX-command-current 'TeX-command-master
  "Specify whether to run command on master, buffer or region.")
;; Function used to run external command.

(defun TeX-command-select-master ()
  "Determine that the next command will be on the master file."
  (interactive)
  (message "Next command will be on the master file.")
  (setq TeX-command-current 'TeX-command-master))

(defun TeX-command-select-buffer ()
  "Determine that the next command will be on the buffer."
  (interactive)
  (message "Next command will be on the buffer")
  (setq TeX-command-current 'TeX-command-buffer))

(defun TeX-command-select-region ()
  "Determine that the next command will be on the region."
  (interactive)
  (message "Next command will be on the region")
  (setq TeX-command-current 'TeX-command-region))

(defvar TeX-command-force nil)
;; If non-nil, TeX-command-query will return the value of this
;; variable instead of quering the user.

(defun TeX-command-menu (name)
  "Execute `TeX-command-list' NAME from a menu."
  (let ((TeX-command-force name))
    (funcall TeX-command-current)))

(defun TeX-command-menu-print (printer command name)
  "Print on PRINTER using method COMMAND to run NAME."
  (let ((TeX-printer-default printer)
	(TeX-printer-list nil)
	(TeX-print-command command))
    (TeX-command-menu name)))

(defun TeX-command-menu-printer-entry (entry)
  "Return `TeX-printer-list' ENTRY as a menu item."
  (vector (nth 0 entry)
	  (list 'TeX-command-menu-print
		(nth 0 entry)
		(or (nth lookup entry) command)
		name)
	  t))

;; Begin fix part 1 by Ulrik Dickow <dickow@nbi.dk> 16-Feb-1996,
;; to make queue command usable.  Easy but ugly code duplication again.

(defun TeX-command-menu-queue (printer command name)
  "Show queue for PRINTER using method COMMAND to run NAME."
  (let ((TeX-printer-default printer)
	(TeX-printer-list nil)
	(TeX-queue-command command))
    (TeX-command-menu name)))

(defun TeX-command-menu-queue-entry (entry)
  "Return `TeX-printer-list' ENTRY as a menu item."
  (vector (nth 0 entry)
	  (list 'TeX-command-menu-queue
		(nth 0 entry)
		(or (nth lookup entry) command)
		name)
	  t))

;; End fix part 1.

(defun TeX-command-menu-entry (entry)
  "Return `TeX-command-list' ENTRY as a menu item."
  (let ((name (car entry)))
    (cond ((and (string-equal name TeX-command-Print)
		TeX-printer-list)
	   (let ((command TeX-print-command)
		 (lookup 1))
	     (append (list TeX-command-Print)
		     (mapcar 'TeX-command-menu-printer-entry
			     TeX-printer-list))))
	  ((and (string-equal name TeX-command-Queue)
		TeX-printer-list)
	   (let ((command TeX-queue-command)
		 (lookup 2))
	     (append (list TeX-command-Queue)
		     (mapcar 'TeX-command-menu-queue-entry ; dickow fix part 2.
			     TeX-printer-list))))
	  (t
	   (vector name (list 'TeX-command-menu name) t)))))

(defconst TeX-command-menu-name "Command"
  "Name to be displayed for the command menu in all modes defined by AUCTeX.")

;;; Keymap

(defcustom TeX-electric-escape nil
  "Specify whether ``\\'' will be bound to `TeX-electric-macro'.
If this is non-nil when AUCTeX is loaded, the TeX escape character ``\\'' will
be bound to `TeX-electric-macro'."
  :group 'TeX-macro
  :type 'boolean)

(defcustom TeX-newline-function 'newline
  "Function to be called upon pressing `RET'."
  :group 'TeX-indentation
  :type '(choice (const newline)
		 (const newline-and-indent)
		 (const reindent-then-newline-and-indent)
		 (sexp :tag "Other")))

(defun TeX-newline ()
  "Call the function specified by the variable `TeX-newline-function'."
  (interactive) (funcall TeX-newline-function))

(defvar TeX-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Standard
    ;; (define-key map "\177"     'backward-delete-char-untabify)
    (define-key map "\C-c}"    'up-list)
    (define-key map "\C-c#"    'TeX-normal-mode)
    (define-key map "\C-c\C-n" 'TeX-normal-mode)
    (define-key map "\C-c?"    'describe-mode)
    (define-key map "\C-c\C-i" 'TeX-goto-info-page)
    (define-key map "\r"       'TeX-newline)
    
    ;; From tex.el
    (define-key map "\""       'TeX-insert-quote)
    (define-key map "$"        'TeX-insert-dollar)
    ;; Removed because LaTeX 2e have a better solution to italic correction.
    ;; (define-key map "."        'TeX-insert-punctuation)
    ;; (define-key map ","        'TeX-insert-punctuation)
    (define-key map "\C-c{"    'TeX-insert-braces)
    (define-key map "\C-c\C-f" 'TeX-font)
    (define-key map "\C-c\C-m" 'TeX-insert-macro)
    (if TeX-electric-escape
	(define-key map "\\" 'TeX-electric-macro))
    (define-key map "\e\t"   'TeX-complete-symbol) ;*** Emacs 19 way
    
    (define-key map "\C-c'"    'TeX-comment-or-uncomment-paragraph) ;*** Old way
    (define-key map "\C-c:"    'TeX-comment-or-uncomment-region) ;*** Old way
    (define-key map "\C-c\""   'TeX-uncomment) ;*** Old way
    
    (define-key map "\C-c;"    'TeX-comment-or-uncomment-region)
    (define-key map "\C-c%"    'TeX-comment-or-uncomment-paragraph)
    
    (define-key map "\C-c\C-t\C-s"   'TeX-source-specials)
    (define-key map "\C-c\C-t\C-r"   'TeX-pin-region)
    (define-key map "\C-c\C-v" 'TeX-view)
    ;; From tex-buf.el
    (define-key map "\C-c\C-d" 'TeX-save-document)
    (define-key map "\C-c\C-r" 'TeX-command-region)
    (define-key map "\C-c\C-b" 'TeX-command-buffer)
    (define-key map "\C-c\C-c" 'TeX-command-master)
    (define-key map "\C-c\C-k" 'TeX-kill-job)
    (define-key map "\C-c\C-l" 'TeX-recenter-output-buffer)
    (define-key map "\C-c^" 'TeX-home-buffer)
    (define-key map "\C-c`"    'TeX-next-error)
    (define-key map "\C-c\C-w" 'TeX-toggle-debug-boxes)
    
    ;; Multifile
    (define-key map "\C-c_" 'TeX-master-file-ask)  ;*** temporary
    map)
  "Keymap for common TeX and LaTeX commands.")

(defvar plain-TeX-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map TeX-mode-map)
    map)
  "Keymap used in plain TeX mode.")

(defun TeX-mode-specific-command-menu (mode)
  "Return a Command menu specific to the major MODE."
  ;; COMPATIBILITY for Emacs < 21
  (if (and (not (featurep 'xemacs))
	   (= emacs-major-version 20))
      (append (list TeX-command-menu-name)
	      (TeX-mode-specific-command-menu-entries mode))
    (list TeX-command-menu-name
	  :filter `(lambda (&rest ignored)
		     (TeX-mode-specific-command-menu-entries ',mode))
	  "Bug.")))

(defun TeX-mode-specific-command-menu-entries (mode)
  "Return the entries for a Command menu specific to the major MODE."
  (append '(("Command on"
	     [ "Master File" TeX-command-select-master
	       :keys "C-c C-c" :style radio
	       :selected (eq TeX-command-current 'TeX-command-master) ]
	     [ "Buffer" TeX-command-select-buffer
	       :keys "C-c C-b" :style radio
	       :selected (eq TeX-command-current 'TeX-command-buffer) ]
	     [ "Region" TeX-command-select-region
	       :keys "C-c C-r" :style radio
	       :selected (eq TeX-command-current 'TeX-command-region) ])
	    [ "Pin region" TeX-pin-region
	      :active (or (if prefix-arg
			      (<= (prefix-numeric-value prefix-arg) 0)
			    (and (boundp 'TeX-command-region-begin)
				 (markerp TeX-command-region-begin)))
			  (TeX-mark-active))
	      ;; :visible (eq TeX-command-current 'TeX-command-region)
	      :style toggle
	      :selected (and (boundp 'TeX-command-region-begin)
			     (markerp TeX-command-region-begin))]
	    [ "Source specials" TeX-source-specials
	      :style toggle :selected TeX-source-specials ])
	  (let ((file 'TeX-command-on-current));; is this actually needed?
	    (mapcar 'TeX-command-menu-entry
		    (TeX-mode-specific-command-list mode)))))

(defun TeX-mode-specific-command-list (mode)
  "Return the list of commands available in the given MODE."
  (let ((full-list (copy-sequence TeX-command-list))
	out-list
	entry)
    (while (car full-list)
      (setq entry (pop full-list))
      ;; `(nth 4 entry)' may be either an atom in case of which the
      ;; entry should be present in any mode or a list of major modes.
      (if (or (atom (nth 4 entry))
	      (memq mode (nth 4 entry)))
	  (setq out-list (append out-list (list entry)))))
    out-list))

;;; Menus for plain TeX mode
(easy-menu-define plain-TeX-mode-command-menu
    plain-TeX-mode-map
    "Command menu used in TeX mode."
    (TeX-mode-specific-command-menu 'plain-tex-mode))

(easy-menu-define plain-TeX-mode-menu
    plain-TeX-mode-map
    "Menu used in plain TeX mode."
  (list "TeX"
	["Macro..." TeX-insert-macro t]
	["Complete" TeX-complete-symbol t]
	["Next Error" TeX-next-error t]
	["Kill Job" TeX-kill-job t]
	["Debug Bad Boxes" TeX-toggle-debug-boxes
	 :style toggle :selected TeX-debug-bad-boxes ]
	["Recenter Output Buffer" TeX-recenter-output-buffer t]
	["Comment or Uncomment Region" TeX-comment-or-uncomment-region t]
	;; ["Comment or Uncomment Paragraph" TeX-comment-or-uncomment-paragraph t]
	(list "Multifile"
	      ["Switch to Master File" TeX-home-buffer t]
	      ["Save Document" TeX-save-document t]
	      ["Set Master File" TeX-master-file-ask
	       :active (not (TeX-local-master-p))])
	"-"
	(list "Customize"
	      ["Browse options"
	       (customize-group 'AUCTeX)]
	      ["Extend this menu"
	       (easy-menu-add-item
		nil '("TeX")
		(customize-menu-create 'AUCTeX))])
	["Documentation" TeX-goto-info-page t]
	["Submit bug report" TeX-submit-bug-report t]
	["Reset Buffer" TeX-normal-mode t]
	["Reset AUCTeX" (TeX-normal-mode t) :keys "C-u C-c C-n"]))

;;; AmSTeX

(defvar AmSTeX-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map TeX-mode-map)
    map)
  "Keymap used in `AmSTeX-mode'.")

;; Menu for AmSTeX mode
(easy-menu-define AmSTeX-mode-command-menu
    AmSTeX-mode-map
    "Command menu used in AmsTeX mode."
    (TeX-mode-specific-command-menu 'ams-tex-mode))

;;;###autoload
(defun ams-tex-mode ()
  "Major mode for editing files of input for AmS TeX.
See info under AUCTeX for documentation.

Special commands:
\\{AmSTeX-mode-map}

Entering AmS-tex-mode calls the value of `text-mode-hook',
then the value of `TeX-mode-hook', and then the value
of `AmS-TeX-mode-hook'."
  (interactive)
  (plain-TeX-common-initialization)
  (use-local-map AmSTeX-mode-map)

  ;; Menu
  (easy-menu-add AmSTeX-mode-command-menu AmSTeX-mode-map)

  (setq mode-name "AmS TeX")
  (setq major-mode 'ams-tex-mode)
  (setq TeX-command-default "AmSTeX")
  (run-hooks 'text-mode-hook 'TeX-mode-hook 'AmS-TeX-mode-hook))


;;; Comments

(fset 'TeX-comment-region 'comment-region)

(eval-and-compile
  ;; COMPATIBILITY for Emacs <= 21.3
  (if (fboundp 'comment-or-uncomment-region)
      (defalias 'TeX-comment-or-uncomment-region 'comment-or-uncomment-region)
    ;; The following function was copied from `newcomment.el' on
    ;; 2004-01-30 and adapted accordingly
    (defun TeX-comment-or-uncomment-region (beg end &optional arg)
      "Call `comment-region', unless the region only consists of comments,
in which case call `uncomment-region'.  If a prefix arg is given, it
is passed on to the respective function."
      (interactive "*r\nP")
      (funcall (if (save-excursion ;; check for already commented region
		     (goto-char beg)
		     ;; `comment-forward' is not available in Emacs 20
		     (if (fboundp 'comment-forward)
			 (comment-forward (point-max))
		       (forward-comment (point-max)))
		     (<= end (point)))
		   'TeX-uncomment-region 'comment-region)
	       beg end arg)))

  ;; COMPATIBILITY for Emacs <= 20.  (Introduced in 21.1?)
  (if (fboundp 'uncomment-region)
      (defalias 'TeX-uncomment-region 'uncomment-region)
    (defun TeX-uncomment-region (beg end &optional arg)
      "Remove comment characters from the beginning of each line
in the region from BEG to END.  Numeric prefix arg ARG means use
ARG comment characters.  If ARG is negative, delete that many
comment characters instead."
      (interactive "*r\nP")
      (or arg
	  ;; Determine the number of comment characters at the
	  ;; beginning of the first commented line.
	  (setq arg
		(save-excursion
		  (goto-char beg)
		  (re-search-forward
		   (concat "^" comment-start "+") end t)
		  (length (match-string 0)))))
      (comment-region beg end (- arg)))))

(defun TeX-uncomment ()
  "Delete comment characters from the beginning of each line in a comment."
  (interactive)
  (save-excursion
    ;; Find first comment line
    (beginning-of-line)
    (while (and (looking-at (concat "^[ \t]*" comment-start)) (not (bobp)))
      (forward-line -1))
    (let ((beg (point)))
      (forward-line 1)
      ;; Find last comment line
      (while (and (looking-at (concat "^[ \t]*" comment-start)) (not (eobp)))
	(forward-line 1))
      ;; Uncomment region
      (TeX-uncomment-region beg (point)))))

(defun TeX-comment-or-uncomment-paragraph ()
  "Comment or uncomment current paragraph."
  (interactive)
  (if (TeX-in-commented-line)
      (TeX-uncomment)
    (save-excursion
      (beginning-of-line)
      ;; Don't do anything if we are in an empty line.  If this line
      ;; is followed by a lot of commented lines, this shall prevent
      ;; that mark-paragraph skips over these lines and marks a
      ;; paragraph outside the visible window which might get
      ;; commented without the user noticing.
      (unless (looking-at "^[ \t]*$")
	(mark-paragraph)
	(comment-region (point) (mark))))))

(defun TeX-in-comment ()
  "Return non-nil if point is in a comment."
  (if (or (bolp)
	  (null comment-start-skip)
	  (eq (preceding-char) ?\r))
      nil
    (save-excursion
      (let ((pos (point)))
	(re-search-backward "^\\|\r" nil t)
	(or (looking-at comment-start-skip)
	    (re-search-forward comment-start-skip pos t))))))

(defun TeX-in-commented-line ()
  "Return non-nil if point is in a line consisting only of a comment.
The comment can be preceded by whitespace.  This means that
`TeX-in-commented-line' is more general than `TeX-in-line-comment'
which will not match commented lines with leading whitespace.  But
`TeX-in-commented-line' will match commented lines without leading
whitespace as well."
  (save-excursion
    (save-match-data
      (re-search-backward "^\\|\r" nil t)
      (if (looking-at (concat "[ \t]*" comment-start))
	  t
	nil))))

(defun TeX-in-line-comment ()
  "Return non-nil if point is in a line comment.
A line comment is a comment starting in column one, i.e. there is
no whitespace before the comment sign."
  (save-excursion
    (save-match-data
      (move-to-left-margin)
      (if (looking-at comment-start)
	  t
	nil))))

(defun TeX-forward-comment-skip (&optional count limit)
  "Move forward to the next comment skip.
This may be a switch between commented and not commented adjacent
lines or between lines with different comment prefixes.  With
argument COUNT do it COUNT times.  If argument LIMIT is given, do
not move point further than this value."
  (unless count (setq count 1))
  ;; A value of 0 is nonsense.
  (when (= count 0) (setq count 1))
  (unless limit (setq limit (point-max)))
  (dotimes (i (abs count))
    (if (< count 0)
	(forward-line -1)
      (beginning-of-line))
    (let ((prefix (progn
		    (when (looking-at (concat "[ \t]*" comment-start
					      "[" comment-start " \t]*"))
		      (buffer-substring
		       (match-beginning 0)
		       (save-excursion
			 (goto-char (match-end 0))
			 (skip-chars-backward " \t")
			 (point)))))))
      (while (save-excursion
	       (and (if (> count 0)
			(<= (point) limit)
		      (>= (point) limit))
		    (zerop (if (> count 0)
			       (forward-line 1)
			     (forward-line -1)))
		    (if prefix
			(if (looking-at
			     (concat "[ \t]*" comment-start
				     "[" comment-start " \t]*"))
			    ;; If the preceding line is a commented line
			    ;; as well, check if the prefixes are
			    ;; identical.
			    (string= prefix
				     (buffer-substring
				      (match-beginning 0)
				      (save-excursion
					(goto-char (match-end 0))
					(skip-chars-backward " \t")
					(point))))
			  nil)
		      (not (looking-at (concat "[ \t]*" comment-start))))))
	(if (> count 0)
	    (forward-line 1)
	  (forward-line -1)))
      (if (> count 0)
	  (forward-line 1)))))

(defun TeX-backward-comment-skip (&optional count limit)
  "Move backward to the next comment skip.
This may be a switch between commented and not commented adjacent
lines or between lines with different comment prefixes.  With
argument COUNT do it COUNT times.  If argument LIMIT is given, do
not move point to a position less than this value."
  (unless count (setq count 1))
  (when (= count 0) (setq count 1))
  (unless limit (setq limit (point-min)))
  (TeX-forward-comment-skip (- count) limit))

(defun TeX-comment-padding-string ()
  "Return  comment padding as a string.
The variable `comment-padding' can hold an integer or a string.
This function will return the appropriate string representation
regardless of its data type."
  (if (integerp comment-padding)
      (make-string comment-padding ? )
    comment-padding))


;;; Indentation

(defgroup TeX-indentation nil
  "Indentation of TeX buffers in AUCTeX."
  :group 'AUCTeX)

(defcustom TeX-brace-indent-level 2
  "*The level of indentation produced by an open brace."
  :group 'TeX-indentation
  :type 'integer)

(defun TeX-comment-indent ()
  "Determine the indentation of a comment."
  (if (looking-at "%%%")
      (current-column)
    (skip-chars-backward " \t")
    (max (if (bolp) 0 (1+ (current-column)))
	 comment-column)))

(defun TeX-brace-count-line ()
  "Count number of open/closed braces."
  (save-excursion
    (save-restriction
      (let ((count 0))
	(narrow-to-region (point)
			  (save-excursion
			    (re-search-forward "[^\\\\]%\\|\n\\|\\'")
			    (backward-char)
			    (point)))

	(while (re-search-forward "\\({\\|}\\|\\\\.\\)" nil t)
	  (cond
	   ((string= "{" (TeX-match-buffer 1))
	    (setq count (+ count TeX-brace-indent-level)))
	   ((string= "}" (TeX-match-buffer 1))
	    (setq count (- count TeX-brace-indent-level)))))
	count))))


;;; Navigation

(defun TeX-find-closing-brace (&optional arg limit)
  "Return the position of the closing brace in a TeX group.
The function assumes that point is inside the group, i.e. after
an opening brace.  With optional ARG>=1, find that outer level.
If LIMIT is non-nil, search down to this position in the buffer."
  (let ((arg (if arg (if (< arg 1) 1 arg) 1)))
    (save-excursion
      (while (and
	      (/= arg 0)
	      (re-search-forward (concat "\\(\\=\\|[^\\]\\)\\(\\\\\\\\\\)*"
					 "\\({\\|}\\)") limit t 1))
	(cond ((string= (substring (match-string 0) -1) "{")
	       (setq arg (1+ arg)))
	      (t
	       (setq arg (1- arg)))))
      (if (/= arg 0)
	  nil
	(point)))))

(defun TeX-find-opening-brace (&optional arg limit)
  "Return the position of the opening brace in a TeX group.
The function assumes that point is inside the group, i.e. before
a closing brace.  With optional ARG>=1, find that outer level.
If LIMIT is non-nil, search up to this position in the buffer."
  (let ((arg (if arg (if (< arg 1) 1 arg) 1))
	brace)
    (save-excursion
      (while (and (/= arg 0)
		  (re-search-backward "{\\|}" limit t 1))
	(setq brace (match-string 0))
	(when (TeX-looking-at-backward
	       (concat "[^" TeX-esc "]\\("
		       (regexp-quote (concat TeX-esc TeX-esc))
		       "\\)*"))
	  (cond ((string= brace "}")
		 (setq arg (1+ arg)))
		(t
		 (setq arg (1- arg))))))
      (if (/= arg 0)
	  nil
	(point)))))

(defun TeX-find-macro-start (&optional arg)
  "Find the start of a macro.
Arguments enclosed in brackets or braces are considered part of
the macro.  If ARG is non-nil, find the end of a macro."
  (save-excursion
    (let ((orig-point (point))
	  start-point
	  found-end-flag)
      (cond
       ;; Point is located directly at the start of a macro.
       ((and (looking-at (concat "\\(" (regexp-quote TeX-esc) "\\)[@A-Za-z]+"))
	     (save-match-data
	       (not (TeX-looking-at-backward
		     (concat "\\(" (regexp-quote (concat TeX-esc TeX-esc)) "\\)*"
			     "\\(" (regexp-quote TeX-esc) "\\)")))))
	(setq start-point (point))
	(goto-char (match-end 1)))
       ;; Search backward for a macro start.
       ((and (re-search-backward
	      (concat "\\(^\\|[^" TeX-esc "\n]\\)"
		      "\\(" (regexp-quote (concat TeX-esc TeX-esc)) "\\)*"
		      "\\(" (regexp-quote TeX-esc) "\\)")
	      nil t)
	     (save-excursion
	       (goto-char (match-end 3))
	       (not (looking-at (regexp-quote TeX-esc)))))
	(setq start-point (match-beginning 3))
	(goto-char (match-end 3))))
      (if (not start-point)
	  nil
	;; Search forward for the end of the macro.
	(skip-chars-forward (concat "^ \t{[\n" (regexp-quote TeX-esc)))
	(while (not found-end-flag)
	  (cond
	   ((or (looking-at "[ \t]*\\(\\[\\)")
		(and (looking-at (concat "[ \t]*" comment-start))
		     (save-excursion
		       (forward-line 1)
		       (looking-at "[ \t]*\\(\\[\\)"))))
	    (goto-char (match-beginning 1))
	    (forward-sexp))
	   ((or (looking-at "[ \t]*{")
		(and (looking-at (concat "[ \t]*" comment-start))
		     (save-excursion
		       (forward-line 1)
		       (looking-at "[ \t]*{"))))
	    (goto-char (match-end 0))
	    (goto-char (or (TeX-find-closing-brace)
			   ;; If we cannot find a regular end, use the
			   ;; next whitespace.
			   (save-excursion (skip-chars-forward "^ \t\n")
					   (point)))))
	   (t
	    (setq found-end-flag t))))
	(if (< orig-point (point))
	    (if arg
		(point)
	      start-point)
	  nil)))))

(defun TeX-find-macro-end ()
  "Find the end of a macro.
Arguments enclosed in brackets or braces are considered part of
the macro."
  (TeX-find-macro-start t))


;;; Fonts

(defcustom TeX-font-list '((?\C-b "{\\bf " "}")
			   (?\C-c "{\\sc " "}")
			   (?\C-e "{\\em " "\\/}")
			   (?\C-i "{\\it " "\\/}")
			   (?\C-r "{\\rm " "}")
			   (?\C-s "{\\sl " "\\/}")
			   (?\C-t "{\\tt " "}")
			   (?\C-d "" "" t))
  "List of fonts used by `TeX-font'.

Each entry is a list.
The first element is the key to activate the font.
The second element is the string to insert before point, and the third
element is the string to insert after point.
If the fourth and fifth element are strings, they specify the prefix and
suffix to be used in math mode.
An optional fourth (or sixth) element means always replace if t."
  :group 'TeX-macro
  :type '(repeat
	   (group
	    :value (?\C-a "" "")
	    (character :tag "Key")
	    (string :tag "Prefix")
	    (string :tag "Suffix")
	    (option (group
		     :inline t
		     (string :tag "Math Prefix")
		     (string :tag "Math Suffix")))
	    (option (sexp :format "Replace\n" :value t)))))

(defvar TeX-font-replace-function 'TeX-font-replace
  "Determines the function which is called when a font should be replaced.")

(defun TeX-describe-font-entry (entry)
  "A textual description of an ENTRY in `TeX-font-list'."
  (concat (format "%16s  " (key-description (char-to-string (nth 0 entry))))
	  (if (or (eq t (nth 3 entry)) (eq t (nth 5 entry)))
	      "-- delete font"
	    (format "%14s %-3s %14s %-3s"
		    (nth 1 entry) (nth 2 entry)
		    (if (stringp (nth 3 entry)) (nth 3 entry) "")
		    (if (stringp (nth 4 entry)) (nth 4 entry) "")))))

(defun TeX-font (replace what)
  "Insert template for font change command.
If REPLACE is not nil, replace current font.  WHAT determines the font
to use, as specified by `TeX-font-list'."
  (interactive "*P\nc")
  (TeX-update-style)
  (let* ((entry (assoc what TeX-font-list))
	 (in-math (texmathp))
	 (before (nth 1 entry))
	 (after (nth 2 entry)))
    (setq replace (or replace (eq t (nth 3 entry)) (eq t (nth 5 entry))))
    (if (and in-math (stringp (nth 3 entry)))
	(setq before (nth 3 entry)
	      after (nth 4 entry)))
    (cond ((null entry)
	   (let ((help (concat
			"Font list:   "
			"KEY        TEXTFONT           MATHFONT\n\n"
			(mapconcat 'TeX-describe-font-entry
				   TeX-font-list "\n"))))
	     (with-output-to-temp-buffer "*Help*"
	       (set-buffer "*Help*")
	       (insert help))))
	  (replace
	   (funcall TeX-font-replace-function before after))
	  ((TeX-active-mark)
	   (save-excursion
	     (cond ((> (mark) (point))
		    (insert before)
		    (goto-char (mark))
		    (insert after))
		   (t
		    (insert after)
		    (goto-char (mark))
		    (insert before)))))
	  (t
	   (insert before)
	   (save-excursion
	     (insert after))))))

(defun TeX-font-replace (start end)
  "Replace font specification around point with START and END.
For modes with font specifications like `{\\font text}'.
See also `TeX-font-replace-macro' and `TeX-font-replace-function'."
  (save-excursion
    (while (not (looking-at "{\\\\[a-zA-Z]+ "))
      (up-list -1))
    (forward-sexp)
    (save-excursion
      (replace-match start t t))
    (if (save-excursion
	  (backward-char 3)
	  (if (looking-at (regexp-quote "\\/}"))
	      (progn
		(delete-char 3)
		nil)
	    t))
	(delete-backward-char 1))
    (insert end)))

(defun TeX-font-replace-macro (start end)
  "Replace font specification around point with START and END.
For modes with font specifications like `\\font{text}'.
See also `TeX-font-replace' and `TeX-font-replace-function'."
  (let ((font-list TeX-font-list)
	cmds strings regexp)
    (while font-list
      (setq strings (cdr (car font-list))
	    font-list (cdr font-list))
      (and (stringp (car strings)) (null (string= (car strings) ""))
	   (setq cmds (cons (car strings) cmds)))
      (setq strings (cdr (cdr strings)))
      (and (stringp (car strings)) (null (string= (car strings) ""))
	   (setq cmds (cons (car strings) cmds))))
    (setq regexp (mapconcat 'regexp-quote cmds "\\|"))
    (save-excursion
      (catch 'done
	(while t
	  (if (/= ?\\ (following-char))
	      (skip-chars-backward "a-zA-Z "))
	  (skip-chars-backward (regexp-quote TeX-esc))
	  (if (looking-at regexp)
	      (throw 'done t)
	    (up-list -1))))
      (forward-sexp 2)
      (save-excursion
	(replace-match start t t))
      (delete-backward-char 1)
      (insert end))))

;;; Dollars
;;
;; Rewritten from scratch with use of `texmathp' by
;; Carsten Dominik <dominik@strw.leidenuniv.nl>

(defvar TeX-symbol-marker nil)

(defvar TeX-symbol-marker-pos 0)

;; The following constants are no longer used, but kept in case some
;; foreign code uses any of them.
(defvar TeX-dollar-sign ?$
  "*Character used to enter and leave math mode in TeX.")
(defconst TeX-dollar-string (char-to-string TeX-dollar-sign))
(defconst TeX-dollar-regexp
  (concat "^" (regexp-quote TeX-dollar-string) "\\|[^" TeX-esc "]"
	  (regexp-quote TeX-dollar-string)))

(defcustom TeX-math-toggle-off-input-method t
  "*If non-nil, auto toggle off CJK input methods when entering math mode."
  :group 'TeX-macro
  :type 'boolean)

(defun TeX-insert-dollar (&optional arg)
  "Insert dollar sign.

If current math mode was not entered with a dollar, refuse to insert one.
Show matching dollar sign if this dollar sign ends the TeX math mode.
Ensure double dollar signs match up correctly by inserting extra
dollar signs when needed.

With raw \\[universal-argument] prefix, insert exactly one dollar sign.
With optional ARG, insert that many dollar signs."
  (interactive "P")
  (cond
   ((and arg (listp arg))
    ;; C-u always inserts one
    (insert "$"))
   (arg
    ;; Numerical arg inserts that many
    (insert (make-string (prefix-numeric-value arg) ?\$)))
   ((TeX-point-is-escaped)
    ;; This is escaped with `\', so just insert one.
    (insert "$"))
   ((texmathp)
    ;; We are inside math mode
    (if (and (stringp (car texmathp-why))
	     (string-equal (substring (car texmathp-why) 0 1) "\$"))
	;; Math mode was turned on with $ or $$ - so finish it accordingly.
	(progn
	  (insert (car texmathp-why))
	  (save-excursion
	    (goto-char (cdr texmathp-why))
	    (if (pos-visible-in-window-p)
		(sit-for 1)
	      (message "Matches %s"
		       (buffer-substring (point)
					 (progn (end-of-line) (point)))))))
      ;; Math mode was not entered with dollar - we cannot finish it with one.
      (error "Math mode because of `%s'.  Use `C-q $' to force a dollar"
	     (car texmathp-why))))
   (t
    ;; Just somewhere in the text.
    (insert "$")))
  (TeX-math-input-method-off))

(defun TeX-point-is-escaped ()
  "Count backslashes before point and return t if number is odd."
  (let (odd)
    (save-excursion
      (while (equal (preceding-char) ?\\)
	(progn
	  (forward-char -1)
	  (setq odd (not odd)))))
    odd))

(defun TeX-math-input-method-off ()
  "Toggle off input method when entering math mode."
  (and TeX-math-toggle-off-input-method
       (texmathp)
       (TeX-toggle-off-input-method)))

(defun TeX-toggle-off-input-method ()
  "Toggle off CJK input methods.
Only support LEIM package (toggle-input-method)."
  (cond
   ;; LEIM Package Support
   ((and (boundp 'current-input-method) current-input-method
	 (string-match "^chinese\\|japanese\\|korean" current-input-method))
    (toggle-input-method))
   (t );; do nothing
   ))

;;; Simple Commands

(defun TeX-normal-mode (arg)
  "Remove all information about this buffer, and apply the style hooks again.
Save buffer first including style information.
With optional argument ARG, also reload the style hooks."
  ;; FIXME: Shouldn't it be (&optional arg)?  -- rs
  (interactive "*P")
  (if arg
      (setq TeX-style-hook-list nil
	    BibTeX-global-style-files nil
	    BibTeX-global-files nil
	    TeX-global-input-files nil))
  (let ((TeX-auto-save t))
    (if (buffer-modified-p)
	(save-buffer)
      (TeX-auto-write)))
  (normal-mode)
  (TeX-update-style))

(defgroup TeX-quote nil
  "Quoting in AUCTeX."
  :group 'AUCTeX)

(defcustom TeX-open-quote "``"
  "*String inserted by typing \\[TeX-insert-quote] to open a quotation."
  :group 'TeX-quote
  :type 'string)

(defcustom TeX-close-quote "''"
  "*String inserted by typing \\[TeX-insert-quote] to close a quotation."
  :group 'TeX-quote
  :type 'string)

(defcustom TeX-quote-after-quote nil
  "*Behaviour of \\[TeX-insert-quote].  Nil means standard behaviour;
when non-nil, opening and closing quotes are inserted only after \"."
  :group 'TeX-quote
  :type 'boolean)

;;;###autoload
(defun TeX-insert-quote (force)
  "Insert the appropriate quote marks for TeX.
Inserts the value of `TeX-open-quote' (normally ``) or `TeX-close-quote'
\(normally '') depending on the context.  If `TeX-quote-after-quote'
is non-nil, this insertion works only after \".
With prefix argument FORCE, always inserts \" characters."
  (interactive "*P")
  (if force
      (self-insert-command (prefix-numeric-value force))
    (TeX-update-style)
    (if TeX-quote-after-quote
	(insert (cond ((bobp)
		       ?\")
		      ((not (= (preceding-char) ?\"))
		       ?\")
		      ((save-excursion
			 (forward-char -1)
			 (bobp))
		       (delete-backward-char 1)
		       TeX-open-quote)
		      ((save-excursion
			 (forward-char -2) ;;; at -1 there is double quote
			 (looking-at "[ \t\n]\\|\\s("))
		       (delete-backward-char 1)
		       TeX-open-quote)
		      (t
		       (delete-backward-char 1)
		       TeX-close-quote)))
      (insert (cond ((bobp)
		     TeX-open-quote)
		    ((= (preceding-char) (string-to-char TeX-esc))
		     ?\")
		    ((= (preceding-char) ?\")
		     ?\")
		    ((save-excursion
		       (forward-char (- (length TeX-open-quote)))
		       (looking-at (regexp-quote TeX-open-quote)))
		     (delete-backward-char (length TeX-open-quote))
		     ?\")
		    ((save-excursion
		       (forward-char (- (length TeX-close-quote)))
		       (looking-at (regexp-quote TeX-close-quote)))
		     (delete-backward-char (length TeX-close-quote))
		     ?\")
		    ((save-excursion
		       (forward-char -1)
		       (looking-at "[ \t\n]\\|\\s("))
		     TeX-open-quote)
		    (t
		     TeX-close-quote))))))

;; For the sake of BibTeX...
;;; Do not ;;;###autoload because of conflict with standard tex-mode.el.
(fset 'tex-insert-quote 'TeX-insert-quote)

(defun TeX-insert-punctuation ()
  "Insert point or comma, cleaning up preceding space."
  (interactive)
  (expand-abbrev)
  (if (TeX-looking-at-backward "\\\\/\\(}+\\)" 50)
      (replace-match "\\1" t))
  (call-interactively 'self-insert-command))

(defun TeX-insert-braces (arg)
  "Make a pair of braces around next ARG sexps and leave point inside.
No argument is equivalent to zero: just insert braces and leave point
between."
  (interactive "P")
  (insert TeX-grop)
  (save-excursion
    (if arg (forward-sexp (prefix-numeric-value arg)))
    (insert TeX-grcl)))

(defun TeX-goto-info-page ()
  "Read documentation for AUCTeX in the info system."
  (interactive)
  (require 'info)
  (Info-goto-node "(auctex)"))

;;;###autoload
(defun TeX-submit-bug-report ()
  "Submit a bug report on AUCTeX via mail."
  (interactive)
  (require 'reporter)
  (reporter-submit-bug-report
   "auc-tex@sunsite.dk"
   (concat "AUCTeX " AUCTeX-version)
   (list 'window-system
	 'LaTeX-version
	 'TeX-style-path
	 'TeX-auto-save
	 'TeX-parse-self
	 'TeX-master)
   nil nil
   "Remember to cover the basics, that is, what you expected to happen and
what in fact did happen."))

;;; Ispell Support

;; FIXME: Document those functions and variables.  -- rs

;; The FSF ispell.el use this.
(defun ispell-tex-buffer-p ()
  (and (boundp 'ispell-tex-p) ispell-tex-p))

;; The FSF ispell.el might one day use this.
(setq ispell-enable-tex-parser t)

(defun TeX-run-ispell (command string file)
  "Run ispell on current TeX buffer."
  (cond ((and (string-equal file (TeX-region-file))
	      (fboundp 'ispell-region))
	 (call-interactively 'ispell-region))
	((string-equal file (TeX-region-file))
	 (call-interactively 'spell-region))
	((fboundp 'ispell-buffer)
	 (ispell-buffer))
	((fboundp 'ispell)
	 (ispell))
	(t
	 (spell-buffer))))

;; Some versions of ispell 3 use this.
(defvar ispell-tex-major-modes nil)
(setq ispell-tex-major-modes
      (append '(plain-tex-mode ams-tex-mode latex-mode doctex-mode)
	      ispell-tex-major-modes))

(provide 'tex)

;;; tex.el ends here
