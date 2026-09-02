/*
    Ported to Odin from ckdl (https://github.com/tjol/ckdl)
    Original C implementation Copyright (c) Thomas Jollans (MIT License)

    UTF-8 helpers built on core:unicode/utf8. ckdl hand-rolls its own decoder
    to distinguish OK/EOF/INCOMPLETE/ERROR for a streaming tokenizer; this
    port parses whole in-memory strings only (see CLAUDE.md), so INCOMPLETE
    never applies and we can lean on the standard library's decoder.
*/
package kdl

// Core
    import "core:unicode/utf8"

///////////////////////////////////////////////////////////////////////////////
// Utf8

    Utf8_Status :: enum u8 {
        OK,
        EOF,
        Decode_Error,
    }

    // Decode and consume one rune from the front of s. Advances s past the rune on OK.
    @(private)
    pop_rune :: proc(s: ^string) -> (r: rune, status: Utf8_Status) {
        if len(s^) == 0 do return 0, .EOF

        width: int
        r, width = utf8.decode_rune_in_string(s^)
        if r == utf8.RUNE_ERROR && width <= 1 do return 0, .Decode_Error

        s^ = s[width:]
        return r, .OK
    }

    // Decode one rune at a byte offset into s, without mutating anything. Returns the
    // byte offset just past the rune. Used by the string tokenizer, which needs to
    // peek and backtrack by exact byte positions.
    @(private)
    peek_rune :: proc(s: string, offset: int) -> (r: rune, next_offset: int, status: Utf8_Status) {
        if offset >= len(s) do return 0, offset, .EOF

        width: int
        r, width = utf8.decode_rune_in_string(s[offset:])
        if r == utf8.RUNE_ERROR && width <= 1 do return 0, offset, .Decode_Error

        return r, offset + width, .OK
    }
