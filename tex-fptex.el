;;; tex-fptex.el --- fpTeX support for AUCTeX.

;; Copyright (C) 2000 Fabrice Popineau
;; Copyright (C) 2004 Free Software Foundation, Inc.

;; Author: Fabrice Popineau <Fabrice.Popineau@supelec.fr>
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
;;
;; This file contains variables customized for fpTeX.

;;; Code:

(defmacro parent-directory (f)
  "Return safe parent directory of the directory given as argument."
  `(directory-file-name
    (file-name-directory
     (directory-file-name ,f))))

(setq TeX-lisp-directory 
      (concat (parent-directory (invocation-directory))
	      "/site-lisp/auctex"))

(unless (get 'TeX-command-list 'saved-value)
  (setq TeX-command-list
	(list (list "TeX" "%(PDF)tex %S%(PDFout) \"%(mode)\\input %t\""
		    'TeX-run-TeX nil (list 'plain-tex-mode)
		    :help "Run plain TeX")
	      (list "LaTeX" "%l \"%(mode)\\input{%t}\"" 'TeX-run-TeX nil
		    (list 'latex-mode 'doctex-mode) :help "Run LaTeX")
	      (list "Makeinfo" "makeinfo %t" 'TeX-run-compile nil
		    (list 'texinfo-mode) :help "Run Makeinfo with Info output")
	      (list "Makeinfo HTML" "makeinfo --html %t" 'TeX-run-compile nil
		    (list 'texinfo-mode) :help "Run Makeinfo with HTML output")
	      (list "AmSTeX" "amstex %S \"%(mode)\\input %t\""
		    'TeX-run-TeX nil (list 'ams-tex-mode) :help "Run AMSTeX")
	      (list "ConTeXt" "texexec --once --texutil %(execmode)%t"
		    'TeX-run-TeX nil (list 'context-mode)
		    :help "Run ConTeXt once")
	      (list "ConTeXt Full" "texexec %(execmode)%t" 'TeX-run-TeX nil
		    (list 'context-mode) :help "Run ConTeXt until completion")
	      (list "ConTeXt Clean" "texutil --purgeall"
		    'TeX-run-interactive nil (list 'context-mode)
		    :help "Clean temporary ConTeXt files")
	      (list "BibTeX" "bibtex %s" 'TeX-run-BibTeX nil t
		    :help "Run BibTeX")
	      (list "View" "%V" 'TeX-run-discard t t :help "Run viewer")
	      (list "Print" "dvips %d" 'TeX-run-command t t
		    :help "Print the file")
	      (list "File" "dvips %d -o %f " 'TeX-run-command t t
		    :help "Generate PostScript file")
	      (list "Index" "makeindex %s" 'TeX-run-command nil t
		    :help "Create index file")
	      (list "Check" "lacheck %s" 'TeX-run-compile nil
		    (list 'latex-mode)
		    :help "Check LaTeX file for correctness")
	      (list "Spell" "<ignored>" 'TeX-run-ispell-on-document nil t
		    :help "Spell-check the document")
	      (list "Other" "" 'TeX-run-command t t
		    :help "Run an arbitrary command"))))

(unless (get 'TeX-view-style 'saved-value)
  (setq TeX-view-style '(("^a5\\(?:comb\\|paper\\)?$" "windvi %d -qpaper a5")
			 ("^landscape$" "windvi %d -qpaper a4r -s 4")
			 ("^epsf$" "gsview32 %f")
			 ("." "windvi %d"))))

(unless (get 'TeX-output-view-style 'saved-value)
  (setq TeX-output-view-style
	'(("^dvi$" "^pstricks$\\|^pst-\\|^psfrag$" "dvips %d -o && gsview32 %f")
	  ("^dvi$" ("^a5\\(?:comb\\|paper\\)$" "^landscape$")
	   "windvi %d %dS -qpaper a5r -s 0")
	  ("^dvi$" "^a5\\(?:comb\\|paper\\)$" "windvi %d %dS -qpaper a5")
	  ("^dvi$" "^b5paper$" "windvi %d %dS -qpaper b5")
	  ("^dvi$" ("^landscape$" "^pstricks$\\|^psfrag$")
	   "dvips -t landscape %d -o && gsview32 %f")
	  ("^dvi$" "^letterpaper$" "windvi %d %dS -qpaper us")
	  ("^dvi$" "^legalpaper$" "windvi %d %dS -qpaper legal")
	  ("^dvi$" "^executivepaper$" "windvi %d %dS -qpaper 7.25x10.5in")
	  ("^dvi$" "^landscape$" "windvi %d %dS -qpaper a4r")
	  ("^dvi$" "." "windvi %d %dS")
	  ("^pdf$" "." "AcroRd32 %o") ; Use "start %o" instead?
	  ("^html?$" "." "mozilla %o"))))

;; WinDVI does not support source specials?
(unless (get 'TeX-source-specials-viewer-flags 'saved-value)
  (setq TeX-source-specials-viewer-flags ""))

(provide 'tex-fptex)

;;; tex-fptex.el ends here
