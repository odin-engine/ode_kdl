/*
    2026 (c) Oleh, https://github.com/zm69

    kdl-cat CLI: reads a KDL v2 document (from a file argument, or stdin)
    and writes it back out in canonical form. Thin wrapper over the
    kdl_cat package; see kdl_cat/cat.odin for the actual logic.
*/
package main

// Core
    import "core:fmt"
    import "core:os"

// ODE
    import kdl_cat "../../kdl_cat"

main :: proc() {
    doc: []byte
    err: os.Error

    if len(os.args) > 1 {
        doc, err = os.read_entire_file_from_path(os.args[1], context.allocator)
        if err != nil {
            fmt.eprintfln("Error opening file \"%s\": %v", os.args[1], err)
            os.exit(1)
        }
    } else {
        doc, err = os.read_entire_file_from_file(os.stdin, context.allocator)
        if err != nil {
            fmt.eprintfln("Error reading stdin: %v", err)
            os.exit(1)
        }
    }
    defer delete(doc)

    result, cat_ok := kdl_cat.cat(string(doc))
    if !cat_ok {
        os.exit(1)
    }
    defer delete(result)

    os.write_string(os.stdout, result)
}
