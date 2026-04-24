;;; pyobj.scm - Python-like Object System for Chez Scheme
;;;
;;; A minimal Python-inspired object system with:
;;;   - <object> and <type> base classes (full bootstrap)
;;;   - Unified attribute access: (@ obj 'attr arg...)
;;;   - Single inheritance
;;;   - Method binding (descriptor-like)
;;;
;;; Usage:
;;;   (load "pyobj.scm")
;;;   (define-class <point> (<object>)
;;;     (def (__init__ self x y)
;;;       (@! self 'x x)
;;;       (@! self 'y y)))
;;;   (define p (make <point> 10 20))
;;;   (@ p 'x)  ; => 10

;;; ============================================================
;;; Section 1: Core Data Structures
;;; ============================================================

;; Unique tag for identifying our objects
(define %object-tag (gensym "pyobj"))

;; Sentinel for "not found" in hashtable lookups
(define %not-found (gensym "not-found"))

;; Create a raw object (vector with tag, class, and dict)
(define (%make-raw-object class)
  (let ((obj (make-vector 3)))
    (vector-set! obj 0 %object-tag)
    (vector-set! obj 1 class)
    (vector-set! obj 2 (make-eq-hashtable))
    obj))

;; Predicate: is x a pyobj?
(define (%pyobj? x)
  (and (vector? x)
       (>= (vector-length x) 3)
       (eq? (vector-ref x 0) %object-tag)))

;; Accessors for object internals
(define (%pyobj-class obj)
  (vector-ref obj 1))

(define (%pyobj-dict obj)
  (vector-ref obj 2))

(define (%set-pyobj-class! obj cls)
  (vector-set! obj 1 cls))

;;; ============================================================
;;; Section 2: Bootstrap - Create <type> and <object>
;;; ============================================================

;; Step 1: Create <type> with class pointing to itself (temporarily #f)
(define <type> (%make-raw-object #f))
(%set-pyobj-class! <type> <type>)  ; <type> is instance of itself

;; Step 2: Create <object> with class pointing to <type>
(define <object> (%make-raw-object <type>))

;; Step 3: Initialize <object>'s class attributes
(let ((dict (%pyobj-dict <object>)))
  (hashtable-set! dict '__name__ "<object>")
  (hashtable-set! dict '__bases__ '())
  (hashtable-set! dict '__mro__ (list <object>)))

;; Step 4: Initialize <type>'s class attributes
(let ((dict (%pyobj-dict <type>)))
  (hashtable-set! dict '__name__ "<type>")
  (hashtable-set! dict '__bases__ (list <object>))
  (hashtable-set! dict '__mro__ (list <type> <object>)))

;;; ============================================================
;;; Section 3: Helper Procedures
;;; ============================================================

;; Get the MRO (method resolution order) for a class
(define (%get-mro cls)
  (hashtable-ref (%pyobj-dict cls) '__mro__ '()))

;; Compute MRO for single inheritance
(define (%compute-mro cls bases)
  (if (null? bases)
      (list cls)
      (cons cls (%get-mro (car bases)))))

;; Check if obj is a class (instance of <type> or subclass)
(define (%is-class? obj)
  (and (%pyobj? obj)
       (memq <type> (%get-mro (%pyobj-class obj)))))

;;; ============================================================
;;; Section 4: Attribute Access - @ and @!
;;; ============================================================

;; Maybe bind a method to an instance (descriptor protocol)
(define (%maybe-bind-method val obj cls)
  (cond
    ;; If not a procedure, return as-is
    [(not (procedure? val)) val]
    ;; If obj is a class, return unbound (like Class.method in Python)
    [(%is-class? obj) val]
    ;; Otherwise, bind the method to the instance
    [else
     (lambda args
       (apply val obj args))]))

;; Look up attribute in MRO chain
(define (%lookup-in-mro obj attr mro)
  (if (null? mro)
      (error '@ "attribute not found" attr obj)
      (let* ((cls (car mro))
             (cls-dict (%pyobj-dict cls))
             (val (hashtable-ref cls-dict attr %not-found)))
        (if (eq? val %not-found)
            (%lookup-in-mro obj attr (cdr mro))
            ;; Found in class - apply descriptor protocol
            (%maybe-bind-method val obj cls)))))

;; Core attribute getter
(define (%getattr obj attr)
  (cond
    ;; Special: __class__ returns the class
    [(eq? attr '__class__)
     (%pyobj-class obj)]
    ;; Special: __dict__ returns the instance dict
    [(eq? attr '__dict__)
     (%pyobj-dict obj)]
    [else
     (let* ((cls (%pyobj-class obj))
            (mro (%get-mro cls)))
       ;; 1. Check instance __dict__ first
       (let ((val (hashtable-ref (%pyobj-dict obj) attr %not-found)))
         (if (not (eq? val %not-found))
             val
             ;; 2. Walk MRO looking in class __dict__s
             (%lookup-in-mro obj attr mro))))]))

;; Look up attribute, return #f if not found (for internal use)
(define (%lookup-in-mro-or-false obj attr mro)
  (if (null? mro)
      #f
      (let* ((cls (car mro))
             (cls-dict (%pyobj-dict cls))
             (val (hashtable-ref cls-dict attr %not-found)))
        (if (eq? val %not-found)
            (%lookup-in-mro-or-false obj attr (cdr mro))
            val))))  ; Don't bind - caller will handle

(define (%getattr-or-false obj attr)
  (let* ((cls (%pyobj-class obj))
         (mro (%get-mro cls)))
    ;; Check instance dict first
    (let ((val (hashtable-ref (%pyobj-dict obj) attr %not-found)))
      (if (not (eq? val %not-found))
          val
          (%lookup-in-mro-or-false obj attr mro)))))

;; The @ procedure - unified attribute access and method call
(define @
  (case-lambda
    [(obj attr)
     (%getattr obj attr)]
    [(obj attr . args)
     (apply (%getattr obj attr) args)]))

;; The @! procedure - attribute setter
(define (@! obj attr val)
  (cond
    [(eq? attr '__class__)
     (error '@! "cannot set __class__" obj)]
    [(eq? attr '__dict__)
     (error '@! "cannot set __dict__" obj)]
    [else
     (hashtable-set! (%pyobj-dict obj) attr val)]))

;;; ============================================================
;;; Section 5: Class Creation
;;; ============================================================

;; Create a new class
(define (%make-class name bases dict-entries)
  (let ((cls (%make-raw-object <type>)))
    (let ((dict (%pyobj-dict cls))
          (mro (%compute-mro cls bases)))
      ;; Set class metadata
      (hashtable-set! dict '__name__ name)
      (hashtable-set! dict '__bases__ bases)
      (hashtable-set! dict '__mro__ mro)
      ;; Copy dict-entries into class dict
      (for-each
        (lambda (entry)
          (hashtable-set! dict (car entry) (cdr entry)))
        dict-entries)
      cls)))

;;; ============================================================
;;; Section 6: Object Instantiation
;;; ============================================================

;; Create a new instance of a class
(define (make cls . init-args)
  (let ((obj (%make-raw-object cls)))
    ;; Call __init__ if it exists
    (let ((init-method (%getattr-or-false cls '__init__)))
      (when init-method
        (apply init-method obj init-args)))
    obj))

;;; ============================================================
;;; Section 7: Super Helper
;;; ============================================================

;; Helper for looking up in parent's MRO
(define (%super-lookup self method-name args mro)
  (if (null? mro)
      (error 'super "method not found in parent classes" method-name)
      (let ((method (hashtable-ref (%pyobj-dict (car mro)) method-name #f)))
        (if method
            (apply method self args)
            (%super-lookup self method-name args (cdr mro))))))

;; Call the parent class's method
(define (super self method-name . args)
  (let* ((cls (%pyobj-class self))
         (bases (hashtable-ref (%pyobj-dict cls) '__bases__ '())))
    (if (null? bases)
        (error 'super "no parent class" cls)
        (let* ((parent (car bases))
               (parent-method (hashtable-ref (%pyobj-dict parent) method-name #f)))
          (if parent-method
              (apply parent-method self args)
              ;; Look up the MRO chain
              (%super-lookup self method-name args (cdr (%get-mro parent))))))))

;;; ============================================================
;;; Section 8: Public Helper Procedures
;;; ============================================================

;; Check if obj is an instance of cls (or subclass)
(define (instance-of? obj cls)
  (and (%pyobj? obj)
       (if (memq cls (%get-mro (%pyobj-class obj))) #t #f)))

;; Get the class of an object
(define (class-of obj)
  (if (%pyobj? obj)
      (%pyobj-class obj)
      (error 'class-of "not a pyobj" obj)))

;;; ============================================================
;;; Section 9: Macros - define-class and def
;;; ============================================================

;; Method definition helper: (def (name self arg ...) body ...)
;; Expands to: (cons 'name (lambda (self arg ...) body ...))
(define-syntax def
  (syntax-rules ()
    [(_ (name self arg ...) body ...)
     (cons 'name (lambda (self arg ...) body ...))]))

;; Class definition macro
;; (define-class <name> (<parent>) body ...)
;; (define-class <name> () body ...)  ; defaults to <object>
(define-syntax define-class
  (syntax-rules ()
    [(_ name (parent) body ...)
     (define name
       (%make-class (symbol->string 'name)
                    (list parent)
                    (list body ...)))]
    [(_ name () body ...)
     (define name
       (%make-class (symbol->string 'name)
                    (list <object>)
                    (list body ...)))]))

;;; ============================================================
;;; Done - Print confirmation
;;; ============================================================

'pyobj-loaded
