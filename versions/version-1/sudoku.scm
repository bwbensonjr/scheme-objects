(load "pyobj.scm")

(define-class <board> (<object>)
  (def ($init self board-file)
       (@! self 'board-file board-file)
       (@ self 'read-file (@ sel
