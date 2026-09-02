# ode_kdl

A [KDL v2](https://kdl.dev) document-language tokenizer, pull-parser, and emitter for Odin, ported from the C library [ckdl](https://github.com/tjol/ckdl).

Validated against the official upstream KDL 2.0.0 test suite (319 cases, vendored in `tests/test_documents/upstream/2.0.0/`) — see `tests/conformance_test.odin`.

## Install

Clone into your project and import the `src` directory as `kdl`:

```sh
git clone https://github.com/zm69/ode_kdl vendor/ode_kdl
```

```odin
import kdl "vendor/ode_kdl/src"
```

## Parsing

`Parser` is a pull parser: each call to `next_event` returns the next `Event` in the document.

```odin
package example

import "core:fmt"
import kdl "ode_kdl/src"

main :: proc() {
    doc := `
    package "ode_kdl" version="0.1.0" {
        dependency "odin" version=">=dev-2026-01"
    }
    `

    parser: kdl.Parser
    kdl.init(&parser, doc)
    defer kdl.destroy(&parser)

    for {
        ev := kdl.next_event(&parser)
        switch ev.type {
        case .Start_Node:
            fmt.println("node:", ev.name)
        case .Argument:
            fmt.println("  arg:", ev.value)
        case .Property:
            fmt.println("  prop:", ev.name, "=", ev.value)
        case .End_Node:
            // nothing to do here in this example
        case .Comment:
            // only produced when kdl.init is called with emit_comments = true
        case .Parse_Error:
            msg, _ := ev.value.variant.(string)
            fmt.eprintln("parse error:", msg)
            return
        case .EOF:
            return
        }
    }
}
```

`Value.variant` is a plain Odin union — `bool`, `Number` (itself `union{i64, f64, string}`, string covering integers too large for `i64`), or `string`; `nil` represents KDL's `#null`. `Value.type_annotation` is a `Maybe(string)` — `nil` means no annotation, `Some("")` means an explicit empty-string annotation (`("")node`), which is legal KDL and distinct from having none.

## Emitting

`Emitter` builds a document back up from the same events:

```odin
emitter: kdl.Emitter
kdl.init(&emitter) // or kdl.init(&emitter, kdl.DEFAULT_EMITTER_OPTIONS)
defer kdl.destroy(&emitter)

kdl.emit_node(&emitter, "package")
kdl.emit_property(&emitter, "version", kdl.Value{variant = "0.1.0"})
kdl.emit_end(&emitter)

fmt.println(kdl.get_buffer(&emitter))
```

## kdl-cat

`kdl_cat/cat.odin` reformats a whole document to canonical form (properties de-duplicated and sorted lexically per node, matching ckdl's `ckdl-cat`), and ships as a small CLI:

```sh
odin build cmd/kdl_cat -out:cmd/kdl_cat/out/kdl_cat.exe -debug
./cmd/kdl_cat/out/kdl_cat.exe path/to/file.kdl
```

## Scope

This is a v2-only, string-input-only port of ckdl's core library — see `CLAUDE.md` for the full list of deliberate differences from upstream (no KDL v1, no streaming I/O, no C++/Python bindings).

## Testing

```sh
cd tests && odin test . -debug -o:none -define:ODIN_TEST_THREADS=1
```
