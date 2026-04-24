# PyObj - A Python-like Object System for Chez Scheme

A minimal Python-inspired object system for Chez Scheme 10.3.0 that captures the essence of Python's object model while remaining idiomatic to Scheme.

## Quick Start

```scheme
(load "pyobj.scm")

;; Define a class
(define-class <point> (<object>)
  (def (__init__ self x y)
    (@! self 'x x)
    (@! self 'y y))

  (def (distance self other)
    (let ((dx (- (@ self 'x) (@ other 'x)))
          (dy (- (@ self 'y) (@ other 'y))))
      (sqrt (+ (* dx dx) (* dy dy))))))

;; Create instances
(define p1 (make <point> 0 0))
(define p2 (make <point> 3 4))

;; Access attributes
(@ p1 'x)              ; => 0

;; Call methods
(@ p1 'distance p2)    ; => 5

;; Set attributes
(@! p1 'x 10)
```

## API Reference

### Attribute Access

| Form | Description |
|------|-------------|
| `(@ obj 'attr)` | Get attribute value |
| `(@ obj 'method arg ...)` | Call method with arguments |
| `(@! obj 'attr val)` | Set attribute value |

**Note:** For zero-argument methods, use `((@ obj 'method))` since `(@ obj 'method)` returns the bound method.

### Class Definition

```scheme
(define-class <name> (<parent>)
  (def (method-name self arg ...)
    body ...))
```

- `<parent>` can be `<object>` (the base class) or any user-defined class
- Use `(def ...)` to define methods within the class body
- The first argument to any method is always `self`

### Object Instantiation

```scheme
(make <class> init-arg ...)
```

Creates a new instance and calls `__init__` with the provided arguments.

### Inheritance and Super

```scheme
(define-class <colored-point> (<point>)
  (def (__init__ self x y color)
    (super self '__init__ x y)    ; Call parent's __init__
    (@! self 'color color)))
```

Use `(super self 'method-name arg ...)` to call a parent class method.

### Type Checking

| Form | Description |
|------|-------------|
| `(instance-of? obj cls)` | Check if obj is instance of cls (or subclass) |
| `(class-of obj)` | Return the class of obj |

### Special Attributes

| Attribute | Description |
|-----------|-------------|
| `'__class__` | The object's class |
| `'__dict__` | The object's attribute dictionary (hashtable) |
| `'__name__` | Class name (string) |
| `'__bases__` | List of parent classes |
| `'__mro__` | Method Resolution Order list |

## Design

### Python Object Model Mapping

This implementation captures key aspects of Python's object system:

| Python Concept | PyObj Implementation |
|----------------|---------------------|
| Everything is an object | All values (including classes) are pyobj instances |
| `object` base class | `<object>` - base class for all classes |
| `type` metaclass | `<type>` - class of all classes |
| `__dict__` | Each object has an eq-hashtable for attributes |
| Descriptor protocol | Methods are functions that get bound to instances on access |
| Single dispatch | Methods dispatch on `self` (first argument) |

### The Bootstrap

The implementation achieves Python's circular bootstrap:

```
<object> is an instance of <type>
<type> is an instance of <type> (itself)
<type> inherits from <object>
```

This is accomplished by:
1. Creating `<type>` with a placeholder class reference
2. Setting `<type>`'s class to itself
3. Creating `<object>` with `<type>` as its class
4. Initializing both with proper metadata

### Object Representation

Objects are represented as 3-element vectors:

```
Index 0: Tag (unique gensym for type checking)
Index 1: Class reference
Index 2: __dict__ (eq-hashtable for attributes)
```

This design was inspired by Tiny CLOS but uses hashtables instead of fixed slots for Python-like dynamic attribute storage.

### Attribute Lookup

When accessing `(@ obj 'attr)`:

1. Check for special attributes (`__class__`, `__dict__`)
2. Look in the instance's `__dict__`
3. Walk the Method Resolution Order (MRO), checking each class's `__dict__`
4. If found in a class and it's a procedure, bind it to the instance (descriptor protocol)

### Method Binding

When a procedure is found in a class (not the instance), it's automatically wrapped:

```scheme
;; Original function stored in class
(lambda (self x) ...)

;; Becomes bound method when accessed on instance
(lambda (x) (original-function instance x))
```

This mirrors Python's descriptor protocol where `obj.method` returns a bound method.

## Limitations (v1)

This is a minimal first version with intentional limitations:

- **Single inheritance only** - No multiple inheritance or C3 linearization
- **No `__slots__`** - All attributes stored in hashtable
- **No property descriptors** - No `@property` equivalent
- **No `__getattr__`/`__setattr__`** - No attribute access customization
- **No class methods or static methods** - All methods are instance methods
- **Simple `super`** - Only looks up direct parent chain

## Files

| File | Description |
|------|-------------|
| `pyobj.scm` | Main implementation (~280 lines) |
| `test-pyobj.scm` | Test suite demonstrating all features |

## Running Tests

```bash
cd versions/version-1
chez --script test-pyobj.scm
```

## Example: Complete Class Hierarchy

```scheme
(load "pyobj.scm")

;; Base shape class
(define-class <shape> (<object>)
  (def (__init__ self name)
    (@! self 'name name))

  (def (describe self)
    (string-append "A shape called " (@ self 'name))))

;; Circle inherits from shape
(define-class <circle> (<shape>)
  (def (__init__ self name radius)
    (super self '__init__ name)
    (@! self 'radius radius))

  (def (area self)
    (* 3.14159 (@ self 'radius) (@ self 'radius)))

  (def (describe self)
    (string-append "A circle called " (@ self 'name)
                   " with radius " (number->string (@ self 'radius)))))

;; Usage
(define c (make <circle> "Bob" 5))
(@ c 'name)           ; => "Bob"
(@ c 'radius)         ; => 5
(@ c 'area)           ; => 78.53975
((@ c 'describe))     ; => "A circle called Bob with radius 5"

;; Type checking
(instance-of? c <circle>)  ; => #t
(instance-of? c <shape>)   ; => #t
(instance-of? c <object>)  ; => #t
```

## References

- [Python Data Model](https://docs.python.org/3/reference/datamodel.html)
- [Tiny CLOS](../examples/tiny-clos/) - Scheme object system that inspired the vector representation
- [PYTHON-OBJECTS.md](../../PYTHON-OBJECTS.md) - Analysis of Python's object system
