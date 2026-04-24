Here is a technical overview of the Python object system, followed by comparisons with CLOS and Smalltalk.

### 1. The Python Object System: Internals
Python’s object system is designed around a "consenting adults" philosophy (open access) and a highly dynamic architecture where classes and functions are themselves first-class objects.

#### A. "Everything is an Object"
In Python, integers, functions, classes, and even the type system itself are objects. This creates a bootstrap loop at the core of the language:
*   **`object`**: The base class for all classes. It has no superclass.
*   **`type`**: The class that creates all classes. It is a subclass of `object`.
*   **The Loop**: `object` is an instance of `type`, and `type` is an instance of itself.

#### B. Attributes and `__dict__`
Unlike statically typed languages where object layout is fixed in memory (like a C struct), Python objects (by default) are essentially wrappers around a hash map (dictionary).
*   **Instance Storage**: Attributes are stored in a dictionary named `__dict__` attached to the instance. When you access `obj.x`, Python usually performs a lookup in `obj.__dict__['x']`.
*   **Memory Optimization**: To prevent the overhead of a dictionary for every object, classes can define `__slots__`, a list of strings that reserves fixed memory space for specific attributes, disabling `__dict__` creation.

#### C. The Descriptor Protocol (How Methods Work)
This is the "secret sauce" of Python objects. It explains the difference between a simple function and a bound method.
In Python, **methods are not distinct entities stored in the object**. They are just functions stored in the *class*.
*   **The Protocol**: Any object defining `__get__`, `__set__`, or `__delete__` is a descriptor.
*   **Function Binding**: All functions in Python are descriptors.
*   **The Mechanism**:
    1. When you access `instance.method`, Python looks up `method` in the class.
    2. It finds a function object.
    3. Because the function is a descriptor, Python calls its `__get__` method, passing the `instance` as an argument.
    4. The function’s `__get__` returns a **bound method** object (a partial application), which holds references to both the original function and the `instance` (as `self`).

This is why `Class.method` returns a `function` (unbound), but `instance.method` returns a `method` (bound).

#### D. Inheritance and MRO (C3 Linearization)
Python supports multiple inheritance. To solve the "Diamond Problem" (ambiguity when inheriting from two classes that share a common ancestor), Python uses the **C3 Linearization** algorithm (adopted from Dylan).
*   It generates a deterministic **Method Resolution Order (MRO)** list for every class.
*   `super()` does not call the "parent" class directly; it calls the **next class in the MRO**. This allows "cooperative multiple inheritance," where a method in a subclass can call `super()`, and the call will traverse sideways across the inheritance graph before going up to the common ancestor.

---

### 2. Comparison: Python vs. Smalltalk
Smalltalk is the spiritual ancestor of Python, and they share the "everything is an object" philosophy. However, their execution models differ significantly.

#### Message Passing vs. Attribute Access
*   **Smalltalk (Message Passing):**
    *   The fundamental atomic operation is **sending a message**.
    *   Syntax: `receiver selector: argument`.
    *   The object receives the message and decides what to do. If it has a method for that selector, it executes it. If not, it triggers `doesNotUnderstand:`.
    *   *Conceptual Distinction:* You cannot "access" a property directly; you can only ask the object to give it to you via a message.

*   **Python (Attribute Access + Call):**
    *   The fundamental atomic operation is **Attribute Lookup**, followed by a **Call**.
    *   Syntax: `obj.method(arg)`.
    *   *Step 1 (Lookup):* Python looks for an attribute named `method` on `obj`. This triggers `__getattribute__`.
    *   *Step 2 (Call):* If Step 1 returns a callable object (like a bound method), you then invoke it using `()`.
    *   *Difference:* In Python, `obj.method` is a valid expression that returns the method object itself without calling it. In Smalltalk, you cannot easily "hold" a message send without wrapping it in a block (closure).

#### Metaclasses
*   **Smalltalk:** Metaclasses are implicit. If you create a class `Dog`, the system automatically creates a `Dog class` metaclass. The hierarchy is parallel: `Dog` is an instance of `Dog class`.
*   **Python:** Metaclasses are explicit. You define a class `Meta(type)` and then set `metaclass=Meta` in your class definition. This gives you finer control over class creation but is less uniform than Smalltalk's parallel hierarchy.

---

### 3. Comparison: Python vs. CLOS (Common Lisp Object System)
CLOS is significantly more powerful (and complex) than Python, representing a different branch of OOP evolution.

#### Single vs. Multiple Dispatch
*   **Python (Single Dispatch):**
    *   Methods belong to a class.
    *   Dispatch is determined solely by the type of the **first argument** (`self`).
    *   `obj.draw(canvas)`: The code executed depends entirely on the type of `obj`.

*   **CLOS (Multiple Dispatch):**
    *   Methods do not belong to classes; they belong to **Generic Functions**.
    *   A Generic Function (e.g., `draw`) is a standalone object.
    *   You define methods for `draw` that specialize on *any* or *all* arguments.
    *   `(draw obj canvas)`: CLOS checks the types of **both** `obj` and `canvas` to decide which method implementation to run.

#### Method Combination
*   **Python:** Uses `super()` to chain calls. It is manual and linear. You must explicitly call `super().method()` inside your method to delegate to the next class in the MRO.
*   **CLOS:** Offers powerful declarative method combinations.
    *   **:before** methods: Run before the primary method.
    *   **:after** methods: Run after the primary method.
    *   **:around** methods: Wrap the entire execution (like a Python decorator but baked into the dispatch).
    *   This allows you to attach behavior (like logging or locking) to a generic function without touching the primary inheritance logic.

#### Encapsulation
*   **Python:** Attributes are public. Privacy is a convention (indicated by `_underscore`).
*   **CLOS:** Slots (attributes) are accessed via accessor functions generated by the class. Direct slot access (`slot-value`) is possible but discouraged. Like Python, it defaults to a permissive, introspectable system rather than strict C++/Java-style private/protected enforcement.

### Summary Table

| Feature | Python | Smalltalk | CLOS |
| :--- | :--- | :--- | :--- |
| **Fundamental Op** | Attribute Lookup + Call | Message Passing | Generic Function Application |
| **Dispatch** | Single (on `self`) | Single (on Receiver) | Multiple (on all args) |
| **Method Ownership** | Class | Class | Generic Function |
| **Inheritance** | Multiple (C3 MRO) | Single | Multiple |
| **Scope** | Explicit `self` | Implicit `self` | Explicit args |
| **Metaclasses** | Explicit (`type` subclass) | Implicit Parallel Hierarchy | Standard Class Objects (MOP) |
