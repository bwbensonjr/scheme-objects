(load "pyobj.scm")

;; Test 1: Bootstrap verification
(display "=== Test 1: Bootstrap ===\n")
(display "  <object> class is <type>: ")
(display (eq? (@ <object> '__class__) <type>))
(newline)
(display "  <type> class is <type>: ")
(display (eq? (@ <type> '__class__) <type>))
(newline)
(display "  <type> has parent <object>: ")
(display (eq? (car (@ <type> '__bases__)) <object>))
(newline)
(display "  <object> has no parents: ")
(display (null? (@ <object> '__bases__)))
(newline)
(display "  <type> name: ")
(display (@ <type> '__name__))
(newline)
(display "  <object> name: ")
(display (@ <object> '__name__))
(newline)

;; Test 2: Define a simple class
(display "\n=== Test 2: Simple Class ===\n")
(define-class <point> (<object>)
  (def (__init__ self x y)
    (@! self 'x x)
    (@! self 'y y))

  (def (distance self other)
    (let ((dx (- (@ self 'x) (@ other 'x)))
          (dy (- (@ self 'y) (@ other 'y))))
      (sqrt (+ (* dx dx) (* dy dy))))))

(define p1 (make <point> 0 0))
(define p2 (make <point> 3 4))

(display "  p1.x: ")
(display (@ p1 'x))
(newline)
(display "  p2.y: ")
(display (@ p2 'y))
(newline)
(display "  distance p1 to p2: ")
(display (@ p1 'distance p2))
(newline)

;; Test 3: Set attribute
(display "\n=== Test 3: Set Attribute ===\n")
(@! p1 'x 10)
(display "  After (@! p1 'x 10), p1.x: ")
(display (@ p1 'x))
(newline)

;; Test 4: Inheritance
(display "\n=== Test 4: Inheritance ===\n")
(define-class <colored-point> (<point>)
  (def (__init__ self x y color)
    (super self '__init__ x y)
    (@! self 'color color))

  (def (describe self)
    (string-append "A "
                   (symbol->string (@ self 'color))
                   " point at ("
                   (number->string (@ self 'x))
                   ", "
                   (number->string (@ self 'y))
                   ")")))

(define cp (make <colored-point> 5 12 'red))
(display "  cp.color: ")
(display (@ cp 'color))
(newline)
(display "  cp.x: ")
(display (@ cp 'x))
(newline)
(display "  cp.describe(): ")
(display ((@ cp 'describe)))  ; Zero-arg method needs extra parens to call
(newline)
(display "  distance cp to p2 (inherited): ")
(display (@ cp 'distance p2))
(newline)

;; Test 5: instance-of?
(display "\n=== Test 5: instance-of? ===\n")
(display "  (instance-of? p1 <point>): ")
(display (instance-of? p1 <point>))
(newline)
(display "  (instance-of? p1 <object>): ")
(display (instance-of? p1 <object>))
(newline)
(display "  (instance-of? cp <colored-point>): ")
(display (instance-of? cp <colored-point>))
(newline)
(display "  (instance-of? cp <point>): ")
(display (instance-of? cp <point>))
(newline)
(display "  (instance-of? <point> <type>): ")
(display (instance-of? <point> <type>))
(newline)

(display "\n=== All tests completed ===\n")
