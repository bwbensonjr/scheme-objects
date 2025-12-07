# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a research project exploring object systems for Scheme. The primary focus is getting Tiny CLOS (a minimal CLOS-like object system) running on Chez Scheme 10.3.0.

## Running the Code

```bash
# Start Chez Scheme REPL
chez

# Load the files in order:
(load "examples/tiny-clos/support.scm")
(load "examples/tiny-clos/tiny-clos.scm")
(load "examples/tiny-clos/tiny-examples.scm")
```

## Architecture

### Key Files in `examples/tiny-clos/`

- **support.scm** - Implementation-specific utilities and helpers. Contains `what-scheme-implementation` variable that must be set to `'chez` for Chez Scheme (currently set to `'mit`). This is the primary file needing modification for Chez compatibility.

- **tiny-clos.scm** - Core object system (~850 lines). Provides:
  - `make-class`, `make-generic`, `make-method`, `add-method`
  - `make`, `initialize`, `slot-ref`, `slot-set!`
  - Multiple inheritance, multi-methods, class specializers
  - Metaobject Protocol (MOP) with 8 introspective procedures and 9 intercessory generics

- **tiny-examples.scm** - Usage examples demonstrating the base language and MOP extensions

### Porting Considerations

The code was originally written for MIT Scheme. Key areas requiring adaptation for Chez Scheme:

1. **support.scm:43-46** - Change `what-scheme-implementation` from `'mit` to `'chez`
2. **support.scm:48-61** - The Chez branch for `define-macro` is incomplete (contains `???`)
3. **support.scm:64-67** - `gsort` already has Chez-specific implementation using `(sort predicate list)`

## Reference Documentation

- Chez Scheme docs: `docs/chez-scheme-docs/`
- Tiny CLOS design: `examples/tiny-clos/tiny-announce.text`
- MOP protocol spec: `examples/tiny-clos/tiny-rpp.text`
- Related book: "The Art of the Metaobject Protocol" (AMOP)
